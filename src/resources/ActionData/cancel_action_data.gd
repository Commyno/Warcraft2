class_name CancelActionData
extends ActionData

func _init() -> void:
	id = "cancel"
	title = "Annulla"
	shortcut_key = KEY_ESCAPE
	action_type = ActionType.IMMEDIATE

func is_ui_action() -> bool:
	return true

func execute_ui(grid) -> void:
	if grid != null:
		grid.pop_page()
