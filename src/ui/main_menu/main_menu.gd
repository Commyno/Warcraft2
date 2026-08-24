extends Control

signal single_player_pressed(origin: String)
signal multi_player_pressed(origin: String)
signal show_credits_pressed(origin: String)
signal show_settings_pressed(origin: String)
signal exit_program_pressed(origin: String)

func _on_single_player_pressed() -> void:
	single_player_pressed.emit("MainMenu")


func _on_multi_player_pressed() -> void:
	multi_player_pressed.emit("MainMenu")


func _on_show_credits_pressed() -> void:
	show_credits_pressed.emit("MainMenu")

func _on_show_settings_pressed() -> void:
	show_settings_pressed.emit("MainMenu")

func _on_exit_program_pressed() -> void:
	exit_program_pressed.emit("MainMenu")
