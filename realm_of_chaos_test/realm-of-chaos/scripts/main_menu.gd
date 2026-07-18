extends Control

const SAVE_PATH := "user://realm_of_chaos.cfg"

var animation_time := 0.0
var popup: Control
var hero_base_y := 0.0

@onready var hero: TextureRect = $Hero
@onready var play_button: Button = $Menu/Play
@onready var records_label: Label = $Menu/Records


func _ready() -> void:
	get_tree().paused = false
	hero_base_y = hero.position.y
	play_button.pressed.connect(_on_play)
	$Menu/Instructions.pressed.connect(_show_instructions)
	$Menu/Credits.pressed.connect(_show_credits)
	_load_records()
	play_button.grab_focus()


func _process(delta: float) -> void:
	animation_time += delta
	hero.position.y = hero_base_y + sin(animation_time * 1.5) * 7.0
	hero.rotation = sin(animation_time * 0.8) * 0.006


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _load_records() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		records_label.text = "SEU PRIMEIRO RITUAL AGUARDA"
		return
	var best_time := float(config.get_value("record", "best_time", 0.0))
	var best_kills := int(config.get_value("record", "best_kills", 0))
	var victories := int(config.get_value("record", "victories", 0))
	@warning_ignore("integer_division")
	records_label.text = "RECORDE  %02d:%02d   ·   %d BANIDOS   ·   %d VITÓRIAS" % [int(best_time) / 60, int(best_time) % 60, best_kills, victories]


func _show_instructions() -> void:
	_show_popup(
		"COMO SOBREVIVER",
		"WASD, SETAS OU ANALÓGICO\nMova o Guardião; a arma inicial é sorteada e ataca automaticamente.\n\nCOLETE CRISTAIS\nCada nível oferece três poderes. Combine armas e passivos.\n\nENFRENTE O RITUAL POR 25 MINUTOS\n0–5 Normal · 5–10 Difícil · 10–15 Caos · 15–25 Modo Inferno.\nChefes marcam as grandes transições do ritual.\n\nESC pausa o jogo. Corações restauram vida."
	)


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
