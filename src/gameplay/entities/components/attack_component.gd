class_name AttackComponent
extends Node

const ATTACK_ACTION_DATA = preload("uid://moq724rjihwe")
const STOP_ACTION_DATA = preload("uid://bexvmhf4682mu")

# --- SEGNALI ---
signal attack_started(target: Node2D)
signal target_out_of_range(target: Node2D)
signal target_died()

# --- STATISTICHE DI ATTACCO ---
@export var basic_damage: int = 6
@export var piercing_damage: int = 3        # Danno perforante (ignora l'Armor nemica)
@export var damage_dice_sides: int = 4      # Danno finale: basic_damage + randi_range(1, dice_sides)
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.35
@export var damage_type: Globals.DamageType = Globals.DamageType.NORMAL

@export var can_attack_air: bool = false
@export var can_attack_ground: bool = true

# --- STATO INTERNO ---
var current_target: Node2D = null
var is_on_cooldown: bool = false
var cooldown_timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Creiamo il timer del cooldown dinamicamente per non doverlo aggiungere a mano nell'editor
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = attack_cooldown
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	add_child(cooldown_timer)

	# Imposto le azioni relative al Component
	get_parent().available_actions.resize(9)
	get_parent().available_actions[1] = ATTACK_ACTION_DATA
	get_parent().available_actions[2] = STOP_ACTION_DATA

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# TODO: Gestione cooldown
	pass

func setup(data: Resource) -> void:
	basic_damage = data.basic_damage
	piercing_damage = data.piercing_damage
	#damage_dice_sides = 4
	attack_range = data.attack_range
	attack_cooldown =data.attack_cooldown
	damage_type = data.damage_type
	cooldown_timer.wait_time = attack_cooldown
	can_attack_air = data.can_attack_air
	can_attack_ground = data.can_attack_ground

# --- CONTROLLI LOGICI ---

func is_in_range(target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false
	# Usiamo il parent (l'unità vera e propria) per calcolare la distanza
	var parent = get_parent() as Node2D
	var distance = parent.global_position.distance_to(target.global_position)
	return distance <= attack_range

func can_attack(target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false
	if is_on_cooldown:
		return false
	# Qui potresti aggiungere controlli se il target è volante e noi possiamo attaccare in aria
	return true

# --- ESECUZIONE ATTACCO ---

# Chiamato ogni frame o dal controller dell'unità quando l'incarico è ATTACK
func process_attack(target: Node2D) -> void:
	if not is_instance_valid(target):
		current_target = null
		target_died.emit()
		return
		
	current_target = target
	
	if not is_in_range(current_target):
		target_out_of_range.emit(current_target)
		return
		
	if can_attack(current_target):
		# Iniziamo l'attacco!
		is_on_cooldown = true
		cooldown_timer.start()
		attack_started.emit(current_target)
		# ATTENZIONE: Non sarà inflitto il danno qui! Ma sarà inflitto tramite animazione

# Questa funzione DEVE essere chiamata dall'AnimationPlayer (tramite Call Method Track)
# nel momento esatto in cui la spada colpisce o la freccia parte.
func perform_strike() -> void:
	if not is_instance_valid(current_target):
		return
		
	# Controlliamo se il bersaglio ha un HealthComponent
	var health_comp = _get_health_component(current_target)
	
	if health_comp != null and not health_comp.is_dead:
		var final_damage = get_calculated_damage()
		health_comp.take_damage(final_damage, damage_type)
	else:
		current_target = null
		target_died.emit()

func get_calculated_damage() -> int:
	var roll = randi_range(1, damage_dice_sides) if damage_dice_sides > 0 else 0
	return basic_damage + roll

func _on_cooldown_finished() -> void:
	is_on_cooldown = false

# Utility per trovare l'HealthComponent del bersaglio, indipendentemente da dove si trova
func _get_health_component(target: Node2D) -> Node:
	# Cerca un nodo figlio chiamato specificamente "HealthComponent"
	var comp = target.get_node_or_null("HealthComponent")
	if comp != null:
		return comp
	# Se la struttura è diversa, puoi fare un check alternativo
	return null

# Calcolo del danno inflitto (con variazione causale)
#func get_calculated_damage() -> int:
	#var roll = randi_range(1, damage_dice_sides) if damage_dice_sides > 0 else 0
	#return basic_damage + roll
