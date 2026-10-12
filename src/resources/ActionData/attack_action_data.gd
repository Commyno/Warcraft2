class_name AttackActionData
extends TargetEntityActionData

func _init() -> void:
	super()
	id = "attack"
	title = "Attacca"
	target_mode = ExecutionTargetMode.ALL # Tutti i lavoratori selezionati vanno a raccogliere

func _is_valid_target(source_entities: Array, target: Node2D) -> bool:
	# 1. Controllo di sicurezza sulle entità sorgente
	if source_entities.is_empty():
		return false
		
	# 2. FILTRO COMPONENTE: Il bersaglio può difendersi/subire danni?
	# Usa has_node se il componente è un nodo figlio con quel nome esatto, 
	# oppure 'if target.defend_component == null' se usi le variabili esportate
	if not target.has_node("DefendComponent"): 
		return false
		
	# 3. Controllo vitalità: evitiamo di attaccare cadaveri o macerie
	if "is_dead" in target and target.is_dead:
		return false

	# 4. Controllo identità del bersaglio
	if not "player_id" in target:
		return false
		
	# Se è un'entità neutra pura (es. un elemento di mappa distruttibile ma senza proprietario)
	if not "player_owner" in target or target.player_owner == null:
		return false

	# 5. Risoluzione Fazione: È un nemico?
	var attacker_id: int = source_entities[0].player_id
	
	# Restituisce true solo se i player_id sono diversi (nemici)
	return target.player_id != attacker_id

func _execute_action(source_entities: Array, target_data = null) -> void:
	# 1. Validazione di sicurezza del bersaglio
	if target_data == null or not target_data is Node2D:
		return

	# 2. Assegna l'ordine a tutte le unità selezionate
	for entity in source_entities:
		var attack_component: AttackComponent = entity.get_node("AttackComponent")
		if attack_component != null:
			# 1. Imposta l'incarico globale
			entity.current_assignment = BaseUnit.AssignmentState.ATTACK
			entity.current_target = target_data
			
			# 2. Consegna il bersaglio al componente specializzato
			attack_component.set_attack_target(target_data)
