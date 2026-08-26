extends Control

# ==========================================
# CONSTANTS (SCENE UIDs)
# ==========================================
const DEBUG_TEXT_OVERLAY_UID : String = "uid://du81fow7urjxf"
const DEBUG_PLAYER_OVERLAY   : String = "uid://kpwsylemtds6"


# ==========================================
# VARIABLES
# ==========================================
var _debug_canvas: CanvasLayer
var _debug_view: Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_debug_layer(DEBUG_TEXT_OVERLAY_UID)
	pass # Replace with function body.

func _unhandled_input(event: InputEvent) -> void:
ù	if event is InputEventKey and event.keycode == KEY_1:
		if event.pressed and not event.echo:
			_set_debug_panel_visible(true)
		elif not event.pressed:
			_set_debug_panel_visible(false)

func _set_debug_panel_visible(is_visible: bool) -> void:
	if is_visible and not is_instance_valid(_debug_canvas):
		_create_debug_panel()

	if is_instance_valid(_debug_canvas):
		_debug_canvas.visible = is_visible
		if is_visible:
			_refresh_debug_data()

func _create_debug_panel() -> void:
	_debug_canvas = CanvasLayer.new()
	add_child(_debug_canvas)

	var debug_scene: PackedScene = ResourceLoader.load(DEBUG_PLAYER_OVERLAY) as PackedScene
	if debug_scene == null:
		push_error("Could not load debug scene: " + DEBUG_PLAYER_OVERLAY)
		return
	
	# Istanziamo la vista UI creata al passaggio precedente
	_debug_view = debug_scene.instantiate() as Node
	_debug_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_canvas.add_child(_debug_view)
	
func _refresh_debug_data() -> void:
	# Recuperiamo la lista dei nodi giocatore
	var player_nodes: Array = get_tree().get_nodes_in_group("players")
	
	# Passiamo l'array alla funzione update della View
	_debug_view.update(player_nodes)
	
func load_debug_layer(scene_path: String) -> void:
	var debug_scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	if debug_scene == null:
		push_error("Could not load debug scene: " + scene_path)
		return
	
	var debug_node = debug_scene.instantiate() as Node
	
	add_child(debug_node)
