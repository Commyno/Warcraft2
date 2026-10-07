extends Node2D

# --- SIGNALS
signal obstacles_changed(affected_cells: Array)

# --- COSTANTI & STATO ---
const TREE_MAX_HEALTH: int = 50
const STUMP_SOURCE_ID: int = 0
const STUMP_ATLAS_COORDS: Vector2i = Vector2i(12, 6)
const EMPTY := 0

var tile_map_layer: TileMapLayer = null
var grid: AStarGrid2D = null

# Vector2i -> true (Memorizza gli ostacoli nativi della mappa come alberi e acqua)
var _base_solid: Dictionary = {}

# Vector2i -> int (Conta quanti oggetti stanno bloccando la cella in questo momento)
var _blocker_counts: Dictionary = {}

# Mappa delle celle occupate/prenotate: Vector2i -> entity_id
var _owner_by_cell: Dictionary[Vector2i, int] = {}
# Storico per annullare i movimenti (Undo)
var _undo_stack: Array[Dictionary] = []

# Dizionario per memorizzare la salute degli alberi
var trees_health: Dictionary = {}

func _ready() -> void:
	z_index = 150

# --- 1. INIZIALIZZAZIONE MAPPA E ASTAR ---

func build_from_tilemap_layer(tile_layer: TileMapLayer) -> void:
	tile_map_layer = tile_layer
	
	var used_rect := tile_layer.get_used_rect()
	var cell_size := tile_layer.tile_set.tile_size

	grid = AStarGrid2D.new()
	grid.region = used_rect
	grid.cell_size = Vector2(cell_size)
	grid.offset = Vector2(cell_size) / 2.0
	# Non consente il movimento in diagonale
	#grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	# Consente sempre il movimento in diagonale
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	# Alternativa: consente la diagonale solo se l'unità non "taglia" l'angolo tra due muri adiacenti
	# grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE

	grid.update()

	_base_solid.clear()
	_blocker_counts.clear()
	
	for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
		for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
			var cell := Vector2i(x, y)
			# Valuta la solidità tramite i metadati del TileMapLayer
			var is_solid = not is_cell_buildable(cell) or is_tree(cell)
			
			if is_solid:
				_base_solid[cell] = true
			
			grid.set_point_solid(cell, is_solid)
						
	print("GridManager: AStarGrid2D generato da TileMapLayer.")

# --- 2. GESTIONE PRENOTAZIONI E OCCUPAZIONE (Reservation Table) ---

func reserved_by(cell: Vector2i) -> int:
	return int(_owner_by_cell.get(cell, EMPTY))

func _success(cell: Vector2i) -> Dictionary:
	return {
		"ok": true,
		"code": "OK",
		"at_cell": cell,
		"reserved_by": reserved_by(cell),
	}

func _failure(code: String, cell: Vector2i, owner := EMPTY) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"at_cell": cell,
		"reserved_by": owner,
	}

func _claim_blocker_cell(cell: Vector2i) -> void:
	var next_count := blocker_count_at(cell) + 1
	_blocker_counts[cell] = next_count
	grid.set_point_solid(cell, true)

func _release_blocker_cell(cell: Vector2i) -> void:
	var next_count := maxi(0, blocker_count_at(cell) - 1)
	
	if next_count == 0:
		_blocker_counts.erase(cell)
	else:
		_blocker_counts[cell] = next_count
		
	# La cella rimane solida se ci sono ancora ostacoli sovrapposti, 
	# oppure se era un ostacolo nativo del livello (es. muro/acqua).
	var remains_solid := authored_solid_at(cell) or next_count > 0
	grid.set_point_solid(cell, remains_solid)

func blocker_count_at(cell: Vector2i) -> int:
	return int(_blocker_counts.get(cell, 0))

func authored_solid_at(cell: Vector2i) -> bool:
	return bool(_base_solid.get(cell, false))

func get_available_destination(target_global_pos: Vector2, entity_id: int, current_cell: Vector2i, auto_reserve: bool = true) -> Vector2:
	if not grid:
		return target_global_pos

	var target_tile := get_tile_coords(target_global_pos)
	var best_tile := target_tile
	var found := false

	# 1. Controllo rapido sul tile desiderato
	if is_valid_cell(target_tile, entity_id, current_cell):
		found = true
	else:
		# 2. NOVITÀ: Controllo di adiacenza prima di innescare la ricerca
		var dist_x = abs(current_cell.x - target_tile.x)
		var dist_y = abs(current_cell.y - target_tile.y)
		
		# Se l'unità è già adiacente (distanza di Chebyshev <= 1) o sul tile stesso, 
		# non ha senso spostarsi lateralmente. Resta dove si trova.
		if maxi(dist_x, dist_y) <= 1:
			best_tile = current_cell
			found = true
		else:
			# 3. PRELAZIONE: Ricerca a spirale (raggio da 1 a 5)
			for radius in range(1, 6):
				for x in range(-radius, radius + 1):
					for y in range(-radius, radius + 1):
						# Controlliamo solo il perimetro esterno dell'anello corrente
						if abs(x) != radius and abs(y) != radius:
							continue
				
						var candidate_tile = target_tile + Vector2i(x, y)

						if is_valid_cell(candidate_tile, entity_id, current_cell):
							best_tile = candidate_tile
							found = true
							break
					if found: break
				if found: break

	if found:
		# Se richiesto, blocca subito la cella per l'unità
		if auto_reserve:
			confirm_move(entity_id, current_cell, best_tile)
		return get_tile_center_global(best_tile)

	# Fallback: l'area è completamente sigillata, restituisce la posizione attuale
	return get_tile_center_global(current_cell)

# Trova il punto di spawn in stile Warcraft II, basato su un Rally Point (es. la miniera d'oro)
func get_warcraft_spawn_position(building: BaseBuilding, entity_id: int, ideal_target: Vector2 = Vector2.INF) -> Vector2:
	if not grid:
		return building.global_position
		
	var cell_size: Vector2 = grid.cell_size
	var offset: Vector2 = (Vector2(building.tile_size) - Vector2.ONE) * (cell_size / 2.0)
	var origin_center_world: Vector2 = building.global_position - offset
	var origin_tile: Vector2i = get_tile_coords(origin_center_world)
	
	var ideal_dir := Vector2.ZERO
	var rallypoint_component = building.get_node_or_null("RallypointComponent")
	if rallypoint_component != null:
		if rallypoint_component.rallypoint_position != Vector2.INF:
			ideal_dir = building.global_position.direction_to(rallypoint_component.rallypoint_position)
	elif ideal_target != Vector2.INF:
		ideal_dir = building.global_position.direction_to(ideal_target)
		
	var w = building.tile_size.x
	var h = building.tile_size.y

	# 1. Determina l'orientamento principale del rally point
	var side_index: int = 0 # Default: LEFT
	if ideal_dir != Vector2.ZERO:
		if abs(ideal_dir.x) > abs(ideal_dir.y):
			side_index = 2 if ideal_dir.x > 0 else 0 # Destra o Sinistra
		else:
			side_index = 1 if ideal_dir.y > 0 else 3 # Basso o Alto

	# 2. Configura il punto di partenza, la spinta iniziale e l'ordine dei movimenti
	var start_corner: Vector2i
	var shift_dir: Vector2i
	var direction_sequence: Array[Vector2i] = []
	var base_dims: Array[int] = []

	match side_index:
		0: # LEFT (Base: in alto a sinistra. Va verso il basso)
			start_corner = origin_tile
			shift_dir = Vector2i.LEFT
			direction_sequence = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
			base_dims = [h, w, h, w]
		1: # BOTTOM (Base: in basso a sinistra. Va verso destra)
			start_corner = origin_tile + Vector2i(0, h - 1)
			shift_dir = Vector2i.DOWN
			direction_sequence = [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN]
			base_dims = [w, h, w, h]
		2: # RIGHT (Base: in basso a destra. Va verso l'alto)
			start_corner = origin_tile + Vector2i(w - 1, h - 1)
			shift_dir = Vector2i.RIGHT
			direction_sequence = [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]
			base_dims = [h, w, h, w]
		3: # TOP (Base: in alto a destra. Va verso sinistra)
			start_corner = origin_tile + Vector2i(w - 1, 0)
			shift_dir = Vector2i.UP
			direction_sequence = [Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP]
			base_dims = [w, h, w, h]

	var last_tile_position = start_corner
	var perimeter_tiles: Array[Vector2i] = []

	# 3. Sviluppa gli anelli
	for radius in range(1, 6):
		# Spostati per iniziare il nuovo anello verso la direzione di partenza
		last_tile_position += shift_dir
		perimeter_tiles.append(last_tile_position)
		
		# I passi si adattano automaticamente. Il primo lato è sempre -2 perché 
		# il comando `shift_dir` ha già "consumato" il primo tile utile della linea.
		var side_steps: Array[int] = [
			base_dims[0] + (radius * 2) - 2,
			base_dims[1] + (radius * 2) - 1,
			base_dims[2] + (radius * 2) - 1,
			base_dims[3] + (radius * 2) - 1
		]
		
		for count in range(4):
			var dir = direction_sequence[count]
			for step in range(side_steps[count]):
				last_tile_position += dir
				perimeter_tiles.append(last_tile_position)

	# Scorre l'anello in senso orario finché non trova un buco
	for tile in perimeter_tiles:
		if is_valid_cell(tile, entity_id, tile):
			confirm_move(entity_id, tile, tile)
			return get_tile_center_global(tile)
			
	# Se sia il lato ideale che quello opposto dell'anello corrente sono bloccati, passa al prossimo 'radius'
	return get_tile_center_global(origin_tile)

# Controlla se una cella esiste, non ha ostacoli fissi e non è occupata da altre truppe
func is_valid_cell(cell: Vector2i, entity_id: int, current_cell: Vector2i) -> bool:
	if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
		return false

	var check = preview_move(entity_id, current_cell, cell)
	return bool(check["ok"])

func get_adjacent_free_position(center_global_pos: Vector2, building_size: Vector2i, ideal_direction: Vector2, entity_id: int, auto_reserve: bool = true) -> Vector2:
	var center_tile := get_tile_coords(center_global_pos)
	
	# 1. Calcoliamo il raggio in tile per determinare il perimetro dell'edificio
	var radius_x := (building_size.x / 2) + 1
	var radius_y := (building_size.y / 2) + 1
	
	var perimeter_tiles: Array[Vector2i] = []
	
	# 2. Generiamo tutti i tile del perimetro
	for x in range(-radius_x, radius_x + 1):
		perimeter_tiles.append(center_tile + Vector2i(x, -radius_y))
		perimeter_tiles.append(center_tile + Vector2i(x, radius_y))
		
	for y in range(-radius_y + 1, radius_y):
		perimeter_tiles.append(center_tile + Vector2i(-radius_x, y))
		perimeter_tiles.append(center_tile + Vector2i(radius_x, y))
		
	# 3. Calcoliamo il punto "ideale" galleggiante
	var ideal_dir := ideal_direction.normalized()
	if ideal_dir == Vector2.ZERO: 
		ideal_dir = Vector2.DOWN 
		
	var ideal_tile_float := Vector2(center_tile) + Vector2(ideal_dir.x * radius_x, ideal_dir.y * radius_y)
	
	# 4. Ordiniamo i tile dal più vicino al più lontano rispetto al punto ideale
	perimeter_tiles.sort_custom(func(a, b):
		var dist_a = Vector2(a).distance_squared_to(ideal_tile_float)
		var dist_b = Vector2(b).distance_squared_to(ideal_tile_float)
		return dist_a < dist_b
	)
	
	# 5. Iteriamo i tile ordinati e troviamo il primo libero e valido
	for tile in perimeter_tiles:
		# Controlla se il tile è fuori dai muri e libero da altre unità
		# Usiamo center_tile come finta cella di partenza per bypassare i controlli su noi stessi
		if is_valid_cell(tile, entity_id, center_tile):
			if auto_reserve:
				confirm_move(entity_id, center_tile, tile)
			return get_tile_center_global(tile)
			
	# 6. Fallback: restituisce il primo tile del perimetro anche se occupato
	return get_tile_center_global(perimeter_tiles[0])

# Anteprima di sola lettura
func preview_move(entity_id: int, from_cell: Vector2i, to_cell: Vector2i) -> Dictionary:
	if entity_id <= 0:
		return _failure("INVALID_AGENT", from_cell)

	if reserved_by(from_cell) != entity_id and reserved_by(from_cell) != EMPTY: 
		return _failure("INVALID_START", from_cell, reserved_by(from_cell))

	var target_owner := reserved_by(to_cell)
	if target_owner != EMPTY and target_owner != entity_id:
		return _failure("TARGET_OCCUPIED", to_cell, target_owner)

	return {
		"ok": true,
		"code": "OK",
		"from_cell": from_cell,
		"to_cell": to_cell,
		"reserved_by": target_owner,
	}

# Transazione di conferma del movimento
func confirm_move(entity_id: int, from_cell: Vector2i, to_cell: Vector2i) -> Dictionary:
	var validation := preview_move(entity_id, from_cell, to_cell)
	if not bool(validation["ok"]):
		return validation

	var before: Dictionary[Vector2i, int] = {}
	before[from_cell] = reserved_by(from_cell)
	before[to_cell] = reserved_by(to_cell)

	_undo_stack.append({
		"entity_id": entity_id,
		"from_cell": from_cell,
		"to_cell": to_cell,
		"before": before,
	})

	if from_cell != to_cell:
		_owner_by_cell.erase(from_cell)
	_owner_by_cell[to_cell] = entity_id

	return {
		"ok": true,
		"code": "OK",
		"from_cell": from_cell,
		"to_cell": to_cell,
		"reserved_by": entity_id,
	}

# --- 3. GESTIONE FOOTPRINT EDIFICI ---

# Calcola tutte le celle occupate dall'edificio
func footprint_cells(anchor: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(size.y):
		for x in range(size.x):
			cells.append(anchor + Vector2i(x, y))
	return cells

# Imposta una serie di celle come solide
func set_cells_solid(cells: Array, solid: bool) -> bool:
	if grid.is_dirty() or not _all_cells_in_bounds(cells):
		return false
	
	for cell: Vector2i in cells:
		if solid:
			_claim_blocker_cell(cell)
		else:
			_release_blocker_cell(cell)
			
	# Avvisa tutte le unità in ascolto che queste celle hanno cambiato stato
	obstacles_changed.emit(cells)
	return true

func _all_cells_in_bounds(cells: Array) -> bool:
	for cell: Vector2i in cells:
		if not grid.is_in_boundsv(cell):
			return false
	return true

# Controlla se un'intera area rettangolare è libera per piazzare un edificio
func is_area_buildable(anchor: Vector2i, size: Vector2i) -> bool:
	if not grid:
		return false
		
	var cells = footprint_cells(anchor, size)
	
	for cell in cells:
		# 1. Controlla se la cella è fuori dalla mappa o è fisicamente bloccata (muri, acqua, altri edifici)
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
			return false
			
		# 2. Controlla se la cella è occupata logicamente da un'unità ferma o in transito
		if reserved_by(cell) != EMPTY:
			return false
			
	return true

# Cerca il tile di legno più vicino partendo da un centro, espandendosi ad anelli
func get_closest_tree_around(center_cell: Vector2i, max_radius: int) -> Vector2i:
	# 1. Controlla prima il punto di partenza
	if is_tree(center_cell):
		return center_cell
		
	# 2. Ricerca a spirale (cerca anello per anello verso l'esterno)
	for radius in range(1, max_radius + 1):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				# Analizza solo il perimetro dell'anello corrente per ottimizzare
				if abs(x) != radius and abs(y) != radius:
					continue
					
				var candidate_cell = center_cell + Vector2i(x, y)
				if is_tree(candidate_cell):
					return candidate_cell
					
	# 3. Nessun albero trovato nel raggio specificato
	return Vector2i(-1, -1)

# Trova e prenota la migliore cella adiacente per tagliare un albero
func get_best_chopping_position(tree_cell: Vector2i, unit_global_pos: Vector2, entity_id: int) -> Vector2:
	var tree_global := get_tile_center_global(tree_cell)
	
	# Calcola da quale direzione sta arrivando il lavoratore
	var approach_dir := unit_global_pos.direction_to(tree_global)
	
	# L'albero è considerato un ostacolo 1x1. 
	# Il parametro 'true' finale chiama confirm_move() per bloccare atomicamente la cella per questo specifico entity_id
	return get_adjacent_free_position(tree_global, Vector2i(1, 1), approach_dir, entity_id, true)

# --- 4. RILASCIO AGENTI E RISORSE ---

# Rilascia le celle quando un'unità lascia la mappa (o muore)
func release_agent(entity_id: int) -> Dictionary:
	if entity_id <= 0:
		return _failure("INVALID_AGENT", Vector2i(-1, -1))

	var freed_cells: Array[Vector2i] = []
	for cell: Vector2i in _owner_by_cell.keys():
		if reserved_by(cell) == entity_id:
			_owner_by_cell.erase(cell)
			#_release_blocker_cell(cell) # Rimosso in quanto nel confirm non blocca. E cmq, 
			#preview_move già controlla _owner_by_cell prima di concedere una cella, quindi
			#le unità si evitano già a livello logico. L'AStar invece non le vede come ostacoli
			freed_cells.append(cell)
	
	var released_count = freed_cells.size()
	
	# Se l'agente possedeva effettivamente delle celle, avvisiamo i viandanti
	if released_count > 0:
		obstacles_changed.emit(freed_cells)
	
	return {
		"ok": true,
		"code": "OK" if released_count > 0 else "OK_EMPTY",
		"entity_id": entity_id,
		"released_cells": released_count,
	}

# --- 5. GESTIONE FORESTA E UTILITIES ---

func is_tree(tile_coords: Vector2i) -> bool:
	var tile_data: TileData = tile_map_layer.get_cell_tile_data(tile_coords)
	if tile_data != null and tile_data.has_meta("is_wood"):
		return tile_data.get_meta("is_wood") == true
	return false

func chop_tree(tile_coords: Vector2i, damage: int) -> int:
	if not is_tree(tile_coords):
		return 0
		
	if not trees_health.has(tile_coords):
		trees_health[tile_coords] = TREE_MAX_HEALTH
		
	trees_health[tile_coords] -= damage
	var wood_yield = damage
	
	if trees_health[tile_coords] <= 0:
		wood_yield += trees_health[tile_coords]
		trees_health.erase(tile_coords)
		
		tile_map_layer.set_cell(tile_coords, STUMP_SOURCE_ID, STUMP_ATLAS_COORDS)
		
		# Aggiorna il pathfinder a runtime senza rebuild
		grid.set_point_solid(tile_coords, false)
		_base_solid.erase(tile_coords)
		
	return max(0, wood_yield)

func get_tile_coords(global_pos: Vector2) -> Vector2i:
	var local_pos = tile_map_layer.to_local(global_pos)
	return tile_map_layer.local_to_map(local_pos)

func get_tile_center_global(tile_coords: Vector2i) -> Vector2:
	var local_pos : Vector2 = tile_map_layer.map_to_local(tile_coords)
	return tile_map_layer.to_global(local_pos)

func is_cell_buildable(cell: Vector2i) -> bool:
	var data := tile_map_layer.get_cell_tile_data(cell)
	if data == null:
		return false
	return data.get_meta("is_buildable") == true

# Interroga l'AStarGrid2D usando le coordinate della griglia
func get_path_for_unit(start_cell: Vector2i, goal_cell: Vector2i) -> Array[Vector2i]:
	if grid.is_in_boundsv(start_cell) and grid.is_in_boundsv(goal_cell):
		return grid.get_id_path(start_cell, goal_cell)
	return []

# Esegue il pathfinding trattando le celle occupate da altri come ostacoli temporanei
func get_path_avoiding_units(start_cell: Vector2i, target_cell: Vector2i, requester_id: int) -> Array[Vector2i]:
	# 1. Rendi temporaneamente solide le celle occupate da altri agenti
	var temp_solid: Array[Vector2i] = []
	for cell in _owner_by_cell.keys():
		var owner = _owner_by_cell[cell]
		if owner != requester_id and not grid.is_point_solid(cell):
			grid.set_point_solid(cell, true)
			temp_solid.append(cell)

	# 2. Calcola il percorso
	var path = grid.get_id_path(start_cell, target_cell, true)

	# 3. Ripristina tutte le celle temporanee
	for cell in temp_solid:
		var remains_solid = authored_solid_at(cell) or blocker_count_at(cell) > 0
		grid.set_point_solid(cell, remains_solid)

	return path

func snap_to_tile(global_pos: Vector2) -> Vector2:
	if not tile_map_layer:
		return global_pos
	var coords = get_tile_coords(global_pos)
	return get_tile_center_global(coords)
