class_name TrainUnitActionData
extends ActionData

@export_group("Unità da addestrare")
@export var resource_data: CostData

func _init() -> void:
	action_type = ActionType.IMMEDIATE
	target_mode = ExecutionTargetMode.ANY

func can_execute(source_entities: Array, player: Player) -> bool:
	if resource_data == null or source_entities.is_empty() or player == null:
		return false
	
	var building = source_entities[0] as BaseBuilding
	if building == null or not building.has_node("TrainingComponent"):
		return false
	
	# 1. Verifica se la coda di produzione dell'edificio è piena
	if building.training_component.is_queue_full():
		return false
	
	# 2. Verifica se il giocatore ha abbastanza risorse -> 0 altrimenti 1, 2 o 3
	# 3. Verifica il limite di cibo (food / farm cap) -> 0 altrimenti 4
	if player.has_enough_resources(resource_data.gold_cost, resource_data.lumber_cost, resource_data.oil_cost, 0) > 0:
		return false
	
	return true

func _execute_action(source_entities: Array, _target_data = null) -> void:
	var building: BaseBuilding = source_entities[0]
	if building == null or resource_data == null:
		return
		
	var player = building.player_owner
	if player == null:
		return
	
	# 1. Scala le risorse per l'unità in produzione
	player.spend_resources(resource_data.gold_cost, resource_data.lumber_cost, resource_data.oil_cost, 0)
	
	# 2. Accoda l'unità nell'edificio di produzione
	if building.training_component:
		building.training_component.enqueue_unit(resource_data)

func has_cost() -> bool:
	return true

# Stringa dei costi già formattata, pronta per il tooltip.
func get_cost_string() -> String:
	var parts: Array[String] = []
	if resource_data.gold_cost > 0: parts.append("Oro: %d" % resource_data.gold_cost)
	if resource_data.lumber_cost > 0: parts.append("Legna: %d" % resource_data.lumber_cost)
	if resource_data.oil_cost > 0:  parts.append("Petrolio: %d" % resource_data.oil_cost)
	if resource_data.food_cost > 0: parts.append("Cibo: %d" % resource_data.food_cost)
	return " | ".join(parts)
