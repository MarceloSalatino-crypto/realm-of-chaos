extends RefCounted

const WEAPON_TEXTURES := {
	"chaos_bolt": preload("res://assets/generated/hero_anim_chaos_bolt.png"),
	"shadow_blades": preload("res://assets/generated/hero_anim_shadow_blades.png"),
	"soul_orbit": preload("res://assets/generated/hero_anim_soul_orbit.png"),
	"chaos_nova": preload("res://assets/generated/hero_anim_chaos_nova.png")
}

var player


func _init(owner_player) -> void:
	player = owner_player


func equip_weapon_visual(weapon_id: String) -> void:
	if not WEAPON_TEXTURES.has(weapon_id):
		return
	player.equipped_weapon_id = weapon_id
	player.sprite.texture = WEAPON_TEXTURES[weapon_id]
	player.sprite.hframes = 4
	player.sprite.vframes = 2
	player.sprite.frame_coords = Vector2i.ZERO


func apply_character_color() -> void:
	player.sprite.modulate = player.character_color


func update_invulnerability_flash() -> void:
	if player.invulnerability > 0.0:
		player.visual.modulate.a = 0.45 if int(player.invulnerability * 18.0) % 2 == 0 else 1.0
	else:
		player.visual.modulate.a = 1.0


func set_primary_attack_facing(direction: Vector2, weapon_id: String) -> void:
	if weapon_id != player.equipped_weapon_id or direction.length_squared() <= 0.0001:
		return
	var normalized_direction: Vector2 = direction.normalized()
	if absf(normalized_direction.x) < player.ATTACK_FACING_DEADZONE:
		return
	var requested_facing: float = signf(normalized_direction.x)
	if player.attack_facing_time > 0.0 and requested_facing != player.attack_facing_x:
		player.pending_attack_facing_x = requested_facing
		return
	player.attack_facing_x = requested_facing
	player.attack_facing_time = player.ATTACK_FACING_HOLD
	player.pending_attack_facing_x = 0.0
	player.sprite.flip_h = player.attack_facing_x < 0.0


func animate_character(delta: float, direction: Vector2, is_moving: bool, distance_moved := 0.0) -> void:
	player.attack_facing_time = maxf(0.0, player.attack_facing_time - delta)
	if player.attack_facing_time <= 0.0 and player.pending_attack_facing_x != 0.0:
		player.attack_facing_x = player.pending_attack_facing_x
		player.pending_attack_facing_x = 0.0
		player.attack_facing_time = player.ATTACK_FACING_HOLD
	player.attack_recoil = move_toward(player.attack_recoil, 0.0, delta * 4.0)
	player.attack_flash = move_toward(player.attack_flash, 0.0, delta * 8.5)
	player.hurt_recoil = move_toward(player.hurt_recoil, 0.0, delta * 6.0)
	var visual_facing_x: float = player.attack_facing_x if player.attack_facing_time > 0.0 else player.last_direction.x
	player.sprite.flip_h = visual_facing_x < 0.0
	if is_moving:
		var actual_speed: float = distance_moved / maxf(delta, 0.0001)
		var walk_fps: float = minf(actual_speed / player.WALK_FRAME_DISTANCE, player.WALK_MAX_FPS)
		player.walk_animation_clock += delta * walk_fps
	elif player.attack_recoil <= 0.0:
		player.walk_animation_clock = 0.0

	if player.attack_recoil > 0.0:
		var attack_progress: float = clampf(1.0 - player.attack_recoil, 0.0, 0.999)
		player.sprite.frame_coords = Vector2i(mini(3, int(attack_progress * 4.0)), 1)
	elif is_moving:
		player.sprite.frame_coords = Vector2i(int(floor(player.walk_animation_clock)) % 4, 0)
	else:
		player.sprite.frame_coords = Vector2i.ZERO

	var breathe: float = sin(player.motion_age * 2.35)
	var stride: float = sin(player.walk_animation_clock * TAU / 4.0)
	var hop: float = absf(stride) if is_moving else (breathe + 1.0) * 0.5
	var target_scale := Vector2(1.0, 1.0)
	var target_rotation := 0.0
	var target_position := Vector2.ZERO
	if is_moving:
		target_rotation = direction.x * 0.008
		target_position = Vector2(-visual_facing_x * player.attack_recoil * 1.5, -hop * 0.65)
	else:
		target_scale = Vector2(1.0 - breathe * 0.004, 1.0 + breathe * 0.006)
		target_rotation = breathe * 0.002
		target_position = Vector2(-visual_facing_x * player.attack_recoil * 1.5, -hop * 0.35)
	if player.hurt_recoil > 0.0:
		target_scale += Vector2(player.hurt_recoil * 0.035, -player.hurt_recoil * 0.035)
		target_rotation += sin(player.motion_age * 42.0) * player.hurt_recoil * 0.025

	var smoothing: float = 1.0 - exp(-delta * 15.0)
	player.visual.scale = player.visual.scale.lerp(target_scale, smoothing)
	player.visual.rotation = lerpf(player.visual.rotation, target_rotation, smoothing)
	player.visual.position = player.visual.position.lerp(target_position, smoothing)
	var shadow_scale := Vector2(1.0 + hop * 0.035, 1.0 - hop * 0.045)
	player.shadow.scale = player.shadow.scale.lerp(shadow_scale, 1.0 - exp(-delta * 10.0))
	player.shadow.color.a = lerpf(player.shadow.color.a, 0.40 - hop * 0.035, smoothing)
	if player.attack_flash > 0.0 or player.weapon_levels.soul_orbit > 0:
		player.queue_redraw()


func play_death_animation() -> void:
	if player.death_started:
		return
	player.death_started = true
	player.disabled = true
	player.velocity = Vector2.ZERO
	player.collision_shape.set_deferred("disabled", true)
	var tween: Tween = player.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(player.visual, "rotation", -0.46 if player.last_direction.x < 0.0 else 0.46, 0.48)
	tween.tween_property(player.visual, "position", Vector2(8.0 * signf(player.last_direction.x), 13.0), 0.48)
	tween.tween_property(player.visual, "scale", Vector2(1.12, 0.72), 0.34)
	tween.tween_property(player.visual, "modulate", Color(0.55, 0.30, 0.68, 0.0), 0.48)
	tween.tween_property(player.shadow, "scale", Vector2(1.35, 0.45), 0.48)
	tween.tween_property(player.shadow, "color", Color(0.01, 0.005, 0.02, 0.0), 0.48)
	tween.chain().tween_callback(func() -> void: player.died.emit())


func draw() -> void:
	var orbit_level: int = player.weapon_levels.soul_orbit
	if orbit_level > 0:
		var evolved := bool(player.evolved_weapons.soul_orbit)
		var radius: float = 122.0 + orbit_level * 8.0 if evolved else 72.0 + orbit_level * 8.0
		var blade_count: int = 6 + int(orbit_level / 2.0) if evolved else 2 + int(orbit_level / 2.0)
		if evolved:
			_draw_soul_devourer(blade_count, radius)
		else:
			_draw_base_soul_orbit(blade_count, radius)
	if player.attack_flash > 0.0:
		var direction: Vector2 = player.attack_direction.normalized()
		var side := direction.rotated(PI * 0.5)
		var muzzle: Vector2 = direction * 39.0 + Vector2(0.0, -9.0)
		var flash_size: float = 19.0 * player.attack_flash
		var flash_outline := PackedVector2Array([
			muzzle + direction * (flash_size + 3.0),
			muzzle + side * (flash_size * 0.48 + 2.0),
			muzzle - direction * (flash_size * 0.60 + 2.0),
			muzzle - side * (flash_size * 0.48 + 2.0),
		])
		var flash_fill := PackedVector2Array([
			muzzle + direction * flash_size,
			muzzle + side * flash_size * 0.34,
			muzzle - direction * flash_size * 0.44,
			muzzle - side * flash_size * 0.34,
		])
		player.draw_colored_polygon(flash_outline, Color(0.07, 0.03, 0.10, player.attack_flash * 0.94))
		player.draw_colored_polygon(flash_fill, Color(0.69, 0.30, 0.90, player.attack_flash))
		player.draw_line(
			muzzle - direction * 10.0,
			muzzle + direction * 17.0,
			Color(0.07, 0.03, 0.10, player.attack_flash * 0.94), 6.0
		)
		player.draw_line(
			muzzle - direction * 8.0,
			muzzle + direction * 15.0,
			Color(0.94, 0.76, 1.0, player.attack_flash), 2.5
		)


func _draw_base_soul_orbit(blade_count: int, radius: float) -> void:
	for index in range(blade_count):
		var position: Vector2 = Vector2.RIGHT.rotated(player.orbit_angle + TAU * index / blade_count) * radius
		var radial := position.normalized()
		var tangent := radial.rotated(PI * 0.5)
		var blade_outline := PackedVector2Array([
			position - tangent * 14.0 - radial * 5.0,
			position + tangent * 7.0 - radial * 7.0,
			position + tangent * 14.0,
			position + tangent * 7.0 + radial * 7.0,
			position - tangent * 14.0 + radial * 5.0,
			position - tangent * 8.0,
		])
		var blade_fill := PackedVector2Array([
			position - tangent * 10.5 - radial * 2.8,
			position + tangent * 5.5 - radial * 4.1,
			position + tangent * 10.5,
			position + tangent * 5.5 + radial * 4.1,
			position - tangent * 10.5 + radial * 2.8,
			position - tangent * 6.5,
		])
		var blade_color := Color("b96cff")
		player.draw_colored_polygon(blade_outline, Color("1b1022"))
		player.draw_colored_polygon(blade_fill, blade_color.darkened(0.18))
		player.draw_line(
			position - tangent * 5.0 - radial * 1.4,
			position + tangent * 6.5 - radial * 2.0,
			blade_color.lightened(0.40), 1.4
		)


func _draw_soul_devourer(blade_count: int, radius: float) -> void:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for index in range(blade_count):
		var position: Vector2 = Vector2.RIGHT.rotated(player.orbit_angle + TAU * index / blade_count) * radius
		var radial := position.normalized()
		var tangent := radial.rotated(PI * 0.5)
		_append_visual_polygon(vertices, colors, indices, PackedVector2Array([
			position - tangent * 17.0 - radial * 7.0,
			position + tangent * 8.0 - radial * 9.0,
			position + tangent * 18.0,
			position + tangent * 7.0 + radial * 9.0,
			position - tangent * 17.0 + radial * 7.0,
			position - tangent * 9.0,
		]), Color("160f20"))
		_append_visual_polygon(vertices, colors, indices, PackedVector2Array([
			position - tangent * 12.5 - radial * 3.5,
			position + tangent * 5.5 - radial * 5.0,
			position + tangent * 13.0,
			position + tangent * 5.5 + radial * 5.0,
			position - tangent * 12.5 + radial * 3.5,
			position - tangent * 7.0,
		]), Color("72449a"))
		_append_visual_polygon(vertices, colors, indices, PackedVector2Array([
			position - tangent * 6.0 - radial * 1.8,
			position + tangent * 8.8,
			position - tangent * 2.0 + radial * 1.8,
		]), Color("efc86a"))
	var charges := 0
	var release_visual_time := 0.0
	if player.combat:
		charges = int(player.combat.soul_essence_charges)
		release_visual_time = float(player.combat.soul_devourer_release_visual_time)
	for index in range(charges):
		var direction := Vector2.RIGHT.rotated(-player.orbit_angle * 0.62 + TAU * index / 6.0)
		var center := direction * (35.0 + float(index % 2) * 5.0)
		var side := direction.rotated(PI * 0.5)
		_append_visual_polygon(vertices, colors, indices, PackedVector2Array([
			center - side * 3.5 - direction * 6.0,
			center + direction * 8.0,
			center + side * 3.5 - direction * 6.0,
		]), Color("d9a853" if index % 2 == 0 else "9b61c3"))
	if release_visual_time > 0.0:
		var intensity := clampf(release_visual_time / 0.44, 0.0, 1.0)
		var direction := Vector2.RIGHT.rotated(player.orbit_angle * 0.18 + 0.24)
		var side := direction.rotated(PI * 0.5)
		var opening := 8.0 + intensity * 7.0
		var reach := 27.0 + intensity * 10.0
		_append_visual_polygon(vertices, colors, indices, PackedVector2Array([
			-direction * 7.0 + side * (opening + 4.0),
			direction * 6.0 + side * (opening + 8.0),
			direction * reach + side * 5.0,
			direction * (reach + 7.0) - side * 1.0,
			direction * 4.0 + side * 4.0,
		]), Color(0.91, 0.66, 0.28, intensity))
		_append_visual_polygon(vertices, colors, indices, PackedVector2Array([
			-direction * 6.0 - side * (opening + 3.0),
			direction * 3.0 - side * (opening + 7.0),
			direction * (reach - 4.0) - side * 7.0,
			direction * (reach + 5.0) - side * 2.0,
			direction * 2.0 - side * 4.0,
		]), Color(0.58, 0.34, 0.76, intensity))
	if not vertices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(player.get_canvas_item(), indices, vertices, colors)


func _append_visual_polygon(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	polygon: PackedVector2Array, color: Color
) -> void:
	var polygon_indices := Geometry2D.triangulate_polygon(polygon)
	var base := vertices.size()
	for point in polygon:
		vertices.append(point)
		colors.append(color)
	for polygon_index in polygon_indices:
		indices.append(base + polygon_index)
