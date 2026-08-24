class_name GridOverlay
extends Node2D

@export var grid_size: float = 32.0         # Dimensione di ogni cella (es. 32x32 o 64x64)
@export var radius_in_cells: int = 4         # Quante celle mostrare intorno all'edificio
@export var grid_color: Color = Color(0.2, 0.8, 1.0, 0.5) # Colore base della griglia

var is_active: bool = false

func update_overlay(target_position: Vector2, show: bool) -> void:
	is_active = show
	if is_active:
		# Centriamo il nodo sulla posizione grigliata
		global_position = target_position
		queue_redraw() # Forza il ridisegno
	else:
		queue_redraw()

func _draw() -> void:
	if not is_active:
		return

	var max_distance: float = radius_in_cells * grid_size

	# Disegniamo le celle in un raggio attorno al centro
	for x in range(-radius_in_cells, radius_in_cells + 1):
		for y in range(-radius_in_cells, radius_in_cells + 1):
			var local_cell_center = Vector2(x * grid_size, y * grid_size)
			var distance = local_cell_center.length()

			# Se la cella rientra nel raggio di visione
			if distance <= max_distance:
				# Calcoliamo la sfumatura (alpha) in base alla distanza dal centro
				var alpha_factor = 1.0 - (distance / max_distance)
				var cell_color = grid_color
				cell_color.a = grid_color.a * alpha_factor

				# Rettangolo della singola cella
				var rect = Rect2(
					local_cell_center - Vector2(grid_size / 2.0, grid_size / 2.0),
					Vector2(grid_size, grid_size)
				)
				
				# Disegna il bordo della cella
				draw_rect(rect, cell_color, false, 1.0)
