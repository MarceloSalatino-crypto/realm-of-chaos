extends Area2D

var speed = 400.0
var direction = Vector2.ZERO
var damage = 1
var hit_radius = 20.0

func init(dir: Vector2):
	direction = dir

func _physics_process(delta):
	position += direction * speed * delta
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < hit_radius:
			enemy.take_damage(damage)
			queue_free()
			return

func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()
