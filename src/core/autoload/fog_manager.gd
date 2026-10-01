extends Node

var fog_layer: TileMapLayer = null
var shroud_layer: TileMapLayer = null
var local_player_id: int = -1

var _vision_providers: Array[Node] = [] 
var _currently_visible: Dictionary = {}
var _discovered: Dictionary = {}

# Inserisci il percorso esatto in cui hai salvato il tuo nuovo TileSet della nebbia
var fog_tileset: TileSet = preload("res://data/tilesets/fog_tile_set.tres")

# --- IMPOSTAZIONI TILESET (Modifica questi valori in base al tuo TileSet) ---
const FOG_SOURCE_ID = 0 
const SHROUD_ATLAS = Vector2i(1, 0) # Tile tutto nero per le zone inesplorate
const FOG_TERRAIN_SET = 0           # L'ID del tuo Terrain Set per la nebbia
const FOG_TERRAIN = 0               # L'ID del Terrain (le "ondine") all'interno del Set[cite: 1]

var update_timer: Timer

func _ready() -> void:
	update_timer = Timer.new()
	update_timer.wait_time = 0.2
	update_timer.autostart = false
	update_timer.timeout.connect(_recalculate_vision)
	add_child(update_timer)

func initialize_fog(parent_node: Node2D, ground_layer: TileMapLayer, player_id: int) -> void:
	local_player_id = player_id
	_vision_providers.clear()
	_currently_visible.clear()
	_discovered.clear()
	
	fog_layer = TileMapLayer.new()
	fog_layer.tile_set = fog_tileset 
	fog_layer.z_index = 200
	fog_layer.modulate = Color(1.0, 1.0, 1.0, 0.6) 
	parent_node.add_child(fog_layer)
	
	shroud_layer = TileMapLayer.new()
	shroud_layer.tile_set = fog_tileset 
	shroud_layer.z_index = 201
	parent_node.add_child(shroud_layer)
	
	# 1. Raccogliamo TUTTE le celle della mappa in un array
	var all_cells: Array[Vector2i] = []
	var used_rect = ground_layer.get_used_rect()
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			all_cells.append(Vector2i(x, y))
			
	# 2. Chiediamo al TERRAIN SYSTEM di riempire la mappa (invece di usare set_cell)
	fog_layer.set_cells_terrain_connect(all_cells, FOG_TERRAIN_SET, FOG_TERRAIN)
	shroud_layer.set_cells_terrain_connect(all_cells, FOG_TERRAIN_SET, FOG_TERRAIN)
			
	update_timer.start()

func register_vision_component(component: Node) -> void:
	if not _vision_providers.has(component):
		_vision_providers.append(component)

func unregister_vision_component(component: Node) -> void:
	_vision_providers.erase(component)

func _recalculate_vision() -> void:
	if fog_layer == null or shroud_layer == null: return
	
	# Salviamo la lista delle celle che erano visibili al frame precedente
	var previous_visible = _currently_visible.duplicate()
	_currently_visible.clear()
	
	# 1. Calcola il nuovo raggio visivo
	for provider in _vision_providers:
		var parent = provider.get_parent()
		if parent.player_owner and parent.player_owner.player_id == local_player_id and not parent.is_dead:
			var center_cell = GridManager.get_tile_coords(parent.global_position)
			var sight_range = provider.sight_range if provider.get("sight_range") != null else 4.0
			_add_circle_to_vision(center_cell, sight_range)
			
	# 2. Determina quali celle sono diventate appena visibili e quali sono tornate nell'ombra
	var current_visible_array: Array[Vector2i] = []
	var newly_discovered: Array[Vector2i] = []
	var cells_to_hide: Array[Vector2i] = []
	
	for cell in _currently_visible:
		current_visible_array.append(cell)
		if not _discovered.has(cell):
			_discovered[cell] = true
			newly_discovered.append(cell)
			
	for cell in previous_visible:
		if not _currently_visible.has(cell):
			cells_to_hide.append(cell)

	for cell in cells_to_hide:
		fog_layer.set_cell(cell, FOG_SOURCE_ID, SHROUD_ATLAS)

	# 3. ripristiniamo la nebbia dove non stiamo più guardando
	if not current_visible_array.is_empty():
		fog_layer.set_cells_terrain_connect(current_visible_array, FOG_TERRAIN_SET, -1)
		
	# 4. Buchiamo la nebbia dove stiamo guardando
	if not newly_discovered.is_empty():
		shroud_layer.set_cells_terrain_connect(newly_discovered, FOG_TERRAIN_SET, -1)
		
	# 4. Comunica ai nemici
	get_tree().call_group("enemy_visible_components", "check_visibility_state")

func _add_circle_to_vision(center: Vector2i, radius: int) -> void:
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			# Se il punto è all'interno del raggio
			if (x * x) + (y * y) <= (radius * radius):
				
				# --- CORREZIONE GLITCH TILESET 16 PEZZI ---
				# Evitiamo di inserire le 4 estremità assolute (le punte da 1 tile)
				# per la singola unità in elaborazione.
				if abs(x) == radius and y == 0:
					continue
				if abs(y) == radius and x == 0:
					continue
					
				# Se non è una punta estrema, la aggiungiamo alla visione globale
				_currently_visible[center + Vector2i(x, y)] = true

func is_cell_visible(cell: Vector2i) -> bool:
	return _currently_visible.has(cell)
