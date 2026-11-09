extends SceneTree
const Host=preload("res://tests/test_world_six_support.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var h=Host.new();var w=h.world_six;var c=h.combat
	h.load_stage("6-1")
	c.start_mini(h,"franker",{})
	check(h.banners.back()=={"text":"Warning!","sub":"The franking machine wants a word","warn":true},"source Franker warning")
	check(h.music_modes==[true],"mini boss music once")
	w.mini_boss.state="fight";w.mini_boss.hp=20;c.mini_tick(0,h)
	check(w.floating.back().text=="Backup!","mini first backup float")
	c.mini_down(h)
	check(w.floating.back().text=="Franking machine bust!","mini defeat float")
	check(h.music_modes==[true,false],"mini defeat restores world6 music")
	c.mini_down(h);check(h.music_modes.size()==2,"mini music transition exactly once")
	h.load_stage("6-3");c.start_mini(h,"jammer",{})
	check(h.banners.back().sub=="The jammer wants a word","source Jammer article")
	h.load_stage("6-1")
	for wave in c.waves:wave.done=true
	h.player.x=h.level.doors[0].x
	w._doors_tick(h);w._last_dt=1.43;w.finish_frame(h)
	check(h.banners.back().text=="Loading bay" and not h.banners.back().warn,"source door banner")
	check(h.go_durations==[1.8],"source door Go lasts1.8 seconds")
	h.load_stage("6-2")
	for wave in c.waves:wave.done=true
	h.camera.x=h.level.w-h.view_width();w._hold_tick(0,h)
	check(h.banners.back()=={"text":"Hold out!","sub":"Keep the robots off the lift until it comes","warn":true},"source hold warning")
	w.hold.t=90;w._hold_tick(0,h)
	check(w.floating.back().text=="Ding!" and w.floating.back().colour==Color("f4c542"),"source lift completion float")
	h.load_stage("6-S");w._dash_tick(111,h)
	check(h.banners.back()=={"text":"Time's up!","sub":"Coffee is going cold","warn":true},"source coffee timeout warning")
	h.load_stage("6-S");h.player.x=h.level.dash.finish;w.dash.left=12.2;w.objective_tick(0,h)
	check(w.floating.back().text=="+£13 time bonus","source bonus float")
	h.load_stage("6-6")
	for wave in c.waves:wave.done=true
	h.camera.x=h.level.w-h.view_width();w.world_tick(0,h)
	check(h.banners.back()=={"text":"Sir Charge","sub":"Top of the Bill-ding. Get the jar back.","warn":true},"actual final boss warning")
	check(h.music_modes==[true],"actual final boss music dispatch")
	w.world_tick(0,h);check(h.music_modes.size()==1,"final boss music dispatch once")
	h.boss.state.state="fight";h.boss.state.hp=70;h.boss.boss_tick(0,h,w)
	check(h.banners.back()=={"text":"Fee storm!","sub":"Watch the shadows. Shoot up and forward","warn":true},"source fee storm banner")
	h.boss.state.at=9.001;h.boss.boss_tick(0,h,w)
	check(w.floating.back().text=="Out of breath! Double damage","source breath float")
	h.boss.state.hp=30;h.boss.boss_tick(0,h,w)
	check(h.banners.back()=={"text":"The tower is shaking!","sub":"He charges. Let him hit the wall","warn":true},"source phase3 banner")
	h.boss.damage(100);h.boss.flush_down(h,w)
	check(h.banners.back()=={"text":"The ledger is smashed!","sub":"Everyone's money is going home","warn":false},"source boss defeat banner")
	print("World 6 presentation: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
