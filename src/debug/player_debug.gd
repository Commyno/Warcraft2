extends Control

# ==========================================
# CONSTANTS (SCENE UIDs)
# ==========================================
const PLAYER_DETAILS_SCENE: PackedScene = preload("uid://dii1aas0smovk")

@onready var v_box_container: VBoxContainer = $MarginContainer/VBoxContainer/VBoxContainer

func update(player_list: Array) -> void:

# 1. SVUOTIAMO IL CONTENITORE
	# Distruggiamo tutti i figli precedenti per evitare duplicati
	# quando premiamo il tasto di debug più volte.
	for child in v_box_container.get_children():
		child.queue_free()

# 2. CICLIAMO SU TUTTI I GIOCATORI
	for player in player_list:
		# Istanziamo la scena a partire dal nostro preload
		var details = PLAYER_DETAILS_SCENE.instantiate()
		
		# Aggiungiamo il nodo all'albero visivo
		v_box_container.add_child(details)
		
		# 3. AGGIORNIAMO I DATI
		# Ora chiamiamo la funzione "update" che abbiamo scritto nel 
		# passaggio precedente all'interno dello script della riga!
		details.update(player)
			
