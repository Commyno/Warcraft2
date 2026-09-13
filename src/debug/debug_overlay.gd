extends Control

const VERSION_SETTING : String = "application/config/version"

@onready var fps_label: Label = $MarginContainer/VBoxContainer/FpsLabel
@onready var version_info: Label = $MarginContainer/VBoxContainer/VersionInfo
@onready var debug_info: Label = $MarginContainer/VBoxContainer/DebugInfo

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_add_version_to_info_label()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	fps_label.text = ("FPS: " + str(Engine.get_frames_per_second()))
	pass

func _add_version_to_info_label() -> void:
	var version_str : String = ProjectSettings.get_setting(VERSION_SETTING)
	version_info.text += version_str
	pass

# Nel tuo GameManager, GameScene o Player
func _unhandled_input(event: InputEvent) -> void:
	# Controlla solo la pressione iniziale del tasto (evita la ripetizione tenendo premuto)
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	
	# Assicurati di avere il riferimento al giocatore locale
	# Se lo script è già dentro Player.gd, puoi usare direttamente self
	var current_player: Player = _bind_local_player()
	if current_player == null:
		return

	match event.keycode:
		KEY_2:
			current_player.add_gold(1000)
			print("Cheat: +1000 Oro aggiunto! (Totale: %d)" % current_player.gold_counts)
		KEY_3:
			current_player.add_lumber(1000) # o add_wood
			print("Cheat: +1000 Legna aggiunta! (Totale: %d)" % current_player.lumber_counts)
		KEY_4:
			current_player.add_oil(1000)
			print("Cheat: +1000 Petrolio aggiunto! (Totale: %d)" % current_player.oil_counts)

func _bind_local_player() -> Player:
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p is Player and p.is_local_player:
			return p
	return null
