extends Node

signal scene_ready(instanced_scene: Node)
signal progress_changed(progress)
signal load_finished

var loading_screen: PackedScene = preload("uid://bwrwkgmap2h4y")
var loaded_resource: PackedScene
var scene_path: String
var progress: Array = []
var use_sub_threads: bool = true

func _ready() -> void:
	set_process(false)

func load_scene(_scene_path: String) -> void:
	scene_path = _scene_path
	
	var new_load_screen = loading_screen.instantiate()
	add_child(new_load_screen)
	
	progress_changed.connect(new_load_screen._on_progress_changed)
	load_finished.connect(new_load_screen._on_load_finished)
	
	await new_load_screen.loading_screen_ready
	
	start_load()
	
func start_load() -> void:
	var state = ResourceLoader.load_threaded_request(scene_path, "", use_sub_threads)
	if state == OK:
		set_process (true)

func _process(_delta: float) -> void:
	var load_status = ResourceLoader.load_threaded_get_status(scene_path, progress)
	progress_changed.emit(progress[0])
	
	match load_status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED:
			set_process(false)
			push_error("Caricamento fallito!")
			
		ResourceLoader.THREAD_LOAD_LOADED:
			loaded_resource = ResourceLoader.load_threaded_get(scene_path)
			
			# 1. Istanziamo la scena qui
			var new_scene = loaded_resource.instantiate()
			
			# 2. Consegniamo la scena allo SceneHandler tramite il segnale
			scene_ready.emit(new_scene)
			
			load_finished.emit()
