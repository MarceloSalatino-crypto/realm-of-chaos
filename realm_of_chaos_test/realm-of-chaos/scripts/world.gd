extends Node2D

var enemy_scene = preload("res://scenes/enemies/enemy.tscn")
var spawn_timer = 0.0
var spawn_interval = 2.0
var player = null

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_enemy()

func spawn_enemy():
	if player == null:
		return
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	var angle = randf() * TAU
	var distance = 400.0
	var offset = Vector2(cos(angle), sin(angle)) * distance
	enemy.global_position = player.global_position + offset

func _draw():
	var grid_size := 128
	var limit := 5000
	for x in range(-limit, limit + grid_size, grid_size):
		draw_line(Vector2(x, -limit), Vector2(x, limit), Color(0.18, 0.25, 0.18), 2.0)
	for y in range(-limit, limit + grid_size, grid_size):
		draw_line(Vector2(-limit, y), Vector2(limit, y), Color(0.18, 0.25, 0.18), 2.0)
