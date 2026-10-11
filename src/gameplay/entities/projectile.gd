class_name Projectile
extends Node2D

@export var speed: float = 400.0

var target: Node2D = null
var damage: int = 0
var piercing_damage: int = 0
var damage_type: Globals.DamageType = Globals.DamageType.NORMAL

func setup(_target: Node2D, _damage: int, _pierce: int, _type: Globals.DamageType) -> void:
	target = _target
	damage = _damage
	piercing_damage = _pierce
	damage_type = _type
	
	# Orienta subito la freccia visivamente verso il bersaglio
	look_at(target.global_position)

func _physics_process(delta: float) -> void:
	# Se il bersaglio muore mentre la freccia è in volo, distruggila
	if not is_instance_valid(target) or ("is_dead" in target and target.is_dead):
		queue_free()
		return

	# Movimento verso il bersaglio
	var direction = global_position.direction_to(target.global_position)
	global_position += direction * speed * delta
	
	# Aggiorna la rotazione per seguire il bersaglio
	rotation = direction.angle()

	# Controllo impatto (Distanza molto piccola)
	if global_position.distance_to(target.global_position) < 10.0:
		_impact()

func _impact() -> void:
	# Infligge il danno passando per il DefendComponent
	var defend_comp = target.get_node_or_null("DefendComponent")
	if defend_comp != null:
		defend_comp.take_damage(damage, piercing_damage, damage_type)
	else:
		var health_comp = target.get_node_or_null("HealthComponent")
		if health_comp != null and not health_comp.is_dead:
			health_comp.take_damage(damage)
			
	# Instanzia effetti particellari di sangue/esplosione se necessario qui
	
	# Rimuove la freccia dalla scena
	queue_free()
