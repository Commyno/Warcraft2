extends Control

signal restart_scenario
signal main_menu

const DEFEAT_HUMANS_BACKGROUND  : String = "uid://bhm1tb6p4svlc"
const DEFEAT_ORCS_BACKGROUND    : String = "uid://cxyqj44sx7yhb"
const VICTORY_HUMANS_BACKGROUND : String = "uid://dm5am0lgkad0a"
const VICTORY_ORCS_BACKGROUND   : String = "uid://cksn8vu7yjmdq"
const STATISTICS_PLAYER_SCENE   : String = "uid://cnc02i4p4l754"

# La nostra tabella dei Rank da Warcraft II
const RANKS = [
	{"min": 0,      "human": "Servant",      "orc": "Slave"},
	{"min": 2001,   "human": "Peasant",      "orc": "Peon"},
	{"min": 5001,   "human": "Squire",       "orc": "Rogue"},
	{"min": 8001,   "human": "Footman",      "orc": "Grunt"},
	{"min": 18001,  "human": "Corporal",     "orc": "Slasher"},
	{"min": 28001,  "human": "Sergeant",     "orc": "Marauder"},
	{"min": 40001,  "human": "Lieutenant",   "orc": "Commander"},
	{"min": 55001,  "human": "Captain",      "orc": "Captain"},
	{"min": 70001,  "human": "Major",        "orc": "Major"},
	{"min": 85001,  "human": "Knight",       "orc": "Raider"},
	{"min": 105001, "human": "General",      "orc": "General"},
	{"min": 125001, "human": "Admiral",      "orc": "Master"},
	{"min": 145001, "human": "Marshall",     "orc": "Marshall"},
	{"min": 165001, "human": "Lord",         "orc": "Chieftain"},
	{"min": 185001, "human": "Grand Admiral", "orc": "Overlord"},
	{"min": 205001, "human": "Highlord",     "orc": "War Chief"},
	{"min": 230001, "human": "Thundergod",   "orc": "Demigod"},
	{"min": 255001, "human": "God",          "orc": "God"},
	{"min": 280001, "human": "Designer",     "orc": "Designer"}
]

var victorious: bool = false
var the_player: Player = null

@onready var texture_rect: TextureRect = $TextureRect

@onready var outcome_node: Label = $VBoxContainer/Status/Outcome/Value
@onready var rank_node: Label = $VBoxContainer/Status/Rank/Value
@onready var score_node: Label = $VBoxContainer/Status/Score/Value

@onready var statistics_list: VBoxContainer = $VBoxContainer/StatisticsList

func _ready() -> void:
	pass

# Questa è la funzione che viene chiamata dalla GameScene appena istanzia il nodo
func setup_screen(is_victorious: bool, all_players: Array) -> void:
	self.victorious = is_victorious
	
	# 1. Troviamo prima chi è il giocatore Umano locale
	for p in all_players:
		if p.is_human:
			the_player = p
			break
			
	if the_player == null:
		push_error("Errore: Giocatore umano non trovato nella lista!")
		return

	# 2. Creiamo un "finto" Player in memoria per accumulare i totali globali
	var globals_stats: Player = Player.new()
	for p in all_players:         
		globals_stats.total_units_trained += p.total_units_trained
		globals_stats.total_buildings_built += p.total_buildings_built
		globals_stats.add_gold(p.gold_counts)
		globals_stats.add_lumber(p.lumber_counts)
		globals_stats.add_oil(p.oil_counts)
		globals_stats.total_units_killed += p.total_units_killed
		globals_stats.total_buildings_destroyed += p.total_buildings_destroyed
		
		# (Se ti servono i totali delle kill/edifici per calcolare percentuali, puoi sommarli qui)

	# 3. Impostiamo lo sfondo relativo alla fazione e all'esito
	_select_background()
	
	# 4. Aggiorniamo le etichette principali (Esito, Punteggio, Rank)
	outcome_node.text = "Victory" if is_victorious else "Defeat"
	
	var final_score = the_player.calculate_final_score()
	score_node.text = str(final_score)
	rank_node.text = _get_rank_name(final_score, the_player.faction)
	
	# 5. Pulizia della UI prima di popolarla
	if statistics_list != null and statistics_list.get_child_count() > 0:
		for child in statistics_list.get_children():
			child.queue_free()
	
	# 6. Creiamo le griglie per i giocatori
	set_player_stats(all_players, globals_stats)
	
	# 7. Svuotiamo il "finto" Player dalla memoria perché non ci serve più
	globals_stats.queue_free()

func set_player_stats(all_players: Array, global_stats: Player) -> void:
	# Prima inserisco il player umano
	for p in all_players:
		if p.is_human:
			_instantiate_stat_grid(p, global_stats)
			break # Va bene interrompere, c'è un solo giocatore umano locale
	
	# Poi inserisco TUTTI gli altri player (AI)
	for p in all_players:
		if not p.is_human:
			_instantiate_stat_grid(p, global_stats)
			# FIX: Rimosso il "break" che impediva di mostrare più di un'intelligenza artificiale.

# Funzione di supporto per pulire il codice (Evita copia-incolla massicci)
func _instantiate_stat_grid(p: Player, global_stats: Player) -> void:
	if STATISTICS_PLAYER_SCENE == null:
		push_error("Impossibile caricare la scena statistics_player")
		return
	
	# 1. Istanziazione corretta della scena
	var statistics_scene = load(STATISTICS_PLAYER_SCENE)
	if statistics_scene == null:
		push_error("Impossibile caricare la scena statistics_player")
		return
	
	var statistics_node = statistics_scene.instantiate()
	
	if statistics_node == null:
		push_error("Could not load statistics scene")
		return
	
	statistics_node.name = "StatisticsPlayer_%s" % p.player_id
	
	# Lo aggiungiamo al nodo lista
	statistics_list.add_child(statistics_node)
	
	# Assumendo che il nodo istanziato abbia la funzione 'setup'
	if statistics_node.has_method("setup"):
		statistics_node.setup(p, global_stats)
	else:
		push_error("Il nodo statistics non ha un metodo 'setup'")

func _select_background() -> void:
	var is_human_faction = (the_player.faction == Globals.RaceType.HUMANS)
	var nuova_texture: Texture2D = null
	
	# Sostituiti gli "if true" con la logica della fazione
	if victorious:
		if is_human_faction:
			nuova_texture = load(VICTORY_HUMANS_BACKGROUND)
		else:
			nuova_texture = load(VICTORY_ORCS_BACKGROUND)
	else:
		if is_human_faction:
			nuova_texture = load(DEFEAT_HUMANS_BACKGROUND)
		else:
			nuova_texture = load(DEFEAT_ORCS_BACKGROUND) # FIX: Corretto da DEFEAT_HUMANS_BACKGROUND
	
	if nuova_texture == null:
		push_error("Could not find background image")
		return

	texture_rect.texture = nuova_texture

func _get_rank_name(score: int, faction: Globals.RaceType) -> String:
	var is_human_faction = (faction == Globals.RaceType.HUMANS)
	
	# Scorriamo la tabella al contrario per trovare lo scaglione giusto
	for i in range(RANKS.size() - 1, -1, -1):
		if score >= RANKS[i]["min"]:
			return RANKS[i]["human"] if is_human_faction else RANKS[i]["orc"]
			
	return "Unknown"

# ==========================================
# BUTTON SIGNALS
# ==========================================
func _on_replay_pressed() -> void:
	restart_scenario.emit()

func _on_main_menu_pressed() -> void:
	main_menu.emit()
