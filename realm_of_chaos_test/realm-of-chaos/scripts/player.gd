extends CharacterBody2D

#region Sinais, dependências e estado

# Emitted through PlayerProgression.
@warning_ignore("unused_signal")
signal level_up_requested
# Emitted through PlayerVisualController.
@warning_ignore("unused_signal")
signal died

const PlayerProgressionScript = preload("res://scripts/player_progression.gd")
const PlayerCombatScript = preload("res://scripts/player_combat.gd")
const PlayerVisualControllerScript = preload("res://scripts/player_visual_controller.gd")
const STARTING_WEAPON_IDS: Array[String] = ["chaos_bolt", "shadow_blades", "soul_orbit", "chaos_nova"]
const WEAPON_IDS: Array[String] = [
	"chaos_bolt", "shadow_blades", "soul_orbit", "chaos_nova",
	"blood_scythe", "forbidden_grimoire", "rune_hammer", "storm_relic", "swarm_idol"
]
const MAX_WEAPONS := 6
const MAX_PASSIVES := 6
const WALK_FRAME_DISTANCE := 21.5
const WALK_MIN_SPEED := 6.0
const WALK_MAX_FPS := 15.0
const ATTACK_FACING_HOLD := 0.24
const ATTACK_FACING_DEADZONE := 0.18
const DASH_COOLDOWN_DURATION := 3.2
const WEAPON_TEXTURES = PlayerVisualControllerScript.WEAPON_TEXTURES
const WEAPON_TITLES := {
	"chaos_bolt": "BESTA DO CAOS",
	"shadow_blades": "LÂMINA SOMBRIA",
	"soul_orbit": "CETRO DAS ALMAS",
	"chaos_nova": "CAJADO DA NOVA",
	"blood_scythe": "FOICE HEMÁTICA",
	"forbidden_grimoire": "GRIMÓRIO PROIBIDO",
	"rune_hammer": "MARTELO RÚNICO",
	"storm_relic": "RELÍQUIA DA TEMPESTADE",
	"swarm_idol": "ÍDOLO DO ENXAME"
}

@export var bullet_scene: PackedScene

var move_speed := 235.0
var movement_acceleration := 1450.0
var movement_deceleration := 1850.0
var hp := 125.0
var max_hp := 125.0
var armor := 0.0
var regeneration := 0.0
var damage_multiplier := 1.0
var cooldown_multiplier := 1.0
var crit_chance := 0.05
var critical_multiplier := 2.0
var pickup_radius := 105.0
var projectile_bonus := 0
var life_steal := 0.0
var boss_damage_multiplier := 1.0
var dodge_chance := 0.0
var revive_charges := 0
var character_id := "eclipse_hunter"
var character_applied := false
var character_color := Color.WHITE
var character_skill_name := "RAJADA DO ECLIPSE"
var character_guard_time := 0.0
var relic_levels: Dictionary = {}
var banished_upgrades: Dictionary = {}
var hazard_tick := 0.0
var dash_cooldown := 0.0
var dash_duration := 0.0
var dash_direction := Vector2.RIGHT
var dash_speed := 760.0
var blessing_time := 0.0
var blessing_title := ""
var blessing_kind := ""
var temporary_damage_multiplier := 1.0
var temporary_cooldown_multiplier := 1.0
var temporary_move_multiplier := 1.0
var temporary_pickup_multiplier := 1.0
var temporary_crit_bonus := 0.0
var temporary_armor := 0.0

var level := 1
var experience := 0
var experience_needed := 12
var disabled := false
var invulnerability := 0.0
var motion_age := 0.0
var last_direction := Vector2.RIGHT
var attack_direction := Vector2.RIGHT
var attack_facing_x := 1.0
var attack_facing_time := 0.0
var pending_attack_facing_x := 0.0
var attack_recoil := 0.0
var attack_flash := 0.0
var hurt_recoil := 0.0
var death_started := false
var equipped_weapon_id := ""
var walk_animation_clock := 0.0

var weapon_levels := {
	"chaos_bolt": 0,
	"shadow_blades": 0,
	"soul_orbit": 0,
	"chaos_nova": 0,
	"blood_scythe": 0,
	"forbidden_grimoire": 0,
	"rune_hammer": 0,
	"storm_relic": 0,
	"swarm_idol": 0
}
var passive_levels := {
	"might": 0, "haste": 0, "vitality": 0, "swiftness": 0,
	"magnet": 0, "armor": 0, "regeneration": 0, "critical": 0
}
var evolved_weapons := {
	"chaos_bolt": false,
	"shadow_blades": false,
	"soul_orbit": false,
	"chaos_nova": false,
	"blood_scythe": false,
	"forbidden_grimoire": false,
	"rune_hammer": false,
	"storm_relic": false,
	"swarm_idol": false
}
var bolt_timer := 0.15
var blades_timer := 1.0
var nova_timer := 4.0
var orbit_tick := 0.0
var orbit_angle := 0.0
var orbit_hit_times: Dictionary = {}
var scythe_timer := 0.8
var grimoire_timer := 1.6
var hammer_timer := 1.4
var storm_timer := 0.9
var swarm_timer := 1.2
var progression: PlayerProgressionScript
var combat: PlayerCombatScript
var visual_controller: PlayerVisualControllerScript

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite2D
@onready var shadow: Polygon2D = $Shadow
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

#endregion

#region Ciclo de vida e movimentação própria


func _ready() -> void:
	progression = PlayerProgressionScript.new(self)
	combat = PlayerCombatScript.new(self)
	visual_controller = PlayerVisualControllerScript.new(self)
	_ensure_gameplay_actions()
	hp = max_hp


func _ensure_gameplay_actions() -> void:
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var dash_key := InputEventKey.new()
		dash_key.physical_keycode = KEY_SPACE
		InputMap.action_add_event("dash", dash_key)
		var dash_button := InputEventJoypadButton.new()
		dash_button.button_index = JOY_BUTTON_A
		InputMap.action_add_event("dash", dash_button)
	if not InputMap.has_action("map_toggle"):
		InputMap.add_action("map_toggle")
		var map_key := InputEventKey.new()
		map_key.physical_keycode = KEY_M
		InputMap.action_add_event("map_toggle", map_key)


func _equip_starting_weapon(weapon_id: String) -> void:
	for candidate_weapon_id in WEAPON_IDS:
		weapon_levels[candidate_weapon_id] = 0
	equipped_weapon_id = weapon_id if weapon_id in STARTING_WEAPON_IDS else "chaos_bolt"
	weapon_levels[equipped_weapon_id] = 1
	_equip_weapon_visual(equipped_weapon_id)
	bolt_timer = 0.12
	blades_timer = 0.18
	nova_timer = 0.65
	orbit_tick = 0.05


func _equip_weapon_visual(weapon_id: String) -> void:
	visual_controller.equip_weapon_visual(weapon_id)


func equipped_weapon_title() -> String:
	return str(WEAPON_TITLES.get(equipped_weapon_id, "ARMA DO CAOS"))


func _physics_process(delta: float) -> void:
	if disabled:
		velocity = Vector2.ZERO
		return
	motion_age += delta
	invulnerability = maxf(0.0, invulnerability - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_duration = maxf(0.0, dash_duration - delta)
	character_guard_time = maxf(0.0, character_guard_time - delta)
	_update_temporary_blessing(delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length_squared() > 0.01:
		last_direction = direction.normalized()
	var environment := {"speed": 1.0, "traction": 1.0, "damage": 0.0, "name": ""}
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_environment_effect"):
		environment = world.get_environment_effect(global_position)
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		_start_dash(direction, world)
	var desired_velocity := direction * move_speed * temporary_move_multiplier * float(environment.get("speed", 1.0))
	var traction := float(environment.get("traction", 1.0))
	if dash_duration > 0.0:
		velocity = dash_direction * dash_speed
	elif direction.length_squared() > 0.01:
		velocity = velocity.move_toward(desired_velocity, movement_acceleration * traction * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, movement_deceleration * traction * delta)
	var movement_start_position := global_position
	move_and_slide()
	_process_landmark_contacts()
	global_position.x = clampf(global_position.x, -5550.0, 5550.0)
	global_position.y = clampf(global_position.y, -5550.0, 5550.0)
	var distance_moved := movement_start_position.distance_to(global_position)
	var actual_speed := distance_moved / maxf(delta, 0.0001)
	var is_moving := actual_speed > WALK_MIN_SPEED

	visual_controller.animate_character(delta, direction, is_moving, distance_moved)
	visual_controller.update_invulnerability_flash()

	if regeneration > 0.0 and hp < max_hp:
		heal(regeneration * delta, false)
	hazard_tick -= delta
	var hazard_damage := float(environment.get("damage", 0.0))
	if hazard_damage > 0.0 and hazard_tick <= 0.0:
		hazard_tick = 0.5
		take_damage(hazard_damage * 0.5, Vector2.ZERO, true)
	combat.update_weapons(delta)

#endregion

#region Fachada de combate — habilidade do caçador


func _start_dash(input_direction: Vector2, world: Node) -> void:
	combat.start_dash(input_direction, world)


func _activate_character_skill(world: Node) -> void:
	combat.activate_character_skill(world)

#endregion

#region Estado temporário próprio


func _update_temporary_blessing(delta: float) -> void:
	if blessing_time <= 0.0:
		return
	blessing_time = maxf(0.0, blessing_time - delta)
	if blessing_time <= 0.0:
		blessing_title = ""
		blessing_kind = ""
		temporary_damage_multiplier = 1.0
		temporary_cooldown_multiplier = 1.0
		temporary_move_multiplier = 1.0
		temporary_pickup_multiplier = 1.0
		temporary_crit_bonus = 0.0
		temporary_armor = 0.0


func _process_landmark_contacts() -> void:
	for collision_index in range(get_slide_collision_count()):
		var collider := get_slide_collision(collision_index).get_collider()
		if is_instance_valid(collider) and collider.has_method("activate_from_physical_contact"):
			collider.activate_from_physical_contact(self)

#endregion

#region Fachada visual


func _animate_character(delta: float, direction: Vector2, is_moving: bool, distance_moved := 0.0) -> void:
	visual_controller.animate_character(delta, direction, is_moving, distance_moved)


func _set_primary_attack_facing(direction: Vector2, weapon_id: String) -> void:
	visual_controller.set_primary_attack_facing(direction, weapon_id)

#endregion

#region Fachada de combate — armas, dano e cura


func _update_weapons(delta: float) -> void:
	combat.update_weapons(delta)


func _fire_chaos_bolt() -> void:
	combat.fire_chaos_bolt()


func _fire_shadow_blades(weapon_level: int) -> void:
	combat.fire_shadow_blades(weapon_level)


func _spawn_player_projectile(
	direction: Vector2, amount: float, projectile_speed: float,
	pierce: int, size: float, color: Color, weapon_id := "unknown", force_critical := false
) -> void:
	combat.spawn_player_projectile(direction, amount, projectile_speed, pierce, size, color, weapon_id, force_critical)


func _spawn_shadow_dance_projectile(
	spawn_position: Vector2, direction: Vector2, amount: float,
	projectile_speed: float, pierce: int, size: float, color: Color,
	is_critical: bool, returning: bool
) -> Node:
	return combat.spawn_shadow_dance_projectile(
		spawn_position, direction, amount, projectile_speed,
		pierce, size, color, is_critical, returning
	)


func _damage_orbit(weapon_level: int) -> void:
	combat.damage_orbit(weapon_level)


func _cast_nova(weapon_level: int) -> void:
	combat.cast_nova(weapon_level)


func _swing_blood_scythe(weapon_level: int) -> void:
	combat.swing_blood_scythe(weapon_level)


func _cast_forbidden_grimoire(weapon_level: int) -> void:
	combat.cast_forbidden_grimoire(weapon_level)


func _slam_rune_hammer(weapon_level: int) -> void:
	combat.slam_rune_hammer(weapon_level)


func _cast_storm_chain(weapon_level: int) -> void:
	combat.cast_storm_chain(weapon_level)


func _release_swarm_eyes(weapon_level: int) -> void:
	combat.release_swarm_eyes(weapon_level)


func _notify_weapon_fired(weapon_id: String) -> void:
	combat.notify_weapon_fired(weapon_id)


func _nearest_enemy() -> Node2D:
	return combat.nearest_enemy()


func _enemies_near(radius: float) -> Array[Node]:
	return combat.enemies_near(radius)


func take_damage(amount: float, source_direction := Vector2.ZERO, environmental := false) -> void:
	combat.take_damage(amount, source_direction, environmental)


func _play_death_animation() -> void:
	visual_controller.play_death_animation()


func heal(amount: float, show_effect := true) -> void:
	combat.heal(amount, show_effect)

#endregion

#region Fachada de progressão — upgrades e bênçãos


func collect_xp(amount: int) -> void:
	progression.collect_xp(amount)


func get_upgrade_options(count: int, excluded_ids: Array[String] = []) -> Array[Dictionary]:
	return progression.get_upgrade_options(count, excluded_ids)


func is_build_complete() -> bool:
	return progression.is_build_complete()


func refresh_build_complete() -> bool:
	return progression.refresh_build_complete()


func _evolution_hint_for(upgrade_id: String) -> String:
	return progression.evolution_hint_for(upgrade_id)


func active_weapon_count() -> int:
	return progression.active_weapon_count()


func active_passive_count() -> int:
	return progression.active_passive_count()


func set_upgrade_run_seed(seed_value: int) -> void:
	progression.set_offer_seed(seed_value)


func reset_upgrade_offer_history() -> void:
	progression.reset_offer_history()


func banish_upgrade(upgrade_id: String) -> void:
	progression.banish_upgrade(upgrade_id)


func _roll_rarity() -> String:
	return progression.roll_rarity()


func get_upgrade_level(upgrade_id: String) -> int:
	return progression.get_upgrade_level(upgrade_id)


func apply_upgrade(upgrade_id: String, rarity := "COMUM") -> void:
	progression.apply_upgrade(upgrade_id, rarity)


func _upgrade_max(upgrade_id: String) -> int:
	return progression.upgrade_max(upgrade_id)


func _check_weapon_evolutions() -> void:
	progression.check_weapon_evolutions()


func apply_meta_bonuses(meta: Dictionary) -> void:
	progression.apply_meta_bonuses(meta)


func apply_landmark_blessing(kind: String, duration := 40.0) -> String:
	return progression.apply_landmark_blessing(kind, duration)


func active_landmark_buffs() -> Array[Dictionary]:
	return progression.active_landmark_buffs()

#endregion

#region Consultas derivadas do Player


func effective_damage_multiplier() -> float:
	return damage_multiplier * temporary_damage_multiplier


func effective_cooldown_multiplier() -> float:
	return cooldown_multiplier * temporary_cooldown_multiplier


func effective_crit_chance() -> float:
	return crit_chance + temporary_crit_bonus


func effective_pickup_radius() -> float:
	return pickup_radius * temporary_pickup_multiplier


func dash_cooldown_progress() -> float:
	return 1.0 - clampf(dash_cooldown / DASH_COOLDOWN_DURATION, 0.0, 1.0)

#endregion

#region Fachadas de personagem, relíquias e recompensas


func apply_character(selected_id: String) -> void:
	progression.apply_character(selected_id)


func _apply_character_visual() -> void:
	visual_controller.apply_character_color()


func get_relic_options(count: int) -> Array[Dictionary]:
	return progression.get_relic_options(count)


func apply_relic(relic_id: String) -> void:
	progression.apply_relic(relic_id)


func on_damage_dealt(amount: float, target_is_boss: bool) -> void:
	combat.on_damage_dealt(amount, target_is_boss)


func all_weapons_evolved() -> bool:
	return progression.all_weapons_evolved()


func relic_summary() -> String:
	return progression.relic_summary()


func grant_boss_reward(final_reward := false) -> void:
	progression.grant_boss_reward(final_reward)


func weapon_summary() -> String:
	return progression.weapon_summary()

#endregion

#region Desenho delegado


func _draw() -> void:
	if visual_controller:
		visual_controller.draw()

#endregion
