extends MarginContainer

@onready var texture: TextureRect = $VBoxContainer/TextureRect
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup(entity: Node2D) -> void:
	if entity is BaseUnit:
		texture.texture = entity.unit_icon
	else:
		texture.texture = entity.building_icon
	texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	progress_bar.value = entity.current_health
	
