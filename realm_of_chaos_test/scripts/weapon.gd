extends Node2D
@export var fire_rate:float=0.55
var timer:=0.0
func _process(delta:float)->void:
	timer-=delta
	if timer<=0:
		timer=fire_rate; shoot()
func shoot()->void:
	var enemies=get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty(): return
	var closest=enemies[0]; var closest_dist=global_position.distance_to(closest.global_position)
	for e in enemies:
		var dist=global_position.distance_to(e.global_position)
		if dist<closest_dist: closest=e; closest_dist=dist
	var bullet=preload("res://scenes/bullet.tscn").instantiate()
	get_tree().current_scene.add_child(bullet); bullet.global_position=global_position; bullet.direction=global_position.direction_to(closest.global_position)
