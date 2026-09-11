extends VBoxContainer
class_name UnitStatsBox

@onready var portrait: TextureRect = $HBoxContainer/ImageVBoxContainer/Portrait
@onready var health_progress_bar: ProgressBar = $HBoxContainer/ImageVBoxContainer/HealthProgressBar
@onready var name_label: Label = $HBoxContainer/NameVBoxContainer/NomeUnita
@onready var livello: Label = $HBoxContainer/NameVBoxContainer/Livello
@onready var health_label: Label = $HBoxContainer/ImageVBoxContainer/HealthLabel

@onready var armor_value: Label = $HBoxContainer2/ValueVBoxContainer/ArmorValue
@onready var damage_value: Label = $HBoxContainer2/ValueVBoxContainer/DamageValue
@onready var range_value: Label = $HBoxContainer2/ValueVBoxContainer/RangeValue
@onready var sight_value: Label = $HBoxContainer2/ValueVBoxContainer/SightValue
@onready var speed_value: Label = $HBoxContainer2/ValueVBoxContainer/SpeedValue

var unit: BaseUnit

func setup(entity: Node2D) -> void:
	unit = entity as BaseUnit
	if unit == null:
		return

	update()
	
	# Connettiamo il signal per gli aggiornamenti futuri delle risorse
	if not unit.health_changed.is_connected(on_health_changed):
		unit.health_changed.connect(on_health_changed)

func on_health_changed(new_health: float, max_health: float) -> void:
	update()

func update() -> void:
	portrait.texture = unit.icon
	health_progress_bar.value = unit.get_health_perc()
	print(unit.get_health_perc())
	health_label.text = str(unit.current_health) + "/" + str(unit.max_health)
	name_label.text = unit.name

	armor_value.text = str(unit.basic_armor)
	damage_value.text = str(unit.basic_damage)
	range_value.text = str(unit.attack_range)
	sight_value.text = str(unit.sight_range)
	speed_value.text = str(unit.move_speed / 10)
