extends Node2D


const BLADE_COUNT := 3
const ARC_STEPS := 11
const OUTLINE_COLOR := Color("210d1a")
const SHADOW_COLOR := Color("5a1428")
const BLADE_COLOR := Color("c92d4d")
const EDGE_COLOR := Color("ff8799")

var max_radius := 245.0
var duration := 0.30
var age := 0.0
var base_angle := 0.0


func _ready() -> void:
	z_index = 18


func setup(world_position: Vector2, attack_angle: float, radius: float, life := 0.30) -> void:
	global_position = world_position
	base_angle = attack_angle
	max_radius = radius
	duration = life
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(age / duration, 0.0, 1.0)
	var sweep := sin(progress * PI * 0.5)
	var fade := 1.0 - smoothstep(0.52, 1.0, progress)
	var scale_factor := lerpf(0.78, 1.0, sweep)
	var rotation_offset := base_angle - 0.46 + sweep * 0.92
	for blade_index in range(BLADE_COUNT):
		var angle := rotation_offset + TAU * float(blade_index) / float(BLADE_COUNT)
		var radius_factor := 0.90 - float(blade_index) * 0.018
		_draw_blade(angle, max_radius * scale_factor * radius_factor, fade, blade_index)


func _draw_blade(start_angle: float, radius: float, alpha: float, blade_index: int) -> void:
	var span := 1.27
	var root_radius := radius * 0.42
	var phase := float(blade_index) * 0.19
	var outline := _blade_polygon(start_angle, span, root_radius, radius + 5.0, 48.0, phase)
	var blade := _blade_polygon(start_angle, span, root_radius + 4.0, radius, 38.0, phase + 0.07)
	var shadow := _blade_polygon(start_angle + 0.025, span * 0.94, root_radius + 12.0, radius - 9.0, 22.0, phase + 0.15)
	var edge := _blade_edge(start_angle, span, root_radius, radius - 4.0, phase)
	draw_colored_polygon(outline, Color(OUTLINE_COLOR, alpha * 0.88))
	draw_colored_polygon(blade, Color(BLADE_COLOR, alpha * 0.78))
	draw_colored_polygon(shadow, Color(SHADOW_COLOR, alpha * 0.64))
	draw_colored_polygon(edge, Color(EDGE_COLOR, alpha * 0.82))


func _blade_polygon(
	start_angle: float, span: float, root_radius: float,
	outer_radius: float, max_thickness: float, phase: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(ARC_STEPS + 1):
		var t := float(index) / float(ARC_STEPS)
		var taper := pow(sin(PI * t), 0.72)
		var irregularity := sin((t + phase) * PI * 4.0) * 1.8
		var current_outer := lerpf(root_radius, outer_radius + irregularity, taper)
		points.append(Vector2.RIGHT.rotated(start_angle + span * t) * current_outer)
	for index in range(ARC_STEPS, -1, -1):
		var t := float(index) / float(ARC_STEPS)
		var taper := pow(sin(PI * t), 0.72)
		var irregularity := sin((t + phase) * PI * 4.0) * 1.8
		var current_outer := lerpf(root_radius, outer_radius + irregularity, taper)
		var thickness := lerpf(2.5, max_thickness, pow(sin(PI * t), 1.18))
		points.append(Vector2.RIGHT.rotated(start_angle + span * t) * (current_outer - thickness))
	return points


func _blade_edge(
	start_angle: float, span: float, root_radius: float,
	outer_radius: float, phase: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var edge_steps := 6
	for index in range(edge_steps + 1):
		var t := lerpf(0.20, 0.78, float(index) / float(edge_steps))
		var taper := pow(sin(PI * t), 0.72)
		var irregularity := sin((t + phase) * PI * 4.0) * 1.4
		var current_outer := lerpf(root_radius, outer_radius + irregularity, taper)
		points.append(Vector2.RIGHT.rotated(start_angle + span * t) * current_outer)
	for index in range(edge_steps, -1, -1):
		var t := lerpf(0.20, 0.78, float(index) / float(edge_steps))
		var taper := pow(sin(PI * t), 0.72)
		var irregularity := sin((t + phase) * PI * 4.0) * 1.4
		var current_outer := lerpf(root_radius, outer_radius + irregularity, taper)
		points.append(Vector2.RIGHT.rotated(start_angle + span * t) * (current_outer - 4.5))
	return points


func visual_signature() -> Dictionary:
	return {
		"blade_count": BLADE_COUNT,
		"arc_steps": ARC_STEPS,
		"radius": max_radius,
		"duration": duration,
	}
