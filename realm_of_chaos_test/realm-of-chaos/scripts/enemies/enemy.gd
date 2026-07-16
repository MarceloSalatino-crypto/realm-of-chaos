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

@onready var sprite: Sprite2D = $Sprite2D
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
	var visual_scale: float = float(data.visual_scale) * (1.13 if elite else 1.0)
	sprite.scale = Vector2.ONE * visual_scale
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
	sprite.position.y = sin(movement_age * (7.0 if enemy_type == "bat" else 4.0)) * 2.0

	if bool(GameDefs.enemy_data(enemy_type).get("ranged", false)) and cast_cooldown <= 0.0:
		_cast_projectile(direction)

	if distance <= hit_radius + 22.0 and damage_cooldown <= 0.0:
		player.take_damage(contact_damage, direction)
		damage_cooldown = 1.0 if not boss else 0.75

	if distance > 1450.0 and world:
		global_position = world.get_spawn_position(690.0, 820.0)


func _cast_projectile(direction: Vector2) -> void:
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
	if world:
		world.handle_enemy_death(self, xp_value, elite, boss)
	queue_free()
