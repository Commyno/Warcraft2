extends Node

# --- IMPOSTAZIONI DEL GIOCATORE ---
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var window_mode: int = 0
var edge_scroll_enabled: bool = true
var edge_scroll_speed: float = 450.0

# --- STATISTICHE GLOBALI ---
var total_matches_played: int = 0
var total_victories: int = 0
var favorite_faction: String = "Umani"

# Questa funzione verrà chiamata all'avvio dal SceneHandler per caricare i settaggi
func load_player_profile() -> void:
	# Qui potrai leggere un file "settings.json" e popolare le variabili sopra
	pass
