class_name ProductionBuilding
extends BaseBuilding

# --- COMPONENTS ---
@onready var defend_component: DefendComponent = get_node_or_null("DefendComponent")

# Signals
#signal progress_updated(progress_percent: float)

func _ready() -> void:
	super()
	add_to_group("interactable")

func setup(data: Resource) -> void:
	super(data)

	# Components
	if defend_component:
		defend_component.setup(data)

# --- METODI DI SELEZIONE ---

func select() -> void:
	super()
	if get_node_or_null("RallypointComponent"):
		get_node("RallypointComponent").show_rally_marker()

func deselect() -> void:
	super()
	if get_node_or_null("RallypointComponent"):
		get_node("RallypointComponent").hide_rally_marker()
