class_name Peasant
extends BaseUnit

const PEASANT_TEXTURES = {
	Color.BLACK: preload("res://assets/art/race/humans/units/peasant/Humans_Peasant_BLACK.png"),
	Color.BLUE: preload("res://assets/art/race/humans/units/peasant/Humans_Peasant_BLUE.png"),
	Color.GREEN: preload("res://assets/art/race/humans/units/peasant/Humans_Peasant_GREEN.png"),
	Color.ORANGE: preload("res://assets/art/race/humans/units/peasant/Humans_Peasant_ORANGE.png"),
	Color.RED: preload("res://assets/art/race/humans/units/peasant/Humans_Peasant_RED.png"),
	Color.VIOLET: preload("res://assets/art/race/humans/units/peasant/Humans_Peasant_VIOLET.png"),
	Color.WHITE: preload("res://assets/art/race/humans/units/peasant/Humans_Peasant_WHITE.png"),
	Color.YELLOW: preload("res://assets/art/race/humans/units/peasant/Humans_Peasant_YELLOW.png"),
}

# --- PARAMETRI CONFIGURABILI DALL'INSPECTOR ---


# --- COMPONENTS ---
@onready var gathering_component: GatheringComponent = $GatheringComponent
@onready var build_component: BuildComponent = $BuildComponent

# TODO: Building variables (Da valutare in futuro, per ora le teniamo)
var is_building: bool: 
	get: return build_component.is_building if build_component else false

# --- GESTIONE BASE ---

func _ready() -> void:	
	super._ready()

	# Team color
	_apply_team_color(Color.BLUE)
	
	# Set Gathering component
	if gathering_component:
		gathering_component.interaction_finished.connect(_on_gathering_finished)
		gathering_component.resources_deposited.connect(_on_resources_deposited)
		gathering_component.mine_entered.connect(_on_mine_entered)
		gathering_component.mine_exited.connect(_on_mine_exited)

func setup(data: Resource) -> void:
	super(data)
	# Set Gathering component
	if gathering_component:
		gathering_component.setup(data)
	# Set Build component
	if build_component:
		build_component.setup(data)

func _process(delta: float) -> void:
	#super(delta)
	if unit_state == UnitState.CHOPPING and gathering_component:
		gathering_component.process_chopping(delta)

# Quando l'unità muore, pulisce tutto in automatico
func die() -> void:
	clear_assignment()
	super()


# --- GESTIONE INTERAZIONE E MINIERA ---

func _start_interaction(target: Node2D) -> void:
	
	if target is GoldMine:
		current_assignment = AssignmentState.GATHER_GOLD
		gathering_component.interact_with_mine(target)
		
	# --- 2. GESTIONE COSTRUZIONE E RIPARAZIONE ---
	if target is ProductionBuilding:
		# Se l'edificio è in cantiere e il nostro ordine era BUILD
		if target.is_under_construction and current_assignment == AssignmentState.BUILD:
			unit_state = UnitState.BUILDING # Forza lo stato
			target.register_builder(self)
			deselect()
			# Si gira verso il centro dell'edificio
			last_facing_dir = (target.global_position - global_position).normalized()
			# Aggiorna l'albero di animazione
			update_animation()
			
		# Gestione analoga se stiamo RIPARANDO un edificio danneggiato
		elif target.is_damaged() and current_assignment == AssignmentState.REPAIR:
			unit_state = UnitState.REPARING
			target.register_builder(self)
			deselect()
			# Si gira verso il centro dell'edificio
			last_facing_dir = (target.global_position - global_position).normalized()
			# Aggiorna l'albero di animazione
			update_animation()
			
	# --- 3. GESTIONE DEPOSITO (Municipio / Lumber Mill) ---
		elif target.is_resource_dropoff:
			gathering_component.deposit_resources(target)

# Quando arriva adiacente all'albero
func _start_tile_interaction(tile_coords: Vector2i) -> void:
	if GridManager.is_tree(tile_coords):
		unit_state = UnitState.CHOPPING
		current_assignment = AssignmentState.GATHER_WOOD
	gathering_component.interact_with_tree(tile_coords)
	update_animation()

func interact_with(target: Node2D) -> void:
	if unit_state == UnitState.MINING: return
	super(target)

func interact_with_tile(tile_coords: Vector2i, safe_destination: Vector2) -> void:
	if unit_state == UnitState.MINING: return
	super(tile_coords, safe_destination)

func enter_mine(mine: GoldMine) -> void:
	if gathering_component:
		gathering_component.enter_mine(mine)

func exit_mine(gold_amount: int) -> void:
	if gathering_component:
		gathering_component.exit_mine(gold_amount, current_target)


# --- REAZIONI AI SEGNALI DEL COMPONENTE ---

func _on_mine_entered() -> void:
	unit_state = UnitState.MINING
	update_animation()

func _on_mine_exited() -> void:
	unit_state = UnitState.MOVING
	update_animation()
	
func _on_resources_deposited() -> void:
	unit_state = UnitState.IDLE
	update_animation()

func _on_gathering_finished() -> void:
	clear_assignment()


# --- GESTIONE BUILD ---

# Sovrascriviamo la funzione del padre per aggiungere le pulizie specifiche del contadino
func clear_assignment() -> void:
	if unit_state == UnitState.MINING:
		return
	is_building = false
	if gathering_component:
		gathering_component.clear_gathering_target()
	super()

func _apply_team_color(color: Color) -> void:
	if not sprite2d:
		return
		
	if PEASANT_TEXTURES.has(color):
		sprite2d.texture = PEASANT_TEXTURES[color]
	else:
		push_warning("Nessuna texture trovata per il colore: ", color)

func move_to(target_pos: Vector2) -> void:
	if unit_state == UnitState.MINING: return
	super(target_pos)

# --- GESTIONE ANIMAZIONWI ---

func update_animation_parameters(move_velocity: Vector2) -> void:
	var move_dir: Vector2 = move_velocity.normalized()
	if move_dir == Vector2.ZERO: return
	animation_tree.set("parameters/Death/blend_position", move_dir)
	animation_tree.set("parameters/Walk/Walk_Normal/blend_position", move_dir)
	animation_tree.set("parameters/Walk/Walk_Gold/blend_position", move_dir)
	animation_tree.set("parameters/Walk/Walk_Wood/blend_position", move_dir)
	animation_tree.set("parameters/Idle/Idle_Normal/blend_position", move_dir)
	animation_tree.set("parameters/Idle/Idle_Gold/blend_position", move_dir)
	animation_tree.set("parameters/Idle/Idle_Wood/blend_position", move_dir)
	animation_tree.set("parameters/Attack/blend_position", move_dir)
	
	var resource_type = gathering_component.current_resource if gathering_component else Globals.ResourceType.NONE
	match resource_type:
		Globals.ResourceType.NONE:
			animation_tree.set("parameters/Walk/ResourceState/transition_request", "Normal")
			animation_tree.set("parameters/Idle/ResourceState/transition_request", "Normal")
		Globals.ResourceType.GOLD:
			animation_tree.set("parameters/Walk/ResourceState/transition_request", "Gold")
			animation_tree.set("parameters/Idle/ResourceState/transition_request", "Gold")
		Globals.ResourceType.WOOD:
			animation_tree.set("parameters/Walk/ResourceState/transition_request", "Wood")
			animation_tree.set("parameters/Idle/ResourceState/transition_request", "Wood")

func update_animation() -> void:
	if not animation_tree or not state_machine:
		return

	var actual_speed: float = velocity.length()
	# Se il componente di movimento c'è ed è attivo, legge la sua intended_dir.
	# Altrimenti usa last_facing_dir memorizzata nella BaseUnit.
	var move_dir: Vector2 = movement_component.intended_dir if (movement_component and movement_component.is_moving) else last_facing_dir
	
	if move_dir == Vector2.ZERO:
		move_dir = last_facing_dir
	
	update_animation_parameters(move_dir)
	
	if is_dead:
		state_machine.travel("Death")
		animation_state = "Death"
	else:
		#if is_moving and actual_speed > 10.0:
		if unit_state == UnitState.MOVING and actual_speed > 10.0:
			last_facing_dir = move_dir
			state_machine.travel("Walk")
			animation_state = "Walk"
		elif unit_state == UnitState.RETURNING_RESOURCES:
			last_facing_dir = move_dir
			state_machine.travel("Walk")
			animation_state = "Walk"
		elif unit_state == UnitState.ATTACKING:
			state_machine.travel("Attack")
			animation_state = "Attack"
		elif unit_state == UnitState.CHOPPING:
			state_machine.travel("Attack")
			animation_state = "Attack"
		elif unit_state == UnitState.MINING:
			state_machine.travel("Idle")
			animation_state = "Idle"
		elif unit_state == UnitState.BUILDING or unit_state == UnitState.REPARING:
			state_machine.travel("Attack")
			animation_state = "Attack"
		else:
			state_machine.travel("Idle")
			animation_state = "Idle"
	
	# Gestione del flip orizzontale dello Sprite
	if move_dir.x < -0.1:
		sprite2d.flip_h = true
	elif move_dir.x > 0.1:
		sprite2d.flip_h = false
