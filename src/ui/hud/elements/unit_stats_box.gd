extends VBoxContainer
class_name UnitStatsBox

@onready var portrait: TextureRect = $HBoxContainer/ImageVBoxContainer/Portrait
@onready var health_progress_bar: ProgressBar = $HBoxContainer/ImageVBoxContainer/HealthProgressBar
@onready var nome_unita: Label = $HBoxContainer/NameVBoxContainer/NomeUnita
@onready var livello: Label = $HBoxContainer/NameVBoxContainer/Livello

@onready var armor_value: Label = $HBoxContainer2/ValueVBoxContainer/ArmorValue
@onready var damage_value: Label = $HBoxContainer2/ValueVBoxContainer/DamageValue
@onready var range_value: Label = $HBoxContainer2/ValueVBoxContainer/RangeValue
@onready var sight_value: Label = $HBoxContainer2/ValueVBoxContainer/SightValue
@onready var speed_value: Label = $HBoxContainer2/ValueVBoxContainer/SpeedValue

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup(entity: Node2D) -> void:
	update(entity)

func update(entity: Node2D) -> void:
		#armor_value.text = str(0)
		#damage_value.text = str(0)
		#range_value.text = str(0)
		#sight_value.text = str(0)
		#speed_value.text = str(0)
	pass
