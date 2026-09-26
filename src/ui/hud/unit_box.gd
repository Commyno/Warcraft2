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
	if unit.health_component:
		if not unit.health_component.health_changed.is_connected(on_health_changed):
			unit.health_component.health_changed.connect(on_health_changed)
	
func _on_tree_exited() -> void:
	# Disconnettere i signal quando la UI viene rimossa
	if unit and unit.health_component:
		if unit.health_component.health_changed.is_connected(on_health_changed):
			unit.health_component.health_changed.disconnect(on_health_changed)

func on_health_changed(new_health: float, max_health: float) -> void:
	update()

func on_stats_changed() -> void:
	unit_stats_box.update()

func update() -> void:
	if unit.has_node("SelectableComponent"):
		portrait.texture = unit.selectable_component.icon
		name_label.text = unit.selectable_component.display_name
	health_progress_bar.value = 0
	health_label.text = str(0) + "/" + str(0)
	if unit.has_node("HealthComponent"):
		var health = unit.health_component.health
		var max_health = unit.health_component.max_health
		health_progress_bar.value = health / max_health
		health_label.text = str(int(health)) + "/" + str(int(max_health))
	
	unit_stats_box.update()
