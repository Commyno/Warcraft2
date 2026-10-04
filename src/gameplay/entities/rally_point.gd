class_name RallyPoint
extends Node2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var animation_player = $AnimationPlayer
@onready var particles = $CPUParticles2D

func _ready():
	# Avvia l'animazione di sventolio della bandiera
	animated_sprite.play("idle")
	
	# Attiva le particelle di impatto sul terreno
	if particles:
		particles.emitting = true

# Funzione per far sparire la bandiera con stile quando il punto cambia
func svanisci():
	queue_free()
