class_name TrainUnitActionData
extends ActionData

@export_group("Unità da addestrare")
@export var unit_data: UnitData

func _init() -> void:
	action_type = ActionType.IMMEDIATE

func can_execute(_source_entities: Array, player: Player) -> bool:
	if player == null or unit_data == null:
		return false
	return player.can_afford_unit(unit_data)

func has_cost() -> bool:
	return true

# Stringa dei costi già formattata, pronta per il tooltip.
func get_cost_string() -> String:
	var parts: Array[String] = []
	if unit_data.gold_cost > 0: parts.append("Oro: %d" % unit_data.gold_cost)
	if unit_data.wood_cost > 0: parts.append("Legna: %d" % unit_data.wood_cost)
	if unit_data.oil_cost > 0:  parts.append("Petrolio: %d" % unit_data.oil_cost)
	if unit_data.food_cost > 0: parts.append("Cibo: %d" % unit_data.food_cost)
	return " | ".join(parts)
