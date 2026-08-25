class_name SelectionManager
extends Node2D

# --- PROPRIETÀ E STATO ---
var is_dragging: bool = false
var start_pos: Vector2 = Vector2.ZERO
var current_pos: Vector2 = Vector2.ZERO
var debug_click_pos: Vector2 = Vector2.ZERO

# Array master contenente gli elementi attualmente selezionati (BaseUnit o BaseBuilding)
var currently_selected: Array[Node2D] = []

# Soglia in pixel per distinguere un "click" da un "trascinamento"
const DRAG_THRESHOLD: float = 10.0

# Spaziatura tra le truppe all'interno della formazione (in pixel)
@export var formation_spacing: float = 64.0

# --- SEGNALI ---
# Emesso ogni volta che la selezione cambia, passando l'array completo degli elementi selezionati
signal selection_changed(selected_objects: Array[Node2D])

func _unhandled_input(event: InputEvent) -> void:
	# --- 1. GESTIONE CLICK SINISTRO (Selezione) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			start_pos = get_global_mouse_position()
			current_pos = start_pos
		else:
			is_dragging = false
			current_pos = get_global_mouse_position()
			_process_selection()
			
		queue_redraw()

	# --- 2. GESTIONE MOVIMENTO (Disegno del rettangolo di selezione) ---
	# Movimento del mouse durante il trascinamento
	if event is InputEventMouseMotion and is_dragging:
		current_pos = get_global_mouse_position()
		queue_redraw()
		
	# --- 3. GESTIONE CLICK DESTRO (Ordine di Movimento in Formazione) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			# Filtra solo le unità mobili per il movimento
			var mobile_units: Array[BaseUnit] = []
			for obj in currently_selected:
				if obj is BaseUnit:
					mobile_units.append(obj as BaseUnit)
			
			if mobile_units.size() > 0:
				var target_position = get_global_mouse_position()

				# 1. Controlliamo se abbiamo cliccato un oggetto interattivo (Nodi: Miniere, Nemici, Municipi)
				var clicked_target = _get_object_under_mouse(target_position)

				if clicked_target:
					# INTERAZIONE NODO: Ordiniamo alle unità di interagire con il bersaglio
					for unit in mobile_units:
						if unit.has_method("interact_with"):
							unit.interact_with(clicked_target)
				else:
					# 2. Controlliamo se abbiamo cliccato un TILE interattivo (es. Alberi)
					var clicked_tile = GridManager.get_tile_coords(target_position)
					
					# Chiediamo al GridManager se quel tile specifico è legna
					if GridManager.is_tree(clicked_tile):
						var tree_global_pos = GridManager.get_global_from_tile(clicked_tile)
						
						for unit in mobile_units:
							# Solo i Peasant hanno l'abilità di tagliare!
							if unit is Peasant:
								# Calcoliamo la direzione per farlo fermare dal lato giusto
								var direction_to_tree = (tree_global_pos - unit.global_position).normalized()
								# Troviamo il tile libero adiacente all'albero
								var safe_destination = GridManager.get_adjacent_free_position(tree_global_pos, Vector2i(1, 1), direction_to_tree, unit)
								
								unit.interact_with_tile(clicked_tile, safe_destination)
							else:
								# Se per caso selezioni soldati e contadini insieme e clicchi un albero, 
								# i soldati si muoveranno semplicemente lì vicino.
								unit.move_to(GridManager.get_available_destination(target_position, unit))
					
					# 3. MOVIMENTO NORMALE SULLA MAPPA (Spazio vuoto)
					else:
						var final_destination = target_position
						if not mobile_units.is_empty():
							final_destination = GridManager.get_available_destination(target_position, mobile_units[0])
						debug_click_pos = final_destination
						queue_redraw()
						FormationManager.move_units_in_formation(mobile_units, final_destination)

func _draw():
	if is_dragging:
		# Convertiamo le posizioni da Globali a Locali relative a questo Node2D
		var local_start = to_local(start_pos)
		var local_current = to_local(current_pos)
		
		# Crea il rettangolo basato sulle posizioni locali
		var rect = Rect2(local_start, local_current - local_start)
		
		# Colore interno (Verde semi-trasparente)
		var fill_color = Color(0.0, 1.0, 0.0, 0.2)
		draw_rect(rect, fill_color, true)
		
		# Colore del bordo (Verde solido, spessore 2 pixel)
		var border_color = Color(0.0, 1.0, 0.0, 0.8)
		draw_rect(rect, border_color, false, 2.0)
		
	# --- AGGIUNGI QUESTO PER IL PUNTINO ROSSO ---
	if debug_click_pos != Vector2.ZERO:
		# Disegna un cerchio rosso pieno di raggio 6 pixel
		draw_circle(to_local(debug_click_pos), 6.0, Color.RED)

func _process_selection():
	# 1. Deseleziona e svuota tutto quello che era selezionato prima
	_clear_current_selection()

	var selection_rect = Rect2(start_pos, current_pos - start_pos).abs()
	var all_selectables = get_tree().get_nodes_in_group("selectable_units")
	
	var candidates: Array[Node2D] = []
	
	# 2. Raccoglie i candidati (differenza tra click singolo e rettangolo)
	if selection_rect.size.length() < DRAG_THRESHOLD:
		# CLICK SINGOLO: Cerca l'oggetto più vicino (raggio di tolleranza ~30px)
		var closest_obj: Node2D = null
		var min_dist: float = INF
		
		for obj in all_selectables:
			if obj is Node2D:
				var dist = obj.global_position.distance_to(start_pos)
				if dist < 30.0 and dist < min_dist:
					closest_obj = obj
					min_dist = dist
				
		if closest_obj:
			candidates.append(closest_obj)
	else:
		# TRASCINAMENTO (BOX SELECTION)
		for obj in all_selectables:
			if obj is Node2D and selection_rect.has_point(obj.global_position):
				candidates.append(obj)
	
	# 3. Applica la priorità WC3: Unità > Edifici
	var units_found: Array[BaseUnit] = []
	var building_found: BaseBuilding = null
	
	for obj in candidates:
		if obj is BaseUnit:
			units_found.append(obj as BaseUnit)
		elif obj is BaseBuilding and building_found == null:
			building_found = obj as BaseBuilding
		
	# Se ci sono unità, selezioniamo quelle. Altrimenti seleziona l'edificio (se presente).
	if not units_found.is_empty():
		for unit in units_found:
			_select_object(unit)
	elif building_found != null:
		_select_object(building_found)
	
	# 4. Emette il segnale finale verso l'UI (ActionGridUI, Portatili, ecc.)
	selection_changed.emit(currently_selected)

func _select_object(obj: Node2D) -> void:
	currently_selected.append(obj)
	if obj.has_method("select"):
		obj.select()

func _clear_current_selection() -> void:
	for obj in currently_selected:
		if is_instance_valid(obj) and obj.has_method("deselect"):
			obj.deselect()
	currently_selected.clear()
	
	# Funzione per trovare l'oggetto sotto il mouse
func _get_object_under_mouse(pos: Vector2) -> Node2D:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = true  # Se la miniera è un'Area2D
	query.collide_with_bodies = true # Se la miniera è uno StaticBody2D/RigidBody2D
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var collider = result.collider
		# Supponiamo che gli edifici o risorse siano in un gruppo specifico o ereditino da una classe
		if collider.is_in_group("interactable") or collider is BaseBuilding:
			return collider
			
	return null

func get_snapped_tile_position(global_click_pos: Vector2, tile_map_layer: TileMapLayer) -> Vector2:
	if not tile_map_layer:
		return global_click_pos # Fallback se manca il TileMapLayer
		
	# 1. Convertiamo la posizione globale del clic in posizione locale del TileMapLayer
	var local_pos = tile_map_layer.to_local(global_click_pos)
	
	# 2. Troviamo le coordinate della griglia (es. Vector2i(x, y))
	var tile_coords = tile_map_layer.local_to_map(local_pos)
	
	# 3. Riconvertiamo le coordinate della griglia nel centro geometrico del tile (in locale)
	var local_center_pos = tile_map_layer.map_to_local(tile_coords)
	
	# 4. Riportiamo tutto in coordinate globali del mondo di gioco
	return tile_map_layer.to_global(local_center_pos)
