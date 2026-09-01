extends SceneTree

const SaveStoreScript = preload("res://scripts/save_store.gd")
const WorldScene = preload("res://scenes/world.tscn")
const TEST_SAVE_PATH := "user://campaign_run_flow_test.cfg"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CAMPAIGN RUN FLOW: " + message)


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".swap", ".corrupt", ".bak.corrupt"]:
		var path := TEST_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _create_world():
	var world = WorldScene.instantiate()
	world.persistence_path_override = TEST_SAVE_PATH
	root.add_child(world)
	await process_frame
	world.audio.enabled = false
	world.set_process(false)
	return world


func _run() -> void:
	_cleanup()
	var manager = root.get_node("CampaignManager")
	manager.load_progress(TEST_SAVE_PATH, true)
	var world_1 = await _create_world()
	_check(world_1.campaign_map_id == "profaned_forest", "novo jogo não abriu o mapa 1")
	world_1._save_record(false)
	manager.load_progress(TEST_SAVE_PATH, false)
	_check(manager.completed_maps.is_empty(), "derrota concluiu o mapa 1")
	_check(manager.selected_map_id == "profaned_forest", "derrota trocou o mapa selecionado")
	var map_1_result: Dictionary = world_1._save_record(true)
	_check(str(map_1_result.completed_map_id) == "profaned_forest", "vitória não concluiu o mapa 1")
	_check(str(map_1_result.unlocked_map_id) == "frozen_ruins", "vitória no mapa 1 não desbloqueou o mapa 2")
	world_1.queue_free()
	await process_frame

	manager.load_progress(TEST_SAVE_PATH, false)
	_check(manager.can_start_map("profaned_forest"), "mapa 1 concluído não pode ser repetido")
	_check(manager.can_start_map("frozen_ruins"), "mapa 2 não está disponível")
	_check(not manager.can_start_map("void_cathedral"), "mapa 3 foi liberado antes do mapa 2")
	_check(manager.persist_selection("frozen_ruins"), "mapa 2 não pôde ser selecionado")
	var world_2 = await _create_world()
	_check(world_2.campaign_map_id == "frozen_ruins", "mundo não carregou o mapa 2 selecionado")
	world_2._save_record(false)
	manager.load_progress(TEST_SAVE_PATH, false)
	_check(manager.selected_map_id == "frozen_ruins", "derrota no mapa 2 não preservou a seleção")
	_check(not manager.can_start_map("void_cathedral"), "derrota no mapa 2 liberou o mapa 3")
	var map_2_result: Dictionary = world_2._save_record(true)
	_check(str(map_2_result.unlocked_map_id) == "void_cathedral", "vitória no mapa 2 não desbloqueou o mapa 3")
	world_2.queue_free()
	await process_frame

	manager.load_progress(TEST_SAVE_PATH, false)
	_check(manager.completed_maps == ["profaned_forest", "frozen_ruins"], "sequência concluída foi salva incorretamente")
	_check(manager.can_start_map("void_cathedral"), "mapa 3 não permaneceu desbloqueado após reinício")
	_check(not manager.can_start_map("map_04"), "mapa EM BREVE pôde iniciar")
	var stored := SaveStoreScript.load_config(TEST_SAVE_PATH)
	_check(str(stored.status) == SaveStoreScript.STATUS_OK, "save final da campanha perdeu integridade")
	_cleanup()
	if failures.is_empty():
		print("CAMPAIGN RUN FLOW OK: derrota conserva mapa; vitórias 1→2→3 persistem sem saltos")
		quit(0)
	else:
		quit(1)
