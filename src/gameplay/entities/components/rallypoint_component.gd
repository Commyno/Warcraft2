class_name RallypointComponent
extends Node2D

# Signals
signal updated(new_position)

# Export
@export var rallypoint_position: Vector2 = Vector2.INF
@export var rally_marker_scene: PackedScene # Assegna una scena con Sprite2D (o creiamo un fallback)
@export var rally_marker_texture: Texture2D  # In alternativa, passa solo la texture

# Variable
var _rally_marker_instance: Node2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Crea l'indicatore all'avvio ma mantienilo nascosto
	_create_rally_marker()

func _exit_tree() -> void:
	# Pulizia se l'edificio viene distrutto
	if is_instance_valid(_rally_marker_instance):
		_rally_marker_instance.queue_free()

# --- GESTIONE RALLY POINT ---

func _create_rally_marker() -> void:
	if _rally_marker_instance != null:
		return

	# Se hai una PackedScene usa quella, altrimenti crea un semplice Sprite2D da codice
	if rally_marker_scene != null:
		_rally_marker_instance = rally_marker_scene.instantiate()
		_rally_marker_instance.visible = false
		_rally_marker_instance.global_position = get_parent().global_position

	rallypoint_position = Vector2.INF

	# Inserisci il marker nel container degli effetti tramite SpawnManager (o nel genitore)
	if SpawnManager.effects_container != null:
		SpawnManager.effects_container.add_child(_rally_marker_instance)
	else:
		get_parent().call_deferred("add_child", _rally_marker_instance)

func show_rally_marker() -> void:
	if rallypoint_position == Vector2.INF:
		return
		
	if _rally_marker_instance == null:
		_create_rally_marker()
		
	if is_instance_valid(_rally_marker_instance):
		_rally_marker_instance.global_position = rallypoint_position
		_rally_marker_instance.visible = true

func hide_rally_marker() -> void:
	if is_instance_valid(_rally_marker_instance):
		_rally_marker_instance.visible = false

# Metodo per aggiornare il rally point a runtime (es. click destro sul terreno)
func set_rally_point(new_pos: Vector2) -> void:
	rallypoint_position = new_pos
	if is_instance_valid(_rally_marker_instance):
		_rally_marker_instance.global_position = rallypoint_position
	show_rally_marker()
