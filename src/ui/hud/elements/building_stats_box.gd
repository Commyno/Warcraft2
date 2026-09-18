class_name  BuildingStatsBox
extends HBoxContainer

@onready var armor_value: Label = $ValueVBoxContainer/ArmorValue
@onready var damage_value: Label = $ValueVBoxContainer/DamageValue
@onready var range_value: Label = $ValueVBoxContainer/RangeValue
@onready var sight_value: Label = $ValueVBoxContainer/SightValue
@onready var speed_value: Label = $ValueVBoxContainer/SpeedValue

var building: BaseBuilding

func setup(entity: Node2D) -> void:
	building = entity as BaseBuilding
	if building == null:
		return

	update()
	
	# Connettiamo il signal per gli aggiornamenti futuri delle risorse
	if not building.health_changed.is_connected(on_health_changed):
		building.health_changed.connect(on_health_changed)

func on_health_changed(new_health: float, max_health: float) -> void:
	update()

func update() -> void:
	armor_value.text = str(building.basic_armor) + "+" + str(building.basic_armor)
	damage_value.text = str(building.basic_damage) + "+" + str(building.basic_damage)
	range_value.text = str(building.attack_range) + "+" + str(building.attack_range)
	sight_value.text = str(building.sight_range) + "+" + str(building.sight_range)
	speed_value.text = str(building.move_speed / 10)

func _on_tree_exited() -> void:
	# Disconnettere i signal quando la UI viene rimossa
	if building and building.health_changed.is_connected(on_health_changed):
		building.health_changed.disconnect(on_health_changed)
