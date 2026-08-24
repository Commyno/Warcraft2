class_name Player
extends Node

# ==========================================
# SIGNALS
# ==========================================
signal game_over(victorious: bool)
signal resources_changed(gold: int, lumber: int, oil: int)

# ==========================================
# CONSTANTS (PUNTEGGI)
# ==========================================

# Punti assegnati per la distruzione di edifici nemici (Umani / Orchi)
const BUILDING_SCORES = {
	# Strutture neutrali / speciali
	"dark_portal": 0, "gold_mine": 0,
	# Mura
	"wall": 1,
	# Torri Base
	"scout_tower": 95, "watch_tower": 95,
	# Produzione Risorse / Base
	"farm": 100, "pig_farm": 100,
	"elven_lumber_mill": 150, "troll_lumber_mill": 150,
	"runestone": 150,
	# Produzione Truppe e Upgrade
	"barracks": 160, "oil_platform": 160,
	"blacksmith": 170, "shipyard": 170,
	# Avanzate e Torri potenziate
	"foundry": 200, "guard_tower": 200, "refinery": 200,
	# Edifici Principali (Tier 1)
	"town_hall": 200, "great_hall": 200,
	# Strutture Magiche e Unità Pesanti
	"stables": 210, "ogre_mound": 210,
	"gnomish_inventor": 230, "goblin_alchemist": 230,
	"church": 240, "altar_of_storms": 240,
	"mage_tower": 240, "temple_of_the_damned": 240,
	# Massima Difesa e Volanti
	"cannon_tower": 250, "gryphon_aviary": 250, "dragon_roost": 250,
	# Edifici Principali (Tier 2 e 3)
	"keep": 600, "stronghold": 600,
	"castle": 1500, "fortress": 1500
}

# Punti assegnati per l'uccisione di unità nemiche
const UNIT_SCORES = {
	"peasant": 10, "peon": 10,
	"footman": 25, "grunt": 25,
	"archer": 30, "axethrower": 30,
	"elven_destroyer": 150, "troll_destroyer": 150,
	"gryphon_rider": 150, "dragon": 150,
	"battleship": 300, "ogre_juggernaut": 300
}

const TIDES_OF_DARKNESS_HERO_SCORE = 120
const BTDP_HERO_EXCEPTIONS = {
	"dentarg": 100
}

# ==========================================
# VARIABLES: RESOURCES (PRIVATE)
# ==========================================
var _gold_counts   : int = 0
var _lumber_counts : int = 0
var _oil_counts    : int = 0

# ==========================================
# VARIABLES: IDENTITY & STATE
# ==========================================
var player_id      : int = 0
var player_name    : String = ""
var is_human       : bool = false
var spawn_position : Vector2i = Vector2i.ZERO
var color          : Color = Color.WHITE
var faction        : String = "Neutrale"
var has_won        : bool = false
var total_score    : int = 0

# ==========================================
# VARIABLES: READ-ONLY RESOURCES
# ==========================================
var gold_counts   : int:
	get: return _gold_counts
var lumber_counts : int:
	get: return _lumber_counts
var oil_counts    : int:
	get: return _oil_counts

# ==========================================
# VARIABLES: CURRENT ENTITY COUNTS (DYNAMIC)
# ==========================================
var current_units_count: int:
	get:
		var all_units = get_tree().get_nodes_in_group("units")
		var count = 0
		for unita in all_units:
			if "player_id" in unita and unita.player_id == self.player_id:
				count += 1
		return count

var current_buildings_count : int:
	get:
		var all_buildings = get_tree().get_nodes_in_group("buildings")
		var count = 0
		for edificio in all_buildings:
			if "player_id" in edificio and edificio.player_id == self.player_id:
				count += 1
		return count

# ==========================================
# VARIABLES: LIFETIME STATISTICS (TOTALS)
# ==========================================˙
# Totali di produzione (incrementati quando il giocatore crea qualcosa)
var total_units_trained   : int = 0
var total_buildings_built : int = 0

# Totali globali di distruzione
var total_units_killed        : int = 0
var total_buildings_destroyed : int = 0

# Dettagli per il calcolo del punteggio
var kills_details           : Dictionary = {} # Es: {"footman": 5}
var buildings_razed_details : Dictionary = {} # Es: {"farm": 2}
var heroes_killed           : Array = []      # Es: ["danath", "dentarg"]


func _ready() -> void:
	add_to_group("players")

# ==========================================
# SETUP & INITIALIZATION
# ==========================================
func setup(id: int, start_pos: Vector2, config: Dictionary) -> void:
	self.player_id = id
	self.spawn_position = start_pos
	
	# Dati di Identità
	self.player_name = config.get("name", "Giocatore " + str(id))
	self.color = config.get("color", Color.WHITE)
	self.faction = config.get("faction", "Umani")
	self.is_human = config.get("type", "") == "Human"
	
	# Dati delle Risorse (usiamo le variabili private _ per non far scattare i getter in errore)
	self._gold_counts = config.get("gold", 0)
	self._lumber_counts = config.get("wood", 0)
	self._oil_counts = config.get("oil", 0)
	
	# Avvisiamo l'UI
	resources_changed.emit(_gold_counts, _lumber_counts, _oil_counts)

# ==========================================
# RESOURCE MANAGEMENT
# ==========================================
func add_gold(amount: int) -> void:
	_gold_counts += amount
	resources_changed.emit(_gold_counts, _lumber_counts, _oil_counts)

func add_lumber(amount: int) -> void:
	_lumber_counts += amount
	resources_changed.emit(_gold_counts, _lumber_counts, _oil_counts)

func add_oil(amount: int) -> void:
	_oil_counts += amount
	resources_changed.emit(_gold_counts, _lumber_counts, _oil_counts)

func can_afford(gold_cost: int, lumber_cost: int, oil_cost: int) -> bool:
	return _gold_counts >= gold_cost and _lumber_counts >= lumber_cost and _oil_counts >= oil_cost

func spend_resources(gold_cost: int, lumber_cost: int, oil_cost: int) -> void:
	_gold_counts -= gold_cost
	_lumber_counts -= lumber_cost
	_oil_counts -= oil_cost
	resources_changed.emit(_gold_counts, _lumber_counts, _oil_counts)

# ==========================================
# STATISTICS & SCORE TRACKING
# ==========================================

# Da chiamare quando l'edificio del giocatore finisce l'addestramento
func register_unit_trained() -> void:
	total_units_trained += 1

# Da chiamare quando il peon del giocatore finisce di costruire
func register_building_built() -> void:
	total_buildings_built += 1

# Da chiamare quando un'unità di questo giocatore distrugge un'unità nemica
func register_unit_kill(unit_type: String) -> void:
	total_units_killed += 1
	if kills_details.has(unit_type):
		kills_details[unit_type] += 1
	else:
		kills_details[unit_type] = 1

# Da chiamare quando un'unità di questo giocatore uccide un Eroe nemico
func register_hero_kill(hero_type: String) -> void:
	total_units_killed += 1
	heroes_killed.append(hero_type)

# Da chiamare quando un'unità di questo giocatore distrugge un edificio nemico
func register_building_razed(building_type: String) -> void:
	total_buildings_destroyed += 1
	if buildings_razed_details.has(building_type):
		buildings_razed_details[building_type] += 1
	else:
		buildings_razed_details[building_type] = 1

# ==========================================
# SCORE CALCULATION
# ==========================================
func calculate_final_score() -> int:
	total_score = 0
	
	# 1. Bonus Vittoria
	if has_won:
		total_score += 500
		
	# 2. Punti Unità
	for unit in kills_details.keys():
		var count = kills_details[unit]
		var pts = UNIT_SCORES.get(unit, 10) # 10 punti base se non trovata
		total_score += count * pts
		
	# 3. Punti Edifici
	for building in buildings_razed_details.keys():
		var count = buildings_razed_details[building]
		var pts = BUILDING_SCORES.get(building, 0)
		total_score += count * pts
		
	# 4. Punti Eroi
	for hero in heroes_killed:
		total_score += _get_hero_points(hero)
		
	return total_score

func _get_hero_points(hero_type: String) -> int:
	if BTDP_HERO_EXCEPTIONS.has(hero_type):
		return BTDP_HERO_EXCEPTIONS[hero_type]
	
	# Assumiamo per ora che tutti gli altri Eroi siano di Tides of Darkness
	return TIDES_OF_DARKNESS_HERO_SCORE

# ==========================================
# GAME STATE
# ==========================================
func check_defeat() -> void:
	if current_buildings_count <= 0:
		death()

func death() -> void:
	game_over.emit(false)
