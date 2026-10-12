class_name AttackComponent
extends Node

const ATTACK_ACTION_DATA = preload("uid://moq724rjihwe")
const STOP_ACTION_DATA = preload("uid://bexvmhf4682mu")

# --- SEGNALI ---
signal attack_started(target: Node2D)
signal target_out_of_range(target: Node2D)
signal target_died()
signal attack_finished() # Usato per avvisare l'unità di resettare l'incarico (tornare IDLE)

# --- STATISTICHE DI ATTACCO ---
@export var basic_damage: int = 6
@export var piercing_damage: int = 3        # Danno perforante (ignora l'Armor nemica)
@export var damage_dice_sides: int = 4      # Danno finale: basic_damage + randi_range(1, dice_sides)
@export var attack_range: float = 0.0
@export var attack_cooldown: float = 1.35
@export var damage_type: Globals.DamageType = Globals.DamageType.NORMAL

# --- TIPOLOGIE DI ATTACCO ---
@export var can_attack_air: bool = false
@export var can_attack_ground: bool = true

# --- ARMI A DISTANZA ---
@export var projectile_scene: PackedScene = null

# --- STATO INTERNO ---
var current_target: Node2D = null
var is_on_cooldown: bool = false
var cooldown_timer: Timer
var attack_distance: float


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Creiamo il timer del cooldown dinamicamente per non doverlo aggiungere a mano nell'editor
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = attack_cooldown
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	add_child(cooldown_timer)

# Controllo di sicurezza: Una torre potrebbe non avere questo array, ma un fante sì
	if "available_actions" in get_parent():
		# Imposto le azioni relative al Component
		get_parent().available_actions.resize(9)
		get_parent().available_actions[1] = ATTACK_ACTION_DATA
		get_parent().available_actions[2] = STOP_ACTION_DATA

func setup(data: Resource) -> void:
	basic_damage = data.basic_damage
	piercing_damage = data.piercing_damage
	#damage_dice_sides = 4
	attack_range = data.attack_range
	attack_distance = attack_range * GridManager.get_tile_size().x
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
	return distance <= attack_distance

func can_attack(target: Node2D) -> bool:
	if not is_instance_valid(target) and not target.is_dead:
		return false
	if is_on_cooldown:
		return false
	# Qui potresti aggiungere controlli se il target è volante e noi possiamo attaccare in aria
	return true

# --- ESECUZIONE ATTACCO ---

# Innesco chiamato dall'AttackActionData
func set_attack_target(target: Node2D) -> void:
	current_target = target

# Da chiamare nel _physics_process della BaseUnit quando current_assignment == ATTACK
func process_combat(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target) or ("is_dead" in current_target and current_target.is_dead):
		current_target = null
		target_died.emit()
		attack_finished.emit() # Avvisa la BaseUnit di fare clear_assignment()
		return
		
	evaluate_combat_state()

# Il vero e proprio "Cervello" del combattimento
func evaluate_combat_state() -> void:
	var parent_entity = get_parent()
	
	if not is_in_range(current_target):
		# IL BERSAGLIO È LONTANO
		target_out_of_range.emit(current_target)
		
		# Duck Typing: Se può muoversi (Fante), insegue!
		var move_comp: MovementComponent = parent_entity.get_node("MovementComponent")
		if move_comp != null:
			# <-- FIX: Evitiamo di ricalcolare il percorso ad ogni singolo frame!
			# Lo ricalcoliamo solo se non ci stiamo muovendo, o se il bersaglio si è allontanato di oltre un tile (32px)
			if not move_comp.is_moving or move_comp.final_target_global.distance_to(current_target.global_position) > GridManager.get_tile_size().x:
				if "unit_state" in parent_entity:
					parent_entity.unit_state = BaseUnit.UnitState.MOVING
					
				move_comp.move_to(current_target.global_position)
			
		# Se NON può muoversi (Torre), aspetta e basta.
		else:
			pass 
			
	else:
		# IL BERSAGLIO È A TIRO
		
		# Se stava inseguendo, inchioda
		if parent_entity.has_node("MovementComponent"):
			var move_comp = parent_entity.get_node("MovementComponent")
			if move_comp.is_moving:
				move_comp.stop_movement()
				
		if "unit_state" in parent_entity:
			parent_entity.unit_state = BaseUnit.UnitState.ATTACKING
			
		if "last_facing_dir" in parent_entity:
			parent_entity.last_facing_dir = (current_target.global_position - parent_entity.global_position).normalized()
			
		# Se non siamo in ricarica, colpiamo!
		if can_attack(current_target):
			is_on_cooldown = true
			cooldown_timer.start()
			
			# Questo segnale ordina alla BaseUnit di far partire l'AnimationTree 
			# con lo stato "Attack".
			attack_started.emit(current_target)

# Questa funzione DEVE essere chiamata dall'AnimationPlayer (tramite Call Method Track)
# nel momento esatto in cui la spada colpisce o la freccia parte.
func perform_strike() -> void:
	if not is_instance_valid(current_target) or get_parent().is_dead:
		return
		
	var final_damage = get_calculated_damage()

	# SE ABBIAMO UN PROIETTILE, SIAMO UNITÀ RANGED (O TORRI)
	if projectile_scene != null:
		var arrow = projectile_scene.instantiate()
		
		# Aggiungiamo la freccia al mondo principale (non all'arciere, altrimenti si muoverebbe con lui)
		get_tree().current_scene.add_child(arrow)
		
		# Facciamo partire la freccia dalla posizione dell'unità
		arrow.global_position = get_parent().global_position
		
		# Inizializziamo il proiettile passandogli il bersaglio e le statistiche calcolate
		arrow.setup(current_target, final_damage, piercing_damage, damage_type)

	# SE NON ABBIAMO IL PROIETTILE, SIAMO UNITÀ MELEE
	else:
		if current_target.has_method("take_damage"):
			current_target.take_damage(final_damage, piercing_damage, damage_type)
		else:
			current_target = null
			target_died.emit()
			attack_finished.emit()

func get_calculated_damage() -> int:
	var roll = randi_range(1, damage_dice_sides) if damage_dice_sides > 0 else 0
	return basic_damage + roll

func _on_cooldown_finished() -> void:
	is_on_cooldown = false

# Utility aggiornata per cercare il DefendComponent
func _get_defend_component(target: Node2D) -> Node:
	return target.get_node_or_null("DefendComponent")

# Utility per trovare l'HealthComponent del bersaglio, indipendentemente da dove si trova
func _get_health_component(target: Node2D) -> Node:
	# Cerca un nodo figlio chiamato specificamente "HealthComponent"
	return target.get_node_or_null("HealthComponent")
