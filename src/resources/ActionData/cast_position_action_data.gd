class_name CastPositionAbilityData
extends TargetPositionActionData

@export_group("Abilità")
@export var ability_data: AbilityData

func can_execute(source_entities: Array, player: Player) -> bool:
	var caster : CasterUnit = source_entities[0] as CasterUnit if not source_entities.is_empty() else null
	if caster == null or ability_data == null:
		return false
	return ability_data.can_cast(caster, player)

func execute(source_entities: Array, target_pos = null) -> void:
	if not (target_pos is Vector2):
		return
	var caster : CasterUnit = source_entities[0] as CasterUnit if not source_entities.is_empty() else null
	if caster == null or ability_data == null:
		return
	var player : Player = (caster.owner_player if "owner_player" in caster else null)
	if not ability_data.can_cast(caster, player):
		return

	# L'effetto dello spell al punto bersaglio
	caster.cast_ability(ability_data, target_pos)

	ability_data.consume(caster, player)
