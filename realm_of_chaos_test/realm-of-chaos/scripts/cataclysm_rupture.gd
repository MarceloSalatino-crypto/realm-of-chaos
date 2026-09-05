extends Node2D


const PRIMARY_DAMAGE_FRACTION := 0.80
const FISSURE_DAMAGE_FRACTION := 0.20
const RUPTURE_TIMES := [0.10, 0.20, 0.30]
const SEGMENT_STARTS := [38.0, 155.0, 275.0]
const SEGMENT_ENDS := [175.0, 295.0, 415.0]
const FISSURE_HALF_WIDTH := 42.0
const FISSURE_KNOCKBACK := 86.0

const GROUND_SHADOW := Color("211611")
const CRACK_DARK := Color("3b271b")
const CRACK_MAIN := Color("9b5b2b")
const CRACK_EDGE := Color("e4a34d")
const DUST_COLOR := Color("8d7962")
const STONE_COLOR := Color("66594e")

var world: Node
var main_radius := 230.0
var total_damage := 184.0
var fissure_damage := 36.8
var duration := 0.58
var age := 0.0
var next_rupture := 0
var rupture_stage_count := 0
var primary_hit_targets: Dictionary = {}
var fissure_hit_targets: Dictionary = {}


func _ready() -> void:
	z_index = 18


func setup(
	owner_world: Node, world_position: Vector2, direction: Vector2,
	radius: float, damage: float
) -> void:
	world = owner_world
	global_position = world_position
	rotation = direction.angle()
	main_radius = radius
	total_damage = damage
	fissure_damage = damage * FISSURE_DAMAGE_FRACTION
	_apply_primary_impact()
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	while next_rupture < RUPTURE_TIMES.size() and age >= float(RUPTURE_TIMES[next_rupture]):
		_apply_fissure_segment(next_rupture)
		next_rupture += 1
	if age >= duration:
		queue_free()
		return
	queue_redraw()


func _apply_primary_impact() -> void:
	if not is_instance_valid(world):
		return
	var primary_damage := total_damage * PRIMARY_DAMAGE_FRACTION
	for enemy in world.get_enemies_near(global_position, main_radius + 70.0):
		if not _enemy_is_alive(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > main_radius + float(enemy.hit_radius):
			continue
		var enemy_id: int = enemy.get_instance_id()
		primary_hit_targets[enemy_id] = enemy
		var force: Vector2 = (enemy.global_position - global_position).normalized() * 185.0
		enemy.take_damage(primary_damage, force, false, "rune_hammer")


func _apply_fissure_segment(segment_index: int) -> void:
	if not is_instance_valid(world):
		return
	rupture_stage_count += 1
	if segment_index == 0:
		_apply_primary_aftershock()
	var local_start := Vector2(float(SEGMENT_STARTS[segment_index]), 0.0)
	var local_end := Vector2(float(SEGMENT_ENDS[segment_index]), 0.0)
	var segment_start: Vector2 = global_transform * local_start
	var segment_end: Vector2 = global_transform * local_end
	var center := (segment_start + segment_end) * 0.5
	var query_radius := segment_start.distance_to(segment_end) * 0.5 + FISSURE_HALF_WIDTH + 70.0
	var direction := (segment_end - segment_start).normalized()
	for enemy in world.get_enemies_near(center, query_radius):
		if not _enemy_is_alive(enemy):
			continue
		var enemy_id: int = enemy.get_instance_id()
		if fissure_hit_targets.has(enemy_id):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(
			enemy.global_position, segment_start, segment_end
		)
		if closest.distance_to(enemy.global_position) > FISSURE_HALF_WIDTH + float(enemy.hit_radius):
			continue
		fissure_hit_targets[enemy_id] = true
		var lateral: Vector2 = enemy.global_position - closest
		var force_direction: Vector2 = lateral.normalized() if lateral.length_squared() > 0.01 else direction
		var fissure_force := 0.0 if primary_hit_targets.has(enemy_id) else FISSURE_KNOCKBACK
		enemy.take_damage(
			fissure_damage, force_direction * fissure_force, false, "rune_hammer"
		)


func _apply_primary_aftershock() -> void:
	for enemy_id_value in primary_hit_targets.keys():
		var enemy_id := int(enemy_id_value)
		var enemy_value: Variant = primary_hit_targets.get(enemy_id)
		if not is_instance_valid(enemy_value):
			primary_hit_targets.erase(enemy_id)
			continue
		var enemy: Node = enemy_value as Node
		if not _enemy_is_alive(enemy):
			continue
		if fissure_hit_targets.has(enemy_id):
			continue
		fissure_hit_targets[enemy_id] = true
		enemy.take_damage(fissure_damage, Vector2.ZERO, false, "rune_hammer")


func _enemy_is_alive(enemy: Node) -> bool:
	return is_instance_valid(enemy) and not bool(enemy.dead)


func has_pending_combat_stages() -> bool:
	return next_rupture < RUPTURE_TIMES.size()


func _draw() -> void:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var impact_fade := 1.0 - smoothstep(0.22, 0.50, age)
	var total_fade := 1.0 - smoothstep(0.48, duration, age)
	var impact_peak := 1.0 - clampf(age / 0.15, 0.0, 1.0)
	var impact_growth := lerpf(0.56, 1.0, smoothstep(0.0, 0.08, age))

	_append_polygon(
		vertices, colors, indices,
		_impact_slab(Vector2(-32.0, -27.0) * impact_growth, 0.12, 1.10 * impact_growth),
		Color(GROUND_SHADOW, impact_fade * 0.78)
	)
	_append_polygon(
		vertices, colors, indices,
		_impact_slab(Vector2(20.0, -20.0) * impact_growth, 1.03, 0.91 * impact_growth),
		Color(CRACK_DARK, impact_fade * 0.86)
	)
	_append_polygon(
		vertices, colors, indices,
		_impact_slab(Vector2(-8.0, 28.0) * impact_growth, -0.72, 0.82 * impact_growth),
		Color(CRACK_MAIN, impact_fade * 0.70)
	)

	for fragment_index in range(7):
		var angle: float = [0.18, 0.79, 1.54, 2.42, 3.31, 4.48, 5.62][fragment_index]
		var distance := (48.0 + 13.0 * float(fragment_index % 3)) * impact_growth
		var fragment_position := Vector2.RIGHT.rotated(angle) * distance
		var fragment_scale := 0.54 + 0.10 * float(fragment_index % 2) + impact_peak * 0.12
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(
				_stone_fragment(fragment_scale), angle + 0.31, fragment_position
			),
			Color(STONE_COLOR.lerp(CRACK_EDGE, impact_peak * 0.28), impact_fade * 0.80)
		)

	for segment_index in range(RUPTURE_TIMES.size()):
		var reveal := smoothstep(
			float(RUPTURE_TIMES[segment_index]) - 0.035,
			float(RUPTURE_TIMES[segment_index]) + 0.055,
			age
		)
		if reveal <= 0.0:
			continue
		var segment_fade := total_fade * reveal
		var start_x := float(SEGMENT_STARTS[segment_index])
		var end_x := lerpf(start_x, float(SEGMENT_ENDS[segment_index]), reveal)
		_append_polygon(
			vertices, colors, indices,
			_fissure_bank_polygon(start_x, end_x, segment_index, -1.0),
			Color(CRACK_DARK, segment_fade * 0.72)
		)
		_append_polygon(
			vertices, colors, indices,
			_fissure_bank_polygon(start_x, end_x, segment_index, 1.0),
			Color(STONE_COLOR.lerp(CRACK_MAIN, 0.32), segment_fade * 0.66)
		)
		_append_polygon(
			vertices, colors, indices,
			_fissure_polygon(start_x, end_x, segment_index, 0.42),
			Color(GROUND_SHADOW, segment_fade * 0.95)
		)
		_append_polygon(
			vertices, colors, indices,
			_fissure_lip_polygon(start_x + 5.0, end_x - 3.0, segment_index),
			Color(CRACK_EDGE, segment_fade * 0.48)
		)
		var eruption_position := Vector2(end_x - 12.0, _segment_offset(segment_index) * 0.45)
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(
				_ground_eruption(0.72 + reveal * 0.20), -0.08, eruption_position
			),
			Color(STONE_COLOR.lerp(CRACK_EDGE, 0.34), segment_fade * 0.76)
		)

	for dust_index in range(5):
		var segment_index := mini(dust_index, RUPTURE_TIMES.size() - 1)
		var reveal := smoothstep(
			float(RUPTURE_TIMES[segment_index]),
			float(RUPTURE_TIMES[segment_index]) + 0.10,
			age
		)
		if reveal <= 0.0:
			continue
		var dust_x := 78.0 + 73.0 * float(dust_index)
		var dust_y := _segment_offset(segment_index) + (-26.0 if dust_index % 2 == 0 else 24.0)
		_append_polygon(
			vertices, colors, indices,
			_transform_polygon(
				_dust_clump(0.42 + 0.08 * float(dust_index % 3)),
				0.15 * float(dust_index), Vector2(dust_x, dust_y)
			),
			Color(DUST_COLOR, total_fade * reveal * 0.34)
		)

	if not vertices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, vertices, colors)


func _impact_slab(offset: Vector2, angle: float, scale_value: float) -> PackedVector2Array:
	return _transform_polygon(_scaled_polygon(PackedVector2Array([
		Vector2(-31.0, -18.0), Vector2(8.0, -25.0), Vector2(34.0, -8.0),
		Vector2(25.0, 17.0), Vector2(-4.0, 27.0), Vector2(-36.0, 9.0),
	]), scale_value), angle, offset)


func _fissure_polygon(
	start_x: float, end_x: float, segment_index: int, width_scale: float
) -> PackedVector2Array:
	var center_y := _segment_offset(segment_index)
	var half_width := (15.0 + 3.0 * float(segment_index % 2)) * width_scale
	var mid_x := (start_x + end_x) * 0.5
	var bend := (13.0 if segment_index % 2 == 0 else -11.0) * width_scale
	return PackedVector2Array([
		Vector2(start_x, center_y - half_width * 0.42),
		Vector2(mid_x - 18.0, center_y + bend - half_width),
		Vector2(end_x, center_y - half_width * 0.28),
		Vector2(end_x - 12.0, center_y + half_width * 0.72),
		Vector2(mid_x + 12.0, center_y + bend + half_width),
		Vector2(start_x + 7.0, center_y + half_width * 0.46),
	])


func _fissure_bank_polygon(
	start_x: float, end_x: float, segment_index: int, side: float
) -> PackedVector2Array:
	var center_y := _segment_offset(segment_index)
	var length := end_x - start_x
	var quarter_x := start_x + length * 0.34
	var three_quarter_x := start_x + length * 0.69
	var bend := 13.0 if segment_index % 2 == 0 else -11.0
	var centers := PackedVector2Array([
		Vector2(start_x, center_y),
		Vector2(quarter_x, center_y + bend),
		Vector2(three_quarter_x, center_y - bend * 0.42),
		Vector2(end_x, center_y + bend * 0.18),
	])
	var polygon := PackedVector2Array()
	for index in range(centers.size()):
		var near_distance := 6.0 + 2.0 * float((index + segment_index) % 2)
		polygon.append(centers[index] + Vector2(0.0, side * near_distance))
	for index in range(centers.size() - 1, -1, -1):
		var far_distance := 19.0 + 5.0 * float((index + segment_index) % 3)
		polygon.append(centers[index] + Vector2(0.0, side * far_distance))
	return polygon


func _fissure_lip_polygon(
	start_x: float, end_x: float, segment_index: int
) -> PackedVector2Array:
	var center_y := _segment_offset(segment_index)
	var length := end_x - start_x
	var bend := 13.0 if segment_index % 2 == 0 else -11.0
	return PackedVector2Array([
		Vector2(start_x, center_y - 5.0),
		Vector2(start_x + length * 0.42, center_y + bend - 7.0),
		Vector2(end_x, center_y + bend * 0.18 - 4.0),
		Vector2(end_x - 7.0, center_y + bend * 0.18 - 1.0),
		Vector2(start_x + length * 0.42, center_y + bend - 2.0),
		Vector2(start_x + 5.0, center_y - 1.0),
	])


func _segment_offset(segment_index: int) -> float:
	return [0.0, 13.0, -8.0][segment_index]


func _stone_fragment(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-13.0, -7.0), Vector2(5.0, -11.0), Vector2(14.0, 0.0),
		Vector2(6.0, 10.0), Vector2(-10.0, 7.0),
	]), scale_value)


func _ground_eruption(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-24.0, 9.0), Vector2(-12.0, -14.0), Vector2(-3.0, 2.0),
		Vector2(8.0, -24.0), Vector2(14.0, 3.0), Vector2(28.0, -8.0),
		Vector2(20.0, 13.0), Vector2(-6.0, 17.0),
	]), scale_value)


func _dust_clump(scale_value: float) -> PackedVector2Array:
	return _scaled_polygon(PackedVector2Array([
		Vector2(-18.0, -5.0), Vector2(-5.0, -13.0), Vector2(12.0, -9.0),
		Vector2(20.0, 2.0), Vector2(7.0, 11.0), Vector2(-13.0, 8.0),
	]), scale_value)


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
		"primary_damage_fraction": PRIMARY_DAMAGE_FRACTION,
		"fissure_damage_fraction": FISSURE_DAMAGE_FRACTION,
		"rupture_count": RUPTURE_TIMES.size(),
		"rupture_stage_count": rupture_stage_count,
		"main_radius": main_radius,
		"fissure_reach": float(SEGMENT_ENDS[SEGMENT_ENDS.size() - 1]),
		"fissure_half_width": FISSURE_HALF_WIDTH,
		"duration": duration,
	}
