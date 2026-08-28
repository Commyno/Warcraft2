extends Node2D

@export var tilemap_layer: TileMapLayer
@export var grid_size: float = 32.0
@export var grid_overlay_scene: PackedScene

var grid_overlay_instance: GridOverlay = null
var preview_building: BaseBuilding = null
var building_scene_to_spawn: PackedScene = null
var is_placing: bool = false

func _ready() -> void:
	if tilemap_layer and tilemap_layer.tile_set:
		grid_size = float(tilemap_layer.tile_set.tile_size.x)
	else:
		push_warning("TileMap non assegnato al BuildingPlacementManager!")

func _process(_delta: float) -> void:
	if is_placing and preview_building:
		show_preview_building()
		

func show_preview_building() -> void:
	# 1. Calcola la posizione del mouse agganciata alla griglia (Grid Snapping)
	var raw_mouse_pos = get_global_mouse_position()
	var snapped_pos = raw_mouse_pos.snapped(Vector2(grid_size, grid_size))
	
	# Aggiorna la posizione dell'anteprima
	preview_building.global_position = snapped_pos
	
	# 2. Aggiorna la griglia visibile attorno all'edificio
	if grid_overlay_instance:
		grid_overlay_instance.update_overlay(snapped_pos, true)
	
	# 3. Controlla le sovrapposizioni e imposta il colore dell'anteprima
	if is_position_valid():
		preview_building.modulate = Color(0.0, 1.0, 0.0, 0.6) # Verde (Posizione Valida)
	else:
		preview_building.modulate = Color(1.0, 0.0, 0.0, 0.6) # Rosso (Posizione Occupata)

func _unhandled_input(event: InputEvent) -> void:
	if not is_placing:
		return
		
	# Conferma Piazzamento (Click Sinistro)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_position_valid():
			place_building()
			
	# Annulla Piazzamento (Click Destro o ESC)
	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or event.is_action_pressed("ui_cancel"):
		cancel_placement()

# Avvia la modalità di piazzamento
func start_placement(building_scene: PackedScene) -> void:
	if is_placing:
		cancel_placement()
		
	building_scene_to_spawn = building_scene
	preview_building = building_scene.instantiate() as BaseBuilding
	
	# 1. Istanzia la griglia dalla PackedScene
	if grid_overlay_scene:
		grid_overlay_instance = grid_overlay_scene.instantiate() as GridOverlay
		grid_overlay_instance.grid_size = grid_size
		get_parent().add_child(grid_overlay_instance) # Aggiunta al mondo di gioco
	
	# Disabilita la fisica dell'edificio reale e attiva l'Area2D per il test
	preview_building.get_node("CollisionShape2D").disabled = true
	preview_building.get_node("NavigationObstacle2D").affect_navigation_mesh = false
	if preview_building.has_node("HealthBar"):
		preview_building.get_node("HealthBar").visible = false
		
	add_child(preview_building)
	is_placing = true

# --- CONTROLLO SOVRAPPOSIZIONI ---
func is_position_valid() -> bool:
	if not preview_building:
		return false
		
	var placement_area = preview_building.get_node_or_null("PlacementArea") as Area2D
	if not placement_area:
		return true # Se non c'è l'area, permette il piazzamento
	
	# Verifica se ci sono corpi fisici o altre aree sovrapposte
	var overlapping_bodies = placement_area.get_overlapping_bodies()
	var overlapping_areas = placement_area.get_overlapping_areas()
	
	# Filtra l'area dell'anteprima stessa se rilevata
	overlapping_areas.erase(placement_area)
	
	# Se trova qualsiasi altro corpo o area dentro laPlacementArea, la posizione non è valida
	if overlapping_bodies.size() > 0 or overlapping_areas.size() > 0:
		return false
		
	return true

func place_building() -> void:
	var final_position = preview_building.global_position

	# Istanzia l'edificio reale definitivo
	var real_building = building_scene_to_spawn.instantiate() as BaseBuilding
	real_building.global_position = final_position

	get_parent().add_child(real_building)

	real_building.place_under_construction()
	
	cancel_placement()	

func cancel_placement() -> void:
	if preview_building:
		preview_building.queue_free()
		preview_building = null
	
	# Rimuove l'istanza della griglia dal mondo
	if grid_overlay_instance:
		grid_overlay_instance.queue_free()
		grid_overlay_instance = null
	
	is_placing = false
	building_scene_to_spawn = null
