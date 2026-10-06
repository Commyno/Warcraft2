class_name BuildComponent
extends Node

const MENU_BUILD_ACTION_DATA = preload("uid://25sba0lgjko5")
const MENU_ADVANCED_BUILD_ACTION_DATA = preload("uid://5tvi7wxl3b3o")

# --- PARAMETRI CONFIGURABILI DALL'INSPECTOR ---
@export_group("Building")
@export var build_range: float = 40.0

@onready var unit: BaseUnit = get_parent() as BaseUnit

# TODO: Building variables (Da valutare in futuro, per ora le teniamo)
var is_building: bool = false

func setup(data: Resource) -> void:
	if unit == null:
		return

	unit.available_actions.resize(9)
	unit.available_actions[6] = MENU_BUILD_ACTION_DATA
	unit.available_actions[7] = MENU_ADVANCED_BUILD_ACTION_DATA
	pass

func assign_build_task(building: BaseBuilding) -> void:
	if unit == null:
		return

	unit.clear_assignment() # Azzera ordini precedenti
	if building.is_under_construction:
		unit.current_assignment = BaseUnit.AssignmentState.BUILD
	else:
		unit.current_assignment = BaseUnit.AssignmentState.REPAIR
	unit.interact_with(building)
