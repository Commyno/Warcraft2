class_name UpgradeBuildingActionData
extends ActionData

@export_group("Evoluzione")
# Qui, nell'Inspector del tasto, trascinerai il file "keep_data.tres"
@export var target_building_data: BuildingData 

func can_execute(source_entities: Array, player: Player) -> bool:
	# Controlla se il giocatore ha i soldi per il Keep
	return target_building_data.is_affordable(player)

func _execute_action(source_entities: Array, target_data = null) -> void:
	var building = source_entities[0] as BaseBuilding
	var player = building.player_owner
	
	# 1. Paga le risorse
	player.spend_resources(
		target_building_data.gold_cost, 
		target_building_data.wood_cost, 
		# ... ecc
	)
	
	# 2. Avvia il processo di upgrade sull'edificio esistente
	building.start_upgrade(target_building_data)
