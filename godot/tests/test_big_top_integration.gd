extends SceneTree
## Actual main host, explicit isolation fixtures, NOT whole-stage routes.
const SaveStore = preload("res://src/save_store.gd")
const AudioLog = preload("res://tests/test_festival_integration.gd").AudioLog
class ProbeHost extends "res://src/main.gd":
	var save_calls := 0
	func _save_progress() -> void:
		save_calls += 1; super._save_progress()
class ProbePainter extends "res://src/festival_big_top_renderer.gd":
	var calls: Array = []
	func draw_crate(host, crate: Dictionary) -> void:
		calls.append("crate"); super.draw_crate(host,crate)
	func draw_player_back(host, player = null) -> void:
		calls.append("player"); super.draw_player_back(host,player)
	func draw_level(host, runtime = null) -> void:
		calls.append("level"); super.draw_level(host, runtime)
	func draw_mid(host, runtime = null, pickups: Callable = Callable()) -> void:
		calls.append("mid"); super.draw_mid(host, runtime, pickups)
	func draw_front(host, runtime = null) -> void:
		calls.append("front"); super.draw_front(host, runtime)
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func near(a: float, b: float) -> bool: return absf(a-b) < 0.002
func fresh(who: String = "jp") -> void:
	game.character = who
	game.save = {"schema": 1, "receipts": {}, "skills": [], "kitty": 13}
	game.load_level("3-4")
	for wave in game.combat.waves: wave.at = INF
	game.step(0, {}); game.coins.clear(); game.audio.clear_log()
func stand(point: Vector2, camera: Vector2) -> void:
	game.player = point; game.camera = camera; game.camera_speed = 0
	game.velocity = Vector2.ZERO; game.grounded = true; game.on_platform = false
	game.invincible = 999; game.hurt_lock = 0; game.jump_held = false; game.drop_time = 0
	game._last_floor = point.y; game.world_three._standing_surface = {}
func shot(point: Vector2, damage: int = 1, ghost: bool = false) -> Dictionary:
	return {"p":point,"v":Vector2.ZERO,"life":20.0,"enemy":false,"damage":damage,"ghost":ghost,"ghost_age":0.0}
func bot(point: Vector2) -> Dictionary:
	var surface := {"row":[point.x-500,point.x+500,point.y],"plat":true}
	return game.combat.new_bot(game,point.x,surface,"throw",{"entered":true,"speed":0.0,"cd":100.0,"hp":20,"dz":0.0})
func lamp_fixture() -> Dictionary:
	fresh(); stand(Vector2(2600,-280),Vector2(2400,-700))
	return game.world_three.big_top.spots[0]
func run() -> void:
	game = load("res://main.tscn").instantiate(); game.set_script(ProbeHost); root.add_child(game); game.set_physics_process(false)
	game.audio.shutdown(); game.audio.queue_free(); game.audio = AudioLog.new()
	test_movers(); test_spots(); test_precedence(); test_dazzle(); test_late_ghost(); test_beam_boundaries(); test_cards_and_checkpoint(); test_lifecycle()
	await test_draw()
	game.queue_free(); await process_frame
	print("Big top integration: ", checks, " checks; ", failures.size(), " failures (explicit actual-main fixtures)")
	quit(0 if failures.is_empty() else 1)
func test_movers() -> void:
	for who in game.CHARACTERS:
		fresh(who)
		check(game._native_world_three() and game.scene_runtime == game.world_three and game.festival_renderer == game.festival_big_top_renderer,who+" selects native Big top")
		var original := JSON.stringify(game.meta)
		var q: Dictionary = game.world_three.big_top.movers[0].q
		var rows: Array = game.world_three.surfaces(game)
		check(is_same(q,rows[25]) and is_same(q.row,rows[25].row) and q.nospawn,"Trapeze live dictionary/row and nospawn survive")
		stand(Vector2(q.row[0]+65,q.row[2]),Vector2(q.row[0]-200,-650)); game.on_platform=true
		game.world_three._standing_surface=q
		var p: Vector2 = game.player
		var enemy: Dictionary = game.combat.new_bot(game,p.x,q,"throw",{"entered":true,"speed":0.0,"cd":100.0,"dz":1.0})
		game.step(0.01,{})
		check(near(game.player.x,p.x) and near(game.player.y,p.y),who+" player does not receive future late mover delta")
		check(near(enemy.p.x,p.x+q.dx) and near(enemy.p.y,q.row[2]) and is_same(enemy.surface,q),who+" late bot carry uses same moved surface")
		var dx: float=q.dx; var dy: float=q.dy
		game.step(0.01,{})
		check(near(game.player.x,p.x+dx) and near(game.player.y,p.y+dy),who+" next player pass consumes previous delta")
		check(near(game.skill_floor_below(q.row[0]+65,q.row[2]-50),q.row[2]) and near(game.ability_land_on(q.row[0]+65,q.row[2]-1,q.row[2]+1),q.row[2]),"Skill and ability landing see current live mover")
		stand(Vector2(q.row[0]+65,q.row[2]),Vector2(q.row[0]-200,-650)); game.on_platform=true
		game.step(0,{"jump":true})
		check(not game.grounded and game.velocity.y<0,who+" ordinary jump from trapeze")
		stand(Vector2(q.row[0]+65,q.row[2]),Vector2(q.row[0]-200,-650)); game.on_platform=true
		game.step(0,{"jump":true,"down":true})
		check(not game.grounded and game.drop_time>0,who+" ordinary drop through trapeze")
		check(JSON.stringify(game.meta)==original,"Mover/query fixtures leave imported META untouched")
	fresh()
	var solid: Dictionary=game.world_three.surfaces(game,true)[1]
	var x: float=solid.row[0]; var y: float=solid.row[2]+30
	check(game.ability_inside_wall(Vector2(x+1,y)),"Ability wall query uses runtime solid")
	check(near(game._wall_clamp(x-30,x+20,y),game.skill_wall_clamp(x-30,x+20,y)),"Normal and skill wall clamps agree")
func test_spots() -> void:
	for ghost in [false,true]:
		var s: Dictionary=lamp_fixture(); var pos:=Vector2(s.x,s.y+4)
		game.bullets.append(shot(pos,99,ghost)); game.step(0,{})
		check(s.hp==1 and not s.on,"Multiplier/ghost first shot costs exactly one HP")
		game.bullets.append(shot(pos,99,ghost)); game.bullets.append(shot(pos,99,ghost)); game.step(0,{})
		check(s.hp==-1 and s.on and game.bullets.all(func(b):return b.get("dead",false)),"Activation frame consumes excess shot without early break")
		check(game.audio.effects.count("power")==2,"Each activation-frame excess hit emits source power event")
		game.bullets.append(shot(pos)); game.step(0,{})
		check(s.hp==-1 and game.bullets.size()==1,"Already-on switch bypasses subsequent shots")
	for delta in [Vector2(26,0),Vector2(-26,0),Vector2(0,26),Vector2(0,-26)]:
		var s: Dictionary=lamp_fixture(); game.bullets.append(shot(Vector2(s.x,s.y+4)+delta)); game.step(0,{})
		check(s.hp==2,"Strict switch rectangle boundary "+str(delta))
func test_precedence() -> void:
	for ghost in [false,true]:
		for kind in ["bot","boss","crate","wall","camera"]:
			var s: Dictionary=lamp_fixture(); var pos:=Vector2(s.x,s.y+4)
			match kind:
				"bot": bot(pos+Vector2(0,50))
				"boss":
					game.combat.start_boss(game,game.meta.l3.mini)
					game.boss.state.state="walk"; game.boss.state.x=pos.x; game.boss.state.fy=pos.y+100; game.boss.state.next=100
				"crate": game.crates.append({"p":pos+Vector2(0,35),"hp":3,"broken":false,"hit":0.0,"give":"heart"})
				"wall":
					# Put lamp at an authored solid interior, no production geometry edit.
					var q: Dictionary=game.world_three.surfaces(game,true)[0]
					pos=Vector2(q.row[0]+100,q.row[2]+10); s.x=pos.x; s.y=pos.y-4
					stand(pos-Vector2(0,100),Vector2(pos.x-200,pos.y-300))
				"camera": game.camera.y=0
			game.bullets.append(shot(pos,1,ghost)); game.step(0,{})
			check(s.hp==2 and game.bullets.is_empty(),kind+" consumes/culls before lamp; ghost="+str(ghost))
func test_dazzle() -> void:
	var s: Dictionary=lamp_fixture(); s.t=0
	var b: Dictionary=bot(Vector2(s.x,s.y+200))
	game.bullets.append(shot(b.p-Vector2(0,60)))
	game.bullets.append(shot(Vector2(s.x,s.y+4))); game.bullets.append(shot(Vector2(s.x,s.y+4)))
	game.step(0,{})
	check(b.hp==19 and b.dz==0.25 and s.on,"Activation late dazzle cannot double earlier ordinary hit")
	game.bullets.append(shot(b.p-Vector2(0,60))); game.step(0.01,{})
	check(b.hp==17 and b.dz==0.25,"Next frame dazzle doubles ordinary damage and refreshes 250ms")
	s.on=false; b.dz=0.01; game.bullets.append(shot(b.p-Vector2(0,60))); game.step(0.01,{})
	check(b.hp==16 and near(b.dz,0),"Exact dazzle expiration before shots removes double damage")
func test_cards_and_checkpoint() -> void:
	for who in game.CHARACTERS:
		fresh(who); stand(Vector2(5600,200),Vector2(5300,-300)); game.hearts=1
		game.step(0,{}); check(not game.world_three.checkpoint_done,"Checkpoint strict x boundary")
		game.player.x+=0.01; var y: float=game.player.y; game.step(0,{})
		check(game.hearts==3 and game.world_three.checkpoint_done and game.player.y==y,who+" checkpoint heals without teleporting to flag y")
		stand(Vector2(5700,-300),Vector2(5400,-700)); game.step(0,{})
		check(game.movement_skills.card_collected and SaveStore.read_save().skills==["ground-pound"],who+" real card pickup persists")
		game.save=SaveStore.read_save(); game.load_level("3-4")
		for wave in game.combat.waves: wave.at=INF
		stand(Vector2(300,100),Vector2.ZERO); game.grounded=false
		game.step(0,{"down":true})
		check(game.movement_skills.ground_pounding and game.velocity.y==1400,who+" reload uses earned pound without injecting skill")
func test_lifecycle() -> void:
	fresh(); stand(Vector2(8300,100),Vector2(8040,0)); game.step(0,{})
	check(game.boss!=null and game.boss.state.max==60 and game.boss.state.fy==482 and game.boss.state.kind=="tout","Real late trigger starts 60HP ground Ringmaster")
	game.boss.state.state="down"; game.boss.state.t=1.8; game.step(0,{})
	check(game.boss!=null,"Mini down celebration exact boundary still blocks")
	game.step(0.001,{}); check(game.boss==null and game.world_three.mini_done,"Mini dismisses after strict down boundary")
	var state: Dictionary=game.world_three.snapshot()
	game._pause(); game.step(9,{}); check(game.world_three.snapshot()==state,"Pause freezes mover/spot clocks")
	game._resume(); game._game_over(); game._continue_level()
	check(game.world_three.snapshot()==state and game.mode=="play","Continue retains live runtime")
	game.load_level("3-4"); check(not game.world_three.mini_done and game.world_three.big_top.spots.all(func(s):return not s.on and s.hp==2),"Fresh load resets mini and lamps")
	fresh(); game.score=7; game.save_calls=0
	for wave in game.combat.waves: wave.done=true; wave.started=true; wave.index=wave.group.size()
	stand(Vector2(game.level.w-300,482),Vector2(game.level.w-game.view_width()-2,0))
	game.world_three.end_time=2.6 # Explicit endpoint/timer fixture, not route completion.
	game.step(0.01,{})
	check(game.mode=="clear" and not game.world_three.mini_done and not game.movement_skills.card_collected,"Ground endpoint clear has no altitude, card or miniDone gate")
	check(SaveStore.read_save().cleared.get("3-4",false) and SaveStore.read_save().kitty==20,"Actual clear persists stage and one score settlement")
	game._complete_level(); game.step(1,{})
	check(SaveStore.read_save().kitty==20 and game.save_calls==1,"Repeated completion cannot award score or save twice")
	game._return_to_map(); check(game.mode=="menu","Return to campaign map works")
func test_draw() -> void:
	fresh(); stand(Vector2(5500,-300),Vector2(5350,-700))
	var painter:=ProbePainter.new(); game.festival_renderer=painter
	var state:=JSON.stringify(game.world_three.snapshot()); var rng_state: int=game.world_three.rng.state
	game.queue_redraw(); await process_frame; await process_frame
	check(painter.calls.has("level") and painter.calls.has("mid") and painter.calls.has("front"),"Actual CanvasItem draw executes Big top painter wrappers")
	var composite: Array=painter.build_level(game,game.world_three)+painter.build_mid(game,game.world_three)
	check(composite.filter(func(c):return c.tag=="big_top_skill_card").size()==1,"Contiguous level and finds phases draw exactly one source card")
	check(painter.calls.find("level")<painter.calls.find("mid") and painter.calls.find("mid")<painter.calls.find("crate") and painter.calls.find("crate")<painter.calls.find("player"),"Actual source-equivalent level/finds/crates/player draw order")
	check(JSON.stringify(game.world_three.snapshot())==state and game.world_three.rng.state==rng_state,"Actual draw is simulation/RNG read-only")
	game.player=Vector2(5700,-300); game.step(0,{})
	composite=painter.build_level(game,game.world_three)+painter.build_mid(game,game.world_three)
	check(not composite.any(func(c):return c.tag=="big_top_skill_card"),"Real collected card disappears from composite draw plan")

func test_late_ghost() -> void:
	var s: Dictionary=lamp_fixture()
	game.abilities.effects.append({"kind":"ball","p":Vector2(s.x,s.y+4),"v":Vector2.ZERO,"age":0.0,"life":5.0,"spin":0.0,"free":0.0,"boss_next":100.0,"floor":482.0,"trail":[]})
	game.step(0,{})
	check(s.hp==2 and game.bullets.size()==1 and game.bullets[0].ghost,"Actual late Theo effect creates ghost after lamp phase")
	game.step(0,{})
	check(s.hp==1,"Late-born ghost reaches switch on following frame only")
func test_beam_boundaries() -> void:
	for angle in [0.1999,0.2001,-0.1999,-0.2001]:
		var s: Dictionary=lamp_fixture(); s.on=true; s.t=-0.01
		var b: Dictionary=bot(Vector2(s.x+tan(angle)*400,s.y+460))
		game.step(0.01,{})
		check((b.dz>0)==(absf(angle)<0.2),"Late beam strict angle near edge "+str(angle))
	var s: Dictionary=lamp_fixture(); s.on=true; s.t=0
	var b: Dictionary=bot(Vector2(s.x,s.y+60))
	game.step(0,{})
	check(b.dz==0,"Beam excludes dy zero")
	b.p.y+=0.01; game.step(0,{})
	check(b.dz==0.25,"Beam admits positive dy immediately")
