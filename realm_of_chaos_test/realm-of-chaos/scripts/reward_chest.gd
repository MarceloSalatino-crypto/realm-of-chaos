class_name RewardChest
extends Node2D

const CHEST_TEXTURE = preload("res://assets/generated/boss_reward_chest.png")

var world: Node
var source_boss := ""
var opened := false
var animation_time := 0.0
var sprite: Sprite2D
var prompt: Label


func _ready() -> void:
	z_index = 6
	sprite = Sprite2D.new()
	sprite.texture = CHEST_TEXTURE
	sprite.hframes = 4
	sprite.frame = 0
	sprite.scale = Vector2.ONE * 0.235
	sprite.position.y = -18.0
	add_child(sprite)
	prompt = Label.new()
	prompt.text = "APROXIME-SE · RELÍQUIA"
	prompt.position = Vector2(-105.0, 54.0)
	prompt.size = Vector2(210.0, 28.0)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 13)
	prompt.add_theme_color_override("font_color", Color("f3d884"))
	prompt.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.04, 0.9))
	prompt.add_theme_constant_override("shadow_offset_x", 2)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	add_child(prompt)
	queue_redraw()


func setup(owner_world: Node, chest_position: Vector2, boss_name: String) -> void:
	world = owner_world
	global_position = chest_position
	source_boss = boss_name


func _process(delta: float) -> void:
	animation_time += delta
	if is_instance_valid(sprite):
		sprite.position.y = -18.0 + sin(animation_time * 2.4) * 2.4
	if is_instance_valid(prompt):
		prompt.modulate.a = 0.72 + (sin(animation_time * 3.1) + 1.0) * 0.14
	if opened or not is_instance_valid(world) or not is_instance_valid(world.player):
		return
	if global_position.distance_to(world.player.global_position) <= 72.0:
		_start_opening()
	queue_redraw()


func _start_opening() -> void:
	opened = true
	prompt.text = "RECOMPENSA DESPERTADA"
	var tween := create_tween()
	tween.tween_callback(_set_frame.bind(1))
	tween.tween_interval(0.16)
	tween.tween_callback(_set_frame.bind(2))
	tween.tween_interval(0.22)
	tween.tween_callback(_set_frame.bind(3))
	tween.tween_interval(0.28)
	tween.tween_callback(_request_reward)


func _set_frame(value: int) -> void:
	if is_instance_valid(sprite):
		sprite.frame = value


func _request_reward() -> void:
	if is_instance_valid(world) and world.has_method("open_reward_chest"):
		world.open_reward_chest(self)


func _draw() -> void:
	var pulse := (sin(animation_time * 2.6) + 1.0) * 0.5
	draw_circle(Vector2(0.0, 18.0), 42.0 + pulse * 5.0, Color(0.54, 0.20, 0.88, 0.08))
	draw_arc(Vector2(0.0, 18.0), 47.0 + pulse * 4.0, animation_time, animation_time + PI * 1.45, 36, Color(0.88, 0.62, 1.0, 0.36), 2.0)
