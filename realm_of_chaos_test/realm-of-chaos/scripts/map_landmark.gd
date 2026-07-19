class_name MapLandmark
extends StaticBody2D

const LANDMARK_TEXTURE = preload("res://assets/generated/map_landmarks_v1.png")

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
var sprite: Sprite2D
var prompt: Label


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
	sprite.position.y = -58.0
	sprite.scale = Vector2.ONE * 0.265
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
	queue_redraw()


func _process(delta: float) -> void:
	animation_time += delta
	if is_instance_valid(sprite):
		sprite.position.y = -58.0 + sin(animation_time * 1.8 + frame_index) * 2.0
	if not activated and is_instance_valid(world) and is_instance_valid(world.player):
		var distance := global_position.distance_to(world.player.global_position)
		prompt.visible = distance < 430.0
		if distance <= 112.0:
			world.activate_landmark(self)
	queue_redraw()


func mark_activated() -> void:
	activated = true
	prompt.text = "%s\nATIVADO" % str(TITLES[landmark_kind])
	prompt.modulate.a = 0.72
	if is_instance_valid(sprite):
		sprite.modulate = Color(0.72, 0.72, 0.78, 0.86)


func minimap_color() -> Color:
	return Color(0.42, 0.42, 0.50, 0.62) if activated else COLORS[landmark_kind]


func _draw() -> void:
	var color: Color = COLORS[landmark_kind]
	var pulse := (sin(animation_time * 2.1 + frame_index) + 1.0) * 0.5
	var alpha := 0.06 if activated else 0.10 + pulse * 0.035
	draw_circle(Vector2.ZERO, 76.0 + pulse * 6.0, Color(color, alpha))
	draw_arc(Vector2.ZERO, 84.0 + pulse * 5.0, animation_time * 0.25, animation_time * 0.25 + PI * 1.55, 48, Color(color, 0.18 if activated else 0.48), 2.5)
