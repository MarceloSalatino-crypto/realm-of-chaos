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
var visual_presented := false


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
	visual_presented = false
	visible = true
	set_physics_process(true)
	queue_redraw()


func bind_runtime(projectile_world: Node, player_target: Node2D) -> void:
	owner_world = projectile_world
	target_player = player_target
	active = true
	visual_presented = false
	visible = true
	set_physics_process(true)


func prepare_for_pool() -> void:
	active = false
	visual_presented = false
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
	# Um disparo que nasce perto do alvo aguarda sua primeira apresentação visual.
	# Isso impede múltiplos ticks de física, em FPS baixo, de acertarem antes do draw.
	if not visual_presented:
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


func _process(_delta: float) -> void:
	# Sem batching, o draw acontece depois deste process e antes do próximo tick
	# de física. Com batching, apenas o renderizador confirma a apresentação
	# depois de inserir a instância no buffer visível.
	if active and visible and not _uses_batch_renderer():
		mark_visual_presented()


func mark_visual_presented() -> void:
	visual_presented = true


func _draw() -> void:
	if _uses_batch_renderer():
		return
	var outline := Color("240b18")
	var shadow := projectile_color.darkened(0.48)
	var highlight := projectile_color.lightened(0.42)
	if uses_danger_style:
		# Pontas irregulares e núcleo escuro formam uma leitura clara de ameaça.
		var danger_outline_points := PackedVector2Array()
		var blade_points := PackedVector2Array()
		for index in range(16):
			var angle := -PI * 0.5 + TAU * float(index) / 16.0
			var is_tip := index % 2 == 0
			var outline_radius := radius * (1.34 if is_tip else 0.62)
			var blade_radius := radius * (1.08 if is_tip else 0.48)
			danger_outline_points.append(Vector2.RIGHT.rotated(angle) * outline_radius)
			blade_points.append(Vector2.RIGHT.rotated(angle) * blade_radius)
		draw_colored_polygon(danger_outline_points, outline)
		draw_colored_polygon(blade_points, projectile_color)
		draw_circle(Vector2.ZERO, radius * 0.36, Color("4a071b"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-radius * 0.06, -radius * 0.28),
			Vector2(radius * 0.22, -radius * 0.02),
			Vector2(-radius * 0.06, radius * 0.20),
			Vector2(-radius * 0.28, -radius * 0.02),
		]), highlight)
		return
	var outline_points := PackedVector2Array([
		Vector2(0.0, -radius * 1.32), Vector2(radius * 0.96, 0.0),
		Vector2(0.0, radius * 1.32), Vector2(-radius * 0.96, 0.0)
	])
	var fill_points := PackedVector2Array([
		Vector2(0.0, -radius), Vector2(radius * 0.68, 0.0),
		Vector2(0.0, radius), Vector2(-radius * 0.68, 0.0)
	])
	draw_colored_polygon(outline_points, outline)
	draw_colored_polygon(fill_points, shadow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -radius * 0.78),
		Vector2(radius * 0.46, 0.0),
		Vector2(0.0, radius * 0.18),
		Vector2(-radius * 0.46, 0.0),
	]), projectile_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -radius * 0.36),
		Vector2(radius * 0.20, 0.0),
		Vector2(0.0, radius * 0.20),
		Vector2(-radius * 0.20, 0.0),
	]), highlight)


func _uses_batch_renderer() -> bool:
	if not is_instance_valid(owner_world):
		return false
	var renderer: Node = owner_world.get("enemy_projectile_batch_renderer")
	return is_instance_valid(renderer) and bool(renderer.get("rendering_enabled"))


func projectile_batch_style() -> String:
	return "danger" if uses_danger_style else "generic"


func projectile_batch_radius() -> float:
	return radius


func projectile_batch_color() -> Color:
	return projectile_color
