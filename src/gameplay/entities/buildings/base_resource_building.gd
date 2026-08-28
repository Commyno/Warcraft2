class_name BaseResourceBuilding
extends StaticBody2D

enum ResourceState { IDLE, ACTIVE, DEPLETED, DESTROYED, INACTIVE }

# --- IDENTIFICAZIONE RISORSA ---
@export var resource_id: int = 0
@export var resource_name: String = "Nome risorsa"
@export var resource_type: Globals.ResourceType = Globals.ResourceType.GOLD
@export var resource_spritesheet: Texture2D
@export var resource_icon:  Texture = preload("uid://de3gns0d6qacn")

@export_group("Azioni e Abilità")
@export var available_actions: Array[UnitAction] = []

# --- STATISTICHE RISORSA ---
@export_group("Riserva")
@export var max_resources: float = 10000.0

@export_group("Produzione")
@export var working_time: float = 2.0
@export var max_worker_count: int = 4

# --- RIFERIMENTI NODI ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var nav_obstacle: NavigationObstacle2D = $NavigationObstacle2D
@onready var selectable: SelectableComponent = get_node_or_null("SelectableComponent")

# --- SEGNALI ---
signal resources_changed(new_resources: float, max_resources: float)
signal worker_entered(worker: Node2D)
signal worker_exited(worker: Node2D)
signal depleted()

# --- VARIABILI INTERNE ---
var current_resources: float
var is_depleted: bool = false
var active_workers: Array[Node2D] = []

func _ready() -> void:
	current_resources = max_resources
	
	if nav_obstacle:
		nav_obstacle.affect_navigation_mesh = true

# --- SISTEMA DI ESTRAZIONE ---

## Ritorna l'ammontare effettivamente estratto
func extract_resource(amount: float) -> float:
	if is_depleted:
		return 0.0
		
	var extracted = min(amount, current_resources)
	current_resources -= extracted
	resources_changed.emit(current_resources, max_resources)
	
	if current_resources <= 0.0:
		deplete_resource()
		
	return extracted

func deplete_resource() -> void:
	if is_depleted:
		return
		
	is_depleted = true
	depleted.emit()
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if nav_obstacle:
		nav_obstacle.affect_navigation_mesh = false
			
	spawn_depleted_ground()
	queue_free()

func spawn_depleted_ground() -> void:
	if not sprite or not sprite.texture:
		return
		
	var rubble = Sprite2D.new()
	rubble.texture = sprite.texture
	rubble.region_enabled = sprite.region_enabled
	rubble.region_rect = sprite.region_rect
	rubble.global_position = global_position
	rubble.modulate = Color(0.3, 0.3, 0.3, 0.6)
	
	get_parent().add_child(rubble)

# --- GESTIONE LAVORATORI ---

func can_accept_worker() -> bool:
	if active_workers.size() >= max_worker_count:
		print("Miniera piena!")
		return false
	if is_depleted:
		print("Miniera distrutta!")
		return false
	return true

func register_worker(worker: Node2D) -> bool:
	if can_accept_worker() and not active_workers.has(worker):
		active_workers.append(worker)
		worker_entered.emit(worker)
		return true
	return false

func unregister_worker(worker: Node2D) -> bool:
	if active_workers.has(worker):
		active_workers.erase(worker)
		worker_exited.emit(worker)
		return true
	return false

func _set_building_region(region: Rect2) -> void:
	if sprite:
		sprite.region_enabled = true
		sprite.region_rect = region

func get_health_perc() -> float:
	return 1.0 # Questo edificio non può essere distrutto dai giocatori

# --- SELEZIONE ---

func select() -> void:
	if selectable: selectable.select()

func deselect() -> void:
	if selectable: selectable.deselect()

func is_selected() -> bool:
	return selectable.is_selected if selectable else false
