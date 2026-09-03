class_name MapData
extends Resource

@export_category("Info Base")
@export var map_name: String = "Nuova Mappa"
@export var description: String = ""
@export var cover_image: Texture2D
@export var size: Vector2i = Vector2i(64, 64)

@export_category("Terreno e Natura")
# Il TileSet da utilizzare per questa mappa (es. Summer, Wasteland, Winter)
@export var map_tileset: TileSet
# Coordinate del tile nell'atlante (es. (0,0)=Erba, (1,0)=Acqua, (-1,-1)=Vuoto)
@export var ground_tile_grid: Array[Vector2i] = [] 
# Valore di legno per ogni tile. Array di (size.x * size.y) elementi.
# 0 = Nessun albero. > 0 = Quantità di legno.
@export var forest_grid: Array[int] = []
@export var marker_tile_grid: Array[int] = []

@export_category("Entità (Edifici, Unità, Miniere)")
# Entità complesse, neutrali e non.
# Es: {"type": "gold_mine", "pos": Vector2i(10, 15), "amount": 5000}
# Es: {"type": "wall", "pos": Vector2i(20, 21), "life": 1000}
# Es: {"type": "peon", "pos": Vector2i(13, 15), "slot_id": 1} # <-- slot_id invece di player!
@export var entities_data: Array[Dictionary] = [] 

@export_category("Setup Giocatori (Spawn)")
# Dati di partenza associati agli slot. 
# Es: {"slot_id": 1, "start_pos": Vector2i(10, 10), "gold": 500, "lumber": 200}
@export var max_players: int = 4
@export var default_race_player: Globals.RaceType = Globals.RaceType.HUMANS
@export var default_resources_player: Globals.MapResourcesType = Globals.MapResourcesType.MEDIUM
@export var default_start_unit_player: Globals.StartUnitsType = Globals.StartUnitsType.ONE_PEASANT_ONLY
@export var player_spawn_points: Array[Dictionary] = []

@export_category("Regole e Triggers")
# Es: {"type": "kill_all"}, {"type": "survive_time", "minutes": 20}
@export var objectives: Array[Dictionary] = []
# Opzionale: Punti di interesse invisibili per script di mappa o IA
# Es: {"name": "imboscata", "pos": Vector2i(30, 40)}
@export var action_points: Array[Dictionary] = []
