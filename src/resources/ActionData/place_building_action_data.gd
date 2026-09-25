class_name PlaceBuildingActionData
extends ActionData

@export_group("Edificio da costruire")
@export var building_data: BuildingData

func _init() -> void:
	action_type = ActionType.TARGET_GRID_TILE
	target_mode = ExecutionTargetMode.ANY

func can_execute(_source_entities: Array, player: Player) -> bool:
	if player == null or building_data == null:
		return false
	# Delega l'affordabilità al BuildingData (che conosce i propri costi)
	return building_data.is_affordable(player)

func _execute_action(_source_entities: Array, _target_data = null) -> void:
	if not (_target_data is Vector2i):
		push_warning("%s: target_tile non è un Vector2i" % id)
		return

	if building_data == null or building_data.scene_path.is_empty():
		push_warning("%s: building_data o scena mancante" % id)
		return
	
	if _source_entities.size() == 0: # is_empty():˙
		return
	
	var builder = _source_entities[0]
	var owner_player: Player = builder.player_owner   # il proprietario = quello del contadino

	if owner_player == null or not building_data.is_affordable(owner_player):
		return
	building_data.pay(owner_player)
	#owner_player.spend_resources(
		#building_data.gold_cost, building_data.lumber_cost,
		#building_data.oil_cost, building_data.food_cost
	#)
	
	var position : Vector2i = _target_data as Vector2i
	var building = SpawnManager.spawn_building(building_data, position, true, owner_player)

	# Manda il primo contadino selezionato a costruire.
	#for unit in source_entities:   # Sostituire poi builder con unit
	if builder != null:
		if builder.has_method("assign_build_task"):
			builder.assign_build_task(building)


func get_cost_string() -> String:
	if building_data == null:
		return ""
	var parts: Array[String] = []
	if building_data.gold_cost > 0: parts.append("Oro: %d" % building_data.gold_cost)
	if building_data.lumber_cost > 0: parts.append("Legna: %d" % building_data.lumber_cost)
	if building_data.oil_cost > 0:  parts.append("Petrolio: %d" % building_data.oil_cost)
	if building_data.food_cost > 0: parts.append("Cibo: %d" % building_data.food_cost)
	return " | ".join(parts)
