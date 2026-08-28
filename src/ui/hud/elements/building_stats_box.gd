extends VBoxContainer
class_name  BuildingStatsBox

@onready var portrait: TextureRect = $HBoxContainer/ImageVBoxContainer/Portrait
@onready var health_progress_bar: ProgressBar = $HBoxContainer/ImageVBoxContainer/HealthProgressBar
@onready var health_label: Label = $HBoxContainer/ImageVBoxContainer/HealthLabel
@onready var name_label: Label = $HBoxContainer/NameVBoxContainer/NomeBuilding

@onready var training_box_container: HBoxContainer = $TrainingBoxContainer
@onready var training_icon: TextureRect = $TrainingBoxContainer/TrainingIcon
@onready var build_progress_bar: ProgressBar = $BuildProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup(entity: Node2D) -> void:
	update(entity)

func update(entity: Node2D) -> void:
	var building = entity as BaseBuilding
	if building == null:
		return

	portrait.texture = building.building_icon
	name_label.text = building.building_name
	health_progress_bar.value = building.get_health_perc()
	health_label.text = str(building.current_health) + "/" + str(building.max_health)
	
	training_box_container.visible = false
	build_progress_bar.visible = false
	if building.is_training:
		training_box_container.visible = true
		#training_icon.texture = building.icon_traning
		build_progress_bar.visible = true
		build_progress_bar.value = building.traning_perc

	if building.is_under_construction:
		build_progress_bar.visible = true
		build_progress_bar.value = building.construction_progress_perc
