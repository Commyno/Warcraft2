class_name Statistics_grid
extends VBoxContainer

#Signals

#Enum

#Const

#Export

#var public

#var _private

@onready var units_progress_bar: ProgressBar = $"HBoxContainer/Units/ProgressBar"
@onready var buildings_progress_bar: ProgressBar = $"HBoxContainer/Buildings/ProgressBar"
@onready var gold_progress_bar: ProgressBar = $"HBoxContainer/Gold/ProgressBar"
@onready var lumber_progress_bar: ProgressBar = $"HBoxContainer/Lumber/ProgressBar"
@onready var oil_progress_bar: ProgressBar = $"HBoxContainer/Oil/ProgressBar"
@onready var kills_progress_bar: ProgressBar = $"HBoxContainer/Kills/ProgressBar"
@onready var razings_progress_bar: ProgressBar = $"HBoxContainer/Razings/ProgressBar"
@onready var faction_player: Label = $FactionPlayer

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#public method
func setup(player: Player, global_stats: Player) -> void:

	_update_text_visibility(player.is_human)

	if global_stats.total_units_trained > 0:
		units_progress_bar.value = (player.total_units_trained / global_stats.total_units_trained)
	if global_stats.total_buildings_built > 0:
		buildings_progress_bar.value = (player.total_buildings_built / global_stats.total_buildings_built)
	if global_stats.gold_counts > 0:
		gold_progress_bar.value = (player.gold_counts / global_stats.gold_counts)
	if global_stats.lumber_counts > 0:
		lumber_progress_bar.value = (player.lumber_counts / global_stats.lumber_counts)
	if global_stats.oil_counts > 0:
		oil_progress_bar.value = (player.oil_counts / global_stats.oil_counts)
	if global_stats.total_units_killed > 0:
		kills_progress_bar.value = (player.total_units_killed / global_stats.total_units_killed)
	if global_stats.total_buildings_destroyed > 0:
		razings_progress_bar.value = (player.total_buildings_destroyed / global_stats.total_buildings_destroyed)
	
	faction_player.text = player.name
	if player.is_human:
		faction_player.text += " - You"
		

#_private method
func _update_text_visibility(show: bool) -> void:
	if not is_node_ready():
		return	
	if show:
		$HBoxContainer/Units/Label.show()
		$HBoxContainer/Buildings/Label.show()
		$HBoxContainer/Gold/Label.show()
		$HBoxContainer/Lumber/Label.show()
		$HBoxContainer/Oil/Label.show()
		$HBoxContainer/Kills/Label.show()
		$HBoxContainer/Razings/Label.show()
	else:
		$HBoxContainer/Units/Label.hide()
		$HBoxContainer/Buildings/Label.hide()
		$HBoxContainer/Gold/Label.hide()
		$HBoxContainer/Lumber/Label.hide()
		$HBoxContainer/Oil/Label.hide()
		$HBoxContainer/Kills/Label.hide()
		$HBoxContainer/Razings/Label.hide()
