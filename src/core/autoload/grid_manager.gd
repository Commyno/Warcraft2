#extends Node solo DEBUG
extends Node2D

const TREE_MAX_HEALTH: int = 50 # Quanta legna contiene un albero prima di crollare
# ID del tuo tileset (di solito è 0 se ne hai caricato solo uno)
const STUMP_SOURCE_ID: int = 0 
# Le coordinate X,Y del ceppo all'interno della griglia del tileset
const STUMP_ATLAS_COORDS: Vector2i = Vector2i(12, 6)

# Riferimento al TileMapLayer principale della mappa di gioco
var tile_map_layer: TileMapLayer = null
# Dizionario delle prenotazioni: Chiave = Vector2i (coordinate tile), Valore = Node2D (unità)
var tile_reservations: Dictionary = {}
# Dizionario per memorizzare la salute degli alberi. Chiave: Vector2i (coordinate tile)
var trees_health: Dictionary = {}

func _ready() -> void:
	# Forza il GridManager a disegnare SOPRA a tutto il resto (alberi compresi)
	z_index = 150 

# --- 1. CONFIGURAZIONE E MAPPA ---

func set_tile_map(map_layer: TileMapLayer) -> void:
	tile_map_layer = map_layer
	print("GridManager: TileMapLayer registrato con successo.")

# --- 2. CONVERSIONI DI POSIZIONE (Tile <-> Globale) ---

func get_tile_coords(global_pos: Vector2) -> Vector2i:
	if not tile_map_layer:
		return Vector2i.ZERO
	var local_pos = tile_map_layer.to_local(global_pos)
	return tile_map_layer.local_to_map(local_pos)

func get_tile_center_global(tile_coords: Vector2i) -> Vector2:
	if not tile_map_layer:
		return Vector2.ZERO
	var local_pos : Vector2 = tile_map_layer.map_to_local(tile_coords)
	return tile_map_layer.to_global(local_pos)

func snap_to_tile(global_pos: Vector2) -> Vector2:
	if not tile_map_layer:
		return global_pos
	var coords = get_tile_coords(global_pos)
	return get_tile_center_global(coords)

# --- 3. GESTIONE PRENOTAZIONI E PRELAZIONE ---

# Libera tutti i tile che erano stati prenotati da un'unità specifica (es. quando muore o cambia ordine)
func release_unit_reservations(unit: Node2D) -> void:
	var keys_to_remove = []
	for tile in tile_reservations.keys():
		if tile_reservations[tile] == unit:
			keys_to_remove.append(tile)
	for tile in keys_to_remove:
		tile_reservations.erase(tile)

# Tenta di prenotare un tile per un'unità
func try_reserve_tile(tile_coords: Vector2i, unit: Node2D) -> bool:
	if not tile_reservations.has(tile_coords):
		tile_reservations[tile_coords] = unit
		return true
	if tile_reservations[tile_coords] == unit:
		return true
	return false # Tile occupato da un'altra unità!

# Restituisce la posizione globale corretta: se il tile desiderato è occupato, 
# trova il primo tile libero disponibile nelle vicinanze o lungo il percorso.
func get_available_destination(target_global_pos: Vector2, unit: Node2D = null) -> Vector2:
	if not tile_map_layer:
		return target_global_pos

	var target_tile = get_tile_coords(target_global_pos)

	# Se il tile di destinazione è libero o già di proprietà di questa unità, usalo
	if unit == null or not tile_reservations.has(target_tile) or tile_reservations[target_tile] == unit:
		return get_tile_center_global(target_tile)

	# PRELAZIONE: Se il tile è occupato, cerchiamo un tile libero a spirale/adiacente (raggio 1 e 2)
	# partendo da quello desiderato e allontanandoci verso l'unità
	for radius in range(1, 4):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var candidate_tile = target_tile + Vector2i(x, y)
				if not tile_reservations.has(candidate_tile):
					return get_tile_center_global(candidate_tile)

	# Fallback estremo: se la zona è totalmente intasata, l'unità resta ferma dove si trova
	return unit.global_position

func get_adjacent_free_position(center_global_pos: Vector2, building_size: Vector2i, ideal_direction: Vector2, unit: Node2D = null) -> Vector2:
	var center_tile = get_tile_coords(center_global_pos)
	
	# 1. Calcoliamo il raggio in tile. 
	# Con divisione intera (es: 3 / 2 = 1). Aggiungiamo 1 per stare sul bordo esterno.
	# Risultato per 3x3: raggio 2.
	var radius_x = (building_size.x / 2) + 1
	var radius_y = (building_size.y / 2) + 1
	
	var perimeter_tiles: Array[Vector2i] = []
	
	# 2. Generiamo tutti i tile del perimetro
	# Lati orizzontali (sopra e sotto)
	for x in range(-radius_x, radius_x + 1):
		perimeter_tiles.append(center_tile + Vector2i(x, -radius_y))
		perimeter_tiles.append(center_tile + Vector2i(x, radius_y))
		
	# Lati verticali (sinistra e destra, escludendo gli angoli già contati)
	for y in range(-radius_y + 1, radius_y):
		perimeter_tiles.append(center_tile + Vector2i(-radius_x, y))
		perimeter_tiles.append(center_tile + Vector2i(radius_x, y))
		
	# 3. Calcoliamo il punto "ideale" galleggiante basato sulla direzione d'ingresso
	var ideal_dir = ideal_direction.normalized()
	# Se ideal_dir è (0,0), usiamo giù come default
	if ideal_dir == Vector2.ZERO: 
		ideal_dir = Vector2.DOWN 
		
	var ideal_tile_float = Vector2(center_tile) + Vector2(ideal_dir.x * radius_x, ideal_dir.y * radius_y)
	
	# 4. Ordiniamo i tile: dal più vicino al punto ideale al più lontano
	perimeter_tiles.sort_custom(func(a, b):
		var dist_a = Vector2(a).distance_squared_to(ideal_tile_float)
		var dist_b = Vector2(b).distance_squared_to(ideal_tile_float)
		return dist_a < dist_b
	)
	
	# 5. Iteriamo i tile ordinati e troviamo il primo libero
	for tile in perimeter_tiles:
		var global_pos = get_tile_center_global(tile)
		
		# Sfruttiamo la tua funzione esistente per controllare se la destinazione è calpestabile
		var safe_pos = get_available_destination(global_pos, unit)
		
		# Se safe_pos è uguale al tile che stiamo testando, significa che è perfettamente libero!
		# (Adatta questo if se la tua funzione is_tile_walkable restituisce un booleano invece del Vector2)
		if safe_pos == global_pos:
			return global_pos
			
	# 6. Fallback di emergenza: se l'edificio è circondato da unità al 100%, 
	# lo facciamo spawnare forzatamente nel punto ideale che avevamo calcolato
	return get_tile_center_global(perimeter_tiles[0])

# --- GESTIONE FORESTA ---

# Verifica se un tile specifico è un albero leggendo il Custom Data
func is_tree(tile_coords: Vector2i) -> bool:
	var tile_data: TileData = tile_map_layer.get_cell_tile_data(tile_coords)
	
	if tile_data != null:
		# 1. Controlliamo se l'importatore di Tiled ha salvato la proprietà come Metadato
		if tile_data.has_meta("is_wood"):
			var is_wood = tile_data.get_meta("is_wood")
			return is_wood == true
			
		# 2. (Opzionale) Manteniamo anche il vecchio controllo nel caso tu decida 
		# di usare i Custom Data nativi di Godot in futuro
		var custom_is_wood = tile_data.get_custom_data("is_wood")
		if custom_is_wood != null:
			return custom_is_wood == true
			
	return false

# Funzione per tagliare l'albero. Restituisce la legna ottenuta.
func chop_tree(tile_coords: Vector2i, damage: int) -> int:
	if not is_tree(tile_coords):
		return 0
		
	# Inizializza la vita dell'albero se è la prima volta che viene colpito
	if not trees_health.has(tile_coords):
		trees_health[tile_coords] = TREE_MAX_HEALTH
		
	trees_health[tile_coords] -= damage
	var wood_yield = damage
	
	# Se l'albero è distrutto
	if trees_health[tile_coords] <= 0:
		wood_yield += trees_health[tile_coords] # Evita di dare più legna del dovuto se il danno sfora
		trees_health.erase(tile_coords)
		
		# --- LA MAGIA DEL CEPPO ---
		# Rimuove il quadrato verde di selezione (per evitare che rimanga sul ceppo)
		remove_tile_highlight(tile_coords) # Solor DEBUG
		
		# Sostituisce il tile con il ceppo
		tile_map_layer.set_cell(tile_coords, STUMP_SOURCE_ID, STUMP_ATLAS_COORDS)
		
	return max(0, wood_yield)

# Ricerca a spirale: cerca il tile albero più vicino partendo da un centro
func get_closest_tree_around(start_tile: Vector2i, max_radius: int = 5) -> Vector2i:
	# Controlla prima il centro stesso (se per caso l'albero c'è ancora)
	if is_tree(start_tile):
		return start_tile
		
	# Espande la ricerca ad anelli concentrici
	for r in range(1, max_radius + 1):
		# Lati orizzontali
		for x in range(-r, r + 1):
			if is_tree(start_tile + Vector2i(x, -r)): return start_tile + Vector2i(x, -r)
			if is_tree(start_tile + Vector2i(x, r)): return start_tile + Vector2i(x, r)
		# Lati verticali
		for y in range(-r + 1, r):
			if is_tree(start_tile + Vector2i(-r, y)): return start_tile + Vector2i(-r, y)
			if is_tree(start_tile + Vector2i(r, y)): return start_tile + Vector2i(r, y)
			
	return Vector2i(-1, -1) # Nessun albero trovato nel raggio


# --- GESTIONE EVIDENZIAZIONE TILE (FEEDBACK VISIVO) --- SOLO DEBUG
var targeted_tiles: Dictionary = {}
const TILE_SIZE: Vector2 = Vector2(32, 32) # Cambialo se i tuoi tile sono 16x16 o 64x64!

func add_tile_highlight(tile_coords: Vector2i) -> void:
	if targeted_tiles.has(tile_coords):
		targeted_tiles[tile_coords] += 1
	else:
		targeted_tiles[tile_coords] = 1
	queue_redraw() # Richiede a Godot di aggiornare il disegno a schermo

func remove_tile_highlight(tile_coords: Vector2i) -> void:
	if targeted_tiles.has(tile_coords):
		targeted_tiles[tile_coords] -= 1
		if targeted_tiles[tile_coords] <= 0:
			targeted_tiles.erase(tile_coords)
	queue_redraw()

# Questa funzione nativa di Godot disegna forme geometriche a schermo
func _draw() -> void:
	if not tile_map_layer: 
		return
		
	for tile in targeted_tiles.keys():
		# 1. Troviamo il centro del tile rispetto al TileMap
		var local_center = tile_map_layer.map_to_local(tile)
		
		# 2. Lo convertiamo in coordinate globali assolute 
		# (fondamentale se il TileMapLayer non si trova esattamente a 0,0)
		var global_center = tile_map_layer.to_global(local_center)
		
		# 3. Calcoliamo l'angolo in alto a sinistra del rettangolo
		var top_left = global_center - (TILE_SIZE / 2.0)
		var rect = Rect2(top_left, TILE_SIZE)
		
		# Disegna il rettangolo (Colore Verde chiaro, NON riempito, spessore 2.0 pixel)
		draw_rect(rect, Color(0.2, 0.9, 0.2, 0.8), false, 2.0)

# Trova il centro del tile libero adiacente all'albero più vicino all'unità (comprese le diagonali)
func get_best_chopping_position(tree_tile: Vector2i, unit_global_pos: Vector2) -> Vector2:
	var best_pos: Vector2 = Vector2.ZERO
	var min_dist: float = INF
	var found_valid = false
	
	# Le 8 direzioni: Cardinali + Diagonali
	var directions = [
		Vector2i.UP,      # Nord (0, -1)
		Vector2i.DOWN,    # Sud (0, 1)
		Vector2i.LEFT,    # Ovest (-1, 0)
		Vector2i.RIGHT,   # Est (1, 0)
		Vector2i(1, -1),  # Nord-Est
		Vector2i(1, 1),   # Sud-Est
		Vector2i(-1, 1),  # Sud-Ovest
		Vector2i(-1, -1)  # Nord-Ovest
	]
	
	for dir in directions:
		var neighbor_tile = tree_tile + dir
		
		# Controlla che il tile adiacente NON sia un altro albero 
		# (Se hai altri ostacoli, es. acqua/muri, aggiungi qui il controllo)
		if not is_tree(neighbor_tile):
			var neighbor_global_center = get_tile_center_global(neighbor_tile)
			var dist = neighbor_global_center.distance_squared_to(unit_global_pos)
			
			if dist < min_dist:
				min_dist = dist
				best_pos = neighbor_global_center
				found_valid = true
				
	# Se trova un tile libero, restituisce il centro perfetto
	if found_valid:
		return best_pos
		
	# Fallback (se l'albero è completamente circondato, lo manda al centro dell'albero stesso)
	return get_tile_center_global(tree_tile)

# Building placemente
func is_area_buildable(origin_tile: Vector2i, tile_size: Vector2i) -> bool:
	# TODO: Da ripristinare non appena aggiorno TileSet su mappa
	#for x in range(tile_size.x):
		#for y in range(tile_size.y):
			#var cell := origin_tile + Vector2i(x, y)
			#if not is_cell_buildable(cell):
				#return false
	return true

func is_cell_buildable(cell: Vector2i) -> bool:
	var data := tile_map_layer.get_cell_tile_data(cell)
	if data == null:
		return false   # cella vuota = non costruibile
	return data.get_custom_data("is_buildable") == true
