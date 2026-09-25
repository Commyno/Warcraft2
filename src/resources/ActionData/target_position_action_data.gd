class_name TargetPositionActionData
extends ActionData

func _init() -> void:
	action_type = ActionType.TARGET_POSITION
	target_mode = ExecutionTargetMode.ALL

func accepts(_entity, _tile, _pos, _units, _player) -> bool:
	return true

func _execute_action(_source_entities: Array, _target_data = null) -> void:
	var position = Vector2.ZERO
	if _target_data is Vector2i:
		position = GridManager.get_tile_center_global(_target_data)
	elif _target_data is Vector2:
		position = _target_data

	if position == Vector2.ZERO:
		push_warning("%s: target_pos non è una posizione valida" % id)
		return

	# Delega interamente il calcolo delle celle e la prenotazione al FormationManager
	FormationManager.move_units_in_formation(_source_entities, position)

	# Hook per i comportamenti specifici (attack-move, patrol...)
	for entity in _source_entities:
		_apply_to_unit(entity, position)

# I figli sovrascrivono questo per aggiungere comportamento oltre al movimento.
func _apply_to_unit(_entity: Node, _target_position: Vector2) -> void:
	pass
