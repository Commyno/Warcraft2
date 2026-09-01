class_name BuildingData
extends Resource

enum Faction { ALLIANCE, HORDE, NEUTRAL }
enum BuildingType { PRODUCTION, ECONOMY, DEFENSE, TECH }

# ==========================================
# IDENTITÀ E GRAFICA
# ==========================================
@export_group("Identity")
@export var building_id: String = ""         # es. "farm", "barracks", "town_hall"
@export var building_name: String = ""       # es. "Barracks"
@export_multiline var description: String = ""
@export var faction: Faction = Faction.ALLIANCE
@export var building_type: BuildingType = BuildingType.PRODUCTION
@export var icon: Texture2D                  # Icona per il menu di costruzione del Peon
@export var building_scene: PackedScene      # Scena .tscn dell'edificio completo

# ==========================================
# GRIGLIA E POSIZIONAMENTO (TileMap / Grid)
# ==========================================
@export_group("Placement")
@export var tile_size: Vector2i = Vector2i(3, 3) # Ingombro in tile (es. Farm 2x2, Barracks 3x3, Town Hall 4x4)
@export var requires_water: bool = false         # True per Shipyard, Oil Platform, Foundry

# ==========================================
# COSTI E COSTRUZIONE
# ==========================================
@export_group("Construction & Economy")
@export var gold_cost: int = 700
@export var wood_cost: int = 450
@export var oil_cost: int = 0
@export var build_time: float = 80.0             # Secondi necessari alla costruzione

# ==========================================
# STATISTICHE DIFENSIVE E VISIVE
# ==========================================
@export_group("Attributes")
@export var max_health: int = 800
@export var base_armor: int = 20                 # Gli edifici in WC2 hanno armatura alta
@export var sight_range: int = 4                 # Raggio visivo (in tile)

# ==========================================
# CAPACITÀ SPECIALI / SUPPORTO
# ==========================================
@export_group("Capabilities")
@export var food_provided: int = 0               # es. +4 per Farm/Pig Farm, +1 per Town Hall/Great Hall
@export var is_resource_dropoff: bool = false    # True per Town Hall, Lumber Mill, Refinery
@export var accepts_gold: bool = false
@export var accepts_wood: bool = false
@export var accepts_oil: bool = false

# ==========================================
# COMBATTIMENTO (Torri difensive)
# ==========================================
@export_group("Combat (Defensive Towers)")
@export var can_attack: bool = false             # True per Guard Tower, Cannon Tower
@export var basic_damage: int = 0
@export var piercing_damage: int = 0
@export var attack_range: float = 0.0
@export var attack_cooldown: float = 1.0
@export var can_attack_air: bool = false
@export var can_attack_ground: bool = true
