class_name UpgradeData
extends Resource

@export var upgrade_id: String = "sword_1"      # ID univoco
@export var upgrade_name: String = "Iron Swords"
@export var icon: Texture2D
@export var research_time: float = 40.0

@export_group("Costs")
@export var gold_cost: int = 800
@export var wood_cost: int = 100
@export var oil_cost: int = 0

@export_group("Target & Effect")
@export var affected_stat: String = "melee_damage" # "melee_damage", "armor", "arrow_damage"
@export var bonus_value: int = 2                   # +2 al danno
