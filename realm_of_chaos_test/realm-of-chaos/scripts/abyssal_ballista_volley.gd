extends Node2D


const FORMATION_TIME := 0.20
const RELEASE_FLASH_TIME := 0.11
const DURATION := 0.38

const OUTLINE_COLOR := Color("17111f")
const FRAME_COLOR := Color("593479")
const FRAME_HIGHLIGHT := Color("9a64c7")
const BOLT_SHADOW := Color("6f4928")
const BOLT_COLOR := Color("ffd36b")
const BOLT_HIGHLIGHT := Color("fff0a8")

var world: Node
var owner_ref: WeakRef
var captured_direction := Vector2.RIGHT
var projectile_entries: Array[Dictionary] = []
var age := 0.0
var released := false
var released_projectile_count := 0
var formation_positions := PackedVector2Array()


func _ready() -> void:
	z_index = 19


func setup(
	owner_world: Node, owner_player: Node2D, direction: Vector2,
	entries: Array[Dictionary]
) -> void:
	world = owner_world
	owner_ref = weakref(owner_player)
	captured_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	projectile_entries = entries.duplicate(true)
	global_position = owner_player.global_position
	rotation = captured_direction.angle()
	_update_formation_positions()
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	var owner := _owner_player()
	if not is_instance_valid(owner):
		queue_free()
		return
	global_position = owner.global_position
	if not released and age >= FORMATION_TIME:
		_release_salvo(owner)
	_update_formation_positions()
	if age >= DURATION:
		queue_free()
		return
	queue_redraw()


func _release_salvo(owner: Node2D) -> void:
	released = true
	for entry in projectile_entries:
		owner._spawn_player_projectile(
			Vector2(entry.get("direction", captured_direction)),
			float(entry.get("damage", 0.0)),
			float(entry.get("speed", 0.0)),
			int(entry.get("pierce", 0)),
			float(entry.get("radius", 0.0)),
			Color(entry.get("color", BOLT_COLOR)),
			"chaos_bolt"
		)
		released_projectile_count += 1


func _owner_player() -> Node:
	return owner_ref.get_ref() if owner_ref else null


func has_pending_combat_stages() -> bool:
	return not released


func _update_formation_positions() -> void:
	formation_positions.resize(projectile_entries.size())
	var progress := smoothstep(0.0, FORMATION_TIME * 0.82, age)
	for index in range(projectile_entries.size()):
		var offset := float(index) - float(projectile_entries.size() - 1) * 0.5
		var staged := Vector2(26.0 + absf(offset) * 3.6, offset * 18.0)
		var collapsed := Vector2(-12.0 + absf(offset) * 1.2, offset * 5.0)
		formation_positions[index] = collapsed.lerp(staged, progress)


func _draw() -> void:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var formation_alpha := clampf(age / 0.07, 0.0, 1.0)
	var release_age := maxf(0.0, age - FORMATION_TIME)
	var release_alpha := 1.0 - smoothstep(0.0, RELEASE_FLASH_TIME, release_age)

	if not released:
		_append_frame(vertices, colors, indices, formation_alpha)
		for index in range(formation_positions.size()):
			var offset := float(index) - float(formation_positions.size() - 1) * 0.5
			_append_bolt(
				vertices, colors, indices, formation_positions[index],
				(1.12 if is_zero_approx(offset) else 1.0) + 0.05 * sin(age * 24.0 + float(index)),
				offset * 0.035, formation_alpha
			)
	else:
		_append_release_shards(vertices, colors, indices, release_alpha)
	if not vertices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, vertices, colors)


func _append_frame(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	alpha: float
) -> void:
	var half_span := maxf(25.0, float(projectile_entries.size() - 1) * 9.0 + 12.0)
	var deploy := smoothstep(0.0, FORMATION_TIME * 0.82, age)
	var x := lerpf(-5.0, 15.0, deploy)
	var upper := PackedVector2Array([
		Vector2(x - 12.0, -half_span + 7.0), Vector2(x - 5.0, -half_span - 2.0),
		Vector2(x + 15.0, -half_span + 3.0), Vector2(x + 4.0, -half_span + 9.0),
	])
	var lower := PackedVector2Array()
	for point in upper:
		lower.append(Vector2(point.x, -point.y))
	_append_polygon(vertices, colors, indices, upper, Color(OUTLINE_COLOR, alpha * 0.94))
	_append_polygon(vertices, colors, indices, lower, Color(OUTLINE_COLOR, alpha * 0.94))
	var upper_inner := PackedVector2Array([
		Vector2(x - 7.0, -half_span + 6.5), Vector2(x - 2.0, -half_span + 1.0),
		Vector2(x + 10.0, -half_span + 4.0), Vector2(x + 3.0, -half_span + 6.8),
	])
	var lower_inner := PackedVector2Array()
	for point in upper_inner:
		lower_inner.append(Vector2(point.x, -point.y))
	_append_polygon(vertices, colors, indices, upper_inner, Color(FRAME_COLOR, alpha))
	_append_polygon(vertices, colors, indices, lower_inner, Color(FRAME_HIGHLIGHT, alpha * 0.82))
	var body_outline := PackedVector2Array([
		Vector2(x - 18.0, -8.0), Vector2(x + 8.0, -10.0), Vector2(x + 21.0, 0.0),
		Vector2(x + 8.0, 10.0), Vector2(x - 18.0, 8.0), Vector2(x - 9.0, 0.0),
	])
	var body_fill := PackedVector2Array([
		Vector2(x - 13.0, -4.5), Vector2(x + 6.0, -5.8), Vector2(x + 14.0, 0.0),
		Vector2(x + 6.0, 5.8), Vector2(x - 13.0, 4.5), Vector2(x - 7.0, 0.0),
	])
	_append_polygon(vertices, colors, indices, body_outline, Color(OUTLINE_COLOR, alpha * 0.96))
	_append_polygon(vertices, colors, indices, body_fill, Color(FRAME_COLOR, alpha * 0.88))


func _append_bolt(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	center: Vector2, scale_value: float, angle: float, alpha: float
) -> void:
	var outline := PackedVector2Array([
		_oriented_point(center, Vector2(-20.0, -5.2), scale_value, angle),
		_oriented_point(center, Vector2(6.0, -5.2), scale_value, angle),
		_oriented_point(center, Vector2(21.0, 0.0), scale_value, angle),
		_oriented_point(center, Vector2(6.0, 5.2), scale_value, angle),
		_oriented_point(center, Vector2(-20.0, 5.2), scale_value, angle),
		_oriented_point(center, Vector2(-13.0, 0.0), scale_value, angle),
	])
	var fill := PackedVector2Array([
		_oriented_point(center, Vector2(-17.0, -2.7), scale_value, angle),
		_oriented_point(center, Vector2(5.0, -2.7), scale_value, angle),
		_oriented_point(center, Vector2(16.5, 0.0), scale_value, angle),
		_oriented_point(center, Vector2(5.0, 2.7), scale_value, angle),
		_oriented_point(center, Vector2(-17.0, 2.7), scale_value, angle),
		_oriented_point(center, Vector2(-12.0, 0.0), scale_value, angle),
	])
	var highlight := PackedVector2Array([
		_oriented_point(center, Vector2(-11.0, -2.0), scale_value, angle),
		_oriented_point(center, Vector2(4.0, -2.0), scale_value, angle),
		_oriented_point(center, Vector2(12.0, 0.0), scale_value, angle),
		_oriented_point(center, Vector2(3.0, 0.0), scale_value, angle),
		_oriented_point(center, Vector2(-11.0, 0.0), scale_value, angle),
	])
	_append_polygon(vertices, colors, indices, outline, Color(OUTLINE_COLOR, alpha))
	_append_polygon(vertices, colors, indices, fill, Color(BOLT_SHADOW, alpha))
	_append_polygon(vertices, colors, indices, highlight, Color(BOLT_HIGHLIGHT, alpha * 0.96))


func _oriented_point(center: Vector2, local_point: Vector2, scale_value: float, angle: float) -> Vector2:
	return center + (local_point * scale_value).rotated(angle)


func _append_release_shards(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	alpha: float
) -> void:
	if alpha <= 0.01:
		return
	var muzzle := PackedVector2Array([
		Vector2(7.0, -13.0), Vector2(34.0, 0.0), Vector2(7.0, 13.0), Vector2(17.0, 0.0),
	])
	_append_polygon(vertices, colors, indices, muzzle, Color(BOLT_HIGHLIGHT, alpha))
	for index in range(4):
		var vertical_sign := -1.0 if index < 2 else 1.0
		var depth := float(index % 2)
		var shard := PackedVector2Array([
			Vector2(12.0 + depth * 7.0, vertical_sign * (8.0 + depth * 8.0)),
			Vector2(31.0 + depth * 9.0, vertical_sign * (13.0 + depth * 13.0)),
			Vector2(20.0 + depth * 6.0, vertical_sign * (5.0 + depth * 6.0)),
		])
		_append_polygon(
			vertices, colors, indices, shard,
			Color(FRAME_HIGHLIGHT if index % 2 == 0 else BOLT_COLOR, alpha * 0.82)
		)


func _append_quad(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color
) -> void:
	var base := vertices.size()
	for point in [a, b, c, d]:
		vertices.append(point)
		colors.append(color)
	indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


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
		"formation_time": FORMATION_TIME,
		"duration": DURATION,
		"entry_count": projectile_entries.size(),
		"released": released,
		"released_projectile_count": released_projectile_count,
		"captured_direction": captured_direction,
		"formation_position_count": formation_positions.size(),
	}
