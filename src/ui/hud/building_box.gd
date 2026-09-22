class_name BuildingBox
extends VBoxContainer

# BuildingInfo
@onready var portrait: TextureRect = $BuildingInfo/ImageVBoxContainer/Portrait
@onready var health_progress_bar: ProgressBar = $BuildingInfo/ImageVBoxContainer/HealthProgressBar
@onready var health_label: Label = $BuildingInfo/ImageVBoxContainer/HealthLabel

@onready var name_label: Label = $BuildingInfo/NameVBoxContainer/NameLabel
@onready var livello: Label = $BuildingInfo/NameVBoxContainer/Livello

# BuildingTrainingBox
@onready var building_training_box: BuildingTrainingBox = $BuildingTrainingBox

# BuildingStatsBox
@onready var building_stats_box: BuildingStatsBox = $BuildingStatsBox

# ProductionStatsBox
@onready var building_production_box: VBoxContainer = $BuildingProductionBox

# BuildingConstrucionBox
@onready var building_construcion_box: MarginContainer = $BuildingConstrucionBox
@onready var build_progress_bar: ProgressBar = $BuildingConstrucionBox/BuildProgressBar

var building: BaseBuilding

func _ready() -> void:
	building_training_box.hide()

func setup(entity: Node2D) -> void:
	building = entity as BaseBuilding
	if building == null:
		return

	building_construcion_box.hide()
	building_training_box.hide()
	building_production_box.hide()
	building_stats_box.hide()

	if building.is_under_construction:
		building_construcion_box.show()
		build_progress_bar.value = 0
	elif building.is_training:
		building_training_box.show()
		building_training_box.setup(entity)
	elif building.is_resource_dropoff:
		building_production_box.show()
		building_production_box.setup(entity)
	elif building is DefendBuilding:
		building_stats_box.show()
		building_stats_box.setup(entity)
	
	update()
	
	# Connettiamo il signal per gli aggiornamenti futuri delle risorse
	if building and not building.health_changed.is_connected(on_health_changed):
		building.health_changed.connect(on_health_changed)
	# Connettiamo il signal per gli aggiornamenti sulla lista di produzione
	if building and not building.queue_updated.is_connected(on_queue_updated):
		building.queue_updated.connect(on_queue_updated)

func _on_tree_exited() -> void:
	# Disconnettere i signal quando la UI viene rimossa
	if building and building.health_changed.is_connected(on_health_changed):
		building.health_changed.disconnect(on_health_changed)

func on_health_changed(new_health: int, max_health: int) -> void:
	update()

func on_queue_updated(queue: Array[UnitData]) -> void:
	setup(building)

func on_data_changed() -> void:
	update()

func update() -> void:
	if building.has_node("SelectableComponent"):
		portrait.texture = building.selectable_component.icon
		name_label.text = building.selectable_component.display_name

	health_progress_bar.value = building.get_health_perc()
	health_label.text = str(building.current_health) + "/" + str(building.max_health)
	
	if building.is_under_construction:
		building_construcion_box.show()
		building_training_box.hide()
		building_production_box.hide()
		building_stats_box.hide()
		build_progress_bar.value = building.get_health_perc()
	elif building.is_training:
		building_construcion_box.hide()
		building_training_box.show()
		building_production_box.hide()
		building_stats_box.hide()
		building_training_box.update()
	elif building.is_resource_dropoff:
		building_construcion_box.hide()
		building_training_box.hide()
		building_production_box.show()
		building_stats_box.hide()
		building_production_box.update()
	elif building is DefendBuilding:
		building_construcion_box.hide()
		building_training_box.hide()
		building_production_box.hide()
		building_stats_box.show()
		building_stats_box.update()
