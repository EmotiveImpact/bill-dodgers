extends "res://src/festival_renderer.gd"
## W4 source paintings, physical deck lines and procedural maritime entities.
## Inherits drawing primitives/sprite renderer, never festival scenery or rules.
func supports(id: String) -> bool: return id in ["4-1","4-2","4-3","4-4","4-5","4-6","4-S"]
func _holiday_context(host) -> Dictionary:
	var c := _context(host)
	c.cfg = host.level.get("cfg", {})
	c.elapsed = float(host.elapsed)
	return c
func _holiday_scene(c: Dictionary) -> Dictionary:
	var selected: Dictionary = {}
	for scene in c.level.get("scenes", []):
		if c.camera.x >= scene.x - 1: selected = scene
	return selected
func _layers(out: Array,c: Dictionary,layers: Array,sky: bool) -> void:
	for layer in layers:
		var y := source_round(float(layer.get("y",0)) - (float(c.camera.y) * float(layer.get("yf",0)) if sky else 0)) + (float(c.camera.y) if sky else float(c.y_snap))
		if layer.has("fill"):
			_rect(out,Rect2(c.camera.x-10,y,c.width+20,3000),Color(layer.fill),"holiday_layer_fill")
			if layer.get("sea",false):
				var offset := fmod(float(c.camera.x)*float(layer.get("f",0.1)),70)
				for r in 7:
					var x := -offset-70+fmod(r*23,70)
					while x<c.width+70:
						_rect(out,Rect2(c.camera.x+source_round(x+sin(c.elapsed/0.7+r+x)*2),y+6+r*r*5,10+r*3,2 if r>3 else 1),Color(1,1,1,0.22),"holiday_sea_shimmer")
						x+=70
			continue
		var key:=str(layer.get("img",""));var size:=_size(c,key)
		if size==Vector2.ZERO:continue
		var h:=float(layer.get("h",size.y));var w:=maxf(8,source_round(float(layer.get("w",size.x*h/size.y))))
		var pos:=float(c.camera.x)*float(layer.get("f",0))+float(layer.get("drift",0))*float(c.elapsed)
		var first:=int(floorf(pos/w));var off:=source_round(pos-first*w);var i:=0
		while -off+i*w<960:
			_texture(out,c,key,Rect2(c.camera.x-off+i*w,y,w,h),"holiday_parallax",Rect2(),bool(layer.get("mirror",false)) and (first+i)%2!=0,{"alpha":float(layer.get("alpha",1)),"factor":float(layer.get("f",0)),"index":first+i})
			i+=1
func build_sky(host,_runtime=null)->Array:
	if not supports(host.level_id):return []
	var c:=_holiday_context(host);var scene:=_holiday_scene(c);var out:Array=[]
	var colours:Array=scene.get("sky",c.cfg.get("sky",["#58b7ef","#bfe6fb","#fff1cf"]))
	for i in colours.size()-1:
		var top:=540.0*i/(colours.size()-1);var bottom:=540.0*(i+1)/(colours.size()-1)
		out.append({"type":"gradient","rect":Rect2(c.camera.x-10,c.camera.y+top,c.width+20,bottom-top),"colours":PackedColorArray([Color(colours[i]),Color(colours[i]),Color(colours[i+1]),Color(colours[i+1])]),"tag":"holiday_sky"})
	_layers(out,c,scene.get("layers",[]),true)
	return out
func _image(out:Array,c:Dictionary,key:String,x:float,y:float,flip:bool=false,tag:String="holiday_decor")->void:
	var size:=_size(c,key)
	_texture(out,c,key,Rect2(_x(c,x),source_round(y)+float(c.y_snap),size.x,size.y),tag,Rect2(),flip)
func _tiled_clip(out:Array,c:Dictionary,key:String,q:Dictionary,y:float,bottom:float,factor:float,tag:String)->bool:
	var size:=_size(c,key)
	if size==Vector2.ZERO:return false
	var clip:=Rect2(_x(c,q.row[0]),y+float(c.y_snap),float(q.row[1])-float(q.row[0]),bottom-y)
	var yy:=y
	while yy<bottom:
		var x:=float(q.row[0])-fmod(float(q.row[0])*factor,size.x)
		# Skip offscreen tiles without changing source phase.
		x+=maxf(0,floorf((float(c.camera.x)-x-size.x)/size.x))*size.x
		while x<q.row[1] and x<c.camera.x+c.width+size.x:
			var commands:Array=[]
			_texture(commands,c,key,Rect2(_x(c,x),source_round(yy)+float(c.y_snap),size.x,size.y),tag)
			for command in commands:
				var clipped:=_clip_texture(command,clip)
				if not clipped.is_empty():out.append(clipped)
			x+=size.x
		yy+=size.y
	return true
func build_level(host,runtime=null)->Array:
	if not supports(host.level_id):return []
	var c:=_holiday_context(host);var out:Array=[];var scene:=_holiday_scene(c)
	_layers(out,c,scene.get("back",[]),false)
	var scenes:Array=c.level.get("scenes",[]);var part:=scenes.find(scene)
	for panel in c.level.get("panels",[]):
		if panel.size()>6 and panel[6]!=part:continue
		var key:=str(panel[0]);var size:=_size(c,key)
		var factor:=float(panel[5]) if panel.size()>5 and panel[5] else 1.0
		var x:=float(c.camera.x)+source_round(float(panel[1])-float(c.camera.x)*factor)
		var commands:Array=[]
		_texture(commands,c,key,Rect2(x,source_round(panel[2])+float(c.y_snap),size.x,size.y),"holiday_panel",Rect2(),bool(panel[3]))
		for command in commands:
			if panel.size()>4 and panel[4]:
				var clipped:=_clip_texture(command,Rect2(x-1,float(panel[2])-2000+float(c.y_snap),size.x+2,float(panel[4])-float(panel[2])+2000))
				if not clipped.is_empty():out.append(clipped)
			else:out.append(command)
	if c.cfg.has("waterTop"):_rect(out,Rect2(c.camera.x-10,c.cfg.waterTop,c.width+20,c.camera.y+560-c.cfg.waterTop),Color("17698f"),"holiday_water_back")
	if c.cfg.has("water"):_water(out,c,float(c.cfg.water),str(scene.get("waterCol",c.cfg.get("waterCol","#1f8fc0"))))
	for q in _surfaces(host,runtime):
		if not q.plat and not q.get("hide",false) and (q.get("style","") or c.cfg.get("blocks","")):_block(out,c,q)
	for q in _surfaces(host,runtime):
		if q.get("belt",0):_carousel(out,c,q)
	var deck:Dictionary=_state(runtime,"deck",{})
	if not deck.is_empty():
		var size:=_size(c,"pedalo");var row:Array=deck.row
		_image(out,c,"pedalo",(float(row[0])+float(row[1]))/2-size.x/2,float(row[2])-float(c.level.get("deckLine",0)),false,"holiday_deck")
	for decor in c.level.get("decor",[]):_image(out,c,str(decor[0]),decor[1],decor[2],bool(decor[3]))
	var hold:Dictionary=_state(runtime,"hold",{})
	for towel in hold.get("towels",[]):
		var key:="lounger" if towel.gone or towel.held!=null else "towel"
		var size:=_size(c,key)
		_image(out,c,key,towel.x-size.x/2,c.ground-size.y,false,"holiday_towel")
		var foes=_state(runtime,"foes",null)
		if hold.on and not hold.over and int(c.elapsed/0.3)%2!=0 and foes!=null and foes.entries.any(func(f):return f.kind=="grab" and not f.dead and is_same(f.get("target"),towel)):
			_text(out,Vector2(_x(c,towel.x),c.ground-120),"!",26,Color("ff8f8f"),"holiday_towel_warning")
	# Source final wrapper moves these props behind actors and disables drawFG.
	for decor in c.level.get("front",[]):_image(out,c,str(decor[0]),decor[1],decor[2],bool(decor[3]),"holiday_front_behind")
	return out
func _water(out:Array,c:Dictionary,y:float,colour:String)->void:
	_rect(out,Rect2(c.camera.x-10,y,c.width+20,c.camera.y+560-y),Color(colour),"holiday_water")
	var x:=-fmod(float(c.camera.x),48)-48
	while x<c.width+48:
		var offset:=sin((x+float(c.camera.x))/37+float(c.elapsed)/0.3)*3
		_rect(out,Rect2(c.camera.x+source_round(x),source_round(y+offset),22,3),Color(1,1,1,0.75),"holiday_water_edge")
		x+=48
	for r in range(1,6):
		x=-fmod(float(c.camera.x)*(1+r*0.1),90)-90
		while x<c.width+90:
			_rect(out,Rect2(c.camera.x+source_round(x+r*31),source_round(y+r*18+sin(c.elapsed/0.4+r+x)*2),26-r*2,2),Color(1,1,1,0.28),"holiday_water_ripple")
			x+=90
func _block(out:Array,c:Dictionary,q:Dictionary)->void:
	var a:=float(q.row[0]);var b:=float(q.row[1]);var top:=float(q.row[2])
	if not _in_view(c,a,b):return
	var x0:=_x(c,a);var x1:=_x(c,b);var bottom:=float(q.get("bottom",c.camera.y+560));var style:=str(q.get("style",c.cfg.get("blocks","")))
	if style=="boat":
		var key:=str(q.get("col",""));var size:=_size(c,key)
		if size!=Vector2.ZERO:
			var w:=x1-x0+70;var h:=source_round(size.y*w/size.x);var dl:=float(c.cfg.get("boatDeck",{}).get(key,0.4))
			_texture(out,c,key,Rect2(x0-35,source_round(top-h*dl)+float(c.y_snap),w,h),"holiday_boat")
		return
	if style=="jetty":
		var x:=a+30
		while x<b:
			_rect(out,Rect2(_x(c,x),top+10,14,bottom-top),Color("6b4a33"),"holiday_jetty_pile");x+=120
		_rect(out,Rect2(x0,top,x1-x0,16),Color("b98a5a"),"holiday_jetty_deck")
		x=a
		while x<b:_rect(out,Rect2(_x(c,x),top,2,16),Color("9a6e45"),"holiday_jetty_plank");x+=30
		_rect(out,Rect2(x0,top+14,x1-x0,4),Color("7a5434"),"holiday_jetty_edge");return
	if style=="quay" and c.images.has("quay"):
		var y:=top-float(c.cfg.get("quayOff",0));var size:=_size(c,"quay")
		_tiled_clip(out,c,"quay",q,y,minf(bottom,y+size.y),0.61,"holiday_quay")
		_rect(out,Rect2(x0,y+size.y,x1-x0,bottom-y-size.y),Color("5e5446"),"holiday_quay_fill")
		for x in [x0,x1-4]:_rect(out,Rect2(x,y,4,bottom-y),Color(0.08,0.055,0.094,0.35),"holiday_quay_side")
		return
	var textured:bool=(style=="mezz" and q.has("tex") and c.images.has(q.tex)) or (style=="terrace" and c.images.has("pave") and c.cfg.has("pave"))
	if textured:
		var key:=str(q.tex) if style=="mezz" else "pave";var size:=_size(c,key)
		var y:=top-float(q.get("texOff",0) if style=="mezz" else c.cfg.pave)
		var face:=str(q.get("face","") if style=="mezz" else c.cfg.get("face",""))
		if not _tiled_clip(out,c,face,q,y+size.y-2,bottom,0.37,"holiday_block_face"):_rect(out,Rect2(x0,y+size.y-4,x1-x0,bottom-y-size.y+4),Color("efe7dc" if style=="mezz" else "f4f1ea"),"holiday_block_fill")
		_tiled_clip(out,c,key,q,y,y+size.y,0.61,"holiday_block_top")
		for x in [x0,x1-8]:_rect(out,Rect2(x,y,5 if x==x0 else 8,bottom-y),Color(0.31,0.24,0.16,0.18),"holiday_block_side")
		if style=="mezz" and q.get("rail",true):_rail(out,c,q,y,"c9a66b",110)
		return
	if style=="mezz":
		var col:Array=q.get("col",["#dfe5ea","#c5ced6","#8e9aa6"])
		_rect(out,Rect2(x0,top,x1-x0,bottom-top),Color(col[1]),"holiday_mezz_fill")
		_rect(out,Rect2(x0,top+12,x1-x0,6),Color(col[2]),"holiday_mezz_edge")
		var x:=a+20
		while x<b-20:_rect(out,Rect2(_x(c,x),top+24,40,bottom-top-30),Color(1,1,1,0.35),"holiday_mezz_columns");x+=80
		_rect(out,Rect2(x0,top,x1-x0,12),Color(col[0]),"holiday_mezz_top")
		_rail(out,c,q,top,"9aa3ad",120)
	else:
		_rect(out,Rect2(x0,top,x1-x0,bottom-top),Color("f4f1ea" if style=="terrace" else "c9c2b4"),"holiday_block_fallback")
		_rect(out,Rect2(x0-3,top-4,x1-x0+6,12),Color("c8bfae"),"holiday_terrace_top")
		for dx in q.get("door",[]):
			_rect(out,Rect2(_x(c,dx),top+70,54,96),Color("2a6fb5"),"holiday_door")
			_rect(out,Rect2(_x(c,dx)+42,top+120,5,5),GOLD,"holiday_door_handle")
		for dx in q.get("win",[]):
			_rect(out,Rect2(_x(c,dx)-10,top+60,64,60),Color("2a6fb5"),"holiday_window_shutter")
			_rect(out,Rect2(_x(c,dx),top+60,44,60),Color("1b2d44"),"holiday_window")
			_rect(out,Rect2(_x(c,dx)+4,top+64,16,22),Color("9fc7e8"),"holiday_window_glass")
func _rail(out:Array,c:Dictionary,q:Dictionary,y:float,colour:String,stride:float)->void:
	var a:=float(q.row[0]);var b:=float(q.row[1]);var x:=a
	_rect(out,Rect2(_x(c,a),y-44,b-a,42),Color(0.745,0.882,0.941,0.38),"holiday_rail_glass")
	_rect(out,Rect2(_x(c,a),y-47,b-a,5),Color(colour),"holiday_rail_top")
	while x<=b:_rect(out,Rect2(_x(c,minf(x,b-4)),y-47,4,47),Color(colour),"holiday_rail_post");x+=stride
func _carousel(out:Array,c:Dictionary,q:Dictionary)->void:
	var a:=float(q.row[0]);var b:=float(q.row[1]);var top:=float(q.row[2])
	if not _in_view(c,a,b):return
	var h:=source_round((float(c.ground)-top)/0.62);var y:=float(c.ground)-h
	_texture(out,c,"carousel",Rect2(_x(c,a)-14,y,b-a+28,h),"holiday_carousel")
	var offset:=fposmod(float(c.elapsed)*1000*float(q.belt),28);var x:=a-28+offset
	while x<b:
		if x>a and x+3<b:_rect(out,Rect2(_x(c,x),source_round(y+h*0.3),3,source_round(h*0.16)),Color(1,1,1,0.16),"holiday_belt_slats")
		x+=28
func draw_mid(host,runtime=null,_pickups:Callable=Callable())->void:
	draw_commands(host,build_finds(host,runtime))
	if host.has_method("_draw_skill_card"):host._draw_skill_card()
func build_mid(_host,_runtime=null)->Array:return []
func build_finds(host,runtime=null)->Array:
	var out:Array=[];var c:=_holiday_context(host)
	for item in host.receipts:
		var taken:bool=item.get("taken",false)
		var age:float=item.get("age",0)
		if taken and age>=0.6:continue
		var p:Vector2=item.position
		if p.x<c.camera.x-40 or p.x>c.camera.x+c.width+40:continue
		var point:=Vector2(_x(c,p.x),source_round(p.y-60+sin(c.elapsed/0.2+p.x)*4)+float(c.y_snap))
		var alpha:=maxf(0,1-age/0.6) if taken else 1.0
		_ellipse(out,point,Vector2(22,22),Color(1,0.945,0.659,0.35*alpha),"holiday_receipt_glow")
		var transform:=Transform2D(sin(c.elapsed/0.3)*0.15,point)
		_poly(out,[Vector2(-11,-16),Vector2(11,-16),Vector2(11,14),Vector2(-11,14)],Color(Color("fffdf4"),alpha),"holiday_receipt",transform)
		for i in 4:
			var width:=8 if i==3 else 14;var top:=-11+i*6
			_poly(out,[Vector2(-7,top),Vector2(-7+width,top),Vector2(-7+width,top+2),Vector2(-7,top+2)],Color(Color("14243b"),alpha),"holiday_receipt_line",transform)
		for i in 4:
			var left:=-11+i*6
			_poly(out,[Vector2(left,14),Vector2(left+4,14),Vector2(left+4,17),Vector2(left,17)],Color(Color("fffdf4"),alpha),"holiday_receipt_tooth",transform)
	return out
func build_front(host,runtime=null)->Array:
	var out:Array=[];var c:=_holiday_context(host)
	if c.cfg.has("waterFront"):_rect(out,Rect2(c.camera.x-10,c.cfg.waterFront,c.width+20,c.camera.y+560-c.cfg.waterFront),Color(0.122,0.561,0.753,0.55),"holiday_water_front")
	var foes=_state(runtime,"foes",null)
	if foes!=null:
		for f in foes.entries:
			if f.kind=="drop" and f.state=="fall":_ellipse(out,Vector2(_x(c,f.x),f.fy-3),Vector2(10+26*minf(1,f.t/f.duration),6),Color(0.055,0.09,0.149,0.35),"holiday_drop_warning")
	return out
func build_hud(host,runtime=null)->Array:
	var out:Array=[];var c:=_holiday_context(host);var hold:Dictionary=_state(runtime,"hold",{});var dash:Dictionary=_state(runtime,"dash",{})
	if not hold.is_empty() and hold.on and not hold.over:
		var left:=maxi(0,int(ceilf(hold.left)));_border(out,Rect2(360,76,240,46),12,Color(0.055,0.09,0.149,0.8),Color("f5f1ea"),2,"holiday_hold_hud")
		_text(out,Vector2(480,92),"Hold on %d:%02d"%[left/60,left%60],16,GOLD,"holiday_hold_time")
		_text(out,Vector2(480,111),"Towels left %d of %d"%[hold.towels.filter(func(t):return not t.gone).size(),hold.towels.size()],11,Color("f5f1ea"),"holiday_towel_count")
	if not dash.is_empty() and not dash.over:
		var left:=maxi(0,int(ceilf(dash.left)));_border(out,Rect2(370,76,220,46),12,Color(0.055,0.09,0.149,0.8),Color("f5f1ea"),2,"holiday_dash_hud")
		_text(out,Vector2(480,92),"Time %d:%02d"%[left/60,left%60],16,Color("ff8f8f") if left<15 else GOLD,"holiday_dash_time")
		_text(out,Vector2(480,111),"Partner bonus x%d"%dash.mult,11,Color("f5f1ea"),"holiday_dash_multiplier")
	if c.level.get("auto",0) and host.mode=="play" and float(_state(runtime,"end_time",0))==0:
		_border(out,Rect2(380,76,200,12),6,Color(0.055,0.09,0.149,0.8),Color("f5f1ea"),2,"holiday_ride_progress")
		_rounded(out,Rect2(382,78,maxf(8,196*minf(1,float(c.camera.x)/(float(c.level.w)-float(c.width)))),8),4,Color("9fe0b8"),"holiday_ride_fill")
		_text(out,Vector2(480,100),str(c.cfg.get("goal","Finish")),11,Color("f5f1ea"),"holiday_ride_goal")
	var captain=_state(runtime,"captain",null)
	var boss:Dictionary={} if captain==null else captain.state
	if not boss.is_empty() and boss.state!="down":
		_border(out,Rect2(266,496,428,26),8,Color(14/255.0,23/255.0,38/255.0,0.85),Color("f5f1ea"),2,"holiday_captain_health_back")
		_rounded(out,Rect2(270,500,420*maxf(0,float(boss.hp)/float(boss.max)),18),6,GOLD if boss.dizzy>0 else Color("e23b3b"),"holiday_captain_health")
		out.append({"type":"festival_left_text","position":Vector2(278,484),"text":str(host.meta.get("txt",{}).get("boss","Boss")),"size":14,"colour":Color("f5f1ea"),"outline":Color("0e1726"),"tag":"holiday_captain_name"})
	var go_time:float=_state(host.combat,"go_time",0)
	if go_time>0 and float(_state(runtime,"end_time",0))==0 and int(go_time/0.3)%2==0:
		_text(out,Vector2(850,260),"Go!",34,GOLD,"holiday_go")
		_poly(out,[Vector2(900,260),Vector2(876,240),Vector2(876,280)],GOLD,"holiday_go_arrow")
	out.append_array(_build_wipe(host,runtime))
	return out
func _text(out:Array,p:Vector2,value:String,size:int,colour:Color,tag:String)->void:out.append({"type":"text","position":p,"text":value,"size":size,"colour":colour,"tag":tag})
func draw_player_back(_host,_player=null)->void:pass
func draw_player_front(_host,_player=null)->void:pass
func draw_foes(host,runtime)->void:draw_commands(host,build_foes(host,runtime))
func build_foes(host,runtime)->Array:
	var out:Array=[];var c:=_holiday_context(host)
	if runtime==null:return out
	for f in runtime.foes.entries:
		var x:=_x(c,f.x);var y:=float(f.y)+float(c.y_snap)
		if f.x<c.camera.x-500 or f.x>c.camera.x+c.width+500:continue
		match str(f.kind):
			"case","drop":
				if f.dead:continue
				var size:=_size(c,"suitcase");var wob:=sin(f.t/0.03)*3 if f.kind=="case" and fmod(f.t,2.6)>2.2 else 0.0
				_image(out,c,"suitcase",f.x-size.x/2+wob,f.y-size.y,bool(f.get("flip",false)),"holiday_suitcase")
				if f.flash>0:_rect(out,Rect2(x-32,y-70,64,70),Color(1,1,1,0.5),"holiday_case_flash")
			"bailiff":
				if f.dead and f.die_t>0.6:continue
				_ellipse(out,Vector2(x,y-2),Vector2(80,10),Color(0.055,0.09,0.149,0.3),"holiday_bailiff_shadow")
				var anim:="pop" if f.dead else ("walk" if f.state=="walk" else "throw")
				var frame:=mini(3,int(f.die_t/0.14)) if f.dead else (int(f.t/0.13)%6 if f.state=="walk" else mini(3,int(f.t/0.12)))
				var commands:=_sprite_commands(host,c,"bot",anim,frame,Vector2(f.x,f.y),-f.face,maxf(0,1-f.die_t/0.6) if f.dead else 1.0,"",f.flash>0,"holiday_bailiff")
				for command in commands:
					command.rect=Rect2(Vector2(x,y)+(command.rect.position-Vector2(x,y))*1.75,command.rect.size*1.75)
					out.append(command)
				if not f.dead:
					_rect(out,Rect2(x-40,y-140,80,12),Color("5b6573"),"holiday_bailiff_armour")
					_rect(out,Rect2(x-34,y-236,68,12),Color("1f2a3a"),"holiday_bailiff_cap")
					_rect(out,Rect2(x-24+f.face*10,y-228,48,8),Color("1f2a3a"),"holiday_bailiff_peak")
					_rounded(out,Rect2(x-60,y-262,120,10),4,Color(0.055,0.09,0.149,0.8),"holiday_bailiff_hp_back")
					_rounded(out,Rect2(x-59,y-261,maxf(4,118*float(f.hp)/float(f.max)),8),3,Color("e23b3b"),"holiday_bailiff_hp")
				for wave in f.waves:
					for i in 4:_rect(out,Rect2(_x(c,wave.x)-6-i*8*signf(wave.vx),y-10-(3-i)*7,12,10+(3-i)*4),Color("e8e1d2"),"holiday_bailiff_wave")
			"jet":
				if f.dead and f.die_t>0.7:continue
				var bob:=sin(f.t/0.16)*4;var flip:= -1.0 if f.face>0 else 1.0
				var trans:=Transform2D(0,Vector2(flip,1),0,Vector2(x,y+bob))
				_poly(out,[Vector2(-70,-20),Vector2(60,-26),Vector2(72,-8),Vector2(-58,6)],Color("d23a2e"),"holiday_jet_hull",trans)
				_poly(out,[Vector2(-50,-24),Vector2(40,-24),Vector2(40,-18),Vector2(-50,-18)],Color("f5f1ea"),"holiday_jet_edge",trans)
				_poly(out,[Vector2(-36,-40),Vector2(-28,-40),Vector2(-28,-22),Vector2(-36,-22)],Color("14243b"),"holiday_jet_handle",trans)
				var anim:="pop" if f.dead else ("throw" if f.throw_t>0 else "walk")
				out.append_array(_sprite_commands(host,c,"bot",anim,mini(3,int(f.die_t/0.14)) if f.dead else (2 if f.throw_t>0 else 0),Vector2(f.x,f.y-16+(0 if f.dead else bob)),-f.face,maxf(0,1-f.die_t/0.7) if f.dead else 1.0,"",f.flash>0,"holiday_jet_rider"))
			"ring":
				if f.dead:continue
				var key:="fl-"+str(f.img);var size:=_size(c,key)
				if size!=Vector2.ZERO:_image(out,c,key,f.x-size.x/2,f.y-size.y,f.vx>0,"holiday_inflatable")
				else:
					var points:=PackedVector2Array()
					for i in 65:points.append(Vector2(x,y-30)+Vector2(cos(i*TAU/64)*36,sin(i*TAU/64)*24))
					out.append({"type":"line","points":points,"colour":Color("ff6fa8"),"width":14.0,"tag":"holiday_ring_fallback"})
				if f.flash>0:_rect(out,Rect2(x-44,y-70,88,70),Color(1,1,1,0.5),"holiday_ring_flash")
			"banana":
				var bob:=sin(f.t/0.2)*4;y+=bob
				for seat in f.seats:
					if seat.dead and seat.die_t>0.6:continue
					var anim:="pop" if seat.dead else ("throw" if seat.throw_t>0 else "walk")
					out.append_array(_sprite_commands(host,c,"bot",anim,mini(3,int(seat.die_t/0.14)) if seat.dead else (2 if seat.throw_t>0 else 0),Vector2(f.x+seat.offset,f.y+bob-36),1,maxf(0,1-seat.die_t/0.6) if seat.dead else 1.0,"",seat.flash>0,"holiday_banana_rider"))
				_ellipse(out,Vector2(x,y-30),Vector2(230,30),Color("f7d43a"),"holiday_banana_hull")
				_rect(out,Rect2(x-220,y-22,440,8),Color("e0b52a"),"holiday_banana_stripe")
				_ellipse(out,Vector2(x-232,y-36),Vector2(18,10),Color("5a7a2a"),"holiday_banana_tip")
				_ellipse(out,Vector2(x+232,y-36),Vector2(14,8),Color("5a7a2a"),"holiday_banana_tip")
				_rect(out,Rect2(x-120,y-52,80,5),Color(1,1,1,0.7),"holiday_banana_shine")
			"melon":
				if f.dead:continue
				_ellipse(out,Vector2(x,y-26),Vector2(26,26),Color("2f7d3a"),"holiday_melon")
				# Clip rotating stripe rectangles to the actual circular melon.
				for stripe in 5:
					var angle:float=-f.x/26+stripe*1.256
					var points:Array=[]
					for j in 17:
						var yy:float=-26+j*52.0/16;var half:=minf(3,sqrt(maxf(0,26*26-yy*yy)))
						points.append(Vector2(half,yy).rotated(angle)+Vector2(x,y-26))
					for j in range(16,-1,-1):
						var yy:float=-26+j*52.0/16;var half:=minf(3,sqrt(maxf(0,26*26-yy*yy)))
						points.append(Vector2(-half,yy).rotated(angle)+Vector2(x,y-26))
					_poly(out,points,Color("1f5a28"),"holiday_melon_stripe")
			"grab":
				if f.dead and f.die_t>0.8:continue
				out.append_array(_sprite_commands(host,c,"bot","pop" if f.dead else "walk",mini(3,int(f.die_t/0.12)) if f.dead else int(f.t/0.08)%6,Vector2(f.x,f.y),-f.face,maxf(0,1-(f.die_t-0.4)/0.4) if f.dead else 1.0,"",f.flash>0,"holiday_grabber"))
				if not f.dead and f.carry!=null:
					_rect(out,Rect2(x-30,y-150,60,16),Color("ff8fc7"),"holiday_carried_towel")
					for i in 4:_rect(out,Rect2(x-28+i*16,y-150,6,16),Color.WHITE,"holiday_towel_stripe")
				elif not f.dead:_rect(out,Rect2(x-3,y-140,6,6),Color("ff8fc7"),"holiday_grabber_marker")
	return out

func _build_wipe(host, runtime = null) -> Array:
	var out: Array = []
	if not supports(host.level_id) or not bool(_state(runtime, "wiping", false)): return out
	var time := float(_state(runtime, "wipe_elapsed", 0))
	if time < 0 or time >= 2.17: return out
	var closure := ease_iris(time / 0.52) if time < 0.52 else (1.0 if time < 1.57 else 1 - ease_iris((time - 1.57) / 0.6))
	if closure >= 1:
		_rect(out, Rect2(0, 0, WIDTH, HEIGHT), INK, "wipe_cover")
	elif closure > 0:
		if str(_state(runtime, "wipe_kind", "lift")) == "fade":
			_rect(out, Rect2(0, 0, WIDTH, HEIGHT), Color(INK, closure), "wipe_cover")
		else:
			var default_focus := Vector2(clampf((float(host.player.x) - float(host.camera.x)) * 1.3, WIDTH * 0.22, WIDTH * 0.78), HEIGHT * 0.6)
			var focus: Vector2 = _state(runtime, "wipe_focus_start" if time < 1.57 else "wipe_focus_end", default_focus)
			var far := maxf(maxf(focus.length(), Vector2(WIDTH - focus.x, focus.y).length()), maxf(Vector2(focus.x, HEIGHT - focus.y).length(), Vector2(WIDTH - focus.x, HEIGHT - focus.y).length()))
			var radius := far / 0.7 * (1 - closure)
			out.append({"type": "radial", "center": focus, "radii": [radius * 0.7, radius * 0.865, radius, far * 2],
				"colours": [Color(INK, 0), Color(INK, 0.55), INK, INK], "tag": "wipe_iris"})
			_rect(out, Rect2(0, 0, WIDTH, HEIGHT), Color(INK, closure * closure * 0.35), "wipe_dim")
	var label := str(_state(runtime, "wipe_label", "Ground floor"))
	if not label.is_empty() and time > 0.42 and time < 1.54:
		var alpha := (time - 0.42) / 0.22 if time < 0.64 else (1 - (time - 1.32) / 0.22 if time > 1.32 else 1.0)
		var k := ease_iris(clampf(alpha, 0, 1))
		var size := 46.0
		var text_width: float = host.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
		if text_width > WIDTH * 0.84: size *= WIDTH * 0.84 / text_width
		text_width = host.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
		var cy := HEIGHT * 0.47 + (1 - k) * (12 if time < 1.32 else -12)
		out.append({"type": "text", "position": Vector2(WIDTH / 2, cy + 4), "text": label, "size": int(size), "colour": Color(0, 0, 0, 0.45 * k), "tag": "wipe_label_shadow"})
		out.append({"type": "text", "position": Vector2(WIDTH / 2, cy), "text": label, "size": int(size), "colour": Color(Color("ffd23f"), k), "tag": "wipe_label"})
		var line_width := minf(WIDTH * 0.6, text_width * 0.7 + 40) * minf(1, k * 1.4)
		_rect(out, Rect2(source_round(WIDTH / 2 - line_width / 2), source_round(cy + size * 0.72), source_round(line_width), 3), Color(1, 210 / 255.0, 63 / 255.0, 0.7 * k), "wipe_label_rule")
	return out

func draw_commands(host, commands: Array) -> void:
	for command in commands:
		if command.type == "texture":
			# CanvasItem's negative destination width mirrors IN PLACE. Unlike
			# source Canvas2D translate(x+w)/scale(-1), it needs no x shift.
			# Shifting as well leaves alternating missing/overlapping sky tiles.
			var destination: Rect2 = command.rect
			if command.flip_h: destination.size.x = -destination.size.x
			host.draw_texture_rect_region(_nearest(host.images[command.key]), destination, command.source, Color(1,1,1,command.alpha))
		else: super.draw_commands(host, [command])
