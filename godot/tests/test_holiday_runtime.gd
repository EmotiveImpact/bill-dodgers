extends SceneTree
const World = preload("res://src/world_four.gd")
const Combat = preload("res://src/holiday_combat.gd")
var checks := 0
var failures: Array[String] = []
class Host extends RefCounted:
	var level_id := "4-1"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var mode := "play"
	var player := Vector2(300,482)
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
	var power_time := 0.0
	var crouching := false
	var score := 0
	var pop_count := 0
	var status := ""
	var abilities = null
	var boss = null
	var enemies: Array = []
	var bullets: Array = []
	var coins: Array = []
	var crates: Array = []
	var items: Array = []
	var sounds: Array = []
	var events: Array = []
	var order: Array = []
	var world_four = World.new()
	var combat = Combat.new()
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func character_height() -> float: return 180.0
	func sfx(key: String) -> void: sounds.append(key)
	func holiday_event(event: Dictionary) -> void: events.append(event)
	func hurt_player(from_x: float) -> void:
		if hearts <= 0 or invincible > 0 or mode != "play": return
		hearts -= 1
		invincible = 1.5
		velocity.x = -350 if player.x < from_x else 350
	func add_coins(p: Vector2, count: int) -> void:
		for i in count: coins.append({"p": p, "v": Vector2(0,-500), "age": 0.0, "rest": false})
	func collect_level_pickups() -> void: order.append("picks")
	func holiday_dash_step() -> void: order.append("dash")
	func ability_inside_wall(p: Vector2) -> bool: return world_four.inside_wall(self,p)
	func _land(x: float,a: float,b: float) -> float:
		var s: Dictionary = world_four.land_on(self,x,a,b)
		return INF if s.is_empty() else float(s.row[2])
	func load_source(id: String, pair: int = 1) -> void:
		level_id = id
		meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/"+id+".json"))
		level = meta.level
		player = Vector2(level.get("start",300), meta.ground)
		mode = "play"
		velocity = Vector2.ZERO
		hearts = 3
		invincible = 0
		grounded = true
		on_platform = false
		enemies.clear(); bullets.clear(); coins.clear(); items.clear(); crates.clear(); sounds.clear(); order.clear()
		score = 0
		pop_count = 0
		world_four.reset(self)
		camera = Vector2.ZERO
		camera_lock = null
		combat.reset(self,pair)
		world_four.seed_pickups(self)
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL ",label)
func near(a: float,b: float) -> bool: return absf(a-b)<0.0001
func shot(x: float,y: float, damage: int = 1) -> Dictionary:
	return {"p":Vector2(x,y),"v":Vector2(780,0),"damage":damage,"life":20.0,"enemy":false,"age":0.0}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var h := Host.new()
	for id in World.SUPPORTED_LEVELS:
		h.camera.x = 20000
		h.load_source(id)
		check(h.world_four.supports(id),id+" supported module")
		check(h.world_four.surfaces(h).size() == h.level.solids.size()+h.level.plats.size()+(1 if id=="4-5" else 0),id+" geometry count")
		check(h.combat.waves.size()==h.level.waves.size(),id+" wave count")
		check(h.crates.size()==h.level.crates.size(),id+" source crates")
		for i in h.combat.waves.size(): check(h.combat.waves[i].group == h.level.waves[i].g,id+" ordered solo group")
		var before := JSON.stringify(h.meta)
		h.world_four.pre_motion(0.016,h)
		check(before==JSON.stringify(h.meta),id+" immutable imported metadata")
	_geometry(h)
	_foes(h)
	_hold(h)
	_bonus(h)
	_gates(h)
	_waves(h)
	_cleanup(h)
	if failures.is_empty(): print("Holiday runtime/combat: ",checks," checks passed; isolated fixtures, not full-run/device evidence.")
	else: printerr(failures)
	quit(0 if failures.is_empty() else 1)
func _geometry(h) -> void:
	h.load_source("4-1")
	check(h.world_four.foes.entries.size()==9,"nine authored suitcases")
	var belts: Array = h.world_four.surfaces(h).filter(func(s):return s.has("belt"))
	check(belts.size()==4 and belts.all(func(s):return s.nobot and s.plat),"four no-bot conveyor platforms")
	var b: Dictionary = belts[0]
	h.player=Vector2((b.row[0]+b.row[1])/2,b.row[2]);var x:float=h.player.x
	h.world_four.pre_motion(0.034,h)
	check(near(h.player.x,x+b.belt*34),"conveyor source px/ms conversion")
	h.load_source("4-4")
	var boats: Array = h.world_four.surfaces(h).filter(func(s):return s.has("bob"))
	check(boats.size()==23,"23 authored bobbing boats")
	b=boats[0];h.player=Vector2((b.row[0]+b.row[1])/2,b.row[2])
	var bot:Dictionary=h.combat.new_bot(h,h.player.x,b,"rush");bot.state="pop"
	h.world_four.pre_motion(0.034,h)
	check(near(h.player.y,b.row[2]) and near(bot.p.y,b.row[2]),"bobs carry player and popped bot by live identity")
	h.load_source("4-5")
	check(near(h.player.x,330) and near(h.world_four.deck.row[0],210),"far camera reset starts deck at source0")
	h.camera.x=100;h.world_four.pre_motion(0.016,h)
	check(near(h.player.x,430) and near(h.world_four.deck.row[0],310),"deck carries pre-motion using previous camera")
	h.player.y=h.world_four.cfg.water+21;h.invincible=10;h.world_four.pre_motion(0.016,h)
	check(h.hearts==2 and h.grounded and h.velocity==Vector2.ZERO,"water rescue resets inv then hurts and zeroes velocity")
	h.load_source("4-2")
	check(h.level.receipts[0][0]==-300 and h.world_four.receipt_position(h,0)==Vector2(60,482),"documented receipt repair leaves original metadata intact")
func _foes(h) -> void:
	h.load_source("4-1")
	var f:Dictionary=h.world_four.foes.entries[0]
	h.player=Vector2(f.x-300,f.y)
	var s:=shot(f.x,f.y-40,99)
	check(h.world_four.intercept_shot(s,f.x-100,h) and f.hp==1 and not f.dead,"case takes fixed1 despite damage99")
	s=shot(f.x,f.y-40)
	check(h.world_four.intercept_shot(s,f.x-100,h) and f.dead and h.enemies.size()==1,"second case shot opens live ordinary bot")
	check(h.enemies[0].entered and h.enemies[0].surface.row[2]==f.y,"case bot keeps live surface")
	h.load_source("4-1");h.world_four.foes.entries.clear()
	h.world_four.foes.start_set(h,h.world_four,{"kind":"chute","n":2,"gap":900})
	h.world_four.foes.tick(0.016,h,h.world_four)
	check(h.world_four.foes.entries.size()==2 and near(h.world_four.foes.entries[1].t,0.016),"new chute drop advances same live iteration")
	check(h.world_four.busy(h),"chute controller blocks even x0 outside screen")
	f=h.world_four.foes.entries[1];h.player=Vector2(f.x,f.fy);h.invincible=0
	h.world_four.foes.tick(1.084,h,h.world_four)
	check(f.state=="land" and h.hearts==2,"warned falling luggage damages only on landing")
	h.load_source("4-5");h.world_four.spawn_foe("r","banana",h)
	f=h.world_four.foes.entries[0];f.x=450;f.state="fight"
	for seat in f.seats:
		for i in 3:
			s=shot(f.x+seat.offset,f.y-70)
			check(h.world_four.intercept_shot(s,s.p.x-2,h),"independent banana seat shot")
	check(f.seats.all(func(t):return t.dead),"four three-HP seats independently defeated")
	h.world_four.foes.tick(0.016,h,h.world_four)
	check(f.state=="out" and not h.world_four.foes.pause_camera(true),"banana departure releases auto-camera")
	check(h.world_four.busy(h),"source banana remains busy until range exit")
	h.load_source("4-2");h.world_four.foes.entries.clear();h.world_four.spawn_foe("r","melon",h)
	check(h.world_four.foes.entries.size()==1 and not h.world_four.busy(h),"standalone melon does not block waves")
func _hold(h) -> void:
	h.load_source("4-3")
	for w in h.combat.waves:w.done=true
	h.camera.x=h.world_four.cfg.hold.cam;h.player=Vector2(h.camera.x+300,482)
	h.world_four.before_combat(0.016,h)
	check(h.world_four.hold.on and near(h.world_four.hold.left,149.984),"150second hold begins after approach waves")
	check(h.order==["picks","dash"],"picks and early dash before objective/foes")
	for t in h.world_four.hold.towels:t.gone=true
	h.world_four.hold.left=50;h.world_four.before_combat(0.1,h)
	check(h.world_four.hold.resets==1 and near(h.world_four.hold.left,89.9) and h.world_four.hold.towels.all(func(t):return not t.gone),"all towels lost resets and adds40 capped seconds")
	h.world_four.foes.entries.clear();h.world_four.spawn_foe("r","grab",h)
	var f:Dictionary=h.world_four.foes.entries[-1];var towel:Dictionary=h.world_four.hold.towels[0]
	f.target=towel;f.x=towel.x;h.world_four.foes.tick(0.016,h,h.world_four)
	check(is_same(towel.held,f) and is_same(f.carry,towel),"grabber owns physical towel")
	var s:=shot(f.x,f.y-60,3);h.world_four.intercept_shot(s,f.x-2,h)
	check(f.dead and towel.held==null and near(towel.back,0.6) and not towel.gone,"shot saves carried towel")
	h.world_four.hold.left=0.01;h.world_four.hold.towels[0].gone=true
	h.world_four.before_combat(0.02,h)
	check(h.world_four.hold.over and h.world_four.hold.reward==30 and h.score==30,"timeout awards kitty10 per towel once")
	h.world_four.before_combat(0.02,h)
	check(h.score==30,"towel reward idempotent")
func _bonus(h) -> void:
	h.load_source("4-S")
	check(h.world_four.dash.left==100 and h.world_four.dash.gates.size()==8,"bonus100second eightgate config")
	check(h.coins.size()==h.world_four.cfg.dash.coins.size() and h.coins[0].age==0.4,"bonus postreset keep coin seeding")
	h.player.x=h.world_four.dash.gates[0].x+1;h.world_four.before_combat(0.016,h)
	check(h.world_four.dash.mult==2 and near(h.world_four.dash.left,107.984),"gate adds8seconds and multiplier")
	h.player.x=300;h.world_four.dash.left=0.01;h.world_four.before_combat(0.02,h)
	check(h.world_four.dash.over and h.world_four.dash.bonus==0 and h.world_four.done(h),"timeout clears regardless waves with0bonus")
	h.load_source("4-S");h.player.x=h.level.w-159;h.world_four.before_combat(0.1,h)
	check(h.world_four.dash.over and h.world_four.dash.mult==9 and h.world_four.dash.bonus==1476,"finish collects crossed gates and rounded time9x")
func _gates(h) -> void:
	h.load_source("4-1")
	var gate:Dictionary=h.world_four.gates[0]
	h.player.x=gate.x-149;h.world_four.foes.entries.clear()
	for w in h.combat.waves:w.done=true
	check(h.world_four.camera_step(0.016,h) and gate.busy,"normal gate starts guarded wipe")
	check(h.world_four.wipe_focus_start==Vector2(748.8,324),"source wipefocus zoomandclamp")
	h.hearts=1;h.coins.append({"p":Vector2(9000,400),"v":Vector2.ZERO,"age":1.0,"rest":true})
	h.world_four.before_combat(1.42,h);h.world_four.finish_frame(h)
	check(not gate.passed,"gate no early midpoint")
	h.world_four.before_combat(0.02,h);h.world_four.finish_frame(h)
	check(gate.passed and near(h.camera.x,gate.to-60) and near(h.player.x,gate.to+140) and h.hearts==3,"gate midpoint relocation/heal")
	check(h.coins.size()==1 and h.world_four.checkpoint_done,"gate preservescoins and flagscheckpoint")
	h.load_source("4-4");h.camera.x=h.world_four.gates[0].x-h.view_width()-4
	check(h.world_four.camera_step(0.016,h) and h.world_four.wiping,"auto gate triggersbeforeadvance")
	var before:float=h.camera.x;h.mode="pause";h.world_four.before_combat(5,h);h.world_four.finish_frame(h)
	check(h.camera.x==before and h.world_four.wipe_elapsed==0,"pause freezeswipe callback")
	h.mode="play";h.world_four.invalidate_run();h.world_four.finish_frame(h)
	check(h.camera.x==before,"invalidated generation cannot relocate")
func _waves(h) -> void:
	h.load_source("4-1",2)
	for i in h.combat.waves.size():check(h.combat.waves[i].group==h.level.waves[i].g+h.level.waves[i].get("x2",[]),"co-op appends x2 without sorting")
	h.combat.waves=[{"at":0,"group":[],"started":false,"done":false,"t":0.0,"index":0}]
	h.world_four.foes.entries.clear();h.world_four.foes._add({"kind":"case","x":300.0,"y":482.0,"hp":2,"h":70,"type":"rush"})
	h.combat.waves_tick(0.016,h)
	check(not h.combat.waves[0].done,"ordinary wave waits blockingfoes")
	h.world_four.foes.entries.clear();h.combat.waves_tick(0.016,h)
	check(h.combat.waves[0].done,"wave completesafterblockerremoval")
	h.load_source("4-4");h.combat.waves=[{"at":0,"group":[],"started":false,"done":false,"t":0.0,"index":0}]
	h.world_four.spawn_foe("r","jet",h);h.combat.waves_tick(0.016,h)
	check(h.combat.waves[0].done,"auto wave ignores survivingfoes")

func _cleanup(h) -> void:
	h.load_source("4-3")
	h.camera.x=h.world_four.cfg.hold.cam
	h.world_four.spawn_foe("r","grab",h)
	var grab:Dictionary=h.world_four.foes.entries[0]
	var towel:Dictionary=h.world_four.hold.towels[0]
	grab.carry=towel;grab.target=towel;towel.held=grab
	h.world_four.invalidate_run()
	check(towel.held==null and grab.carry==null and grab.target==null and h.world_four.foes.entries.is_empty(),"invalidaterun breaks RefCounted carrier/towel cycle")
	h.load_source("4-3");h.camera.x=h.world_four.cfg.hold.cam;h.world_four.spawn_foe("r","grab",h)
	grab=h.world_four.foes.entries[0];towel=h.world_four.hold.towels[0]
	grab.carry=towel;grab.target=towel;towel.held=grab
	h.world_four.foes.keep_controllers()
	check(towel.held==null and grab.carry==null,"gatediscard breaks carrier ownership")
	h.load_source("4-6");h.events.clear();h.world_four.captain.start(h);h.world_four.boss_tick(0.016,h)
	check(h.events.size()==1 and h.events[0].get("music",false),"Captain start presentation event deliveredonce")
	h.world_four.boss_tick(0.016,h)
	check(h.events.size()==1,"Captain presentation event not duplicated")
