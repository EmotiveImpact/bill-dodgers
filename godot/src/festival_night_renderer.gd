extends "res://src/festival_renderer.gd"
## After dark painter. Builders are pure; material passes require an ordered
## CanvasItem host hook (see docs/FESTIVAL_NIGHT_RENDERER.md).

const DARK_SHADER := """shader_type canvas_item;
render_mode unshaded;
uniform vec4 holes[128];
uniform int hole_count = 0;
uniform vec2 extent;
uniform float darkness;
void fragment() {
 float a = darkness;
 vec2 p = UV * extent;
 for (int i=0; i<hole_count; i++) {
  float d = distance(p, holes[i].xy);
  float h = clamp((holes[i].z-d)/(holes[i].z*0.85),0.0,1.0)*holes[i].w;
  a *= 1.0-h;
 }
 COLOR=vec4(6.0/255.0,8.0/255.0,26.0/255.0,a);
}
"""
const ADD_SHADER := """shader_type canvas_item;
render_mode unshaded, blend_add;
void fragment() { COLOR = texture(TEXTURE, UV) * COLOR; }
"""
const GLOW_SHADER := """shader_type canvas_item;
render_mode unshaded, blend_add;
void fragment() {
 float a=clamp((200.0-length((UV-vec2(0.5))*400.0))/190.0,0.0,1.0)*0.35;
 COLOR=vec4(1.0,140.0/255.0,40.0/255.0,a);
}
"""
var _night_materials: Dictionary = {}
var _fire_textures: Dictionary = {}

func supports(id: String) -> bool: return id == "3-3"

func build_sky(host, runtime = null) -> Array:
	var out := super.build_sky(host, runtime)
	var colours := [Color("060a1f"), Color("060a1f"), Color("16204a"), Color("2b2f5e"), Color("2b2f5e")]
	var index := 0
	for command in out:
		if command.tag == "festival_sky_gradient":
			command.colours = PackedColorArray([colours[index], colours[index], colours[index + 1], colours[index + 1]])
			index += 1
	return out

func _decor_cut(out: Array, c: Dictionary, decor: Array) -> void:
	if decor[4] == "back" and (str(decor[0]).begins_with("flag") or decor[0] == "speaker"): return
	if decor[0] != "lantern":
		super._decor_cut(out, c, decor)
		return
	var x := float(decor[1])
	if x - float(c.camera.x) < -560 or x - float(c.camera.x) > float(c.width) + 560: return
	var y := float(decor[2])
	var origin := Vector2(_x(c, x), y + float(c.y_snap))
	for part in [[11,40,8,float(c.ground)-y-36,"14121e"], [13,40,3,float(c.ground)-y-36,"3a3448"], [2,-6,26,6,"14121e"], [5,float(c.ground)-y-10,20,10,"14121e"], [13,0,4,8,"2a2f3d"], [4,8,22,30,"ffcf5a"], [9,13,12,18,"fff3b0"], [2,36,26,6,"ff8a2a"], [2,6,26,4,"2a2f3d"]]:
		_rect(out, Rect2(origin + Vector2(part[0],part[1]), Vector2(part[2],part[3])), Color(part[4]), "night_lantern")

func _surface(out: Array, c: Dictionary, q: Dictionary) -> void:
	var commands: Array = []
	super._surface(commands,c,q)
	for command in commands:
		if command.tag=="festival_bale": command.type="festival_texture"; command.filter="night_bale"
		out.append(command)

static func _hue(rgb: Vector3, degrees: float) -> Vector3:
	var co := cos(deg_to_rad(degrees))
	var si := sin(deg_to_rad(degrees))
	return Vector3(
		Vector3(0.213+co*0.787-si*0.213,0.715-co*0.715-si*0.715,0.072-co*0.072+si*0.928).dot(rgb),
		Vector3(0.213-co*0.213+si*0.143,0.715+co*0.285+si*0.140,0.072-co*0.072-si*0.283).dot(rgb),
		Vector3(0.213-co*0.213-si*0.787,0.715-co*0.715+si*0.715,0.072+co*0.928+si*0.072).dot(rgb))

static func night_bale_pixel(pixel: Color) -> Color:
	var rgb := Vector3(pixel.r,pixel.g,pixel.b)*0.5
	var gray := rgb.dot(Vector3(0.213,0.715,0.072))
	rgb=rgb*0.7+Vector3.ONE*gray*0.3
	# Preserve BOTH authored CSS matrices, not a generic colour wash.
	rgb=_hue(_hue(rgb,200),160)
	return Color(rgb.x,rgb.y,rgb.z,pixel.a)

func _festival_variant(command: Dictionary, original: Texture2D) -> Texture2D:
	if command.get("filter","")!="night_bale": return super._festival_variant(command,original)
	var source: Rect2=command.source
	var key := "night:%d:%s"%[original.get_instance_id(),source]
	if not _festival_variants.has(key):
		var pixels := original.get_image().get_region(Rect2i(source))
		pixels.convert(Image.FORMAT_RGBA8)
		for y in pixels.get_height():
			for x in pixels.get_width(): pixels.set_pixel(x,y,night_bale_pixel(pixels.get_pixel(x,y)))
		_festival_variants[key]=ImageTexture.create_from_image(pixels)
	return _festival_variants[key]

static func fire_geometry(frame: int) -> Array:
	var out: Array = [[Rect2(8,96,74,10),Color("5b3a2a")],[Rect2(16,90,58,8),Color("7a4d33")],[Rect2(0,104,90,6),Color("3d2a20")]]
	var rng: Array = [12 + posmod(frame,4)*5]
	for i in 40:
		var a := _festival_random(rng)
		var h := 30 + _festival_random(rng)*60*(1-absf(a-0.5))
		var colour := Color("ffd23f") if _festival_random(rng)<0.4 else (Color("ff8a2a") if _festival_random(rng)<0.7 else Color("e8432e"))
		var w := 4 + _festival_random(rng)*4
		out.append([Rect2(source_round(18+a*54),source_round(92-h),source_round(w),source_round(h*0.4)),colour])
	out.append([Rect2(38,70,12,18),Color("fff3b0")])
	return out

func fire_texture(frame: int) -> Texture2D:
	frame = posmod(frame,4)
	if not _fire_textures.has(frame):
		var pixels := Image.create(90,110,false,Image.FORMAT_RGBA8)
		pixels.fill(Color.TRANSPARENT)
		for part in fire_geometry(frame): pixels.fill_rect(Rect2i(part[0]),part[1])
		_fire_textures[frame] = ImageTexture.create_from_image(pixels)
	return _fire_textures[frame]

func build_level(host, runtime = null) -> Array:
	var out := super.build_level(host, runtime)
	if not supports(host.level_id): return out
	var c := _festival_context(host)
	var checkpoint: Array = []
	var body: Array = []
	for command in out:
		if str(command.tag).begins_with("festival_checkpoint"): checkpoint.append(command)
		else: body.append(command)
	var frame := int(floorf(float(_state(runtime,"elapsed",host.elapsed))/0.11 + 0.000000001)) % 4
	for fire in c.level.get("fires",[]):
		var x := float(fire[0])
		var y := float(fire[1])+float(c.y_snap)
		if x-float(c.camera.x)<-160 or x-float(c.camera.x)>float(c.width)+160: continue
		var size := _world_size(c,"cut_campfire")
		if size != Vector2.ZERO:
			_texture(body,c,"cut_campfire",Rect2(_x(c,x-size.x/2),y+6-size.y,size.x,size.y),"night_fire_pit")
			body.append({"type":"night_additive","tag":"night_fire_flames","frame":frame,"rect":Rect2(_x(c,x-27),y-128,54,92),"source":Rect2(18,0,54,92),"alpha":0.55})
		else:
			body.append({"type":"night_fire_texture","tag":"night_fire_fallback","frame":frame,"rect":Rect2(_x(c,x-45),y-106,90,110),"source":Rect2(0,0,90,110),"alpha":1.0})
	body.append_array(checkpoint)
	return body

func _actor_position(actor) -> Vector2:
	if actor is Vector2: return actor
	var p = _state(actor,"p",null)
	if p is Vector2: return p
	return Vector2(float(_state(actor,"x",0)),float(_state(actor,"fy",_state(actor,"y",482))))

func build_darkness(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var c := _festival_context(host)
	var data: Dictionary = _state(runtime,"stage_data",{})
	var elapsed := float(_state(runtime,"elapsed",host.elapsed))
	var origin := Vector2(c.camera.x,c.view.position.y)
	var holes: Array[Vector4] = []
	var players: Array = _state(host,"players",[host.player])
	for player in players: _hole(holes,_actor_position(player)-Vector2(0,90)-origin,230,1)
	for fire in c.level.get("fires",[]): _hole(holes,Vector2(fire[0],float(fire[1])-60)-origin,240+sin(elapsed/0.07)*10,1)
	for decor in c.level.get("decor",[]):
		if decor[0]=="lantern": _hole(holes,Vector2(float(decor[1])+15,float(decor[2])+20)-origin,150,0.9)
	for tent in _tents(host,runtime):
		if bool(tent.get("glow",false)): _hole(holes,Vector2(tent.x,float(tent.y)-50)-origin,120,0.7)
	for shot in _state(host,"shots",_state(host,"bullets",[])):
		if not bool(shot.get("enemy",false)): _hole(holes,_actor_position(shot)-origin,60,0.8)
	var bots: Array = _state(host,"enemies",_state(host,"bots",[]))
	for bot in bots:
		if bot.get("state","")!="pop": _hole(holes,_actor_position(bot)-Vector2(0,90)-origin,70,0.5)
	var alpha := maxf(0,1-float(data.get("flash_time",0))/0.6)*float(c.l3.get("dark",0.8))
	var out: Array = [{"type":"night_darkness","tag":"night_darkness","rect":Rect2(origin+Vector2(0,c.y_snap),Vector2(c.width,ceilf(540/1.3)+4)),"holes":holes,"alpha":alpha}]
	for fire in c.level.get("fires",[]):
		var x := float(fire[0])
		if x-float(c.camera.x)<-200 or x-float(c.camera.x)>float(c.width)+200: continue
		out.append({"type":"night_glow","tag":"night_fire_glow","rect":Rect2(x-200,float(fire[1])-240+float(c.y_snap),400,400)})
	for bot in bots:
		if bot.get("state","")=="pop": continue
		var p := _actor_position(bot)
		for dx in [-12,6]: _rect(out,Rect2(_x(c,p.x)+dx,p.y-104+float(c.y_snap),6,4),Color("ff4040"),"night_bot_eye")
	for fw in data.get("fireworks",[]):
		var t := float(fw.t)
		var colour := Color(str(fw.col))
		colour.a = maxf(0,1-t/1.4)
		for ray in fw.s:
			var v: Vector2 = ray if ray is Vector2 else Vector2(ray[0],ray[1])
			_rect(out,Rect2(_x(c,float(fw.x)+v.x*t*120),source_round(float(fw.y)+v.y*t*120+t*t*40)+float(c.y_snap),4,4),colour,"night_firework")
	return out

func _hole(holes: Array[Vector4], p: Vector2, radius: float, alpha: float) -> void:
	# Offscreen holes cannot affect the finite original darkness canvas.
	if p.x+radius<0 or p.x-radius>738 or p.y+radius<0 or p.y-radius>420: return
	holes.append(Vector4(p.x,p.y,radius,alpha))

static func darkness_at(point: Vector2, holes: Array, alpha: float) -> float:
	for hole in holes:
		alpha *= 1-clampf((hole.z-point.distance_to(Vector2(hole.x,hole.y)))/(hole.z*0.85),0,1)*hole.w
	return alpha

func build_front(host, runtime = null) -> Array:
	var source := super.build_front(host,runtime)
	var out: Array = []
	var hints: Array = []
	for command in source:
		if command.tag in ["festival_hint","festival_cheer"]: hints.append(command)
		else: out.append(command)
	out.append_array(build_darkness(host,runtime))
	out.append_array(hints)
	return out

func build_hud(host, runtime = null) -> Array:
	# Inherited wipe honors runtime.wipe_kind == fade, preserving its timing
	# and source label rather than substituting an iris or moving simulation.
	return super.build_hud(host,runtime)

func material_for(command: Dictionary) -> ShaderMaterial:
	var kind := str(command.type)
	if not _night_materials.has(kind):
		var shader := Shader.new()
		shader.code = DARK_SHADER if kind=="night_darkness" else (GLOW_SHADER if kind=="night_glow" else ADD_SHADER)
		var material := ShaderMaterial.new()
		material.shader = shader
		_night_materials[kind] = material
	var material: ShaderMaterial = _night_materials[kind]
	if kind=="night_darkness":
		assert(command.holes.size()<=128,"Night shader capacity exceeded; do not silently discard source lights")
		var packed := PackedVector4Array(command.holes)
		packed.resize(128)
		material.set_shader_parameter("holes",packed)
		material.set_shader_parameter("hole_count",command.holes.size())
		material.set_shader_parameter("extent",command.rect.size)
		material.set_shader_parameter("darkness",command.alpha)
	return material

func draw_material_command(canvas: CanvasItem, command: Dictionary) -> void:
	# Call only from canvas._draw(), with canvas.material=material_for(command).
	if command.type=="night_additive":
		canvas.draw_texture_rect_region(_nearest(fire_texture(command.frame)),command.rect,command.source,Color(1,1,1,command.alpha))
	else: canvas.draw_rect(command.rect,Color.WHITE)

func draw_commands(host, commands: Array) -> void:
	for command in commands:
		if command.type in ["night_darkness","night_additive","night_glow"]:
			assert(host.has_method("draw_festival_material"),"After dark requires ordered material CanvasItems; see FESTIVAL_NIGHT_RENDERER.md")
			host.draw_festival_material(command,material_for(command))
		elif command.type=="night_fire_texture":
			host.draw_texture_rect_region(_nearest(fire_texture(command.frame)),command.rect,command.source,Color.WHITE)
		else: super.draw_commands(host,[command])

func clear_cache() -> void:
	super.clear_cache()
	_night_materials.clear()
	_fire_textures.clear()
