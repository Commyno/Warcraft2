extends VBoxContainer

@onready var gold_resource: HBoxContainer = $GoldResource
@onready var wood_resource: HBoxContainer = $WoodResource
@onready var oil_resource: HBoxContainer = $OilResource
@onready var gold_amount_value: Label = $GoldResource/AmountValue
@onready var wood_amount_value: Label = $WoodResource/AmountValue
@onready var oil_amount_value: Label = $OilResource/AmountValue

var building: BaseBuilding

func setup(entity: Node2D) -> void:
	building = entity as BaseBuilding
	if building == null:
		return
	
	if building.accepts_gold:
		gold_resource.show()
	else:
		gold_resource.hide()

	if building.accepts_wood:
		wood_resource.show()
	else:
		wood_resource.hide()

	if building.accepts_oil:
		oil_resource.show()
	else:
		oil_resource.hide()
	
	update()
	
	# Connettiamo il signal per gli aggiornamenti futuri delle risorse
	if not building.upgrade_completed.is_connected(on_upgrade_completed):
		building.upgrade_completed.connect(on_upgrade_completed)
	if not building.player_owner == null:
		if not building.player_owner.modifier_changed.is_connected(on_modifier_changed):
			building.player_owner.modifier_changed.connect(on_modifier_changed)
			

func on_upgrade_completed(new_building_data) -> void:
	update()

func on_modifier_changed(resource: Globals.ResourceType) -> void:
	update()

func update() -> void:
	if building.player_owner == null:
		return
	
	gold_amount_value.text = str(building.player_owner.gold_gather_base)
	if building.player_owner.get_gold_bonus() > 0:
		gold_amount_value.text += " + " + str(building.player_owner.get_gold_bonus())

	wood_amount_value.text = str(building.player_owner.wood_gather_base)
	if building.player_owner.get_wood_bonus() > 0:
		wood_amount_value.text += " + " + str(building.player_owner.get_wood_bonus())

	oil_amount_value.text = str(building.player_owner.oil_gather_base)
	if building.player_owner.get_oil_bonus() > 0:
		oil_amount_value.text += " + " + str(building.player_owner.get_oil_bonus())

func _on_tree_exited() -> void:
	# Disconnettere i signal quando la UI viene rimossa
	if building and building.upgrade_completed.is_connected(on_upgrade_completed):
		building.upgrade_completed.disconnect(on_upgrade_completed)
	if not building.player_owner == null:
		if not building.player_owner.modifier_changed.is_connected(on_modifier_changed):
			building.player_owner.modifier_changed.disconnect(on_modifier_changed)
