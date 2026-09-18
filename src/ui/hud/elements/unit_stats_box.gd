extends VBoxContainer
class_name UnitStatsBox

@onready var armor_value: Label = $UnitStatsBoxContainer/ValueVBoxContainer/ArmorValue
@onready var damage_value: Label = $UnitStatsBoxContainer/ValueVBoxContainer/DamageValue
@onready var range_value: Label = $UnitStatsBoxContainer/ValueVBoxContainer/RangeValue
@onready var sight_value: Label = $UnitStatsBoxContainer/ValueVBoxContainer/SightValue
@onready var speed_value: Label = $UnitStatsBoxContainer/ValueVBoxContainer/SpeedValue

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
	armor_value.text = str(unit.basic_armor) + "+" + str(unit.basic_armor)
	damage_value.text = str(unit.basic_damage) + "+" + str(unit.basic_damage)
	range_value.text = str(unit.attack_range) + "+" + str(unit.attack_range)
	sight_value.text = str(unit.sight_range) + "+" + str(unit.sight_range)
	speed_value.text = str(unit.move_speed / 10)

func _on_tree_exited() -> void:
	# Disconnettere i signal quando la UI viene rimossa
	if unit and unit.resources_changed.is_connected(update):
		unit.resources_changed.disconnect(update)
