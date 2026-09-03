class_name Player
extends Node

# ==========================================
# SIGNALS
# ==========================================
signal game_over(victorious: bool)
signal resources_changed(gold: int, lumber: int, oil: int, food_used: int, food_max: int)
signal upgrade_unlocked(upgrade_id: String, new_level: int)

# ==========================================
# CONSTANTS (PUNTEGGI)
# ==========================================
const MAX_FOOD_LIMIT: int = 200 # Limite massimo di cap in Warcraft II

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
# VARIABLES: IDENTITY & STATE
# ==========================================
@export var player_id      : int = 0
@export var player_name    : String = ""
@export var is_human       : bool = false
@export var is_ai          : bool = false
@export var is_local_player: bool = false
var spawn_position         : Vector2i = Vector2i.ZERO
var color                  : Color = Color.WHITE
var faction                : Globals.RaceType = Globals.RaceType.HUMANS #String = "Alliance"
var team                   : int = 1
var has_won                : bool = false
var total_score            : int = 0


# ==========================================
# VARIABLES: RESOURCES (PRIVATE)
# ==========================================
var _gold_counts   : int = 0
var _lumber_counts : int = 0
var _oil_counts    : int = 0
var _food_used     : int = 0
var _food_max      : int = 0

# Read-Only Getters
var gold_counts   : int: 
	get: return _gold_counts
var lumber_counts : int:
	get: return _lumber_counts
var oil_counts    : int: 
	get: return _oil_counts
var food_used     : int: 
	get: return _food_used
var food_max      : int: 
	get: return _food_max


# ==========================================
# VARIABLES: UPGRADES & TECH TREE
# ==========================================
# Dizionario degli upgrade attivi e livello (es. {"sword_level": 2, "shield_level": 1})
var unlocked_upgrades: Dictionary = {}

# Mappa degli edifici attivi per tipo per controlli Tech-Tree (es. {"barracks": 2, "blacksmith": 1})
var active_building_types: Dictionary = {}


# ==========================================
# VARIABLES: ENTITY COUNTERS
# ==========================================
var current_units_count     : int = 0
var current_buildings_count : int = 0

# ==========================================
# VARIABLES: LIFETIME STATISTICS (TOTALS)
# ==========================================˙
# Totali di produzione (incrementati quando il giocatore crea qualcosa)
var total_units_trained   : int = 0
var total_buildings_built : int = 0
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
func setup(id: int, start_pos: Vector2i, config: Dictionary) -> void:
	self.player_id = id
	self.spawn_position = start_pos
	
	self.player_name = config.get("name", "Player " + str(id))
	self.color = config.get("color", Color.WHITE)
	self.faction = config.get("faction", "Alliance")
	self.team = config.get("team", 1)
	self.is_human = config.get("type", "") == "Human"
	self.is_local_player = config.get("is_local", false)
	self.is_ai = not self.is_human

	self._gold_counts = config.get("gold", 1000)
	self._lumber_counts = config.get("lumber", 500)
	self._oil_counts = config.get("oil", 0)
	self._food_used = 0
	self._food_max = config.get("starting_food_max", 1) # Es. 1 fornito dalla Town Hall iniziale
	
	_notify_resources_changed()

# ==========================================
# RESOURCE MANAGEMENT
# ==========================================
func can_afford(gold: int, lumber: int, oil: int, food: int = 0) -> bool:
	var has_res = _gold_counts >= gold and _lumber_counts >= lumber and _oil_counts >= oil
	var has_food = (_food_used + food) <= _food_max
	return has_res and has_food

func spend_resources(gold: int, lumber: int, oil: int, food: int) -> void:
	_gold_counts -= gold
	_lumber_counts -= lumber
	_oil_counts -= oil
	_food_used += min(food, food_max)
	_notify_resources_changed()

func refund_resources(gold: int, lumber: int, oil: int) -> void:
	_gold_counts += gold
	_lumber_counts += lumber
	_oil_counts += oil
	_notify_resources_changed()

func add_gold(amount: int) -> void:
	_gold_counts += amount
	_notify_resources_changed()

func add_lumber(amount: int) -> void:
	_lumber_counts += amount
	_notify_resources_changed()

func add_oil(amount: int) -> void:
	_oil_counts += amount
	_notify_resources_changed()

func consume_food(amount: int) -> void:
	_food_used += amount
	_notify_resources_changed()

func release_food(amount: int) -> void:
	_food_used = maxi(0, _food_used - amount)
	_notify_resources_changed()

func add_food_capacity(amount: int) -> void:
	_food_max = mini(MAX_FOOD_LIMIT, _food_max + amount)
	_notify_resources_changed()

func remove_food_capacity(amount: int) -> void:
	_food_max = maxi(0, _food_max - amount)
	_notify_resources_changed()

func _notify_resources_changed() -> void:
	resources_changed.emit(_gold_counts, _lumber_counts, _oil_counts, _food_used, _food_max)


# ==========================================
# UPGRADES & TECH TREE
# ==========================================
func unlock_upgrade(upgrade_id: String, bonus_value: int = 1) -> void:
	unlocked_upgrades[upgrade_id] = unlocked_upgrades.get(upgrade_id, 0) + bonus_value
	upgrade_unlocked.emit(upgrade_id, unlocked_upgrades[upgrade_id])

func get_upgrade_level(upgrade_id: String) -> int:
	return unlocked_upgrades.get(upgrade_id, 0)

func has_building(building_id: String) -> bool:
	return active_building_types.get(building_id, 0) > 0


# ==========================================
# ENTITY REGISTRATION (TRACKING IN REAL TIME)
# ==========================================
func register_unit_spawned(unit_data: UnitData) -> void:
	current_units_count += 1
	total_units_trained += 1
	consume_food(unit_data.food_cost)

func register_unit_destroyed(unit_data: UnitData) -> void:
	current_units_count = maxi(0, current_units_count - 1)
	release_food(unit_data.food_cost)

func register_building_completed(building_id: String, food_provided: int = 0) -> void:
	current_buildings_count += 1
	total_buildings_built += 1
	active_building_types[building_id] = active_building_types.get(building_id, 0) + 1
	
	if food_provided > 0:
		add_food_capacity(food_provided)

func register_building_lost(building_id: String, food_provided: int = 0) -> void:
	current_buildings_count = maxi(0, current_buildings_count - 1)
	
	if active_building_types.has(building_id):
		active_building_types[building_id] = maxi(0, active_building_types[building_id] - 1)
		
	if food_provided > 0:
		remove_food_capacity(food_provided)
		
	check_defeat()


# ==========================================
# STATISTICS & SCORE TRACKING
# ==========================================
func register_unit_kill(unit_type: String) -> void:
	total_units_killed += 1
	kills_details[unit_type] = kills_details.get(unit_type, 0) + 1

func register_hero_kill(hero_type: String) -> void:
	total_units_killed += 1
	heroes_killed.append(hero_type)

func register_building_razed(building_type: String) -> void:
	total_buildings_destroyed += 1
	buildings_razed_details[building_type] = buildings_razed_details.get(building_type, 0) + 1


# ==========================================
# SCORE CALCULATION
# ==========================================
func calculate_final_score() -> int:
	total_score = 0
	
	if has_won:
		total_score += 500
		
	for unit in kills_details.keys():
		var count = kills_details[unit]
		var pts = UNIT_SCORES.get(unit, 10)
		total_score += count * pts
		
	for building in buildings_razed_details.keys():
		var count = buildings_razed_details[building]
		var pts = BUILDING_SCORES.get(building, 0)
		total_score += count * pts
		
	for hero in heroes_killed:
		total_score += _get_hero_points(hero)
		
	return total_score

func _get_hero_points(hero_type: String) -> int:
	if BTDP_HERO_EXCEPTIONS.has(hero_type):
		return BTDP_HERO_EXCEPTIONS[hero_type]
	return TIDES_OF_DARKNESS_HERO_SCORE

# ==========================================
# GAME STATE
# ==========================================
func check_defeat() -> void:
	if current_buildings_count <= 0:
		death()

func death() -> void:
	game_over.emit(false)

func _exit_tree() -> void:
	PlayerManager.unregister_player(self)
