extends SceneTree
const Feedback=preload("res://src/visual_feedback.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func run()->void:
	var fx=Feedback.new();var p:=Vector2(120,160)
	fx.puff(p,Color.WHITE,8,250)
	check(fx.particles.size()==8,"source puff count")
	for q in fx.particles:
		check(q.p==p and q.age==0,"puff begins at exact event position")
		check(q.life>=.38 and q.life<=.58 and q.size>=4 and q.size<=8,"source puff lifetime and size")
		check(absf(q.v.x)<=250 and q.v.y>=-300 and q.v.y<=200 and q.gravity==0,"source independent-axis puff velocity")
	var before=var_to_str(fx.particles);var state=fx.rng.state
	var a:Array=fx.build_commands(Vector2(20.4,-31.6));var b:Array=fx.build_commands(Vector2(20.4,-31.6))
	check(var_to_str(a)==var_to_str(b) and fx.rng.state==state and var_to_str(fx.particles)==before,"drawing neither samples RNG nor mutates particles")
	check(a[0].rect.position==Vector2(120.4,160.4),"source camera and world pixel snapping")
	fx.tick(.1);check(is_equal_approx(fx.particles[0].age,.1),"time advances only explicit tick")
	check(is_equal_approx(fx.build_commands(Vector2.ZERO)[0].colour.a,1-.1/fx.particles[0].life),"particle alpha fades across lifetime")
	fx.tick(1);check(fx.particles.is_empty(),"expired puff removed")
	fx.bits(p);check(fx.particles.size()==10,"source ten cardboard bits")
	for q in fx.particles:
		check(q.life==.9 and q.gravity==1800 and q.size>=5 and q.size<=10,"source bits lifetime gravity and size")
		check(q.v.x>=-300 and q.v.x<=300 and q.v.y>=-900 and q.v.y<=-400,"source bits velocities")
		check(q.colour in [Color("b07a3a"),Color("d9a560")],"source cardboard palette")
	var velocity:Vector2=fx.particles[0].v
	fx.tick(.1);check(is_equal_approx(fx.particles[0].v.y,velocity.y+180),"semi-implicit source gravity step")
	fx.reset();fx.burst(p,Color("ff8fc7"));check(fx.particles.size()==16,"ability activation sixteen-particle burst")
	for q in fx.particles:check(q.gravity==600 and q.life>=.42 and q.life<=.68 and q.colour==Color("ff8fc7"),"source ability burst contract")
	fx.reset();fx.coin_pickup(p);check(fx.particles[0].v==Vector2(0,-80) and fx.particles[0].size==6 and fx.particles[0].life==.3,"source single pickup sparkle")
	fx.add_float("Crew!",p,Color("ffb3b3"));fx.tick(.5)
	var texts:Array=fx.build_commands(Vector2.ZERO).filter(func(c):return c.type=="text")
	check(texts[0].position==p-Vector2(0,20) and texts[0].size==16 and texts[0].colour==Color("ffb3b3"),"source floats rise40px persecond")
	fx.tick(.8);check(fx.floats.is_empty(),"source floats expire1300ms")
	fx.shake_screen(16);fx.shake_screen(6);check(fx.shake==16,"shake retains maximum request")
	fx.tick(.1);check(fx.shake==13 and absf(fx.offset.x)<=7 and absf(fx.offset.y)<=7,"source30px persecond shake decay")
	fx.reduced_motion=true;fx.tick(.01);fx.shake_screen(20)
	check(fx.shake==0 and fx.offset==Vector2.ZERO,"reduced motion suppresses shake")
	fx.reset();check(fx.particles.is_empty() and fx.floats.is_empty() and fx.offset==Vector2.ZERO,"new stage clears cosmetics")
	fx.reduced_motion=false;fx.puff(p,Color.WHITE);before=var_to_str(fx.particles);fx.reset();fx.puff(p,Color.WHITE)
	check(before==var_to_str(fx.particles),"isolated seeded cosmetic RNG reproducible")
	var simulation:=RandomNumberGenerator.new();simulation.seed=4521;state=simulation.state
	fx.bits(p);fx.burst(p,Color.WHITE);fx.shake_screen(8);fx.tick(.1);fx.build_commands(Vector2.ZERO)
	check(simulation.state==state,"cosmetics never consume gameplay RNG")
	if failures.is_empty():print("Visual feedback: %d checks passed."%checks);quit(0)
	else:printerr("Visual feedback failures: %d/%d"%[failures.size(),checks]);quit(1)
