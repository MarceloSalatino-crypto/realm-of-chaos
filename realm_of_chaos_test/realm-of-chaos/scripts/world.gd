extends Node2D

var enemy_scene = preload("res://scenes/enemies/enemy.tscn")
var elite_scene = preload("res://scenes/enemies/enemy_elite.tscn")
var spawn_timer = 0.0
var spawn_interval = 2.0
var spawn_count = 1
var elite_timer = 0.0
var elite_interval = 15.0
var player = null
var enemies_killed = 0
var time_survived = 0.0
var game_over = false

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	if game_over:
		return
	
	time_survived += delta
	
	# A cada 10 segundos reduz o intervalo e aumenta a quantidade
	spawn_interval = max(0.5, 2.0 - (time_survived / 10.0) * 0.2)
	spawn_count = 1 + int(time_survived / 15.0)
	
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		for i in range(spawn_count):
			spawn_enemy()
	
	elite_timer += delta
	if elite_timer >= elite_interval:
		elite_timer = 0.0
		spawn_elite()

func spawn_enemy():
	if player == null:
		return
	var enemy = enemy_scene.instantiate()
	enemy.world = self
	add_child(enemy)
	var angle = randf() * TAU
	var distance = 400.0
	var offset = Vector2(cos(angle), sin(angle)) * distance
	enemy.global_position = player.global_position + offset

func spawn_elite():
	if player == null:
		return
	var elite = elite_scene.instantiate()
	elite.world = self
	add_child(elite)
	var angle = randf() * TAU
	var distance = 400.0
	var offset = Vector2(cos(angle), sin(angle)) * distance
	elite.global_position = player.global_position + offset

func enemy_died():
	enemies_killed += 1

func show_game_over():
	game_over = true
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_game_over(time_survived, enemies_killed)

func _draw():
	var grid_size := 128
	var limit := 5000
	for x in range(-limit, limit + grid_size, grid_size):
		draw_line(Vector2(x, -limit), Vector2(x, limit), Color(0.18, 0.25, 0.18), 2.0)
	for y in range(-limit, limit + grid_size, grid_size):
		draw_line(Vector2(-limit, y), Vector2(limit, y), Color(0.18, 0.25, 0.18), 2.0)
