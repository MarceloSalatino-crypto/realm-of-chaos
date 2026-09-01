extends SceneTree

const LAB_SCENE := preload("res://scenes/biome_vertical_slice_lab.tscn")
const EXPECTED_TREE_ANCHORS := 26
const EXPECTED_STONES := 10
const EXPECTED_GROVE_LOBES := 55
const EXPECTED_LANDMARK_SHAPES := 17
const EXPECTED_LANDMARK_PROFILE_COUNTS := {
	"altar": 5,
	"obelisk": 4,
	"tree": 5,
	"portal": 3,
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FOREST ENVIRONMENT COLLISION: " + message)


func _collision_shapes(node: Node) -> Array[Node]:
	return node.find_children("*", "CollisionShape2D", true, false)


func _player_fits_at(world: Node, world_position: Vector2) -> bool:
	var capsule := CapsuleShape2D.new()
	capsule.radius = 16.0
	capsule.height = 42.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = capsule
	query.transform = Transform2D(0.0, world_position)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [world.player.get_rid()]
	return world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _run() -> void:
	var lab = LAB_SCENE.instantiate()
	root.add_child(lab)
	await process_frame
	await lab.load_slice("forest_production")
	var world = lab.current_world
	world.audio.enabled = false
	world.set_process(false)
	await physics_frame

	var collision_summary: Dictionary = world.environment_builder.forest_collision_composer.summary()
	_check(bool(collision_summary.active), "o perfil físico do Bosque não ficou ativo")
	_check(int(collision_summary.grove_lobes) == EXPECTED_GROVE_LOBES, "as 26 composições não geraram 55 massas sólidas calibradas")
	_check(int(collision_summary.dense_lobes) == 9, "as três florestas densas não receberam três massas cada")
	_check(int(collision_summary.landmark_shapes) == EXPECTED_LANDMARK_SHAPES, "os quatro landmarks não receberam os 17 sólidos específicos")

	var tree_anchor_count := 0
	var stone_count := 0
	var grove_lobe_count := 0
	for body in world.obstacles.get_children():
		_check(body is StaticBody2D, "o container físico contém nó que não é StaticBody2D")
		_check(body.collision_layer == 1 and body.collision_mask == 1, "obstáculo saiu da camada física do mundo")
		_check(body.is_in_group("physical_obstacles"), "obstáculo não participa do índice espacial")
		var kind := str(body.get_meta("environment_obstacle_kind", ""))
		if kind == "tree":
			tree_anchor_count += 1
			_check(_collision_shapes(body).is_empty(), "âncora antiga de árvore ainda cria colisão invisível duplicada")
		elif kind == "stone":
			stone_count += 1
			var stone_shapes := _collision_shapes(body)
			_check(stone_shapes.size() == 1 and stone_shapes[0].shape is CircleShape2D, "pedra perdeu o colisor circular da base")
		elif body.is_in_group("forest_collision_lobes"):
			grove_lobe_count += 1
			var grove_shapes := _collision_shapes(body)
			_check(grove_shapes.size() == 1 and grove_shapes[0].shape is CapsuleShape2D, "massa florestal não usa uma cápsula simples")
			_check(world.environment_builder.obstacles_near(body.global_position, 1.0).has(body), "grade espacial não encontra a massa florestal")
	_check(tree_anchor_count == EXPECTED_TREE_ANCHORS, "as 26 âncoras determinísticas de árvore mudaram")
	_check(stone_count == EXPECTED_STONES, "as 10 pedras físicas mudaram")
	_check(grove_lobe_count == EXPECTED_GROVE_LOBES, "o container físico perdeu massas florestais")
	_check(world.obstacles.get_child_count() == EXPECTED_TREE_ANCHORS + EXPECTED_STONES + EXPECTED_GROVE_LOBES, "a população física do Bosque é inesperada")

	for landmark in world.landmarks.get_children():
		var kind := str(landmark.landmark_kind)
		var expected_shapes := int(EXPECTED_LANDMARK_PROFILE_COUNTS[kind])
		_check(_collision_shapes(landmark).size() == expected_shapes, "perfil sólido incorreto no landmark " + kind)
		_check(landmark.contact_activation_enabled, "landmark do Bosque ainda usa ativação por distância: " + kind)
		_check(_player_fits_at(world, landmark.global_position + Vector2(0.0, 92.0)), "abordagem/interação foi bloqueada no landmark " + kind)
		if kind == "portal":
			_check(_player_fits_at(world, landmark.global_position + Vector2(0.0, -120.0)), "entrada central do portal foi fechada")
			_check(not _player_fits_at(world, landmark.global_position + Vector2(-71.0, -100.0)), "pilar esquerdo do portal ficou atravessável")
			_check(not _player_fits_at(world, landmark.global_position + Vector2(71.0, -100.0)), "pilar direito do portal ficou atravessável")
			_check(not _player_fits_at(world, landmark.global_position + Vector2(0.0, -207.0)), "arco superior do portal ficou atravessável")
		elif kind == "altar":
			_check(not _player_fits_at(world, landmark.global_position + Vector2(0.0, -91.0)), "mesa sólida do altar ficou atravessável")
			_check(not _player_fits_at(world, landmark.global_position + Vector2(65.0, -157.0)), "massa principal do altar ficou atravessável")
		elif kind == "obelisk":
			_check(not _player_fits_at(world, landmark.global_position + Vector2(0.0, -150.0)), "corpo do obelisco ficou atravessável")
		elif kind == "tree":
			_check(not _player_fits_at(world, landmark.global_position + Vector2(0.0, -150.0)), "tronco do santuário ficou atravessável")

	var composer = world.environment_builder.terrain_composer
	_check(_player_fits_at(world, composer.capture_point("OPEN_ARENA")), "arena aberta recebeu colisão")
	var grove_layout: Array[Dictionary] = composer.grove_visual_layout()
	for grove_index in range(grove_layout.size()):
		var descriptor: Dictionary = grove_layout[grove_index]
		if bool(descriptor.dense):
			continue
		var records: Array = collision_summary.records.filter(func(record: Dictionary) -> bool:
			return int(record.grove_index) == grove_index
		)
		_check(records.size() == 2, "bosque individual não preservou duas massas com vão visual")
		if records.size() == 2:
			var first := records[0] as Dictionary
			var second := records[1] as Dictionary
			var approximate_gap := Vector2(first.center).distance_to(Vector2(second.center)) - float(first.height) * 0.5 - float(second.height) * 0.5
			_check(approximate_gap >= 32.0, "abertura visual entre troncos ficou estreita demais para o jogador")

	_check(lab.toggle_collision_debug(), "F2 não liga a visualização temporária")
	var overlay = world.get_node_or_null("EnvironmentCollisionDebugOverlay")
	_check(is_instance_valid(overlay) and overlay.visible, "a visualização F2 não apareceu sobre o world.tscn real")
	_check(overlay.displayed_shape_count() >= 70, "a visualização F2 não lista todos os sólidos ambientais")
	_check(not lab.toggle_collision_debug() and not overlay.visible, "F2 não desliga a visualização")

	lab.queue_free()
	for _frame in range(5):
		await process_frame
	if failures.is_empty():
		print("FOREST ENVIRONMENT COLLISION OK: 55 massas de floresta, 10 pedras, 17 sólidos de landmarks e F2 validados")
	quit(0 if failures.is_empty() else 1)
