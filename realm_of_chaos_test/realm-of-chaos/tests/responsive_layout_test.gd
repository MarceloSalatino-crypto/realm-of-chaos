extends SceneTree

const MAIN_MENU_SCENE = preload("res://scenes/main_menu.tscn")
const HUD_SCENE = preload("res://scenes/hud.tscn")
const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1024, 576),
	Vector2i(960, 540),
	Vector2i(800, 450),
	Vector2i(640, 360),
]

var failures: Array[String] = []
var capture_dir := ""


func _initialize() -> void:
	capture_dir = OS.get_environment("ROC_LAYOUT_CAPTURE_DIR")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("RESPONSIVE LAYOUT: " + message)


func _inside_viewport(control: Control, viewport_size: Vector2, label: String) -> void:
	var rect := control.get_global_rect()
	_check(
		rect.position.x >= -0.6
		and rect.position.y >= -0.6
		and rect.end.x <= viewport_size.x + 0.6
		and rect.end.y <= viewport_size.y + 0.6,
		"%s saiu da viewport %dx%d: pos=%s size=%s"
		% [label, int(viewport_size.x), int(viewport_size.y), rect.position, rect.size]
	)


func _inside_parent(control: Control, parent: Control, label: String) -> void:
	var rect := Rect2(control.position, control.size)
	_check(
		rect.position.x >= -0.6
		and rect.position.y >= -0.6
		and rect.end.x <= parent.size.x + 0.6
		and rect.end.y <= parent.size.y + 0.6,
		"%s saiu do controle pai: pos=%s size=%s pai=%s"
		% [label, rect.position, rect.size, parent.size]
	)


func _settle(frame_count := 3) -> void:
	for _frame in range(frame_count):
		await process_frame


func _new_viewport(viewport_size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _capture(viewport: SubViewport, capture_name: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var output_path := capture_dir.path_join(capture_name + ".png")
	_check(image.save_png(output_path) == OK, "falha ao salvar captura %s" % output_path)


func _viewport_tag(viewport_size: Vector2i) -> String:
	return "%dx%d" % [viewport_size.x, viewport_size.y]


func _upgrade_worst_case() -> Array[Dictionary]:
	return [
		{
			"id": "storm_relic", "icon": "ϟ", "title": "RELÍQUIA DA TEMPESTADE",
			"category": "EVOLUÇÃO DE ARMA", "level": 4, "max": 6, "levels_gained": 2,
			"description": "Encadeia relâmpagos entre vários alvos e amplia o alcance da tempestade.",
			"short_description": "Relâmpagos encadeados entre alvos",
			"evolution_hint": "EVOLUI COM RITUAL ACELERADO NÍVEL 3",
			"synergy_items": [{"id": "haste", "required_level": 3}],
			"rarity": "LENDÁRIO",
		},
		{
			"id": "forbidden_grimoire", "icon": "◆", "title": "GRIMÓRIO PROIBIDO",
			"category": "NOVA ARMA", "level": 1, "max": 5, "levels_gained": 1,
			"description": "Invoca páginas amaldiçoadas que atravessam grupos e retornam carregadas de energia sombria.",
			"short_description": "Selo explosivo sob grupos de inimigos",
			"evolution_hint": "EVOLUI COM RITUAL ACELERADO NÍVEL 3",
			"synergy_items": [{"id": "magnet", "required_level": 3}],
			"rarity": "RARO",
		},
		{
			"id": "regeneration", "icon": "+", "title": "PACTO REGENERATIVO",
			"category": "PASSIVO", "level": 3, "max": 5, "levels_gained": 2,
			"description": "Amplia a vida máxima e fortalece todas as fontes de recuperação durante o ritual.",
			"short_description": "Regenera HP continuamente",
			"evolution_hint": "COMBINA COM CETRO DAS ALMAS E ÍDOLO DO ENXAME",
			"synergy_items": [
				{"id": "soul_orbit", "required_level": 0},
				{"id": "swarm_idol", "required_level": 0},
			],
			"rarity": "LENDÁRIO",
		},
	]


func _validate_meta(menu: Control, viewport: SubViewport, viewport_size: Vector2i) -> void:
	menu.call("_show_meta_progression")
	await _settle()
	var panel := menu.popup.get_node("MetaPanel") as PanelContainer
	var scroll := panel.get_node("Margin/VBox/UpgradeScroll") as ScrollContainer
	var upgrades := scroll.get_node("Upgrades") as VBoxContainer
	var close := panel.get_node("Margin/VBox/Close") as Button
	_inside_viewport(panel, viewport_size, "Legado/Panel")
	_inside_viewport(scroll, viewport_size, "Legado/Scroll")
	_inside_viewport(close, viewport_size, "Legado/Voltar")
	_check(upgrades.size.x <= scroll.size.x + 0.6, "Legado criou overflow horizontal em %s" % _viewport_tag(viewport_size))
	if viewport_size.y <= 360:
		_check(scroll.get_v_scroll_bar().visible, "Legado não ativou scroll vertical em 640x360")
	print(
		"LAYOUT %s LEGADO panel=%dx%d scroll=%dx%d content=%dx%d cols=-"
		% [
			_viewport_tag(viewport_size), roundi(panel.size.x), roundi(panel.size.y),
			roundi(scroll.size.x), roundi(scroll.size.y), roundi(upgrades.size.x), roundi(upgrades.size.y),
		]
	)
	await _capture(viewport, "legado_" + _viewport_tag(viewport_size))


func _validate_content_popup(
	menu: Control, viewport: SubViewport, viewport_size: Vector2i, instructions: bool
) -> void:
	if instructions:
		menu.call("_show_instructions")
	else:
		menu.call("_show_credits")
	await _settle()
	var panel := menu.popup.get_node("PopupPanel") as PanelContainer
	var scroll := panel.get_node("Margin/VBox/BodyScroll") as ScrollContainer
	var body := scroll.get_node("Body") as Label
	var close := panel.get_node("Margin/VBox/Close") as Button
	var screen_name := "INSTRUÇÕES" if instructions else "CRÉDITOS"
	_inside_viewport(panel, viewport_size, screen_name + "/Panel")
	_inside_viewport(scroll, viewport_size, screen_name + "/Scroll")
	_inside_viewport(close, viewport_size, screen_name + "/Fechar")
	_check(body.size.x <= scroll.size.x + 0.6, "%s criou overflow horizontal em %s" % [screen_name, _viewport_tag(viewport_size)])
	if instructions and viewport_size.y <= 360:
		_check(scroll.get_v_scroll_bar().visible, "Instruções não ativou scroll vertical em 640x360")
	print(
		"LAYOUT %s %s panel=%dx%d scroll=%dx%d content=%dx%d cols=-"
		% [
			_viewport_tag(viewport_size), screen_name, roundi(panel.size.x), roundi(panel.size.y),
			roundi(scroll.size.x), roundi(scroll.size.y), roundi(body.size.x), roundi(body.size.y),
		]
	)
	await _capture(
		viewport,
		("instrucoes_" if instructions else "creditos_") + _viewport_tag(viewport_size)
	)


func _validate_menu_layouts(viewport_size: Vector2i) -> void:
	var viewport := _new_viewport(viewport_size)
	var menu = MAIN_MENU_SCENE.instantiate()
	viewport.add_child(menu)
	await _settle()
	menu.set_process(false)
	await _validate_meta(menu, viewport, viewport_size)
	await _validate_content_popup(menu, viewport, viewport_size, true)
	await _validate_content_popup(menu, viewport, viewport_size, false)
	root.remove_child(viewport)
	viewport.queue_free()
	await process_frame


func _validate_upgrade(hud: CanvasLayer, viewport: SubViewport, viewport_size: Vector2i) -> void:
	hud.show_level_up(99, _upgrade_worst_case())
	await _settle()
	var panel := hud.upgrade_panel as PanelContainer
	var scroll := hud.upgrade_scroll as ScrollContainer
	var cards := hud.upgrade_cards as GridContainer
	var expected_columns := 3 if viewport_size.x >= 1280 else (2 if viewport_size.x >= 800 else 1)
	_inside_viewport(panel, viewport_size, "LevelUp/Panel")
	_inside_viewport(scroll, viewport_size, "LevelUp/Scroll")
	_check(
		hud.get_node_or_null("UpgradeOverlay/Panel/Margin/VBox/ChoiceActions") == null,
		"Level up ainda criou os controles removidos"
	)
	_check(cards.columns == expected_columns, "Level up usou %d colunas, esperado %d em %s" % [cards.columns, expected_columns, _viewport_tag(viewport_size)])
	_check(cards.size.x <= scroll.size.x + 0.6, "Level up criou overflow horizontal em %s" % _viewport_tag(viewport_size))
	_check(scroll.scroll_vertical == 0, "Level up não abriu na primeira carta em %s" % _viewport_tag(viewport_size))
	for index in range(hud.upgrade_icon_rects.size()):
		var icon_rect: TextureRect = hud.upgrade_icon_rects[index]
		var summary_label: Label = hud.upgrade_summary_labels[index]
		var effect_label: Label = hud.upgrade_effect_labels[index]
		var rarity_badge: PanelContainer = hud.upgrade_rarity_badges[index]
		var synergy_row: HBoxContainer = hud.upgrade_synergy_rows[index]
		_inside_parent(
			icon_rect, hud.upgrade_buttons[index],
			"LevelUp/Ícone%d" % (index + 1)
		)
		_inside_parent(
			summary_label, hud.upgrade_buttons[index],
			"LevelUp/Resumo%d" % (index + 1)
		)
		_inside_parent(
			effect_label, hud.upgrade_buttons[index],
			"LevelUp/Efeito%d" % (index + 1)
		)
		_inside_parent(
			rarity_badge, hud.upgrade_buttons[index],
			"LevelUp/Raridade%d" % (index + 1)
		)
		_inside_parent(
			synergy_row, hud.upgrade_buttons[index],
			"LevelUp/Sinergia%d" % (index + 1)
		)
		_check(icon_rect.texture != null, "Level up não carregou o ícone da carta %d" % (index + 1))
		if icon_rect.texture:
			_check(
				icon_rect.texture.get_size() == Vector2(256.0, 256.0),
				"Level up carregou ícone fora de 256x256 na carta %d" % (index + 1)
			)
		_check(
			not icon_rect.get_rect().intersects(rarity_badge.get_rect()),
			"Ícone principal e selo de raridade se sobrepõem na carta %d em %s" % [
				index + 1, _viewport_tag(viewport_size)
			]
		)
		_check(
			icon_rect.position.y + icon_rect.size.y <= summary_label.position.y + 0.6
			and summary_label.position.y + summary_label.size.y <= effect_label.position.y + 0.6
			and effect_label.position.y + effect_label.size.y <= synergy_row.position.y + 0.6,
			"Conteúdo vertical se sobrepõe na carta %d em %s" % [
				index + 1, _viewport_tag(viewport_size)
			]
		)
		_check(
			"\n" not in summary_label.text
			and "\n" not in effect_label.text
			and hud.upgrade_buttons[index].text.is_empty(),
			"Carta %d manteve o bloco textual antigo em %s" % [
				index + 1, _viewport_tag(viewport_size)
			]
		)
		var expected_synergies := 2 if index == 2 else 1
		_check(
			synergy_row.get_child_count() == expected_synergies,
			"Carta %d exibiu quantidade incorreta de sinergias em %s" % [
				index + 1, _viewport_tag(viewport_size)
			]
		)
		for holder in synergy_row.get_children():
			_check(
				holder.size.x >= 28.0 and holder.size.x <= 32.0
				and holder.size.y >= 28.0 and holder.size.y <= 32.0,
				"Ícone de sinergia saiu de 28-32 px em %s" % _viewport_tag(viewport_size)
			)
	if viewport_size.y <= 360:
		_check(scroll.get_v_scroll_bar().visible, "Level up não ativou scroll vertical em 640x360")
	print(
		"LAYOUT %s LEVEL_UP panel=%dx%d scroll=%dx%d content=%dx%d cols=%d offset=%d focus=%s"
		% [
			_viewport_tag(viewport_size), roundi(panel.size.x), roundi(panel.size.y),
			roundi(scroll.size.x), roundi(scroll.size.y), roundi(cards.size.x), roundi(cards.size.y), cards.columns,
			scroll.scroll_vertical,
			scroll.get_viewport().gui_get_focus_owner().name if scroll.get_viewport().gui_get_focus_owner() else "none",
		]
	)
	await _capture(viewport, "level_up_" + _viewport_tag(viewport_size))


func _validate_pause(hud: CanvasLayer, viewport: SubViewport, viewport_size: Vector2i) -> void:
	hud.hide_level_up()
	hud.pause_overlay.show()
	hud.call("_update_responsive_hud_layout")
	await _settle()
	_inside_viewport(hud.pause_panel, viewport_size, "Pausa/Panel")
	_inside_viewport(hud.pause_title, viewport_size, "Pausa/Título")
	for button in hud.pause_buttons:
		_inside_viewport(button, viewport_size, "Pausa/" + button.name)
	print(
		"LAYOUT %s PAUSA panel=%dx%d content=%dx%d cols=-"
		% [
			_viewport_tag(viewport_size), roundi(hud.pause_panel.size.x), roundi(hud.pause_panel.size.y),
			roundi(hud.pause_vbox.size.x), roundi(hud.pause_vbox.size.y),
		]
	)
	await _capture(viewport, "pausa_" + _viewport_tag(viewport_size))


func _validate_stage_banner(hud: CanvasLayer, viewport: SubViewport, viewport_size: Vector2i) -> void:
	hud.pause_overlay.hide()
	hud.show_stage_banner("IV · CATEDRAL PROFANADA · A TEMPESTADE DO VÉU SE APROXIMA")
	if hud.stage_banner_tween and hud.stage_banner_tween.is_valid():
		hud.stage_banner_tween.kill()
	hud.stage_banner.modulate = Color.WHITE
	hud.stage_banner.show()
	await _settle()
	_inside_viewport(hud.stage_banner, viewport_size, "Banner/Fase")
	print(
		"LAYOUT %s FASE panel=%dx%d content=%dx%d cols=-"
		% [
			_viewport_tag(viewport_size), roundi(hud.stage_banner.size.x), roundi(hud.stage_banner.size.y),
			roundi(hud.stage_banner.get_minimum_size().x), roundi(hud.stage_banner.get_minimum_size().y),
		]
	)
	await _capture(viewport, "fase_" + _viewport_tag(viewport_size))


func _validate_boss_banner(hud: CanvasLayer, viewport: SubViewport, viewport_size: Vector2i) -> void:
	hud.stage_banner.hide()
	hud.show_boss("SOBERANO ABSOLUTO DO CAOS · FASE 3", 7250.0, 9200.0)
	hud.show_boss_intro(
		"SOBERANO ABSOLUTO DO CAOS E DO VÉU PARTIDO",
		"CHEFE FINAL · O ÚLTIMO RITUAL COMEÇOU",
		true
	)
	if hud.boss_intro_tween and hud.boss_intro_tween.is_valid():
		hud.boss_intro_tween.kill()
	hud.boss_intro.modulate = Color.WHITE
	hud.boss_intro.show()
	await _settle()
	_inside_viewport(hud.boss_panel, viewport_size, "Boss/Barra")
	_inside_viewport(hud.boss_intro_band, viewport_size, "Boss/Banner")
	_inside_viewport(hud.boss_intro_label, viewport_size, "Boss/Texto")
	print(
		"LAYOUT %s BOSS panel=%dx%d intro=%dx%d cols=-"
		% [
			_viewport_tag(viewport_size), roundi(hud.boss_panel.size.x), roundi(hud.boss_panel.size.y),
			roundi(hud.boss_intro_band.size.x), roundi(hud.boss_intro_band.size.y),
		]
	)
	await _capture(viewport, "boss_" + _viewport_tag(viewport_size))


func _validate_hud_layouts(viewport_size: Vector2i) -> void:
	var viewport := _new_viewport(viewport_size)
	var hud = HUD_SCENE.instantiate()
	viewport.add_child(hud)
	await _settle()
	await _validate_upgrade(hud, viewport, viewport_size)
	await _validate_pause(hud, viewport, viewport_size)
	await _validate_stage_banner(hud, viewport, viewport_size)
	await _validate_boss_banner(hud, viewport, viewport_size)
	paused = false
	root.remove_child(viewport)
	viewport.queue_free()
	await process_frame


func _run() -> void:
	for viewport_size in VIEWPORT_SIZES:
		await _validate_menu_layouts(viewport_size)
		await _validate_hud_layouts(viewport_size)
	paused = false
	if failures.is_empty():
		var validation_mode := "com capturas reais" if not capture_dir.is_empty() else "dimensionalmente"
		print("RESPONSIVE LAYOUT OK: 7 estados validados %s em 5 resoluções" % validation_mode)
		quit(0)
	else:
		quit(1)
