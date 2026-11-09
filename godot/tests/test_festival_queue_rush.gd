extends SceneTree
const Queue = preload("res://src/festival_queue_rush.gd")
const BaseFixture = preload("res://tests/test_world_three.gd")
const World = preload("res://src/world_three.gd")
var checks := 0
var failures: Array[String] = []
# Use the actual production WorldThree and its owned queue extension.
class BossController extends RefCounted:
	var state := {"state": "walk"}
class Host extends BaseFixture.Host:
	var player_animation := "idle"
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
func near(a: float, b: float) -> bool: return absf(a-b) < 0.002
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var h := Host.new()
	h.load_source("3-2")
	var q = h.world_three.queue_rush
	var r = h.world_three
	var original := JSON.stringify(h.meta)
	check(q.supports("3-2") and not q.supports("3-1"), "Stage-isolated extension")
	check(h.level.w == 30000 and h.level.auto == 0.14 and h.level.fall == 782 and h.level.duck.size() == 6, "Exact authored world/auto/fall/banner fixtures")
	check(q.auto_displacement(0.034,h,r,1.8) == 0 and near(q.auto_displacement(0.034,h,r,1.80001),4.76), "Strict warmup and140px/s conversion")
	var camera := 0.0
	for i in range(100):
		r.level_time = i * 0.034
		camera = minf(29262, camera + r.auto_displacement(0.034,h))
	check(near(camera,48*4.76), "100 frames source recurrence includes crossing frame after52 warmup frames")
	check(minf(29262,29260+q.auto_displacement(0.034,h,r,5)) == 29262, "Camera caps at world minus738, not endthreshold")
	for mode in ["paused","over","clear"]:
		h.mode = mode
		check(q.auto_displacement(1,h,r,5) == 0, "Auto blocked in"+mode)
	h.mode = "play"
	r.wiping = true
	check(q.auto_displacement(1,h,r,5) == 0,"Wipe blocks scroll")
	r.wiping = false
	h.boss = BossController.new()
	check(q.auto_displacement(1,h,r,5) == 0,"Living boss blocks scroll")
	h.boss.state.state = "down"
	check(q.auto_displacement(1,h,r,5) == 140,"Down boss permits scroll (but shared end still requires nullboss)")
	h.boss = null
	r.end_time = 0.001
	check(q.auto_displacement(1,h,r,5) == 0,"Ending blocks scroll")
	r.after_pickups(0.034,h)
	check(near(q.end_run,0.034),"Runner clock seconds")
	r.end_time = 0
	check(q.end_ok(h) and h.combat.waves.any(func(w): return not w.done),"Auto end ignores incomplete waves")
	h.meta.l3.noEnd = true
	check(not q.end_ok(h),"noEnd still suppresses exit")
	h.meta.l3.erase("noEnd")
	_objective(h)
	_geometry(h,q)
	_banners(h,q)
	_scene_events(h,q)
	check(JSON.stringify(h.meta) == original,"All imported metadata immutable")
	_source()
	print("Festival queue rush: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _objective(h) -> void:
	var r = h.world_three
	h.camera.x = 29259.99
	check(r.objective_tick(0.016,h) == "", "Production objective rejects before29260")
	h.camera.x = 29260
	h.enemies.append({"state":"walk"})
	h.boss = BossController.new()
	h.boss.state.state = "down"
	check(r.objective_tick(0.016,h) == "", "Production objective still rejects existing downboss")
	h.boss = null
	check(r.objective_tick(0.016,h) == "ending" and near(r.end_time,0.017), "Production objective starts with livebot and incompletewaves")
	check(r.objective_tick(2.583,h) == "" and near(r.end_time,2.6), "Production objective strict2600ms boundary")
	check(r.objective_tick(0.0001,h) == "clear" and r.objective_tick(1,h) == "", "Production objective clear one-shot")
	h.load_source("3-2")
func _geometry(h,q) -> void:
	var r = h.world_three
	var crowds: Array = r.surfaces(h).filter(func(s): return s.get("style","") == "crowd")
	check(crowds.size() == 5 and crowds.all(func(s): return not s.plat and s.conv == 0.12),"All five crowds are solid conveyors")
	for s in crowds:
		h.player = Vector2(s.row[0]+100,442)
		h.grounded = true
		r.after_motion(h)
		var x: float = h.player.x
		r.carry_player(0.034,h)
		check(near(h.player.x-x,4.08) and h.player.y == 442,"Crowd carry exact120px/s")
		h.grounded = false
		x = h.player.x
		r.carry_player(0.034,h)
		check(h.player.x == x,"No airborne crowd carry")
	for gap in h.level.gaps:
		check(r.below(h,(gap[0]+gap[1])*0.5,0).is_empty(),"Authored gap remains open")
	h.camera.x = 1000
	r.safe_position = Vector2(1050,482)
	h.player = Vector2(1110,482)
	h.invincible = 9
	h.hearts = 3
	check(q.squash(h,r) and h.hearts == 2 and h.player == Vector2(1230,482),"Inside barrier squash forces normal recovery damage despite oldinvincibility")
	check(h.grounded and not h.on_platform and h.velocity == Vector2.ZERO,"Recovery resets velocity and lands on solid roof")
	h.player = Vector2(1100,482)
	check(not q.squash(h,r),"Exact solid xedge is not inside wall")
func _banners(h,q) -> void:
	for row in h.level.duck:
		for x in [float(row[0])-10,float(row[1])+10]:
			check(q.banner_hits(row,Vector2(x,482),180,"idle"),"Inclusive banner horizontal edge")
		check(not q.banner_hits(row,Vector2(row[0]-10.001,482),180,"idle") and not q.banner_hits(row,Vector2(row[1]+10.001,482),180,"idle"),"Outside banner excluded")
		check(not q.banner_hits(row,Vector2(row[0],482),180,"crouch"),"Ground crouch clears banner")
		check(not q.banner_hits(row,Vector2(row[0],322),180,"idle") and q.banner_hits(row,Vector2(row[0],322.001),180,"idle"),"Strict feet above underside-40 boundary")
		check(not q.banner_hits(row,Vector2(row[0],362+100*0.86),100,"idle") and q.banner_hits(row,Vector2(row[0],362+100*0.86-0.001),100,"idle"),"Strict head top boundary")
	h.player = Vector2(1900,482)
	h.hearts = 3
	h.invincible = 0
	h.player_animation = "crouch"
	h.world_three.after_pickups(0.01,h)
	check(h.hearts == 3,"Crouch action not raw input suppresses damage")
	h.player_animation = "idle"
	h.world_three.after_pickups(0.01,h)
	h.world_three.after_pickups(0.01,h)
	check(h.hearts == 2,"Normal damage preserves shared invincibility guards")
func _scene_events(h,q) -> void:
	h.load_source("3-2")
	var r = h.world_three
	h.camera.x = 14000
	h.player.x = 14300
	h.hearts = 1
	r.after_pickups(0.01,h)
	check(not r.wiping and not r.checkpoint_done,"Strict14300 checkpoint andscene boundary")
	h.player.x += 0.01
	h.enemies.append({"state":"walk"})
	h.combat.waves[0].started = true
	r.after_pickups(0.01,h)
	check(q.scene_can_start(h,r) and r.wiping and r.wipe_kind == "iris" and r.checkpoint_done and h.hearts == 3,"Shared realiris/checkpoint through auto busy bypass")
	r.after_pickups(1.429,h)
	r.finish_frame(h)
	check(h.camera.x == 14000,"No early iris teleport")
	r.after_pickups(0.001,h)
	check(h.camera.x == 14000,"Callback deferred until finish_frame")
	r.finish_frame(h)
	check(h.camera.x == 15300 and near(h.player.x,15600.01) and h.enemies.is_empty(),"Iris preserves camera-relative offset and clears enemies")
	r.after_pickups(0.01,h)
	check(q.events_done == [0] and h.status == "Crowd surf!. Ride the crowd and keep up","First source notice at destination on nextlate pass")
	h.camera.x = 27761.99
	r.after_pickups(0.01,h)
	check(q.events_done == [0],"Second event exact lower bound")
	h.camera.x = 27762
	r.after_pickups(0.01,h)
	r.after_pickups(0.01,h)
	check(q.events_done == [0,1] and h.festival_events.size() == 2,"Both authored notices once only")
	h.mode = "paused"
	var frozen: Dictionary = q.snapshot()
	r.after_pickups(30,h)
	check(q.snapshot() == frozen,"Pause freezes extension")
	h.mode = "clear"
	h.final_base_step = true
	r.end_time = 2.601
	r.after_pickups(0.034,h)
	check(near(q.end_run,0.034),"Final clear base frame continues late clock")
	h.load_source("3-2")
	check(q.end_run == 0 and q.events_done.is_empty(),"Reset clears event andrunner state")
func _source() -> void:
	var source := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../game/3-2/index.html"))
	for token in ["levelT > 1800", "cam + LV.auto * dt", "LV.auto ? true : waves.every", "LV.auto || !waveBusy()", "p.x < z[0] - 10 || p.x > z[1] + 10", "crouch ? 0.6 : 0.86", "GROUND + p.y > z[2] - 40", "if (q.conv) p.x += q.conv * dt", "if (L3.jarRunner && endT) endRun += dt", "if (f1 > LV.fall) fellOff(p)"]:
		check(source.contains(token),"Immutable HTML source contract: "+token)
