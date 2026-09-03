class_name TargetEntityActionData
extends ActionData

func _init() -> void:
	action_type = ActionType.TARGET_ENTITY

func execute(source_entities: Array, target_entity = null) -> void:
	if not (target_entity is Node2D):
		push_warning("%s: target_entity non valido" % id)
		return

	if not _is_valid_target(source_entities, target_entity):
		return

	for unit in source_entities:
		_apply_to_unit(unit, target_entity)

## Delega alla logica dell'unità (interact_with esiste già su BaseUnit).
func _apply_to_unit(unit: Node, target: Node2D) -> void:
	if unit.has_method("interact_with"):
		unit.interact_with(target)

## I figli restringono i bersagli ammessi (nemico per Attack, alleato danneggiato per Repair...).
func _is_valid_target(_source_entities: Array, _target: Node2D) -> bool:
	return true
