extends VBoxContainer
class_name  BuildingStatsBox

@onready var portrait: TextureRect = $HBoxContainer/ImageVBoxContainer/Portrait
@onready var health_progress_bar: ProgressBar = $HBoxContainer/ImageVBoxContainer/HealthProgressBar
@onready var health_label: Label = $HBoxContainer/ImageVBoxContainer/HealthLabel
@onready var name_label: Label = $HBoxContainer/NameVBoxContainer/NomeBuilding

@onready var training_box_container: HBoxContainer = $TrainingBoxContainer
@onready var training_icon: TextureRect = $TrainingBoxContainer/TrainingIcon
@onready var build_progress_bar: ProgressBar = $BuildProgressBar

var building: BaseBuilding

func setup(entity: Node2D) -> void:
	building = entity as BaseBuilding
	if building == null:
		return

	update()
	
	# Connettiamo il signal per gli aggiornamenti futuri delle risorse
	if not building.health_changed.is_connected(on_health_changed):
		building.health_changed.connect(on_health_changed)
	if not building.construction_progress_updated.is_connected(on_health_changed):
		building.construction_progress_updated.connect(on_health_changed)

func on_health_changed(new_health: float, max_health: float) -> void:
	update()

func construction_progress_updated(current_hp: float, max_hp: float) -> void:
	update()

func update() -> void:
	portrait.texture = building.building_icon
	health_progress_bar.value = building.get_health_perc()
	health_label.text = str(building.current_health) + "/" + str(building.max_health)

	name_label.text = building.building_name
	
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

func _on_tree_exited() -> void:
	if building == null:
		return
	if not building.health_changed.is_connected(on_health_changed):
		building.health_changed.disconnect(on_health_changed)
	if not building.construction_progress_updated.is_connected(on_health_changed):
		building.construction_progress_updated.disconnect(on_health_changed)
