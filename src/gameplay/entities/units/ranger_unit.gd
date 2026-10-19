extends BaseUnit
class_name RangerUnit

func _ready() -> void:
	super()
	
	# 1. Inizializza e attiva l'AnimationTree in modo sicuro
	if animation_tree:
		animation_tree.active = true
		state_machine = animation_tree.get("parameters/playback")

func _physics_process(delta: float) -> void:
	pass
