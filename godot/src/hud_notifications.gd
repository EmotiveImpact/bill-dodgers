extends RefCounted
## Presentation only. Source banners and Go hint, with seconds replacing ms.
var banner: Dictionary = {}
var go_time := 0.0

func reset() -> void:
	banner.clear()
	go_time = 0

func show_banner(text: String, sub := "", warning := false) -> void:
	if text.is_empty() and sub.is_empty(): return
	banner = {"text":text,"sub":sub,"warn":warning,"age":0.0}

func show_go(duration := 2.2) -> void: go_time = duration

func step(delta: float) -> void:
	go_time = maxf(0, go_time - delta)
	if not banner.is_empty():
		banner.age += delta
		if banner.age > 2.9: banner.clear()

func build_commands(viewport := Vector2(960,540), ending := false) -> Array:
	var out: Array = []
	if go_time > 0 and not ending and int(go_time / 0.3) % 2 == 0:
		_text(out,Vector2(viewport.x-110,viewport.y/2-10),"Go!",34,Color("f4c542"),"go_label")
		out.append({"type":"polygon","points":PackedVector2Array([Vector2(viewport.x-60,viewport.y/2-10),Vector2(viewport.x-84,viewport.y/2-30),Vector2(viewport.x-84,viewport.y/2+10)]),"colour":Color("f4c542"),"tag":"go_arrow"})
	if banner.is_empty(): return out
	var age: float = banner.age
	var alpha := clampf(age / 0.3 if age < 0.3 else (1-(age-2.4)/0.4 if age > 2.4 else 1.0),0,1)
	if alpha <= 0: return out
	out.append({"type":"rect","rect":Rect2(0,viewport.y/2-60,viewport.x,110),"colour":Color(Color("781414") if banner.warn else Color("0e1726"),0.75*alpha),"tag":"banner_back"})
	if banner.warn:
		for i in range(-2,24):
			var x:=i*44+fmod(age*125,44)
			out.append({"type":"polygon","points":PackedVector2Array([Vector2(x,viewport.y/2-60),Vector2(x+20,viewport.y/2-60),Vector2(x,viewport.y/2-50)]),"colour":Color(Color("f4c542"),alpha),"tag":"banner_warning_stripe"})
	_text(out,Vector2(viewport.x/2,viewport.y/2-16),banner.text,36,Color(Color("ffd2d2") if banner.warn else Color("f4c542"),alpha),"banner_title")
	_text(out,Vector2(viewport.x/2,viewport.y/2+26),banner.sub,16,Color(Color("f5f1ea"),alpha),"banner_sub")
	return out

func _text(out: Array, position: Vector2, text: String, size: int, colour: Color, tag: String) -> void:
	out.append({"type":"text","position":position,"text":text,"size":size,"colour":colour,"center":true,"outline":true,"tag":tag})
