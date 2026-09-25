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

# Mappa delle celle occupate/prenotate: Vector2i -> agent_id
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
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
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

func get_available_destination(target_global_pos: Vector2, agent_id: int, current_cell: Vector2i, auto_reserve: bool = true) -> Vector2:
	if not grid:
		return target_global_pos

	var target_tile := get_tile_coords(target_global_pos)
	var best_tile := target_tile
	var found := false

	# 1. Controllo rapido sul tile desiderato
	if is_valid_cell(target_tile, agent_id, current_cell):
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

						if is_valid_cell(candidate_tile, agent_id, current_cell):
							best_tile = candidate_tile
							found = true
							break
					if found: break
				if found: break

	if found:
		# Se richiesto, blocca subito la cella per l'unità
		if auto_reserve:
			confirm_move(agent_id, current_cell, best_tile)
		return get_tile_center_global(best_tile)

	# Fallback: l'area è completamente sigillata, restituisce la posizione attuale
	return get_tile_center_global(current_cell)

# Trova il punto di spawn in stile Warcraft II, basato su un Rally Point (es. la miniera d'oro)
func get_warcraft_spawn_position(building_center_global: Vector2, building_size: Vector2i, rally_point_global: Vector2, agent_id: int) -> Vector2:
	if not grid:
		return building_center_global
		
	var cell_size: Vector2 = grid.cell_size
	var offset: Vector2 = (Vector2(building_size) - Vector2.ONE) * (cell_size / 2.0)
	var origin_center_world: Vector2 = building_center_global - offset
	var origin_tile: Vector2i = get_tile_coords(origin_center_world)
	
	var ideal_dir := Vector2.ZERO
	if rally_point_global != Vector2.INF:
		ideal_dir = building_center_global.direction_to(rally_point_global)
	
	# Espandiamo la ricerca fino a 5 anelli di distanza (puoi aumentare il limite se necessario)
	var direction : Array[Vector2i] = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]
	var w = building_size.x
	var h = building_size.y
	var last_tile_position = origin_tile
	var perimeter_tiles: Array[Vector2i] = []

	for radius in range(1, 6):
		# Spostati a sinistra per iniziare il nuovo anello
		last_tile_position += Vector2i.LEFT
		# Fondamentale: aggiungi subito la posizione iniziale per non saltare il tile
		perimeter_tiles.append(last_tile_position)
		
		# Calcola i passi esatti in base al bounding box espanso del raggio
		var steps_down = h + (radius * 2) - 2
		var steps_right = w + (radius * 2) - 1
		var steps_up = h + (radius * 2) - 1
		var steps_left = w + (radius * 2) - 1
		
		var side_dimension : Array[int] = [steps_down, steps_right, steps_up, steps_left]
		
		for count in range(4):
			var dir = direction[count]
			for step in range(side_dimension[count]):
				last_tile_position += dir
				perimeter_tiles.append(last_tile_position)
		
	# --- CASO SENZA RALLY POINT ---
	if ideal_dir == Vector2.ZERO:
		# Scorre l'anello in senso orario finché non trova un buco
		for tile in perimeter_tiles:
			if is_valid_cell(tile, agent_id, tile):
				confirm_move(agent_id, tile, tile)
				return get_tile_center_global(tile)

	# --- CASO CON RALLY POINT ---
	perimeter_tiles.sort_custom(func(a, b):
		var pos_a = get_tile_center_global(a)
		var pos_b = get_tile_center_global(b)
		var dir_a = building_center_global.direction_to(pos_a)
		var dir_b = building_center_global.direction_to(pos_b)
		return dir_a.dot(ideal_dir) > dir_b.dot(ideal_dir)
	)
	
	var primary_side: Array[Vector2i] = []
	var opposite_side: Array[Vector2i] = []
	
	for tile in perimeter_tiles:
		var pos = get_tile_center_global(tile)
		var dir = building_center_global.direction_to(pos)
		if dir.dot(ideal_dir) >= 0:
			primary_side.append(tile)
		else:
			opposite_side.append(tile)
			
	for tile in primary_side:
		if is_valid_cell(tile, agent_id, origin_tile): 
			confirm_move(agent_id, origin_tile, tile) 
			return get_tile_center_global(tile)
			
	for tile in opposite_side:
		if is_valid_cell(tile, agent_id, origin_tile):
			confirm_move(agent_id, origin_tile, tile)
			return get_tile_center_global(tile)
			
	# Se sia il lato ideale che quello opposto dell'anello corrente sono bloccati, passa al prossimo 'radius'
	return get_tile_center_global(origin_tile)

		#var perimeter_tiles: Array[Vector2i] = []
#
		## --- GENERAZIONE DELL'ANELLO (Senso orario, angoli non duplicati) ---
		## 1. Lato Superiore
		#for x in range(-radius, building_size.x + radius):
			#perimeter_tiles.append(origin_tile + Vector2i(x, -radius))
			#
		## 2. Lato Destro
		#for y in range(-radius + 1, building_size.y + radius):
			#perimeter_tiles.append(origin_tile + Vector2i(building_size.x + radius - 1, y))
			#
		## 3. Lato Inferiore
		#for x in range(building_size.x + radius - 2, -radius - 1, -1):
			#perimeter_tiles.append(origin_tile + Vector2i(x, building_size.y + radius - 1))
			#
		## 4. Lato Sinistro
		#for y in range(building_size.y + radius - 2, -radius, -1):
			#perimeter_tiles.append(origin_tile + Vector2i(-radius, y))
			#
		#
		## --- CASO SENZA RALLY POINT ---
		#if ideal_dir == Vector2.ZERO:
			## Scorre l'anello in senso orario finché non trova un buco
			#for tile in perimeter_tiles:
				#if is_valid_cell(tile, agent_id, origin_tile):
					#confirm_move(agent_id, origin_tile, tile)
					#return get_tile_center_global(tile)
			#
			## Se l'anello è tutto pieno, il ciclo continua col 'radius' successivo
			#continue
			
		## --- CASO CON RALLY POINT ---
		#perimeter_tiles.sort_custom(func(a, b):
			#var pos_a = get_tile_center_global(a)
			#var pos_b = get_tile_center_global(b)
			#var dir_a = building_center_global.direction_to(pos_a)
			#var dir_b = building_center_global.direction_to(pos_b)
			#return dir_a.dot(ideal_dir) > dir_b.dot(ideal_dir)
		#)
		#
		#var primary_side: Array[Vector2i] = []
		#var opposite_side: Array[Vector2i] = []
		#
		#for tile in perimeter_tiles:
			#var pos = get_tile_center_global(tile)
			#var dir = building_center_global.direction_to(pos)
			#if dir.dot(ideal_dir) >= 0:
				#primary_side.append(tile)
			#else:
				#opposite_side.append(tile)
				#
		#for tile in primary_side:
			#if is_valid_cell(tile, agent_id, origin_tile): 
				#confirm_move(agent_id, origin_tile, tile) 
				#return get_tile_center_global(tile)
				#
		#for tile in opposite_side:
			#if is_valid_cell(tile, agent_id, origin_tile):
				#confirm_move(agent_id, origin_tile, tile)
				#return get_tile_center_global(tile)
				#
		## Se sia il lato ideale che quello opposto dell'anello corrente sono bloccati, passa al prossimo 'radius'

	# Fallback di emergenza: l'edificio è murato vivo per 5 tile di profondità in ogni direzione
	return get_tile_center_global(origin_tile)

# Controlla se una cella esiste, non ha ostacoli fissi e non è occupata da altre truppe
func is_valid_cell(cell: Vector2i, agent_id: int, current_cell: Vector2i) -> bool:
	if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
		return false

	var check = preview_move(agent_id, current_cell, cell)
	return bool(check["ok"])

func get_adjacent_free_position(center_global_pos: Vector2, building_size: Vector2i, ideal_direction: Vector2, agent_id: int, auto_reserve: bool = true) -> Vector2:
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
		if is_valid_cell(tile, agent_id, center_tile):
			if auto_reserve:
				confirm_move(agent_id, center_tile, tile)
			return get_tile_center_global(tile)
			
	# 6. Fallback: restituisce il primo tile del perimetro anche se occupato
	return get_tile_center_global(perimeter_tiles[0])

# Anteprima di sola lettura
func preview_move(agent_id: int, from_cell: Vector2i, to_cell: Vector2i) -> Dictionary:
	if agent_id <= 0:
		return _failure("INVALID_AGENT", from_cell)

	if reserved_by(from_cell) != agent_id and reserved_by(from_cell) != EMPTY: 
		return _failure("INVALID_START", from_cell, reserved_by(from_cell))

	var target_owner := reserved_by(to_cell)
	if target_owner != EMPTY and target_owner != agent_id:
		return _failure("TARGET_OCCUPIED", to_cell, target_owner)

	return {
		"ok": true,
		"code": "OK",
		"from_cell": from_cell,
		"to_cell": to_cell,
		"reserved_by": target_owner,
	}

# Transazione di conferma del movimento
func confirm_move(agent_id: int, from_cell: Vector2i, to_cell: Vector2i) -> Dictionary:
	var validation := preview_move(agent_id, from_cell, to_cell)
	if not bool(validation["ok"]):
		return validation

	var before: Dictionary[Vector2i, int] = {}
	before[from_cell] = reserved_by(from_cell)
	before[to_cell] = reserved_by(to_cell)

	_undo_stack.append({
		"agent_id": agent_id,
		"from_cell": from_cell,
		"to_cell": to_cell,
		"before": before,
	})

	if from_cell != to_cell:
		_owner_by_cell.erase(from_cell)
	_owner_by_cell[to_cell] = agent_id

	return {
		"ok": true,
		"code": "OK",
		"from_cell": from_cell,
		"to_cell": to_cell,
		"reserved_by": agent_id,
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
func get_best_chopping_position(tree_cell: Vector2i, unit_global_pos: Vector2, agent_id: int) -> Vector2:
	var tree_global := get_tile_center_global(tree_cell)
	
	# Calcola da quale direzione sta arrivando il lavoratore
	var approach_dir := unit_global_pos.direction_to(tree_global)
	
	# L'albero è considerato un ostacolo 1x1. 
	# Il parametro 'true' finale chiama confirm_move() per bloccare atomicamente la cella per questo specifico agent_id
	return get_adjacent_free_position(tree_global, Vector2i(1, 1), approach_dir, agent_id, true)

# --- 4. RILASCIO AGENTI E RISORSE ---

# Rilascia le celle quando un'unità lascia la mappa (o muore)
func release_agent(agent_id: int) -> Dictionary:
	if agent_id <= 0:
		return _failure("INVALID_AGENT", Vector2i(-1, -1))

	var freed_cells: Array[Vector2i] = []
	for cell: Vector2i in _owner_by_cell.keys():
		if reserved_by(cell) == agent_id:
			_owner_by_cell.erase(cell)
			_release_blocker_cell(cell) # <-- Usa il decremento invece di forzare a false
			freed_cells.append(cell)
	
	var released_count = freed_cells.size()
	
	# Se l'agente possedeva effettivamente delle celle, avvisiamo i viandanti
	if released_count > 0:
		obstacles_changed.emit(freed_cells)
	
	return {
		"ok": true,
		"code": "OK" if released_count > 0 else "OK_EMPTY",
		"agent_id": agent_id,
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

func snap_to_tile(global_pos: Vector2) -> Vector2:
	if not tile_map_layer:
		return global_pos
	var coords = get_tile_coords(global_pos)
	return get_tile_center_global(coords)
