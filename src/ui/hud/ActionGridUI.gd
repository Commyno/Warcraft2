class_name ActionGridUI
extends Control

@export var grid_container: GridContainer
@export var selection_manager: SelectionManager
const ACTION_BUTTON_SCENE = preload("res://src/ui/hud/action_button.tscn")

func _ready() -> void:
	if selection_manager:
		# Collega il segnale emesso dal manager alla funzione di aggiornamento della griglia
		selection_manager.selection_changed.connect(update_action_grid)

func update_action_grid(selected_objects: Array) -> void:
	# 1. Pulisce la griglia dai vecchi pulsanti
	for child in grid_container.get_children():
		child.queue_free()
		
	if selected_objects.is_empty():
		return

	var first_selected = selected_objects[0]
	var actions_to_show: Array[UnitAction] = []
	
	# 2. Recupera le azioni a seconda che sia un'unità o un edificio
	if first_selected is BaseUnit:
		actions_to_show = (first_selected as BaseUnit).available_actions
	elif first_selected is BaseBuilding:
		# Se in futuro aggiungi azioni agli edifici (es. Addestra Soldato, Rally Point)
		if "available_actions" in first_selected:
			actions_to_show = first_selected.available_actions

	# 3. Popola la griglia
	for action in actions_to_show:
		var btn_instance = ACTION_BUTTON_SCENE.instantiate() as ActionButton
		grid_container.add_child(btn_instance)
		btn_instance.setup(action)
		btn_instance.pressed.connect(_on_action_clicked.bind(action, selected_objects))

func _on_action_clicked(action: UnitAction, selected_objects: Array) -> void:
	print("Azione eseguita: ", action.id, " su ", selected_objects.size(), " elementi selezionati.")
	# Qui collegheremo l'esecuzione (es. modalita' posizionamento cantiere o ordine di movimento)
	
#	match action.action_type:
#		UnitAction.ActionType.IMMEDIATE:
#			# Es. "STOP": Esegue subito l'ordine su tutte le unità
#			for obj in selected_objects:
#				if obj.has_method("stop"): obj.stop()
#				
#		UnitAction.ActionType.TARGET_POSITION:
#			# Es. "MUOVI" o "ATTACCA": Attiva il cursore di mira sul terreno
#			CommandManager.set_active_command(action, selected_objects)
#			
#		UnitAction.ActionType.SUB_MENU:
#			# Es. "COSTRUISCI": Apre la griglia secondaria degli edifici edificabili!
#			_show_build_sub_menu(action)
