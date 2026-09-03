class_name CasterUnit
extends BaseUnit

@export var abilities: Array[AbilityData] = []

# Mappa: ability_id -> istante (in secondi) in cui l'abilità torna disponibile.
var _cooldowns: Dictionary = {}

## Applica SOLO l'effetto dell'abilità. Mana e cooldown sono già gestiti
## dall'ActionData (can_cast prima, consume dopo). Qui non si paga nulla.
## 'target' è polimorfico: null (self), Vector2 (punto), o BaseUnit (entità).
func cast_ability(ability: AbilityData, target = null) -> void:
	if ability == null:
		return

	# Ricava una posizione utile per gli effetti che ne hanno bisogno.
	var effect_pos: Vector2 = global_position
	if target is Vector2:
		effect_pos = target
	elif target is Node2D:
		effect_pos = target.global_position

	# Evocazione
	if ability is SummonAbilityData:
		_spawn_summon(ability.unit_to_spawn, effect_pos, ability.summon_duration)

	# Proiettile / AoE ad area
	elif ability.effect_scene != null:
		var effect := ability.effect_scene.instantiate()
		get_parent().add_child(effect)
		effect.global_position = effect_pos
		# se il target è un'entità, passala all'effetto (utile per spell mirati)
		if target is BaseUnit and "target_unit" in effect:
			effect.target_unit = target

func _spawn_summon(unit_to_spawn: UnitData, target_position: Vector2, summon_duration: float) -> void:
	pass

# --- COOLDOWN (invariato, va bene così) ---

func start_cooldown(ability_id: String, duration: float) -> void:
	if duration > 0.0:
		_cooldowns[ability_id] = Time.get_ticks_msec() / 1000.0 + duration

func get_cooldown_remaining(ability_id: String) -> float:
	if not _cooldowns.has(ability_id):
		return 0.0
	var remaining: float = _cooldowns[ability_id] - Time.get_ticks_msec() / 1000.0
	return maxf(remaining, 0.0)

func is_on_cooldown(ability_id: String) -> bool:
	return get_cooldown_remaining(ability_id) > 0.0
