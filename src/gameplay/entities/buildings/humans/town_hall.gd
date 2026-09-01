class_name TownHall
extends ProductionBuilding

# --- VARIABILI PER PRODUZIONE ---
@export_group("Produzione")
@export var trainable_units: Array[UnitData] = [] # contiene peasant_data.tres

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	add_to_group("town_hall")
	
	deselect()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
