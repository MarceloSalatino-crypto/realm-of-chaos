extends RefCounted

var enemy


func _init(owner_enemy) -> void:
	enemy = owner_enemy


func prepare_velocity(direction: Vector2, distance: float, delta: float) -> void:
	update_movement(direction, distance)
	apply_separation(delta)


func update_movement(direction: Vector2, distance: float) -> void:
	match enemy.behavior:
		"ranged", "archer", "necromancer", "glacial":
			var desired_min: float = 220.0 if enemy.behavior == "archer" else 185.0
			var desired_max: float = 340.0 if enemy.behavior == "archer" else 285.0
			if distance > desired_max:
				enemy.velocity = direction * enemy.move_speed
			elif distance < desired_min:
				enemy.velocity = -direction * enemy.move_speed
			else:
				enemy.velocity = direction.rotated(PI * 0.5) * enemy.move_speed * sin(enemy.movement_age * 1.7)
		"swarm_flight":
			enemy.velocity = direction.rotated(sin(enemy.movement_age * 5.5) * 0.28) * enemy.move_speed
		"assassin":
			enemy.velocity = direction.rotated(sin(enemy.movement_age * 3.2) * 0.12) * enemy.move_speed
		"sovereign":
			enemy.velocity = direction.rotated(sin(enemy.movement_age * 1.5) * 0.15) * enemy.move_speed
		_:
			enemy.velocity = direction * enemy.move_speed


func apply_separation(delta: float) -> void:
	if not enemy.world or enemy.boss or not enemy.world.has_method("get_enemies_near"):
		return
	enemy.separation_timer -= delta
	if enemy.separation_timer > 0.0:
		enemy.velocity += enemy.separation_force
		return
	enemy.separation_timer = 0.10 + fmod(float(enemy.get_instance_id()), 7.0) * 0.006
	var separation := Vector2.ZERO
	var checked := 0
	for neighbor in enemy.world.get_enemies_near(enemy.global_position, enemy.hit_radius * 2.4 + 16.0):
		if neighbor == enemy or not is_instance_valid(neighbor):
			continue
		var away: Vector2 = enemy.global_position - neighbor.global_position
		var distance_squared := maxf(away.length_squared(), 16.0)
		separation += away.normalized() / sqrt(distance_squared)
		checked += 1
		if checked >= 8:
			break
	if separation.length_squared() > 0.0001:
		enemy.separation_force = separation.normalized() * enemy.move_speed * minf(0.52, checked * 0.08)
	else:
		enemy.separation_force = Vector2.ZERO
	enemy.velocity += enemy.separation_force


func integrate_motion(delta: float, direction: Vector2) -> float:
	enemy.velocity += enemy.knockback_velocity + enemy.dash_velocity + enemy.obstacle_avoidance
	enemy.knockback_velocity = enemy.knockback_velocity.move_toward(Vector2.ZERO, 720.0 * delta)
	enemy.dash_velocity = enemy.dash_velocity.move_toward(Vector2.ZERO, 980.0 * delta)
	enemy.obstacle_avoidance = enemy.obstacle_avoidance.move_toward(Vector2.ZERO, 420.0 * delta)
	var event_speed: float = float(enemy.world.enemy_speed_multiplier) if enemy.world else 1.0
	enemy.velocity *= event_speed * enemy.slow_multiplier
	var movement_start_position: Vector2 = enemy.global_position
	enemy.move_and_slide()
	var distance_moved: float = movement_start_position.distance_to(enemy.global_position)
	if enemy.get_slide_collision_count() > 0 and enemy.dash_velocity.length_squared() < 10.0:
		var collision: KinematicCollision2D = enemy.get_slide_collision(0)
		var tangent: Vector2 = collision.get_normal().rotated(PI * 0.5)
		if tangent.dot(direction) < 0.0:
			tangent = -tangent
		enemy.obstacle_avoidance = tangent * enemy.move_speed * 0.62
	return distance_moved


func apply_slow(multiplier: float, duration: float) -> void:
	enemy.slow_multiplier = minf(enemy.slow_multiplier, clampf(multiplier, 0.35, 1.0))
	enemy.slow_time = maxf(enemy.slow_time, duration * (0.45 if enemy.boss else 1.0))
	if enemy.world:
		enemy.world.spawn_effect(enemy.global_position, Color("69dcff"), enemy.hit_radius * 1.4, 0.28)


func reposition_far() -> void:
	var spawn_position: Vector2 = enemy.world.get_spawn_position(690.0, 820.0)
	if is_finite(spawn_position.x) and is_finite(spawn_position.y):
		enemy.global_position = spawn_position
