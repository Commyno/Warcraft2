class_name ActionData
extends Resource

enum ActionType {
	IMMEDIATE,          # Esegue subito (Stop, Stand Ground, Cancel, Open Submenu)
	TARGET_POSITION,    # Richiede un clic su punto della mappa (Move, Patrol)
	TARGET_ENTITY,      # Richiede un clic su unità/edificio nemico o alleato (Attack, Repair)
	TARGET_GRID_TILE    # Richiede selezione su cella libera della griglia (Piazzamento Edificio)
}

@export var id: String = "move"
@export var title: String = "Muoversi"
@export_multiline var description: String = ""   # ← tooltip, universale
@export var icon: Texture2D
@export var action_type: ActionType = ActionType.IMMEDIATE
@export var shortcut_key: Key = KEY_M

# Verifica se il pulsante deve essere attivo o disabilitato (es. risorse insufficienti)
func can_execute(_source_entities: Array, player: Player) -> bool:
	return true

# Esecuzione effettiva dell'ordine
func execute(_source_entities: Array, _target_data = null) -> void:
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
