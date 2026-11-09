extends SceneTree
const BigTop = preload("res://src/festival_big_top.gd")
const Base = preload("res://tests/test_world_three.gd")
const Boss = preload("res://src/festival_boss.gd")
var checks := 0
var failures: Array[String] = []
class RuntimeStub extends RefCounted:
	var rng := RandomNumberGenerator.new()
	var level_time := 0.0
	func _can_step(h) -> bool: return h.mode == "play"
	func surfaces(h) -> Array: return h.world_three.surfaces(h)
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
func near(a: float, b: float) -> bool: return absf(a - b) < 0.000001
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var h := Base.Host.new()
	h.load_source("3-4")
	var original := JSON.stringify(h.meta)
	var r := RuntimeStub.new()
	r.rng.seed = 42
	var b := BigTop.new()
	b.reset(h, r)
	check(b.supports("3-4") and not b.supports("3-3"), "Only big top")
	check(h.level.plats.size() == 49 and h.level.solids.size() == 15, "Exact authored inventory")
	check(b.movers.size() == 4 and b.spots.size() == 6, "Four movers and six switches")
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 42
	for spot in b.spots: check(near(spot.t, expected_rng.randf() * 6) and spot.hp == 2 and not spot.on, "Source randomized phase and two HP")
	var live: Dictionary = r.surfaces(h)[25]
	var row: Array = live.row
	check(is_same(live, b.movers[0].q) and live.nospawn and live.style == "trapeze", "Live surface identity and props")
	live.nodrop = true
	var bot := {"p": Vector2(4185,-228), "state":"walk", "surface":live}
	var pop := {"p": Vector2(4185,-228), "state":"pop", "surface":live}
	var hopping := {"p": Vector2(4185,-228), "state":"walk", "surface":live, "hop":{}}
	h.enemies = [bot,pop,hopping]
	r.level_time = 0.8
	b.movers_tick(h,r)
	check(near(row[0],4209.999999903422) and near(row[2],-202.0000000279004), "Independent quarter-cycle source reference")
	check(is_same(row, live.row) and near(live.dx,89.999999903422) and near(live.dy,25.9999999720996), "In-place rows and displacements")
	check(live.nodrop and live.nospawn, "Runtime properties survive transform")
	check(near(bot.p.x,4274.999999903422) and near(bot.p.y,row[2]), "Late bot x carry and top snap")
	check(pop.p == Vector2(4185,-228) and hopping.p == Vector2(4185,-228), "Pop and hopping excluded")
	h.world_three._active = true
	h.world_three._standing_surface = live
	h.player = Vector2(4230,-228)
	h.grounded = true
	h.world_three.carry_player(0.016,h)
	check(near(h.player.x,4319.999999903422) and near(h.player.y,row[2]), "Shared next-frame carry consumes cached late deltas")
	check(not h.world_three.allow_drop(h), "Shared nodrop respects live props")
	live.nodrop = false
	check(h.world_three.allow_drop(h), "Authored trapeze permits source drop")
	h.grounded = false
	var air := h.player
	h.world_three.carry_player(0.016,h)
	check(h.player == air, "Airborne player never carried")
	var old_x := float(row[0])
	r.level_time = 0.816
	b.movers_tick(h,r)
	check(near(live.dx, float(row[0])-old_x), "Delta is latest frame displacement")
	var phase := float(b.spots[0].t)
	var pos := float(row[0])
	b.spots[0].hp = -1
	b.spots[0].on = true
	b.reset_round()
	check(b.spots[0].hp == 2 and not b.spots[0].on and b.spots[0].t == phase and row[0] == pos, "Source round reset retains phase and mover position")
	_spots(h,r,b)
	h.camera.x = 3899.999
	b.events_tick(h,r)
	check(b.events_done.is_empty(), "Event below threshold")
	h.camera.x = 3900
	b.events_tick(h,r)
	b.events_tick(h,r)
	check(b.events_done == [0] and h.status == "Trapeze!. Time your jumps", "One-shot camera event at threshold")
	h.mode = "paused"
	phase = b.spots[0].t
	pos = row[0]
	r.level_time += 1
	b.spotlights_tick(1,h,r)
	b.movers_tick(h,r)
	check(b.spots[0].t == phase and row[0] == pos, "Pause freezes stage state")
	var snapshot := b.snapshot()
	snapshot.spots[0].hp = 99
	snapshot.movers[0].q.row[0] = -999
	check(b.spots[0].hp != 99 and row[0] != -999, "Painter snapshots detached")
	for count in [1,2]:
		var boss := Boss.new()
		boss.reset(h.meta.l3.mini,738,482,count,31)
		check(boss.state.hp == (60 if count == 1 else 80) and boss.state.cam == 8300 and boss.state.fy == 482 and boss.state.kind == "tout", "Shared ground Ringmaster exact config")
	check(h.meta.l3.mini.cam - 260 == 8040 and h.meta.l3.check == 5600 and h.meta.l3.checkY == -278, "Shared trigger and checkpoint coordinates")
	check(h.level.skill[0] == 5700 and h.level.skill[1] == -358 and h.level.skill[2] == "ground-pound" and h.level.receipts[0][0] == 3900 and h.level.receipts[0][1] == -278 and h.level.receipts[1][0] == 7900 and h.level.receipts[1][1] == -218 and h.level.receipts[2][0] == 12300 and h.level.receipts[2][1] == -438, "Shared finds exact upper coordinates")
	check(not h.meta.l3.has("noEnd") and not h.meta.l3.has("boss") and not h.meta.l3.has("stage"), "No roof altitude or final-stage gate authored")
	check(JSON.stringify(h.meta) == original, "Imported metadata unchanged")
	print("Festival big top: ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
func _shot(p: Vector2, enemy: bool = false) -> Dictionary:
	return {"p":p,"enemy":enemy,"damage":99,"ghost":true}
func _spots(h,r,b) -> void:
	var spot: Dictionary = b.spots[0]
	spot.t = 0
	h.enemies.clear()
	h.bullets = [_shot(Vector2(spot.x+26,spot.y+4)), _shot(Vector2(spot.x,spot.y+30)), _shot(Vector2(spot.x,spot.y+4),true)]
	var dead := _shot(Vector2(spot.x,spot.y+4))
	dead.dead = true
	h.bullets.append(dead)
	b.spotlights_tick(0,h,r)
	check(spot.hp == 2, "Strict 26px switch limits and hostile/dead exclusion")
	var first := _shot(Vector2(spot.x,spot.y+4))
	h.bullets = [first]
	b.spotlights_tick(0,h,r)
	check(first.dead and spot.hp == 1 and not spot.on, "Ghost/high damage is one switch hit")
	var second := _shot(Vector2(spot.x,spot.y+4))
	var third := _shot(Vector2(spot.x,spot.y+4))
	h.bullets = [second,third]
	var bot := {"p":Vector2(spot.x,spot.y+160),"state":"walk","dz":0.0}
	var pop := {"p":bot.p,"state":"pop","dz":0.0}
	h.enemies = [bot,pop]
	b.spotlights_tick(0,h,r)
	check(spot.on and spot.hp == -1 and second.dead and third.dead, "Source inner loop consumes excess activation-frame shots")
	check(near(bot.dz,0.25) and pop.dz == 0, "Immediate activation dazzle excludes pop")
	bot.dz = 0.216
	b.spotlights_tick(0.034,h,r)
	check(near(bot.dz,0.25), "Dazzle refresh every late frame")
	bot.dz = 0.5
	b.spotlights_tick(0,h,r)
	check(bot.dz == 0.5, "Longer existing daze preserved")
	spot.t = 0
	check(not b.beam_hits(spot,Vector2(spot.x,spot.y+60)), "Beam dy strictly positive")
	check(b.beam_hits(spot,Vector2(spot.x+tan(0.1999)*100,spot.y+160)), "Inside strict angular cone")
	check(not b.beam_hits(spot,Vector2(spot.x+tan(0.2001)*100,spot.y+160)), "Outside strict angular cone")
	check(b.beam_hits(spot,Vector2(spot.x,spot.y+100000)), "Source beam has no range or wall occlusion limit")
	var bypass := _shot(Vector2(spot.x,spot.y+4))
	h.bullets = [bypass]
	b.spotlights_tick(0,h,r)
	check(not bypass.get("dead",false), "Already-on lamp no longer intercepts")
