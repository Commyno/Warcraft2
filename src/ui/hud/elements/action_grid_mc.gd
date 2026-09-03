class_name ActionGridMC
extends MarginContainer

@onready var slots: Array[ActionButton] = [
	$MarginContainer/ActionGrid/Slot0, $MarginContainer/ActionGrid/Slot1, $MarginContainer/ActionGrid/Slot2,
	$MarginContainer/ActionGrid/Slot3, $MarginContainer/ActionGrid/Slot4, $MarginContainer/ActionGrid/Slot5,
	$MarginContainer/ActionGrid/Slot6, $MarginContainer/ActionGrid/Slot7, $MarginContainer/ActionGrid/Slot8
]
@onready var margin_container: MarginContainer = $MarginContainer

var local_player: Player
var current_selected_entity: Node

func _ready() -> void:
	var selection_manager = _get_selection_manager()
	if selection_manager:
		# Collega il segnale emesso dal manager alla funzione di aggiornamento della griglia
		selection_manager.selection_changed.connect(update_action_grid)
	# Inizialmente non visualizza nulla
	update_action_grid([])
	
	# Cerca il giocatore locale nella scena se non ancora agganciato
	if local_player == null:
		_bind_local_player()

func _bind_local_player() -> void:
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p is Player and p.is_local_player:
			bind_player(p)
			break

func bind_player(player: Player) -> void:
	local_player = player
	if local_player != null and not local_player.resources_changed.is_connected(_on_resources_changed):
		local_player.resources_changed.connect(_on_resources_changed)

func update_action_grid(selected_objects: Array) -> void:
	current_selected_entity = null
	if selected_objects.size() > 0:
		current_selected_entity = selected_objects[0]
	 
	_refresh_action_grid()

func _refresh_action_grid() -> void:
	_clear_all_slots()

	margin_container.visible = (current_selected_entity != null)
	
	if current_selected_entity == null:
		return

	# Recupera le azioni disponibili dall'entità selezionata
	var actions: Array[ActionData] = []
	if current_selected_entity.has_method("get_available_actions"):
		actions = current_selected_entity.get_available_actions()
	elif "available_actions" in current_selected_entity:
		actions = current_selected_entity.available_actions

	# Assegna ogni azione allo slot corrispondente (0..8)
	for i in range(mini(actions.size(), slots.size())):
		slots[i].setup(actions[i], local_player)

func _get_selection_manager() -> Node:
	var managers = get_tree().get_nodes_in_group("selection_manager")
	if not managers.is_empty():
		return managers[0]
	return null

func _clear_all_slots() -> void:
	for slot in slots:
		slot.setup(null, local_player)

func _on_resources_changed(_g: int, _w: int, _o: int, _fu: int, _fm: int) -> void:
	for slot in slots:
		if slot.visible:
			slot.update_affordability()
