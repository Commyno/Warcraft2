class_name ResourceBox
extends VBoxContainer

# ResourceInfo
@onready var portrait: TextureRect = $ResourceInfo/ImageVBoxContainer/Portrait
@onready var health_progress_bar: ProgressBar = $ResourceInfo/ImageVBoxContainer/HealthProgressBar
@onready var health_label: Label = $ResourceInfo/ImageVBoxContainer/HealthLabel

@onready var name_label: Label = $ResourceInfo/NameVBoxContainer/NameLabel
@onready var livello: Label = $ResourceInfo/NameVBoxContainer/Livello

# ResourceStats
@onready var amount_label: Label = $ResourceStats/LabelVBoxContainer/AmountLabel
@onready var amount_value: Label = $ResourceStats/ValueVBoxContainer/AmountValue

var resource: ResourceBuilding

func setup(entity: Node2D) -> void:
	resource = entity as ResourceBuilding
	if resource == null:
		return
	
	if resource.resource_type == Globals.ResourceType.GOLD:
		amount_label.text = "Gold Left: "
	elif resource.resource_type == Globals.ResourceType.OIL:
		amount_label.text = "Oil Left: "
		
	update()
	
	# Connettiamo il signal per gli aggiornamenti futuri delle risorse
	if resource and not resource.resources_changed.is_connected(on_resources_changed):
		resource.resources_changed.connect(on_resources_changed)

func _on_tree_exited() -> void:
	# Disconnettere i signal quando la UI viene rimossa
	if resource and resource.resources_changed.is_connected(on_resources_changed):
		resource.resources_changed.disconnect(on_resources_changed)

func on_resources_changed(new_resources: int, max_resources: int) -> void:
	update()

func on_data_changed() -> void:
	update()

func update() -> void:
	portrait.texture = resource.icon
	health_progress_bar.value = resource.get_health_perc()
	health_label.text = str(resource.current_health) + "/" + str(resource.max_health)
	name_label.text = resource.entity_name

	amount_value.text = str(resource.current_resources)
