extends SceneTree

const CampaignSceneScript = preload("res://scripts/campaign_select.gd")
const MainMenuScene = preload("res://scenes/main_menu.tscn")
const SaveStoreScript = preload("res://scripts/save_store.gd")
const TEST_SAVE_PATH := "user://campaign_navigation_test.cfg"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CAMPAIGN NAVIGATION: " + message)


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".swap", ".corrupt", ".bak.corrupt"]:
		var path := TEST_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _run() -> void:
	_cleanup()
	var manager = root.get_node("CampaignManager")
	manager.load_progress(TEST_SAVE_PATH, true)
	var menu = MainMenuScene.instantiate()
	menu.save_path = TEST_SAVE_PATH
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu._open_campaign()
	await process_frame
	await process_frame
	_check(current_scene is CampaignSceneScript, "INICIAR RITUAL não abriu a campanha")
	var campaign = current_scene
	if not (campaign is CampaignSceneScript):
		quit(1)
		return
	_check(campaign.save_path == TEST_SAVE_PATH, "campanha deixou o caminho isolado de teste")
	_check(campaign.selected_map_id == "profaned_forest", "campanha não manteve o mapa 1 selecionado")
	_check(manager.persist_selection("profaned_forest"), "seleção do mapa 1 não foi persistida")
	campaign._open_selected_map("res://scenes/world.tscn")
	await process_frame
	await process_frame
	var first_world = current_scene
	_check(str(first_world.name) == "World", "INICIAR MAPA não abriu world.tscn")
	_check(first_world.campaign_map_id == "profaned_forest", "world.tscn abriu um mapa diferente do selecionado")
	_check(first_world.persistence.save_path == TEST_SAVE_PATH, "world.tscn deixou o save isolado de navegação")
	first_world.run_was_victory = false
	first_world.run_flow.restart_run()
	await process_frame
	await process_frame
	var retried_world = current_scene
	_check(str(retried_world.name) == "World", "TENTAR NOVAMENTE não recarregou world.tscn")
	_check(retried_world != first_world, "TENTAR NOVAMENTE reutilizou a instância encerrada")
	_check(retried_world.campaign_map_id == "profaned_forest", "derrota reiniciou outro mapa")
	retried_world.run_was_victory = true
	retried_world.run_flow.restart_run()
	await process_frame
	await process_frame
	_check(current_scene is CampaignSceneScript, "vitória não voltou para a campanha")
	_check(current_scene.save_path == TEST_SAVE_PATH, "retorno da vitória deixou o save isolado")

	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	manager.load_progress("user://realm_of_chaos.cfg", false)
	_cleanup()
	if failures.is_empty():
		print("CAMPAIGN NAVIGATION OK: menu→campanha→mapa, retry idêntico e vitória→campanha validados")
		quit(0)
	else:
		quit(1)
