class_name Peasant
extends BaseUnit

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
const CHOP_SPEED: float = 1.0 # Quanto tempo ci mette per dare un colpo di ascia (in secondi)
const MAX_CARRY: int = 10     # Quanta legna può portare

# --- PARAMETRI CONFIGURABILI DALL'INSPECTOR ---
@export_group("Building")
@export var build_range: float = 40.0

var enter_direction: Vector2 = Vector2.DOWN

# Building variables
var is_building: bool = false
var target_building: BaseBuilding = null

# Mining variables
var target_mine: GoldMine = null
var current_resource: Globals.ResourceType = Globals.ResourceType.NONE
#var is_collecting: bool = false
var resource_amount: int = 0
#var target_resource_tile: Vector2i = Vector2i(-1, -1) Solo DEBUG
var action_timer: float = 0.0

# Automatismo per il feedback visivo dell'albero in fase di taglio
var target_resource_tile: Vector2i = Vector2i(-1, -1):
	set(value):
		if target_resource_tile != Vector2i(-1, -1) and GridManager:
			GridManager.remove_tile_highlight(target_resource_tile)
			
		target_resource_tile = value
		
		if target_resource_tile != Vector2i(-1, -1) and GridManager:
			GridManager.add_tile_highlight(target_resource_tile)

func _ready() -> void:
	super._ready()
	_apply_team_color(Color.BLUE)

func _process(delta: float) -> void:
	super(delta)
	_handle_building_logic()
	
	# --- CICLO DI TAGLIO LEGNA ---
	if unit_state == UnitState.CHOPPING:
		action_timer -= delta
		if action_timer <= 0.0:
			action_timer = CHOP_SPEED
			_perform_chop()

# --- GESTIONE INTERAZIONE E MINIERA ---

func _start_interaction(target: Node2D) -> void:
	# 1. Sganciamento dal eventuale altra attività
	_stop_collecting_task()
	
	# --- 1. GESTIONE MINIERA (Raccolta) ---
	if target is GoldMine:
		# --- DIMENTICA LA LEGNA ---
		target_resource_tile = Vector2i(-1, -1) 
		unit_state = UnitState.IDLE # Resetta eventuali stati di chopping
		
		# CONTROLLO: Il contadino ha già delle risorse in tasca?
		if current_resource != Globals.ResourceType.NONE and resource_amount > 0:
			print("Ho già delle risorse! Vado a depositarle al Municipio.")
			_go_to_town_hall()
			return
			
		# Se le tasche sono vuote, procede normalmente con l'ingresso
		target_mine = target
		#is_collecting = true
		
		if target.has_method("register_worker"):
			var success = target.register_worker(self)
			if not success:
				print("Miniera piena, non posso entrare!")
	
	# --- 2. GESTIONE DEPOSITO (Municipio o Lumber Mill) ---
	elif target.is_in_group("town_hall") or target.is_in_group("lumber_mill"):
		
		if current_resource != Globals.ResourceType.NONE and resource_amount > 0:
			print("Scaricato ", resource_amount, " risorse alla base!")
			
			# Qui è dove dirai al gioco di aggiungere effettivamente i soldi al giocatore.
			# Esempio: GameManager.add_resource(player_id, current_resource, resource_amount)
			if current_resource == Globals.ResourceType.GOLD:
				player_owner.add_gold(resource_amount)
			elif current_resource == Globals.ResourceType.WOOD:
				player_owner.add_lumber(resource_amount)
			elif current_resource == Globals.ResourceType.OIL:
				player_owner.add_oil(resource_amount)

			# 1. Svuotiamo lo zaino del contadino
			current_resource = Globals.ResourceType.NONE
			resource_amount = 0
			unit_state = UnitState.IDLE
			update_animation() # Questo farà tornare l'animazione senza sacco d'oro
			
			# 2. Torna automaticamente a lavorare
			if target_mine and is_instance_valid(target_mine):
				print("Oro scaricato. Torno in miniera!")
				interact_with(target_mine)
			elif target_resource_tile != Vector2i(-1, -1):
				print("Legna scaricata. Torno nella foresta!")
				_find_next_tree(target_resource_tile)
			else:
				print("Lavoro finito, attendo ordini.")

func enter_mine(mine: GoldMine) -> void:
	if !is_instance_valid(target_mine) or target_mine.is_depleted:
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
	
	if target_mine and is_instance_valid(target_mine) and GridManager.tile_map_layer:
		# Passiamo la posizione della miniera, la sua dimensione in tile (3x3), 
		# la direzione di entrata e il peasant stesso per i controlli di collisione
		exit_position = GridManager.get_adjacent_free_position(target_mine.global_position, Vector2i(3, 3), enter_direction, self)
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
	#is_moving = true
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
	#is_moving = false
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
		target_mine = null

func _go_to_town_hall():
	unit_state = UnitState.RETURNING_RESOURCES
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
		#nav_agent.target_position = closest_building.global_position
		# Inserisci qui l'eventuale cambio di stato (es. cambiare l'animazione o avviare il movimento)
	else:
		print("Nessun centro di deposito trovato per il Player ", player_id)

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
		state = "Death"
	else:
		#if is_moving and actual_speed > 10.0:
		if unit_state == UnitState.MOVING and actual_speed > 10.0:
			last_facing_dir = move_dir
			state_machine.travel("Walk")
			state = "Walk"
		elif unit_state == UnitState.RETURNING_RESOURCES:
			last_facing_dir = move_dir
			state_machine.travel("Walk")
			state = "Walk"
		elif unit_state == UnitState.ATTACKING:
			state_machine.travel("Attack")
			state = "Attack"
		elif unit_state == UnitState.CHOPPING:
			state_machine.travel("Attack")
			state = "Attack"
		elif unit_state == UnitState.MINING:
			state_machine.travel("Idle")
			state = "Idle"
		elif unit_state == UnitState.BUILDING or unit_state == UnitState.REPARING:
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

func _apply_team_color(color: Color) -> void:
	if not unit_sprite:
		return
		
	if PEASANT_TEXTURES.has(color):
		unit_sprite.texture = PEASANT_TEXTURES[color]
	else:
		push_warning("Nessuna texture trovata per il colore: ", color)

# Quando arriva adiacente all'albero
# Quando arriva adiacente all'albero
func _start_tile_interaction(tile_coords: Vector2i) -> void:
	# 1. Sganciamento dal eventuale altra attività
	_stop_collecting_task()

	# 2. Controllo se zaino pieno
	# Se il contadino ha già della legna e clicchi un albero, prima deve
	# andare a depositare le risorse al volo!
	if current_resource != Globals.ResourceType.WOOD and resource_amount > 0:
		print("Ho già delle risorse! Vado a depositarle alla base.")
		_go_to_town_hall()
		return # Blocca l'inizio del taglio
		
	# 3. Verifico che il tile sia un albero e che non sia stato già
	#  tagliato via
	if GridManager.is_tree(tile_coords):
		# Dimentico la miniera
		target_mine = null 
		# Mel caso abbia altre risorse che non erano legno altrimenti le 
		# avrei depositate, le getto via
		resource_amount = 0
		current_resource != Globals.ResourceType.NONE
		
		unit_state = UnitState.CHOPPING
		target_resource_tile = tile_coords
		action_timer = CHOP_SPEED
		
		# Gira lo sprite verso l'albero (Aggiorniamo la memoria permanente della direzione!)
		var tree_global_pos = GridManager.get_tile_center_global(tile_coords)
		var face_direction = (tree_global_pos - global_position).normalized()
		
		intended_dir = face_direction
		last_facing_dir = face_direction # <-- LA RIGA MAGICA
		
		update_animation()
		
	# --- 3. Albero già tagliato mentre ci arrivava, ne cerca un altro
	else:
		print("Albero non trovato all'arrivo! Ne cerco un altro vicino...")
		# Invece di fermarsi a caso, cerca automaticamente il prossimo albero
		_find_next_tree(tile_coords)

# Il colpo d'ascia effettivo (chiamato dal _process ogni secondo)
func _perform_chop() -> void:
	# Infligge 5 danni all'albero e ottiene legna
	var obtained = GridManager.chop_tree(target_resource_tile, 5) 
	
	if obtained > 0:
		current_resource = Globals.ResourceType.WOOD
		resource_amount += obtained
		
		print("Legna attuale: ", resource_amount)
		
		if resource_amount >= MAX_CARRY:
			print("Zaino pieno! Torno alla base.")
			unit_state = UnitState.IDLE # Reset prima del viaggio
			_go_to_town_hall()
	else:
		# L'albero è crollato prima di riempire lo zaino! 
		# Dobbiamo cercare il prossimo albero a partire da qui.
		_find_next_tree(target_resource_tile)

# Ricerca un nuovo albero vicino a quello appena tagliato
func _find_next_tree(start_tile: Vector2i) -> void:
	var next_tree = GridManager.get_closest_tree_around(start_tile, 5)
	
	if next_tree != Vector2i(-1, -1):
		# Trovato! Calcoliamo il tile adiacente per metterci vicini
		var tree_global = GridManager.get_tile_center_global(next_tree)
		# Usiamo la funzione del GridManager fingendo che l'albero sia 1x1
		var safe_pos = GridManager.get_adjacent_free_position(tree_global, Vector2i(1, 1), Vector2.DOWN, self)
		
		print("Nuovo albero trovato! Ci vado.")
		interact_with_tile(next_tree, safe_pos)
	else:
		print("Foresta disboscata! Nessun albero nel raggio.")
		unit_state = UnitState.IDLE
		target_resource_tile = Vector2i(-1, -1)
		
		# Se ha almeno un po' di legna nello zaino, la porta a casa
		if resource_amount > 0:
			_go_to_town_hall()

func _stop_collecting_task() -> void:
	# --- 1. STOP ORO ---
	if unit_state == UnitState.MINING:
		if target_mine and is_instance_valid(target_mine):
			# Nota: prima avevamo usato "unassign_worker", controlla quale nome usi nella GoldMine!
			if target_mine.has_method("unregister_worker"):
				target_mine.unregister_worker(self)
		target_mine = null 
		
	# --- 2. STOP LEGNA ---
	elif unit_state == UnitState.CHOPPING:
		# Azzera le coordinate. Questo farà scattare il Setter,
		# che chiederà al GridManager di spegnere il quadrato verde!
		target_resource_tile = Vector2i(-1, -1)
		
		# Resetta il timer del colpo d'ascia
		action_timer = 0.0
	
	# --- 3. STOP BUILDING ---
	elif unit_state == UnitState.BUILDING:
		_stop_current_building_task()
	
	# --- 4. PULIZIA GENERALE ---
	# A prescindere da cosa stava facendo, torna in stato di riposo
	unit_state = UnitState.IDLE
	
	# Chiama l'aggiornamento grafico: 
	# non essendo più in CHOPPING, fermerà l'animazione dell'ascia
	update_animation()


func die() -> void:
	_stop_collecting_task()
	super()
