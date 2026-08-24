extends Node2D

@export var grid_size: int = 64
@export var grid_dimensions: Vector2i = Vector2i(50, 50)
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.5)

func _draw() -> void:
	var width = grid_dimensions.x * grid_size
	var height = grid_dimensions.y * grid_size
	var start_x = -width / 2.0
	var start_y = -height / 2.0

	# Disegna righe verticali
	for x in range(grid_dimensions.x + 1):
		var x_pos = start_x + (x * grid_size)
		draw_line(Vector2(x_pos, start_y), Vector2(x_pos, start_y + height), grid_color, 2.0)

	# Disegna righe orizzontali
	for y in range(grid_dimensions.y + 1):
		var y_pos = start_y + (y * grid_size)
		draw_line(Vector2(start_x, y_pos), Vector2(start_x + width, y_pos), grid_color, 2.0)
