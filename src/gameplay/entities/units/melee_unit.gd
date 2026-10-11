class_name MeleeUnit
extends BaseUnit

@onready var attack_component: AttackComponent = $AttackComponent
@onready var defend_component: DefendComponent = $DefendComponent

func _ready() -> void:
	super._ready()
	add_to_group("interactable")

func _physics_process(delta: float) -> void:
#	Check Attack status
	if unit_state == UnitState.ATTACKING and attack_component != null:
		attack_component.process_combat(delta)

	
func setup(data: Resource) -> void:
	super(data)
	self.entity_id = data.id

	if attack_component:
		attack_component.setup(data)
	if defend_component:
		defend_component.setup(data)
