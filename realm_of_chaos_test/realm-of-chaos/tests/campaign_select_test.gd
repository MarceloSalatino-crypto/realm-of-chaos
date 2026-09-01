extends SceneTree

const CampaignCatalogScript = preload("res://scripts/campaign_catalog.gd")
const CampaignScene = preload("res://scenes/campaign_select.tscn")
const SaveStoreScript = preload("res://scripts/save_store.gd")
const TEST_SAVE_PATH := "user://campaign_select_test.cfg"
const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1024, 576), Vector2i(960, 540),
	Vector2i(800, 450), Vector2i(640, 360),
]

var failures: Array[String] = []
var capture_dir := ""


func _initialize() -> void:
	capture_dir = OS.get_environment("ROC_CAMPAIGN_CAPTURE_DIR")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CAMPAIGN SELECT: " + message)


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".swap", ".corrupt", ".bak.corrupt"]:
		var path := TEST_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _seed_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "essence", 91)
	config.set_value("record", "victories", 4)
	_check(SaveStoreScript.save_config(config, TEST_SAVE_PATH) == OK, "save visual de teste não foi criado")


func _settle(frames := 3) -> void:
	for _frame in range(frames):
		await process_frame


func _inside_viewport(control: Control, viewport_size: Vector2i, label: String) -> void:
	var rect := control.get_global_rect()
	_check(
		rect.position.x >= -0.6 and rect.position.y >= -0.6
		and rect.end.x <= viewport_size.x + 0.6 and rect.end.y <= viewport_size.y + 0.6,
		"%s saiu de %dx%d: %s" % [label, viewport_size.x, viewport_size.y, rect]
	)


func _capture(viewport: SubViewport, capture_name: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	_check(not image.is_empty(), "captura da campanha ficou vazia: %s" % capture_name)
	if not image.is_empty():
		_check(image.save_png(capture_dir.path_join(capture_name + ".png")) == OK, "captura não pôde ser salva: %s" % capture_name)


func _run() -> void:
	_cleanup()
	_seed_profile()
	var manager = root.get_node("CampaignManager")
	for viewport_size in VIEWPORT_SIZES:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		viewport.disable_3d = true
		viewport.gui_disable_input = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var screen = CampaignScene.instantiate()
		screen.save_path = TEST_SAVE_PATH
		viewport.add_child(screen)
		await _settle()
		_check(screen.map_cards.size() == 10, "seleção não exibiu dez mapas em %s" % viewport_size)
		_check(screen.selected_map_id == "profaned_forest", "novo perfil não selecionou o mapa 1")
		_check(not screen.start_button.disabled, "mapa 1 iniciou indisponível")
		var selection_before: String = str(screen.selected_map_id)
		screen._on_card_pressed("frozen_ruins")
		_check(screen.selected_map_id == selection_before, "mapa 2 bloqueado alterou a seleção")
		_check("Conclua BOSQUE PROFANADO" in screen.status_label.text, "requisito do mapa 2 não foi explicado")
		screen._on_card_pressed("map_04")
		_check(screen.selected_map_id == selection_before, "mapa EM BREVE alterou a seleção")
		_check("EM BREVE" in screen.status_label.text, "mapa futuro não informou EM BREVE")
		_inside_viewport(screen.map_scroll, viewport_size, "trilha da campanha")
		_inside_viewport(screen.back_button, viewport_size, "voltar")
		_inside_viewport(screen.start_button, viewport_size, "iniciar")
		_check(screen.map_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "campanha perdeu rolagem horizontal")
		await _capture(viewport, "campaign_%dx%d" % [viewport_size.x, viewport_size.y])
		screen.queue_free()
		viewport.queue_free()
		await _settle(1)

	manager.load_progress(TEST_SAVE_PATH, false)
	var config_result := SaveStoreScript.load_config(TEST_SAVE_PATH)
	var config: ConfigFile = config_result.config
	var completion: Dictionary = manager.apply_completion(config, "profaned_forest")
	_check(str(completion.unlocked_map_id) == "frozen_ruins", "conclusão não desbloqueou Ruínas Glaciais")
	_check(SaveStoreScript.save_config(config, TEST_SAVE_PATH) == OK, "desbloqueio não pôde ser salvo")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var unlocked_screen = CampaignScene.instantiate()
	unlocked_screen.save_path = TEST_SAVE_PATH
	viewport.add_child(unlocked_screen)
	await _settle()
	var forest_state := unlocked_screen.map_cards.profaned_forest.get_node("Margin/Content/State") as Label
	var frozen_state := unlocked_screen.map_cards.frozen_ruins.get_node("Margin/Content/State") as Label
	_check(forest_state.text == "CONCLUÍDO", "mapa concluído não recebeu estado visual")
	_check(frozen_state.text == "◆ DISPONÍVEL", "mapa desbloqueado não recebeu estado visual")
	unlocked_screen._on_card_pressed("frozen_ruins")
	_check(unlocked_screen.selected_map_id == "frozen_ruins", "mapa 2 desbloqueado não pôde ser selecionado")
	_check(not unlocked_screen.start_button.disabled, "ação de iniciar ficou bloqueada no mapa 2")
	await _capture(viewport, "campaign_unlocked_1280x720")
	unlocked_screen.queue_free()
	viewport.queue_free()
	await _settle(1)

	var before_reset := SaveStoreScript.load_config(TEST_SAVE_PATH).config as ConfigFile
	_check(int(before_reset.get_value("meta", "essence", 0)) == 91, "precondição do reset perdeu Essência")
	_check(manager.reset_campaign_progress(TEST_SAVE_PATH) == OK, "reset de campanha falhou")
	var after_reset := SaveStoreScript.load_config(TEST_SAVE_PATH).config as ConfigFile
	_check(int(after_reset.get_value("meta", "essence", 0)) == 91, "reset de campanha apagou Essência")
	_check(int(after_reset.get_value("record", "victories", 0)) == 4, "reset de campanha apagou recordes")
	_check(manager.unlocked_maps == [CampaignCatalogScript.first_map_id()], "reset não voltou ao mapa 1")
	_cleanup()
	if failures.is_empty():
		print("CAMPAIGN SELECT OK: 10 mapas, bloqueios, EM BREVE, estados, reset e 5 resoluções validados")
		quit(0)
	else:
		quit(1)
