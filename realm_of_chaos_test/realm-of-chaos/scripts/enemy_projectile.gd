extends Area2D

var direction := Vector2.ZERO
var speed := 230.0
var damage := 12.0
var radius := 9.0
var lifetime := 5.0
var projectile_color := Color("62c7ff")
var uses_danger_style := false
var owner_world: Node
var target_player: Node2D
var active := false


func setup(dir: Vector2, amount: float, projectile_speed: float, color: Color, size := 9.0, danger_style := false, projectile_world: Node = null, player_target: Node2D = null) -> void:
	direction = dir.normalized()
	damage = amount
	speed = projectile_speed
	projectile_color = color
	radius = size
	uses_danger_style = danger_style
	owner_world = projectile_world
	target_player = player_target
	lifetime = 5.0
	rotation = 0.0
	active = true
	visible = true
	set_physics_process(true)
	queue_redraw()


func bind_runtime(projectile_world: Node, player_target: Node2D) -> void:
	owner_world = projectile_world
	target_player = player_target
	active = true
	visible = true
	set_physics_process(true)


func prepare_for_pool() -> void:
	active = false
	visible = false
	set_physics_process(false)


func _finish() -> void:
	if not active:
		return
	prepare_for_pool()
	if is_instance_valid(owner_world) and owner_world.has_method("recycle_enemy_projectile"):
		owner_world.call_deferred("recycle_enemy_projectile", self)
	else:
		queue_free()


func _physics_process(delta: float) -> void:
	if not active:
		return
	global_position += direction * speed * delta
	rotation += delta * 4.0
	lifetime -= delta
	if lifetime <= 0.0:
		_finish()
		return
	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player")
	if target_player and global_position.distance_squared_to(target_player.global_position) <= pow(radius + 18.0, 2.0):
		target_player.take_damage(damage, direction)
		_finish()


func _draw() -> void:
	if uses_danger_style:
		# Pontas irregulares e núcleo escuro formam uma leitura clara de ameaça.
		draw_circle(Vector2.ZERO, radius * 2.05, Color(projectile_color, 0.18))
		var outline_points := PackedVector2Array()
		var blade_points := PackedVector2Array()
		for index in range(16):
			var angle := -PI * 0.5 + TAU * float(index) / 16.0
			var is_tip := index % 2 == 0
			var outline_radius := radius * (1.34 if is_tip else 0.62)
			var blade_radius := radius * (1.08 if is_tip else 0.48)
			outline_points.append(Vector2.RIGHT.rotated(angle) * outline_radius)
			blade_points.append(Vector2.RIGHT.rotated(angle) * blade_radius)
		draw_colored_polygon(outline_points, Color("290713"))
		draw_colored_polygon(blade_points, projectile_color)
		draw_circle(Vector2.ZERO, radius * 0.36, Color("4a071b"))
		draw_circle(Vector2(-radius * 0.10, -radius * 0.12), radius * 0.13, Color("ffb0bc"))
		return
	draw_circle(Vector2.ZERO, radius * 1.8, Color(projectile_color, 0.16))
	var points := PackedVector2Array([
		Vector2(0, -radius), Vector2(radius * 0.75, 0),
		Vector2(0, radius), Vector2(-radius * 0.75, 0)
	])
	draw_colored_polygon(points, projectile_color)
	draw_circle(Vector2.ZERO, radius * 0.28, Color.WHITE)
