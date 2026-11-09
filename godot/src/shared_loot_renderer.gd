extends RefCounted
## W1/W2 original drawItem and coinIcon. Read-only seconds/world-coordinate
## adapter; no caches, random samples, clock advances or gameplay changes.
const HEART: Array[String] = [".XX.XX.","XXXXXXX","XXXXXXX",".XXXXX.","..XXX..","...X..."]
const GOLD := Color("f4c542")
static func source_round(value:float)->float:return floorf(value+.5)
static func _world(screen:Vector2,camera:Vector2)->Vector2:
	return screen+Vector2(camera.x,camera.y-source_round(camera.y))
static func crate_jitter(crate:Dictionary,visual_time:float)->float:
	if float(crate.get("hit",crate.get("hitT",0)))<=0:return 0.0
	if crate.has("visual_jitter"):return clampf(float(crate.visual_jitter),-2,2)
	# Source samples (random-.5)*4 while hitT>0. A read-only 60Hz cosmetic
	# hash preserves that +/-2px tremble without consuming gameplay RNG.
	var p:Vector2=crate.p
	var value:=sin(p.x*12.9898+p.y*78.233+floorf(visual_time*60)*37.719)*43758.5453
	return (value-floorf(value)-.5)*4
static func build_crate(crate:Dictionary,camera:Vector2,visual_time:float=0.0)->Array:
	if crate.get("broken",false):return []
	var p:Vector2=crate.p
	var origin:=_world(Vector2(source_round(p.x-camera.x)+crate_jitter(crate,visual_time),p.y-64),camera)
	var out:Array=[]
	for row in [[Rect2(-34,0,68,64),"7a5226"],[Rect2(-31,3,62,58),"c48a4a"],[Rect2(-31,26,62,6),"a8743c"],[Rect2(-28,6,24,4),"e0b070"],[Rect2(-14,10,28,28),"f5f1ea"]]:
		out.append({"type":"rect","rect":Rect2(origin+row[0].position,row[0].size),"colour":Color(row[1]),"tag":"loot_crate"})
	out.append({"type":"text","position":origin+Vector2(0,25),"text":"?","size":22,"colour":Color("2d6a4f"),"tag":"loot_crate_label"})
	return out
static func draw_crates(canvas,crates:Array,visual_time:float)->void:
	for crate in crates:draw_commands(canvas,build_crate(crate,canvas.camera,visual_time))
static func build_coin(coin:Dictionary,camera:Vector2)->Array:
	var time:=float(coin.get("age",coin.get("t",0)))
	if time>9 and int(floorf(time/.1))%2:return []
	var p:Vector2=coin.p
	var k:=1.3;var w:=float([12,9,4,9][posmod(int(floorf(time/.06)),4)])*k;var h:=12*k
	var rows:Array=[[Rect2(-w/2-k,-h/2-k,w+2*k,h+2*k),"7a5410"],[Rect2(-w/2,-h/2,w,h),"f4c542"]]
	if w>5*k:rows.append_array([[Rect2(-w/2+k,-h/2+k,2*k,5*k),"fff1a8"],[Rect2(-k,-3*k,2*k,6*k),"c99a1d"]])
	var out:Array=[]
	for row in rows:
		var point:=Vector2(source_round(p.x-camera.x+row[0].position.x),source_round(p.y+row[0].position.y))
		out.append({"type":"rect","rect":Rect2(_world(point,camera),Vector2(source_round(row[0].size.x),source_round(row[0].size.y))),"colour":Color(row[1]),"tag":"loot_coin"})
	return out
static func build_item(item:Dictionary,camera:Vector2)->Array:
	var time:=float(item.get("age",item.get("t",0)))
	if time>9 and int(floorf(time/.12))%2:return []
	var p:Vector2=item.p
	var origin:=_world(Vector2(source_round(p.x-camera.x),source_round(p.y+sin(time/.15)*3)),camera)
	var out:Array=[{"type":"circle","center":origin,"radius":24+sin(time/.12)*2,"colour":Color(1,1,1,.25),"tag":"loot_glow"}]
	if item.give=="heart":
		for row in HEART.size():
			for col in 7:
				if HEART[row][col]=="X":out.append({"type":"rect","rect":Rect2(origin+Vector2(-14+col*4,-10+row*4),Vector2(4,4)),"colour":Color("ffb3b3" if row==1 and col==1 else "e23b3b"),"tag":"loot_heart"})
	else:
		out.append({"type":"rounded","rect":Rect2(origin-Vector2(20,20),Vector2(40,40)),"radius":10.0,"colour":Color("2d6a4f" if item.give=="split" else "14243b"),"stroke":GOLD,"width":3.0,"tag":"loot_power"})
		out.append({"type":"text","position":origin+Vector2(0,1),"text":"x3" if item.give=="split" else "DD","size":15,"colour":GOLD,"tag":"loot_label"})
	return out
static func rounded_points(rect:Rect2,radius:float)->PackedVector2Array:
	var points:=PackedVector2Array()
	var centers:=[rect.position+Vector2(radius,radius),Vector2(rect.end.x-radius,rect.position.y+radius),rect.end-Vector2(radius,radius),Vector2(rect.position.x+radius,rect.end.y-radius)]
	for corner in 4:
		for i in 13:
			var angle:float=PI+corner*PI*.5+i*PI/24
			points.append(centers[corner]+Vector2(cos(angle),sin(angle))*radius)
	return points
static func draw_commands(canvas,commands:Array)->void:
	for c in commands:
		match c.type:
			"rect":canvas.draw_rect(c.rect,c.colour)
			"circle":canvas.draw_circle(c.center,c.radius,c.colour)
			"rounded":
				var points:=rounded_points(c.rect,c.radius)
				canvas.draw_colored_polygon(points,c.colour)
				points.append(points[0]);canvas.draw_polyline(points,c.stroke,c.width)
			"text":
				var font:Font=canvas.font
				var point:Vector2=c.position+Vector2(-font.get_string_size(c.text,HORIZONTAL_ALIGNMENT_LEFT,-1,c.size).x*.5,(font.get_ascent(c.size)-font.get_descent(c.size))*.5)
				canvas.draw_string(font,point,c.text,HORIZONTAL_ALIGNMENT_LEFT,-1,c.size,c.colour)
static func draw(canvas,coins:Array,items:Array)->void:
	for coin in coins:draw_commands(canvas,build_coin(coin,canvas.camera))
	for item in items:draw_commands(canvas,build_item(item,canvas.camera))
