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
@export_group("Building")
@export var build_range: float = 40.0
@export var chop_speed: float =  1.0 # Quanto tempo ci mette per dare un colpo di ascia (in secondi)
@export var max_carry: int =  10 # Quanta legna può portare

var enter_direction: Vector2 = Vector2.DOWN

# TODO: Building variables (Da valutare in futuro, per ora le teniamo)
var is_building: bool = false

# Collecting variables
var target_mine: GoldMine = null
var target_resource_tile: Vector2i = Vector2i(-1, -1):
	set(value):
		if target_resource_tile != Vector2i(-1, -1) and GridManager:
			GridManager.remove_tile_highlight(target_resource_tile)
			
		target_resource_tile = value
		
		if target_resource_tile != Vector2i(-1, -1) and GridManager:
			GridManager.add_tile_highlight(target_resource_tile)
var current_resource: Globals.ResourceType = Globals.ResourceType.NONE
var resource_amount: int = 0
var action_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_apply_team_color(Color.BLUE)

func _process(delta: float) -> void:
	super(delta)
	
	# --- CICLO DI TAGLIO LEGNA ---
	if unit_state == UnitState.CHOPPING:
		action_timer -= delta
		if action_timer <= 0.0:
			action_timer = chop_speed
			_perform_chop()

# --- GESTIONE INTERAZIONE E MINIERA ---

func _start_interaction(target: Node2D) -> void:
	# --- GESTIONE COSTRUZIONE E RIPARAZIONE ---
	if target is BaseBuilding:
		# Se l'edificio è in cantiere e il nostro ordine era BUILD
		if target.is_under_construction and current_assignment == AssignmentState.BUILD:
			unit_state = UnitState.BUILDING # Forza lo stato
			#target_building = target
			target.register_builder(self)
			
			# Si gira verso il centro dell'edificio
			intended_dir = (target.global_position - global_position).normalized()
			last_facing_dir = intended_dir
			
			# Aggiorna l'albero di animazione
			update_animation()

		# Gestione analoga se stiamo RIPARANDO un edificio danneggiato
		elif target.is_damaged() and current_assignment == AssignmentState.REPAIR:
			unit_state = UnitState.REPARING
			#target_building = target
			target.register_builder(self)
			intended_dir = (target.global_position - global_position).normalized()
			last_facing_dir = intended_dir
			update_animation()
	
# --- 1. GESTIONE MINIERA ---
	elif target is GoldMine:
		target_resource_tile = Vector2i(-1, -1) # Dimentica la legna
		action_timer = 0.0
		
		if current_resource != Globals.ResourceType.NONE and resource_amount > 0:
			print("Ho già delle risorse! Vado a depositarle al Municipio.")
			current_assignment = AssignmentState.GATHER_GOLD
			target_mine = target # <- SALVA IN MEMORIA LA MINIERA
			_go_to_town_hall()
			return
		
		current_assignment = AssignmentState.GATHER_GOLD
		target_mine = target # <- SALVA IN MEMORIA LA MINIERA
		
		if target.has_method("register_worker"):
			var success = target.register_worker(self)
			if not success:
				print("Miniera piena!")
				clear_assignment() 
	
	# --- 2. GESTIONE DEPOSITO (Municipio / Lumber Mill) ---
	elif target.is_in_group("town_hall") or target.is_in_group("lumber_mill"):
		if current_resource != Globals.ResourceType.NONE and resource_amount > 0:
			if current_resource == Globals.ResourceType.GOLD: player_owner.add_gold(resource_amount)
			elif current_resource == Globals.ResourceType.WOOD: player_owner.add_lumber(resource_amount)
			elif current_resource == Globals.ResourceType.OIL: player_owner.add_oil(resource_amount)

			current_resource = Globals.ResourceType.NONE
			resource_amount = 0
			unit_state = UnitState.IDLE
			update_animation()
			
			# LEGGE DALLA MEMORIA SICURA (target_mine e target_resource_tile)
			if current_assignment == AssignmentState.GATHER_GOLD and target_mine != null:
				interact_with(target_mine) 
			elif current_assignment == AssignmentState.GATHER_WOOD and target_resource_tile != Vector2i(-1, -1):
				_find_next_tree(target_resource_tile)
			else:
				clear_assignment()

func enter_mine(mine: GoldMine) -> void:
	if !is_instance_valid(current_target) or current_target.is_depleted:
		return
	
	#is_moving = false
	unit_state = UnitState.MINING
	
	velocity = Vector2.ZERO
	set_physics_process(false) # Spostato qui in alto!

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
	
	# Sganciamo il Peasant dalla selezione attiva del giocatore
	var sm = get_tree().get_first_node_in_group("selection_manager")
	if sm and sm.currently_selected.has(self):
		sm.currently_selected.erase(self)
		sm.selection_changed.emit(sm.currently_selected)
	
	# --- NUOVO: Calcolo dinamico della durata basato su move_speed ---
	var distance = global_position.distance_to(mine.global_position)
	# Usiamo move_speed (con un moltiplicatore opzionale se vuoi renderlo un po' più scattante)
	var speed = max(move_speed, 1.0) # Evita divisioni per zero
	var total_duration: float = distance / speed
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
	# 1. Riattiviamo il process normale e rendiamo visibile il nodo[cite: 1]
	set_process(true)
	visible = true
	
	if unit_sprite:
		unit_sprite.modulate.a = 0.0

	# 2. Calcoliamo la posizione di uscita[cite: 1]
	var exit_position = global_position
	
	if current_target and is_instance_valid(current_target) and GridManager.tile_map_layer:
		# Passiamo la posizione della miniera, la sua dimensione in tile (3x3), 
		# la direzione di entrata e il peasant stesso per i controlli di collisione
		exit_position = GridManager.get_adjacent_free_position(current_target.global_position, Vector2i(3, 3), enter_direction, self)
	else:
		# Fallback se manca il target
		exit_position = global_position + (enter_direction * 32.0)

	# 2. Impostiamo la direzione verso cui è rivolto mentre esce[cite: 1]
	# Calcolo dinamico della durata basato su move_speed ---
	var distance = global_position.distance_to(exit_position)
	var speed = max(move_speed, 1.0) # Evita divisioni per zero
	var total_duration: float = distance / speed
	var half_duration: float = total_duration * 0.5

	var exit_direction = (exit_position - global_position).normalized()
	if exit_direction != Vector2.ZERO:
		intended_dir = exit_direction
		last_facing_dir = exit_direction

	# 3. Forziamo l'animazione di camminata ("Walk") durante l'uscita[cite: 1]
	unit_state = UnitState.MOVING
	update_animation()

	# 4. Tween di movimento e dissolvenza[cite: 1]
	var tween = create_tween()
	tween.tween_property(self, "global_position", exit_position, total_duration)

	if unit_sprite:
		var tween_fade = create_tween()
		tween_fade.tween_interval(half_duration)
		tween_fade.tween_property(unit_sprite, "modulate:a", 1.0, half_duration)

	# ASPETTIAMO CHE IL MOVIMENTO DI USCITA SIA FINITO
	await tween.finished

	# 5. Fine movimento: fermiamo l'animazione di camminata[cite: 1]
	unit_state = UnitState.IDLE
	update_animation()

	# 6. Riattivazione collisioni e avoidance[cite: 6]
	if has_node("CollisionShape2D"):
		collision_shape.set_deferred("disabled", false)
	
	if has_node("NavigationAgent2D"):
		nav_agent.avoidance_enabled = true
		nav_agent.set_velocity(Vector2.ZERO) # Pulisce la memoria in uscita
		nav_agent.target_position = global_position
		
	if has_node("HealthBar"):
		health_bar.visible = true
	
	if has_node("SelectableComponent"):
		if !is_in_group("selectable_units"):
			add_to_group("selectable_units")
			
	deselect()
	
	# 3. PAUSA DI SINCRONIZZAZIONE: Diamo a Godot il tempo di capire le nuove coordinate
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# SOLO ORA riattiviamo la fisica
	set_physics_process(true)
	
	# 7. Gestione oro / prossimo obiettivo[cite: 6]
	if gold_amount > 0:
		current_resource = Globals.ResourceType.GOLD
		resource_amount = gold_amount
		print("Uscito dalla miniera con ", gold_amount, " di oro.")
		_go_to_town_hall()
	else:
		unit_state = UnitState.IDLE
		current_target = null

func _go_to_town_hall():
	var valid_buildings = []
	
	# Recupera gli edifici dalla scena tramite i gruppi assegnati
	var town_halls = get_tree().get_nodes_in_group("town_hall")
	var lumber_mills = get_tree().get_nodes_in_group("lumber_mill")
	
	# Di base, consideriamo sempre le TownHall come potenziali destinazioni
	var potential_targets = town_halls.duplicate()
	
	# 1) Se il contadino porta legno, aggiungiamo anche i Lumber Mill alle opzioni
	if current_resource == Globals.ResourceType.WOOD:
		potential_targets.append_array(lumber_mills)
		
	# 2) Filtriamo i risultati in base al player_id
	for building in potential_targets:
		if building.player_id == self.player_id:
			valid_buildings.append(building)
			
	# 3) Troviamo l'edificio valido più vicino
	var closest_building = null
	var min_distance = INF # Inizializziamo a infinito per il primo confronto
	for building in valid_buildings:
		# Usiamo distance_squared_to per evitare il calcolo della radice quadrata, ottimizzando le performance
		var dist = global_position.distance_squared_to(building.global_position)

		if dist < min_distance:
			min_distance = dist
			closest_building = building
			
	# Assegniamo la destinazione finale al NavigationAgent2D
	if closest_building:
		interact_with(closest_building)
	else:
		print("Nessun centro di deposito trovato per il Player ", player_id)

# Quando arriva adiacente all'albero
func _start_tile_interaction(tile_coords: Vector2i) -> void:
	if current_resource != Globals.ResourceType.NONE and resource_amount > 0:
		current_assignment = AssignmentState.GATHER_WOOD
		target_resource_tile = tile_coords # <- SALVA L'ALBERO IN MEMORIA
		_go_to_town_hall()
		return 
		
	if GridManager.is_tree(tile_coords):
		target_mine = null # Dimentica la miniera
		unit_state = UnitState.CHOPPING
		current_assignment = AssignmentState.GATHER_WOOD
		target_resource_tile = tile_coords # <- SALVA L'ALBERO IN MEMORIA
		action_timer = chop_speed
		
		var tree_global_pos = GridManager.get_tile_center_global(tile_coords)
		intended_dir = (tree_global_pos - global_position).normalized()
		last_facing_dir = intended_dir 
		update_animation()
	else:
		if current_assignment == AssignmentState.GATHER_WOOD:
			_find_next_tree(tile_coords)

# Il colpo d'ascia effettivo (chiamato dal _process ogni secondo)
func _perform_chop() -> void:
	var obtained = GridManager.chop_tree(target_resource_tile, 5) # <- corretto
	
	if obtained > 0:
		current_resource = Globals.ResourceType.WOOD
		resource_amount += obtained
		
		if resource_amount >= max_carry:
			unit_state = UnitState.IDLE 
			_go_to_town_hall()
	else:
		_find_next_tree(target_resource_tile) # <- corretto

# Ricerca un nuovo albero vicino a quello appena tagliato
func _find_next_tree(start_tile: Vector2i) -> void:
	var next_tree = GridManager.get_closest_tree_around(start_tile, 5)
	
	if next_tree != Vector2i(-1, -1):
		var tree_global = GridManager.get_tile_center_global(next_tree)
		var safe_pos = GridManager.get_adjacent_free_position(tree_global, Vector2i(1, 1), Vector2.DOWN, self)
		interact_with_tile(next_tree, safe_pos) 
	else:
		if resource_amount > 0:
			_go_to_town_hall()
		else:
			clear_assignment() # Nessuna legna, nessun albero: fermati del tutto.

# --- GESTIONE BUILD ---

func assign_build_task(building: BaseBuilding) -> void:
	clear_assignment() # Azzera ordini precedenti
	current_assignment = AssignmentState.BUILD
	interact_with(building)

# --- GESTIONE ANIMAZIONWI ---

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
	var move_dir: Vector2 = intended_dir

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
	
	if move_dir.x < -0.1:
		unit_sprite.flip_h = true
	elif move_dir.x > 0.1:
		unit_sprite.flip_h = false
		
# Sovrascriviamo la funzione del padre per aggiungere le pulizie specifiche del contadino
func clear_assignment() -> void:
	if unit_state == UnitState.MINING:
		return
	target_mine = null
	target_resource_tile = Vector2i(-1, -1)
	action_timer = 0.0
	is_building = false
	super()

func _apply_team_color(color: Color) -> void:
	if not unit_sprite:
		return
		
	if PEASANT_TEXTURES.has(color):
		unit_sprite.texture = PEASANT_TEXTURES[color]
	else:
		push_warning("Nessuna texture trovata per il colore: ", color)

# Quando l'unità muore, pulisce tutto in automatico
func die() -> void:
	clear_assignment() # <- Usa la funzione del padre
	super()

func move_to(target_pos: Vector2, arrival_offset: float = 16.0) -> void:
	if unit_state == UnitState.MINING: return
	super(target_pos, arrival_offset)

func interact_with(target: Node2D) -> void:
	if unit_state == UnitState.MINING: return
	super(target)

func interact_with_tile(tile_coords: Vector2i, safe_destination: Vector2) -> void:
	if unit_state == UnitState.MINING: return
	super(tile_coords, safe_destination)
