# targeting_manager.gd — Autoload "TargetingManager"
extends Node

var _active: bool = false
var _action: ActionData = null
var _units: Array = []
var _player: Player = null

func _ready() -> void:
	add_to_group("targeting_manager")
	# niente set_process_unhandled_input: non ascoltiamo più l'input direttamente

func begin_targeting(action: ActionData, units: Array, player: Player) -> void:
	if action == null or units.is_empty():
		return
	_action = action
	_units = units
	_player = player
	_active = true
	
	# Build: delega al PlacementManager	
	if action is PlaceBuildingActionData:
		var pm := _get_placement_manager()
		if pm:
			pm.start_placement(action, _units)
		return
	
	_update_cursor(true)

func cancel() -> void:
	_active = false
	_action = null
	_units = []
	_player = null
	_update_cursor(false)

func is_targeting() -> bool:
	return _active

## Chiamato dal SelectionManager quando è in targeting mode.
func handle_input(event: InputEvent) -> void:
	if not _active:
		return

	# Se si è in modalità costruzione
	if _action is PlaceBuildingActionData:
		var pm := _get_placement_manager()
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				pm.confirm()
				if not pm.is_placing:   # piazzato davvero → esci dal targeting
					cancel()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				pm.cancel()
				cancel()   # esci anche dal targeting
		return
	
	# Altrimenti getstisce gli input normalmente
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) \
	or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		cancel()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_resolve_and_execute(event)

func _resolve_and_execute(_event: InputEventMouseButton) -> void:
	var world_pos: Vector2 = _get_world_mouse_position()

	match _action.action_type:
		ActionData.ActionType.TARGET_POSITION:
			_get_selection_manager().show_click_marker(world_pos)
			_action.execute(_units, world_pos)
		ActionData.ActionType.TARGET_ENTITY:
			var target := _pick_entity_at(world_pos)
			if target == null:
				return
			_action.execute(_units, target)
		ActionData.ActionType.TARGET_GRID_TILE:
			var tile: Vector2i = GridManager.get_tile_coords(world_pos)
			_action.execute(_units, tile)

	cancel()

func _get_world_mouse_position() -> Vector2:
	var cam := _get_game_camera()
	if cam == null:
		push_warning("game_camera non trovata nel gruppo!")
		return Vector2.ZERO
	return cam.get_global_mouse_position()

func _get_world_mouse_position_old() -> Vector2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()

func _pick_entity_at(world_pos: Vector2) -> Node2D:
	var space := get_viewport().get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hits := space.intersect_point(query, 1)
	if hits.is_empty():
		return null
	return hits[0].collider as Node2D

func _update_cursor(targeting: bool) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if targeting else Input.CURSOR_ARROW)

func _get_selection_manager() -> Node:
	var m := get_tree().get_nodes_in_group("selection_manager")
	return m[0] if not m.is_empty() else null

func _get_game_camera() -> Camera2D:
	var cams := get_tree().get_nodes_in_group("game_camera")
	if cams.is_empty():
		return null
	return cams[0] as Camera2D

func _get_placement_manager() -> Node:
	var m := get_tree().get_nodes_in_group("placement_manager")
	return m[0] if not m.is_empty() else null
