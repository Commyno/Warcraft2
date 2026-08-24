extends Control

signal pause_menu(origin: String)

@onready var single_selection_panel: PanelContainer = $MarginContainer/PanelContainer/VContainer/SingleSelectionPanel
@onready var multi_selection_panel: PanelContainer = $MarginContainer/PanelContainer/VContainer/MultiSelectionPanel

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
	
	if count == 0:
		single_selection_panel.hide()
		multi_selection_panel.hide()
	elif count == 1:
		multi_selection_panel.hide()
		single_selection_panel.show()
		# _update_single_panel_ui(selected_objects[0])
	else:
		single_selection_panel.hide()
		multi_selection_panel.show()
		# _update_multi_panel_ui(selected_objects)
