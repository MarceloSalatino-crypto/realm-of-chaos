extends SceneTree

const CampaignCatalogScript = preload("res://scripts/campaign_catalog.gd")
const WorldScene = preload("res://scenes/world.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CAMPAIGN WORLD: " + message)


func _run() -> void:
	for definition in CampaignCatalogScript.all_maps():
		if not bool(definition.content_ready):
			continue
		var world = WorldScene.instantiate()
		world.suppress_save = true
		world.campaign_map_override_id = str(definition.id)
		root.add_child(world)
		await process_frame
		world.audio.enabled = false
		world.set_process(false)
		_check(world.campaign_map_id == str(definition.id), "map_id incorreto para %s" % definition.name)
		_check(str(world.biome.id) == str(definition.biome_id), "bioma incorreto para %s" % definition.name)
		_check(world.map_seed_offset == int(definition.seed_offset), "seed incorreta para %s" % definition.name)
		_check(is_equal_approx(world.map_boss_power, float(definition.boss_power)), "força de boss incorreta para %s" % definition.name)
		_check(is_equal_approx(float(world.biome.enemy_power), float(definition.enemy_power)), "força de inimigos incorreta para %s" % definition.name)
		_check(world.persistence.save_path == world.SAVE_PATH, "override visual alterou o caminho real do save")
		world.queue_free()
		await process_frame

	var future := CampaignCatalogScript.map_by_order(4)
	_check(not bool(future.content_ready) and str(future.scene_path).is_empty(), "mapa futuro ganhou cena jogável por engano")
	if failures.is_empty():
		print("CAMPAIGN WORLD OK: Bosque, Gelo e Catedral carregam por map_id; mapas futuros não iniciam")
		quit(0)
	else:
		quit(1)
