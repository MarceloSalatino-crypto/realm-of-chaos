extends SceneTree

const SaveStoreScript = preload("res://scripts/save_store.gd")
const MENU_SCENE = preload("res://scenes/main_menu.tscn")
const TEST_SAVE_PATH := "user://save_recovery_ui_test.cfg"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SAVE RECOVERY UI: " + message)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _clean_artifacts() -> void:
	for path in [
		TEST_SAVE_PATH,
		TEST_SAVE_PATH + ".bak",
		TEST_SAVE_PATH + ".tmp",
		TEST_SAVE_PATH + ".swap",
		TEST_SAVE_PATH + ".bak.tmp",
		TEST_SAVE_PATH + ".bak.swap",
		TEST_SAVE_PATH + ".corrupt",
		TEST_SAVE_PATH + ".bak.corrupt",
	]:
		_remove_file(path)
	for index in range(1, 8):
		_remove_file("%s.corrupt.%d" % [TEST_SAVE_PATH, index])
		_remove_file("%s.bak.corrupt.%d" % [TEST_SAVE_PATH, index])
	var temporary_absolute := ProjectSettings.globalize_path(TEST_SAVE_PATH + ".tmp")
	if DirAccess.dir_exists_absolute(temporary_absolute):
		DirAccess.remove_absolute(temporary_absolute)


func _popup_text(menu: Control, node_path: String) -> String:
	if not is_instance_valid(menu.popup):
		return ""
	var node: Node = menu.popup.get_node_or_null(node_path)
	return str(node.text) if node else ""


func _tamper_checksum(path: String) -> void:
	var config := ConfigFile.new()
	_check(config.load(path) == OK, "save de interface nao pode ser adulterado: " + path)
	config.set_value("_save_integrity", "checksum", "checksum_invalido")
	_check(config.save(path) == OK, "checksum adulterado nao pode ser gravado: " + path)


func _run() -> void:
	_clean_artifacts()
	var menu = MENU_SCENE.instantiate()
	menu.save_path = TEST_SAVE_PATH
	root.add_child(menu)
	await process_frame
	await process_frame
	_check(menu.save_load_status == SaveStoreScript.STATUS_MISSING, "primeira execucao nao foi reconhecida")
	_check(not is_instance_valid(menu.popup), "primeira execucao exibiu aviso indevido")

	var legacy := ConfigFile.new()
	legacy.set_value("meta", "essence", 12)
	legacy.set_value("record", "best_time", 90.0)
	legacy.set_value("profile", "character", "eclipse_hunter")
	legacy.set_value("settings", "music", 0.75)
	_check(legacy.save(TEST_SAVE_PATH) == OK, "save legado do menu nao foi preparado")
	menu._load_records()
	_check(menu.save_load_status == SaveStoreScript.STATUS_OK, "menu nao aceitou save legado")
	menu._select_character("crimson_knight")
	await process_frame
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH), "menu nao gravou checksum")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH + ".bak"), "menu nao criou backup")
	var saved_profile := ConfigFile.new()
	_check(saved_profile.load(TEST_SAVE_PATH) == OK, "save atualizado do menu nao pode ser relido")
	_check(str(saved_profile.get_value("profile", "character", "")) == "crimson_knight", "selecao de personagem nao foi persistida")

	var main_before_failure := FileAccess.get_file_as_bytes(TEST_SAVE_PATH)
	var backup_before_failure := FileAccess.get_file_as_bytes(TEST_SAVE_PATH + ".bak")
	var blocked_temporary := ProjectSettings.globalize_path(TEST_SAVE_PATH + ".tmp")
	_check(DirAccess.make_dir_absolute(blocked_temporary) == OK, "falha de escrita do menu nao foi preparada")
	menu._cycle_setting("music")
	_check(menu.last_save_error != OK, "menu nao detectou falha de escrita")
	_check(_popup_text(menu, "PopupPanel/Margin/VBox/Title") == "FALHA AO SALVAR", "menu nao mostrou aviso imediato de escrita")
	_check(FileAccess.get_file_as_bytes(TEST_SAVE_PATH) == main_before_failure, "falha do menu alterou o principal")
	_check(FileAccess.get_file_as_bytes(TEST_SAVE_PATH + ".bak") == backup_before_failure, "falha do menu alterou o backup")
	DirAccess.remove_absolute(blocked_temporary)

	_tamper_checksum(TEST_SAVE_PATH)
	menu.save_load_notice_shown = false
	menu._load_records()
	await process_frame
	_check(menu.save_load_status == SaveStoreScript.STATUS_RECOVERED, "menu nao recuperou principal adulterado")
	_check(_popup_text(menu, "PopupPanel/Margin/VBox/Title") == "PROGRESSO RECUPERADO", "menu nao mostrou aviso de recuperacao")
	_check("recuperado automaticamente" in _popup_text(menu, "PopupPanel/Margin/VBox/BodyScroll/Body"), "texto de recuperacao nao foi exibido")

	_tamper_checksum(TEST_SAVE_PATH)
	_tamper_checksum(TEST_SAVE_PATH + ".bak")
	menu.save_load_notice_shown = false
	menu._load_records()
	await process_frame
	_check(menu.save_load_status == SaveStoreScript.STATUS_FAILED, "menu nao detectou principal e backup corrompidos")
	_check(menu.records_label.text == "SEU PRIMEIRO RITUAL AGUARDA", "menu nao caiu para os valores padrao")
	_check(_popup_text(menu, "PopupPanel/Margin/VBox/Title") == "AVISO DE PROGRESSO", "menu nao mostrou aviso da falha dupla")
	var failed_body := _popup_text(menu, "PopupPanel/Margin/VBox/BodyScroll/Body")
	_check("novo perfil" in failed_body and "preservados" in failed_body, "aviso da falha dupla esta incompleto")

	menu.queue_free()
	await process_frame
	_clean_artifacts()
	if failures.is_empty():
		print("SAVE RECOVERY UI OK: primeiro uso, menu compartilhado, recuperacao e avisos validados")
		quit(0)
	else:
		quit(1)
