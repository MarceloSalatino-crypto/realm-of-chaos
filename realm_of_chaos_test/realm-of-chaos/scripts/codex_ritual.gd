extends Node2D


const PULSE_TIMES := [0.24, 0.52]
const PULSE_FRACTIONS := [0.22, 0.24]
const PULSE_PULL := [15.0, 22.0]
const IMPLOSION_TIME := 0.84
const IMPLOSION_FRACTION := 0.54
const IMPLOSION_PULL := 34.0
const RUNE_COUNT := 8
const PAGE_COUNT := 4

const SHADOW_COLOR := Color("160d20")
const SEAL_DARK := Color("47205f")
const SEAL_MAIN := Color("9b3bd0")
const SEAL_EDGE := Color("d68cff")
const PAGE_COLOR := Color("b7a5bd")
const PAGE_INK := Color("46344e")
const CORE_COLOR := Color("f0b0ff")

var world: Node
var max_radius := 205.0
var total_damage := 132.86
var critical_chance := 0.0
var critical_multiplier := 2.0
var duration := 0.96
var age := 0.0
var next_pulse := 0
var implosion_done := false
var critical_targets: Dictionary = {}
var damage_stage_count := 0


func _ready() -> void:
	z_index = 18


func setup(
	owner_world: Node, world_position: Vector2, radius: float, damage: float,
	crit_chance: float, crit_multiplier: float
) -> void:
	world = owner_world
	global_position = world_position
	max_radius = radius
	total_damage = damage
	critical_chance = crit_chance
	critical_multiplier = crit_multiplier
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	while next_pulse < PULSE_TIMES.size() and age >= float(PULSE_TIMES[next_pulse]):
		_apply_damage_stage(float(PULSE_FRACTIONS[next_pulse]), float(PULSE_PULL[next_pulse]))
		next_pulse += 1
	if not implosion_done and age >= IMPLOSION_TIME:
		implosion_done = true
		_apply_damage_stage(IMPLOSION_FRACTION, IMPLOSION_PULL)
		if is_instance_valid(world) and world.has_method("shake_camera"):
			world.shake_camera(3.0, 0.14)
	if age >= duration:
		queue_free()
		return
	queue_redraw()


func _apply_damage_stage(fraction: float, pull_force: float) -> void:
	if not is_instance_valid(world):
		return
	damage_stage_count += 1
	for enemy in world.get_enemies_near(global_position, max_radius + 65.0):
		if not is_instance_valid(enemy):
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance > max_radius + float(enemy.hit_radius):
			continue
		var enemy_id: int = enemy.get_instance_id()
		if not critical_targets.has(enemy_id):
			critical_targets[enemy_id] = randf() < critical_chance
		var critical := bool(critical_targets[enemy_id])
		var amount := total_damage * fraction * (critical_multiplier if critical else 1.0)
		var pull: Vector2 = (global_position - enemy.global_position).normalized() * pull_force
		enemy.take_damage(amount, pull, critical, "forbidden_grimoire")


func has_pending_combat_stages() -> bool:
	return not implosion_done


func _draw() -> void:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var appear := clampf(age / 0.16, 0.0, 1.0)
	var collapse := clampf((age - 0.66) / 0.24, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.88, duration, age)
	var pulse_energy := maxf(_pulse_peak(float(PULSE_TIMES[0])), _pulse_peak(float(PULSE_TIMES[1])))
	var seal_scale := appear * lerpf(1.0, 0.38, collapse)
	var rotation_offset := age * 0.42

	_append_polygon(
		vertices, colors, indices,
		_irregular_polygon(max_radius * 0.72 * seal_scale, 12, rotation_offset * 0.17),
		Color(SHADOW_COLOR, fade * (0.30 + pulse_energy * 0.14))
	)

	for rune_index in range(RUNE_COUNT):
		var angle := rotation_offset + TAU * float(rune_index) / float(RUNE_COUNT)
		var rune_radius := max_radius * (0.70 + 0.035 * float(rune_index % 2)) * seal_scale
		var rune_scale := 1.0 + pulse_energy * (0.16 if rune_index % 2 == 0 else 0.08)
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_rune_shape(rune_scale), angle + PI * 0.5, Vector2.RIGHT.rotated(angle) * rune_radius),
			Color(SEAL_DARK, fade * 0.94)
		)
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_rune_inlay(rune_scale), angle + PI * 0.5, Vector2.RIGHT.rotated(angle) * rune_radius),
			Color(SEAL_MAIN.lerp(SEAL_EDGE, pulse_energy), fade * 0.90)
		)

	var inner_rotation := -rotation_offset * 1.7
	for quadrant in range(4):
		var angle := inner_rotation + PI * 0.5 * float(quadrant)
		var position := Vector2.RIGHT.rotated(angle) * max_radius * 0.31 * seal_scale
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_inner_glyph(), angle, position),
			Color(SEAL_MAIN, fade * 0.82)
		)

	for page_index in range(PAGE_COUNT):
		var angle := -rotation_offset * 0.82 + TAU * float(page_index) / float(PAGE_COUNT)
		var page_radius := max_radius * lerpf(0.58, 0.19, collapse) * appear
		var page_position := Vector2.RIGHT.rotated(angle) * page_radius
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_page_shape(page_index), angle + PI * 0.5, page_position),
			Color(PAGE_COLOR, fade * 0.78)
		)
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_page_ink(), angle + PI * 0.5, page_position),
			Color(PAGE_INK, fade * 0.86)
		)

	for shard_index in range(RUNE_COUNT):
		var angle := -rotation_offset * 0.55 + TAU * float(shard_index) / float(RUNE_COUNT)
		var stagger := float(shard_index % 3) * 0.035
		var inward := clampf(collapse + stagger, 0.0, 1.0)
		var shard_radius := max_radius * lerpf(0.91, 0.10, inward)
		var shard_position := Vector2.RIGHT.rotated(angle) * shard_radius
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_energy_shard(1.0 + pulse_energy * 0.24), angle + PI, shard_position),
			Color(SEAL_EDGE, fade * (0.18 + pulse_energy * 0.54 + collapse * 0.24))
		)

	var implosion_peak := 1.0 - clampf(absf(age - IMPLOSION_TIME) / 0.12, 0.0, 1.0)
	if implosion_peak > 0.0:
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(
				_fracture_core(0.55 + implosion_peak * 0.70),
				rotation_offset * 0.7, Vector2.ZERO
			),
			Color(CORE_COLOR, fade * implosion_peak * 0.92)
		)
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_core_void(0.75 + implosion_peak * 0.55), -rotation_offset, Vector2.ZERO),
			Color(SHADOW_COLOR, fade * 0.96)
		)

	if not vertices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, vertices, colors)


func _pulse_peak(pulse_time: float) -> float:
	return pow(1.0 - clampf(absf(age - pulse_time) / 0.10, 0.0, 1.0), 2.0)


func _rune_shape(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-20.0, -8.0), Vector2(4.0, -10.0), Vector2(14.0, -4.0),
		Vector2(7.0, 1.0), Vector2(18.0, 7.0), Vector2(2.0, 10.0),
		Vector2(-5.0, 4.0), Vector2(-17.0, 8.0), Vector2(-12.0, 1.0),
		Vector2(-23.0, -2.0),
	]), scale_value)


func _rune_inlay(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-14.0, -3.0), Vector2(3.0, -5.0), Vector2(9.0, -2.0),
		Vector2(0.0, 1.0), Vector2(8.0, 5.0), Vector2(0.0, 6.0),
		Vector2(-5.0, 2.0), Vector2(-12.0, 4.0),
	]), scale_value)


func _inner_glyph() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-12.0, -4.0), Vector2(3.0, -10.0), Vector2(15.0, -3.0),
		Vector2(5.0, 1.0), Vector2(11.0, 9.0), Vector2(-5.0, 6.0),
	])


func _page_shape(index: int) -> PackedVector2Array:
	var skew := 2.0 if index % 2 == 0 else -2.0
	return PackedVector2Array([
		Vector2(-9.0 + skew, -13.0), Vector2(10.0, -10.0),
		Vector2(8.0 - skew, 13.0), Vector2(-11.0, 9.0),
	])


func _page_ink() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-5.5, -6.5), Vector2(5.5, -5.5),
		Vector2(5.2, -2.5), Vector2(-5.4, -3.5),
	])


func _energy_shard(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-13.0, 0.0), Vector2(-3.0, -4.0),
		Vector2(11.0, 0.0), Vector2(-3.0, 4.0),
	]), scale_value)


func _scaled_polygon(polygon: PackedVector2Array, scale_value: float) -> PackedVector2Array:
	for index in range(polygon.size()):
		polygon[index] *= scale_value
	return polygon


func _irregular_polygon(radius: float, point_count: int, angle_offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := angle_offset + TAU * float(index) / float(point_count)
		var variation := 0.93 if index % 3 == 0 else (1.0 if index % 2 == 0 else 0.97)
		points.append(Vector2.RIGHT.rotated(angle) * radius * variation)
	return points


func _fracture_core(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-34.0, -6.0), Vector2(-14.0, -13.0), Vector2(-5.0, -38.0),
		Vector2(5.0, -15.0), Vector2(28.0, -25.0), Vector2(14.0, -5.0),
		Vector2(40.0, 4.0), Vector2(15.0, 10.0), Vector2(19.0, 31.0),
		Vector2(2.0, 16.0), Vector2(-13.0, 35.0), Vector2(-11.0, 13.0),
		Vector2(-37.0, 19.0), Vector2(-17.0, 1.0),
	]), scale_value)


func _core_void(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-13.0, -4.0), Vector2(-3.0, -15.0), Vector2(12.0, -9.0),
		Vector2(16.0, 3.0), Vector2(4.0, 14.0), Vector2(-12.0, 10.0),
	]), scale_value)


func _transform_polygon(
	polygon: PackedVector2Array, angle: float, offset: Vector2
) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	var transform := Transform2D(angle, offset)
	for point in polygon:
		transformed.append(transform * point)
	return transformed


func _append_polygon(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	polygon: PackedVector2Array, color: Color
) -> void:
	var polygon_indices := Geometry2D.triangulate_polygon(polygon)
	var base := vertices.size()
	for point in polygon:
		vertices.append(point)
		colors.append(color)
	for polygon_index in polygon_indices:
		indices.append(base + polygon_index)


func visual_signature() -> Dictionary:
	return {
		"pulse_count": PULSE_TIMES.size(),
		"damage_stage_count": damage_stage_count,
		"radius": max_radius,
		"duration": duration,
		"implosion_time": IMPLOSION_TIME,
	}
