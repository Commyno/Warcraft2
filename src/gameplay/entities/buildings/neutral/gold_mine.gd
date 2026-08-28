class_name GoldMine
extends BaseResourceBuilding

var current_state: ResourceState = ResourceState.IDLE

@export var idle_region: Rect2
@export var active_region: Rect2
@export var depleted_region: Rect2

# --- VARIABILI PER I LAVORATORI ---
@export var max_workers: int = 5
@export var extraction_time: float = 2.0
@export var gold_per_cycle: int = 10

# --- SEGNALI ---
signal state_changed(old_state: ResourceState, new_state: ResourceState)

# --- Variabili publiche ---
var extraction_timer: Timer

func _ready() -> void:
	super()
	add_to_group("interactable")
	
	# Creazione del timer ciclico per la miniera
	extraction_timer = Timer.new()
	extraction_timer.wait_time = extraction_time
	extraction_timer.one_shot = false
	extraction_timer.timeout.connect(_on_extraction_tick)
	add_child(extraction_timer)
	extraction_timer.stop()
	
	# Imposto lo stao idle manualmente per non far scattare chagne_state
	current_state = ResourceState.IDLE
	_set_building_region(idle_region)

func setup(resource_amount: int, status_active: bool) -> void:
	max_resources = resource_amount
	if status_active: 
		change_state(ResourceState.IDLE)
	else:
		change_state(ResourceState.INACTIVE)

func change_state(new_state: ResourceState) -> void:
	if current_state == new_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	match current_state:
		ResourceState.IDLE:
			_set_building_region(idle_region)
			add_to_group("interactable")
			extraction_timer.stop()
		ResourceState.ACTIVE:
			_set_building_region(active_region)
			add_to_group("interactable")
			if extraction_timer.is_stopped():
				extraction_timer.start()
		ResourceState.DEPLETED:
			_set_building_region(depleted_region)
			remove_from_group("interactable")
			extraction_timer.stop()
		ResourceState.DESTROYED:
			_set_building_region(depleted_region)
			remove_from_group("interactable")
			queue_free()
		ResourceState.INACTIVE:
			_set_building_region(idle_region)
			remove_from_group("interactable")
			extraction_timer.stop()
	
	# Emetto il seganle di cambio stato
	state_changed.emit(old_state, current_state)

# --- GESTIONE LAVORATORI ---

func register_worker(worker: Node2D) -> bool:
	if super(worker):
		if current_state == ResourceState.IDLE:
			change_state(ResourceState.ACTIVE)
			
		# Chiama la funzione di entrata sul peasant
		if worker.has_method("enter_mine"):
			worker.enter_mine(self)
		
		return true
	
	return false

func _on_extraction_tick() -> void:
	if not active_workers.is_empty():
		var peasant = active_workers.pop_front()
		
		if is_instance_valid(peasant):
			# Rilascia il peasant con il carico d'oro
			var extracted = extract_resource(gold_per_cycle)
			peasant.exit_mine(extracted)
			
	if active_workers.is_empty():
		change_state(ResourceState.IDLE)

func unregister_worker_manually(worker: Node2D) -> bool:
	if unregister_worker(worker):
		if worker.has_method("exit_mine"):
			worker.exit_mine(0)
		
		if active_workers.is_empty():
			change_state(ResourceState.IDLE)
	return true
