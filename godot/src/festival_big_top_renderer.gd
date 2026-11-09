extends "res://src/festival_renderer.gd"
## Big top source painter. No simulation writes, RNG consumption or new blend passes.
var _smooth_textures: Dictionary = {}
func supports(id: String) -> bool: return id == "3-4"

func _festival_context(host) -> Dictionary:
	var c := super._festival_context(host)
	c.dims=host.meta.get("dims",{})
	return c

func _world_size(c: Dictionary,key: String) -> Vector2:
	if c.get("dims",{}).has(key): return Vector2(c.dims[key][0],c.dims[key][1])
	return super._world_size(c,key)

func build_sky(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _festival_context(host)
	var stops := [-10.0,0.0,297.0,540.0,550.0]
	var colours := [Color("3a0d14"),Color("3a0d14"),Color("5a1520"),Color("2a0a10"),Color("2a0a10")]
	for i in 4:
		out.append({"type":"gradient","rect":Rect2(c.camera.x-10,c.camera.y+stops[i],c.width+20,stops[i+1]-stops[i]),"colours":PackedColorArray([colours[i],colours[i],colours[i+1],colours[i+1]]),"tag":"big_top_sky"})
	var size := _world_size(c,"backdrop")
	if size == Vector2.ZERO: return out
	var y := source_round(float(c.ground)-4-size.y-float(c.camera.y)*0.3)
	if y > -10: _rect(out,Rect2(c.camera.x-10,c.camera.y-10,c.width+20,y+12),Color("2a0a10"),"big_top_ceiling")
	var x := -fposmod(float(c.camera.x)*0.16,size.x)
	while x < float(c.width):
		_texture(out,c,"backdrop",Rect2(c.camera.x+source_round(x),c.camera.y+y,size.x,size.y),"big_top_backdrop",Rect2(),false,{"smooth":true})
		x+=size.x
	var pole := _world_size(c,"pole")
	if pole == Vector2.ZERO: return out
	var off := float(c.camera.x)*0.55
	var bottom := source_round(float(c.ground)+6-float(c.camera.y)*0.55)
	var index := int(floorf((off-pole.x)/760))
	while index*760-off < float(c.width)+pole.x:
		x=source_round(index*760-off+180)+float(c.camera.x)
		_texture(out,c,"pole",Rect2(x,c.camera.y+bottom-pole.y,pole.x,pole.y),"big_top_pole",Rect2(),false,{"smooth":true,"brightness":0.82})
		var top := bottom-pole.y
		while top > -40:
			_texture(out,c,"pole",Rect2(x,c.camera.y+top-pole.y*0.4,pole.x,pole.y*0.4),"big_top_pole_extension",Rect2(0,_size(c,"pole").y*0.3,_size(c,"pole").x,_size(c,"pole").y*0.4),false,{"smooth":true,"brightness":0.82})
			top-=pole.y*0.4
		index+=1
	return out

func _decor_cut(out: Array,c: Dictionary,decor: Array) -> void:
	if decor[0]!="pole": super._decor_cut(out,c,decor); return
	var x := float(decor[1])
	if x-c.camera.x < -560 or x-c.camera.x > c.width+560: return
	var y := float(decor[2])+float(c.y_snap)
	_rect(out,Rect2(_x(c,x)-6,y-2000,12,2000+float(c.ground)-float(decor[2])+4),Color("d9dde4"),"big_top_decor_pole")
	_rect(out,Rect2(_x(c,x)+2,y-2000,4,2000+float(c.ground)-float(decor[2])+4),Color("9aa3b2"),"big_top_decor_pole_shade")

func _surface(out: Array,c: Dictionary,q: Dictionary) -> void:
	var row: Array=q.row
	var a := float(row[0])
	var b := float(row[1])
	if not _in_view(c,a,b): return
	var x := _x(c,a)
	var w := source_round(b-a)
	var y := float(row[2])+float(c.y_snap)
	var style := str(q.get("style",row[3].get("style","") if row.size()>3 else ""))
	var base := float(q.get("base",c.ground))+float(c.y_snap)
	match style:
		"truss","trapeze":
			_rect(out,Rect2(x,y,w,5),Color("f4c542") if style=="trapeze" else Color("c9ced8"),"big_top_"+style)
			if style=="trapeze": _rect(out,Rect2(x,y+4,w,3),Color("b08a1d"),"big_top_trapeze_edge")
			else:
				_rect(out,Rect2(x,y+22,w,4),Color("c9ced8"),"big_top_truss_bottom")
				var xx := a
				while xx < b-10:
					_line(out,Vector2(xx,y+4),Vector2(xx+11,y+23),Color("9aa3b2"),2,"big_top_truss_brace")
					_line(out,Vector2(xx+11,y+23),Vector2(xx+22,y+4),Color("9aa3b2"),2,"big_top_truss_brace")
					xx+=22
		"cases":
			while y < base:
				for part in [[Rect2(x,y,w,62),"1b1d24"],[Rect2(x+4,y+4,w-8,54),"2f333d"],[Rect2(x,y,10,10),"9aa3b2"],[Rect2(_x(c,b)-10,y,10,10),"9aa3b2"],[Rect2(x+20,y+28,w-40,4),"9aa3b2"]]: _rect(out,part[0],Color(part[1]),"big_top_cases")
				y+=64
		"bleach":
			_rect(out,Rect2(x,y,w,base-y),Color("5a1520"),"big_top_bleacher_base")
			var xx := a
			while xx < b-8:
				_rect(out,Rect2(_x(c,xx)+2,y-14,20,16),Color("c8283a"),"big_top_seat")
				_rect(out,Rect2(_x(c,xx)+2,y-14,20,4),Color("e04a5a"),"big_top_seat_highlight")
				xx+=26
			_rect(out,Rect2(x,y,w,4),Color("d9dde4"),"big_top_bleacher_top")
		"ring":
			var clip := Rect2(x,y-10,w,float(c.camera.y)+560-float(row[2])+10)
			_rect(out,clip,Color("1c0c14"),"big_top_ring_base")
			var size := _world_size(c,"bigfloor")
			if size==Vector2.ZERO: return
			var xx := floorf(a/size.x)*size.x
			while xx < b:
				var commands: Array=[]
				_texture(commands,c,"bigfloor",Rect2(_x(c,xx),y-10,size.x,size.y),"big_top_ring")
				for command in commands:
					var cropped := _clip_texture(command,clip)
					if not cropped.is_empty(): out.append(cropped)
				xx+=size.x
		_: super._surface(out,c,q)

func build_level(host,runtime = null) -> Array:
	var out := super.build_level(host,runtime)
	if not supports(host.level_id): return out
	var c := _festival_context(host)
	var spots = _state(runtime,"spots",_state(runtime,"stage_data",{}).get("spots",null))
	if not spots is Array:
		spots=[]
		for row in c.level.get("spots",[]): spots.append({"x":row[0],"y":row[1],"on":false,"t":0.0})
	for spot in spots: _spot(out,c,spot,float(_state(runtime,"elapsed",host.elapsed)))
	var surfaces := _surfaces(host,runtime)
	for mover in c.level.get("movers",[]):
		var index := int(mover[0])
		var row: Array=surfaces[c.level.solids.size()+index].row
		var anchor: Array=c.level.plats[index]
		for edge in [0,1]:
			var dx := 6 if edge==0 else -6
			_line(out,Vector2(float(row[edge])+dx,float(row[2])+float(c.y_snap)),Vector2(float(anchor[edge])+dx,c.view.position.y-20+float(c.y_snap)),Color("c9ced8"),2,"big_top_rope")
	return out

func _spot(out: Array,c: Dictionary,spot: Dictionary,elapsed: float) -> void:
	var x := float(spot.x)
	if x-c.camera.x < -400 or x-c.camera.x > c.width+400: return
	var y := float(spot.y)+float(c.y_snap)
	if spot.on:
		var angle := sin(float(spot.t)/0.9)*0.6
		_poly(out,[Vector2(x,y+12),Vector2(x+sin(angle-0.2)*760,y+cos(angle-0.2)*760),Vector2(x+sin(angle+0.2)*760,y+cos(angle+0.2)*760)],Color(1,240/255.0,170/255.0,0.18),"big_top_beam")
	_rect(out,Rect2(_x(c,x)-3,y-30,6,24),Color("2a2f3d"),"big_top_spot_stem")
	_border(out,Rect2(_x(c,x)-18,y-10,36,30),6,Color("3a404c"),Color("9aa3b2"),2,"big_top_spot_body")
	_rect(out,Rect2(_x(c,x)-12,y+10,24,8),Color("fff3b0") if spot.on else Color("5a6272"),"big_top_spot_lens")
	if not spot.on and int(floorf(elapsed/0.4))%2:
		out.append({"type":"text","position":Vector2(_x(c,x),y-40),"text":"Shoot","size":10,"colour":GOLD,"tag":"big_top_spot_hint"})

func draw_commands(host,commands: Array) -> void:
	for command in commands:
		if command.get("smooth",false):
			var original: Texture2D=host.images[command.key]
			var key := original.get_instance_id()
			if not _smooth_textures.has(key):
				var texture := CanvasTexture.new()
				texture.diffuse_texture=original
				texture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
				_smooth_textures[key]=texture
			var brightness := float(command.get("brightness",1.0))
			host.draw_texture_rect_region(_smooth_textures[key],command.rect,command.source,Color(brightness,brightness,brightness,1))
		else: super.draw_commands(host,[command])

func clear_cache() -> void:
	super.clear_cache()
	_smooth_textures.clear()

func build_finds(host,runtime = null) -> Array:
	var out := super.build_finds(host,runtime)
	if not supports(host.level_id): return out
	var skill: Array=host.level.get("skill",[])
	var collected := bool(_state(runtime,"skill_collected",_state(_state(host,"movement_skills",null),"card_collected",false)))
	if skill.is_empty() or collected: return out
	var c := _festival_context(host)
	var x := _x(c,float(skill[0]))
	if x-c.camera.x <= -60 or x-c.camera.x >= c.width+60: return out
	var y := source_round(float(skill[1])+sin(float(_state(runtime,"elapsed",host.elapsed))/0.18)*5)+float(c.y_snap)
	_ellipse(out,Vector2(x,y),Vector2(34,34),Color(244/255.0,197/255.0,66/255.0,0.35),"big_top_skill_glow")
	_border(out,Rect2(x-20,y-28,40,56),6,Color("14243b"),GOLD,3,"big_top_skill_card")
	_rect(out,Rect2(x-3,y-18,6,22),GOLD,"big_top_skill_arrow")
	_poly(out,[Vector2(x-11,y+2),Vector2(x+11,y+2),Vector2(x,y+16)],GOLD,"big_top_skill_arrowhead")
	_rect(out,Rect2(x-14,y+18,28,4),GOLD,"big_top_skill_floor")
	return out
