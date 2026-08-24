extends Control

signal dismiss
signal new_campaign_menu(origin: String)
signal load_menu(origin: String)
signal custom_scenario_menu(origin: String)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	dismiss.emit()

func _on_new_campaign_btn_pressed() -> void:
	new_campaign_menu.emit("SingleGameMenu")

func _on_load_game_btn_pressed() -> void:
	load_menu.emit("SingleGameMenu")

func _on_custom_scenario_btn_pressed() -> void:
	custom_scenario_menu.emit("SingleGameMenu")
