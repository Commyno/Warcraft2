class_name Minimap
extends Control

const TILE_SIZE: int = 32 # Modifica in base al tuo TileSet (es. 16, 32, 64)

#@export var game_camera: Camera2D
var game_camera: Camera2D

var minimap_size: Vector2
var world_size_pixels: Vector2
var scale_factor: Vector2

var bg_texture: Texture2D

func _ready() -> void:
	minimap_size = size
	clip_contents = true
	
	# Timer per ottimizzare il ridisegno (10 FPS invece di 60, risparmia risorse)
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(queue_redraw)
	add_child(timer)

# Chiamata da GameScene quando la mappa e MatchData sono pronti
func setup_minimap() -> void:
	# 1. Calcolo dimensione reale del mondo in pixel
	world_size_pixels = Vector2(MatchData.map_dimensions) * TILE_SIZE
	
	# 2. Calcolo del fattore di scala
	if world_size_pixels != Vector2.ZERO:
		scale_factor = minimap_size / world_size_pixels
	
	# 3. Recupero dinamico dello sfondo (Screenshot)
	var map_path: String = MatchData.selected_map_path
	if map_path != "":
		var image_path = map_path.get_basename() + ".png"
		if ResourceLoader.exists(image_path):
			bg_texture = load(image_path)
		else:
			push_warning("Minimappa: Screenshot non trovato in " + image_path)
	
	queue_redraw()

# --- FASE DI DISEGNO ---
func _draw() -> void:
	# 1. Sfondo (Immagine PNG o colore di fallback)
	if bg_texture != null:
		draw_texture_rect(bg_texture, Rect2(Vector2.ZERO, minimap_size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, minimap_size), Color(0.1, 0.15, 0.1, 1.0))
		
	# 2. Unità ed Edifici
	var entities = get_tree().get_nodes_in_group("units")
	entities.append_array(get_tree().get_nodes_in_group("buildings"))
	
	for entity in entities:
		if not is_instance_valid(entity):
			continue
			
		var map_pos = entity.global_position * scale_factor
		var dot_color = Color.WHITE
		
		# Preleva il colore del giocatore se l'entità lo possiede
		if "player_color" in entity:
			dot_color = entity.player_color
			
		# Dimensione del quadratino: 2x2 per unità, 4x4 per edifici
		var dot_size = Vector2(2, 2)
		if entity is BaseBuilding: 
			dot_size = Vector2(4, 4)
			
		draw_rect(Rect2(map_pos - (dot_size / 2.0), dot_size), dot_color)
		
# 3. Rettangolo della Telecamera compensato
	if game_camera != null:
		var hud_left_width: float = 300.0 # <--- INSERISCI QUI LA LARGHEZZA DEL TUO HUD
		
		# Ottiene la dimensione reale compensando lo zoom
		var viewport_size = get_viewport_rect().size / game_camera.zoom
		var hud_offset = hud_left_width / game_camera.zoom.x
		
		# 1. Riduciamo la larghezza visibile togliendo l'HUD
		viewport_size.x -= hud_offset
		
		# 2. Calcoliamo la dimensione del rettangolo sulla minimappa
		var cam_rect_size = viewport_size * scale_factor
		
		# 3. Spostiamo il centro della camera "più a destra" per compensare il taglio a sinistra
		var cam_center_world = game_camera.get_screen_center_position()
		cam_center_world.x += (hud_offset / 2.0)
		
		var cam_pos_minimap = cam_center_world * scale_factor
		
		# 4. Disegniamo il rettangolo
		var cam_rect = Rect2(cam_pos_minimap - (cam_rect_size / 2.0), cam_rect_size)
		draw_rect(cam_rect, Color.WHITE, false, 1.0)

# --- FASE DI INPUT ---
func _gui_input(event: InputEvent) -> void:
	if game_camera == null:
		return
		
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			# 1. Definizione offset HUD (DEVE ESSERE IDENTICO A QUELLO IN _draw)
			var hud_left_width: float = 300.0 
			var hud_offset = hud_left_width / game_camera.zoom.x
			
			# 2. Posizione cliccata (limitata ai bordi)
			var click_pos = event.position
			click_pos.x = clamp(click_pos.x, 0, minimap_size.x)
			click_pos.y = clamp(click_pos.y, 0, minimap_size.y)
			
			# 3. Calcolo del punto del mondo desiderato
			var world_target = click_pos / scale_factor
			
			# 4. COMPENSAZIONE INVERSA: 
			# Spostiamo il vero centro della telecamera a sinistra,
			# così l'area visibile cadrà esattamente al centro del click!
			world_target.x -= (hud_offset / 2.0)
			
			# 5. Assegnazione finale
			game_camera.global_position = world_target
