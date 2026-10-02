extends VBoxContainer
class_name EntityStatsBox

@onready var armor_value: Label = $EntityStatsBoxContainer/ValueVBoxContainer/ArmorValue
@onready var damage_value: Label = $EntityStatsBoxContainer/ValueVBoxContainer/DamageValue
@onready var range_value: Label = $EntityStatsBoxContainer/ValueVBoxContainer/RangeValue
@onready var sight_value: Label = $EntityStatsBoxContainer/ValueVBoxContainer/SightValue
@onready var speed_value: Label = $EntityStatsBoxContainer/ValueVBoxContainer/SpeedValue

var node: Node2D

func _ready() -> void:
	print("ok")

func setup(entity: Node2D) -> void:
	node = entity
	if node == null:
		return

	update()

func on_stats_changed() -> void:
	update()

func update() -> void:
	if node == null:
		return

	var attack_component   = node.get_node_or_null("AttackComponent")
	var defend_component   = node.get_node_or_null("DefendComponent")
	var vision_component   = node.get_node_or_null("VisionComponent")
	var movement_component = node.get_node_or_null("MovementComponent")

	# Controllo se almeno uno è diverso da null
	var any_component_exists = (
		attack_component != null or
		defend_component != null or
		vision_component != null or
		movement_component != null
	)

	# Mostra o nasconde tutti i label
	armor_value.visible  = any_component_exists
	damage_value.visible = any_component_exists
	range_value.visible  = any_component_exists
	sight_value.visible  = any_component_exists
	speed_value.visible  = any_component_exists

	# Se nessun componente esiste, esci
	if not any_component_exists:
		return

	# ATTACK
	if attack_component:
		range_value.text  = str(attack_component.attack_range) + "+" + str(0)
		damage_value.text = str(attack_component.basic_damage) + "+" + str(0)
	else:
		range_value.text  = "0" + "+" + str(0)
		damage_value.text = "0" + "+" + str(0)

	# DEFEND
	if defend_component:
		armor_value.text = str(defend_component.basic_armor) + "+" + str(0)
	else:
		armor_value.text = "0" + "+" + str(0)

	# VISION
	if vision_component:
		sight_value.text = str(vision_component.sight_range) + "+" + str(0)
	else:
		sight_value.text = "0" + "+" + str(0)

	# MOVEMENT
	if movement_component:
		speed_value.text = str(movement_component.move_speed / 10.0) + "+" + str(0)
	else:
		speed_value.text = "0" + "+" + str(0)
