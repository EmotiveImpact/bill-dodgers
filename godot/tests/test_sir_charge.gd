extends SceneTree
const Host=preload("res://tests/test_world_six_support.gd")
const Boss=preload("res://src/sir_charge.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func near(a:float,b:float,label:String)->void:check(absf(a-b)<0.001,label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var h:=Host.new();h.load_stage("6-6")
	var world=h.world_six
	for w in h.combat.waves:w.done=true
	h.camera.x=h.level.w-h.view_width();h.player=Vector2(h.camera.x+150,482)
	check(world.objective_tick(10,h)=="","boss stage never generic exit")
	world.world_tick(0,h)
	check(h.boss!=null,"Sir Charge spawns after approach waves")
	var b=h.boss;var s:Dictionary=b.state
	check(s.hp==110 and s.max==110 and s.x==5080,"correct actual boss not unused old thief")
	check(not b.hit(Vector2(s.x,300),99),"entry invulnerable")
	world.boss_tick(2,h)
	check(s.state=="fight","entry to fight")
	s.x=h.camera.x+500;s.at=0;s.next=1.8;s.act="walk";h.invincible=999
	world.boss_tick(1.8,h);check(s.act=="walk","ledger attack strict 1.8 threshold")
	world.boss_tick(0.001,h);check(s.act in ["slam","volley"],"ledger chooses attack")
	s.act="slam";s.at=0;s.pend=true
	world.boss_tick(0.48,h);check(s.waves.is_empty(),"slam strict 480ms")
	world.boss_tick(0.001,h);check(s.waves.size()==2 and s.waves[0].vx==-420,"slam emits both directions")
	s.x=4500
	check(not b.hit(Vector2(s.x+78,300)),"boss strict 78 x extent")
	check(not b.hit(Vector2(s.x,182)),"boss strict top")
	check(not b.hit(Vector2(s.x,472)),"boss strict bottom")
	s.hp=110;s.dizzy=0
	check(b.hit(Vector2(s.x,300),50) and s.hp==109,"boss bullet ignores supplied damage")
	s.dizzy=1;b.hit(Vector2(s.x,300),50);check(s.hp==107,"dizzy doubles bullet only")
	s.hp=72.6;s.dizzy=3;s.act="slam";s.at=0.4
	world.boss_tick(0,h)
	check(s.phase==2 and s.act=="float" and s.dizzy==0,"exact 66 percent enters fee storm and resets dizzy")
	check(world.fees.size()==1 and world.fees[0].warn==0.7,"fee warning 700ms")
	check(world.fliers.size()==1,"phase two mailer backup")
	world.boss_tick(0.5,h)
	near(s.yo,-180,"phase two ascent easing")
	near(s.fy,302,"native fy explicit alias for shared specials")
	var fee:Dictionary=world.fees[0];var original_y:float=fee.y
	world._fees_tick(0.699,h);near(fee.y,original_y,"fee no motion before warning")
	world._fees_tick(0.001,h);check(fee.y>original_y,"fee motion begins warning equality")
	s.at=9;s.dizzy=0;world.boss_tick(0,h);check(s.dizzy==0,"phase2 breath strict nine seconds")
	world.boss_tick(0.001,h);near(s.dizzy,2.8,"phase2 breath 2.8s")
	s.hp=36.3;s.dizzy=0;world.boss_tick(0,h)
	check(s.phase==3 and s.act=="wind","exact 33 percent phase3")
	check(world.fees.any(func(f):return f.kind=="rock"),"tower drops rocks")
	s.at=0;s.dizzy=0;world.boss_tick(0.7,h);check(s.act=="wind","wind strict .7")
	world.boss_tick(0.001,h);check(s.act=="charge" and absf(s.vx)==550,"charge 550px/s")
	s.x=h.camera.x+90;s.vx=-550;s.act="charge";s.dizzy=0
	var before:int=world.fees.size();world.boss_tick(0.01,h)
	check(s.act=="wind" and s.dizzy==1.9 and s.at==-0.3,"wall impact dizziness")
	check(world.fees.size()>=before+3,"wall impact three debris")
	h.coins.clear();s.hp=1;s.state="fight";s.yo=0;s.fy=482;s.dizzy=0
	b.hit(Vector2(s.x,300));b.flush_down(h,world)
	check(s.state=="down" and s.waves.is_empty() and world.fees.is_empty(),"boss death clears waves fees")
	check(h.coins.size()==24 and world.fliers.all(func(f):return f.state=="pop"),"boss death 24 coins and mailers pop")
	world.boss_tick(1.8,h);check(s.jar.is_empty(),"jar spawn strict 1.8")
	world.boss_tick(0.001,h);check(not s.jar.is_empty() and s.jar.t==0,"jar age starts at birth")
	h.player.x=s.jar.x
	check(world.jar_tick(0.6,h)=="","jar pickup strict actual age .6")
	# Keep x adjacent after physics drift; source pickup has no vertical requirement.
	s.jar.vx=0;h.player.x=s.jar.x;h.player.y=-999
	check(world.jar_tick(0.001,h)=="clear" and s.jar.got,"actual jar collect to clear")
	check(world.jar_tick(2,h)=="","jar clear event once")
	var duo=Boss.new();duo.reset(4900,h.view_width(),482,2)
	check(duo.state.hp==150,"multiplayer actual boss health150")
	print("Sir Charge: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
