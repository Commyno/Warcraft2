class_name CostData
extends Resource

@export_group("Costo")
@export var gold_cost: int = 0
@export var wood_cost: int = 0
@export var oil_cost: int = 0
@export var food_cost: int = 0

@export_group("Costo Mana")
@export var mana_cost: int = 0

func has_resource_cost() -> bool:
	return gold_cost > 0 or wood_cost > 0 or oil_cost > 0 or food_cost > 0

func has_mana_cost() -> bool:
	return mana_cost > 0

## Affordabilità completa: risorse dal player, mana dalla fonte (l'unità che lancia).
## 'source' può essere null per le azioni che non consumano mana.
func is_affordable(player: Player, source = null) -> bool:
	# 1. Risorse globali del player
	if has_resource_cost():
		if player == null or not player.can_afford(gold_cost, wood_cost, oil_cost, food_cost):
			return false

	# 2. Mana dell'unità sorgente
	if has_mana_cost():
		if source == null or not ("current_mana" in source):
			return false
		if source.current_mana < mana_cost:
			return false

	return true

func pay(player: Player, source = null) -> void:
	if has_resource_cost() and player != null:
		player.spend_resources(gold_cost, wood_cost, oil_cost, food_cost)
	if has_mana_cost() and source != null and "current_mana" in source:
		source.current_mana -= mana_cost

## Stringa dei costi pronta per i tooltip — un solo posto, riusata da tutti.
func get_cost_string() -> String:
	var parts: Array[String] = []
	if gold_cost > 0: parts.append("Oro: %d" % gold_cost)
	if wood_cost > 0: parts.append("Legna: %d" % wood_cost)
	if oil_cost > 0:  parts.append("Petrolio: %d" % oil_cost)
	if food_cost > 0: parts.append("Cibo: %d" % food_cost)
	if mana_cost > 0: parts.append("Mana: %d" % mana_cost)
	return " | ".join(parts)
