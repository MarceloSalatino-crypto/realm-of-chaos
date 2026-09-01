extends SceneTree

const CampaignSceneScript = preload("res://scripts/campaign_select.gd")
const MainMenuSceneScript = preload("res://scripts/main_menu.gd")
const WorldScene = preload("res://scenes/world.tscn")
const TEST_SAVE_PATH := "user://scene_transition_guard_test.cfg"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("SCENE TRANSITION GUARD: " + message)


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".swap", ".corrupt", ".bak.corrupt"]:
		var path := TEST_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _world_count() -> int:
	var count := 0
	for child in root.get_children():
		if str(child.name).begins_with("World"):
			count += 1
	return count


func _run() -> void:
	_cleanup()
	var manager = root.get_node("CampaignManager")
	var guard = root.get_node("SceneTransitionGuard")
	manager.load_progress(TEST_SAVE_PATH, true)

	var invalid_error: Error = guard.change_scene_to_file("res://scenes/missing_transition_target.tscn")
	_check(invalid_error != OK, "cena inexistente foi aceita")
	_check(not guard.is_transitioning(), "falha de cena deixou a trava central presa")

	var world = WorldScene.instantiate()
	world.persistence_path_override = TEST_SAVE_PATH
	root.add_child(world)
	current_scene = world
	await process_frame
	world.audio.enabled = false
	world.set_process(false)
	world.run_was_victory = false
	world.run_flow.restart_run()
	_check(world.hud.end_restart_button.disabled and world.hud.end_menu_button.disabled, "botões do fim não foram travados")
	world.run_flow.restart_run()
	await process_frame
	await process_frame
	var retried_world = current_scene
	_check(str(retried_world.name) == "World", "retry duplo não recarregou o mapa")
	_check(retried_world != world, "retry duplo manteve a instância antiga")
	_check(_world_count() == 1, "retry duplo criou mais de um World")

	retried_world.audio.enabled = false
	retried_world.set_process(false)
	retried_world.run_was_victory = true
	retried_world.run_flow.restart_run()
	retried_world.run_flow.restart_run()
	await process_frame
	await process_frame
	_check(current_scene is CampaignSceneScript, "retorno duplo da vitória não abriu a campanha")
	_check(not guard.is_transitioning(), "trava central não foi liberada após abrir a campanha")

	var campaign = current_scene
	campaign._on_back_pressed()
	campaign._on_back_pressed()
	await process_frame
	await process_frame
	_check(current_scene is MainMenuSceneScript, "retorno duplo ao menu não abriu uma única tela principal")

	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	manager.load_progress("user://realm_of_chaos.cfg", false)
	guard.release()
	_cleanup()
	if failures.is_empty():
		print("SCENE TRANSITION GUARD OK: falha libera trava; retry, campanha e menu ignoram duplicatas")
		quit(0)
	else:
		quit(1)
