class_name BaseBuilding
extends StaticBody2D

enum BuildingState { IDLE, ACTIVE, DEPLETED, DESTROYED, INACTIVE }

# --- PARAMETRI CONFIGURABILI ---
@export_group("Edificio")
@export var player_owner: Player # Assegnato allo spawn o tramite editor
@export var player_color: Color = Color.BLUE : set = _set_player_color
#@export var name: String = "Edificio Base"
@export_multiline var description: String = ""
@export var icon:  Texture = preload("uid://dibevppt5yrf2")
@export var spritesheet: Texture2D

@export_group("Azioni e Abilità")
@export var available_actions: Array[ActionData] = []

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
@export var max_health: int = 800
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
@onready var health_bar: ProgressBar = $HealthBar
@onready var selectable_component: SelectableComponent = get_node_or_null("SelectableComponent")

# --- SEGNALI ---
signal health_changed(new_health: float, max_health: float)
signal construction_completed
signal construction_progress_updated(current_hp: float, max_hp: float)
signal work_completed
signal depleted()
signal destroyed()

# --- VARIABILI INTERNE ---
var player_id: int = -1 : get = _get_player_id
var is_depleted: bool = false
var is_destroyed: bool = false
var is_training: bool = false
var current_health: int = 0:
	set(value):
		if health_bar:
			health_bar.value = current_health

var active_builders: Array[Node2D] = []
var construction_progress_perc: float = 0.0 # Da 0.0 a 1.0
var training_progress_perc: float = 0.0 # Da 0.0 a 1.0

func _ready() -> void:
	# 1. Nascondi il cerchio di selezione all'avvio
	if selectable_component:
		selectable_component.deselect()
	
	if spritesheet and sprite2d:
		sprite2d.texture = spritesheet
		sprite2d.region_enabled = true
		
	# Inizializza l'ostacolo per la navmesh
	if nav_obstacle:
		nav_obstacle.affect_navigation_mesh = false
		
	health_changed.connect(_on_health_changed)
	
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		#health_bar.value = current_health
		
	# Gestione dello stato iniziale (già costruito)
	active_builders.clear()	
	_set_building_region(region_completed)

func _process(delta: float) -> void:
	if is_under_construction and not active_builders.is_empty():
		_advance_construction(delta)

func setup(data: Resource) -> void:
	self.name = data.name
	self.description = data.description
	self.icon = data.icon
	self.tile_size = data.tile_size
	self.requires_water = data.requires_water
	self.build_time = data.build_time
	self.max_health = data.max_health
	self.current_health = max_health
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
	return float(current_health) / float(max_health)

func get_available_actions() -> Array[ActionData]:
	return available_actions

func is_damaged() -> bool:
	return current_health < max_health and not is_under_construction

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
		
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	print(name, " ha subito ", amount, " danni. Vita residua: ", current_health)
	
	if current_health <= 0.0:
		destroy_building()

func heal(amount: float) -> void:
	if is_destroyed:
		return
		
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func destroy_building() -> void:
	is_destroyed = true
	destroyed.emit()
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if nav_obstacle:
		nav_obstacle.affect_navigation_mesh = false
		
	if health_bar:
		health_bar.visible = false
		
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
	if health_bar:
		health_bar.visible = false
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
	var health_perc = float(current_health) / float(max_health)
	
	# 2. Sostituisce i dati base
	self.building_data = new_building_data
	
	# 3. Aggiorna le statistiche dal nuovo BuildingData
	self.max_health = new_building_data.max_health
	self.current_health = roundi(max_health * health_perc) # Mantiene la % di vita
	
	# 4. Aggiorna la parte visiva e le azioni
	if sprite2d:
		sprite2d.texture = new_building_data.spritesheet
		
	# Sostituisce i bottoni dell'interfaccia (ora può addestrare nuove unità o fare nuove ricerche)
	self.available_actions = new_building_data.available_actions
	
	# Aggiorna la UI (vita massima cambiata, ecc.)
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

# --- GESTIONE UI ---

func _on_health_changed(new_health: float, _max: float) -> void:
	if health_bar:
		health_bar.value = new_health

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
	current_health = 1.0 # Parte con pochissima vita

	if health_bar:
			health_bar.visible = true
			health_bar.max_value = max_health
			#health_bar.value = current_health

	_set_building_region(region_under_construction)

func _advance_construction(delta: float) -> void:
	var count = active_builders.size()
	var speed_multiplier = 1.0 + (count - 1) * 0.5 
	
	construction_progress_perc += (delta / build_time) * speed_multiplier
	construction_progress_perc = clamp(construction_progress_perc, 0.0, 1.0)
	
	current_health = roundi(lerp(1.0, float(max_health), construction_progress_perc))

	#construction_progress_updated.emit(current_health, max_health)
	health_changed.emit(current_health, max_health) # Aggiorna l'UI durante la costruzione
	
	# Transizione alla fase "metà costruito"
	if construction_progress_perc >= 0.33 and construction_progress_perc < 0.66:
		_set_building_region(region_first_step_build)
	if construction_progress_perc >= 0.66 and construction_progress_perc < 1.0:
		_set_building_region(region_second_step_build)
	
	# Completamento
	if construction_progress_perc >= 1.0:
		complete_construction()

func complete_construction() -> void:
	is_under_construction = false
	current_health = max_health
	
	if health_bar:
		health_bar.visible = false

	_set_building_region(region_completed)

	var builders_to_release = active_builders.duplicate()
	active_builders.clear()
	for builder in builders_to_release:
		if is_instance_valid(builder):
			builder.clear_assignment()

	health_changed.emit(current_health, max_health)
	construction_completed.emit()
	
func _set_building_region(region: Rect2) -> void:
	if sprite2d  and region != Rect2():
		sprite2d.region_enabled = true
		sprite2d.region_rect = region
