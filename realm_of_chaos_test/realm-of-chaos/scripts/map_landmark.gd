class_name MapLandmark
extends StaticBody2D

const LANDMARK_TEXTURE = preload("res://assets/generated/map_landmarks_v1.png")
const REDRAW_INTERVAL := 1.0 / 20.0
const VISUAL_SCALE := 0.44
const VISUAL_BASE_Y := -102.0
const VISUAL_NOTIFIER_RECT := Rect2(Vector2(-142.0, -275.0), Vector2(284.0, 385.0))

const TITLES := {
	"altar": "ALTAR RUBRO",
	"obelisk": "OBELISCO CRONAL",
	"tree": "SANTUÁRIO DAS ALMAS",
	"portal": "PORTAL FRATURADO"
}

const COLORS := {
	"altar": Color("ff5c61"),
	"obelisk": Color("69ddff"),
	"tree": Color("58e3d0"),
	"portal": Color("c36cff")
}

var world: Node
var landmark_kind := "altar"
var frame_index := 0
var activated := false
var animation_time := 0.0
var visual_on_screen := false
var redraw_timer := 0.0
var sprite: Sprite2D
var prompt: Label
var screen_notifier: VisibleOnScreenNotifier2D


func configure(owner_world: Node, kind: String, landmark_position: Vector2, atlas_frame: int) -> void:
	world = owner_world
	landmark_kind = kind
	global_position = landmark_position
	frame_index = atlas_frame


func _ready() -> void:
	z_index = 3
	add_to_group("map_landmarks")
	sprite = Sprite2D.new()
	sprite.texture = LANDMARK_TEXTURE
	sprite.hframes = 4
	sprite.frame = frame_index
	sprite.position.y = VISUAL_BASE_Y
	sprite.scale = Vector2.ONE * VISUAL_SCALE
	add_child(sprite)
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 43.0
	collision.position.y = -4.0
	collision.shape = circle
	add_child(collision)
	prompt = Label.new()
	prompt.position = Vector2(-125.0, 54.0)
	prompt.size = Vector2(250.0, 42.0)
	prompt.text = "%s\nAPROXIME-SE" % str(TITLES[landmark_kind])
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 13)
	prompt.add_theme_color_override("font_color", COLORS[landmark_kind])
	prompt.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.04, 0.95))
	prompt.add_theme_constant_override("outline_size", 5)
	add_child(prompt)
	screen_notifier = VisibleOnScreenNotifier2D.new()
	screen_notifier.name = "VisibleOnScreenNotifier2D"
	screen_notifier.rect = VISUAL_NOTIFIER_RECT
	screen_notifier.show_rect = false
	add_child(screen_notifier)
	screen_notifier.screen_entered.connect(_on_screen_entered)
	screen_notifier.screen_exited.connect(_on_screen_exited)
	redraw_timer = REDRAW_INTERVAL * (0.25 + _visual_phase() * 0.75)
	queue_redraw()


func _process(delta: float) -> void:
	animation_time += delta
	if visual_on_screen and is_instance_valid(sprite):
		sprite.position.y = VISUAL_BASE_Y + sin(animation_time * 1.8 + frame_index) * 2.0
	if not activated and is_instance_valid(world) and is_instance_valid(world.player):
		var distance := global_position.distance_to(world.player.global_position)
		prompt.visible = distance < 430.0
		if distance <= 112.0:
			world.activate_landmark(self)
	if visual_on_screen:
		redraw_timer -= delta
		if redraw_timer <= 0.0:
			redraw_timer += REDRAW_INTERVAL
			queue_redraw()


func mark_activated() -> void:
	activated = true
	prompt.text = "%s\nATIVADO" % str(TITLES[landmark_kind])
	prompt.modulate.a = 0.72
	if is_instance_valid(sprite):
		sprite.modulate = Color(0.72, 0.72, 0.78, 0.86)
	queue_redraw()


func minimap_color() -> Color:
	return Color(0.42, 0.42, 0.50, 0.62) if activated else COLORS[landmark_kind]


func _visual_phase() -> float:
	return float(get_instance_id() % 997) / 997.0


func _on_screen_entered() -> void:
	visual_on_screen = true
	if is_instance_valid(sprite):
		sprite.position.y = VISUAL_BASE_Y + sin(animation_time * 1.8 + frame_index) * 2.0
	queue_redraw()
	redraw_timer = REDRAW_INTERVAL * (0.25 + _visual_phase() * 0.75)


func _on_screen_exited() -> void:
	visual_on_screen = false


func _ring_points(radius: float, point_count: int, phase: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := phase + TAU * float(index) / float(point_count)
		var point_radius := radius * (0.94 if index % 2 == 0 else 1.0)
		points.append(Vector2.RIGHT.rotated(angle) * point_radius)
	return points


func _draw() -> void:
	var color: Color = COLORS[landmark_kind]
	var pulse := (sin(animation_time * 2.1 + frame_index) + 1.0) * 0.5
	var radius := 84.0 + pulse * 5.0
	var points := _ring_points(radius, 12, animation_time * 0.08)
	var fill := Color(color, 0.035 if activated else 0.065 + pulse * 0.018)
	var edge := Color(color, 0.20 if activated else 0.58)
	draw_colored_polygon(points, fill)
	for index in range(4):
		var angle := animation_time * 0.18 + TAU * float(index) / 4.0
		var marker_position := Vector2.RIGHT.rotated(angle) * (radius - 3.0)
		var radial := marker_position.normalized()
		var tangent := radial.rotated(PI * 0.5)
		draw_colored_polygon(PackedVector2Array([
			marker_position + radial * 6.0,
			marker_position + tangent * 4.0,
			marker_position - radial * 6.0,
			marker_position - tangent * 4.0,
		]), Color(0.025, 0.012, 0.038, 0.90) if activated else edge)
