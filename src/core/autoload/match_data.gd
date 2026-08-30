extends Node

# ==========================================
# CONSTANTS (PUNTEGGI)
# ==========================================



# ==========================================
# IMPOSTAZIONI DELLA PARTITA IN CORSO
# ==========================================
var game_mode: Globals.GameType = Globals.GameType.CAMPAIGN

# ==========================================
# IMPOSTAZIONI DELLA MAPPA SELEZIONATA
# ==========================================
var selected_map_path   : String = ""
var selected_map_data   : Dictionary = {} # Conterrà tutti i dati (nome, dimensione, giocatori)
var map_dimensions      : Vector2i = Vector2i.ZERO
var max_players         : int = 8
var your_race           : Globals.RaceType = Globals.RaceType.HUMAN
var map_resources       : Globals.MapResourcesType
var start_units         : Globals.StartUnitsType
var map_tileset         : Globals.MapTilesetType

# ==========================================
# ELENCO DEI GIOCATORI
# ==========================================
var number_of_opponents : int = 0
var participants_setup  : Dictionary = {}

# ==========================================
# ELENCO DELLE MAPPE CUSTOM (CACHE)
# ==========================================
var available_maps_cache: Array[Dictionary] = []
var _is_loading_maps    : bool = false


# ==========================================
# GESTIONE DEI DATI E RESET
# ==========================================
func reset_match_data() -> void:
	game_mode = Globals.GameType.CAMPAIGN
	
	selected_map_path = ""
	selected_map_data.clear()
	
	max_players = 8
	your_race = Globals.RaceType.MAP_DEFAULT
	map_resources = Globals.MapResourcesType.MAP_DEFAULT
	start_units = Globals.StartUnitsType.MAP_DEFAULT
	map_tileset = Globals.MapTilesetType.MAP_DEFAULT
	map_dimensions = Vector2i.ZERO
	
	number_of_opponents = 0
	participants_setup.clear()

# ==========================================
# FUNZIONI DI UTILITÀ (HELPER)
# ==========================================
func get_player_color(id: int) -> Color:
	if participants_setup.has(id):
		# Usa .get() come sicurezza in caso la chiave "color" manchi nel dizionario
		return participants_setup[id].get("color", Color.WHITE) 
	return Color.WHITE

func get_player_race(id: int) -> Globals.RaceType:
	if participants_setup.has(id):
		# Usa .get() come sicurezza in caso la chiave "color" manchi nel dizionario
		return participants_setup[id].get("race", Globals.RaceType.HUMAN)
	return Globals.RaceType.HUMAN

func get_player_team(id: int) -> int:
	if participants_setup.has(id):
		# Usa .get() come sicurezza in caso la chiave "color" manchi nel dizionario
		return participants_setup[id].get("team", 0)
	return 0

func get_active_players_count() -> int:
	return participants_setup.size()

func get_active_player_ids() -> Array:
	return participants_setup.keys()

func get_player_info(id: int) -> Dictionary:
	if participants_setup.has(id):
		return participants_setup[id]
	return {}

# ==========================================
# PRECARICAMENTO MAPPE
# ==========================================
func preload_maps(folder_path: String) -> void:
	if not available_maps_cache.is_empty() or _is_loading_maps:
		return
		
	_is_loading_maps = true
	var dir = DirAccess.open(folder_path)
	
	if dir:
		# get_files() è il metodo moderno di Godot 4 per scansionare le cartelle
		for file_name in dir.get_files():
			if file_name.ends_with(".scn"):
				var full_path = folder_path + "/" + file_name
				var map_scene: PackedScene = load(full_path)
				
				if map_scene:
					var map_instance = map_scene.instantiate()
					
					var display_name = file_name.get_basename().capitalize()
					var map_size: Vector2i = Vector2i.ZERO
					var ground_layer: TileMapLayer = map_instance.find_child("ground", true, false)
					
					if ground_layer:
						map_size = ground_layer.get_used_rect().size
					
					# Variabili locali rinominate (meta_*) per evitare conflitti coi nomi in alto
					var meta_max_players = map_instance.get_meta("max_players") if map_instance.has_meta("max_players") else 2
					var meta_def_race = map_instance.get_meta("default_race_player") if map_instance.has_meta("default_race_player") else Globals.RaceType.HUMAN
					var meta_def_res = map_instance.get_meta("default_resources_player") if map_instance.has_meta("default_resources_player") else Globals.MapResourcesType.LOW
					var meta_def_units = map_instance.get_meta("default_start_unit_player") if map_instance.has_meta("default_start_unit_player") else Globals.StartUnitsType.ONE_PEASANT_ONLY
					
					available_maps_cache.append({
						"file_path": full_path,
						"name": display_name,
						"size": map_size,
						"max_players": meta_max_players,
						"default_race_player": meta_def_race,
						"default_resources_player": meta_def_res,
						"default_start_unit_player": meta_def_units
					})
					
					# Usiamo free() immediato invece di queue_free() 
					# perché il nodo non fa parte del SceneTree
					map_instance.free()
					
					# Pausa magica per evitare i freeze
					await get_tree().process_frame
					
	_is_loading_maps = false
