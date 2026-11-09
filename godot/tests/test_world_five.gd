extends SceneTree
const Runtime = preload("res://src/world_five.gd")
const Combat = preload("res://src/moving_day_combat.gd")
const King = preload("res://src/cardboard_king.gd")
var checks := 0
var failures: Array[String] = []
class Host extends RefCounted:
	var level_id := "5-1"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var mode := "play"
	var player := Vector2.ZERO
	var velocity := Vector2.ZERO
	var camera := Vector2.ZERO
	var camera_speed := 0.0
	var camera_lock = null
	var hearts := 3
	var invincible := 0.0
	var grounded := true
	var on_platform := false
	var crouching := false
	var face := 1
	var power := ""
	var power_time := 0.0
	var status := ""
	var enemies: Array = []
	var bullets: Array = []
	var coins: Array = []
	var crates: Array = []
	var items: Array = []
	var score := 0
	var pop_count := 0
	var elapsed := 0.0
	var abilities = null
	var boss = null
	var combat = Combat.new()
	var world_five = Runtime.new()
	var images: Dictionary = {}
	var sheets: Dictionary = {}
	var receipts: Array = []
	var character := "jp"
	var font: Font = load("res://assets/fonts/silk.woff2")
	var recorded: Array = []
	func draw_texture_rect_region(texture, rect, source, colour): recorded.append(["texture", texture, rect, source, colour])
	func draw_rect(rect, colour): recorded.append(["rect", rect, colour])
	func draw_colored_polygon(points, colour): recorded.append(["polygon", points, colour])
	func draw_polygon(points, colours, uv = null, texture = null): recorded.append(["gradient", points, colours, uv, texture])
	func draw_polyline(points, colour, width): recorded.append(["line", points, colour, width])
	func draw_style_box(style, rect): recorded.append(["rounded", style, rect])
	func draw_string(font_resource, position, text, alignment, width, size, colour): recorded.append(["text", font_resource, position, text, alignment, width, size, colour])
	func draw_string_outline(font_resource, position, text, alignment, width, size, outline, colour): recorded.append(["text_outline", font_resource, position, text, alignment, width, size, outline, colour])
	func view_width() -> float: return 738
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func character_height() -> float: return 180
	func sfx(_key: String) -> void: pass
	func collect_level_pickups() -> void: pass
	func add_coins(p: Vector2, n: int) -> void:
		for i in n: coins.append({"p": p, "v": Vector2.ZERO, "age": 0.0, "rest": false})
	func hurt_player(_from: float) -> void:
		if mode != "play" or invincible > 0 or hearts <= 0: return
		hearts -= 1; invincible = 1.5
	func floor_at(x: float, y: float) -> float:
		var q: Dictionary = world_five.below(self, x, y)
		return q.row[2] if not q.is_empty() else meta.ground
	func _land(x: float, y0: float, y1: float) -> float:
		var q: Dictionary = world_five.land_on(self, x, y0, y1)
		return q.row[2] if not q.is_empty() else INF
	func ability_inside_wall(p: Vector2) -> bool: return world_five.inside_wall(self, p)
	func load_source(id: String, count: int = 1) -> void:
		level_id = id; meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % id)); level = meta.level
		player = Vector2(level.start, meta.ground); camera = Vector2.ZERO; camera_speed = 0; camera_lock = null; mode = "play"; hearts = 3; invincible = 0; grounded = true; on_platform = false; crouching = false; velocity = Vector2.ZERO
		enemies.clear(); bullets.clear(); coins.clear(); crates.clear(); items.clear(); boss = null
		world_five.reset(self, 51); player.y = floor_at(player.x, meta.ground - (10 if level.get("vert", false) else 3000)); world_five.safe_position = player
		combat.reset(self, count, 51); world_five.seed_pickups(self)
	func tick(dt: float, controls: Dictionary = {}) -> String:
		world_five.before_camera(dt, self, controls); combat.waves_tick(dt, self)
		var outcome: String = world_five.objective_tick(dt, self)
		combat.enemies_tick(dt, self); combat.projectiles_tick(dt, self); combat.pickups_tick(dt, self); combat.boss_tick(dt, self)
		if combat.jar_tick(dt, self) == "clear": outcome = "clear"
		world_five.finish_frame(self); return outcome
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var h := Host.new()
	for id in Runtime.SUPPORTED_LEVELS:
		h.load_source(id)
		var before := JSON.stringify(h.meta)
		check(h.world_five.supports(id), id + " supported runtime")
		check(h.world_five._surfaces.size() == h.level.solids.size() + h.level.plats.size(), id + " all surfaces")
		check(h.combat.waves.size() == h.level.waves.size(), id + " all waves")
		for i in 60: h.tick(1.0 / 60)
		check(before == JSON.stringify(h.meta), id + " immutable META after simulation")
	h.load_source("5-1")
	check(h.world_five.mimics.size() == 6 and h.world_five.drops.size() == 6, "all box mountain traps")
	h.player = Vector2(550, 482); h.world_five.before_camera(0.016, h)
	check(h.world_five.mimics[0].sprung and h.enemies.size() == 1 and h.enemies[0].has("hop"), "mimic proximity jump")
	h.enemies.clear(); h.player = Vector2(1260, 482); h.world_five.before_camera(0.016, h)
	check(h.world_five.drops[0].state == "warn", "drop warning starts before timer")
	for i in 39: h.world_five.before_camera(1.0 / 60, h)
	check(h.world_five.drops[0].state == "warn", "650ms strict warning boundary")
	h.world_five.before_camera(0.001, h)
	check(h.world_five.drops[0].state == "fall", "fall begins after warning")
	h.load_source("5-2")
	h.world_five.sofa.x = 2940; h.player = Vector2(2940, 482)
	for i in 45: h.world_five._tick_sofa(0.01, h)
	check(not h.world_five.sofa.tip, "no unrequested sofa tipping")
	h.world_five.controls = {"down": true}
	for i in 45: h.world_five._tick_sofa(0.01, h)
	check(not h.world_five.sofa.tip, "450ms strict tip edge")
	h.world_five._tick_sofa(0.001, h)
	check(h.world_five.sofa.tip and h.world_five.carrying, "doorway held down tips sofa")
	check(is_equal_approx(h.world_five.sofa_rect().size.x, 92), "tipped sofa collision width")
	check(is_equal_approx(h.world_five.base_displacement(1, h, 1), 210.6), "sofa carrying movement penalty")
	h.player.x = 3700; h.world_five.sofa.x = 3500; h.world_five.before_camera(0.016, h)
	check(h.world_five.wiping, "sofa scene gate needs sofa proximity")
	var generation: int = h.world_five.run_generation
	for i in 90: h.world_five.before_camera(1.0/60, h); h.world_five.finish_frame(h)
	check(h.world_five.wipe_midpoint_done and h.player.x == 4910 and h.world_five.sofa.x >= 5110 - 30, "scene relocates actor and sofa")
	h.world_five.invalidate_run(); check(not h.world_five._apply_scene_transition(h, generation), "stale wipe cannot relocate new run")
	h.load_source("5-3")
	check(h.world_five.lift.surface.row[2] == 482, "broken lift starts floor zero")
	h.player = Vector2(660, 482)
	for i in 240: h.world_five._tick_lift(1.0 / 60, h)
	check(h.world_five.lift.floor == 1 and absf(h.player.y - 152) < 0.1, "lift carries player one floor")
	h.world_five.lift.floor = 3; h.world_five.lift.state = "move"; h.world_five.lift.to = 482 - 4*330; h.world_five.lift.surface.row[2] = h.world_five.lift.to + 1; h.player.y = h.world_five.lift.surface.row[2]
	h.world_five._tick_lift(0.016, h)
	check(h.world_five.lift.state == "shake", "fourth floor forced shake")
	for i in 200: h.world_five._tick_lift(1.0 / 60, h)
	check(h.world_five.lift.floor == 2 and h.world_five.lift.state == "wait", "broken lift drops two floors")
	h.player.y = -3478; check(h.world_five.at_end(h), "vertical goal uses height not horizontal distance")
	h.combat.waves_tick(0.016, h); check(h.combat.waves.all(func(w): return w.started), "vertical progress activates all floor waves")
	h.load_source("5-4", 2)
	var count := 0
	for w in h.combat.waves: count += w.group.size()
	var authored := 0; var extras := 0
	for w in h.level.waves: authored += w.g.size(); extras += 1 if w.get("extra", true) else 0
	check(count == authored + extras, "pair extra wave branch preserved")
	h.player = Vector2(4500, 482); h.world_five.carry_player(0.1, h)
	# Source landOn selects first coincident floor, not overlapping belt. Keep it.
	check(h.player.x == 4500, "source first overlapping floor wins belt tie")
	h.player = Vector2(6100, 242); h.world_five.carry_player(0.1, h)
	check(is_equal_approx(h.player.x, 6114), "raised conveyor carries at 140px/s")
	h.camera.x = 0; h.player = Vector2(300, 482); h.combat.spawn(h, "r", "tape")
	check(h.enemies.size() == 1 and h.enemies[0].get("hidden", 0) == 0.52, "visible shutter spawns tape robot")
	h.load_source("5-5")
	check(h.world_five.movers.size() == 3 and h.world_five.surfaces(h).size() == 2, "vehicle slots inactive at reset")
	h.combat.spawn(h, "l", "van")
	check(h.enemies.size() == 2 and not h.world_five.movers[0].off, "van brings two riders")
	var q: Dictionary = h.world_five.movers[0]
	check(is_same(h.enemies[0].surface, q), "riders retain live mover identity")
	var old: float = q.row[0]; h.world_five._tick_movers(0.016, h)
	check(q.row[0] > old, "left van approaches deck")
	h.combat.spawn(h, "r", "bridge"); check(h.world_five.beams.size() == 1, "low bridge wave")
	h.combat.spawn(h, "r", "big"); check(h.enemies[-1].big and h.enemies[-1].hp == 26 and h.enemies[-1].has("hop"), "timed boss hops onto van")
	h.world_five.level_time = 239.999; check(not h.world_five.at_end(h), "trip not early"); h.world_five.level_time = 240; check(h.world_five.at_end(h), "trip duration 240 seconds")
	h.load_source("5-S")
	check(h.coins.size() == 484 and h.coins.all(func(c): return c.stay), "all persistent bonus coins")
	var mattress: Dictionary = h.world_five._surfaces.filter(func(s): return s.get("bounce", false))[0]
	h.world_five.landing(h, mattress); check(h.velocity.y == -1420 and not h.grounded, "bonus mattress bounce")
	h.world_five.clock_left = 0; check(h.world_five.at_end(h), "bonus timeout marks end predicate")
	check(h.world_five.objective_tick(0.016, h) == "", "timeout still requires source wave completion")
	for w in h.combat.waves: w.done = true
	check(h.world_five.objective_tick(0.016, h) == "ending", "bonus ending after all waves")
	var result := ""
	for i in 160: result = h.world_five.objective_tick(1.0 / 60, h) if not h.world_five.clear_reported else result
	check(result == "clear", "source 2.6 second end delay")
	_test_king(h)
	print("World 5 mechanics: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _test_king(h) -> void:
	h.load_source("5-6"); h.combat.start_boss(h)
	var b = h.boss
	check(b.state.hp == 26 and b.state.hh == 202 and b.state.hw == 88, "first King phase geometry and HP")
	check(not b.hit(Vector2(b.state.x, 400), 999), "King entry invulnerable")
	b.state.state = "walk"; b.state.x = 4100
	check(b.hit(Vector2(4100, 400), 999) and b.state.hp == 25, "King ignores projectile dmg as source")
	b.hit(Vector2(4100, b.state.crown_y - 1)); check(b.state.hp == 23, "crown double damage")
	b.state.dizzy = 1; b.hit(Vector2(4100, b.state.crown_y - 1)); check(b.state.hp == 19, "crown and dizzy multiply")
	for phase in 3:
		b.state.dizzy = 0; b.state.state = "walk"; b.state.armour = false
		while b.state.hp > 0: b.hit(Vector2(b.state.x, 400))
		if phase < 2:
			check(b.state.state == "collapse" and b.state.armour, "King phase collapse armour")
			check(not b.hit(Vector2(b.state.x, 400)), "collapse cannot be damaged")
			var events: Array = []
			for i in 55: events.append_array(b.boss_tick(1.0 / 60, [], true))
			check(events.any(func(e): return e.type == "helpers" and e.count == 2 + phase), "phase helper delay and count")
			for i in 90: b.boss_tick(1.0 / 60, [], false)
			check(b.state.state == "rebuild", "collapse waits 2.2s and no bots")
			for i in 110: b.boss_tick(1.0 / 60, [], false)
			check(b.state.phase == phase + 1 and b.state.hp == [26, 32, 38][phase + 1], "King rebuild next HP")
	check(b.state.state == "down", "third King defeat final")
	for i in 91: b.boss_tick(1.0 / 60, [], false)
	check(not b.state.jar.is_empty(), "jar appears only after final defeat delay")
	var events: Array = []
	for i in 40: events.append_array(b.jar_tick(1.0 / 60, [{"p": Vector2(b.state.jar.x, -9000)}]))
	check(events.any(func(e): return e.type == "clear"), "jar source pickup ignores height after 600ms")
