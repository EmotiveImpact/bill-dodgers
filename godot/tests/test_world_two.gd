extends SceneTree
const Runtime = preload("res://src/world_two.gd")
var failures: Array[String] = []
var checks := 0

class StubCombat extends RefCounted:
	var waves: Array = []
	var calls: Array = []
	func late_carts(_dt: float, host) -> void:
		calls.append("carts")
		host.observed_hearts = host.hearts
	func late_drones(_dt: float, _host) -> void: calls.append("drones")

class Host extends RefCounted:
	var level_id := "2-1"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var mode := "play"
	var elapsed := 0.0
	var player_animation := "idle"
	var player := Vector2(300, 482)
	var velocity := Vector2.ZERO
	var camera := Vector2.ZERO
	var camera_speed := 0.0
	var camera_lock = null
	var hearts := 3
	var invincible := 0.0
	var grounded := true
	var crouching := false
	var on_platform := false
	var face := 1
	var status := ""
	var enemies: Array = []
	var bullets: Array = []
	var coins: Array = []
	var crates: Array = []
	var items: Array = []
	var effects: Array = []
	var combat = StubCombat.new()
	var world_two = Runtime.new()
	var observed_hearts := -1
	var pickup_camera := -1.0
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func character_height() -> float: return 180.0
	func sfx(key: String) -> void: effects.append(key)
	func hurt_player(_from: float) -> void:
		if invincible > 0 or hearts <= 0: return
		hearts -= 1
		invincible = 1.5
		velocity.x = 350
	func add_coins(p: Vector2, count: int) -> void:
		for i in range(count): coins.append({"p": p, "v": Vector2.ZERO, "age": 0.0, "rest": false})
	func collect_level_pickups() -> void:
		combat.calls.append("pickups")
		pickup_camera = camera.x
	func load_source(id: String = "2-1") -> void:
		level_id = id
		meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % id))
		level = meta.level
		player = Vector2(float(level.start), float(meta.ground))
		velocity = Vector2.ZERO
		camera = Vector2.ZERO
		camera_speed = 0
		camera_lock = null
		hearts = 3
		invincible = 0
		grounded = true
		on_platform = false
		mode = "play"
		status = ""
		enemies.clear()
		bullets.clear()
		coins.clear()
		crates.clear()
		items.clear()
		effects.clear()
		combat.waves.clear()
		combat.calls.clear()
		for wave in level.get("waves", []): combat.waves.append({"at": wave.at, "started": false, "done": false})
		world_two.reset(self, 23)
	func step(dt: float) -> void:
		world_two.after_pickups(dt, self)
		world_two.finish_frame(self)
	func finish_early_waves() -> void:
		for wave in combat.waves:
			if wave.at <= 7162:
				wave.started = true
				wave.done = true
	func start_wipe() -> void:
		finish_early_waves()
		camera.x = 7162
		player.x = 7550
		step(0.016)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func near(a: float, b: float) -> bool: return absf(a - b) < 0.0001
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var h := Host.new()
	h.load_source()
	check(h.world_two.supports("2-1") and h.world_two.supports("2-2") and h.world_two.supports("2-3") and h.world_two.supports("2-S") and h.world_two.supports("2-6") and not h.world_two.supports("3-1"), "World 2 runtime supported; later worlds remain gated")
	check(h.world_two.surfaces(h).size() == 14 and h.world_two.surfaces(h, true).size() == 1, "Source ground and thirteen one-way car roofs imported")
	check(h.world_two.hazards.size() == 17 and h.world_two.entities.size() == 4, "Thirteen authored rows and four trolley batches preserved")
	check(h.level.receipts.size() == 3 and h.level.receipts[0][0] == 80 and h.level.receipts[0][1] == 482 and h.level.receipts[1][0] == 3920 and h.level.receipts[1][1] == 269 and h.level.receipts[2][0] == 12120 and h.level.receipts[2][1] == 269, "All source receipts preserved, including behind-start receipt")
	var original_meta := JSON.stringify(h.meta)
	check(h.world_two.land_on(h, 960, 329, 330).row == h.level.plats[0], "Car roof accepts inclusive left edge and exact top")
	check(h.world_two.land_on(h, 1130, 331, 329.5).row[2] == 330, "Car roof accepts old minus one and new plus half tolerances")
	check(h.world_two.land_on(h, 1130.1, 300, 340).is_empty(), "Car roof rejects just beyond right edge")
	check(h.world_two.land_on(h, 1000, 0, 500).row[2] == 330, "Landing chooses highest crossed surface")
	check(h.world_two.land_on(h, 1000, 0, 500, true).row[2] == 482, "Drop-through ignores roofs but not ground")
	check(h.world_two.below(h, 1000, 332).row[2] == 330 and h.world_two.below(h, 1000, 332.01).row[2] == 482, "Below retains exact two-pixel tolerance")
	check(h.world_two.wall_clamp(h, 900, 1000, 482) == 1000, "Painted cars and car roofs do not become body walls")
	check(not h.world_two.inside_wall(h, Vector2(1000, 482)) and not h.world_two.inside_wall(h, Vector2(1000, 486)) and h.world_two.inside_wall(h, Vector2(1000, 486.01)), "Ground interior has strict top plus four boundary")
	check(near(h.world_two.base_displacement(0.1, h, -1), -27), "Base270px/s excludes knockback/character bonus")
	h.player.x = 80
	check(h.world_two.wall_clamp(h, 300, 80, 482) == 80 and h.world_two.camera_cap(h) == 7162, "Behind-start receipt remains reachable before scrolling")
	h.level = {"w": 2000, "solids": [[0, 1000, 482], [200, 300, 300]], "plats": [[50, 150, 200]], "hz": [], "fall": 742}
	h.world_two.reset(h)
	check(h.world_two.wall_clamp(h, 100, 250, 482) == 186 and h.world_two.wall_clamp(h, 400, 250, 482) == 314, "Solid side walls retain14pixel player offset")
	check(h.world_two.wall_clamp(h, 100, 250, 306) == 250 and h.world_two.wall_clamp(h, 100, 250, 306.1) == 186, "Wall ignores top exactly six pixels above feet")
	check(not h.world_two.inside_wall(h, Vector2(200, 400)) and h.world_two.inside_wall(h, Vector2(200.1, 400)), "Wall horizontal bounds remain strict")
	h.player = Vector2(400, 482)
	h.world_two.after_motion(h)
	check(h.world_two.safe_position == Vector2(400, 482), "Interior solid remembers safe recovery position")
	h.player = Vector2(100, 200)
	h.on_platform = true
	h.world_two.after_motion(h)
	check(h.world_two.safe_position == Vector2(400, 482), "One-way platform does not replace solid safe position")
	h.on_platform = false
	h.player = Vector2(90, 482)
	h.world_two.after_motion(h)
	check(h.world_two.safe_position == Vector2(400, 482), "Exactly90pixel inset does not become safe position")
	h.load_source()
	h.camera.x = 1000
	h.player = Vector2(50, 800)
	h.invincible = 9
	h.velocity = Vector2(20, 700)
	h.world_two.recover_from_fall(h)
	check(h.player == Vector2(1070, 330) and h.hearts == 2, "Fall clamps old safe x to camera, finds roof there, and damages despite prior invulnerability")
	check(h.velocity == Vector2.ZERO and h.grounded and h.on_platform and near(h.invincible, 1.5), "Recovery zeroes motion and applies normal hurt protection")
	h.level = {"w": 2000, "solids": [[0, 200, 482], [400, 1000, 482]], "plats": [], "hz": [], "fall": 742}
	h.player = Vector2(200, 800)
	h.camera = Vector2.ZERO
	h.world_two.reset(h)
	h.world_two.recover_from_fall(h)
	check(h.player == Vector2(440, 482), "Fall search steps right20pixels until strictly30inside a valid solid")

	# Source scene gating is independent of distance-end objective.
	h.load_source()
	h.camera.x = 7162
	h.player.x = 7700
	h.step(0.016)
	check(h.player.x == 7600 and not h.world_two.wiping, "Scene caps player at7600 even while earlier waves remain unfinished")
	h.finish_early_waves()
	h.combat.waves[6].started = true
	h.step(0.016)
	check(not h.world_two.wiping, "Any active wave blocks transition even beyond scene cap")
	h.combat.waves[6].started = false
	h.player.x = 7549.9
	h.step(0.016)
	check(not h.world_two.wiping and h.status == "Take the lift down!", "Trigger is strict7550 and near-cap hint uses authored copy")
	h.player.x = 7550
	h.step(0.016)
	check(h.world_two.wiping and h.world_two.scene_index == 0 and h.world_two.wipe_elapsed == 0, "Trigger starts iris without immediate teleport or consuming trigger-frame dt")
	check(h.world_two.wipe_kind == "lift" and h.world_two.wipe_label == "Ground floor", "Iris retains source lift label")
	check(h.world_two.wipe_focus_start == Vector2(504.4, 324), "Iris captures source screen-space player focus")
	h.bullets = [{"owner": "player"}, {"owner": "enemy"}]
	h.enemies = [{"p": Vector2(7900, 482), "state": "walk"}, {"p": Vector2(7950, 482), "state": "walk"}]
	h.camera.y = -50
	h.camera_speed = 40
	h.velocity = Vector2(200, -100)
	h.on_platform = true
	var old_safe: Vector2 = h.world_two.safe_position
	h.step(1.429)
	check(h.world_two.scene_index == 0 and h.bullets.size() == 2 and not h.world_two.checkpoint_hit, "No transition before1430ms; checkpoint remains beyond capped camera")
	check(h.combat.calls.size() > 6 and h.world_two.elapsed > 1.4, "Late simulation and world clock continue during visual wipe")
	h.world_two.after_pickups(0.001, h)
	check(h.world_two.scene_index == 0 and h.player.x == 7550, "Due transition waits for explicit finish_frame after late ability effects")
	h.world_two.finish_frame(h)
	check(h.world_two.scene_index == 1 and h.player == Vector2(8020, 482), "Actual lift callback at1430ms moves to8020 at highest destination surface")
	check(h.world_two.wiping and h.world_two.wipe_midpoint_done and h.world_two.camera_cap(h) == INF, "Visual wipe stays active after callback; scene cap releases")
	check(h.camera == Vector2(7860, 0) and h.camera_speed == 0 and h.velocity == Vector2.ZERO and h.grounded, "Callback resets cameraY/speed and player velocities")
	check(h.bullets.is_empty() and h.enemies[0].state == "pop" and h.enemies[1].state == "walk", "Callback clears both shot types and only pops enemies left of destination minus100")
	check(h.world_two.safe_position == old_safe and h.on_platform, "Callback preserves source safe and onPlat caches")
	check(h.pickup_camera == 7162 and not h.world_two.checkpoint_hit, "Destination receipts and checkpoint do not run retroactively on callback frame")
	h.hearts = 1
	h.invincible = 0.4
	h.step(0.14)
	check(h.world_two.checkpoint_hit and h.hearts == 3 and near(h.invincible, 0.4), "Following late frame tops up hearts without resetting living invulnerability")
	check(h.world_two.wipe_focus_end == Vector2(211.2, 324), "Open focus captures destination player and source22percent clamp at1570ms")
	h.hearts = 1
	h.step(0.599)
	check(h.world_two.wiping and h.hearts == 1, "Iris remains until2170ms and checkpoint heals only once")
	h.step(0.001)
	check(not h.world_two.wiping and near(h.world_two.wipe_elapsed, 2.17), "Iris finishes at source2170ms visual duration")
	check(JSON.stringify(h.meta) == original_meta, "Scene, coins, trolleys and checkpoint never mutate original metadata")

	# Pause, Continue and stale-run safety are independent of the draw path.
	h.load_source()
	h.start_wipe()
	h.step(0.5)
	var paused := h.world_two.snapshot()
	var old_calls: int = h.combat.calls.size()
	h.mode = "paused"
	h.step(30)
	check(h.world_two.snapshot() == paused and h.combat.calls.size() == old_calls, "Actual pause freezes wipe/world/entities and does not dispatch late combat or pickups")
	check(h.world_two.base_displacement(1, h, 1) == 0 and h.world_two.objective_tick(30, h) == "", "Pause also freezes movement and objective")
	h.mode = "play"
	h.step(0.929)
	check(h.world_two.scene_index == 0, "Paused wall-clock time does not fast-forward callback on resume")
	h.step(0.001)
	check(h.world_two.scene_index == 1, "Resumed simulation reaches original callback after remaining time")
	var token: int = h.world_two.run_generation
	h.world_two.invalidate_run()
	h.player = Vector2(200, 482)
	check(not h.world_two._apply_scene_transition(h, token) and h.player.x == 200, "Invalidated callback cannot move exited run")
	h.load_source()
	h.start_wipe()
	token = h.world_two.run_generation
	h.world_two.after_pickups(1.43, h)
	h.load_source()
	check(not h.world_two._apply_scene_transition(h, token) and h.player.x == 300 and h.world_two.scene_index == 0, "Restart invalidates even a queued callback for same level")
	check(h.world_two.entities.size() == 4 and h.world_two.entities.all(func(e): return e.done == 0 and not e.on) and h.world_two.coins_done.is_empty(), "Fresh reset clears every batch counter/coin row flag")
	h.start_wipe()
	h.world_two.after_pickups(1.43, h)
	token = h.world_two.run_generation
	h.level_id = "1-1"
	check(not h.world_two._apply_scene_transition(h, token) and h.player.x == 7550, "Mismatched level rejects callback even before explicit invalidation")
	h.load_source()
	h.camera.x = 7600
	h.hearts = 0
	h.step(0.016)
	check(h.hearts == 3 and near(h.invincible, 2.0) and h.world_two.checkpoint_hit and h.observed_hearts == 3, "Late checkpoint revives a zero-heart player before late carts/drones/receipts")
	check(h.combat.calls.slice(-3) == ["carts", "drones", "pickups"], "World late order is carts then drones then level pickups")
	var continued_snapshot := h.world_two.snapshot()
	h.hearts = 0
	h.mode = "over"
	h.step(4)
	h.hearts = 3
	h.invincible = 2.5
	h.mode = "play"
	check(h.world_two.snapshot() == continued_snapshot, "Continue changes host hearts/mode, not runtime scene/batches/checkpoint/elapsed")
	h.load_source()
	h.start_wipe()
	h.world_two.after_pickups(1.43, h)
	h.hearts = 0
	h.world_two.finish_frame(h)
	check(h.hearts == 3 and h.world_two.scene_index == 1, "Source transition callback revives player downed during wipe")
	h.load_source()
	h.start_wipe()
	h.step(0.7)
	var generation_before_continue: int = h.world_two.run_generation
	h.mode = "over"
	h.hearts = 0
	h.step(20)
	h.hearts = 3
	h.mode = "play"
	h.invincible = 2.5
	h.step(0.729)
	check(h.world_two.scene_index == 0 and h.world_two.run_generation == generation_before_continue, "Continue during wipe retains original token and simulation clock")
	h.step(0.001)
	check(h.world_two.scene_index == 1 and near(h.invincible, 2.5), "Continued wipe executes pending callback and preserves Continue protection")
	h.load_source()
	h.start_wipe()
	h.world_two.after_pickups(1.43, h)
	token = h.world_two.run_generation
	h.mode = "paused"
	h.world_two.finish_frame(h)
	check(h.world_two.scene_index == 0, "Pause between queue and finish blocks even an already-due callback")
	var other_host := Host.new()
	other_host.load_source()
	check(not h.world_two._apply_scene_transition(other_host, token) and other_host.player.x == 300, "Callback also rejects a different host with same level ID")
	h.mode = "play"
	h.world_two.finish_frame(h)
	check(h.world_two.scene_index == 1, "A due callback runs once after explicitly resumed finish_frame")

	# Authored rows are late spawn, one-shot, stationary and age-kept.
	h.load_source()
	h.camera.x = -38
	h.step(0)
	check(h.coins.is_empty(), "Authored row does not spawn at exact camera plus width plus260 boundary")
	h.camera.x += 0.001
	h.step(0)
	check(h.coins.size() == 5 and h.world_two.coins_done.size() == 1, "Authored row spawns immediately inside strict prefetch boundary")
	check(h.coins[0].p == Vector2(960, 312) and h.coins[2].p == Vector2(1045, 282) and h.coins[4].p == Vector2(1130, 312), "Authored coin positions retain even spacing and sine arc")
	check(h.coins.all(func(c): return near(c.age, 0.3) and c.rest and c.keep and c.v == Vector2.ZERO), "New rows use source300ms rest/keep schema")
	h.coins[0].age = 5
	h.coins[1].age = 5
	h.coins[1].rest = false
	h.coins.append({"p": Vector2(950, 400), "v": Vector2.ZERO, "age": 5.0, "rest": true})
	h.step(0)
	check(h.coins[0].age == 2 and h.coins[1].age == 5 and h.coins.back().age == 5, "Late keep-age applies only authored resting coins, not airborne or dropped coins")
	h.coins.pop_back()
	h.camera.x = 16000
	h.step(0)
	check(h.coins.size() == 73 and h.world_two.coins_done.size() == 13, "All thirteen authored rows emit exact73coin total")
	h.step(0)
	check(h.coins.size() == 73, "Rows never spawn twice in one run")
	var snapshot := h.world_two.snapshot()
	snapshot.entities[0].done = 999
	check(h.world_two.entities[0].done != 999, "Renderer/test snapshot does not share entity mutation")
	var unknown := ["future-hazard", 111, {"payload": [2, 3]}]
	h.level.hz.append(unknown)
	h.world_two.reset(h)
	check(h.world_two.unsupported_hazards == [unknown], "Unknown future hazard schema is preserved losslessly, not activated or discarded")
	h.world_two.unsupported_hazards[0][2].payload[0] = 99
	check(h.level.hz.back()[2].payload[0] == 2, "Preserved unknown schema is deeply detached from imported metadata")

	# Four source batches, per-frame spawn limits, contact boundaries/physics.
	h.load_source()
	h.camera.x = 2599.99
	h.step(0.016)
	check(h.world_two.entities[0].done == 0, "First trolley batch waits for camera2600")
	h.camera.x = 2600
	h.step(0.016)
	check(h.world_two.entities[0].done == 1 and h.world_two.entities.size() == 5, "First batch activates and spawns immediately in same update")
	var trolley: Dictionary = h.world_two.entities.back()
	check(trolley.p.x < 3428 and trolley.p.x > 3420 and trolley.v.x <= -360 and trolley.v.x >= -440 and near(trolley.t, 0.016), "Fresh trolley enters right edge plus90 and moves immediately at360–440px/s")
	h.step(1.299)
	check(h.world_two.entities[0].done == 1, "Batch retains1300ms gap after first spawn")
	h.step(0.001)
	check(h.world_two.entities[0].done == 2, "Batch spawns second trolley at1300ms")
	h.step(20)
	check(h.world_two.entities[0].done == 3, "Large dt creates only one remaining trolley, with no catch-up loop")
	h.step(20)
	check(h.world_two.entities[0].done == 3, "Exhausted batch never respawns")
	h.camera.x = 13900
	h.step(0)
	check(h.world_two.entities.slice(0, 4).map(func(e): return e.n) == [3, 5, 4, 3], "All four source counts retained")
	check(h.world_two.entities.slice(0, 4).map(func(e): return e.gap) == [1.3, 0.75, 1.0, 1.1], "All batch gaps convert ms to seconds")
	var rightward: Dictionary = h.world_two.entities.back()
	check(rightward.p.x == 13810 and rightward.v.x >= 360 and rightward.v.x <= 440, "Fourth batch enters left90 and travels right")
	for i in range(5): h.step(2)
	check(h.world_two.entities.filter(func(e): return e.k == "tspawn").map(func(e): return e.done) == [3, 5, 4, 3], "All four batches finish all fifteen authored spawn attempts")
	h.load_source()
	h.level.solids = []
	h.level.plats = []
	h.world_two.reset(h)
	h.camera.x = 2600
	h.step(0)
	check(h.world_two.entities[0].done == 1 and h.world_two.entities.size() == 4 and "throw" in h.effects, "Failed support consumes trolley attempt and retains throw sound, without wedging batch")
	h.load_source()
	h.world_two.entities = [{"k": "trolley", "p": Vector2(500, 482), "v": Vector2.ZERO, "t": 0.0}]
	h.player = Vector2(546, 482)
	h.step(0)
	check(h.hearts == 3, "Trolley contact excludes exact46horizontal boundary")
	h.player.x = 545.99
	h.player.y = 396
	h.step(0)
	check(h.hearts == 3, "Trolley contact excludes exact top86boundary")
	h.player.y = 502
	h.step(0)
	check(h.hearts == 3, "Trolley contact excludes exact bottom20boundary")
	h.player.y = 501.99
	h.step(0)
	check(h.hearts == 2, "Trolley harms inside strict body rectangle")
	check(not h.world_two.intercept_shot(h, {"p": Vector2(500, 450)}) and h.world_two.land_on(h, 500, 390, 400).is_empty(), "Autonomous trolley is neither shootable nor a supporting platform")
	h.level = {"w": 2000, "solids": [[0, 2000, 482], [600, 700, 300]], "plats": [], "hz": [], "fall": 742}
	h.world_two.reset(h)
	h.world_two.entities = [{"k": "trolley", "p": Vector2(580, 482), "v": Vector2(400, 0), "t": 0.0}]
	h.step(0.1)
	trolley = h.world_two.entities[0]
	check(trolley.p.x == 620 and trolley.v.x == -240, "Trolley wall collision reverses/attenuates without correcting penetrated x")
	h.level.solids = [[0, 2000, 600]]
	h.world_two.reset(h)
	h.world_two.entities = [{"k": "trolley", "p": Vector2(500, 482), "v": Vector2.ZERO, "t": 0.0}]
	h.step(0.1)
	trolley = h.world_two.entities[0]
	check(trolley.p.y == 512 and trolley.v.y == 300, "Unsupported trolley integrates3000px/s² gravity")
	h.step(0.2)
	check(trolley.p.y == 600 and trolley.v.y == 0, "Falling trolley lands on crossed supporting surface")
	h.world_two.entities = [{"k": "trolley", "p": Vector2(-300, 600), "v": Vector2.ZERO, "t": 0.0}]
	h.step(0)
	check(h.world_two.entities.size() == 1, "Trolley cull keeps exact camera minus300 boundary")
	h.world_two.entities[0].p.x -= 0.01
	h.step(0)
	check(h.world_two.entities.is_empty(), "Trolley culls only beyond strict camera boundary")
	h.load_source()
	h.level.solids.append([200, 500, 400])
	h.level.solids.append([200, 500, 300])
	h.world_two.reset(h)
	h.enemies = [{"p": Vector2(300, 482), "state": "walk"}, {"p": Vector2(300, 482), "state": "drone"}, {"p": Vector2(300, 482), "state": "pop"}]
	h.step(0)
	check(h.enemies[0].p.y == 400 and h.enemies[0].segment == [200, 500, 400], "Late embedded-bot repair chooses first overlapping eligible solid and updates segment")
	check(h.enemies[1].p.y == 482 and h.enemies[2].p.y == 482, "Embedded-bot repair excludes drones and popped bots")

	# Source normal exit waits for all waves and strictly beyond2600ms.
	h.load_source()
	h.camera.x = 15262
	check(h.world_two.objective_tick(1, h) == "" and h.world_two.end_time == 0, "Distance cannot bypass unfinished waves")
	for wave in h.combat.waves: wave.done = true
	h.camera.x = 15259.9
	check(h.world_two.objective_tick(1, h) == "", "Normal exit waits for camera width minus view minus2")
	h.camera.x = 15260
	check(h.world_two.objective_tick(0.016, h) == "ending" and near(h.world_two.end_time, 0.017), "Normal exit uses1ms sentinel and adds first frame delta")
	h.world_two.end_time = 2.6
	check(h.world_two.objective_tick(0, h) == "", "Exactly2600ms cannot clear")
	check(h.world_two.objective_tick(0.0001, h) == "clear" and h.world_two.objective_tick(5, h) == "", "Strictly later exit returns clear exactly once")
	h.load_source("2-6")
	h.camera.x = 4162
	for wave in h.combat.waves: wave.done = true
	check(h.world_two.objective_tick(10, h) == "" and h.world_two.end_time == 0, "Checkout cannot accidentally use parking timed exit")
	check(h.world_two.hazards == h.level.hz and h.world_two.camera_cap(h) == 4162 and h.world_two.checkout.boss.get("state") == "enter", "Checkout retains authored hazards and starts its dedicated locked encounter")
	print("World 2 runtime: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
