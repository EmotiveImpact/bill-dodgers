extends SceneTree
## Actual main.tscn seam fixtures. Actor placement, suppressed waves and chosen
## health/state below are explicit isolation setup, never full-route evidence.
const World = preload("res://src/world_three.gd")
const Combat = preload("res://src/festival_combat.gd")
const Painter = preload("res://src/festival_renderer.gd")
const SaveStore = preload("res://src/save_store.gd")

class AudioLog extends RefCounted:
	var enabled := false
	var paused := false
	var music_requested := false
	var starts: Array = []
	var stops := 0
	var effects: Array = []
	func set_enabled(value: bool) -> void: enabled = value
	func set_paused(value: bool) -> void: paused = value
	func play_effect(effect: String) -> void: effects.append(effect)
	func start_music(boss: bool = false) -> void: starts.append(boss); music_requested = true
	func stop_music() -> void: stops += 1; music_requested = false
	func shutdown() -> void: pass
	func clear_log() -> void: starts.clear(); stops = 0; effects.clear()

class ProbeWorld extends World:
	var trace: Array = []
	func base_displacement(dt: float, host, move: float) -> float:
		trace.append(["motion", host.mode]); return super.base_displacement(dt, host, move)
	func carry_player(dt: float, host) -> void:
		trace.append(["carry", host.mode]); super.carry_player(dt, host)
	func after_motion(host) -> void:
		trace.append(["after_motion", host.mode]); super.after_motion(host)
	func after_camera(dt: float, host) -> void:
		trace.append(["camera", host.mode]); super.after_camera(dt, host)
	func objective_tick(dt: float, host) -> String:
		trace.append(["objective", host.mode]); return super.objective_tick(dt, host)
	func after_pickups(dt: float, host) -> void:
		trace.append(["world", host.mode]); super.after_pickups(dt, host)
	func finish_frame(host) -> void:
		trace.append(["finish", host.mode]); super.finish_frame(host)

class ProbeCombat extends Combat:
	var trace: Array = []
	func waves_tick(dt: float, host) -> void:
		trace.append(["waves", host.mode]); super.waves_tick(dt, host)
	func enemies_tick(dt: float, host) -> void:
		trace.append(["bots", host.mode]); super.enemies_tick(dt, host)
	func projectiles_tick(dt: float, host) -> void:
		trace.append(["shots", host.mode]); super.projectiles_tick(dt, host)
	func pickups_tick(dt: float, host) -> void:
		trace.append(["pickups", host.mode]); super.pickups_tick(dt, host)
	func boss_tick(dt: float, host) -> String:
		trace.append(["boss", host.mode]); return super.boss_tick(dt, host)
	func jar_tick(dt: float, host) -> String:
		trace.append(["jar", host.mode]); return super.jar_tick(dt, host)

class ProbeAbilities extends "res://src/abilities.gd":
	var trace: Array = []
	func tick(dt: float, controls: Dictionary, host, deferred: bool = false) -> void:
		trace.append(["pre", host.mode]); super.tick(dt, controls, host, deferred)
	func bubbles_tick(dt: float, host) -> void:
		trace.append(["bubbles", host.mode]); super.bubbles_tick(dt, host)
	func effects_tick(dt: float, host) -> void:
		trace.append(["effects", host.mode]); super.effects_tick(dt, host)

class ProbePainter extends Painter:
	var draw_calls: Array = []
	func draw_sky(host, runtime = null) -> void: draw_calls.append("sky"); super.draw_sky(host, runtime)
	func draw_level(host, runtime = null) -> void: draw_calls.append("level"); super.draw_level(host, runtime)
	func draw_mid(host, runtime = null, pickups: Callable = Callable()) -> void: draw_calls.append("finds"); super.draw_mid(host, runtime, pickups)
	func draw_boss(host, runtime = null) -> void: draw_calls.append("boss"); super.draw_boss(host, runtime)
	func draw_enemy(host, enemy: Dictionary) -> bool: draw_calls.append("bot"); return super.draw_enemy(host, enemy)
	func draw_player_back(host, player = null) -> void: draw_calls.append("player_back"); super.draw_player_back(host, player)
	func draw_player_front(host, player = null) -> void: draw_calls.append("player_front"); super.draw_player_front(host, player)
	func draw_bill(host, bullet: Dictionary) -> void: draw_calls.append("bill"); super.draw_bill(host, bullet)
	func draw_front(host, runtime = null) -> void: draw_calls.append("front"); super.draw_front(host, runtime)

var checks := 0
var failures: Array[String] = []
var trace: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func near(a: float, b: float) -> bool: return absf(a - b) < 0.001
func no_waves(game) -> void:
	for wave in game.combat.waves: wave.at = INF
func mark_waves(game) -> void:
	for wave in game.combat.waves: wave.started = true; wave.done = true; wave.index = wave.group.size()
func fresh(game, who: String = "jp", skills: Array = []) -> void:
	game.character = who
	game.save = {"schema": 1, "receipts": {}, "skills": skills.duplicate(), "kitty": 13}
	game.audio.clear_log()
	game.load_level("3-1")
	no_waves(game)
	game.step(0, {}) # Actual initial late coin-row spawn, then isolated removal.
	game.coins.clear()
	trace.clear()
func stand(game, point: Vector2, camera_x: float = 0) -> void:
	game.player = point; game.camera = Vector2(camera_x, 0); game.camera_speed = 0
	game.camera_lock = null; game.velocity = Vector2.ZERO; game.grounded = true
	game.on_platform = false; game.hurt_lock = 0; game.jump_held = false; game.drop_time = 0
	game._last_floor = point.y
	game.world_three._standing_surface = {}
func advance(game, seconds: float, controls: Dictionary = {}) -> void:
	while seconds > 0.000000001:
		var dt := minf(seconds, 0.01); game.step(dt, controls); seconds -= dt
func shot(point: Vector2, damage: int = 1, ghost: bool = false) -> Dictionary:
	return {"p": point, "v": Vector2.ZERO, "life": 20.0, "enemy": false, "damage": damage, "ghost": ghost, "ghost_age": 0.0}
func bill(point: Vector2, tie: bool = false) -> Dictionary:
	return {"p": point, "v": Vector2.ZERO, "life": 20.0, "enemy": true, "gravity": 0.0, "tie": tie}
func bot(game, point: Vector2, kind: String = "throw") -> Dictionary:
	var surface: Dictionary = game.world_three.below(game, point.x, point.y - 2)
	if surface.is_empty(): surface = {"row": [point.x - 1000, point.x + 1000, point.y], "plat": false}
	var enemy: Dictionary = game.combat.new_bot(game, point.x, surface, kind, {"entered": true})
	enemy.p = point; enemy.speed = 0.0; enemy.cd = 100.0; enemy.stop = 300.0
	return enemy
func arena(game) -> void:
	stand(game, Vector2(9050, 482), 8640)
	game.world_three._scenes[1].done = true # Isolate seller from earlier door.
	game.step(0, {}) # Actual late entry predicate, not direct start_boss.
	game.boss.state.state = "walk"; game.boss.state.x = 9200
	game.boss.state.next = 100.0
	game.boss.state.called = [true, true]; game.boss.state.dz = true
func ball(point: Vector2) -> Dictionary:
	return {"kind": "ball", "p": point, "v": Vector2.ZERO, "age": 0.0, "life": 5.0, "spin": 0.0, "free": 0.0, "boss_next": 100.0, "floor": 482.0, "trail": []}

func test_selection(game) -> void:
	fresh(game)
	check(game._native_world_three() and game.is_native_supported() and game.scene_runtime == game.world_three and game.combat == game.festival_combat, "Main selects distinct supported3-1 family/runtime/combat")
	check(not game._native_world_one() and not game._native_world_two() and game._source_ability_shots(), "Festival never aliases W1/W2 and enables source ghost routing")
	check(game.combat.waves.size() == 10 and game.combat.waves.reduce(func(total, w): return total + w.group.size(), 0) == 47, "Actual main loads ten waves and47solo groups")
	check(game.crates.size() == 7 and game.receipts.size() == 3 and game.world_three.tents.size() == 16, "Actual main loads seven crates, three finds and16tents")
	check(game.world_three.surfaces(game).size() == 31 and game.player == Vector2(300, 482), "Authored28solids3platforms and source start feet")
	check(game.audio.starts == [false] and game.boss == null, "Fresh ordinary soundtrack once, no fake entry boss")
	for id in ["7-1", "7-6", "7-S"]:
		game.load_level("4-1"); game.level_id = id; game._complete_level()
		check(not game.is_native_supported() and game.mode == "play" and not game.save.get("cleared", {}).get(id, false), id + " unknown run remains gated despite reusable combat")
	game.load_level("3-2")
	check(game._native_world_three() and game.combat.waves.size() == 15 and game.festival_renderer.supports("3-2"), "Queue extension selects its own runtime data and painter")
	game.load_level("3-3")
	check(game._native_world_three() and game.combat.waves.size() == 10 and game.festival_renderer.supports("3-3"), "Night extension selects actual shared combat and layered painter")
	game.load_level("3-4")
	check(game._native_world_three() and game.combat.waves.size() == 9 and game.festival_renderer.supports("3-4"), "Big-top extension selects actual shared combat and interior painter")
	game.load_level("1-2")
	check(game._native_world_one() and game.combat == game.street_combat and game.world_one.crumbles.size() == 12, "Returning to W1 retains actual rooftop runtime and12crumbles")
	game.load_level("2-1")
	check(game._native_world_two() and game.combat == game.supermarket_combat and game.combat.waves.size() == 11, "Returning to W2 retains separate supermarket policy")
	fresh(game)
	game.step(0.01, {})
	check(trace.map(func(row): return row[0]) == ["motion", "carry", "after_motion", "pre", "camera", "waves", "objective", "bots", "bubbles", "shots", "pickups", "world", "boss", "jar", "effects", "finish"], "Real main phase dispatch preserves complete source order")

func test_six_character_motion(game) -> void:
	for who in ["jp", "maya", "ama", "leo", "theo", "mei"]:
		var speed := 1.12 if who == "mei" else 1.0
		var jump := 1.09 if who == "ama" else 1.0
		fresh(game, who); stand(game, Vector2(2100, 482), 1800)
		game.step(0.01, {"right": true})
		check(near(game.player.x, 2100 + 270 * 0.55 * speed * 0.01), who + " mud scales base and post-passive speed")
		fresh(game, who); stand(game, Vector2(2100, 482), 1800)
		game.world_three.tied = 1
		game.step(0.01, {"right": true, "jump": true})
		check(game.grounded and game.velocity.y == 0 and near(game.player.x, 2100 + 270 * 0.55 * 0.45 * speed * 0.01), who + " tie blocks normal jump and compounds mud speed")
		check(near(game.world_three.tied, 0.99), who + " late tie countdown after movement")
		fresh(game, who); stand(game, Vector2(2100, 482), 1800)
		game.step(0.01, {"right": true, "jump": true})
		check(near(game.player.y, 482 + (-980 * 0.84 + 33) * 0.01) and near(game.velocity.y, (-980 * 0.84 + 33) * jump), who + " mud jump gravity precedes Ama post-multiplier without retroactive displacement")
		check(near(game.player.x, 2100 + 270 * (0.55 + speed - 1) * 0.01), who + " jumping loses mud for post-motion bonus only")
		fresh(game, who); stand(game, Vector2(2100, 482), 1800)
		game.power = "wellies"; game.power_time = 12
		game.step(0.01, {"right": true, "jump": true})
		check(near(game.player.x, 2100 + 270 * speed * 0.01) and near(game.velocity.y, (-980 + 33) * jump), who + " wellies removes both mud penalties before jump")
		fresh(game, who); stand(game, Vector2(2100, 482), 1800)
		game.power = "wellies"; game.power_time = 0.01
		game.step(0.01, {"right": true})
		check(game.power == "" and near(game.player.x, 2100 + 270 * 0.55 * speed * 0.01), who + " expiring wellies loses protection before same-frame base movement")
		fresh(game, who); stand(game, Vector2(2100, 370), 1800)
		game.power = "wellies"; game.power_time = 12; game.grounded = false; game.velocity.y = 101
		var enemy := bot(game, Vector2(2100, 482))
		game.step(0, {})
		check(enemy.state == "pop" and game.pop_count == 1 and game.velocity.y == -800, who + " actual combat wellies stomp rebounds and credits one pop")
		fresh(game, who); stand(game, Vector2(2100, 482), 1800)
		game.invincible = 1; game.bullets = [bill(game.player - Vector2(0, 60), true)]
		game.step(0.01, {})
		check(game.hearts == 3 and near(game.world_three.tied, 2.19), who + " invulnerable wristband still ties before late decrement")
	fresh(game, "mei"); stand(game, Vector2(2100, 482), 1800)
	game.abilities.active = "mei"; game.abilities.duration = 6; game.abilities.remaining = 6
	game.world_three.tied = 1
	game.step(0.01, {"right": true})
	check(near(game.player.x, 2100 + 270 * 1.72 * 0.55 * 0.45 * 0.01), "Mei active bonus also scales mud and tie in post-hook")
	fresh(game, "leo"); stand(game, Vector2(2100, 300), 1800)
	game.grounded = false; game.velocity.y = 500; game.world_three.tied = 1
	game.abilities.active = "leo"; game.abilities.duration = 5; game.abilities.remaining = 5
	game.step(0.01, {"right": true})
	check(near(game.player.x, 2100 + 270 * 1.35 * 0.45 * 0.01) and game.velocity.y == 70, "Airborne Leo bonus scales tie and glide cap follows base gravity")

func test_surfaces(game) -> void:
	fresh(game)
	var authored: String = JSON.stringify(game.level)
	var solid := {"row": [450.0, 500.0, 350.0], "plat": false}
	var deck := {"row": [550.0, 700.0, 300.0], "plat": true, "conv": 0.1, "dx": 0.0, "dy": 0.0}
	game.world_three.surfaces(game).append(solid); game.world_three.surfaces(game).append(deck)
	check(game.floor_at(475, 0) == 350 and game._land(475, 349, 351) == 350, "Main floor and land use live W3 solid")
	check(game._land(600, 299, 301) == 300 and game._land(600, 299, 301, true) == INF, "Main one-way land respects drop-through")
	check(game.skill_floor_below(600, 0) == 300 and game.ability_land_on(600, 299, 301) == 300, "Shared ability/skill queries use same W3 platform")
	check(game._wall_clamp(400, 470, 482) == 436 and game.skill_wall_clamp(400, 470, 482) == 436 and game.ability_inside_wall(Vector2(475, 355)), "Main wall clamp and ability solidity use W3 geometry")
	check(not game.ability_inside_wall(Vector2(600, 305)) and JSON.stringify(game.level) == authored, "Platform never becomes wall and runtime fixture leaves META immutable")
	stand(game, Vector2(600, 300)); game.on_platform = true
	game.step(0, {})
	deck.row[2] = 303.0; deck.dx = 2.0; deck.dy = 3.0
	game.step(0.01, {})
	check(game.player == Vector2(603, 303) and game.grounded, "Base+knockback then source conveyor/dx/dy carry before support query")
	deck.dx = 0; deck.dy = 0; deck.conv = 0
	game.world_three.tied = 1; game.jump_held = false
	game.step(0.01, {"jump": true, "down": true})
	check(not game.grounded and game.drop_time > 0 and game.player.y > 303, "Tied permits prior down+jump platform-drop branch")
	stand(game, Vector2(600, 303)); game.on_platform = true; deck.nodrop = true; game.world_three.tied = 1
	game.step(0.01, {"jump": true, "down": true})
	check(game.grounded and game.drop_time == 0, "nodrop platform plus tied blocks both jump/drop branches")
	# Restore a live platform then use the actual shared football landing path.
	deck.nodrop = false; stand(game, Vector2(300, 482))
	var effect := ball(Vector2(600, 280)); effect.v.y = 100; effect.free = 100
	game.abilities.effects = [effect]
	game.step(0.01, {})
	check(effect.p.y == 281 and effect.v.y == -620, "Football late bounce sees actual live W3 top303")

func test_shot_order_and_abilities(game) -> void:
	for ghost in [false, true]:
		fresh(game); arena(game)
		var point := Vector2(9200, 430)
		var enemy := bot(game, Vector2(9200, 482))
		var crate := {"p": Vector2(9200, 482), "hp": 3, "give": "heart", "broken": false, "hit": 0.0}
		game.crates.append(crate)
		game.world_three.surfaces(game).append({"row": [9160, 9240, 350], "plat": false})
		game.bullets = [shot(point, 1, ghost)]
		game.step(0, {})
		check(enemy.hp == 3 and game.boss.state.hp == 60 and crate.hp == 3 and game.bullets.is_empty(), str(ghost) + " bot precedes seller/crate/wall")
		game.enemies.clear(); game.bullets = [shot(point, 999, ghost)]
		game.step(0, {})
		check(game.boss.state.hp == 59 and crate.hp == 3 and game.bullets.is_empty(), str(ghost) + " seller ignores999damage and precedes crate/wall")
		game.boss.state.dizzy = 1; game.bullets = [shot(point, 999, ghost)]
		game.step(0, {})
		check(game.boss.state.hp == 57, str(ghost) + " dizzy seller takes exactly2")
		game.boss.state.state = "enter"; game.bullets = [shot(point, 999, ghost)]
		game.step(0, {})
		check(crate.hp == 2 and game.bullets.is_empty(), str(ghost) + " rejected seller shot gives crate fixed1 before wall")
		game.crates.clear(); game.bullets = [shot(point, 1, ghost)]
		game.step(0, {})
		check(game.bullets.is_empty(), str(ghost) + " remaining shot culled by wall after all hits")
	fresh(game, "ama"); arena(game)
	game.abilities.meter = 1
	game.step(0, {"special": true})
	check(game.boss.state.hp == 58 and game.boss.state.dizzy == 3.5, "Actual main Ama queues3damage ghost but seller takes fixed2")
	fresh(game, "maya"); stand(game, Vector2(300, 482))
	game.abilities.active = "maya"; game.abilities.duration = 6; game.abilities.remaining = 0.01
	game.bullets = [bill(game.player - Vector2(0, 81), true)]
	game.step(0.01, {})
	check(game.abilities.active == "" and game.hearts == 3 and game.world_three.tied == 0 and game.bullets.is_empty(), "Maya exact-expiry pre-step cancellation survives later bill phase")
	fresh(game); arena(game)
	game.boss.state.state = "throw"; game.boss.state.t = 0.31; game.boss.state.pending_throw = true
	game.step(0.01, {})
	check(game.bullets.size() == 3 and game.bullets.all(func(b): return b.enemy and b.tie and b.age == 0), "Late seller wristbands receive no same-frame projectile motion")
	var before: Vector2 = game.bullets[0].p
	game.step(0.01, {})
	check(game.bullets[0].age > 0 and game.bullets[0].p != before, "Seller wristbands first move on next frame")

func test_mini_lifecycle(game) -> void:
	fresh(game)
	stand(game, Vector2(9050, 482), 8639.999); game.world_three._scenes[1].done = true
	game.step(0, {})
	check(game.boss == null, "Seller entry not below8640camera")
	game.camera.x = 8640; game.step(0, {})
	check(game.boss != null and game.boss.state.hp == 60 and game.boss.state.kind == "seller" and game.camera_lock == 8900, "Actual late threshold creates60HPseller and8900lock")
	check(game.audio.starts == [false, true], "Seller entry requests boss soundtrack exactly once")
	var state: Dictionary = game.boss.state
	game.step(0, {})
	check(is_same(game.boss.state, state) and game.audio.starts == [false, true], "Repeat threshold does not replace boss or restart music")
	game.invincible = 999; advance(game, 0.61)
	check(state.state == "walk" and near(state.next, 1.6), "Actual main entry walks from first clamp into arena")
	state.hp = 1; state.dizzy = 0; state.next = 100; state.called = [true, true]; state.dz = true
	game.bullets = [shot(Vector2(state.x, 400), 500)]
	game.step(0, {})
	check(state.state == "down" and game.mode == "play" and game.coins.size() == 16, "Real last bullet defeats mini, drops coins, never clears level")
	check(game.audio.starts == [false, true, false], "Mini defeat resumes ordinary soundtrack")
	advance(game, 1.8)
	check(game.boss != null and state.jar.is_empty() and not game.world_three.mini_done, "Down mini remains through exact1.8seconds, no jar")
	game.step(0.001, {})
	check(game.boss == null and game.world_three.mini_done and game.camera_lock == null and game.mode == "play", "Strict mini departure unlocks path and records completion only")
	game.step(0, {})
	check(game.boss == null and not game.save.get("cleared", {}).get("3-1", false), "Completed mini never restarts or marks stage clear")

func test_checkpoint_and_receipts(game) -> void:
	fresh(game); stand(game, Vector2(7000, 482), 6700); game.hearts = 1
	game.step(0, {})
	check(game.hearts == 1 and not game.world_three.checkpoint_done, "Checkpoint strictly after player7000")
	game.player.x = 7000.001; game.bullets = [bill(game.player - Vector2(0, 80))]; game.hearts = 2
	game.step(0, {})
	check(game.hearts == 3 and game.world_three.checkpoint_done and game.invincible == 1.5, "Nonlethal combat hit occurs before checkpoint full heal/invulnerability")
	game.bullets = [bill(game.player - Vector2(0, 80))]; game.step(0.01, {})
	check(game.hearts == 3, "Checkpoint protection blocks following-frame bill")
	fresh(game); stand(game, Vector2(7001, 482), 6700); game.hearts = 1
	game.bullets = [bill(game.player - Vector2(0, 80))]; game.step(0, {})
	check(game.mode == "over" and game.hearts == 0 and not game.world_three.checkpoint_done, "Lethal solo bill leaves no living checkpoint crosser")
	fresh(game)
	for i in range(3):
		var point := Vector2(game.level.receipts[i][0], game.level.receipts[i][1])
		check(game.receipts[i].position == point, "Receipt%d native position is original source y" % i)
		stand(game, Vector2(point.x + 42, point.y + 100), maxf(0, point.x - 300)); game.grounded = false
		game.step(0, {})
		check(not game.receipts[i].taken, "Receipt%d excludes horizontal edge42" % i)
		game.player.x = point.x; game.step(0, {})
		check(game.receipts[i].taken and game.score == 0 and game.save.receipts["3-1"].has(i), "Receipt%d saves immediately with zero currency" % i)
	var disk: Dictionary = SaveStore.read_save()
	check(disk.receipts.get("3-1", []) == [0, 1, 2] and disk.kitty == 13, "Real save persists original three IDs without receipt rewards")
	game.load_level("3-1"); no_waves(game)
	check(game.receipts.all(func(r): return not r.taken and r.previously_collected), "Replay resets live receipts while retaining saved tint markers")

func test_transition_frames(game) -> void:
	fresh(game); mark_waves(game)
	game.world_three.mini_done = true; game.world_three._scenes[1].done = true
	stand(game, Vector2(15500, 482), float(game.level.w) - game.view_width())
	game.world_three.end_time = 2.6
	var enemy := bot(game, Vector2(15600, 482)); enemy.t = 0; enemy.cd = 100
	var old_coin := {"p": Vector2(15900, 400), "v": Vector2.ZERO, "age": 1.0, "rest": true}
	game.coins = [old_coin]; game.score = 7
	var hostile := bill(Vector2(15550, 300), true); hostile.v.x = 50
	var ghost := shot(Vector2(15400, 100), 1, true); ghost.ghost_age = 0.07
	game.bullets = [hostile, ghost, shot(Vector2(15600, 430), 4)]
	game.items = [{"p": Vector2(15900, 400), "vy": 0.0, "age": 0.0, "rest": true, "give": "heart"}]
	game.world_three.tied = 0.5
	game.abilities.effects = [ball(Vector2(15700, 200))]
	trace.clear(); game.step(0.01, {})
	check(game.mode == "clear" and game.save.get("cleared", {}).get("3-1", false), "Explicit end-time fixture clears via actual objective")
	check(enemy.state == "pop" and hostile.p.x == 15550.5 and near(game.items[0].age, 0.01), "Clear transition still executes bots/shots/items after stageClear")
	check(near(game.world_three.tied, 0.49), "Authorized final base step still executes late world tie clock after clear")
	check(game.score == 8 and game.save.kitty == 21 and game.coins.size() >= 4 and game.coins.size() <= 6, "Clear sweeps original coin once, later same-frame bot drops remain unbanked per source")
	check(game.abilities.effects[0].age == 0.01 and not game.bullets.has(ghost), "Clear transition unconditionally runs late ball and old ghost expiry")
	check(game.coins.all(func(coin): return near(coin.age, 0.01)) and game.bullets.any(func(b): return b.get("ghost", false) and near(b.ghost_age, 0.01)), "Final-base drop coins update now and new late-ball ghost ages now, without same-frame hit")
	check(trace.has(["bots", "clear"]) and trace.has(["world", "clear"]) and trace.has(["boss", "clear"]) and trace.has(["effects", "clear"]), "Phase probes see clear before remaining base and late wrapper")
	var frozen := JSON.stringify([enemy, game.items, game.world_three.tied, game.abilities.effects, game.bullets])
	game.step(1, {}); game.world_three.after_pickups(1, game)
	check(JSON.stringify([enemy, game.items, game.world_three.tied, game.abilities.effects, game.bullets]) == frozen, "Next clear frame and direct late world call cannot resume final-step permission")
	fresh(game); game.hearts = 1
	game.bullets = [bill(game.player - Vector2(0, 60), true)]
	var effect := ball(Vector2(600, 200)); game.abilities.effects = [effect]
	var old_ghost := shot(Vector2(500, 100), 1, true); old_ghost.ghost_age = 0.07; game.bullets.append(old_ghost)
	trace.clear(); game.step(0.01, {})
	check(game.mode == "over" and game.hearts == 0 and near(game.world_three.tied, 2.19), "Lethal band still ties and runs late world before global knockout")
	check(trace.has(["world", "play"]) and trace.has(["boss", "play"]) and trace.has(["effects", "over"]), "All-down occurs after base boss/jar and before unconditional effects")
	check(effect.age == 0.01 and not game.bullets.has(old_ghost), "Knockout transition advances ball and expires ghosts once")
	frozen = JSON.stringify([effect, game.world_three.tied, game.bullets])
	game.step(1, {})
	check(JSON.stringify([effect, game.world_three.tied, game.bullets]) == frozen, "Subsequent over frame freezes late effects and tie")

func test_pause_continue_and_wipes(game) -> void:
	fresh(game); arena(game)
	game.boss.state.hp = 37; game.world_three.tied = 0.8
	var enemy := bot(game, Vector2(9000, 482)); enemy.age = 2
	game._pause()
	var frozen := JSON.stringify([game.player, game.boss.state, game.world_three.tied, game.enemies, game.elapsed])
	game.step(1, {})
	check(game.mode == "paused" and game.audio.paused and JSON.stringify([game.player, game.boss.state, game.world_three.tied, game.enemies, game.elapsed]) == frozen, "Pause freezes complete encounter and audio")
	game._resume(); game.hearts = 1; game.invincible = 0
	game.bullets = [bill(game.player - Vector2(0, 80))]
	game.step(0, {})
	check(game.mode == "over" and game.boss.state.hp == 37, "Actual knockout retains damaged seller")
	var boss_state: Dictionary = game.boss.state
	var position: Vector2 = game.player
	var clock: float = game.world_three.level_time
	game._continue_level()
	check(game.mode == "play" and game.hearts == 3 and game.invincible == 2.5 and game.player == position, "Continue heals/invulnerable in place, no reload")
	check(is_same(game.boss.state, boss_state) and game.boss.state.hp == 37 and game.enemies.has(enemy) and game.world_three.level_time == clock, "Continue preserves actual boss/bot/time/identity")
	game.load_level("3-1")
	check(game.boss == null and game.world_three.tied == 0 and not game.world_three.mini_done and game.enemies.is_empty() and game.world_three.level_time == 0, "Fresh replay resets all encounter and tie state")
	fresh(game); stand(game, Vector2(7100, 482), 6800)
	game.step(0, {})
	check(game.world_three.wiping and game.world_three.wipe_kind == "door", "Actual source scene gate begins door with no active wave")
	game.step(0.01, {"right": true})
	check(game.player.x > 7100 and near(game.world_three.wipe_elapsed, 0.01), "W3 wipe leaves ordinary input and gameplay running")
	game._pause(); var age: float = game.world_three.wipe_elapsed; game.step(2, {}); game.world_three.finish_frame(game)
	check(game.world_three.wipe_elapsed == age and not game.world_three.wipe_midpoint_done, "Native reliability repair freezes wipe callback on pause")
	game._resume(); advance(game, 1.42)
	check(game.world_three.wipe_midpoint_done and near(game.camera.x, 7900), "1430ms actual post-frame door callback jumps to source7900")
	var generation: int = game.world_three.run_generation
	game.load_level("3-1"); var new_player: Vector2 = game.player
	check(not game.world_three._apply_scene_transition(game, generation) and game.player == new_player, "Previous-run wipe callback rejected after replay generation changes")
	fresh(game); stand(game, Vector2(7100, 482), 6800); game.step(0, {})
	advance(game, 1.42); game.hearts = 1; game.invincible = 0
	game.bullets = [bill(game.player - Vector2(0, 70))]; game.step(0.01, {})
	check(game.mode == "over" and not game.world_three.wipe_midpoint_done, "Due scene callback remains pending when base frame knocks player out")
	game._continue_level(); game.step(0, {})
	check(game.world_three.wipe_midpoint_done and near(game.camera.x, 7900), "Continue resumes same pending scene callback rather than discarding it")

func test_render(game) -> void:
	fresh(game); arena(game); bot(game, Vector2(9100, 482))
	game.bullets = [bill(Vector2(9100, 300), true)]
	game.world_three.tied = 1
	game.festival_renderer.draw_calls.clear()
	game.queue_redraw(); await process_frame; await process_frame
	var calls: Array = game.festival_renderer.draw_calls
	check(calls.has("sky") and calls.has("level") and calls.has("finds") and calls.has("boss") and calls.has("bot") and calls.has("bill") and calls.has("front"), "Actual main render dispatches festival paintings/finds/boss/bot/band/front")
	check(calls.find("boss") < calls.find("bot") and calls.find("bot") < calls.find("bill") and calls.find("player_back") < calls.find("player_front"), "Actual renderer ordering matches source boss/bots/players/bills")
	var state := JSON.stringify([game.boss.state, game.enemies, game.bullets, game.player, game.world_three.tied])
	game.queue_redraw(); await process_frame; await process_frame
	check(JSON.stringify([game.boss.state, game.enemies, game.bullets, game.player, game.world_three.tied]) == state, "Repeated painting never advances combat/animations/tie")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Festival integration: main script failed to load"); game.free(); quit(1); return
	root.add_child(game); game.set_physics_process(false)
	game.audio.shutdown(); game.audio.queue_free(); game.audio = AudioLog.new()
	game.world_three = ProbeWorld.new(); game.world_three.trace = trace
	game.festival_combat = ProbeCombat.new(); game.festival_combat.trace = trace
	game.abilities = ProbeAbilities.new(); game.abilities.trace = trace
	game.festival_field_renderer = ProbePainter.new()
	game.festival_renderer = game.festival_field_renderer
	test_selection(game)
	test_six_character_motion(game)
	test_surfaces(game)
	test_shot_order_and_abilities(game)
	test_mini_lifecycle(game)
	test_checkpoint_and_receipts(game)
	test_transition_frames(game)
	test_pause_continue_and_wipes(game)
	await test_render(game)
	game.queue_free(); await process_frame
	print("Festival main integration: ", checks, " checks, ", failures.size(), " failures (focused fixtures, not full progression)")
	quit(0 if failures.is_empty() else 1)
