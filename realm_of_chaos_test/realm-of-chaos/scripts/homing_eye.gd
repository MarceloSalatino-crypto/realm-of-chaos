class_name HomingEye
extends Node2D

const WEAPON_ATLAS = preload("res://assets/generated/weapon_atlas_v1.png")

var target: Node2D
var world: Node
var damage := 20.0
var speed := 330.0
var critical := false
var source_id := "swarm_idol"
var lifetime := 4.0
var direction := Vector2.RIGHT
var sprite: Sprite2D


func setup(start_position: Vector2, initial_target: Node2D, amount: float, projectile_speed: float, is_critical: bool) -> void:
	global_position = start_position
	target = initial_target
	damage = amount
	speed = projectile_speed
	critical = is_critical
	if is_instance_valid(target):
		direction = (target.global_position - global_position).normalized()


func _ready() -> void:
	world = get_tree().get_first_node_in_group("world")
	sprite = Sprite2D.new()
	sprite.texture = WEAPON_ATLAS
	sprite.hframes = 5
	sprite.frame = 4
	sprite.scale = Vector2.ONE * 0.075
	sprite.modulate = Color("d9a2ff")
	add_child(sprite)
	z_index = 13


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if not is_instance_valid(target) or bool(target.get("dead")):
		target = world.get_nearest_enemy(global_position, 900.0) if world else null
	if is_instance_valid(target):
		var desired := (target.global_position - global_position).normalized()
		direction = direction.lerp(desired, 1.0 - exp(-delta * 7.5)).normalized()
		if global_position.distance_to(target.global_position) <= float(target.hit_radius) + 15.0:
			target.take_damage(damage, direction * 18.0, critical, source_id)
			if world:
				world.spawn_effect(global_position, Color("c36cff"), 34.0, 0.20, true)
			queue_free()
			return
	global_position += direction * speed * delta
	rotation = direction.angle() + sin(Time.get_ticks_msec() * 0.008) * 0.08

