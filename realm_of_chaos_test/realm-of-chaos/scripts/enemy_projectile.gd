extends Area2D

var direction := Vector2.ZERO
var speed := 230.0
var damage := 12.0
var radius := 9.0
var lifetime := 5.0
var projectile_color := Color("62c7ff")


func setup(dir: Vector2, amount: float, projectile_speed: float, color: Color, size := 9.0) -> void:
	direction = dir.normalized()
	damage = amount
	speed = projectile_speed
	projectile_color = color
	radius = size
	queue_redraw()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	rotation += delta * 4.0
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_squared_to(player.global_position) <= pow(radius + 18.0, 2.0):
		player.take_damage(damage, direction)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius * 1.8, Color(projectile_color, 0.16))
	var points := PackedVector2Array([
		Vector2(0, -radius), Vector2(radius * 0.75, 0),
		Vector2(0, radius), Vector2(-radius * 0.75, 0)
	])
	draw_colored_polygon(points, projectile_color)
	draw_circle(Vector2.ZERO, radius * 0.28, Color.WHITE)
