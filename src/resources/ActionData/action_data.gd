class_name ActionData
extends Resource

enum ActionType {
	IMMEDIATE,          # Esegue subito (Stop, Stand Ground, Cancel, Open Submenu)
	TARGET_POSITION,    # Richiede un clic su punto della mappa (Move, Patrol)
	TARGET_ENTITY,      # Richiede un clic su unità/edificio nemico o alleato (Attack, Repair)
	TARGET_GRID_TILE    # Richiede selezione su cella libera della griglia (Piazzamento Edificio)
}

# Definisce quante unità eseguono l'ordine quando ce n'è più di una selezionata
enum ExecutionTargetMode {
	ALL, # Tutte le unità selezionate eseguono l'azione (Move, Attack, Gather, Repair)
	ANY  # Solo la prima unità selezionata esegue l'azione (Place Building, abilità singole)
}

@export var id: String = "move"
@export var title: String = "Muoversi"
@export_multiline var description: String = ""   # ← tooltip, universale
@export var icon: Texture2D
@export var action_type: ActionType = ActionType.IMMEDIATE
@export var target_mode: ExecutionTargetMode = ExecutionTargetMode.ALL
@export var shortcut_key: Key = KEY_M
@export var targeting_cursor: Texture2D
@export var cursor_hotspot: Vector2 = Vector2(16, 16)

func accepts(_entity, _tile, _pos, _units, _player) -> bool:
	return false

# Verifica se il pulsante deve essere attivo o disabilitato (es. risorse insufficienti)
func can_execute(_source_entities: Array, player: Player) -> bool:
	return true

# Esecuzione effettiva dell'ordine
func execute(source_entities: Array, target_data = null) -> void:
	if source_entities.is_empty():
		return

	# Filtra l'array in base all'enum
	var units_to_run: Array = []
	match target_mode:
		ExecutionTargetMode.ALL:
			units_to_run = source_entities
		ExecutionTargetMode.ANY:
			units_to_run = [source_entities[0]]

	# Esegue la logica concreta
	_execute_action(units_to_run, target_data)

# Metodo virtuale da sovrascrivere nelle sottoclassi
func _execute_action(_source_entities: Array, _target_data = null) -> void:
	pass

## Esecuzione di un'azione di pura INTERFACCIA (aprire submenu, tornare indietro).
## Riceve la griglia come contesto. Le azioni di gioco NON la sovrascrivono.
func execute_ui(_grid) -> void:
	pass

## Distingue i due mondi: le azioni di UI ritornano true.
## Il pulsante usa questo per decidere quale metodo chiamare.
func is_ui_action() -> bool:
	return false

func has_cost() -> bool:
	return false

# Stringa dei costi già formattata, pronta per il tooltip.
func get_cost_string() -> String:
	return ""
