class_name UpgradeActionData
extends ActionData

@export_group("Unità da addestrare")
@export var upgrade_data: UpgradeData

func _init() -> void:
	action_type = ActionType.IMMEDIATE

func can_execute(_source_entities: Array, player: Player) -> bool:
	if player == null or upgrade_data == null:
		return false
	return player.can_afford_unit(upgrade_data)

func has_cost() -> bool:
	return true

# Stringa dei costi già formattata, pronta per il tooltip.
func get_cost_string() -> String:
	var parts: Array[String] = []
	if upgrade_data.gold_cost > 0: parts.append("Oro: %d" % upgrade_data.gold_cost)
	if upgrade_data.wood_cost > 0: parts.append("Legna: %d" % upgrade_data.wood_cost)
	if upgrade_data.oil_cost > 0:  parts.append("Petrolio: %d" % upgrade_data.oil_cost)
	if upgrade_data.food_cost > 0: parts.append("Cibo: %d" % upgrade_data.food_cost)
	return " | ".join(parts)
