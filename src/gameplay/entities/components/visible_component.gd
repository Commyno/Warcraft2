class_name VisibleComponent
extends Node

enum VisionState {
	# Area has never been visited before.
	UNKNOWN,
	# Area has been visited before, but is currently not.
	KNOWN,
	# Area is revealed right now.
	VISIBLE
}

# --- SEGNALI ---
signal on_visible_change()

# --- ESPOSIZIONE ---


# Client. Whether the local player can see the actor.
var is_visible: bool = true
# Client. Whether the local player has ever seen the actor.
var was_ever_seen_map: Dictionary = {}  # { player (Player) : stato (bool) }
# Server. Whether the actor is hidden due to vision, by player. */
var vision_state: Dictionary = {}  # { player (Player) : vision state (VisionState) }
 
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# TODO: Register for events.
	
	# Set initial state.
	is_visible = (get_parent() as Node2D).visible

func setup() -> void:
	pass

# Server. Whether the actor is visible due to vision for the specified player.
func is_visible_for_player(player: Player) -> bool:

	# Check if we are visible anyway.
	if get_parent().has_meta("player_owner"):
		var owner : Player = get_parent().player_owner
		if get_vision_state_for_player(owner) == VisionState.VISIBLE:
			return true

	# Check if it's a friendly unit.
	return is_same_team_as_local_client()

# Client. Sets the actor and all of its components visible or invisible.
func set_visible(_is_visible: bool) -> void:
	if is_visible != _is_visible:
		is_visible = _is_visible
		
		# Nascondiamo effettivamente il nodo genitore e i suoi figli grafici
		var parent = get_parent()
		if parent is Node2D:
			parent.visible = is_visible
			
		on_visible_change.emit()

func get_vision_state_for_player(player: Player) -> VisionState:
	if vision_state.has(player):
		return vision_state[player] as VisionState # Nessun ciclo for necessario
	return VisionState.UNKNOWN

# Client. Whether the actor is owned by a player that is in the same team as the local player. */
func is_same_team_as_local_client() -> bool:
	var parent = get_parent()
	if "player_owner" in parent and parent.player_owner != null:
		var local_player = PlayerManager.get_local_player()
		return parent.player_owner == local_player
	return false

func check_visibility_state() -> void:
	if is_same_team_as_local_client():
		return # Le nostre truppe sono sempre visibili
		
	var my_cell = GridManager.get_tile_coords(get_parent().global_position)
	var should_be_visible = FogManager.is_cell_visible(my_cell)
	
	set_visible(should_be_visible)
