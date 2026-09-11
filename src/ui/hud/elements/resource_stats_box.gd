extends VBoxContainer
class_name ResourceStatsBox

@onready var portrait: TextureRect = $HBoxContainer/ImageVBoxContainer/Portrait
@onready var progress_bar: ProgressBar = $HBoxContainer/ImageVBoxContainer/ProgressBar
@onready var nome_unita: Label = $HBoxContainer/NameVBoxContainer/NomeUnita
@onready var amount_label: Label = $HBoxContainer2/LabelVBoxContainer/AmountLabel
@onready var amount_value: Label = $HBoxContainer2/ValueVBoxContainer/AmountValue

var resource: ResourceBuilding

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func setup(entity: Node2D) -> void:
	resource = entity as ResourceBuilding
	if resource == null:
		return
	
	# Ora siamo sicuri che il nodo è in scena (perché add_child è stato fatto prima),
	# quindi i nodi @onready esistono e possiamo aggiornare tutto subito!
	portrait.texture = resource.icon
	progress_bar.value = resource.get_health_perc()
	nome_unita.text = resource.name
	
	if resource.resource_type == Globals.ResourceType.GOLD:
		amount_label.text = "Gold Left: "
	elif resource.resource_type == Globals.ResourceType.OIL:
		amount_label.text = "Oil Left: "
		
	update_resources(resource.current_resources, resource.max_resources)
	
	# Connettiamo il signal per gli aggiornamenti futuri delle risorse
	if resource and not resource.resources_changed.is_connected(update_resources):
		resource.resources_changed.connect(update_resources)

# Gestisce solo i dati dinamici (chiamato dal signal della miniera)
func update_resources(new_resources: int, max_resources: int) -> void:
	var building = resource as ResourceBuilding
	if building == null:
		return
	amount_value.text = str(new_resources)

func _on_tree_exited() -> void:
	# Disconnettere i signal quando la UI viene rimossa
	if resource and resource.resources_changed.is_connected(update_resources):
		resource.resources_changed.disconnect(update_resources)
