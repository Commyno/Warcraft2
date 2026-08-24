extends Control

signal return_to_game
#signal show_confirm_end_game(origin: String)
#signal quit_game(origin: String)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_save_button_pressed() -> void:
# FUTURE visualizzare elenco salvataggi per load
#	SaveManager.load_game()
	pass

func _on_load_button_pressed() -> void:
# FUTURE visualizzare elenco salvataggi con possibilità di sovrascrittura 
# o salvataggio in nuovo file
#	SaveManager.save_game()
	pass

func _on_options_button_pressed() -> void:
	pass

func _on_help_button_pressed() -> void:
	pass

func _on_scenario_objectives_button_pressed() -> void:
	pass

func _on_return_to_game_button_pressed() -> void:
	return_to_game.emit()

func _on_end_scenario_button_pressed() -> void:
	get_parent().open_menu("ConfirmEndMenu")
