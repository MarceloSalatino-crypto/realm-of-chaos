extends Control

const TAB_HUNTERS := "hunters"
const TAB_LEGACY := "legacy"
const TAB_ACHIEVEMENTS := "achievements"
const TAB_OPTIONS := "options"
const VALID_TABS := [TAB_HUNTERS, TAB_LEGACY, TAB_ACHIEVEMENTS, TAB_OPTIONS]

const GOLD := Color("f1c66a")
const VIOLET := Color("a77ae0")
const CYAN := Color("72d7e8")
const TEXT := Color("e9e1f1")
const MUTED := Color("9b8da8")
const PANEL := Color("170d22f4")
const PANEL_LIGHT := Color("261534f2")
const BORDER := Color("69418a")

const CHARACTER_SHEETS := {
	"eclipse_hunter": preload("res://assets/generated/hero_anim_chaos_bolt.png"),
	"glacial_oracle": preload("res://assets/generated/hero_anim_soul_orbit.png"),
	"crimson_knight": preload("res://assets/generated/hero_anim_shadow_blades.png"),
	"void_automaton": preload("res://assets/generated/hero_anim_chaos_nova.png"),
}

const LEGACY_ICONS := {
	"power": preload("res://assets/ui/upgrade_icons/might.png"),
	"vitality": preload("res://assets/ui/upgrade_icons/vitality.png"),
	"speed": preload("res://assets/ui/upgrade_icons/swiftness.png"),
	"fortune": preload("res://assets/ui/upgrade_icons/critical.png"),
}

const ACHIEVEMENT_ART := {
	"first_boss": {"texture": preload("res://assets/generated/boss_ossuary_colossus.png"), "hframes": 4, "vframes": 2},
	"boss_slayer": {"texture": preload("res://assets/generated/boss_chaos_sovereign.png"), "hframes": 4, "vframes": 2},
	"survivor": {"texture": preload("res://assets/generated/hero_anim_chaos_bolt.png"), "hframes": 4, "vframes": 2},
	"exterminator": {"texture": preload("res://assets/generated/enemy_anim_prowler.png"), "hframes": 4, "vframes": 1},
	"arsenal": {"texture": preload("res://assets/ui/upgrade_icons/rune_hammer.png"), "hframes": 1, "vframes": 1},
	"untouchable": {"texture": preload("res://assets/generated/hero_anim_shadow_blades.png"), "hframes": 4, "vframes": 2},
	"cartographer": {"texture": preload("res://assets/generated/map_landmarks_v1.png"), "hframes": 4, "vframes": 1},
}

var menu_host: Control
var current_tab := TAB_HUNTERS
var focused_legacy_id := "power"
var config := ConfigFile.new()
var compact := false
var last_layout_key := ""

var panel: PanelContainer
var outer_margin: MarginContainer
var main_column: VBoxContainer
var header: HBoxContainer
var title_label: Label
var subtitle_label: Label
var essence_label: Label
var close_button: Button
var tabs: HBoxContainer
var tab_buttons: Dictionary = {}
var content_panel: PanelContainer
var content_margin: MarginContainer
var content_root: Control

var character_grid: GridContainer
var legacy_list: VBoxContainer
var achievement_grid: GridContainer
var options_grid: GridContainer
var primary_scroll: ScrollContainer


static func character_sheet(character_id: String) -> Texture2D:
	return CHARACTER_SHEETS.get(character_id, CHARACTER_SHEETS.eclipse_hunter) as Texture2D


static func character_frame(character_id: String) -> AtlasTexture:
	return _atlas_frame(character_sheet(character_id), 4, 2)


static func _atlas_frame(source: Texture2D, hframes: int, vframes: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(
		0.0, 0.0,
		float(source.get_width()) / float(maxi(hframes, 1)),
		float(source.get_height()) / float(maxi(vframes, 1))
	)
	return atlas


func _ready() -> void:
	_build_shell()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()


func setup(host: Control, initial_tab := TAB_HUNTERS) -> void:
	menu_host = host
	current_tab = initial_tab if initial_tab in VALID_TABS else TAB_HUNTERS
	refresh()


func refresh(preferred_tab := "") -> void:
	if not preferred_tab.is_empty() and preferred_tab in VALID_TABS:
		current_tab = preferred_tab
	if is_instance_valid(menu_host):
		config = menu_host.call("_load_save_config") as ConfigFile
	_update_header()
	_rebuild_content()


func show_tab(tab_id: String) -> void:
	if tab_id not in VALID_TABS or tab_id == current_tab:
		return
	current_tab = tab_id
	_update_tab_styles()
	_rebuild_content()


func _build_shell() -> void:
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.015, 0.008, 0.025, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD, 2, 12))
	add_child(panel)

	outer_margin = MarginContainer.new()
	outer_margin.name = "Margin"
	panel.add_child(outer_margin)
	main_column = VBoxContainer.new()
	main_column.name = "VBox"
	outer_margin.add_child(main_column)

	header = HBoxContainer.new()
	header.name = "Header"
	main_column.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.name = "TitleBox"
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", -2)
	header.add_child(title_box)
	title_label = _label("PERFIL DO RITUAL", 28, GOLD)
	title_label.name = "Title"
	title_box.add_child(title_label)
	subtitle_label = _label("CAÇADOR, LEGADO E MARCAS DA SUA JORNADA", 12, MUTED)
	subtitle_label.name = "Subtitle"
	title_box.add_child(subtitle_label)
	essence_label = _label("0 ESSÊNCIAS", 14, CYAN)
	essence_label.name = "Essence"
	essence_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(essence_label)
	close_button = _button("FECHAR  ×", false)
	close_button.name = "Close"
	close_button.pressed.connect(_close)
	header.add_child(close_button)

	tabs = HBoxContainer.new()
	tabs.name = "Tabs"
	main_column.add_child(tabs)
	for tab_data in [
		{"id": TAB_HUNTERS, "title": "CAÇADORES"},
		{"id": TAB_LEGACY, "title": "LEGADO"},
		{"id": TAB_ACHIEVEMENTS, "title": "CONQUISTAS"},
		{"id": TAB_OPTIONS, "title": "OPÇÕES"},
	]:
		var tab_id := str(tab_data.id)
		var tab_button := _button(str(tab_data.title), false)
		tab_button.name = "Tab_%s" % tab_id
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.pressed.connect(show_tab.bind(tab_id))
		tabs.add_child(tab_button)
		tab_buttons[tab_id] = tab_button

	content_panel = PanelContainer.new()
	content_panel.name = "ContentPanel"
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override("panel", _style(Color("100918dc"), BORDER, 1, 9))
	main_column.add_child(content_panel)
	content_margin = MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_panel.add_child(content_margin)
	_update_tab_styles()


func _update_responsive_layout() -> void:
	if not is_instance_valid(panel) or size.x <= 1.0 or size.y <= 1.0:
		return
	compact = size.x <= 800.0 or size.y <= 576.0
	var horizontal_inset := 30.0 if size.x >= 1000.0 else (18.0 if size.x >= 800.0 else 10.0)
	var vertical_inset := 24.0 if size.y >= 576.0 else (14.0 if size.y >= 450.0 else 8.0)
	panel.position = Vector2(horizontal_inset, vertical_inset)
	panel.size = Vector2(size.x - horizontal_inset * 2.0, size.y - vertical_inset * 2.0)
	var padding := 18 if not compact else 8
	_set_margins(outer_margin, padding)
	_set_margins(content_margin, 12 if not compact else 6)
	main_column.add_theme_constant_override("separation", 8 if not compact else 4)
	header.custom_minimum_size.y = 50.0 if not compact else 34.0
	title_label.add_theme_font_size_override("font_size", 28 if not compact else 18)
	subtitle_label.add_theme_font_size_override("font_size", 12 if not compact else 8)
	essence_label.add_theme_font_size_override("font_size", 14 if not compact else 10)
	close_button.custom_minimum_size = Vector2(92.0 if not compact else 62.0, 34.0 if not compact else 26.0)
	close_button.add_theme_font_size_override("font_size", 12 if not compact else 8)
	tabs.custom_minimum_size.y = 42.0 if not compact else 29.0
	tabs.add_theme_constant_override("separation", 6 if not compact else 2)
	for tab_button in tab_buttons.values():
		(tab_button as Button).add_theme_font_size_override("font_size", 12 if not compact else 8)
	var layout_key := "%s:%d" % ["compact" if compact else "wide", _content_columns()]
	if layout_key != last_layout_key:
		last_layout_key = layout_key
		_rebuild_content.call_deferred()


func _update_header() -> void:
	essence_label.text = "%d ESSÊNCIAS" % int(config.get_value("meta", "essence", 0))
	_update_tab_styles()


func _update_tab_styles() -> void:
	for tab_id in tab_buttons:
		var tab_button := tab_buttons[tab_id] as Button
		var selected := str(tab_id) == current_tab
		tab_button.add_theme_stylebox_override(
			"normal",
			_style(Color("38204a") if selected else Color("21122e"), GOLD if selected else BORDER, 2 if selected else 1, 7)
		)
		tab_button.add_theme_color_override("font_color", GOLD if selected else TEXT)


func _rebuild_content() -> void:
	if not is_instance_valid(content_margin):
		return
	if is_instance_valid(content_root):
		content_margin.remove_child(content_root)
		content_root.queue_free()
		content_root = null
	character_grid = null
	legacy_list = null
	achievement_grid = null
	options_grid = null
	primary_scroll = null
	match current_tab:
		TAB_LEGACY:
			content_root = _build_legacy()
		TAB_ACHIEVEMENTS:
			content_root = _build_achievements()
		TAB_OPTIONS:
			content_root = _build_options()
		_:
			content_root = _build_hunters()
	content_root.name = "Content"
	content_margin.add_child(content_root)


func _build_hunters() -> Control:
	primary_scroll = ScrollContainer.new()
	primary_scroll.name = "HunterScroll"
	primary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	primary_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	primary_scroll.focus_mode = Control.FOCUS_ALL
	primary_scroll.follow_focus = true
	character_grid = GridContainer.new()
	character_grid.name = "CharacterGrid"
	character_grid.columns = 4 if size.x >= 1000.0 else 2
	character_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_grid.add_theme_constant_override("h_separation", 10 if not compact else 5)
	character_grid.add_theme_constant_override("v_separation", 10 if not compact else 5)
	primary_scroll.add_child(character_grid)
	var selected_id := str(config.get_value("profile", "character", "eclipse_hunter"))
	for definition in GameDefs.characters():
		var character_id := str(definition.id)
		var selected := character_id == selected_id
		var card := PanelContainer.new()
		card.name = "Card_%s" % character_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 430.0 if size.x >= 1000.0 and not compact else (175.0 if not compact else 115.0)
		card.add_theme_stylebox_override(
			"panel", _style(PANEL_LIGHT, Color(definition.color) if selected else BORDER, 3 if selected else 1, 9)
		)
		character_grid.add_child(card)
		var margin := MarginContainer.new()
		_set_margins(margin, 10 if not compact else 5)
		card.add_child(margin)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 5 if not compact else 1)
		margin.add_child(box)
		box.add_child(_texture(character_frame(character_id), 250.0 if size.x >= 1000.0 and not compact else (92.0 if not compact else 52.0)))
		var name_label := _label(str(definition.title), 16 if not compact else 10, Color(definition.color))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(name_label)
		var role_text := str(definition.role).to_upper() + ("  ·  SELECIONADO" if selected else "")
		var role_label := _label(role_text, 11 if not compact else 8, GOLD if selected else MUTED)
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(role_label)
		var detail_label := _label(
			"HABILIDADE  ·  %s\nARMA INICIAL  ·  %s" % [
				str(definition.skill), GameDefs.upgrade_title(str(definition.starting_weapon)).to_upper()
			],
			11 if not compact else 7,
			TEXT
		)
		detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(detail_label)
		var select_button := Button.new()
		select_button.name = "Character_%s" % character_id
		select_button.flat = true
		select_button.disabled = selected
		select_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		select_button.tooltip_text = "Selecionar %s" % str(definition.title).capitalize()
		select_button.pressed.connect(_select_character.bind(character_id))
		card.add_child(select_button)
	return primary_scroll


func _build_legacy() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14 if not compact else 6)
	legacy_list = VBoxContainer.new()
	legacy_list.name = "LegacyList"
	legacy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legacy_list.add_theme_constant_override("separation", 7 if not compact else 3)
	row.add_child(legacy_list)
	for definition in GameDefs.meta_upgrades():
		legacy_list.add_child(_legacy_entry(definition))
	row.add_child(_legacy_focus_panel())
	return row


func _legacy_entry(definition: Dictionary) -> PanelContainer:
	var upgrade_id := str(definition.id)
	var level := int(config.get_value("meta", upgrade_id, 0))
	var next_level := mini(level + 1, int(definition.max))
	var cost := GameDefs.meta_cost(definition, level)
	var essence := int(config.get_value("meta", "essence", 0))
	var focused := upgrade_id == focused_legacy_id
	var entry := PanelContainer.new()
	entry.name = "Legacy_%s" % upgrade_id
	entry.custom_minimum_size.y = 90.0 if not compact else 47.0
	entry.add_theme_stylebox_override(
		"panel", _style(Color("2d183c") if focused else PANEL_LIGHT, GOLD if focused else BORDER, 2 if focused else 1, 7)
	)
	var margin := MarginContainer.new()
	_set_margins(margin, 8 if not compact else 3)
	entry.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8 if not compact else 4)
	margin.add_child(row)
	row.add_child(_texture(LEGACY_ICONS.get(upgrade_id) as Texture2D, 65.0 if not compact else 34.0))
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	text_box.add_child(_label(str(definition.title), 15 if not compact else 9, GOLD if focused else TEXT))
	text_box.add_child(_label("NÍVEL %d/%d  ·  %s" % [level, int(definition.max), _legacy_effect(upgrade_id, level, next_level)], 11 if not compact else 7, MUTED))
	var cost_label := _label("MÁXIMO" if level >= int(definition.max) else "%d ESSÊNCIAS" % cost, 11 if not compact else 7, CYAN)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(cost_label)
	var buy_button := Button.new()
	buy_button.name = "Upgrade_%s" % upgrade_id
	buy_button.flat = true
	buy_button.disabled = level >= int(definition.max) or essence < cost
	buy_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buy_button.tooltip_text = "Comprar %s" % str(definition.title).capitalize()
	buy_button.mouse_entered.connect(_focus_legacy.bind(upgrade_id))
	buy_button.focus_entered.connect(_focus_legacy.bind(upgrade_id))
	buy_button.pressed.connect(_buy_legacy.bind(upgrade_id))
	entry.add_child(buy_button)
	return entry


func _legacy_focus_panel() -> PanelContainer:
	var definition := _meta_definition(focused_legacy_id)
	if definition.is_empty():
		definition = GameDefs.meta_upgrades()[0]
		focused_legacy_id = str(definition.id)
	var level := int(config.get_value("meta", focused_legacy_id, 0))
	var max_level := int(definition.max)
	var next_level := mini(level + 1, max_level)
	var cost := GameDefs.meta_cost(definition, level)
	var focus := PanelContainer.new()
	focus.name = "LegacyFocus"
	focus.custom_minimum_size.x = 360.0 if size.x >= 1000.0 and not compact else (260.0 if not compact else 205.0)
	focus.add_theme_stylebox_override("panel", _style(Color("21102ce8"), GOLD, 2, 9))
	var margin := MarginContainer.new()
	_set_margins(margin, 14 if not compact else 6)
	focus.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 7 if not compact else 2)
	margin.add_child(box)
	var heading := _label("MELHORIA FOCADA", 12 if not compact else 8, MUTED)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	box.add_child(_texture(LEGACY_ICONS.get(focused_legacy_id) as Texture2D, 220.0 if not compact else 80.0))
	var title := _label(str(definition.title), 23 if not compact else 13, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var progress := ProgressBar.new()
	progress.name = "LegacyProgress"
	progress.value = float(level) / float(maxi(max_level, 1)) * 100.0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0.0, 16.0 if not compact else 8.0)
	progress.add_theme_stylebox_override("background", _style(Color("0d0812"), BORDER, 1, 5))
	progress.add_theme_stylebox_override("fill", _style(Color("9b5dd1"), Color("d4a4ff"), 1, 5))
	box.add_child(progress)
	var info_text := "NÍVEL %d/%d\n%s" % [level, max_level, _legacy_effect(focused_legacy_id, level, next_level)]
	if level < max_level:
		info_text += "\nPRÓXIMO NÍVEL · %d ESSÊNCIAS" % cost
	else:
		info_text += "\nMELHORIA CONCLUÍDA"
	var info := _label(info_text, 13 if not compact else 8, TEXT)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	return focus


func _build_achievements() -> Control:
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 7 if not compact else 3)
	var unlocked_count := 0
	for definition in GameDefs.achievements():
		if bool(config.get_value("achievements", str(definition.id), false)):
			unlocked_count += 1
	var heading := HBoxContainer.new()
	root_box.add_child(heading)
	heading.add_child(_label("%d/%d DESBLOQUEADAS" % [unlocked_count, GameDefs.achievements().size()], 17 if not compact else 10, GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	heading.add_child(_label("MARCAS PERMANENTES DO RITUAL", 11 if not compact else 7, MUTED))
	primary_scroll = ScrollContainer.new()
	primary_scroll.name = "AchievementScroll"
	primary_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	primary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	primary_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root_box.add_child(primary_scroll)
	achievement_grid = GridContainer.new()
	achievement_grid.name = "AchievementGrid"
	achievement_grid.columns = 3 if size.x >= 1000.0 else 2
	achievement_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_grid.add_theme_constant_override("h_separation", 8 if not compact else 4)
	achievement_grid.add_theme_constant_override("v_separation", 8 if not compact else 4)
	primary_scroll.add_child(achievement_grid)
	for definition in GameDefs.achievements():
		achievement_grid.add_child(_achievement_card(definition))
	return root_box


func _achievement_card(definition: Dictionary) -> PanelContainer:
	var achievement_id := str(definition.id)
	var unlocked := bool(config.get_value("achievements", achievement_id, false))
	var card := PanelContainer.new()
	card.name = "Achievement_%s" % achievement_id
	card.custom_minimum_size.y = 118.0 if not compact else 67.0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel", _style(PANEL_LIGHT if unlocked else Color("111016e8"), GOLD if unlocked else Color("403846"), 2 if unlocked else 1, 7)
	)
	var margin := MarginContainer.new()
	_set_margins(margin, 7 if not compact else 3)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8 if not compact else 4)
	margin.add_child(row)
	var image := _texture(_achievement_texture(achievement_id), 92.0 if not compact else 51.0)
	if not unlocked:
		image.modulate = Color(0.30, 0.29, 0.33, 0.58)
	row.add_child(image)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(box)
	box.add_child(_label(str(definition.title), 13 if not compact else 8, GOLD if unlocked else MUTED))
	var description := _label(str(definition.description), 10 if not compact else 7, TEXT if unlocked else Color("706879"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	box.add_child(_label("DESBLOQUEADA" if unlocked else "BLOQUEADA", 9 if not compact else 6, CYAN if unlocked else Color("625969")))
	return card


func _build_options() -> Control:
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8 if not compact else 4)
	root_box.add_child(_label("AJUSTE A EXPERIÊNCIA SEM SAIR DO SEU PERFIL", 12 if not compact else 8, MUTED))
	options_grid = GridContainer.new()
	options_grid.name = "OptionsGrid"
	options_grid.columns = 2
	options_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_grid.add_theme_constant_override("h_separation", 10 if not compact else 4)
	options_grid.add_theme_constant_override("v_separation", 10 if not compact else 4)
	root_box.add_child(options_grid)
	for option in [
		{"id": "music", "title": "MÚSICA", "glyph": "♫"},
		{"id": "sfx", "title": "EFEITOS", "glyph": "✦"},
		{"id": "flash", "title": "FLASHES", "glyph": "☼"},
		{"id": "shake", "title": "TREMORES DE CÂMERA", "glyph": "⌁"},
	]:
		options_grid.add_child(_setting_card(str(option.id), str(option.title), str(option.glyph)))
	options_grid.add_child(_fullscreen_card())
	options_grid.add_child(_information_card())
	return root_box


func _setting_card(setting_id: String, setting_title: String, glyph_text: String) -> PanelContainer:
	var default_value := float(GameDefs.default_settings()[setting_id])
	var value := float(config.get_value("settings", setting_id, default_value))
	var card := _option_card(setting_title, "%d%%" % roundi(value * 100.0), glyph_text)
	var button := Button.new()
	button.name = "Setting_%s" % setting_id
	button.flat = true
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.tooltip_text = "Alterar %s" % setting_title.capitalize()
	button.pressed.connect(_cycle_setting.bind(setting_id))
	card.add_child(button)
	return card


func _fullscreen_card() -> PanelContainer:
	var fullscreen := bool(config.get_value("settings", "fullscreen", false))
	var card := _option_card("TELA CHEIA", "ATIVADA" if fullscreen else "DESATIVADA", "▣")
	var button := Button.new()
	button.name = "Setting_fullscreen"
	button.flat = true
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.tooltip_text = "Alternar tela cheia"
	button.pressed.connect(_toggle_fullscreen)
	card.add_child(button)
	return card


func _information_card() -> PanelContainer:
	return _option_card("ACESSIBILIDADE", "ÁUDIO, FLASHES E TREMOR", "◇")


func _option_card(option_title: String, value_text: String, glyph_text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 120.0 if not compact else 64.0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(PANEL_LIGHT, BORDER, 1, 8))
	var margin := MarginContainer.new()
	_set_margins(margin, 12 if not compact else 5)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12 if not compact else 6)
	margin.add_child(row)
	var glyph := _label(glyph_text, 31 if not compact else 18, VIOLET)
	glyph.custom_minimum_size.x = 48.0 if not compact else 26.0
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(glyph)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text_box)
	text_box.add_child(_label(option_title, 15 if not compact else 9, TEXT))
	text_box.add_child(_label(value_text, 13 if not compact else 8, GOLD))
	var arrows := _label("‹   ›", 17 if not compact else 10, CYAN)
	arrows.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(arrows)
	return card


func _select_character(character_id: String) -> void:
	if is_instance_valid(menu_host):
		menu_host.call("_select_character", character_id)


func _focus_legacy(upgrade_id: String) -> void:
	if focused_legacy_id == upgrade_id:
		return
	focused_legacy_id = upgrade_id
	_rebuild_content()


func _buy_legacy(upgrade_id: String) -> void:
	focused_legacy_id = upgrade_id
	if is_instance_valid(menu_host):
		menu_host.call("_buy_meta_upgrade", upgrade_id)


func _cycle_setting(setting_id: String) -> void:
	if is_instance_valid(menu_host):
		menu_host.call("_cycle_setting", setting_id)


func _toggle_fullscreen() -> void:
	if is_instance_valid(menu_host):
		menu_host.call("_toggle_fullscreen")


func _close() -> void:
	queue_free()


func _meta_definition(upgrade_id: String) -> Dictionary:
	for definition in GameDefs.meta_upgrades():
		if str(definition.id) == upgrade_id:
			return definition
	return {}


func _legacy_effect(upgrade_id: String, current_level: int, next_level: int) -> String:
	match upgrade_id:
		"power":
			return "+%d%%  →  +%d%% DANO" % [current_level * 5, next_level * 5]
		"vitality":
			return "+%d  →  +%d VIDA" % [current_level * 10, next_level * 10]
		"speed":
			return "+%d%%  →  +%d%% MOVIMENTO" % [current_level * 3, next_level * 3]
		"fortune":
			return "+%.1f%%  →  +%.1f%% CRÍTICO" % [float(current_level) * 1.5, float(next_level) * 1.5]
		_:
			return "NÍVEL %d  →  %d" % [current_level, next_level]


func _achievement_texture(achievement_id: String) -> Texture2D:
	var art: Dictionary = ACHIEVEMENT_ART.get(achievement_id, ACHIEVEMENT_ART.survivor)
	return _atlas_frame(art.texture as Texture2D, int(art.hframes), int(art.vframes))


func _content_columns() -> int:
	if current_tab == TAB_HUNTERS:
		return 4 if size.x >= 1000.0 else 2
	if current_tab == TAB_ACHIEVEMENTS:
		return 3 if size.x >= 1000.0 else 2
	return 2


func _texture(texture: Texture2D, height: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size.y = height
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect


func _label(label_text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.01, 0.05, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _button(button_text: String, is_compact: bool) -> Button:
	var button := Button.new()
	button.text = button_text
	button.add_theme_font_size_override("font_size", 12 if not is_compact else 8)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _style(Color("21122e"), BORDER, 1, 7))
	button.add_theme_stylebox_override("hover", _style(Color("352047"), VIOLET, 2, 7))
	button.add_theme_stylebox_override("pressed", _style(Color("3d254e"), GOLD, 2, 7))
	button.add_theme_stylebox_override("focus", _style(Color("352047"), GOLD, 2, 7))
	return button


func _style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _set_margins(container: MarginContainer, margin_value: int) -> void:
	container.add_theme_constant_override("margin_left", margin_value)
	container.add_theme_constant_override("margin_top", margin_value)
	container.add_theme_constant_override("margin_right", margin_value)
	container.add_theme_constant_override("margin_bottom", margin_value)
