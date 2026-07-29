extends Control

const GameDefs = preload("res://scripts/game_defs.gd")
const SaveStoreScript = preload("res://scripts/save_store.gd")
const SAVE_PATH := "user://realm_of_chaos.cfg"

var animation_time := 0.0
var popup: Control
var hero_base_y := 0.0
var profile_button: Button
var transitioning := false
var save_path := SAVE_PATH
var save_load_status := SaveStoreScript.STATUS_MISSING
var save_load_notice_shown := false
var last_save_error := OK

@onready var hero: TextureRect = $Hero
@onready var play_button: Button = $Menu/Play
@onready var records_label: Label = $Menu/Records


func _ready() -> void:
	get_tree().paused = false
	hero_base_y = hero.position.y
	play_button.pressed.connect(_on_play)
	$Menu/Instructions.pressed.connect(_show_instructions)
	$Menu/Meta.pressed.connect(_show_meta_progression)
	$Menu/Credits.pressed.connect(_show_credits)
	profile_button = $Menu/Credits.duplicate()
	profile_button.name = "Profile"
	profile_button.text = "CAÇADORES, OPÇÕES E CONQUISTAS"
	$Menu.add_child(profile_button)
	$Menu.move_child(profile_button, $Menu/Credits.get_index())
	profile_button.pressed.connect(_show_profile)
	$Menu.add_theme_constant_override("separation", 6)
	play_button.custom_minimum_size.y = 60.0
	for button in [$Menu/Instructions, $Menu/Meta, profile_button, $Menu/Credits]:
		button.custom_minimum_size.y = 43.0
	_load_records()
	if OS.has_feature("editor"):
		var editor_hint := Label.new()
		editor_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		editor_hint.position = Vector2(24.0, -34.0)
		editor_hint.size = Vector2(650.0, 22.0)
		editor_hint.text = "F5 abre este menu · F6 executa somente a cena aberta"
		editor_hint.add_theme_font_size_override("font_size", 12)
		editor_hint.add_theme_color_override("font_color", Color(0.54, 0.47, 0.62, 0.82))
		add_child(editor_hint)
	play_button.grab_focus()


func _process(delta: float) -> void:
	animation_time += delta
	hero.position.y = hero_base_y + sin(animation_time * 1.5) * 7.0
	hero.rotation = sin(animation_time * 0.8) * 0.006
	$Runes.modulate.a = 0.46 + (sin(animation_time * 0.62) + 1.0) * 0.12


func _on_play() -> void:
	if transitioning:
		return
	transitioning = true
	play_button.disabled = true
	var fade := ColorRect.new()
	fade.color = Color(0.01, 0.004, 0.025, 0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.z_index = 100
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color", Color(0.01, 0.004, 0.025, 1.0), 0.32)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/world.tscn"))


func _load_records() -> void:
	var config := _load_save_config(true)
	if save_load_status in [SaveStoreScript.STATUS_MISSING, SaveStoreScript.STATUS_FAILED]:
		records_label.text = "SEU PRIMEIRO RITUAL AGUARDA"
		return
	var best_time := float(config.get_value("record", "best_time", 0.0))
	var best_kills := int(config.get_value("record", "best_kills", 0))
	var victories := int(config.get_value("record", "victories", 0))
	var essence := int(config.get_value("meta", "essence", 0))
	var cycle := int(config.get_value("progress", "active_cycle", 0))
	var selected_character := str(config.get_value("profile", "character", "eclipse_hunter"))
	hero.modulate = GameDefs.character_data(selected_character).color
	var fullscreen := bool(config.get_value("settings", "fullscreen", false))
	if not OS.has_feature("headless"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	@warning_ignore("integer_division")
	records_label.text = "%s · %d ESSÊNCIAS\nRECORDE %02d:%02d · %d BANIDOS · %d VITÓRIAS" % [
		str(GameDefs.biome_data(cycle).name), essence, int(best_time) / 60, int(best_time) % 60, best_kills, victories
	]


func _load_save_config(notify := true) -> ConfigFile:
	var result := SaveStoreScript.load_config(save_path)
	save_load_status = str(result.status)
	if (
		notify
		and not save_load_notice_shown
		and save_load_status in [SaveStoreScript.STATUS_RECOVERED, SaveStoreScript.STATUS_FAILED]
	):
		save_load_notice_shown = true
		var title := "PROGRESSO RECUPERADO" if save_load_status == SaveStoreScript.STATUS_RECOVERED else "AVISO DE PROGRESSO"
		call_deferred("_show_save_notice", title, str(result.message))
	return result.config


func _save_config_safely(config: ConfigFile) -> bool:
	last_save_error = SaveStoreScript.save_config(config, save_path)
	if last_save_error == OK:
		return true
	push_warning("Não foi possível salvar o progresso pelo menu (erro %d)." % last_save_error)
	_show_save_notice(
		"FALHA AO SALVAR",
		"Não foi possível salvar suas alterações.\nSeu progresso anterior e o backup foram mantidos."
	)
	return false


func _show_save_notice(title: String, message: String) -> void:
	if is_inside_tree():
		_show_popup(title, message)


func _show_instructions() -> void:
	_show_popup(
		"COMO SOBREVIVER",
		"WASD, SETAS OU ANALÓGICO\nMova o Caçador; cada caçador possui uma arma inicial própria que ataca automaticamente.\n\nESPAÇO / BOTÃO A · ESQUIVA + HABILIDADE\nAtravesse a horda com um impulso invulnerável e ative o poder exclusivo do personagem.\n\nMAPA E SANTUÁRIOS\nO minimapa mostra marcos, chefes e baús. M oculta ou exibe. Explore os quatro santuários para receber bênçãos temporárias.\n\nEVOLUA ARMAS E RELÍQUIAS\nAs cartas mostram as combinações de evolução. Escolha uma das três cartas apresentadas para desenvolver sua build de até seis armas.\n\nRITUAL DE 25 MINUTOS\nChefes surgem em 5, 10, 15, 20 e 25 minutos. Raízes atrasam, gelo reduz controle e fendas causam dano. ESC pausa."
	)


func _show_meta_progression() -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(popup)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.01, 0.035, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(shade)
	var panel := PanelContainer.new()
	panel.name = "MetaPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	popup.add_child(panel)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("171126")
	panel_style.border_color = Color("7e52bb")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "VBox"
	margin.add_child(box)
	var config := _load_save_config()
	var essence := int(config.get_value("meta", "essence", 0))
	var heading := Label.new()
	heading.name = "Title"
	heading.text = "LEGADO DO CAÇADOR"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_color_override("font_color", Color("ffd36b"))
	box.add_child(heading)
	var balance := Label.new()
	balance.name = "Balance"
	balance.text = "ESSÊNCIA DISPONÍVEL  %d" % essence
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	balance.add_theme_color_override("font_color", Color("c89aff"))
	box.add_child(balance)
	var meta_scroll := ScrollContainer.new()
	meta_scroll.name = "UpgradeScroll"
	meta_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	meta_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	meta_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meta_scroll.focus_mode = Control.FOCUS_ALL
	meta_scroll.follow_focus = true
	meta_scroll.scroll_vertical_custom_step = 34.0
	box.add_child(meta_scroll)
	var upgrade_box := VBoxContainer.new()
	upgrade_box.name = "Upgrades"
	upgrade_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_scroll.add_child(upgrade_box)
	var upgrade_buttons: Array[Button] = []
	for definition in GameDefs.meta_upgrades():
		var level := int(config.get_value("meta", str(definition.id), 0))
		var cost := GameDefs.meta_cost(definition, level)
		var button := Button.new()
		button.name = "Upgrade_%s" % str(definition.id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s  ·  NÍVEL %d/%d\n%s  ·  CUSTO %d" % [definition.title, level, definition.max, definition.description, cost]
		button.disabled = level >= int(definition.max) or essence < cost
		button.pressed.connect(_buy_meta_upgrade.bind(str(definition.id)))
		upgrade_box.add_child(button)
		upgrade_buttons.append(button)
	var close := Button.new()
	close.name = "Close"
	close.text = "VOLTAR"
	close.pressed.connect(func(): popup.queue_free())
	box.add_child(close)
	var meta_popup := popup
	var update_meta_layout := func() -> void:
		if not is_instance_valid(meta_popup) or not is_instance_valid(panel):
			return
		var viewport_size := meta_popup.size
		if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
			return
		var horizontal_inset := clampf(viewport_size.x * 0.035, 12.0, 40.0)
		var vertical_inset := clampf(viewport_size.y * 0.035, 8.0, 28.0)
		var panel_size := Vector2(
			minf(880.0, maxf(1.0, viewport_size.x - horizontal_inset * 2.0)),
			minf(610.0, maxf(1.0, viewport_size.y - vertical_inset * 2.0))
		)
		panel.size = panel_size
		panel.position = (viewport_size - panel_size) * 0.5
		var horizontal_margin := int(roundf(clampf(viewport_size.x * 0.04, 14.0, 44.0)))
		var vertical_margin := int(roundf(clampf(viewport_size.y * 0.025, 8.0, 30.0)))
		for side in ["margin_left", "margin_right"]:
			margin.add_theme_constant_override(side, horizontal_margin)
		for side in ["margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(side, vertical_margin)
		var spacing := int(roundf(clampf(viewport_size.y * 0.018, 6.0, 12.0)))
		box.add_theme_constant_override("separation", spacing)
		upgrade_box.add_theme_constant_override("separation", spacing)
		heading.add_theme_font_size_override(
			"font_size",
			int(roundf(clampf(minf(viewport_size.x * 0.052, viewport_size.y * 0.05), 22.0, 32.0)))
		)
		balance.add_theme_font_size_override(
			"font_size",
			int(roundf(clampf(viewport_size.y * 0.027, 14.0, 18.0)))
		)
		var upgrade_height := roundf(clampf(viewport_size.y * 0.105, 54.0, 74.0))
		var upgrade_font_size := int(roundf(clampf(viewport_size.y * 0.024, 13.0, 16.0)))
		for button in upgrade_buttons:
			button.custom_minimum_size = Vector2(0.0, upgrade_height)
			button.add_theme_font_size_override("font_size", upgrade_font_size)
		close.custom_minimum_size = Vector2(0.0, roundf(clampf(viewport_size.y * 0.07, 40.0, 48.0)))
	meta_popup.resized.connect(update_meta_layout)
	update_meta_layout.call()
	update_meta_layout.call_deferred()
	close.grab_focus()


func _buy_meta_upgrade(upgrade_id: String) -> void:
	var config := _load_save_config()
	var essence := int(config.get_value("meta", "essence", 0))
	for definition in GameDefs.meta_upgrades():
		if str(definition.id) != upgrade_id:
			continue
		var level := int(config.get_value("meta", upgrade_id, 0))
		var cost := GameDefs.meta_cost(definition, level)
		if level >= int(definition.max) or essence < cost:
			return
		config.set_value("meta", "essence", essence - cost)
		config.set_value("meta", upgrade_id, level + 1)
		if not _save_config_safely(config):
			return
		_load_records()
		_show_meta_progression()
		return


func _show_profile() -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(popup)
	var shade := ColorRect.new()
	shade.color = Color(0.012, 0.006, 0.03, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	popup.add_child(panel)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("171126")
	panel_style.border_color = Color("8f61c7")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = "PERFIL DO RITUAL"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("ffd36b"))
	box.add_child(heading)
	var profile_scroll := ScrollContainer.new()
	profile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	profile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	profile_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile_scroll.focus_mode = Control.FOCUS_ALL
	profile_scroll.scroll_vertical_custom_step = 34.0
	box.add_child(profile_scroll)
	var content_box := VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 10)
	profile_scroll.add_child(content_box)
	var config := _load_save_config()
	var selected := str(config.get_value("profile", "character", "eclipse_hunter"))
	var character_heading := Label.new()
	character_heading.text = "CAÇADOR ATIVO · escolha seu estilo"
	character_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_heading.add_theme_font_size_override("font_size", 17)
	character_heading.add_theme_color_override("font_color", Color("cba8ef"))
	content_box.add_child(character_heading)
	var character_grid := GridContainer.new()
	character_grid.columns = 4
	character_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_grid.add_theme_constant_override("h_separation", 8)
	character_grid.add_theme_constant_override("v_separation", 8)
	content_box.add_child(character_grid)
	for definition in GameDefs.characters():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 124.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s%s\n%s\n%s" % ["◆ " if selected == str(definition.id) else "", definition.title, definition.role, definition.description]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", definition.color)
		button.disabled = selected == str(definition.id)
		button.pressed.connect(_select_character.bind(str(definition.id)))
		character_grid.add_child(button)
	var achievement_heading := Label.new()
	achievement_heading.text = "CONQUISTAS"
	achievement_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievement_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	achievement_heading.add_theme_font_size_override("font_size", 17)
	achievement_heading.add_theme_color_override("font_color", Color("cba8ef"))
	content_box.add_child(achievement_heading)
	var achievement_text := Label.new()
	var lines: Array[String] = []
	for definition in GameDefs.achievements():
		var unlocked := bool(config.get_value("achievements", str(definition.id), false))
		lines.append("%s %s — %s" % ["✓" if unlocked else "○", definition.title, definition.description])
	achievement_text.text = "\n".join(lines)
	achievement_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievement_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	achievement_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_text.add_theme_font_size_override("font_size", 13)
	achievement_text.add_theme_color_override("font_color", Color("ded5e9"))
	content_box.add_child(achievement_text)
	var settings_heading := Label.new()
	settings_heading.text = "ACESSIBILIDADE E ÁUDIO"
	settings_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_heading.add_theme_font_size_override("font_size", 17)
	settings_heading.add_theme_color_override("font_color", Color("cba8ef"))
	content_box.add_child(settings_heading)
	var settings_grid := GridContainer.new()
	settings_grid.columns = 5
	settings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_grid.add_theme_constant_override("h_separation", 8)
	settings_grid.add_theme_constant_override("v_separation", 8)
	content_box.add_child(settings_grid)
	for setting in [
		{"id": "music", "title": "MÚSICA"}, {"id": "sfx", "title": "EFEITOS"},
		{"id": "shake", "title": "TREMORES"}, {"id": "flash", "title": "FLASHES"}
	]:
		var setting_button := Button.new()
		var default_value := float(GameDefs.default_settings()[setting.id])
		var value := float(config.get_value("settings", setting.id, default_value))
		setting_button.text = "%s\n%d%%" % [setting.title, roundi(value * 100.0)]
		setting_button.custom_minimum_size = Vector2(0.0, 58.0)
		setting_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		setting_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		setting_button.pressed.connect(_cycle_setting.bind(str(setting.id)))
		settings_grid.add_child(setting_button)
	var fullscreen_button := Button.new()
	var fullscreen := bool(config.get_value("settings", "fullscreen", false))
	fullscreen_button.text = "TELA\n%s" % ("CHEIA" if fullscreen else "JANELA")
	fullscreen_button.custom_minimum_size = Vector2(0.0, 58.0)
	fullscreen_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullscreen_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	settings_grid.add_child(fullscreen_button)
	var close := Button.new()
	close.text = "VOLTAR"
	close.custom_minimum_size.y = 42.0
	close.pressed.connect(func(): popup.queue_free())
	box.add_child(close)
	var profile_popup := popup
	var update_profile_layout := func() -> void:
		if not is_instance_valid(profile_popup) or not is_instance_valid(panel):
			return
		var viewport_size := profile_popup.size
		var horizontal_inset := clampf(viewport_size.x * 0.035, 12.0, 40.0)
		var vertical_inset := clampf(viewport_size.y * 0.035, 12.0, 28.0)
		var panel_size := Vector2(
			minf(1120.0, maxf(1.0, viewport_size.x - horizontal_inset * 2.0)),
			minf(680.0, maxf(1.0, viewport_size.y - vertical_inset * 2.0))
		)
		panel.size = panel_size
		panel.position = (viewport_size - panel_size) * 0.5
		var content_width := maxf(1.0, panel_size.x - 70.0)
		character_grid.columns = 4 if content_width >= 900.0 else (2 if content_width >= 430.0 else 1)
		settings_grid.columns = 5 if content_width >= 780.0 else (3 if content_width >= 460.0 else (2 if content_width >= 300.0 else 1))
	profile_popup.resized.connect(update_profile_layout)
	update_profile_layout.call()
	update_profile_layout.call_deferred()
	close.grab_focus()


func _select_character(character_id: String) -> void:
	var config := _load_save_config()
	config.set_value("profile", "version", 2)
	config.set_value("profile", "character", character_id)
	if not _save_config_safely(config):
		return
	hero.modulate = GameDefs.character_data(character_id).color
	_show_profile()


func _cycle_setting(setting_id: String) -> void:
	var config := _load_save_config()
	var current := float(config.get_value("settings", setting_id, GameDefs.default_settings()[setting_id]))
	var next := snappedf(current + 0.25, 0.25)
	if next > 1.0:
		next = 0.0
	config.set_value("settings", setting_id, next)
	if not _save_config_safely(config):
		return
	_show_profile()


func _toggle_fullscreen() -> void:
	var config := _load_save_config()
	var fullscreen := not bool(config.get_value("settings", "fullscreen", false))
	config.set_value("settings", "fullscreen", fullscreen)
	if not _save_config_safely(config):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	_show_profile()


func _show_credits() -> void:
	_show_popup(
		"CRÉDITOS",
		"Realm of Chaos\n\nConceito original de Marcelo Galimberti Salatino e Bruno Aloy\n\nEngine: Godot 4\nDireção e implementação desta evolução: colaboração com Codex\nArte adicional: assets originais gerados para este projeto\n\nInspirado pelo gênero survivor, com identidade visual própria."
	)


func _show_popup(title: String, content: String) -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(popup)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.01, 0.035, 0.90)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(shade)
	var panel := PanelContainer.new()
	panel.name = "PopupPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	popup.add_child(panel)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("171126")
	panel_style.border_color = Color("7e52bb")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "VBox"
	margin.add_child(box)
	var heading := Label.new()
	heading.name = "Title"
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_color_override("font_color", Color("ffd36b"))
	box.add_child(heading)
	var body_scroll := ScrollContainer.new()
	body_scroll.name = "BodyScroll"
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.focus_mode = Control.FOCUS_ALL
	body_scroll.scroll_vertical_custom_step = 32.0
	box.add_child(body_scroll)
	var body := Label.new()
	body.name = "Body"
	body.text = content
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("font_color", Color("ddd4ec"))
	body_scroll.add_child(body)
	var close := Button.new()
	close.name = "Close"
	close.text = "FECHAR"
	close.pressed.connect(func(): popup.queue_free())
	box.add_child(close)
	var content_popup := popup
	var update_popup_layout := func() -> void:
		if not is_instance_valid(content_popup) or not is_instance_valid(panel):
			return
		var viewport_size := content_popup.size
		if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
			return
		var horizontal_inset := clampf(viewport_size.x * 0.035, 12.0, 38.0)
		var vertical_inset := clampf(viewport_size.y * 0.035, 8.0, 26.0)
		var panel_size := Vector2(
			minf(780.0, maxf(1.0, viewport_size.x - horizontal_inset * 2.0)),
			minf(500.0, maxf(1.0, viewport_size.y - vertical_inset * 2.0))
		)
		panel.size = panel_size
		panel.position = (viewport_size - panel_size) * 0.5
		var horizontal_margin := int(roundf(clampf(viewport_size.x * 0.045, 18.0, 46.0)))
		var vertical_margin := int(roundf(clampf(viewport_size.y * 0.035, 10.0, 38.0)))
		for side in ["margin_left", "margin_right"]:
			margin.add_theme_constant_override(side, horizontal_margin)
		for side in ["margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(side, vertical_margin)
		box.add_theme_constant_override(
			"separation",
			int(roundf(clampf(viewport_size.y * 0.025, 8.0, 24.0)))
		)
		heading.add_theme_font_size_override(
			"font_size",
			int(roundf(clampf(minf(viewport_size.x * 0.055, viewport_size.y * 0.052), 22.0, 34.0)))
		)
		body.add_theme_font_size_override(
			"font_size",
			int(roundf(clampf(viewport_size.y * 0.029, 14.0, 19.0)))
		)
		close.custom_minimum_size = Vector2(0.0, roundf(clampf(viewport_size.y * 0.07, 40.0, 48.0)))
	content_popup.resized.connect(update_popup_layout)
	update_popup_layout.call()
	update_popup_layout.call_deferred()
	close.grab_focus()
