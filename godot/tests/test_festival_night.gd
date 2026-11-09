extends SceneTree
const Night = preload("res://src/festival_night.gd")
const Base = preload("res://tests/test_world_three.gd")
const Boss = preload("res://src/festival_boss.gd")
var checks := 0
var failures: Array[String] = []
class FixedRandom extends RefCounted:
	var values: Array = []
	var draws := 0
	func randf() -> float:
		draws += 1
		return values.pop_front() if not values.is_empty() else 0.5
class RuntimeStub extends RefCounted:
	var rng = FixedRandom.new()
	func _can_step(h) -> bool: return h.mode == "play"
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
func near(a: float,b: float) -> bool: return absf(a-b) < 0.000001
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var h := Base.Host.new()
	h.load_source("3-3")
	var original := JSON.stringify(h.meta)
	var n := Night.new()
	var r := RuntimeStub.new()
	n.reset(h)
	check(n.supports("3-3") and not n.supports("3-1"),"Night isolated")
	check(n.snapshot().fires.size() == 5,"Five authored campfires")
	for i in range(5):
		check(n.snapshot().fires[i][0] == [1450,3900,8650,12250,14550][i] and n.snapshot().fires[i][1] == 482,"Exact authored fire position")
	for f in h.level.fires:
		for offset in [Vector2(34,0),Vector2(-34,0),Vector2(0,30),Vector2(0,-30)]:
			check(not n.fire_hits(f,Vector2(f[0],f[1])+offset),"Strict fire boundary")
		check(n.fire_hits(f,Vector2(f[0]+33.99,f[1]+29.99)),"Inside fire rectangle")
		h.player = Vector2(f[0],f[1])
		h.invincible = 0
		h.hearts = 3
		n.fires_tick(h,r)
		check(h.hearts == 2,"Fire uses normal damage")
		n.fires_tick(h,r)
		check(h.hearts == 2,"Fire respects normal invulnerability")
	check(n.snapshot().authored_tent_glows.size() == 15 and h.world_three.tents.all(func(t): return not t.get("glow",false)),"Source ignores authored fifth tent glow column")
	r.rng.values = [0.034/7.0]
	n.fireworks_tick(0.034,h,r)
	check(n.fireworks.is_empty() and r.rng.draws == 1,"Strict chance boundary consumes exactly one draw")
	r.rng.values = [0.0,0.25,0.75,0.99]
	n.fireworks_tick(0.034,h,r)
	check(r.rng.draws == 49,"Spawn consumes chance + xyz-color +44 independent spark draws")
	var sound: Dictionary = h.festival_events.back()
	check(sound.type == "firework" and near(sound.noise.delay,0.05) and not sound.noise.has("end_volume"),"Source firework noise fourth argument is50ms start delay")
	var f: Dictionary = n.fireworks[0]
	check(near(f.x,234.5) and near(f.y,h.view_top()+135) and f.col == "#9be37a", "Firework camera/view relative placement and palette")
	check(f.s.size()==22 and near(f.s[1].x,cos(0.2856)) and near(f.s[1].y,sin(0.2856)),"22 sparks with independent component scales")
	check(near(f.t,0.034) and near(n.flash_time,0.5) and near(n.darkness_alpha(),1.0/12),"Birth ages immediately; flash is not decremented again")
	n.timers_tick(0.1,h,r)
	check(near(n.flash_time,0.4) and near(n.darkness_alpha(),1.0/6),"Flash decay source opacity")
	var snapshot := n.snapshot()
	snapshot.fireworks[0].s.clear()
	check(n.fireworks[0].s.size()==22,"Detached immutable renderer snapshot")
	n.fireworks[0].t = 1.366
	r.rng.values = [0.99]
	n.fireworks_tick(0.034,h,r)
	check(n.fireworks.is_empty(),"Strict1.4 second expiry")
	h.mode = "paused"
	var draws: int = r.rng.draws
	n.timers_tick(1,h,r)
	n.fireworks_tick(1,h,r)
	check(near(n.flash_time,0.4) and r.rng.draws == draws,"Pause freezes clocks and RNG")
	h.mode = "play"
	n.reset(h)
	check(n.flash_time==0 and n.fireworks.is_empty() and n.dark==0.5,"Reset clears run animation")
	_bailiff(h)
	if h.world_three.supports("3-3"): _integration(h)
	else: print("Production integration pending: WorldThree does not yet advertise3-3; isolated tests only.")
	check(JSON.stringify(h.meta)==original,"Imported metadata immutable")
	print("Festival night: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _bailiff(h) -> void:
	for count in [1,2]:
		var b := Boss.new()
		b.reset(h.meta.l3.mini,738,482,count,31,{},true)
		check(b.state.hp == (70 if count==1 else 95) and b.state.cam==8000 and b.state.kind=="bailiff", "Exact shared Bailiff config/scaling")
		b.drain_events()
		b.state.state = "throw"
		b.state.x = 8400
		b.state.t = 0.319
		b.state.pending_throw = true
		var events: Array = b.boss_tick(0.001,[{"position":Vector2(8200,482)}])
		var bills: Array = events.filter(func(e): return e.type=="bill")
		check(bills.size()==3 and bills.all(func(e):return e.big and not e.tie),"Bailiff throws three big nontying bills")
		b.state.state="charge"
		b.state.t=0
		b.state.face=1
		b.boss_tick(0.034,[{"position":Vector2(8200,482)}])
		check(near(b.state.x,8417),"Shared Bailiff charge500px/s")
		b.state.state="stomp"
		b.state.t=0.319
		b.state.pending_throw=true
		b.boss_tick(0.001,[{"position":Vector2(8200,482)}])
		check(b.state.waves.size()==2 and b.state.waves[0].vx==-420 and b.state.waves[1].vx==420,"Shared Bailiff shockwaves")
func _integration(h) -> void:
	h.load_source("3-3")
	var r = h.world_three
	h.camera.x=6700
	h.player.x=7000
	h.hearts=1
	h.step(0.016)
	check(not r.checkpoint_done and not r.wiping,"Strict scene/checkpoint x7000")
	h.player.x=7000.01
	h.step(0.016)
	check(r.checkpoint_done and h.hearts==3 and r.wiping and r.wipe_kind=="fade","Shared night checkpoint/fade")
	var expected_player_x: float = Vector2(h.player.x + (7900 - h.camera.x), h.player.y).x
	h.step(1.43)
	check(r.scene_index==1 and h.camera.x==7900 and h.player.x == expected_player_x,"Exact after-dark fade callback1.43 and destination7900")
	h.step(0.016)
	check(h.combat.boss_starts.size()==1 and h.combat.boss_starts[0].config.kind=="bailiff", "Production late Bailiff trigger after transition")
	check(r.stage_data.has("fireworks") and r.stage_data.dark==0.5,"Production renderer snapshot supplies night state")
	h.load_source("3-3")
	h.player=Vector2(1450,482)
	h.step(0.016)
	check(h.hearts==2,"Production late phase invokes fire hazards")
