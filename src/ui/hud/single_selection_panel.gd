extends PanelContainer

# ==========================================
# ONREADY: GAME WORLD NODES
# ==========================================

@onready var panel_container: VBoxContainer = $MarginContainer/PanelContainer
@onready var unit_box: UnitBox = $MarginContainer/PanelContainer/UnitBox
@onready var building_box: BuildingBox = $MarginContainer/PanelContainer/BuildingBox
@onready var resource_box: ResourceBox = $MarginContainer/PanelContainer/ResourceBox

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
	if selected_object is BaseUnit:
		unit_box.show()
		unit_box.setup(selected_object)
	elif selected_object is ResourceBuilding:
		resource_box.setup(selected_object)
		resource_box.show()
	elif selected_object is BaseBuilding:
		building_box.setup(selected_object)
		building_box.show()
