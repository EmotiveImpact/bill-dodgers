extends RefCounted
## Cosmetic state only. Its RNG is deliberately separate from combat/world RNG.
## Rendering is pure; particles, floats and shake advance only through tick().
var rng := RandomNumberGenerator.new()
var particles: Array[Dictionary] = []
var floats: Array[Dictionary] = []
var shake := 0.0
var offset := Vector2.ZERO
var reduced_motion := false

func _init() -> void: reset()

func reset(seed_value := 728451) -> void:
	rng.seed=seed_value
	particles.clear();floats.clear();shake=0;offset=Vector2.ZERO

func puff(position: Vector2, colour: Color, count := 6, speed := 250.0) -> void:
	for i in count:
		var angle:=rng.randf()*6.28
		particles.append({"p":position,"v":Vector2(cos(angle)*speed*rng.randf(),sin(angle)*speed*rng.randf()-50),"age":0.0,"life":.38+rng.randf()*.2,"colour":colour,"size":4+rng.randf()*4,"gravity":0.0})

func bits(position: Vector2) -> void:
	for i in 10:
		particles.append({"p":position,"v":Vector2((rng.randf()-.5)*600,-400-rng.randf()*500),"age":0.0,"life":.9,"colour":Color("b07a3a") if rng.randf()<.5 else Color("d9a560"),"size":5+rng.randf()*5,"gravity":1800.0})

func burst(position: Vector2, colour: Color, count := 16) -> void:
	for i in count:
		var angle:=rng.randf()*6.283
		var speed:=80+rng.randf()*220
		particles.append({"p":position,"v":Vector2(cos(angle)*speed,sin(angle)*speed-80),"age":0.0,"life":.42+rng.randf()*.26,"colour":colour,"size":4+rng.randf()*4,"gravity":600.0})

func coin_pickup(position: Vector2) -> void:
	particles.append({"p":position,"v":Vector2(0,-80),"age":0.0,"life":.3,"colour":Color("fff1a8"),"size":6.0,"gravity":0.0})

func add_float(text: String, position: Vector2, colour := Color("f4c542")) -> void:
	floats.append({"text":text,"p":position,"colour":colour,"age":0.0})

func shake_screen(amount: float) -> void:
	if not reduced_motion: shake=maxf(shake,amount)

func tick(delta: float) -> void:
	if delta<=0 or not is_finite(delta):return
	for q in particles:
		q.age+=delta;q.v.y+=q.gravity*delta;q.p+=q.v*delta
	particles=particles.filter(func(q):return q.age<q.life)
	for f in floats:f.age+=delta
	floats=floats.filter(func(f):return f.age<1.3)
	shake=maxf(0,shake-delta*30)
	if reduced_motion:shake=0
	offset=Vector2(floorf((rng.randf()-.5)*shake+.5),floorf((rng.randf()-.5)*shake+.5)) if shake>0 else Vector2.ZERO

func build_commands(camera: Vector2) -> Array:
	var out:Array=[]
	for q in particles:
		var point:=Vector2(floorf(q.p.x-camera.x+.5)+camera.x,floorf(q.p.y+.5)+camera.y-floorf(camera.y+.5))
		out.append({"type":"rect","rect":Rect2(point,Vector2.ONE*q.size),"colour":Color(q.colour,q.colour.a*maxf(0,1-q.age/q.life)),"tag":"feedback_particle"})
	for f in floats:
		out.append({"type":"text","position":f.p-Vector2(0,f.age*40),"text":f.text,"size":16,"colour":f.colour,"center":true,"outline":true,"tag":"feedback_float"})
	return out

func draw(canvas: CanvasItem, font: Font, camera: Vector2) -> void:
	for c in build_commands(camera):
		if c.type=="rect":canvas.draw_rect(c.rect,c.colour)
		elif c.type=="text":
			var point:Vector2=c.position+Vector2(-font.get_string_size(c.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x*.5,16*.36)
			canvas.draw_string_outline(font,point,c.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,4,Color("0e1726"))
			canvas.draw_string(font,point,c.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,c.colour)
