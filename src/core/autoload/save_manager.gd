extends Node

# La cartella dove metteremo tutti i salvataggi
const SAVES_DIR = "user://saves/"

func _ready() -> void:
	# Controlla se la cartella esiste. Se è la prima volta che il giocatore avvia, la crea.
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_absolute(SAVES_DIR)

# --- SALVATAGGIO DINAMICO ---
func save_game(save_name: String) -> void:
	# Costruiamo il percorso: "user://saves/MiaPartitaWarcraft.json"
	var path = SAVES_DIR + save_name + ".json"
	
	var save_data: Dictionary = {
		# ... qui raccogli i tuoi dati come abbiamo visto prima ...
		"match_info": {"map": "Lordaeron"}
	}
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("Partita salvata come: ", save_name)
	else:
		push_error("Errore durante il salvataggio.")

# --- CARICAMENTO DINAMICO ---
func load_game(save_name: String) -> void:
	var path = SAVES_DIR + save_name + ".json"
	
	if not FileAccess.file_exists(path):
		push_warning("Il salvataggio specificato non esiste.")
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error == OK:
		var loaded_data = json.data
		print("Dati caricati da: ", save_name)
		# ... ripristina il gioco ...

func delete_file(save_name: String) -> void:
	pass

# Restituisce un Array di stringhe con i nomi di tutti i salvataggi
func get_all_saves() -> Array[String]:
	var saves_list: Array[String] = []

	# 1. Controlliamo se la cartella esiste. Se non esiste, la creiamo e ci fermiamo 
	# (ovviamente sarà vuota, quindi non c'è nulla da caricare)
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_absolute(SAVES_DIR)
		return []
	
	# Apriamo la cartella dei salvataggi
	var dir = DirAccess.open(SAVES_DIR)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		# Scorriamo tutti i file nella cartella
		while file_name != "":
			# Se non è una cartella e finisce per .json
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				# Rimuoviamo l'estensione ".json" per mostrare solo il nome pulito all'utente
				var clean_name = file_name.trim_suffix(".json")
				saves_list.append(clean_name)
			
			file_name = dir.get_next()
			
	return saves_list
