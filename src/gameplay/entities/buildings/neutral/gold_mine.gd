class_name GoldMine
extends ResourceBuilding

# --- IDENTIFICAZIONE RISORSA ---
@onready var resource_component: ResourceComponent = $ResourceComponent

# --- SEGNALI ---
signal state_changed(old_state: BuildingState, new_state: BuildingState)

# --- Variabili publiche ---
var current_state: BuildingState = BuildingState.IDLE  : set = change_state

func _ready() -> void:
	super()
	
	can_destroy = false
	can_attack = false
	
	# Imposto lo stao idle manualmente per non far scattare chagne_state
	current_state = BuildingState.IDLE
	_set_building_region(region_idle)
	
	if health_component:
		health_component.hide_health_bar()
	
	if resource_component:
		resource_component.setup(Globals.ResourceType.GOLD, null)
		
		if not resource_component.depleted.is_connected(on_depleted):
			resource_component.depleted.connect(on_depleted)
		if not resource_component.worker_entered.is_connected(on_worker_entered):
			resource_component.worker_entered.connect(on_worker_entered)
		if not resource_component.worker_exited.is_connected(ok_worker_exited):
			resource_component.worker_exited.connect(ok_worker_exited)

func _exit_tree() -> void:
	if resource_component:
		if resource_component.depleted.is_connected(on_depleted):
			resource_component.depleted.disconnect(on_depleted)
		if resource_component.worker_entered.is_connected(on_worker_entered):
			resource_component.worker_entered.disconnect(on_worker_entered)
		if resource_component.worker_exited.is_connected(ok_worker_exited):
			resource_component.worker_exited.disconnect(ok_worker_exited)


func change_state(new_state: BuildingState) -> void:
	if current_state == new_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	match current_state:
		BuildingState.IDLE:
			_set_building_region(region_idle)
			add_to_group("interactable")
			if resource_component:
				resource_component.extraction_timer.stop()
		BuildingState.ACTIVE:
			_set_building_region(region_active)
			add_to_group("interactable")
			if resource_component:
				if resource_component.extraction_timer.is_stopped():
					resource_component.extraction_timer.start()
		BuildingState.DEPLETED:
			_set_building_region(region_depleted)
			remove_from_group("interactable")
			if resource_component:
				resource_component.extraction_timer.stop()
		BuildingState.DESTROYED:
			_set_building_region(region_depleted)
			remove_from_group("interactable")
			queue_free()
		BuildingState.INACTIVE:
			_set_building_region(region_idle)
			remove_from_group("interactable")
			if resource_component:
				resource_component.extraction_timer.stop()
	
	# Emetto il seganle di cambio stato
	state_changed.emit(old_state, current_state)

func on_depleted() -> void:
	super()
	current_state = BuildingState.DEPLETED
	
	# 3. Rimuovo le connessioni
	if resource_component:
		if resource_component.depleted.is_connected(on_depleted):
			resource_component.depleted.disconnect(on_depleted)

# --- GESTIONE LAVORATORI ---

func on_worker_entered(worker: Node2D) -> void:
	if current_state == BuildingState.IDLE:
		change_state(BuildingState.ACTIVE)
	
	# Chiama la funzione di entrata sul peasant
	if worker.has_method("enter_mine"):
		worker.enter_mine(self)

func ok_worker_exited(worker: Node2D) -> void:
	if resource_component.active_workers.size() <= 0:
		change_state(BuildingState.IDLE)
