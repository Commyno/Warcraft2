extends PanelContainer

# ==========================================
# ONREADY: GAME WORLD NODES
# ==========================================

# Image and name
@onready var portrait: TextureRect = $MarginContainer/StatsBox/HBoxContainer/ImageVBoxContainer/Portrait
@onready var progress_bar: ProgressBar = $MarginContainer/StatsBox/HBoxContainer/ImageVBoxContainer/ProgressBar
@onready var nome_unita: Label = $MarginContainer/StatsBox/HBoxContainer/NameVBoxContainer/NomeUnita
@onready var livello: Label = $MarginContainer/StatsBox/HBoxContainer/NameVBoxContainer/Livello

# Statistics
@onready var armor_value: Label = $MarginContainer/StatsBox/HBoxContainer2/ValueVBoxContainer/ArmorValue
@onready var damage_value: Label = $MarginContainer/StatsBox/HBoxContainer2/ValueVBoxContainer/DamageValue
@onready var range_value: Label = $MarginContainer/StatsBox/HBoxContainer2/ValueVBoxContainer/RangeValue
@onready var sight_value: Label = $MarginContainer/StatsBox/HBoxContainer2/ValueVBoxContainer/SightValue
@onready var speed_value: Label = $MarginContainer/StatsBox/HBoxContainer2/ValueVBoxContainer/SpeedValue

func _ready() -> void:
	hide() # All'avvio si nasconde da solo
	
	var manager = get_tree().get_first_node_in_group("selection_manager")
	if manager:
		manager.selection_changed.connect(_on_selection_changed)

func _on_selection_changed(selected_objects: Array[Node2D]) -> void:
	# Selezionata esattamente UNA unità? Mi mostro, altrimenti mi nascondo.
	if selected_objects.size() == 1:
		show()
		_update_ui(selected_objects[0])
	else:
		hide()

func _update_ui(entity: Node2D) -> void:
	# Qui aggiornerai i nodi figli (es. salute, nome, icona)

	if entity is BaseUnit:
		# Image and name
		#portrait.texture = 
		progress_bar.value = entity.current_health #/ entity.max_health
		nome_unita.text = entity.unit_name
		livello.text = "Livello " + "1"

		# Statistics
		armor_value.text = str(0)
		damage_value.text = str(0)
		range_value.text = str(0)
		sight_value.text = str(0)
		speed_value.text = str(0)

	if entity is BaseBuilding:
		# Image and name
		#portrait.texture = 
		progress_bar.value = entity.current_health #/ entity.max_health
		nome_unita.text = entity.building_name
		livello.text = "Livello " + "1"

		# Statistics
		armor_value.text = str(0)
		damage_value.text = str(0)
		range_value.text = str(0)
		sight_value.text = str(0)
		speed_value.text = str(0)
