class_name MovementComponent
extends Node

# --- SEGNALI ---

@export var move_speed: int = 100            # Raggio visivo (in tile o unità di misura)

func _ready() -> void:
	pass

#func _exit_tree() -> void:
	#pass

func setup(data: Resource) -> void:
	self.move_speed = data.move_speed
