extends Node2D
var enemy_scene=preload("res://scenes/enemy.tscn")
@onready var player:Node2D=$Player
@onready var hud:Label=$CanvasLayer/HUD
func _ready()->void: randomize()
func _process(_delta:float)->void:
	if is_instance_valid(player):
		hud.text="HP: %s/%s   LVL: %s   XP: %s/%s   Inimigos: %s" % [player.hp,player.max_hp,player.level,player.xp,player.xp_to_next,get_tree().get_nodes_in_group("enemy").size()]
func _on_spawn_timer_timeout()->void:
	var enemy=enemy_scene.instantiate(); add_child(enemy)
	var angle=randf()*TAU; enemy.global_position=player.global_position+Vector2.RIGHT.rotated(angle)*randf_range(650,850)
func _draw()->void:
	var grid:=128; var limit:=5000
	for x in range(-limit,limit+grid,grid): draw_line(Vector2(x,-limit),Vector2(x,limit),Color(0.18,0.22,0.18),2)
	for y in range(-limit,limit+grid,grid): draw_line(Vector2(-limit,y),Vector2(limit,y),Color(0.18,0.22,0.18),2)
