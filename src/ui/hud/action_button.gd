class_name ActionButton
extends TextureButton

@export_group("Riferimenti Grafici")
# Se usi il nodo Button nativo, puoi impostare l'icona direttamente su icon.
# Se invece hai un nodo figlio TextureRect o Label per l'hotkey, li colleghi qui:
@export var hotkey_label: Label 
@export var current_action: UnitAction = null:
	set(value):
		if value != null:
			_update_icon(value.icon)
			current_action = value	 

@onready var icon: TextureRect = $Icon

# Funzione principale di inizializzazione
func setup(action: UnitAction) -> void:
	current_action = action
	
	if not action:
		clear_slot()
		return
		
	disabled = false

	# 2. Imposta il Tooltip (titolo dell'azione)
	tooltip_text = action.title

	# 3. Imposta il testo dell'Hotkey se c'è una Label dedicata
	if hotkey_label and action.shortcut_key != KEY_NONE:
		hotkey_label.text = OS.get_keycode_string(action.shortcut_key)
	
	if current_action.id == "none":
		disabled = true

func _update_icon(texture: Texture) -> void:
	if icon:
		icon.texture = texture
		var atlas = icon.texture as AtlasTexture
		if atlas:
			atlas.margin = Rect2(2, 2, 4, 4)

func clear_slot() -> void:
	current_action = null
	icon.texture = null
	tooltip_text = ""
	disabled = true
	if hotkey_label:
		hotkey_label.text = ""

# Gestione della pressione
func _pressed() -> void:
	if current_action:
		# Avvisa i manager o esegui la logica dell'azione
		print("Azione premuta: ", current_action.title)


func _on_button_down() -> void:
	var atlas_texture: AtlasTexture = icon.texture as AtlasTexture
	atlas_texture.margin = Rect2(3, 3, 4, 4)


func _on_button_up() -> void:
	var atlas_texture: AtlasTexture = icon.texture as AtlasTexture
	atlas_texture.margin = Rect2(2, 2, 4, 4)
