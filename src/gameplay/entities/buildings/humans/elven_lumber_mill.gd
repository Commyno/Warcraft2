class_name ElvenLumberMill
extends ProductionBuilding

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	add_to_group("lumber_mill")

# Se l'edificio viene distrutto e decidi che il bonus deve svanire
func _on_building_destroyed() -> void:
	player_owner.remove_lumber_modifier("elven_mill_upgrade_1")
