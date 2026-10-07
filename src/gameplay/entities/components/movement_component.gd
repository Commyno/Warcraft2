class_name MovementComponent
extends Node

const MOVE_ACTION_DATA = preload("uid://3jln7kt6s6oa")
const STOP_ACTION_DATA = preload("uid://bexvmhf4682mu")

# --- SEGNALI ---
signal movement_finished()

@export var move_speed: int = 100

# --- STATO DI MOVIMENTO ---
var current_path: Array[Vector2i] = []
var current_step_target: Vector2 = Vector2.INF
var final_target_global: Vector2 = Vector2.INF
var intended_dir: Vector2 = Vector2.DOWN

var is_processing_grid: bool = false
var is_moving: bool = false

@onready var unit: BaseUnit = get_parent() as BaseUnit

func _ready() -> void:
	# Imposto le azioni relative al Component
	unit.available_actions.resize(9)
	unit.available_actions[0] = MOVE_ACTION_DATA
	unit.available_actions[2] = STOP_ACTION_DATA
	
	# Il componente ascolta i cambiamenti della griglia
	if not GridManager.obstacles_changed.is_connected(_on_obstacles_changed):
		GridManager.obstacles_changed.connect(_on_obstacles_changed)

func setup(data: Resource) -> void:
	self.move_speed = data.move_speed

# Viene chiamato dalla BaseUnit nel suo _physics_process
func process_movement(delta: float) -> void:
	if not is_moving:
		return
		
	# Se non abbiamo un bersaglio locale in corso, abbiamo terminato l'intero percorso
	if current_step_target == Vector2.INF:
		_finish_movement()
		return
		
	var dist = unit.global_position.distance_to(current_step_target)
	
	if dist > 3.0: 
		# Avanziamo linearmente verso il centro del tile
		intended_dir = unit.global_position.direction_to(current_step_target)
		unit.velocity = intended_dir * move_speed # Settiamo velocity per l'AnimationTree dell'unità
		unit.global_position = unit.global_position.move_toward(current_step_target, move_speed * delta)
	else:
		# Siamo arrivati esatti al centro della cella!
		unit.global_position = current_step_target
		_prepare_next_step()

func move_to(target_pos: Vector2) -> void:
	final_target_global = target_pos
	is_moving = true
	_calculate_path()

# Cancella il percorso attuale e prenota la cella corrente per fermarsi
func stop_movement() -> void:
	is_moving = false
	current_path.clear()
	current_step_target = Vector2.INF
	unit.velocity = Vector2.ZERO
	
	# ALZA LO SCUDO
	is_processing_grid = true 
	var unit_id : int = unit.get_instance_id()
	var standing_tile = GridManager.get_tile_coords(unit.global_position)
	GridManager.release_agent(unit_id)
	GridManager.confirm_move(unit_id, standing_tile, standing_tile)
	is_processing_grid = false 

func _prepare_next_step() -> void:
	if current_path.is_empty():
		current_step_target = Vector2.INF
		return
		
	var current_cell = GridManager.get_tile_coords(unit.global_position)
	var next_cell = current_path[0]
	var entity_id = unit.get_instance_id()

	# Controllo di adiacenza dinamico leggendo il current_target dall'unità
	if is_instance_valid(unit.current_target) and unit.current_target is BaseBuilding:
		if is_adjacent_to_target(unit.current_target):
			current_path.clear()
			_finish_movement()
			return
	
	is_processing_grid = true
	var result = GridManager.confirm_move(entity_id, current_cell, next_cell)
	is_processing_grid = false
	
	if result["ok"]:
		current_path.pop_front()
		current_step_target = GridManager.get_tile_center_global(next_cell)
	else:
		unit.velocity = Vector2.ZERO
		var target_cell = GridManager.get_tile_coords(final_target_global)		
		if (next_cell == target_cell):
			current_path.clear()
			_finish_movement()
		else:
			_repath_around_obstacle(next_cell)

func is_adjacent_to_target(target: Node2D) -> bool:
	var my_cell := GridManager.get_tile_coords(unit.global_position)
	
	if target is BaseBuilding:
		var origin: Vector2i = target.get_first_tile()
		var size: Vector2i = target.tile_size
	
		var min_x = origin.x - 1
		var max_x = origin.x + size.x
		var min_y = origin.y - 1
		var max_y = origin.y + size.y
	
		return my_cell.x >= min_x and my_cell.x <= max_x and my_cell.y >= min_y and my_cell.y <= max_y
	else:
		# Per unità o target 1x1 usa Chebyshev
		var target_cell := GridManager.get_tile_coords(target.global_position)
		return maxi(abs(my_cell.x - target_cell.x), abs(my_cell.y - target_cell.y)) <= 1

func _repath_around_obstacle(blocked_cell: Vector2i) -> void:
	is_processing_grid = true
	#GridManager.grid.set_point_solid(blocked_cell, true)
	
	var start_cell = GridManager.get_tile_coords(unit.global_position)
	var target_cell = GridManager.get_tile_coords(final_target_global)
	#var detour_path = GridManager.grid.get_id_path(start_cell, target_cell, true)
	var detour_path = GridManager.get_path_avoiding_units(start_cell, target_cell, unit.get_instance_id())
	
	#var remains_solid = GridManager.authored_solid_at(blocked_cell) or GridManager.blocker_count_at(blocked_cell) > 0
	#GridManager.grid.set_point_solid(blocked_cell, remains_solid)
	
	is_processing_grid = false
	
	if not detour_path.is_empty():
		if detour_path[0] == start_cell:
			detour_path.pop_front()
		current_path = detour_path
		current_step_target = unit.global_position
	else:
		current_path.clear()
		current_step_target = Vector2.INF

func _calculate_path() -> void:
	var start_cell = GridManager.get_tile_coords(unit.global_position)
	var target_cell = GridManager.get_tile_coords(final_target_global)
	
	if start_cell == target_cell:
		current_path.clear()
		current_step_target = GridManager.get_tile_center_global(target_cell)
		return
		
	#current_path = GridManager.grid.get_id_path(start_cell, target_cell, true)
	current_path = GridManager.get_path_avoiding_units(start_cell, target_cell, unit.get_instance_id())

	if not current_path.is_empty():
		if current_path[0] == start_cell:
			current_path.pop_front()
		_prepare_next_step()
	else:
		is_moving = false
		unit.velocity = Vector2.ZERO

func _on_obstacles_changed(changed_cells: Array) -> void:
	if is_processing_grid or not is_moving or current_path.is_empty():
		return
	for cell in changed_cells:
		if current_path.has(cell):
			_calculate_path()
			break

func _finish_movement() -> void:
	is_moving = false
	unit.velocity = Vector2.ZERO
	current_step_target = Vector2.INF

	# Consolida la cella finale come "occupata da fermo"
	var unit_id := unit.get_instance_id()
	var standing_tile := GridManager.get_tile_coords(unit.global_position)
	GridManager.release_agent(unit_id)
	GridManager.confirm_move(unit_id, standing_tile, standing_tile)

	movement_finished.emit() # Avvisa la BaseUnit che siamo arrivati!
