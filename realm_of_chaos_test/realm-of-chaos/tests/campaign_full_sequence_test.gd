extends SceneTree

const CampaignScene = preload("res://scenes/campaign_select.tscn")
const CampaignSceneScript = preload("res://scripts/campaign_select.gd")
const SaveStoreScript = preload("res://scripts/save_store.gd")
const TEST_SAVE_PATH := "user://campaign_full_sequence_test.cfg"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CAMPAIGN FULL SEQUENCE: " + message)


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".swap", ".corrupt", ".bak.corrupt"]:
		var path := TEST_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _prepare_world(world) -> void:
	world.audio.enabled = false
	world.set_process(false)


func _start_selected_map(campaign, map_id: String):
	campaign._on_card_pressed(map_id)
	campaign._on_start_pressed()
	await create_timer(0.45).timeout
	await process_frame
	return current_scene


func _run() -> void:
	_cleanup()
	var manager = root.get_node("CampaignManager")
	manager.load_progress(TEST_SAVE_PATH, true)
	var campaign = CampaignScene.instantiate()
	campaign.save_path = TEST_SAVE_PATH
	root.add_child(campaign)
	current_scene = campaign
	await process_frame

	var world_1 = await _start_selected_map(campaign, "profaned_forest")
	_check(str(world_1.name) == "World" and world_1.campaign_map_id == "profaned_forest", "Mapa 1 não iniciou no world.tscn real")
	_prepare_world(world_1)
	world_1._end_run(true)
	_check("PRÓXIMO MAPA DESBLOQUEADO" in world_1.hud.end_summary.text, "vitória do Mapa 1 não confirmou o desbloqueio")
	var first_victory_result := SaveStoreScript.load_config(TEST_SAVE_PATH, false)
	var first_victory_config: ConfigFile = first_victory_result.config
	_check(str(first_victory_result.status) == SaveStoreScript.STATUS_OK, "transação da vitória não pôde ser confirmada")
	_check(bool(first_victory_config.get_value("achievements", "survivor", false)), "conquista da vitória não foi salva na mesma transação")
	_check(int(first_victory_config.get_value("record", "victories", 0)) == 1, "recorde de vitórias não foi salvo na mesma transação")
	_check("profaned_forest" in first_victory_config.get_value("campaign", "completed_maps", PackedStringArray()), "campanha não foi salva na mesma transação")
	world_1.run_flow.restart_run()
	await process_frame
	await process_frame
	_check(current_scene is CampaignSceneScript, "vitória do Mapa 1 não voltou à campanha")

	campaign = current_scene
	var world_2 = await _start_selected_map(campaign, "frozen_ruins")
	_check(str(world_2.name) == "World" and world_2.campaign_map_id == "frozen_ruins", "Mapa 2 desbloqueado não iniciou")
	_prepare_world(world_2)
	world_2._end_run(false)
	world_2.run_flow.restart_run()
	world_2.run_flow.restart_run()
	await process_frame
	await process_frame
	var retried_world_2 = current_scene
	_check(str(retried_world_2.name) == "World", "derrota não recarregou world.tscn")
	_check(retried_world_2.campaign_map_id == "frozen_ruins", "retry da derrota abriu outro mapa")
	_prepare_world(retried_world_2)
	retried_world_2._end_run(true)
	retried_world_2.run_flow.restart_run()
	await process_frame
	await process_frame
	_check(current_scene is CampaignSceneScript, "vitória do Mapa 2 não voltou à campanha")

	campaign = current_scene
	_check(manager.can_start_map("void_cathedral"), "Mapa 3 não foi desbloqueado após concluir o Mapa 2")
	var world_3 = await _start_selected_map(campaign, "void_cathedral")
	_check(str(world_3.name) == "World" and world_3.campaign_map_id == "void_cathedral", "Mapa 3 não iniciou após a sequência")
	manager.load_progress(TEST_SAVE_PATH, false)
	_check(manager.completed_maps == ["profaned_forest", "frozen_ruins"], "conclusões persistidas não correspondem à sequência")
	_check(not manager.can_start_map("map_04"), "sequência liberou conteúdo EM BREVE")

	paused = false
	if is_instance_valid(world_3):
		world_3.queue_free()
		await process_frame
	manager.load_progress("user://realm_of_chaos.cfg", false)
	root.get_node("SceneTransitionGuard").release()
	_cleanup()
	if failures.is_empty():
		print("CAMPAIGN FULL SEQUENCE OK: M1 vitória → M2 derrota/retry/vitória → M3")
		quit(0)
	else:
		quit(1)
