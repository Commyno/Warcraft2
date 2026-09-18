extends Node2D

@export var box_size: Vector2 = Vector2(32, 32)
@export var color: Color = Color(0.2, 0.9, 0.2, 0.8)
@export var thickness: float = 1.0

func _draw() -> void:
	var top_left := -box_size / 2.0        # centra il rettangolo sull'unità
	var rect := Rect2(top_left, box_size)
	draw_rect(rect, color, false, thickness)   # false = solo bordo, non riempito
