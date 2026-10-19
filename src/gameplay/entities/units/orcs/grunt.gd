class_name Grunt
extends BaseUnit

func _ready() -> void:
	super()
	
	# 1. Inizializza e attiva l'AnimationTree in modo sicuro
	if animation_tree:
		animation_tree.active = true
		state_machine = animation_tree.get("parameters/playback")
