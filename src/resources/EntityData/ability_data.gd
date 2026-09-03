class_name AbilityData
extends CostData

enum TargetType { POINT, UNIT, SELF, CORPSE } # Bersaglio a terra, su unità, su se stessi o cadavere

@export var ability_id: String = ""
@export var ability_name: String = ""
@export var icon: Texture2D

@export_group("Target & Effect")
@export var range: float = 200.0
@export var cooldown: float = 1.0
@export var target_type: TargetType = TargetType.POINT
@export var effect_scene: PackedScene # Scena proiettile/VFX (es. Fireball.tscn o BlizzardArea.tscn)


# Tutto ciò che serve per decidere se il caster può lanciare QUESTA abilità.
# Racchiude mana + cooldown in un solo posto.
func can_cast(caster: Node, player: Player) -> bool:
	if caster == null:
		return false
	if caster.has_method("is_on_cooldown") and caster.is_on_cooldown(ability_id):
		return false
	# is_affordable (da CostData) controlla risorse dal player e mana dal caster
	return is_affordable(player, caster)

# Applica le conseguenze del lancio: spende mana/risorse e avvia il cooldown.
func consume(caster: Node, player: Player) -> void:
	pay(player, caster)   # da CostData: scala risorse + mana
	if caster.has_method("start_cooldown"):
		caster.start_cooldown(ability_id, cooldown)
