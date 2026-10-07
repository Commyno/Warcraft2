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
@export var food_cost: int = 1
@export var bounty_gold: int = 15

# --- STATO INTERNO ---
#@onready var selection_ring: Node2D = $SelectionRing
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite2d: Sprite2D = $Sprite2D
@onready var animation_tree: AnimationTree = $AnimationTree

# --- COMPONENTS ---
@onready var selectable_component: SelectableComponent = $SelectableComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var mana_component: ManaComponent = $ManaComponent
@onready var attack_component: AttackComponent = $AttackComponent
@onready var defend_component: DefendComponent = $DefendComponent
@onready var visible_component: VisibleComponent = $VisibleComponent
@onready var vision_component: VisionComponent = $VisionComponent

# --- SEGNALI ---
signal destroyed()

# Variabili di stato nello script dell'unità
const INTERACT_DISTANCE: float = 40.0           # Quanto vicino deve essere per intereggire

var entity_id: String = ""
var player_id: int = -1 : get = _get_player_id

# --- VARIABILI VITA ---
var current_health: int:
	get():
		if health_component:
			return int(health_component.health)
		return 0

# --- VARIABILI MANA ---
var current_mana: int:
	get():
		if mana_component:
			return int(mana_component.mana)
		return 0

var is_dead: bool = false

# Dichiariamo state_machine senza @onready per inizializzarla in _ready() in sicurezza
var state_machine: AnimationNodeStateMachinePlayback

var unit_state: UnitState = UnitState.IDLE
var current_assignment: AssignmentState = AssignmentState.NONE
var current_target: Node2D = null
var current_tile_target: Vector2i = Vector2i(-1, -1)

var is_interacting: bool = false                # Per tracciare lo stato di interazione

var animation_state: String = "Idle"
var last_facing_dir: Vector2 = Vector2.DOWN     # Per tracciare lo sguardo relativo all'ultimo movimento

func _ready() -> void:
	available_actions.resize(9)

	# 1. Nascondi il cerchio di selezione all'avvio
	if selectable_component:
		selectable_component.deselect()
	
	# 2. Inizializza e attiva l'AnimationTree in modo sicuro
	if animation_tree:
		animation_tree.active = true
		state_machine = animation_tree.get("parameters/playback")
	
	# Ci colleghiamo al segnale del componente invece che al GridManager
	if movement_component:
		movement_component.movement_finished.connect(_on_movement_finished)

func setup(data: Resource) -> void:
	self.entity_id = data.id

	# Set components
	if selectable_component:
		selectable_component.setup(data)
	if movement_component:
		movement_component.setup(data)
	if health_component:
		health_component.setup(data)
	if mana_component:
		mana_component.setup(data)
	if attack_component:
		attack_component.setup(data)
	if defend_component:
		defend_component.setup(data)
	if vision_component:
		vision_component.setup(data)
	
	self.type = data.type

#func _process(delta: float) -> void:
	#pass

func _physics_process(delta: float) -> void:
	if is_dead or unit_state != UnitState.MOVING:
		update_animation()
		return
		
	# Deleghiamo il movimento fisico al componente se lo stato è MOVING
	if unit_state == UnitState.MOVING and movement_component != null:
		movement_component.process_movement(delta)
		
	update_animation()

func _get_player_id() -> int:
	if is_instance_valid(player_owner):
		return player_owner.player_id
	return -1

func _set_player_color(color: Color) -> void:
	player_color = color
	_apply_team_color(color)

func _apply_team_color(color: Color) -> void:
	pass

# FUNCTION COMPONENT

func get_health_percentage() -> float:
	if health_component:
		return health_component.get_health_percentage()
	return 0

func get_mana_percentage() -> float:
	if mana_component:
		return mana_component.get_mana_percentage()
	return 0

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

# --- OTHER FUNCTION

func get_available_actions() -> Array[ActionData]:
	return available_actions

func remove_from_selection() -> void:
	var selection_manager = _get_selection_manager()
	if is_instance_valid(selection_manager):
		selection_manager.remove_from_selection(self)


# --- SISTEMA DI MOVIMENTO ---

func move_to(target_pos: Vector2) -> void:
	unit_state = UnitState.MOVING
	movement_component.move_to(target_pos)
	update_animation()

func _on_movement_finished() -> void:
	unit_state = UnitState.IDLE
	update_animation()
	
	# Innesca le interazioni ora che siamo arrivati
	if current_target != null:
		if movement_component.is_adjacent_to_target(current_target):
			_start_interaction(current_target)
		else:
			clear_assignment()
	elif current_tile_target != Vector2i(-1, -1):
		# Per i tile (alberi ecc.) Chebyshev diretto va bene, sono sempre 1x1
		var my_cell := GridManager.get_tile_coords(global_position)
		var dist = maxi(abs(my_cell.x - current_tile_target.x), abs(my_cell.y - current_tile_target.y))
		if dist <= 1:
			_start_tile_interaction(current_tile_target)
		else:
			clear_assignment()

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
	
	# Il rilascio sulla griglia ora lo gestisce il componente
	if movement_component:
		movement_component.stop_movement()	
	
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
	var move_dir: Vector2 = movement_component.intended_dir if movement_component else last_facing_dir

	# Fallback se l'avoidance ci rallenta o ferma un secondo
	if move_dir == Vector2.ZERO:
		move_dir = last_facing_dir
		
	if is_dead:
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

func heal(amount: float) -> void:
	if is_dead:
		return
		
	# Aumenta la vita, ma non oltre il massimo consentito
	if health_component:
		health_component.restore(amount)

func die() -> void:
	if is_dead:
		return # Evita che la funzione venga chiamata più volte
		
	is_dead = true
	destroyed.emit()
	
	# Nasconde la barra della vita
	if health_component:
		health_component.hide_health_bar()
	
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

# --- GESTIONE IERAZIONI ---

func interact_with(target: Node2D) -> void:
	# Nessuna pulizia qui!
	current_target = target
	current_tile_target = Vector2i(-1, -1)
	
		# Prenota subito una cella adiacente libera prima di calcolare il percorso
	var current_cell := GridManager.get_tile_coords(global_position)
	var destination := GridManager.get_available_destination(
		target.global_position, 
		get_instance_id(), 
		current_cell,
		true  # auto_reserve
	)

	#move_to(target.global_position)
	move_to(destination)

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
