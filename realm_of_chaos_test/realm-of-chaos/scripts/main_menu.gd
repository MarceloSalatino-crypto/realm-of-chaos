extends Control

const GameDefs = preload("res://scripts/game_defs.gd")
const SAVE_PATH := "user://realm_of_chaos.cfg"

var animation_time := 0.0
var popup: Control
var hero_base_y := 0.0
var profile_button: Button
var transitioning := false

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
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
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


func _show_instructions() -> void:
	_show_popup(
		"COMO SOBREVIVER",
		"WASD, SETAS OU ANALÓGICO\nMova o Caçador; a arma inicial é sorteada e ataca automaticamente.\n\nESPAÇO / BOTÃO A · ESQUIVA + HABILIDADE\nAtravesse a horda com um impulso invulnerável e ative o poder exclusivo do personagem.\n\nMAPA E SANTUÁRIOS\nO minimapa mostra marcos, chefes e baús. M oculta ou exibe. Explore os quatro santuários para receber bênçãos temporárias.\n\nEVOLUA ARMAS E RELÍQUIAS\nAs cartas mostram as combinações de evolução. Use reroll, banimento ou pular para controlar sua build de até seis armas.\n\nRITUAL DE 25 MINUTOS\nChefes surgem em 5, 10, 15, 20 e 25 minutos. Raízes atrasam, gelo reduz controle e fendas causam dano. ESC pausa."
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
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-440, -305)
	panel.size = Vector2(880, 610)
	popup.add_child(panel)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("171126")
	panel_style.border_color = Color("7e52bb")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var essence := int(config.get_value("meta", "essence", 0))
	var heading := Label.new()
	heading.text = "LEGADO DO CAÇADOR"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color("ffd36b"))
	box.add_child(heading)
	var balance := Label.new()
	balance.text = "ESSÊNCIA DISPONÍVEL  %d" % essence
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance.add_theme_font_size_override("font_size", 18)
	balance.add_theme_color_override("font_color", Color("c89aff"))
	box.add_child(balance)
	for definition in GameDefs.meta_upgrades():
		var level := int(config.get_value("meta", str(definition.id), 0))
		var cost := GameDefs.meta_cost(definition, level)
		var button := Button.new()
		button.custom_minimum_size.y = 74.0
		button.text = "%s  ·  NÍVEL %d/%d\n%s  ·  CUSTO %d" % [definition.title, level, definition.max, definition.description, cost]
		button.disabled = level >= int(definition.max) or essence < cost
		button.pressed.connect(_buy_meta_upgrade.bind(str(definition.id)))
		box.add_child(button)
	var close := Button.new()
	close.text = "VOLTAR"
	close.custom_minimum_size.y = 48
	close.pressed.connect(func(): popup.queue_free())
	box.add_child(close)
	close.grab_focus()


func _buy_meta_upgrade(upgrade_id: String) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
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
		config.save(SAVE_PATH)
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
	panel.position = Vector2(-510.0, -335.0)
	panel.size = Vector2(1020.0, 670.0)
	popup.add_child(panel)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("171126")
	panel_style.border_color = Color("8f61c7")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = "PERFIL DO RITUAL"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("ffd36b"))
	box.add_child(heading)
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var selected := str(config.get_value("profile", "character", "eclipse_hunter"))
	var character_heading := Label.new()
	character_heading.text = "CAÇADOR ATIVO · escolha seu estilo"
	character_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_heading.add_theme_font_size_override("font_size", 17)
	character_heading.add_theme_color_override("font_color", Color("cba8ef"))
	box.add_child(character_heading)
	var character_row := HBoxContainer.new()
	character_row.add_theme_constant_override("separation", 8)
	box.add_child(character_row)
	for definition in GameDefs.characters():
		var button := Button.new()
		button.custom_minimum_size = Vector2(230.0, 105.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s%s\n%s\n%s" % ["◆ " if selected == str(definition.id) else "", definition.title, definition.role, definition.description]
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", definition.color)
		button.disabled = selected == str(definition.id)
		button.pressed.connect(_select_character.bind(str(definition.id)))
		character_row.add_child(button)
	var achievement_heading := Label.new()
	achievement_heading.text = "CONQUISTAS"
	achievement_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievement_heading.add_theme_font_size_override("font_size", 17)
	achievement_heading.add_theme_color_override("font_color", Color("cba8ef"))
	box.add_child(achievement_heading)
	var achievement_text := Label.new()
	var lines: Array[String] = []
	for definition in GameDefs.achievements():
		var unlocked := bool(config.get_value("achievements", str(definition.id), false))
		lines.append("%s %s — %s" % ["✓" if unlocked else "○", definition.title, definition.description])
	achievement_text.text = "\n".join(lines)
	achievement_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievement_text.add_theme_font_size_override("font_size", 13)
	achievement_text.add_theme_color_override("font_color", Color("ded5e9"))
	box.add_child(achievement_text)
	var settings_heading := Label.new()
	settings_heading.text = "ACESSIBILIDADE E ÁUDIO"
	settings_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_heading.add_theme_font_size_override("font_size", 17)
	settings_heading.add_theme_color_override("font_color", Color("cba8ef"))
	box.add_child(settings_heading)
	var settings_row := HBoxContainer.new()
	settings_row.add_theme_constant_override("separation", 8)
	box.add_child(settings_row)
	for setting in [
		{"id": "music", "title": "MÚSICA"}, {"id": "sfx", "title": "EFEITOS"},
		{"id": "shake", "title": "TREMORES"}, {"id": "flash", "title": "FLASHES"}
	]:
		var setting_button := Button.new()
		var default_value := float(GameDefs.default_settings()[setting.id])
		var value := float(config.get_value("settings", setting.id, default_value))
		setting_button.text = "%s\n%d%%" % [setting.title, roundi(value * 100.0)]
		setting_button.custom_minimum_size = Vector2(155.0, 58.0)
		setting_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		setting_button.pressed.connect(_cycle_setting.bind(str(setting.id)))
		settings_row.add_child(setting_button)
	var fullscreen_button := Button.new()
	var fullscreen := bool(config.get_value("settings", "fullscreen", false))
	fullscreen_button.text = "TELA\n%s" % ("CHEIA" if fullscreen else "JANELA")
	fullscreen_button.custom_minimum_size = Vector2(155.0, 58.0)
	fullscreen_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	settings_row.add_child(fullscreen_button)
	var close := Button.new()
	close.text = "VOLTAR"
	close.custom_minimum_size.y = 42.0
	close.pressed.connect(func(): popup.queue_free())
	box.add_child(close)
	close.grab_focus()


func _select_character(character_id: String) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("profile", "version", 2)
	config.set_value("profile", "character", character_id)
	config.save(SAVE_PATH)
	hero.modulate = GameDefs.character_data(character_id).color
	_show_profile()


func _cycle_setting(setting_id: String) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var current := float(config.get_value("settings", setting_id, GameDefs.default_settings()[setting_id]))
	var next := snappedf(current + 0.25, 0.25)
	if next > 1.0:
		next = 0.0
	config.set_value("settings", setting_id, next)
	config.save(SAVE_PATH)
	_show_profile()


func _toggle_fullscreen() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var fullscreen := not bool(config.get_value("settings", "fullscreen", false))
	config.set_value("settings", "fullscreen", fullscreen)
	config.save(SAVE_PATH)
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
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-390, -250)
	panel.size = Vector2(780, 500)
	popup.add_child(panel)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("171126")
	panel_style.border_color = Color("7e52bb")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_bottom", 38)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color("ffd36b"))
	box.add_child(heading)
	var body := Label.new()
	body.text = content
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", Color("ddd4ec"))
	box.add_child(body)
	var close := Button.new()
	close.text = "FECHAR"
	close.custom_minimum_size.y = 48
	close.pressed.connect(func(): popup.queue_free())
	box.add_child(close)
	close.grab_focus()
