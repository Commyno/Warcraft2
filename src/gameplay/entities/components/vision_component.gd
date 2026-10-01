class_name VisionComponent
extends Node

# --- SEGNALI ---

@export var sight_range: int = 4            # Raggio visivo (in tile o unità di misura)

func _ready() -> void:
	# Registra questo componente al FogManager appena il nodo entra nella scena
	FogManager.register_vision_component(self)

func _exit_tree() -> void:
	# Rimuove il componente dalla lista quando l'unità muore o viene rimossa (queue_free)
	FogManager.unregister_vision_component(self)

func setup(data: Resource) -> void:
	self.sight_range = data.sight_range
