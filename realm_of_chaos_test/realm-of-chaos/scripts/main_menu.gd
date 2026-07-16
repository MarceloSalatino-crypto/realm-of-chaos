extends Control

@onready var btn_jogar = $VBoxContainer/Button
@onready var btn_instrucoes = $VBoxContainer/Button2
@onready var btn_creditos = $VBoxContainer/Button3

func _ready():
	btn_jogar.pressed.connect(_on_jogar)
	btn_instrucoes.pressed.connect(_on_instrucoes)
	btn_creditos.pressed.connect(_on_creditos)

func _on_jogar():
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_instrucoes():
	show_panel("INSTRUÇÕES",
	"• WASD ou setas para mover\n• O personagem atira automaticamente no inimigo mais próximo\n• Sobreviva o máximo de tempo possível\n• Cuidado com os magos — eles atiram bolas de gelo à distância\n• Inimigos elite são mais resistentes e causam mais dano")

func _on_creditos():
	show_panel("CRÉDITOS",
	"Desenvolvido por Marcelo Galimberti Salatino e Bruno Aloy\n\nEngine: Godot 4.6\n\nInspirado em Vampire Survivors\n\nArte: Em desenvolvimento\n\nMúsica: Em desenvolvimento")

func show_panel(titulo: String, conteudo: String):
	var overlay = ColorRect.new()
	overlay.color = Color(0.05, 0.02, 0.08, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = titulo
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color("c8a028"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	var content_label = Label.new()
	content_label.text = conteudo
	content_label.add_theme_font_size_override("font_size", 20)
	content_label.add_theme_color_override("font_color", Color("ffffff"))
	content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(content_label)
	
	var btn_fechar = Button.new()
	btn_fechar.text = "Fechar"
	btn_fechar.add_theme_font_size_override("font_size", 20)
	btn_fechar.pressed.connect(func():
		overlay.queue_free()
		vbox.queue_free()
	)
	vbox.add_child(btn_fechar)
