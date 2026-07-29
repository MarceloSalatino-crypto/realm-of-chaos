extends SceneTree

const ENEMY_TYPES := [
	"prowler", "assassin", "bat", "swarm", "mage", "necromancer",
	"archer", "brute", "guardian", "ember", "bomber"
]
const EXPECTED_ANIMATIONS := {
	"prowler": "prowler",
	"assassin": "assassin",
	"bat": "bat",
	"swarm": "swarm",
	"mage": "mage",
	"necromancer": "necromancer",
	"archer": "archer",
	"brute": "brute",
	"guardian": "guardian",
	"ember": "ember",
	"bomber": "bomber"
}

const BOSS_TYPES := [
	"void_knight", "ossuary_colossus", "glacial_archon",
	"infernal_reaper", "void_titan", "chaos_sovereign"
]
const EXPECTED_BOSS_ANIMATIONS := {
	"void_knight": "void_knight", "ossuary_colossus": "ossuary_colossus",
	"glacial_archon": "glacial_archon", "infernal_reaper": "infernal_reaper",
	"void_titan": "void_titan", "chaos_sovereign": "chaos_sovereign"
}

class VisualBoundsWorld:
	extends Node

	var in_bounds := false

	func is_position_in_visual_bounds(_position: Vector2) -> bool:
		return in_bounds


var failures: Array[String] = []
var spawned_enemies: Array[Node] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ENEMY VISUAL CONTROLLER: " + message)


func _spawn_enemy(kind: String, elite := false) -> Node:
	var enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
	enemy.setup(kind, 1.0, elite)
	root.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	spawned_enemies.append(enemy)
	return enemy


func _run() -> void:
	var prowler = _spawn_enemy("prowler")
	var elite = _spawn_enemy("prowler", true)
	var boss = _spawn_enemy("ossuary_colossus")
	for method in ["_apply_definition", "_update_visual_animation", "_animate_sprite", "_locomotion_fps", "_draw"]:
		_check(prowler.has_method(method), "API visual ausente: " + method)
	_check(prowler.sprite.texture != null and prowler.sprite.hframes == 4 and prowler.sprite.vframes == 1, "folha visual comum configurada incorretamente")
	_check(prowler.sprite.frame == 0 and prowler.sprite.scale.is_equal_approx(Vector2.ONE * prowler.base_visual_scale), "pose ou escala inicial comum mudou")
	_check(prowler.collision_shape.shape is CircleShape2D and is_equal_approx(prowler.collision_shape.shape.radius, prowler.hit_radius), "colisao deixou de acompanhar o raio visual")
	_check(not prowler.health_bar.visible and is_equal_approx(prowler.health_bar.max_value, prowler.max_hp), "barra do inimigo comum mudou")
	_check(elite.health_bar.visible and elite.base_modulate.is_equal_approx(Color("d8b7ff")), "marcacao visual de elite mudou")
	_check(boss.health_bar.visible and is_equal_approx(boss.health_bar.offset_left, -boss.hit_radius), "barra de chefe perdeu o dimensionamento")

	var boss_texture_paths: Dictionary = {}
	for kind in BOSS_TYPES:
		var mapped_boss = _spawn_enemy(kind)
		var expected_animation: String = EXPECTED_BOSS_ANIMATIONS[kind]
		var expected_texture_path := "res://assets/generated/%s.png" % (
			"enemy_anim_void_knight" if kind == "void_knight" else "boss_" + expected_animation
		)
		_check(mapped_boss.boss, "%s deixou de ser chefe" % kind)
		_check(mapped_boss.definition_animation == expected_animation, "ID visual de chefe incorreto para %s" % kind)
		_check(
			mapped_boss.sprite.texture.resource_path == expected_texture_path,
			"%s caiu em textura incorreta: %s" % [kind, mapped_boss.sprite.texture.resource_path]
		)
		_check(
			mapped_boss.sprite.hframes == 4 and mapped_boss.sprite.vframes == 1,
			"grade visual de %s deixou de ser 4x1" % kind
		)
		_check(not boss_texture_paths.has(expected_texture_path), "%s compartilhou folha de chefe" % kind)
		boss_texture_paths[expected_texture_path] = kind
		var aura_colors: Array[Color] = mapped_boss.visual_controller.boss_aura_colors()
		var expected_fill: Color = mapped_boss.definition_color
		expected_fill.a = 0.09
		var expected_edge: Color = mapped_boss.definition_color.lightened(0.30)
		expected_edge.a = 0.42
		_check(aura_colors[0].is_equal_approx(expected_fill), "aura interna de %s nao herdou sua cor" % kind)
		_check(aura_colors[1].is_equal_approx(expected_edge), "contorno da aura de %s nao herdou sua cor" % kind)
	_check(boss_texture_paths.size() == 6, "as seis folhas de chefe nao ficaram unicas")

	var unique_texture_paths: Dictionary = {}
	for kind in ENEMY_TYPES:
		var mapped_enemy = _spawn_enemy(kind)
		var expected_animation: String = EXPECTED_ANIMATIONS[kind]
		var expected_texture_path := "res://assets/generated/enemy_anim_%s.png" % expected_animation
		_check(mapped_enemy.definition_animation == expected_animation, "ID visual incorreto para %s" % kind)
		_check(
			mapped_enemy.sprite.texture.resource_path == expected_texture_path,
			"%s caiu em textura incorreta: %s" % [kind, mapped_enemy.sprite.texture.resource_path]
		)
		_check(
			mapped_enemy.sprite.hframes == 4 and mapped_enemy.sprite.vframes == 1,
			"grade visual de %s deixou de ser 4x1" % kind
		)
		_check(
			not unique_texture_paths.has(expected_texture_path),
			"%s compartilhou textura com %s" % [kind, unique_texture_paths.get(expected_texture_path, "outro tipo")]
		)
		unique_texture_paths[expected_texture_path] = kind
	_check(unique_texture_paths.size() == 11, "os onze inimigos comuns nao terminaram com texturas unicas")

	var smoothing := 1.0 - exp(-0.20 * 14.0)
	var motion_profiles := [
		{"kinds": ["bat", "swarm"], "age": PI * 0.5 / 5.2, "lift": 3.5, "rotation": 0.025},
		{"kinds": ["mage", "necromancer", "archer"], "age": PI * 0.5 / 2.35, "lift": 4.0, "rotation": 0.0},
		{
			"kinds": ["ember", "bomber"],
			"age": PI * 0.5 / 3.0,
			"lift": 5.5,
			"rotation": sin((PI * 0.5 / 3.0) * 2.1) * 0.035
		}
	]
	for profile in motion_profiles:
		for kind in profile.kinds:
			var profile_enemy = _spawn_enemy(kind)
			profile_enemy.movement_age = float(profile.age)
			profile_enemy.sprite.position = Vector2.ZERO
			profile_enemy.sprite.rotation = 0.0
			profile_enemy.velocity = Vector2.ZERO
			profile_enemy.hit_squash = 0.0
			profile_enemy._animate_sprite(0.20, 0.0)
			var expected_y: float = (-16.0 + float(profile.lift)) * smoothing
			var expected_rotation: float = float(profile.rotation) * smoothing
			_check(
				is_equal_approx(profile_enemy.sprite.position.y, expected_y),
				"flutuacao por comportamento mudou para %s" % kind
			)
			_check(
				is_equal_approx(profile_enemy.sprite.rotation, expected_rotation),
				"balanco por comportamento mudou para %s" % kind
			)

	for kind in ["prowler", "assassin", "brute", "guardian"]:
		var grounded_enemy = _spawn_enemy(kind)
		grounded_enemy.movement_age = 1.0
		grounded_enemy.sprite.position = Vector2.ZERO
		grounded_enemy.sprite.rotation = 0.0
		grounded_enemy.velocity = Vector2.ZERO
		grounded_enemy._animate_sprite(0.20, 0.0)
		_check(
			is_equal_approx(grounded_enemy.sprite.position.y, -16.0 * smoothing),
			"%s ganhou flutuacao indevida" % kind
		)
		_check(is_zero_approx(grounded_enemy.sprite.rotation), "%s ganhou balanco indevido" % kind)

	var bat = _spawn_enemy("bat")
	bat.velocity = Vector2(-100.0, 0.0)
	bat.animation_clock = 0.0
	bat.attack_pulse = 0.0
	bat.cast_pulse = 0.0
	bat.telegraph_time = 0.0
	bat._animate_sprite(0.15)
	_check(bat.sprite.flip_h and bat.sprite.frame == 1, "locomocao ou flip do morcego mudou")
	_check(is_equal_approx(bat._locomotion_fps(), 9.5), "cadencia rapida mudou")
	bat.velocity = Vector2.ZERO
	bat._animate_sprite(0.05, 0.0)
	_check(bat.sprite.frame == 0 and is_zero_approx(bat.animation_clock), "animacao nao para junto com o inimigo")

	prowler.attack_pulse = 1.0
	prowler.cast_pulse = 0.0
	prowler.telegraph_time = 0.0
	prowler._animate_sprite(0.01, 0.0)
	_check(prowler.sprite.frame == 2, "quadro forte de ataque mudou")
	prowler.attack_pulse = 0.0
	prowler.cast_pulse = 0.30
	prowler._animate_sprite(0.01, 0.0)
	_check(prowler.sprite.frame == 3, "quadro final de ataque mudou")
	prowler.telegraph_time = 0.5
	prowler._animate_sprite(0.01, 0.0)
	_check(prowler.sprite.frame == 2, "telegrafia deixou de priorizar a pose de ataque")

	bat.movement_age = PI * 0.5 / 5.2
	bat.sprite.position = Vector2.ZERO
	bat.hit_squash = 1.0
	bat._animate_sprite(0.05, 0.0)
	_check(bat.sprite.position.y < 0.0 and bat.sprite.scale.x > bat.sprite.scale.y, "balanco ou squash visual mudou")
	_check(bat.shadow.color.a < 0.50, "sombra deixou de acompanhar a altura")

	var bounds_world := VisualBoundsWorld.new()
	root.add_child(bounds_world)
	var lod_enemy = _spawn_enemy("prowler")
	lod_enemy.world = bounds_world
	lod_enemy.sprite.frame = 3
	lod_enemy.animation_clock = 0.0
	lod_enemy._update_visual_animation(0.05, 3.0)
	_check(lod_enemy.sprite.frame == 3 and is_equal_approx(lod_enemy.visual_lod_elapsed, 0.05), "LOD fora da tela atualizou cedo demais")
	lod_enemy._update_visual_animation(0.08, 5.0)
	_check(lod_enemy.sprite.frame != 3 and is_zero_approx(lod_enemy.visual_lod_elapsed), "LOD fora da tela nao atualizou no intervalo")
	bounds_world.in_bounds = true
	lod_enemy.sprite.frame = 3
	lod_enemy._update_visual_animation(0.01, 0.0)
	_check(lod_enemy.sprite.frame == 0 and is_zero_approx(lod_enemy.visual_lod_elapsed), "inimigo visivel nao atualizou imediatamente")

	var draw_count := [0]
	elite.draw.connect(func() -> void: draw_count[0] += 1)
	elite.queue_redraw()
	await process_frame
	await process_frame
	_check(draw_count[0] > 0, "desenho customizado nao foi solicitado")

	var damage_target = _spawn_enemy("prowler")
	damage_target.take_damage(1.0, Vector2.ZERO, true)
	_check(damage_target.health_bar.visible and damage_target.sprite.modulate.r > 1.0, "flash critico ou barra de dano mudou")
	await create_timer(0.25).timeout
	_check(damage_target.sprite.modulate.is_equal_approx(damage_target.base_modulate), "flash de dano nao retornou a cor base")

	var dying = _spawn_enemy("prowler")
	dying._die()
	await process_frame
	_check(dying.dead and not dying.health_bar.visible and dying.collision_shape.disabled, "estado visual imediato da morte mudou")
	await create_timer(0.35).timeout
	_check(not is_instance_valid(dying), "animacao de morte nao liberou o inimigo no tempo esperado")

	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	bounds_world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY VISUAL CONTROLLER OK: 11 comuns, 6 chefes, auras tematicas, frames, LOD, dano e morte validados")
	quit(0 if failures.is_empty() else 1)
