class_name ProductionBuilding
extends BaseBuilding

@export var max_queue_size: int = 5
@export var spawn_offset: Vector2 = Vector2(0, 32)

@export_group("Rally Point")
@export var rally_point: Vector2 = Vector2.ZERO
@export var rally_marker_scene: PackedScene # Assegna una scena con Sprite2D (o creiamo un fallback)
@export var rally_marker_texture: Texture2D  # In alternativa, passa solo la texture

var training_queue: Array[UnitData] = []
var current_training_time: float = 0.0
var _rally_marker_instance: Node2D = null

signal queue_updated(queue: Array[UnitData])
signal progress_updated(progress_percent: float)

func _ready() -> void:
	super()
	add_to_group("interactable")
	
	# Crea l'indicatore all'avvio ma mantienilo nascosto
	_create_rally_marker()

func _process(delta: float) -> void:
	# 1. Gestione Training
	if training_queue.is_empty():
		return
	
	var current_unit: UnitData = training_queue[0]
	var total_time: float = max(current_unit.build_time, 0.1)
	
	# 1. Se il tempo non è ancora finito, fai avanzare la barra
	if current_training_time < total_time:
		current_training_time += delta
		var progress: float = clampf(current_training_time / total_time, 0.0, 1.0)
		progress_updated.emit(progress)
	
	# 2. Se il tempo è completato, tenta lo spawn solo se c'è cibo
	if current_training_time >= total_time:
		# Assicuriamo che la barra resti fissa al 100% in caso di attesa cibo
		progress_updated.emit(1.0)
		
		if player_owner != null:
			if player_owner.has_enough_food(current_unit.food_cost):
				_complete_training(current_unit)
			else:
				# Bloccato al 100%: aspetta finché il player non costruisce una fattoria
				pass
		else:
			_complete_training(current_unit)

# --- GESTIONE CODA ---

func is_queue_full() -> bool:
	return training_queue.size() >= max_queue_size

func enqueue_unit(data: UnitData) -> bool:
	if is_queue_full() or player_owner == null:
		return false
		
	if player_owner.has_enough_resources(data.gold_cost, data.lumber_cost, data.oil_cost, data.food_cost) > 0:
		return false
		
	player_owner.spend_for_unit(data)
	training_queue.append(data)
	queue_updated.emit(training_queue)
	return true

func cancel_unit_at(index: int) -> void:
	if index < 0 or index >= training_queue.size():
		return
		
	var canceled_unit: UnitData = training_queue[index]
	training_queue.remove_at(index)
	
	if player_owner != null:
		player_owner.refund_unit(canceled_unit)
	
	# Se annulliamo la prima unità, resettiamo il timer
	if index == 0:
		current_training_time = 0.0
		progress_updated.emit(0.0)
		
	queue_updated.emit(training_queue)

func _complete_training(data: UnitData) -> void:
	# Consuma il cibo prima di togliere l'unità dalla coda
	if player_owner != null:
		player_owner.consume_food(data.food_cost)

	training_queue.pop_front()
	current_training_time = 0.0
	progress_updated.emit(0.0)
	queue_updated.emit(training_queue)

	var spawn_pos: Vector2 = global_position + spawn_offset
	SpawnManager.spawn_unit(data, spawn_pos, rally_point, player_owner)

func _spawn_unit(data: UnitData) -> void:
	if data.scene_path.is_empty():
		return

	var unit_instance: Node2D = data.get_scene().instantiate()
	
	# Passiamo prima le statistiche all'unità
	if unit_instance.has_method("setup"):
		unit_instance.setup(data)

	# Aggiungiamo l'unità allo stesso livello dell'edificio (mondo di gioco)
	get_parent().add_child(unit_instance)
	unit_instance.global_position = global_position + spawn_offset
	
	if "player_owner" in unit_instance:
		unit_instance.player_owner = player_owner

	# Movimento verso il Rally Point
	if unit_instance.has_method("move_to") and rally_point != Vector2.ZERO:
		unit_instance.move_to(rally_point)

func accept_resources(resource: Globals.ResourceType) -> bool:
	if is_resource_dropoff:
		if resource == Globals.ResourceType.GOLD and accepts_gold:
			return true
		if resource == Globals.ResourceType.WOOD and accepts_wood:
			return true
		if resource == Globals.ResourceType.OIL and accepts_oil:
			return true
	
	return false

func _create_rally_marker() -> void:
	if _rally_marker_instance != null:
		return

	# Se hai una PackedScene usa quella, altrimenti crea un semplice Sprite2D da codice
	if rally_marker_scene != null:
		_rally_marker_instance = rally_marker_scene.instantiate()
	else:
		var sprite = Sprite2D.new()
		sprite.texture = rally_marker_texture
		# Opzionale: offset visivo se l'icona è centrata
		_rally_marker_instance = sprite

	_rally_marker_instance.visible = false
	_rally_marker_instance.global_position = global_position

	# Inserisci il marker nel container degli effetti tramite SpawnManager (o nel genitore)
	if SpawnManager.effects_container != null:
		SpawnManager.effects_container.add_child(_rally_marker_instance)
	else:
		get_parent().call_deferred("add_child", _rally_marker_instance)

func _exit_tree() -> void:
	# Pulizia se l'edificio viene distrutto
	if is_instance_valid(_rally_marker_instance):
		_rally_marker_instance.queue_free()

func _show_rally_marker() -> void:
	if rally_point == Vector2.ZERO:
		return
		
	if _rally_marker_instance == null:
		_create_rally_marker()
		
	if is_instance_valid(_rally_marker_instance):
		_rally_marker_instance.global_position = rally_point
		_rally_marker_instance.visible = true

func _hide_rally_marker() -> void:
	if is_instance_valid(_rally_marker_instance):
		_rally_marker_instance.visible = false

# Metodo per aggiornare il rally point a runtime (es. click destro sul terreno)
func set_rally_point(new_pos: Vector2) -> void:
	rally_point = new_pos
	if is_instance_valid(_rally_marker_instance):
		_rally_marker_instance.global_position = rally_point
	_show_rally_marker()

# --- METODI DI SELEZIONE ---

func select() -> void:
	super()
	_show_rally_marker()

func deselect() -> void:
	super()
	_hide_rally_marker()
