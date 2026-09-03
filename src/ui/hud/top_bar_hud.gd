class_name TopBarHUD
extends PanelContainer

@onready var gold_label: Label = $HBoxContainer/GoldBox/GoldLabel
@onready var lumber_label: Label = $HBoxContainer/WoodBox/LumberLabel
@onready var oil_label: Label = $HBoxContainer/OilBox/OilLabel
@onready var food_label: Label = $HBoxContainer/FoodBox/FoodLabel

var current_player: Player

func _ready() -> void:
	# Cerca il giocatore locale nella scena se non ancora agganciato
	if current_player == null:
		_bind_local_player()

func bind_player(player: Player) -> void:
	if current_player != null and current_player.resources_changed.is_connected(_on_resources_changed):
		current_player.resources_changed.disconnect(_on_resources_changed)

	current_player = player
	if current_player != null:
		current_player.resources_changed.connect(_on_resources_changed)
		# Sincronizzazione iniziale
		_on_resources_changed(
			current_player.gold_counts,
			current_player.lumber_counts,
			current_player.oil_counts,
			current_player.food_used,
			current_player.food_max
		)

func _bind_local_player() -> void:
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p is Player and p.is_local_player:
			bind_player(p)
			break

func _on_resources_changed(gold: int, lumber: int, oil: int, food_used: int, food_max: int) -> void:
	if not is_instance_valid(self):
		return

	if is_instance_valid(gold_label):
		gold_label.text = str(gold)

	if is_instance_valid(lumber_label):
		lumber_label.text = str(lumber)

	if is_instance_valid(oil_label):
		oil_label.text = str(oil)

	if is_instance_valid(food_label):
		food_label.text = "%d/%d" % [food_used, food_max]
		
		# Se si è al cap di cibo, evidenzia in rosso come in WC2
		if food_used >= food_max:
			food_label.modulate = Color.RED
		else:
			food_label.modulate = Color.WHITE
