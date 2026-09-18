class_name BuildingTrainingBox
extends VBoxContainer

@onready var training_icon: TextureRect = $TrainingIconBoxContainer/TrainingIcon
@onready var training_progress_bar: ProgressBar = $MarginContainer/TrainingProgressBar

var building: BaseBuilding
var _progress_percent: float

func setup(entity: Node2D) -> void:
	building = entity as BaseBuilding
	if building == null:
		return
	
	training_icon.texture = building.icon
	
	update()
	
	# Connettiamo il signal per gli aggiornamenti sullo stato di avanzamento
	if building and not building.progress_updated.is_connected(on_progress_updated):
		building.progress_updated.connect(on_progress_updated)

func _on_tree_exited() -> void:
	# Disconnettere i signal quando la UI viene rimossa
	if building and building.progress_updated.is_connected(on_progress_updated):
		building.progress_updated.disconnect(on_progress_updated)

func on_progress_updated(progress_percent: float) -> void:
	_progress_percent = progress_percent
	update()

func update() -> void:
	training_progress_bar.value = _progress_percent
