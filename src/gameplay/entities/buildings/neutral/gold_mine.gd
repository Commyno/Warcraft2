class_name GoldMine
extends ResourceBuilding

var current_state: BuildingState = BuildingState.IDLE

# --- SEGNALI ---
signal state_changed(old_state: BuildingState, new_state: BuildingState)

# --- Variabili publiche ---
var extraction_timer: Timer

func _ready() -> void:
	super()
	
	# Creazione del timer ciclico per la miniera
	extraction_timer = Timer.new()
	extraction_timer.wait_time = working_time
	extraction_timer.one_shot = false
	extraction_timer.timeout.connect(_on_extraction_tick)
	add_child(extraction_timer)
	extraction_timer.stop()
	
	# Imposto lo stao idle manualmente per non far scattare chagne_state
	current_state = BuildingState.IDLE
	_set_building_region(region_idle)

func setup(resource_amount: int, status_active: bool) -> void:
	max_resources = resource_amount
	current_resources = max_resources
	resources_changed.emit(current_resources, max_resources)
	
	if status_active: 
		change_state(BuildingState.IDLE)
	else:
		change_state(BuildingState.INACTIVE)

func change_state(new_state: BuildingState) -> void:
	if current_state == new_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	match current_state:
		BuildingState.IDLE:
			_set_building_region(region_idle)
			add_to_group("interactable")
			extraction_timer.stop()
		BuildingState.ACTIVE:
			_set_building_region(region_active)
			add_to_group("interactable")
			if extraction_timer.is_stopped():
				extraction_timer.start()
		BuildingState.DEPLETED:
			_set_building_region(region_depleted)
			remove_from_group("interactable")
			extraction_timer.stop()
		BuildingState.DESTROYED:
			_set_building_region(region_depleted)
			remove_from_group("interactable")
			queue_free()
		BuildingState.INACTIVE:
			_set_building_region(region_idle)
			remove_from_group("interactable")
			extraction_timer.stop()
	
	# Emetto il seganle di cambio stato
	state_changed.emit(old_state, current_state)

func _on_depleted() -> void:
	current_state = BuildingState.DEPLETED
	extraction_timer.stop()

# --- GESTIONE LAVORATORI ---

func register_worker(worker: Node2D) -> bool:
	if super(worker):
		if current_state == BuildingState.IDLE:
			change_state(BuildingState.ACTIVE)
			
		# Chiama la funzione di entrata sul peasant
		if worker.has_method("enter_mine"):
			worker.enter_mine(self)
		
		return true
	
	return false

func _on_extraction_tick() -> void:
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
		change_state(BuildingState.IDLE)

func unregister_worker_manually(worker: Node2D) -> bool:
	if unregister_worker(worker):
		if worker.has_method("exit_mine"):
			worker.exit_mine(0)
		
		if active_workers.is_empty():
			change_state(BuildingState.IDLE)
	return true
