class_name BaseBuilding
extends StaticBody2D

enum BuildingState { IDLE, ACTIVE, DEPLETED, DESTROYED, INACTIVE }

# --- PARAMETRI CONFIGURABILI ---
@export_group("Edificio")
@export var player_owner: Player # Assegnato allo spawn o tramite editor
@export var player_color: Color = Color.BLUE : set = _set_player_color
@export var spritesheet: Texture2D

@export_group("Azioni e Abilità")
@export var available_actions: Array[ActionData]

# --- PARAMETRI DI COSTRUZIONE ---
@export_group("Costruzione")
@export var is_under_construction: bool = false
@export var region_under_construction: Rect2
@export var region_first_step_build: Rect2
@export var region_second_step_build: Rect2
@export var region_completed: Rect2
@export var region_idle: Rect2
@export var region_active: Rect2
@export var region_depleted: Rect2

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
@export var build_time: float = 80.0             # Secondi necessari alla costruzione

# ==========================================
# STATISTICHE DIFENSIVE E VISIVE
# ==========================================
@export_group("Attributes")
@export var basic_armor: int = 20                 # Gli edifici in WC2 hanno armatura alta
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
@export var can_destroy: bool = true             # False per Mine
@export var basic_damage: int = 0
@export var piercing_damage: int = 0
@export var attack_range: float = 0.0
@export var attack_cooldown: float = 1.0
@export var can_attack_air: bool = false
@export var can_attack_ground: bool = true

# --- RIFERIMENTI NODI ---
@onready var sprite2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var nav_obstacle: NavigationObstacle2D = $NavigationObstacle2D

# --- COMPONENTS ---
@onready var selectable_component: SelectableComponent = get_node_or_null("SelectableComponent")
@onready var health_component: HealthComponent = $HealthComponent

# --- SEGNALI ---
signal upgrade_completed(new_building_data: BuildingData)
signal construction_completed
signal construction_progress_updated(current_hp: float, max_hp: float)
signal work_completed
signal depleted()
signal destroyed()

# --- VARIABILI INTERNE ---
var entity_id: String
var player_id: int = -1 : get = _get_player_id
var entity_name: String = "" :
	get:
		if  selectable_component:
			return selectable_component.display_name
		return ""
var description: String = "" :
	get:
		if  selectable_component:
			return selectable_component.display_description
		return ""
var icon:  Texture :
	get:
		if  selectable_component:
			return selectable_component.icon
		return Globals.NO_IMAGE

var is_depleted: bool = false
var is_destroyed: bool = false
var current_health: int:
	get():
		if health_component:
			return int(health_component.health)
		return 0

var active_builders: Array[Node2D] = []
var construction_progress_perc: float = 0.0 # Da 0.0 a 1.0
var training_progress_perc: float = 0.0 # Da 0.0 a 1.0

func _ready() -> void:
	add_to_group("buildings")
	
	available_actions = available_actions.duplicate()
	
	# 1. Nascondi il cerchio di selezione all'avvio
	if selectable_component:
		selectable_component.deselect()
	
	if health_component:
		health_component.process_mode = Node.PROCESS_MODE_DISABLED
	
	if spritesheet and sprite2d:
		sprite2d.texture = spritesheet
		sprite2d.region_enabled = true
		
	# Inizializza l'ostacolo per la navmesh
	if nav_obstacle:
		nav_obstacle.affect_navigation_mesh = false
	
	# Gestione dello stato iniziale (già costruito)
	active_builders.clear()	
	_set_building_region(region_completed)
	
	deselect()

func _process(delta: float) -> void:
	if is_under_construction and not active_builders.is_empty():
		_advance_construction(delta)

func setup(data: Resource) -> void:
	self.entity_id = data.id

	# Components
	if selectable_component:
		selectable_component.setup(data)
	if health_component:
		health_component.setup(data)

	self.tile_size = data.tile_size
	self.requires_water = data.requires_water
	self.build_time = data.build_time
	self.basic_armor = data.basic_armor
	self.sight_range = data.sight_range
	self.food_provided = data.food_provided
	self.is_resource_dropoff = data.is_resource_dropoff
	self.accepts_gold = data.accepts_gold
	self.accepts_wood = data.accepts_wood
	self.accepts_oil = data.accepts_oil
	self.can_attack = data.can_attack
	self.basic_damage = data.basic_damage
	self.piercing_damage = data.piercing_damage
	self.attack_range = data.attack_range
	self.attack_cooldown = data.attack_cooldown
	self.can_attack_air = data.can_attack_air
	self.can_attack_ground = data.can_attack_ground
	
func _get_player_id() -> int:
	if is_instance_valid(player_owner):
		return player_owner.player_id
	return -1

func _set_player_color(color: Color) -> void:
	player_color = color
	_apply_team_color(color)

func _apply_team_color(color: Color) -> void:
	pass

func get_health_perc() -> float:
	if health_component:
		return health_component.get_health_percentage()
	return 0

func get_available_actions() -> Array[ActionData]:
	return available_actions

func is_damaged() -> bool:
	if health_component:
		return health_component.is_damaged() and not is_under_construction
	return false

# --- SISTEMA DI SELEZIONE ---

func select() -> void:
	if selectable_component: selectable_component.select()

func deselect() -> void:
	if selectable_component: selectable_component.deselect()

func is_selected() -> bool:
	return selectable_component.is_selected if selectable_component else false

# --- SISTEMA DI DANNO E DISTRUZIONE ---

func take_damage(amount: float) -> void:
	if is_destroyed:
		return
		
	if health_component:
		health_component.damage(amount)
		print(name, " ha subito ", amount, " danni! Vita attuale: ", health_component.health)

# TODO: Passare la funzione di morte al component
func die() -> void:
	destroy_building()

func heal(amount: float) -> void:
	if is_destroyed:
		return
		
	# Aumenta la vita, ma non oltre il massimo consentito
	if health_component:
		health_component.restore(amount)

func destroy_building() -> void:
	player_owner.register_building_lost(entity_id, food_provided)
	
	is_destroyed = true
	destroyed.emit()
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if nav_obstacle:
		nav_obstacle.affect_navigation_mesh = false
	# Nasconde la barra della vita
	if health_component:
		health_component.hide_health_bar()
		
	print(name, " è stato distrutto!")
	
	spawn_rubble()
	queue_free()

## Rende l'edificio una decorazione inerte: niente collisioni,
## navmesh, selezione, input o logica di processo.
func _disable_interactivity() -> void:
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if nav_obstacle:
		nav_obstacle.affect_navigation_mesh = false
	# Nasconde la barra della vita
	if health_component:
		health_component.hide_health_bar()
	if selectable_component:
		selectable_component.deselect()

	# Blocca il click-picking sul corpo fisico (StaticBody2D è un CollisionObject2D)
	input_pickable = false

	# Esce da tutti i gruppi che lo rendono bersagliabile/selezionabile
	remove_from_group("interactable")
	remove_from_group("selectable_units")  # rimuovi/aggiungi i gruppi che usi davvero

	# Ferma qualsiasi logica per-frame (costruzione, ecc.)
	set_process(false)

func spawn_rubble() -> void:
	if not sprite2d or not sprite2d.texture:
		return
		
	var rubble = Sprite2D.new()
	rubble.texture = sprite2d.texture
	rubble.region_enabled = sprite2d.region_enabled
	rubble.region_rect = sprite2d.region_rect # FONDAMENTALE PER NON MOSTRARE TUTTO L'ATLAS
	rubble.global_position = global_position
	rubble.modulate = Color(0.2, 0.2, 0.2, 0.8)
	
	get_parent().add_child(rubble)

func apply_upgrade(new_building_data: BuildingData) -> void:
	# 1. Calcola la percentuale di vita attuale

	
	# 1. Sostituisce i dati base
	self.building_data = new_building_data
	
	# 2. Aggiorna le statistiche dal nuovo BuildingData
	if health_component:
		var health_perc = health_component.get_health_percentage()
		health_component.setup(new_building_data, health_perc) #new_building_data.health_regen)
	
	# 3. Aggiorna la parte visiva e le azioni
	if sprite2d:
		sprite2d.texture = new_building_data.spritesheet
		
	# Sostituisce i bottoni dell'interfaccia (ora può addestrare nuove unità o fare nuove ricerche)
	self.available_actions = new_building_data.available_actions
	
	upgrade_completed.emit(new_building_data)

# --- GESTIONE UI ---


# --- GESTIONE COSTRUZIONE ---

func register_builder(builder: Node2D) -> void:
	if not active_builders.has(builder):
		active_builders.append(builder)

func unregister_builder(builder: Node2D) -> void:
	if active_builders.has(builder):
		active_builders.erase(builder)

func place_under_construction() -> void:
	is_under_construction = true
	construction_progress_perc = 0.0

	if health_component:
		health_component.set_health(1.0)
		health_component.show_health_bar()

	_set_building_region(region_under_construction)

func _advance_construction(delta: float) -> void:
	var count = active_builders.size()
	var speed_multiplier = 1.0 + (count - 1) * 0.5 
	
	construction_progress_perc += (delta / build_time) * speed_multiplier
	construction_progress_perc = clamp(construction_progress_perc, 0.0, 1.0)
	
		# Completamento
	if construction_progress_perc >= 1.0:
		complete_construction()

	if health_component:
		var max_health = health_component.max_health
		var new_health = roundi(lerp(1.0, float(max_health), construction_progress_perc))
		# Imposta la nuova salute e fa scattare il signal
		health_component.set_health(new_health)
		# Imposta la nuova percentuale e fa scattare il signal
		construction_progress_updated.emit(new_health, max_health)

	# Transizione alla fase "metà costruito"
	if construction_progress_perc >= 0.33 and construction_progress_perc < 0.66:
		_set_building_region(region_first_step_build)
	if construction_progress_perc >= 0.66 and construction_progress_perc < 1.0:
		_set_building_region(region_second_step_build)

func complete_construction() -> void:
	is_under_construction = false
	if health_component:
		health_component.process_mode = Node.PROCESS_MODE_PAUSABLE
		health_component.hide_health_bar()
		# Imposta la nuova salute e fa scattare il signal
		health_component.set_health(health_component.max_health)
		# Imposta la nuova percentuale e fa scattare il signal
		construction_progress_updated.emit(health_component.health, health_component.max_health)

	_set_building_region(region_completed)

	construction_completed.emit()
	
func _set_building_region(region: Rect2) -> void:
	if sprite2d  and region != Rect2():
		sprite2d.region_enabled = true
		sprite2d.region_rect = region

func _get_selection_manager() -> Node:
	var m := get_tree().get_nodes_in_group("selection_manager")
	return m[0] if not m.is_empty() else null

# Restituisce le coordinate griglia (Vector2i) del tile in alto a sinistra
func get_first_tile() -> Vector2i:
	if not GridManager.grid:
		return Vector2i(-1, -1)
		
	var cell_size: Vector2 = GridManager.grid.cell_size
	
	# 1. Ricalcola l'offset visivo usato per centrare la posizione
	var offset: Vector2 = (Vector2(tile_size) - Vector2.ONE) * (cell_size / 2.0)
	
	# 2. Sottrai l'offset per tornare al centro globale del tile di origine
	var origin_center_world: Vector2 = global_position - offset
	
	# 3. Chiedi al GridManager di convertire il punto globale in coordinate logiche
	return GridManager.get_tile_coords(origin_center_world)
