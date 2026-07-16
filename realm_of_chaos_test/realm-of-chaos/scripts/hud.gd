extends CanvasLayer

signal upgrade_selected(upgrade_id: String, rarity: String)
signal restart_requested
signal menu_requested
signal resume_requested

var upgrade_options: Array[Dictionary] = []
var modal_open := false

@onready var health_bar: ProgressBar = $Top/HealthBar
@onready var health_label: Label = $Top/HealthBar/Label
@onready var xp_bar: ProgressBar = $XPBar
@onready var timer_label: Label = $Top/Timer
@onready var level_label: Label = $Top/Level
@onready var kills_label: Label = $Top/Kills
@onready var stage_label: Label = $Top/Stage
@onready var weapons_label: Label = $Weapons
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


func update_run(
	current_hp: float, maximum_hp: float, current_xp: int, needed_xp: int,
	level: int, kills: int, remaining: float, stage: String, weapon_summary: String
) -> void:
	health_bar.max_value = maximum_hp
	health_bar.value = current_hp
	health_label.text = "%d / %d" % [ceili(current_hp), ceili(maximum_hp)]
	xp_bar.max_value = needed_xp
	xp_bar.value = current_xp
	level_label.text = "NÍVEL %02d" % level
	kills_label.text = "☠  %04d" % kills
	var minutes := int(remaining) / 60
	var seconds := int(remaining) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	stage_label.text = stage
	weapons_label.text = weapon_summary


func show_boss(name: String, current: float, maximum: float) -> void:
	boss_panel.show()
	boss_label.text = name
	update_boss(current, maximum)


func update_boss(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = maxf(0.0, current)


func hide_boss() -> void:
	boss_panel.hide()


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


func flash_damage() -> void:
	damage_flash.color = Color(0.65, 0.02, 0.12, 0.32)
	var tween := create_tween()
	tween.tween_property(damage_flash, "color", Color(0.65, 0.02, 0.12, 0.0), 0.35)


func show_end_screen(victory: bool, survived: float, kills: int, level: int) -> void:
	modal_open = true
	end_overlay.show()
	end_title.text = "O VÉU FOI SELADO" if victory else "O CAOS PREVALECEU"
	end_title.add_theme_color_override("font_color", Color("ffd36b") if victory else Color("ff687d"))
	var minutes := int(survived) / 60
	var seconds := int(survived) % 60
	end_summary.text = "Tempo sobrevivido  %02d:%02d\nInimigos banidos  %d\nNível alcançado  %d" % [minutes, seconds, kills, level]
	$EndOverlay/Panel/Margin/VBox/Restart.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or end_overlay.visible or upgrade_overlay.visible:
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
