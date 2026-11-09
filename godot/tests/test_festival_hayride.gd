extends SceneTree
const Ride = preload("res://src/festival_hayride.gd")
const Base = preload("res://tests/test_world_three.gd")
const Combat = preload("res://src/festival_combat.gd")
# Isolation adapter enables only the runtime guard before parent integration.
# No alternative geometry, collision, carry, checkpoint, or combat algorithm.
class Runtime extends "res://src/world_three.gd":
	func supports(id: String) -> bool: return id == "3-5" or super.supports(id)
class Host extends Base.Host:
	var pop_count := 0
	var crates: Array = []
	var crouching := false
	var player_animation := "idle"
	var drops: Array = []
	func add_coins(p: Vector2, n: int) -> void: drops.append({"p":p,"count":n})
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func near(a: float,b: float) -> bool: return absf(a-b) < 0.002
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var h := Host.new()
	h.world_three = Runtime.new()
	h.load_source("3-5")
	h.combat = Combat.new()
	h.combat.reset(h)
	var r = h.world_three
	var q = Ride.new()
	q.reset(h)
	q.bind_trailer(h,r)
	var original := JSON.stringify(h.meta)
	check(h.level.w == 34000 and h.level.fall == 572 and h.level.startY == 392,"Authored world/start/fall")
	check(near(r.trailer.row[0],60) and near(r.trailer.row[1],540) and near(r.trailer.row[2],402) and r.trailer.nospawn and r.trailer.nodrop,"Exact initial live trailer")
	check(r.below(h,300,392) == r.trailer,"Trailer exists before initial floor lookup")
	h.player = Vector2(300,402)
	h.on_platform = true
	r.after_motion(h)
	check(not r.allow_drop(h),"Trailer nodrop")
	check(q.auto_displacement(.034,h,r,1.8) == 0 and near(q.auto_displacement(.034,h,r,1.801),5.78),"Strict warmup170px/s")
	var before := h.player
	r.carry_player(.034,h)
	check(h.player == before,"No invented early deck movement")
	r.cam_dx = 5.78
	q.trailer_tick(h,r)
	check(h.player == before and near(r.trailer.row[0],65.78),"Late deck moves without same-frame player carry")
	r.carry_player(.034,h)
	check(near(h.player.x,305.78),"Previous-frame carry")
	h.grounded = false
	r.carry_player(.034,h)
	check(near(h.player.x,305.78),"Airborne player not carried")
	h.grounded = true
	var bot := {"p":Vector2(200,390),"state":"walk","surface":r.trailer}
	h.enemies.append(bot)
	q.trailer_tick(h,r)
	check(near(bot.p.x,205.78) and bot.p.y == 402,"Late bot dx carry snaps feet")
	r.cam_dx = 0
	bot.p.y = 390
	q.trailer_tick(h,r)
	check(bot.p.y == 390,"Zero dx deliberately does not snap bot feet")
	h.enemies.clear()
	check(h.level.duck.size() == 18,"18 authored branches")
	for row in h.level.duck:
		check(q.banner_hits(row,Vector2(row[0]-10,402),180,"idle"),"Branch inclusive edge")
		check(not q.banner_hits(row,Vector2(row[0],402),180,"crouch"),"Branch crouch clearance")
	check(h.meta.l3.check == 13300 and h.meta.l3.scenes[1].to == 14500 and h.meta.l3.scenes[1].wipe == "fade","Checkpoint/dusk source constants")
	h.camera.x = 15000
	q.harvester_tick(0,h,r)
	check(q.harvester.hp == 70 and q.harvester.x == 14580 and h.boss == null,"Solo harvester separate from boss")
	var deck_offset: float = r.trailer.row[0] - h.camera.x
	var harv_offset: float = q.harvester.x - h.camera.x
	q.scene_translate(1234,r)
	h.camera.x += 1234
	check(near(r.trailer.row[0]-h.camera.x,deck_offset) and near(q.harvester.x-h.camera.x,harv_offset) and r.trailer.dx == 0,"Scene translates deck/harvester preserving offsets/dx")
	_harvester(h,q,r)
	check(q.end_ok(h) and h.combat.waves.any(func(w): return not w.done),"No harvester or wave gate on auto exit")
	q.harvester = {"hp":70,"max":70,"x":100,"t":0.0,"flash":0.0,"dead":false}
	h.mode = "paused"
	q.harvester_tick(1,h,r)
	check(q.harvester.t == 0,"Pause preserves encounter")
	h.mode = "play"
	q.harvester_tick(.016,h,r)
	check(near(q.harvester.t,.016),"Continue resumes live encounter without reset")
	var data: Dictionary = q.snapshot()
	data.harvester.hp = 0
	check(q.harvester.hp == 70,"Snapshot copy does not mutate encounter")
	check(JSON.stringify(h.meta) == original,"Metadata immutable across movement/scene/combat")
	r.reset(h)
	q.reset(h)
	q.bind_trailer(h,r)
	check(near(r.trailer.row[0],60) and near(r.trailer.row[1],540) and near(r.trailer.row[2],402) and r.trailer.dx == 0 and q.harvester.is_empty(),"Fresh translated-run reset before spawn restores deck and encounter")
	h.combat.reset(h,2)
	h.camera.x = 15000
	q.harvester_tick(0,h,r)
	check(q.harvester.hp == 91 and q.harvester.max == 91,"Pair91 HP")
	_source_waves(h)
	_carriers(h,q,r)
	print("Festival hayride: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _harvester(h,q,r) -> void:
	r.cam_dx = 0
	r.trailer.row[0] = 160
	r.trailer.row[1] = 640
	q.harvester = {"x":100.0,"hp":2.0,"max":70.0,"flash":0.0,"t":0.0,"dead":false}
	# goal100 keeps x fixed. First shot shoves to94; second x99 still hits.
	h.bullets = [{"p":Vector2(100,103),"damage":99,"ghost":true},{"p":Vector2(99,103),"damage":99},{"p":Vector2(100,102)},{"p":Vector2(100,103),"enemy":true}]
	q.harvester_tick(0,h,r)
	check(q.harvester.hp == 0 and q.harvester.x == 88 and not q.harvester.dead and h.drops.is_empty(),"Late fixed-one shot hits push6 each and defer death")
	check(not h.bullets[2].get("dead",false) and not h.bullets[3].get("dead",false),"Strict shot y bound and hostile exclusion")
	q.harvester_tick(.034,h,r)
	check(q.harvester.dead and h.drops.size() == 1 and h.drops[0] == {"p":Vector2(240,302),"count":14},"Death drops14 at deck+80/top-100 once")
	check(near(q.harvester.x,77.8) and q.harvester.t == 0,"Death frame clock reset and300px/s retreat")
	q.harvester_tick(3,h,r)
	check(not q.harvester.get("done",false),"Strict3000ms death boundary")
	q.harvester_tick(.001,h,r)
	check(q.harvester.done and q.harvester.x == -1e9 and h.drops.size() == 1,"Done sentinel never respawns/double drops")
	var x: float = q.harvester.x
	q.scene_translate(900,r)
	check(q.harvester.x == x,"Done sentinel excluded from scene translation")
func _source_waves(h) -> void:
	var solo := 0
	var pair := 0
	for wave in h.meta.l3.waves:
		for entry in wave[1]:
			pair += 1
			if entry.size() < 4 or not entry[3]: solo += 1
	check(h.meta.l3.waves.size() == 16 and solo == 39 and pair == 62,"Authored16 waves39/62 entries")
	check(h.level.receipts.size() == 3 and h.level.receipts[0][0] == 8000 and h.level.receipts[1][0] == 20000 and h.level.receipts[2][0] == 30000 and h.level.receipts.all(func(row): return row[1] == 212),"Three stationary receipt centers")

func _carriers(h,q,r) -> void:
	for count in [1,2]:
		h.combat.reset(h,count)
		h.enemies.clear()
		for wave in h.combat.waves:
			h.camera.x = wave.at
			r.trailer.row[0] = h.camera.x + 60
			r.trailer.row[1] = h.camera.x + 540
			h.combat.waves_tick(4,h)
		check(h.enemies.size() == (39 if count == 1 else 62) and h.combat.waves.all(func(w): return w.done),"Every authored auto wave dispatches with surviving carriers/flyers")
		check(h.enemies.all(func(b): return (b.get("ride",false) and b.hp == 3 and b.p.y == 327) or (b.get("fly",false) and b.hp == 2 and b.p.y == 372)),"Delivery/flying factories exact HP and altitude")
	h.enemies.clear()
	h.camera.x = 0
	r.trailer.row[0] = 60
	r.trailer.row[1] = 540
	r.cam_dx = 5.78
	h.combat.spawn(h,"k","throw")
	var bot: Dictionary = h.enemies[0]
	bot.p.x = bot.tx
	bot.cd = 9.0
	bot.hop_t = 0.0
	h.combat._bot_hook(.034,h,bot)
	check(not bot.ride and not bot.carry and bot.type == "rush" and bot.hop.duration == .42 and bot.hop.surface == r.trailer,"Carrier drops into420ms rush hop onto same live deck")
	check(h.combat.ex_drones.size() == 1 and near(bot.hop.end.x,clampf(bot.p.x,120,480)+5.78*30),"Detach once and source camDX-times30 hop lead")
	h.combat.spawn(h,"k","throw")
	var killed: Dictionary = h.enemies.back()
	h.combat.kill_enemy(h,killed)
	check(not killed.carry and not killed.ride and h.combat.ex_drones.size() == 2,"Pop detaches in simulation without render")
	r.level_time += 2.6
	h.combat.visuals_tick(0,h)
	check(h.combat.ex_drones.is_empty(),"Detached drones expire at2.6s without drawing")
