extends SceneTree
const Finale = preload("res://src/festival_finale.gd")
const Base = preload("res://tests/test_world_three.gd")
class Boss extends RefCounted:
	var state: Dictionary = {"jar": {}}
class Combat extends Base.StubCombat:
	var players: Array = []
	func start_boss(host, cfg: Dictionary) -> void:
		boss_starts.append(cfg.duplicate(true))
		host.boss = Boss.new()
		host.boss.state.cfg = cfg
	func _living(_host) -> Array: return players
class Runtime extends "res://src/world_three.gd":
	func supports(id: String) -> bool: return id == "3-6" or super.supports(id)
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host := Base.Host.new()
	host.world_three = Runtime.new()
	host.combat = Combat.new()
	host.load_source("3-6")
	var finale := Finale.new()
	var r = host.world_three
	var c = host.combat
	var original := JSON.stringify(host.meta)
	check(finale.supports("3-6") and not finale.supports("3-5"), "Finale only")
	check(host.level.w == 4400 and c.waves.size() == 3 and host.meta.l3.boss.hp == 160 and host.meta.l3.boss.hp2 == 220, "Authored three-wave approach and 160/220 HP")
	check(host.meta.l3.stage == 0 and host.level.plats[0][0] == 4040 and host.level.plats[0][1] == 4290 and host.level.plats[0][2] == 354 and host.level.plats[0][3].base == 482 and host.level.plats[0][3].style == "cases", "Stage zero retains exact live cases geometry")
	host.camera.x = 3660
	finale.after_mini_trigger(0,host,r)
	check(host.boss == null, "End camera cannot skip unfinished approach waves")
	for wave in c.waves: wave.done = true
	host.camera.x = 3659.999
	finale.after_mini_trigger(0,host,r)
	check(host.boss == null, "Strict left edge before end-minus-two cannot start")
	host.camera.x = 3660
	finale.after_mini_trigger(0,host,r)
	check(host.boss != null and c.boss_starts.size() == 1, "Inclusive end-minus-two starts after all waves")
	check(c.boss_starts[0].cam == 3662 and c.boss_starts[0].kind == "tout" and not c.boss_starts[0].has("mini"), "Full arena lock and non-mini source config")
	finale.after_mini_trigger(0,host,r)
	check(c.boss_starts.size() == 1, "No repeated encounter creation")
	host.boss.state.x = 4200.0
	finale.sync_visuals(host,r)
	check(not host.boss.state.moved, "First visual sample has no invented previous x")
	host.boss.state.x = 4201.0
	finale.sync_visuals(host,r)
	check(not host.boss.state.moved and host.boss.state.visual_x == 4200, "Repeated level clock never resamples movement")
	r.level_time = 0.016
	finale.sync_visuals(host,r)
	check(host.boss.state.moved and host.boss.state.visual_x == 4201, "New simulation time captures actual displacement")
	r.level_time = 0.032
	finale.sync_visuals(host,r)
	check(not host.boss.state.moved, "Stationary next frame returns to hide animation")
	host.boss.state.x = 4201.049; r.level_time = 0.048
	finale.sync_visuals(host,r)
	check(not host.boss.state.moved, "Movement below strict source 0.05 threshold stays idle")
	host.boss.state.x = 4201.1; r.level_time = 0.064
	finale.sync_visuals(host,r)
	check(host.boss.state.moved, "Movement above strict source threshold selects walk")
	check(r.objective_tick(100,host).is_empty(), "Main-boss metadata never uses ordinary timed distance clear")
	host.boss.state.jar = {"x":4000.0,"y":100.0,"t":1.4,"got":false}
	c.players = [{"p":Vector2(3900,-900)},{"p":Vector2(4010,800)}]
	finale.after_mini_trigger(0.1,host,r)
	check(host.boss.state.jar.x == 4000, "Magnet excludes exact 1400ms previous age")
	host.boss.state.jar.t = 1.401
	finale.after_mini_trigger(0.1,host,r)
	check(host.boss.state.jar.x == 4010, "Magnet selects horizontal nearest irrespective of height and never overshoots")
	c.players = [{"p":Vector2(3900,482)}]
	finale.after_mini_trigger(0.1,host,r)
	check(host.boss.state.jar.x == 3998, "Magnet moves 120 pixels per second")
	host.boss.state.jar.got = true
	finale.after_mini_trigger(1,host,r)
	check(host.boss.state.jar.x == 3998, "Collected jar cannot move")
	host.boss.state.jar.got = false
	host.mode = "paused"
	finale.after_mini_trigger(1,host,r)
	check(host.boss.state.jar.x == 3998, "Pause freezes late magnet")
	host.mode = "play"; c.players = []
	finale.after_mini_trigger(1,host,r)
	check(host.boss.state.jar.x == 3998, "No living participant means no attraction")
	c.players = [{"p":Vector2(4100,482)}]
	r.invalidate_run()
	finale.after_mini_trigger(1,host,r)
	check(host.boss.state.jar.x == 3998, "Invalidated generation cannot move old jar")
	check(JSON.stringify(host.meta) == original, "Source metadata unchanged")
	print("Festival finale: ",checks," checks; ",failures.size()," failures (isolated hooks)")
	quit(0 if failures.is_empty() else 1)
