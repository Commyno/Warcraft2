class_name BaseBuilding
extends StaticBody2D

enum BuildingState { IDLE, ACTIVE, DEPLETED, DESTROYED, INACTIVE }

# --- PARAMETRI CONFIGURABILI ---
@export_group("Edificio")
@export var player_owner: Player # Assegnato allo spawn o tramite editor
@export var player_color: Color = Color.BLUE : set = _set_player_color
@export var building_name: String = "Edificio Base"
@export var building_icon:  Texture = preload("uid://dibevppt5yrf2")
@export var building_spritesheet: Texture2D

@export_group("Azioni e Abilità")
@export var available_actions: Array[UnitAction] = []

# --- STATISTICHE DI BASE ---
@export_group("Vitalità")
@export var max_health: float = 500.0

# --- PARAMETRI DI COSTRUZIONE ---
@export_group("Costruzione")
@export var build_time: float = 10.0
@export var is_under_construction: bool = false
@export var region_under_construction: Rect2
@export var region_first_step_build: Rect2
@export var region_second_step_build: Rect2
@export var region_completed: Rect2
@export var region_idle: Rect2
@export var region_active: Rect2
@export var region_depleted: Rect2

# --- RIFERIMENTI NODI ---
@onready var sprite: Sprite2D = $Sprite2D
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
var current_health: float
var is_depleted: bool = false
var is_destroyed: bool = false
var construction_progress_perc: float = 0.0 # Da 0.0 a 1.0
var active_builders: Array[Node2D] = []

var is_training: bool = false
var training_progress_perc: float = 0.0 # Da 0.0 a 1.0

func _ready() -> void:
	# 1. Nascondi il cerchio di selezione all'avvio
	if selectable_component:
		selectable_component.deselect()
	
	if building_spritesheet and sprite:
		sprite.texture = building_spritesheet
		sprite.region_enabled = true
		
	# Inizializza l'ostacolo per la navmesh
	if nav_obstacle:
		nav_obstacle.affect_navigation_mesh = false
		
	health_changed.connect(_on_health_changed)
	
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	# Gestione dello stato iniziale (già costruito)
	active_builders.clear()	
	_set_building_region(region_completed)

func _process(delta: float) -> void:
	if is_under_construction and not active_builders.is_empty():
		_advance_construction(delta)

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
	return current_health / max_health

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
	
	print(building_name, " ha subito ", amount, " danni. Vita residua: ", current_health)
	
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
		
	print(building_name, " è stato distrutto!")
	
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
	if not sprite or not sprite.texture:
		return
		
	var rubble = Sprite2D.new()
	rubble.texture = sprite.texture
	rubble.region_enabled = sprite.region_enabled
	rubble.region_rect = sprite.region_rect # FONDAMENTALE PER NON MOSTRARE TUTTO L'ATLAS
	rubble.global_position = global_position
	rubble.modulate = Color(0.2, 0.2, 0.2, 0.8)
	
	get_parent().add_child(rubble)

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
	_set_building_region(region_under_construction)

func _advance_construction(delta: float) -> void:
	var count = active_builders.size()
	var speed_multiplier = 1.0 + (count - 1) * 0.5 
	
	construction_progress_perc += (delta / build_time) * speed_multiplier
	construction_progress_perc = clamp(construction_progress_perc, 0.0, 1.0)
	
	current_health = lerp(1.0, max_health, construction_progress_perc)
	construction_progress_updated.emit(current_health, max_health)
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
	active_builders.clear()
	current_health = max_health
	
	_set_building_region(region_completed)
	health_changed.emit(current_health, max_health)
	construction_completed.emit()
	
func _set_building_region(region: Rect2) -> void:
	if sprite  and region != Rect2():
		sprite.region_enabled = true
		sprite.region_rect = region
