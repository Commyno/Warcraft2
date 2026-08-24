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
