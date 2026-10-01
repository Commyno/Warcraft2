class_name ManaComponent
extends Node

# --- SEGNALI ---
signal mana_changed(new_mana: float, max_mana: float)

# --- ESPOSIZIONE ---
@onready var mana_bar: ProgressBar = $ManaBar

@export var max_mana: float = 100.0
@export var is_mana_regen: bool = false      # Se il mana si rigenera
@export var mana_regen: float = 0.25          # Mana rigenerata al secondo

var mana: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mana = max_mana
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = get_mama_percentage()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_mana_regen:
		if mana < max_mana and mana > 0:
			mana = min(mana + mana_regen * delta, max_mana)

func setup(data: Resource, _start_mana_percentage: float = 0.0) -> void:
	max_mana = data.max_mana
	mana = data.max_mana * _start_mana_percentage
	mana_regen = data.mana_regen
	is_mana_regen = data.mana_regen > 0

func get_mama_percentage() -> float:
	return mana / max_mana

func spend(mana_usage: float) -> void:
	mana -= mana_usage
	
	# Emette il segnale per aggiornare eventuali barre della vita (UI)
	_on_mana_changed()

func restore(mana_restored: float) -> void:
	mana -= mana_restored
	
	# Emette il segnale per aggiornare eventuali barre della vita (UI)
	_on_mana_changed()

func show_mana_bar() -> void:
	if mana_bar:
		mana_bar.show()

func hide_mana_bar() -> void:
	if mana_bar:
		mana_bar.hide()

func _on_mana_changed() -> void:
	if mana_bar:
		mana_bar.value = get_mama_percentage()
	
	mana_changed.emit(mana, max_mana)
