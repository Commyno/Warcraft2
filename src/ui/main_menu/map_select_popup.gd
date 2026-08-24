extends Control

signal dismiss

@onready var map_list: ItemList = $VBoxContainer/MarginContainer3/MarginContainer/VBoxContainer/MapList
@onready var select_map_detail: RichTextLabel = $VBoxContainer/MarginContainer3/MarginContainer/VBoxContainer/SelectMapDetail

@export_dir var maps_folder: String = "res://maps/custom" 

# Variabile temporanea finché non premiamo OK
var _select_map_data: Dictionary = {}

func _ready() -> void:
	_populate_map_list()

func _populate_map_list() -> void:
	map_list.clear()
	
	# Leggiamo i dati dalla cache di sistema (già precaricati in background!)
	var mappe_disponibili = MatchData.available_maps_cache
	
	for map_data in mappe_disponibili:
		var item_index = map_list.add_item(map_data["name"])
		map_list.set_item_metadata(item_index, map_data)
		
		# Se la mappa è quella già salvata in MatchData, la riselezioniamo
		if not MatchData.selected_map_data.is_empty() and MatchData.selected_map_data["file_path"] == map_data["file_path"]:
			map_list.select(item_index)
			_select_map_data = map_data
			_update_map_details(_select_map_data)

func _on_map_list_item_selected(index: int) -> void:
	_select_map_data = map_list.get_item_metadata(index)
	_update_map_details(_select_map_data)

func _update_map_details(data: Dictionary) -> void:
	var testo_formattato = ""
	testo_formattato += "[font_size=9][b]" + data["name"] + "[/b][/font_size]\n"
	testo_formattato += "[font_size=9][b]Dimensioni:[/b] " + str(data["size"].x) + "x" + str(data["size"].y) + "[/font_size]\n"
	testo_formattato += "[font_size=9][b]Giocatori Max:[/b] " + str(data["max_players"]) + "[/font_size]\n"
	
	select_map_detail.text = testo_formattato

func _on_ok_button_pressed() -> void:
	if _select_map_data.is_empty():
		return

	# Quando premiamo OK confermiamo i dati nell'Autoload globale
	MatchData.selected_map_path = _select_map_data["file_path"]
	MatchData.selected_map_data = _select_map_data
	
	dismiss.emit()

func _on_cancel_button_pressed() -> void:
	dismiss.emit()
