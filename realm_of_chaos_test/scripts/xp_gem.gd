extends Area2D
@export var value:int=1
var player:Node2D
func _ready()->void: player=get_tree().get_first_node_in_group("player")
func _physics_process(delta:float)->void:
	if player and global_position.distance_to(player.global_position)<170:
		global_position=global_position.move_toward(player.global_position,350*delta)
func _on_body_entered(body:Node)->void:
	if body.is_in_group("player") and body.has_method("add_xp"):
		body.add_xp(value); queue_free()
