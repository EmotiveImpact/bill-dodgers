extends SceneTree
## Real main/session scheduler fixtures, including production party admission.
## Trace subclasses record phase calls without replacing start or simulation.
const Main = preload("res://src/main.gd")
const Session = preload("res://src/party_session.gd")
const World = preload("res://src/world_five.gd")
const Combat = preload("res://src/moving_day_combat.gd")
const AI = preload("res://src/companion_ai.gd")
class TraceWorld extends World:
	var trace: Array = []
	func before_camera(dt, host, controls = {}): trace.append("world"); super.before_camera(dt, host, controls)
	func finish_frame(host): trace.append("finish"); super.finish_frame(host)
class TraceCombat extends Combat:
	var trace: Array = []
	func waves_tick(dt, host): trace.append("waves"); super.waves_tick(dt, host)
	func enemies_tick(dt, host): trace.append("enemies"); super.enemies_tick(dt, host)
	func projectiles_tick(dt, host): trace.append("shots"); super.projectiles_tick(dt, host)
	func pickups_tick(dt, host): trace.append("pickups"); super.pickups_tick(dt, host)
	func boss_tick(dt, host): trace.append("boss"); return super.boss_tick(dt, host)
	func jar_tick(dt, host): trace.append("jar"); return super.jar_tick(dt, host)
	func visuals_tick(dt, host): trace.append("visuals"); super.visuals_tick(dt, host)
class TraceAI extends AI:
	var trace: Array = []
	var snapshot: Dictionary = {}
	func controls(dt, actor, context):
		trace.append("cpu")
		snapshot = {"leader": context.actors[0].player, "mate": actor.player}
		return super.controls(dt, actor, context)
class FixtureSession extends Session:
	var trace: Array = []
	func _effects(host, dt): trace.append("effects:%d" % bridge.active_slot); super._effects(host, dt)
	func _late_skill(host): trace.append("skill:%d" % bridge.active_slot); super._late_skill(host)
class TraceMain extends Main:
	var trace: Array = []
	func _actor_step(dt, controls): trace.append("actor:%d" % party_session.active_slot); super._actor_step(dt, controls)
	func _update_camera(dt): trace.append("camera"); super._update_camera(dt)
	func scene_objective(dt): trace.append("objective"); super.scene_objective(dt)
	func collect_level_pickups(): trace.append("picks:%d" % combat_owner_slot()); super.collect_level_pickups()
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
	check(game.configure_party(mode, mate), id + " explicit pair mode accepted")
	check(game.load_level(id), id + " actual source metadata loaded")
	game.trace.clear()
func place(actor, position: Vector2) -> void:
	actor.player = position; actor.velocity = Vector2.ZERO; actor.grounded = true; actor.on_platform = false
	actor.hurt_lock = 0; actor.invincible = 0; actor.hearts = 3; actor.down = false
	actor.scene_state.safe_position = position
func run() -> void:
	game = TraceMain.new()
	game.world_five = TraceWorld.new()
	game.moving_day_combat = TraceCombat.new()
	game.party_session = FixtureSession.new()
	game.party_session.ai = TraceAI.new()
	game.world_five.trace = game.trace
	game.moving_day_combat.trace = game.trace
	game.party_session.trace = game.trace
	game.party_session.ai.trace = game.trace
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	_test_order_and_input()
	_test_sofa_and_scenes()
	_test_pickups_and_lift()
	_test_lifecycle()
	_test_abilities_and_king()
	_test_all_stage_smoke()
	game.queue_free()
	await process_frame
	print("Moving Day actual-main party: %d checks, %d failures. Scheduler/lifecycle fixtures, not complete party routes." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _test_order_and_input() -> void:
	start("5-1")
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	check(s.active and s.runtime.actors.size() == 2 and game.combat.participant_count == 2, "actual loader creates both actors and scaled combat")
	var first: Vector2 = p1.player
	var second: Vector2 = p2.player
	s.step(game, 0.016, {"right": true, "shoot": true}, {"left": true, "shoot": true})
	check(game.trace == ["actor:0", "actor:1", "world", "picks:0", "picks:1", "camera", "waves", "objective", "enemies", "bubbles", "shots", "pickups", "skill:0", "skill:1", "boss", "jar", "visuals", "effects:0", "effects:1", "expire", "finish"], "exact source W5 phase order and no duplicate world simulation")
	check(is_equal_approx(game.elapsed, 0.016) and is_equal_approx(game.world_five.level_time, 0.016), "shared host and W5 clocks tick once")
	check(is_equal_approx(p1.player.x, first.x + 4.32) and is_equal_approx(p2.player.x, second.x - 4.32), "both human actors move independently once")
	check(game.bullets.filter(func(q): return not q.enemy and q.owner_slot == 0).size() == 1 and game.bullets.filter(func(q): return not q.enemy and q.owner_slot == 1).size() == 1, "real normal fire stamps both firing slots")
	check(is_equal_approx(p1.abilities._time, 0.016) and is_equal_approx(p2.abilities._time, 0.016), "each actor owns one ability clock")
	check(game.receipts.all(func(r): return is_equal_approx(r.age, 0.016)), "receipt presentation ages once globally")
	check(game.player == p1.player and game.character == "jp" and not s.bridge.shared_phase, "P1 facade restored after real frame")
	game._physics_process(0.016)
	first = p1.player; second = p2.player
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D; key.keycode = KEY_D; key.pressed = true
	Input.parse_input_event(key); Input.flush_buffered_events()
	game._physics_process(0.016)
	check(p1.player == first and p2.player.x > second.x, "engine D event controls only real P2")
	key = key.duplicate(); key.pressed = false
	Input.parse_input_event(key); Input.flush_buffered_events(); game._physics_process(0.016)
	start("5-1", "cpu")
	s = game.party_session; p1 = s.runtime.actors[0]
	first = p1.player
	game.step(0.016, {"right": true})
	check(game.trace.slice(0, 4) == ["cpu", "actor:0", "actor:1", "world"], "W5 CPU intent sampled before every actor and shared world")
	check(s.ai.snapshot.leader == first and p1.player.x > first.x, "CPU sees old leader position rather than future movement")
func _test_sofa_and_scenes() -> void:
	start("5-2")
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	game.camera.x = 2400
	place(p1, Vector2(2500, 482)); place(p2, Vector2(2940, 482)); s.bind(game, 0)
	game.world_five.sofa.x = 2940
	for i in 46: s.step(game, 0.01, {}, {"down": true})
	check(game.world_five.sofa.tip, "P2 actual independent down control tips sofa")
	check(not p1.scene_state.carrying and p2.scene_state.carrying and not game.world_five.carrying, "source carry flag independently persists and restores P1")
	var first: Vector2 = p1.player
	var second: Vector2 = p2.player
	s.step(game, 0.01, {"right": true}, {"right": true})
	check(absf(p1.player.x - first.x - 2.7) < 0.001 and absf(p2.player.x - second.x - 2.106) < 0.001, "next actor frame applies carry slowdown only to carrier")
	p2.mark_down(); s.bind(game, 0)
	game.world_five._start_wipe(game, {"to": 4910.0})
	game.world_five.wipe_elapsed = game.world_five.WIPE_CALLBACK - 0.005
	game.trace.clear()
	game.step(0.01, {})
	check(p1.player.x == 4910 and p2.player.x == 4970 and game.world_five.scene_index == 1, "real final-frame wipe moves both actors at source spacing")
	check(p2.down and p2.hearts == 0 and p2.grounded, "real wipe relocates downed mate without accidental revival")
	check(game.player == p1.player and game.trace[-1] == "finish", "wipe proxy mutations reconcile before final P1 restore")
	check(game.world_five.sofa.x == 5110, "sofa shares single scene transition")
func _test_pickups_and_lift() -> void:
	start("5-1")
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	place(p2, game.receipts[0].position); s.bind(game, 0)
	game.step(0.016, {})
	check(game.receipts[0].taken and game.save.receipts["5-1"] == [0], "real P2 collects repaired x60 receipt with original save index")
	check(game.score == 0 and game.receipt_score == 0 and p1.coins == 0 and p2.coins == 0, "W5 physical receipts award no kitty or personal coins")
	check(game.receipts[0].age == 0 and is_equal_approx(game.receipts[1].age, 0.016), "P2 receipt reset occurs after one shared age increment")
	start("5-4")
	s = game.party_session; p1 = s.runtime.actors[0]; p2 = s.runtime.actors[1]
	game.camera.x = 3300
	place(p1, Vector2(3380, 482)); place(p2, Vector2(game.level.card[0], game.level.card[1])); s.bind(game, 0)
	game.step(0.016, {})
	check(game.save.skills.has("wall-jump"), "P2 collects authored wall-jump card through real save flow")
	check(p1.movement_skills.skills.has("wall-jump") and p2.movement_skills.skills.has("wall-jump"), "actually collected card shared with both movement-skill instances")
	start("5-3")
	s = game.party_session; p1 = s.runtime.actors[0]; p2 = s.runtime.actors[1]
	var q: Dictionary = game.world_five.lift.surface
	place(p1, Vector2(q.row[0] + 40, q.row[2])); place(p2, Vector2(q.row[0] + 100, q.row[2])); s.bind(game, 0)
	game.world_five.lift.state = "move"; game.world_five.lift.to = q.row[2] - 330
	var y: float = q.row[2]
	game.step(0.016, {})
	check(is_equal_approx(q.row[2], y - 2.56) and is_equal_approx(p1.player.y, q.row[2]) and is_equal_approx(p2.player.y, q.row[2]), "actual shared lift carries both actors once after movement")
	check(is_equal_approx(game.world_five.lift.t, 0.016), "real lift clock advances once")
func _test_lifecycle() -> void:
	start("5-2")
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	var x: float = game.level.check
	game.camera.x = x - 300
	place(p1, Vector2(x - 100, 482)); p1.mark_down()
	place(p2, Vector2(x + 1, 482)); s.bind(game, 0)
	game.step(0.016, {})
	check(not p1.down and p1.hearts == 3 and p1.invincible == 1.2 and p2.hearts == 3, "actual checkpoint restores downed P1 after P2 trigger")
	var time: float = game.world_five.level_time
	var position: Vector2 = p2.player
	game.mode = "paused"; game.step(0.2, {"right": true})
	check(game.world_five.level_time == time and p2.player == position, "pause freezes all W5 actors and world")
	game.mode = "play"
	place(p1, Vector2(x - 100, 482)); p1.mark_down(); place(p2, Vector2(x - 70, 482)); s.bind(game, 0)
	for i in 85: game.step(1.0 / 60, {})
	check(not p1.down and p1.hearts == 2 and game.mode == "play", "real P2 can rescue downed P1 on W5 floor")
	# Continue's W5 checkpoint rescue is a once-shared record transaction.
	place(p1, Vector2(x - 100, 482)); place(p2, Vector2(x - 70, 482))
	p1.mark_down(); p2.mark_down(); s.bind(game, 0)
	game.step(0.016, {})
	check(game.mode == "over", "all-down opens actual Continue")
	time = game.world_five.level_time
	game._continue_level()
	check(game.mode == "play" and p1.hearts == 3 and p2.hearts == 3 and not p1.down and not p2.down, "Continue revives both source actors")
	check(p1.player.x == x and p2.player.x == x and game.player == p1.player, "Continue moves both slots to preserved checkpoint and restores P1")
	check(game.world_five.level_time == time and p1.invincible == 2.5 and p2.invincible == 2.5, "Continue preserves world clock and gives both own protection")
func _test_abilities_and_king() -> void:
	start("5-6", "p2", "ama")
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	game.camera.x = game.level.w - game.view_width()
	place(p1, Vector2(3800, 482)); place(p2, Vector2(4000, 482)); s.bind(game, 0)
	game.combat.start_boss(game)
	var k: Dictionary = game.boss.state
	k.state = "walk"; k.x = 4100
	p2.abilities.meter = 1.0
	s.step(game, 0.016, {}, {"special": true})
	check(k.hp < 34 and is_finite(k.fy) and k.fy == 482 and k.dizzy > 3, "actual P2 Ama special uses repaired finite King feet and source dizzy damage")
	check(p2.scene_state.get("boss_hits", 0) > 0 and p1.scene_state.get("boss_hits", 0) == 0, "P2 Ama ghost hit credits original P2 only")
	check(p2.abilities.active == "ama" and p1.abilities.active == "", "special activation belongs to P2 instance")
	# Ama-held enemy follows one shared bubble clock and ownership.
	var enemy: Dictionary = game.combat.new_bot(game, 4000, game.world_five.surfaces(game)[-1], "rush", {"hp": 3})
	enemy.p = Vector2(4000, 482); enemy.ab_bubble = 1.0; enemy.ab_bubble_total = 1.0; enemy.ab_floor = 482.0; enemy.ab_bubble_owner = 1
	var before: float = enemy.ab_bubble
	game.step(0.016, {})
	check(is_equal_approx(enemy.ab_bubble, before - 0.016), "one global held-enemy bubble clock not twice per party")
	p1.mark_down(); s.bind(game, 0)
	k.state = "down"; k.jar = {"x": p2.player.x, "y": 452.0, "vy": 0.0, "vx": 0.0, "t": 0.61, "got": false}
	game.enemies.clear(); game.bullets.clear()
	game.step(0.016, {})
	check(game.mode == "clear" and game.save.cleared.get("5-6", false), "living P2 physical King jar runs normal completion/save")
	check(not p1.down and p1.hearts == 1 and p1.player_animation == "win" and p2.player_animation == "win", "jar clear settles and celebrates both actors")
	start("5-S")
	for wave in game.combat.waves: wave.done = true; wave.started = true
	game.world_five.clock_left = 0; game.world_five.end_time = 2.599
	game.step(0.01, {})
	check(game.mode == "clear" and game.trace.count("enemies") == 1 and game.trace.count("boss") == 1 and game.trace.count("effects:1") == 1, "final W5 objective retains late base phases and both effects before clear")
func _test_all_stage_smoke() -> void:
	for id in World.SUPPORTED_LEVELS:
		for mode in ["cpu", "p2"]:
			start(id, mode, "ama")
			game.step(0.016, {})
			check(game.mode == "play" and game.party_session.active and game.combat.participant_count == 2, id + mode + " actual party frame")
			check(is_equal_approx(game.elapsed, 0.016) and is_equal_approx(game.world_five.level_time, 0.016), id + mode + " one shared clock")
			check(game.character == "jp" and game.player == game.party_session.runtime.actors[0].player, id + mode + " final restored facade")
