class_name CancelActionData
extends ActionData

func _init() -> void:
	id = "cancel"
	title = "Annulla"
	shortcut_key = KEY_ESCAPE
	action_type = ActionType.IMMEDIATE
	target_mode = ExecutionTargetMode.ALL # Tutti i lavoratori selezionati vanno a raccogliere

func is_ui_action() -> bool:
	return true

func execute_ui(grid) -> void:
	if grid != null:
		grid.pop_page()
