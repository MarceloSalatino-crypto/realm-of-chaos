extends CharacterBody2D

var speed = 80.0
var hp = 3
var player = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")

func _physics_process(delta):
	if player == null:
		return
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

func take_damage(amount):
	hp -= amount
	if hp <= 0:
		queue_free()
