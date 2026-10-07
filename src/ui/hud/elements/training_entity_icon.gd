extends MarginContainer
class_name TrainingEntityIcon

@onready var texture_rect: TextureRect = $VBoxContainer/TextureRect

var resource: Resource = null

func setup(_resource: Resource) -> void:
	resource = _resource

	# Info
	if resource and "icon" in resource:
		texture_rect.texture = resource.icon
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
