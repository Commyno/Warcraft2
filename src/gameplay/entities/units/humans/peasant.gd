class_name Peasant
extends BaseUnit

enum PeasantState { IDLE, MOVING, MINING, RETURNING_GOLD }
enum ResourceType { NONE, WOOD, GOLD }

const PEASANT_TEXTURES = {
	Color.BLACK: preload("res://assets/spritesheets/humans/units/peasant/Humans_Peasant_BLACK.png"),
	Color.BLUE: preload("res://assets/spritesheets/humans/units/peasant/Humans_Peasant_BLUE.png"),
	Color.GREEN: preload("res://assets/spritesheets/humans/units/peasant/Humans_Peasant_GREEN.png"),
	Color.ORANGE: preload("res://assets/spritesheets/humans/units/peasant/Humans_Peasant_ORANGE.png"),
	Color.RED: preload("res://assets/spritesheets/humans/units/peasant/Humans_Peasant_RED.png"),
	Color.VIOLET: preload("res://assets/spritesheets/humans/units/peasant/Humans_Peasant_VIOLET.png"),
	Color.WHITE: preload("res://assets/spritesheets/humans/units/peasant/Humans_Peasant_WHITE.png"),
	Color.YELLOW: preload("res://assets/spritesheets/humans/units/peasant/Humans_Peasant_YELLOW.png"),
}

@export var player_id: int = 1 : set = _set_player_id
@export var player_color: Color = Color.BLUE : set = _set_player_color
@export var build_range: float = 40.0

var peasant_state: PeasantState = PeasantState.IDLE
var enter_direction: Vector2 = Vector2.DOWN

# Building variables
var target_building: BaseBuilding = null
var is_building: bool = false

# Mining variables
var target_mine: GoldMine = null
var current_resource: ResourceType = ResourceType.NONE
var is_collecting: bool = false
var resource_amount: int = 0

func _ready() -> void:
	super._ready()
	_apply_team_color(Color.BLUE)

func _process(delta: float) -> void:
	super._process(delta)
	_handle_building_logic()

# --- GESTIONE INTERAZIONE E MINIERA ---

func _start_interaction(target: Node2D) -> void:
	if target is GoldMine:
		target_mine = target
		is_collecting = true
		
		if target.has_method("assign_worker"):
			var success = target.assign_worker(self)
			if not success:
				print("Miniera piena, non posso entrare!")

func enter_mine(mine: GoldMine) -> void:
	peasant_state = PeasantState.MINING
	
	# 1. Memorizziamo la direzione da cui è entrato rispetto al centro della miniera
	enter_direction = (global_position - mine.global_position).normalized()
	if enter_direction == Vector2.ZERO:
		enter_direction = Vector2.DOWN # Fallback di sicurezza

	# 2. Disattiviamo collisioni e avoidance
	if has_node("CollisionShape2D"):
		collision_shape.set_deferred("disabled", true)
	
	if has_node("NavigationAgent2D"):
		nav_agent.avoidance_enabled = false

	if has_node("HealthBar"):
		health_bar.visible = false
	
	if has_node("SelectableComponent"):
		if is_in_group("selectable_units"):
			remove_from_group("selectable_units")
	
	deselect()
		
	var total_duration: float = 0.7
	var half_duration: float = total_duration * 0.5 
	
	# 3. Movimento al centro e fade-out nella prima metà
	var tween_fade = create_tween().set_parallel(true)
	tween_fade.tween_property(self, "global_position", mine.global_position, total_duration)
	if unit_sprite:
		tween_fade.tween_property(unit_sprite, "modulate:a", 0.0, half_duration)
		
	await tween_fade.finished
	
	visible = false
	set_process(false)
	set_physics_process(false)

func exit_mine(gold_amount: int) -> void:
	set_process(true)
	set_physics_process(true)
	visible = true
	
	if unit_sprite:
		unit_sprite.modulate.a = 0.0

	# 2. Calcoliamo la posizione di uscita usando la STESSA direzione d'ingresso
	var exit_position = global_position
	
	if target_mine and is_instance_valid(target_mine) and GridManager.tile_map_layer:
		var mine_tile_coords = GridManager.get_tile_coords(target_mine.global_position)
		
		# Usiamo enter_direction per uscire dallo stesso lato in cui è entrato
		var tile_offset = Vector2i.ZERO
		if abs(enter_direction.x) > abs(enter_direction.y):
			tile_offset.x = 1 if enter_direction.x > 0 else -1
		else:
			tile_offset.y = 1 if enter_direction.y > 0 else -1
			
		var target_exit_tile = mine_tile_coords + tile_offset
		var raw_exit_pos = GridManager.get_global_from_tile(target_exit_tile)
		exit_position = GridManager.get_available_destination(raw_exit_pos, self)
	else:
		# Fallback se manca il target
		exit_position = global_position + (enter_direction * 32.0)

	# 3. Tween di movimento (durata totale 0.7s)
	var total_duration: float = 0.7
	var half_duration: float = total_duration * 0.5

	# 1. Impostiamo la direzione corretta verso cui è rivolto mentre esce
	# Se usciamo da una miniera, la direzione di camminata è opposta a enter_direction (oppure calcolata sul tragitto)
	var exit_direction = (exit_position - global_position).normalized()
	if exit_direction != Vector2.ZERO:
		intended_dir = exit_direction
		last_facing_dir = exit_direction

	# 2. Forziamo l'animazione di camminata ("Walk") durante l'uscita
	is_moving = true
	update_animation()

	# 3. Tween di movimento (durata totale 0.7s)
	var tween = create_tween()
	tween.tween_property(self, "global_position", exit_position, total_duration)

	# 4. Fade-in nella seconda metà del percorso
	if unit_sprite:
		var tween_fade = create_tween()
		tween_fade.tween_interval(half_duration)
		tween_fade.tween_property(unit_sprite, "modulate:a", 1.0, half_duration)

	await tween.finished

	# 5. Fine movimento: fermiamo l'animazione di camminata
	is_moving = false
	update_animation()

	# 5. Riattivazione collisioni e avoidance
	if has_node("CollisionShape2D"):
		collision_shape.set_deferred("disabled", false)

	if has_node("NavigationAgent2D"):
		nav_agent.avoidance_enabled = true

	if has_node("HealthBar"):
		health_bar.visible = true
	
	if has_node("SelectableComponent"):
		if !is_in_group("selectable_units"):
			add_to_group("selectable_units")
	
	deselect()
	
	# 6. Gestione oro / prossimo obiettivo
	if gold_amount > 0:
		current_resource = ResourceType.GOLD
		resource_amount = gold_amount
		print("Uscito dalla miniera con ", gold_amount, " di oro.")
		_go_to_town_hall()
	else:
		peasant_state = PeasantState.IDLE
		target_mine = null

func _go_to_town_hall() -> void:
	peasant_state = PeasantState.RETURNING_GOLD
	
	var town_halls = get_tree().get_nodes_in_group("town_hall")
	if not town_halls.is_empty():
		var target_hall = town_halls[0] 
		move_to(target_hall.global_position)
	else:
		print("Errore: Nessun Municipio trovato sulla mappa!")

func update_animation_parameters(move_velocity: Vector2) -> void:
	var move_dir: Vector2 = move_velocity.normalized()
	animation_tree.set("parameters/Death/blend_position", move_dir)
	animation_tree.set("parameters/Walk/Walk_Normal/blend_position", move_dir)
	animation_tree.set("parameters/Walk/Walk_Gold/blend_position", move_dir)
	animation_tree.set("parameters/Walk/Walk_Wood/blend_position", move_dir)
	animation_tree.set("parameters/Idle/Idle_Normal/blend_position", move_dir)
	animation_tree.set("parameters/Idle/Idle_Gold/blend_position", move_dir)
	animation_tree.set("parameters/Idle/Idle_Wood/blend_position", move_dir)
	animation_tree.set("parameters/Attack/blend_position", move_dir)
	
	match current_resource:
		ResourceType.NONE:
			animation_tree.set("parameters/Walk/ResourceState/transition_request", "Normal")
			animation_tree.set("parameters/Idle/ResourceState/transition_request", "Normal")
		ResourceType.GOLD:
			animation_tree.set("parameters/Walk/ResourceState/transition_request", "Gold")
			animation_tree.set("parameters/Idle/ResourceState/transition_request", "Gold")
		ResourceType.WOOD:
			animation_tree.set("parameters/Walk/ResourceState/transition_request", "Wood")
			animation_tree.set("parameters/Idle/ResourceState/transition_request", "Wood")

func update_animation() -> void:
	if not animation_tree or not state_machine:
		return

	var actual_speed: float = velocity.length()
	var move_dir: Vector2 = intended_dir

	if move_dir == Vector2.ZERO:
		move_dir = last_facing_dir
	
	update_animation_parameters(move_dir)
	
	if is_dead:
		state_machine.travel("Death")
		state = "Death"
	else:
		if is_moving and actual_speed > 10.0:
			last_facing_dir = move_dir
			state_machine.travel("Walk")
			state = "Walk"
		elif is_attacking:
			state_machine.travel("Attack")
			state = "Attack"
		else:
			state_machine.travel("Idle")
			state = "Idle"
	
	if move_dir.x < -0.1:
		unit_sprite.flip_h = true
	elif move_dir.x > 0.1:
		unit_sprite.flip_h = false

func assign_build_task(building: BaseBuilding) -> void:
	_stop_current_building_task()
	target_building = building
	move_to(building.global_position)

func stop_or_change_task() -> void:
	_stop_current_building_task()
	
func _handle_building_logic() -> void:
	if not target_building or not is_instance_valid(target_building):
		_stop_current_building_task()
		return
		
	if not target_building.is_under_construction:
		_stop_current_building_task()
		return
	
	var distance = global_position.distance_to(target_building.global_position)
	
	if distance <= build_range:
		if nav_agent and not nav_agent.is_navigation_finished():
			nav_agent.target_position = global_position
			
		if not is_building:
			is_building = true
			target_building.register_builder(self)
	elif is_building and distance > build_range:
		is_building = false
		target_building.unregister_builder(self)
		
func _stop_current_building_task() -> void:
	if is_building and target_building and is_instance_valid(target_building):
		target_building.unregister_builder(self)
		
	is_building = false
	target_building = null

func _set_player_id(new_id: int) -> void:
	player_id = new_id

func _set_player_color(color: Color) -> void:
	player_color = color
	_apply_team_color(color)

func _apply_team_color(color: Color) -> void:
	if not unit_sprite:
		return
		
	if PEASANT_TEXTURES.has(color):
		unit_sprite.texture = PEASANT_TEXTURES[color]
	else:
		push_warning("Nessuna texture trovata per il colore: ", color)
