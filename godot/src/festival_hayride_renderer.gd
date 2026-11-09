extends "res://src/festival_renderer.gd"
## Active 3-5 painted assets, pure seconds-based snapshots.
var _bright: Dictionary = {}
func supports(id: String) -> bool: return id == "3-5"
func _festival_context(host) -> Dictionary:
	var c := super._festival_context(host)
	c.dims = host.meta.get("dims", {})
	return c
func _world_size(c: Dictionary, key: String) -> Vector2:
	if c.get("dims", {}).has(key): return Vector2(c.dims[key][0], c.dims[key][1])
	return super._world_size(c, key)
func build_sky(host, runtime = null) -> Array:
	var out := super.build_sky(host, runtime)
	var palette := [Color("6aa8e8"), Color("6aa8e8"), Color("f5c6a0"), Color("ffd98a"), Color("ffd98a")]
	for i in mini(4, out.size()): out[i].colours = PackedColorArray([palette[i], palette[i], palette[i+1], palette[i+1]])
	return out
func _trailer(host, runtime) -> Array:
	return _surfaces(host, runtime)[host.level.solids.size() + int(host.meta.l3.trailer.plat)].row
func build_level(host, runtime = null) -> Array:
	var out := super.build_level(host, runtime)
	if not supports(host.level_id): return out
	var c := _festival_context(host)
	var q := _trailer(host, runtime)
	var time := float(_state(runtime, "elapsed", host.elapsed))
	var tr := _world_size(c, "cut_trailer")
	var tc := _world_size(c, "cut_tractor")
	if tr == Vector2.ZERO or tc == Vector2.ZERO: return out
	var tw := (float(q[1])-float(q[0]))/0.858
	var th := tw*tr.y/tr.x
	var ty := float(q[2])-th*0.469+sin(time/0.09)*1.2
	_texture(out,c,"cut_trailer",Rect2(_x(c,q[0]),source_round(ty)+c.y_snap,tw,th),"hayride_trailer")
	_texture(out,c,"cut_tractor",Rect2(_x(c,float(q[0])+tw-14),source_round(ty+th-tc.y+sin(time/0.07)*1.5)+c.y_snap,tc.x,tc.y),"hayride_tractor")
	return out
func _harvester(runtime) -> Dictionary:
	return _state(runtime,"harv",_state(runtime,"stage_data",{}).get("harvester",{}))
func build_front(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var c := _festival_context(host)
	var out: Array = []
	var time := float(_state(runtime,"elapsed",host.elapsed))
	var h := _harvester(runtime)
	if not h.is_empty():
		var size := _world_size(c,"cut_harvester")
		var top := float(_trailer(host,runtime)[2])+40
		_texture(out,c,"cut_harvester",Rect2(_x(c,float(h.x)+40-size.x),source_round(top+40-size.y+sin(time/0.08)*2)+c.y_snap,size.x,size.y),"hayride_harvester",Rect2(),false,{"brightness":1.8 if float(h.get("flash",0))>0 else 1.0,"alpha":0.7 if float(h.get("flash",0))>0 else 1.0})
		if not out.is_empty() and out[-1].tag=="hayride_harvester": out[-1].alpha=0.7 if float(h.get("flash",0))>0 else 1.0
	var drones = _state(runtime,"ex_drones",_state(_state(host,"festival_combat",null),"ex_drones",[]))
	for d in drones:
		var age := float(d.get("age", time-float(d.get("t0",0))))
		var start: Vector2=d.get("p",Vector2(d.get("x",0),d.get("y",0)))
		if age < 0 or age >= 2.6: continue
		var origin := Vector2(_x(c,start.x+float(d.dir)*age*220),source_round(start.y-age*160-age*age*20)+c.y_snap)
		_drone(out,c,origin,float(d.dir)*0.12,int(d.dir)>0,true,"hayride_departing_drone")
	out.append_array(super.build_front(host,runtime))
	return out
func build_hud(host, runtime = null) -> Array:
	var out := super.build_hud(host,runtime)
	if not supports(host.level_id): return out
	var h := _harvester(runtime)
	if not h.is_empty() and float(h.hp)>0:
		var health: Array=[]
		_border(health,Rect2(266,496,428,26),8,Color(14/255.0,23/255.0,38/255.0,0.85),Color("f5f1ea"),2,"hayride_health_back")
		_rounded(health,Rect2(270,500,maxf(8,420*float(h.hp)/float(h.max)),18),6,Color("e23b3b"),"hayride_health")
		health.append({"type":"festival_left_text","position":Vector2(278,484),"text":"Harvester bot","size":14,"colour":Color("f5f1ea"),"outline":Color("0e1726"),"tag":"hayride_health_name"})
		health.append_array(out)
		return health
	return out
func _drone(out: Array,c: Dictionary,origin: Vector2,angle: float,flip: bool,cropped: bool,tag: String,brightness: float=1) -> void:
	if not c.images.has("cut_drone"): return
	var size := _world_size(c,"cut_drone")
	var fraction := 0.6 if cropped else 1.0
	out.append({"type":"hayride_texture","texture":c.images.cut_drone,"rect":Rect2(-size.x/2,-size.y*fraction if cropped else 0,size.x,size.y*fraction),"source":Rect2(Vector2.ZERO,_size(c,"cut_drone")*Vector2(1,fraction)),"flip_h":flip,"alpha":1.0,"brightness":brightness,"transform":Transform2D(angle,origin),"tag":tag})
func build_enemy(host, bot: Dictionary) -> Array:
	if not supports(host.level_id): return []
	var c := _festival_context(host)
	var p: Vector2 = bot.p
	if p.x-c.camera.x < -150 or p.x-c.camera.x > c.width+150: return []
	var out: Array=[]
	var carried: bool = bool(bot.get("carry",false)) and bot.state!="pop"
	if carried:
		var origin := Vector2(_x(c,p.x),source_round(p.y-118)+c.y_snap)
		var angle := sin(float(host.elapsed)/0.26+p.x*0.01)*0.06
		_drone(out,c,origin,angle,int(bot.face)>0,true,"hayride_carrier")
		var local := c.duplicate()
		local.camera=Vector2.ZERO
		local.y_snap=0.0
		var animation := "throw" if bot.state=="throw" else "walk"
		var frame := mini(3,int(float(bot.t)/0.11)) if animation=="throw" else 1
		for command in _sprite_commands(host,local,"bot",animation,frame,Vector2.ZERO,-int(bot.face),1,"",float(bot.get("flash",0))>0,"hayride_carried_robot"):
			command.transform=Transform2D(angle,origin)*Transform2D(0,Vector2(0,118))
			command.type="hayride_texture"
			out.append(command)
	elif bot.get("fly",false) and bot.state!="pop" and host.images.has("cut_drone"):
		_ellipse(out,Vector2(_x(c,p.x),p.y-2+c.y_snap),Vector2(34,6),Color(14/255.0,23/255.0,38/255.0,0.25),"festival_bot_shadow")
		_drone(out,c,Vector2(_x(c,p.x),source_round(p.y-150)+c.y_snap),0,int(bot.face)>0,false,"hayride_flying_drone",2 if float(bot.get("flash",0))>0 else 1)
	else:
		out=super.build_enemy(host,bot)
		# Source rotor remains visible over the robot pop when fly is true.
		if bot.get("fly",false):
			var rotor: Array=[]
			var wide := int(float(host.elapsed)/0.04)%2!=0
			_rect(rotor,Rect2(_x(c,p.x)-2,p.y-136+c.y_snap,4,16),Color("3a404c"),"hayride_rotor_stem")
			_rect(rotor,Rect2(_x(c,p.x)-(40 if wide else 12),p.y-138+c.y_snap,80 if wide else 24,4),Color(220/255.0,230/255.0,240/255.0,0.8),"hayride_rotor")
			out.insert(1,rotor[1]); out.insert(1,rotor[0])
		return out
	if bot.get("type",bot.get("kind",""))=="flat": _rect(out,Rect2(_x(c,p.x)-3,p.y-128+c.y_snap,6,6),Color("e23b3b"),"festival_flat_marker")
	return out
# These wrappers deliberately query the LIVE deck, not immutable platform metadata.
func build_player_back(host, player = null) -> Array: return super.build_player_back(host,player)
func build_player_front(host, player = null) -> Array: return super.build_player_front(host,player)
func _brightness(texture: Texture2D, factor: float) -> Texture2D:
	if factor==1: return texture
	var key := "%d:%s"%[texture.get_instance_id(),factor]
	if not _bright.has(key):
		var im := texture.get_image()
		im.convert(Image.FORMAT_RGBA8)
		for y in im.get_height():
			for x in im.get_width():
				var p := im.get_pixel(x,y)
				im.set_pixel(x,y,Color(minf(1,p.r*factor),minf(1,p.g*factor),minf(1,p.b*factor),p.a))
		_bright[key]=ImageTexture.create_from_image(im)
	return _bright[key]
func draw_commands(host,commands: Array) -> void:
	for original in commands:
		var command: Dictionary=original
		if command.type=="hayride_texture":
			var texture: Texture2D=command.texture
			var source: Rect2=command.source
			if command.get("flash",false):
				texture=_festival_variant(command,texture)
				source.position=Vector2.ZERO
			texture=_brightness(texture,float(command.get("brightness",1)))
			var r: Rect2=command.rect
			var t: Transform2D=command.transform
			var points := PackedVector2Array([t*r.position,t*Vector2(r.end.x,r.position.y),t*r.end,t*Vector2(r.position.x,r.end.y)])
			var a := source.position/texture.get_size()
			var b := source.end/texture.get_size()
			if command.flip_h:
				var swap := a.x; a.x=b.x; b.x=swap
			host.draw_polygon(points,PackedColorArray([Color(1,1,1,command.alpha)]),PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]),_nearest(texture))
		elif float(command.get("brightness",1))!=1:
			command=command.duplicate()
			command.texture=_brightness(host.images[command.key],float(command.brightness))
			command.type="festival_texture"
			super.draw_commands(host,[command])
		else: super.draw_commands(host,[command])
func clear_cache() -> void:
	super.clear_cache()
	_bright.clear()
