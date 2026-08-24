extends Node

# --- CONFIGURAZIONE AI ---
@export var ai_team_id: int = 2 # 1 per il Player, 2 per questa AI, ecc.
@export var aggro_distance: float = 300.0 # Distanza di ingaggio (300 pixel)

# L'AI penserà e darà ordini ogni mezzo secondo (0.5), molto meglio per le performance!
@export var think_interval: float = 0.5 
var _think_timer: float = 0.0

func _process(delta: float) -> void:
	# Aggiorniamo il timer
	_think_timer += delta
	
	# Quando il timer supera l'intervallo, l'AI analizza la mappa
	if _think_timer >= think_interval:
		_think_timer = 0.0
		_evaluate_battlefield()

func _evaluate_battlefield() -> void:
	# 1. Recupera tutte le unità presenti in gioco tramite il gruppo
	var all_units = get_tree().get_nodes_in_group("units")
	
	var my_units = []
	var enemy_units = []
	
	# 2. Separa le truppe dell'AI da quelle nemiche
	for unit in all_units:
		if unit.team_id == ai_team_id:
			my_units.append(unit)
		else:
			enemy_units.append(unit)
			
	# Se non ci sono nemici, fermiamo la logica qui
	if enemy_units.is_empty():
		return
		
	# 3. Assegna gli ordini alle truppe dell'AI
	for my_unit in my_units:
		# Opzionale: Se l'unità sta già combattendo o si sta muovendo verso un bersaglio, lasciala fare
		# if my_unit.is_busy(): continue 
		
		# Trova il nemico più vicino a QUESTA specifica unità
		var closest_enemy = _get_closest_unit(my_unit, enemy_units)
		
		if closest_enemy != null:
			# Calcola la distanza
			var distance = my_unit.global_position.distance_to(closest_enemy.global_position)
			
			# Se il nemico è nel raggio di 300 pixel, attaccalo!
			if distance <= aggro_distance:
				# Assicurati di avere una funzione simile nel tuo script dell'unità
				my_unit.attack_target(closest_enemy) 

# --- FUNZIONE DI SUPPORTO ---
# Trova il nodo più vicino in un array rispetto a un punto di origine
func _get_closest_unit(origin_unit: Node2D, targets: Array) -> Node2D:
	var closest_target: Node2D = null
	var min_distance: float = INF # Iniziamo con una distanza infinita
	
	for target in targets:
		# Calcola la distanza tra l'unità dell'AI e il potenziale bersaglio
		var distance = origin_unit.global_position.distance_to(target.global_position)
		
		# Se questa è la distanza più piccola trovata finora, aggiorniamo il bersaglio
		if distance < min_distance:
			min_distance = distance
			closest_target = target
			
	return closest_target
