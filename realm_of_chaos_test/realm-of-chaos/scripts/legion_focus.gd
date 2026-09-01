extends Node2D


const WEAPON_ATLAS = preload("res://assets/generated/weapon_atlas_v1.png")

const EYE_COUNT := 8
const FOCUS_RANGE := 900.0
const EYE_KNOCKBACK := 18.0
const MARK_TIME := 0.10
const CONVERGE_START := 0.12
const CONVERGE_END := 0.30
const FIRST_STRIKE_TIME := 0.34
const SECOND_STRIKE_TIME := 0.50
const REDISTRIBUTE_TIME := 0.58
const DURATION := 0.78
const STRIKE_VISUAL_TIME := 0.075

const EYE_COLOR := Color("d9a2ff")
const FOCUS_EYE_COLOR := Color("8eeaff")
const MARK_COLOR := Color("c486ff")
const STRIKE_COLOR := Color("75e9ff")
const STRIKE_CORE := Color("fff0bd")
const SHADOW_COLOR := Color("171323")

var world: Node
var owner_ref: WeakRef
var focus_target_ref: WeakRef
var attack_entries: Array[Dictionary] = []
var origin := Vector2.ZERO
var age := 0.0
var attack_stage_count := 0
var successful_wave_count := 0
var focus_decision_count := 0
var retarget_count := 0
var hit_count := 0
var cancelled_wave_count := 0
var eye_positions := PackedVector2Array()
var focus_target_history: Array[int] = []
var _eye_multimesh: MultiMesh
var _eye_batch: MultiMeshInstance2D


func _ready() -> void:
	z_index = 19
	_build_eye_batch()


func setup(
	owner_world: Node, owner_player: Node2D, priority_target: Node,
	entries: Array[Dictionary]
) -> void:
	world = owner_world
	owner_ref = weakref(owner_player)
	origin = owner_player.global_position
	global_position = origin
	attack_entries = entries.duplicate(true)
	_set_focus_target(priority_target, false)
	_update_eye_formation()
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	if attack_stage_count == 0 and age >= FIRST_STRIKE_TIME:
		_fire_wave(PackedInt32Array([0, 2, 4, 6]))
		attack_stage_count = 1
	if attack_stage_count == 1 and age >= SECOND_STRIKE_TIME:
		_fire_wave(PackedInt32Array([1, 3, 5, 7]))
		attack_stage_count = 2
	_update_eye_formation()
	if age >= DURATION:
		queue_free()
		return
	queue_redraw()


func has_pending_combat_stages() -> bool:
	return attack_stage_count < 2


func _fire_wave(entry_indices: PackedInt32Array) -> void:
	var target := _ensure_focus_target()
	if not _target_is_usable(target):
		cancelled_wave_count += 1
		return
	successful_wave_count += 1
	for entry_index in entry_indices:
		if entry_index < 0 or entry_index >= attack_entries.size():
			continue
		if not _target_is_alive(target):
			break
		var entry: Dictionary = attack_entries[entry_index]
		var owner: Node2D = _owner_player() as Node2D
		var hit_direction: Vector2 = (
			(target.global_position - owner.global_position).normalized()
			if is_instance_valid(owner)
			else Vector2.ZERO
		)
		target.take_damage(
			float(entry.get("damage", 0.0)),
			hit_direction * EYE_KNOCKBACK,
			bool(entry.get("critical", false)),
			"swarm_idol"
		)
		hit_count += 1


func _ensure_focus_target() -> Node:
	var target := current_focus_target()
	if _target_is_usable(target):
		return target
	var replacement := _select_priority_target()
	_set_focus_target(replacement, true)
	return replacement


func _select_priority_target() -> Node:
	var owner: Node2D = _owner_player() as Node2D
	if not is_instance_valid(world) or not is_instance_valid(owner):
		return null
	focus_decision_count += 1
	var selected: Node = null
	var selected_rank := -1
	var selected_distance := INF
	for candidate in world.get_enemies_near(owner.global_position, FOCUS_RANGE):
		if not _target_is_alive(candidate):
			continue
		var rank := 2 if bool(candidate.get("boss")) else (1 if bool(candidate.get("elite")) else 0)
		var distance: float = owner.global_position.distance_squared_to(candidate.global_position)
		if rank > selected_rank or (rank == selected_rank and distance < selected_distance):
			selected = candidate
			selected_rank = rank
			selected_distance = distance
	return selected


func _set_focus_target(target: Node, is_retarget: bool) -> void:
	if is_retarget:
		retarget_count += 1
	if not _target_is_alive(target):
		focus_target_ref = null
		return
	if not is_retarget:
		focus_decision_count = 1
	focus_target_ref = weakref(target)
	focus_target_history.append(target.get_instance_id())


func current_focus_target() -> Node:
	return focus_target_ref.get_ref() if focus_target_ref else null


func _owner_player() -> Node:
	return owner_ref.get_ref() if owner_ref else null


func _target_is_alive(target: Node) -> bool:
	return is_instance_valid(target) and not bool(target.get("dead"))


func _target_is_usable(target: Node) -> bool:
	if not _target_is_alive(target):
		return false
	var owner: Node2D = _owner_player() as Node2D
	return is_instance_valid(owner) and owner.global_position.distance_to(target.global_position) <= FOCUS_RANGE


func _build_eye_batch() -> void:
	var eye_mesh := ArrayMesh.new()
	var half_size := Vector2(397.0, 793.0) * 0.5
	var atlas_width := 397.0 * 5.0
	var u_min := 397.0 * 4.0 / atlas_width
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-half_size.x, -half_size.y, 0.0),
		Vector3(half_size.x, -half_size.y, 0.0),
		Vector3(half_size.x, half_size.y, 0.0),
		Vector3(-half_size.x, half_size.y, 0.0),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(u_min, 0.0), Vector2(1.0, 0.0),
		Vector2(1.0, 1.0), Vector2(u_min, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	eye_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_eye_multimesh = MultiMesh.new()
	_eye_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_eye_multimesh.use_colors = true
	_eye_multimesh.mesh = eye_mesh
	_eye_multimesh.instance_count = EYE_COUNT
	_eye_multimesh.visible_instance_count = EYE_COUNT
	_eye_batch = MultiMeshInstance2D.new()
	_eye_batch.name = "LegionEyes"
	_eye_batch.multimesh = _eye_multimesh
	_eye_batch.texture = WEAPON_ATLAS
	add_child(_eye_batch)


func _update_eye_formation() -> void:
	if not is_instance_valid(_eye_multimesh):
		return
	eye_positions.resize(EYE_COUNT)
	var owner: Node2D = _owner_player() as Node2D
	var player_position: Vector2 = owner.global_position - origin if is_instance_valid(owner) else Vector2.ZERO
	var target: Node2D = current_focus_target() as Node2D
	var target_position: Vector2 = target.global_position - origin if _target_is_alive(target) else player_position
	var convergence := smoothstep(CONVERGE_START, CONVERGE_END, age)
	var redistribution := smoothstep(REDISTRIBUTE_TIME, DURATION, age)
	for index in range(EYE_COUNT):
		var angle := -PI * 0.5 + TAU * float(index) / float(EYE_COUNT)
		var deployment_radius := lerpf(28.0, 76.0, smoothstep(0.0, MARK_TIME, age))
		var deployment: Vector2 = player_position + Vector2(cos(angle) * deployment_radius, sin(angle) * deployment_radius * 0.68)
		var formation_radius := 96.0 + 8.0 * float(index % 2)
		var formation: Vector2 = target_position + Vector2(cos(angle) * formation_radius, sin(angle) * formation_radius * 0.62)
		var eye_position: Vector2 = deployment.lerp(formation, convergence)
		var strike_time := FIRST_STRIKE_TIME if index % 2 == 0 else SECOND_STRIKE_TIME
		var strike_pulse := _strike_pulse(strike_time)
		# O avanço comunica a descarga, mas preserva distância suficiente para que
		# os quatro traços sincronizados sejam legíveis durante o impacto.
		eye_position = eye_position.lerp(target_position, strike_pulse * 0.32)
		var redistributed: Vector2 = player_position + Vector2.RIGHT.rotated(angle + 0.42) * 88.0
		eye_position = eye_position.lerp(redistributed, redistribution)
		eye_positions[index] = eye_position
		var facing: float = (target_position - eye_position).angle() if eye_position.distance_squared_to(target_position) > 0.01 else angle
		var scale_value := 0.075 * (1.0 + strike_pulse * 0.18)
		var eye_transform := Transform2D(facing, eye_position).scaled_local(Vector2.ONE * scale_value)
		_eye_multimesh.set_instance_transform_2d(index, eye_transform)
		var color := FOCUS_EYE_COLOR if strike_pulse > 0.08 or age >= CONVERGE_START and age < REDISTRIBUTE_TIME else EYE_COLOR
		color.a = 1.0 - smoothstep(0.68, DURATION, age)
		_eye_multimesh.set_instance_color(index, color)


func _strike_pulse(strike_time: float) -> float:
	return clampf(1.0 - absf(age - strike_time) / STRIKE_VISUAL_TIME, 0.0, 1.0)


func _draw() -> void:
	var target := current_focus_target()
	if not _target_is_alive(target) or age < MARK_TIME:
		return
	var target_position: Vector2 = target.global_position - origin
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var marker_fade := 1.0 - smoothstep(REDISTRIBUTE_TIME, DURATION, age)
	_append_target_marker(vertices, colors, indices, target_position, marker_fade)
	for index in range(EYE_COUNT):
		var strike_time := FIRST_STRIKE_TIME if index % 2 == 0 else SECOND_STRIKE_TIME
		var pulse := _strike_pulse(strike_time)
		if pulse <= 0.05:
			continue
		_append_bolt(vertices, colors, indices, eye_positions[index], target_position, index, pulse)
	if not vertices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, vertices, colors)


func _append_target_marker(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	center: Vector2, alpha: float
) -> void:
	var radius := lerpf(38.0, 29.0, smoothstep(MARK_TIME, CONVERGE_END, age))
	for index in range(4):
		var angle := PI * 0.25 + TAU * float(index) / 4.0
		var outward := Vector2.RIGHT.rotated(angle)
		var side := outward.rotated(PI * 0.5)
		var tip := center + outward * radius
		var marker := PackedVector2Array([
			tip,
			center + outward * (radius + 13.0) + side * 5.0,
			center + outward * (radius + 9.0) - side * 5.0,
		])
		_append_polygon(vertices, colors, indices, marker, Color(MARK_COLOR, alpha * 0.76))


func _append_bolt(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	start: Vector2, finish: Vector2, bolt_index: int, alpha: float
) -> void:
	var segment := finish - start
	if segment.length_squared() <= 0.01:
		return
	var normal := segment.normalized().rotated(PI * 0.5)
	var midpoint := start.lerp(finish, 0.52) + normal * sin(float(bolt_index * 7 + 3)) * 8.0
	var path := PackedVector2Array([start, midpoint, finish])
	_append_polyline(vertices, colors, indices, path, 6.2, Color(SHADOW_COLOR, alpha * 0.88))
	_append_polyline(vertices, colors, indices, path, 3.0, Color(STRIKE_COLOR, alpha))
	_append_polyline(vertices, colors, indices, path, 0.9, Color(STRIKE_CORE, alpha * 0.94))


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
		"eye_count": EYE_COUNT,
		"focus_range": FOCUS_RANGE,
		"eye_knockback": EYE_KNOCKBACK,
		"mark_time": MARK_TIME,
		"first_strike_time": FIRST_STRIKE_TIME,
		"second_strike_time": SECOND_STRIKE_TIME,
		"redistribute_time": REDISTRIBUTE_TIME,
		"duration": DURATION,
		"attack_stage_count": attack_stage_count,
		"successful_wave_count": successful_wave_count,
		"focus_decision_count": focus_decision_count,
		"retarget_count": retarget_count,
		"hit_count": hit_count,
		"cancelled_wave_count": cancelled_wave_count,
		"temporary_reference_count": 2,
	}
