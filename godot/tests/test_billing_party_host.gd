extends SceneTree
## Real main/session scheduler boundary fixtures. Trace wrappers always call the
## production implementation. Both start and step are inherited unchanged; no
## test-only integration gate or second world simulation is permitted.
const Main = preload("res://src/main.gd")
const Session = preload("res://src/party_session.gd")
const World = preload("res://src/world_six.gd")
const Combat = preload("res://src/billing_combat.gd")
const AI = preload("res://src/companion_ai.gd")

class TraceWorld extends World:
	var trace: Array = []
	func pre_motion(dt, host): trace.append("pre"); super.pre_motion(dt, host)
	func world_tick(dt, host): trace.append("world"); super.world_tick(dt, host)
	func boss_tick(dt, host): trace.append("boss"); super.boss_tick(dt, host)
	func jar_tick(dt, host): trace.append("jar"); return super.jar_tick(dt, host)
	func finish_frame(host): trace.append("finish"); super.finish_frame(host)
class TraceCombat extends Combat:
	var trace: Array = []
	func waves_tick(dt, host): trace.append("waves"); super.waves_tick(dt, host)
	func enemies_tick(dt, host): trace.append("enemies"); super.enemies_tick(dt, host)
	func projectiles_tick(dt, host): trace.append("shots"); super.projectiles_tick(dt, host)
	func pickups_tick(dt, host): trace.append("pickups"); super.pickups_tick(dt, host)
	func visuals_tick(dt, host): trace.append("visuals"); super.visuals_tick(dt, host)
class TraceAI extends AI:
	var trace: Array = []
	var snapshot: Dictionary = {}
	func controls(dt, actor, context):
		trace.append("cpu")
		snapshot = {"leader": context.actors[0].player, "mate": actor.player, "elapsed": context.elapsed}
		return super.controls(dt, actor, context)
class FixtureSession extends Session:
	var trace: Array = []
	func _effects(host, dt): trace.append("effects:%d" % bridge.active_slot); super._effects(host, dt)
	func _late_skill(host): trace.append("skill:%d" % bridge.active_slot); super._late_skill(host)
class TraceMain extends Main:
	var trace: Array = []
	func _actor_step(dt, controls): trace.append("actor:%d" % party_session.active_slot); super._actor_step(dt, controls)
	func _update_camera(dt): trace.append("camera"); super._update_camera(dt)
	func scene_objective(dt): trace.append("objective"); super.scene_objective(dt)
	func collect_level_pickups(): trace.append("picks:%d" % combat_owner_slot()); super.collect_level_pickups()
	func combat_bubbles_tick(dt): trace.append("bubbles"); super.combat_bubbles_tick(dt)
	func _expire_ability_zaps(dt): trace.append("expire"); super._expire_ability_zaps(dt)

var game
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func start(id: String, mode := "p2", mate := "maya") -> void:
	game._show_menu()
	game.character = "jp"
	game.save = {"schema": 1, "receipts": {}, "skills": [], "seen": {}}
	check(game.configure_party(mode, mate), id + " explicit party mode accepted")
	check(game.load_level(id), id + " real metadata loaded")
	game.trace.clear()
func run() -> void:
	game = TraceMain.new()
	game.world_six = TraceWorld.new()
	game.billing_combat = TraceCombat.new()
	game.party_session = FixtureSession.new()
	game.party_session.ai = TraceAI.new()
	game.world_six.trace = game.trace
	game.billing_combat.trace = game.trace
	game.party_session.trace = game.trace
	game.party_session.ai.trace = game.trace
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	_frame_order()
	_cpu_order_and_pickups()
	_doors_and_lifecycle()
	_lift_and_ride()
	_boss_and_clear()
	_stage_smoke()
	game.queue_free()
	await process_frame
	print("Billing actual-main party: %d checks, %d failures. Phase/lifecycle fixtures, not complete party routes." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _frame_order() -> void:
	start("6-1")
	var session = game.party_session
	var p1 = session.runtime.actors[0]
	var p2 = session.runtime.actors[1]
	check(session.active and game.combat.participant_count == 2, "real load creates pair and scales W6 waves")
	var before1: Vector2 = p1.player
	var before2: Vector2 = p2.player
	session.step(game,0.016,{"right":true,"shoot":true},{"left":true,"shoot":true})
	check(game.trace == ["pre","actor:0","actor:1","camera","waves","objective","world","picks:0","picks:1","enemies","bubbles","shots","pickups","skill:0","skill:1","boss","jar","visuals","effects:0","effects:1","expire","finish"], "exact W6 source phase trace without duplicated shared systems")
	check(is_equal_approx(game.elapsed,0.016) and is_equal_approx(game.world_six.level_time,0.016) and is_equal_approx(game.world_six.world_time,0.016), "all three clocks advance once")
	check(is_equal_approx(p1.player.x,before1.x+4.32) and is_equal_approx(p2.player.x,before2.x-4.32), "human actors move independently once")
	check(game.bullets.filter(func(s):return not s.enemy and s.owner_slot==0).size()==1 and game.bullets.filter(func(s):return not s.enemy and s.owner_slot==1).size()==1, "real normal fire stamps both exact owners")
	check(is_equal_approx(p1.abilities._time,0.016) and is_equal_approx(p2.abilities._time,0.016), "per-actor ability clocks tick once")
	check(game.player==p1.player and game.character=="jp" and not session.bridge.shared_phase,"restores P1 facade and closes bridge")
	game._physics_process(0.016)
	before1=p1.player;before2=p2.player
	var key:=InputEventKey.new();key.physical_keycode=KEY_D;key.keycode=KEY_D;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events()
	game._physics_process(0.016)
	check(p1.player==before1 and p2.player.x>before2.x,"native engine D event moves only P2")
	key=key.duplicate();key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
	game._physics_process(0.016)
func _cpu_order_and_pickups() -> void:
	start("6-1","cpu")
	var session=game.party_session
	var p1=session.runtime.actors[0]
	var p2=session.runtime.actors[1]
	var before:Vector2=p1.player
	game.step(0.016,{"right":true})
	check(game.trace.slice(0,4)==["pre","cpu","actor:0","actor:1"],"W6 level prelude precedes CPU and both actors")
	check(session.ai.snapshot.leader==before and is_equal_approx(session.ai.snapshot.elapsed,0.016),"CPU sees this frame clock and previous player position")
	# P2 crosses the actual receipt body. Setup is a focused fixture, not route evidence.
	start("6-1")
	session=game.party_session;p1=session.runtime.actors[0];p2=session.runtime.actors[1]
	p2.player=game.receipts[0].position+Vector2(0,p2.character_height()*0.5)
	p2.grounded=true
	session.bind(game,0)
	game.step(0.016,{})
	check(game.receipts[0].taken and game.save.receipts["6-1"]==[0],"actual P2 receipt collision persists source index")
	check(game.score==0 and game.receipt_score==0 and p1.coins==0 and p2.coins==0,"W6 receipts award no invented kitty or personal coins")
	# Independent safe state survives binding through an unrelated actor callback.
	var safe1:Vector2=p1.scene_state.safe_position
	var safe2:Vector2=p2.scene_state.safe_position
	session.bridge.begin_shared(0)
	session.bridge.call_for_actor(1,game.hurt_player,[p2.player.x-10])
	session.bridge.end_shared(0)
	check(p1.scene_state.safe_position==safe1 and p2.scene_state.safe_position==safe2,"nested hurt callback retains both safe checkpoints")
	check(p2.hearts==2 and p1.hearts==3,"actual host hurt is victim scoped")
func _doors_and_lifecycle() -> void:
	start("6-1")
	var session=game.party_session
	var p1=session.runtime.actors[0];var p2=session.runtime.actors[1]
	var door:Dictionary=game.level.doors[0]
	# Force only the focused transition prerequisite, then exercise normal frame.
	for wave in game.combat.waves:wave.done=true
	game.world_six.wiping=false
	game.camera.x=door.x-200
	p1.mark_down();p1.player=Vector2(door.x-160,482)
	p2.player=Vector2(door.x-60,482)
	session.bind(game,0)
	game.step(0.016,{})
	check(game.world_six.wiping and game.world_six.doors_used.has(door.x),"living P2 opens real door despite downed leader")
	game.world_six._door.cp=true
	game.world_six.wipe_elapsed=1.42
	game.step(0.016,{})
	check(p1.player==Vector2(door.to+80,482) and p2.player==Vector2(door.to+150,482),"finish-frame shared door callback relocates both actor states")
	check(p1.down and p1.hearts==2 and p2.hearts==3,"door healing retains source down flag")
	check(game.player==p1.player and not session.bridge.shared_phase,"door midpoint reconciles before restoring facade")
	var time:float=game.world_six.world_time
	var position:Vector2=p2.player
	game.mode="paused";game.step(0.2,{"right":true})
	check(game.world_six.world_time==time and p2.player==position,"pause freezes both actors and scene clocks")
	game.mode="play"
	# After door, source +70 spacing is itself within rescue range.
	for i in 86:game.step(1.0/60,{})
	check(not p1.down and p1.hearts==2 and game.mode=="play","P2 normally revives leader after all-actor door transition")
	p1.mark_down();p2.mark_down();session.bind(game,0)
	game.step(0.016,{})
	check(game.mode=="over","all-down runs after W6 base frame")
	time=game.world_six.world_time;var camera:Vector2=game.camera
	game._continue_level()
	check(game.mode=="play" and p1.hearts==3 and p2.hearts==3 and not p1.down and not p2.down,"Continue revives both actual actors")
	check(game.world_six.world_time==time and game.camera==camera,"Continue preserves W6 scene progress")
func _lift_and_ride() -> void:
	start("6-4")
	var session=game.party_session
	var p1=session.runtime.actors[0];var p2=session.runtime.actors[1]
	game.world_six.level_time=10
	p1.player=Vector2(330,game.world_six.lift.row[2]-200)
	p2.player=Vector2(430,game.world_six.lift.row[2]+10)
	p2.grounded=false;session.bind(game,0)
	game.step(0.016,{})
	check(p1.hearts==3 and p2.hearts==2 and p2.velocity.y == -900 and not p2.grounded,"real lift phase damages and launches only P2 after actor movement")
	check(p2.invincible==1.5,"lift damage happens after actor timer decrement")
	start("6-5")
	session=game.party_session;p1=session.runtime.actors[0];p2=session.runtime.actors[1]
	var hazard:Dictionary=game.world_six.hazards.filter(func(h):return h.kind=="box")[0]
	game.camera.x=hazard.x-300
	game.world_six.camera_override(0,game)
	p1.player=Vector2(hazard.x,game.world_six.ride.row[2]);p2.player=p1.player
	session.bind(game,0)
	game.step(0.016,{})
	check(hazard.hit_slots.size()==2 and p1.hearts==2 and p2.hearts==2,"actual moving-cradle hazard hits both independent victims")
	check(p1.velocity.x==-300 and p2.velocity.x==-300,"actual cradle hazard keeps both per-victim source kicks")
func _boss_and_clear() -> void:
	start("6-6")
	var session=game.party_session
	var p1=session.runtime.actors[0];var p2=session.runtime.actors[1]
	game.camera.x=game.level.w-game.view_width()
	for wave in game.combat.waves:wave.done=true
	p1.player=Vector2(game.camera.x+100,482);p2.player=Vector2(game.camera.x+400,482)
	session.bind(game,0);game.step(0.016,{})
	check(game.boss!=null and game.boss.state.max==150,"actual W6 world phase starts source pair Sir Charge")
	var boss:Dictionary=game.boss.state
	boss.state="fight";boss.x=game.camera.x+500
	session.bridge.begin_shared(0)
	session.bridge.call_for_actor(1,game.damage_boss,[50])
	session.bridge.end_shared(0)
	check(game.bullets.any(func(s):return not s.enemy and s.get("ghost",false) and s.owner_slot==1),"actual P2 ability emits owner-stamped ghost through finite fy")
	game.step(0.016,{})
	check(boss.hp==149 and p2.scene_state.boss_hits==1 and not p1.scene_state.has("boss_hits"),"real ghost collision preserves fixed boss damage and exact owner tally")
	p1.mark_down();boss.state="down"
	boss.jar={"x":p2.player.x,"y":452.0,"vx":0.0,"vy":0.0,"t":0.61,"got":false}
	session.bind(game,0);game.step(0.016,{})
	check(game.mode=="clear" and game.save.cleared.get("6-6",false),"living P2 jar collision performs actual clear and save")
	check(not p1.down and p1.hearts==1 and p1.player_animation=="win" and p2.player_animation=="win","clear restores downed leader and both victory poses")
func _stage_smoke() -> void:
	for id in World.SUPPORTED_LEVELS:
		start(id,"cpu","ama")
		game.step(0.016,{})
		check(game.mode=="play" and game.party_session.active and game.combat.participant_count==2,id+" actual CPU frame")
		check(is_equal_approx(game.elapsed,0.016) and is_equal_approx(game.world_six.level_time,0.016) and is_equal_approx(game.world_six.world_time,0.016),id+" shared clocks each advance once")
		check(game.character=="jp" and game.player==game.party_session.runtime.actors[0].player,id+" restores P1 facade")
