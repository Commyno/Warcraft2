class_name AbilityData
extends Resource

enum TargetType { POINT, UNIT, SELF, CORPSE } # Bersaglio a terra, su unità, su se stessi o cadavere

@export var ability_id: String = ""
@export var ability_name: String = ""
@export var icon: Texture2D
@export var mana_cost: int = 50
@export var range: float = 200.0
@export var cooldown: float = 1.0
@export var target_type: TargetType = TargetType.POINT
@export var effect_scene: PackedScene # Scena proiettile/VFX (es. Fireball.tscn o BlizzardArea.tscn)
