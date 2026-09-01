class_name ResourceBuilding
extends BaseBuilding

# --- IDENTIFICAZIONE RISORSA ---
@export var resource_id: int = 0
@export var resource_type: Globals.ResourceType = Globals.ResourceType.GOLD

# --- STATISTICHE RISORSA ---
@export_group("Riserva")
@export var max_resources: int = 10000

# --- VARIABILI PER I LAVORATORI ---
@export_group("Produzione")
@export var max_workers: int = 4
@export var working_time: float = 2.0
@export var resource_per_cycle: int = 10

# --- SEGNALI ---
signal resources_changed(new_resources: float, max_resources: float)
signal worker_entered(worker: Node2D)
signal worker_exited(worker: Node2D)

# --- VARIABILI INTERNE ---
var current_resources: int
var active_workers: Array[Node2D] = []

func _ready() -> void:
	super()
	add_to_group("interactable")
	
	current_resources = max_resources
	
	# Inizializza l'ostacolo per la navmesh
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
	
	# 1. Spegne collisioni, navmesh, selezione, input, _process
	_disable_interactivity()
	
	# 2. Mostra la texture di "miniera esaurita" (region_depleted è su BaseBuilding)
	_set_building_region(region_depleted)
	
	# 3. Notifica i sottotipi (GoldMine) e chiunque altro sia in ascolto
	_on_depleted()      # ← hook per i sottotipi (chiamata diretta, ordine garantito)
	depleted.emit()

## Virtuale: i figli lo sovrascrivono per reagire alla deplezione.
func _on_depleted() -> void:
	pass

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

# --- SISTEMA DI DANNO E DISTRUZIONE ---
#Override delle funzioni di distruzione in quanto non puo essere distrutta
func take_damage(amount: float) -> void:
	pass

func heal(amount: float) -> void:
	pass

func destroy_building() -> void:
	pass

# --- GESTIONE LAVORATORI ---

func can_accept_worker() -> bool:
	if active_workers.size() >= max_workers:
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

func get_health_perc() -> float:
	return 1.0 # Questo edificio non può essere distrutto dai giocatori
