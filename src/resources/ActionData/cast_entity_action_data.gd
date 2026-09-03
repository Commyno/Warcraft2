class_name CastEntityAbilityData
extends TargetEntityActionData

@export_group("Abilità")
@export var ability_data: AbilityData

func can_execute(source_entities: Array, player: Player) -> bool:
	var caster : CasterUnit = source_entities[0] as CasterUnit if not source_entities.is_empty() else null
	if caster == null or ability_data == null:
		return false
	return ability_data.can_cast(caster, player)

func execute(source_entities: Array, target_entity = null) -> void:
	if not (target_entity is Node2D):
		return
	var caster : CasterUnit = source_entities[0] as CasterUnit if not source_entities.is_empty() else null
	if caster == null or ability_data == null:
		return
	if not _is_valid_target(source_entities, target_entity):
		return
	var player : Player = (caster.owner_player if "owner_player" in caster else null)
	if not ability_data.can_cast(caster, player):
		return

	caster.cast_ability(ability_data, target_entity)

	ability_data.consume(caster, player)

## Es. Heal valido solo su alleati, Polymorph solo su nemici — override nei figli o via ability_data.
func _is_valid_target(_source_entities: Array, _target: Node2D) -> bool:
	return true
