extends Node2D


const PULL_TIMES := [0.18, 0.36, 0.52]
const PULL_FORCES := [18.0, 32.0, 45.0]
const IMPLOSION_TIME := 0.68
const IMPLOSION_FORCE := 60.0
const SCAR_COUNT := 7
const DEBRIS_COUNT := 10

const VOID_SHADOW := Color("0b0712")
const VOID_DEEP := Color("241039")
const VOID_MAIN := Color("6630a3")
const VOID_EDGE := Color("b36dff")
const VOID_CORE := Color("e1bcff")
const DEBRIS_COLOR := Color("62566d")

var world: Node
var max_radius := 431.0
var total_damage := 165.9
var critical_chance := 0.0
var critical_multiplier := 2.0
var duration := 0.88
var age := 0.0
var next_pull := 0
var implosion_done := false
var pull_stage_count := 0
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
	while next_pull < PULL_TIMES.size() and age >= float(PULL_TIMES[next_pull]):
		_apply_pull(float(PULL_FORCES[next_pull]))
		next_pull += 1
	if not implosion_done and age >= IMPLOSION_TIME:
		implosion_done = true
		_apply_implosion()
		if is_instance_valid(world) and world.has_method("shake_camera"):
			world.shake_camera(6.0, 0.24)
	if age >= duration:
		queue_free()
		return
	queue_redraw()


func _apply_pull(force: float) -> void:
	if not is_instance_valid(world):
		return
	pull_stage_count += 1
	for enemy in world.get_enemies_near(global_position, max_radius + 70.0):
		if not _enemy_is_inside(enemy):
			continue
		var inward: Vector2 = (global_position - enemy.global_position).normalized()
		var boss_scale := 0.34 if bool(enemy.boss) else 1.0
		enemy.knockback_velocity += inward * force * boss_scale


func _apply_implosion() -> void:
	if not is_instance_valid(world):
		return
	damage_stage_count += 1
	for enemy in world.get_enemies_near(global_position, max_radius + 70.0):
		if not _enemy_is_inside(enemy):
			continue
		var critical: bool = randf() < critical_chance
		var amount := total_damage * (critical_multiplier if critical else 1.0)
		var inward: Vector2 = (global_position - enemy.global_position).normalized()
		enemy.take_damage(amount, inward * IMPLOSION_FORCE, critical, "chaos_nova")


func _enemy_is_inside(enemy: Node) -> bool:
	return (
		is_instance_valid(enemy)
		and global_position.distance_to(enemy.global_position)
		<= max_radius + float(enemy.hit_radius)
	)


func has_pending_combat_stages() -> bool:
	return not implosion_done


func _draw() -> void:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var formation := smoothstep(0.0, 0.16, age)
	var collapse := smoothstep(0.45, IMPLOSION_TIME, age)
	var fade := 1.0 - smoothstep(0.76, duration, age)
	var pull_peak := 0.0
	for pull_time in PULL_TIMES:
		pull_peak = maxf(pull_peak, _event_peak(float(pull_time), 0.09))
	var implosion_peak := _event_peak(IMPLOSION_TIME, 0.13)
	var spin := age * 0.44

	var core_radius := max_radius * lerpf(0.028, 0.088, formation) * lerpf(1.0, 0.38, collapse)
	_append_polygon(
		vertices, colors, indices,
		_irregular_polygon(core_radius * 1.18, 9, -spin * 0.7),
		Color(VOID_SHADOW, fade * (0.48 + implosion_peak * 0.28))
	)
	_append_polygon(
		vertices, colors, indices,
		_irregular_polygon(core_radius * 0.78, 7, spin),
		Color(VOID_DEEP.lerp(VOID_MAIN, pull_peak * 0.28), fade * 0.72)
	)
	for lobe_index in range(3):
		var lobe_angle := -spin * 0.8 + TAU * float(lobe_index) / 3.0
		var lobe_position := Vector2.RIGHT.rotated(lobe_angle) * core_radius * 0.48
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(
				_void_lobe(0.52 + pull_peak * 0.10), lobe_angle + PI, lobe_position
			),
			Color(VOID_MAIN, fade * (0.42 + pull_peak * 0.30))
		)

	for scar_index in range(SCAR_COUNT):
		var angle := spin * (0.22 if scar_index % 2 == 0 else -0.17)
		angle += TAU * float(scar_index) / float(SCAR_COUNT)
		var depth := 0.27 + 0.065 * float(scar_index % 4)
		var radial_distance := max_radius * lerpf(depth, 0.095, collapse) * formation
		var scar_position := Vector2.RIGHT.rotated(angle) * radial_distance
		var scar_scale := 0.58 + 0.08 * float(scar_index % 3) + pull_peak * 0.10
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_gravity_scar(scar_scale), angle + PI, scar_position),
			Color(VOID_SHADOW, fade * 0.64 * (1.0 - implosion_peak * 0.72))
		)
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_scar_inlay(scar_scale), angle + PI, scar_position),
			Color(
				VOID_MAIN.lerp(VOID_EDGE, pull_peak),
				fade * (0.40 + pull_peak * 0.32) * (1.0 - implosion_peak * 0.72)
			)
		)

	for debris_index in range(DEBRIS_COUNT):
		var angle := -spin * 0.58 + TAU * float(debris_index) / float(DEBRIS_COUNT)
		angle += 0.08 * sin(float(debris_index) * 2.3)
		var start_radius := max_radius * (0.79 + 0.04 * float(debris_index % 3))
		var radial_distance := lerpf(start_radius, max_radius * 0.08, collapse) * formation
		var debris_position := Vector2.RIGHT.rotated(angle) * radial_distance
		var debris_scale := 0.54 + 0.10 * float(debris_index % 4)
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_debris_shape(debris_index, debris_scale), angle + PI, debris_position),
			Color(
				DEBRIS_COLOR.lerp(VOID_EDGE, pull_peak * 0.48),
				fade * (0.30 + pull_peak * 0.32) * (1.0 - implosion_peak * 0.58)
			)
		)

	for tear_index in range(4):
		var angle := spin * 0.31 + TAU * float(tear_index) / 4.0 + float(tear_index % 2) * 0.17
		var tear_position := Vector2.RIGHT.rotated(angle) * max_radius * lerpf(0.39, 0.08, collapse)
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_void_tear(0.62 + pull_peak * 0.16), angle + PI, tear_position),
			Color(
				VOID_EDGE,
				fade * (0.14 + pull_peak * 0.44 + collapse * 0.13)
					* (1.0 - implosion_peak * 0.68)
			)
		)

	if implosion_peak > 0.0:
		var jaw_scale := 0.72 + implosion_peak * 0.30
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_implosion_jaw(jaw_scale), 0.08, Vector2(-21.0, -5.0)),
			Color(VOID_EDGE, fade * implosion_peak * 0.82)
		)
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(_implosion_jaw(jaw_scale * 0.92), PI + 0.19, Vector2(20.0, 7.0)),
			Color(VOID_CORE, fade * implosion_peak * 0.78)
		)
		var fragment_positions := [Vector2(-8.0, -34.0), Vector2(31.0, 18.0), Vector2(-35.0, 15.0)]
		var fragment_angles := [-1.22, 0.72, 2.54]
		for fragment_index in range(fragment_positions.size()):
			_append_polygon(
				vertices, colors, indices,
				_transform_polygon(
					_implosion_fragment(0.36 + implosion_peak * 0.24),
					float(fragment_angles[fragment_index]), fragment_positions[fragment_index]
				),
				Color(VOID_CORE, fade * implosion_peak * 0.72)
			)
		_append_polygon(
			vertices, colors, indices,
			_irregular_polygon(14.0 + 15.0 * implosion_peak, 7, -spin),
			Color(VOID_SHADOW, fade * 0.94)
		)

	if not vertices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, vertices, colors)


func _event_peak(event_time: float, half_width: float) -> float:
	return pow(1.0 - clampf(absf(age - event_time) / half_width, 0.0, 1.0), 2.0)


func _gravity_scar(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-35.0, -8.0), Vector2(-13.0, -16.0), Vector2(10.0, -12.0),
		Vector2(31.0, -2.0), Vector2(14.0, 2.0), Vector2(5.0, 15.0),
		Vector2(-17.0, 12.0), Vector2(-29.0, 5.0), Vector2(-18.0, 0.0),
	]), scale_value)


func _scar_inlay(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-25.0, -3.0), Vector2(-9.0, -9.0), Vector2(11.0, -7.0),
		Vector2(22.0, -2.0), Vector2(7.0, 1.0), Vector2(2.0, 8.0),
		Vector2(-13.0, 7.0), Vector2(-20.0, 3.0),
	]), scale_value)


func _void_lobe(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-27.0, -5.0), Vector2(-11.0, -14.0), Vector2(12.0, -10.0),
		Vector2(28.0, -1.0), Vector2(9.0, 3.0), Vector2(2.0, 17.0),
		Vector2(-13.0, 10.0), Vector2(-20.0, 2.0),
	]), scale_value)


func _debris_shape(index: int, scale_value: float) -> PackedVector2Array:
	var skew := 3.0 if index % 2 == 0 else -3.0
	return _scaled_polygon(PackedVector2Array([
		Vector2(-13.0, -5.0 + skew), Vector2(4.0, -9.0),
		Vector2(14.0, 1.0), Vector2(2.0, 8.0), Vector2(-10.0, 5.0),
	]), scale_value)


func _void_tear(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-31.0, -3.0), Vector2(-8.0, -8.0), Vector2(24.0, -3.0),
		Vector2(35.0, 1.0), Vector2(8.0, 5.0), Vector2(-17.0, 8.0),
	]), scale_value)


func _implosion_fragment(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-21.0, -6.0), Vector2(-5.0, -13.0), Vector2(18.0, -5.0),
		Vector2(8.0, 2.0), Vector2(16.0, 11.0), Vector2(-8.0, 7.0),
	]), scale_value)


func _implosion_jaw(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-48.0, -18.0), Vector2(-19.0, -29.0), Vector2(16.0, -21.0),
		Vector2(39.0, -7.0), Vector2(9.0, -5.0), Vector2(31.0, 8.0),
		Vector2(4.0, 18.0), Vector2(-21.0, 13.0), Vector2(-38.0, 2.0),
		Vector2(-12.0, -2.0),
	]), scale_value)


func _irregular_polygon(radius: float, point_count: int, angle_offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := angle_offset + TAU * float(index) / float(point_count)
		var variation := 0.88 + 0.06 * float(index % 3)
		points.append(Vector2.RIGHT.rotated(angle) * radius * variation)
	return points


func _scaled_polygon(polygon: PackedVector2Array, scale_value: float) -> PackedVector2Array:
	for index in range(polygon.size()):
		polygon[index] *= scale_value
	return polygon


func _transform_polygon(
	polygon: PackedVector2Array, angle: float, offset: Vector2
) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	var shape_transform := Transform2D(angle, offset)
	for point in polygon:
		transformed.append(shape_transform * point)
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
		"pull_count": PULL_TIMES.size(),
		"pull_stage_count": pull_stage_count,
		"damage_stage_count": damage_stage_count,
		"radius": max_radius,
		"duration": duration,
		"implosion_time": IMPLOSION_TIME,
		"total_force": float(PULL_FORCES[0]) + float(PULL_FORCES[1])
			+ float(PULL_FORCES[2]) + IMPLOSION_FORCE,
	}
