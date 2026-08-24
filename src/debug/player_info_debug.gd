extends HBoxContainer

@onready var player_id: Label = $PlayerID
@onready var human: Label = $Human
@onready var color_rect: ColorRect = $Color
@onready var gold: Label = $Gold
@onready var race: Label = $Race
@onready var spawn_position: Label = $SpawnPosition
@onready var lumber: Label = $Lumber
@onready var oil: Label = $Oil
@onready var units: Label = $Units
@onready var buildings: Label = $Buildings

func update(player: Player) -> void:
	# Controllo di sicurezza per evitare crash se il giocatore non esiste
	if player == null:
		return
		
	# Valorizziamo le label convertendo i dati del player in stringhe
	player_id.text = str(player.player_id) # o player.id a seconda di come lo hai definito
	if player.is_human:
		human.text = "Human"
	else:
		human.text = "IA"
	color_rect.color = player.color
	race.text = player.faction
	
	# Risorse
	gold.text = str(player.gold_counts)
	lumber.text = str(player.lumber_counts)
	oil.text = str(player.oil_counts)
	
	# Posizione (str converte in automatico i Vector2 o Vector3 in testo leggibile, es: "(10, 20)")
	spawn_position.text = str(player.spawn_position)
	
	# Unità e Costruzioni
	# Se sono numeri (contatori):
	units.text = str(player.current_units_count)
	buildings.text = str(player.current_buildings_count)
	
