extends Node2D

@export var radius: float = 32.0          # Raggio del cerchio
@export var ring_color: Color = Color(0, 1, 0, 0.8) # Verde semi-trasparente
@export var line_thickness: float = 2.0   # Spessore della linea

func _draw() -> void:
	# Disegna un anello verde ai piedi dell'unità
	# Se vuoi un cerchio perfetto usa Vector2(1.0, 1.0)
	# Usiamo uno schiacciamento verticale Vector2(1.0, 0.5) per dare l'effetto prospettiva 2D dell'RTS!
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.8))
	
	draw_arc(
		Vector2.ZERO,       # Centro (relativo al nodo)
		radius,             # Raggio
		0,                  # Angolo iniziale
		TAU,                # Angolo finale (360 gradi)
		32,                 # Dettaglio/Segmenti del cerchio
		ring_color,         # Colore
		line_thickness,     # Spessore della linea
		true                # Antialiasing attivo per bordi morbidi
	)
