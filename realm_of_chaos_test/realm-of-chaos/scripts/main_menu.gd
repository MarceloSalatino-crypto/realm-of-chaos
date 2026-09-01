extends Control

const SaveStoreScript = preload("res://scripts/save_store.gd")
const ProfileHubScript = preload("res://scripts/profile_hub.gd")
const PROFILE_HUB_SCENE = preload("res://scenes/profile_hub.tscn")
const SAVE_PATH := "user://realm_of_chaos.cfg"

var animation_time := 0.0
var popup: Control
var hero_base_y := 0.0
var profile_button: Button
var transitioning := false
var transition_fade: ColorRect
var save_path := SAVE_PATH
var save_load_status := SaveStoreScript.STATUS_MISSING
var save_load_notice_shown := false
var last_save_error := OK

@onready var hero: TextureRect = $Hero
@onready var play_button: Button = $Menu/Play
@onready var records_label: Label = $Menu/Records


func _ready() -> void:
	get_tree().paused = false
	profile_button = $Menu/Profile
	play_button.pressed.connect(_on_play)
	profile_button.pressed.connect(_show_profile)
	$Menu/Instructions.pressed.connect(_show_instructions)
	$Menu/Credits.pressed.connect(_show_credits)
	$Menu.move_child(profile_button, 1)
	$Menu.add_theme_constant_override("separation", 6)
	_load_records()
	resized.connect(_update_main_layout)
	_update_main_layout()
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


func _update_main_layout() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var compact := size.x <= 800.0
	var short_view := not compact and size.y <= 576.0
	var eyebrow := $Eyebrow as Label
	var title := $Title as Label
	var subtitle := $Subtitle as Label
	var menu_box := $Menu as VBoxContainer
	var instructions := $Menu/Instructions as Button
	var credits := $Menu/Credits as Button
	if compact:
		eyebrow.hide()
		subtitle.hide()
		title.position = Vector2(24.0, 14.0)
		title.size = Vector2(310.0, 88.0)
		title.add_theme_font_size_override("font_size", 32)
		menu_box.position = Vector2(24.0, 118.0)
		menu_box.size = Vector2(270.0, 190.0)
		menu_box.add_theme_constant_override("separation", 4)
		play_button.custom_minimum_size.y = 42.0
		profile_button.custom_minimum_size.y = 32.0
		instructions.custom_minimum_size.y = 32.0
		credits.custom_minimum_size.y = 32.0
		records_label.add_theme_font_size_override("font_size", 9)
		hero.anchor_left = 0.48
		hero.anchor_top = 0.0
		hero.anchor_right = 1.0
		hero.anchor_bottom = 1.0
		hero.offset_left = 0.0
		hero.offset_top = 15.0
		hero.offset_right = -5.0
		hero.offset_bottom = 35.0
	else:
		eyebrow.show()
		subtitle.show()
		eyebrow.position = Vector2(70.0, 28.0 if short_view else 65.0)
		eyebrow.size = Vector2(490.0, 30.0)
		title.position = Vector2(64.0, 58.0 if short_view else 98.0)
		title.size = Vector2(656.0, 132.0 if short_view else 152.0)
		title.add_theme_font_size_override("font_size", 54 if short_view else 69)
		subtitle.position = Vector2(70.0, 218.0 if short_view else 296.0)
		subtitle.size = Vector2(540.0, 56.0)
		menu_box.position = Vector2(70.0, 285.0 if short_view else 370.0)
		menu_box.size = Vector2(438.0, 270.0 if short_view else 334.0)
		menu_box.add_theme_constant_override("separation", 4 if short_view else 6)
		play_button.custom_minimum_size.y = 50.0 if short_view else 60.0
		profile_button.custom_minimum_size.y = 36.0 if short_view else 43.0
		instructions.custom_minimum_size.y = 36.0 if short_view else 43.0
		credits.custom_minimum_size.y = 36.0 if short_view else 43.0
		records_label.add_theme_font_size_override("font_size", 11 if short_view else 13)
		hero.anchor_left = 0.48
		hero.anchor_top = 0.0
		hero.anchor_right = 1.0
		hero.anchor_bottom = 1.0
		hero.offset_left = 25.0
		hero.offset_top = 20.0 if short_view else 50.0
		hero.offset_right = -25.0
		hero.offset_bottom = 20.0 if short_view else 55.0
	hero_base_y = hero.position.y


func _on_play() -> void:
	if transitioning:
		return
	transitioning = true
	play_button.disabled = true
	transition_fade = ColorRect.new()
	transition_fade.color = Color(0.01, 0.004, 0.025, 0.0)
	transition_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_fade.z_index = 100
	add_child(transition_fade)
	var tween := create_tween()
	tween.tween_property(transition_fade, "color", Color(0.01, 0.004, 0.025, 1.0), 0.32)
	tween.tween_callback(_open_campaign)


func _open_campaign() -> void:
	var transition_guard = get_node_or_null("/root/SceneTransitionGuard")
	var error: Error = transition_guard.change_scene_to_file("res://scenes/campaign_select.tscn") if transition_guard != null else get_tree().change_scene_to_file("res://scenes/campaign_select.tscn")
	if error == OK:
		return
	transitioning = false
	play_button.disabled = false
	if is_instance_valid(transition_fade):
		transition_fade.queue_free()
	transition_fade = null


func _load_records() -> void:
	var config := _load_save_config(true)
	var selected_character := str(config.get_value("profile", "character", "eclipse_hunter"))
	_update_hero_character(selected_character)
	if save_load_status in [SaveStoreScript.STATUS_MISSING, SaveStoreScript.STATUS_FAILED]:
		records_label.text = "SEU PRIMEIRO RITUAL AGUARDA"
		return
	var best_time := float(config.get_value("record", "best_time", 0.0))
	var best_kills := int(config.get_value("record", "best_kills", 0))
	var victories := int(config.get_value("record", "victories", 0))
	var essence := int(config.get_value("meta", "essence", 0))
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	var current_map_name := "BOSQUE PROFANADO"
	if campaign_manager != null:
		campaign_manager.load_progress(save_path, false)
		current_map_name = str(campaign_manager.selected_map().name)
	var fullscreen := bool(config.get_value("settings", "fullscreen", false))
	if not OS.has_feature("headless"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	@warning_ignore("integer_division")
	records_label.text = "%s · %d ESSÊNCIAS\nRECORDE %02d:%02d · %d BANIDOS · %d VITÓRIAS" % [
		current_map_name, essence, int(best_time) / 60, int(best_time) % 60, best_kills, victories
	]


func _update_hero_character(character_id: String) -> void:
	hero.texture = ProfileHubScript.character_frame(character_id)
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.modulate = Color.WHITE


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


# Fachada preservada para chamadas e testes anteriores.
func _show_meta_progression() -> void:
	_show_profile_hub(ProfileHubScript.TAB_LEGACY)


func _show_profile() -> void:
	_show_profile_hub(ProfileHubScript.TAB_HUNTERS)


func _show_profile_hub(initial_tab: String) -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = PROFILE_HUB_SCENE.instantiate()
	add_child(popup)
	popup.call("setup", self, initial_tab)


func _refresh_profile_hub(preferred_tab := "") -> void:
	if is_instance_valid(popup) and popup.has_method("refresh"):
		popup.call("refresh", preferred_tab)


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
		_refresh_profile_hub(ProfileHubScript.TAB_LEGACY)
		return


func _select_character(character_id: String) -> void:
	var config := _load_save_config()
	config.set_value("profile", "version", 2)
	config.set_value("profile", "character", character_id)
	if not _save_config_safely(config):
		return
	_update_hero_character(character_id)
	_refresh_profile_hub(ProfileHubScript.TAB_HUNTERS)


func _cycle_setting(setting_id: String) -> void:
	var config := _load_save_config()
	var current := float(config.get_value("settings", setting_id, GameDefs.default_settings()[setting_id]))
	var next_value := snappedf(current + 0.25, 0.25)
	if next_value > 1.0:
		next_value = 0.0
	config.set_value("settings", setting_id, next_value)
	if not _save_config_safely(config):
		return
	_refresh_profile_hub(ProfileHubScript.TAB_OPTIONS)


func _toggle_fullscreen() -> void:
	var config := _load_save_config()
	var fullscreen := not bool(config.get_value("settings", "fullscreen", false))
	config.set_value("settings", "fullscreen", fullscreen)
	if not _save_config_safely(config):
		return
	if not OS.has_feature("headless"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	_refresh_profile_hub(ProfileHubScript.TAB_OPTIONS)


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
		box.add_theme_constant_override("separation", int(roundf(clampf(viewport_size.y * 0.025, 8.0, 24.0))))
		heading.add_theme_font_size_override(
			"font_size", int(roundf(clampf(minf(viewport_size.x * 0.055, viewport_size.y * 0.052), 22.0, 34.0)))
		)
		body.add_theme_font_size_override("font_size", int(roundf(clampf(viewport_size.y * 0.029, 14.0, 19.0))))
		close.custom_minimum_size = Vector2(0.0, roundf(clampf(viewport_size.y * 0.07, 40.0, 48.0)))
	content_popup.resized.connect(update_popup_layout)
	update_popup_layout.call()
	update_popup_layout.call_deferred()
	close.grab_focus()
