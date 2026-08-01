extends Area2D

var speed := 620.0
var direction := Vector2.RIGHT
var damage := 10.0
var hit_radius := 10.0
var pierce := 0
var knockback := 16.0
var lifetime := 2.2
var projectile_color := Color("a96cff")
var critical := false
var source_weapon := "unknown"
var hit_targets: Dictionary = {}
var world: Node


func _ready() -> void:
	world = get_tree().get_first_node_in_group("world")


func setup(
	dir: Vector2,
	amount: float,
	projectile_speed: float,
	pierce_count: int,
	radius: float,
	color: Color,
	is_critical := false,
	weapon_id := "unknown"
) -> void:
	direction = dir.normalized()
	damage = amount
	speed = projectile_speed
	pierce = pierce_count
	hit_radius = radius
	projectile_color = color
	critical = is_critical
	source_weapon = weapon_id
	rotation = direction.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	var candidates: Array[Node] = world.get_enemies_near(global_position, hit_radius + 64.0) if world and world.has_method("get_enemies_near") else get_tree().get_nodes_in_group("enemies")
	for enemy in candidates:
		if not is_instance_valid(enemy):
			continue
		var enemy_id := enemy.get_instance_id()
		if hit_targets.has(enemy_id):
			continue
		if global_position.distance_squared_to(enemy.global_position) <= pow(hit_radius + enemy.hit_radius, 2.0):
			hit_targets[enemy_id] = true
			enemy.take_damage(damage, direction * knockback, critical, source_weapon)
			pierce -= 1
			if pierce < 0:
				queue_free()
				return


func _draw() -> void:
	if _uses_batch_renderer():
		return
	var outline := Color("1b1022")
	var shadow := projectile_color.darkened(0.46)
	var highlight := projectile_color.lightened(0.42)
	match source_weapon:
		"shadow_blades":
			var blade_outline := PackedVector2Array([
				Vector2(-hit_radius * 1.65, -hit_radius * 0.48),
				Vector2(hit_radius * 0.55, -hit_radius * 0.76),
				Vector2(hit_radius * 1.48, 0.0),
				Vector2(hit_radius * 0.55, hit_radius * 0.76),
				Vector2(-hit_radius * 1.65, hit_radius * 0.48),
				Vector2(-hit_radius * 1.12, 0.0),
			])
			var blade_fill := PackedVector2Array([
				Vector2(-hit_radius * 1.35, -hit_radius * 0.27),
				Vector2(hit_radius * 0.42, -hit_radius * 0.48),
				Vector2(hit_radius * 1.12, 0.0),
				Vector2(hit_radius * 0.42, hit_radius * 0.48),
				Vector2(-hit_radius * 1.35, hit_radius * 0.27),
				Vector2(-hit_radius * 0.88, 0.0),
			])
			draw_colored_polygon(blade_outline, outline)
			draw_colored_polygon(blade_fill, projectile_color)
			draw_line(
				Vector2(-hit_radius * 0.82, -hit_radius * 0.12),
				Vector2(hit_radius * 0.58, -hit_radius * 0.25),
				highlight, maxf(1.0, hit_radius * 0.16)
			)
		"chaos_bolt":
			var bolt_outline := PackedVector2Array([
				Vector2(-hit_radius * 1.72, -hit_radius * 0.46),
				Vector2(hit_radius * 0.30, -hit_radius * 0.46),
				Vector2(hit_radius * 1.50, 0.0),
				Vector2(hit_radius * 0.30, hit_radius * 0.46),
				Vector2(-hit_radius * 1.72, hit_radius * 0.46),
				Vector2(-hit_radius * 1.25, 0.0),
			])
			var bolt_fill := PackedVector2Array([
				Vector2(-hit_radius * 1.42, -hit_radius * 0.24),
				Vector2(hit_radius * 0.22, -hit_radius * 0.24),
				Vector2(hit_radius * 1.12, 0.0),
				Vector2(hit_radius * 0.22, hit_radius * 0.24),
				Vector2(-hit_radius * 1.42, hit_radius * 0.24),
				Vector2(-hit_radius * 1.08, 0.0),
			])
			draw_colored_polygon(bolt_outline, outline)
			draw_colored_polygon(bolt_fill, shadow)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-hit_radius * 0.72, -hit_radius * 0.22),
				Vector2(hit_radius * 0.22, -hit_radius * 0.22),
				Vector2(hit_radius * 0.88, 0.0),
				Vector2(hit_radius * 0.22, 0.0),
				Vector2(-hit_radius * 0.72, 0.0),
			]), projectile_color)
			draw_line(
				Vector2(-hit_radius * 1.25, 0.0),
				Vector2(-hit_radius * 2.15, 0.0),
				outline, maxf(2.0, hit_radius * 0.42)
			)
			draw_line(
				Vector2(-hit_radius * 1.28, 0.0),
				Vector2(-hit_radius * 2.08, 0.0),
				projectile_color, maxf(1.0, hit_radius * 0.18)
			)
		_:
			var sigil_outline := PackedVector2Array([
				Vector2(hit_radius * 1.35, 0.0),
				Vector2(hit_radius * 0.45, hit_radius * 0.62),
				Vector2(0.0, hit_radius * 1.15),
				Vector2(-hit_radius * 0.45, hit_radius * 0.62),
				Vector2(-hit_radius * 1.35, 0.0),
				Vector2(-hit_radius * 0.45, -hit_radius * 0.62),
				Vector2(0.0, -hit_radius * 1.15),
				Vector2(hit_radius * 0.45, -hit_radius * 0.62),
			])
			draw_colored_polygon(sigil_outline, outline)
			draw_colored_polygon(PackedVector2Array([
				Vector2(hit_radius, 0.0),
				Vector2(0.0, hit_radius * 0.78),
				Vector2(-hit_radius, 0.0),
				Vector2(0.0, -hit_radius * 0.78),
			]), projectile_color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(hit_radius * 0.42, 0.0),
				Vector2(0.0, hit_radius * 0.32),
				Vector2(-hit_radius * 0.42, 0.0),
				Vector2(0.0, -hit_radius * 0.32),
			]), highlight)


func _uses_batch_renderer() -> bool:
	if not is_instance_valid(world):
		return false
	var renderer: Node = world.get("player_projectile_batch_renderer")
	return is_instance_valid(renderer) and bool(renderer.get("rendering_enabled"))


func projectile_batch_style() -> String:
	match source_weapon:
		"chaos_bolt":
			return "chaos"
		"shadow_blades":
			return "shadow_small" if hit_radius <= 6.25 else "shadow"
		_:
			return "default"


func projectile_batch_radius() -> float:
	return hit_radius


func projectile_batch_color() -> Color:
	return projectile_color


func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	if lifetime < 1.0:
		queue_free()
