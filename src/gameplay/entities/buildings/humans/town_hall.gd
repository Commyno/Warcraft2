class_name TownHall
extends ProductionBuilding

# Onready
@onready var drain_component: DrainComponent = $DrainComponent
@onready var training_component: TrainingComponent = $TrainingComponent

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	add_to_group("town_hall")

func setup(data: Resource) -> void:
	super(data)
	
	if drain_component:
		drain_component.setup(data)

func accept_resources(resource: Globals.ResourceType) -> bool:
	if drain_component:
		return drain_component.accept_resources(resource)
	return false
