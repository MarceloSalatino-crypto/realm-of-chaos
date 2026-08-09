class_name BossArena
extends Node2D

const REDRAW_INTERVAL := 1.0 / 30.0
const HIGH_LOAD_REDRAW_INTERVAL := 1.0 / 20.0

var world: Node
var boss: Node
var boss_kind := "ossuary_colossus"
var radius := 720.0
var phase := 1
var active := true
var animation_time := 0.0
var arena_color := Color("b86cff")
var redraw_timer := 0.0
var marker_meshes: Dictionary = {}


func configure(owner_world: Node, arena_boss: Node, center: Vector2, kind: String, final_boss := false) -> void:
	world = owner_world
	boss = arena_boss
	global_position = center
	boss_kind = kind
	radius = 790.0 if final_boss else 690.0
	arena_color = _color_for_kind(kind)
	z_index = -1


func _process(delta: float) -> void:
	animation_time += delta
	if not active or not is_instance_valid(world) or not is_instance_valid(world.player):
		return
	var offset: Vector2 = world.player.global_position - global_position
	var limit := radius - 34.0
	if offset.length() > limit:
		var normal := offset.normalized()
		world.player.global_position = global_position + normal * limit
		if world.player.velocity.dot(normal) > 0.0:
			world.player.velocity -= normal * world.player.velocity.dot(normal)
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer += HIGH_LOAD_REDRAW_INTERVAL if _use_reduced_detail() else REDRAW_INTERVAL
		queue_redraw()


func set_phase(new_phase: int) -> void:
	phase = new_phase
	queue_redraw()


func finish() -> void:
	if not active:
		return
	active = false
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.55)
	tween.tween_callback(queue_free)


func _color_for_kind(kind: String) -> Color:
	match kind:
		"ossuary_colossus": return Color("d6ad72")
		"glacial_archon": return Color("67ddff")
		"infernal_reaper": return Color("ff5d4f")
		"void_titan": return Color("ce63ff")
		"chaos_sovereign": return Color("ffd06a")
		_: return Color("b86cff")


func _use_reduced_detail() -> bool:
	if not is_instance_valid(world):
		return false
	var enemies: Node = world.get_node_or_null("Enemies")
	var effects: Node = world.get_node_or_null("Effects")
	var enemy_projectiles: Node = world.get_node_or_null("EnemyProjectiles")
	if not is_instance_valid(enemies) or not is_instance_valid(effects) or not is_instance_valid(enemy_projectiles):
		return false
	return (
		enemies.get_child_count() >= world.ENEMY_HIGH_VISUAL_LOAD
		or effects.get_child_count() >= world.EFFECT_HIGH_LOAD
		or enemy_projectiles.get_child_count() >= 96
	)


func _draw_segmented_boundary(pulse: float, reduced_detail: bool) -> void:
	var segment_count := 10 if reduced_detail else 16
	var dark := Color(0.025, 0.012, 0.038, 0.94)
	var color := Color(arena_color, 0.62 + pulse * 0.20)
	var lines := _segmented_arc_lines(radius, animation_time * 0.025, segment_count, 0.72, 9)
	draw_multiline(lines, dark, 11.0)
	draw_multiline(lines, color, 6.0)


func _segmented_arc_lines(arc_radius: float, rotation: float, segments: int, coverage: float, point_count: int) -> PackedVector2Array:
	var lines := PackedVector2Array()
	var segment_angle := TAU / float(segments)
	for segment_index in range(segments):
		var start := rotation + segment_angle * float(segment_index)
		var finish := start + segment_angle * coverage
		var previous := Vector2.RIGHT.rotated(start) * arc_radius
		for point_index in range(1, point_count):
			var progress := float(point_index) / float(point_count - 1)
			var current := Vector2.RIGHT.rotated(lerpf(start, finish, progress)) * arc_radius
			lines.append(previous)
			lines.append(current)
			previous = current
	return lines


func _marker_mesh(marker_count: int, outline: bool) -> ArrayMesh:
	var key := "%d:%s:%.2f" % [marker_count, str(outline), radius]
	if marker_meshes.has(key):
		return marker_meshes[key]
	var vertices := PackedVector2Array()
	for index in range(marker_count):
		var angle := TAU * float(index) / float(marker_count)
		var radial := Vector2.RIGHT.rotated(angle)
		var tangent := radial.rotated(PI * 0.5)
		var position := radial * (radius - 7.0)
		if outline:
			vertices.append_array(PackedVector2Array([
				position + radial * 15.0,
				position - radial * 9.0 + tangent * 10.0,
				position - radial * 9.0 - tangent * 10.0,
			]))
		else:
			vertices.append_array(PackedVector2Array([
				position + radial * 11.0,
				position - radial * 6.0 + tangent * 6.0,
				position - radial * 6.0 - tangent * 6.0,
			]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	marker_meshes[key] = mesh
	return mesh


func _draw_boundary_markers(pulse: float, reduced_detail: bool) -> void:
	var marker_count := 8 if reduced_detail else 12
	var rotation := Transform2D(animation_time * 0.08, Vector2.ZERO)
	draw_mesh(_marker_mesh(marker_count, true), null, rotation, Color(0.025, 0.012, 0.038, 0.92))
	draw_mesh(_marker_mesh(marker_count, false), null, rotation, Color(arena_color, 0.50 + pulse * 0.24))


func _draw() -> void:
	var pulse := (sin(animation_time * (1.5 + phase * 0.18)) + 1.0) * 0.5
	var reduced_detail := _use_reduced_detail()
	draw_circle(Vector2.ZERO, radius, Color(arena_color, 0.010 + phase * 0.004))
	_draw_segmented_boundary(pulse, reduced_detail)
	_draw_boundary_markers(pulse, reduced_detail)
