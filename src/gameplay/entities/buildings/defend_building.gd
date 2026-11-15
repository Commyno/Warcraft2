class_name DefendBuilding
extends BaseBuilding

# --- COMPONENTS ---
@onready var defend_component: DefendComponent = get_node_or_null("DefendComponent")

func _ready() -> void:
	super()
	add_to_group("interactable")

func setup(data: Resource) -> void:
	super(data)

	# Components
	if defend_component:
		defend_component.setup(data)

func complete_construction() -> void:
	var builders_to_release = active_builders.duplicate()
	active_builders.clear()
	for builder in builders_to_release:
		if is_instance_valid(builder):
			builder.clear_assignment()
	
	player_owner.register_building_completed(entity_id, food_provided)
	
	super()
