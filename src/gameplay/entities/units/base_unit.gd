class_name BaseUnit
extends CharacterBody2D

# --- ENUMERATORI PER TIPI DI DANNO E ARMATURA (Stile WC3) ---
enum AssignmentState { NONE, MOVE, ATTACK, PATROL, GATHER_GOLD, GATHER_WOOD, BUILD, REPAIR }
enum UnitState { IDLE, MOVING, ATTACKING, PATROLING, BUILDING, REPARING, MINING, CHOPPING, RETURNING_RESOURCES }

# --- PARAMETRI CONFIGURABILI DALL'INSPECTOR ---
@export_group("Unità")
@export var player_owner: Player # Assegnato allo spawn o tramite editor
@export var player_color: Color = Color.BLUE : set = _set_player_color
@export var type: Globals.UnitType = Globals.UnitType.LAND

@export_group("Azioni e Abilita")
@export var available_actions: Array[ActionData] = []


# --- STATISTICHE DI BASE ---
@export_group("Vitalità")
@export var max_health: float = 100.0
@export var health_regen: float = 0.25      # Vita rigenerata al secondo
@export var max_mana: float = 0.0
@export var mana_regen: float = 0.0
@export var sight_range: int = 4            # Raggio visivo (in tile o unità di misura)

@export_group("Attacco")
@export var basic_damage: int = 6
@export var piercing_damage: int = 3        # Danno perforante (ignora l'Armor nemica)
@export var damage_dice_sides: int = 4      # Danno finale: basic_damage + randi_range(1, dice_sides)
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.35
@export var damage_type: Globals.DamageType = Globals.DamageType.NORMAL
@export var can_attack_air: bool = false
@export var can_attack_ground: bool = true

@export_group("Difesa")
@export var basic_armor: float = 2.0
@export var armor_type: Globals.ArmorType = Globals.ArmorType.MEDIUM

@export_group("Movimento e Costi")
@export var move_speed: float = 150.0:
	set(value):
		move_speed = value

@export var food_cost: int = 1
@export var bounty_gold: int = 15

# --- STATO INTERNO ---
#@onready var selection_ring: Node2D = $SelectionRing
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite2d: Sprite2D = $Sprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var health_bar: ProgressBar = $HealthBar
@onready var selectable_component: SelectableComponent = $SelectableComponent

# --- SEGNALI ---
signal health_changed(new_health: float, max_health: float)
signal destroyed()

# Variabili di stato nello script dell'unità
const INTERACT_DISTANCE: float = 40.0           # Quanto vicino deve essere per intereggire

var entity_id: String = ""
var player_id: int = -1 : get = _get_player_id
# --- VARIABILI VITA ---
var current_health: float = 0.0:
	set(value):
		current_health = value
		if health_bar:
			health_bar.value = value
var current_mana: float = 0.0:
	set(value):
		current_mana = value
		#if mana_bar:
			#mana_bar.value = value
var is_dead: bool = false

# Dichiariamo state_machine senza @onready per inizializzarla in _ready() in sicurezza
var state_machine: AnimationNodeStateMachinePlayback

var unit_state: UnitState = UnitState.IDLE
var current_assignment: AssignmentState = AssignmentState.NONE
var current_target: Node2D = null
var current_tile_target: Vector2i = Vector2i(-1, -1)

var is_interacting: bool = false                # Per tracciare lo stato di interazione
var is_processing_grid: bool = false # TRUE quando l'unità sta modificando la griglia intenzionalmente
var current_path: Array[Vector2i] = []
var current_step_target: Vector2 = Vector2.INF
var final_target_global: Vector2 = Vector2.INF

var animation_state: String = "Idle"
var last_facing_dir: Vector2 = Vector2.DOWN     # Per tracciare lo sguardo relativo all'ultimo movimento
var intended_dir: Vector2 = Vector2.DOWN

func _ready() -> void:
	# 1. Nascondi il cerchio di selezione all'avvio
	if selectable_component:
		selectable_component.deselect()
	
	# 2. Inizializza e attiva l'AnimationTree in modo sicuro
	if animation_tree:
		animation_tree.active = true
		state_machine = animation_tree.get("parameters/playback")
	
	# 3. Impedisci all'unità di muoversi appena spawnata
#	nav_agent.target_position = global_position
	
	# Inizializza la vita al massimo
	current_health = max_health
	current_mana = max_mana
	
	# Imposta la UI della barra della vita
	if health_bar:
		health_bar.max_value = max_health
		#health_bar.value = current_health
	
	# Collega l'unità al bollettino sul traffico del GridManager
	if not GridManager.obstacles_changed.is_connected(_on_obstacles_changed):
		GridManager.obstacles_changed.connect(_on_obstacles_changed)

func setup(data: Resource) -> void:
	self.entity_id = data.id
	#self.entity_name = data.name
	#self.description = data.description
	#self.icon = data.icon
	if selectable_component:
		selectable_component.setup(data.name, data.description, data.icon)
	
	self.type = data.type
	self.max_health = data.max_health
	self.health_regen = data.health_regen
	self.max_mana = data.max_mana
	self.mana_regen = data.mana_regen
	self.basic_armor = data.basic_armor
	self.sight_range = data.sight_range
	self.move_speed = data.move_speed
	self.basic_damage = data.basic_damage
	self.piercing_damage = data.piercing_damage
	self.attack_range = data.attack_range
	self.attack_cooldown = data.attack_cooldown
	self.can_attack_air = data.can_attack_air
	self.can_attack_ground = data.can_attack_ground
	self.damage_type = data.damage_type

func _process(delta: float) -> void:
	_handle_regeneration(delta)

func _physics_process(delta: float) -> void:
	if is_dead or unit_state != UnitState.MOVING:
		update_animation()
		return
		
	# Se non abbiamo un bersaglio locale in corso, abbiamo terminato l'intero percorso
	if current_step_target == Vector2.INF:
		_finish_movement()
		return
		
	var dist = global_position.distance_to(current_step_target)
	
	if dist > 3.0: 
		# Avanziamo linearmente verso il centro del tile
		intended_dir = global_position.direction_to(current_step_target)
		velocity = intended_dir * move_speed # Settiamo velocity solo per l'AnimationTree
		global_position = global_position.move_toward(current_step_target, move_speed * delta)
	else:
		# Siamo arrivati esatti al centro della cella!
		global_position = current_step_target
		_prepare_next_step()
		
	update_animation()

# Prepara e autorizza lo spostamento sulla singola cella successiva
func _prepare_next_step() -> void:
	if current_path.is_empty():
		current_step_target = Vector2.INF
		return
		
	var current_cell = GridManager.get_tile_coords(global_position)
	var next_cell = current_path[0]
	var agent_id = self.get_instance_id()
	
	is_processing_grid = true
	var result = GridManager.confirm_move(agent_id, current_cell, next_cell)
	is_processing_grid = false
	
	if result["ok"]:
		current_path.pop_front()
		current_step_target = GridManager.get_tile_center_global(next_cell)
	else:
		velocity = Vector2.ZERO
		
		# --- LA SOLUZIONE ---
		# Controlliamo se la cella bloccata è esattamente la destinazione finale
		var target_cell = GridManager.get_tile_coords(final_target_global)
		
		if next_cell == target_cell:
			# Siamo arrivati davanti all'obiettivo e lo spazio finale è occupato.
			# Ci fermiamo qui in modo pulito.
			current_path.clear()
			_finish_movement()
		else:
			# L'ostacolo è in mezzo al tragitto, cerchiamo di aggirarlo.
			_repath_around_obstacle(next_cell)

# Cerca una deviazione quando incontra un'altra unità a bloccare il passaggio
func _repath_around_obstacle(blocked_cell: Vector2i) -> void:
	# ALZA LO SCUDO: stiamo falsificando la mappa
	is_processing_grid = true
	
	GridManager.grid.set_point_solid(blocked_cell, true)
	
	var start_cell = GridManager.get_tile_coords(global_position)
	var target_cell = GridManager.get_tile_coords(final_target_global)
	var detour_path = GridManager.grid.get_id_path(start_cell, target_cell)
	
	var remains_solid = GridManager.authored_solid_at(blocked_cell) or GridManager.blocker_count_at(blocked_cell) > 0
	GridManager.grid.set_point_solid(blocked_cell, remains_solid)
	
	# ABBASSA LO SCUDO
	is_processing_grid = false
	
	if not detour_path.is_empty():
		if detour_path[0] == start_cell:
			detour_path.pop_front()
			
		current_path = detour_path
		# Assegniamo la nostra posizione attuale. Al prossimo _physics_process 
		# la distanza sarà 0 e attiverà il _prepare_next_step() del nuovo path.
		current_step_target = global_position
	else:
		current_path.clear()
		current_step_target = Vector2.INF

# Funzione separata in modo che possa essere chiamata dal segnale _on_obstacles_changed
func _calculate_path() -> void:
	var start_cell = GridManager.get_tile_coords(global_position)
	var target_cell = GridManager.get_tile_coords(final_target_global)
	
	# ---> LA SOLUZIONE: Caso in cui clicchiamo sulla cella in cui ci troviamo <---
	if start_cell == target_cell:
		current_path.clear()
		# Forziamo l'unità a raggiungere il centro esatto del tile
		current_step_target = GridManager.get_tile_center_global(target_cell)
		unit_state = UnitState.MOVING
		return
		
	# Deleghiamo il calcolo alla griglia
	current_path = GridManager.grid.get_id_path(start_cell, target_cell)
	
	if not current_path.is_empty():
		# Se il percorso inizia con la cella in cui ci troviamo già, la rimuoviamo
		if current_path[0] == start_cell:
			current_path.pop_front()
			
		_prepare_next_step()
		unit_state = UnitState.MOVING
	else:
		unit_state = UnitState.IDLE
		velocity = Vector2.ZERO

# Il "sensore" dell'unità che scatta quando un nemico costruisce un muro o cade un albero
func _on_obstacles_changed(changed_cells: Array) -> void:
	# 1. Se stiamo modificando noi la griglia, ignora il segnale
	if is_processing_grid:
		return
		
	# 2. Se non stiamo viaggiando o non abbiamo un percorso, ignora il segnale
	if unit_state != UnitState.MOVING or current_path.is_empty():
		return
		
	# 3. Controlla le deviazioni esterne
	for cell in changed_cells:
		if current_path.has(cell):
			_calculate_path()
			break

func _finish_movement() -> void:
	unit_state = UnitState.IDLE
	velocity = Vector2.ZERO
	current_step_target = Vector2.INF
	update_animation()
	
	# Innesca le interazioni (attacco, raccolta legno, ecc.) ora che siamo arrivati
	if current_target != null:
		_start_interaction(current_target)
	elif current_tile_target != Vector2i(-1, -1):
		_start_tile_interaction(current_tile_target)

func _get_player_id() -> int:
	if is_instance_valid(player_owner):
		return player_owner.player_id
	return -1

func _set_player_color(color: Color) -> void:
	player_color = color
	_apply_team_color(color)

func _apply_team_color(color: Color) -> void:
	pass

func get_health_perc() -> float:
	return float(current_health) / float(max_health)

func get_available_actions() -> Array[ActionData]:
	return available_actions

# --- SISTEMA DI SELEZIONE ---

func select() -> void:
	if selectable_component:
		selectable_component.select()

func deselect() -> void:
	if selectable_component:
		selectable_component.deselect()

func is_selected() -> bool:
	if selectable_component:
		return selectable_component.is_selected
	return false
	
func remove_from_selection() -> void:
	var selection_manager = _get_selection_manager()
	if is_instance_valid(selection_manager):
		selection_manager.remove_from_selection(self)


# --- SISTEMA DI MOVIMENTO ---

func move_to(target_pos: Vector2) -> void:
	# Salviamo la destinazione finale per eventuali ricalcoli futuri (repathing)
	final_target_global = target_pos
	
	# Invochiamo il calcolo del percorso
	_calculate_path()
	
	# Aggiorniamo subito l'animazione per un feedback visivo istantaneo
	update_animation()

func clear_assignment() -> void:
	match current_assignment:
		AssignmentState.GATHER_GOLD:
			if current_target != null and current_target.has_method("unregister_worker"):
					current_target.unregister_worker(self)
		AssignmentState.BUILD, AssignmentState.REPAIR:
			if current_target != null and current_target.has_method("unregister_builder"):
					current_target.unregister_builder(self)
	
	current_target = null
	current_tile_target = Vector2i(-1, -1)
	current_assignment = AssignmentState.NONE
	
	unit_state = UnitState.IDLE
	velocity = Vector2.ZERO
	
	# ALZA LO SCUDO
	is_processing_grid = true 
	
	var unit_id : int = self.get_instance_id()
	var standing_tile = GridManager.get_tile_coords(global_position)
	GridManager.release_agent(unit_id)
	GridManager.confirm_move(unit_id, standing_tile, standing_tile)
	
	# ABBASSA LO SCUDO
	is_processing_grid = false 

	update_animation()

func stop() -> void:
	# Il comando Stop del giocatore cancella ogni incarico, ferma l'agente 
	# di navigazione e prenota automaticamente il tile sotto i piedi dell'unità!
	clear_assignment()

# --- GESTIONE ANIMAZIONI ---

func update_animation() -> void:
	if not animation_tree or not state_machine:
		return
	
	var actual_speed: float = velocity.length()
	
	# Direzione di movimento basata sulla velocità attuale dell'Avoidance
	var move_dir: Vector2 = intended_dir
	
	# Fallback se l'avoidance ci rallenta o ferma un secondo
	if move_dir == Vector2.ZERO:
		move_dir = last_facing_dir
		
	if(is_dead):
		animation_tree.set("parameters/Death/blend_position", move_dir)
		state_machine.travel("Death")
		animation_state = "Death"
	else:
		#if is_moving = true and actual_speed > 10.0:
		if unit_state == UnitState.MOVING and actual_speed > 10.0:
			last_facing_dir = move_dir
			
			# Aggiorna BlendSpace e Stato Walk
			animation_tree.set("parameters/Walk/blend_position", move_dir)
			state_machine.travel("Walk")
			animation_state = "Walk"
		
		else:
			# Aggiorna BlendSpace e Stato Idle
			animation_tree.set("parameters/Idle/blend_position", move_dir)
			state_machine.travel("Idle")
			animation_state = "Idle"
	

	# Gestione flip orizzontale
	if move_dir.x < -0.1:
		sprite2d.flip_h = true
	elif move_dir.x > 0.1:
		sprite2d.flip_h = false

# --- SISTEMA VITA E COMBATTIMENTO ---

# Rigenerazione passiva di vita e mana
func _handle_regeneration(delta: float) -> void:
	if current_health < max_health and current_health > 0:
		current_health = min(current_health + health_regen * delta, max_health)
	if max_mana > 0 and current_mana < max_mana:
		current_mana = min(current_mana + mana_regen * delta, max_mana)
	
# Calcolo del danno inflitto (con variazione causale)
func get_calculated_damage() -> int:
	var roll = randi_range(1, damage_dice_sides) if damage_dice_sides > 0 else 0
	return basic_damage + roll
	
# Ricezione del danno con riduzione tramite Armatura
func take_damage(amount: float, source_damage_type: Globals.DamageType = Globals.DamageType.NORMAL) -> void:
	if is_dead:
		return # Non può subire danni se è già morta
		
	var type_multiplier = _get_damage_multiplier(source_damage_type, armor_type)
	var damage_after_type = amount * type_multiplier
	
	# Formula di riduzione armatura classica di WC3: (basic_armor * 0.06) / (1 + 0.06 * basic_armor)
	var armor_reduction = 1.0
	if basic_armor >= 0:
		armor_reduction = 1.0 - ((basic_armor * 0.06) / (1.0 + 0.06 * basic_armor))
	else:
		armor_reduction = 2.0 - pow(0.94, -basic_armor) # Armatura negativa aumenta il danno
		
	var final_damage = max(1.0, damage_after_type * armor_reduction)
	current_health -= final_damage
	
	# Emette il segnale per aggiornare eventuali barre della vita (UI)
	_on_health_changed()
		
	print(name, " ha subito ", amount, " danni! Vita attuale: ", current_health)
	
	if current_health <= 0.0:
		die()

# Matrice dei moltiplicatori tra Tipi Danno / Tipi Armatura
func _get_damage_multiplier(dmg_t: Globals.DamageType, arm_t: Globals.ArmorType) -> float:
	match dmg_t:
		Globals.DamageType.PIERCING:
			if arm_t == Globals.ArmorType.LIGHT: return 2.0  # Fanti leggeri / Volanti
			if arm_t == Globals.ArmorType.HEAVY: return 1.0
			if arm_t == Globals.ArmorType.FORTIFIED: return 0.35 # Edifici
		Globals.DamageType.SIEGE:
			if arm_t == Globals.ArmorType.FORTIFIED: return 1.5 # Edifici
			if arm_t == Globals.ArmorType.MEDIUM: return 0.5
		Globals.DamageType.NORMAL:
			if arm_t == Globals.ArmorType.MEDIUM: return 1.5
			if arm_t == Globals.ArmorType.FORTIFIED: return 0.7
	return 1.0 # Valore di default se non ci sono interazioni particolari

func heal(amount: float) -> void:
	if is_dead:
		return
		
	# Aumenta la vita, ma non oltre il massimo consentito
	current_health = min(current_health + amount, max_health)
	_on_health_changed()

func die() -> void:
	if is_dead:
		return # Evita che la funzione venga chiamata più volte
		
	is_dead = true
	destroyed.emit()
	
	# Nasconde la barra della vita
	if health_bar:
		health_bar.visible = false
	
	# 1. PULIZIA TOTALE: Ferma il movimento e avvisa miniere/edifici che il lavoratore è morto!
	clear_assignment() 
	
	# 2. DISATTIVA LA FISICA
	# Usiamo set_deferred per le collisioni per evitare errori se chiamato durante un frame fisico
	collision_shape.set_deferred("disabled", true)
	set_physics_process(false) 
	
	# 3. AVVIA ANIMAZIONE
	update_animation()
	
	# 4. ATTENDI FINE ANIMAZIONE
	await get_tree().create_timer(0.6).timeout
	
	# 5. GENERA IL CADAVERE (solo visivo)
	spawn_corpse()
	
	# 6. LIBERA LA GRIGLIA
	# Poiché clear_assignment() ha riprenotato il tile sotto ai suoi piedi per fermarsi,
	# ora che è definitivamente morto (e c'è solo un cadavere calpestabile), lo liberiamo.
	GridManager.release_agent(self.get_instance_id())
	
	# 7. ELIMINA L'UNITÀ
	queue_free()

func spawn_corpse() -> void:
	# Crea un nuovo nodo Sprite2D
	var corpse = Sprite2D.new()
		
	# Copia le proprietà visive per renderlo identico all'ultimo frame dell'animazione
	corpse.texture = sprite2d.texture
	corpse.hframes = sprite2d.hframes
	corpse.vframes = sprite2d.vframes
	corpse.frame = sprite2d.frame
	corpse.flip_h = sprite2d.flip_h
	
	# Imposta la posizione esatta dell'unità
	corpse.global_position = global_position
	
	# Opzionale: scurisce leggermente la sagoma per far capire che è un'unità morta
	corpse.modulate = Color(0.5, 0.5, 0.5, 1.0) 
	
	# Aggiunge il cadavere al nodo genitore (il livello/mondo)
	# Questo è fondamentale: se lo aggiungessimo all'unità, verrebbe distrutto insieme a lei!
	get_parent().add_child(corpse)
	
	# Imposta un timer per far sparire il cadavere (es. 5 secondi)
	var despawn_timer = get_tree().create_timer(8.0)
	despawn_timer.timeout.connect(corpse.queue_free)

# --- GESTIONE UI ---

func _on_health_changed() -> void:
	if health_bar:
		health_bar.value = current_health
	
	health_changed.emit(current_health, max_health)

# --- GESTIONE IERAZIONI ---

func interact_with(target: Node2D) -> void:
	# Nessuna pulizia qui!
	current_target = target
	current_tile_target = Vector2i(-1, -1)
	
	if target.is_in_group("interactable"):
		var direction_to_unit = (global_position - target.global_position).normalized()
		var edge_offset: float = 5.0 
		
		for child in target.get_children():
			if child is NavigationObstacle2D:
				edge_offset = child.radius - 18 
				break 
		
		var optimal_target_pos = target.global_position + (direction_to_unit * edge_offset)
		move_to(optimal_target_pos)
	else:
		move_to(target.global_position)

# Funzione per mandare l'unità verso un tile di risorse (es. albero)
func interact_with_tile(tile_coords: Vector2i, safe_destination: Vector2) -> void:
	# Nessuna pulizia qui!
	current_tile_target = tile_coords
	current_target = null
	move_to(safe_destination)

#Funzione virtuale: sovrascrivila nelle classi figlie!
func _start_interaction(target: Node2D) -> void:
	pass

# Funzione virtuale che il Peasant sovrascriverà
func _start_tile_interaction(tile_coords: Vector2i) -> void:
	pass

func _get_selection_manager() -> Node:
	var m := get_tree().get_nodes_in_group("selection_manager")
	return m[0] if not m.is_empty() else null
