class_name HealthComponent
extends Node2D

# --- SEGNALI ---
signal health_changed(new_health: float, max_health: float)

# --- ESPOSIZIONE ---
@onready var health_bar: ProgressBar = $HealthBar

@export var max_health: float = 100.0
@export var is_health_regen: bool = false      # Se la vita si rigenera
@export var health_regen: float = 0.25          # Vita rigenerata al secondo

var health: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	health = max_health
	if health_bar:
		health_bar.value = get_health_percentage()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_health_regen:
		if health < max_health and health > 0:
			restore(health_regen * delta)

func setup(data: Resource, _start_health_percentage: float = 1.0) -> void:
	max_health = data.max_health
	health = data.max_health * _start_health_percentage
	health_regen = data.health_regen
	is_health_regen = data.health_regen > 0

	if health_bar:
		health_bar.value = get_health_percentage()

func get_health_percentage() -> float:
	return health / max_health

func is_damaged() -> bool:
	return health < max_health

func damage(attack_damage: float) -> void:
	health -= attack_damage
	
	if health <= 0:
		get_parent().die()
	
	# Emette il segnale per aggiornare eventuali barre della vita (UI)
	_on_health_changed()

func set_health(_health: float) -> void:
	if _health > 0 and health > 0: #Altrimenti è morto e non posso aumentare la salute
		health = min(_health, max_health)
		
		# Emette il segnale per aggiornare eventuali barre della vita (UI)
		_on_health_changed()

func restore(health_restored: float) -> void:
	if health < max_health and health > 0:
		health = min(health + health_restored, max_health)
		
		# Emette il segnale per aggiornare eventuali barre della vita (UI)
		_on_health_changed()

func show_health_bar() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if health_bar:
		health_bar.show()

func hide_health_bar() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	if health_bar:
		health_bar.hide()

func _on_health_changed() -> void:
	if health_bar:
		health_bar.value = get_health_percentage()
	_update_health_bar_color()
	health_changed.emit(health, max_health)

func _update_health_bar_color() -> void:
	var p := get_health_percentage()

	if p <= 0.5:
		health_bar.modulate = Color.RED
	elif p <= 0.75:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color.GREEN
