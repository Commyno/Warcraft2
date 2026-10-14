class_name MeleeUnit
extends BaseUnit

@onready var attack_component: AttackComponent = $AttackComponent
@onready var defend_component: DefendComponent = $DefendComponent

func _ready() -> void:
	super._ready()
	add_to_group("interactable")

	if attack_component:
		# Connette il segnale per l'inizio dell'animazione
		attack_component.attack_started.connect(_on_attack_started)
		attack_component.attack_finished.connect(_on_attack_finished)

func _physics_process(delta: float) -> void:
	super(delta)

#	Check Attack status
	if attack_component != null and current_assignment == AssignmentState.ATTACK:
		attack_component.process_combat(delta)

func setup(data: Resource) -> void:
	super(data)
	self.entity_id = data.id

	if attack_component:
		attack_component.setup(data)
	if defend_component:
		defend_component.setup(data)

func _on_attack_started(target: Node2D) -> void:
	if not state_machine:
		return
	
	# Direzione di movimento basata sulla velocità attuale dell'Avoidance
	var move_dir: Vector2 = movement_component.intended_dir if movement_component else last_facing_dir
	# Fallback se l'avoidance ci rallenta o ferma un secondo
	if move_dir == Vector2.ZERO:
		move_dir = last_facing_dir
	last_facing_dir = move_dir
	
	# Forza il riavvio dell'animazione di attacco dal primo frame.
	# Usare .start() invece di .travel() garantisce che l'animazione 
	# riparta da zero ad ogni singolo colpo (ad ogni fine cooldown).
	unit_state = UnitState.ATTACKING
	# Aggiorna BlendSpace e Stato Attack
	animation_tree.set("parameters/Attack/blend_position", move_dir)
	state_machine.start("Attack")
	animation_state = "Attack"

func _on_attack_finished() -> void:
	clear_assignment()

# --- GESTIONE ANIMAZIONWI ---

func update_animation_parameters(move_velocity: Vector2) -> void:
	var move_dir: Vector2 = move_velocity.normalized()
	if move_dir == Vector2.ZERO: return
	animation_tree.set("parameters/Death/blend_position", move_dir)
	animation_tree.set("parameters/Walk/Walk_Normal/blend_position", move_dir)
	animation_tree.set("parameters/Walk/Walk_Gold/blend_position", move_dir)
	animation_tree.set("parameters/Walk/Walk_Wood/blend_position", move_dir)
	animation_tree.set("parameters/Idle/Idle_Normal/blend_position", move_dir)
	animation_tree.set("parameters/Idle/Idle_Gold/blend_position", move_dir)
	animation_tree.set("parameters/Idle/Idle_Wood/blend_position", move_dir)
	animation_tree.set("parameters/Attack/blend_position", move_dir)

func update_animation() -> void:
	if not animation_tree or not state_machine:
		return
	
	var actual_speed: float = velocity.length()
	# Direzione di movimento basata sulla velocità attuale dell'Avoidance
	var move_dir: Vector2 = movement_component.intended_dir if (movement_component and movement_component.is_moving) else last_facing_dir

	# Fallback se l'avoidance ci rallenta o ferma un secondo
	if move_dir == Vector2.ZERO:
		move_dir = last_facing_dir
	
	update_animation_parameters(move_dir)
	
	if is_dead:
		state_machine.start("Death")
		animation_state = "Death"
		return
		
	# Gestione flip orizzontale
	if move_dir.x < -0.1:
		sprite2d.flip_h = true
	elif move_dir.x > 0.1:
		sprite2d.flip_h = false
		
	animation_state = "Idle"
	match unit_state:
		UnitState.MOVING, UnitState.RETURNING_RESOURCES:
			if actual_speed > 10.0:
				last_facing_dir = move_dir
				animation_state = "Walk"
		UnitState.ATTACKING, UnitState.BUILDING, UnitState.REPARING, UnitState.CHOPPING:
			animation_state = "Attack"
	
	if animation_state != last_animation_state:
		state_machine.travel(animation_state)
		last_animation_state = animation_state
