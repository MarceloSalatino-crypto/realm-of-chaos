extends SceneTree

const AbilityIndicatorScript = preload("res://scripts/ability_indicator.gd")
const WORLD_SCENE = preload("res://scenes/world.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ABILITY INDICATOR: " + message)


func _run() -> void:
	var indicator = AbilityIndicatorScript.new()
	indicator.size = Vector2(172.0, 96.0)
	root.add_child(indicator)
	await process_frame
	var icon := load("res://assets/ui/upgrade_icons/soul_orbit.png") as Texture2D
	indicator.set_state(0.5, icon, "PULSO GLACIAL", Color("70dcff"), false)
	_check(is_equal_approx(indicator.fill_progress, 0.5), "preenchimento radial não recebeu progresso normalizado")
	_check(not indicator.is_ready_state, "meia recarga foi marcada como pronta")
	_check(indicator.icon_rect.texture == icon, "ícone temático não foi aplicado")
	_check(indicator.skill_label.text == "PULSO GLACIAL", "nome compacto da habilidade não foi aplicado")
	indicator.set_state(1.0, icon, "PULSO GLACIAL", Color("70dcff"), true)
	_check(indicator.is_ready_state, "progresso completo não marcou habilidade como pronta")
	_check(indicator.pulse_tween != null and indicator.pulse_tween.is_valid(), "transição para pronta não iniciou pulso")
	indicator.set_state(0.0, icon, "PULSO GLACIAL", Color("70dcff"), false)
	_check(not indicator.is_ready_state and is_zero_approx(indicator.fill_progress), "estado após uso não voltou ao vazio")
	indicator.queue_free()

	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.dash_cooldown = world.player.DASH_COOLDOWN_DURATION
	_check(is_zero_approx(world.player.dash_cooldown_progress()), "cooldown cheio não começou em progresso zero")
	world.player.dash_cooldown = world.player.DASH_COOLDOWN_DURATION * 0.5
	_check(is_equal_approx(world.player.dash_cooldown_progress(), 0.5), "metade do cooldown não produziu progresso 0,5")
	world.player.dash_cooldown = 0.0
	_check(is_equal_approx(world.player.dash_cooldown_progress(), 1.0), "cooldown concluído não produziu progresso 1,0")
	_check(world.hud.get_node_or_null("DashStatus") == null, "texto antigo de status ainda foi criado")
	var expected_icons := {
		"eclipse_hunter": "chaos_bolt.png",
		"glacial_oracle": "soul_orbit.png",
		"crimson_knight": "shadow_blades.png",
		"void_automaton": "chaos_nova.png",
	}
	for character_id in expected_icons:
		world.hud.update_navigation(0.5, character_id, "HABILIDADE")
		var texture_path: String = world.hud.ability_indicator.icon_rect.texture.resource_path
		_check(texture_path.ends_with(str(expected_icons[character_id])), "ícone incorreto para %s" % character_id)
	world.queue_free()
	await process_frame

	if failures.is_empty():
		print("ABILITY INDICATOR OK: progresso, estados, pulso, cooldown e quatro ícones validados")
		quit(0)
	else:
		quit(1)
