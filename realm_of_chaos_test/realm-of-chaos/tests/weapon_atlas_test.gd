extends SceneTree

const ATLAS_PATH := "res://assets/generated/weapon_atlas_v1.png"
const WeaponFlashScript = preload("res://scripts/weapon_flash.gd")
const HomingEyeScript = preload("res://scripts/homing_eye.gd")

const CELL_WIDTH := 397
const CELL_HEIGHT := 793
const EXPECTED_SIZE := Vector2i(1985, 793)
const SAFE_MARGIN := 12
const FRAME_NAMES := [
	"blood_scythe",
	"forbidden_grimoire",
	"rune_hammer",
	"storm_relic",
	"swarm_idol",
]
const EXPECTED_BOUNDS := [
	Rect2i(40, 131, 317, 530),
	Rect2i(20, 187, 356, 419),
	Rect2i(23, 153, 350, 487),
	Rect2i(43, 129, 311, 535),
	Rect2i(23, 166, 350, 461),
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("WEAPON ATLAS: " + message)


func _visible_bounds(image: Image, frame_index: int) -> Rect2i:
	var start_x := frame_index * CELL_WIDTH
	var min_x := CELL_WIDTH
	var min_y := CELL_HEIGHT
	var max_x := -1
	var max_y := -1
	for y in range(CELL_HEIGHT):
		for local_x in range(CELL_WIDTH):
			if image.get_pixel(start_x + local_x, y).a <= 0.10:
				continue
			min_x = mini(min_x, local_x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, local_x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _color_signature(image: Image, frame_index: int) -> Dictionary:
	var start_x := frame_index * CELL_WIDTH
	var signature := {
		"visible": 0,
		"red": 0,
		"purple": 0,
		"gold": 0,
		"cyan": 0,
	}
	for y in range(CELL_HEIGHT):
		for local_x in range(CELL_WIDTH):
			var color := image.get_pixel(start_x + local_x, y)
			if color.a <= 0.10:
				continue
			signature.visible += 1
			if color.r > 0.38 and color.r > color.g * 1.45 and color.r > color.b * 1.22:
				signature.red += 1
			if color.b > 0.30 and color.b > color.r * 1.10 and color.r > color.g * 1.15:
				signature.purple += 1
			if color.r > 0.45 and color.g > 0.22 and color.b < 0.28 and color.r > color.b * 2.0:
				signature.gold += 1
			if color.b > 0.45 and color.g > 0.42 and color.r < 0.45 and color.b > color.r * 1.30:
				signature.cyan += 1
	return signature


func _validate_frame_order(signatures: Array[Dictionary]) -> void:
	_check(
		signatures[0].red > 12000
		and signatures[0].gold < 2500
		and signatures[0].purple < 100,
		"quadro 0 deixou de representar a Foice Hemática"
	)
	_check(
		signatures[1].purple > 8000
		and signatures[1].red < 1000
		and signatures[1].cyan < 100,
		"quadro 1 deixou de representar o Grimório Proibido"
	)
	_check(
		signatures[2].gold > 9000
		and signatures[2].red > 5000
		and signatures[2].cyan < 100,
		"quadro 2 deixou de representar o Martelo Rúnico"
	)
	_check(
		signatures[3].cyan > 8000
		and signatures[3].purple < 100,
		"quadro 3 deixou de representar a Relíquia da Tempestade"
	)
	_check(
		signatures[4].cyan > 3000
		and signatures[4].purple > 3500,
		"quadro 4 deixou de representar o Ídolo do Enxame"
	)


func _validate_runtime_consumers() -> void:
	var flash = WeaponFlashScript.new()
	root.add_child(flash)
	_check(flash.texture != null, "WeaponFlash não carregou o atlas")
	_check(flash.texture.resource_path == ATLAS_PATH, "WeaponFlash aponta para outro atlas")
	_check(flash.hframes == 5, "WeaponFlash não preservou cinco quadros")

	var eye = HomingEyeScript.new()
	root.add_child(eye)
	_check(eye.sprite != null, "HomingEye não criou seu Sprite2D")
	if eye.sprite != null:
		_check(eye.sprite.texture != null, "HomingEye não carregou o atlas")
		_check(eye.sprite.texture.resource_path == ATLAS_PATH, "HomingEye aponta para outro atlas")
		_check(eye.sprite.hframes == 5, "HomingEye não preservou cinco quadros")
		_check(eye.sprite.frame == 4, "HomingEye deixou de usar o quadro do Ídolo")

	flash.queue_free()
	eye.queue_free()
	await process_frame


func _run() -> void:
	var texture: Texture2D = load(ATLAS_PATH)
	_check(texture != null, "atlas não pôde ser carregado como recurso importado")
	if texture == null:
		quit(1)
		return
	var image := texture.get_image()
	_check(image != null and not image.is_empty(), "imagem importada do atlas ficou vazia")
	if image == null or image.is_empty():
		quit(1)
		return
	_check(image.get_size() == EXPECTED_SIZE, "atlas não manteve 1985x793")
	_check(image.get_width() % 5 == 0, "atlas não pode ser dividido em cinco células iguais")
	_check(floori(float(image.get_width()) / 5.0) == CELL_WIDTH, "largura de célula deixou de ser 397")

	var signatures: Array[Dictionary] = []
	for frame_index in range(FRAME_NAMES.size()):
		var bounds := _visible_bounds(image, frame_index)
		_check(bounds.has_area(), "%s ficou vazio" % FRAME_NAMES[frame_index])
		_check(
			bounds == EXPECTED_BOUNDS[frame_index],
			"%s mudou de enquadramento: %s" % [FRAME_NAMES[frame_index], bounds]
		)
		_check(
			bounds.position.x >= SAFE_MARGIN
			and bounds.position.y >= SAFE_MARGIN
			and bounds.end.x <= CELL_WIDTH - SAFE_MARGIN
			and bounds.end.y <= CELL_HEIGHT - SAFE_MARGIN,
			"%s invadiu a margem segura da própria célula" % FRAME_NAMES[frame_index]
		)
		var signature: Dictionary = _color_signature(image, frame_index)
		_check(signature.visible > 50000, "%s perdeu conteúdo visual demais" % FRAME_NAMES[frame_index])
		signatures.append(signature)

	_validate_frame_order(signatures)
	await _validate_runtime_consumers()

	if failures.is_empty():
		print(
			"WEAPON ATLAS OK: 1985x793, ordem 0-4, margens e consumidores de runtime validados"
		)
	quit(0 if failures.is_empty() else 1)
