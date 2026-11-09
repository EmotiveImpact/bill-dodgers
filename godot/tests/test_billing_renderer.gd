extends SceneTree
const Host=preload("res://tests/test_world_six_support.gd")
const Renderer=preload("res://src/billing_renderer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func tagged(a:Array,tag:String)->Array:return a.filter(func(c):return c.tag==tag)
func _initialize()->void:call_deferred("run")
func run()->void:
	var h:=Host.new();var r=Renderer.new()
	for id in ["6-1","6-2","6-3","6-4","6-5","6-6","6-S"]:
		h.load_stage(id);h.load_images()
		check(r.supports(id),id+" renderer dispatch")
		var world=h.world_six
		var snapshot:Dictionary=world.snapshot()
		var commands:Array=[]
		for zone in h.level.get("zones",[{"x0":0,"art":h.level.art}]):
			h.camera.x=maxf(0,zone.x0+100)
			commands.append_array(r.build_sky(h,world))
			var level:Array=r.build_level(h,world)
			commands.append_array(level)
			if zone.art not in ["shaft","void"]:
				check(not tagged(level,"billing_wall").is_empty(),id+" original wall "+zone.art)
				for c in tagged(level,"billing_wall"):check(c.factor==1 and absf(c.source.size.x-c.rect.size.x)<0.001,id+" source wall native size/parallax")
		for s in world.surfaces(h):
			if s.art in ["floor","void"]:continue
			h.camera=Vector2(maxf(0,float(s.row[0])-200),minf(0,float(s.row[2])-450))
			var level:Array=r.build_level(h,world)
			commands.append_array(level)
			check(not level.is_empty(),id+" renders surface "+s.art)
		commands.append_array(r.build_mid(h,world));commands.append_array(r.build_finds(h,world));commands.append_array(r.build_front(h,world));commands.append_array(r.build_hud(h,world))
		check(world.snapshot()==snapshot,id+" renderer pure")
		check(not tagged(commands,"billing_receipts_hud").is_empty(),id+" receipt count hud")
		r.draw_commands(h,commands)
		check(not h.recorded.is_empty(),id+" draws all command variants")
		h.recorded.clear()
	h.load_stage("6-1");h.load_images();h.camera.x=1500
	var belt:Array=r.build_level(h,h.world_six)
	check(tagged(belt,"billing_belt_cap").size()==2,"conveyor three slice caps")
	check(not tagged(belt,"billing_belt_mid").is_empty(),"conveyor middle")
	check(not tagged(belt,"billing_belt_arrow").is_empty(),"conveyor direction warning")
	h.combat.start_mini(h,"franker");h.world_six.mini_boss.state="fight";h.world_six.mini_boss.x=1800
	h.combat.spawn_flier(h,"r");h.world_six.fliers[0].p=Vector2(1700,250)
	h.world_six.fees.append({"x":1700.0,"y":100.0,"t":0.5,"warn":0.7,"r":16.0,"kind":"fee"})
	h.recorded.clear();r.draw_mid(h,h.world_six)
	check(h.recorded.any(func(c):return c[0]=="texture"),"draw_mid actually submits mini and mailer")
	var mid:Array=r.build_mid(h,h.world_six)
	check(not tagged(mid,"billing_mini_franker").is_empty(),"original franker painting")
	check(not tagged(mid,"billing_mailer").is_empty(),"original mailer sprite")
	check(tagged(mid,"billing_mailer")[0].source.size==Vector2(173,129),"mailer unscaled source cells")
	check(not tagged(mid,"billing_fee_warning").is_empty() and tagged(mid,"billing_fee").is_empty(),"fee shadow precedes paper")
	h.load_stage("6-2");h.load_images();h.world_six.hold.on=true;h.world_six.hold.t=30
	var hud:Array=r.build_hud(h,h.world_six)
	check(tagged(hud,"billing_hold_hud_label")[0].text=="Lift arriving in 1:00","hold timer actual secs")
	h.load_stage("6-4");h.load_images();h.camera.y=-5600;h.player=Vector2(369,-5632)
	var shaft:Array=r.build_level(h,h.world_six)
	check(not tagged(shaft,"billing_shaft").is_empty(),"original shaft painting")
	check(not tagged(shaft,"billing_girder").is_empty(),"procedural girders")
	check(not tagged(r.build_hud(h,h.world_six),"billing_climb_hud_label").is_empty(),"climb floor HUD")
	check(not tagged(r.build_finds(h,h.world_six),"billing_skill_card").is_empty(),"super card art")
	h.load_stage("6-5");h.load_images();h.camera.x=4100;h.world_six.camera_override(0,h)
	var ride:Array=r.build_level(h,h.world_six)
	check(not tagged(ride,"billing_cradle").is_empty(),"procedural cradle rail and tools")
	check(not tagged(ride,"billing_box").is_empty(),"original AC hazard painting")
	check(not tagged(r.build_hud(h,h.world_six),"billing_ride_hud").is_empty(),"ride progress HUD")
	h.load_stage("6-6");h.load_images();h.camera.x=h.level.w-h.view_width()
	for w in h.combat.waves:w.done=true
	h.world_six.world_tick(0,h);h.boss.state.x=4500;h.boss.state.state="fight"
	var boss:Array=r.build_boss(h,h.world_six)
	check(tagged(boss,"sir_charge")[0].source.size==Vector2(468,310),"Sir Charge original sprite sheet")
	check(tagged(r.build_hud(h,h.world_six),"sir_charge_hud_label")[0].text=="Sir Charge","final boss HUD correct name")
	h.boss.state.act="float"
	check(tagged(r.build_boss(h),"sir_charge")[0].animation=="float","phase2 float animation")
	h.load_stage("6-S");h.load_images();h.world_six.dash.left=14.01
	hud=r.build_hud(h,h.world_six)
	check(tagged(hud,"billing_dash_hud_label")[0].text=="Coffee run: 15s","coffee ceil seconds HUD")
	h.world_six.dash.left=14
	check(tagged(r.build_hud(h,h.world_six),"billing_dash_hud_fill")[0].colour==Color("e23b3b"),"coffee urgent red")
	for kind in ["leaf","stamp","sheet","big"]:
		var bill:Dictionary={"p":Vector2(300,300),"age":0.2,kind:true}
		check(not r.build_bill(h,bill).is_empty(),kind+" authored projectile art")
		bill.delay=0.1;check(r.build_bill(h,bill).is_empty(),kind+" delayed invisible")
	h.load_stage("6-1")
	h.world_six.add_float("Backup!", Vector2(200,150), Color("ffb3b3"))
	h.world_six.effects_tick(0.5,h)
	var notices:Array=tagged(r.build_front(h,h.world_six),"billing_float")
	check(notices.size()==1 and notices[0].text=="Backup!", "source W6 floating text rendered")
	check(notices[0].position==Vector2(200,130) and notices[0].size==16 and notices[0].colour==Color("ffb3b3"), "source float position speed font and colour")
	check(h.world_six.floating[0].age==0.5, "float painter does not age simulation")
	print("Billing renderer: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
