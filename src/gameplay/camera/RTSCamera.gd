extends Camera2D

const LERP_WEIGHT : float = 2
const CAMERA_LOOK_AHEAD_VAL : Vector2 = Vector2(0.0, -8.0)
const CAMERA_LOOK_AMOUNT : float = 64

# --- PARAMETRI CONFIGURABILI ---
# Velocità di movimento della fotocamera (pixel al secondo)
@export var move_speed: float = 450.0
@export var edge_move_speed: float = 225.0 

# Margine dal bordo dello schermo in pixel per attivare l'edge scrolling
@export var edge_margin: float = 10.0
@export var enable_edge_scroll: bool = true

# Larghezza in pixel dell'HUD sulla sinistra. 
# Impedisce lo scroll se il mouse vi passa sopra e sposta il bordo di rilevamento.
@export var hud_left_width: float = 140.0 

# Limiti e sensibilità dello zoom
@export var zoom_speed: float = 0.15
@export var min_zoom: float = 0.5
@export var max_zoom: float = 1.0
@export var zoom_smoothness: float = 8.0

var target_zoom: Vector2 = Vector2.ONE
var target : Node2D = null

# --- CONFINI REALI DELLA MAPPA ---
var map_limit_left: float = 0.0
var map_limit_top: float = 0.0
var map_limit_right: float = 10000.0
var map_limit_bottom: float = 10000.0

func _ready() -> void:
	target_zoom = zoom
	
func _process(delta: float) -> void:
	handle_movement(delta)
	handle_zoom(delta)

func _physics_process(delta: float) -> void:
	_follow_camera_target(delta)

func _follow_camera_target(delta: float) -> void:
	if not target:
		return
	
	var target_camera_offset : Vector2 = CAMERA_LOOK_AHEAD_VAL
	var target_global_pos : Vector2 = target.global_position + target_camera_offset
	target_global_pos += target.camera_look_direction * CAMERA_LOOK_AMOUNT
	
	var camera_pos_out : Vector2
	camera_pos_out.x = lerpf(global_position.x, target_global_pos.x, LERP_WEIGHT * delta)
	camera_pos_out.y = lerpf(global_position.y, target_global_pos.y, LERP_WEIGHT * delta)
	
	global_position = camera_pos_out
	
func handle_movement(delta: float) -> void:
	var keyboard_dir = Vector2.ZERO
	var edge_dir = Vector2.ZERO

	# 1. Movimento da Tastiera (WASD o Frecce)
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		keyboard_dir.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		keyboard_dir.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		keyboard_dir.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		keyboard_dir.y -= 1

	# 2. Movimento ai bordi dello schermo (Edge Scrolling)
	if enable_edge_scroll:
		var mouse_pos = get_viewport().get_mouse_position()
		var viewport_size = get_viewport_rect().size

		# Controlliamo che il mouse non sia sopra l'HUD a sinistra
		if mouse_pos.x > hud_left_width:
			
			if mouse_pos.x >= viewport_size.x - edge_margin:
				edge_dir.x += 1
			elif mouse_pos.x <= hud_left_width + edge_margin:
				edge_dir.x -= 1

			if mouse_pos.y >= viewport_size.y - edge_margin:
				edge_dir.y += 1
			elif mouse_pos.y <= edge_margin:
				edge_dir.y -= 1

	# Normalizzazione indipendente per evitare la velocità doppia in diagonale
	if keyboard_dir.length() > 0:
		keyboard_dir = keyboard_dir.normalized()
		
	if edge_dir.length() > 0:
		edge_dir = edge_dir.normalized()

	# 3. Calcolo della velocità finale unendo tastiera e mouse
	var final_velocity = (keyboard_dir * move_speed) + (edge_dir * edge_move_speed)
	
	if final_velocity.length() > move_speed:
		final_velocity = final_velocity.normalized() * move_speed

	# Applichiamo il movimento temporaneo
	position += final_velocity * (1.0 / zoom.x) * delta
	
	# --- 4. BLOCCO FISICO DELLA POSIZIONE (FIX) ---
	var visible_rect_size = get_viewport_rect().size / zoom
	var half_width = visible_rect_size.x / 2.0
	var half_height = visible_rect_size.y / 2.0
	
	var world_hud_width = hud_left_width / zoom.x
	
	# Usiamo le NOSTRE variabili al posto dei limiti nativi di Godot
	var min_x = map_limit_left + half_width - world_hud_width
	var max_x = max(min_x, map_limit_right - half_width)
	
	var min_y = map_limit_top + half_height
	var max_y = max(min_y, map_limit_bottom - half_height)
	
	position.x = clamp(position.x, min_x, max_x)
	position.y = clamp(position.y, min_y, max_y)

func _unhandled_input(event: InputEvent) -> void:
	# 1. Zoom tramite Rotella del Mouse Fisica
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			apply_zoom(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			apply_zoom(-zoom_speed)

	# 2. Zoom tramite Pinch-to-Zoom Nativo del Trackpad del Mac
	elif event is InputEventMagnifyGesture:
		# 'factor' è > 1.0 quando allarghi le dita, e < 1.0 quando le unisci
		var zoom_delta = (event.factor - 1.0) * 2.0
		apply_zoom(zoom_delta)

# Funzione di supporto per applicare e limitare lo zoom
func apply_zoom(amount: float) -> void:
	target_zoom += Vector2(amount, amount)
	target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
	target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)

# Imposta direttamente lo zoom iniziale scavalcando i calcoli incrementali
func set_initial_zoom(zoom_value: float) -> void:
	target_zoom = Vector2(zoom_value, zoom_value)
	target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
	target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)
	zoom = target_zoom # Lo applica subito senza aspettare il lerp

func handle_zoom(delta: float) -> void:
	# Transizione fluida verso lo zoom desiderato
	zoom = zoom.lerp(target_zoom, zoom_smoothness * delta)
