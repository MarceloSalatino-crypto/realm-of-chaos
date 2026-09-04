extends SceneTree

const SaveStoreScript = preload("res://scripts/save_store.gd")
const WorldScene = preload("res://scenes/world.tscn")
const TEST_SAVE_PATH := "user://campaign_atomic_save_test.cfg"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CAMPAIGN ATOMIC SAVE: " + message)


func _remove_path(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute(absolute)


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".swap", ".bak.tmp", ".bak.swap", ".corrupt", ".bak.corrupt"]:
		_remove_path(TEST_SAVE_PATH + str(suffix))


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func _run() -> void:
	_cleanup()
	var manager = root.get_node("CampaignManager")
	manager.load_progress(TEST_SAVE_PATH, true)
	var disk_before := _bytes(TEST_SAVE_PATH)
	var backup_before := _bytes(TEST_SAVE_PATH + ".bak")
	var before_result := SaveStoreScript.load_config(TEST_SAVE_PATH, false)
	var before_config: ConfigFile = before_result.config
	var victories_before := int(before_config.get_value("record", "victories", 0))
	var essence_before := int(before_config.get_value("meta", "essence", 0))

	var world = WorldScene.instantiate()
	world.persistence_path_override = TEST_SAVE_PATH
	root.add_child(world)
	await process_frame
	world.audio.enabled = false
	world.set_process(false)
	world.bosses_defeated = 5
	world.enemies_killed = 600
	world.essence_earned = 73
	world.time_survived = 1500.0
	world.damage_taken = 0.0

	var temporary_absolute := ProjectSettings.globalize_path(TEST_SAVE_PATH + ".tmp")
	_check(DirAccess.make_dir_absolute(temporary_absolute) == OK, "não foi possível bloquear a escrita temporária")
	world._end_run(true)

	_check(world.persistence.write_failed, "falha de gravação não foi registrada pela persistência")
	_check(world.hud.end_title.text == "VITÓRIA · NÃO SALVA", "HUD apresentou a vitória como persistida")
	_check("PRÓXIMO MAPA DESBLOQUEADO" not in world.hud.end_summary.text, "HUD alegou desbloqueio após falha")
	_check("CONQUISTA DESBLOQUEADA" not in world.hud.end_summary.text, "HUD alegou conquista após falha")
	_check("Essência conquistada  0" in world.hud.end_summary.text, "HUD alegou recompensa persistente após falha")
	_check("não pôde ser gravado" in world.hud.end_summary.text, "HUD não explicou a falha de persistência")
	_check(_bytes(TEST_SAVE_PATH) == disk_before, "falha alterou o save principal")
	_check(_bytes(TEST_SAVE_PATH + ".bak") == backup_before, "falha alterou o backup")

	manager.load_progress(TEST_SAVE_PATH, false)
	_check(not manager.can_start_map("frozen_ruins"), "estado em memória manteve o mapa 2 desbloqueado")
	_check(manager.completed_maps.is_empty(), "estado em memória manteve conclusão não salva")
	var restarted_result := SaveStoreScript.load_config(TEST_SAVE_PATH, false)
	var restarted_config: ConfigFile = restarted_result.config
	_check(int(restarted_config.get_value("record", "victories", 0)) == victories_before, "reinício encontrou vitória não salva")
	_check(int(restarted_config.get_value("meta", "essence", 0)) == essence_before, "reinício encontrou Essência não salva")
	_check(not bool(restarted_config.get_value("achievements", "survivor", false)), "reinício encontrou conquista não salva")

	paused = false
	world.queue_free()
	await process_frame
	DirAccess.remove_absolute(temporary_absolute)

	_cleanup()
	manager.load_progress(TEST_SAVE_PATH, false)
	var blocked_backup_temporary := ProjectSettings.globalize_path(TEST_SAVE_PATH + ".bak.tmp")
	_check(DirAccess.make_dir_absolute(blocked_backup_temporary) == OK, "não foi possível bloquear o primeiro backup")
	var first_save_world = WorldScene.instantiate()
	first_save_world.persistence_path_override = TEST_SAVE_PATH
	root.add_child(first_save_world)
	await process_frame
	first_save_world.audio.enabled = false
	first_save_world.set_process(false)
	first_save_world.bosses_defeated = 5
	first_save_world.enemies_killed = 600
	first_save_world.essence_earned = 73
	first_save_world.time_survived = 1500.0
	first_save_world.damage_taken = 0.0
	first_save_world._end_run(true)
	_check(first_save_world.persistence.write_failed, "falha do primeiro backup não foi registrada")
	_check(first_save_world.hud.end_title.text == "VITÓRIA · NÃO SALVA", "HUD confirmou vitória com primeiro backup bloqueado")
	_check(not FileAccess.file_exists(TEST_SAVE_PATH), "falha do primeiro backup deixou progresso parcial no principal")
	manager.load_progress(TEST_SAVE_PATH, false)
	_check(not manager.can_start_map("frozen_ruins"), "falha do primeiro backup desbloqueou o mapa 2 em memória")
	paused = false
	first_save_world.queue_free()
	await process_frame
	DirAccess.remove_absolute(blocked_backup_temporary)

	_cleanup()
	manager.load_progress(TEST_SAVE_PATH, false)
	var blocked_primary := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	_check(DirAccess.make_dir_absolute(blocked_primary) == OK, "não foi possível bloquear a promoção final")
	var blocked_promotion_world = WorldScene.instantiate()
	blocked_promotion_world.persistence_path_override = TEST_SAVE_PATH
	root.add_child(blocked_promotion_world)
	await process_frame
	blocked_promotion_world.audio.enabled = false
	blocked_promotion_world.set_process(false)
	blocked_promotion_world.bosses_defeated = 5
	blocked_promotion_world.enemies_killed = 600
	blocked_promotion_world.essence_earned = 73
	blocked_promotion_world.time_survived = 1500.0
	blocked_promotion_world.damage_taken = 0.0
	blocked_promotion_world._end_run(true)
	_check(blocked_promotion_world.persistence.write_failed, "falha da promoção final não foi registrada")
	_check(blocked_promotion_world.hud.end_title.text == "VITÓRIA · NÃO SALVA", "HUD confirmou vitória com promoção final bloqueada")
	_check("PRÓXIMO MAPA DESBLOQUEADO" not in blocked_promotion_world.hud.end_summary.text, "HUD alegou desbloqueio após falha da promoção")
	_check("CONQUISTA DESBLOQUEADA" not in blocked_promotion_world.hud.end_summary.text, "HUD alegou conquista após falha da promoção")
	_check(not FileAccess.file_exists(TEST_SAVE_PATH), "falha da promoção criou progresso parcial no principal")
	_check(not SaveStoreScript.is_valid_file(TEST_SAVE_PATH + ".bak"), "falha da promoção deixou backup inicial confirmado")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH + ".tmp"), "falha da promoção não preservou o candidato temporário completo")
	manager.load_progress(TEST_SAVE_PATH, false)
	_check(not manager.can_start_map("frozen_ruins"), "temporário residual desbloqueou o mapa 2 em memória")
	_check(manager.completed_maps.is_empty(), "temporário residual marcou conclusão em memória")
	var promotion_restart := SaveStoreScript.load_config(TEST_SAVE_PATH, false)
	_check(str(promotion_restart.status) == SaveStoreScript.STATUS_MISSING, "reinício interpretou temporário residual como save")
	paused = false
	blocked_promotion_world.queue_free()
	await process_frame
	_remove_path(TEST_SAVE_PATH)
	manager.load_progress("user://realm_of_chaos.cfg", false)
	_cleanup()
	if failures.is_empty():
		print("CAMPAIGN ATOMIC SAVE OK: falha de vitória preserva disco, memória e HUD confirmados")
		quit(0)
	else:
		quit(1)
