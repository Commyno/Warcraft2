class_name TargetPositionActionData
extends ActionData



func _init() -> void:
	action_type = ActionType.TARGET_POSITION

func execute(source_entities: Array, target_pos = null) -> void:
	if not (target_pos is Vector2):
		push_warning("%s: target_pos non è un Vector2" % id)
		return

	# Plumbing comune: risolvi una destinazione valida e muovi in formazione.
	var final_destination: Vector2 = GridManager.get_available_destination(target_pos)
	FormationManager.move_units_in_formation(source_entities, final_destination)

	# Hook per i comportamenti specifici (attack-move, patrol...)
	for unit in source_entities:
		_apply_to_unit(unit, final_destination)

## I figli sovrascrivono questo per aggiungere comportamento oltre al movimento.
func _apply_to_unit(_unit: Node, _destination: Vector2) -> void:
	pass
