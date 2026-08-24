extends MarginContainer

@onready var action_grid: GridContainer = $ActionGrid

const ACTION_BUTTON_UID: String ="uid://mfavlv18jfrk"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#hide() # All'avvio si nasconde da solo
	
	var manager = get_tree().get_first_node_in_group("selection_manager")
	if manager:
		manager.selection_changed.connect(_on_selection_changed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_selection_changed(selected_objects: Array[Node2D]) -> void:
	# Selezionate PIÙ di una unità? Mi mostro, altrimenti mi nascondo.
	if selected_objects.size() > 0:
		action_grid.show()
		_update_ui(selected_objects)
	else:
		action_grid.hide()

func _update_ui(entities: Array[Node2D]) -> void:

# 1. PULIZIA: Elimina tutti i vecchi nodi figli dal GridContainer
	for child in action_grid.get_children():
		action_grid.remove_child(child) # Lo scollega istantaneamente dalla griglia
		child.queue_free()              # Lo cancella dalla memoria in sicurezza
		
	var button_scene: PackedScene = ResourceLoader.load(ACTION_BUTTON_UID) as PackedScene
	if button_scene == null:
		push_error("Could not load selected unit icon scene: " + ACTION_BUTTON_UID)
		return
	
	# 2. POPOLAMENTO: Crea un nuovo elemento per ogni entità selezionata
	if entities.size() > 0:
		# --- METODO A: Usando una Scena Prefabbricata (Consigliato) ---
		var entity = entities[0]
		
		if entity.available_actions.size() > 0:
			for action in entity.available_actions:
				var button = button_scene.instantiate()
				action_grid.add_child(button)
				
				# Se il tuo ritratto ha una funzione per aggiornarsi, passagli l'entità
				if button.has_method("setup"):
					button.setup(action)
				
				# Se sono stati selezionati più di un unità, visualizza solo i primi 4
				if entities.size() > 1 and action_grid.get_children().size() >= 4:
					break
	
	# 3. RIEMPIMENTO SLOT VUOTI FINO A 12
	var current_count = action_grid.get_children().size()
	var max_slots = 12
	
	if current_count < max_slots:
		var empty_needed = max_slots - current_count
		for i in range(empty_needed):
			# Creiamo un "fantasma" invisibile che tenga la posizione nella griglia
			var empty_slot = button_scene.instantiate()
			#empty_slot.custom_minimum_size = Vector2(31, 26)
			#empty_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			#empty_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			# 1. Rendiamo il bottone non cliccabile
			empty_slot.disabled = true
				
			action_grid.add_child(empty_slot)
