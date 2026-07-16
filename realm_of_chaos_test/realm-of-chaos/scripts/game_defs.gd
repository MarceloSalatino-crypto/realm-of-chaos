class_name GameDefs
extends RefCounted


static func enemy_data(kind: String) -> Dictionary:
	match kind:
		"bat":
			return {
				"name": "Morcego Rubro", "cell": Vector2i(1, 0), "hp": 18.0,
				"speed": 155.0, "damage": 8.0, "xp": 2, "radius": 17.0,
				"visual_scale": 0.18, "color": Color("ff5b65")
			}
		"mage":
			return {
				"name": "Cultista Glacial", "cell": Vector2i(2, 0), "hp": 52.0,
				"speed": 72.0, "damage": 12.0, "xp": 5, "radius": 22.0,
				"visual_scale": 0.20, "ranged": true, "color": Color("65bfff")
			}
		"brute":
			return {
				"name": "Brutamonte de Pedra", "cell": Vector2i(0, 1), "hp": 145.0,
				"speed": 48.0, "damage": 22.0, "xp": 9, "radius": 32.0,
				"visual_scale": 0.23, "color": Color("d3a86e")
			}
		"ember":
			return {
				"name": "Crânio de Brasa", "cell": Vector2i(1, 1), "hp": 38.0,
				"speed": 105.0, "damage": 17.0, "xp": 5, "radius": 22.0,
				"visual_scale": 0.19, "color": Color("ff8a32")
			}
		"void_knight":
			return {
				"name": "Arauto do Vazio", "cell": Vector2i(2, 1), "hp": 1500.0,
				"speed": 58.0, "damage": 28.0, "xp": 80, "radius": 42.0,
				"visual_scale": 0.27, "ranged": true, "boss": true,
				"color": Color("b05cff")
			}
		_:
			return {
				"name": "Espreitador Ósseo", "cell": Vector2i(0, 0), "hp": 30.0,
				"speed": 92.0, "damage": 10.0, "xp": 3, "radius": 21.0,
				"visual_scale": 0.19, "color": Color("d7d0ad")
			}


static func upgrades() -> Array[Dictionary]:
	return [
		{"id": "chaos_bolt", "title": "Seta do Caos", "icon": "✦", "max": 8,
		 "description": "Mais dano, projéteis e perfuração."},
		{"id": "shadow_blades", "title": "Lâminas Sombrias", "icon": "◆", "max": 6,
		 "description": "Dispara uma rajada em leque contra a horda."},
		{"id": "soul_orbit", "title": "Órbita de Almas", "icon": "◉", "max": 6,
		 "description": "Lâminas orbitais ferem inimigos próximos."},
		{"id": "chaos_nova", "title": "Nova do Vazio", "icon": "☼", "max": 6,
		 "description": "Uma explosão periódica atinge toda a área."},
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


static func stage_name(elapsed: float) -> String:
	if elapsed < 180.0:
		return "I · BOSQUE PROFANADO"
	if elapsed < 360.0:
		return "II · LUA RUBRA"
	if elapsed < 540.0:
		return "III · RUPTURA DO VÉU"
	return "IV · O ARAUTO DESPERTA"
