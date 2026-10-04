class_name DrainActionData
extends TargetEntityActionData

func _init() -> void:
	super()
	id = "drain"
	title = "Riporta"
	action_type = ActionType.TARGET_ENTITY
	target_mode = ExecutionTargetMode.ALL # Tutti i lavoratori selezionati vanno a raccogliere

func accepts(_entity, _tile, _pos, _units, _player) -> bool:
	if not is_instance_valid(_entity):
		return false
	# Se ha effetivamente risorse da depositare
	if _units.size() > 0:
		var unit : Peasant = _units[0] as Peasant
		if is_instance_valid(unit):
			var gathering_component = unit.get_node_or_null("GatheringComponent")
			if gathering_component:
				return gathering_component.is_valid_dropoff(_entity)
	return false

func _execute_action(_source_entities: Array, _target_data = null) -> void:
	if _source_entities.is_empty():
		return
	if not _target_data is BaseBuilding:
		return

	for worker in _source_entities:
		# Miniera: target è la GoldMine (entità)
		if _target_data != null and _target_data.is_resource_dropoff:
			if worker.has_method("interact_with"):
				worker.interact_with(_target_data)
