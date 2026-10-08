class_name ResourceBuilding
extends BaseBuilding

# --- SEGNALI ---

# --- VARIABILI INTERNE ---

func _ready() -> void:
	super()
	add_to_group("interactable")
	

# --- SISTEMA DI ESTRAZIONE ---

func on_depleted() -> void:
	# 1. Spegne collisioni, navmesh, selezione, input, _process
	_disable_interactivity()
	
	# 2. Mostra la texture di "miniera esaurita" (region_depleted è su BaseBuilding)
	_set_building_region(region_depleted)
	
# --- SISTEMA DI DANNO E DISTRUZIONE ---
#Override delle funzioni di distruzione in quanto non puo essere distrutta
func take_damage(amount: float) -> void:
	pass

func heal(amount: float) -> void:
	pass

func destroy_building() -> void:
	pass

# --- GESTIONE LAVORATORI ---

func get_health_perc() -> float:
	return 1.0 # Questo edificio non può essere distrutto dai giocatori
