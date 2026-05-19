extends Area2D

var speed = 200.0
var direction = Vector2.ZERO
var damage = 15

func init(dir: Vector2):
	direction = dir

func _physics_process(delta):
	position += direction * speed * delta
	
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if global_position.distance_to(player.global_position) < 20:
			player.take_damage(damage)
			queue_free()
			return

func _on_visible_on_screen_enabler_2d_screen_exited():
	queue_free()
