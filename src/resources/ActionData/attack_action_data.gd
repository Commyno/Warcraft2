class_name AttackActionData
extends TargetEntityActionData

func _init() -> void:
	super()
	id = "attack"
	title = "Attacca"

func _is_valid_target(source_entities: Array, target: Node2D) -> bool:
	if not "player_id" in target:
		return false
	# Bersaglio valido solo se di un player diverso da chi attacca.
	var attacker_id: int = source_entities[0].player_id if not source_entities.is_empty() else -1
	return target.player_id != attacker_id
