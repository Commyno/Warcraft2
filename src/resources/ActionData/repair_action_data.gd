class_name RepairActionData
extends TargetEntityActionData

func _init() -> void:
	super()
	id = "repair"
	title = "Ripara"
	shortcut_key = KEY_R

func _is_valid_target(source_entities: Array, target: Node2D) -> bool:
	# 1. Deve avere un proprietario confrontabile
	if not "player_id" in target:
		return false

	# 2. Bersaglio alleato (stesso player di chi ripara)
	var repairer_id: int = source_entities[0].player_id if not source_entities.is_empty() else -1
	if target.player_id != repairer_id:
		return false

	# 3. Di solito si riparano solo gli EDIFICI (non altre unità)
	if not target is BaseBuilding:
		return false

	# 4. Deve essere effettivamente danneggiato
	if target.current_health >= target.max_health:
		return false

	return true

func _apply_to_unit(unit: Node, target: Node2D) -> void:
	# Repair non è "attacca": serve un comportamento dedicato sull'unità.
	if unit.has_method("start_repair"):
		unit.start_repair(target)
	elif unit.has_method("interact_with"):
		# Fallback: almeno mandalo verso l'edificio finché start_repair non esiste.
		unit.interact_with(target)
