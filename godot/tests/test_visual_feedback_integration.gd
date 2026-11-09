extends SceneTree
const Support=preload("res://tests/test_support.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func run()->void:
	var game=load("res://src/main.gd").new();root.add_child(game);await process_frame
	Support.silence(game);game.set_physics_process(false)
	for id in ["1-1","2-1","3-1","4-1","5-1","6-1"]:
		game.load_level(id,false)
		var fx=game.visual_feedback
		check(fx.particles.is_empty() and fx.floats.is_empty() and fx.shake==0,"%s fresh stage clears cosmetics"%id)
		var random_before=game.combat.rng.state
		var crate={"p":Vector2(400,482),"hp":1,"broken":false,"hit":0.0,"give":"heart"}
		game.combat.hit_crate(game,crate,1)
		check(fx.particles.size()==10 and fx.particles[0].p==Vector2(400,442),"%s real crate callback exact cardboard position/count"%id)
		check(game.combat.rng.state==random_before,"%s crate cosmetic does not consume simulation RNG"%id)
		fx.reset()
		var enemy={"p":Vector2(400,482),"state":"walk","hp":1,"t":0.0,"gone":0.0,"kind":"walk"}
		game.combat.kill_enemy(game,enemy)
		check(fx.particles.size()==10 and fx.particles[0].p==Vector2(400,422) and fx.shake==3,"%s real death callback bits and shake"%id)
		var expected_rng=game.combat.rng.state
		game.combat.rng.state=random_before;fx.reset(2398)
		enemy={"p":Vector2(400,482),"state":"walk","hp":1,"t":0.0,"gone":0.0,"kind":"walk"}
		game.combat.kill_enemy(game,enemy)
		check(game.combat.rng.state==expected_rng,"%s alternate cosmetic seed leaves combat random sequence unchanged"%id)
		fx.reset();game.items.clear();game.coins.clear();game.player=Vector2(240,482)
		var coin={"p":Vector2(240,410),"v":Vector2.ZERO,"rest":true,"age":.5}
		game.coins.append(coin)
		if id=="1-1":game.combat._pickups(0,game)
		else:game.combat.pickups_tick(0,game)
		check(fx.particles.size()==1 and fx.particles[0].size==6 and fx.particles[0].v==Vector2(0,-80),"%s actual coin pickup has source sparkle"%id)
		fx.reset();game.items.append({"p":Vector2(240,456),"vy":0.0,"rest":true,"age":.5,"give":"heart"})
		if id=="1-1":game.combat._pickups(0,game)
		else:game.combat.pickups_tick(0,game)
		var texts:Array=game.world_six.floating if id=="6-1" else fx.floats
		check(texts.any(func(f):return f.text=="+1 heart"),"%s actual heart pickup source float"%id)
		if id=="6-1":check(fx.floats.is_empty(),"W6 floats owned solely by W6 runtime")
		fx.reset();game.invincible=0;game.hearts=3;game.abilities.active="";game.character="jp"
		game.hurt_player(game.player.x+30)
		check(fx.particles.size()==8 and fx.shake==6,"%s actual damage emits eight puffs and source shake"%id)
		game.load_level(id,false);fx=game.visual_feedback
		game.abilities.meter=1;game.abilities._start(game)
		check(fx.particles.size()==16 and fx.shake==5,"%s source ability activation burst/shake"%id)
		texts=game.world_six.floating if id=="6-1" else fx.floats
		check(texts.any(func(f):return f.text=="Coin rain!"),"%s source ability name float"%id)
	game.load_level("4-6",false);var fx=game.visual_feedback
	game.world_four.captain.boss={"x":500.0,"y":482.0,"face":-1,"hp":60}
	var hp=game.world_four.captain.boss.hp;var coins=game.coins.size();var score=game.score;var rng=game.combat.rng.state
	game.holiday_event({"type":"hit","p":Vector2(560,360),"valve":true})
	check(fx.particles.size()==9,"Captain valve source five pink plus four white particles")
	check(fx.particles.filter(func(q):return q.colour==Color("ffd2e6") and q.p==Vector2(570,362)).size()==5,"Captain valve exact colour/position")
	game.holiday_event({"type":"text","p":Vector2(500,152),"text":"Crew!"})
	game.holiday_event({"type":"text","p":Vector2(500,162),"text":"Pssssssss..."})
	game.holiday_event({"type":"bits","p":Vector2(500,282)})
	game.holiday_event({"type":"shake","amount":16})
	check(fx.floats.size()==2 and fx.floats[0].colour==Color("ffb3b3") and fx.floats[1].colour==Color("ffd2e6"),"Captain exact reinforcement and defeat floats")
	check(fx.particles.size()==19 and fx.shake==16,"Captain defeat fragments and shake")
	check(game.world_four.captain.boss.hp==hp and game.coins.size()==coins and game.score==score and game.combat.rng.state==rng,"Captain presentation does not duplicate simulation/rewards/RNG")
	game.load_level("1-1",false);fx=game.visual_feedback;game.fx_puff(game.player,Color.WHITE)
	game._pause();game.step(.2,{})
	check(fx.particles[0].age==0,"pause freezes feedback")
	game._resume();game.step(.02,{})
	check(is_equal_approx(fx.particles[0].age,.02),"one update ages feedback once")
	game.load_level("3-3",false);game.visual_feedback.offset=Vector2(3,-2);game.festival_night_front.refresh(game.world_three)
	check(game.festival_night_front.transform.origin==Vector2(-game.camera.x*1.3,540*(1-1.3)-game.camera.y*1.3)+Vector2(3,-2),"night foreground shares world shake transform")
	check(game.position==Vector2.ZERO and game.ui.position==Vector2.ZERO,"world shake never moves native HUD/touch UI")
	game.queue_free();await process_frame
	if failures.is_empty():print("Visual feedback integration: %d checks passed."%checks);quit(0)
	else:printerr("Visual feedback integration failures: %d/%d"%[failures.size(),checks]);quit(1)
