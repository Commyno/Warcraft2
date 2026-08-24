class_name SelectableComponent
extends Node2D

# --- PARAMETRI CONFIGURABILI DALL'INSPECTOR ---
@export_group("Informazioni UI")
@export var display_name: String = "Entità"
@export var display_description: String = "Entità"
@export var icon: Texture2D

@export_group("Selezione")
# Collega il nodo SelectionRing dall'Ispettore di Godot 
@export var selection_ring: CanvasItem 

# --- SEGNALI ---
signal selection_changed(is_selected: bool)

#var is_selected: bool = false
var is_selected: bool = false

func select() -> void:
	is_selected = true
	if selection_ring:
		selection_ring.show()
	selection_changed.emit(true)

func deselect() -> void:
	is_selected = false
	if selection_ring:
		selection_ring.hide()
	selection_changed.emit(false)

# Funzione comoda per risalire all'entità principale (BaseUnit o BaseBuilding)
func get_owner_entity() -> Node2D:
	return get_parent() as Node2D
