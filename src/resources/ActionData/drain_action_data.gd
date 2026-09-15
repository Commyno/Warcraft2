class_name DrainActionData
extends TargetEntityActionData

func _init() -> void:
	super()
	id = "drain"
	title = "Riporta"
	action_type = ActionType.TARGET_ENTITY
	target_mode = ExecutionTargetMode.ALL # Tutti i lavoratori selezionati vanno a raccogliere

func accepts(_entity, _tile, _pos, _units, _player) -> bool:
	# Se ha effetivamente risorse da depositare
	if _units.size() > 0:
		var unit : Peasant = _units[0] as Peasant
		if is_instance_valid(unit) and is_instance_valid(_entity):
			return unit.is_valid_dropoff(_entity)
	return false

func _execute_action(_source_entities: Array, _target_data = null) -> void:
	if _source_entities.is_empty():
		return

	for worker in _source_entities:
		# Miniera: target è la GoldMine (entità)
		if _target_data != null:
			if _target_data.is_in_group("town_hall") or _target_data.is_in_group("lumber_mill"):
				if worker.has_method("interact_with"):
					worker.interact_with(_target_data)
