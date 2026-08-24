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
		
	# --- CASO SPECIALE: 1 SOLA UNITÀ ---
	if movable_units.size() == 1:
		var final_pos = GridManager.get_available_destination(target_position, movable_units[0])
		movable_units[0].move_to(final_pos)
		return

	# --- LOGICA PER PIÙ UNITÀ ---
	var cols: int = 3 
	
	for i in range(movable_units.size()):
		var unit = movable_units[i]
		var row: int = i / cols
		var col: int = i % cols
		
		var current_cols: int = min(movable_units.size() - (row * cols), cols)
		
		# Usiamo la spaziatura desiderata (es. 32.0)
		var x_offset: float = (col - (current_cols - 1) / 2.0) * default_spacing
		var y_offset: float = (row - (ceil(float(movable_units.size()) / cols) - 1) / 2.0) * default_spacing
		
		var slot_position: Vector2 = target_position + Vector2(x_offset, y_offset)
		
		# Prima di mandarla, facciamo fare lo snap al centro del tile e verifichiamo la prelazione
		var final_slot_position = GridManager.get_available_destination(slot_position, unit)
		
		unit.move_to(final_slot_position)
