class_name ActionButton
extends TextureButton

@export_group("Riferimenti Grafici")
@export var hotkey_label: Label
@export var action_data: ActionData = null:
	set(value):
		action_data = value          # assegna SEMPRE (anche null)
		if value != null:
			_update_icon(value.icon)

@onready var icon: TextureRect = $Icon
@onready var cooldown_overlay: ProgressBar = $CooldownOverlay

var current_player: Player
var _unit_caster: CasterUnit          # l'unità da cui leggere il cooldown

# --- COOLDOWN ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _should_track_cooldown():
		set_process(false)
		cooldown_overlay.visible = false
		return

	var ability_id: String = action_data.ability_data.ability_id
	var remaining: float = _unit_caster.get_cooldown_remaining(ability_id)

	if remaining > 0.0:
		cooldown_overlay.visible = true
		cooldown_overlay.max_value = action_data.ability_data.cooldown
		cooldown_overlay.value = remaining      # svuotamento (mostra quanto manca)
		disabled = true
	else:
		cooldown_overlay.visible = false
		# fine cooldown: la riattivazione dipende anche da mana/risorse
		update_affordability()

func _should_track_cooldown() -> bool:
	# È un'azione con abilità (ha il campo ability_data) e c'è un caster valido?
	return action_data != null \
		and "ability_data" in action_data \
		and action_data.ability_data != null \
		and is_instance_valid(_unit_caster)

# --- SETUP / CLEAR ----------------------------------------------------------

func setup(data: ActionData, player: Player) -> void:
	action_data = data
	current_player = player
	_unit_caster = _resolve_caster()

	if data == null:
		clear_slot()
		return

	tooltip_text = _build_tooltip(data)
	update_affordability()               # imposta disabled/modulate correttamente

	if hotkey_label and data.shortcut_key != KEY_NONE:
		hotkey_label.text = OS.get_keycode_string(data.shortcut_key)

	set_process(_should_track_cooldown())

func clear_slot() -> void:
	action_data = null
	icon.texture = null
	tooltip_text = ""
	disabled = true
	modulate = Color.WHITE
	cooldown_overlay.visible = false
	set_process(false)
	if hotkey_label:
		hotkey_label.text = ""

func _update_icon(texture: Texture) -> void:
	if icon:
		icon.texture = texture
		var atlas := icon.texture as AtlasTexture
		if atlas:
			atlas.margin = Rect2(2, 2, 4, 4)

# --- PRESSIONE --------------------------------------------------------------

func _pressed() -> void:
	if action_data == null:
		return

	# Ramo 1: azioni di INTERFACCIA (submenu, cancel)
	if action_data.is_ui_action():
		action_data.execute_ui(_get_action_grid())
		return

	# Ramo 2: azioni di GIOCO
	var selection_manager := _get_selection_manager()
	if selection_manager == null:
		push_error("SelectionManager non trovato nel gruppo 'selection_manager'!")
		return

	var selected_units: Array = selection_manager.currently_selected

	if not action_data.can_execute(selected_units, current_player):
		return

	match action_data.action_type:
		ActionData.ActionType.IMMEDIATE:
			action_data.execute(selected_units)
			# se l'azione ha appena avviato un cooldown, riattiva il tracking
			set_process(_should_track_cooldown())

		ActionData.ActionType.TARGET_POSITION, \
		ActionData.ActionType.TARGET_ENTITY, \
		ActionData.ActionType.TARGET_GRID_TILE:
			_begin_targeting(selected_units)

## Delega al gestore di targeting: entra in "attesa del secondo click".
func _begin_targeting(selected_units: Array) -> void:
	var tm := _get_targeting_manager()
	if tm == null:
		push_error("TargetingManager non trovato nel gruppo 'targeting_manager'!")
		return
	# Il manager risolverà il click nel tipo giusto (Vector2 / Node2D / Vector2i)
	# secondo action_data.action_type, poi chiamerà action_data.execute(units, target).
	tm.begin_targeting(action_data, selected_units, current_player)

# --- AFFORDABILITÀ ----------------------------------------------------------

func update_affordability() -> void:
	if action_data == null:
		return
	# le azioni di UI non hanno costi/requisiti: sempre attive
	if action_data.is_ui_action():
		disabled = false
		modulate = Color.WHITE
		return

	var units: Array = []
	var sm := _get_selection_manager()
	if sm != null:
		units = sm.currently_selected

	var can: bool = action_data.can_execute(units, current_player)
	disabled = not can
	modulate = Color.WHITE if can else Color(0.4, 0.4, 0.4, 1.0)

# --- TOOLTIP ----------------------------------------------------------------

func _build_tooltip(data: ActionData) -> String:
	var text: String = data.title

	if "description" in data and data.description != "":
		text += "\n" + data.description

	# I costi: le sottoclassi con dati (unit/building/ability) espongono get_cost_string()
	if data.has_method("get_cost_string"):
		var cost_str: String = data.get_cost_string()
		if cost_str != "":
			text += "\n" + cost_str

	if data.shortcut_key != KEY_NONE:
		text += "\n[%s]" % OS.get_keycode_string(data.shortcut_key)

	return text

# --- FEEDBACK VISIVO PRESSIONE ---------------------------------------------

func _on_button_down() -> void:
	var atlas := icon.texture as AtlasTexture
	if atlas:
		atlas.margin = Rect2(3, 3, 4, 4)

func _on_button_up() -> void:
	var atlas := icon.texture as AtlasTexture
	if atlas:
		atlas.margin = Rect2(2, 2, 4, 4)

# --- HELPER DI RICERCA ------------------------------------------------------

func _get_selection_manager() -> Node:
	var m := get_tree().get_nodes_in_group("selection_manager")
	return m[0] if not m.is_empty() else null

func _get_targeting_manager() -> Node:
	var m := get_tree().get_nodes_in_group("targeting_manager")
	return m[0] if not m.is_empty() else null

func _resolve_caster() -> CasterUnit:
	var sm := _get_selection_manager()
	if sm != null and not sm.currently_selected.is_empty():
		return sm.currently_selected[0] as CasterUnit
	return null

## Il pulsante è figlio della griglia: risale l'albero finché la trova.
func _get_action_grid() -> ActionGridMC:
	var node: Node = self
	while node != null:
		if node is ActionGridMC:
			return node
		node = node.get_parent()
	return null
