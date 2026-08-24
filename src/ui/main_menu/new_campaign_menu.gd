extends Control

#Signals
signal dismiss
signal new_campaign(origin: String)

#Const
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

#@export
@export_file("*.tres") var orc_campaign_01: String
@export_file("*.tres") var human_campaign_01: String

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_orc_btn_pressed() -> void:
	MatchData.game_mode = Globals.GameType.CAMPAIGN
	MatchData.selected_map_path = orc_campaign_01
	new_campaign.emit("NewCampaignMenu")

func _on_human_btn_pressed() -> void:
	MatchData.game_mode = Globals.GameType.CAMPAIGN
	MatchData.selected_map_path = human_campaign_01
	new_campaign.emit("NewCampaignMenu")

func _on_back_button_pressed() -> void:
	dismiss.emit()
