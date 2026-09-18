class_name TrainUnitActionData
extends ActionData

@export_group("Unità da addestrare")
@export var unit_data: UnitData

func _init() -> void:
	action_type = ActionType.IMMEDIATE
	target_mode = ExecutionTargetMode.ANY

func can_execute(source_entities: Array, player: Player) -> bool:
	if unit_data == null or source_entities.is_empty() or player == null:
		return false
	
	var building = source_entities[0] as ProductionBuilding
	if building == null:
		return false
	
	# 1. Verifica se la coda di produzione dell'edificio è piena
	if building.is_queue_full():
		return false
	
	# 2. Verifica se il giocatore ha abbastanza risorse -> 0 altrimenti 1, 2 o 3
	# 3. Verifica il limite di cibo (food / farm cap) -> 0 altrimenti 4
	if player.has_enough_resources(unit_data.gold_cost, unit_data.lumber_cost, unit_data.oil_cost, 0) > 0:
		return false
	
	return true

func _execute_action(source_entities: Array, _target_data = null) -> void:
	var building = source_entities[0] as ProductionBuilding
	if building == null or unit_data == null:
		return
		
	var player = building.player_owner
	if player == null:
		return
	
	# 1. Scala le risorse per l'unità in produzione
	player.spend_resources(unit_data.gold_cost, unit_data.lumber_cost, unit_data.oil_cost, 0)
	
	# 2. Accoda l'unità nell'edificio di produzione
	building.enqueue_unit(unit_data)

func has_cost() -> bool:
	return true

# Stringa dei costi già formattata, pronta per il tooltip.
func get_cost_string() -> String:
	var parts: Array[String] = []
	if unit_data.gold_cost > 0: parts.append("Oro: %d" % unit_data.gold_cost)
	if unit_data.lumber_cost > 0: parts.append("Legna: %d" % unit_data.lumber_cost)
	if unit_data.oil_cost > 0:  parts.append("Petrolio: %d" % unit_data.oil_cost)
	if unit_data.food_cost > 0: parts.append("Cibo: %d" % unit_data.food_cost)
	return " | ".join(parts)
