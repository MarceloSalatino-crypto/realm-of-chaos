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
	is_critical := false
) -> void:
	direction = dir.normalized()
	damage = amount
	speed = projectile_speed
	pierce = pierce_count
	hit_radius = radius
	projectile_color = color
	critical = is_critical
	rotation = direction.angle()
	queue_redraw()


func init(dir: Vector2) -> void:
	setup(dir, damage, speed, pierce, hit_radius, projectile_color)


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
			enemy.take_damage(damage, direction * knockback, critical)
			pierce -= 1
			if pierce < 0:
				queue_free()
				return


func _draw() -> void:
	var glow := projectile_color
	glow.a = 0.20
	draw_circle(Vector2.ZERO, hit_radius * 1.9, glow)
	draw_circle(Vector2.ZERO, hit_radius, projectile_color)
	draw_circle(Vector2(hit_radius * 0.25, -hit_radius * 0.25), hit_radius * 0.35, Color.WHITE)
	draw_line(Vector2(-hit_radius * 2.4, 0), Vector2(-hit_radius * 0.7, 0), Color(projectile_color, 0.4), hit_radius * 0.8)


func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	if lifetime < 1.0:
		queue_free()
