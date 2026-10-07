class_name BuildingTrainingBox
extends VBoxContainer

@export var training_entity_icon: PackedScene = preload("res://src/ui/hud/elements/training_entity_icon.tscn")

@onready var training_icon: TextureRect = $TrainingIconBoxContainer/TrainingIcon
@onready var training_progress_bar: ProgressBar = $MarginContainer/TrainingProgressBar
@onready var queue_list_container: HBoxContainer = $QueueContainer/QueueListContainer

var entity: Node2D
var _progress_percent: float
var training_component: TrainingComponent

func setup(_entity: Node2D) -> void:
	entity = _entity
	if entity == null:
		return
	
	for element in queue_list_container.get_children():
		queue_list_container.remove_child(element)

	training_icon.texture = entity.icon
	
	update()
	update_queue()

	# Connettiamo il signal per gli aggiornamenti sullo stato di avanzamento
	training_component = entity.get_node_or_null("TrainingComponent")
	if training_component:
		if not training_component.progress_updated.is_connected(on_progress_updated):
			training_component.progress_updated.connect(on_progress_updated)
		if not training_component.queue_updated.is_connected(on_queue_updated):
			training_component.queue_updated.connect(on_queue_updated)
		if not training_component.complete_training.is_connected(on_complete_training):
			training_component.complete_training.connect(on_complete_training)

func _on_tree_exited() -> void:
	if entity == null:
		return

	# Disconnettere i signal quando la UI viene rimossa
	if training_component:
		if entity.progress_updated.is_connected(on_progress_updated):
			entity.progress_updated.disconnect(on_progress_updated)

func on_progress_updated(progress_percent: float) -> void:
	_progress_percent = progress_percent
	update()

func on_complete_training(data: UnitData) -> void:
	update_queue()

func on_queue_updated(queue: Array[UnitData]) -> void:
	update_queue()

func update() -> void:
	training_progress_bar.value = _progress_percent

func update_queue() -> void:
	for element in queue_list_container.get_children():
		queue_list_container.remove_child(element)
	for element in training_component.training_queue:
		var traingin_icon = training_entity_icon.instantiate()
		queue_list_container.add_child(traingin_icon)
		traingin_icon.setup(element)
