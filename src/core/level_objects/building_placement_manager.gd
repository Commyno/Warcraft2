extends Node2D

@export var tilemap_layer: TileMapLayer
@export var grid_size: float = 32.0
@export var grid_overlay_scene: PackedScene

var grid_overlay_instance: GridOverlay = null
var preview_building: BaseBuilding = null
var building_scene_to_spawn: PackedScene = null
var is_placing: bool = false

var _building_tile_size: Vector2i = Vector2i.ONE
var _action: PlaceBuildingActionData = null
var _units: Array = []

func _ready() -> void:
	add_to_group("placement_manager")
	if tilemap_layer and tilemap_layer.tile_set:
		grid_size = float(tilemap_layer.tile_set.tile_size.x)
	else:
		push_warning("TileMap non assegnato al BuildingPlacementManager!")

func _process(_delta: float) -> void:
	if is_placing and preview_building:
		show_preview_building()

func show_preview_building() -> void:
	var raw_mouse_pos = get_global_mouse_position()
	var origin_tile: Vector2i = GridManager.get_tile_coords(raw_mouse_pos)
	var snapped_pos: Vector2 = GridManager.get_tile_center_global(origin_tile)

	preview_building.global_position = snapped_pos

	if grid_overlay_instance:
		grid_overlay_instance.update_overlay(snapped_pos, true)

	if is_position_valid():
		preview_building.modulate = Color(0.0, 1.0, 0.0, 0.6)
	else:
		preview_building.modulate = Color(1.0, 0.0, 0.0, 0.6)

func confirm() -> void:
	if is_placing and is_position_valid():
		place_building()

func cancel() -> void:
	if is_placing:
		cancel_placement()

# Avvia la modalità di piazzamento
func start_placement(action: PlaceBuildingActionData, units: Array) -> void:
	if is_placing:
		cancel_placement()

	if units.is_empty():
		return
	var owner_player: Player = units[0].player_owner
	if owner_player == null or not action.building_data.is_affordable(owner_player):
		return
	
	_action = action
	_units = units
	building_scene_to_spawn = action.building_data.building_scene
	_building_tile_size = action.building_data.tile_size
	preview_building = building_scene_to_spawn.instantiate() as BaseBuilding

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
	var origin_tile: Vector2i = GridManager.get_tile_coords(preview_building.global_position)
	return GridManager.is_area_buildable(origin_tile, _building_tile_size)

#func place_building() -> void:
	#var final_position = preview_building.global_position
#
	## Istanzia l'edificio reale definitivo
	#var real_building = building_scene_to_spawn.instantiate() as BaseBuilding
	#real_building.global_position = final_position
#
	#get_parent().add_child(real_building)
#
	#real_building.place_under_construction()
	#
	#cancel_placement()	

func place_building() -> void:
	var origin_tile := GridManager.get_tile_coords(preview_building.global_position)
	_action.execute(_units, origin_tile)
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
