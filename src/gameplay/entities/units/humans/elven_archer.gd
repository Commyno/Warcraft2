extends RangerUnit
class_name ElvenArcher

func _ready() -> void:
	super()

	# 1. Inizializza e attiva l'AnimationTree in modo sicuro
	if animation_tree:
		animation_tree.active = true
		state_machine = animation_tree.get("parameters/playback")

func update_animation() -> void:
	if not animation_tree or not state_machine:
		return
	
	var actual_speed: float = velocity.length()
	# Direzione di movimento basata sulla velocità attuale dell'Avoidance
	var move_dir: Vector2 = movement_component.intended_dir if (movement_component and movement_component.is_moving) else last_facing_dir

	# Fallback se l'avoidance ci rallenta o ferma un secondo
	if move_dir == Vector2.ZERO:
		move_dir = last_facing_dir
	
	update_animation_parameters(move_dir)
	
	if is_dead:
		state_machine.start("Death")
		animation_state = "Death"
		return
		
	# Gestione flip orizzontale
	if move_dir.x < -0.1:
		sprite2d.flip_h = true
	elif move_dir.x > 0.1:
		sprite2d.flip_h = false
		
	animation_state = "Idle"
	match unit_state:
		UnitState.MOVING, UnitState.RETURNING_RESOURCES:
			if actual_speed > 10.0:
				last_facing_dir = move_dir
				animation_state = "Walk"
		UnitState.ATTACKING, UnitState.BUILDING, UnitState.REPARING, UnitState.CHOPPING:
			animation_state = "Attack"
	
	if animation_state != last_animation_state:
		state_machine.travel(animation_state)
		last_animation_state = animation_state

func update_animation_parameters(move_velocity: Vector2) -> void:
	var move_dir: Vector2 = move_velocity.normalized()
	if move_dir == Vector2.ZERO: return
	animation_tree.set("parameters/Death/blend_position", move_dir)
	animation_tree.set("parameters/Attack/blend_position", move_dir)	
	animation_tree.set("parameters/Idle/blend_position", move_dir)
	animation_tree.set("parameters/Walk/blend_position", move_dir)
