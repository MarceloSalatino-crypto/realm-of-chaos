extends Node2D

const SECOND_OUTBOUND_TIME := 0.07
const FIRST_RETURN_TIME := 0.20
const SECOND_RETURN_TIME := 0.27
const RETURN_DISTANCE := 176.0
const RETURN_TRAVEL_TIME := RETURN_DISTANCE / 820.0
const FINAL_START := 0.43
const DURATION := 0.64

const OUTLINE := Color("170d22")
const OUTBOUND_SHADOW := Color("6f2d86")
const OUTBOUND_LIGHT := Color("ef74ff")
const RETURN_SHADOW := Color("30204e")
const RETURN_LIGHT := Color("a278ff")
const FINAL_LIGHT := Color("ffd1ff")

var world: Node
var owner_ref: WeakRef
var origin := Vector2.ZERO
var projectile_entries: Array[Dictionary] = []
var outbound_indices := PackedInt32Array()
var return_indices := PackedInt32Array()
var first_outbound_indices := PackedInt32Array()
var second_outbound_indices := PackedInt32Array()
var first_return_indices := PackedInt32Array()
var second_return_indices := PackedInt32Array()
var age := 0.0
var outbound_released := false
var return_released := false
var second_outbound_released := false
var first_return_released := false
var released_projectile_count := 0
var cancelled_wave_count := 0


func _ready() -> void:
	z_index = 19


func setup(owner_world: Node, owner_player: Node2D, entries: Array[Dictionary]) -> void:
	world = owner_world
	owner_ref = weakref(owner_player)
	origin = owner_player.global_position
	global_position = origin
	projectile_entries = entries.duplicate(true)
	for index in range(projectile_entries.size()):
		if index % 2 == 0:
			outbound_indices.append(index)
		else:
			return_indices.append(index)
	for order in range(outbound_indices.size()):
		(first_outbound_indices if order < ceili(outbound_indices.size() * 0.5) else second_outbound_indices).append(outbound_indices[order])
	for order in range(return_indices.size()):
		(first_return_indices if order >= floori(return_indices.size() * 0.5) else second_return_indices).append(return_indices[order])
	_release_wave(first_outbound_indices, false)
	outbound_released = true
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	if not second_outbound_released and age >= SECOND_OUTBOUND_TIME:
		second_outbound_released = true
		_release_wave(second_outbound_indices, false)
	if not first_return_released and age >= FIRST_RETURN_TIME:
		first_return_released = true
		_release_wave(first_return_indices, true)
	if not return_released and age >= SECOND_RETURN_TIME:
		return_released = true
		_release_wave(second_return_indices, true)
	if age >= DURATION:
		queue_free()
		return
	queue_redraw()


func _release_wave(indices: PackedInt32Array, returning: bool) -> void:
	var owner := _owner_player()
	if not is_instance_valid(owner):
		cancelled_wave_count += 1
		return
	for entry_index in indices:
		if entry_index < 0 or entry_index >= projectile_entries.size():
			continue
		var entry: Dictionary = projectile_entries[entry_index]
		var direction := Vector2(entry.get("direction", Vector2.RIGHT)).normalized()
		var spawn_position := origin - direction * RETURN_DISTANCE if returning else origin + direction * 22.0
		var projectile = owner._spawn_shadow_dance_projectile(
			spawn_position, direction,
			float(entry.get("damage", 0.0)),
			float(entry.get("speed", 820.0)),
			int(entry.get("pierce", 3)),
			float(entry.get("radius", 8.0)),
			Color(entry.get("color", Color("df63ff"))),
			bool(entry.get("critical", false)),
			returning
		)
		if is_instance_valid(projectile):
			released_projectile_count += 1


func _owner_player() -> Node:
	return owner_ref.get_ref() if owner_ref else null


func has_pending_combat_stages() -> bool:
	return not (second_outbound_released and first_return_released and return_released)


func _draw() -> void:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for order in range(outbound_indices.size()):
		var entry_index := outbound_indices[order]
		var release_time := 0.0 if first_outbound_indices.has(entry_index) else SECOND_OUTBOUND_TIME
		if age < release_time:
			continue
		var local_age := age - release_time
		var outbound_progress := smoothstep(0.0, 0.20, local_age)
		var outbound_alpha := 1.0 - smoothstep(0.10, 0.31, local_age)
		var direction := Vector2(projectile_entries[entry_index].direction).normalized()
		var head := direction * lerpf(28.0, 168.0, outbound_progress)
		var lateral := direction.rotated(PI * 0.5) * sin(float(order * 5 + 2)) * 5.0
		_append_slash(
			vertices, colors, indices, head + lateral, direction,
			30.0, 8.5, Color(OUTBOUND_SHADOW, outbound_alpha * 0.80),
			Color(OUTBOUND_LIGHT, outbound_alpha * 0.90)
		)

	for order in range(return_indices.size()):
		var entry_index := return_indices[order]
		var release_time := FIRST_RETURN_TIME if first_return_indices.has(entry_index) else SECOND_RETURN_TIME
		if age < release_time - 0.045:
			continue
		var local_age := age - release_time
		var return_progress := clampf(local_age / RETURN_TRAVEL_TIME, 0.0, 1.0)
		var return_alpha := 1.0 - smoothstep(RETURN_TRAVEL_TIME - 0.03, RETURN_TRAVEL_TIME + 0.12, local_age)
		var direction := Vector2(projectile_entries[entry_index].direction).normalized()
		var head := (-direction * RETURN_DISTANCE).lerp(Vector2.ZERO, return_progress)
		var lateral := direction.rotated(PI * 0.5) * sin(float(order * 7 + 1)) * 6.0
		_append_slash(
			vertices, colors, indices, head + lateral, direction,
			34.0, 9.0, Color(RETURN_SHADOW, return_alpha * 0.88),
			Color(RETURN_LIGHT, return_alpha)
		)

	if age >= FINAL_START:
		var final_progress := clampf((age - FINAL_START) / (DURATION - FINAL_START), 0.0, 1.0)
		var final_alpha := sin(final_progress * PI)
		var final_centers := [Vector2(-12.0, 8.0), Vector2(13.0, -13.0)]
		var final_angles := [0.56, 0.34]
		for index in range(2):
			var direction := Vector2.RIGHT.rotated(final_angles[index])
			var center: Vector2 = final_centers[index]
			_append_slash(
				vertices, colors, indices, center, direction,
				68.0 - float(index) * 18.0, 7.0, Color(OUTLINE, final_alpha * 0.90),
				Color(FINAL_LIGHT, final_alpha * 0.92)
			)

	if not vertices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, vertices, colors)


func _append_slash(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	center: Vector2, direction: Vector2, length: float, width: float,
	shadow_color: Color, light_color: Color
) -> void:
	var forward := direction.normalized()
	var side := forward.rotated(PI * 0.5)
	var outline_shape := PackedVector2Array([
		center - forward * length * 0.58,
		center - forward * length * 0.20 + side * width,
		center + forward * length * 0.58,
		center + forward * length * 0.12 - side * width * 0.72,
	])
	var inner_shape := PackedVector2Array([
		center - forward * length * 0.46,
		center - forward * length * 0.16 + side * width * 0.48,
		center + forward * length * 0.43,
		center + forward * length * 0.08 - side * width * 0.34,
	])
	_append_polygon(vertices, colors, indices, outline_shape, shadow_color)
	_append_polygon(vertices, colors, indices, inner_shape, light_color)


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
		"second_outbound_time": SECOND_OUTBOUND_TIME,
		"first_return_time": FIRST_RETURN_TIME,
		"second_return_time": SECOND_RETURN_TIME,
		"return_distance": RETURN_DISTANCE,
		"return_travel_time": RETURN_TRAVEL_TIME,
		"duration": DURATION,
		"entry_count": projectile_entries.size(),
		"outbound_count": outbound_indices.size(),
		"return_count": return_indices.size(),
		"outbound_released": outbound_released,
		"second_outbound_released": second_outbound_released,
		"first_return_released": first_return_released,
		"return_released": return_released,
		"released_projectile_count": released_projectile_count,
		"cancelled_wave_count": cancelled_wave_count,
		"temporary_reference_count": 1,
	}
