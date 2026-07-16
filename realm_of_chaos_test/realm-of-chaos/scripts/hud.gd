extends CanvasLayer

@onready var health_bar = $HealthBar
@onready var info = $Info

func update_hp(current, maximum):
	health_bar.max_value = maximum
	health_bar.value = current

func update_timer(time: float):
	var minutes = int(time) / 60
	var seconds = int(time) % 60
	info.text = "FASE 1 pronta | WASD ou setas para mover | Câmera suave | Player animado | %02d:%02d" % [minutes, seconds]

func show_game_over(time_survived: float, enemies_killed: int):
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)
	
	var title = Label.new()
	title.text = "GAME OVER"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var minutes = int(time_survived) / 60
	var seconds = int(time_survived) % 60
	var time_label = Label.new()
	time_label.text = "Tempo: %02d:%02d" % [minutes, seconds]
	time_label.add_theme_font_size_override("font_size", 24)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(time_label)
	
	var kills_label = Label.new()
	kills_label.text = "Inimigos mortos: %d" % enemies_killed
	kills_label.add_theme_font_size_override("font_size", 24)
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(kills_label)
	
	var button = Button.new()
	button.text = "Reiniciar"
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(_on_restart_pressed)
	vbox.add_child(button)

func show_victory(enemies_killed: int):
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)
	
	var title = Label.new()
	title.text = "VITÓRIA!"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("c8a028"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Você sobreviveu 25 minutos no Realm of Chaos!"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	
	var kills_label = Label.new()
	kills_label.text = "Inimigos mortos: %d" % enemies_killed
	kills_label.add_theme_font_size_override("font_size", 24)
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(kills_label)
	
	var button = Button.new()
	button.text = "Menu Principal"
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(_on_menu_pressed)
	vbox.add_child(button)

func _on_restart_pressed():
	get_tree().reload_current_scene()

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")
