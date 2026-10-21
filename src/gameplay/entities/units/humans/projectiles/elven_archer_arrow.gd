extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _update_directional_sprite(dir: Vector2) -> void:
	# 1. Gestione del Flip Orizzontale: 
	# Se la freccia va a sinistra (X negativa), flippiamo le sprite nate per destra.
	if dir.x < 0:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false

	# 2. Calcolo dell'angolo in gradi (da -180 a 180)
	var angle_deg = rad_to_deg(dir.angle())
	
	# 3. Selezione dell'animazione tra le 5 disponibili 
	# (0° = Destra, 90° = Basso, -90° = Alto)
	# Nota: Usiamo il valore assoluto o le soglie adatte considerando il flip attivo per la sinistra
	if angle_deg > -67.5 and angle_deg <= -22.5:
		animated_sprite.play("up_right")  # Diagonale alta
	elif angle_deg > -22.5 and angle_deg <= 22.5:
		animated_sprite.play("right")     # Perfettamente orizzontale
	elif angle_deg > 22.5 and angle_deg <= 67.5:
		animated_sprite.play("down_right") # Diagonale bassa
	elif angle_deg > 67.5 and angle_deg <= 112.5:
		animated_sprite.play("down")      # Perfettamente verticale in basso
	else:
		animated_sprite.play("up")        # Perfettamente verticale in alto
