extends TileMapLayer

func _unhandled_input(event: InputEvent) -> void:
	# Rileva il click sinistro del mouse sulla mappa
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var global_mouse_pos = get_global_mouse_position()
		
		# Converte le coordinate dello schermo/mondo nelle coordinate della griglia (es. Vector2i(5, 12))
		var tile_coords: Vector2i = local_to_map(global_mouse_pos)
		
		print("Hai cliccato sul Tile in coordinata: ", tile_coords)
