class_name HeroUnit
extends BaseUnit

# --- COSTANTI ---
# L'indice rappresenta il livello, il valore è l'exp richiesta per RAGGIUNGERE il livello successivo.
# Es: Per passare dal livello 1 al 2 servono 100 exp. (Lo 0 all'inizio serve ad allineare l'indice al livello)
const LEVEL_THRESHOLDS: Array[int] = [0, 100, 250, 500, 1000, 2500, 5000]

# --- VARIABILI GLOBALI ---
var level: int = 1
var experience: int = 0

# --- SEGNALI ---
# Questi permetteranno alla tua UI di aggiornarsi solo quando serve
signal experience_gained(current_exp: int, required_exp: int)
signal leveled_up(new_level: int)

# --- FUNZIONI PRINCIPALI ---

func add_experience(amount: int) -> void:
	experience += amount
	_check_level_up()
	
	# Emettiamo il segnale per dire all'HUD (o altri sistemi) che l'exp è cambiata
	experience_gained.emit(experience, get_required_exp())

func _check_level_up() -> void:
	# Un ciclo while nel caso in cui il giocatore ottenga così tanta exp da saltare più livelli insieme
	while level < LEVEL_THRESHOLDS.size() and experience >= LEVEL_THRESHOLDS[level]:
		# Sottrai l'esperienza usata se vuoi che l'exp riparta da zero, 
		# altrimenti rimuovi la riga sotto per un'esperienza accumulata globale
		experience -= LEVEL_THRESHOLDS[level] 
		
		level += 1
		leveled_up.emit(level)

# Funzione di supporto per ottenere l'esperienza richiesta al livello attuale
func get_required_exp() -> int:
	if level < LEVEL_THRESHOLDS.size():
		return LEVEL_THRESHOLDS[level]
	return 0 # Indica che abbiamo raggiunto il Level Cap
