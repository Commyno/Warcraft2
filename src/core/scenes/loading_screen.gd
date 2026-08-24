extends CanvasLayer

signal loading_screen_ready

@onready var progress_bar: ProgressBar = $Panel/ProgressBar
@onready var progress_label: Label = $Panel/ProgressBar/ProgressLabel
@export var animation_player: AnimationPlayer

func _ready() -> void:
	animation_player.play("transition") # Forziamo l'avvio anche se ho impostato l'autoplay
	await animation_player.animation_finished
	loading_screen_ready.emit()

func _on_progress_changed(new_value: float) -> void:
	_update_progressbar(new_value)
	pass

func _on_load_finished() -> void:
	animation_player.play_backwards("transition")
	await animation_player.animation_finished
	queue_free()

func _update_progressbar(new_value: float) -> void:
	# new_value è un numero che va da 0.0 a 1.0
	
	# Se usi un nodo ProgressBar:
	if progress_bar:
		# Moltiplichiamo per 100 se la barra ha max_value = 100
		progress_bar.value = new_value * 100 
		
	# Se usi una Label (es. "Caricamento: 45%"):
	if progress_label:
		# Trasformiamo il decimale in percentuale senza la virgola
		progress_label.text = "Caricamento: " + str(int(new_value * 100)) + "%"
