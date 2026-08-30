class_name UnitData
extends Resource

enum Faction { ALLIANCE, HORDE, NEUTRAL }
enum UnitType { LAND, AIR, SEA }

# ==========================================
# IDENTITÀ E GRAFICA
# ==========================================
@export_group("Identity")
@export var unit_id: String = ""            # es. "footman", "grunt", "peon"
@export var unit_name: String = ""          # es. "Footman"
@export_multiline var description: String = ""
@export var faction: Faction = Faction.ALLIANCE
@export var unit_type: UnitType = UnitType.LAND
@export var icon: Texture2D
@export var unit_scene: PackedScene         # Scena .tscn dell'unità sul campo

# ==========================================
# COSTI E TEMPI DI PRODUZIONE
# ==========================================
@export_group("Production & Economy")
@export var gold_cost: int = 600
@export var wood_cost: int = 0
@export var oil_cost: int = 0
@export var food_cost: int = 1
@export var training_time: float = 60.0     # Tempo di addestramento in secondi

# ==========================================
# STATISTICHE BASE DI VITA E MOVIMENTO
# ==========================================
@export_group("Attributes")
@export var max_health: int = 60
@export var base_armor: int = 2
@export var max_mana: int = 0               # 255 per Mage, Paladin, Death Knight, Ogre-Mage
@export var sight_range: int = 4            # Raggio visivo (in tile o unità di misura)
@export var move_speed: float = 100.0       # Velocità in pixel/sec (mappata dallo "Speed: 10" di WC2)

# ==========================================
# COMBATTIMENTO
# ==========================================
@export_group("Combat")
@export var basic_damage: int = 6           # Danno base (soggetto a riduzione dall'Armor nemica)
@export var piercing_damage: int = 3        # Danno perforante (ignora l'Armor nemica)
@export var attack_range: float = 32.0      # Gittata (es. 32px melee ~ 1 tile; 128px ranged ~ 4 tiles)
@export var attack_cooldown: float = 1.2    # Secondi tra un fendente/freccia e l'altro
@export var can_attack_air: bool = false
@export var can_attack_ground: bool = true
