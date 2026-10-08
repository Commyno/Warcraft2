class_name ResourceComponent
extends Node

# --- STATISTICHE RISORSA ---
@export var resource_type: Globals.ResourceType = Globals.ResourceType.GOLD
@export var max_resources: int = 10000

# --- VARIABILI PER I LAVORATORI ---
@export_group("Produzione")
@export var max_workers: int = 4
@export var working_time: float = 2.0
@export var resource_per_cycle: int = 1

# --- SEGNALI ---
signal resources_changed(new_resources: int, max_resources: int)
signal worker_entered(worker: Node2D)
signal worker_exited(worker: Node2D)
signal depleted()

# --- VARIABILI INTERNE ---
var is_depleted: bool = false
var current_resources: int
var active_workers: Array[Node2D] = []
var extraction_timer: Timer


func _ready() -> void:
	current_resources = max_resources
	
	# Creazione del timer ciclico per la miniera
	extraction_timer = Timer.new()
	extraction_timer.wait_time = working_time
	extraction_timer.one_shot = false
	extraction_timer.timeout.connect(on_extraction_tick)
	add_child(extraction_timer)
	extraction_timer.stop()

func setup(_resource_type: Globals.ResourceType, data: Resource) -> void:
	resource_type = _resource_type

func set_resources(_resource: int, _max_resources) -> void: #resource_amount: int, status_active: bool) -> void:
	current_resources = _resource
	max_resources = _max_resources
	resources_changed.emit(current_resources, max_resources)


# --- SISTEMA DI ESTRAZIONE ---

## Ritorna l'ammontare effettivamente estratto
func extract_resource(amount: int) -> int:
	if is_depleted:
		return 0
		
	var extracted : int = min(amount, current_resources)
	current_resources -= extracted
	resources_changed.emit(current_resources, max_resources)
	
	if current_resources <= 0:
		deplete_resource()
		
	return extracted

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

func unregister_worker_manually(worker: Node2D) -> bool:
	if active_workers.has(worker):
		active_workers.erase(worker)
		
		# Visto che lo sto comandando da qui, informo il lavoratore di uscire
		if worker.has_method("exit_mine"):
			worker.exit_mine(0)
		
		worker_exited.emit(worker)
		return true
	return false

func deplete_resource() -> void:
	if is_depleted:
		return
	
	is_depleted = true
	
	if not extraction_timer.is_stopped():
		extraction_timer.stop()

	depleted.emit()

func on_extraction_tick() -> void:
	if not active_workers.is_empty():
		var peasant: Node2D = active_workers.front()
		
		if is_instance_valid(peasant):
			# Rilascia il peasant con il carico d'oro
			var extracted = extract_resource(resource_per_cycle)
			peasant.exit_mine(extracted)
			unregister_worker(peasant)    # rimozione pulita + segnale
		else:
			active_workers.pop_front()    # peasant fantasma: lo scarto e basta
	
	# Se l'ultima estrazione ha esaurito la miniera, non tornare a IDLE
	if is_depleted:
		return

	if active_workers.is_empty():
		worker_exited.emit()

# Funzione per spawnare l'immagine dei resti di unaminiera su cui è possibile costruire.
# TODO: Da chiamare dopo diversi minuti che la miniera è esaurita.
func spawn_depleted_ground() -> void:
	var miniera = get_parent()
	if not miniera.sprite2d or not miniera.sprite2d.texture:
		return
		
	var rubble = Sprite2D.new()
	rubble.texture = miniera.sprite2d.texture
	rubble.region_enabled = miniera.sprite2d.region_enabled
	rubble.region_rect = miniera.sprite2d.region_rect
	rubble.global_position = miniera.global_position
	rubble.z_index  = 2
	rubble.modulate = Color(0.3, 0.3, 0.3, 0.6)
	
	# TODO: Al momento prendo il padre del padre, la implementare una funzione 
	# nel Autoload SpqwnManager che spawna questi relitti
	miniera.get_parent().add_child(rubble)
