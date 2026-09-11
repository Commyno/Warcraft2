class_name UnitData
extends CostData

# ==========================================
# IDENTITÀ E GRAFICA
# ==========================================
@export_group("Identity")
@export var id: String = ""            # es. "footman", "grunt", "peon"
@export var name: String = ""          # es. "Footman"
@export_multiline var description: String = ""
@export var faction: Globals.FactionType = Globals.FactionType.ALLIANCE
@export var type: Globals.UnitType = Globals.UnitType.LAND
@export var icon: Texture2D
@export var scene: PackedScene         # Scena .tscn dell'unità sul campo
@export var shortcut_key: Key

# ==========================================
# COSTI E TEMPI DI PRODUZIONE
# ==========================================
@export_group("Production & Economy")
@export var training_time: float = 60.0     # Tempo di addestramento in secondi

# ==========================================
# STATISTICHE BASE DI VITA E MOVIMENTO
# ==========================================
@export_group("Attributes")
@export var max_health: int = 60
@export var health_regen: float = 0.25      # Vita rigenerata al secondo
@export var max_mana: int = 0               # 255 per Mage, Paladin, Death Knight, Ogre-Mage
@export var mana_regen: float = 0.0         # Mana rigenerata al secondo
@export var basic_armor: int = 2
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
@export var damage_type: Globals.DamageType = Globals.DamageType.NORMAL
