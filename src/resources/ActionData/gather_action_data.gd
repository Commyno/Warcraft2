class_name GatherActionData
extends TargetEntityActionData

func _init() -> void:
	super()
	id = "gather"
	title = "Raccogli"
	action_type = ActionType.TARGET_ENTITY
	target_mode = ExecutionTargetMode.ALL # Tutti i lavoratori selezionati vanno a raccogliere

func accepts(entity, tile, _pos, _units, _player) -> bool:
	# Miniera (entità) oppure albero (tile)
	if entity != null and entity is GoldMine:
		return true
	if GridManager.is_tree(tile):
		return true
	return false

func _execute_action(_source_entities: Array, _target_data = null) -> void:
	if _source_entities.is_empty():
		return

	for worker in _source_entities:
		# Miniera: target è la GoldMine (entità)
		if _target_data is GoldMine:
			if worker.has_method("interact_with"):
				worker.interact_with(_target_data)
		# Albero: target è il tile (Vector2i)
		elif _target_data is Vector2i:
			if worker.has_method("interact_with_tile"):
				worker.interact_with_tile(_target_data)
