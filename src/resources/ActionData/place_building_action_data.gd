class_name PlaceBuildingActionData
extends ActionData

@export_group("Edificio da costruire")
@export var building_data: BuildingData

func _init() -> void:
	action_type = ActionType.TARGET_GRID_TILE

func can_execute(source_entities: Array, player: Player) -> bool:
	if player == null or building_data == null:
		return false
	# Delega l'affordabilità al BuildingData (che conosce i propri costi)
	return building_data.is_affordable(player)

func execute(source_entities: Array, target_tile = null) -> void:
	if not (target_tile is Vector2i):
		push_warning("%s: target_tile non è un Vector2i" % id)
		return

	if building_data == null or building_data.building_scene == null:
		push_warning("%s: building_data o scena mancante" % id)
		return
	
	if source_entities.is_empty():
		return
	
	var builder = source_entities[0]
	var parent : Node2D = builder.get_parent()
	var owner_player: Player = builder.player_owner   # il proprietario = quello del contadino
	
	# Rete di sicurezza: non costruire in debito
	if owner_player == null or not building_data.is_affordable(owner_player):
		return
	
	# Paga le risorse
	if owner_player != null:
		owner_player.spend_resources(
			building_data.gold_cost, building_data.wood_cost,
			building_data.oil_cost, building_data.food_cost
		)
	
	# Istanzia sotto entities_root (non GridManager)
	var world_pos: Vector2 = GridManager.get_tile_center_global(target_tile)
	var building: BaseBuilding = building_data.building_scene.instantiate()
	if parent != null:
		parent.add_child(building)
	building.global_position = world_pos
	
	# Proprietario (id + oggetto + colore), come nello spawn
	if owner_player != null:
		building.player_owner = owner_player
		building.player_id = owner_player.player_id
		if "player_color" in building:
			building.player_color = owner_player.color
	
	building.place_under_construction()

	# Manda il primo contadino selezionato a costruire.
	#for unit in source_entities:   # Sostituire poi builder con unit
	if builder != null:
		if building.has_method("register_builder"):
			building.register_builder(builder)
		if builder.has_method("interact_with"):
			builder.interact_with(building)


func get_cost_string() -> String:
	if building_data == null:
		return ""
	var parts: Array[String] = []
	if building_data.gold_cost > 0: parts.append("Oro: %d" % building_data.gold_cost)
	if building_data.wood_cost > 0: parts.append("Legna: %d" % building_data.wood_cost)
	if building_data.oil_cost > 0:  parts.append("Petrolio: %d" % building_data.oil_cost)
	if building_data.food_cost > 0: parts.append("Cibo: %d" % building_data.food_cost)
	return " | ".join(parts)
