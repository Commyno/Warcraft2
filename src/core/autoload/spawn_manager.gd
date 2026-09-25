extends Node

# Riferimento al layer YSort dove devono risiedere tutte le unità
var entity_container: Node2D = null
var effects_container: Node2D = null

func register_units_container(_entity_container: Node2D, _effects_container: Node2D) -> void:
	entity_container = _entity_container
	effects_container = _effects_container

func spawn_building(building_data: BuildingData, spawn_tile: Vector2, is_under_costruction: bool, owner_player: Player) -> BaseBuilding:
	var world_pos: Vector2 = GridManager.get_tile_center_global(spawn_tile)
	# 2. Calcola l'offset per centrare l'edificio fisicamente (stessa logica della preview)
	var size: Vector2i = building_data.tile_size
	var cell_size: Vector2 = GridManager.grid.cell_size
	var offset: Vector2 = (Vector2(size) - Vector2.ONE) * (cell_size / 2.0)
	var final_world_pos: Vector2 = world_pos + offset
	
	var building: BaseBuilding = building_data.get_scene().instantiate()
	
	if building.has_method("setup"):
		building.setup(building_data)

	if entity_container != null:
		entity_container.add_child(building)
	building.global_position = final_world_pos

	# --- NUOVA LOGICA: Registrazione Footprint Edificio ---
	#var origin_tile: Vector2i = GridManager.get_tile_coords(final_world_pos)
	var building_id: int = building.get_instance_id()
	
	# Assumendo che tile_size sia un Vector2i (es. 3x3), usiamo la X
	var footprint = GridManager.footprint_cells(spawn_tile, building_data.tile_size)
	
	for cell in footprint:
		GridManager.confirm_move(building_id, cell, cell)
	GridManager.set_cells_solid(footprint, true)
	# ------------------------------------------------------

	if is_instance_valid(owner_player):
		if "player_owner" in building:
			building.player_owner = owner_player

		if "player_color" in building:
			building.player_color = owner_player.color
	
	if is_under_costruction:
		building.place_under_construction()
	else:
		building.complete_construction()
	
	return building

func spawn_unit(unit_data: UnitData, building_center_pos: Vector2, rally_point: Vector2, owner_player: Player, building_size: Vector2i = Vector2i.MIN) -> BaseUnit:
	if unit_data == null or unit_data.scene_path.is_empty():
		push_error("SpawnManager: UnitData o scena non valida.")
		return null
		
	var entity_scene = unit_data.get_scene()
	if entity_container == null:
		push_error("SpawnManager: units_container non registrato!")
		return null

	# 1. Istanzia subito l'unità per registrarla nell'albero e ottenere l'ID univoco
	var unit_instance : BaseUnit = entity_scene.instantiate() as BaseUnit
	entity_container.add_child(unit_instance)
	var unit_id: int = unit_instance.get_instance_id()

	# 2. Calcola la posizione di spawn consapevole del contesto (stile War2)
	var final_spawn_pos = building_center_pos
	 # Se lo spawn è da edificio, calcoliamo l'offset
	if not building_size == Vector2i.MIN:
		final_spawn_pos = GridManager.get_warcraft_spawn_position(building_center_pos, building_size, rally_point, unit_id)

	# 3. Setup dei dati dell'unità
	unit_instance.global_position = final_spawn_pos
	unit_instance.player_owner = owner_player
	if unit_instance.has_method("setup"):
		unit_instance.setup(unit_data)

	# 4. Ordine di movimento verso il Rally Point
	if rally_point != Vector2.INF and rally_point != final_spawn_pos:
		if unit_instance.has_method("move_to"):
			var current_cell = GridManager.get_tile_coords(final_spawn_pos)
			var safe_target = GridManager.get_available_destination(rally_point, unit_id, current_cell, true)
			unit_instance.move_to(safe_target)

	return unit_instance

func spawn_effect(effect_scene: PackedScene, spawn_pos: Vector2, auto_free_delay: float = 0.0) -> Node2D:
	if effect_scene == null:
		return null
		
	var parent_node = effects_container if effects_container != null else entity_container
	if parent_node == null:
		push_error("SpawnManager: Nessun container registrato per gli effetti!")
		return null
		
	var effect_instance = effect_scene.instantiate()
	parent_node.add_child(effect_instance)
	effect_instance.global_position = spawn_pos
	
	# Se passi un delay > 0, distrugge automaticamente l'effetto senza timer interni
	if auto_free_delay > 0.0:
		get_tree().create_timer(auto_free_delay).timeout.connect(effect_instance.queue_free)
		
	return effect_instance
