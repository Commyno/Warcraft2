class_name GameScene
extends Node

signal levelup

# ==========================================
# CONSTANTS (SCENE UIDs)
# ==========================================
const HUD_ROOT_UID           : String = "uid://ssce78o0mjpg"
# Mappa per Fazione -> Tipo Entità -> Scena effettiva
const FACTION_SPAWN_DATABASE: Dictionary = {
	"Alliance": {
		"gold_mine": preload("res://src/gameplay/entities/buildings/neutral/gold_mine.tscn"),
		"town_hall": preload("res://src/gameplay/entities/buildings/humans/town_hall.tscn"),
		"farm": preload("res://src/gameplay/entities/buildings/humans/farm.tscn"),
		"peasant": preload("res://src/gameplay/entities/units/humans//peasant.tscn"),
		"footman": preload("res://src/gameplay/entities/units/humans//footman.tscn")
	},
	"Horde": {
		"gold_mine": preload("res://src/gameplay/entities/buildings/neutral/gold_mine.tscn"),
		"town_hall": preload("res://src/gameplay/entities/buildings/humans/town_hall.tscn"),
		"farm": preload("res://src/gameplay/entities/buildings/humans/farm.tscn"),
		"peon": preload("res://src/gameplay/entities/units/humans//peasant.tscn"),
		"footman": preload("res://src/gameplay/entities/units/humans//footman.tscn")
	},
	"Neutral": {
		"gold_mine": preload("res://src/gameplay/entities/buildings/neutral/gold_mine.tscn"),
	}
}

# Mappatura dei Tile ID di "logic" / "group 0" verso le scene del gioco
const TILE_MAP_ENTITIES: Dictionary = {
	381: {"faction_key": "Alliance",   "entity_key": "peasant"},
	382: {"faction_key": "Horde",   "entity_key": "peon"},
	421: {"faction_key": "Alliance",   "entity_key": "town_hall"},
	422: {"faction_key": "Horde",   "entity_key": "town_hall"},
	455: {"faction_key": "Neutral",   "entity_key": "gold_mine"}
}

# ==========================================
# VARIABLES
# ==========================================
var _previous_menu: Array = []
var ground_layer   : TileMapLayer = null

var local_player   : Player = null      # Giocatore Locale Umano
var player_list    : Array[Player] = [] # Lista di tutti i giocatori
var players_by_id  : Dictionary = {}    # { player_id (int) : Player }
var spawn_positions: Dictionary = {}    # { slot_id (int) : Vector2 }

@export var end_game_screen_packed : PackedScene = null
@export var confirm_end_game_menu_packed : PackedScene = null

# ==========================================
# ONREADY: GAME WORLD NODES
# ==========================================
@onready var nav_region        : NavigationRegion2D = $World/NavigationRegion2D
@onready var level_root        : Node2D       = $World/NavigationRegion2D/LevelRoot
@onready var entities_root     : Node2D       = $World/NavigationRegion2D/EntitiesRoot
@onready var effects_root      : Node2D       = $World/NavigationRegion2D/EffectsRoot
@onready var players_node      : Node2D       = $Players
@onready var game_camera       : Camera2D     = $Camera2D 

# ==========================================
# ONREADY: UI NODES
# ==========================================
@onready var hud_root        : Control = $HudLayer/HudRoot
@onready var pause_root      : Control = $PauseLayer/PauseRoot
@onready var transition_root : Control = $TransitionLayer/TransitionRoot
@onready var debug_root      : Control = $DebugLayer/DebugRoot

# ==========================================
# INITIALIZATION
# ==========================================
func _ready() -> void:
	# 1. Inizializziamo prima tutte le istanze Player da MatchData
	_init_players()
	
	# 2. Carichiamo la mappa e spawniamo le entità agganciando i Player già creati
	_load_map()

	# 3. Configuriamo HUD e Telecamera
	_load_hud(HUD_ROOT_UID)
	_setup_level_camera()
	
# ==========================================
# PLAYER SETUP
# ==========================================
func _init_players() -> void:
	if MatchData.participants_setup.is_empty():
		push_error("ATTENZIONE: Nessun giocatore trovato in MatchData!")
		return

	player_list.clear()
	players_by_id.clear()

	for player_id in MatchData.participants_setup.keys():
		var config_giocatore: Dictionary = MatchData.participants_setup[player_id]
		
		var nuovo_player: Player = Player.new()
		nuovo_player.name = "Player_" + str(player_id)
		players_node.add_child(nuovo_player)
		
		nuovo_player.setup(player_id, Vector2i.ZERO, config_giocatore)
		nuovo_player.game_over.connect(display_end_game_screen.bind(nuovo_player))
		
		if config_giocatore.get("type", "") == "Human":
			local_player = nuovo_player 
		
		player_list.append(nuovo_player)
		players_by_id[player_id] = nuovo_player
		
		print("✅ Registrato Player: ", nuovo_player.name, " (ID: ", player_id, ")")

# ==========================================
# LEVEL & MAP LOADING
# ==========================================
func _load_map() -> void:
	# Recuperiamo il path della mappa dall'Autoload
	var map_path: String = MatchData.selected_map_path
	if map_path.is_empty() or not ResourceLoader.exists(map_path):
		push_error("Could not load level from custom map: " + map_path)
		return
	
	# Pulizia preliminare del livello
	for child in level_root.get_children():
		if child.name != "EntitiesRoot" and child.name != "EffectsRoot":
			child.queue_free()
	
	# Caricamento sincrono della scena .scn
	var map_res: PackedScene = load(map_path)
		
	if not map_res:
		push_error("Impossibile caricare la risorsa mappa: " + map_path)
		return
		
	# Istanziamo la mappa esportata da YATI (.scn)
	var map_instance: Node2D = map_res.instantiate()
	level_root.add_child(map_instance)
	
	# Recuperiamo il ground layer e lo riassegnamo al nodo padre
	var new_ground = map_instance.find_child("ground", true, false)
	if new_ground is TileMapLayer: 
		ground_layer = new_ground
		GridManager.tile_map_layer = new_ground
		new_ground.reparent(level_root)
		new_ground.position = Vector2.ZERO
	
	# 1. Recupera i marker di spawn
	_parse_spawn_points(map_instance)

	# 2. Assegna slot e spawna le entità dei giocatori
	_parse_players(map_instance)

	# 3. Spawna entità neutrali / ambiente
	_parse_entities_layer(map_instance, "environment")

func _parse_spawn_points(map_node: Node2D) -> void:	
	spawn_positions.clear()
	
	var spawn_layer = map_node.find_child("spawn point", true, false)
	if not spawn_layer:
		push_warning("Nessun layer 'spawn point' trovato nella mappa!")
		return
		
	# Cicliamo su tutti gli oggetti piazzati in quel layer
	for spawn_obj in spawn_layer.get_children():
		
		if spawn_obj.has_meta("slot_id"):
			var s_id: int = spawn_obj.get_meta("slot_id")
			spawn_positions[s_id] = spawn_obj.global_position
			# Distruggiamo l'oggetto segnaposto (non vogliamo che si veda la grafica statica in gioco)
			spawn_obj.queue_free()
	
	spawn_layer.queue_free()

func _parse_players(map_node: Node2D) -> void:
	# Recuperiamo il numero di slot totali supportati dalla mappa 
	var max_slots: int = MatchData.selected_map_data.get("max_players", 2)
	
	# Creiamo un array con gli slot disponibili (es. per 4 max_players avremo [0, 1, 2, 3])
	var available_slots: Array[int] = []
	for i in range(max_slots):
		available_slots.append(i)
		
	# Mescolamento casuale cosi da cambiare posizione di inizio ad ogni partita
	available_slots.shuffle()
	
	# Itera direttamente sulla lista delle istanze Player già create
	for current_player in player_list:
		if available_slots.is_empty():
			push_error("Ci sono più giocatori attivi che slot di partenza sulla mappa!")
			break
		
		var assigned_slot = available_slots.pop_front()
		var group_layer_name = "group " + str(assigned_slot)
		
		# Assegna la spawn position definitiva all'istanza Player
		if spawn_positions.has(assigned_slot):
			current_player.spawn_position = Vector2i(spawn_positions[assigned_slot])
		
		print("Assegnato ", current_player.name, " al ", group_layer_name, " con colore: ", current_player.color)
		
		# Passa direttamente l'istanza Player
		_parse_group_layer(map_node, group_layer_name, current_player)
	
	# Rimuove i layer dei gruppi non utilizzati
	for slot_id in available_slots:
		var unused_layer = map_node.find_child("group " + str(slot_id), true, false)
		if unused_layer:
			unused_layer.queue_free()

func _parse_group_layer(map_node: Node2D, layer_name: String, player: Player) -> void:
	
	# Cerca il layer gruppo indicato
	var entities_layer: TileMapLayer = map_node.find_child(layer_name, true, false)
	if not entities_layer:
		return

	# Recupero le info del player
	var player_race: Globals.RaceType = MatchData.get_player_race(player.player_id)

	# Scansiona tutte le tile presenti nel layer
	for cell_coords in entities_layer.get_used_cells():
		var atlas_coords = entities_layer.get_cell_atlas_coords(cell_coords)
		
		# Verifico se c'è corrispondenza di razza tra quanto indicato sulla
		# mappa e quanto scelto dal plaeyer. Se c'è discrepanza la risolve 
		# con un offset differente
		var tile_race: Globals.RaceType = Globals.RaceType.HUMAN
		var offset_tile = 381
		if player_race != tile_race:
			if tile_race == Globals.RaceType.HUMAN:
				offset_tile += 1
			else:
				offset_tile += -1
		var tile_id = offset_tile + (atlas_coords.y * 10) + atlas_coords.x 
		
		# Recupera la classe relativa al tile individuato e lo spawna
		if TILE_MAP_ENTITIES.has(tile_id):
			var spawn_info: Dictionary = TILE_MAP_ENTITIES[tile_id]
			var local_pos: Vector2 = entities_layer.map_to_local(cell_coords)
			var global_pos: Vector2 = entities_layer.to_global(local_pos)
			
			# Spawna l'entità iniettando l'istanza target_player
			spawn_entity_by_key(spawn_info["faction_key"], spawn_info["entity_key"], global_pos, player)
	
	# Nascondi il layer visivo dei tile logici a runtime
	entities_layer.queue_free()

## Risolve faction_key + entity_key nella scena corretta e istanzia l'entità.
## Ritorna il nodo spawnato, oppure null in caso di errore (già loggato).
func spawn_entity_by_key(faction_key: String, entity_key: String, global_pos: Vector2, player_owner: Player = null) -> Node:
	# --- Risoluzione della scena (doppio lookup con guardie) ---
	if not FACTION_SPAWN_DATABASE.has(faction_key):
		push_error("Fazione sconosciuta: '%s'" % faction_key)
		return null

	var faction_entities: Dictionary = FACTION_SPAWN_DATABASE[faction_key]
	if not faction_entities.has(entity_key):
		push_error("Entità '%s' non definita per la fazione '%s'" % [entity_key, faction_key])
		return null

	var entity_scene: PackedScene = faction_entities[entity_key]
	if entity_scene == null:
		push_error("Scena nulla per '%s'/'%s'" % [faction_key, entity_key])
		return null

	# --- Istanziazione ---
	var entity: Node = entity_scene.instantiate()
	if entity == null:
		push_error("instantiate() fallita per '%s'/'%s'" % [faction_key, entity_key])
		return null

	entities_root.add_child(entity)
	entity.global_position = global_pos

	# Iniezione diretta dell'istanza Player
	if is_instance_valid(player_owner):
		if "player_owner" in entity:
			entity.player_owner = player_owner
		
		if "player_color" in entity:
			entity.player_color = player_owner.color

	return entity

func _parse_entities_layer(map_node: Node2D, layer_name: String) -> void:
	
	# Cerca il layer gruppo indicato
	var entities_layer: TileMapLayer = map_node.find_child(layer_name, true, false)
	if not entities_layer:
		return
	
	# Scansiona tutte le tile presenti nel layer
	for cell_coords in entities_layer.get_used_cells():
		var atlas_coords = entities_layer.get_cell_atlas_coords(cell_coords)
		var tile_id = 381 + (atlas_coords.y * 10) + atlas_coords.x 
		
		# Recupera la classe relativa al tile individuato e lo spawna
		if TILE_MAP_ENTITIES.has(tile_id):
			var spawn_info: Dictionary = TILE_MAP_ENTITIES[tile_id]
			var local_pos: Vector2 = entities_layer.map_to_local(cell_coords)
			var global_pos: Vector2 = entities_layer.to_global(local_pos)
			
			# Spawn neutrale (owner_player = null)
			var spawned_entity = spawn_entity_by_key(spawn_info["faction_key"], spawn_info["entity_key"], global_pos, null)
			
			# Controlliamo se l'entità è di tipo ResourceBuilding
			if spawned_entity is ResourceBuilding:
				if spawned_entity.has_method("setup"):
					spawned_entity.setup(10000, true)
	
	entities_layer.queue_free()

## Chiamala subito dopo aver fatto add_child() della mappa caricata
#func _generate_dynamic_navmesh(map_tilemap_layer: TileMapLayer) -> void:
	#var nav_poly = nav_region.navigation_polygon
	#
	#if not nav_poly:
		#push_error("Nessun NavigationPolygon assegnato al NavigationRegion2D!")
		#return
#
	## 1. Puliamo eventuali perimetri di mappe precedenti
	#nav_poly.clear_outlines()
#
	#print("1. Attendo che i muri vengano caricati nella fisica...")
	#await get_tree().physics_frame
	#
	## 2. Calcoliamo le dimensioni totali della mappa in pixel
	#var used_rect = map_tilemap_layer.get_used_rect()
	#var tile_size = map_tilemap_layer.tile_set.tile_size
	#
	#var top_left = Vector2(used_rect.position) * Vector2(tile_size)
	#var bottom_right = Vector2(used_rect.end) * Vector2(tile_size)
	#
	## 3. Creiamo un array con i 4 angoli del rettangolo della mappa
	#var bounding_outline = PackedVector2Array([
		#top_left,
		#Vector2(bottom_right.x, top_left.y),
		#bottom_right,
		#Vector2(top_left.x, bottom_right.y)
	#])
	#
	## 4. Assegniamo il recinto al NavigationPolygon
	#nav_poly.add_outline(bounding_outline)
	#
	## 5. Impostiamo l'Agent Radius via codice (se non l'hai già fatto nell'editor)
	#nav_poly.agent_radius = 14.0 
	#
	## 6. Lanciamo il bake! 
	## Godot prenderà il rettangolo, sottrarrà i muri fisici, applicherà il raggio e creerà l'area blu.
	#nav_region.bake_navigation_polygon()
	#
	#print("NavMesh dinamica generata con successo!")

# ==========================================
# UI & HUD MANAGEMENT
# ==========================================
func _load_hud(scene_path: String) -> void:
	var hud_scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	if hud_scene == null:
		push_error("Could not load hud scene: " + scene_path)
		return
	
	var hud_instance: Node = hud_scene.instantiate()
	hud_instance.pause_menu.connect(self.on_show_pause_menu)
	hud_root.add_child(hud_instance)

# ==========================================
# PAUSE MENU
# ==========================================
func on_show_pause_menu(origin: String) -> void:
	get_tree().paused = true
	pause_root.open_menu("PauseMenu")

func on_close_pause_menu(origin: String) -> void:
	pause_root.close_all()
	get_tree().paused = false

func on_quit_game(origin: String) -> void:
	on_close_pause_menu("GameScene")
	quit_game()

func load_previous_menu(origin: String) -> void:
	var current_menu = get_node_or_null(origin)
	if current_menu:
		current_menu.hide()
	
	var scene = get_node_or_null(_previous_menu.pop_back())
	if scene:
		scene.show()

# ==========================================
# CAMERA CONTROLS
# ==========================================
func _setup_level_camera() -> void:
	if game_camera == null:
		push_warning("Nessun nodo Camera2D collegato a game_camera.")
		return
	
	if local_player == null:
		push_warning("Nessun player in gioco.")
		return

	# Leggiamo le dimensioni direttamente dal dizionario salvato per immediatezza
	var map_size: Vector2i = Vector2i(0, 0)
	if not MatchData.selected_map_data.is_empty():
		map_size = MatchData.selected_map_data["size"]
	else:
		push_warning("Dimensioni mappa non trovate nei dati di gioco.")
		return
		
	# Ricaviamo la dimensione in pixel del singolo tile (es. 32x32) dal TileSet del layer
	var tile_pixel_size: Vector2i = Vector2i(32, 32)
	if ground_layer != null and ground_layer.tile_set != null:
		tile_pixel_size = ground_layer.tile_set.tile_size
	
	# Calcoliamo l'estensione totale in pixel e dividiamo per 2 per trovare il punto mediano
	var world_size_px: Vector2 = Vector2(map_size.x * tile_pixel_size.x, map_size.y * tile_pixel_size.y)
	
	# Applichiamo la posizione globale alla telecamera
	game_camera.global_position = local_player.spawn_position
	game_camera.set_initial_zoom(0.8)
	print("🎥 Telecamera posizionata al centro della mappa: ", local_player.spawn_position)
	
	
	# Presumiamo che la mappa inizi alle coordinate (0,0) e finisca a world_size_px
	game_camera.limit_left = 0
	game_camera.limit_top = 0
	game_camera.limit_right = int(world_size_px.x)
	game_camera.limit_bottom = int(world_size_px.y)

	# Disattiviamo i limiti nativi di rendering per permettere all'HUD 
	# di "sconfinare" in coordinate negative
	game_camera.limit_left = -2000
	game_camera.limit_top = -2000
	game_camera.limit_right = 50000
	game_camera.limit_bottom = 50000

# ==========================================
# END GAME & SYSTEM
# ==========================================
func display_end_game_screen(victorious: bool, _triggering_player: Player = null) -> void:
	if end_game_screen_packed == null:
		push_error("Nessuna scena di EndGame assegnata nell'Inspector!")
		return

	remove_all_under_world()

	var end_game_screen_scene: Control = end_game_screen_packed.instantiate()
	end_game_screen_scene.setup_screen(victorious, player_list)
	
	var scene_handler: Node = get_node("/root/SceneHandler")
	if scene_handler:
		end_game_screen_scene.restart_scenario.connect(scene_handler.on_restart_scenario)
		end_game_screen_scene.main_menu.connect(scene_handler.on_restart_menu)
	
	transition_root.add_child(end_game_screen_scene)
		
	await get_tree().create_timer(3).timeout
	get_tree().paused = true

func remove_all_under_world() -> void:
	var world_node = get_node_or_null("World") 
	
	if world_node:
		for child in world_node.get_children():
			child.queue_free()
			
	var end_screen = get_node("CanvasLayer/EndGameScreen") 
	if end_screen:
		end_screen.show()

func quit_game() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()

# ==========================================
# LEGACY RPG MECHANICS
# ==========================================
func player_defeat() -> void:
	if local_player == null:
		return

	if end_game_screen_packed == null:
		push_error("Nessuna scena di EndGame assegnata nell'Inspector!")
		return
		
	var end_game_screen_scene: Control = end_game_screen_packed.instantiate()
	
	var scene_handler: Node = get_node_or_null("/root/SceneHandler")
	if scene_handler:
		end_game_screen_scene.restart_scenario.connect(scene_handler.on_restart_scenario)
		end_game_screen_scene.main_menu.connect(scene_handler.on_restart_menu)
	
	transition_root.add_child(end_game_screen_scene)
	end_game_screen_scene.setup_screen(false, player_list)


func enemy_death(exp_reward: int) -> void:
	if local_player != null:
		local_player.total_units_killed += 1 
	
	experience_gained(exp_reward)
	
	#if local_player.total_units_killed >= total_enemy:
		#display_end_game_screen(true)
	# FUTURE : Consderare di contare il numero di nemici per sapere se 
	# sono stati uccisi tuti opure di verificare se ci sono altri enemy

func experience_gained(exp_gain: int) -> void:
	if PlayerData.level >= PlayerData.MAX_LEVEL:
		return

	var new_experience : int = PlayerData.experience
	new_experience += exp_gain
	if new_experience >= PlayerData.LEVEL_THRESHOLDS[PlayerData.level + 1]:
		level_up(new_experience)
	else:
		PlayerData.experience = new_experience

func level_up(new_experience: int) -> void:
	new_experience -= PlayerData.LEVEL_THRESHOLDS[PlayerData.level - 1]
	PlayerData.level += 1
	PlayerData.experience = new_experience
	levelup.emit()
