class_name EntityBox
extends VBoxContainer

# BuildingInfo
@onready var portrait: TextureRect = $EntityInfo/ImageVBoxContainer/Portrait
@onready var health_progress_bar: ProgressBar = $EntityInfo/ImageVBoxContainer/HealthProgressBar
@onready var health_label: Label = $EntityInfo/ImageVBoxContainer/HealthLabel

@onready var name_label: Label = $EntityInfo/NameVBoxContainer/NameLabel
@onready var livello: Label = $EntityInfo/NameVBoxContainer/Livello

# BuildingTrainingBox
@onready var entity_training_box: BuildingTrainingBox = $EntityTrainingBox

# BuildingStatsBox
@onready var entity_stats_box: EntityStatsBox = $EntityStatsBox

# ProductionStatsBox
@onready var entity_production_box: VBoxContainer = $EntityProductionBox

# BuildingConstrucionBox
@onready var entity_construcion_box: MarginContainer = $EntityConstrucionBox
@onready var build_progress_bar: ProgressBar = $EntityConstrucionBox/BuildProgressBar

# ResourceBox
@onready var resource_stats_box: ResourceStatsBox = $ResourceStatsBox

var entity: Node2D

func _ready() -> void:
	entity_construcion_box.hide()
	entity_training_box.hide()
	entity_production_box.hide()
	entity_stats_box.hide()
	resource_stats_box.hide()

func setup(_entity: Node2D) -> void:
	entity = _entity
	if entity == null:
		return

	# Nascondi tutto
	entity_construcion_box.hide()
	entity_training_box.hide()
	entity_production_box.hide()
	entity_stats_box.hide()
	resource_stats_box.hide()

	if entity is ResourceBuilding:
		resource_stats_box.show()
		resource_stats_box.setup(entity)

	elif entity is BaseBuilding:

		if entity.is_under_construction:
			entity_construcion_box.show()
			build_progress_bar.value = 0
		
		elif entity.has_node("TrainingComponent"):
			var training_component = entity.training_component
			if training_component.is_training:
				entity_training_box.show()
				entity_training_box.setup(entity)

			# Connettiamo il signal per gli aggiornamenti sulla lista di produzione
			if not training_component.queue_updated.is_connected(on_queue_updated):
				training_component.queue_updated.connect(on_queue_updated)

		elif entity.is_resource_dropoff:
			entity_production_box.show()
			entity_production_box.setup(entity)

		else:
			entity_stats_box.show()
			entity_stats_box.setup(entity)

	elif entity is BaseUnit:
		entity_stats_box.show()
		entity_stats_box.setup(entity)
	
	update()
	
	# Connettiamo il signal per gli aggiornamenti futuri delle risorse
	if entity and entity.health_component:
		if not entity.health_component.health_changed.is_connected(on_health_changed):
			entity.health_component.health_changed.connect(on_health_changed)

func _on_tree_exited() -> void:
	# Disconnettere i signal quando la UI viene rimossa
	if entity and entity.health_component:
		if entity.health_component.health_changed.is_connected(on_health_changed):
			entity.health_component.health_changed.disconnect(on_health_changed)
	if entity and entity is ProductionBuilding:
		if entity.queue_updated.is_connected(on_queue_updated):
			entity.queue_updated.disconnect(on_queue_updated)

func on_health_changed(new_health: int, max_health: int) -> void:
	update()

func on_queue_updated(queue: Array[UnitData]) -> void:
	setup(entity)

func on_resources_changed(new_resources: int, max_resources: int) -> void:
	update()

func on_data_changed() -> void:
	update()

func update() -> void:
	if entity.has_node("SelectableComponent"):
		portrait.texture = entity.selectable_component.icon
		name_label.text = entity.selectable_component.display_name

	health_progress_bar.value = 0
	health_label.text = str(0) + "/" + str(0)
	if entity.has_node("HealthComponent"):
		var health = entity.health_component.health
		var max_health = entity.health_component.max_health
		health_progress_bar.value = entity.get_health_percentage()
		health_label.text = str(int(health)) + "/" + str(int(max_health))

	entity_construcion_box.hide()
	entity_training_box.hide()
	entity_production_box.hide()
	entity_stats_box.hide()
	resource_stats_box.hide()
	
			
	if entity is BaseBuilding:
		if entity.is_under_construction:
			entity_construcion_box.show()
			build_progress_bar.value = entity.get_health_percentage()

		elif entity.has_node("ResourceComponent"):
			resource_stats_box.show()
			resource_stats_box.setup(entity)
			health_progress_bar.value = entity.get_health_percentage()
			health_label.text = ""

		elif entity.has_node("TrainingComponent"):
			var training_component = entity.get_node_or_null("TrainingComponent")
			if training_component.is_training:
				entity_training_box.show()
				entity_training_box.update()

		elif entity.has_node("DrainComponent"):
			entity_production_box.show()
			entity_production_box.update()

		else:
			entity_stats_box.show()
			entity_stats_box.update()
			
	elif entity is BaseUnit:
		entity_stats_box.show()
		entity_stats_box.update()
