extends HBoxContainer
class_name ResourceStatsBox

@onready var amount_label: Label = $LabelVBoxContainer/AmountLabel
@onready var amount_value: Label = $ValueVBoxContainer/AmountValue

var entity: Node2D
var resource_component: ResourceComponent = null

func setup(_entity: Node2D) -> void:
	entity = _entity
	if entity == null:
		return
	
	resource_component = entity.get_node_or_null("ResourceComponent")
	if resource_component == null:
		return
	
	if amount_label:
		if resource_component.resource_type == Globals.ResourceType.GOLD:
			amount_label.text = "Gold Left: "
		elif resource_component.resource_type == Globals.ResourceType.OIL:
			amount_label.text = "Oil Left: "

		# Connettiamo il signal per gli aggiornamenti futuri delle risorse
		if not resource_component.resources_changed.is_connected(on_resources_changed):
			resource_component.resources_changed.connect(on_resources_changed)

func _on_exit_tree() -> void:
	if resource_component:
		if not resource_component.resources_changed.is_connected(on_resources_changed):
			resource_component.resources_changed.connect(on_resources_changed)
	

func on_resources_changed(new_resources: int, max_resources: int) -> void:
	update(new_resources)

func update(value: int) -> void:
	if amount_value:
		amount_value.text = str(value)
