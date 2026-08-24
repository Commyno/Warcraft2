extends Node

# Spaziatura di default tra le unità nella griglia (in pixel)
@export var default_spacing: float = 64.0

# Funzione principale richiamabile da qualunque parte del gioco
func move_units_in_formation(units: Array, target_position: Vector2) -> void:
	# 1. Filtriamo per prendere SOLO le unità mobili
	var movable_units: Array = []
	for obj in units:
		# Il Duck Typing (has_method) è più flessibile del controllo di classe stretto
		if obj.has_method("move_to"): 
			movable_units.append(obj)
			
	# Se non ci sono unità da muovere, usciamo subito
	if movable_units.is_empty():
		return
		
	# --- CASO SPECIALE: 1 SOLA UNITÀ ---
	if movable_units.size() == 1:
		movable_units[0].move_to(target_position)
		return

	# --- LOGICA PER PIÙ UNITÀ (Griglia dinamica) ---
	var cols: int = 3 # Griglia base 3x3
	
	for i in range(movable_units.size()):
		var row: int = i / cols
		var col: int = i % cols
		
		# Per centrare la formazione sul punto target:
		var current_cols: int = min(movable_units.size() - (row * cols), cols)
		
		# Offset per centrare le righe e le colonne rispetto al click usando default_spacing
		var x_offset: float = (col - (current_cols - 1) / 2.0) * default_spacing
		var y_offset: float = (row - (ceil(float(movable_units.size()) / cols) - 1) / 2.0) * default_spacing
		
		var slot_position: Vector2 = target_position + Vector2(x_offset, y_offset)
		movable_units[i].move_to(slot_position)
