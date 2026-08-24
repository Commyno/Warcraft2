class_name GoldMine
extends BaseResourceBuilding

enum MineState { IDLE, ACTIVE, DEPLETED, DESTROYED, INACTIVE }
var current_state: MineState = MineState.IDLE

@export var texture_idle: Texture2D
@export var texture_active: Texture2D
@export var texture_depleted: Texture2D

# --- VARIABILI PER I LAVORATORI ---
@export var max_workers: int = 5
@export var extraction_time: float = 2.0
@export var gold_per_cycle: int = 10

var assigned_workers: Array[Node2D] = []
var extraction_timer: Timer

func _ready() -> void:
	add_to_group("interactable")
	change_state(MineState.IDLE)
	
	# Creazione del timer ciclico per la miniera
	extraction_timer = Timer.new()
	extraction_timer.wait_time = extraction_time
	extraction_timer.one_shot = false
	extraction_timer.timeout.connect(_on_extraction_tick)
	add_child(extraction_timer)

func setup(resource_amount: int, status_active: bool) -> void:
	if sprite: sprite.texture = texture_idle
	max_resources = resource_amount
	if status_active: 
		change_state(MineState.IDLE)
	else:
		change_state(MineState.INACTIVE)

func change_state(new_state: MineState) -> void:
	if current_state == new_state:
		return
		
	current_state = new_state
	
	match current_state:
		MineState.IDLE:
			add_to_group("interactable")
			if sprite: sprite.texture = texture_idle
			extraction_timer.stop()
		MineState.ACTIVE:
			add_to_group("interactable")
			if sprite: sprite.texture = texture_active
			if extraction_timer.is_stopped():
				extraction_timer.start()
		MineState.DEPLETED:
			if sprite: sprite.texture = texture_depleted
			remove_from_group("interactable")
			extraction_timer.stop()
		MineState.DESTROYED:
			remove_from_group("interactable")
			queue_free()
		MineState.INACTIVE:
			if sprite: sprite.texture = texture_depleted
			remove_from_group("interactable")
			extraction_timer.stop()

# --- GESTIONE LAVORATORI ---

func assign_worker(peasant: Node2D) -> bool:
	if assigned_workers.size() >= max_workers:
		print("Miniera piena!")
		return false
		
	assigned_workers.append(peasant)
	
	if current_state == MineState.IDLE:
		change_state(MineState.ACTIVE)
		
	# Chiama la funzione di entrata sul peasant
	if peasant.has_method("enter_mine"):
		peasant.enter_mine(self)
	
	return true

func _on_extraction_tick() -> void:
	if not assigned_workers.is_empty():
		var peasant = assigned_workers.pop_front()
		
		if is_instance_valid(peasant):
			# Rilascia il peasant con il carico d'oro
			peasant.exit_mine(gold_per_cycle)
			
	if assigned_workers.is_empty():
		change_state(MineState.IDLE)

func remove_worker_manually(peasant: Node2D) -> void:
	if peasant in assigned_workers:
		assigned_workers.erase(peasant)
		peasant.exit_mine(0)
		
		if assigned_workers.is_empty():
			change_state(MineState.IDLE)
