extends SceneTree
const Host = preload("res://tests/test_world_six_support.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func near(a: float, b: float, label: String) -> void: check(absf(a - b) < 0.001, label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var h := Host.new()
	var world = h.world_six
	var common := ""
	for id in world.SUPPORTED_LEVELS:
		h.load_stage(id)
		check(world.supports(id), id + " dispatched")
		check(world.surfaces(h).size() == h.level.solids.size() + h.level.plats.size(), id + " all authored surfaces")
		check(h.combat.waves.size() == h.level.waves.size(), id + " all source waves")
		check(h.coins.size() == h.level.coinRows.size(), id + " all source coin rows")
		world.seed_pickups(h)
		check(h.coins.size() == h.level.coinRows.size(), id + " pickup seeding idempotent")
		check(world.snapshot().kind == h.level.kind, id + " distinct kind")
		var source := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../game/%s/index.html" % id))
		var start := source.find("// ================= World 6:")
		var end := source.find("// ================= World 6 art:")
		var runtime := source.substr(start, end - start)
		if common.is_empty(): common = runtime
		check(runtime == common, id + " identical source W6 runtime")
		check(source.contains("w6Update(dt); updateBots(dt); updateShots(dt); updateCoins(dt);"), id + " source phase order")
		var authored := h.level.duplicate(true)
		world.pre_motion(0.02, h)
		world.world_tick(0.02, h)
		check(h.level == authored, id + " immutable imported metadata")
	h.load_stage("6-1")
	var belt: Dictionary = world.surf_under(1600, 420)
	check(belt.art == "belt" and not belt.plat, "numeric vx not mistaken for bool or properties")
	h.player = Vector2(1600,420)
	world.carry_player(0.1,h)
	near(h.player.x,1610,"belt 0.1 px/ms converted to 100 px/s")
	h.player = Vector2(5000,420)
	world.carry_player(0.1,h)
	near(h.player.x,4994,"reverse conveyor")
	h.grounded = false
	world.carry_player(0.1,h)
	near(h.player.x,4994,"no airborne carry")
	check(world.surf_under(1600,423).is_empty(),"carry excludes exact three-pixel boundary")
	check(not world.land_on(h,900,341,342,true).get("plat",false),"skip one-way platforms")
	near(world.wall_clamp(h,1530,1550,482),1526,"solid side wall")
	check(not world.inside_wall(h,Vector2(1540,450)) and world.inside_wall(h,Vector2(1541,450)),"wall strict x edges")
	check(world.finds_near(h,Vector2(h.player.x,h.player.y-90)),"receipt half-height center")
	check(not world.finds_near(h,Vector2(h.player.x+40,h.player.y-90)),"receipt strict 40px")
	check(not world.wave_ready({"atT":1000},h),"time wave before threshold")
	world.level_time=1
	check(world.wave_ready({"atT":1000},h),"time wave at threshold")
	h.player.y=-18
	check(world.wave_ready({"atY":-18},h),"height wave inclusive threshold")
	h.player.y=-17
	check(not world.wave_ready({"atY":-18},h),"height wave one pixel below")
	h.camera.x=498
	check(world.wave_ready({"at":500},h),"position threshold has two-pixel tolerance")
	h.load_stage("6-1")
	for w in h.combat.waves: w.done=true
	h.camera.x=h.level.w-h.view_width()
	check(world.objective_tick(0,h)=="ending","run objective starts")
	check(world.objective_tick(2.599,h)=="","strict 2.6 ending boundary")
	check(world.objective_tick(0.001,h)=="clear","run clear after boundary")
	check(world.objective_tick(1,h)=="","only one clear event")
	h.load_stage("6-1")
	var door: Dictionary=h.level.doors[0]
	h.player.x=door.x-69
	check(not world.door_open(door,h),"door gated by all earlier waves")
	for w in h.combat.waves:
		if w.at<door.x:w.done=true
	check(world.door_open(door,h),"future waves do not block door")
	world.pre_motion(0.01,h);world.world_tick(0.01,h)
	check(world.wiping,"door creates wipe")
	world._last_dt=1.42;world.finish_frame(h)
	check(not world.wipe_midpoint_done,"door before 1.43 callback")
	world._last_dt=0.01;world.finish_frame(h)
	near(h.player.x,door.to+80,"door arrival player")
	near(h.camera.x,door.to-60,"door arrival camera")
	check(world.checkpoint_done and world.scene_index==1,"door checkpoint")
	world.invalidate_run();world.finish_frame(h)
	check(not world.wiping,"invalidated stale wipe")
	h.load_stage("6-2")
	for w in h.combat.waves:w.done=true
	h.camera.x=h.level.w-h.view_width()
	check(world.objective_tick(0,h)=="","hold not complete on arrival")
	world.world_tick(0,h)
	check(world.hold.on and world.hold.t==0,"hold activates after objective")
	world.hold.t=30;world.hold.spawn_t=999
	var floor_s: Dictionary=world.below(h,h.level.hold.door,482)
	var jammer: Dictionary=h.combat.new_bot(h,h.level.hold.door,floor_s,"rush",{"entered":true})
	world._hold_tick(0,h)
	near(world.hold.t,25,"robot reaching lift adds five seconds")
	check(jammer.state=="pop" and world.hold.jams==1,"jam removes bot")
	world.hold.t=89.99
	world._hold_tick(0.01,h)
	check(world.hold.done and not world.hold.on,"ninety-second hold")
	check(world.objective_tick(0,h)=="ending","hold ending next objective")
	h.load_stage("6-4")
	world.level_time=5;h.player.y=482
	world._lift_tick(0.1,h)
	near(world.lift.row[2],482,"lift delay strict at five seconds")
	world.level_time=5.001;h.player.y=482;h.invincible=0
	world._lift_tick(0.1,h)
	near(world.lift.row[2],479.6,"lift v0 24 px/s")
	check(h.hearts==2 and h.velocity.y==-900 and not h.grounded,"lift charging damage and 900 launch")
	world.lift.row[2]=482;h.player.y=-218;h.invincible=999
	var speed:=lerpf(24,42,700.0/8400)*2.6
	world._lift_tick(0.1,h)
	near(world.lift.row[2],482-speed*0.1,"lift catch-up 2.6 speed")
	world.lift.row[2]=-7900
	world._lift_tick(1,h)
	near(world.lift.row[2],-7758,"lift stops top plus 160")
	for w in h.combat.waves:w.done=true
	h.player.y=-7914;h.grounded=true
	check(world.done(h),"climb completion top plus four")
	h.grounded=false
	check(not world.done(h),"climb requires landing")
	h.load_stage("6-5")
	world.carry_player(0.1,h)
	near(h.player.x,310,"cradle rider carry")
	check(world.camera_override(0.1,h),"ride overrides camera")
	near(h.camera.x,10,"ride 100 px/s")
	near(world.ride.row[0],140,"ride moves live platform after player")
	# Source beam uses 75% height: JP's 180px body cannot touch a ledge 150px high while standing.
	h.player=Vector2(2400,482);h.crouching=false
	world._ride_tick(h)
	check(h.hearts==3,"source beam height strict prevents standing short-character collision")
	h.player.y=450;world._ride_tick(h)
	check(h.hearts==2,"beam intersects raised body")
	h.player=Vector2(4450,424);h.invincible=0
	world._ride_tick(h)
	check(h.hearts==2,"box excludes feet exactly top minus58")
	h.player.y=425;world._ride_tick(h)
	check(h.hearts==1,"box collision just beyond jump boundary")
	h.load_stage("6-S")
	world.dash.left=12.2;h.player.x=h.level.dash.finish
	check(world.objective_tick(0,h)=="ending" and h.score==13,"coffee finish ceil seconds bonus")
	world.objective_tick(0,h)
	check(h.score==13,"bonus once, no repeated objective award")
	h.load_stage("6-S")
	world.dash.left=0.01
	check(world.objective_tick(0.01,h)=="","timeout objective before decrement")
	world._dash_tick(0.01,h)
	check(world.dash.done and world.end_time==0.001,"timeout starts source one-ms ending")
	check(world.objective_tick(2.599,h)=="","timeout strict delay")
	check(world.objective_tick(0.001,h)=="clear","timeout clears normally")
	h.load_stage("6-6")
	check(world.wiping and world.wipe_kind == "lift", "final-stage authored intro wipe")
	var initial_position: Vector2 = h.player
	world._last_dt=1.43;world.finish_frame(h)
	check(world.wipe_midpoint_done and h.player==initial_position and world.scene_index==0, "intro midpoint does not teleport")
	world._last_dt=0.74;world.finish_frame(h)
	check(not world.wiping, "intro source2.17seconds complete")
	world.add_float("Lift jammed! +5s", Vector2(200,182), Color("ffb3b3"))
	world.effects_tick(1.299,h)
	check(world.floating.size()==1 and absf(world.floating[0].age-1.299)<0.0001, "float remains below1.3second edge")
	world.effects_tick(0.001,h)
	check(world.floating.is_empty(), "float removed exactly at1.3second edge")
	world.add_float("test",Vector2.ZERO,Color.WHITE)
	h.mode="paused";world.effects_tick(1,h)
	check(world.floating[0].age==0, "float pause guard")
	h.load_stage("6-1")
	check(world.floating.is_empty(), "float lifetime cannot cross level reset")
	print("World 6 systems: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
