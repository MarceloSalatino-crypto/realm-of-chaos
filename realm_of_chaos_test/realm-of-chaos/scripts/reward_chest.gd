class_name RewardChest
extends Node2D

const CHEST_TEXTURE = preload("res://assets/generated/boss_reward_chest.png")
const REDRAW_INTERVAL := 1.0 / 20.0

var world: Node
var source_boss := ""
var opened := false
var animation_time := 0.0
var visual_on_screen := false
var redraw_timer := 0.0
var sprite: Sprite2D
var prompt: Label
var screen_notifier: VisibleOnScreenNotifier2D


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
	screen_notifier = VisibleOnScreenNotifier2D.new()
	screen_notifier.name = "VisibleOnScreenNotifier2D"
	screen_notifier.rect = Rect2(Vector2(-82.0, -92.0), Vector2(164.0, 176.0))
	screen_notifier.show_rect = false
	add_child(screen_notifier)
	screen_notifier.screen_entered.connect(_on_screen_entered)
	screen_notifier.screen_exited.connect(_on_screen_exited)
	redraw_timer = REDRAW_INTERVAL * (0.25 + _visual_phase() * 0.75)
	queue_redraw()


func setup(owner_world: Node, chest_position: Vector2, boss_name: String) -> void:
	world = owner_world
	global_position = chest_position
	source_boss = boss_name


func _process(delta: float) -> void:
	animation_time += delta
	if visual_on_screen and is_instance_valid(sprite):
		sprite.position.y = -18.0 + sin(animation_time * 2.4) * 2.4
	if visual_on_screen and is_instance_valid(prompt):
		prompt.modulate.a = 0.72 + (sin(animation_time * 3.1) + 1.0) * 0.14
	if opened or not is_instance_valid(world) or not is_instance_valid(world.player):
		return
	if global_position.distance_to(world.player.global_position) <= 72.0:
		_start_opening()
	if visual_on_screen:
		redraw_timer -= delta
		if redraw_timer <= 0.0:
			redraw_timer += REDRAW_INTERVAL
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


func _visual_phase() -> float:
	return float(get_instance_id() % 997) / 997.0


func _on_screen_entered() -> void:
	visual_on_screen = true
	if is_instance_valid(sprite):
		sprite.position.y = -18.0 + sin(animation_time * 2.4) * 2.4
	queue_redraw()
	redraw_timer = REDRAW_INTERVAL * (0.25 + _visual_phase() * 0.75)


func _on_screen_exited() -> void:
	visual_on_screen = false


func _ring_points(radius: float, point_count: int, phase: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := phase + TAU * float(index) / float(point_count)
		var point_radius := radius * (0.93 if index % 2 == 0 else 1.0)
		points.append(Vector2.RIGHT.rotated(angle) * point_radius + Vector2(0.0, 18.0))
	return points


func _draw() -> void:
	var pulse := (sin(animation_time * 2.6) + 1.0) * 0.5
	var radius := 47.0 + pulse * 4.0
	var points := _ring_points(radius, 10, animation_time * 0.18)
	draw_colored_polygon(points, Color(0.40, 0.10, 0.60, 0.055))
	for index in range(4):
		var angle := -animation_time * 0.28 + TAU * float(index) / 4.0
		var radial := Vector2.RIGHT.rotated(angle)
		var tangent := radial.rotated(PI * 0.5)
		var position := Vector2(0.0, 18.0) + radial * (radius - 2.0)
		draw_colored_polygon(PackedVector2Array([
			position + radial * 5.5,
			position + tangent * 3.5,
			position - radial * 5.5,
			position - tangent * 3.5,
		]), Color("f0bd57") if opened else Color("c889ff"))
