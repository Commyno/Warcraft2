extends Node

# Riferimento al layer YSort dove devono risiedere tutte le unità
var units_container: Node2D = null
var effects_container: Node2D = null

func register_units_container(_units_container: Node2D, _effects_container: Node2D) -> void:
	units_container = _units_container
	effects_container = _effects_container

func spawn_unit(unit_data: UnitData, spawn_pos: Vector2, rally_point: Vector2, owner_player: Player) -> BaseUnit:
	if unit_data == null or unit_data.scene_path.is_empty():
		push_error("SpawnManager: UnitData o scena non valida.")
		return null
	var entity_scene = unit_data.get_scene()
	if entity_scene == null:
		push_error("SpawnManager: UnitData o scena non valida.")
		return null

	if units_container == null:
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
	units_container.add_child(unit_instance)

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
		
	var parent_node = effects_container if effects_container != null else units_container
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
