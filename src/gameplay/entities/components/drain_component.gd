class_name DrainComponent
extends Node

@export_group("Capabilities")
@export var food_provided: int = 0               # es. +4 per Farm/Pig Farm, +1 per Town Hall/Great Hall
@export var accepts_gold: bool = false
@export var accepts_wood: bool = false
@export var accepts_oil: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup(data: Resource) -> void:
	self.accepts_gold = data.accepts_gold
	self.accepts_wood = data.accepts_wood
	self.accepts_oil = data.accepts_oil

func accept_resources(resource: Globals.ResourceType) -> bool:
	if resource == Globals.ResourceType.GOLD and accepts_gold:
		return true
	if resource == Globals.ResourceType.WOOD and accepts_wood:
		return true
	if resource == Globals.ResourceType.OIL and accepts_oil:
		return true
	
	return false
