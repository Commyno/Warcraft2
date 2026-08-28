extends Control

# ==========================================
# SIGNALS
# ==========================================
signal dismiss
signal new_custom_scenario
signal map_select_popup

# ==========================================
# ONREADY VARIABLES
# ==========================================
@onready var your_race_ob       : OptionButton = $VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer2/YourRaceOB
@onready var resources_ob       : OptionButton = $VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer2/ResourcesOB
@onready var units_ob           : OptionButton = $VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer2/UnitsOB
@onready var opponents_ob       : OptionButton = $VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer4/OpponentsOB
@onready var map_tileset_ob     : OptionButton = $VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer4/MapTilesetOB
@onready var selected_map_info  : RichTextLabel = $VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer5/SelectedMapInfo

# ==========================================
# SETUP SCENA
# ==========================================
func _ready() -> void:
	# 1. Imposta in automatico la modalità di gioco
	MatchData.game_mode = Globals.GameType.CUSTOM
	
	# 2. Avviamo il caricamento asincrono delle mappe in background (cartella custom)
	MatchData.preload_maps("res://maps/custom")
	
	# 3. Aggiorniamo le info della mappa selezionata
	_update_map_details()

func _sync_ui_with_match_data() -> void:
	_select_item_by_id(your_race_ob, MatchData.your_race)
	_select_item_by_id(resources_ob, MatchData.map_resources)
	_select_item_by_id(units_ob, MatchData.start_units)
	_select_item_by_id(opponents_ob, MatchData.number_of_opponents)
	_select_item_by_id(map_tileset_ob, MatchData.map_tileset)

func _select_item_by_id(ob: OptionButton, id: int) -> void:
	var idx = ob.get_item_index(id)
	if idx != -1:
		ob.select(idx)

# ==========================================
# HANDLERS: MENU BUTTONS
# ==========================================
func _on_back_button_pressed() -> void:
	dismiss.emit()

func _on_start_game_button_pressed() -> void:
	# Sicurezza: Impediamo l'avvio se non c'è una mappa selezionata!
	if MatchData.selected_map_data.is_empty():
		push_warning("Attenzione: Impossibile avviare, nessuna mappa valida selezionata.")
		return
	
	var map_data: Dictionary = MatchData.selected_map_data
	
	# 1.a Gestione dinamica della Fazione
	var selected_race_id = your_race_ob.get_selected_id()
	if selected_race_id == Globals.RaceType.RANDOM:
		MatchData.your_race = [Globals.RaceType.HUMAN, Globals.RaceType.ORC].pick_random()
	elif selected_race_id == Globals.RaceType.MAP_DEFAULT:
		MatchData.your_race = map_data["default_race_player"]
	else:
		MatchData.your_race = selected_race_id as Globals.RaceType
	
	# 1.b Gestione dinamica delle risorse
	var selected_resources_id = resources_ob.get_selected_id()
	if selected_resources_id == Globals.MapResourcesType.MAP_DEFAULT:
		MatchData.map_resources = map_data["default_resources_player"]
	else:
		MatchData.map_resources = selected_resources_id as Globals.MapResourcesType

	# 1.c Gestione dinamica delle unità
	var selected_start_units_id = units_ob.get_selected_id()
	if selected_start_units_id == Globals.StartUnitsType.MAP_DEFAULT:
		MatchData.start_units = map_data["default_start_unit_player"]
	else:
		MatchData.start_units = selected_start_units_id as Globals.StartUnitsType
	
	# 1.d Gestione dinamica del numero di giocatori
	var selected_opponents_id = opponents_ob.get_selected_id()
	if selected_opponents_id == 0:
		MatchData.number_of_opponents = map_data["max_players"]
	else:
		MatchData.number_of_opponents = selected_opponents_id
	
	MatchData.map_tileset = map_tileset_ob.get_selected_id() as Globals.MapTilesetType
	
	# SETUP PARTECIPANTI (Stessa logica di prima)
	var human_race: Globals.RaceType = MatchData.your_race
	var resource_type: Globals.MapResourcesType = MatchData.map_resources
	var start_units_type: Globals.StartUnitsType = MatchData.start_units

	# 1. Creiamo la lista dei colori disponibili e la mescoliamo casualmente
	var available_colors = [
		Color.BLACK, Color.BLUE, Color.GREEN, Color.ORANGE, 
		Color.RED, Color.VIOLET, Color.WHITE, Color.YELLOW
	]
	available_colors.shuffle()
	
	# 2. Assegniamo il primo colore al Giocatore 1 e lo rimuoviamo dall'array
	MatchData.participants_setup[1] = {
		"slot_id": 1,
		"type": "Human",
		"race": human_race,
		"resources": resource_type,
		"start_units": start_units_type,
		"team": 1,
		"color": available_colors.pop_front() 
	}
		
	var total_opponents: int = 0
	if selected_opponents_id == 0:
		total_opponents = map_data["max_players"] - 1
	else:
		total_opponents = selected_opponents_id
	
	for i in range(1, total_opponents + 1):
		var slot_id: int = i + 1
		var ai_race: Globals.RaceType = [Globals.RaceType.HUMAN, Globals.RaceType.ORC].pick_random()
		
		# Estraiamo il prossimo colore disponibile (se la mappa dovesse supportare 
		# più di 8 giocatori, mettiamo un colore di fallback come Color.WHITE)
		var assigned_color = available_colors.pop_front() if not available_colors.is_empty() else Color.BLUE
		
		MatchData.participants_setup[slot_id] = {
			"slot_id": slot_id,
			"type": "AI",
			"race": ai_race,
			"resources": resource_type,
			"start_units": start_units_type,
			"team": slot_id,
			"color": assigned_color
		}
	
	new_custom_scenario.emit("CustomScenarioMenu")

# ==========================================
# MAP SELECTION E AGGIORNAMENTO UI
# ==========================================
func _on_map_select_pressed() -> void:
	map_select_popup.emit("CustomScenarioMenu")

func map_select_popup_dismiss() -> void:
	_update_map_details()

func _update_opponents_list(max_players: int) -> void:
	var current_selected_id = 0
	if opponents_ob.item_count > 0:
		current_selected_id = opponents_ob.get_selected_id()
		
	opponents_ob.clear()
	opponents_ob.add_item("Map Default", 0)
	
	for i in range(1, max_players + 1):
		var label_text = str(i) + " Opponent"
		if i > 1:
			label_text += "s" 
		opponents_ob.add_item(label_text, i)
		
	_select_item_by_id(opponents_ob, current_selected_id)
	if opponents_ob.selected == -1:
		_select_item_by_id(opponents_ob, 0)

func _update_map_details() -> void:
	if selected_map_info == null:
		return

	# Controllo veloce nel dizionario
	if MatchData.selected_map_data.is_empty():
		selected_map_info.text = "[font_size=9][b] No map selected [/b][/font_size]\n"
		return

	var map_data: Dictionary = MatchData.selected_map_data
	
	# Aggiorniamo la tendina
	_update_opponents_list(map_data["max_players"])

	# Costruiamo il testo in modo istantaneo
	var testo_formattato = ""
	testo_formattato += "[font_size=9][b]" + map_data["name"] + "[/b][/font_size]\n"
	testo_formattato += "[font_size=9][b]Dimensioni:[/b] " + str(map_data["size"].x) + "x" + str(map_data["size"].y) + "[/font_size]\n"
	testo_formattato += "[font_size=9][b]Giocatori Max:[/b] " + str(map_data["max_players"]) + "[/font_size]\n"
	
	selected_map_info.text = testo_formattato
