extends Node2D
## Ordered GPU world-front passes. Place after the world and before UI.
## Parent calls refresh after simulation, and hides on other stages/menus.

class Pass extends Node2D:
	var painter
	var host
	var commands: Array = []
	var material_pass := false
	var draw_count := 0
	func _draw() -> void:
		if painter == null or host == null: return
		if material_pass:
			for command in commands: painter.draw_material_command(self,command)
		else:
			# Standard primitives need host assets/font, but must target THIS
			# CanvasItem. Proxy forwards drawing and reads original resources.
			painter.draw_commands(DrawProxy.new(self,host),commands)
		draw_count += 1

class DrawProxy extends RefCounted:
	var canvas: CanvasItem
	var images: Dictionary
	var font: Font
	func _init(target: CanvasItem, host) -> void:
		canvas=target
		images=host.images
		font=host.font
	func draw_texture_rect_region(texture,rect,source,colour): canvas.draw_texture_rect_region(texture,rect,source,colour)
	func draw_rect(rect,colour): canvas.draw_rect(rect,colour)
	func draw_colored_polygon(points,colour): canvas.draw_colored_polygon(points,colour)
	func draw_polygon(points,colours): canvas.draw_polygon(points,colours)
	func draw_polyline(points,colour,width): canvas.draw_polyline(points,colour,width)
	func draw_style_box(style,rect): canvas.draw_style_box(style,rect)
	func draw_string(f,p,t,a,w,s,c): canvas.draw_string(f,p,t,a,w,s,c)
	func draw_string_outline(f,p,t,a,w,s,o,c): canvas.draw_string_outline(f,p,t,a,w,s,o,c)

var host
var painter
var passes: Array[Pass] = []
var phase := "front"

func configure(source_host, renderer, draw_phase: String = "front") -> void:
	host=source_host
	painter=renderer
	phase=draw_phase
	show_behind_parent=phase=="level"

func refresh(runtime = null, supplied: Array = []) -> void:
	if host == null or painter == null: return
	visible = host.level_id=="3-3" and host.mode in ["play","paused","clear","over"]
	if not visible:
		for node in passes: node.visible=false; node.commands=[]
		return
	var commands: Array = supplied
	if commands.is_empty():
		if phase=="level":
			commands=painter.build_sky(host,runtime)
			commands.append_array(painter.build_level(host,runtime))
		else: commands=painter.build_front(host,runtime)
	# Same bottom-anchored logical world transform used by main._draw.
	transform=Transform2D(0,Vector2.ONE*1.3,0,Vector2(-host.camera.x*1.3,540*(1-1.3)-host.camera.y*1.3))
	if "visual_feedback" in host: transform.origin += host.visual_feedback.offset
	var batches: Array = []
	var ordinary: Array = []
	for command in commands:
		if command.type in ["night_darkness","night_glow","night_additive"]:
			if not ordinary.is_empty(): batches.append({"commands":ordinary,"material":false}); ordinary=[]
			batches.append({"commands":[command],"material":true})
		else: ordinary.append(command)
	if not ordinary.is_empty(): batches.append({"commands":ordinary,"material":false})
	while passes.size()<batches.size():
		var node := Pass.new()
		node.name="NightPass%d"%passes.size()
		passes.append(node)
		add_child(node)
	for i in passes.size():
		var node := passes[i]
		node.visible=i<batches.size()
		if not node.visible: continue
		node.painter=painter
		node.host=host
		node.commands=batches[i].commands
		node.material_pass=batches[i].material
		node.material=painter.material_for(node.commands[0]) if node.material_pass else null
		node.queue_redraw()
