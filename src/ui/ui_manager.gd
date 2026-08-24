extends CanvasLayer

# Trascineremo questi riferimenti dall'Inspector
@export var placement_manager: Node2D
@export var townhall_scene: PackedScene 
@export var barracks_scene: PackedScene 
@export var farm_scene: PackedScene 

# Creiamo un riferimento al bottone tramite percorso

func _ready() -> void:
	return
	
func _on_build_townhall_pressed() -> void:
	# Quando il bottone viene premuto, diciamo al manager di iniziare il piazzamento
	if placement_manager and townhall_scene:
		placement_manager.start_placement(townhall_scene)
	else:
		print("Errore: Placement Manager o Scena Edificio non assegnati nella UI!")

func _on_build_barracks_pressed() -> void:
	# Quando il bottone viene premuto, diciamo al manager di iniziare il piazzamento
	if placement_manager and barracks_scene:
		placement_manager.start_placement(barracks_scene)
	else:
		print("Errore: Placement Manager o Scena Edificio non assegnati nella UI!")

func _on_build_farm_pressed() -> void:
	# Quando il bottone viene premuto, diciamo al manager di iniziare il piazzamento
	if placement_manager and farm_scene:
		placement_manager.start_placement(farm_scene)
	else:
		print("Errore: Placement Manager o Scena Edificio non assegnati nella UI!")
