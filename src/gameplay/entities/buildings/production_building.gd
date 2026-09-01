class_name ProductionBuilding
extends BaseBuilding

@export var max_queue_size: int = 5
@export var spawn_offset: Vector2 = Vector2(0, 32)
@export var rally_point: Vector2

var training_queue: Array[UnitData] = []
var current_training_time: float = 0.0

signal queue_updated(queue: Array[UnitData])
signal progress_updated(progress_percent: float)


func _ready() -> void:
	super()
	add_to_group("building")
	add_to_group("interactable")


func enqueue_unit(data: UnitData) -> bool:
	if training_queue.size() >= max_queue_size:
		return false
	
	# Verifica e spende le risorse del player proprietario
	if player_owner == null:
		return false
	if training_queue.size() >= max_queue_size:
		return false
	if not player_owner.can_afford(data.gold_cost, data.wood_cost, data.oil_cost, data.food_cost):
		return false
		
	player_owner.spend_for_unit(data)
	training_queue.append(data)
	queue_updated.emit(training_queue)
	return true

func cancel_unit_at(index: int) -> void:
	if index < 0 or index >= training_queue.size():
		return
		
	var canceled_unit: UnitData = training_queue[index]
	training_queue.remove_at(index)
	
	if player_owner != null:
		player_owner.refund_unit(canceled_unit)
	
	if index == 0:
		current_training_time = 0.0
		progress_updated.emit(0.0)
		
	queue_updated.emit(training_queue)

func _complete_training(data: UnitData) -> void:
	training_queue.pop_front()
	current_training_time = 0.0
	progress_updated.emit(0.0)
	queue_updated.emit(training_queue)

	if player_owner != null:
		player_owner.consume_food(1)

	_spawn_unit(data)

func _spawn_unit(data: UnitData) -> void:
	if data.unit_scene == null:
		return

	var unit_instance: Node2D = data.unit_scene.instantiate()
	get_parent().add_child(unit_instance)
	unit_instance.global_position = global_position + spawn_offset
	
	# Propaga la proprietà dell'unità al nuovo soldato/lavoratore
	if "player_owner" in unit_instance:
		unit_instance.player_owner = player_owner

	if unit_instance.has_method("move_to"):
		unit_instance.move_to(rally_point)
