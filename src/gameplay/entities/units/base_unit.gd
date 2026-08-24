class_name BaseUnit
extends CharacterBody2D

# --- ENUMERATORI PER TIPI DI DANNO E ARMATURA (Stile WC3) ---
enum DamageType { NORMAL, PIERCING, SIEGE, MAGIC, HERO }
enum ArmorType { UNARMORED, LIGHT, MEDIUM, HEAVY, FORTIFIED, HERO }

# --- PARAMETRI CONFIGURABILI DALL'INSPECTOR ---
@export_group("Unità")
@export var unit_name:  String
@export var unit_icon:  Texture = preload("uid://c0saq2cohbtd2")

@export_group("Azioni e Abilita")
@export var available_actions: Array[UnitAction] = []

# --- STATISTICHE DI BASE ---
@export_group("Vitalità")
@export var max_health: float = 100.0
@export var health_regen: float = 0.25 # Vita rigenerata al secondo
@export var max_mana: float = 0.0
@export var mana_regen: float = 0.0

@export_group("Attacco")
@export var base_damage: int = 12
@export var damage_dice_sides: int = 4 # Danno finale: base_damage + randi_range(1, dice_sides)
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.35
@export var damage_type: DamageType = DamageType.NORMAL

@export_group("Difesa")
@export var armor: float = 2.0
@export var armor_type: ArmorType = ArmorType.MEDIUM

@export_group("Movimento e Costi")
@export var move_speed: float = 150.0:
	set(value):
		move_speed = value
		if nav_agent:
			nav_agent.max_speed = move_speed

@export var food_cost: int = 1
@export var bounty_gold: int = 15

# --- STATO INTERNO ---
#@onready var selection_ring: Node2D = $SelectionRing
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var unit_sprite: Sprite2D = $Sprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var health_bar: ProgressBar = $HealthBar
@onready var selectable_component: SelectableComponent = $SelectableComponent

# --- SEGNALI ---
signal health_changed(new_health: float, max_health: float)
signal died()

# Variabili di stato nello script dell'unità
const INTERACT_DISTANCE: float = 40.0           # Quanto vicino deve essere per intereggire

# --- VARIABILI VITA ---
var current_health: float
var current_mana: float
var is_dead: bool = false

# Dichiariamo state_machine senza @onready per inizializzarla in _ready() in sicurezza
var state_machine: AnimationNodeStateMachinePlayback

var is_moving: bool = false                     # Per tracciare lo stato di movimento reale
var is_interacting: bool = false                # Per tracciare lo stato di interazione
var is_attacking: bool = false                  # Per tracciare lo stato di attacco
var last_facing_dir: Vector2 = Vector2.DOWN     # Per tracciare lo sguardo relativo all'ultimo movimento
var intended_dir: Vector2 = Vector2.DOWN
var current_target: Node2D = null
var current_offset_target: float = 15.0

var state: String = "Idle"
var last_state: String = "None"

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
	
	# 4. Connetti il segnale di evitamento (RVO)
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	
	# Inizializza la vita al massimo
	current_health = max_health
	current_mana = max_mana
	
	# Riporta la velocità sulla navigation agent
	if nav_agent:
		nav_agent.max_speed = move_speed	
	
	# Imposta la UI della barra della vita
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		
	# Connetti il segnale della vita per aggiornare la UI in automatico
	health_changed.connect(_on_health_changed)
	
func _process(delta: float) -> void:
	_handle_regeneration(delta)

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

# --- SISTEMA DI MOVIMENTO ---

func move_to(target_pos: Vector2) -> void:
	# 1. Assegni il bersaglio
	nav_agent.target_position = target_pos
	
	# 2. TRUCCO GODOT 4: Forza la generazione immediata della rotta!
	nav_agent.get_current_navigation_path()
	
	# 3. Ora che la rotta è certa, chiediamo il prossimo punto
	var next_path_pos = nav_agent.get_next_path_position()
	
	# 4. Calcoliamo la direzione
	intended_dir = global_position.direction_to(next_path_pos)
	
	# 5. Diciamo fisicamente all'unità che deve mettersi in marcia
	is_moving = true
	update_animation()

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	
	var current_position: Vector2 = global_position
	
	# 1. Definiamo la tolleranza: ampia per edifici, stretta per punti a terra
	#var required_distance = current_offset_target if current_target != null and current_target.is_in_group("interactable") else 15.0

	var distance_to_target: float = 0
	if is_moving and nav_agent:
		# Calcoliamo la distanza effettiva dal punto di destinazione finale
		distance_to_target = global_position.distance_to(nav_agent.target_position)
		
		# 2. CONDIZIONE DI ARRIVO (usiamo required_distance!)
		if nav_agent.is_navigation_finished() or distance_to_target <= current_offset_target:
			# Se siamo arrivati a meno di 0.5 pixel dal centro, forziamo la posizione perfetta
			
			# NUOVA LOGICA: Se stiamo andando a terra (no interazione) e siamo vicini, scivoliamo al centro!
			if current_target == null and distance_to_target > 0.5:
				# Scivolamento dolce (bypassiamo il navigation agent per gli ultimi pixel)
				global_position = global_position.move_toward(nav_agent.target_position, move_speed * _delta)
				print("move_toward(" + str(nav_agent.target_position) + str(move_speed) + str(_delta))
				return # Interrompiamo il frame qui, continuerà a scivolare al prossimo frame
			
			if current_target == null:
				global_position = nav_agent.target_position 
			
			velocity = Vector2.ZERO
			is_moving = false
			update_animation()
			
			# --- GESTIONE INTERAZIONE ---
			if current_target != null:
				_start_interaction(current_target)
				# Dimentichiamo il target per non ripetere l'azione ogni singolo frame
				current_target = null 
			
			return

		# 3. MOVIMENTO (Siamo ancora in viaggio)
		var next_path_position: Vector2 = nav_agent.get_next_path_position()
		intended_dir = current_position.direction_to(next_path_position)
		var intended_velocity: Vector2 = intended_dir * move_speed
		
		# Manteniamo is_moving a true per tutta la durata del tragitto
		is_moving = true
		
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(intended_velocity)
		else:
			_on_velocity_computed(intended_velocity)

#Funzione virtuale: sovrascrivila nelle classi figlie!
func _start_interaction(target: Node2D) -> void:
	pass

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	# Muoviamo FISICAMENTE l'unità
	move_and_slide()
	
	# Chiamiamo l'aggiornamento dell'animazione DOPO esserci mossi,
	# in modo che get_real_velocity() sia accurato
	update_animation()

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
		state = "Death"
	else:
		if is_moving and actual_speed > 10.0:
			last_facing_dir = move_dir
			
			# Aggiorna BlendSpace e Stato Walk
			animation_tree.set("parameters/Walk/blend_position", move_dir)
			state_machine.travel("Walk")
			state = "Walk"
		
		elif is_attacking:
			animation_tree.set("parameters/Attack/blend_position", move_dir)
			state_machine.travel("Attack")
			state = "Attack"
		
		else:
			# Aggiorna BlendSpace e Stato Idle
			animation_tree.set("parameters/Idle/blend_position", move_dir)
			state_machine.travel("Idle")
			state = "Idle"
	

	# Gestione flip orizzontale
	if move_dir.x < -0.1:
		unit_sprite.flip_h = true
	elif move_dir.x > 0.1:
		unit_sprite.flip_h = false

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
	return base_damage + roll
	
# Ricezione del danno con riduzione tramite Armatura
func take_damage(amount: float, source_damage_type: DamageType = DamageType.NORMAL) -> void:
	if is_dead:
		return # Non può subire danni se è già morta
		
	var type_multiplier = _get_damage_multiplier(source_damage_type, armor_type)
	var damage_after_type = amount * type_multiplier
	
	# Formula di riduzione armatura classica di WC3: (armor * 0.06) / (1 + 0.06 * armor)
	var armor_reduction = 1.0
	if armor >= 0:
		armor_reduction = 1.0 - ((armor * 0.06) / (1.0 + 0.06 * armor))
	else:
		armor_reduction = 2.0 - pow(0.94, -armor) # Armatura negativa aumenta il danno
		
	var final_damage = max(1.0, damage_after_type * armor_reduction)
	current_health -= final_damage
	
	# Emette il segnale per aggiornare eventuali barre della vita (UI)
	health_changed.emit(current_health, max_health)
	
	collision_shape.disabled = true
	
	print(name, " ha subito ", amount, " danni! Vita attuale: ", current_health)
	
	if current_health <= 0.0:
		die()

# Matrice dei moltiplicatori tra Tipi Danno / Tipi Armatura
func _get_damage_multiplier(dmg_t: DamageType, arm_t: ArmorType) -> float:
	match dmg_t:
		DamageType.PIERCING:
			if arm_t == ArmorType.LIGHT: return 2.0  # Fanti leggeri / Volanti
			if arm_t == ArmorType.HEAVY: return 1.0
			if arm_t == ArmorType.FORTIFIED: return 0.35 # Edifici
		DamageType.SIEGE:
			if arm_t == ArmorType.FORTIFIED: return 1.5 # Edifici
			if arm_t == ArmorType.MEDIUM: return 0.5
		DamageType.NORMAL:
			if arm_t == ArmorType.MEDIUM: return 1.5
			if arm_t == ArmorType.FORTIFIED: return 0.7
	return 1.0 # Valore di default se non ci sono interazioni particolari

func heal(amount: float) -> void:
	if is_dead:
		return
		
	# Aumenta la vita, ma non oltre il massimo consentito
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func die() -> void:
	if is_dead:
		return # Evita che la funzione venga chiamata più volte
		
	is_dead = true
	died.emit()
	
	# Nasconde la barra della vita
	if health_bar:
		health_bar.visible = false
	
	# Ferma il movimento
	velocity = Vector2.ZERO
	is_moving = false
	nav_agent.target_position = global_position
	set_physics_process(false) 
	
	# 1. Avvia l'animazione di morte
	# Assicurati che "Death" sia il nome esatto del nodo nell'AnimationTree
	update_animation()
	
	# 2. Attendi la fine dell'animazione
	# Sostituisci 1.0 con la durata effettiva in secondi della tua animazione
	await get_tree().create_timer(0.6).timeout
	
	# 3. Genera la sagoma
	spawn_corpse()
	
	# 4. Distruggi l'unità
	queue_free()

func spawn_corpse() -> void:
	# Crea un nuovo nodo Sprite2D
	var corpse = Sprite2D.new()
		
	# Copia le proprietà visive per renderlo identico all'ultimo frame dell'animazione
	corpse.texture = unit_sprite.texture
	corpse.hframes = unit_sprite.hframes
	corpse.vframes = unit_sprite.vframes
	corpse.frame = unit_sprite.frame
	corpse.flip_h = unit_sprite.flip_h
	
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

func _on_health_changed(new_health: float, _max: float) -> void:
	if health_bar:
		health_bar.value = new_health

# --- GESTIONE IERAZIONI ---

func interact_with(target: Node2D) -> void:
	current_target = target
	
	if target.is_in_group("interactable"):
		# 1. Calcoliamo la direzione verso la nostra unità
		var direction_to_unit = (global_position - target.global_position).normalized()
		
		# 2. Valore di default
		var edge_offset: float = 50.0
		
		# 3. Cerchiamo dinamicamente il raggio dell'ostacolo
		for child in target.get_children():
			if child is NavigationObstacle2D:
				# Aggiungiamo un piccolo margine (+ 5.0) per essere sicuri 
				# che il punto cada esattamente nell'area calpestabile (blu) 
				# e non sulla linea matematica di confine dell'ostacolo.
				#edge_offset = child.radius + 0.0 
				# SOMMIAMO: raggio miniera + raggio unità + un piccolo margine
				edge_offset = child.radius - 10 # + nav_agent.radius + 10.0
				current_offset_target = edge_offset
				break # Appena lo troviamo, interrompiamo la ricerca
		
		# 4. Applichiamo l'offset dinamico
		var optimal_target_pos = target.global_position + (direction_to_unit * edge_offset)
		
		move_to(optimal_target_pos)
	else:
		# Bersaglio normale (punto a terra)
		move_to(target.global_position)
