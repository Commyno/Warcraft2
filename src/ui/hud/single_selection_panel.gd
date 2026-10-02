extends PanelContainer

# ==========================================
# ONREADY: GAME WORLD NODES
# ==========================================

@onready var panel_container: VBoxContainer = $MarginContainer/PanelContainer
@onready var entity_box: EntityBox = $MarginContainer/PanelContainer/EntityBox

func _ready() -> void:
	hide() # All'avvio si nasconde da solo
		
	var manager = get_tree().get_first_node_in_group("selection_manager")
	if manager:
		manager.selection_changed.connect(_on_selection_changed)

func _on_selection_changed(selected_objects: Array[Node2D]) -> void:
	if selected_objects.size() != 1:
		return
	
	var selected_object = selected_objects[0]

	# 1. Nascondiamo tutti i figli
	for child in panel_container.get_children():
		child.hide()
		
	# 2. Aggiungiamo il nodo corretto
	entity_box.show()
	entity_box.setup(selected_object)
