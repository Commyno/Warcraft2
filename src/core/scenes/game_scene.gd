class_name GameScene
extends Node

signal levelup

# ==========================================
# CONSTANTS (SCENE UIDs)
# ==========================================
const HUD_ROOT_UID           : String = "uid://ssce78o0mjpg"

# Mappatura dei Tile ID di "logic" / "group 0" verso le scene del gioco
#const ENVIRONMENT_TILE_ENTITIES = {
	#455: preload("res://src/gameplay/entities/buildings/neutral/gold_mine.tscn"),
#}
#
#const HUMANS_TILE_ENTITIES = {
	#381: preload("res://src/gameplay/entities/units/humans/peasant.tscn"),
	#421: preload("res://src/gameplay/entities/buildings/humans/TownHall.tscn"),
#}
#
#const ORCS_TILE_ENTITIES = {
	#382: preload("res://src/gameplay/entities/units/humans/peasant.tscn"),
	#422: preload("res://src/gameplay/entities/buildings/humans/TownHall.tscn"),
#}

const TILE_MAP_ENTITIES = {
	381: preload("res://src/gameplay/entities/units/humans/peasant.tscn"),
	382: preload("res://src/gameplay/entities/units/humans/peasant.tscn"),
	421: preload("res://src/gameplay/entities/buildings/humans/TownHall.tscn"),
	422: preload("res://src/gameplay/entities/buildings/humans/TownHall.tscn"),
	455: preload("res://src/gameplay/entities/buildings/neutral/gold_mine.tscn")
}

# ==========================================
# VARIABLES
# ==========================================
var _previous_menu: Array = []
var _current_level : Node = null 
var ground_layer   : TileMapLayer = null

var total_enemy    : int = 0
var player         : Player = null # Giocatore Locale Umano
var spawn_positions: Dictionary = {} # Conterrà { slot_id : Vector2 }

@export var end_game_screen_packed : PackedScene = null
@export var confirm_end_game_menu_packed : PackedScene = null

# ==========================================
# ONREADY: GAME WORLD NODES
# ==========================================
# Queste variabili TileMapLayer potrebbero inizialmente essere vuote/nulle
# ma le ripopoleremo dinamicamente al caricamento della mappa
@onready var nav_region        : NavigationRegion2D = $World/NavigationRegion2D
@onready var level_root        : Node2D       = $World/NavigationRegion2D/LevelRoot
@onready var entities_root     : Node2D       = $World/NavigationRegion2D/EntitiesRoot
@onready var effects_root      : Node2D       = $World/NavigationRegion2D/EffectsRoot
@onready var players           : Node2D       = $Players

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
	_load_map()
	_init_players()
	_load_hud(HUD_ROOT_UID)
	_setup_level_camera()
	# 1. (Opzionale ma consigliato) Se vuoi impostare l'Agent Radius via codice prima del bake:
#	var nav_poly = nav_region.navigation_polygon
#	if nav_poly:
#		nav_poly.agent_radius = 32.0 # Metti qui il valore desiderato (es. 16 o 24)
	
# ==========================================
# LEVEL & MAP LOADING
# ==========================================
func _load_map() -> void:
	# 1. Recuperiamo il path della mappa dall'Autoload
	if MatchData.selected_map_path.is_empty() or not ResourceLoader.exists(MatchData.selected_map_path):
		push_error("Could not load level from custom map: " + MatchData.selected_map_path)
		return

	# 2. Recuperiamo il percorso della mappa direttamente da MatchData
	var map_path: String = MatchData.selected_map_path
	
	if map_path == "":
		push_error("Nessun percorso mappa valido in MatchData.selected_map_path!")
		return

	# 3. Pulizia preliminare del livello
	for child in level_root.get_children():
		if child.name != "EntitiesRoot" and child.name != "EffectsRoot":
			child.queue_free()
	
	# 4. Caricamento sincrono della scena .scn
	var map_res: PackedScene = load(map_path)
		
	if not map_res:
		push_error("Impossibile caricare la risorsa mappa: " + map_path)
		return
		
	# 5. Istanziamo la mappa esportata da YATI (.scn)
	var map_instance: Node2D = map_res.instantiate()
	level_root.add_child(map_instance)
	
	# 6. Recuperiamo il ground layer e lo riassegnamo al nodo padre
	var new_ground = map_instance.find_child("ground", true, false)
	if new_ground is TileMapLayer: 
		ground_layer = new_ground
		GridManager.tile_map_layer = new_ground
		new_ground.reparent(level_root) #nav_region
		new_ground.position = Vector2.ZERO # Azzera l'offset rispetto alla region

	# 6. Gestione logica
	#Gestione degli spawn point
	_parse_spawn_points(map_instance)

	#Per ogni spawnpoint recuperiamo e aggiungiamo il relativo gruppo alla mappa
	_parse_players(map_instance)

	#Per ogni spawnpoint recuperiamo e aggiungiamo il relativo gruppo alla mappa
	#_parse_miscellaneous_layer(map_instance, "resources")
	_parse_entities_layer(map_instance, "environment")

	# Generazione automatica dell'area di navigazione
	#_setup_navigation(map_instance)
	#_generate_dynamic_navmesh(ground_layer)

func _parse_spawn_points(map_node: Node2D) -> void:	
	spawn_positions.clear()
	
	# Cerchiamo il Livello Oggetti creato in Tiled
	var spawn_layer = map_node.find_child("spawn point", true, false)
	if not spawn_layer:
		push_warning("Nessun layer 'spawnlayer' trovato nella mappa!")
		return
		
	# Cicliamo su tutti gli oggetti piazzati in quel layer
	for spawn_obj in spawn_layer.get_children():
		# Controlliamo se l'oggetto ha la proprietà slot_id
		if spawn_obj.has_meta("slot_id"):
			var s_id = spawn_obj.get_meta("slot_id")
			
			# Salviamo la posizione globale dell'oggetto per quello slot
			spawn_positions[s_id] = spawn_obj.global_position
			
			# Distruggiamo l'oggetto segnaposto (non vogliamo che si veda la grafica statica in gioco)
			spawn_obj.queue_free()
	
	spawn_layer.queue_free()

func _parse_players(map_node: Node2D) -> void:
	# Recuperiamo l'elenco dei giocatori che si sono uniti alla partita tramite MatchData
	var active_players = MatchData.get_active_player_ids()
	
	# Recuperiamo il numero di slot totali supportati dalla mappa 
	# (usa il fallback a 2 se per caso il dato non dovesse esistere)
	var max_slots: int = MatchData.selected_map_data.get("max_players", 2)

	if active_players.size() > max_slots:
		push_error("Ci sono più giocatori attivi che slot di partenza sulla mappa!")
		# FUTURE : Gestire lato utente questo errore.
	
	# Creiamo un array con gli slot disponibili (es. per 4 max_players avremo [0, 1, 2, 3])
	var available_slots: Array[int] = []
	for i in range(max_slots):
		available_slots.append(i)
		
	# Mescolamento casuale cosi da cambiare posizione di inizio ad ogni partita
	available_slots.shuffle()
	
	# Cicliamo su tutti i giocatori attivi e assegniamo loro uno slot
	for i in range(active_players.size()):
		var player_id = active_players[i]
		
		# Controllo di sicurezza: evitiamo crash se abbiamo inserito troppi giocatori
		if available_slots.size() == 0:
			push_error("Ci sono più giocatori attivi che slot di partenza sulla mappa!")
			break
			
		var assigned_slot = available_slots.pop_front()
		var group_layer_name = "group " + str(assigned_slot)
		
		var player_color = MatchData.get_player_color(player_id)
		print("Assegnato Player ID: ", player_id, " al ", group_layer_name, " con colore: ", player_color)
		
		# Passiamo alla funzione il nodo mappa, il nome del layer da cercare e l'ID del giocatore
		_parse_group_layer(map_node, group_layer_name, player_id)
	
	if available_slots.size() > 0:
		for slot_id in available_slots:
			var group_layer_name = "group " + str(slot_id)
			var entities_layer: TileMapLayer = map_node.find_child(group_layer_name, true, false)
			entities_layer.queue_free()
			# FUTURE oppure dopo cancella tutto il nodo mappa.

func _parse_group_layer(map_node: Node2D, layer_name: String, player_id: int) -> void:
	
	# Cerca il layer gruppo indicato
	var entities_layer: TileMapLayer = map_node.find_child(layer_name, true, false)
	if not entities_layer:
		return

	# Recupero le info del player
	var player_race = MatchData.get_player_race(player_id)

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
			var entity_scene: PackedScene = TILE_MAP_ENTITIES[tile_id]

			var local_center_pos: Vector2 = entities_layer.map_to_local(cell_coords)
			var local_center_pos_global: Vector2 = entities_layer.to_global(local_center_pos)

			var spawned_entity = spawn_entity(entity_scene, local_center_pos_global, player_id)
			if spawned_entity == null:
				push_error("Impossibile spawnare entità legata al tile: " + tile_id)
				continue
			
			# Controlliamo se l'entità è di tipo BaseBuilding
			if spawned_entity is BaseBuilding:
				spawned_entity.complete_construction()
		
	# Nascondi il layer visivo dei tile logici a runtime
	#entities_layer.visible = false
	entities_layer.queue_free()

func spawn_entity(entity_type: Resource, spawn_position: Vector2, player_id: int = -1) -> Node2D:
	# 1. Instanzia la nuova entità
	var entity_instance = entity_type.instantiate()
	
	# 2. La aggiunge alla mappa
	entities_root.add_child(entity_instance)
	
	# 3. Applichiamo la posizione globale finale
	entity_instance.global_position = spawn_position
	
	# 4. Completiamo con le  info del player
	if player_id >= 0:
		# Assegnazione fondamentale del id giocatore e del colore!
		if "player_id" in entity_instance:
			entity_instance.player_id = player_id
		if "player_color" in entity_instance:
			var player_color = MatchData.get_player_color(player_id)
			entity_instance.player_color = player_color

	return entity_instance

func _parse_entities_layer(map_node: Node2D, layer_name: String) -> void:
	
	# Cerca il layer gruppo indicato
	var entities_layer: TileMapLayer = map_node.find_child(layer_name, true, false)
	if not entities_layer:
		return
	
	# Scansiona tutte le tile presenti nel layer
	for cell_coords in entities_layer.get_used_cells():
		var atlas_coords = entities_layer.get_cell_atlas_coords(cell_coords)
		
		# Recupero l'id del tile di riferimento
		var tile_id = 381 + (atlas_coords.y * 10) + atlas_coords.x 
		
		# Recupera la classe relativa al tile individuato e lo spawna
		if TILE_MAP_ENTITIES.has(tile_id):
			var entity_scene: PackedScene = TILE_MAP_ENTITIES[tile_id]
			
			var local_center_pos: Vector2 = entities_layer.map_to_local(cell_coords)
			var local_center_pos_global: Vector2 = entities_layer.to_global(local_center_pos)
			
			var spawned_entity = spawn_entity(entity_scene, local_center_pos_global)
			if spawned_entity == null:
				push_error("Impossibile spawnare entità legata al tile: " + tile_id)
				continue
			
			# Controlliamo se l'entità è di tipo BaseBuilding
			if spawned_entity is BaseResourceBuilding:
				if spawned_entity.has_method("setup"):
					spawned_entity.setup(10000, true)
	
	# Nascondi il layer visivo dei tile logici a runtime
	#entities_layer.visible = false
	entities_layer.queue_free()
	
#func _parse_miscellaneous_layer(map_node: Node2D, layer_name: String) -> void:
	## Cerchiamo il Livello Oggetti creato in Tiled
	#var entities_layer = map_node.find_child(layer_name, true, false)
	#if not entities_layer:
		#push_warning("Nessun layer " + layer_name + " trovato nella mappa!")
		#return
	#
	## Scansiona tutte le tile presenti nel layer
	#for spawn_obj in entities_layer.get_children():
		## Controlliamo se l'oggetto ha la proprietà slot_id
		#var resource_amount = 10000
		#if spawn_obj.has_meta("resource_amount"):
			#resource_amount = spawn_obj.get_meta("resource_amount")
		#var objectobj_class = spawn_obj.get_meta("class")
#
		#var tile_id = 381 #+ (atlas_coords.y * 10) + atlas_coords.x 
		#
		## Recupera la classe relativa al tile individuato e lo spawna
		#if TILE_MAP_ENTITIES.has(tile_id):
			#var entity_scene: PackedScene = TILE_MAP_ENTITIES[tile_id]
#
		## 1. Convertiamo la posizione globale in posizione locale rispetto al TileMapLayer
			#var local_pos = entities_layer.to_local(spawn_obj.global_position)
			#
			## 2. Troviamo le coordinate della griglia (es. Vector2i(5, 12))
			#var coords = entities_layer.local_to_map(local_pos)
#
			## 1. Converte le coordinate della griglia in posizione locale (spesso restituisce l'angolo in alto a sinistra del tile)
			#var local_center_pos_global = entities_layer.map_to_local(coords)
				#
			#var spawned_entity = spawn_entity(entity_scene, local_center_pos_global)
			#if spawned_entity == null:
				#push_error("Impossibile spawnare entità legata al tile: " + tile_id)
				#continue
			#
			## Posizionamento differenziato in base al tipo di entità
			#if spawned_entity is BaseResourceBuilding:
				#if spawned_entity.has_method("setup"):
					#spawned_entity.setup(10000, true)
	#
	## Nascondi il layer visivo dei tile logici a runtime
	##entities_layer.visible = false
	#entities_layer.queue_free()

#func _setup_navigation(map_node: Node2D) -> void:
	#var nav_layer: TileMapLayer = map_node.find_child("Navigation", true, false)
	#if nav_layer:
		#nav_layer.visible = false # Nascondi la griglia visiva in gioco

# Chiamala subito dopo aver fatto add_child() della mappa caricata
func _generate_dynamic_navmesh(map_tilemap_layer: TileMapLayer) -> void:
	var nav_poly = nav_region.navigation_polygon
	
	if not nav_poly:
		push_error("Nessun NavigationPolygon assegnato al NavigationRegion2D!")
		return

	# 1. Puliamo eventuali perimetri di mappe precedenti
	nav_poly.clear_outlines()

	print("1. Attendo che i muri vengano caricati nella fisica...")
	await get_tree().physics_frame
	
	# 2. Calcoliamo le dimensioni totali della mappa in pixel
	var used_rect = map_tilemap_layer.get_used_rect()
	var tile_size = map_tilemap_layer.tile_set.tile_size
	
	var top_left = Vector2(used_rect.position) * Vector2(tile_size)
	var bottom_right = Vector2(used_rect.end) * Vector2(tile_size)
	
	# 3. Creiamo un array con i 4 angoli del rettangolo della mappa
	var bounding_outline = PackedVector2Array([
		top_left,
		Vector2(bottom_right.x, top_left.y),
		bottom_right,
		Vector2(top_left.x, bottom_right.y)
	])
	
	# 4. Assegniamo il recinto al NavigationPolygon
	nav_poly.add_outline(bounding_outline)
	
	# 5. Impostiamo l'Agent Radius via codice (se non l'hai già fatto nell'editor)
	nav_poly.agent_radius = 14.0 
	
	# 6. Lanciamo il bake! 
	# Godot prenderà il rettangolo, sottrarrà i muri fisici, applicherà il raggio e creerà l'area blu.
	nav_region.bake_navigation_polygon()
	
	print("NavMesh dinamica generata con successo!")

# ==========================================
# PLAYER SETUP
# ==========================================
func _init_players() -> void:
	if MatchData.participants_setup.is_empty():
		push_error("ATTENZIONE: Nessun giocatore trovato in MatchData!")
		return

	for player_id in MatchData.participants_setup.keys():
		var config_giocatore = MatchData.participants_setup[player_id]
		
		var nuovo_player = Player.new()
		nuovo_player.name = "Player_" + str(player_id)
		players.add_child(nuovo_player)
		
		# ---- ASSEGNAZIONE SPAWN ----
		var spawn_pos = Vector2.ZERO 
		if spawn_positions.has(player_id):
			spawn_pos = spawn_positions[player_id]
		else:
			push_warning("Spawn non trovato per il player " + str(player_id) + "! Verrà spawnato a 0,0.")
		# ----------------------------
		
		nuovo_player.setup(player_id, spawn_pos, config_giocatore)
		nuovo_player.game_over.connect(display_end_game_screen.bind(nuovo_player))
		
		if config_giocatore.get("type", "") == "Human":
			player = nuovo_player 
		
		print("✅ Creato in gioco: ", nuovo_player.name, " allo spawn ", spawn_pos)
		
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
	
	if player == null:
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
	game_camera.global_position = player.spawn_position
	game_camera.set_initial_zoom(0.8)
	print("🎥 Telecamera posizionata al centro della mappa: ", player.spawn_position)
	
	
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
	var tutti_i_giocatori = players.get_children()
	end_game_screen_scene.setup_screen(victorious, tutti_i_giocatori)
	
	var scene_handler: Node = get_node("/root/SceneHandler")
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
	if player == null:
		return

	if end_game_screen_packed == null:
		push_error("Nessuna scena di EndGame assegnata nell'Inspector!")
		return
		
	var end_game_screen_scene: Control = end_game_screen_packed.instantiate()
	var tutti_i_giocatori = players.get_children()
	
	var scene_handler: Node = get_node("/root/SceneHandler")
	end_game_screen_scene.restart_scenario.connect(scene_handler.on_restart_scenario)
	end_game_screen_scene.main_menu.connect(scene_handler.on_restart_menu)
	
	transition_root.add_child(end_game_screen_scene)
	end_game_screen_scene.setup_screen(false, tutti_i_giocatori)


func enemy_death(exp_reward: int) -> void:
	if player != null:
		player.total_units_killed += 1 
	
	experience_gained(exp_reward)
	
	if player != null and player.total_units_killed >= total_enemy:
		display_end_game_screen(true)

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
