extends SceneTree
## Actual production-main input routes. Invulnerability is the sole assist.
## No teleports, health/wave/foe edits, forced timers, pickups or clears.
## This verifies progression, not human difficulty or physical mobile devices.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 60000
const STAGES := ["4-1", "4-2", "4-3", "4-4", "4-5", "4-S"]
var failures: Array[String] = []
var debug_run := false
var opening_done := false
var totals := {"ticks": 0, "waves": 0, "entries": 0, "receipts": 0, "gates": 0, "sets": 0, "falls": 0, "clears": 0}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok and label not in failures: failures.append(label)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Holiday input: production main failed to load")
		game.free()
		quit(1)
		return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var args := OS.get_cmdline_user_args()
	var characters: Array = game.CHARACTERS
	var stages: Array = STAGES
	if "--jp-only" in args: characters = ["jp"]
	debug_run = "--trace" in args
	for arg in args:
		if arg.begins_with("--stage="): stages = [arg.trim_prefix("--stage=")]
		if arg.begins_with("--character="): characters = [arg.trim_prefix("--character=")]
	if not characters.all(func(c): return c in game.CHARACTERS) or not stages.all(func(s): return s in STAGES):
		printerr("Holiday input: unknown housemate or stage filter")
		game.queue_free()
		await process_frame
		quit(1)
		return
	var passed := 0
	for character in characters:
		for stage in stages:
			if run_stage(game, stage, character): passed += 1
	var expected := characters.size() * stages.size()
	print("Holiday input matrix: ", passed, "/", expected, " routes passed; totals=", totals)
	game.queue_free()
	await process_frame
	quit(0 if passed == expected else 1)

func run_stage(game, stage: String, character: String) -> bool:
	failures.clear()
	opening_done = false
	game.character = character
	game.save = {"schema": 1, "receipts": {}, "skills": [], "kitty": 0}
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(game.load_level(stage), "stage load failed")
	check(game._native_world_four() and game.is_native_supported(), "actual native dispatch missing")
	if not failures.is_empty():
		printerr("Holiday input [", stage, "/", character, "] FAIL: ", failures)
		return false
	check(game.movement_skills.skills.is_empty(), "inherited unearned movement skills")
	var source := JSON.stringify(game.meta)
	var starts: Array = []
	var dones: Array = []
	var receipts: Array = []
	var gates: Array = []
	var foe_kinds: Array = []
	var ending_frame := -1
	var jumps := 0
	var falls := 0
	var ticks := 0
	var dash_activations := 0
	var planned := 0
	for wave in game.combat.waves: planned += wave.group.size()
	for frame in MAX_TICKS:
		ticks = frame + 1
		game.invincible = 999 # Sole progression assist; combat still runs normally.
		var controls := controls_for(game, frame)
		var grounded: bool = game.grounded
		var old_position: Vector2 = game.player
		var old_hearts: int = game.hearts
		var old_dash_cooldown:float=game.movement_skills.dash_cooldown
		game.step(DT, controls)
		if game.movement_skills.dash_cooldown>old_dash_cooldown+0.1:dash_activations+=1
		if debug_run and game.hearts < old_hearts:
			print("HURT ", frame, " from=", old_position, " to=", game.player, " hearts=", game.hearts, " input=", controls)
		if grounded and not game.grounded and game.velocity.y < 0:
			jumps += 1
			if debug_run and stage == "4-4": print("JUMP ", frame, " from=", old_position, " to=", game.player, " velocity=", game.velocity, " input=", controls)
		if old_position.y > float(game.level.fall) - 80 and game.player.y < old_position.y - 100:
			falls += 1
			if debug_run: print("FALL ", frame, " from=", old_position, " to=", game.player, " hearts=", game.hearts)
		for i in game.combat.waves.size():
			var wave: Dictionary = game.combat.waves[i]
			if wave.started and i not in starts: starts.append(i)
			if wave.done and i not in dones:
				dones.append(i)
				check(wave.index == wave.group.size(), "wave finished before consuming all source entries")
		for i in game.receipts.size():
			if game.receipts[i].taken and i not in receipts:
				receipts.append(i)
				if debug_run: print("PICK ", stage, " receipt=", i, " position=", game.player, " frame=", frame)
		for i in game.world_four.gates.size():
			if game.world_four.gates[i].passed and i not in gates: gates.append(i)
		for foe in game.world_four.foes.entries:
			if foe.kind not in foe_kinds: foe_kinds.append(foe.kind)
		if game.world_four.end_time > 0 and ending_frame < 0: ending_frame = frame
		if debug_run and frame % 1200 == 0:
			print("HOLIDAY ", stage, "/", character, " frame=", frame, " position=", game.player, " camera=", game.camera, " waves=", dones.size(), " foes=", game.world_four.foes.snapshot(), " bots=", game.enemies.filter(func(b): return b.state != "pop").map(func(b): return [b.p, b.hp, b.state]), " hold=", game.world_four._hold_snapshot())
		if game.mode != "play": break
	var consumed := 0
	for wave in game.combat.waves: consumed += wave.index
	var sets: Array = game.level.get("cfg", {}).get("sets", [])
	var completed_sets := 0
	for encounter in sets:
		if game.world_four.set_done.has(encounter.id): completed_sets += 1
	var saved := SaveStore.read_save()
	var saved_receipts: Array = saved.get("receipts", {}).get(stage, [])
	var sorted_receipts := receipts.duplicate()
	sorted_receipts.sort()
	saved_receipts.sort()
	check(game.mode == "clear", "actual clear not reached")
	check(JSON.stringify(game.meta) == source, "runtime mutated imported content")
	check(gates.size() == game.level.get("gates", []).size(), "authored gate not traversed")
	check(starts.size() == game.combat.waves.size(), "not all source waves started")
	check(dones.size() == game.combat.waves.size(), "not all source waves finished")
	check(consumed == planned, "not all source wave entries consumed")
	check(completed_sets == sets.size(), "not all authored encounters reached")
	check(receipts.size() == 3, "all three receipts not physically collected")
	check(saved.get("cleared", {}).get(stage, false), "normal clear not saved")
	check(saved_receipts == sorted_receipts, "receipt persistence mismatch")
	if stage == "4-4":
		check(game.movement_skills.has_skill("dash") and "dash" in saved.get("skills", []), "actual dash card not earned and saved")
		check(dash_activations>0,"earned Dash never activated through input")
	if stage == "4-S":
		check(game.world_four.dash.gates.all(func(g):return g.got) and game.world_four.dash.mult==9,"all eight bonus time gates not physically crossed")
		check(game.world_four.dash.over and game.world_four.dash.left>0 and game.world_four.dash.bonus>0,"finish route did not earn remaining-time bonus")
	if stage == "4-3": check(game.world_four.hold.over and game.world_four.hold.mini, "hold and halfway Bailiff not reached")
	if stage == "4-5": check("banana" in foe_kinds, "banana encounter not reached")
	check(ending_frame >= 0 and ticks - 1 - ending_frame >= 155, "source delayed ending skipped")
	totals.ticks += ticks
	totals.waves += dones.size()
	totals.entries += consumed
	totals.receipts += receipts.size()
	totals.gates += gates.size()
	totals.sets += completed_sets
	totals.falls += falls
	if game.mode == "clear": totals.clears += 1
	print("Holiday input [", stage, "/", character, "] ", "PASS" if failures.is_empty() else "FAIL", " ticks=", ticks, " waves=", dones.size(), "/", game.combat.waves.size(), " entries=", consumed, "/", planned, " receipts=", receipts, " gates=", gates, " sets=", completed_sets, "/", sets.size(), " jumps=", jumps, " dashes=",dash_activations," falls=", falls, " foe_types=", foe_kinds, " score=", game.score, " position=", game.player, " camera=", game.camera, " failures=", failures)
	return failures.is_empty()

func controls_for(game,frame:int)->Dictionary:
	var c:={"right":true,"left":false,"jump":false,"shoot":true,"down":false,"aim":false,"special":false,"dash":false}
	var rt=game.world_four
	# Physically walk back to the actual first receipt, including the named
	# 4-2 repair. No camera relaxation or position rewrite is used.
	if not opening_done:
		if game.level_id in ["4-1","4-2","4-3","4-S"] and not game.receipts[0].taken:
			c.left=true;c.right=false;c.shoot=false
			return c
		opening_done=true
	var auto:bool=bool(game.level.get("auto",0))
	var target:Dictionary={}
	for b in game.enemies:
		if b.state=="pop" or b.p.x<game.camera.x+15 or b.p.x>game.camera.x+game.view_width()-15:continue
		if target.is_empty() or absf(b.p.x-game.player.x)<absf(target.p.x-game.player.x):target={"p":b.p,"kind":"bot"}
	for f in rt.foes.entries:
		if f.dead or not rt.foes.hittable(f) or f.x<game.camera.x+15 or f.x>game.camera.x+game.view_width()-15:continue
		if f.kind=="banana":
			for seat in f.seats:
				if seat.dead:continue
				var p:=Vector2(f.x+seat.offset,f.y)
				if target.is_empty() or absf(p.x-game.player.x)<absf(target.p.x-game.player.x):target={"p":p,"kind":"banana"}
		elif target.is_empty() or absf(f.x-game.player.x)<absf(target.p.x-game.player.x):target={"p":Vector2(f.x,f.y),"kind":f.kind}
	# Only stop for live encounters when geometry permits. On automatic
	# harbour/boat stages remain central while firing at the visible target.
	if not target.is_empty():
		var dx:float=target.p.x-game.player.x
		c.right=dx>210;c.left=dx < -210
		if game.face!=(1 if dx>=0 else -1):c.right=dx>=0;c.left=dx<0
		if game.grounded and game.player.y<target.p.y-35 and not auto:
			# Descend to the bot's source floor instead of firing over its head.
			# Overlapping old-town stair solids require retreat, not always right.
			var goal:=INF
			for distance in range(30,600,20):
				for sign_x in [-1,1]:
					var x:float=game.player.x+distance*sign_x
					if x<game.camera.x+35 or x>game.camera.x+game.view_width()-35:continue
					var q:Dictionary=rt.below(game,x,-9999)
					if not q.is_empty() and q.row[2]>=target.p.y-10 and q.row[2]<=target.p.y+30:
						goal=x;break
				if goal!=INF:break
			if goal!=INF:c.right=goal>game.player.x;c.left=goal<game.player.x;c.descending=true
			else:c.right=true;c.left=false
		if target.kind in ["jet","ring","melon","case"] and absf(game.player.y-target.p.y)<65:c.down=true;c.right=false;c.left=false
		if target.p.y<game.player.y-80:
			c.aim=true;c.right=dx>0;c.left=dx<0
		if auto and game.level_id=="4-4" and not rt.foes.pause_camera(true):
			c.right=game.player.x<game.camera.x+500;c.left=false;c.down=false
		if auto and game.level_id=="4-5" and not rt.foes.pause_camera(true):
			var desired:float=game.camera.x+430
			c.right=game.player.x<desired-10;c.left=game.player.x>desired+10
			if not c.right and not c.left and game.face!=(1 if dx>=0 else -1):c.right=dx>=0;c.left=dx<0
	elif auto:
		var desired:float=game.camera.x+(430 if game.level_id=="4-5" else 500)
		c.right=game.player.x<desired-10;c.left=game.player.x>desired+10
	if not target.is_empty() and c.down and game.face != (1 if target.p.x>=game.player.x else -1):
		c.down=false;c.right=target.p.x>=game.player.x;c.left=target.p.x<game.player.x
	if game.level_id=="4-4" and not rt.foes.pause_camera(true):
		c.right=not game.grounded or game.player.x<game.camera.x+500;c.left=false;c.down=false
	# Old town's final encounter overlaps two narrow stair solids with
	# its broad bot floor. Retreat onto the exposed end of that floor, so
	# the bots approach into a real horizontal firing lane.
	if game.level_id == "4-2" and game.combat.waves[-1].started and not game.combat.waves[-1].done:
		var anchor := 15548.0
		c.right = game.player.x < anchor - 6
		c.left = game.player.x > anchor + 6
		c.down = false
		c.aim = false
		c.descending = true
		if not c.right and not c.left and not target.is_empty() and game.face != (1 if target.p.x >= game.player.x else -1):
			c.right = target.p.x >= game.player.x
			c.left = target.p.x < game.player.x
	# Jump toward nearby untaken elevated receipts before passing their x.
	for receipt in game.receipts:
		if receipt.taken or receipt.position.x<game.camera.x+35:continue
		var dx:float=receipt.position.x-game.player.x
		if dx>=-25 and dx<100 and game.player.y>=receipt.position.y+game.character_height()-10:
			if game.grounded and not game.jump_held:c.jump=true
			c.down=false;c.right=dx>8;c.left=dx < -8
			break
	if game.level_id=="4-4" and not game.movement_skills.has_skill("dash") and absf(game.player.x-float(game.level.card[0]))<100:
		if game.grounded and not game.jump_held:c.jump=true
		c.down=false;c.right=true;c.left=false
	if game.grounded and not game.jump_held:
		var direction:=1 if c.right or (game.level_id=="4-4" and game.velocity.x>10) else (-1 if c.left else 0)
		if direction!=0:
			var next_x:float=game.player.x+direction*(maxf(25,(270+absf(game.velocity.x))*DT+10) if game.level_id=="4-4" else 55)
			var wall:float=rt.wall_clamp(game,game.player.x,next_x,game.player.y)
			var floor:Dictionary=rt.below(game,next_x,game.player.y-2)
			if absf(wall-next_x)>0.1 or floor.is_empty() or (floor.row[2]>game.player.y+30 and not c.get("descending",false)):
				c.jump=true;c.down=false
		# A foot-level obstacle also needs a jump when combat wishes to stop
		# exactly at the wall; do not manufacture a surface or skip an enemy.
		if not c.jump and not target.is_empty() and target.p.y<game.player.y-80:
			c.jump=true;c.down=false
	if game.level_id=="4-4" and not rt.foes.pause_camera(true):
		# Keep forward momentum throughout harbour jumps. Steering toward a
		# screen-space comfort point midair can turn a valid gap jump around.
		c.right=not game.grounded or game.player.x<game.camera.x+500;c.left=false;c.down=false
	if game.level_id=="4-4" and game.movement_skills.has_skill("dash") and c.jump:c.dash=true
	if game.level_id == "4-4" and game.character == "leo" and not game.grounded:
		# Hold the real jump input for Leo's slow fall and powered glider.
		c.jump = true
		c.down = false
	if game.level_id == "4-5":
		# Staying aboard takes precedence over turning or crouching to shoot.
		# Down suppresses movement, even when a direction is also held.
		var desired: float = game.camera.x + 430
		c.right = game.player.x < desired - 10
		c.left = game.player.x > desired + 10
		c.jump = false
		if c.right or c.left: c.down = false
		elif not target.is_empty() and game.face != (1 if target.p.x >= game.player.x else -1):
			c.down = false
			c.right = target.p.x >= game.player.x
			c.left = target.p.x < game.player.x
	if game.abilities.meter>=1 and frame%60==0:c.special=true
	return c
