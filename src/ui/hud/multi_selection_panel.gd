extends PanelContainer

const SELECTED_UNIT_ICON : PackedScene = preload("res://src/ui/hud/elements/selected_unit_icon.tscn")

@onready var grid_container: GridContainer = $GridContainer

func _ready() -> void:
	hide() # All'avvio si nasconde da solo

func update_ui(entities: Array[Node2D]) -> void:

# Convertiamo l'array delle entità selezionate in un Dizionario per ricerche super veloci O(1)
	var new_selection_dict = {}
	for e in entities:
		new_selection_dict[e] = true

	var current_badges = grid_container.get_children()
	var entities_already_in_ui = {}

	# 1. PULIZIA E AGGIORNAMENTO: Rimuovi chi non è più selezionato, aggiorna chi è rimasto
	for badge in current_badges:
		# Recuperiamo l'entità associata a questo badge
		# (Assicurati che lo script del badge abbia 'var entity')
		var badge_entity = badge.entity if "entity" in badge else null
		
		# Se il badge è orfano o l'entità non è più nella nuova selezione, eliminalo
		if badge_entity == null or not new_selection_dict.has(badge_entity):
			badge.queue_free()
		else:
			# L'entità è ancora selezionata! Salviamola così non la ricreiamo
			entities_already_in_ui[badge_entity] = true
			
	# 2. POPOLAMENTO: Aggiungi i badge SOLO per le entità che non sono già nella UI
	for entity in entities:
		if not entities_already_in_ui.has(entity):
			var portrait = SELECTED_UNIT_ICON.instantiate()
			grid_container.add_child(portrait)
			
			if portrait.has_method("setup"):
				portrait.setup(entity)

	## 1. PULIZIA: Elimina tutti i vecchi nodi figli dal GridContainer
	#for child in grid_container.get_children():
		#child.queue_free()
		#
	## 2. POPOLAMENTO: Crea un nuovo elemento per ogni entità selezionata
	#for entity in entities:
		## --- METODO A: Usando una Scena Prefabbricata (Consigliato) ---
		#var hud_scene: PackedScene = ResourceLoader.load(SELECTED_UNIT_ICON) as PackedScene
		#if hud_scene == null:
			#push_error("Could not load selected unit icon scene: " + SELECTED_UNIT_ICON)
			#return
#
		#var portrait = hud_scene.instantiate()
		#grid_container.add_child(portrait)
		#
		## Se il tuo ritratto ha una funzione per aggiornarsi, passagli l'entità
		#if portrait.has_method("setup_portrait"):
			#portrait.setup_portrait(entity)
