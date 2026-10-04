class_name GatheringComponent
extends Node

# --- SEGNALI ---
signal resource_gathered(type: Globals.ResourceType, amount: int)
signal resources_deposited()
signal mine_entered()
signal mine_exited()
signal interaction_finished() # Per avvisare l'unità di tornare in IDLE

# --- PARAMETRI ---
@export var chop_speed: float = 1.0
@export var max_carry: int = 10

# --- STATO ---
var current_resource: Globals.ResourceType = Globals.ResourceType.NONE
var resource_amount: int = 0

var target_mine: GoldMine = null
var target_resource_tile: Vector2i = Vector2i(-1, -1)
var enter_tile_position: Vector2i = Vector2i.MIN
var enter_direction: Vector2 = Vector2.DOWN

var action_timer: float = 0.0

@onready var unit: BaseUnit = get_parent() as BaseUnit

# Chiamato dal _process dell'unità se lo stato è CHOPPING
func process_chopping(delta: float) -> void:
	action_timer -= delta
	if action_timer <= 0.0:
		action_timer = chop_speed
		_perform_chop()

# --- GESTIONE MINIERA ---
func interact_with_mine(mine: GoldMine) -> void:
	target_resource_tile = Vector2i(-1, -1) # Dimentica la legna
	action_timer = 0.0
	
	if current_resource != Globals.ResourceType.NONE and resource_amount > 0:
		target_mine = mine
		go_to_dropoff()
		return
		
	target_mine = mine
	if mine.has_method("register_worker"):
		var success = mine.register_worker(unit)
		if not success:
			clear_gathering_target()
			interaction_finished.emit()

func enter_mine(mine: GoldMine) -> void:
	if mine.is_depleted:
		interaction_finished.emit()
		return
		
	mine_entered.emit()
	enter_tile_position = GridManager.get_tile_coords(unit.global_position)
	
	if unit.movement_component:
		unit.movement_component.stop_movement()
		
	enter_direction = (unit.global_position - mine.global_position).normalized()
	if enter_direction == Vector2.ZERO:
		enter_direction = Vector2.DOWN 
		
	# Disabilita fisica e visibilità tramite l'unità
	unit.collision_shape.set_deferred("disabled", true)
	if unit.health_component:
		unit.health_component.hide_health_bar()
	unit.remove_from_selection()
	
	var move_speed = unit.movement_component.move_speed if unit.movement_component else 1.0
	var distance = unit.global_position.distance_to(mine.global_position)
	var speed = max(move_speed, 1.0) 
	var total_duration: float = distance / speed
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(unit, "global_position", mine.global_position, total_duration)
	if unit.sprite2d:
		tween.tween_property(unit.sprite2d, "modulate:a", 0.0, total_duration * 0.5)
		
	await tween.finished
	unit.visible = false
	unit.set_physics_process(false)

func exit_mine(gold_amount: int, current_target: Node2D) -> void:
	unit.visible = true
	if unit.sprite2d:
		unit.sprite2d.modulate.a = 0.0
		
	var ideal_target: Vector2 = Vector2.INF
	var exit_position = unit.global_position
	
	var closest_dropoff = get_closest_dropoff()
	if closest_dropoff:
		ideal_target = closest_dropoff.global_position
	else:
		ideal_target = current_target.global_position + (enter_direction * 64.0)
		
	if GridManager.is_valid_cell(enter_tile_position, unit.get_instance_id(), enter_tile_position):
		exit_position = GridManager.get_tile_center_global(enter_tile_position)
	else:
		exit_position = GridManager.get_warcraft_spawn_position(current_target, unit.get_instance_id(), ideal_target)
		
	var exit_direction = (exit_position - unit.global_position).normalized()
	if exit_direction != Vector2.ZERO:
		unit.last_facing_dir = exit_direction
		
	mine_exited.emit() # Avvisa l'unità di riprodurre l'animazione di movimento
	
	var speed = max(unit.movement_component.move_speed, 1.0) if unit.movement_component else 1.0
	var distance = unit.global_position.distance_to(exit_position)
	var total_duration: float = distance / speed
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(unit, "global_position", exit_position, total_duration)
	if unit.sprite2d:
		tween.tween_property(unit.sprite2d, "modulate:a", 1.0, total_duration * 0.5).set_delay(total_duration * 0.5)
		
	await tween.finished
	
	unit.collision_shape.set_deferred("disabled", false)
	
	await unit.get_tree().physics_frame
	await unit.get_tree().physics_frame
	unit.set_physics_process(true)
	
	if gold_amount > 0:
		current_resource = Globals.ResourceType.GOLD
		resource_amount = gold_amount
		go_to_dropoff()
	else:
		interaction_finished.emit()

# --- GESTIONE ALBERI E TAGLIO ---
func interact_with_tree(tile_coords: Vector2i) -> void:
	if current_resource != Globals.ResourceType.NONE and resource_amount > 0:
		target_resource_tile = tile_coords 
		go_to_dropoff()
		return 
		
	if GridManager.is_tree(tile_coords):
		target_mine = null 
		target_resource_tile = tile_coords 
		action_timer = chop_speed
		
		var tree_global_pos = GridManager.get_tile_center_global(tile_coords)
		unit.last_facing_dir = (tree_global_pos - unit.global_position).normalized()
	else:
		_find_next_tree(tile_coords)

func _perform_chop() -> void:
	var obtained = GridManager.chop_tree(target_resource_tile, 5) 
	
	if obtained > 0:
		current_resource = Globals.ResourceType.WOOD
		resource_amount += obtained
		
		if resource_amount >= max_carry:
			go_to_dropoff()
	else:
		_find_next_tree(target_resource_tile) 

func _find_next_tree(start_tile: Vector2i) -> void:
	var next_tree = GridManager.get_closest_tree_around(start_tile, 5)
	
	if next_tree != Vector2i(-1, -1):
		var entity_id = unit.get_instance_id()
		var tree_global = GridManager.get_tile_center_global(next_tree)
		var approach_dir = unit.global_position.direction_to(tree_global)
		var safe_pos = GridManager.get_adjacent_free_position(tree_global, Vector2i(1, 1), approach_dir, entity_id, true)
		
		unit.interact_with_tile(next_tree, safe_pos) 
	else:
		if resource_amount > 0:
			go_to_dropoff()
		else:
			clear_gathering_target()
			interaction_finished.emit()

# --- DEPOSITO RISORSE ---
func deposit_resources(building: ProductionBuilding) -> void:
	if current_resource != Globals.ResourceType.NONE and resource_amount > 0:
		if current_resource == Globals.ResourceType.GOLD: 
			unit.player_owner.add_gold(resource_amount)
		elif current_resource == Globals.ResourceType.WOOD: 
			unit.player_owner.add_lumber(resource_amount)
		elif current_resource == Globals.ResourceType.OIL: 
			unit.player_owner.add_oil(resource_amount)
			
		current_resource = Globals.ResourceType.NONE
		resource_amount = 0
		resources_deposited.emit()
		
		unit.remove_from_selection()
		
		# Torna al lavoro
		if target_mine != null:
			unit.interact_with(target_mine) 
		elif target_resource_tile != Vector2i(-1, -1):
			_find_next_tree(target_resource_tile)
		else:
			clear_gathering_target()
			interaction_finished.emit()

func go_to_dropoff() -> void:
	var closest_building = get_closest_dropoff()
	if closest_building:
		unit.interact_with(closest_building)
	else:
		interaction_finished.emit()

func get_closest_dropoff() -> Node2D:
	var valid_buildings = []
	var all_buildings = get_tree().get_nodes_in_group("buildings")
	
	for building in all_buildings:
		if building.player_id == unit.player_id:
			var drain_component = building.get_node("DrainComponent")
			if drain_component and drain_component.accept_resources(current_resource):
				valid_buildings.append(building)
				
	var closest = null
	var min_distance = INF
	
	for building in valid_buildings:
		var dist = unit.global_position.distance_squared_to(building.global_position)
		if dist < min_distance:
			min_distance = dist
			closest = building
			
	return closest

func clear_gathering_target() -> void:
	target_mine = null
	target_resource_tile = Vector2i(-1, -1)
	action_timer = 0.0

func is_valid_dropoff(entity: BaseBuilding) -> bool:
	if entity != null and entity.has_method("accept_resources"):
		return entity.accept_resources(current_resource)
	
	return false
