extends SceneTree
## Actual-main W3 party fixtures. Production initialization is used when admitted;
## dormant-session fallback is a focused fixture, not complete route acceptance.
var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func near(a: float, b: float, tolerance := 0.001) -> bool: return absf(a - b) < tolerance

func pair(id := "3-1", mode := "p2", mate := "maya") -> void:
	game._show_menu()
	game.character = "jp"
	game.save = {"schema": 1, "receipts": {}, "skills": [], "seen": {}}
	game.configure_party(mode, mate)
	game.load_level(id)
	var session = game.party_session
	# Test-only explicit setup while native selection remains hidden. Production
	# start() owns this initialization after integration is admitted normally.
	if not session.active:
		session.active = true
		session.runtime.start(id, game.player, [])
		for actor in session.runtime.actors:
			actor.player.y = game.floor_at(actor.player.x, game.player.y - 10)
			actor.checkpoint = actor.player
			actor._last_floor = actor.player.y
			actor.scene_state = {"safe_position": actor.player, "tied": 0.0, "standing_surface": {}}
		session.bind(game, 0)
		session.bridge.configure(session.runtime, game)
		game.combat.reset(game, 2, 31)
	game._step_delta = 0

func actor(slot: int): return game.party_session.runtime.actors[slot]
func bind_leader() -> void: game.party_session.bind(game, 0)
func begin_shared() -> void:
	bind_leader()
	game.party_session.bridge.begin_shared(0)
func end_shared() -> void: game.party_session.bridge.end_shared(0)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	_test_frame_clocks()
	_test_ties_and_recovery()
	_test_low_banners()
	_test_checkpoint_and_finds()
	_test_surface_carry()
	_test_hayride_carry_and_transition()
	_test_scene_jump()
	_test_cpu_and_downed_timers()
	_test_lifecycle()
	game.queue_free()
	await process_frame
	print("Festival party world: %d checks, %d failures. Explicit actual-host fixtures, not full party routes." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_frame_clocks() -> void:
	for id in ["3-1", "3-2", "3-3", "3-4", "3-5", "3-6", "3-S"]:
		pair(id)
		game.party_session.step(game, 0.016, {"shoot": true}, {"shoot": true})
		check(near(game.elapsed, 0.016) and near(game.world_three.level_time, 0.016), id + " shared elapsed advances once")
		check(near(actor(0).abilities._time, 0.016) and near(actor(1).abilities._time, 0.016), id + " each ability effect clock advances once")
		check(game.bullets.any(func(b): return not b.enemy and b.owner_slot == 0) and game.bullets.any(func(b): return not b.enemy and b.owner_slot == 1), id + " both ordinary actors fire owned shots")
		check(game.player == actor(0).player and game.character == "jp" and not game.party_session.bridge.shared_phase, id + " final facade and phase restore")
		if id == "3-S": check(near(game.world_three.bonus.timer_elapsed, 0.016), "bonus clock is not doubled by per-actor finds")
		if id == "3-5": check(game.world_three.trailer.dx == 0, "hayride warmup keeps shared trailer still")

func _test_ties_and_recovery() -> void:
	pair()
	actor(0).player = Vector2(500, 482)
	actor(1).player = Vector2(600, 482)
	actor(0).invincible = 2.0
	actor(1).invincible = 2.0
	bind_leader()
	game.bullets = [{"p": Vector2(600, 400), "v": Vector2.ZERO, "gravity": 0.0, "enemy": true, "tie": true, "life": 20.0}]
	game.party_session.step(game, 0.01, {}, {})
	check(near(actor(1).scene_state.tied, 2.19) and actor(0).scene_state.tied == 0, "P2 tie survives projectile and late phase in its own actor state")
	check(actor(1).hearts == 3 and game.world_three.tied == 0, "invulnerability rejects harm but not tie, and leader facade stays untied")
	var p1: Vector2 = actor(0).player
	var p2: Vector2 = actor(1).player
	game.party_session.step(game, 0.01, {"right": true}, {"right": true, "jump": true})
	check(near(actor(0).player.x - p1.x, 2.7) and near(actor(1).player.x - p2.x, 1.215), "only tied actor gets source 0.45 horizontal speed")
	check(actor(1).grounded and near(actor(1).scene_state.tied, 2.18), "P2 normal jump is blocked and tied clock decrements once")
	actor(1).scene_state.tied = 0.005
	game.party_session.step(game, 0.01, {}, {})
	check(actor(1).scene_state.tied == 0, "tie clamps at zero without affecting another actor")
	actor(0).scene_state.safe_position = Vector2(500, 482)
	actor(1).scene_state.safe_position = Vector2(600, 482)
	actor(1).player = Vector2(700, 900)
	actor(1).grounded = false
	actor(1).invincible = 100
	bind_leader()
	game.party_session.step(game, 0, {}, {})
	check(actor(1).player == Vector2(600, 482) and actor(1).hearts == 2 and actor(0).hearts == 3, "P2 recovery uses its own safe x and forced victim damage")
	check(actor(0).scene_state.safe_position.x != actor(1).scene_state.safe_position.x and actor(1).velocity == Vector2.ZERO, "recovery cannot replace P1 safe point or retain P2 knockback")

func _test_low_banners() -> void:
	for id in ["3-2", "3-5"]:
		pair(id)
		var row: Array = game.level.duck[0]
		var y := 482.0 if id == "3-2" else float(game.world_three.trailer.row[2])
		actor(0).player = Vector2(float(row[0]) - 30, y)
		actor(1).player = Vector2((float(row[0]) + float(row[1])) / 2, y)
		actor(1).player_animation = "idle"
		begin_shared()
		var extension = game.world_three.queue_rush if id == "3-2" else game.world_three.hayride
		extension.banners_tick(game, game.world_three)
		check(actor(0).hearts == 3 and actor(1).hearts == 2 and actor(1).abilities._hits == 1, id + " low banner harms actual P2 once")
		var record: Dictionary = game.party_session.bridge.record(1)
		record.invincible = 0.0
		extension.banners_tick(game, game.world_three)
		check(actor(1).hearts == 2 and actor(1).abilities._hits == 2 and actor(1).invincible == 0.9, id + " low banner respects P2 Maya alternating passive")
		record.invincible = 0.0
		record.player_animation = "crouch"
		extension.banners_tick(game, game.world_three)
		check(actor(1).abilities._hits == 2, id + " source crouch animation clears banner")
		end_shared()

func _test_checkpoint_and_finds() -> void:
	pair()
	actor(0).player = Vector2(6900, 482)
	actor(0).mark_down()
	actor(1).player = Vector2(7001, 482)
	actor(1).hearts = 1
	begin_shared()
	game.world_three._checkpoint(game)
	end_shared()
	check(game.world_three.checkpoint_done and actor(0).hearts == 3 and not actor(0).down and actor(1).hearts == 3, "living P2 checkpoint revives all actors")
	check(actor(0).invincible == 1.5 and actor(1).invincible == 1.5, "checkpoint protection survives final facade reconciliation")
	pair()
	var point: Vector2 = game.receipts[0].position
	actor(0).player = Vector2(point.x - 200, point.y + 80)
	actor(1).player = point + Vector2(0, 80)
	begin_shared()
	game.world_three.after_pickups(0, game)
	end_shared()
	check(game.receipts[0].taken and game.score == 0, "P2 collects W3 receipt through scoped callback with no invented money")
	pair("3-4")
	actor(0).player = Vector2(5400, -278)
	actor(1).player = Vector2(5700, -278)
	begin_shared()
	game.world_three.after_pickups(0, game)
	end_shared()
	check(actor(0).movement_skills.has_skill("ground-pound") and actor(1).movement_skills.has_skill("ground-pound"), "P2 earned card is shared with both actors")
	check(actor(0).movement_skills.card_collected and actor(1).movement_skills.card_collected and game.save.skills == ["ground-pound"], "shared card persists once and cannot be collected twice")

func _test_surface_carry() -> void:
	pair("3-4")
	var first: Dictionary = game.world_three.big_top.movers[0].q
	var second: Dictionary = game.world_three.big_top.movers[1].q
	for index in [0, 1]:
		var surface: Dictionary = first if index == 0 else second
		surface.dx = 9.0 if index == 0 else -7.0
		surface.dy = 3.0 if index == 0 else 5.0
		actor(index).player = Vector2((float(surface.row[0]) + float(surface.row[1])) / 2, float(surface.row[2]) - float(surface.dy))
		actor(index).grounded = true
		actor(index).on_platform = true
		actor(index).scene_state.standing_surface = surface
	game.camera.x = first.row[0] - 100
	bind_leader()
	var p1: Vector2 = actor(0).player
	var p2: Vector2 = actor(1).player
	game.party_session.step(game, 0, {}, {})
	check(actor(0).player == p1 + Vector2(9, 3), "P1 consumes only its own previous support delta")
	check(actor(1).player == p2 + Vector2(-7, 5), "P2 consumes distinct previous support delta")
	check(is_same(actor(0).scene_state.standing_surface, first) and is_same(actor(1).scene_state.standing_surface, second), "each actor retains original live surface identity through bridge callbacks")
	check(is_same(game.world_three._standing_surface, first), "leader surface facade is restored after shared mover mutation")

func _test_hayride_carry_and_transition() -> void:
	pair("3-5")
	var deck: Dictionary = game.world_three.trailer
	var deck_left: float = deck.row[0]
	deck.dx = 5.0
	for index in [0, 1]:
		actor(index).player = Vector2(deck_left + 160 + index * 100, deck.row[2])
		actor(index).grounded = true
		actor(index).on_platform = true
		actor(index).scene_state.standing_surface = deck
	bind_leader()
	var p1: Vector2 = actor(0).player
	var p2: Vector2 = actor(1).player
	game.party_session.step(game, 0, {}, {})
	check(actor(0).player == p1 + Vector2(5, 0) and actor(1).player == p2 + Vector2(5, 0), "both riders consume prior deck delta once")
	check(deck.row[0] == deck_left and deck.dx == 0, "warmup late trailer runs once without doubling either actor's carry")
	game.camera.x = 13000
	game.world_three.checkpoint_done = true
	actor(0).player = Vector2(13200, deck.row[2])
	actor(0).mark_down()
	actor(1).player = Vector2(13400, deck.row[2] - 20)
	actor(1).velocity = Vector2(40, 90)
	actor(1).grounded = false
	deck.row[0] += 13000
	deck.row[1] += 13000
	deck.dx = 5.0
	deck_left = deck.row[0]
	game.world_three.hayride.harvester = {"x": 12900.0, "done": false}
	begin_shared()
	game.world_three._scene_update(game)
	game.world_three._advance_wipe(1.43, game)
	game.world_three.finish_frame(game)
	end_shared()
	check(game.camera.x == 14500 and actor(0).player.x == 14700 and actor(1).player.x == 14900, "auto scene shifts downed and living actors by one camera delta")
	check(deck.row[0] == deck_left + 1500 and game.world_three.hayride.harvester.x == 14400 and deck.dx == 5, "auto scene translates shared deck/harvester once and preserves old deck dx")
	check(actor(1).player.y == float(deck.row[2]) - 20 and actor(1).velocity == Vector2(0, 90) and not actor(1).grounded, "auto scene preserves airborne feet and vertical velocity")
	check(is_same(actor(0).scene_state.standing_surface, deck) and actor(0).scene_state.safe_position == actor(0).player, "downed rider keeps live support identity and its translated safe position")

func _test_scene_jump() -> void:
	pair()
	game.camera = Vector2(6700, -20)
	game.camera_speed = 27
	game.world_three.checkpoint_done = true
	for wave in game.combat.waves: wave.done = true
	actor(0).player = Vector2(6900, 300)
	actor(0).mark_down()
	actor(0).grounded = false
	actor(0).on_platform = true
	actor(1).player = Vector2(7100, 200)
	actor(1).velocity = Vector2(50, 100)
	actor(1).power = "wellies"
	actor(1).power_time = 4
	begin_shared()
	game.world_three._scene_update(game)
	check(game.world_three.wiping and near(game.world_three.wipe_focus_start.x, 520), "living P2 starts wipe, source focus excludes downed P1")
	game.world_three._advance_wipe(0.7, game)
	game.mode = "paused"
	game.world_three._advance_wipe(1, game)
	game.world_three.finish_frame(game)
	check(near(game.world_three.wipe_elapsed, 0.7) and game.camera.x == 6700, "paused shared wipe neither advances nor relocates")
	game.mode = "play"
	game.world_three._advance_wipe(0.73, game)
	game.bullets.append({"p": Vector2.ZERO, "enemy": false})
	game.world_three.finish_frame(game)
	check(game.camera.x == 7900 and game.bullets.is_empty(), "one delayed transition translates shared camera and clears shots once")
	end_shared()
	check(actor(0).player.x == 8100 and actor(1).player.x == 8300, "scene transition relocates both living and downed actors exactly once")
	check(actor(0).scene_state.safe_position == actor(0).player and actor(1).scene_state.safe_position == actor(1).player, "new per-actor safe positions survive merge")
	check(actor(0).scene_state.px == actor(0).player.x and actor(1).scene_state.px == actor(1).player.x and actor(1).velocity == Vector2.ZERO, "scene resets previous x and per-actor velocities")
	check(actor(0).down and not actor(0).grounded and actor(0).on_platform and actor(1).power == "wellies" and game.camera.y == -20 and game.camera_speed == 27, "scene preserves source down/platform/power and vertical camera state")
	begin_shared()
	game.world_three.finish_frame(game)
	end_shared()
	check(actor(0).player.x == 8100 and actor(1).player.x == 8300, "repeated scene callback never translates a second time")
	# Average framing includes both CPU and human, unlike camera-follow policy.
	actor(0).down = false
	actor(0).hearts = 3
	actor(0).player.x = 8100
	actor(1).player.x = 8500
	begin_shared()
	check(near(game.world_three._wipe_focus(game).x, 520), "wipe uses mean actor x rather than active facade or human-only camera roster")
	end_shared()

func _test_cpu_and_downed_timers() -> void:
	pair("3-1", "cpu", "ama")
	actor(0).player = Vector2(600, 482)
	actor(1).player = Vector2(100, 482)
	actor(1).ai.far_time = 1.6
	actor(1).scene_state.standing_surface = game.world_three.surfaces(game).filter(func(q): return q.plat)[0]
	bind_leader()
	game.party_session.step(game, 0.02, {}, {})
	check(absf(actor(1).player.x - actor(0).player.x) < 40 and actor(1).player.y == 482 and actor(1).ai.far_time == 0, "source CPU catch-up relocates through normal scheduler")
	check(not actor(1).scene_state.standing_surface.plat and actor(1).scene_state.standing_surface.row[0] < actor(1).player.x and actor(1).scene_state.standing_surface.row[1] > actor(1).player.x, "caught-up CPU rebinds its own stale support to local ground")
	actor(1).player = Vector2(200, 482)
	actor(1).mark_down()
	actor(1).power = "wellies"
	actor(1).power_time = 0.01
	actor(1).invincible = 1.0
	actor(1).scene_state.tied = 1.0
	bind_leader()
	game.party_session.step(game, 0.02, {}, {})
	check(actor(1).down and actor(1).power == "" and actor(1).power_time == 0 and near(actor(1).invincible, 0.98), "downed actor still consumes source prelude invulnerability and power timers")
	check(near(actor(1).scene_state.tied, 0.98) and actor(1).velocity.y == 0, "downed actor tie decays once and vertical motion stays stopped")
	actor(1).player = actor(0).player + Vector2(30, 0)
	for index in 71: game.party_session.step(game, 0.02, {}, {})
	check(not actor(1).down and actor(1).hearts == 2 and actor(1).invincible > 2 and actor(1).player_animation == "win", "CPU mate is revived normally with its own protection and celebration")
	var frozen: String = JSON.stringify([actor(0).player, actor(1).player, actor(1).scene_state.tied, game.elapsed, game.world_three.level_time])
	game._pause()
	game.party_session.step(game, 1, {"right": true}, {})
	check(game.mode == "paused" and JSON.stringify([actor(0).player, actor(1).player, actor(1).scene_state.tied, game.elapsed, game.world_three.level_time]) == frozen, "pause freezes both actors and all shared world clocks")

func _test_lifecycle() -> void:
	pair()
	actor(0).mark_down()
	actor(1).mark_down()
	bind_leader()
	game.party_session.step(game, 0.016, {}, {})
	check(game.mode == "over", "both down resolves only after shared frame")
	var elapsed: float = game.elapsed
	var world_time: float = game.world_three.level_time
	game._continue_level()
	check(game.mode == "play" and actor(0).hearts == 3 and actor(1).hearts == 3, "Continue revives both actors")
	check(game.elapsed == elapsed and game.world_three.level_time == world_time, "Continue preserves world encounter clocks")
	pair("3-S")
	actor(0).mark_down()
	actor(1).mark_down()
	bind_leader()
	game.world_three.bonus.timer_elapsed = game.world_three.bonus.timer_duration - 0.001
	game.party_session.step(game, 0.016, {}, {})
	check(game.mode == "clear" and not actor(0).down and not actor(1).down and actor(0).hearts == 1 and actor(1).hearts == 1, "same-frame source bonus clear wins before all-down")
	var duration: float = game.world_three.bonus.timer_elapsed
	game.party_session.step(game, 1, {}, {})
	check(game.world_three.bonus.timer_elapsed == duration, "completed party bonus cannot advance timers again")
