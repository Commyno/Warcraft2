@tool
extends Node2D

@export_category("Configurazione Esportazione")
@export var target_resource: MapData 
@export var map_width: int = 64
@export var map_height: int = 64

@export_category("Nodi della Mappa")
# Creiamo due "prese" dove collegheremo i tuoi TileMapLayer dall'Inspector
@export var ground_layer: TileMapLayer
@export var forest_layer: TileMapLayer

@export_category("Azione")
@export var salva_dati_su_file: bool = false:
	set(value):
		if value == true:
			_bake_map()
			salva_dati_su_file = false 

func _bake_map() -> void:
	if target_resource == null:
		push_error("ATTENZIONE: Trascina il file .tres in 'Target Resource'!")
		return
	if ground_layer == null or forest_layer == null:
		push_error("ATTENZIONE: Assegna i livelli Ground e Forest nell'Inspector!")
		return
		
	print("Inizio esportazione mappa...")
	
	# 1. Assegna esplicitamente le dimensioni
	target_resource.size = Vector2i(map_width, map_height)
	
	# 2. Cattura il TileSet
	if ground_layer.tile_set != null:
		target_resource.map_tileset = ground_layer.tile_set
	
	# 3. Costruzione griglie
	var nuova_griglia_terreno: Array[Vector2i] = []
	var nuova_griglia_foresta: Array[int] = []
	
	for y in range(map_height):
		for x in range(map_width):
			var cell_pos = Vector2i(x, y)
			
			var source_id = ground_layer.get_cell_source_id(cell_pos)
			if source_id != -1:
				var atlas_coords = ground_layer.get_cell_atlas_coords(cell_pos)
				nuova_griglia_terreno.append(atlas_coords)
			else:
				nuova_griglia_terreno.append(Vector2i(-1, -1))
			
			var forest_id = forest_layer.get_cell_source_id(cell_pos)
			if forest_id != -1:
				nuova_griglia_foresta.append(100)
			else:
				nuova_griglia_foresta.append(0)
			
	target_resource.ground_tile_grid = nuova_griglia_terreno
	target_resource.forest_grid = nuova_griglia_foresta
	
	# Segnala a Godot che la risorsa è stata modificata internamente
	target_resource.emit_changed()
	
	# Salva su disco
	var save_err = ResourceSaver.save(target_resource, target_resource.resource_path)
	if save_err == OK:
		print("✅ Mappa salvata con successo con dimensioni: ", target_resource.size)
	else:
		push_error("Errore durante il salvataggio della risorsa: ", save_err)
