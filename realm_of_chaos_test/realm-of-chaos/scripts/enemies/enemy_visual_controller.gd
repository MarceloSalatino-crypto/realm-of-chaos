extends RefCounted

const LOCOMOTION_MIN_SPEED := 3.0
const LOCOMOTION_MAX_FPS := 14.0
const OFFSCREEN_VISUAL_INTERVAL := 0.12
const ENEMY_ANIMATIONS := {
	"prowler": preload("res://assets/generated/enemy_anim_prowler.png"),
	"assassin": preload("res://assets/generated/enemy_anim_assassin.png"),
	"bat": preload("res://assets/generated/enemy_anim_bat.png"),
	"swarm": preload("res://assets/generated/enemy_anim_swarm.png"),
	"mage": preload("res://assets/generated/enemy_anim_mage.png"),
	"necromancer": preload("res://assets/generated/enemy_anim_necromancer.png"),
	"archer": preload("res://assets/generated/enemy_anim_archer.png"),
	"brute": preload("res://assets/generated/enemy_anim_brute.png"),
	"guardian": preload("res://assets/generated/enemy_anim_guardian.png"),
	"ember": preload("res://assets/generated/enemy_anim_ember.png"),
	"bomber": preload("res://assets/generated/enemy_anim_bomber.png"),
	"void_knight": preload("res://assets/generated/enemy_anim_void_knight.png"),
	"ossuary_colossus": preload("res://assets/generated/boss_ossuary_colossus.png"),
	"glacial_archon": preload("res://assets/generated/boss_glacial_archon.png"),
	"infernal_reaper": preload("res://assets/generated/boss_infernal_reaper.png"),
	"void_titan": preload("res://assets/generated/boss_void_titan.png"),
	"chaos_sovereign": preload("res://assets/generated/boss_chaos_sovereign.png")
}

var enemy


func _init(owner_enemy) -> void:
	enemy = owner_enemy


func configure_sprite(data: Dictionary) -> void:
	enemy.sprite.texture = ENEMY_ANIMATIONS.get(enemy.definition_animation, ENEMY_ANIMATIONS.prowler)
	enemy.sprite.hframes = 4
	enemy.sprite.vframes = 1
	enemy.sprite.frame = 0
	enemy.base_visual_scale = float(data.visual_scale) * (1.0 if enemy.boss else 0.72) * (1.13 if enemy.elite else 1.0)
	enemy.sprite.scale = Vector2.ONE * enemy.base_visual_scale
	enemy.base_modulate = Color("d8b7ff") if enemy.elite and not enemy.boss else Color.WHITE
	if enemy.enemy_type != enemy.definition_animation and not enemy.boss:
		enemy.base_modulate = enemy.base_modulate.lerp(enemy.definition_color, 0.26)
	enemy.sprite.modulate = enemy.base_modulate


func configure_health_bar() -> void:
	enemy.health_bar.max_value = enemy.max_hp
	enemy.health_bar.value = enemy.hp
	enemy.health_bar.visible = enemy.elite or enemy.boss
	if enemy.boss:
		enemy.health_bar.offset_left = -enemy.hit_radius
		enemy.health_bar.offset_right = enemy.hit_radius
		enemy.health_bar.offset_top = -enemy.hit_radius - 58.0
		enemy.health_bar.offset_bottom = enemy.health_bar.offset_top + 8.0
	var style := StyleBoxFlat.new()
	style.bg_color = enemy.definition_color
	style.set_corner_radius_all(3)
	enemy.health_bar.add_theme_stylebox_override("fill", style)


func update_health_bar(show := false) -> void:
	enemy.health_bar.value = enemy.hp
	if show:
		enemy.health_bar.visible = true


func hide_health_bar() -> void:
	enemy.health_bar.hide()


func update_visual_animation(delta: float, distance_moved: float) -> void:
	enemy.visual_lod_elapsed += delta
	enemy.visual_lod_distance += distance_moved
	var in_visual_bounds: bool = enemy.boss or not enemy.world or not enemy.world.has_method("is_position_in_visual_bounds") or bool(enemy.world.is_position_in_visual_bounds(enemy.global_position))
	if not in_visual_bounds and enemy.visual_lod_elapsed < OFFSCREEN_VISUAL_INTERVAL:
		return
	animate_sprite(enemy.visual_lod_elapsed, enemy.visual_lod_distance, in_visual_bounds)
	enemy.visual_lod_elapsed = 0.0
	enemy.visual_lod_distance = 0.0


func animate_sprite(delta: float, distance_moved := -1.0, allow_custom_redraw := true) -> void:
	enemy.sprite.flip_h = enemy.velocity.x < -2.0
	enemy.attack_pulse = move_toward(enemy.attack_pulse, 0.0, delta * 2.7)
	enemy.cast_pulse = move_toward(enemy.cast_pulse, 0.0, delta * 2.4)
	enemy.hit_squash = move_toward(enemy.hit_squash, 0.0, delta * 7.5)
	var active_attack := maxf(enemy.attack_pulse, enemy.cast_pulse)
	if enemy.telegraph_time > 0.0:
		enemy.sprite.frame = 2
	elif active_attack > 0.0:
		enemy.sprite.frame = 2 if active_attack > 0.48 else 3
	else:
		var nominal_speed := maxf(enemy.definition_speed, 1.0)
		var actual_speed := nominal_speed if distance_moved < 0.0 else distance_moved / maxf(delta, 0.0001)
		if actual_speed > LOCOMOTION_MIN_SPEED:
			var frame_distance := nominal_speed / locomotion_fps()
			var current_locomotion_fps := minf(actual_speed / frame_distance, LOCOMOTION_MAX_FPS)
			enemy.animation_clock += delta * current_locomotion_fps
			enemy.sprite.frame = int(floor(enemy.animation_clock)) % 2
		else:
			enemy.animation_clock = 0.0
			enemy.sprite.frame = 0

	var lift := 0.0
	var target_rotation := 0.0
	match enemy.behavior:
		"swarm_flight":
			lift = sin(enemy.movement_age * 5.2) * 3.5
			target_rotation = sin(enemy.movement_age * 5.2) * 0.025
		"ranged", "archer", "necromancer", "glacial":
			lift = sin(enemy.movement_age * 2.35) * 4.0
		"ember", "bomber":
			lift = sin(enemy.movement_age * 3.0) * 5.5
			target_rotation = sin(enemy.movement_age * 2.1) * 0.035
		"sovereign":
			lift = sin(enemy.movement_age * 1.9) * 2.0
	var target_scale: Vector2 = Vector2.ONE * enemy.base_visual_scale
	if enemy.hit_squash > 0.0:
		target_scale *= Vector2(1.0 + enemy.hit_squash * 0.07, 1.0 - enemy.hit_squash * 0.06)
	var smoothing := 1.0 - exp(-delta * 14.0)
	enemy.sprite.scale = enemy.sprite.scale.lerp(target_scale, smoothing)
	enemy.sprite.position = enemy.sprite.position.lerp(Vector2(0.0, -16.0 + lift), smoothing)
	enemy.sprite.rotation = lerpf(enemy.sprite.rotation, target_rotation, smoothing)
	var altitude := absf(lift)
	enemy.shadow.scale = enemy.shadow.scale.lerp(Vector2(1.0 + altitude * 0.012, 1.0 - altitude * 0.018), 1.0 - exp(-delta * 9.0))
	enemy.shadow.color.a = lerpf(enemy.shadow.color.a, 0.48 - altitude * 0.016, smoothing)
	if allow_custom_redraw and (enemy.boss or enemy.behavior in ["ember", "bomber"] or enemy.telegraph_time > 0.0):
		enemy.queue_redraw()


func locomotion_fps() -> float:
	match enemy.behavior:
		"swarm_flight", "assassin", "reaper": return 9.5
		"ranged", "archer", "necromancer", "glacial": return 5.5
		"brute", "guardian", "ossuary", "titan", "sovereign": return 5.5
		_: return 7.5


func play_damage_flash(critical: bool) -> void:
	var flash_color := Color("fff2a8") if critical else Color.WHITE
	enemy.sprite.modulate = flash_color * 1.8
	var tween: Tween = enemy.create_tween()
	tween.tween_property(enemy.sprite, "modulate", enemy.base_modulate, 0.12)


func play_death_animation() -> void:
	var tween: Tween = enemy.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(enemy.sprite, "scale", Vector2.ONE * enemy.base_visual_scale * 0.86, 0.26)
	tween.tween_property(enemy.sprite, "rotation", enemy.sprite.rotation + (0.18 if randf() > 0.5 else -0.18), 0.26)
	tween.tween_property(enemy.sprite, "modulate", Color(0.42, 0.16, 0.55, 0.0), 0.28)
	tween.tween_property(enemy.shadow, "scale", Vector2(1.25, 0.45), 0.28)
	tween.tween_property(enemy.shadow, "color", Color(0.01, 0.005, 0.02, 0.0), 0.28)
	tween.chain().tween_callback(enemy.queue_free)


func boss_aura_colors() -> Array[Color]:
	var fill: Color = enemy.definition_color
	fill.a = 0.09
	var edge: Color = enemy.definition_color.lightened(0.30)
	edge.a = 0.42
	return [fill, edge]


func _ring_points(center: Vector2, radius: float, point_count: int, phase := 0.0, inset := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := phase + TAU * float(index) / float(point_count)
		var point_radius := radius - inset if index % 2 == 0 else radius
		points.append(center + Vector2.RIGHT.rotated(angle) * point_radius)
	return points


func _use_reduced_detail() -> bool:
	if not is_instance_valid(enemy.world):
		return false
	var enemies: Node = enemy.world.get_node_or_null("Enemies")
	var effects: Node = enemy.world.get_node_or_null("Effects")
	var enemy_projectiles: Node = enemy.world.get_node_or_null("EnemyProjectiles")
	if not is_instance_valid(enemies) or not is_instance_valid(effects) or not is_instance_valid(enemy_projectiles):
		return false
	return (
		enemies.get_child_count() >= enemy.world.ENEMY_HIGH_VISUAL_LOAD
		or effects.get_child_count() >= enemy.world.EFFECT_HIGH_LOAD
		or enemy_projectiles.get_child_count() >= 96
	)


func draw() -> void:
	var reduced_detail := _use_reduced_detail()
	if enemy.behavior in ["ember", "bomber"]:
		var ember_alpha := 0.10 + (sin(enemy.movement_age * 3.2) + 1.0) * 0.035
		var ember_center := Vector2(0.0, -12.0)
		var ember_radius: float = enemy.hit_radius * 1.30
		var ember_points := _ring_points(ember_center, ember_radius, 12, enemy.movement_age * 0.08, ember_radius * 0.10)
		enemy.draw_colored_polygon(ember_points, Color(0.82, 0.08, 0.055, ember_alpha * 0.62))
	if enemy.telegraph_time > 0.0:
		var progress := 1.0 - clampf(enemy.telegraph_time / maxf(enemy.telegraph_duration, 0.01), 0.0, 1.0)
		var radius: float = enemy._special_radius()
		if enemy.pending_special == "ward":
			var ward_points := _ring_points(Vector2.ZERO, radius, 16, enemy.movement_age * 0.08, radius * 0.045)
			enemy.draw_colored_polygon(ward_points, Color(0.88, 0.70, 0.36, 0.045 + progress * 0.055))
		enemy.draw_circle(Vector2.ZERO, radius, Color(0.55, 0.035, 0.05, 0.025 + progress * 0.025))
		enemy.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.08, 0.018, 0.025, 0.90), 7.0)
		enemy.draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, Color(1.0, 0.25, 0.20, 0.92), 4.0)
		var marker_count := 4 if reduced_detail else 8
		for index in range(marker_count):
			var marker_angle := TAU * float(index) / float(marker_count)
			var marker_start := Vector2.RIGHT.rotated(marker_angle) * (radius - 8.0)
			var marker_end := Vector2.RIGHT.rotated(marker_angle) * (radius + 2.0)
			enemy.draw_line(marker_start, marker_end, Color(0.08, 0.018, 0.025, 0.88), 5.0)
			enemy.draw_line(marker_start, marker_end, Color(1.0, 0.40, 0.28, 0.72), 2.0)
	if enemy.boss:
		var aura_radius: float = enemy.hit_radius * (1.40 + sin(enemy.movement_age * 1.75) * 0.06)
		var aura_colors := boss_aura_colors()
		var aura_center := Vector2(0.0, -5.0)
		var aura_point_count := 12 if reduced_detail else 16
		var aura_points := _ring_points(aura_center, aura_radius, aura_point_count, PI / float(aura_point_count), aura_radius * 0.055)
		enemy.draw_colored_polygon(aura_points, aura_colors[0])
