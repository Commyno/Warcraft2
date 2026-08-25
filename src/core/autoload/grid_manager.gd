extends Node

# Riferimento al TileMapLayer principale della mappa di gioco
var tile_map_layer: TileMapLayer = null

# Dizionario delle prenotazioni: Chiave = Vector2i (coordinate tile), Valore = Node2D (unità)
var tile_reservations: Dictionary = {}

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

func get_global_from_tile(tile_coords: Vector2i) -> Vector2:
	if not tile_map_layer:
		return Vector2.ZERO
	var local_pos = tile_map_layer.map_to_local(tile_coords)
	return tile_map_layer.to_global(local_pos)

func snap_to_tile(global_pos: Vector2) -> Vector2:
	if not tile_map_layer:
		return global_pos
	var coords = get_tile_coords(global_pos)
	return get_global_from_tile(coords)

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
func get_available_destination(target_global_pos: Vector2, unit: Node2D) -> Vector2:
	if not tile_map_layer:
		return target_global_pos

	var target_tile = get_tile_coords(target_global_pos)

	# Se il tile di destinazione è libero o già di proprietà di questa unità, usalo
	if not tile_reservations.has(target_tile) or tile_reservations[target_tile] == unit:
		return get_global_from_tile(target_tile)

	# PRELAZIONE: Se il tile è occupato, cerchiamo un tile libero a spirale/adiacente (raggio 1 e 2)
	# partendo da quello desiderato e allontanandoci verso l'unità
	for radius in range(1, 4):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var candidate_tile = target_tile + Vector2i(x, y)
				if not tile_reservations.has(candidate_tile):
					return get_global_from_tile(candidate_tile)

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
		var global_pos = get_global_from_tile(tile)
		
		# Sfruttiamo la tua funzione esistente per controllare se la destinazione è calpestabile
		var safe_pos = get_available_destination(global_pos, unit)
		
		# Se safe_pos è uguale al tile che stiamo testando, significa che è perfettamente libero!
		# (Adatta questo if se la tua funzione is_tile_walkable restituisce un booleano invece del Vector2)
		if safe_pos == global_pos:
			return global_pos
			
	# 6. Fallback di emergenza: se l'edificio è circondato da unità al 100%, 
	# lo facciamo spawnare forzatamente nel punto ideale che avevamo calcolato
	return get_global_from_tile(perimeter_tiles[0])
