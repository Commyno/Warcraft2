class_name DefendBuilding
extends BaseBuilding

func complete_construction() -> void:
	var builders_to_release = active_builders.duplicate()
	active_builders.clear()
	for builder in builders_to_release:
		if is_instance_valid(builder):
			builder.clear_assignment()
	
	player_owner.register_building_completed(entity_id, food_provided)
	
	super()
