class_name TargetEntityActionData
extends ActionData

func _init() -> void:
	action_type = ActionType.TARGET_ENTITY
	target_mode = ExecutionTargetMode.ALL

func accepts(entity, _tile, _pos, units, _player) -> bool:
	return entity != null and _is_valid_target(units, entity)

func _execute_action(_source_entities: Array, _target_data = null) -> void:
	if not (_target_data is Node2D):
		push_warning("%s: target_entity non valido" % id)
		return

	if not _is_valid_target(_source_entities, _target_data):
		return

	for entity in _source_entities:
		_apply_to_unit(entity, _target_data)

# I figli sovrascrivono questo per aggiungere comportamento oltre al movimento.
func _apply_to_unit(_entity: Node, _target_position: Vector2) -> void:
	if _entity.has_method("interact_with"):
		_entity.interact_with(_target_position)

## I figli restringono i bersagli ammessi (nemico per Attack, alleato danneggiato per Repair...).
func _is_valid_target(_source_entities: Array, _target: Node2D) -> bool:
	return true
