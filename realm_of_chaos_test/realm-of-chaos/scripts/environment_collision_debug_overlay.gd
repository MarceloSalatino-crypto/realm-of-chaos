class_name EnvironmentCollisionDebugOverlay
extends Node2D

const CATEGORY_COLORS := {
	"grove": Color("61d899"),
	"dense": Color("ffb84d"),
	"stone": Color("aeb8c5"),
	"landmark": Color("57d8ff"),
	"player": Color("ffffff"),
}
const CURVE_SEGMENTS := 18

var world: Node
var overlay_enabled := false


func setup(owner_world: Node) -> void:
	world = owner_world
	name = "EnvironmentCollisionDebugOverlay"
	z_index = 95
	show_behind_parent = false
	visible = false
	set_process(false)


func set_overlay_enabled(enabled: bool) -> void:
	overlay_enabled = enabled
	visible = enabled
	if enabled:
		queue_redraw()


func toggle() -> bool:
	set_overlay_enabled(not overlay_enabled)
	return overlay_enabled


func displayed_shape_count() -> int:
	var count := 0
	for entry in _collision_entries():
		var collision := entry.collision as CollisionShape2D
		if not collision.disabled and collision.shape != null:
			count += 1
	return count


func _draw() -> void:
	if not overlay_enabled or not is_instance_valid(world):
		return
	for entry in _collision_entries():
		var collision := entry.collision as CollisionShape2D
		if collision.disabled or collision.shape == null:
			continue
		var points := _shape_polygon(collision)
		if points.size() < 3:
			continue
		var category := str(entry.category)
		var base_color: Color = CATEGORY_COLORS.get(category, Color("ff4f83"))
		draw_colored_polygon(points, Color(base_color, 0.22))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color(base_color, 0.96), 2.0, true)


func _collision_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not is_instance_valid(world):
		return entries
	for container in [world.obstacles, world.landmarks]:
		if not is_instance_valid(container):
			continue
		for body in container.get_children():
			var category := str(body.get_meta("forest_collision_category", ""))
			if category.is_empty():
				continue
			for collision in body.find_children("*", "CollisionShape2D", true, false):
				entries.append({"collision": collision, "category": category})
	if is_instance_valid(world.player):
		for collision in world.player.find_children("*", "CollisionShape2D", true, false):
			entries.append({"collision": collision, "category": "player"})
	return entries


func _shape_polygon(collision: CollisionShape2D) -> PackedVector2Array:
	var local_points := PackedVector2Array()
	if collision.shape is CircleShape2D:
		var circle := collision.shape as CircleShape2D
		for index in range(CURVE_SEGMENTS * 2):
			var angle := TAU * float(index) / float(CURVE_SEGMENTS * 2)
			local_points.append(Vector2.RIGHT.rotated(angle) * circle.radius)
	elif collision.shape is CapsuleShape2D:
		var capsule := collision.shape as CapsuleShape2D
		var straight_half := maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		for index in range(CURVE_SEGMENTS + 1):
			var angle := PI + PI * float(index) / float(CURVE_SEGMENTS)
			local_points.append(Vector2(0.0, -straight_half) + Vector2.RIGHT.rotated(angle) * capsule.radius)
		for index in range(CURVE_SEGMENTS + 1):
			var angle := PI * float(index) / float(CURVE_SEGMENTS)
			local_points.append(Vector2(0.0, straight_half) + Vector2.RIGHT.rotated(angle) * capsule.radius)
	elif collision.shape is RectangleShape2D:
		var rectangle := collision.shape as RectangleShape2D
		var half_size := rectangle.size * 0.5
		local_points = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y),
		])
	else:
		return local_points
	var world_points := PackedVector2Array()
	for local_point in local_points:
		world_points.append(to_local(collision.to_global(local_point)))
	return world_points
