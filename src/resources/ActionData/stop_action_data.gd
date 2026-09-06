class_name StopActionData
extends ActionData

func _init() -> void:
	action_type = ActionType.IMMEDIATE
	target_mode = ExecutionTargetMode.ALL

func _execute_action(_source_entities: Array, _target_data = null) -> void:
	for unit in _source_entities:
		if unit.has_method("stop"):
			unit.stop()
