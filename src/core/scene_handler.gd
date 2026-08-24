extends Node

# --- Export Originali ---
@export var main_menu_packed : PackedScene
@export var new_single_menu_packed : PackedScene
@export var new_multi_menu_packed : PackedScene
@export var settings_menu_packed : PackedScene
@export var credits_menu_packed : PackedScene
@export var new_campaign_menu_packed : PackedScene
@export var load_game_menu_packed : PackedScene
@export var custom_scenario_menu_packed : PackedScene
@export var load_map_select_popup_packed : PackedScene

@export_file("*.tscn") var game_scene_path: String

# --- Nuove Variabili di Stato ---
# Questo dizionario salva le referenze alle scene già istanziate, evitando di dover scorrere i figli
var _instantiated_menus: Dictionary = {}
var _active_menu: Node = null
var _history: Array[String] = []

# Mappiamo i nomi dei menu alle relative PackedScene
@onready var _menu_blueprints: Dictionary = {
	"MainMenu": main_menu_packed,
	"SingleGameMenu": new_single_menu_packed,
	"MultiGameMenu": new_multi_menu_packed,
	"SettingsMenu": settings_menu_packed,
	"CreditsMenu": credits_menu_packed,
	"NewCampaignMenu": new_campaign_menu_packed,
	"LoadGameMenu": load_game_menu_packed,
	"CustomScenarioMenu": custom_scenario_menu_packed
}

func _ready() -> void:
	on_restart_menu()

# --- Funzione Centrale di Navigazione ---
func on_restart_menu() -> void:
	get_tree().paused = false

		# Rimuoviamo vecchie GameScene (se stiamo tornando al menu principale)
	var old_game = get_node_or_null("GameScene")
	if old_game:
		old_game.queue_free()
		
	# Apriamo il menu iniziale
	open_menu("MainMenu")

# --- Funzione Centrale di Navigazione ---
func open_menu(menu_name: String, save_history: bool = true) -> void:
	# 1. Nascondiamo il menu attivo attuale e salviamo la storia!
	if _active_menu != null:
		if save_history:
			_history.append(_active_menu.name) # <-- Salviamo da dove veniamo
		_active_menu.hide()

	# ... IL RESTO DELLA FUNZIONE RIMANE IDENTICO ...

	if _instantiated_menus.has(menu_name):
		_active_menu = _instantiated_menus[menu_name]
		_active_menu.show()
		return
		
	var packed_scene: PackedScene = _menu_blueprints.get(menu_name)
	if packed_scene == null:
		push_error("Impossibile trovare o caricare la scena: " + menu_name)
		return

	var new_menu: Node = packed_scene.instantiate()
	new_menu.name = menu_name
	add_child(new_menu)

	_connect_menu_signals(new_menu, menu_name)

	_instantiated_menus[menu_name] = new_menu
	_active_menu = new_menu
	_active_menu.show()

func go_back() -> void:
	if _history.size() > 0:
		# Estraiamo l'ultimo menu visitato
		var previous_menu_name = _history.pop_back()
		# Lo apriamo, ma passiamo "false" così non salviamo questo movimento all'indietro nella storia
		open_menu(previous_menu_name, false)
	else:
		# Fallback di sicurezza: se la storia è vuota, torniamo al MainMenu
		open_menu("MainMenu", false)

# --- Smistamento Segnali ---
func _connect_menu_signals(menu_node: Node, menu_name: String) -> void:
	
	# Molti sottomenù possiedono il segnale "main_menu". Lo colleghiamo a prescindere:
	if menu_node.has_signal("dismiss"):
		# Usiamo le lambda: ignoriamo l'argomento origin e apriamo la scena bersaglio.
		menu_node.dismiss.connect(func(): go_back())

	# Colleghiamo i segnali specifici in base al menu instanziato
	match menu_name:
		"MainMenu":
			menu_node.single_player_pressed.connect(func(_origin): open_menu("SingleGameMenu"))
			menu_node.multi_player_pressed.connect(func(_origin): open_menu("MultiGameMenu"))
			menu_node.show_credits_pressed.connect(func(_origin): open_menu("CreditsMenu"))
			menu_node.show_settings_pressed.connect(func(_origin): open_menu("SettingsMenu"))
			menu_node.exit_program_pressed.connect(func(_origin): get_tree().quit())
			
		"SingleGameMenu":
			menu_node.new_campaign_menu.connect(func(_origin): open_menu("NewCampaignMenu"))
			menu_node.load_menu.connect(func(_origin): open_menu("LoadGameMenu"))
			menu_node.custom_scenario_menu.connect(func(_origin): open_menu("CustomScenarioMenu"))
			
		"CustomScenarioMenu":
			menu_node.new_custom_scenario.connect(func(_origin): load_new_custom_scenario())
			menu_node.map_select_popup.connect(func(_origin): load_map_select_popup())


# --- Gestione Scene Speciali e Popup ---

# I popup hanno bisogno di un trattamento speciale (queue_free invece di hide)
func load_map_select_popup() -> void:
	# Non interferiamo con _active_menu perché è un popup sopra il menu attuale
	var popup: Node = load_map_select_popup_packed.instantiate()
	popup.name = "MapSelectPopup"
	add_child(popup)
	
	# Quando viene chiuso, lo eliminiamo
	popup.dismiss.connect(func(): popup.queue_free())
	
	# Inviamo il segnale di dismiss anche al menu scenario se aperto
	var custom_scenario = _instantiated_menus.get("CustomScenarioMenu")
	if custom_scenario and custom_scenario.has_method("map_select_popup_dismiss"):
		popup.dismiss.connect(custom_scenario.map_select_popup_dismiss)

# Il caricamento della vera e propria scena di gioco
func load_new_custom_scenario() -> void:
	if _active_menu:
		_active_menu.hide()
	
	print_game_setup()
	
	SceneLoader.scene_ready.connect(_on_level_ready, CONNECT_ONE_SHOT)
	SceneLoader.load_scene(game_scene_path)

func on_restart_scenario() -> void:
	get_tree().paused = false

	var old_scene = get_node_or_null("GameScene")
	if old_scene:
		old_scene.queue_free()

	SceneLoader.scene_ready.connect(_on_level_ready, CONNECT_ONE_SHOT)
	SceneLoader.load_scene(game_scene_path)

func _on_level_ready(level_node: Node) -> void:
	level_node.name = "GameScene"
	add_child(level_node)


# --- Debug ---
func print_game_setup() -> void:
	print("\n========== STATO ATTUALE DELLA PARTITA ==========")
	
	print("\n--- IMPOSTAZIONI GENERALI ---")
	print("- Modalità di Gioco: ", MatchData.game_mode)
	
	print("\n--- IMPOSTAZIONI MAPPA ---")
	print("- Nome Mappa: ", MatchData.selected_map_path)
	print("- Max Giocatori: ", MatchData.max_players)
	print("- La tua Razza: ", MatchData.your_race)
	print("- Risorse Mappa: ", MatchData.map_resources)
	print("- Unità Iniziali: ", MatchData.start_units)
	print("- Tileset Mappa: ", MatchData.map_tileset)
	
	print("\n--- ELENCO PARTECIPANTI (Avversari: ", MatchData.number_of_opponents, ") ---")
	
	if MatchData.participants_setup.is_empty():
		print("Nessun partecipante è stato ancora inserito nell'array.")
	else:
		for p in MatchData.participants_setup.values():
			var p_id = p.get("slot_id", "Sconosciuto")
			var p_type = p.get("type", "Sconosciuto")
			var p_race = p.get("race", "Sconosciuta")
			var p_team = p.get("team", "Sconosciuto")
			var p_resources = p.get("resources", "Sconosciute")
			print(" -> Slot ID: ", p_id, " | Tipo: ", p_type, " | Razza: ", p_race, " | Team: ", p_team, " | Risorse: ", p_resources)
			
	print("=================================================\n")
