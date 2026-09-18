extends Node

# Riferimento al layer YSort dove devono risiedere tutte le unità
var entity_container: Node2D = null
var effects_container: Node2D = null

func register_units_container(_entity_container: Node2D, _effects_container: Node2D) -> void:
	entity_container = _entity_container
	effects_container = _effects_container

func spawn_building(building_data: BuildingData, spawn_pos: Vector2, is_under_costruction: bool, owner_player: Player) -> BaseBuilding:
	# Rete di sicurezza: non costruire in debito
	if owner_player == null or not building_data.is_affordable(owner_player):
		return
	
	# Paga le risorse
	if owner_player != null:
		owner_player.spend_resources(
			building_data.gold_cost, building_data.lumber_cost,
			building_data.oil_cost, building_data.food_cost
		)
	
	# Istanzia sotto entities_root (non GridManager)
	var world_pos: Vector2 = GridManager.get_tile_center_global(spawn_pos)
	var building: BaseBuilding = building_data.get_scene().instantiate()
	if building:
		building.setup(building_data)

	if entity_container != null:
		entity_container.add_child(building)
	building.global_position = world_pos

	var origin_tile: Vector2i = GridManager.get_tile_coords(world_pos)
	GridManager.register_building_occupation(origin_tile, building_data.tile_size, building)

	# Proprietario (id + oggetto + colore), come nello spawn
	if owner_player != null:
		building.player_owner = owner_player
		building.player_id = owner_player.player_id
		if "player_color" in building:
			building.player_color = owner_player.color
	
	building.place_under_construction()
	
	return building

func spawn_unit(unit_data: UnitData, spawn_pos: Vector2, rally_point: Vector2, owner_player: Player) -> BaseUnit:
	if unit_data == null or unit_data.scene_path.is_empty():
		push_error("SpawnManager: UnitData o scena non valida.")
		return null
	var entity_scene = unit_data.get_scene()
	if entity_scene == null:
		push_error("SpawnManager: UnitData o scena non valida.")
		return null

	if entity_container == null:
		push_error("SpawnManager: units_container non registrato! Assicurati di registrarlo in GameScene.")
		return null

	# 1. Trova una posizione valida libera usando la griglia per evitare sovrapposizioni
	var target_tile = GridManager.get_tile_coords(spawn_pos)
	var final_spawn_pos = spawn_pos

	# Se hai una funzione di ricerca tile libero nel tuo GridManager:
	if GridManager.has_method("find_nearest_walkable_tile"):
		final_spawn_pos = GridManager.find_nearest_walkable_tile(spawn_pos)
	
	# 2. Istanziazione della scena dell'unità
	var unit_instance = entity_scene.instantiate()
	if unit_instance == null:
		push_error("SpawnManager: Impossibile istanziare l'unità %s" % unit_data.name)
		return null

	# 3. Setup dei dati prima di aggiungerla all'albero
	if unit_instance.has_method("setup"):
		unit_instance.setup(unit_data)

	unit_instance.player_owner = owner_player
	unit_instance.global_position = final_spawn_pos

	# 4. Inserimento nel mondo di gioco
	entity_container.add_child(unit_instance)

	# 5. Registrazione sulla griglia
	var standing_tile = GridManager.get_tile_coords(final_spawn_pos)
	if GridManager.has_method("try_reserve_tile"):
		GridManager.try_reserve_tile(standing_tile, unit_instance)

	# 6. Ordine di movimento verso il Rally Point (se diverso dalla posizione di spawn)
	if rally_point != Vector2.ZERO and rally_point != final_spawn_pos:
		if unit_instance.has_method("move_to"):
			unit_instance.move_to(rally_point)

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
