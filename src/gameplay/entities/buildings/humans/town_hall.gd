class_name TownHall
extends ProductionBuilding

# Onready
@onready var drain_component: DrainComponent = $DrainComponent
@onready var training_component: TrainingComponent = $TrainingComponent

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	add_to_group("town_hall")
	if training_component:
		if not training_component.complete_training.is_connected(_on_complete_training):
			training_component.complete_training.connect(_on_complete_training)


func _on_tree_exited() -> void:
	if training_component:
		if training_component.complete_training.is_connected(_on_complete_training):
			training_component.complete_training.disconnect(_on_complete_training)

func setup(data: Resource) -> void:
	super(data)
	
	if drain_component:
		drain_component.setup(data)

func accept_resources(resource: Globals.ResourceType) -> bool:
	if drain_component:
		return drain_component.accept_resources(resource)
	return false

# --- REAZIONI AI SEGNALI DEL COMPONENTE ---

func _on_complete_training(data: UnitData) -> void:
	SpawnManager.spawn_unit_from_building(data,self, player_owner)
