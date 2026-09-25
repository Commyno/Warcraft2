extends TileMapLayer # Oppure extends Node2D se preferisci tenerlo separato

# Usiamo il font di default del motore
var font = ThemeDB.fallback_font
var font_size = 10 # Adatta questo valore alla grandezza dei tuoi tile (es. 8 o 12)
var show_coordinates: bool = true

func _ready() -> void:
	# Forza il motore a chiamare _draw() all'avvio
	queue_redraw()

func _process(_delta: float) -> void:
	# Tasto rapido per accendere/spegnere le coordinate (utile in gioco)
	if Input.is_action_just_pressed("ui_focus_next"): # Es: tasto TAB
		show_coordinates = not show_coordinates
		queue_redraw() # Richiede un nuovo disegno (o cancella il precedente)

func _draw() -> void:
	if not show_coordinates:
		return
		
	# Recupera tutte le coordinate "usate" sulla mappa (i tile piazzati)
	var cells = get_used_cells()
	
	for cell in cells:
		# map_to_local restituisce esattamente il centro del tile
		var center_pos = map_to_local(cell)
		
		var text = "%d,%d" % [cell.x, cell.y]
		
		# Calcoliamo le dimensioni del testo per centrarlo perfettamente nel tile
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var draw_pos = center_pos - (text_size / 2.0)
		draw_pos.y += text_size.y / 3.0 # Correzione visiva per la baseline del font
		
		# Disegna un bordo nero per leggibilità su qualsiasi terreno
		draw_string_outline(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Color.BLACK)
		
		# Disegna il testo bianco
		draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
