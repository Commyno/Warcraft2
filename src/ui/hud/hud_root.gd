extends Control

signal pause_menu(origin: String)
@onready var single_selection_panel: PanelContainer = $PanelContainer/VContainer/SingleSelectionPanel
@onready var multi_selection_panel: PanelContainer = $PanelContainer/VContainer/MultiSelectionPanel
@onready var action_grid_mc: MarginContainer = $PanelContainer/VContainer/ActionGridMC
@onready var minimap: Minimap = $PanelContainer/VContainer/MinimapContainer/Minimap

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Nascondiamo i pannelli all'avvio
	single_selection_panel.hide()
	multi_selection_panel.hide()
	
	# Cerchiamo il SelectionManager tramite il gruppo
	var manager = get_tree().get_first_node_in_group("selection_manager")
	
	if manager:
		manager.selection_changed.connect(_on_selection_changed)
	else:
		push_error("HUD: Nessun SelectionManager trovato nel gruppo 'selection_manager'!")

func _on_menu_button_pressed() -> void:
	pause_menu.emit("GameScene")

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_selection_changed(selected_objects: Array[Node2D]) -> void:
	var count = selected_objects.size()
	
	single_selection_panel.hide()
	multi_selection_panel.hide()
	action_grid_mc.hide()

	multi_selection_panel.update_ui(selected_objects)

	if count == 1:
		# Show DetailBox
		single_selection_panel.show()
		# Check to show ActionGrid box
		if action_grid_mc.can_show():
			action_grid_mc.show()
		else:
			action_grid_mc.hide()
	elif count > 1:
		# Show MultiSelection
		multi_selection_panel.show()

func setup_minimap(camera: Camera2D) -> void:
	minimap.game_camera = camera
	minimap.setup_minimap()
	pass
