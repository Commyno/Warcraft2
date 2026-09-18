class_name UnitBox
extends VBoxContainer

@onready var portrait: TextureRect = $UnitInfo/ImageVBoxContainer/Portrait
@onready var health_progress_bar: ProgressBar = $UnitInfo/ImageVBoxContainer/HealthProgressBar
@onready var health_label: Label = $UnitInfo/ImageVBoxContainer/HealthLabel

@onready var name_label: Label = $UnitInfo/NameVBoxContainer/NameLabel
@onready var livello: Label = $UnitInfo/NameVBoxContainer/Livello

@onready var unit_stats_box: UnitStatsBox = $UnitStatsBox

var unit: BaseUnit = null

func setup(entity: Node2D) -> void:
	if not entity is BaseUnit:
		return

	unit = entity as BaseUnit
	
	unit_stats_box.setup(unit)
	unit_stats_box.show()

	update()
	
	# Connettiamo il signal per gli aggiornamenti futuri delle risorse
	if not unit.health_changed.is_connected(on_health_changed):
		unit.health_changed.connect(on_health_changed)
	
func _on_tree_exited() -> void:
	# Disconnettere i signal quando la UI viene rimossa
	if unit and unit.resources_changed.is_connected(on_health_changed):
		unit.resources_changed.disconnect(on_health_changed)

func on_health_changed(new_health: float, max_health: float) -> void:
	update()

func update() -> void:
	# UnitInfo
	portrait.texture = unit.icon
	health_progress_bar.value = unit.get_health_perc()
	health_label.text = str(unit.current_health) + "/" + str(unit.max_health)
	name_label.text = unit.entity_name
	
	unit_stats_box.update()
