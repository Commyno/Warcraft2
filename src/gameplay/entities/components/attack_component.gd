class_name AttackComponent
extends Node

# --- SEGNALI ---


# --- ESPOSIZIONE ---
@export var basic_damage: int = 6
@export var piercing_damage: int = 3        # Danno perforante (ignora l'Armor nemica)
@export var damage_dice_sides: int = 4      # Danno finale: basic_damage + randi_range(1, dice_sides)
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.35
@export var damage_type: Globals.DamageType = Globals.DamageType.NORMAL
@export var can_attack_air: bool = false
@export var can_attack_ground: bool = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# TODO: Gestione cooldown
	pass

func setup(_basic_damage: int, \
			_piercing_damage: int, \
			_attack_range: float, \
			_attack_cooldown: float, \
			_damage_type: Globals.DamageType, \
			_can_attack_ground: bool, \
			_can_attack_air: bool) -> void:
	basic_damage = _basic_damage
	piercing_damage = _piercing_damage
	damage_dice_sides = 4
	attack_range = _attack_range
	attack_cooldown =_attack_cooldown
	damage_type = _damage_type
	can_attack_air = _can_attack_air
	can_attack_ground = _can_attack_ground

func is_attack_air() -> bool:
	return can_attack_air

func is_attack_ground() -> bool:
	return can_attack_ground

func attack(attack_damage: float) -> void:
	pass

# Calcolo del danno inflitto (con variazione causale)
#func get_calculated_damage() -> int:
	#var roll = randi_range(1, damage_dice_sides) if damage_dice_sides > 0 else 0
	#return basic_damage + roll
