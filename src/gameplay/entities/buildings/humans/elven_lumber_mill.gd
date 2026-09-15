class_name ElvenLumberMill
extends ProductionBuilding

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	add_to_group("lumber_mill")
