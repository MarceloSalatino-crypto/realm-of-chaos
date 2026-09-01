extends Node2D

const DURATION := 0.44
const OUTLINE := Color("160f20")
const SOUL_DARK := Color("43245f")
const SOUL_MID := Color("8b55b5")
const SOUL_LIGHT := Color("e9b85d")

var age := 0.0
var target_offsets := PackedVector2Array()
var source_charge_count := 0


func _ready() -> void:
	z_index = 19


func setup(origin: Vector2, target_positions: PackedVector2Array, charge_count: int) -> void:
	global_position = origin
	source_charge_count = charge_count
	for target_position in target_positions:
		target_offsets.append(target_position - origin)
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	if age >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var progress := clampf(age / DURATION, 0.0, 1.0)
	var convergence := smoothstep(0.0, 0.56, progress)
	var fade := 1.0 - smoothstep(0.68, 1.0, progress)
	for index in range(target_offsets.size()):
		var source := target_offsets[index]
		if source.length_squared() < 1.0:
			continue
		var tangent := source.normalized().rotated(PI * 0.5)
		var head := source.lerp(source.normalized() * 21.0, convergence)
		var bend_sign := -1.0 if index % 2 == 0 else 1.0
		var tail := source.lerp(source * 0.50 + tangent * bend_sign * 15.0, convergence)
		var width := 7.0 + sin(progress * PI) * 4.0
		_append_polygon(vertices, colors, indices, PackedVector2Array([
			head - tangent * width * 0.45,
			head + source.normalized() * 7.0,
			head + tangent * width,
			tail + tangent * 2.5,
			tail - tangent * 2.5,
		]), Color(OUTLINE, fade * 0.92))
		_append_polygon(vertices, colors, indices, PackedVector2Array([
			head - tangent * (width - 3.0) * 0.35,
			head + source.normalized() * 4.0,
			head + tangent * (width - 2.5),
			tail,
		]), Color(SOUL_MID if index % 2 == 0 else SOUL_DARK, fade * 0.88))
	var release := smoothstep(0.30, 0.62, progress)
	var jaw_scale := 0.72 + release * 0.58
	var facing := Vector2.RIGHT
	if not target_offsets.is_empty() and target_offsets[0].length_squared() > 1.0:
		facing = target_offsets[0].normalized()
	var jaw_side := facing.rotated(PI * 0.5)
	var jaw_reach := 27.0 * jaw_scale
	var jaw_open := (7.0 + release * 8.0) * jaw_scale
	_append_polygon(vertices, colors, indices, PackedVector2Array([
		-facing * 9.0 + jaw_side * (jaw_open + 5.0),
		facing * 6.0 + jaw_side * (jaw_open + 10.0),
		facing * jaw_reach + jaw_side * 8.0,
		facing * (jaw_reach + 10.0) + jaw_side * 1.0,
		facing * (jaw_reach - 4.0) - jaw_side * 2.0,
		facing * 3.0 + jaw_side * 4.0,
	]), Color(OUTLINE, fade))
	_append_polygon(vertices, colors, indices, PackedVector2Array([
		-facing * 6.0 + jaw_side * (jaw_open + 3.0),
		facing * 7.0 + jaw_side * (jaw_open + 6.0),
		facing * (jaw_reach - 1.0) + jaw_side * 5.0,
		facing * (jaw_reach + 5.0) + jaw_side * 1.0,
		facing * 5.0 + jaw_side * 6.0,
	]), Color(SOUL_LIGHT, fade * 0.94))
	_append_polygon(vertices, colors, indices, PackedVector2Array([
		-facing * 8.0 - jaw_side * (jaw_open + 4.0),
		facing * 3.0 - jaw_side * (jaw_open + 8.0),
		facing * (jaw_reach - 5.0) - jaw_side * 10.0,
		facing * (jaw_reach + 7.0) - jaw_side * 3.0,
		facing * (jaw_reach - 8.0) + jaw_side * 1.0,
		facing * 1.0 - jaw_side * 3.0,
	]), Color(OUTLINE, fade))
	_append_polygon(vertices, colors, indices, PackedVector2Array([
		-facing * 5.0 - jaw_side * (jaw_open + 2.0),
		facing * 4.0 - jaw_side * (jaw_open + 5.0),
		facing * (jaw_reach - 5.0) - jaw_side * 6.0,
		facing * (jaw_reach + 2.0) - jaw_side * 3.0,
		facing * 3.0 - jaw_side * 5.0,
	]), Color(SOUL_MID, fade * 0.94))
	if not vertices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, vertices, colors)


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
		"duration": DURATION,
		"target_count": target_offsets.size(),
		"source_charge_count": source_charge_count,
	}
