extends CanvasLayer

const MinimapScript = preload("res://scripts/minimap.gd")

signal upgrade_selected(upgrade_id: String, rarity: String)
signal relic_selected(relic_id: String)
signal restart_requested
signal menu_requested
signal resume_requested

var upgrade_options: Array[Dictionary] = []
var relic_options: Array[Dictionary] = []
var modal_open := false
var flash_intensity := 0.70
var relic_overlay: Control
var relic_title: Label
var relic_buttons: Array[Button] = []
var boss_intro: Control
var boss_intro_label: Label
var minimap: Control
var dash_label: Label

@onready var health_bar: ProgressBar = $Top/HealthBar
@onready var health_label: Label = $Top/HealthBar/Label
@onready var xp_bar: ProgressBar = $XPBar
@onready var timer_label: Label = $Top/Timer
@onready var level_label: Label = $Top/Level
@onready var kills_label: Label = $Top/Kills
@onready var essence_label: Label = $Top/Essence
@onready var stage_label: Label = $Top/Stage
@onready var weapons_label: Label = $Weapons
@onready var world_event_label: Label = $WorldEvent
@onready var boss_panel: Control = $Boss
@onready var boss_bar: ProgressBar = $Boss/Bar
@onready var boss_label: Label = $Boss/Name
@onready var stage_banner: Label = $StageBanner
@onready var damage_flash: ColorRect = $DamageFlash
@onready var upgrade_overlay: Control = $UpgradeOverlay
@onready var upgrade_title: Label = $UpgradeOverlay/Panel/Margin/VBox/Title
@onready var upgrade_buttons: Array[Button] = [
	$UpgradeOverlay/Panel/Margin/VBox/Cards/Card1,
	$UpgradeOverlay/Panel/Margin/VBox/Cards/Card2,
	$UpgradeOverlay/Panel/Margin/VBox/Cards/Card3
]
@onready var pause_overlay: Control = $PauseOverlay
@onready var end_overlay: Control = $EndOverlay
@onready var end_title: Label = $EndOverlay/Panel/Margin/VBox/Title
@onready var end_summary: Label = $EndOverlay/Panel/Margin/VBox/Summary


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in range(upgrade_buttons.size()):
		upgrade_buttons[index].pressed.connect(_on_upgrade_button_pressed.bind(index))
	$PauseOverlay/Panel/VBox/Resume.pressed.connect(_on_resume_pressed)
	$PauseOverlay/Panel/VBox/Restart.pressed.connect(func(): restart_requested.emit())
	$PauseOverlay/Panel/VBox/Menu.pressed.connect(func(): menu_requested.emit())
	$EndOverlay/Panel/Margin/VBox/Restart.pressed.connect(func(): restart_requested.emit())
	$EndOverlay/Panel/Margin/VBox/Menu.pressed.connect(func(): menu_requested.emit())
	_build_relic_overlay()
	_build_boss_intro()
	_build_navigation_ui()
	end_summary.add_theme_font_size_override("font_size", 18)


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
	dash_label = Label.new()
	dash_label.name = "DashStatus"
	dash_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	dash_label.position = Vector2(24.0, -72.0)
	dash_label.size = Vector2(360.0, 48.0)
	dash_label.text = "ESPAÇO / A · ESQUIVA PRONTA"
	dash_label.add_theme_font_size_override("font_size", 14)
	dash_label.add_theme_color_override("font_color", Color("cbb2df"))
	dash_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.04, 0.94))
	dash_label.add_theme_constant_override("outline_size", 4)
	dash_label.z_index = -2
	add_child(dash_label)


func bind_world(world: Node) -> void:
	if is_instance_valid(minimap):
		minimap.bind_world(world)


func update_navigation(dash_status: String, blessing: String, blessing_remaining: float) -> void:
	var blessing_text := ""
	if blessing_remaining > 0.0:
		blessing_text = "  ·  %s %ds" % [blessing, ceili(blessing_remaining)]
	dash_label.text = "ESPAÇO / A · ESQUIVA %s%s" % [dash_status, blessing_text]
	dash_label.add_theme_color_override("font_color", Color("7fe9ff") if dash_status == "PRONTA" else Color("a98fbd"))


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
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-500.0, -295.0)
	panel.size = Vector2(1000.0, 590.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("171027")
	panel_style.border_color = Color("c88dff")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	relic_overlay.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34 if side in ["top", "bottom"] else 42)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	relic_title = Label.new()
	relic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_title.add_theme_font_size_override("font_size", 32)
	relic_title.add_theme_color_override("font_color", Color("ffd36b"))
	box.add_child(relic_title)
	var subtitle := Label.new()
	subtitle.text = "Uma relíquia ficará com você até o fim da partida"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("cbb8df"))
	box.add_child(subtitle)
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 16)
	box.add_child(cards)
	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(285.0, 390.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_relic_button_pressed.bind(index))
		cards.add_child(button)
		relic_buttons.append(button)
	relic_overlay.hide()


func _build_boss_intro() -> void:
	boss_intro = Control.new()
	boss_intro.name = "BossIntro"
	boss_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(boss_intro)
	var band := ColorRect.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.color = Color(0.03, 0.005, 0.06, 0.86)
	band.set_anchors_preset(Control.PRESET_CENTER)
	band.position = Vector2(-580.0, -78.0)
	band.size = Vector2(1160.0, 156.0)
	boss_intro.add_child(band)
	boss_intro_label = Label.new()
	boss_intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_intro_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_intro_label.add_theme_font_size_override("font_size", 34)
	boss_intro_label.add_theme_color_override("font_color", Color("f2c4ff"))
	boss_intro_label.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.07, 1.0))
	boss_intro_label.add_theme_constant_override("outline_size", 7)
	boss_intro.add_child(boss_intro_label)
	boss_intro.hide()


func update_run(
	current_hp: float, maximum_hp: float, current_xp: int, needed_xp: int,
	level: int, kills: int, remaining: float, stage: String, weapon_summary: String,
	essence := 0, event_title := ""
) -> void:
	health_bar.max_value = maximum_hp
	health_bar.value = current_hp
	health_label.text = "%d / %d" % [ceili(current_hp), ceili(maximum_hp)]
	xp_bar.max_value = needed_xp
	xp_bar.value = current_xp
	level_label.text = "NÍVEL %02d" % level
	kills_label.text = "☠  %04d" % kills
	essence_label.text = "ESSÊNCIA  %03d" % essence
	world_event_label.text = event_title
	var minutes := int(remaining) / 60
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
	weapons_label.text = weapon_summary


func show_boss(name: String, current: float, maximum: float) -> void:
	boss_panel.show()
	boss_label.text = name
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
	modal_open = true
	upgrade_options = options
	upgrade_title.text = "NÍVEL %d · ESCOLHA SEU PODER" % new_level
	upgrade_overlay.show()
	for index in range(upgrade_buttons.size()):
		var button := upgrade_buttons[index]
		if index >= options.size():
			button.hide()
			continue
		button.show()
		var option := options[index]
		button.text = "%s\n\n%s\nNÍVEL %d\n\n%s\n\n[%s]" % [
			option.icon, option.title, option.level, option.description, option.rarity
		]
		var rarity_color := Color("ffcc66") if option.rarity == "LENDÁRIO" else (Color("bd8cff") if option.rarity == "RARO" else Color("e7e1f5"))
		button.add_theme_color_override("font_color", rarity_color)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
	upgrade_buttons[0].grab_focus()


func hide_level_up() -> void:
	modal_open = false
	upgrade_overlay.hide()


func show_relic_choice(options: Array[Dictionary], boss_name := "") -> void:
	modal_open = true
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
	relic_buttons[0].grab_focus()


func hide_relic_choice() -> void:
	modal_open = false
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


func show_stage_banner(text: String) -> void:
	stage_banner.text = text
	stage_banner.modulate = Color(1, 1, 1, 0)
	stage_banner.show()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(stage_banner, "modulate", Color.WHITE, 0.25)
	tween.tween_interval(1.65)
	tween.tween_property(stage_banner, "modulate", Color(1, 1, 1, 0), 0.45)
	tween.tween_callback(stage_banner.hide)


func show_boss_intro(boss_name: String, subtitle: String, final_boss := false) -> void:
	boss_intro_label.text = "%s\n%s" % [subtitle, boss_name]
	boss_intro_label.add_theme_color_override("font_color", Color("ffd36b") if final_boss else Color("f2c4ff"))
	boss_intro.modulate = Color(1, 1, 1, 0)
	boss_intro.show()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(boss_intro, "modulate", Color.WHITE, 0.22)
	tween.tween_interval(1.25)
	tween.tween_property(boss_intro, "modulate", Color(1, 1, 1, 0), 0.40)
	tween.tween_callback(boss_intro.hide)


func flash_damage(intensity := -1.0) -> void:
	var strength := flash_intensity if intensity < 0.0 else clampf(intensity, 0.0, 1.0)
	if strength <= 0.01:
		return
	damage_flash.color = Color(0.65, 0.02, 0.12, 0.32 * strength)
	var tween := create_tween()
	tween.tween_property(damage_flash, "color", Color(0.65, 0.02, 0.12, 0.0), 0.35)


func show_end_screen(
	victory: bool, survived: float, kills: int, level: int, essence := 0,
	next_biome := "", extra_stats := "", new_achievements: Array[String] = []
) -> void:
	modal_open = true
	end_overlay.show()
	end_title.text = "VITÓRIA!" if victory else "GAME OVER"
	end_title.add_theme_color_override("font_color", Color("ffd36b") if victory else Color("ff687d"))
	var minutes := int(survived) / 60
	var seconds := int(survived) % 60
	var result_line := "O chefe final caiu. A próxima fase foi aberta: %s." % next_biome if victory else "Sua jornada terminou, mas você pode reiniciar esta fase."
	var achievement_text := ""
	if not new_achievements.is_empty():
		achievement_text = "\n\nCONQUISTA DESBLOQUEADA  ·  %s" % ", ".join(new_achievements)
	end_summary.text = "%s\n\nTempo sobrevivido  %02d:%02d  ·  Inimigos mortos  %d  ·  Nível  %d\nEssência conquistada  %d\n\n%s%s" % [result_line, minutes, seconds, kills, level, essence, extra_stats, achievement_text]
	$EndOverlay/Panel/Margin/VBox/Restart.text = "PRÓXIMA FASE" if victory else "TENTAR NOVAMENTE"
	$EndOverlay/Panel/Margin/VBox/Restart.grab_focus()


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
		pause_overlay.show()
		modal_open = true
		get_tree().paused = true
		$PauseOverlay/Panel/VBox/Resume.grab_focus()
	get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	pause_overlay.hide()
	modal_open = false
	resume_requested.emit()
