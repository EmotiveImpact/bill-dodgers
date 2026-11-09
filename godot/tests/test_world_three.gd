extends SceneTree
const Runtime = preload("res://src/world_three.gd")
var failures: Array[String] = []
var checks := 0

class StubCombat extends RefCounted:
	var waves: Array = []
	var boss_starts: Array = []
	func start_boss(host, cfg: Dictionary) -> void:
		boss_starts.append({"config": cfg.duplicate(true), "tied": host.world_three.tied, "hearts": host.hearts, "coins": host.coins.size()})
		host.boss = {"state": "enter", "cfg": cfg}
		host.camera_lock = cfg.cam

class Host extends RefCounted:
	var level_id := "3-1"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var mode := "play"
	var final_base_step := false
	var player := Vector2(300, 482)
	var velocity := Vector2.ZERO
	var camera := Vector2.ZERO
	var camera_speed := 0.0
	var camera_lock = null
	var hearts := 3
	var invincible := 0.0
	var grounded := true
	var on_platform := false
	var face := 1
	var power := ""
	var status := ""
	var enemies: Array = []
	var bullets: Array = []
	var coins: Array = []
	var effects: Array = []
	var festival_events: Array = []
	var pickup_observations: Array = []
	var boss = null
	var combat = StubCombat.new()
	var world_three = Runtime.new()
	func festival_base_step_active() -> bool: return final_base_step
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func character_height() -> float: return 180.0
	func sfx(key: String) -> void: effects.append(key)
	func festival_event(event: Dictionary) -> void: festival_events.append(event.duplicate(true))
	func hurt_player(_from: float) -> void:
		if invincible > 0 or hearts <= 0: return
		hearts -= 1
		invincible = 1.5
		velocity.x = 350
	func collect_level_pickups() -> void:
		pickup_observations.append({"camera": camera.x, "coins": coins.size(), "tied": world_three.tied, "checkpoint": world_three.checkpoint_done, "hearts": hearts})
	func load_source(id: String = "3-1") -> void:
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
		power = ""
		mode = "play"
		status = ""
		enemies.clear()
		bullets.clear()
		coins.clear()
		effects.clear()
		festival_events.clear()
		pickup_observations.clear()
		boss = null
		combat.waves.clear()
		combat.boss_starts.clear()
		for row in meta.get("l3", {}).get("waves", []): combat.waves.append({"at": row[0], "started": false, "done": false})
		world_three.reset(self, 31)
	func step(dt: float) -> void:
		world_three.after_motion(self)
		world_three.after_camera(dt, self)
		world_three.after_pickups(dt, self)
		world_three.finish_frame(self)
	func start_wipe() -> void:
		camera.x = 6700
		player.x = 7100
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
	_geometry(h)
	_movement(h)
	_finds_coins_and_order(h)
	_checkpoint_and_mini(h)
	_scenes(h)
	_lifecycle(h)
	_objective(h)
	_source_contract()
	if failures.is_empty(): print("World 3 runtime: ", checks, " isolated checks passed (3-1 only; no device/full-run claim).")
	else: printerr("World 3 runtime: ", failures.size(), " of ", checks, " checks failed.")
	quit(0 if failures.is_empty() else 1)

func _geometry(h) -> void:
	check(h.world_three.supports("3-1") and h.world_three.supports("3-2") and h.world_three.supports("3-3") and h.world_three.supports("3-4") and h.world_three.supports("3-5") and h.world_three.supports("3-6") and not h.world_three.supports("4-1") and h.world_three.supports("3-S") and not h.world_three.supports("4-S") and not h.world_three.supports("2-1"), "Only completed field, queue, night, big-top, hayride, finale and bonus runtimes are advertised")
	check(h.world_three.surfaces(h).size() == 31 and h.world_three.surfaces(h, true).size() == 28, "All28solid+3platform source rows imported")
	check(h.world_three.tents.size() == 16 and h.world_three.trailer.is_empty(), "All16tents copied without inventing a trailer")
	check(h.world_three.tents[1].kind == "cut:dome-orange@335" and h.world_three.tents[1].col == 0 and h.world_three.tents[1].shake == 0, "Tent kind/color/shake schema survives import")
	check(h.world_three.surfaces(h)[28].nospawn and h.world_three.surfaces(h)[28].style == "vanroof", "Surface properties are exposed alongside copied row")
	check(h.world_three.land_on(h, 8532, 245, 246).row == h.level.plats[0], "Roof accepts inclusive leftedge and exacttop")
	check(h.world_three.land_on(h, 8852, 247, 245.5).row == h.level.plats[0], "Roof accepts inclusive rightedge and oldminus1/newplus0.5")
	check(h.world_three.land_on(h, 8852.01, 240, 250).is_empty(), "Roof rejects just beyond rightedge")
	check(h.world_three.land_on(h, 8700, 0, 500).row[2] == 246, "Landing chooses highest crossed roof")
	check(h.world_three.land_on(h, 8700, 0, 500, true).row[2] == 482, "Dropping ignores roof only")
	check(h.world_three.below(h, 8700, 248).row[2] == 246 and h.world_three.below(h, 8700, 248.01).row[2] == 482, "Below preserves two-pixel inclusive tolerance")
	check(h.world_three.wall_clamp(h, 1400, 1600, 482) == 1486, "Bale at1500 blocks at1486 with14pixeloffset")
	check(h.world_three.wall_clamp(h, 2050, 1900, 482) == 1994, "Bale rightedge blocks leftward at1994")
	check(h.world_three.wall_clamp(h, 1400, 1600, 434) == 1600 and h.world_three.wall_clamp(h, 1400, 1600, 434.01) == 1486, "Wall sixpixel top tolerance is inclusive")
	check(h.world_three.wall_clamp(h, 8500, 8600, 482) == 8600, "One-way van roof never becomes a wall")
	check(not h.world_three.inside_wall(h, Vector2(1500, 450)) and not h.world_three.inside_wall(h, Vector2(1600, 432)) and h.world_three.inside_wall(h, Vector2(1600, 432.01)), "Insidewall x and top+4 boundaries remain strict")
	var continuous := true
	for x in range(0, 15800, 20):
		if h.world_three.below(h, x, -9999).is_empty(): continuous = false
	check(continuous, "Authored ground and bales cover full reachable field without invented gaps")
	var original := JSON.stringify(h.meta)
	h.world_three.surfaces(h)[28].row[0] = 8500
	h.world_three.surfaces(h)[28].row[3].nospawn = false
	h.world_three.tents[0].x = 999
	check(JSON.stringify(h.meta) == original, "Mutable surface rows/nestedprops/tents never alias imported metadata")
	h.load_source()
	h.player = Vector2(600, 482)
	h.world_three.after_motion(h)
	check(h.world_three.safe_position == h.player, "Solid interior stores latest safe position")
	h.player = Vector2(1410, 482)
	h.world_three.after_motion(h)
	check(h.world_three.safe_position == Vector2(600, 482), "Exactly90pixel boundary does not replace safe point")
	h.player = Vector2(8700, 246)
	h.on_platform = true
	h.world_three.after_motion(h)
	check(h.world_three.safe_position == Vector2(600, 482), "One-way roof does not replace solid recovery point")
	h.camera.x = 8500
	h.invincible = 99
	h.player = Vector2(600, 900)
	h.world_three.recover_from_fall(h)
	check(h.player == Vector2(8570, 246) and h.hearts == 2 and near(h.invincible, 1.5), "Fall clamps cached x to camera and damages through previous invincibility")
	check(h.velocity == Vector2.ZERO and h.grounded and h.on_platform and h.status == "Mind the gap!", "Fall restores highest valid roof and zeros both velocities")
	h.load_source()
	h.level = {"solids": [[0, 200, 482], [400, 1000, 482]], "plats": [], "w": 2000}
	h.player = Vector2(200, 900)
	h.world_three.reset(h)
	h.world_three.recover_from_fall(h)
	check(h.player == Vector2(440, 482), "Fall20pixel search requires strictly30pixel surface inset")

func _movement(h) -> void:
	h.load_source()
	check(near(h.world_three.base_displacement(0.1, h, 1), 27) and near(h.world_three.base_displacement(0.1, h, -1), -27), "Base270px/s displacement excludes character bonuses/knockback")
	for row in h.level.mud:
		h.player = Vector2(row[0], 482)
		check(not h.world_three.in_mud(h), "Mud rejects exactleft " + str(row[0]))
		h.player.x += 0.01
		check(h.world_three.in_mud(h), "Mud accepts insideleft " + str(row[0]))
		h.player.x = row[1]
		check(not h.world_three.in_mud(h), "Mud rejects exactright " + str(row[1]))
	h.player = Vector2(2200, 485.99)
	check(h.world_three.in_mud(h), "Mud accepts feet within4pixels of482")
	h.player.y = 486
	check(not h.world_three.in_mud(h), "Mud rejects exactly4pixels off ground")
	h.player.y = 482
	h.grounded = false
	check(not h.world_three.in_mud(h) and h.world_three.jump_multiplier(h) == 1, "Airborne feet over mud avoid slowdown")
	h.grounded = true
	check(near(h.world_three.base_displacement(0.1, h, 1), 14.85) and near(h.world_three.jump_multiplier(h), 0.84), "Mud applies0.55movement and0.84jump")
	h.invincible = 5
	h.world_three.set_tied(h, {"host_player": true}, 2.2)
	check(h.hearts == 3 and near(h.world_three.tied, 2.2) and not h.world_three.can_jump(h), "Tied applies during invincibility and blocks normaljump")
	check(near(h.world_three.base_displacement(0.1, h, 1), 6.6825), "Tied0.45multiplies mud0.55")
	h.power = "wellies"
	check(near(h.world_three.base_displacement(0.1, h, 1), 12.15) and h.world_three.jump_multiplier(h) == 1 and not h.world_three.can_jump(h), "Wellies remove mud modifiers but not tie")
	check(h.world_three.allow_drop(h), "Tied does not block source drop-through branch")
	h.world_three.after_pickups(0.2, h)
	check(near(h.world_three.tied, 2), "Tie decrements in latelevel phase")
	h.world_three.set_tied(h, {}, 2.2)
	check(near(h.world_three.tied, 2.2), "A new wristband refreshes exactly2.2seconds")
	h.world_three.after_pickups(2.2, h)
	check(h.world_three.can_jump(h) and h.world_three.tied == 0, "Tie clamps tozero at exactexpiry")
	var other := {"p": Vector2(2200, 482), "grounded": true, "tied": 0.0}
	h.world_three.set_tied(h, other, 1.4)
	check(near(other.tied, 1.4) and h.world_three.tied == 0 and h.world_three.in_mud(h, other), "Explicit mutable participant tie never affects primary")
	h.load_source()
	h.level = {"solids": [], "plats": [[0, 1000, 100, {"nodrop": true, "conv": 0.2}]], "w": 2000}
	h.player = Vector2(100, 100)
	h.on_platform = true
	h.world_three.reset(h)
	h.world_three.after_motion(h)
	var surface: Dictionary = h.world_three.surfaces(h)[0]
	surface.row[2] = 103
	surface.dx = 5
	surface.dy = 3
	h.world_three.carry_player(0.1, h)
	check(h.player == Vector2(125, 103), "Carry adds conv px/ms*1000dt plus per-frame dx/dy")
	check(not h.world_three.allow_drop(h), "Nodrop copied property blocks downjump")
	h.grounded = false
	h.world_three.carry_player(1, h)
	check(h.player == Vector2(125, 103), "Airborne player receives no carry")
	h.load_source()
	h.world_three.after_motion(h)
	h.camera.x = 6
	h.world_three.after_camera(0.025, h)
	check(h.world_three.cam_dx == 6 and near(h.world_three.level_time, 0.025) and h.world_three.elapsed == h.world_three.level_time, "after_camera records pixels/frame and seconds clocks")
	h.world_three.after_motion(h)
	h.camera.x = 9
	h.world_three.after_camera(0.01, h)
	check(h.world_three.cam_dx == 3 and near(h.world_three.elapsed, 0.035), "Camera delta does not accumulate previous frames")
	check(h.world_three.camera_cap(h) == INF and h.world_three.auto_displacement(10, h) == 0, "Field has no scene approach cap or auto-scroll")

func _finds_coins_and_order(h) -> void:
	h.load_source()
	check(h.level.receipts.size() == 3 and h.level.receipts[0][0] == 5060 and h.level.receipts[0][1] == 252 and h.level.receipts[1][0] == 8700 and h.level.receipts[1][1] == 152 and h.level.receipts[2][0] == 14100 and h.level.receipts[2][1] == 152, "All three receipt coordinates match authored source")
	check(h.world_three.receipt_position(h.level.receipts[0]) == Vector2(5060, 252) and h.world_three.receipt_reward() == 0, "W3receipt adapter keeps original y and zero currency reward")
	var point := Vector2(5060, 252)
	h.player = Vector2(5018, 374)
	check(not h.world_three.finds_near(h, point), "Receipt exact42pixel xdistance is excluded")
	h.player.x = 5018.01
	check(h.world_three.finds_near(h, point), "Receipt valid body overlap at authored bale location")
	h.player = Vector2(5060, 442)
	check(not h.world_three.finds_near(h, point), "Receipt exactfeet-height-10 excluded")
	h.player.y = 441.99
	check(h.world_three.finds_near(h, point), "Receipt just inside upper bound accepted")
	h.player.y = 232
	check(not h.world_three.finds_near(h, point), "Receipt exactfeet+20 excluded")
	h.player.y = 232.01
	check(h.world_three.finds_near(h, point), "Receipt just inside lower bound accepted")
	h.hearts = 0
	check(not h.world_three.finds_near(h, point), "Down player cannot collect receipt/card")
	h.load_source()
	var source_copy := JSON.stringify(h.meta)
	h.world_three.set_tied(h, {}, 2.2)
	h.world_three.tents[0].shake = 0.5
	h.world_three.cheer = 0.3
	h.world_three.after_pickups(0.1, h)
	check(h.pickup_observations.size() == 1 and h.pickup_observations[0].coins == 0 and near(h.pickup_observations[0].tied, 2.2), "Finds happen before authoredcoin seeding and tie decrement")
	check(h.coins.size() == 29, "Firstlate frame creates all29coins, including far-offscreen rows")
	check(h.coins[0].p == Vector2(1560, 372) and h.coins[5].p == Vector2(1760, 372) and h.coins[28].p == Vector2(12000, 152), "Authored row xstep/count/order preserved")
	check(near(h.coins[7].p.y, 312 - sin(PI / 5) * 40) and near(h.coins[8].p.y, 312 - sin(2 * PI / 5) * 40), "Bale row arc uses sin(i/max(1,n-1)*PI)*40")
	check(h.coins.all(func(coin): return coin.rest and coin.stay and coin.v == Vector2.ZERO and near(coin.age, 0.3)), "Every authoredcoin rests, persists bystay, and starts300msold")
	check(near(h.world_three.tied, 2.1) and near(h.world_three.tents[0].shake, 0.4) and near(h.world_three.cheer, 0.2), "Tie, tents andcheer tick once in late phase")
	h.coins.pop_back()
	h.world_three.after_pickups(0.5, h)
	check(h.coins.size() == 28 and h.world_three.tents[0].shake == 0 and h.world_three.cheer == 0, "Collectedcoins never respawn and visual timers clamp")
	check(JSON.stringify(h.meta) == source_copy, "Movement, coin seed, timer andtent mutation leave source unchanged")

func _checkpoint_and_mini(h) -> void:
	h.load_source()
	h.player.x = 7000
	h.camera.x = 7900
	h.hearts = 1
	h.world_three.after_pickups(0.01, h)
	check(not h.world_three.checkpoint_done and h.hearts == 1, "Checkpoint is strictplayer>7000, never camera threshold")
	h.player.x = 7000.01
	h.invincible = 9
	h.world_three.after_pickups(0.01, h)
	check(h.world_three.checkpoint_done and h.hearts == 3 and near(h.invincible, 1.5), "Checkpoint fills hearts and unconditionally sets1.5s protection")
	h.hearts = 1
	h.invincible = 0.7
	h.world_three.after_pickups(0.01, h)
	check(h.hearts == 1 and near(h.invincible, 0.7), "Checkpoint heals only once per run")
	h.load_source()
	h.player.x = 7100
	h.hearts = 0
	h.world_three.after_pickups(0.01, h)
	check(not h.world_three.checkpoint_done and h.hearts == 0 and not h.world_three.wiping, "All-down does not qualify for checkpoint or scene")
	h.load_source()
	h.player.x = 7100
	h.hearts = 1
	h.combat.waves[0].started = true
	h.world_three.after_pickups(0.01, h)
	check(h.world_three.checkpoint_done and not h.world_three.wiping and h.hearts == 3, "Activewave blocks scene but not sameframe checkpoint")
	check(h.pickup_observations[0].hearts == 1 and not h.pickup_observations[0].checkpoint, "Finds observe precheckpoint state")
	h.load_source()
	h.camera.x = 8639.99
	h.world_three.after_pickups(0.01, h)
	check(h.combat.boss_starts.is_empty(), "Mini does not start before8640camera")
	h.camera.x = 8640
	h.world_three.set_tied(h, {}, 0.1)
	h.world_three.after_pickups(0.05, h)
	check(h.combat.boss_starts.size() == 1 and h.boss != null and h.camera_lock == 8900, "Mini starts exactlycam8900minus260 without waiting on waves")
	check(h.combat.boss_starts[0].config == h.meta.l3.mini and h.combat.boss_starts[0].coins == 29 and near(h.combat.boss_starts[0].tied, 0.05), "Mini receives exact60/80HPconfig after coins/tie phase")
	h.world_three.after_pickups(0.01, h)
	check(h.combat.boss_starts.size() == 1, "Active mini cannot duplicate")
	h.boss = null
	h.world_three.mini_done = true
	h.world_three.after_pickups(0.01, h)
	check(h.combat.boss_starts.size() == 1, "Completed mini cannot respawn")
	h.world_three.boss_event(h, {"cheer": 1.2})
	check(near(h.world_three.cheer, 1.2), "Boss event exposes seconds cheer to renderer")
	check(h.festival_events.size() == 1 and h.festival_events[0].cheer == 1.2, "Boss event forwards to optional host audio/presentation adapter")

func _scenes(h) -> void:
	h.load_source()
	h.player.x = 7000
	h.camera.x = 6700
	h.step(0.01)
	check(not h.world_three.wiping and h.player.x == 7000, "Scene strictgreater7000 boundary")
	h.player.x = 7000.01
	h.enemies.append({"state": "walk", "p": Vector2(7200, 482)})
	h.step(0.01)
	check(not h.world_three.wiping, "Unattached livingbot blocks scene")
	h.enemies[0].state = "pop"
	h.boss = {"state": "down"}
	h.step(0.01)
	check(not h.world_three.wiping, "Even downboss blocks scene while object exists")
	h.boss = null
	h.combat.waves[0].started = true
	h.step(0.01)
	check(not h.world_three.wiping, "Startedunfinishedwave blocks scene")
	h.combat.waves[0].done = true
	h.step(0.01)
	check(h.world_three.wiping and h.world_three.wipe_elapsed == 0 and h.world_three.scene_index == 0, "Unstartedunfinishedwaves and poppedbot do not prevent wipe trigger")
	check(h.world_three.wipe_kind == "door" and h.world_three.wipe_label == "Food village", "Door scene retains authored label")
	h.load_source()
	h.start_wipe()
	check(h.world_three.wiping and h.world_three.wipe_focus_start == Vector2(520, 324), "Iris captures actual screenoffset at source1.3zoom")
	h.camera.y = -25
	h.camera_speed = 42
	h.camera_lock = 6800
	h.player.x = 7120
	h.velocity = Vector2(250, -90)
	h.grounded = false
	h.on_platform = true
	h.bullets = [{"enemy": true}, {"enemy": false}]
	h.enemies = [{"state": "walk", "p": Vector2(9000, 482)}, {"state": "pop", "p": Vector2(6000, 482)}]
	var safe_before: Vector2 = h.world_three.safe_position
	h.step(1.429)
	check(h.world_three.scene_index == 0 and h.camera.x == 6700 and h.bullets.size() == 2, "No scene teleport before1430ms")
	h.world_three.after_pickups(0.001, h)
	check(h.world_three.scene_index == 0 and h.player.x == 7120, "1430ms queues callback until finish_frame")
	h.world_three.finish_frame(h)
	check(h.world_three.scene_index == 1 and h.camera == Vector2(7900, -25) and h.player == Vector2(8320, 428), "Scene camera7900translates currentplayer offset and resolves bale top")
	check(h.world_three.safe_position == h.player and h.world_three.safe_position != safe_before and h.velocity == Vector2.ZERO, "Scene jump updates safe position and zeros horizontal/landedvertical velocity")
	check(h.camera_speed == 42 and h.camera_lock == null and not h.grounded and h.on_platform, "Scene preserves cameraY/speed/grounded/onPlat but clearslock")
	check(h.bullets.is_empty() and h.enemies.is_empty() and h.coins.size() == 29, "Scene clears ALLenemies/projectiles while preservingcoins")
	check(h.world_three.wiping and h.world_three.wipe_midpoint_done and h.world_three.camera_cap(h) == INF, "Visualwipe persists aftermidpoint without approach cap")
	check(h.pickup_observations.back().camera == 6700, "Destination finds are not retroactive oncallbackframe")
	h.step(0.14)
	check(h.world_three.wipe_focus_end == Vector2(546, 324), "Openingfocus captured at1570ms after translatedplayeroffset")
	h.step(0.599)
	check(h.world_three.wiping, "Iris remains before2170ms")
	h.step(0.001)
	check(not h.world_three.wiping and near(h.world_three.wipe_elapsed, 2.17), "Iris ends at2170ms")
	h.player.x = 7100
	h.camera.x = 6700
	h.step(0.01)
	check(not h.world_three.wiping and h.world_three.scene_index == 1, "Triggered scene does not restart even revisiting oldposition")

func _lifecycle(h) -> void:
	h.load_source()
	h.start_wipe()
	h.step(0.5)
	var frozen: Dictionary = h.world_three.snapshot()
	var finds_count: int = h.pickup_observations.size()
	h.mode = "paused"
	h.step(30)
	check(h.world_three.snapshot() == frozen and h.pickup_observations.size() == finds_count, "Pause freezes runtime/timers/pickups, no wallclock callback")
	check(h.world_three.base_displacement(1, h, 1) == 0 and h.world_three.objective_tick(9, h) == "" and not h.world_three.can_jump(h), "Paused movement and objective hooks cannot advance")
	h.mode = "play"
	h.step(0.929)
	check(h.world_three.scene_index == 0, "Resume does not include paused walltime")
	h.world_three.after_pickups(0.001, h)
	h.mode = "over"
	h.world_three.finish_frame(h)
	check(h.world_three.scene_index == 0, "All-down resolution blocks duecallback on sameframe")
	h.mode = "play"
	h.world_three.finish_frame(h)
	check(h.world_three.scene_index == 1, "Continue resumes duecallback without resettingrun")
	h.load_source()
	h.start_wipe()
	h.world_three.after_pickups(2, h)
	var old_generation: int = h.world_three.run_generation
	h.world_three.invalidate_run()
	h.world_three.finish_frame(h)
	check(h.camera.x == 6700 and not h.world_three.wiping and not h.world_three._apply_scene_transition(h, old_generation), "Leaving invalidates pendingtransition and explicitstalecallback")
	h.load_source()
	h.start_wipe()
	h.world_three.after_pickups(2, h)
	old_generation = h.world_three.run_generation
	h.load_source()
	check(not h.world_three._apply_scene_transition(h, old_generation) and h.player == Vector2(300, 482) and h.camera == Vector2.ZERO, "Restart prevents callback frompriorgeneration")
	check(h.world_three.tied == 0 and h.world_three.cheer == 0 and not h.world_three.checkpoint_done and not h.world_three.mini_done and h.world_three.elapsed == 0, "Restart clears allrun-only state")
	var stranger := Host.new()
	stranger.load_source()
	var before: Dictionary = h.world_three.snapshot()
	h.world_three.after_pickups(10, stranger)
	h.world_three.after_camera(10, stranger)
	check(h.world_three.snapshot() == before and stranger.coins.is_empty(), "Runtime cannot mutate a different host instance")
	h.load_source()
	h.world_three.set_tied(h, {}, 1)
	h.mode = "clear"
	before = h.world_three.snapshot()
	h.world_three.after_pickups(0.1, h)
	check(h.world_three.snapshot() == before and h.coins.is_empty(), "Clear outside attested base step remains frozen")
	h.final_base_step = true
	h.world_three.after_pickups(0.1, h)
	check(h.coins.size() == 29 and near(h.world_three.tied, 0.9), "Attested final base step runs source late levelUpdate after clear")
	h.final_base_step = false
	h.load_source("4-1")
	h.world_three.after_camera(10, h)
	h.world_three.after_pickups(10, h)
	check(h.world_three.elapsed == 0 and h.coins.is_empty() and h.combat.boss_starts.is_empty(), "Unsupportedlaterstage metadata never enables gameplay")
	stranger = null

func _objective(h) -> void:
	h.load_source()
	h.camera.x = 15060
	check(h.world_three.objective_tick(1, h) == "", "End camera alone cannot clear unfinishedwaves")
	for wave in h.combat.waves: wave.done = true
	h.camera.x = 15059.99
	check(h.world_three.objective_tick(1, h) == "", "End rejects just beforeworld-view-2")
	h.camera.x = 15060
	h.boss = {"state": "down"}
	check(h.world_three.objective_tick(3, h) == "" and h.world_three.end_time == 0, "Mini celebration blocks end even when ordinarywavesdone")
	h.boss = null
	h.world_three.mini_done = true
	check(h.world_three.objective_tick(0.016, h) == "ending" and near(h.world_three.end_time, 0.017), "End begins1ms plus currentdt exactlyafterfinalmini dismissal")
	check(h.world_three.objective_tick(2.583, h) == "" and near(h.world_three.end_time, 2.6), "End stays pending at exact2600ms")
	check(h.world_three.objective_tick(0.0001, h) == "clear", "Clear requires strictlymorethan2600ms")
	check(h.world_three.objective_tick(10, h) == "", "Completion is one-shot")
	h.load_source()
	h.camera.x = 15060
	for wave in h.combat.waves: wave.done = true
	h.hearts = 0
	check(h.world_three.objective_tick(0.016, h) == "ending", "Objective checks playstate before frame-end all-down, nothearts")
	h.mode = "over"
	var old_time: float = h.world_three.end_time
	check(h.world_three.objective_tick(30, h) == "" and h.world_three.end_time == old_time, "Gameover freezes endtimer untilContinue")

func _source_contract() -> void:
	# Assert source tokens without logging its embedded base64 images. This is
	# deliberately a repo fixture, not packaged-game or device verification.
	var path := ProjectSettings.globalize_path("res://../game/3-1/index.html")
	if not FileAccess.file_exists(path):
		check(false, "Original3-1 source is available for provenance fixture")
		return
	var source := FileAccess.get_file_as_string(path)
	check(source.contains("alive().some((p) => p.x > s.x) && (LV.auto || !waveBusy())") and source.contains("const d = s.to - cam; cam += d; camLock = null;"), "Actualsource proves scene strictthreshold/busyguard/camera-relative teleport")
	check(source.contains("p.tied = 2200") and source.contains("if (p.tied > 0) k *= 0.45") and source.contains("k *= 0.55") and source.contains("? 0.84 : 1"), "Actualsource proves tied andmud conversion constants")
	check(source.contains("p.x > L3.check") and source.contains("p.hearts = 3; p.inv = 1500"), "Actualsource proves checkpoint livingplayer/fullheal/protection")
	check(source.contains("cam >= L3.mini.cam - 260") and source.contains("waves.every((w) => w.done)"), "Actualsource proves mini approach andnormalend gates")
	check(source.contains("updateBots(dt); updateShots(dt); updateCoins(dt); levelUpdate(dt);") and source.contains("updateFinds(); updateScenes();"), "Actualsource proves combat/pickup/scene late ordering")
	check(source.contains("c[0] + i * c[2]") and source.contains("rest: true, stay: true") and source.contains("c.stay || c.t < 11000"), "Actualsource proves immediate authoredcoin step andstay lifetime")
	check(source.contains("o.y > GROUND + p.y - charH(p.k) - 10 && o.y < GROUND + p.y + 20"), "Actualsource proves strictW3receipt/card vertical bounds")
	var polish := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../game/polish.js"))
	check(polish.contains("T_CLOSE = 520, T_OPEN = 600, T_CARD = 220") and polish.contains("o.label ? 1050 : 380") and polish.contains("MID = T_CLOSE + HOLD - 140"), "Actualpolish proves labeled1430/1570/2170ms wipe boundaries")
