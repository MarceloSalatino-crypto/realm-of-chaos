extends CharacterBody2D

var speed = 80.0
var hp = 3
var max_hp = 3
var player = null
var world = null
@onready var health_bar = $HealthBar

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	health_bar.max_value = max_hp
	health_bar.value = hp
	var style = StyleBoxFlat.new()
	style.bg_color = Color.RED
	health_bar.add_theme_stylebox_override("fill", style)

var damage_cooldown := 0.0

func _physics_process(delta):
	if player == null:
		return
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
	
	damage_cooldown -= delta
	var dist = global_position.distance_to(player.global_position)
	if dist < 40 and damage_cooldown <= 0:
		player.take_damage(10)
		damage_cooldown = 1.0

func take_damage(amount):
	hp -= amount
	health_bar.value = hp
	if hp <= 0:
		if world != null:
			world.enemy_died()
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.take_damage(1)
