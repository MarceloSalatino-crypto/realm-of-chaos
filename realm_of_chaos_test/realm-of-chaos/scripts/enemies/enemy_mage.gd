extends CharacterBody2D

var speed = 60.0
var hp = 5
var max_hp = 5
var player = null
var world = null
@onready var health_bar = $HealthBar

var cast_cooldown := 0.0
var cast_interval := 3.0
var ice_blast_scene = preload("res://scenes/enemies/ice_blast.tscn")

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	health_bar.max_value = max_hp
	health_bar.value = hp
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 1.0)
	health_bar.add_theme_stylebox_override("fill", style)
	cast_cooldown = randf_range(1.0, 3.0)

func _physics_process(delta):
	if player == null:
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	if dist > 150:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	cast_cooldown -= delta
	if cast_cooldown <= 0:
		cast_cooldown = cast_interval
		cast_ice_blast()

func cast_ice_blast():
	if player == null:
		return
	var blast = ice_blast_scene.instantiate()
	blast.global_position = global_position
	var dir = (player.global_position - global_position).normalized()
	blast.init(dir)
	get_parent().add_child(blast)

func take_damage(amount):
	hp -= amount
	health_bar.value = hp
	if hp <= 0:
		if world != null:
			world.enemy_died()
		queue_free()
