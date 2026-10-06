class_name TrainingComponent
extends Node2D

# Signals
signal queue_updated(queue: Array[UnitData])
signal progress_updated(progress_percent: float)
signal complete_training(data: UnitData)

# Export

@export_group("Training")
@export var max_queue_size: int = 5
@export var available_training: Array[ActionData]

# Variable
var is_training: bool = false :
	get:
		return training_queue.size() > 0
var training_queue: Array[UnitData] = []
var current_training_time: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Imposto le azioni relative al Component
	get_parent().available_actions.resize(9)
	available_training.resize(3)
	for i in range(0, 3):
		get_parent().available_actions[i] = available_training[i]
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 1. Gestione Training
	if training_queue.is_empty():
		return

	var current_unit: UnitData = training_queue[0]
	var total_time: float = max(current_unit.training_time, 0.2)
	
	# 1. Se il tempo non è ancora finito, fai avanzare la barra
	if current_training_time < total_time:
		current_training_time += delta
		var progress: float = clampf(current_training_time / total_time, 0.0, 1.0)
		progress_updated.emit(progress)
	
	# 2. Se il tempo è completato, tenta lo spawn solo se c'è cibo
	if current_training_time >= total_time:
		# Assicuriamo che la barra resti fissa al 100% in caso di attesa cibo
		progress_updated.emit(1.0)
		
		if get_player_owner() != null:
			if get_player_owner().has_enough_food(current_unit.food_cost):
				_complete_training(current_unit)
			else:
				# Bloccato al 100%: aspetta finché il player non costruisce una fattoria
				pass
		else:
			_complete_training(current_unit)

func _exit_tree() -> void:
	# TODO: Secondo me qui si dovrebbe richiamare la funzione di rimboso
	pass

# --- GESTIONE CODA ---

func is_queue_full() -> bool:
	return training_queue.size() >= max_queue_size

func enqueue_unit(data: UnitData) -> bool:
	if is_queue_full():
		return false
		
	training_queue.append(data)
	queue_updated.emit(training_queue)
	return true

func cancel_unit_at(index: int) -> void:
	if index < 0 or index >= training_queue.size():
		return
		
	var canceled_unit: UnitData = training_queue[index]
	training_queue.remove_at(index)
	
	if get_player_owner() != null:
		get_player_owner().refund_unit(canceled_unit)
	
	# Se annulliamo la prima unità, resettiamo il timer
	if index == 0:
		current_training_time = 0.0
		progress_updated.emit(0.0)
		
	queue_updated.emit(training_queue)

func _complete_training(data: UnitData) -> void:
	# Consuma il cibo prima di togliere l'unità dalla coda
	var player_owner = get_player_owner()
	if player_owner != null:
		player_owner.consume_food(data.food_cost)
	training_queue.pop_front()
	current_training_time = 0.0
	progress_updated.emit(0.0)
	queue_updated.emit(training_queue)
	complete_training.emit(data)

func get_player_owner() -> Player:
	if "player_owner" in get_parent():
		return get_parent().player_owner
	return null
