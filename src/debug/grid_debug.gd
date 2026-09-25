extends Node2D

@export var thickness: float = 1.0 # 1.0 evita sbavature su tile piccoli
@export var tile_size: int = 32
@export var grid_dimensions: Vector2i = Vector2i(50, 50)
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.5)

var font = ThemeDB.fallback_font
var font_size = 7 # Ridotto per entrare agevolmente in 32x32

func _draw() -> void:
	var width = grid_dimensions.x * tile_size
	var height = grid_dimensions.y * tile_size

	# Disegna righe verticali
	for x in range(grid_dimensions.x + 1):
		var x_pos = (x * tile_size)
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, height), grid_color, thickness)

	# Disegna righe orizzontali
	for y in range(grid_dimensions.y + 1):
		var y_pos = (y * tile_size)
		draw_line(Vector2(0, y_pos), Vector2(width, y_pos), grid_color, thickness)

	# Disegna le coordinate al centro di ogni tile
	for x in range(grid_dimensions.x):
		for y in range(grid_dimensions.y):
			var cell_x = (x * tile_size)
			var cell_y = (y * tile_size)
			
			var center_pos = Vector2(cell_x + (tile_size / 2.0), cell_y + (tile_size / 2.0))
			
			var text = "%d,%d" % [x, y]
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			
			var draw_pos = center_pos - (text_size / 2.0)
			draw_pos.y += text_size.y / 3.0
			
			draw_string_outline(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Color.BLACK)
			draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
