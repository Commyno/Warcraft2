extends MarginContainer
class_name SelectedEntityIcon

@onready var texture: TextureRect = $VBoxContainer/TextureRect
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar

var entity: Node2D = null
var health_component : HealthComponent = null

func setup(_entity: Node2D) -> void:
	entity = _entity

	# Info
	var selectable_component : SelectableComponent = entity.get_node_or_null("SelectableComponent")
	if selectable_component:
		texture.texture = selectable_component.icon
		texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH

	# Health
	health_component = entity.get_node_or_null("HealthComponent")
	if health_component:
		progress_bar.value = health_component.get_health_percentage()
		if not health_component.health_changed.is_connected(on_health_changed):
			health_component.health_changed.is_connected(on_health_changed)

func _exit_tree():
	if health_component:
		if health_component.health_changed.is_connected(on_health_changed):
			health_component.health_changed.disconnect(on_health_changed)

func on_health_changed(new_health: float, max_health: float) -> void:
	progress_bar.value = new_health / max_health
		
