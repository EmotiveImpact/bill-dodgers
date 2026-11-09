extends SceneTree
const Scene = preload("res://src/world_one.gd")
const Combat = preload("res://src/combat.gd")
var failures: Array[String] = []
var checks := 0

class Host extends RefCounted:
	var level_id := "1-2"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var player := Vector2.ZERO
	var velocity := Vector2.ZERO
	var camera := Vector2.ZERO
	var camera_speed := 0.0
	var camera_lock = null
	var checkpoint := Vector2.ZERO
	var grounded := true
	var on_platform := false
	var hearts := 3
	var invincible := 0.0
	var face := 1
	var mode := "play"
	var status := ""
	var score := 0
	var pop_count := 0
	var crouching := false
	var power := ""
	var power_time := 0.0
	var boss = null
	var abilities = null
	var enemies: Array = []
	var crates: Array = []
	var coins: Array = []
	var items: Array = []
	var bullets: Array = []
	var effects: Array = []
	var combat = Combat.new()
	var scene = Scene.new()
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func character_height() -> float: return 180.0
	func sfx(effect: String) -> void: effects.append(effect)
	func add_coins(p: Vector2, count: int) -> void:
		for i in range(count): coins.append({"p": p, "v": Vector2.ZERO, "age": 0.0, "rest": false})
	func hurt_player(_from: float) -> void:
		if invincible > 0 or hearts <= 0: return
		hearts -= 1
		invincible = 1.5
		velocity.x = 350
	func floor_at(x: float, y: float) -> float:
		var surface: Dictionary = scene.below(self, x, y)
		return float(surface.row[2]) if not surface.is_empty() else float(meta.ground)
	func _land(x: float, old_y: float, new_y: float, skip: bool = false) -> float:
		var surface: Dictionary = scene.land_on(self, x, old_y, new_y, skip)
		return float(surface.row[2]) if not surface.is_empty() else INF
	func load_source(id: String) -> void:
		level_id = id
		meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % id))
		level = meta.level
		player = Vector2(float(level.start), float(meta.ground))
		camera = Vector2.ZERO
		velocity = Vector2.ZERO
		grounded = true
		on_platform = false
		hearts = 3
		mode = "play"
		boss = null
		enemies.clear()
		crates.clear()
		coins.clear()
		items.clear()
		bullets.clear()
		effects.clear()
		scene.reset(self)
		player.y = floor_at(player.x, float(level.get("startY", float(meta.ground) - 10)))
		scene.safe_position = player
		combat.reset(self, 17)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func near(a: float, b: float) -> bool: return absf(a - b) < 0.00001
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var h = Host.new()
	h.load_source("1-2")
	check(h.combat.waves.size() == 11, "Rooftops imports all eleven source waves")
	check(h.scene.crumbles.size() == 12, "Rooftops imports twelve loose slate platforms")
	check(h.level.solids.size() == 28 and h.level.plats.size() == 22, "Rooftop solid and one-way geometry matches source")
	check(h.level.roofs.size() == 14 and h.level.w == 19922, "Fourteen source roofs retain absolute width")
	check(h.player == Vector2(300, 482), "Rooftop start remains in back yard below fire escape")
	check(h.combat.waves.back().at == 19184 and h.combat.waves.back().group.size() == 8, "Final rooftop wave keeps camera trigger and all eight spawns")
	check(h.combat.checks.size() == 2 and h.crates.size() == 6, "Shared combat owns checkpoints and six original crates")
	var immutable_level := JSON.stringify(h.level)
	var first: Dictionary = h.scene.crumbles[0]
	check(first.row[0] == 5685 and first.row[1] == 5868 and first.row[2] == -222, "First slate uses imported source coordinates")
	check(h.scene.land_on(h, 5700, -230, -220).row == first.row, "Dynamic slate catches descending feet")
	check(h.scene.land_on(h, 5700, -230, -220, true).is_empty(), "Drop-through ignores crumbling one-way slate")
	h.player = Vector2(5700, -222)
	h.on_platform = true
	h.scene.tick(0.65, h)
	check(near(first.t, 0.65) and first.fall == 0 and h.grounded, "Slate remains solid at exactly650ms")
	h.player.x = 5750
	h.scene.tick(0.0001, h)
	check(near(first.fall, 0.001) and not h.grounded and h.velocity.y == 50, "After650ms slate drops and releases rider at50px/s")
	check(h.scene.land_on(h, 5700, -230, -220).is_empty(), "Fallen slate leaves collision queries")
	check(JSON.stringify(h.level) == immutable_level, "Crumble state never mutates imported source geometry")
	h.scene.tick(5.198, h)
	check(first.fall > 0, "Fallen slate remains absent just before5.2s")
	h.scene.tick(0.002, h)
	check(first.fall == 0 and first.t == 0, "Slate regenerates only after5.2s")
	check(not h.scene.land_on(h, 5700, -230, -220).is_empty(), "Regenerated slate restores collision")
	h.grounded = true
	h.player = Vector2(5700, -222)
	h.scene.tick(0.1, h)
	h.player.x = 5900
	h.grounded = false
	h.scene.tick(0.551, h)
	check(first.fall > 0, "A triggered slate continues its countdown after rider leaves")
	h.scene.reset(h)
	check(h.scene.crumbles.all(func(q): return q.t == 0 and q.fall == 0), "Restart rebuilds every slate without retained fall timers")
	h.player = Vector2(5700, -222)
	h.grounded = true
	h.enemies = [{"p": Vector2(5740, -222), "state": "walk", "kind": "rush", "segment": h.scene.crumbles[0].row, "t": 0.0, "gone": 0.0}]
	h.scene.tick(0.651, h)
	check(h.enemies[0].state == "pop" and h.pop_count == 0, "Crumble kills supported robot without crediting a player pop")
	check(h.coins.size() >= 4 and h.coins.size() <= 6, "Environment robot kill drops source four-to-six coins")
	# Boundary values use source landOn and below, not generous visual bounds.
	h.level = {"w": 2000, "solids": [[0, 1000, 200]], "plats": [[100, 300, 100]], "crumble": []}
	h.scene.reset(h)
	check(h.scene.land_on(h, 100, 101, 100).row[2] == 100, "Landing accepts top exactlyoldFeet-1 and inclusive left edge")
	check(h.scene.land_on(h, 300, 99, 99.5).row[2] == 100, "Landing accepts top exactlynewFeet+0.5 and inclusive right edge")
	check(h.scene.land_on(h, 301, 90, 110).is_empty(), "One-way landing rejects horizontal point outside surface")
	check(h.scene.land_on(h, 150, 0, 250).row[2] == 100, "Landing selects highest crossed surface")
	check(h.scene.land_on(h, 150, 0, 250, true).row[2] == 200, "Drop-through still collides with solid roofs")
	check(h.scene.below(h, 150, 102).row[2] == 100, "Below uses exact source two-pixel tolerance")
	check(h.scene.below(h, 150, 102.01).row[2] == 200, "Below excludes platform outside tolerance")
	# Timed non-boss objective, with source one-millisecond sentinel.
	h.load_source("1-2")
	h.camera.x = 19184
	check(h.scene.objective_tick(0.016, h) == "" and h.scene.end_time == 0, "End cannot bypass unfinished source waves")
	for wave in h.combat.waves: wave.started = true; wave.done = true
	h.camera.x = 19181.9
	check(h.scene.objective_tick(0.016, h) == "", "Timed exit waits for source camera end threshold")
	h.camera.x = 19182
	check(h.scene.objective_tick(0.016, h) == "ending" and near(h.scene.end_time, 0.017), "Exit starts at end-2 and includes first frame dt")
	check(h.scene.objective_tick(2.582, h) == "", "Exit does not clear before2.6seconds")
	check(h.scene.objective_tick(0.002, h) == "clear", "Exit clears only after2.6seconds")
	check(h.scene.objective_tick(10, h) == "", "Clear event is emitted once")
	h.load_source("1-2")
	for wave in h.combat.waves: wave.done = true
	h.camera.x = 19184
	h.mode = "paused"
	check(h.scene.objective_tick(4, h) == "" and h.scene.end_time == 0, "Pause cannot start or advance exit timer")
	h.mode = "play"
	h.hearts = 0
	check(h.scene.objective_tick(4, h) == "", "Defeated player cannot receive timed clear")
	h.load_source("1-6")
	for wave in h.combat.waves: wave.done = true
	h.camera.x = h.level.w - h.view_width()
	check(h.scene.objective_tick(0.016, h) == "boss" and h.scene.end_time == 0, "Bin Day requests its own boss, never a timed clear")
	check(h.scene.objective_tick(10, h) == "", "Unhandled Binman boss request does not grant completion")
	h.load_source("1-3")
	for wave in h.combat.waves: wave.done = true
	check(h.scene.objective_tick(10, h) == "", "Unported bus timeline cannot receive fake completion")
	# Source flying mailers anchor to a standing player or midpoint surface.
	h.load_source("1-2")
	h.player = Vector2(4500, -242)
	h.grounded = true
	check(h.scene.flyer_floor(h) == -242, "Flyer uses grounded player's supporting roof")
	h.player = Vector2(5800, 800)
	h.grounded = false
	h.camera.x = 4100
	check(h.scene.flyer_floor(h) == -242, "Falling player cannot drag flyer base height into gap")
	h.camera.x = 5500
	check(h.scene.flyer_floor(h) == 482, "Flyer without midpoint surface falls back to source ground")
	# Enemy roof-to-roof and chimney hops use source motion and durations.
	h.level = {"w": 2000, "solids": [[0, 400, 0], [510, 900, 40]], "plats": []}
	h.scene.reset(h)
	h.player = Vector2(700, 40)
	var enemy := {"p": Vector2(378, 0), "state": "walk", "kind": "rush", "segment": h.level.solids[0], "entered": true, "face": 1}
	h.scene.try_enemy_gap_hop(h, enemy)
	check(enemy.has("hop") and enemy.hop.finish == Vector2(550, 40), "Robot chooses reachable next roof and forty-pixel landing inset")
	check(near(enemy.hop.duration, 0.52 + 172 * 0.0012), "Gap hop uses520ms plus1.2msperpixel")
	var duration: float = enemy.hop.duration
	check(h.scene.tick_enemy_hop(duration / 2, enemy) and enemy.p.distance_to(Vector2(464, -50)) < 0.001, "Hop midpoint follows source sine trajectory")
	check(h.scene.tick_enemy_hop(duration / 2, enemy) and not enemy.has("hop") and enemy.p == Vector2(550, 40), "Hop lands exactly on destination and switches segment")
	check(not h.scene.tick_enemy_hop(0.016, enemy), "Landed robot returns to ordinary AI next frame")
	enemy.p = Vector2(378, 0)
	enemy.segment = h.level.solids[0]
	h.level.solids[1][0] = 630
	h.scene.try_enemy_gap_hop(h, enemy)
	check(not enemy.has("hop"), "Exactly230pixel roof gap is not jumpable")
	h.level.solids[1][0] = 510
	h.level.solids[1][2] = 230
	h.scene.try_enemy_gap_hop(h, enemy)
	check(not enemy.has("hop"), "Exactly230pixel roof height delta is not jumpable")
	h.level = {"w": 2000, "solids": [[0, 1000, 482], [100, 200, 372]], "plats": []}
	h.scene.reset(h)
	h.player = Vector2(500, 482)
	enemy = {"p": Vector2(80, 482), "state": "walk", "kind": "rush", "segment": h.level.solids[0], "entered": true, "face": 1}
	h.enemies = [enemy]
	h.scene.tick(0.016, h)
	check(enemy.has("hop") and enemy.hop.finish == Vector2(234, 482), "Robot clears nearby chimney with34pixel landing inset")
	check(near(enemy.hop.duration, 0.65 + 154 * 0.0015), "Chimney hop uses650ms plus1.5msperpixel")
	h.scene.tick_enemy_hop(enemy.hop.duration, enemy)
	check(enemy.p == Vector2(234, 482), "Chimney hop returns robot to supporting roof")
	# Fall recovery searches forward inside the camera, rather than spawning
	# a player at a nonexistent global ground plane underneath a roof gap.
	h.load_source("1-2")
	h.player = Vector2(5000, -242)
	h.grounded = true
	h.on_platform = false
	h.scene.after_motion(h)
	check(h.scene.safe_position == h.player, "Interior solid roof updates fall-safe position")
	h.player = Vector2(5700, -222)
	h.on_platform = true
	h.scene.after_motion(h)
	check(h.scene.safe_position == Vector2(5000, -242), "Loose slate cannot replace safe solid roof")
	h.camera = Vector2(5000, -700)
	h.player = Vector2(5700, 1000)
	h.invincible = 5
	h.scene.recover_from_fall(h)
	check(h.grounded and h.player.y == -242 and h.hearts == 2 and h.velocity == Vector2.ZERO, "Fall recovery finds visible roof, clears velocity, applies fall damage despite previous invulnerability")
	# Reusable tile-run mechanics are tested without claiming integration.
	h.load_source("1-5")
	h.camera.x = 1000
	h.camera_speed = 300
	h.scene.after_camera(1, h)
	check(near(h.camera.x, 1190) and h.camera_speed == 0, "Alley camera adds source190px/s auto-scroll")
	h.camera.x = h.level.w - h.view_width() - 10
	h.scene.after_camera(1, h)
	check(h.camera.x == h.level.w - h.view_width(), "Auto-scroll clamps exactly to world end")
	h.player = Vector2(1200, 482)
	h.grounded = false
	h.velocity.y = 500
	h.scene.tick(0.016, h)
	check(h.player.y == 402 and h.grounded and not h.on_platform and h.velocity.y == 0, "Auto-scroll lifts player trapped in source solid obstacle")
	h.load_source("1-S")
	h.scene.tick(0.016, h)
	check(h.coins.size() == 8 and h.scene.next_coin == 1260 and h.scene.coin_pattern == 1, "Bonus emits eight-coin row only as it enters spawn horizon")
	check(h.coins[0].p == Vector2(700, 442) and h.coins[7].p == Vector2(1022, 442), "Bonus row uses46pixelspacing and ground-40")
	check(h.coins[0].rest and near(h.coins[0].age, 0.26), "Bonus coins start resting and collectable at260ms")
	h.scene.tick(0.016, h)
	check(h.coins.size() == 8, "Bonus tick cannot duplicate a row")
	h.camera.x = 1682
	h.scene.tick(0.016, h)
	check(h.coins.size() == 32 and h.scene.coin_pattern == 4, "Bonus horizon produces all four repeating source patterns")
	check(near(h.coins[11].p.y, 482 - 70 - sin(3.0 / 7 * PI) * 170), "Bonus arc keeps source sine height")
	check(h.coins[16].p.y == 282 and h.coins[24].p.y == 442 and h.coins[25].p.y == 362, "Bonus high row and alternating row retain source heights")
	print("World 1 scene state: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
