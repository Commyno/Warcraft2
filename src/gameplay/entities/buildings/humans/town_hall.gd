class_name TownHall
extends ProductionBuilding

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	print(get_available_actions())
	add_to_group("town_hall")
