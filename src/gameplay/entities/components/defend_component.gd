class_name DefendComponent
extends Node

# --- SEGNALI ---
signal target_died()

# --- STATISTICHE DI ATTACCO ---
@export var basic_armor: float = 2.0
@export var armor_type: Globals.ArmorType = Globals.ArmorType.MEDIUM

# --- STATO INTERNO ---
var current_target: Node2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# TODO: Gestione cooldown
	pass

func setup(data: Resource) -> void:
	basic_armor = data.basic_armor
	armor_type = data.armor_type

# --- CONTROLLI LOGICI ---

# Ricezione del danno con riduzione tramite Armatura
func take_damage(amount: float, source_damage_type: Globals.DamageType = Globals.DamageType.NORMAL) -> void:
	if get_parent().is_dead:
		return # Non può subire danni se è già morta
		
	var type_multiplier = _get_damage_multiplier(source_damage_type, armor_type)
	var damage_after_type = amount * type_multiplier
	
	# Formula di riduzione armatura classica di WC3: (basic_armor * 0.06) / (1 + 0.06 * basic_armor)
	var armor_reduction = 1.0
	if basic_armor >= 0:
		armor_reduction = 1.0 - ((basic_armor * 0.06) / (1.0 + 0.06 * basic_armor))
	else:
		armor_reduction = 2.0 - pow(0.94, -basic_armor) # Armatura negativa aumenta il danno
		
	var final_damage = max(1.0, damage_after_type * armor_reduction)
	if get_parent().health_component:
		get_parent().health_component.damage(final_damage)
		print(name, " ha ricevuto danno ",  amount, "  subendone ", final_damage, " ! Vita attuale: ", get_parent().health_component.health)

# Utility per trovare l'HealthComponent del bersaglio, indipendentemente da dove si trova
func _get_health_component(target: Node2D) -> Node:
	# Cerca un nodo figlio chiamato specificamente "HealthComponent"
	var comp = target.get_node_or_null("HealthComponent")
	if comp != null:
		return comp
	# Se la struttura è diversa, puoi fare un check alternativo
	return null

# Matrice dei moltiplicatori tra Tipi Danno / Tipi Armatura
func _get_damage_multiplier(dmg_t: Globals.DamageType, arm_t: Globals.ArmorType) -> float:
	match dmg_t:
		Globals.DamageType.PIERCING:
			if arm_t == Globals.ArmorType.LIGHT: return 2.0  # Fanti leggeri / Volanti
			if arm_t == Globals.ArmorType.HEAVY: return 1.0
			if arm_t == Globals.ArmorType.FORTIFIED: return 0.35 # Edifici
		Globals.DamageType.SIEGE:
			if arm_t == Globals.ArmorType.FORTIFIED: return 1.5 # Edifici
			if arm_t == Globals.ArmorType.MEDIUM: return 0.5
		Globals.DamageType.NORMAL:
			if arm_t == Globals.ArmorType.MEDIUM: return 1.5
			if arm_t == Globals.ArmorType.FORTIFIED: return 0.7
	return 1.0 # Valore di default se non ci sono interazioni particolari

# Calcolo del danno inflitto (con variazione causale)
#func _get_calculated_damage() -> int:
	#var roll = randi_range(1, damage_dice_sides) if damage_dice_sides > 0 else 0
	#return basic_damage + roll
