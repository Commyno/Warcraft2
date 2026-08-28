extends VBoxContainer
class_name ResourceStatsBox

@onready var portrait: TextureRect = $HBoxContainer/ImageVBoxContainer/Portrait
@onready var progress_bar: ProgressBar = $HBoxContainer/ImageVBoxContainer/ProgressBar
@onready var nome_unita: Label = $HBoxContainer/NameVBoxContainer/NomeUnita
@onready var amount_label: Label = $HBoxContainer2/LabelVBoxContainer/AmountLabel
@onready var amount_value: Label = $HBoxContainer2/ValueVBoxContainer/AmountValue

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup(entity: Node2D) -> void:
	update(entity)

func update(entity: Node2D) -> void:
	var building = entity as BaseResourceBuilding
	if building == null:
		return
	
	portrait.texture = building.resource_icon
	progress_bar.value = building.get_health_perc()
	nome_unita.text = building.resource_name
	if building.resource_type == Globals.ResourceType.GOLD:
		amount_label.text = "Gold Left: "
	elif building.resource_type == Globals.ResourceType.OIL:
		amount_label.text = "Oil Left: "
	amount_value.text = str(building.current_resources)
