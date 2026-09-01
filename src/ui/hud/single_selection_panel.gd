extends PanelContainer

const UNIT_STATS_BOX = preload("uid://cidjmt5bpauh3")
const BUILDING_STATS_BOX = preload("uid://l83peu7cjsl")
const RESOURCE_STATS_BOX = preload("uid://cuycp45w1u4p4")

# ==========================================
# ONREADY: GAME WORLD NODES
# ==========================================

# Image and name
@onready var portrait: TextureRect = $HBoxContainer/ImageVBoxContainer/Portrait
@onready var progress_bar: ProgressBar = $HBoxContainer/ImageVBoxContainer/ProgressBar
@onready var nome_unita: Label = $HBoxContainer/NameVBoxContainer/NomeUnita
@onready var livello: Label = $HBoxContainer/NameVBoxContainer/Livello

# Statistics
@onready var armor_value: Label = $HBoxContainer2/ValueVBoxContainer/ArmorValue
@onready var damage_value: Label = $HBoxContainer2/ValueVBoxContainer/DamageValue
@onready var range_value: Label = $HBoxContainer2/ValueVBoxContainer/RangeValue
@onready var sight_value: Label = $HBoxContainer2/ValueVBoxContainer/SightValue
@onready var speed_value: Label = $HBoxContainer2/ValueVBoxContainer/SpeedValue

func _ready() -> void:
	hide() # All'avvio si nasconde da solo
	
	var manager = get_tree().get_first_node_in_group("selection_manager")
	if manager:
		manager.selection_changed.connect(_on_selection_changed)

func _on_selection_changed(selected_objects: Array[Node2D]) -> void:
	# Selezionata esattamente UNA unità? Mi mostro, altrimenti mi nascondo.
	if selected_objects.size() == 1:
		# 1. Ripuliamo tutti i figli
		for child in get_children():
			child.queue_free()
			
		var selected_object = selected_objects[0]
		
		# 2. Aggiungiamo il nodo corretto
		if selected_object is BaseUnit:
			# 1. Istanzia la scena (crea l'oggetto in memoria)
			var stats_box = UNIT_STATS_BOX.instantiate()
			
			# 2. Aggiungilo come figlio del nodo corrente
			add_child(stats_box)
			
			# 3. Chiama la funzione setup()
			if stats_box.has_method("setup"):
				stats_box.setup(selected_object)
		elif selected_object is BaseBuilding:
			# 1. Istanzia la scena (crea l'oggetto in memoria)
			var stats_box = BUILDING_STATS_BOX.instantiate()
			
			# 2. Aggiungilo come figlio del nodo corrente
			add_child(stats_box)
			
			# 3. Chiama la funzione setup()
			if stats_box.has_method("setup"):
				stats_box.setup(selected_object)
		elif selected_object is ResourceBuilding:
			# 1. Istanzia la scena (crea l'oggetto in memoria)
			var stats_box = RESOURCE_STATS_BOX.instantiate()
			
			# 2. Aggiungilo come figlio del nodo corrente
			add_child(stats_box)
			
			# 3. Chiama la funzione setup()
			if stats_box.has_method("setup"):
				stats_box.setup(selected_object)
		
		show()
		_update_ui(selected_object)
	else:
		# 1. Ripuliamo tutti i figli
		for child in get_children():
			child.queue_free()
		
		hide()

func _update_ui(entity: Node2D) -> void:
	# Qui aggiornerai i nodi figli (es. salute, nome, icona)

	if entity is BaseUnit:
		var panel = get_child(0) as UnitStatsBox
		if panel and panel.has_method("update"):
			panel.update(entity)
	
	elif entity is BaseBuilding:
		var panel = get_child(0) as BuildingStatsBox
		if panel and panel.has_method("update"):
			panel.update(entity)
	
	elif entity is ResourceBuilding:
		var panel = get_child(0) as ResourceStatsBox
		if panel and panel.has_method("update"):
			panel.update(entity)
