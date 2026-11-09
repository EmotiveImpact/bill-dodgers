extends SceneTree
## Focused real-main fixtures, NOT a complete input-driven checkout run.
## Deliberate placement/phase/wave/HP fixtures isolate host seams. Production
## main, world, combat, input handlers, abilities, skills and save writer run.
const SaveStore = preload("res://src/save_store.gd")
const CheckoutRenderer = preload("res://src/checkout_renderer.gd")
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
	func start_music(boss: bool = false) -> void:
		starts.append(boss); music_requested = true
	func stop_music() -> void: stops += 1; music_requested = false
	func shutdown() -> void: pass
	func clear_log() -> void: starts.clear(); stops = 0; effects.clear()
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func near(a: float, b: float) -> bool: return absf(a - b) < 0.00001
func fresh(game, who: String = "jp", skills: Array = []) -> void:
	game.character = who
	game.save = {"schema": 1, "receipts": {}, "skills": skills.duplicate(), "kitty": 13}
	game.audio.clear_log()
	game.load_level("2-6")
func stand(game, point: Vector2, camera_x: float = 4162) -> void:
	game.player = point; game.camera = Vector2(camera_x, 0)
	game.camera_speed = 0; game.velocity = Vector2.ZERO
	game.grounded = true; game.on_platform = false; game.hurt_lock = 0
func mark_waves(game) -> void:
	# Test setup, not gameplay progression. The independent full-run suite
	# must actually spawn/fight all three waves without these assignments.
	for wave in game.combat.waves:
		wave.started = true; wave.done = true; wave.index = wave.group.size()
func arena(game, phase: int = 1) -> void:
	mark_waves(game)
	stand(game, Vector2(4300, 482))
	game.camera_lock = null
	game.step(0, {}) # Entry itself always executes through main's end predicate.
	game.world_two.checkout.boss.state = "fight"
	game.world_two.checkout.boss.phase = phase
	game.world_two.checkout.boss.next = 100.0
func state(game) -> Dictionary: return game.world_two.checkout.players[game.get_instance_id()]
func advance(game, seconds: float, controls: Dictionary = {}) -> void:
	while seconds > 0.000000001:
		var dt := minf(seconds, 0.01)
		game.step(dt, controls)
		seconds -= dt
func shot(point: Vector2, ghost := false, damage := 1) -> Dictionary:
	return {"p": point, "v": Vector2.ZERO, "enemy": false, "life": 20.0, "damage": damage, "ghost": ghost, "ghost_age": 0.0}
func bill(point: Vector2, speed: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"p": point, "v": speed, "enemy": true, "life": 20.0, "gravity": 0.0}
func key(pressed := true, repeat := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F8 # An unmapped key still tears a bag.
	event.keycode = KEY_F8; event.pressed = pressed; event.echo = repeat
	return event
func touch(pressed := true) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = 83; event.position = Vector2(400, 200); event.pressed = pressed
	return event
func freeze_bag(game) -> void:
	game.world_two.checkout.boss.beam = null
	game.world_two.checkout.boss.next = 100.0

func test_entry(game) -> void:
	fresh(game)
	check(game.is_native_supported() and game._native_world_two() and game.boss == null, "2-6 selects native W2 while generic boss stays null")
	check(game.supermarket_renderer is CheckoutRenderer and game.world_two.checkout != null, "Main selects checkout controller and dedicated painter")
	check(game.combat.waves.size() == 3 and game.world_two.unsupported_hazards.is_empty(), "Three authored approach waves and every checkout hazard schema load")
	for i in range(3):
		check(game.combat.waves[i].at == [500, 1700, 3000][i] and game.combat.waves[i].group == game.level.waves[i].g, "Approach wave %d retains source solo order and timing" % (i + 1))
	check(game.audio.starts == [false], "Level load requests ordinary soundtrack once")
	mark_waves(game)
	stand(game, Vector2(4490, 482), 4159.999)
	game.step(0, {})
	check(game.world_two.checkout.boss.is_empty(), "Camera strictly below4160 cannot start checkout even with all waves done")
	for missing in range(3):
		fresh(game); mark_waves(game)
		game.combat.waves[missing].done = false
		game.combat.spawn(game, 4500, "rush") # A real live bot prevents waves_tick auto-completing the fixture.
		stand(game, Vector2(4300, 482), 4160)
		game.step(0, {})
		check(game.world_two.checkout.boss.is_empty(), "Unfinished approach wave %d independently prevents entry" % (missing + 1))
	fresh(game); mark_waves(game); stand(game, Vector2(4300, 482), 4160)
	game.step(0, {})
	var b: Dictionary = game.world_two.checkout.boss
	check(not b.is_empty() and b.state == "enter" and b.hp == 70 and b.x == 4760, "Exact4160 eligibility enters original stationary70HP checkout")
	check(game.audio.starts == [false, true] and game.world_two.checkout.events.is_empty(), "Entry music event is drained and starts boss music once")
	check(game.camera_lock == 4162 and game.world_two.camera_cap(game) == 4162, "Both main and runtime enforce source4162 encounter cap")
	game.step(0, {})
	check(game.audio.starts == [false, true] and is_same(b, game.world_two.checkout.boss), "Repeated eligibility neither reinitializes TB nor replays music")
	advance(game, 1.4)
	check(b.state == "enter", "Real-main boot remains entering at exactly1.4 seconds")
	advance(game, 0.01)
	check(b.state == "fight" and near(b.next, 1.8), "First post1.4 frame changes state without consuming initial scan delay")
	game.invincible = 999
	advance(game, 4)
	check(game.mode == "play" and game.world_two.end_time == 0 and not game.save.get("cleared", {}).get("2-6", false), "Ordinary2.6-second ending cannot bypass live checkout objective")
	stand(game, Vector2(4800, 482), 4160)
	advance(game, 0.3)
	check(game.camera.x <= 4162 and game.player.x == 4595, "Actual motion is camera-capped and late fighting barrier clamps to4595")
	check(not game.ability_inside_wall(Vector2(4750, 350)), "Checkout is not an artificial generic body wall")

func test_shot_order(game) -> void:
	for ghost in [false, true]:
		fresh(game); arena(game, 3)
		var b: Dictionary = game.world_two.checkout.boss
		b.steps = 3 # No step emission in overlap fixture.
		var point := Vector2(4700, 250)
		game.combat.spawn(game, 4700, "rush")
		var bot: Dictionary = game.enemies.back()
		bot.p = Vector2(4700, 300); bot.speed = 0; bot.cd = 100
		var button := {"x": 4700.0, "y": 250.0, "id": "fixture", "hit": 0.0}
		game.world_two.hazard_controller.buttons.append(button)
		var box := {"p": Vector2(4700, 280), "hp": 3, "give": "heart", "broken": false, "hit": 0.0}
		game.crates.append(box)
		game.world_two.surfaces(game).append({"row": [4660.0, 4740.0, 200.0], "plat": false})
		game.bullets.append(shot(point, ghost))
		game.step(0, {})
		check(bot.hp == 2 and button.hit == 0 and b.hp == 70 and box.hp == 3 and game.bullets.is_empty(), "%s: real bot precedes button/TB/crate/wall" % str(ghost))
		game.enemies.clear()
		game.bullets.append(shot(point, ghost))
		game.step(0, {})
		check(button.hit == 0.3 and b.hp == 70 and box.hp == 3 and game.bullets.is_empty(), "%s: button precedes TB/crate/wall" % str(ghost))
		game.world_two.hazard_controller.buttons.clear()
		game.bullets.append(shot(point, ghost, 999))
		game.step(0, {})
		check(b.hp == 67 and box.hp == 3 and game.bullets.is_empty(), "%s: TB screen receives fixed3 before crate/wall despite shot damage999" % str(ghost))
		check(state(game).boss_hits == 1, "%s: ownerless main shot receives actual host boss-hit credit" % str(ghost))
		b.state = "enter"
		game.bullets.append(shot(point, ghost))
		game.step(0, {})
		check(box.hp == 2 and game.bullets.is_empty(), "%s: rejected TB shot reaches ordinary crate before wall" % str(ghost))
		game.crates.clear()
		game.bullets.append(shot(point, ghost))
		game.step(0, {})
		check(game.bullets.is_empty() and b.hp == 67, "%s: unconsumed shot finally dies in real solid-wall pass" % str(ghost))
	fresh(game); arena(game, 3)
	game.world_two.checkout.boss.steps = 3
	game.bullets.append(shot(Vector2(4650, 250)))
	game.bullets.back().homing = true
	game.bullets.back().v = Vector2(50, 0)
	game.step(0.01, {})
	check(game.world_two.checkout.boss.hp == 67, "Incidental homing projectile can hit TB through ordinary ordered interception")

func test_receipt_surfaces(game) -> void:
	fresh(game); arena(game, 2)
	var original := JSON.stringify(game.level)
	var base_count: int = game.world_two.surfaces(game).size()
	var b: Dictionary = game.world_two.checkout.boss
	b.hp = 21 # Threshold fixture, not earned boss damage.
	game.step(0, {})
	check(b.phase == 3 and game.enemies.size() == 2, "Threshold frame actually starts phase3 and both source rush helpers")
	game.enemies.clear(); game.invincible = 999
	for i in range(3):
		advance(game, 0.6)
		check(b.steps == i, "Receipt%d does not arrive at inclusive600ms" % (i + 1))
		advance(game, 0.01)
		var x := 4430.0 + i * 80
		var y := 412.0 - i * 65
		var surface: Dictionary = game.world_two.below(game, x, y - 20)
		check(b.steps == i + 1 and game.world_two.surfaces(game).size() == base_count + i + 1, "Late real-main update adds receipt%d to live surfaces" % (i + 1))
		check(surface.get("receipt", false) and surface.plat and is_same(surface, game.world_two.surfaces(game).back()), "Receipt%d query returns actual live platform dictionary" % (i + 1))
		check(game._land(x, y - 2, y + 2) == y and game.ability_land_on(x, y - 2, y + 2) == y, "Receipt%d is visible to player and ability landing" % (i + 1))
		check(game.floor_at(x, y - 20) == y and game.skill_floor_below(x, y - 20) == y, "Receipt%d is visible to ordinary floor and movement-skill probes" % (i + 1))
		check(game._land(x, y - 2, y + 2, true) == INF and not game.ability_inside_wall(Vector2(x, y + 10)), "Receipt%d permits drop-through and is not a solid projectile wall" % (i + 1))
		check(game._wall_clamp(x - 70, x, y + 30) == x, "Receipt%d does not side-block player/skill motion" % (i + 1))
	check(JSON.stringify(game.level) == original and game.level.plats.size() == 5, "Receipt growth never mutates imported lane geometry")
	stand(game, Vector2(4430, 410))
	game.grounded = false; game.velocity.y = 180
	game.step(0.01, {})
	check(game.player.y == 412 and game.grounded and game.on_platform, "Actual falling player lands on first receipt and receives platform flag")
	game.jump_held = false
	game.step(0.01, {"jump": true, "down": true})
	check(not game.grounded and game.drop_time > 0 and game.player.y > 412, "Actual jump+down drops through dynamic receipt")
	stand(game, Vector2(4300, 482))
	var coin := {"p": Vector2(4430, 403), "v": Vector2(0, 100), "age": 0.0, "rest": false}
	var item := {"p": Vector2(4430, 385), "vy": 100.0, "age": 0.0, "give": "heart", "rest": false}
	var falling_bill := bill(Vector2(4430, 405), Vector2(0, 150))
	game.coins.append(coin); game.items.append(item); game.bullets.append(falling_bill)
	game.step(0.01, {})
	check(coin.p.y == 404 and coin.rest, "Actual coin settles8px above receipt instead of ground")
	check(item.p.y == 386 and item.rest, "Actual item rests26px above receipt instead of ground")
	check(not game.bullets.has(falling_bill), "Descending hostile bill collides with live receipt landing query")
	var horizontal := shot(Vector2(4430, 425)); horizontal.v = Vector2(50, 0)
	game.bullets.append(horizontal); game.step(0.01, {})
	check(game.bullets.has(horizontal), "Horizontal friendly shot passes beneath receipt rather than treating it as wall")
	game.bullets.clear()
	var ball := {"kind": "ball", "p": Vector2(4430, 389), "v": Vector2(0, 100), "age": 0.0, "life": 5.0, "spin": 0.0, "free": 100.0, "boss_next": 0.0, "floor": 482.0, "trail": []}
	game.abilities.effects.append(ball); game.step(0.01, {})
	check(ball.p.y == 390 and ball.v.y == -620, "Theo ball late pass bounces on the same receipt geometry")

func test_bags_and_raw_input(game) -> void:
	fresh(game); arena(game)
	var b: Dictionary = game.world_two.checkout.boss
	b.beam = {"y": 448.0, "t": 0.9}
	game.velocity = Vector2(120, -10)
	game.step(0.01, {})
	check(game.hearts == 2 and near(state(game).bag, 1.5) and game.velocity.x == 0, "Unprotected live scanner actually removes health and applies1500ms bag")
	check(game.invincible > 0 and game.player_animation == "hit", "Scanner uses main hurt/invulnerability/animation pathway")
	freeze_bag(game)
	game._input(key()); game._input(key(true, true)); game._input(touch())
	check(game.world_two.checkout.mash == 3, "Unmapped key-down, actual repeat and touch-start each count globally")
	game._input(key(false)); game._input(touch(false))
	var mouse := InputEventMouseButton.new(); mouse.button_index = MOUSE_BUTTON_LEFT; mouse.pressed = true
	game._input(mouse); mouse.device = InputEvent.DEVICE_ID_EMULATION; game._input(mouse)
	var drag := InputEventScreenDrag.new(); drag.index = 83; drag.position = Vector2(450, 200); game._input(drag)
	game._input(InputEventMouseMotion.new())
	game._unhandled_input(touch())
	check(game.world_two.checkout.mash == 3, "Release, native/emulated mouse, motion, drag and unhandled routing add no duplicate mash")
	game.step(0.01, {})
	check(near(state(game).bag, 1.01) and game.world_two.checkout.mash == 0 and game.hurt_lock >= 0.06, "Next real update consumes global3×160ms mash once plus elapsed time")
	game.step(0.01, {"shoot": true, "right": true, "special": true})
	check(near(state(game).bag, 1.0), "Held control dictionaries do not masquerade as raw repeated input")
	var routed := touch(); routed.index = 84; routed.position = Vector2(700, 30) # GUI Sound button.
	game.get_viewport().push_input(routed)
	check(game.world_two.checkout.mash == 1, "Actual viewport touch-start reaches _input before GUI handling")
	var release := touch(false); release.index = 84; release.position = routed.position
	game.get_viewport().push_input(release)
	check(game.world_two.checkout.mash == 1, "Viewport touch release adds no mash")
	game.step(0, {})
	check(near(state(game).bag, 0.84), "GUI-area touch tears bag by160ms on actual main update")
	for i in range(6): game._input(key(true, i > 0))
	game.step(0, {})
	check(state(game).bag == 0 and game.hurt_lock >= 0.06 and game.velocity.x == 0, "Mash release frame retains source minimum lock and zero lateral velocity")
	game.invincible = 0.5; b.beam = {"y": 448.0, "t": 0.9}
	game.step(0.01, {})
	check(game.hearts == 2 and state(game).bag == 0, "Existing invulnerability excludes both scanner damage and bag")
	freeze_bag(game)
	game._pause()
	var snapshot: Dictionary = game.world_two.checkout.snapshot()
	game._input(key()); game._input(touch()); game.step(10, {"right": true})
	check(game.world_two.checkout.snapshot() == snapshot and game.audio.paused, "Paused raw input and held controls cannot advance or mash checkout")
	game._resume()
	check(game.mode == "play" and not game.audio.paused and game.touches.is_empty(), "Resume restores play/audio while safely releasing held touches")
	var before_clock: float = b.t
	game._physics_process(1.0)
	check(near(b.t - before_clock, 0.034), "Actual physics host caps an oversized frame to source34ms for checkout")

func test_real_defenses(game) -> void:
	fresh(game, "maya"); arena(game)
	game.abilities.meter = 1 # Meter fixture; actual activation uses ordinary controls.
	game.world_two.checkout.boss.beam = {"y": 448.0, "t": 0.9}
	game.step(0.01, {"special": true})
	check(game.abilities.active == "maya" and game.hearts == 3 and state(game).bag == 1.5, "Actual Maya shield rejects health loss while source scanner bag still applies")
	fresh(game, "jp", ["slide"]); arena(game)
	advance(game, 0.15, {"right": true})
	game.world_two.checkout.boss.beam = {"y": 448.0, "t": 0.9}
	game.step(0.01, {"right": true, "down": true})
	check(game.movement_skills.slide_remaining > 0 and game.hearts == 3 and state(game).bag == 1.5, "Actual run/down slide blocks scanner damage but not bag")
	check(game.velocity.x == 0, "Late bag overrides slide lateral velocity in the same frame")
	fresh(game, "jp", ["dash"]); arena(game)
	game.world_two.checkout.boss.beam = {"y": 448.0, "t": 0.9}
	game.step(0.01, {"dash": true})
	check(game.movement_skills.dash_remaining > 0 and game.hearts == 3 and state(game).bag == 1.5, "Actual shared dash blocks scanner damage but not bag")
	check(game.velocity.x == 0, "Late bag overrides dash lateral velocity in the same frame")
	for who in game.CHARACTERS:
		fresh(game, who); arena(game)
		game.world_two.checkout.boss.beam = {"y": 332.0, "t": 0.9}
		game.step(0.01, {"down": true})
		check(game.hearts == 3 and state(game).bag == 0 and game.crouching, "%s real crouch avoids high beam using source character height" % who)
		game.world_two.checkout.boss.beam = {"y": 448.0, "t": 0.9}
		game.step(0.01, {})
		check(game.hearts == 2 and state(game).bag == 1.5, "%s real standing low-beam collision applies damage and bag" % who)
	fresh(game, "maya"); arena(game)
	game.world_two.checkout.boss.beam = {"y": 448.0, "t": 0.9}
	game.step(0.01, {})
	freeze_bag(game); advance(game, 1.6)
	game.world_two.checkout.boss.beam = {"y": 448.0, "t": 0.9}
	game.step(0.01, {})
	check(game.hearts == 2 and near(game.invincible, 0.9) and state(game).bag == 1.5, "Maya second-hit passive rejects damage and grants protection while bag still applies")

func test_generic_blindness(game) -> void:
	for who in game.CHARACTERS:
		fresh(game, who, ["super"]); arena(game, 3)
		var b: Dictionary = game.world_two.checkout.boss
		b.steps = 3
		game.abilities.meter = 1
		game.step(0, {"special": true})
		check(game.abilities.active == who and game.boss == null and not game.abilities._boss_on(game), "%s actual special activates without generic checkout target" % who)
		check(b.hp == 70 and b.dizzy == 0, "%s special activation cannot directly auto-damage or stun TB" % who)
	fresh(game, "maya"); arena(game, 3)
	game.world_two.checkout.boss.steps = 3
	stand(game, Vector2(4650, 482)); game.abilities.meter = 1
	game.step(0, {"special": true})
	check(game.world_two.checkout.boss.hp == 70 and game.bullets.is_empty(), "Maya aura within generic boss range remains blind to TB")
	fresh(game, "jp", ["ground-pound", "super"]); arena(game, 3)
	game.world_two.checkout.boss.steps = 3
	stand(game, Vector2(4600, 450)); game.grounded = false; game.velocity.y = 1400
	game.movement_skills.ground_pounding = true # Landing fixture, not skill acquisition.
	game.step(0.03, {})
	check(game.grounded and game.movement_skills.events.has("ground-pound-land"), "Actual ground-pound landing pathway executes beside TB")
	check(game.world_two.checkout.boss.hp == 70 and game.bullets.is_empty(), "Ground-pound generic boss branch stays blind to checkout")
	fresh(game, "theo"); arena(game, 3)
	var b: Dictionary = game.world_two.checkout.boss
	b.steps = 3
	var ball := {"kind": "ball", "p": Vector2(4700, 250), "v": Vector2(20, 0), "age": 0.0, "life": 5.0, "spin": 0.0, "free": 100.0, "boss_next": 0.0, "floor": 482.0, "trail": []}
	game.abilities.effects.append(ball)
	game.step(0.01, {})
	check(b.hp == 70 and ball.v.x == 20 and game.bullets.is_empty(), "Theo ball inside TB does not target or bounce from generic boss branch")
	ball.free = 0
	game.step(0.01, {})
	check(b.hp == 70 and game.bullets.size() == 1 and game.bullets[0].ghost, "Late untargeted ball ghost is emitted after this frame's shot pass")
	game.step(0.01, {})
	check(b.hp == 67 and game.bullets.is_empty(), "Next frame's actual ghost interception deals fixed3 screen damage")
	fresh(game); arena(game, 3)
	game.world_two.checkout.boss.steps = 3
	game.abilities.meter = 1; game.abilities.rng.seed = 33
	var expected := RandomNumberGenerator.new(); expected.seed = 33
	expected.randf()
	var rain_x: float = game.camera.x + 40 + expected.randf() * (game.view_width() - 80)
	game.step(0, {"special": true})
	check(game.bullets.size() == 1 and absf(game.bullets[0].p.x - rain_x) < 0.001, "JP actual rain uses source uniform screen position, not boss-biased target")

func test_lifecycle_and_carry(game) -> void:
	fresh(game); arena(game, 2)
	var checkout = game.world_two.checkout
	var b: Dictionary = checkout.boss
	var box := {"p": Vector2(4300, 482), "vy": 0.0, "st": "ground", "k": 0, "by": null}
	b.crates.append(box)
	game.step(0, {})
	check(box.st == "carry" and is_same(state(game).crate, box) and box.by == game.get_instance_id(), "Actual overlap acquires crate with stable host identity and shared carry reference")
	game.step(0.01, {})
	check(box.p == game.player - Vector2(0, game.character_height() + 10), "Real carried crate follows full character height plus10")
	var generation: int = game.world_two.run_generation
	game.touches[101] = "right"
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var frozen: Dictionary = checkout.snapshot()
	game.step(5, {"right": true})
	check(game.mode == "paused" and checkout.snapshot() == frozen and game.touches.is_empty(), "Real focus-out pauses carry/timers and releases input")
	game._resize()
	check(checkout.snapshot() == frozen, "Layout resize releases controls without resetting encounter/carry")
	game._resume()
	game.hearts = 1; game.invincible = 0
	game.bullets.append(bill(game.player - Vector2(0, 80)))
	game.step(0.01, {})
	check(game.mode == "over" and game.hearts == 0, "Actual hostile bill causes deferred end-of-frame global knockout")
	check(box.st == "ground" and box.p.y == 482 and state(game).crate == null, "Same lethal frame drops dead owner's carried crate and clears carry reference")
	check(box.by == game.get_instance_id(), "Dropped crate keeps only stable source owner ID, not a cyclic host object")
	var over: Dictionary = checkout.snapshot()
	game._input(key()); game.step(20, {"right": true})
	check(checkout.snapshot() == over, "Knockout screen freezes boss/crate timers and excludes raw mash")
	game._continue_level()
	check(game.hearts == 3 and game.invincible == 2.5 and game.mode == "play", "Actual Continue restores three hearts and source2.5-second protection")
	check(is_same(checkout, game.world_two.checkout) and is_same(b, checkout.boss) and game.world_two.run_generation == generation, "Continue preserves controller/boss identities and run generation")
	check(checkout.snapshot() == over and game.boss == null, "Continue does not reset encounter phase, crate, bag, hit count or clock")
	game.step(0, {})
	check(box.st == "carry" and is_same(state(game).crate, box), "Continued living player can recover dropped crate through real pickup")
	checkout.input_event(game)
	game.world_two.surfaces(game).append(checkout.receipt_step(0))
	var stale: Dictionary = checkout.snapshot()
	game.load_level("2-1")
	check(game.world_two.checkout == null and game.world_two.surfaces(game).all(func(s): return not s.get("receipt", false)), "Switching W2 stage removes checkout and dynamic receipt geometry")
	check(checkout.late_tick(10, game, game.world_two) == "" and checkout.snapshot() == stale, "Old controller cannot run callbacks or mutate state after stage switch")
	game._input(key())
	check(checkout.snapshot() == stale, "Raw input on other W2 stage cannot reach stale checkout")
	fresh(game)
	check(game.world_two.checkout != checkout and game.world_two.checkout.boss.is_empty() and game.world_two.checkout.jar.is_empty(), "Fresh2-6 reload creates clean encounter and jar rather than Continue state")
	check(state(game).crate == null and state(game).bag == 0 and state(game).boss_hits == 0 and game.world_two.checkout.mash == 0, "Fresh replay clears carry/bag/hits/global mash")
	check(game.world_two.surfaces(game).size() == 6 and game.world_two.end_time == 0 and not game.world_two.clear_reported, "Fresh replay restores six static surfaces and completion latches")
	arena(game)
	var old = game.world_two.checkout
	var before_menu: Dictionary = old.snapshot()
	game._show_menu()
	old.late_tick(10, game, game.world_two)
	check(game.mode == "menu" and old.snapshot() == before_menu and not game.audio.music_requested, "Map lifecycle invalidates pending checkout callbacks and stops music")
	game.load_level("1-1")
	old.late_tick(10, game, game.world_two)
	check(game.scene_runtime == game.world_one and old.snapshot() == before_menu, "Cross-world switch cannot revive stale W2 controller or geometry")

func defeat_fixture(game) -> void:
	fresh(game); arena(game, 3)
	game.world_two.checkout.boss.steps = 3
	game.world_two.checkout.boss.hp = 3 # Final-hit fixture, not earned full battle.
	game.bullets.append(shot(Vector2(4700, 250), false, 99))
	game.step(0, {}) # Real main ordered collision causes defeat and drops.

func test_jar_clear_and_knockout(game) -> void:
	# Final player shot and lethal enemy bill deliberately share one frame.
	fresh(game); arena(game, 3)
	game.world_two.checkout.boss.steps = 3
	game.world_two.checkout.boss.hp = 3
	game.hearts = 1
	game.bullets.append(bill(game.player - Vector2(0, 80))) # Stored first on purpose.
	game.bullets.append(shot(Vector2(4700, 250)))
	game.step(0.01, {})
	check(game.world_two.checkout.boss.state == "down" and game.coins.size() == 20 and game.mode == "over", "Player final shot resolves before stored-first lethal bill, then real global knockout")
	check(near(game.world_two.checkout.boss.t, 0.01) and game.world_two.checkout.jar.is_empty() and not game.save.get("cleared", {}).get("2-6", false), "Lethal final-hit frame still runs late down timer without fake jar/clear")
	var pending_final: Dictionary = game.world_two.checkout.snapshot()
	game.step(20, {})
	check(game.world_two.checkout.snapshot() == pending_final, "No wall-clock jar callback can escape final-hit knockout screen")
	game._continue_level()
	advance(game, 1.5)
	check(not game.world_two.checkout.jar.is_empty() and game.mode == "play", "Continue resumes original final-hit down timer into real jar spawn")
	defeat_fixture(game)
	var checkout = game.world_two.checkout
	var b: Dictionary = checkout.boss
	check(b.state == "down" and b.hp == 0 and game.mode == "play", "Actual final shot defeats TB without clearing main play")
	check(game.coins.size() == 20 and game.score == 0 and game.save.kitty == 13, "Defeat drops20 real coins without premature banking")
	check(game.audio.starts == [false, true] and game.audio.stops == 0 and game.audio.music_requested, "Source bossMusic=false event does not prematurely stop soundtrack")
	check(not game.save.get("cleared", {}).get("2-6", false), "Defeat alone never writes checkout clear flag")
	advance(game, 1.5)
	check(checkout.jar.is_empty(), "Down callback remains pending at exactly1500ms")
	game._pause(); var pending: Dictionary = checkout.snapshot()
	game.step(10, {}); game._resume()
	check(checkout.snapshot() == pending, "Pause/resume preserves strict pending jar deadline without wall-clock callback")
	game.step(0.01, {})
	check(not checkout.jar.is_empty() and near(checkout.jar.t, 0.01) and near(checkout.jar.p.x, 4608.5), "First postdeadline frame creates and immediately advances real jar")
	check(near(checkout.jar.p.y, 253.24) and near(checkout.jar.v.y, -876), "Spawn-frame jar gravity and motion execute after checkout down update")
	advance(game, 1.1)
	check(game.mode == "play" and checkout.jar.t > 0.6 and not checkout.jar.got and not game.world_two.clear_reported, "Mature jar away from player still cannot trigger ordinary timed clear")
	# Horizontal-only source collision: place player very high but safely above
	# fall bounds. No fake jar, _complete_level call, or manual clear flag.
	stand(game, Vector2(checkout.jar.p.x, 150))
	game.grounded = false; game.velocity = Vector2.ZERO
	game.score = 7 # Fixture checks carried score plus all remaining real coins.
	var remaining: int = game.coins.size()
	check(remaining > 0 and SaveStore.write_save(game.save) == OK, "Isolated save starts uncleared while actual defeat coins remain")
	check(not SaveStore.read_save().get("cleared", {}).get("2-6", false), "Real on-disk save remains uncleared before jar collision")
	game.step(0, {})
	check(game.mode == "clear" and checkout.jar.got and checkout.clear_reported and game.world_two.clear_reported, "Actual mature horizontal-only jar collision completes through both latches")
	check(checkout.jar.by == game.get_instance_id() and absf(game.player.y - checkout.jar.p.y) > 100, "Jar uses stable real collector identity and no vertical proximity condition")
	check(game.score == 7 + remaining and game.coins.is_empty() and game.save.kitty == 13 + 7 + remaining, "Real completion banks each remaining coin and carried score once")
	check(game.audio.stops == 1 and not game.audio.music_requested and game.audio.effects.count("win") == 1, "Real jar completion stops music and plays win exactly once")
	var disk: Dictionary = SaveStore.read_save()
	check(disk.get("cleared", {}).get("2-6", false) and disk.kitty == game.save.kitty, "Real save writer persists jar-only checkout clear and exact bank")
	var saved_text := FileAccess.get_file_as_string(SaveStore.PATH)
	for i in range(3):
		game.step(1, {}); game.world_two.after_pickups(1, game); checkout.late_tick(1, game, game.world_two)
	check(game.save.kitty == disk.kitty and game.audio.stops == 1 and game.audio.effects.count("win") == 1 and FileAccess.get_file_as_string(SaveStore.PATH) == saved_text, "Repeated postclear host/controller calls cannot double-bank, replay win or resave")
	defeat_fixture(game)
	checkout = game.world_two.checkout
	advance(game, 2.2)
	stand(game, Vector2(checkout.jar.p.x, 482))
	game.hearts = 1; game.invincible = 0
	game.bullets.append(bill(game.player - Vector2(0, 80)))
	var jar_age: float = checkout.jar.t
	game.step(0.01, {})
	check(game.mode == "over" and game.hearts == 0 and not checkout.jar.got and not game.save.get("cleared", {}).get("2-6", false), "Lethal bill before jar pass leaves no living collector, so global knockout wins")
	check(checkout.jar.t > jar_age and game.audio.stops == 0, "Pending global knockout still finishes source jar update before freezing, without stopping music")
	var snapshot: Dictionary = checkout.snapshot()
	game.step(20, {})
	check(checkout.snapshot() == snapshot, "Pending mature jar and down timer freeze on knockout screen")
	game._continue_level()
	check(checkout.snapshot() == snapshot and game.mode == "play", "Continue keeps pending jar/boss state intact")
	game.step(0, {})
	check(game.mode == "clear" and checkout.jar.got and game.save.get("cleared", {}).get("2-6", false), "Revived living player collects original pending jar on resumed frame")
	check(game.audio.stops == 1 and game.audio.effects.count("win") == 1, "Knockout/Continue path still has one real completion and soundtrack stop")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Checkout integration: main script failed to load")
		game.free(); quit(1); return
	root.add_child(game); game.set_physics_process(false)
	game.audio.shutdown(); game.audio.queue_free(); game.audio = AudioLog.new()
	test_entry(game)
	test_shot_order(game)
	test_receipt_surfaces(game)
	test_bags_and_raw_input(game)
	test_real_defenses(game)
	test_generic_blindness(game)
	test_lifecycle_and_carry(game)
	test_jar_clear_and_knockout(game)
	game.queue_free(); await process_frame
	print("Checkout main integration: ", checks, " checks, ", failures.size(), " failures (focused fixtures, not full progression)")
	quit(0 if failures.is_empty() else 1)
