class_name ChaosMinimap
extends Control

const MAP_EXTENT := 5550.0

var world: Node
var update_timer := 0.0


func bind_world(owner_world: Node) -> void:
	world = owner_world
	queue_redraw()


func _process(delta: float) -> void:
	update_timer -= delta
	if update_timer <= 0.0:
		update_timer = 0.12
		queue_redraw()


func _map_position(world_position: Vector2) -> Vector2:
	var usable := size - Vector2(18.0, 30.0)
	return Vector2(9.0, 21.0) + (world_position / (MAP_EXTENT * 2.0) + Vector2(0.5, 0.5)) * usable


func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 16.0), "MAPA · M", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("cbb2df"))
	var map_rect := Rect2(Vector2(9.0, 21.0), size - Vector2(18.0, 30.0))
	draw_rect(map_rect, Color(0.03, 0.015, 0.055, 0.76), true)
	draw_rect(map_rect, Color(0.55, 0.34, 0.72, 0.48), false, 1.0)
	draw_circle(_map_position(Vector2.ZERO), 2.5, Color(0.55, 0.35, 0.72, 0.55))
	if not is_instance_valid(world):
		return
	for landmark in get_tree().get_nodes_in_group("map_landmarks"):
		if is_instance_valid(landmark):
			var point := _map_position(landmark.global_position)
			draw_circle(point, 4.2, landmark.minimap_color())
			draw_arc(point, 6.5, 0.0, TAU, 12, Color(landmark.minimap_color(), 0.42), 1.0)
	if is_instance_valid(world.active_boss) and not world.active_boss.dead:
		draw_circle(_map_position(world.active_boss.global_position), 5.5, Color("ff4c61"))
	if is_instance_valid(world.rewards):
		for reward in world.rewards.get_children():
			if is_instance_valid(reward):
				draw_circle(_map_position(reward.global_position), 3.8, Color("ffd36b"))
	if is_instance_valid(world.player):
		var player_point := _map_position(world.player.global_position)
		draw_circle(player_point, 5.0, Color("f4f0ff"))
		draw_arc(player_point, 7.5, 0.0, TAU, 16, Color("9f6cff"), 1.5)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.012, 0.045, 0.88)
	style.border_color = Color(0.45, 0.28, 0.61, 0.68)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
