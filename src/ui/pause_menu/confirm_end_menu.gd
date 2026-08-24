extends Control

#signal
signal restart_game()
signal player_defeat()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_restart_button_pressed() -> void:
	restart_game.emit()

func _on_end_scenario_button_pressed() -> void:
	player_defeat.emit()

func _on_return_to_game_button_pressed() -> void:
	get_parent().go_back()
