class_name SummonAbilityData
extends AbilityData

@export var unit_to_spawn: UnitData       # Risorsa dello Scheletro da istanziare
@export var summon_duration: float = 30.0 # Durata a tempo prima che muoia

func can_execute(source_entities: Array, player: Player) -> bool:
	var caster = source_entities[0] if not source_entities.is_empty() else null
	if caster == null:
		return false
	# cooldown attivo → non eseguibile
	if caster.has_method("is_on_cooldown") and caster.is_on_cooldown(ability_id):
		return false
	return is_affordable(player, caster)

func execute(source_entities: Array, target_data = null) -> void:
	var caster : CasterUnit = source_entities[0] as CasterUnit if not source_entities.is_empty() else null
	if caster == null:
		return
	# ... logica dello spell ...
	pay(null, caster)   # spende mana/risorse
	if caster.has_method("start_cooldown"):
		caster.start_cooldown(ability_id, cooldown)
