class_name SubmenuActionData
extends ActionData

@export_group("Sottomenu")
## Le azioni da mostrare quando si apre questo sottomenu (es. i vari edifici base).
@export var sub_actions: Array[ActionData] = []

func _init() -> void:
	action_type = ActionType.IMMEDIATE

func is_ui_action() -> bool:
	return true

func execute_ui(grid) -> void:
	if grid != null:
		grid.push_page(sub_actions)
