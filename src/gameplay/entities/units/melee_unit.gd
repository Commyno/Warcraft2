class_name MeleeUnit
extends BaseUnit

@onready var attack_component: AttackComponent = $AttackComponent
@onready var defend_component: DefendComponent = $DefendComponent

func _ready() -> void:
	super()
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
