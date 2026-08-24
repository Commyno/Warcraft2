extends Control

#Signals
signal dismiss

#Enum
enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN } 

#Const

#Export
@export var music_volume_slider: HSlider
@export var sfx_volume_slider: HSlider
@export var window_mode_option: OptionButton

#var public
#var _private

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_load_settings()
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_back_button_pressed() -> void:
	_load_settings()
	dismiss.emit()

func _on_apply_button_pressed() -> void:
	_save_settings()

func _load_settings() -> void:
	if music_volume_slider:
		music_volume_slider.value = PlayerData.music_volume
	if sfx_volume_slider:
		sfx_volume_slider.value = PlayerData.sfx_volume
	if window_mode_option:
		window_mode_option.select(PlayerData.window_mode)

func _save_settings() -> void:
	if music_volume_slider:
		PlayerData.music_volume = music_volume_slider.value
	if sfx_volume_slider:
		PlayerData.sfx_volume = sfx_volume_slider.value
	if window_mode_option:
		PlayerData.window_mode = window_mode_option.selected
		set_window_mode(PlayerData.window_mode as WindowMode)

func set_window_mode(mode: int) -> void:
	match mode:
		0: # Windowed
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			
		1: # Borderless Fullscreen (Finestra senza bordi massimizzata alla risoluzione schermo)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			
		2: # Fullscreen Esclusivo
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
