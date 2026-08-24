extends Control

signal dismiss

# Trascina qui la scena 'save_slot_button.tscn' dall'Inspector
@export var save_slot_packed: PackedScene 

# Otteniamo il riferimento al VBoxContainer
@onready var saves_list: ItemList = $VBoxContainer/MarginContainer/SavesList

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_populate_saves_list()

func _populate_saves_list() -> void:
	# 1. Svuotiamo la lista per evitare di duplicare le voci 
	# se il giocatore apre il menu più volte
	saves_list.clear()
	
	# 2. Ottieni la lista dei file dal tuo Autoload SaveManager
	var saves = SaveManager.get_all_saves()
	saves.append("Prova 01")
	saves.append("Prova 02")
	saves.append("Prova 03")

	# 3. Cicla attraverso i nomi dei salvataggi
	for save_name in saves:
		# Rimuoviamo l'estensione ".json" per mostrare solo il nome pulito all'utente
		var clean_name = save_name.trim_suffix(".json")
		
		# 1. Usiamo add_item() invece di append() se saves_list è un nodo ItemList
		var item_index = saves_list.add_item(clean_name)
		
		# 2. Salviamo il nome completo con .json nel "dietro le quinte" della riga
		saves_list.set_item_metadata(item_index, save_name)
	
# Riceve come parametro il nome del salvataggio grazie al .bind()
func _on_save_slot_pressed(selected_save_name: String) -> void:
	print("L'utente ha selezionato il salvataggio: ", selected_save_name)
	
	# Qui potrai aggiungere la logica per caricare la partita, ad esempio:
	SaveManager.load_game(selected_save_name)


func _on_back_button_pressed() -> void:
	dismiss.emit()


func _on_delete_button_pressed() -> void:
	#1. Verifico se sono presenti item selezionati
	var items = saves_list.get_selected_items()
	if items.is_empty():
		return
		
	#2. Se sono presenti, mi prendo il primo file
	var index = items[0]
	var file_da_eliminare = saves_list.get_item_metadata(index)
	
	#3 Rimuovo il salvataggio
	SaveManager.delete_file(file_da_eliminare)

	#4 Lo rimuovo dalla lista
	saves_list.remove_item(index)

	pass # Replace with function body.


func _on_save_list_item_activated(index: int) -> void:
# Recuperiamo il nome pulito solo per stamparlo a schermo o nella UI
	var display_name = saves_list.get_item_text(index)
	print("Hai selezionato: ", display_name)
	pass # Replace with function body.
