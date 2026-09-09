class_name CastEntityAbilityData
extends TargetEntityActionData

@export_group("Abilità")
@export var ability_data: AbilityData

func _init() -> void:
	target_mode = ExecutionTargetMode.ANY 	# Solo il primo mago selezionato effettuerà il cast

func can_execute(_source_entities: Array, player: Player) -> bool:
	var caster : CasterUnit = _source_entities[0] as CasterUnit if not _source_entities.is_empty() else null
	if caster == null or ability_data == null:
		return false
	return ability_data.can_cast(caster, player)

func _execute_action(_source_entities: Array, _target_data = null) -> void:
	if not (_target_data is Node2D):
		return
	var caster : CasterUnit = _source_entities[0] as CasterUnit if not _source_entities.is_empty() else null
	if caster == null or ability_data == null:
		return
	if not _is_valid_target(_source_entities, _target_data):
		return
	var player : Player = (caster.owner_player if "owner_player" in caster else null)
	if not ability_data.can_cast(caster, player):
		return

	caster.cast_ability(ability_data, _target_data)

	ability_data.consume(caster, player)

## Es. Heal valido solo su alleati, Polymorph solo su nemici — override nei figli o via ability_data.
func _is_valid_target(_source_entities: Array, _target: Node2D) -> bool:
	return true
