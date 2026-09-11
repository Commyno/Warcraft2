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

func resolve_smart_command(world_pos: Vector2, actions: Array, units: Array, player: Player) -> void:
	var entity: Node2D = _get_object_under_mouse(world_pos)
	var tile: Vector2i = GridManager.get_tile_coords(world_pos)
	
	for action in actions:
		if action.accepts(entity, tile, world_pos, units, player):
			
			# --- LA REGOLA D'ORO: Ordine del giocatore ---
			for unit in units:
				if unit.has_method("clear_assignment"):
					unit.clear_assignment()
					
			action.execute(units, entity if entity != null else tile)
			return

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

	# --- LA REGOLA D'ORO: Ordine del giocatore ---
	for unit in _units:
		if unit.has_method("clear_assignment"):
			unit.clear_assignment()

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

func _get_object_under_mouse(pos: Vector2) -> Node2D:
	var space_state = get_viewport().get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = true  # Se la miniera è un'Area2D
	query.collide_with_bodies = true # Se la miniera è uno StaticBody2D/RigidBody2D
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var collider = result.collider
		# Supponiamo che gli edifici o risorse siano in un gruppo specifico o ereditino da una classe
		if collider.is_in_group("interactable") or collider is BaseBuilding:
			return collider
			
	return null

func _update_cursor(targeting: bool) -> void:
	if targeting and _action != null and _action.targeting_cursor != null:
		Input.set_custom_mouse_cursor(_action.targeting_cursor, Input.CURSOR_ARROW, _action.cursor_hotspot)
	else:
		Input.set_custom_mouse_cursor(null)

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
