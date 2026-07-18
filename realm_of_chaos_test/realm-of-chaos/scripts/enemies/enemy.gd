extends CharacterBody2D

const GameDefs = preload("res://scripts/game_defs.gd")
const EnemyProjectileScene = preload("res://scenes/enemies/enemy_projectile.tscn")
const ENEMY_ATLAS = preload("res://assets/generated/enemy_atlas.png")

var enemy_type := "prowler"
var power := 1.0
var elite := false
var boss := false
var hp := 30.0
var max_hp := 30.0
var move_speed := 90.0
var contact_damage := 10.0
var xp_value := 3
var hit_radius := 21.0
var world: Node
var player: Node2D
var damage_cooldown := 0.0
var cast_cooldown := 2.0
var knockback_velocity := Vector2.ZERO
var movement_age := 0.0
var dead := false
var base_visual_scale := 0.2
var animation_offset := 0.0
var attack_pulse := 0.0
var cast_pulse := 0.0
var hit_squash := 0.0
var front_arm: Node2D
var back_arm: Node2D
var front_leg: Node2D
var back_leg: Node2D
var limb_length := 24.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Polygon2D = $Shadow
@onready var back_limbs: Node2D = $BackLimbs
@onready var front_limbs: Node2D = $FrontLimbs
@onready var health_bar: ProgressBar = $HealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func setup(kind: String, difficulty_power := 1.0, is_elite := false, owner_world: Node = null) -> void:
	enemy_type = kind
	power = difficulty_power
	elite = is_elite
	world = owner_world


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	movement_age = randf() * TAU
	animation_offset = randf() * TAU
	_apply_definition()


func _apply_definition() -> void:
	var data := GameDefs.enemy_data(enemy_type)
	boss = bool(data.get("boss", false))
	max_hp = float(data.hp) * power
	move_speed = float(data.speed) * (1.0 + (power - 1.0) * 0.12)
	contact_damage = float(data.damage) * (1.0 + (power - 1.0) * 0.28)
	xp_value = maxi(1, int(round(float(data.xp) * sqrt(power))))
	hit_radius = float(data.radius)
	if elite and not boss:
		max_hp *= 3.2
		move_speed *= 1.08
		contact_damage *= 1.55
		xp_value *= 4
	hp = max_hp

	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = ENEMY_ATLAS
	var cell: Vector2i = data.cell
	atlas_texture.region = Rect2(cell.x * 512, cell.y * 512, 512, 512)
	sprite.texture = atlas_texture
	base_visual_scale = float(data.visual_scale) * (1.13 if elite else 1.0)
	sprite.scale = Vector2.ONE * base_visual_scale
	sprite.modulate = Color("d8b7ff") if elite and not boss else Color.WHITE

	var circle := CircleShape2D.new()
	circle.radius = hit_radius
	collision_shape.shape = circle
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_bar.visible = elite or boss
	var style := StyleBoxFlat.new()
	style.bg_color = data.color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	health_bar.add_theme_stylebox_override("fill", style)
	cast_cooldown = randf_range(0.8, 2.2)
	_build_limb_rig(data)


func _build_limb_rig(data: Dictionary) -> void:
	var limb_color: Color = data.color.darkened(0.60)
	if elite and not boss:
		limb_color = limb_color.lightened(0.12)
	limb_length = clampf(hit_radius * 0.90, 17.0, 39.0)
	var limb_width := clampf(hit_radius * 0.15, 3.0, 6.4)
	if enemy_type == "bat":
		back_arm = _create_wing(back_limbs, "BackWing", -1.0, limb_color)
		front_arm = _create_wing(front_limbs, "FrontWing", 1.0, limb_color.lightened(0.12))
		return
	if enemy_type == "ember":
		back_arm = _create_wing(back_limbs, "BackFlame", -1.0, limb_color)
		front_arm = _create_wing(front_limbs, "FrontFlame", 1.0, limb_color.lightened(0.10))
		back_arm.scale = Vector2.ONE * 0.48
		front_arm.scale = Vector2.ONE * 0.48
		return

	back_arm = _create_limb(back_limbs, "BackArm", Vector2(-hit_radius * 0.43, -hit_radius * 0.50), limb_length, limb_width, limb_color)
	front_arm = _create_limb(front_limbs, "FrontArm", Vector2(hit_radius * 0.43, -hit_radius * 0.50), limb_length, limb_width, limb_color.lightened(0.06))
	if enemy_type == "prowler" or enemy_type == "void_knight":
		_add_melee_weapon(front_arm, limb_length, limb_width, data.color)


func _create_limb(parent_node: Node2D, node_name: String, anchor: Vector2, length: float, half_width: float, color: Color) -> Node2D:
	var pivot := Node2D.new()
	pivot.name = node_name
	pivot.position = anchor
	parent_node.add_child(pivot)
	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([
		Vector2(-half_width, -2.0), Vector2(half_width, -2.0),
		Vector2(half_width * 0.82, length * 0.52), Vector2(half_width * 0.62, length),
		Vector2(-half_width * 0.62, length), Vector2(-half_width * 0.82, length * 0.52)
	])
	outline.color = Color(0.035, 0.018, 0.05, 0.96)
	pivot.add_child(outline)
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([
		Vector2(-half_width * 0.64, 0.0), Vector2(half_width * 0.64, 0.0),
		Vector2(half_width * 0.52, length * 0.50), Vector2(half_width * 0.38, length * 0.88),
		Vector2(-half_width * 0.38, length * 0.88), Vector2(-half_width * 0.52, length * 0.50)
	])
	fill.color = Color(color.r, color.g, color.b, 0.88)
	pivot.add_child(fill)
	return pivot


func _create_wing(parent_node: Node2D, node_name: String, side: float, color: Color) -> Node2D:
	var pivot := Node2D.new()
	pivot.name = node_name
	pivot.position = Vector2(side * 5.0, -17.0)
	parent_node.add_child(pivot)
	var wing := Polygon2D.new()
	wing.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(side * 34.0, -15.0), Vector2(side * 27.0, 0.0),
		Vector2(side * 37.0, 15.0), Vector2(side * 18.0, 10.0), Vector2(side * 8.0, 19.0)
	])
	wing.color = color
	pivot.add_child(wing)
	var membrane := Polygon2D.new()
	membrane.polygon = PackedVector2Array([
		Vector2(side * 4.0, 1.0), Vector2(side * 29.0, -10.0),
		Vector2(side * 23.0, 0.0), Vector2(side * 30.0, 10.0), Vector2(side * 11.0, 8.0)
	])
	membrane.color = Color(0.42, 0.04, 0.12, 0.72)
	pivot.add_child(membrane)
	return pivot


func _add_melee_weapon(arm: Node2D, length: float, width: float, color: Color) -> void:
	var blade := Polygon2D.new()
	blade.name = "MovingWeapon"
	blade.polygon = PackedVector2Array([
		Vector2(-width * 0.34, length * 0.78), Vector2(width * 0.34, length * 0.78),
		Vector2(width * 0.28, length * 1.20), Vector2(0.0, length * 1.38),
		Vector2(-width * 0.28, length * 1.20)
	])
	var blade_color := color.darkened(0.38)
	blade.color = Color(blade_color.r, blade_color.g, blade_color.b, 0.88)
	arm.add_child(blade)


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	movement_age += delta
	damage_cooldown -= delta
	cast_cooldown -= delta
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized()

	if enemy_type == "mage":
		if distance > 285.0:
			velocity = direction * move_speed
		elif distance < 190.0:
			velocity = -direction * move_speed
		else:
			velocity = direction.rotated(PI * 0.5) * move_speed * sin(movement_age * 1.7)
	elif enemy_type == "bat":
		velocity = direction.rotated(sin(movement_age * 5.5) * 0.28) * move_speed
	else:
		velocity = direction * move_speed

	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 720.0 * delta)
	move_and_slide()
	sprite.flip_h = velocity.x < -2.0
	_animate_visual(delta, direction)

	if bool(GameDefs.enemy_data(enemy_type).get("ranged", false)) and cast_cooldown <= 0.0:
		_cast_projectile(direction)

	if distance <= hit_radius + 22.0 and damage_cooldown <= 0.0:
		attack_pulse = 1.0
		player.take_damage(contact_damage, direction)
		damage_cooldown = 1.0 if not boss else 0.75

	if distance > 1450.0 and world:
		global_position = world.get_spawn_position(690.0, 820.0)


func _animate_visual(delta: float, direction: Vector2) -> void:
	attack_pulse = move_toward(attack_pulse, 0.0, delta * 4.8)
	cast_pulse = move_toward(cast_pulse, 0.0, delta * 3.5)
	hit_squash = move_toward(hit_squash, 0.0, delta * 7.5)
	var cycle := movement_age + animation_offset
	var target_scale := Vector2.ONE * base_visual_scale
	var target_position := Vector2(0.0, -16.0)
	var target_rotation := 0.0
	var lift := 0.0

	match enemy_type:
		"bat":
			var flap := sin(cycle * 13.0)
			lift = sin(cycle * 5.2) * 7.0
			target_scale *= Vector2(1.0 + flap * 0.13, 1.0 - flap * 0.10)
			target_rotation = sin(cycle * 5.2) * 0.11
		"mage":
			lift = sin(cycle * 2.35) * 7.5
			target_scale *= Vector2(1.0 - sin(cycle * 2.35) * 0.025, 1.0 + sin(cycle * 2.35) * 0.035 + cast_pulse * 0.10)
			target_rotation = sin(cycle * 1.7) * 0.035
		"brute":
			var stomp := sin(cycle * 4.25)
			lift = -abs(stomp) * 3.2
			target_scale *= Vector2(1.0 + stomp * 0.035, 1.0 - stomp * 0.045)
			target_rotation = stomp * 0.032
		"ember":
			var pulse := sin(cycle * 3.2)
			lift = sin(cycle * 3.0) * 8.5
			target_scale *= Vector2.ONE * (1.0 + pulse * 0.075)
			target_rotation = sin(cycle * 2.1) * 0.075
		"void_knight":
			var menace := sin(cycle * 1.75)
			lift = menace * 4.5
			target_scale *= Vector2(1.0 - menace * 0.018, 1.0 + menace * 0.028 + cast_pulse * 0.08)
			target_rotation = sin(cycle * 1.15) * 0.018
		_:
			var stride := sin(cycle * 8.4)
			lift = -abs(stride) * 3.8
			target_scale *= Vector2(1.0 + stride * 0.04, 1.0 - stride * 0.055)
			target_rotation = stride * 0.055

	target_position.y += lift
	target_position -= direction * attack_pulse * 7.0
	if hit_squash > 0.0:
		target_scale *= Vector2(1.0 + hit_squash * 0.15, 1.0 - hit_squash * 0.13)
		target_rotation += sin(cycle * 35.0) * hit_squash * 0.08
	var smoothing := 1.0 - exp(-delta * 13.0)
	sprite.scale = sprite.scale.lerp(target_scale, smoothing)
	sprite.position = sprite.position.lerp(target_position, smoothing)
	sprite.rotation = lerpf(sprite.rotation, target_rotation, smoothing)
	_animate_limb_rig(smoothing, cycle)
	var altitude := absf(lift)
	var shadow_target := Vector2(1.0 + altitude * 0.012, 1.0 - altitude * 0.018)
	shadow.scale = shadow.scale.lerp(shadow_target, 1.0 - exp(-delta * 9.0))
	shadow.color.a = lerpf(shadow.color.a, 0.48 - altitude * 0.018, smoothing)
	if elite or boss or enemy_type == "ember":
		queue_redraw()


func _animate_limb_rig(smoothing: float, cycle: float) -> void:
	var facing := -1.0 if velocity.x < -2.0 else 1.0
	back_limbs.scale.x = facing
	front_limbs.scale.x = facing
	var stride := sin(cycle * (4.2 if enemy_type == "brute" or boss else 8.0))
	var strike := sin((1.0 - attack_pulse) * PI) if attack_pulse > 0.0 else 0.0
	if enemy_type == "bat":
		var flap := sin(cycle * 13.0)
		back_arm.rotation = lerpf(back_arm.rotation, -flap * 0.32, smoothing)
		front_arm.rotation = lerpf(front_arm.rotation, flap * 0.32, smoothing)
		back_arm.scale.y = lerpf(back_arm.scale.y, 0.72 + absf(flap) * 0.34, smoothing)
		front_arm.scale.y = lerpf(front_arm.scale.y, 0.72 + absf(flap) * 0.34, smoothing)
		return
	if enemy_type == "ember":
		back_arm.rotation = lerpf(back_arm.rotation, sin(cycle * 4.1) * 0.58, smoothing)
		front_arm.rotation = lerpf(front_arm.rotation, -sin(cycle * 4.6) * 0.58 + strike * 0.8, smoothing)
		return

	var arm_amount := 0.25 if enemy_type == "mage" else (0.34 if enemy_type == "brute" or boss else 0.46)
	var front_arm_target := -stride * arm_amount + strike * (1.05 if enemy_type == "mage" else 1.52)
	var back_arm_target := stride * arm_amount - strike * 0.28
	if cast_pulse > 0.0:
		front_arm_target -= cast_pulse * 1.18
		back_arm_target += cast_pulse * 0.76
	front_arm.rotation = lerpf(front_arm.rotation, front_arm_target, smoothing)
	back_arm.rotation = lerpf(back_arm.rotation, back_arm_target, smoothing)
	if is_instance_valid(front_leg) and is_instance_valid(back_leg):
		var leg_amount := 0.17 if enemy_type == "mage" else (0.24 if enemy_type == "brute" or boss else 0.34)
		front_leg.rotation = lerpf(front_leg.rotation, stride * leg_amount, smoothing)
		back_leg.rotation = lerpf(back_leg.rotation, -stride * leg_amount, smoothing)


func _cast_projectile(direction: Vector2) -> void:
	cast_pulse = 1.0
	cast_cooldown = 2.8 if enemy_type == "mage" else 1.55
	var count := 1 if not boss else 5
	for index in range(count):
		var projectile = EnemyProjectileScene.instantiate()
		var offset := float(index) - float(count - 1) * 0.5
		var shot_direction := direction.rotated(offset * 0.17)
		projectile.global_position = global_position + shot_direction * (hit_radius + 8.0)
		var color := Color("63c7ff") if enemy_type == "mage" else Color("b05cff")
		projectile.setup(shot_direction, contact_damage * 0.7, 235.0 if not boss else 275.0, color, 8.0 if not boss else 11.0)
		if world:
			world.add_enemy_projectile(projectile)
		else:
			get_tree().current_scene.add_child(projectile)


func take_damage(amount: float, force := Vector2.ZERO, critical := false) -> void:
	if dead:
		return
	hp -= amount
	knockback_velocity += force
	hit_squash = 1.0
	health_bar.value = hp
	health_bar.visible = true
	var flash_color := Color("fff2a8") if critical else Color.WHITE
	sprite.modulate = flash_color * 1.8
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color("d8b7ff") if elite and not boss else Color.WHITE, 0.12)
	if world:
		world.spawn_effect(global_position, GameDefs.enemy_data(enemy_type).color, hit_radius * 1.3, 0.16)
	if hp <= 0.0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)
	health_bar.hide()
	if world:
		world.handle_enemy_death(self, xp_value, elite, boss)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2.ONE * base_visual_scale * 1.38, 0.26)
	tween.tween_property(sprite, "rotation", sprite.rotation + (0.42 if randf() > 0.5 else -0.42), 0.26)
	tween.tween_property(sprite, "modulate", Color(0.42, 0.16, 0.55, 0.0), 0.28)
	tween.tween_property(front_limbs, "modulate", Color(0.42, 0.16, 0.55, 0.0), 0.28)
	tween.tween_property(back_limbs, "modulate", Color(0.42, 0.16, 0.55, 0.0), 0.28)
	tween.tween_property(shadow, "scale", Vector2(1.45, 0.35), 0.28)
	tween.tween_property(shadow, "color", Color(0.01, 0.005, 0.02, 0.0), 0.28)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	if enemy_type == "ember":
		var ember_alpha := 0.12 + (sin(movement_age * 3.2 + animation_offset) + 1.0) * 0.045
		draw_circle(Vector2(0.0, -12.0), hit_radius * 1.45, Color(1.0, 0.25, 0.16, ember_alpha))
	if elite and not boss:
		draw_arc(Vector2(0.0, 1.0), hit_radius * 1.35, 0.0, TAU, 30, Color(0.76, 0.45, 1.0, 0.34), 2.0)
	if boss:
		var aura_radius := hit_radius * (1.40 + sin(movement_age * 1.75) * 0.08)
		draw_circle(Vector2(0.0, -5.0), aura_radius, Color(0.52, 0.12, 0.82, 0.10))
		draw_arc(Vector2(0.0, -5.0), aura_radius, movement_age * 0.55, movement_age * 0.55 + PI * 1.45, 48, Color(0.78, 0.44, 1.0, 0.48), 3.0)
