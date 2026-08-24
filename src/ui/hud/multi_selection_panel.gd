extends PanelContainer

const SELECTED_UNIT_ICON : String = "uid://brjing0k5xjv2"

@onready var grid_container: GridContainer = $GridContainer

func _ready() -> void:
	hide() # All'avvio si nasconde da solo
	
	var manager = get_tree().get_first_node_in_group("selection_manager")
	if manager:
		manager.selection_changed.connect(_on_selection_changed)

func _on_selection_changed(selected_objects: Array[Node2D]) -> void:
	# Selezionate PIÙ di una unità? Mi mostro, altrimenti mi nascondo.
	if selected_objects.size() > 1:
		show()
		_update_ui(selected_objects)
	else:
		hide()

func _update_ui(entities: Array[Node2D]) -> void:
	# 1. PULIZIA: Elimina tutti i vecchi nodi figli dal GridContainer
	for child in grid_container.get_children():
		child.queue_free()
		
	# 2. POPOLAMENTO: Crea un nuovo elemento per ogni entità selezionata
	for entity in entities:
		# --- METODO A: Usando una Scena Prefabbricata (Consigliato) ---
		var hud_scene: PackedScene = ResourceLoader.load(SELECTED_UNIT_ICON) as PackedScene
		if hud_scene == null:
			push_error("Could not load selected unit icon scene: " + SELECTED_UNIT_ICON)
			return

		var portrait = hud_scene.instantiate()
		grid_container.add_child(portrait)
		
		# Se il tuo ritratto ha una funzione per aggiornarsi, passagli l'entità
		if portrait.has_method("setup_portrait"):
			portrait.setup_portrait(entity)
