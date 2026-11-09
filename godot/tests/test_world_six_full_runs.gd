extends SceneTree
## Production host, real input traversal/combat. Only invulnerability is assisted.
## No teleports, forced timers, enemy damage, wave edits, clears or receipt writes.
const SaveStore=preload("res://src/save_store.gd")
const DT:=1.0/60.0
var failures:Array[String]=[]
var trace:=false
var climb_target:=Vector2.ZERO
var stage_frames:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if not ok and label not in failures:failures.append(label)
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var args:=OS.get_cmdline_user_args()
	var stages:Array=["6-1","6-2","6-3","6-4","6-5","6-6","6-S"]
	var characters:Array=["jp"]
	trace="--trace" in args
	if "--all-characters" in args:characters=game.CHARACTERS
	for arg in args:
		if arg.begins_with("--stage="):stages=[arg.trim_prefix("--stage=")]
		if arg.begins_with("--character="):characters=[arg.trim_prefix("--character=")]
	var passed:=true
	for character in characters:
		for stage in stages:
			if not run_stage(game,stage,character):passed=false
	game.queue_free();await process_frame;await process_frame
	quit(0 if passed else 1)
func run_stage(g,id:String,character:String)->bool:
	failures.clear();climb_target=Vector2.ZERO
	g.character=character;g.save={"schema":1,"receipts":{},"skills":[],"kitty":0}
	check(SaveStore.write_save(g.save)==OK,"isolated save")
	check(g.load_level(id),"stage load")
	check(g._native_world_six() and g.is_native_supported(),"actual W6 dispatch")
	var source:=JSON.stringify(g.meta)
	var spawned:Array=[];var completed:Array=[];var mini_kind:="";var phases:Array=[]
	var end_frame:=-1;var ticks:=0
	for frame in range(60000):
		stage_frames=frame;ticks=frame+1
		g.invincible=999
		g.step(DT, controls_for(g,frame))
		for i in g.combat.waves.size():
			if g.combat.waves[i].started and i not in spawned:spawned.append(i)
			if g.combat.waves[i].done and i not in completed:completed.append(i)
		if not g.world_six.mini_boss.is_empty():mini_kind=g.world_six.mini_boss.kind
		if g.boss!=null and g.boss.state.phase not in phases:phases.append(g.boss.state.phase)
		if g.world_six.end_time>0 and end_frame<0:end_frame=frame
		if trace and frame%1800==0:print("BILLING ",id,"/",character," f=",frame," p=",g.player," cam=",g.camera," waves=",completed.size()," enemies=",g.enemies.filter(func(b):return b.state!="pop").map(func(b):return [b.p,b.hp,b.state])," fliers=",g.world_six.fliers.map(func(f):return [f.p,f.hp])," mini=",g.world_six.mini_boss," boss=",g.boss.state if g.boss!=null else {}," hold=",g.world_six.hold)
		if g.mode!="play":break
	check(g.mode=="clear","normal clear not reached")
	check(JSON.stringify(g.meta)==source,"metadata changed")
	if id!="6-S":check(completed.size()==g.combat.waves.size(),"not all source waves completed")
	check(SaveStore.read_save().get("cleared",{}).get(id,false),"normal clear not persisted")
	check(g.world_six.doors_used.size()==g.level.get("doors",[]).size(),"not all authored doors traversed")
	for index in g.world_six.RECEIPT_REPAIRS.get(id, {}):
		check(g.receipts[index].taken,"repaired receipt %d not collected through actual input"%index)
		check(index in SaveStore.read_save().receipts.get(id, []),"repaired receipt %d not persisted"%index)
	if id=="6-1":check(mini_kind=="franker" and g.world_six.mini_boss.state=="down","franker not defeated")
	if id=="6-3":check(mini_kind=="jammer" and g.world_six.mini_boss.state=="down","jammer not defeated")
	if id=="6-2":check(g.world_six.hold.done,"hold not survived")
	if id=="6-4":check(g.movement_skills.has_skill("super"),"super skill card not physically collected")
	if id=="6-6":check(phases.size()==3 and g.boss.state.jar.get("got",false),"all boss phases and real jar not completed")
	else:check(end_frame>=0 and ticks-1-end_frame>=155,"source delayed ending skipped")
	print("Billing input [",id,"/",character,"] ","PASS" if failures.is_empty() else "FAIL"," ticks=",ticks," waves=",completed.size(),"/",g.combat.waves.size()," receipts=",g.receipts.filter(func(r):return r.taken).size()," score=",g.score," p=",g.player," cam=",g.camera," phases=",phases," failures=",failures)
	return failures.is_empty()
func controls_for(g,frame:int)->Dictionary:
	var c:={"right":true,"left":false,"jump":false,"shoot":true,"aim":false,"down":false,"special":false}
	var w=g.world_six
	if g.level_id=="6-4":return climb_controls(g,c)
	if g.level_id=="6-5":
		var goal:float=g.camera.x+390
		c.right=g.player.x<goal-8;c.left=g.player.x>goal+8
		c.aim=true
		for h in w.hazards:
			if absf(h.x-g.player.x)<75:
				if h.kind=="beam":c.down=true;c.right=false;c.left=false
				elif g.grounded and not g.jump_held:c.jump=true
		return c
	if not g.receipts[0].taken and g.player.x>75 and g.camera.x==0 and frame<200:
		c.right=false;c.left=true;c.shoot=false;return c
	if g.level_id=="6-S":
		jump_obstacles(g,c)
		return c
	var target:Dictionary={}
	for b in g.enemies:
		if b.state=="pop" or b.p.x<g.camera.x+25 or b.p.x>g.camera.x+g.view_width()-25:continue
		if target.is_empty() or absf(b.p.x-g.player.x)<absf(target.x-g.player.x):target={"x":b.p.x,"y":b.p.y-60,"feet":b.p.y,"type":"bot"}
	for f in w.fliers:
		if f.state=="pop" or not f.entered:continue
		if target.is_empty():target={"x":f.p.x,"y":f.p.y,"feet":f.p.y+235,"type":"mailer"}
	if not w.mini_boss.is_empty() and w.mini_boss.state=="fight":
		var m:Dictionary=w.mini_boss
		if target.is_empty():target={"x":m.x,"y":m.y-100,"feet":m.y,"type":"mini"}
	if g.boss!=null:
		var b:Dictionary=g.boss.state
		if b.state=="down":
			if not b.jar.is_empty():c.right=g.player.x<b.jar.x-5;c.left=g.player.x>b.jar.x+5
			return c
		if b.state!="enter" and target.is_empty():target={"x":b.x,"y":b.fy-140,"feet":b.fy,"type":"boss"}
	if not target.is_empty():
		var dx:float=target.x-g.player.x
		var dy:float=g.player.y-g.character_height()*0.7-target.y
		var aim:bool=dy>50
		var want:float=clampf(dy+g.character_height()*0.36,100,300) if aim else 200
		c.aim=aim
		c.right=dx>want+25;c.left=dx < -want-25
		# Do not retreat from ordinary ground bots: retreating onto the plinth
		# behind us can synchronize jump/shot cooldowns into an endless loop.
		if absf(dx)<want-35 and target.type!="bot":c.right=dx<0;c.left=dx>0
		if not c.right and not c.left and g.face!=(1 if dx>=0 else -1):c.right=dx>=0;c.left=dx<0
		if g.player.y<target.feet-35 and target.type=="bot":
			# Walk across the raised run toward the foe, not the nearest floor
			# behind us. Backtracking across pallet/cage pairs creates a loop.
			c.right=dx>8;c.left=dx < -8;c.aim=false
			if absf(dx)<30 and g.on_platform and not g.jump_held:c.down=true;c.jump=true
		if target.type=="bot" and target.feet<g.player.y-30:
			# Close onto the raised surface instead of holding a flat-fire range
			# whose muzzle can sit just below the bot for shorter characters.
			c.right=dx>8;c.left=dx < -8;c.aim=false
			if g.grounded and not g.jump_held:c.jump=true
	# At the camera edge, backing away would face away forever while clamped.
		# Turn into the target instead; this is controller navigation, not game logic.
		if (c.right and g.player.x>=g.camera.x+g.view_width()-35) or (c.left and g.player.x<=g.camera.x+35):
			c.right=dx>0;c.left=dx<0
	# Keep lift-door enemies in range, never let controller camp behind the wall.
	jump_obstacles(g,c)
	if g.abilities.meter>=1 and frame%60==0:c.special=true
	return c
func jump_obstacles(g,c:Dictionary)->void:
	if not g.grounded or g.jump_held:return
	var direction:=1 if c.right else -1 if c.left else 0
	if direction==0:return
	var next_x:float=g.player.x+direction*55
	var wall:float=g.world_six.wall_clamp(g,g.player.x,next_x,g.player.y)
	if absf(wall-next_x)>0.1:c.jump=true;c.down=false
func climb_controls(g,c:Dictionary)->Dictionary:
	c.right=false;c.left=false;c.aim=true
	if g.grounded:
		climb_target=Vector2.ZERO
		var best_y:=-INF
		for s in g.world_six.surfaces(g):
			var dy:float=g.player.y-s.row[2]
			if dy<=4 or dy>146:continue
			var xx:=clampf(g.player.x,float(s.row[0])+30,float(s.row[1])-30)
			if absf(xx-g.player.x)>190:continue
			if float(s.row[2])>best_y:
				best_y=s.row[2];climb_target=Vector2(xx,s.row[2])
		# The wide landing before card crosses its real collection radius.
		if g.player.y>=-5560 and g.player.y<=-5540 and not g.movement_skills.has_skill("super"):
			c.right=g.player.x<369-5;c.left=g.player.x>369+5;return c
		if climb_target!=Vector2.ZERO:
			var dx:float=climb_target.x-g.player.x
			c.right=dx>4;c.left=dx < -4
			if absf(dx)<125 and not g.jump_held:c.jump=true
	elif climb_target!=Vector2.ZERO:
		c.right=g.player.x<climb_target.x-4;c.left=g.player.x>climb_target.x+4
	return c
