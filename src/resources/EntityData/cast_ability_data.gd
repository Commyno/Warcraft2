class_name CastAbilityData
extends ActionData

@export_group("Abilità")
@export var ability_data: AbilityData

func _init() -> void:
	action_type = ActionType.IMMEDIATE

func can_execute(source_entities: Array, player: Player) -> bool:
	var caster : CasterUnit = source_entities[0] as CasterUnit if not source_entities.is_empty() else null
	if caster == null or ability_data == null:
		return false

	return ability_data.can_cast(caster, player)

func execute(source_entities: Array, _target_data = null) -> void:
	var caster : CasterUnit = source_entities[0] as CasterUnit if not source_entities.is_empty() else null
	if caster == null or ability_data == null:
		return
	
	# doppia guardia: lo stato può essere cambiato tra can_execute e execute
	var player := _resolve_player(caster)
	if not ability_data.can_cast(caster, player):
		return

	_apply_ability(caster, null)
	ability_data.consume(caster, player)

## Effetto vero e proprio. Delega all'unità o a un sistema di abilità.
func _apply_ability(caster: CasterUnit, target) -> void:
	caster.cast_ability(ability_data, target)

func _resolve_player(caster: CasterUnit) -> Player:
	return caster.owner_player if "owner_player" in caster else null
