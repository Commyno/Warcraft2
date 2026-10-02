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
	#if unit.health_component:
		#if not unit.health_component.health_changed.is_connected(on_health_changed):
			#unit.health_component.health_changed.connect(on_health_changed)

#func on_health_changed(new_health: float, max_health: float) -> void:
	#update()

func on_stats_changed() -> void:
	update()

func update() -> void:
	var attack_component = unit.get_node_or_null("AttackComponent")
	if attack_component != null:
		range_value.text = str(attack_component.attack_range) + "+" + str(0)
		damage_value.text = str(attack_component.basic_damage) + "+" + str(0)

	var defend_component = unit.get_node_or_null("DefendComponent")
	if defend_component != null:
		armor_value.text = str(defend_component.unit.basic_armor) + "+" + str(0)
		
	var vision_component = unit.get_node_or_null("VisionComponent")
	if vision_component != null:
		sight_value.text = str(vision_component.sight_range) + "+" + str(0)
		
	var movement_component = unit.get_node_or_null("MovementComponent")
	if movement_component != null:
		speed_value.text = str(movement_component.move_speed / 10)

#func _on_tree_exited() -> void:
	# Disconnettere i signal quando la UI viene rimossa
	#if unit and unit.health_component:
		#if unit.health_component.health_changed.is_connected(on_health_changed):
			#unit.health_component.health_changed.disconnect(on_health_changed)
