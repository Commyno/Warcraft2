extends Node

# Spaziatura tra le unità nella griglia (es. 32.0)
@export var default_spacing: float = 32.0

func move_units_in_formation(units: Array, target_position: Vector2) -> void:
	var movable_units: Array = []
	for obj in units:
		if obj.has_method("move_to"): 
			movable_units.append(obj)
			
	if movable_units.is_empty():
		return
	
	# 1. Prima di calcolare la formazione, liberiamo i tile posseduti da TUTTE le unità del gruppo.
	# Questo evita che le unità si blocchino a vicenda se la nuova destinazione ricalca in parte quella vecchia.
	for unit in movable_units:
		var agent_id = unit.get_instance_id()
		if unit.has_method("clear_assignment"):
			unit.clear_assignment()
		else:
			# Fallback di sicurezza usando l'ID corretto
			GridManager.release_agent(agent_id) 
	
	# --- CASO SPECIALE: 1 SOLA UNITÀ ---
	if movable_units.size() == 1:
		var unit = movable_units[0]
		var agent_id = unit.get_instance_id()
		var current_cell = GridManager.get_tile_coords(unit.global_position)
		var final_pos = GridManager.get_available_destination(target_position, agent_id, current_cell, true)
		unit.move_to(final_pos)
		return

	# --- CASO GRUPPO: > 1 UNITÀ ---
	# Qui definiamo una regola stabile per processare le richieste in sequenza,
	# in modo che ogni unità blocchi la sua cella prima che scelga la successiva
	for i in range(movable_units.size()):
		var unit = movable_units[i]
		var agent_id = unit.get_instance_id()
		var current_cell = GridManager.get_tile_coords(unit.global_position)
		
		# 2. Calcola dove "dovrebbe" stare questa unità nella formazione.
		# Puoi personalizzare _get_formation_offset per fare un quadrato, due linee, ecc.
		var formation_offset = _get_formation_offset(i, movable_units.size())
		var ideal_target = target_position + formation_offset
		
		# 3. Trova la cella libera più vicina all'ideal_target e prenotala atomitcamente.
		# Dato che auto_reserve = true, la cella viene bloccata e la prossima unità non vi si sovrapporrà.
		var final_pos = GridManager.get_available_destination(ideal_target, agent_id, current_cell, true)
		unit.move_to(final_pos)

## Funzione di supporto per calcolare lo sfalsamento a griglia (modificabile a piacere)
#func _get_formation_offset(index: int, total_units: int) -> Vector2:
	## Esempio: dispone le unità in una griglia quadrata centrata
	#var columns = ceil(sqrt(total_units))
	#var spacing = 32.0 # Spazio tra le unità (di solito pari al TILE_SIZE)
	#
	#var col = index % int(columns)
	#var row = floor(index / columns)
	#
	## Centra la griglia sul mouse
	#var offset_x = (col - (columns - 1) / 2.0) * spacing
	#var offset_y = (row - (ceil(total_units / columns) - 1) / 2.0) * spacing
	#
	#return Vector2(offset_x, offset_y)

# Calcola lo sfalsamento per disporre un gruppo di unità a forma di quadrato
func _get_formation_offset(index: int, total_units: int) -> Vector2:
	# La distanza tra un'unità e l'altra.
	# Sostituisci 32.0 con la dimensione in pixel della tua cella logica (es. GridManager.grid.cell_size.x)
	var spacing: float = 32.0 
	
	# Calcola quante colonne e righe servono per formare un quadrato
	var columns := int(ceil(sqrt(total_units)))
	var rows := int(ceil(float(total_units) / columns))
	
	# Determina la posizione nella griglia locale della formazione
	var col := index % columns
	var row := int(index / columns)
	
	# Moltiplica per lo spacing e sottrae la metà della larghezza/altezza totale 
	# per centrare perfettamente la formazione attorno al cursore
	var offset_x := (col - (columns - 1) / 2.0) * spacing
	var offset_y := (row - (rows - 1) / 2.0) * spacing
	
	return Vector2(offset_x, offset_y)
