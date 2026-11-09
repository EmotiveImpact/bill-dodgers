extends SceneTree
## Real main/session scheduler boundary fixtures. Trace wrappers always call the
## production implementation. W4 must pass the real hidden allowlist and loader;
## no fixture changes admission, initialization, step or gameplay logic.
const Main = preload("res://src/main.gd")
const Session = preload("res://src/party_session.gd")
const World = preload("res://src/world_four.gd")
const Combat = preload("res://src/holiday_combat.gd")
const AI = preload("res://src/companion_ai.gd")

class TraceWorld extends World:
	var trace: Array = []
	func pre_motion(dt, host): trace.append("pre"); super.pre_motion(dt, host)
	func before_combat(dt, host): trace.append("world"); super.before_combat(dt, host)
	func boss_tick(dt, host): trace.append("boss"); super.boss_tick(dt, host)
	func jar_tick(dt, host): trace.append("jar"); return super.jar_tick(dt, host)
	func finish_frame(host): trace.append("finish"); super.finish_frame(host)
class TraceCombat extends Combat:
	var trace: Array = []
	func waves_tick(dt, host): trace.append("waves"); super.waves_tick(dt, host)
	func enemies_tick(dt, host): trace.append("enemies"); super.enemies_tick(dt, host)
	func projectiles_tick(dt, host): trace.append("shots"); super.projectiles_tick(dt, host)
	func pickups_tick(dt, host): trace.append("pickups"); super.pickups_tick(dt, host)
	func visuals_tick(dt, host): trace.append("visuals"); super.visuals_tick(dt, host)
class TraceAI extends AI:
	var trace: Array = []
	var snapshot: Dictionary = {}
	func controls(dt, actor, context):
		trace.append("cpu")
		snapshot = {"leader": context.actors[0].player, "mate": actor.player}
		return super.controls(dt, actor, context)
class TraceSession extends Session:
	var trace: Array = []
	func _effects(host, dt): trace.append("effects:%d" % bridge.active_slot); super._effects(host, dt)
class TraceMain extends Main:
	var trace: Array = []
	func _actor_step(dt, controls): trace.append("actor:%d" % party_session.active_slot); super._actor_step(dt, controls)
	func _update_camera(dt): trace.append("camera"); super._update_camera(dt)
	func scene_objective(dt): trace.append("objective"); super.scene_objective(dt)
	func collect_level_pickups(): trace.append("picks:%d" % combat_owner_slot()); super.collect_level_pickups()
	func holiday_dash_step(): trace.append("dash:%d" % combat_owner_slot()); super.holiday_dash_step()
	func combat_bubbles_tick(dt): trace.append("bubbles"); super.combat_bubbles_tick(dt)
	func _expire_ability_zaps(dt): trace.append("expire"); super._expire_ability_zaps(dt)

var game
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func start(id: String, mode := "p2", mate := "maya", skills: Array = []) -> void:
	game._show_menu()
	game.character = "jp"
	game.save = {"schema": 1, "receipts": {}, "skills": skills, "seen": {}}
	check(game.configure_party(mode, mate), id + " explicit source mode accepted")
	check(game.load_level(id), id + " production metadata loaded")
	game.trace.clear()
func run() -> void:
	game = TraceMain.new()
	game.world_four = TraceWorld.new()
	game.holiday_combat = TraceCombat.new()
	game.party_session = TraceSession.new()
	game.party_session.ai = TraceAI.new()
	game.world_four.trace = game.trace
	game.holiday_combat.trace = game.trace
	game.party_session.trace = game.trace
	game.party_session.ai.trace = game.trace
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	_test_frame_order()
	_test_cpu_premotion()
	_test_pickups_and_dash()
	_test_water_and_lifecycle()
	_test_captain_and_clear()
	_test_all_stage_smoke()
	game.queue_free()
	await process_frame
	print("Holiday actual-main party: %d checks, %d failures. Explicit phase/lifecycle fixtures, not complete party routes." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_frame_order() -> void:
	start("4-1")
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	check(s.active and s.runtime.actors.size() == 2 and game.combat.participant_count == 2, "actual loader creates2 actors and source pair waves")
	var before1: Vector2 = p1.player
	var before2: Vector2 = p2.player
	s.step(game, 0.016, {"right": true, "shoot": true}, {"left": true, "shoot": true})
	check(game.trace == ["pre", "actor:0", "actor:1", "camera", "waves", "objective", "world", "picks:0", "picks:1", "dash:0", "dash:1", "enemies", "bubbles", "shots", "pickups", "boss", "jar", "visuals", "effects:0", "effects:1", "expire", "finish"], "exact source W4 scheduler phase order with no duplicate shared pass")
	check(is_equal_approx(game.elapsed, 0.016) and is_equal_approx(game.world_four.level_time, 0.016), "host and W4 clocks each advance once")
	check(is_equal_approx(p1.player.x, before1.x + 4.32) and is_equal_approx(p2.player.x, before2.x - 4.32), "independent human motion runs once per actor")
	check(game.bullets.filter(func(shot): return not shot.enemy and shot.owner_slot == 0).size() == 1 and game.bullets.filter(func(shot): return not shot.enemy and shot.owner_slot == 1).size() == 1, "actual normal fire stamps both owner slots")
	check(is_equal_approx(p1.abilities._time, 0.016) and is_equal_approx(p2.abilities._time, 0.016), "both actor ability clocks run once")
	check(game.receipts.all(func(receipt): return is_equal_approx(receipt.age, 0.016)), "receipt presentation clock advances once globally")
	check(game.player == p1.player and game.character == "jp" and not s.bridge.shared_phase, "final facade and bridge restore P1")
	# Real native event flow, not controls dictionaries for the independent key.
	game._physics_process(0.016)
	before1 = p1.player
	before2 = p2.player
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	game._physics_process(0.016)
	check(p1.player == before1 and p2.player.x > before2.x, "real engine D key moves P2 without changing P1")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	game._physics_process(0.016)

func _test_cpu_premotion() -> void:
	start("4-5", "cpu")
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	var deck: Dictionary = game.world_four.deck
	check(p1.player.x == deck.row[0] + 120 and p2.player.x == deck.row[0] + 210, "actual start executes source pedalo slot-placement hook")
	game.camera.x = 100
	var before: Vector2 = p1.player
	game.step(0.016, {"right": true})
	check(game.trace.slice(0, 4) == ["pre", "cpu", "actor:0", "actor:1"], "W4 carry precedes all CPU decisions and actor motion")
	check(is_equal_approx(s.ai.snapshot.leader.x, before.x + 100) and is_equal_approx(s.ai.snapshot.leader.y, deck.row[2]), "CPU observes newly moved deck carry before player controls")
	check(game.trace.count("dash:1") == 0 and game.trace.count("dash:0") == 1, "CPU never receives W4 early Dash callback")
	check(is_equal_approx(game.world_four.level_time, 0.016) and game.camera.x > 100, "pre-motion and camera each advance once in source order")

func _test_pickups_and_dash() -> void:
	start("4-4", "p2", "maya", ["dash"])
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	game.step(0.016, {"dash": true})
	check(p1.movement_skills.dash_cooldown == 0.6 and p2.movement_skills.dash_cooldown <= 0, "actual early W4 Dash only activates requested actor")
	game.step(0.016, {})
	check(is_equal_approx(p1.movement_skills.dash_cooldown, 0.584), "early Dash cooldown decrements once with no duplicate late pass")
	start("4-1")
	s = game.party_session
	p1 = s.runtime.actors[0]
	p2 = s.runtime.actors[1]
	p2.player = game.receipts[0].position
	p2.grounded = true
	s.bind(game, 0)
	game.step(0.016, {})
	check(game.receipts[0].taken and game.score == 5 and game.receipt_score == 5, "real P2 physically collects receipt with one shared reward")
	check(p1.coins == 0 and p2.coins == 0 and game.save.receipts["4-1"] == [0], "receipt reward remains distinct from both personal coin counters")
	check(game.receipts[0].age == 0 and is_equal_approx(game.receipts[1].age, 0.016), "P2 pickup resets only its physical receipt age after one shared tick")

func _test_water_and_lifecycle() -> void:
	start("4-5")
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	p2.player.y = game.world_four.cfg.water + 21
	p2.grounded = false
	p2.invincible = 100
	game.step(0.016, {})
	check(p1.hearts == 3 and p2.hearts == 2 and p2.grounded, "actual pre-motion rescues and damages only P2")
	check(is_equal_approx(p2.invincible, 1.484), "water damage invulnerability decrements in following actor phase")
	check(p2.abilities._hits == 1 and p1.abilities._hits == 0, "actual water hit binds Maya passive exactly once")
	var time: float = game.world_four.level_time
	var position: Vector2 = p2.player
	game.mode = "paused"
	game.step(0.2, {"right": true})
	check(game.world_four.level_time == time and p2.player == position, "pause freezes W4 and all actor movement")
	game.mode = "play"
	# Source does not carry downed actors. An authored banana pause keeps
	# the deck nearby long enough for rescue, without changing actor positions.
	game.world_four.spawn_foe("r", "banana", game)
	p1.mark_down()
	p1.player = p2.player - Vector2(30, 0)
	s.bind(game, 0)
	for i in 90: game.step(1.0 / 60, {})
	check(not p1.down and p1.hearts == 2 and game.mode == "play", "downed P1 rescued by P2 while source banana camera pause keeps deck in reach")
	p1.mark_down()
	p2.mark_down()
	s.bind(game, 0)
	game.step(0.016, {})
	check(game.mode == "over", "all-down after W4 base frame opens Continue")
	time = game.world_four.level_time
	var cam: Vector2 = game.camera
	game._continue_level()
	check(game.mode == "play" and p1.hearts == 3 and p2.hearts == 3 and not p1.down and not p2.down, "actual Continue revives both actors")
	check(game.world_four.level_time == time and game.camera == cam, "Continue preserves W4 deck/encounter timeline")

func _test_captain_and_clear() -> void:
	start("4-6")
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	game.camera.x = game.level.w - game.view_width()
	for wave in game.combat.waves: wave.done = true
	p1.player = Vector2(game.camera.x + 100, 482)
	p2.player = Vector2(game.camera.x + 400, 482)
	s.bind(game, 0)
	game.step(0.016, {})
	check(game.boss == game.world_four.captain and game.boss.state.max == 120, "actual shared W4 hook starts120HP party Captain")
	var boss: Dictionary = game.boss.state
	boss.state = "drift"
	boss.x = game.camera.x + 500
	s.bridge.begin_shared(0)
	s.bridge.call_for_actor(1, game.damage_boss, [50])
	s.bridge.end_shared(0)
	check(game.bullets.any(func(shot): return not shot.enemy and shot.get("ghost", false) and shot.owner_slot == 1), "real P2 special damage emits owner-stamped source ghost")
	game.step(0.016, {})
	check(boss.hp == 119 and p2.scene_state.boss_hits == 1 and not p1.scene_state.has("boss_hits"), "real shared projectile phase credits P2 Captain hit with fixed damage")
	# Explicit objective-order setup: the jar can settle clear before all-down.
	p1.mark_down()
	p2.player = Vector2(game.camera.x + 400, 482)
	game.world_four.captain.jar = {"p": Vector2(p2.player.x, 452), "v": Vector2.ZERO, "t": 0.61, "got": false}
	boss.state = "down"
	s.bind(game, 0)
	game.step(0.016, {})
	check(game.mode == "clear" and game.save.cleared.get("4-6", false), "living P2 jar pickup executes normal party clear/save")
	check(not p1.down and p1.hearts == 1 and p1.player_animation == "win" and p2.player_animation == "win", "clear settles both real actors and revives P1")

func _test_all_stage_smoke() -> void:
	for id in World.SUPPORTED_LEVELS:
		start(id, "cpu", "ama")
		game.step(0.016, {})
		check(game.mode == "play" and game.party_session.active and game.combat.participant_count == 2, id + " real CPU party frame supported")
		check(is_equal_approx(game.elapsed, 0.016) and is_equal_approx(game.world_four.level_time, 0.016), id + " clocks stay single-step")
		check(game.character == "jp" and game.player == game.party_session.runtime.actors[0].player, id + " final facade restored")
