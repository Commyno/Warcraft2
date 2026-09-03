extends Node

var players: Array[Player] = []
var players_by_id: Dictionary = {}
var local_player: Player = null

## Crea le istanze Player da MatchData. 'parent' è il nodo della scena di gioco
## sotto cui vivranno (così muoiono con la partita, non restano appesi all'autoload).
func create_players_from_match(parent: Node) -> void:
	clear()
	if MatchData.participants_setup.is_empty():
		push_error("Nessun giocatore in MatchData!")
		return

	for player_id in MatchData.participants_setup.keys():
		var config: Dictionary = MatchData.participants_setup[player_id]
		var p := Player.new()
		p.name = "Player_" + str(player_id)
		parent.add_child(p)
		p.setup(player_id, Vector2i.ZERO, config)

		players.append(p)
		players_by_id[player_id] = p
		if config.get("type", "") == "Human":
			local_player = p
		print("✅ Registrato Player: ", p.name, " (ID: ", player_id, ")")

func clear() -> void:
	players.clear()
	players_by_id.clear()
	local_player = null

func get_local_player() -> Player:
	return local_player

func get_player(id: int) -> Player:
	return players_by_id.get(id, null)

func unregister_player(p: Player) -> void:
	players.erase(p)
	players_by_id.erase(p.player_id)
	if local_player == p:
		local_player = null
