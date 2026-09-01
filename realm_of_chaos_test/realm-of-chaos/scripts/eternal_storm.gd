extends Node2D


const MAIN_DAMAGE_FRACTION := 0.65
const ECHO_DAMAGE_FRACTION := 0.35
const ECHO_DELAY := 0.16
const MAIN_REVEAL_TIME := 0.10
const ECHO_REVEAL_TIME := 0.11

const SHADOW_COLOR := Color("111521")
const MAIN_COLOR := Color("68eaff")
const MAIN_CORE_COLOR := Color("d8fbff")
const BRANCH_COLOR := Color("89a8ff")
const ECHO_COLOR := Color("d89cff")
const ECHO_CORE_COLOR := Color("fff0bf")

var duration := 0.44
var age := 0.0
var echo_stage_count := 0
var echo_triggered := false
var chain_points := PackedVector2Array()
var echo_points := PackedVector2Array()
var target_entries: Array[Dictionary] = []


func _ready() -> void:
	z_index = 19


func setup(origin: Vector2, entries: Array[Dictionary]) -> void:
	global_position = origin
	chain_points = PackedVector2Array([Vector2.ZERO])
	target_entries.clear()
	for entry in entries:
		var target: Node = entry.get("target") as Node
		if not _target_is_alive(target):
			continue
		var captured_position: Vector2 = target.global_position - origin
		target_entries.append({
			"target": weakref(target),
			"position": captured_position,
			"critical": bool(entry.get("critical", false)),
			"total_damage": float(entry.get("total_damage", 0.0)),
		})
		chain_points.append(captured_position)
	_build_echo_points()
	_apply_damage_fraction(MAIN_DAMAGE_FRACTION)
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	if not echo_triggered and age >= ECHO_DELAY:
		echo_triggered = true
		echo_stage_count = 1
		_apply_damage_fraction(ECHO_DAMAGE_FRACTION)
	if age >= duration:
		queue_free()
		return
	queue_redraw()


func _build_echo_points() -> void:
	echo_points.clear()
	for index in range(chain_points.size() - 1, 0, -1):
		echo_points.append(chain_points[index])
	if chain_points.size() > 1:
		echo_points.append(Vector2.ZERO)


func _apply_damage_fraction(fraction: float) -> void:
	for entry in target_entries:
		var target_reference: WeakRef = entry.target as WeakRef
		var target: Node = target_reference.get_ref() if target_reference else null
		if not _target_is_alive(target):
			continue
		target.take_damage(
			float(entry.total_damage) * fraction,
			Vector2.ZERO,
			bool(entry.critical),
			"storm_relic"
		)


func _target_is_alive(target: Node) -> bool:
	return is_instance_valid(target) and not bool(target.get("dead"))


func has_pending_combat_stages() -> bool:
	return not echo_triggered


func _draw() -> void:
	if chain_points.size() < 2:
		return
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var main_reveal := smoothstep(0.0, MAIN_REVEAL_TIME, age)
	var main_fade := 1.0 - smoothstep(0.24, duration, age)
	_append_network(
		vertices, colors, indices, chain_points, main_reveal,
		Color(MAIN_COLOR, main_fade), Color(MAIN_CORE_COLOR, main_fade * 0.94),
		false
	)

	if age >= ECHO_DELAY and echo_points.size() >= 2:
		var echo_age := age - ECHO_DELAY
		var echo_reveal := smoothstep(0.0, ECHO_REVEAL_TIME, echo_age)
		var echo_fade := 1.0 - smoothstep(0.15, duration - ECHO_DELAY, echo_age)
		_append_network(
			vertices, colors, indices, echo_points, echo_reveal,
			Color(ECHO_COLOR, echo_fade), Color(ECHO_CORE_COLOR, echo_fade * 0.96),
			true
		)

	if not vertices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), indices, vertices, colors
		)


func _append_network(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	points: PackedVector2Array, reveal: float, outer_color: Color, core_color: Color,
	reversed: bool
) -> void:
	var segment_total := points.size() - 1
	var visible_segments := reveal * float(segment_total)
	for segment_index in range(segment_total):
		var segment_reveal := clampf(visible_segments - float(segment_index), 0.0, 1.0)
		if segment_reveal <= 0.0:
			continue
		var start := points[segment_index]
		var finish := start.lerp(points[segment_index + 1], segment_reveal)
		var path := _jagged_path(start, finish, segment_index, reversed)
		_append_polyline(vertices, colors, indices, path, 7.2, Color(SHADOW_COLOR, outer_color.a * 0.92))
		_append_polyline(vertices, colors, indices, path, 3.8 if not reversed else 3.2, outer_color)
		_append_polyline(vertices, colors, indices, path, 1.15, core_color)
		if not reversed and segment_reveal >= 0.54:
			_append_branch(vertices, colors, indices, start, finish, segment_index, outer_color)
	_append_node_shards(vertices, colors, indices, points, reveal, core_color, reversed)


func _jagged_path(start: Vector2, finish: Vector2, segment_index: int, reversed: bool) -> PackedVector2Array:
	var path := PackedVector2Array([start])
	var segment := finish - start
	var normal := segment.normalized().rotated(PI * 0.5)
	var direction_sign := -1.0 if reversed else 1.0
	for step in range(1, 5):
		var amount := float(step) / 5.0
		var noise := sin(float(segment_index * 17 + step * 11) * 0.71) * 9.5
		path.append(start.lerp(finish, amount) + normal * noise * direction_sign)
	path.append(finish)
	return path


func _append_branch(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	start: Vector2, finish: Vector2, segment_index: int, color: Color
) -> void:
	var segment := finish - start
	if segment.length_squared() < 256.0:
		return
	var midpoint := start.lerp(finish, 0.48)
	var branch_angle := (0.62 if segment_index % 2 == 0 else -0.62)
	var branch_length := minf(34.0, segment.length() * 0.24)
	var branch_end := midpoint + segment.normalized().rotated(branch_angle) * branch_length
	var branch := _jagged_path(midpoint, branch_end, segment_index + 31, false)
	_append_polyline(vertices, colors, indices, branch, 4.4, Color(SHADOW_COLOR, color.a * 0.72))
	_append_polyline(vertices, colors, indices, branch, 1.9, Color(BRANCH_COLOR, color.a * 0.78))


func _append_node_shards(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	points: PackedVector2Array, reveal: float, color: Color, reversed: bool
) -> void:
	var visible_nodes := 1 + int(floor(reveal * float(points.size() - 1)))
	for index in range(mini(visible_nodes, points.size())):
		var point := points[index]
		var scale_value := 3.7 if reversed else 4.4
		var diamond := PackedVector2Array([
			point + Vector2(0.0, -scale_value),
			point + Vector2(scale_value * 0.62, 0.0),
			point + Vector2(0.0, scale_value),
			point + Vector2(-scale_value * 0.62, 0.0),
		])
		_append_polygon(vertices, colors, indices, diamond, color)


func _append_polyline(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	points: PackedVector2Array, width: float, color: Color
) -> void:
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var direction := finish - start
		if direction.length_squared() <= 0.001:
			continue
		var normal := direction.normalized().rotated(PI * 0.5) * width * 0.5
		_append_quad(vertices, colors, indices, start - normal, start + normal, finish + normal, finish - normal, color)


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
		"main_damage_fraction": MAIN_DAMAGE_FRACTION,
		"echo_damage_fraction": ECHO_DAMAGE_FRACTION,
		"echo_delay": ECHO_DELAY,
		"duration": duration,
		"target_count": target_entries.size(),
		"main_point_count": chain_points.size(),
		"echo_point_count": echo_points.size(),
		"echo_stage_count": echo_stage_count,
	}
