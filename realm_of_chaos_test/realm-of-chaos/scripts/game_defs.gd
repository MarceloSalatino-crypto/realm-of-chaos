class_name GameDefs
extends RefCounted


static func enemy_data(kind: String) -> Dictionary:
	match kind:
		"bat":
			return _enemy("Morcego Rubro", 18.0, 155.0, 8.0, 2, 17.0, 0.18, "ff5b65", "bat", "swarm_flight")
		"mage":
			return _enemy("Cultista Glacial", 52.0, 72.0, 12.0, 5, 22.0, 0.20, "65bfff", "mage", "ranged", true)
		"brute":
			return _enemy("Brutamonte de Pedra", 145.0, 48.0, 22.0, 9, 32.0, 0.23, "d3a86e", "brute", "brute")
		"ember":
			return _enemy("Crânio de Brasa", 38.0, 105.0, 17.0, 5, 22.0, 0.19, "ff8a32", "ember", "ember")
		"bomber":
			return _enemy("Carniçal Instável", 54.0, 92.0, 28.0, 7, 23.0, 0.18, "ff744a", "ember", "bomber")
		"necromancer":
			return _enemy("Tecelão de Ossos", 96.0, 57.0, 15.0, 13, 24.0, 0.20, "9d72ff", "mage", "necromancer", true)
		"archer":
			return _enemy("Atirador do Véu", 62.0, 82.0, 14.0, 8, 21.0, 0.19, "78d7ff", "mage", "archer", true)
		"assassin":
			return _enemy("Assassino Espectral", 46.0, 142.0, 19.0, 9, 19.0, 0.18, "d86cff", "prowler", "assassin")
		"swarm":
			return _enemy("Farpas Aladas", 13.0, 192.0, 6.0, 1, 11.0, 0.115, "ff6278", "bat", "swarm_flight")
		"guardian":
			return _enemy("Guardião Rúnico", 235.0, 43.0, 21.0, 16, 35.0, 0.24, "e0b779", "brute", "guardian")
		"ossuary_colossus":
			return _boss("COLOSSO DO OSSUÁRIO", 2200.0, 45.0, 24.0, 120, 48.0, 0.19, "cfaa75", "ossuary_colossus", "ossuary")
		"glacial_archon":
			return _boss("ARCONTE GLACIAL", 4800.0, 62.0, 27.0, 180, 43.0, 0.19, "64d9ff", "glacial_archon", "glacial", true)
		"infernal_reaper":
			return _boss("CEIFADOR INFERNAL", 9200.0, 92.0, 34.0, 260, 46.0, 0.18, "ff5a42", "infernal_reaper", "reaper")
		"void_titan":
			return _boss("TITÃ DO VAZIO", 17500.0, 52.0, 42.0, 380, 58.0, 0.19, "d653ff", "void_titan", "titan")
		"chaos_sovereign":
			var data := _boss("SOBERANO DO CAOS", 34000.0, 72.0, 48.0, 900, 62.0, 0.19, "f0a34d", "chaos_sovereign", "sovereign", true)
			data["final_boss"] = true
			return data
		"void_knight":
			return _boss("Arauto do Vazio", 1500.0, 58.0, 28.0, 80, 42.0, 0.27, "b05cff", "void_knight", "legacy", true)
		_:
			return _enemy("Espreitador Ósseo", 30.0, 92.0, 10.0, 3, 21.0, 0.19, "d7d0ad", "prowler", "hunter")


static func _enemy(
	name: String, hp: float, speed: float, damage: float, xp: int,
	radius: float, visual_scale: float, color: String, animation: String,
	behavior: String, ranged := false
) -> Dictionary:
	return {
		"name": name, "hp": hp, "speed": speed, "damage": damage, "xp": xp,
		"radius": radius, "visual_scale": visual_scale, "color": Color(color),
		"animation": animation, "behavior": behavior, "ranged": ranged
	}


static func _boss(
	name: String, hp: float, speed: float, damage: float, xp: int,
	radius: float, visual_scale: float, color: String, animation: String,
	behavior: String, ranged := false
) -> Dictionary:
	var data := _enemy(name, hp, speed, damage, xp, radius, visual_scale, color, animation, behavior, ranged)
	data["boss"] = true
	data["mini_boss"] = true
	return data


static func boss_schedule() -> Array[Dictionary]:
	return [
		{"time": 300.0, "kind": "ossuary_colossus", "name": "COLOSSO DO OSSUÁRIO", "final": false},
		{"time": 600.0, "kind": "glacial_archon", "name": "ARCONTE GLACIAL", "final": false},
		{"time": 900.0, "kind": "infernal_reaper", "name": "CEIFADOR INFERNAL", "final": false},
		{"time": 1200.0, "kind": "void_titan", "name": "TITÃ DO VAZIO", "final": false},
		{"time": 1500.0, "kind": "chaos_sovereign", "name": "SOBERANO DO CAOS", "final": true}
	]


static func upgrades() -> Array[Dictionary]:
	return [
		{"id": "chaos_bolt", "title": "Besta do Caos", "icon": "✦", "max": 8,
		 "description": "Dispara setas profanas; ganha dano, projéteis e perfuração."},
		{"id": "shadow_blades", "title": "Lâminas Sombrias", "icon": "◆", "max": 6,
		 "description": "Dispara uma rajada em leque contra a horda."},
		{"id": "soul_orbit", "title": "Cetro das Almas", "icon": "◉", "max": 6,
		 "description": "Invoca lâminas orbitais que ferem inimigos próximos."},
		{"id": "chaos_nova", "title": "Cajado da Nova", "icon": "☼", "max": 6,
		 "description": "Conjura uma explosão periódica em toda a área."},
		{"id": "might", "title": "Poder Profano", "icon": "▲", "max": 5,
		 "description": "+15% de dano para todas as armas."},
		{"id": "haste", "title": "Ritual Acelerado", "icon": "»", "max": 5,
		 "description": "+10% de velocidade de ataque."},
		{"id": "vitality", "title": "Sangue Ancestral", "icon": "♥", "max": 5,
		 "description": "+25 de vida máxima e cura imediata."},
		{"id": "swiftness", "title": "Passo Espectral", "icon": "➤", "max": 5,
		 "description": "+8% de velocidade de movimento."},
		{"id": "magnet", "title": "Ímã de Éter", "icon": "⌁", "max": 5,
		 "description": "+35% de alcance para coletar cristais."},
		{"id": "armor", "title": "Pele de Pedra", "icon": "⬟", "max": 5,
		 "description": "Reduz em 2 o dano recebido."},
		{"id": "regeneration", "title": "Pacto Regenerativo", "icon": "+", "max": 5,
		 "description": "Recupera vida continuamente."},
		{"id": "critical", "title": "Olhar Fatal", "icon": "!", "max": 5,
		 "description": "+7% de chance de dano crítico."}
	]


static func evolution_data(weapon_id: String) -> Dictionary:
	match weapon_id:
		"chaos_bolt":
			return {"title": "BALISTA ABISSAL", "passive": "critical", "weapon_level": 8, "passive_level": 3}
		"shadow_blades":
			return {"title": "DANÇA DAS SOMBRAS", "passive": "swiftness", "weapon_level": 6, "passive_level": 3}
		"soul_orbit":
			return {"title": "DEVORADOR DE ESPÍRITOS", "passive": "regeneration", "weapon_level": 6, "passive_level": 3}
		"chaos_nova":
			return {"title": "COLAPSO DO VAZIO", "passive": "might", "weapon_level": 6, "passive_level": 3}
		_:
			return {}


static func meta_upgrades() -> Array[Dictionary]:
	return [
		{"id": "power", "title": "FORÇA ETERNA", "max": 10, "base_cost": 35, "description": "+5% de dano inicial por nível"},
		{"id": "vitality", "title": "CORAÇÃO DO VÉU", "max": 10, "base_cost": 30, "description": "+10 de vida inicial por nível"},
		{"id": "speed", "title": "PASSO DO CAÇADOR", "max": 8, "base_cost": 40, "description": "+3% de movimento por nível"},
		{"id": "fortune", "title": "SORTE PROFANA", "max": 8, "base_cost": 45, "description": "+1,5% de crítico por nível"}
	]


static func meta_cost(definition: Dictionary, level: int) -> int:
	return int(definition.base_cost) + level * level * 12


static func biome_data(cycle: int) -> Dictionary:
	match cycle % 3:
		1:
			return {
				"id": "frozen", "name": "RUÍNAS GLACIAIS", "ground": "res://assets/generated/frozen_ruins_ground.png",
				"ground_modulate": Color("aecce2"), "fog": Color(0.10, 0.28, 0.42, 0.08), "enemy_power": 1.22
			}
		2:
			return {
				"id": "cathedral", "name": "CATEDRAL DO VAZIO", "ground": "res://assets/generated/void_cathedral_ground.png",
				"ground_modulate": Color("b7a7ca"), "fog": Color(0.25, 0.06, 0.36, 0.10), "enemy_power": 1.48
			}
		_:
			return {
				"id": "forest", "name": "BOSQUE PROFANADO", "ground": "res://assets/generated/corrupted_forest_ground.png",
				"ground_modulate": Color("d1dbe9"), "fog": Color(0.10, 0.04, 0.16, 0.06), "enemy_power": 1.0
			}


static func stage_name(elapsed: float) -> String:
	return str(difficulty_data(elapsed).name)


static func difficulty_data(elapsed: float) -> Dictionary:
	if elapsed < 300.0:
		var progress := clampf(elapsed / 300.0, 0.0, 1.0)
		return {
			"id": "normal", "name": "I · NORMAL", "color": Color("b995e8"),
			"interval": lerpf(0.95, 0.52, progress),
			"batch": 1 + int(progress * 2.0), "cap": 80 + int(progress * 40.0),
			"power": lerpf(1.0, 1.9, progress), "elite_chance": lerpf(0.02, 0.055, progress)
		}
	if elapsed < 600.0:
		var progress := clampf((elapsed - 300.0) / 300.0, 0.0, 1.0)
		return {
			"id": "hard", "name": "II · DIFÍCIL", "color": Color("ffb454"),
			"interval": lerpf(0.42, 0.28, progress),
			"batch": 4 + int(progress * 2.0), "cap": 150 + int(progress * 50.0),
			"power": lerpf(2.0, 3.1, progress), "elite_chance": lerpf(0.07, 0.12, progress)
		}
	if elapsed < 900.0:
		var progress := clampf((elapsed - 600.0) / 300.0, 0.0, 1.0)
		return {
			"id": "chaos", "name": "III · CAOS", "color": Color("df63ff"),
			"interval": lerpf(0.20, 0.11, progress),
			"batch": 7 + int(progress * 5.0), "cap": 230 + int(progress * 70.0),
			"power": lerpf(3.3, 5.0, progress), "elite_chance": lerpf(0.14, 0.21, progress)
		}
	var progress := clampf((elapsed - 900.0) / 600.0, 0.0, 1.0)
	return {
		"id": "inferno", "name": "IV · MODO INFERNO", "color": Color("ff4b52"),
		"interval": lerpf(0.085, 0.05, progress),
		"batch": 14 + int(progress * 6.0), "cap": 320 + int(progress * 60.0),
		"power": lerpf(5.5, 10.0, progress), "elite_chance": lerpf(0.23, 0.34, progress)
	}
