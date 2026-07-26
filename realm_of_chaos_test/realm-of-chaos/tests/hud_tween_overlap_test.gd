extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(10.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("HUD TWEEN OVERLAP: teste excedeu 10 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("HUD TWEEN OVERLAP: " + message)


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	var hud = world.hud

	hud.show_stage_banner("PRIMEIRO")
	var first_stage_tween: Tween = hud.stage_banner_tween
	hud.show_stage_banner("SEGUNDO")
	_check(not first_stage_tween.is_valid(), "banner anterior continuou controlando o HUD")
	_check(hud.stage_banner.text == "SEGUNDO" and hud.stage_banner_tween.is_valid(), "banner novo não assumiu o controle")

	hud.show_boss_intro("CHEFE UM", "ALERTA")
	var first_boss_tween: Tween = hud.boss_intro_tween
	hud.show_boss_intro("CHEFE DOIS", "ALERTA")
	_check(not first_boss_tween.is_valid(), "intro anterior continuou controlando o HUD")
	_check("CHEFE DOIS" in hud.boss_intro_label.text and hud.boss_intro_tween.is_valid(), "intro nova não assumiu o controle")

	hud.flash_damage(0.4)
	var first_damage_tween: Tween = hud.damage_flash_tween
	hud.flash_damage(1.0)
	_check(not first_damage_tween.is_valid(), "flash anterior continuou alterando a opacidade")
	_check(hud.damage_flash.color.a > 0.30 and hud.damage_flash_tween.is_valid(), "flash novo não reiniciou com a intensidade correta")

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("HUD TWEEN OVERLAP OK: avisos novos substituem animações anteriores")
		quit(0)
	else:
		quit(1)
