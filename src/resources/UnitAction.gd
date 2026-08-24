class_name UnitAction
extends Resource

enum ActionType { IMMEDIATE, TARGET_POSITION, TARGET_ENTITY, SUB_MENU }

@export var id: String = "move"
@export var title: String = "Muoversi"
@export var icon: Texture2D
@export var action_type: ActionType = ActionType.TARGET_POSITION
@export var shortcut_key: Key = KEY_M

# Metodo eseguito quando l'azione scatta
func execute(source_units: Array[BaseUnit], target_data = null) -> void:
	pass
