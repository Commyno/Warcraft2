class_name CastPositionAbilityData
extends TargetPositionActionData

@export_group("Abilità")
@export var ability_data: AbilityData

func _init() -> void:
	target_mode = ExecutionTargetMode.ANY 	# Solo il primo mago selezionato effettuerà il cast

func can_execute(source_entities: Array, player: Player) -> bool:
	var caster : CasterUnit = source_entities[0] as CasterUnit if not source_entities.is_empty() else null
	if caster == null or ability_data == null:
		return false
	return ability_data.can_cast(caster, player)

func _execute_action(_source_entities: Array, _target_data = null) -> void:
	if not (_target_data is Vector2):
		return
	var caster : CasterUnit = _source_entities[0] as CasterUnit if not _source_entities.is_empty() else null
	if caster == null or ability_data == null:
		return
	var player : Player = (caster.owner_player if "owner_player" in caster else null)
	if not ability_data.can_cast(caster, player):
		return

	# L'effetto dello spell al punto bersaglio
	caster.cast_ability(ability_data, _target_data)

	ability_data.consume(caster, player)
