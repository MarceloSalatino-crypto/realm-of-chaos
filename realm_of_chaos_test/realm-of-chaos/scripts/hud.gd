extends CanvasLayer

const MinimapScript = preload("res://scripts/minimap.gd")
const AbilityIndicatorScript = preload("res://scripts/ability_indicator.gd")
const UPGRADE_ICON_TEXTURES := {
	"chaos_bolt": preload("res://assets/ui/upgrade_icons/chaos_bolt.png"),
	"shadow_blades": preload("res://assets/ui/upgrade_icons/shadow_blades.png"),
	"soul_orbit": preload("res://assets/ui/upgrade_icons/soul_orbit.png"),
	"chaos_nova": preload("res://assets/ui/upgrade_icons/chaos_nova.png"),
	"blood_scythe": preload("res://assets/ui/upgrade_icons/blood_scythe.png"),
	"forbidden_grimoire": preload("res://assets/ui/upgrade_icons/forbidden_grimoire.png"),
	"rune_hammer": preload("res://assets/ui/upgrade_icons/rune_hammer.png"),
	"storm_relic": preload("res://assets/ui/upgrade_icons/storm_relic.png"),
	"swarm_idol": preload("res://assets/ui/upgrade_icons/swarm_idol.png"),
	"might": preload("res://assets/ui/upgrade_icons/might.png"),
	"haste": preload("res://assets/ui/upgrade_icons/haste.png"),
	"vitality": preload("res://assets/ui/upgrade_icons/vitality.png"),
	"swiftness": preload("res://assets/ui/upgrade_icons/swiftness.png"),
	"magnet": preload("res://assets/ui/upgrade_icons/magnet.png"),
	"armor": preload("res://assets/ui/upgrade_icons/armor.png"),
	"regeneration": preload("res://assets/ui/upgrade_icons/regeneration.png"),
	"critical": preload("res://assets/ui/upgrade_icons/critical.png"),
}
const CHARACTER_ABILITY_ICONS := {
	"eclipse_hunter": preload("res://assets/ui/upgrade_icons/chaos_bolt.png"),
	"glacial_oracle": preload("res://assets/ui/upgrade_icons/soul_orbit.png"),
	"crimson_knight": preload("res://assets/ui/upgrade_icons/shadow_blades.png"),
	"void_automaton": preload("res://assets/ui/upgrade_icons/chaos_nova.png"),
}
const CHARACTER_ABILITY_COLORS := {
	"eclipse_hunter": Color("d89cff"),
	"glacial_oracle": Color("70dcff"),
	"crimson_knight": Color("ff6b72"),
	"void_automaton": Color("b873ff"),
}

signal upgrade_selected(upgrade_id: String, rarity: String)
signal relic_selected(relic_id: String)
signal restart_requested
signal menu_requested
signal resume_requested

var upgrade_options: Array[Dictionary] = []
var relic_options: Array[Dictionary] = []
var flash_intensity := 0.70
var relic_overlay: Control
var relic_panel: PanelContainer
var relic_margin: MarginContainer
var relic_box: VBoxContainer
var relic_title: Label
var relic_subtitle: Label
var relic_scroll: ScrollContainer
var relic_cards: GridContainer
var relic_buttons: Array[Button] = []
var boss_intro: Control
var boss_intro_band: ColorRect
var boss_intro_label: Label
var minimap: Control
var ability_indicator: Control
var stage_banner_tween: Tween
var boss_intro_tween: Tween
var damage_flash_tween: Tween
var upgrade_synergy_icon_size := 32.0
var bound_world: Node
var pause_scroll: ScrollContainer
var pause_content_grid: GridContainer
var pause_character_card: PanelContainer
var pause_loadout_card: PanelContainer
var pause_portrait: TextureRect
var pause_character_name: Label
var pause_character_role: Label
var pause_stat_grid: GridContainer
var pause_stat_labels: Array[Label] = []
var pause_weapons_grid: GridContainer
var pause_passives_grid: GridContainer
var pause_button_row: HBoxContainer

@onready var health_bar: ProgressBar = $Top/HealthBar
@onready var health_label: Label = $Top/HealthBar/Label
@onready var xp_bar: ProgressBar = $XPBar
@onready var timer_label: Label = $Top/Timer
@onready var level_label: Label = $Top/Level
@onready var kills_label: Label = $Top/Kills
@onready var essence_label: Label = $Top/Essence
@onready var stage_label: Label = $Top/Stage
@onready var world_event_label: Label = $WorldEvent
@onready var boss_panel: Control = $Boss
@onready var boss_bar: ProgressBar = $Boss/Bar
@onready var boss_label: Label = $Boss/Name
@onready var stage_banner: Label = $StageBanner
@onready var damage_flash: ColorRect = $DamageFlash
@onready var upgrade_overlay: Control = $UpgradeOverlay
@onready var upgrade_panel: PanelContainer = $UpgradeOverlay/Panel
@onready var upgrade_margin: MarginContainer = $UpgradeOverlay/Panel/Margin
@onready var upgrade_vbox: VBoxContainer = $UpgradeOverlay/Panel/Margin/VBox
@onready var upgrade_title: Label = $UpgradeOverlay/Panel/Margin/VBox/Title
@onready var upgrade_hint: Label = $UpgradeOverlay/Panel/Margin/VBox/Hint
@onready var upgrade_scroll: ScrollContainer = $UpgradeOverlay/Panel/Margin/VBox/CardsScroll
@onready var upgrade_cards: GridContainer = $UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards
@onready var upgrade_buttons: Array[Button] = [
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card1,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card2,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card3
]
@onready var upgrade_icon_rects: Array[TextureRect] = [
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card1/Icon,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card2/Icon,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card3/Icon
]
@onready var upgrade_summary_labels: Array[Label] = [
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card1/Summary,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card2/Summary,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card3/Summary
]
@onready var upgrade_effect_labels: Array[Label] = [
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card1/Effect,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card2/Effect,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card3/Effect
]
@onready var upgrade_rarity_badges: Array[PanelContainer] = [
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card1/RarityBadge,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card2/RarityBadge,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card3/RarityBadge
]
@onready var upgrade_rarity_labels: Array[Label] = [
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card1/RarityBadge/Label,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card2/RarityBadge/Label,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card3/RarityBadge/Label
]
@onready var upgrade_synergy_rows: Array[HBoxContainer] = [
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card1/SynergyRow,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card2/SynergyRow,
	$UpgradeOverlay/Panel/Margin/VBox/CardsScroll/Cards/Card3/SynergyRow
]
@onready var pause_overlay: Control = $PauseOverlay
@onready var pause_panel: PanelContainer = $PauseOverlay/Panel
@onready var pause_vbox: VBoxContainer = $PauseOverlay/Panel/VBox
@onready var pause_title: Label = $PauseOverlay/Panel/VBox/Title
@onready var pause_buttons: Array[Button] = [
	$PauseOverlay/Panel/VBox/Resume,
	$PauseOverlay/Panel/VBox/Restart,
	$PauseOverlay/Panel/VBox/Menu
]
@onready var end_overlay: Control = $EndOverlay
@onready var end_panel: PanelContainer = $EndOverlay/Panel
@onready var end_margin: MarginContainer = $EndOverlay/Panel/Margin
@onready var end_vbox: VBoxContainer = $EndOverlay/Panel/Margin/VBox
@onready var end_title: Label = $EndOverlay/Panel/Margin/VBox/Title
@onready var end_summary_scroll: ScrollContainer = $EndOverlay/Panel/Margin/VBox/SummaryScroll
@onready var end_summary: Label = $EndOverlay/Panel/Margin/VBox/SummaryScroll/Summary
@onready var end_restart_button: Button = $EndOverlay/Panel/Margin/VBox/Restart
@onready var end_menu_button: Button = $EndOverlay/Panel/Margin/VBox/Menu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in range(upgrade_buttons.size()):
		upgrade_buttons[index].pressed.connect(_on_upgrade_button_pressed.bind(index))
	pause_buttons[0].pressed.connect(_on_resume_pressed)
	pause_buttons[1].pressed.connect(func(): restart_requested.emit())
	pause_buttons[2].pressed.connect(func(): menu_requested.emit())
	$EndOverlay/Panel/Margin/VBox/Restart.pressed.connect(func(): restart_requested.emit())
	$EndOverlay/Panel/Margin/VBox/Menu.pressed.connect(func(): menu_requested.emit())
	_build_pause_character_panel()
	_build_relic_overlay()
	_build_boss_intro()
	_build_navigation_ui()
	relic_overlay.resized.connect(_update_relic_layout)
	end_overlay.resized.connect(_update_end_layout)
	upgrade_overlay.resized.connect(_update_responsive_hud_layout)
	_update_relic_layout()
	_update_end_layout()
	_update_responsive_hud_layout()
	_update_relic_layout.call_deferred()
	_update_end_layout.call_deferred()
	_update_responsive_hud_layout.call_deferred()


func set_accessibility(new_flash_intensity: float) -> void:
	flash_intensity = clampf(new_flash_intensity, 0.0, 1.0)


func _build_navigation_ui() -> void:
	minimap = MinimapScript.new()
	minimap.name = "Minimap"
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.position = Vector2(-208.0, -205.0)
	minimap.size = Vector2(188.0, 185.0)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.z_index = -2
	add_child(minimap)
	ability_indicator = AbilityIndicatorScript.new()
	ability_indicator.name = "AbilityIndicator"
	ability_indicator.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ability_indicator.position = Vector2(18.0, -116.0)
	ability_indicator.size = Vector2(172.0, 96.0)
	ability_indicator.z_index = -2
	add_child(ability_indicator)


func bind_world(world: Node) -> void:
	bound_world = world
	if is_instance_valid(minimap):
		minimap.bind_world(world)
	_refresh_pause_character_panel()


func update_navigation(cooldown_progress: float, character_id: String, ability_name: String) -> void:
	var icon := CHARACTER_ABILITY_ICONS.get(character_id, CHARACTER_ABILITY_ICONS.eclipse_hunter) as Texture2D
	var color := Color(CHARACTER_ABILITY_COLORS.get(character_id, Color("d89cff")))
	ability_indicator.set_state(cooldown_progress, icon, ability_name, color)


func _pause_card_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.035, 0.09, 0.96)
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _pause_section_title(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", Color("ffd36b"))
	label.add_theme_font_size_override("font_size", 16)
	return label


func _build_pause_character_panel() -> void:
	pause_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	pause_scroll = ScrollContainer.new()
	pause_scroll.name = "CharacterScroll"
	pause_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pause_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pause_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pause_vbox.add_child(pause_scroll)
	pause_vbox.move_child(pause_scroll, 1)

	pause_content_grid = GridContainer.new()
	pause_content_grid.name = "CharacterContent"
	pause_content_grid.columns = 2
	pause_content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_content_grid.add_theme_constant_override("h_separation", 14)
	pause_content_grid.add_theme_constant_override("v_separation", 12)
	pause_scroll.add_child(pause_content_grid)

	pause_character_card = PanelContainer.new()
	pause_character_card.name = "CharacterCard"
	pause_character_card.add_theme_stylebox_override("panel", _pause_card_style(Color("7d5aa8")))
	pause_content_grid.add_child(pause_character_card)
	var character_box := VBoxContainer.new()
	character_box.name = "CharacterVBox"
	character_box.add_theme_constant_override("separation", 7)
	pause_character_card.add_child(character_box)
	var portrait_center := CenterContainer.new()
	portrait_center.name = "PortraitCenter"
	character_box.add_child(portrait_center)
	pause_portrait = TextureRect.new()
	pause_portrait.name = "Portrait"
	pause_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pause_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pause_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_center.add_child(pause_portrait)
	pause_character_name = Label.new()
	pause_character_name.name = "CharacterName"
	pause_character_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_character_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_character_name.add_theme_color_override("font_color", Color("f2c4ff"))
	pause_character_name.add_theme_font_size_override("font_size", 19)
	character_box.add_child(pause_character_name)
	pause_character_role = Label.new()
	pause_character_role.name = "CharacterRole"
	pause_character_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_character_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_character_role.add_theme_color_override("font_color", Color("bca8d2"))
	pause_character_role.add_theme_font_size_override("font_size", 13)
	character_box.add_child(pause_character_role)
	pause_stat_grid = GridContainer.new()
	pause_stat_grid.name = "Stats"
	pause_stat_grid.columns = 2
	pause_stat_grid.add_theme_constant_override("h_separation", 7)
	pause_stat_grid.add_theme_constant_override("v_separation", 7)
	character_box.add_child(pause_stat_grid)
	for stat_name in ["HP", "XP", "TEMPO", "ESSÊNCIA"]:
		var stat_panel := PanelContainer.new()
		stat_panel.name = stat_name.capitalize()
		stat_panel.custom_minimum_size = Vector2(92.0, 48.0)
		stat_panel.add_theme_stylebox_override("panel", _pause_card_style(Color(0.32, 0.23, 0.43, 0.75)))
		pause_stat_grid.add_child(stat_panel)
		var stat_label := Label.new()
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_label.add_theme_color_override("font_color", Color("e7dcef"))
		stat_label.add_theme_font_size_override("font_size", 12)
		stat_panel.add_child(stat_label)
		pause_stat_labels.append(stat_label)

	pause_loadout_card = PanelContainer.new()
	pause_loadout_card.name = "LoadoutCard"
	pause_loadout_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_loadout_card.add_theme_stylebox_override("panel", _pause_card_style(Color("9b6bd1")))
	pause_content_grid.add_child(pause_loadout_card)
	var loadout_box := VBoxContainer.new()
	loadout_box.name = "LoadoutVBox"
	loadout_box.add_theme_constant_override("separation", 7)
	pause_loadout_card.add_child(loadout_box)
	loadout_box.add_child(_pause_section_title("ARMAS"))
	pause_weapons_grid = GridContainer.new()
	pause_weapons_grid.name = "Weapons"
	pause_weapons_grid.columns = 2
	pause_weapons_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_weapons_grid.add_theme_constant_override("h_separation", 8)
	pause_weapons_grid.add_theme_constant_override("v_separation", 6)
	loadout_box.add_child(pause_weapons_grid)
	loadout_box.add_child(_pause_section_title("PASSIVOS"))
	pause_passives_grid = GridContainer.new()
	pause_passives_grid.name = "Passives"
	pause_passives_grid.columns = 2
	pause_passives_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_passives_grid.add_theme_constant_override("h_separation", 8)
	pause_passives_grid.add_theme_constant_override("v_separation", 6)
	loadout_box.add_child(pause_passives_grid)

	pause_button_row = HBoxContainer.new()
	pause_button_row.name = "Buttons"
	pause_button_row.add_theme_constant_override("separation", 10)
	pause_vbox.add_child(pause_button_row)
	for button in pause_buttons:
		button.reparent(pause_button_row)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_pause_character_panel()


func _set_pause_portrait(texture: Texture2D) -> void:
	if not is_instance_valid(pause_portrait) or not is_instance_valid(texture):
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	var texture_size := texture.get_size()
	atlas.region = Rect2(Vector2.ZERO, Vector2(texture_size.x / 4.0, texture_size.y / 2.0))
	pause_portrait.texture = atlas


func _clear_pause_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.free()


func _add_pause_loadout_item(grid: GridContainer, definition: Dictionary, level: int, evolved := false) -> void:
	var item_panel := PanelContainer.new()
	item_panel.custom_minimum_size = Vector2(0.0, 46.0)
	item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var item_style := StyleBoxFlat.new()
	item_style.bg_color = Color(0.08, 0.055, 0.12, 0.88)
	item_style.set_corner_radius_all(7)
	item_style.content_margin_left = 7.0
	item_style.content_margin_right = 7.0
	item_style.content_margin_top = 5.0
	item_style.content_margin_bottom = 5.0
	item_panel.add_theme_stylebox_override("panel", item_style)
	grid.add_child(item_panel)
	var row := HBoxContainer.new()
	row.name = "Content"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 7)
	item_panel.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(34.0, 34.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = UPGRADE_ICON_TEXTURES.get(str(definition.id)) as Texture2D
	row.add_child(icon)
	var label := Label.new()
	label.name = "NameAndLevel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("e9dfef"))
	label.add_theme_font_size_override("font_size", 12)
	var evolution_text := " · EVOLUÍDA" if evolved else ""
	label.text = "%s\nNv %d/%d%s" % [str(definition.title), level, int(definition.max), evolution_text]
	row.add_child(label)


func _populate_pause_loadout(grid: GridContainer, levels: Dictionary, evolved_levels := {}) -> void:
	_clear_pause_grid(grid)
	var item_count := 0
	for definition in GameDefs.upgrades():
		var upgrade_id := str(definition.id)
		if not levels.has(upgrade_id):
			continue
		var item_level := int(levels.get(upgrade_id, 0))
		if item_level <= 0:
			continue
		_add_pause_loadout_item(grid, definition, item_level, bool(evolved_levels.get(upgrade_id, false)))
		item_count += 1
	if item_count == 0:
		var empty_label := Label.new()
		empty_label.text = "Nenhum equipado"
		empty_label.add_theme_color_override("font_color", Color("9f8ead"))
		grid.add_child(empty_label)


func _refresh_pause_character_panel() -> void:
	if not is_instance_valid(pause_portrait):
		return
	var character_id := "eclipse_hunter"
	var level := 17
	var hp := 104.0
	var max_hp := 160.0
	var xp := 86
	var xp_needed := 132
	var survived := 754.0
	var essence := 87
	var weapon_levels := {
		"chaos_bolt": 6, "shadow_blades": 4, "soul_orbit": 5,
		"blood_scythe": 3, "storm_relic": 2, "swarm_idol": 2,
	}
	var passive_levels := {
		"might": 5, "haste": 4, "vitality": 4, "swiftness": 3,
		"magnet": 3, "armor": 4, "regeneration": 3, "critical": 5,
	}
	var evolved_levels := {"chaos_bolt": true}
	var portrait_texture := load("res://assets/generated/hero_anim_chaos_bolt.png") as Texture2D
	if is_instance_valid(bound_world) and is_instance_valid(bound_world.player):
		var player = bound_world.player
		character_id = str(player.character_id)
		level = int(player.level)
		hp = float(player.hp)
		max_hp = float(player.max_hp)
		xp = int(player.experience)
		xp_needed = int(player.experience_needed)
		survived = float(bound_world.time_survived)
		essence = int(bound_world.essence_earned)
		weapon_levels = player.weapon_levels
		passive_levels = player.passive_levels
		evolved_levels = player.evolved_weapons
		portrait_texture = player.sprite.texture
	var character := GameDefs.character_data(character_id)
	pause_character_name.text = str(character.title)
	pause_character_role.text = "%s · NÍVEL %02d" % [str(character.role).to_upper(), level]
	_set_pause_portrait(portrait_texture)
	var minutes := floori(survived / 60.0)
	var seconds := int(survived) % 60
	var stat_values := [
		"HP\n%d / %d" % [ceili(hp), ceili(max_hp)],
		"XP\n%d / %d" % [xp, xp_needed],
		"TEMPO\n%02d:%02d" % [minutes, seconds],
		"ESSÊNCIA\n%d" % essence,
	]
	for index in range(pause_stat_labels.size()):
		pause_stat_labels[index].text = stat_values[index]
	_populate_pause_loadout(pause_weapons_grid, weapon_levels, evolved_levels)
	_populate_pause_loadout(pause_passives_grid, passive_levels)
	pause_scroll.scroll_vertical = 0
	_update_responsive_hud_layout.call_deferred()


func _build_relic_overlay() -> void:
	relic_overlay = Control.new()
	relic_overlay.name = "RelicOverlay"
	relic_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	relic_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(relic_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.005, 0.035, 0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	relic_overlay.add_child(shade)
	relic_panel = PanelContainer.new()
	relic_panel.name = "Panel"
	relic_panel.set_anchors_preset(Control.PRESET_CENTER)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("171027")
	panel_style.border_color = Color("c88dff")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	relic_panel.add_theme_stylebox_override("panel", panel_style)
	relic_overlay.add_child(relic_panel)
	relic_margin = MarginContainer.new()
	relic_margin.name = "Margin"
	relic_panel.add_child(relic_margin)
	relic_box = VBoxContainer.new()
	relic_box.name = "VBox"
	relic_margin.add_child(relic_box)
	relic_title = Label.new()
	relic_title.name = "Title"
	relic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_title.add_theme_color_override("font_color", Color("ffd36b"))
	relic_box.add_child(relic_title)
	relic_subtitle = Label.new()
	relic_subtitle.name = "Subtitle"
	relic_subtitle.text = "Uma relíquia ficará com você até o fim da partida"
	relic_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relic_subtitle.add_theme_color_override("font_color", Color("cbb8df"))
	relic_box.add_child(relic_subtitle)
	relic_scroll = ScrollContainer.new()
	relic_scroll.name = "CardsScroll"
	relic_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relic_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	relic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	relic_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	relic_scroll.follow_focus = true
	relic_scroll.focus_mode = Control.FOCUS_ALL
	relic_box.add_child(relic_scroll)
	relic_cards = GridContainer.new()
	relic_cards.name = "Cards"
	relic_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relic_cards.add_theme_constant_override("h_separation", 16)
	relic_cards.add_theme_constant_override("v_separation", 16)
	relic_scroll.add_child(relic_cards)
	for index in range(3):
		var button := Button.new()
		button.name = "Card%d" % (index + 1)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_relic_button_pressed.bind(index))
		relic_cards.add_child(button)
		relic_buttons.append(button)
	relic_overlay.hide()


func _update_relic_layout() -> void:
	if not is_instance_valid(relic_overlay) or not is_instance_valid(relic_panel):
		return
	var viewport_size := relic_overlay.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var horizontal_inset := clampf(viewport_size.x * 0.03, 10.0, 38.0)
	var vertical_inset := clampf(viewport_size.y * 0.035, 8.0, 28.0)
	var panel_size := Vector2(
		minf(1000.0, maxf(1.0, viewport_size.x - horizontal_inset * 2.0)),
		minf(620.0, maxf(1.0, viewport_size.y - vertical_inset * 2.0))
	)
	relic_panel.size = panel_size
	relic_panel.position = (viewport_size - panel_size) * 0.5
	var horizontal_margin := roundf(clampf(viewport_size.x * 0.035, 14.0, 42.0))
	var vertical_margin := roundf(clampf(viewport_size.y * 0.025, 8.0, 26.0))
	relic_margin.add_theme_constant_override("margin_left", int(horizontal_margin))
	relic_margin.add_theme_constant_override("margin_right", int(horizontal_margin))
	relic_margin.add_theme_constant_override("margin_top", int(vertical_margin))
	relic_margin.add_theme_constant_override("margin_bottom", int(vertical_margin))
	var spacing := int(roundf(clampf(viewport_size.y * 0.022, 7.0, 18.0)))
	relic_box.add_theme_constant_override("separation", spacing)
	relic_cards.add_theme_constant_override("h_separation", spacing)
	relic_cards.add_theme_constant_override("v_separation", spacing)
	var content_width := panel_size.x - horizontal_margin * 2.0
	var column_count := 3 if content_width >= 760.0 else (2 if content_width >= 520.0 else 1)
	relic_cards.columns = column_count
	var card_height := 350.0 if column_count == 3 else (220.0 if column_count == 2 else 180.0)
	var title_size := int(roundf(clampf(minf(viewport_size.x * 0.032, viewport_size.y * 0.052), 22.0, 32.0)))
	var subtitle_size := int(roundf(clampf(viewport_size.y * 0.026, 13.0, 17.0)))
	var button_size := int(roundf(clampf(viewport_size.y * 0.026, 14.0, 17.0)))
	relic_title.add_theme_font_size_override("font_size", title_size)
	relic_subtitle.add_theme_font_size_override("font_size", subtitle_size)
	for button in relic_buttons:
		button.custom_minimum_size = Vector2(0.0, card_height)
		button.add_theme_font_size_override("font_size", button_size)


func _build_boss_intro() -> void:
	boss_intro = Control.new()
	boss_intro.name = "BossIntro"
	boss_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(boss_intro)
	var band := ColorRect.new()
	boss_intro_band = band
	boss_intro_band.name = "Band"
	boss_intro_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_intro_band.color = Color(0.03, 0.005, 0.06, 0.86)
	boss_intro_band.set_anchors_preset(Control.PRESET_CENTER)
	boss_intro.add_child(boss_intro_band)
	boss_intro_label = Label.new()
	boss_intro_label.name = "Label"
	boss_intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_intro_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_intro_label.add_theme_color_override("font_color", Color("f2c4ff"))
	boss_intro_label.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.07, 1.0))
	boss_intro_band.add_child(boss_intro_label)
	boss_intro.hide()


func _update_responsive_hud_layout() -> void:
	if not is_instance_valid(upgrade_overlay):
		return
	var viewport_size := upgrade_overlay.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	_update_upgrade_layout(viewport_size)
	_update_pause_layout(viewport_size)
	_update_banner_layout(viewport_size)


func _update_upgrade_layout(viewport_size: Vector2) -> void:
	var horizontal_inset := clampf(viewport_size.x * 0.035, 12.0, 40.0)
	var vertical_inset := clampf(viewport_size.y * 0.035, 8.0, 28.0)
	var panel_size := Vector2(
		minf(1120.0, maxf(1.0, viewport_size.x - horizontal_inset * 2.0)),
		minf(600.0, maxf(1.0, viewport_size.y - vertical_inset * 2.0))
	)
	upgrade_panel.size = panel_size
	upgrade_panel.position = (viewport_size - panel_size) * 0.5
	var horizontal_margin := int(roundf(clampf(viewport_size.x * 0.032, 14.0, 36.0)))
	var vertical_margin := int(roundf(clampf(viewport_size.y * 0.024, 7.0, 28.0)))
	for side in ["margin_left", "margin_right"]:
		upgrade_margin.add_theme_constant_override(side, horizontal_margin)
	for side in ["margin_top", "margin_bottom"]:
		upgrade_margin.add_theme_constant_override(side, vertical_margin)
	var spacing := int(roundf(clampf(viewport_size.y * 0.015, 5.0, 16.0)))
	upgrade_vbox.add_theme_constant_override("separation", spacing)
	upgrade_cards.add_theme_constant_override("h_separation", spacing)
	upgrade_cards.add_theme_constant_override("v_separation", spacing)
	var content_width := maxf(1.0, panel_size.x - horizontal_margin * 2.0)
	var column_count := 3 if content_width >= 1000.0 else (2 if content_width >= 640.0 else 1)
	upgrade_cards.columns = column_count
	var card_height := roundf(clampf(viewport_size.y * 0.50, 250.0, 350.0))
	var icon_size := roundf(clampf(viewport_size.y * 0.16, 68.0, 116.0))
	var icon_top := roundf(clampf(viewport_size.y * 0.022, 8.0, 16.0))
	var summary_font_size := int(roundf(clampf(viewport_size.y * 0.022, 13.0, 15.0)))
	var effect_font_size := int(roundf(clampf(viewport_size.y * 0.020, 12.0, 13.0)))
	var summary_top := icon_top + icon_size + roundf(clampf(viewport_size.y * 0.012, 6.0, 10.0))
	var summary_height := roundf(clampf(viewport_size.y * 0.042, 26.0, 30.0))
	var effect_top := summary_top + summary_height + roundf(clampf(viewport_size.y * 0.010, 5.0, 8.0))
	var effect_height := roundf(clampf(viewport_size.y * 0.064, 38.0, 46.0))
	var badge_width := roundf(clampf(viewport_size.y * 0.14, 76.0, 96.0))
	var badge_height := roundf(clampf(viewport_size.y * 0.04, 22.0, 26.0))
	upgrade_synergy_icon_size = roundf(clampf(viewport_size.y * 0.055, 28.0, 32.0))
	var card_width := floorf(
		maxf(1.0, content_width - 18.0 - spacing * float(column_count - 1)) / float(column_count)
	)
	for index in range(upgrade_buttons.size()):
		var button := upgrade_buttons[index]
		button.custom_minimum_size = Vector2(card_width, card_height)
		var icon_rect := upgrade_icon_rects[index]
		icon_rect.offset_left = -icon_size * 0.5
		icon_rect.offset_top = icon_top
		icon_rect.offset_right = icon_size * 0.5
		icon_rect.offset_bottom = icon_top + icon_size
		var summary_label := upgrade_summary_labels[index]
		summary_label.offset_top = summary_top
		summary_label.offset_bottom = summary_top + summary_height
		summary_label.add_theme_font_size_override("font_size", summary_font_size)
		var effect_label := upgrade_effect_labels[index]
		effect_label.offset_top = effect_top
		effect_label.offset_bottom = effect_top + effect_height
		effect_label.add_theme_font_size_override("font_size", effect_font_size)
		var rarity_badge := upgrade_rarity_badges[index]
		rarity_badge.offset_left = -badge_width - 10.0
		rarity_badge.offset_top = 10.0
		rarity_badge.offset_right = -10.0
		rarity_badge.offset_bottom = 10.0 + badge_height
		upgrade_rarity_labels[index].add_theme_font_size_override(
			"font_size",
			int(roundf(clampf(viewport_size.y * 0.019, 10.0, 11.0)))
		)
		var synergy_row := upgrade_synergy_rows[index]
		synergy_row.offset_top = -upgrade_synergy_icon_size - 18.0
		synergy_row.offset_bottom = -14.0
		for holder in synergy_row.get_children():
			_update_synergy_holder_size(holder as Control)
	upgrade_title.add_theme_font_size_override(
		"font_size",
		int(roundf(clampf(minf(viewport_size.x * 0.035, viewport_size.y * 0.045), 20.0, 30.0)))
	)
	upgrade_hint.add_theme_font_size_override(
		"font_size",
		int(roundf(clampf(viewport_size.y * 0.023, 12.0, 15.0)))
	)
	# A largura final dos cartões altera o mínimo combinado do painel.
	# Reaplique o alvo depois que todos os mínimos responsivos estiverem atualizados.
	upgrade_panel.size = panel_size
	upgrade_panel.position = (viewport_size - panel_size) * 0.5


func _update_pause_layout(viewport_size: Vector2) -> void:
	var horizontal_inset := clampf(viewport_size.x * 0.04, 14.0, 36.0)
	var vertical_inset := clampf(viewport_size.y * 0.035, 8.0, 26.0)
	var panel_size := Vector2(
		minf(960.0, maxf(1.0, viewport_size.x - horizontal_inset * 2.0)),
		minf(620.0, maxf(1.0, viewport_size.y - vertical_inset * 2.0))
	)
	pause_panel.size = panel_size
	pause_panel.position = (viewport_size - panel_size) * 0.5
	pause_vbox.add_theme_constant_override(
		"separation",
		int(roundf(clampf(viewport_size.y * 0.018, 7.0, 12.0)))
	)
	pause_title.add_theme_font_size_override(
		"font_size",
		int(roundf(clampf(minf(viewport_size.x * 0.052, viewport_size.y * 0.046), 20.0, 32.0)))
	)
	var wide_layout := panel_size.x >= 820.0
	pause_content_grid.columns = 2 if wide_layout else 1
	pause_weapons_grid.columns = 2 if wide_layout else 1
	pause_passives_grid.columns = 2 if wide_layout else 1
	pause_stat_grid.columns = 2 if wide_layout else 4
	pause_character_card.custom_minimum_size = Vector2(248.0 if wide_layout else 0.0, 0.0)
	pause_loadout_card.custom_minimum_size = Vector2(520.0 if wide_layout else 0.0, 0.0)
	var portrait_size := (
		roundf(clampf(viewport_size.y * 0.18, 86.0, 128.0))
		if wide_layout
		else roundf(clampf(viewport_size.y * 0.14, 54.0, 70.0))
	)
	pause_portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
	pause_character_name.add_theme_font_size_override("font_size", 19 if wide_layout else 17)
	pause_character_role.add_theme_font_size_override("font_size", 13 if wide_layout else 11)
	var item_font_size := int(roundf(clampf(viewport_size.y * 0.022, 11.0, 13.0)))
	for grid in [pause_weapons_grid, pause_passives_grid]:
		for item_panel in grid.get_children():
			var item_label := item_panel.get_node_or_null("Content/NameAndLevel") as Label
			if item_label:
				item_label.add_theme_font_size_override("font_size", item_font_size)
	var button_height := roundf(clampf(viewport_size.y * 0.068, 38.0, 50.0))
	var button_font_size := int(roundf(clampf(viewport_size.y * 0.026, 13.0, 18.0)))
	for button in pause_buttons:
		button.custom_minimum_size = Vector2(0.0, button_height)
		button.add_theme_font_size_override("font_size", button_font_size)
	pause_panel.size = panel_size
	pause_panel.position = (viewport_size - panel_size) * 0.5


func _update_banner_layout(viewport_size: Vector2) -> void:
	var horizontal_inset := clampf(viewport_size.x * 0.03, 10.0, 36.0)
	var stage_size := Vector2(
		minf(1020.0, maxf(1.0, viewport_size.x - horizontal_inset * 2.0)),
		roundf(clampf(viewport_size.y * 0.09, 60.0, 72.0))
	)
	stage_banner.size = stage_size
	stage_banner.position = Vector2((viewport_size.x - stage_size.x) * 0.5, viewport_size.y * 0.25)
	stage_banner.add_theme_font_size_override(
		"font_size",
		int(roundf(clampf(minf(viewport_size.x * 0.045, viewport_size.y * 0.049), 21.0, 35.0)))
	)
	var boss_width := minf(620.0, maxf(1.0, viewport_size.x - horizontal_inset * 2.0))
	boss_panel.size.x = boss_width
	boss_panel.position.x = (viewport_size.x - boss_width) * 0.5
	boss_panel.position.y = 112.0
	boss_label.add_theme_font_size_override(
		"font_size",
		int(roundf(clampf(viewport_size.y * 0.024, 14.0, 17.0)))
	)
	world_event_label.size.x = boss_width
	world_event_label.position.x = (viewport_size.x - boss_width) * 0.5
	var band_size := Vector2(
		minf(1160.0, maxf(1.0, viewport_size.x - horizontal_inset * 2.0)),
		roundf(clampf(viewport_size.y * 0.217, 96.0, 156.0))
	)
	boss_intro_band.size = band_size
	boss_intro_band.position = (viewport_size - band_size) * 0.5
	boss_intro_label.add_theme_font_size_override(
		"font_size",
		int(roundf(clampf(minf(viewport_size.x * 0.046, viewport_size.y * 0.047), 22.0, 34.0)))
	)
	boss_intro_label.add_theme_constant_override(
		"outline_size",
		int(roundf(clampf(viewport_size.y * 0.01, 4.0, 7.0)))
	)


func update_run(
	current_hp: float, maximum_hp: float, current_xp: int, needed_xp: int,
	level: int, kills: int, remaining: float, stage: String,
	essence := 0, event_title := ""
) -> void:
	health_bar.max_value = maximum_hp
	health_bar.value = current_hp
	var health_ratio := current_hp / maxf(1.0, maximum_hp)
	if health_ratio <= 0.30:
		var danger_pulse := 0.78 + (sin(Time.get_ticks_msec() * 0.012) + 1.0) * 0.11
		health_bar.self_modulate = Color(1.0, danger_pulse, danger_pulse)
		health_label.text = "PERIGO · %d / %d" % [ceili(current_hp), ceili(maximum_hp)]
	else:
		health_bar.self_modulate = Color.WHITE
		health_label.text = "%d / %d" % [ceili(current_hp), ceili(maximum_hp)]
	xp_bar.max_value = needed_xp
	xp_bar.value = current_xp
	level_label.text = "NÍVEL %02d" % level
	kills_label.text = "☠  %04d" % kills
	essence_label.text = "ESSÊNCIA  %03d" % essence
	world_event_label.text = event_title
	var minutes := floori(remaining / 60.0)
	var seconds := int(remaining) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	stage_label.text = stage
	var stage_color := Color("b995e8")
	if stage.begins_with("IV"):
		stage_color = Color("ff4b52")
	elif stage.begins_with("III"):
		stage_color = Color("df63ff")
	elif stage.begins_with("II"):
		stage_color = Color("ffb454")
	stage_label.add_theme_color_override("font_color", stage_color)
	timer_label.add_theme_color_override("font_color", stage_color.lightened(0.18))


func show_boss(boss_name: String, current: float, maximum: float) -> void:
	boss_panel.show()
	boss_label.text = boss_name
	update_boss(current, maximum)


func set_boss_phase(phase: int) -> void:
	var base_name := boss_label.text.split(" · FASE")[0]
	boss_label.text = "%s · FASE %d" % [base_name, phase]


func update_boss(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = maxf(0.0, current)


func hide_boss() -> void:
	boss_panel.hide()


func show_event(title: String, color: Color) -> void:
	world_event_label.text = title
	world_event_label.add_theme_color_override("font_color", color.lightened(0.25))
	world_event_label.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(world_event_label, "modulate", Color.WHITE, 0.22)


func show_level_up(new_level: int, options: Array[Dictionary]) -> void:
	upgrade_options = options
	upgrade_title.text = "NÍVEL %d · ESCOLHA SEU PODER" % new_level
	upgrade_hint.text = "Escolha uma das três cartas para continuar"
	upgrade_overlay.show()
	for index in range(upgrade_buttons.size()):
		var button := upgrade_buttons[index]
		var icon_rect := upgrade_icon_rects[index]
		if index >= options.size():
			button.hide()
			icon_rect.texture = null
			upgrade_summary_labels[index].text = ""
			upgrade_effect_labels[index].text = ""
			upgrade_rarity_badges[index].hide()
			_populate_synergy_row(upgrade_synergy_rows[index], [])
			continue
		button.show()
		var option := options[index]
		icon_rect.texture = UPGRADE_ICON_TEXTURES.get(str(option.id))
		icon_rect.visible = icon_rect.texture != null
		button.text = ""
		var category := str(option.get("category", "PODER"))
		var type_label := "Passivo" if category == "PASSIVO" else "Arma"
		upgrade_summary_labels[index].text = "%s — %s · Nv %d/%d" % [
			option.title, type_label, option.level, option.max,
		]
		upgrade_effect_labels[index].text = str(
			option.get("short_description", option.get("description", ""))
		)
		var rarity_color := _rarity_color(str(option.rarity))
		upgrade_rarity_labels[index].text = str(option.rarity)
		upgrade_rarity_labels[index].add_theme_color_override("font_color", rarity_color)
		_style_rarity_badge(upgrade_rarity_badges[index], rarity_color)
		upgrade_rarity_badges[index].show()
		_populate_synergy_row(
			upgrade_synergy_rows[index],
			option.get("synergy_items", []) as Array
		)
	upgrade_scroll.scroll_vertical = 0
	_update_responsive_hud_layout()
	_update_responsive_hud_layout.call_deferred()
	upgrade_buttons[0].grab_focus()
	upgrade_scroll.set_deferred("scroll_vertical", 0)


func _populate_synergy_row(row: HBoxContainer, synergy_items: Array) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for value in synergy_items:
		var item: Dictionary = value
		var synergy_id := str(item.get("id", ""))
		var texture: Texture2D = UPGRADE_ICON_TEXTURES.get(synergy_id)
		if synergy_id.is_empty() or texture == null:
			continue
		var required_level := int(item.get("required_level", 0))
		var holder := Control.new()
		holder.name = "Synergy_" + synergy_id
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		holder.focus_mode = Control.FOCUS_NONE
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		holder.set_meta("upgrade_id", synergy_id)
		holder.set_meta("required_level", required_level)
		holder.tooltip_text = GameDefs.upgrade_title(synergy_id)
		if required_level > 0:
			holder.tooltip_text += " · Nv %d" % required_level
		row.add_child(holder)
		_update_synergy_holder_size(holder)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = texture
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		holder.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var required_label := Label.new()
		required_label.name = "RequiredLevel"
		required_label.text = "Nv %d" % required_level
		required_label.visible = required_level > 0
		required_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		required_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		required_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		required_label.add_theme_color_override("font_color", Color("f7d36b"))
		required_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.07, 1))
		required_label.add_theme_constant_override("outline_size", 4)
		required_label.add_theme_font_size_override("font_size", 10)
		holder.add_child(required_label)
		required_label.anchor_left = 1.0
		required_label.anchor_top = 1.0
		required_label.anchor_right = 1.0
		required_label.anchor_bottom = 1.0
		required_label.offset_left = -32.0
		required_label.offset_top = -15.0
		required_label.offset_right = 2.0
		required_label.offset_bottom = 2.0
	row.visible = row.get_child_count() > 0


func _update_synergy_holder_size(holder: Control) -> void:
	if holder == null:
		return
	holder.custom_minimum_size = Vector2(upgrade_synergy_icon_size, upgrade_synergy_icon_size)
	holder.size = holder.custom_minimum_size
	var required_label := holder.get_node_or_null("RequiredLevel") as Label
	if required_label:
		required_label.add_theme_font_size_override(
			"font_size",
			int(roundf(clampf(upgrade_synergy_icon_size * 0.34, 9.0, 11.0)))
		)


func _style_rarity_badge(badge: PanelContainer, rarity_color: Color) -> void:
	var style := badge.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = Color(
		rarity_color.r * 0.22,
		rarity_color.g * 0.22,
		rarity_color.b * 0.22,
		0.96
	)
	style.border_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.92)
	badge.add_theme_stylebox_override("panel", style)


func hide_level_up() -> void:
	upgrade_overlay.hide()


func show_relic_choice(options: Array[Dictionary], boss_name := "") -> void:
	relic_options = options
	relic_title.text = "TESOURO DE %s" % boss_name if not boss_name.is_empty() else "ESCOLHA UMA RELÍQUIA"
	relic_overlay.show()
	for index in range(relic_buttons.size()):
		var button := relic_buttons[index]
		if index >= options.size():
			button.hide()
			continue
		button.show()
		var option := options[index]
		button.text = "%s\n\n%s\nNÍVEL %d/%d\n\n%s" % [
			option.icon, option.title, option.level, option.max, option.description
		]
		button.add_theme_color_override("font_color", Color("eadbff"))
		button.add_theme_color_override("font_hover_color", Color("ffd36b"))
	relic_scroll.scroll_vertical = 0
	_update_relic_layout()
	_update_relic_layout.call_deferred()
	relic_buttons[0].grab_focus()


func hide_relic_choice() -> void:
	relic_overlay.hide()


func _on_relic_button_pressed(index: int) -> void:
	if index >= relic_options.size():
		return
	relic_selected.emit(str(relic_options[index].id))


func _on_upgrade_button_pressed(index: int) -> void:
	if index >= upgrade_options.size():
		return
	var option := upgrade_options[index]
	upgrade_selected.emit(option.id, option.rarity)


func _rarity_color(rarity: String) -> Color:
	if rarity == "LENDÁRIO":
		return Color("ffcc66")
	if rarity == "RARO":
		return Color("bd8cff")
	return Color("e7e1f5")


func show_stage_banner(text: String) -> void:
	if stage_banner_tween and stage_banner_tween.is_valid():
		stage_banner_tween.kill()
	stage_banner.text = text
	stage_banner.modulate = Color(1, 1, 1, 0)
	stage_banner.show()
	stage_banner_tween = create_tween()
	stage_banner_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	stage_banner_tween.tween_property(stage_banner, "modulate", Color.WHITE, 0.25)
	stage_banner_tween.tween_interval(1.65)
	stage_banner_tween.tween_property(stage_banner, "modulate", Color(1, 1, 1, 0), 0.45)
	stage_banner_tween.tween_callback(stage_banner.hide)


func show_boss_intro(boss_name: String, subtitle: String, final_boss := false) -> void:
	if boss_intro_tween and boss_intro_tween.is_valid():
		boss_intro_tween.kill()
	boss_intro_label.text = "%s\n%s" % [subtitle, boss_name]
	boss_intro_label.add_theme_color_override("font_color", Color("ffd36b") if final_boss else Color("f2c4ff"))
	boss_intro.modulate = Color(1, 1, 1, 0)
	boss_intro.show()
	boss_intro_tween = create_tween()
	boss_intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	boss_intro_tween.tween_property(boss_intro, "modulate", Color.WHITE, 0.22)
	boss_intro_tween.tween_interval(1.25)
	boss_intro_tween.tween_property(boss_intro, "modulate", Color(1, 1, 1, 0), 0.40)
	boss_intro_tween.tween_callback(boss_intro.hide)


func flash_damage(intensity := -1.0) -> void:
	var strength := flash_intensity if intensity < 0.0 else clampf(intensity, 0.0, 1.0)
	if strength <= 0.01:
		return
	if damage_flash_tween and damage_flash_tween.is_valid():
		damage_flash_tween.kill()
	damage_flash.color = Color(0.65, 0.02, 0.12, 0.32 * strength)
	damage_flash_tween = create_tween()
	damage_flash_tween.tween_property(damage_flash, "color", Color(0.65, 0.02, 0.12, 0.0), 0.35)


func show_end_screen(
	victory: bool, survived: float, kills: int, level: int, essence := 0,
	next_biome := "", extra_stats := "", new_achievements: Array[String] = []
) -> void:
	end_overlay.show()
	end_title.text = "VITÓRIA!" if victory else "GAME OVER"
	end_title.add_theme_color_override("font_color", Color("ffd36b") if victory else Color("ff687d"))
	var minutes := floori(survived / 60.0)
	var seconds := int(survived) % 60
	var result_line := "O chefe final caiu. A próxima fase foi aberta: %s." % next_biome if victory else "Sua jornada terminou, mas você pode reiniciar esta fase."
	var achievement_text := ""
	if not new_achievements.is_empty():
		achievement_text = "\n\nCONQUISTA DESBLOQUEADA  ·  %s" % ", ".join(new_achievements)
	end_summary.text = "%s\n\nTempo sobrevivido  %02d:%02d  ·  Inimigos mortos  %d  ·  Nível  %d\nEssência conquistada  %d\n\n%s%s" % [result_line, minutes, seconds, kills, level, essence, extra_stats, achievement_text]
	$EndOverlay/Panel/Margin/VBox/Restart.text = "PRÓXIMA FASE" if victory else "TENTAR NOVAMENTE"
	end_summary_scroll.scroll_vertical = 0
	_update_end_layout()
	_update_end_layout.call_deferred()
	$EndOverlay/Panel/Margin/VBox/Restart.grab_focus()


func _update_end_layout() -> void:
	if not is_instance_valid(end_overlay) or not is_instance_valid(end_panel):
		return
	var viewport_size := end_overlay.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var horizontal_inset := clampf(viewport_size.x * 0.035, 10.0, 40.0)
	var vertical_inset := clampf(viewport_size.y * 0.035, 8.0, 28.0)
	var panel_size := Vector2(
		minf(920.0, maxf(1.0, viewport_size.x - horizontal_inset * 2.0)),
		minf(650.0, maxf(1.0, viewport_size.y - vertical_inset * 2.0))
	)
	end_panel.size = panel_size
	end_panel.position = (viewport_size - panel_size) * 0.5
	var horizontal_margin := int(roundf(clampf(viewport_size.x * 0.04, 16.0, 50.0)))
	var vertical_margin := int(roundf(clampf(viewport_size.y * 0.035, 10.0, 30.0)))
	end_margin.add_theme_constant_override("margin_left", horizontal_margin)
	end_margin.add_theme_constant_override("margin_right", horizontal_margin)
	end_margin.add_theme_constant_override("margin_top", vertical_margin)
	end_margin.add_theme_constant_override("margin_bottom", vertical_margin)
	end_vbox.add_theme_constant_override(
		"separation",
		int(roundf(clampf(viewport_size.y * 0.02, 8.0, 20.0)))
	)
	end_title.add_theme_font_size_override(
		"font_size",
		int(roundf(clampf(viewport_size.y * 0.052, 24.0, 38.0)))
	)
	end_summary.add_theme_font_size_override(
		"font_size",
		int(roundf(clampf(viewport_size.y * 0.025, 14.0, 18.0)))
	)
	var button_height := roundf(clampf(viewport_size.y * 0.075, 42.0, 58.0))
	var button_font_size := int(roundf(clampf(viewport_size.y * 0.032, 15.0, 20.0)))
	for button in [end_restart_button, end_menu_button]:
		button.custom_minimum_size = Vector2(0.0, button_height)
		button.add_theme_font_size_override("font_size", button_font_size)


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action("map_toggle") and event.is_action_pressed("map_toggle"):
		minimap.visible = not minimap.visible
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel") or end_overlay.visible or upgrade_overlay.visible or relic_overlay.visible:
		return
	if pause_overlay.visible:
		_on_resume_pressed()
	else:
		_refresh_pause_character_panel()
		pause_overlay.show()
		get_tree().paused = true
		pause_buttons[0].grab_focus()
	get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	pause_overlay.hide()
	resume_requested.emit()
