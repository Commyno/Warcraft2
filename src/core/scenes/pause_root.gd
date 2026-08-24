extends Control

#signal return_to_game

@onready var menus: Dictionary = {}
var menu_stack: Array[Control] = []

func _ready() -> void:
	# Registra in automatico tutti i menu figli nel dizionario
	for child in get_children():
		if child is Control:
			menus[child.name] = child
			child.hide() # Nasconde tutti all'avvio
			
			# Se il sottomenu definisce il segnale, lo colleghiamo a open_menu
			if child.has_signal("return_to_game"):
				child.return_to_game.connect(on_return_to_game)
			if child.has_signal("restart_game"):
				child.restart_game.connect(on_restart_game)
			if child.has_signal("player_defeat"):
				child.player_defeat.connect(on_player_defeat)
	
	close_all()

## Apre un menu specifico e lo aggiunge alla pila di navigazione
func open_menu(menu_name: String) -> void:
	if not menus.has(menu_name):
		push_error("Menu non trovato: " + menu_name)
		return
	
	# Nasconde il menu corrente se presente
	if not menu_stack.is_empty():
		menu_stack.back().hide()
	
	var target_menu: Control = menus[menu_name]
	target_menu.show()
	menu_stack.append(target_menu)

## Torna al menu precedente (tasto Indietro/ESC)
func go_back() -> void:
	if menu_stack.is_empty():
		return
	
	# Chiude il menu attuale
	var current = menu_stack.pop_back()
	current.hide()
	
	# Riapre il precedente
	if not menu_stack.is_empty():
		menu_stack.back().show()

## Chiude e resetta tutti i menu di pausa
func close_all() -> void:
	for m in menus.values():
		m.hide()
	menu_stack.clear()

func on_return_to_game() -> void:
	get_tree().paused = false
	close_all()

func on_restart_game() -> void:
	get_tree().paused = false
	var scene_handler = get_node_or_null("/root/SceneHandler")
	if scene_handler:
		scene_handler.on_restart_scenario()

func on_player_defeat() -> void:
	var game_scene = get_node_or_null("/root/SceneHandler/GameScene")
	if game_scene:
		game_scene.player_defeat()
