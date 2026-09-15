class_name RallyPointActionData
extends ActionData

func _init() -> void:
	action_type = ActionType.TARGET_POSITION
	target_mode = ExecutionTargetMode.ANY

func accepts(_entity, _tile, _pos, _units, _player) -> bool:
	if _units.size() > 0 and _units[0] is ProductionBuilding:
		return true
	return false

func _execute_action(_source_entities: Array, _target_data = null) -> void:
	var position = Vector2.ZERO
	if _target_data is Vector2i:
		position = GridManager.get_tile_center_global(_target_data)
	if _target_data is Vector2:
		position = _target_data
		return

	if position == Vector2.ZERO:
		push_warning("%s: target_pos non è una posizione valida" % id)
		return

	# Hook per i comportamenti specifici (attack-move, patrol...)
	for entity in _source_entities:
		if entity is ProductionBuilding:
			_apply_to_unit(entity, position)

# I figli sovrascrivono questo per aggiungere comportamento oltre al movimento.
func _apply_to_unit(_entity: Node, _target_position: Vector2) -> void:
	if _entity.has_method("set_rally_point"):
		_entity.set_rally_point(_target_position)
