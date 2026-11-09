extends SceneTree
## Real main.tscn integration with deliberately placed collision/lifecycle fixtures.
## Suppressed/completed waves and actor placement are NOT whole-run proof.
## test_full_parking_run.gd separately owns authored traversal evidence.
const WorldTwo = preload("res://src/world_two.gd")
const SupermarketCombat = preload("res://src/supermarket_combat.gd")
const LegacyCombat = preload("res://src/combat.gd")
const SaveStore = preload("res://src/save_store.gd")

class ProbeWorld extends WorldTwo:
	var trace: Array = []
	var hits: Array = []
	func objective_tick(dt: float, host) -> String:
		trace.append("objective")
		return super.objective_tick(dt, host)
	func intercept_shot(host, shot: Dictionary) -> bool:
		hits.append({"tag": shot.get("tag", ""), "hearts": host.hearts, "crates": host.crates.map(func(c): return c.hp)})
		return shot.get("intercept", false)
	func after_pickups(dt: float, host) -> void:
		trace.append("world")
		super.after_pickups(dt, host)
	func finish_frame(host) -> void:
		trace.append("finish")
		super.finish_frame(host)

class ProbeCombat extends SupermarketCombat:
	var trace: Array = []
	var crate_hits: Array = []
	var hurts: Array = []
	func waves_tick(dt: float, host) -> void:
		trace.append("waves")
		super.waves_tick(dt, host)
	func enemies_tick(dt: float, host) -> void:
		trace.append("enemies")
		super.enemies_tick(dt, host)
	func projectiles_tick(dt: float, host) -> void:
		trace.append("shots")
		super.projectiles_tick(dt, host)
	func pickups_tick(dt: float, host) -> void:
		trace.append("pickups")
		super.pickups_tick(dt, host)
	func late_carts(dt: float, host) -> void:
		trace.append("carts")
		super.late_carts(dt, host)
	func late_drones(dt: float, host) -> void:
		trace.append("drones")
		super.late_drones(dt, host)
	func hit_crate(host, crate: Dictionary, damage: int) -> void:
		crate_hits.append({"hearts": host.hearts, "damage": damage, "hp": crate.hp})
		super.hit_crate(host, crate, damage)
	func _hurt(host, player: Dictionary, from_x: float) -> void:
		hurts.append({"friendly_left": host.bullets.filter(func(b): return not b.enemy).size(), "crates": host.crates.map(func(c): return c.hp)})
		super._hurt(host, player, from_x)
	# These methods deliberately exist only to detect leaked W1 host dispatch.
	func bob_flyers(_dt: float, _host) -> void: trace.append("WRONG_W1_FLYERS")
	func bailiff_volleys(_dt: float, _host) -> void: trace.append("WRONG_W1_BAILIFF")

class ProbeAbilities extends "res://src/abilities.gd":
	var trace: Array = []
	func tick(dt: float, controls: Dictionary, host, defer_effects: bool = false) -> void:
		trace.append("ability_pre")
		super.tick(dt, controls, host, defer_effects)
	func bubbles_tick(dt: float, host) -> void:
		trace.append("bubbles")
		super.bubbles_tick(dt, host)
	func effects_tick(dt: float, host) -> void:
		trace.append("effects")
		super.effects_tick(dt, host)

class ProbeWorldOne extends "res://src/world_one.gd":
	var trace: Array = []
	func after_motion(_host) -> void: trace.append("WRONG_W1_MOTION")
	func after_camera(_dt: float, _host) -> void: trace.append("WRONG_W1_CAMERA")
	func crumble_step(_dt: float, _host) -> void: trace.append("WRONG_W1_CRUMBLE")
	func chimney_step(_host) -> void: trace.append("WRONG_W1_CHIMNEY")
	func after_pickups(_host) -> void: trace.append("WRONG_W1_PICKUPS")

class ProbeBus extends "res://src/bus_ride.gd":
	var trace: Array = []
	func tick(_dt: float, _host) -> void: trace.append("WRONG_W1_BUS")

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void: call_deferred("run")

func no_waves(game) -> void:
	# Explicit isolation fixture, never legitimate progression evidence.
	for wave in game.combat.waves: wave.at = INF

func fresh(game) -> void:
	game.character = "jp"
	game.load_level("2-1")
	no_waves(game)

func advance(game, seconds: float, controls: Dictionary = {}) -> void:
	# Use ordinary <=34ms source-sized steps even for long timing assertions.
	var remaining := seconds
	while remaining > 0.00000001:
		var dt := minf(0.01, remaining)
		game.step(dt, controls)
		remaining -= dt

func stand(game, position: Vector2, camera_x: float = 0) -> void:
	game.player = position
	game.camera = Vector2(camera_x, 0)
	game.camera_speed = 0
	game.camera_lock = null
	game.velocity = Vector2.ZERO
	game.grounded = true
	game.on_platform = false
	game.hurt_lock = 0

func shot(position: Vector2, damage: int = 1, hostile: bool = false) -> Dictionary:
	return {"p": position, "v": Vector2.ZERO, "life": 20.0, "enemy": hostile, "damage": damage}

func bot(game, x: float, kind: String = "rush") -> Dictionary:
	game.combat.spawn(game, x, kind)
	var enemy: Dictionary = game.enemies.back()
	enemy.speed = 0.0
	enemy.stop = 300.0
	enemy.cd = 100.0
	enemy.entered = true
	return enemy

func lift_fixture(game) -> void:
	game.load_level("2-1")
	stand(game, Vector2(7550, 482), 7162)
	# Complete only earlier encounters to expose the real scene gate. Later
	# authored waves remain uncompleted, exactly as during a lift approach.
	for wave in game.combat.waves:
		if wave.at <= 7162:
			wave.started = true
			wave.done = true
			wave.index = wave.group.size()
	game.invincible = 99
	game.step(0, {})

func test_selection_and_surfaces(game) -> void:
	game.load_level("1-2")
	check(game.is_native_supported() and game._native_world_one() and not game._native_world_two() and game.combat is LegacyCombat, "W1 retains its original runtime and combat policy")
	check(game.world_one.crumbles.size() == 12 and game.combat.waves.size() == 11, "W1 rooftop data and live crumble controller remain intact")
	game.load_level("2-1")
	check(game.is_native_supported() and game._native_world_two() and not game._native_world_one() and game.combat is SupermarketCombat, "Only supported parking selects the separate W2 policy")
	check(game._source_ability_shots() and game.player == Vector2(300, 482) and game.boss == null, "Parking starts at authored feet with source-ordered ability shots and no fake boss")
	check(game.combat.waves.size() == 11 and game.combat.waves.reduce(func(total, w): return total + w.group.size(), 0) == 52, "Main loads every authored solo wave and all52 entries")
	check(game.crates.size() == 5 and game.receipts.size() == 3 and game.world_two.entities.size() == 4, "Main initializes five crates, three receipts and four trolley batches")
	check(game.world_two.hazards.size() == 17 and game.world_two.surfaces(game).size() == 14, "Runtime copies all17 hazard rows and14 source surfaces")
	check(game.world_two.camera_cap(game) == 7162 and game.world_two.scene_index == 0, "Top-deck camera cap is7600+300-738")
	var snapshot: Dictionary = game.world_two.snapshot()
	snapshot.entities[0].done = 999
	check(game.world_two.entities[0].done == 0, "Renderer/debug snapshot cannot mutate live trolley state")
	var authored: String = JSON.stringify(game.level)
	game.world_two.surfaces(game).append({"row": [500, 550, 350], "plat": false})
	game.world_two.surfaces(game).append({"row": [600, 650, 300], "plat": true})
	check(game.floor_at(525, 0) == 350 and game._land(525, 340, 360) == 350, "Host floor and landing route through runtime solids")
	check(game._land(625, 290, 310) == 300 and game._land(625, 290, 310, true) == INF, "Host landing preserves runtime one-way surfaces and drop-through")
	check(game.ability_land_on(625, 290, 310) == 300 and game.skill_floor_below(625, 0) == 300, "Ability and skill probes share runtime surfaces")
	check(game._wall_clamp(480, 520, 482) == 486 and game.skill_wall_clamp(480, 520, 482) == 486 and game.ability_inside_wall(Vector2(525, 355)), "Wall, skill and shot queries use live runtime solids")
	check(JSON.stringify(game.level) == authored, "Fixture runtime surfaces never mutate imported level JSON")
	for id in ["7-1"]:
		game.load_level("4-1"); game.level_id = id
		game._complete_level()
		check(not game.is_native_supported() and not game._native_world_one() and not game._native_world_two() and game.mode == "play" and not game.save.get("cleared", {}).get(id, false), "%s unknown run cannot fake a clear" % id)
	game.load_level("1-2")
	no_waves(game)
	game.hearts = 1
	game.camera.x = float(game.combat.checks[0].x) - game.view_width() * 0.5
	game.combat.tick(0, game)
	check(game.hearts == 2, "Original W1 checkpoint still gives its minimum two hearts")

func test_lift_and_lifecycle(game) -> void:
	game.load_level("2-1")
	stand(game, Vector2(7600, 482), 7162)
	game.scene_objective(10)
	check(game.mode == "play" and game.world_two.end_time == 0 and game.boss == null, "Lift approach cannot complete the stage or create a boss")
	game.step(0, {})
	check(not game.world_two.wiping, "Outstanding earlier authored waves block the lift")
	game.enemies.clear()
	for wave in game.combat.waves:
		if wave.at <= 7162: wave.done = true; wave.started = true
	stand(game, Vector2(7549.99, 482), 7162)
	game.step(0, {})
	check(not game.world_two.wiping, "Lift requires player at least7550, not merely camera at cap")
	game.player.x = 7550
	game.step(0, {})
	check(game.world_two.wiping and game.world_two.wipe_elapsed == 0 and game.world_two.wipe_kind == "lift" and game.world_two.wipe_label == "Ground floor", "Exact7550 trigger starts authored lift with zero elapsed wipe")
	game.invincible = 99
	game.bullets.append({"p": Vector2(7500, 200), "v": Vector2(100, 0), "life": 20.0, "enemy": false, "damage": 1})
	var elapsed: float = game.elapsed
	advance(game, 0.1, {"right": true})
	check(is_equal_approx(game.bullets[0].p.x, 7510) and game.elapsed > elapsed and game.player.x > 7550, "Player, projectile and gameplay clocks continue under the wipe")
	game._pause()
	var frozen: String = JSON.stringify(game.world_two.snapshot())
	var time: float = game.elapsed
	game.step(10, {"right": true})
	check(game.mode == "paused" and JSON.stringify(game.world_two.snapshot()) == frozen and game.elapsed == time, "Pause freezes lift and every runtime clock")
	game._resume()
	game.touches[77] = "right"
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game.step(10, {})
	check(game.mode == "paused" and game.touches.is_empty() and JSON.stringify(game.world_two.snapshot()) == frozen, "Application background clears held input and freezes lift")
	game._resume()
	advance(game, 1.329)
	check(game.world_two.scene_index == 0 and game.player.x <= 7600 and game.camera.x <= 7162 and not game.world_two.checkpoint_hit, "Before1.43seconds camera/player stay capped and checkpoint cannot trigger")
	advance(game, 0.002)
	check(game.world_two.scene_index == 1 and game.world_two.wiping and game.world_two.wipe_midpoint_done and game.player == Vector2(8020, 482), "At1.43seconds lift callback teleports to authored8020 landing")
	check(game.camera == Vector2(7860, 0) and game.velocity == Vector2.ZERO and game.bullets.is_empty(), "Lift resets camera/motion and clears both shot stores at frame end")
	check(not game.world_two.checkpoint_hit, "Checkpoint remains unprocessed until the pass after scene callback")
	game.hearts = 1
	game.step(0, {})
	check(game.world_two.checkpoint_hit and game.hearts == 3, "First post-lift checkpoint gives full three hearts, not W1 minimum two")
	advance(game, 0.738)
	check(game.world_two.wiping and game.world_two.wipe_elapsed < 2.17, "Iris remains active just before2.17seconds")
	advance(game, 0.002)
	check(not game.world_two.wiping and is_equal_approx(game.world_two.wipe_elapsed, 2.17), "Full wipe ends at2.17seconds while simulation stays live")
	# Restart and menu cancellation must reject an old callback generation.
	lift_fixture(game)
	advance(game, 0.1)
	var old_generation: int = game.world_two.run_generation
	game.load_level("2-1")
	check(game.world_two.run_generation > old_generation and not game.world_two._apply_scene_transition(game, old_generation) and game.player == Vector2(300, 482), "Fresh restart rejects stale lift callback and returns to source start")
	lift_fixture(game)
	old_generation = game.world_two.run_generation
	game._show_menu()
	game.step(20, {})
	check(game.mode == "menu" and not game.world_two.wiping and game.world_two.run_generation > old_generation and not game.world_two._apply_scene_transition(game, old_generation), "Map exit invalidates the in-flight wipe rather than merely hiding it")
	game.load_level("1-2")
	check(not game.world_two._apply_scene_transition(game, old_generation) and game._native_world_one() and game.player.x == float(game.level.start), "Old W2 callback cannot teleport a newly loaded W1 run")

func test_checkpoint_and_dead_pickups(game) -> void:
	fresh(game)
	game.world_two.scene_index = 1 # Geometry/lifecycle fixture, not traversal.
	stand(game, Vector2(7600, 482), 7330.99)
	game.hearts = 1
	game.step(0, {})
	check(not game.world_two.checkpoint_hit and game.hearts == 1, "Checkpoint remains pending below midpoint7700")
	game.camera.x = 7331
	game.bullets = [shot(game.player - Vector2(0, 60), 1, true)]
	var coin := {"p": game.player - Vector2(0, 60), "v": Vector2.ZERO, "age": 0.5, "rest": true}
	var heart := {"p": game.player - Vector2(0, 26), "vy": 0.0, "age": 0.5, "rest": true, "give": "heart"}
	game.coins = [coin]
	game.items = [heart]
	game.step(0, {})
	check(game.mode == "play" and game.hearts == 3 and game.invincible == 2 and game.world_two.checkpoint_hit, "Same-frame lethal bill is intentionally revived by late W2 checkpoint")
	check(game.score == 0 and game.coins.has(coin) and game.items.has(heart), "Dead ordinary pickup pass cannot collect coins/hearts before checkpoint revival")
	check(game.checkpoint == Vector2(300, 482), "W2 checkpoint does not overwrite Continue/fall-safe respawn coordinates")
	game.step(0, {})
	check(game.score == 1 and not game.coins.has(coin) and not game.items.has(heart), "Revived player can collect those ordinary pickups only on following pass")
	game.hearts = 1
	game.step(0, {})
	check(game.hearts == 1, "Consumed full-heal checkpoint cannot heal repeatedly")
	fresh(game)
	stand(game, Vector2(80, 482))
	game.hearts = 1
	game.bullets = [shot(Vector2(80, 420), 1, true)]
	game.coins = [{"p": Vector2(80, 420), "v": Vector2.ZERO, "age": 0.5, "rest": true}]
	game.items = [{"p": Vector2(80, 456), "vy": 0.0, "age": 0.5, "rest": true, "give": "heart"}]
	game.step(0, {})
	check(game.mode == "over" and game.hearts == 0 and game.score == 0 and not game.receipts[0].taken, "Without checkpoint a lethal bill cannot be rescued by heart/coin/receipt overlap")
	check(game.items.size() == 1 and game.coins.any(func(c): return c.p.x == 80), "Dead player leaves ordinary pickups untouched")
	fresh(game)
	stand(game, Vector2(80, 482))
	game.hearts = 1
	game.world_two.entities.append({"k": "trolley", "p": Vector2(80, 482), "v": Vector2.ZERO, "t": 0.0, "dead": false})
	game.step(0, {})
	check(game.mode == "over" and game.score == 0 and not game.receipts[0].taken, "Late trolley death precedes receipt collection and cannot reward a dead player")

func test_receipts_and_coins(game) -> void:
	game.save.receipts.erase("2-1")
	fresh(game)
	check(game.receipts[0].position == Vector2(80, 442) and game.receipts[1].position == Vector2(3920, 229), "W2 receipt drawing centers use source40pixel offset")
	advance(game, 0.82, {"left": true})
	check(game.receipts[0].taken and game.score == 5 and game.camera.x == 0, "Ordinary left input recovers behind-start receipt before camera advances")
	check(game.save.receipts["2-1"] == [0], "Source receipt1 adapts explicitly to native saved index0")
	game.collect_level_pickups()
	check(game.score == 5 and game.save.receipts["2-1"] == [0], "One receipt cannot reward twice within a run")
	game.load_level("2-1")
	check(not game.receipts[0].taken, "Source replay deliberately presents saved W2 receipts again")
	stand(game, Vector2(80, 452))
	game.collect_level_pickups()
	check(not game.receipts[0].taken and game.score == 0, "Receipt pickup rejects exact lower bound feet=y-30")
	game.player = Vector2(122, 482)
	game.collect_level_pickups()
	check(not game.receipts[0].taken, "Receipt pickup rejects exact42pixel horizontal boundary")
	game.player = Vector2(80, 482 + game.character_height())
	game.collect_level_pickups()
	check(not game.receipts[0].taken, "Receipt pickup rejects exact body-top equality")
	game.player = Vector2(80, 452.01)
	game.collect_level_pickups()
	check(game.receipts[0].taken and game.score == 5 and game.save.receipts["2-1"] == [0], "Replay reawards five kitty while persisted zero-based index stays deduplicated")
	for i in [1, 2]:
		game.player = Vector2(game.level.receipts[i][0], game.level.receipts[i][1])
		game.collect_level_pickups()
	check(game.receipts.all(func(r): return r.taken) and game.score == 15 and game.save.receipts["2-1"] == [0, 1, 2], "All three authored receipts store native indices0/1/2 and total15 kitty")
	game.load_level("1-2")
	game.save.receipts["1-2"] = [0]
	game.load_level("1-2")
	check(not game.receipts[0].taken and game.receipts[0].previously_collected and game.save.receipts["1-2"] == [0], "W1 source replay restores pickup while saved history remains intact")
	fresh(game)
	game.step(0, {})
	check(game.coins.size() == 5 and game.coins.all(func(c): return c.keep and c.rest and c.age == 0.3), "First authored coin row spawns after pickup phase with source rest/keep age")
	check(game.coins[0].p == Vector2(960, 312) and is_equal_approx(game.coins[2].p.y, 282) and game.coins[4].p == Vector2(1130, 312), "Authored row preserves endpoints and sine arc")
	var authored_coin: Dictionary = game.coins[0]
	authored_coin.age = 2.001
	game.step(0.01, {})
	check(authored_coin.age == 2 and game.coins.size() == 5, "Late keep-age clamp avoids respawning authored rows")
	advance(game, 12)
	check(game.coins.size() == 5 and game.coins.has(authored_coin) and authored_coin.age == 2, "Resting authored coins survive beyond ordinary11second expiration")
	var ordinary := {"p": Vector2(600, 420), "v": Vector2.ZERO, "age": 10.999, "rest": true}
	game.coins.append(ordinary)
	game.step(0.002, {})
	check(not game.coins.has(ordinary) and game.coins.has(authored_coin), "Ordinary dropped coins still expire independently of authored keep coins")
	stand(game, Vector2(2300, 482), 2000)
	game.step(0, {})
	check(not game.coins.has(authored_coin), "Authored keep flag does not prevent source behind-camera culling")

func test_phase_and_collision_order(game) -> void:
	fresh(game)
	var originals := {"world": game.world_two, "one": game.world_one, "bus": game.bus_ride, "combat": game.combat, "abilities": game.abilities, "runtime": game.scene_runtime}
	var trace: Array = []
	var runtime := ProbeWorld.new()
	var combat := ProbeCombat.new()
	var abilities := ProbeAbilities.new()
	var one := ProbeWorldOne.new()
	var bus := ProbeBus.new()
	runtime.trace = trace; combat.trace = trace; abilities.trace = trace; one.trace = trace; bus.trace = trace
	game.world_two = runtime; game.scene_runtime = runtime; game.combat = combat; game.abilities = abilities; game.world_one = one; game.bus_ride = bus
	runtime.reset(game); combat.reset(game); abilities.reset("jp")
	no_waves(game)
	game.step(0.016, {})
	check(trace == ["ability_pre", "waves", "objective", "enemies", "bubbles", "shots", "pickups", "world", "carts", "drones", "effects", "finish"], "Real main obeys every source phase and excludes all W1/bus late hooks")
	check(is_equal_approx(abilities._time, 0.016), "W2 ability effect clock advances exactly once per frame")
	trace.clear()
	var enemy: Dictionary = bot(game, 400)
	game.crates = [{"p": Vector2(500, 482), "hp": 3, "give": "heart", "broken": false, "hit": 0.0}, {"p": Vector2(600, 482), "hp": 3, "give": "heart", "broken": false, "hit": 0.0}]
	runtime.surfaces(game).append({"row": [590, 660, 400], "plat": false})
	var bot_shot := shot(Vector2(400, 430)); bot_shot.tag = "bot"
	var hook_shot := shot(Vector2(500, 430)); hook_shot.tag = "hook"; hook_shot.intercept = true
	var crate_shot := shot(Vector2(600, 430), 9); crate_shot.tag = "crate"
	var wall_shot := shot(Vector2(650, 430)); wall_shot.tag = "wall"
	# Hostile bill intentionally stored first, so an interleaved one-pass loop fails.
	game.bullets = [shot(Vector2(300, 420), 1, true), bot_shot, hook_shot, crate_shot, wall_shot]
	game.step(0, {})
	check(enemy.hp == 2 and runtime.hits.map(func(h): return h.tag) == ["hook", "crate", "wall"], "Bot consumes friendly shot before runtime hook; remaining hooks retain shot order")
	check(runtime.hits.all(func(h): return h.hearts == 3) and runtime.hits[1].crates == [3, 3], "Runtime hook runs before ordinary crates and all hostile damage")
	check(game.crates[0].hp == 3 and game.crates[1].hp == 2 and combat.crate_hits.size() == 1 and combat.crate_hits[0].damage == 1, "Hook intercept protects crate; ordinary crate takes exactly one HP even from damage9")
	check(combat.crate_hits[0].hearts == 3 and combat.hurts.size() == 1 and combat.hurts[0].friendly_left == 0 and combat.hurts[0].crates == [3, 2], "Crate resolution and final friendly wall cleanup precede hostile bill processing")
	check(game.hearts == 2 and game.bullets.is_empty(), "Actual hostile collision executes after every friendly shot is resolved")
	game.world_two = originals.world; game.scene_runtime = originals.runtime; game.world_one = originals.one; game.bus_ride = originals.bus; game.combat = originals.combat; game.abilities = originals.abilities

func test_spawn_and_late_motion(game) -> void:
	fresh(game)
	game.combat.spawn(game, 400, "rush")
	var enemy: Dictionary = game.enemies.back()
	check(enemy.p == Vector2(400, 482) and enemy.face == 1 and enemy.entered and enemy.arrival == 0.3, "Numeric spawn preserves world x, rightward face and source arrival state")
	game.enemies.clear()
	game.combat.spawn(game, 500, "big")
	enemy = game.enemies.back()
	check(enemy.hp == 24 and enemy.hw == 58 and enemy.hh == 186 and enemy.big and enemy.speed == 55 and enemy.stop == 250 and enemy.cd == 1.2, "Security bot uses source24HP/58x186 hitbox and ordinary arc-throw setup")
	check(not enemy.has("volley") and not enemy.has("fly") and game.boss == null, "Security cannot inherit W1 Bailiff volleys, flyers or boss hooks")
	enemy.speed = 0; enemy.cd = 100
	game.bullets = [shot(Vector2(555, 302))]
	game.step(0, {})
	check(enemy.hp == 23, "Real host projectile path honors enlarged security hitbox")
	game.enemies.clear()
	game.combat.reset(game, 2)
	check(game.combat.waves.reduce(func(total, w): return total + w.group.size(), 0) == 64 and game.combat.waves[5].group.map(func(g): return int(g[0])) == [0, 2500, 4500, 6500, 3500], "Two-participant schema appends all extras without sorting nonmonotonic delays")
	game.combat.spawn(game, 500, "big")
	check(game.enemies.back().hp == 34, "Participant-count fixture gives security34HP without claiming co-op implemented")
	fresh(game)
	stand(game, Vector2(450, 482))
	enemy = bot(game, 400, "cart")
	enemy.speed = 300; enemy.cart_dir = 1
	game.step(0.034, {})
	check(game.hearts == 3 and is_equal_approx(enemy.p.x, 410.2), "Cart contact uses old position before its late300px/s movement")
	game.step(0, {})
	check(game.hearts == 2, "Cart contacts player on following base enemy pass")
	fresh(game)
	enemy = bot(game, 500, "drone")
	enemy.phase = 0; enemy.p.y = 282
	check(enemy.hp == 2 and enemy.hw == 40 and enemy.hh == 70 and not enemy.has("fly"), "Barcode drone has source hitbox and intentionally no W1 fly flag")
	game.bullets = [shot(Vector2(500, 283))]
	game.step(0.034, {})
	check(enemy.hp == 2 and enemy.p.y > 283 and game.bullets.size() == 1, "Drone projectile collision sees pre-bob feet, not late hover position")
	game.step(0, {})
	check(enemy.hp == 1 and game.bullets.is_empty(), "Following projectile pass sees late drone position")
	enemy.cd = 0.001
	game.step(0.016, {})
	check(game.bullets.size() == 1 and game.bullets[0].get("sticker", false) and game.bullets[0].p == enemy.p + Vector2(0, 6) and game.bullets[0].v == Vector2(0, 50), "Late drone bill remains at source muzzle with unmoved50px/s velocity")
	var muzzle: Vector2 = game.bullets[0].p
	game.step(0.016, {})
	check(game.bullets.size() == 1 and game.bullets[0].p.y > muzzle.y and is_equal_approx(game.bullets[0].v.y, 69.2), "Drone sticker begins moving and applying1200gravity only next frame")

func test_bubbles_and_ghosts(game) -> void:
	fresh(game)
	var held: Dictionary = bot(game, 400)
	var ordinary: Dictionary = bot(game, 400)
	held.merge({"ab_bubble": 0.001, "ab_bubble_total": 4.2, "ab_floor": 482.0, "wait": 5.999}, true)
	var ai_time: float = held.t
	game.step(0.016, {})
	check(game.enemies[0] == ordinary and game.enemies[1] == held and held.ab_bubble == 0 and held.p.y == 482, "Main releases/reinserts held bubble after ordinary AI and before shot collisions")
	check(held.t == ai_time and held.wait == 5.999 and held.hp == 3 and ordinary.hp == 2, "Bubble skips AI/cleanup and same-frame release ghost hits earlier unheld bot")
	check(game.bullets.is_empty(), "Bubble release sting is collision-resolved this frame rather than deferred")
	fresh(game)
	game.character = "theo"; game.abilities.reset("theo")
	var enemy: Dictionary = bot(game, 440)
	game.abilities.effects = [{"kind": "ball", "p": Vector2(440, 400), "v": Vector2.ZERO, "age": 0.0, "life": 3.6, "spin": 0.0, "free": 0.0, "boss_next": 0.0, "floor": 482.0, "trail": []}]
	game.step(0.016, {})
	check(enemy.hp == 3 and game.bullets.size() == 1 and game.bullets[0].get("ghost", false) and game.bullets[0].damage == 2, "Theo late effect queues physical ghost without bypassing current combat order")
	game.step(0, {})
	check(enemy.hp == 1 and game.bullets.is_empty(), "Late ball ghost resolves through ordinary bot collision on following frame")
	game.bullets = [shot(Vector2(650, 150))]
	game.bullets[0].ghost = true; game.bullets[0].ghost_age = 0.069
	game.step(0.002, {})
	check(game.bullets.is_empty(), "Source ghost expiry runs after collision/effect phase at strictly70ms")

func test_continue_and_fresh_reset(game) -> void:
	lift_fixture(game)
	advance(game, 0.1)
	game.world_two.entities.append({"k": "trolley", "p": Vector2(7300, 482), "v": Vector2(360, 0), "t": 1.0, "dead": false})
	bot(game, 7400)
	game.receipts[0].taken = true
	game.score = 17
	game.coins = [{"p": Vector2(7250, 422), "v": Vector2.ZERO, "age": 0.5, "rest": true, "keep": true}]
	game.hearts = 1; game.invincible = 0
	game.bullets = [shot(game.player - Vector2(0, 60), 1, true)]
	game.step(0, {})
	check(game.mode == "over" and game.hearts == 0 and game.audio.paused and game.world_two.wiping, "Actual lethal collision freezes an in-flight lift encounter in game-over mode")
	var snapshot := JSON.stringify(game.world_two.snapshot())
	var waves := JSON.stringify(game.combat.waves)
	var enemies := JSON.stringify(game.enemies)
	var coins := JSON.stringify(game.coins)
	var position: Vector2 = game.player
	var camera: Vector2 = game.camera
	game.step(10, {})
	check(JSON.stringify(game.world_two.snapshot()) == snapshot and JSON.stringify(game.enemies) == enemies, "Game over freezes retained wipe and hazard/enemy state")
	game._continue_level()
	check(game.mode == "play" and game.hearts == 3 and game.invincible == 2.5 and not game.audio.paused, "Continue restores source three hearts and2.5second protection")
	check(game.player == position and game.camera == camera and JSON.stringify(game.world_two.snapshot()) == snapshot and JSON.stringify(game.combat.waves) == waves, "Continue retains scene, timer, trolleys, camera and wave progress")
	check(JSON.stringify(game.enemies) == enemies and JSON.stringify(game.coins) == coins and game.score == 17 and game.receipts[0].taken, "Continue retains enemies, loose coins, kitty and receipt state")
	game._continue_level()
	check(JSON.stringify(game.world_two.snapshot()) == snapshot and game.invincible == 2.5, "Repeated Continue outside game-over is a no-op")
	game.step(0.016, {})
	check(game.world_two.wipe_elapsed > 0.1 and game.world_two.entities.any(func(e): return e.k == "trolley" and e.p.x > 7300), "Continue advances the existing wipe/trolley instead of starting fresh")
	var generation: int = game.world_two.run_generation
	game.load_level("2-1")
	check(game.world_two.run_generation > generation and game.world_two.scene_index == 0 and not game.world_two.wiping and not game.world_two.checkpoint_hit and game.world_two.end_time == 0, "Explicit replay resets every scene/checkpoint/objective state")
	check(game.world_two.entities.size() == 4 and game.world_two.entities.all(func(e): return e.k == "tspawn" and not e.on and e.done == 0) and game.world_two.coins_done.is_empty(), "Fresh replay rebuilds untouched trolley batches and authored-coin flags")
	check(game.enemies.is_empty() and game.coins.is_empty() and game.bullets.is_empty() and game.score == 0 and game.receipts.all(func(r): return not r.taken), "Fresh replay resets encounter objects and source replay receipt rewards")
	game.load_level("2-1")
	check(game.world_two.entities.size() == 4 and game.combat.waves.size() == 11 and game.crates.size() == 5, "Repeated fresh load does not accumulate duplicate controllers or objects")

func test_defensive_specials_and_hurt_lock(game) -> void:
	for who in ["ama", "maya"]:
		game.character = who
		game.load_level("2-1")
		no_waves(game)
		game.abilities.meter = 1.0
		if who == "maya":
			game.abilities.active = "maya"
			game.abilities.remaining = 0.005
		game.bullets = [shot(game.player + Vector2(0, -80), 1, true)]
		game.step(0.01, {"special": who == "ama"})
		check(game.hearts == 3 and game.bullets.is_empty(), "%s cancels overlapping hostile bill before same-frame contact" % who)
	game.character = "theo"
	game.load_level("2-1")
	no_waves(game)
	stand(game, Vector2(2170, 482), 2000)
	game.hurt_lock = 0.4
	var crate: Dictionary = game.crates[0]
	check(crate.p == Vector2(2200, 482) and crate.hp == 3, "Hurt-lock kick uses the authored first parking crate")
	game.step(0.01, {"right": true})
	check(crate.hp == 3 and game.player.x == 2170 and game.hurt_lock > 0, "Theo cannot kick while directional input is hurt-locked")
	game.hurt_lock = 0
	game.step(0.01, {"right": true})
	check(crate.hp == 2, "Theo resumes source ghost-shot crate kick when movement unlocks")

func test_objective_and_persistence(game) -> void:
	game.save.erase("cleared")
	game.save.kitty = 0
	game.load_level("2-1")
	game.world_two.scene_index = 1 # End-controller fixture, not a completed run.
	stand(game, Vector2(15650, 482), 15262)
	game.invincible = 99
	game.scene_objective(10)
	check(game.mode == "play" and game.world_two.end_time == 0 and game.boss == null, "Exit distance without all eleven waves cannot start clear timer")
	for wave in game.combat.waves:
		wave.started = true; wave.done = true; wave.index = wave.group.size()
	game.combat.waves[-1].done = false
	var enemy: Dictionary = bot(game, 15700)
	enemy.hp = 1
	game.bullets = [shot(Vector2(15700, 430))]
	game.step(0.016, {})
	check(enemy.state == "pop" and not game.combat.waves[-1].done and game.world_two.end_time == 0, "Last bot killed after objective cannot release wave/end in the same frame")
	game.step(0, {})
	check(game.combat.waves[-1].done and game.world_two.end_time == 0.001 and game.mode == "play", "Next wave/objective pass starts source one-millisecond end clock")
	advance(game, 2.598)
	check(game.mode == "play" and not game.save.get("cleared", {}).get("2-1", false), "All waves still require strictly more than2.6seconds before persistent clear")
	advance(game, 0.002)
	check(game.mode == "clear" and game.save.get("cleared", {}).get("2-1", false) and game.boss == null, "Actual W2 objective banks native parking completion after source delay")
	var banked: int = game.save.kitty
	game.scene_objective(10); game._complete_level(); game._continue_level()
	check(game.mode == "clear" and game.save.kitty == banked, "Repeated objective/clear/Continue cannot bank completion twice")
	var loaded: Dictionary = SaveStore.read_save()
	check(loaded.get("cleared", {}).get("2-1", false) and loaded.get("kitty", -1) == banked, "Shared native capability allowlist retains legitimate parking clear on disk reload")
	var forged := {"schema": 1, "receipts": {"2-1": [0, 1, 2]}, "cleared": {"1-2": true, "2-1": true, "7-1": true, "7-2": true}}
	SaveStore.write_save(forged, "user://supermarket-allowlist-fixture.json")
	loaded = SaveStore.read_save("user://supermarket-allowlist-fixture.json")
	check(loaded.cleared.get("1-2", false) and loaded.cleared.get("2-1", false) and not loaded.cleared.has("7-1") and not loaded.cleared.has("7-2"), "Save reader accepts supported W1/parking but strips forged unknown-level clears")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	game.save = {"schema": 1, "receipts": {}, "skills": []}
	test_selection_and_surfaces(game)
	test_lift_and_lifecycle(game)
	test_checkpoint_and_dead_pickups(game)
	test_receipts_and_coins(game)
	test_phase_and_collision_order(game)
	test_spawn_and_late_motion(game)
	test_bubbles_and_ghosts(game)
	test_continue_and_fresh_reset(game)
	test_defensive_specials_and_hurt_lock(game)
	test_objective_and_persistence(game)
	game.queue_free()
	await process_frame
	print("Supermarket main integration: ", checks, " checks, ", failures.size(), " failures (focused fixtures, not full-run proof)")
	quit(0 if failures.is_empty() else 1)
