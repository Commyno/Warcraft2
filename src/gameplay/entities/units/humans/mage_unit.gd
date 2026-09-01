extends CharacterBody2D

# In Mage / Spellcaster Unit
@export var abilities: Array[AbilityData] = []
var current_mana: int = 255

func cast_ability(ability: AbilityData, target_position: Vector2, target_unit: BaseUnit = null) -> bool:
	if current_mana < ability.mana_cost:
		return false
		
	current_mana -= ability.mana_cost
	
	# Se è un'evocazione:
	if ability is SummonAbilityData:
		_spawn_summon(ability.unit_to_spawn, target_position, ability.summon_duration)
	# Se è un proiettile / AoE ad area:
	elif ability.effect_scene != null:
		var effect = ability.effect_scene.instantiate()
		get_parent().add_child(effect)
		effect.global_position = target_position
		
	return true

func _spawn_summon(unit_to_spawn: UnitData, target_position: Vector2, summon_duration: float) -> void:
	pass
