extends RefCounted
## Test-only ordinary-input drivers copied from the certified solo route suites.
## Game state is read only. The runner records actual stomp/pound events.
## Night/Tout solo pattern-observation holds are disabled: an independent CPU
## can keep firing, so those observation holds are not a valid co-op controller.

class Field:
	extends RefCounted
	# Source control functions: res://tests/test_full_festival_field_run.gd
	const LOWER_ROUTE := [Vector2(1300,482), Vector2(1600,428), Vector2(1800,374), Vector2(2200,482), Vector2(3900,482), Vector2(4800,428), Vector2(5060,374), Vector2(5400,482), Vector2(5900,482), Vector2(7010,482)]
	const UPPER_ROUTE := [Vector2(8310,428), Vector2(8440,374), Vector2(8580,246), Vector2(8700,246), Vector2(8950,482), Vector2(9250,482), Vector2(9420,428), Vector2(9750,482), Vector2(10600,428), Vector2(10800,374), Vector2(11100,482), Vector2(11510,428), Vector2(11640,374), Vector2(11780,246), Vector2(11900,246), Vector2(12200,482), Vector2(12700,482), Vector2(13200,428), Vector2(13400,374), Vector2(13550,482), Vector2(13720,428), Vector2(13840,374), Vector2(13980,246), Vector2(14100,246), Vector2(14400,482), Vector2(14900,482), Vector2(15200,428), Vector2(15580,482)]
	var route_step := 0
	var route_scene := 0
	var stomp_confirmed := false
	var debug_run := false

	func walk(game, controls: Dictionary, x: float, tolerance := 4.0) -> void:
		controls.right = x-game.player.x > tolerance
		controls.left = x-game.player.x < -tolerance

	func navigate(game, controls: Dictionary, goal: Vector2) -> void:
		walk(game,controls,goal.x)
		if not game.grounded or game.jump_held: return
		var dx: float = goal.x-game.player.x
		var forward := 1 if dx >= 0 else -1
		if goal.y < game.player.y-6 and absf(dx) < 110: controls.jump = true
		for row in game.level.solids:
			if row[2] >= game.player.y-6: continue
			var edge: float = row[0] if forward > 0 else row[1]
			var distance: float = (edge-game.player.x)*forward
			if distance >= 0 and distance < 65 and absf(dx) > distance: controls.jump = true
		if goal.y > game.player.y+6 and game.on_platform and absf(dx) < 10:
			controls.down = true
			controls.jump = true

	func controls_for(game, frame: int) -> Dictionary:
		var controls := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
		if game.world_three.wiping and game.world_three.scene_index == 0: return controls
		if route_scene != game.world_three.scene_index:
			route_scene = game.world_three.scene_index
			route_step = 0
		# Normal standing muzzles are above the70px crate. Use actual crouch-fire
		# from the approach, then walk into the naturally spawned wellies item.
		if route_scene == 0 and route_step == 0 and game.player.x > 1100 and not game.crates[0].broken:
			controls.down = true
			if game.face != 1: controls.right = true
			return controls
		var route: Array = LOWER_ROUTE if route_scene == 0 else UPPER_ROUTE
		if route_step < route.size():
			var goal: Vector2 = route[route_step]
			if game.grounded and absf(game.player.x-goal.x) < 15 and absf(game.player.y-goal.y) < 1:
				route_step += 1
				if debug_run: print("Festival route=",route_scene,"/",route_step," frame=",frame," p=",game.player)
		if route_step < route.size(): navigate(game,controls,route[route_step])
		else: walk(game,controls,7010 if route_scene == 0 else 15580)
		if game.boss != null:
			var b: Dictionary = game.boss.state
			if game.player.y < 450: return controls # Walk off the real van roof before fighting.
			if b.state != "down":
				controls.left = false
				controls.right = false
				controls.jump = false
				controls.down = false
				if game.face != (1 if b.x >= game.player.x else -1):
					controls.right = b.x >= game.player.x
					controls.left = b.x < game.player.x
			return controls
		if game.power == "wellies" and not stomp_confirmed: controls.shoot = false
		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.state == "pop": continue
			if target.is_empty() or absf(enemy.p.x-game.player.x) < absf(target.p.x-game.player.x): target = enemy
		if not target.is_empty():
			var dx: float = target.p.x-game.player.x
			var dy: float = target.p.y-game.player.y
			if game.power == "wellies" and not stomp_confirmed and absf(dx) < 400 and absf(dy) < 160:
				controls.shoot = false
				walk(game,controls,target.p.x,4)
				controls.jump = game.grounded and not game.jump_held and absf(dx) < 95
				return controls
			if absf(dy) < 70 and game.grounded:
				controls.left = false
				controls.right = false
				controls.jump = false
				if game.face != (1 if dx >= 0 else -1):
					controls.right = dx >= 0
					controls.left = dx < 0
				# An input-only wellies attempt. Do not count a pop as a stomp unless
				# the actual descending overlap and -800 bounce were both observed.
				if game.power == "wellies" and absf(dx) < 150 and not game.jump_held:
					controls.shoot = false
					controls.jump = true
					walk(game,controls,target.p.x,4)
			elif game.power == "wellies" and not game.grounded and absf(dx) < 160 and absf(dy) < 160:
				controls.shoot = false
				walk(game,controls,target.p.x,4)
			elif dy < -70: controls.aim = true
			if frame%300 == 0 and absf(dy) < 70: controls.down = true
		return controls
	func controls(game, frame: int) -> Dictionary:
		return controls_for(game, frame)

class Queue:
	extends RefCounted
	# Source control functions: res://tests/test_full_festival_queue_run.gd
	var receipt_jump := false
	var receipt_airborne := false

	func controls_for(game) -> Dictionary:
		var c := {"left":false,"right":false,"down":false,"jump":false,"shoot":true,"aim":false,"special":false}
		if game.world_three.wiping: return c
		if receipt_jump:
			if not game.grounded: receipt_airborne = true
			if receipt_airborne and game.grounded:
				receipt_jump = false
				receipt_airborne = false
			else: return c
		c.right = game.player.x < game.camera.x+320
		# Banners stop ordinary walking while ducked. The source's scrolling
		# left clamp legitimately carries a crouching player under each banner.
		for row in game.level.duck:
			if game.player.x >= row[0]-20 and game.player.x <= row[1]+12:
				c.down = true
				return c
		# Receipt centers are reached by ordinary ground/crowd jumps. Wait above
		# the center until picked, then resume walking. No pickup edits.
		for receipt in game.receipts:
			if not receipt.taken and absf(receipt.position.x-game.player.x) < 20:
				c.right = false
				c.jump = game.grounded and not game.jump_held
				if c.jump: receipt_jump = true
				return c
		if game.grounded and not game.jump_held:
			for gap in game.level.gaps:
				if gap[0]-game.player.x > 0 and gap[0]-game.player.x < 30:
					c.jump = true
					c.right = true
			for row in game.level.solids:
				if row[2] < game.player.y-6 and row[0]-game.player.x >= 0 and row[0]-game.player.x < 62:
					c.jump = true
					c.right = true
		if not game.grounded: c.right = true
		return c
	func controls(game, _frame: int) -> Dictionary:
		return controls_for(game)

class Night:
	extends RefCounted
	# Source control functions: res://tests/test_full_festival_night_run.gd
	const LOWER_ROUTE := [Vector2(1350,482), Vector2(1760,428), Vector2(2000,374), Vector2(2300,482), Vector2(3750,482), Vector2(4200,482), Vector2(4680,428), Vector2(4900,374), Vector2(5240,374), Vector2(5400,319), Vector2(5450,319), Vector2(5800,482), Vector2(7010,482)]
	const UPPER_ROUTE := [Vector2(8400,482), Vector2(9000,482), Vector2(9700,428), Vector2(10050,374), Vector2(10440,374), Vector2(10600,322), Vector2(10650,322), Vector2(11100,482), Vector2(12000,482), Vector2(12300,428), Vector2(12500,374), Vector2(13050,374), Vector2(13200,319), Vector2(13300,319), Vector2(13800,482), Vector2(14400,482), Vector2(14700,428), Vector2(15180,482)]
	var route_step := 0
	var route_scene := 0
	var debug_run := false
	var boss_patterns_seen := true

	func walk(game, controls: Dictionary, x: float, tolerance := 4.0) -> void:
		controls.right = x-game.player.x > tolerance
		controls.left = x-game.player.x < -tolerance

	func navigate(game, controls: Dictionary, goal: Vector2) -> void:
		walk(game,controls,goal.x)
		if not game.grounded or game.jump_held: return
		var dx: float = goal.x-game.player.x
		var forward := 1 if dx >= 0 else -1
		if goal.y < game.player.y-6 and absf(dx) < 110: controls.jump = true
		for row in game.level.solids:
			if row[2] >= game.player.y-6: continue
			var edge: float = row[0] if forward > 0 else row[1]
			var distance: float = (edge-game.player.x)*forward
			if distance >= 0 and distance < 65 and absf(dx) > distance: controls.jump = true
		if goal.y > game.player.y+6 and game.on_platform and absf(dx) < 10:
			controls.down = true
			controls.jump = true

	func controls_for(game, frame: int) -> Dictionary:
		var controls := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
		if game.world_three.wiping and game.world_three.scene_index == 0: return controls
		if route_scene != game.world_three.scene_index:
			route_scene = game.world_three.scene_index
			route_step = 0
		var route: Array = LOWER_ROUTE if route_scene == 0 else UPPER_ROUTE
		if route_step < route.size():
			var goal: Vector2 = route[route_step]
			if game.grounded and absf(game.player.x-goal.x) < 15 and absf(game.player.y-goal.y) < 1:
				route_step += 1
				if debug_run: print("Festival route=",route_scene,"/",route_step," frame=",frame," p=",game.player)
		if route_step < route.size(): navigate(game,controls,route[route_step])
		else: walk(game,controls,7010 if route_scene == 0 else 15180)
		if game.boss != null:
			var b: Dictionary = game.boss.state
			controls.shoot = boss_patterns_seen
			if game.player.y < 450: return controls # Walk off the real van roof before fighting.
			if b.state != "down":
				controls.left = false
				controls.right = false
				controls.jump = false
				controls.down = false
				if game.face != (1 if b.x >= game.player.x else -1):
					controls.right = b.x >= game.player.x
					controls.left = b.x < game.player.x
			if b.state != "down": return controls

		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.state == "pop": continue
			if target.is_empty() or absf(enemy.p.x-game.player.x) < absf(target.p.x-game.player.x): target = enemy
		if not target.is_empty():
			var dx: float = target.p.x-game.player.x
			var dy: float = target.p.y-game.player.y
			if absf(dy) < 70 and game.grounded:
				controls.left = false
				controls.right = false
				controls.jump = false
				if game.face != (1 if dx >= 0 else -1):
					controls.right = dx >= 0
					controls.left = dx < 0
			elif dy < -70: controls.aim = true
			if frame%300 == 0 and absf(dy) < 70: controls.down = true
		for fire in game.level.fires:
			var distance: float = float(fire[0])-game.player.x
			if distance > -65 and distance < 70 and game.player.y > float(fire[1])-95:
				controls.left = false
				controls.right = true
				controls.down = false
				if game.grounded and not game.jump_held: controls.jump = true
		return controls
	func controls(game, frame: int) -> Dictionary:
		return controls_for(game, frame)

class BigTop:
	extends RefCounted
	# Source control functions: res://tests/test_full_big_top_run.gd
	const ROUTE := [Vector2(1550,392),Vector2(1750,302),Vector2(1950,212),Vector2(2285,94),Vector2(2285,-24),Vector2(2285,-142),Vector2(2430,-218),Vector2(2800,-218),Vector2(3190,-158),Vector2(3500,-218),Vector2(3900,-218),Vector2(4085,-158),10,11,12,13,Vector2(5510,-226),Vector2(5700,-278),Vector2(6000,-278),Vector2(6590,-218),Vector2(7100,-278),Vector2(7900,-158),Vector2(8350,482),Vector2(9000,482),Vector2(9500,364),Vector2(9500,246),Vector2(9500,128),Vector2(9500,10),Vector2(9500,-108),Vector2(9500,-226),Vector2(9700,-338),Vector2(10580,-278),Vector2(11000,-338),Vector2(11580,-278),Vector2(12300,-378)]
	var route_step := 0
	var trace := false
	var dwell := 0
	var pound_landed := false
	var pound_test := 0

	func walk(game, c: Dictionary, x: float, tolerance := 3.0) -> void:
		c.right = x-game.player.x>tolerance; c.left = x-game.player.x < -tolerance

	func controls_for(game) -> Dictionary:
		var c := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
		if game.boss!=null and game.player.y>450 and game.boss.state.state!="down":
			if absf(game.boss.state.x-game.player.x)<140:
				walk(game,c,game.boss.state.x-240 if game.boss.state.x>game.camera.x+260 else game.boss.state.x+240)
				return c
			if absf(game.boss.state.x-game.player.x)>280 or game.face!=(1 if game.boss.state.x>=game.player.x else -1): walk(game,c,game.boss.state.x)
			return c
		if game.movement_skills.card_collected and not pound_landed:
			if game.grounded and pound_test==0: c.jump=true; pound_test=1
			elif not game.grounded and game.velocity.y>-650: c.down=true
			return c
		if route_step>=ROUTE.size(): walk(game,c,12300); return c
		var goal = ROUTE[route_step]
		var dynamic := goal is int
		var target: Vector2
		if dynamic:
			var row: Array = game.world_three.surfaces(game)[15+goal].row
			target = Vector2((row[0]+row[1])*0.5,row[2])
			if game.grounded and game.world_three._standing_surface == game.world_three.surfaces(game)[15+goal]:
				dwell += 1
				if dwell>15: route_step+=1; dwell=0
				return c
		else: target = goal
		if not dynamic and game.grounded and absf(game.player.x-target.x)<12 and absf(game.player.y-target.y)<2:
			if route_step==7 and dwell<90:
				dwell+=1; c.aim=true
				return c
			dwell=0
			route_step+=1
			if trace: print("Big top waypoint ",route_step," ",game.player)
			return c
		walk(game,c,target.x)
		if game.grounded and not game.jump_held:
			if target.y<game.player.y-6 and absf(target.x-game.player.x)<150: c.jump=true
			var surface: Dictionary = game.world_three._standing_surface
			if not surface.is_empty() and target.x>game.player.x:
				var edge: float = surface.row[1]
				if edge-game.player.x<12 and target.x>edge:
					if dynamic:
						var future_t: float = game.world_three.level_time+0.54
						var mr: Array = game.level.movers[goal-10]
						var landing_x: float = game.level.plats[goal][0]+90*sin(future_t/3.2*6.283+mr[4])
						if landing_x-game.player.x<140: c.jump=true
						else: c.right=false
					else: c.jump=true
			for row in game.level.solids:
				if row[2]<game.player.y-6 and row[0]-game.player.x>=0 and row[0]-game.player.x<65 and target.x>row[0]: c.jump=true
		return c
	func controls(game, _frame: int) -> Dictionary:
		return controls_for(game)

class Hayride:
	extends RefCounted
	# Source control functions: res://tests/test_full_festival_hayride_run.gd
	var receipt_jump := -1
	var receipt_airborne := false
	var recovery_mode := false
	var defeat := true

	func controls_for(game) -> Dictionary:
		var c := {"left":false,"right":false,"down":false,"jump":false,"shoot":defeat,"aim":false,"special":false}
		if game.world_three.wiping: return c
		if recovery_mode:
			c.left = true
			return c
		if receipt_jump >= 0:
			if not game.grounded: receipt_airborne = true
			if receipt_airborne and game.grounded:
				receipt_jump = -1
				receipt_airborne = false
			else:
				c.right = game.player.x < game.receipts[receipt_jump].position.x-16
				return c
		for row in game.level.duck:
			if game.player.x >= row[0]-25 and game.player.x <= row[1]+12:
				c.down = true
				var h: Dictionary = game.world_three.hayride.harvester
				if not h.is_empty() and not h.dead: c.left = true
				return c
		for i in range(game.receipts.size()):
			var r: Dictionary = game.receipts[i]
			if not r.taken and r.position.x-game.player.x < 80 and r.position.x-game.player.x > -20:
				c.jump = game.grounded and not game.jump_held
				c.right = true
				if c.jump: receipt_jump = i
				return c
		# Stay near the center of the only support. Facing is changed with normal
		# directional taps, never a player/face write; airborne players get no carry.
		var relative: float = game.player.x-game.camera.x
		c.right = relative < 294
		c.left = relative > 306
		if not c.left and not c.right:
			var h: Dictionary = game.world_three.hayride.harvester
			var want_face := -1 if not h.is_empty() and not h.dead and defeat else 1
			if game.face != want_face:
				c.left = want_face < 0
				c.right = want_face > 0
		return c
	func controls(game, _frame: int) -> Dictionary:
		return controls_for(game)

class Tout:
	extends RefCounted
	# Source control functions: res://tests/test_full_ticket_tout_run.gd
	const ROUTE := [Vector2(940,372),Vector2(1350,482),Vector2(1820,428),Vector2(2000,374),Vector2(2400,482),Vector2(2840,372),Vector2(3300,482),Vector2(3970,482),Vector2(4170,354),Vector2(3880,482)]
	var route_step := 0
	var trace := false
	var ground_throw := true
	var ground_stomp := true
	var stage_hop := true
	var return_slam := true
	var late_hop := true
	var late_slam := true
	var late_throw := true
	var jar_goal := 3880.0

	func walk(game, c: Dictionary, x: float, tolerance:=3.0) -> void:
		c.right=x-game.player.x>tolerance; c.left=x-game.player.x < -tolerance

	func face_target(game, c: Dictionary, x: float) -> void:
		if game.face!=(1 if x>=game.player.x else -1):
			c.right=x>=game.player.x; c.left=x<game.player.x

	func navigate(game, c: Dictionary, target: Vector2) -> void:
		walk(game,c,target.x)
		if not game.grounded or game.jump_held: return
		var direction:=1 if target.x>=game.player.x else -1
		if target.y<game.player.y-6 and absf(target.x-game.player.x)<115: c.jump=true
		for row in game.level.solids:
			if row[2]>=game.player.y-6: continue
			var distance: float=((row[0] if direction>0 else row[1])-game.player.x)*direction
			if distance>=0 and distance<65 and absf(target.x-game.player.x)>distance: c.jump=true
		if target.y>game.player.y+6 and game.on_platform and absf(target.x-game.player.x)<10: c.down=true; c.jump=true

	func controls_for(game) -> Dictionary:
		var c: Dictionary={"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
		if game.boss!=null: c.shoot=false
		if route_step<ROUTE.size():
			var goal: Vector2=ROUTE[route_step]
			if game.grounded and absf(game.player.x-goal.x)<12 and absf(game.player.y-goal.y)<2:
				var receipt_index: int=0 if route_step==2 else (1 if route_step==3 else (2 if route_step==8 else -1))
				if receipt_index>=0 and not game.receipts[receipt_index].taken:
					c.jump=not game.jump_held
					return c
				route_step+=1
				if trace: print("Tout waypoint=",route_step," p=",game.player)
			if route_step<ROUTE.size(): navigate(game,c,ROUTE[route_step])
		if game.boss!=null and route_step>=ROUTE.size():
			var b: Dictionary=game.boss.state
			if b.state=="down": walk(game,c,jar_goal); return c
			if absf(b.x-game.player.x)<180 and b.fy>450:
				walk(game,c,b.x-230 if b.x>4030 else b.x+230)
			else: face_target(game,c,b.x)
			if b.fy<450 and return_slam: c.aim=true
			if ground_throw and ground_stomp:
				if not return_slam: c.shoot=b.hp>102 and not stage_hop
				elif not late_hop or not late_slam or not late_throw: c.shoot=b.hp>50
				else: c.shoot=true
			return c
		if game.boss!=null: return c
		var target: Dictionary={}
		for enemy in game.enemies:
			if enemy.state=="pop": continue
			if target.is_empty() or absf(enemy.p.x-game.player.x)<absf(target.p.x-game.player.x): target=enemy
		if not target.is_empty():
			var dy: float=target.p.y-game.player.y
			if absf(dy)<70 and game.grounded:
				c.left=false; c.right=false; c.jump=false
				face_target(game,c,target.p.x)
			elif dy < -70: c.aim=true
		return c
	func controls(game, _frame: int) -> Dictionary:
		return controls_for(game)

class Bonus:
	extends RefCounted
	# Source control functions: res://tests/test_full_festival_bonus_run.gd
	const ROUTE := [
		Vector2(1100,482), Vector2(1300,428), Vector2(1500,374), Vector2(1670,482),
		Vector2(1810,428), Vector2(1940,374), Vector2(2120,246), Vector2(2290,246), Vector2(2600,482),
		Vector2(2900,482), Vector2(3100,428), Vector2(3300,374), Vector2(3550,482),
		Vector2(4700,482), Vector2(4900,428), Vector2(5100,374), Vector2(5270,482),
		Vector2(5410,428), Vector2(5540,374), Vector2(5720,246), Vector2(5890,246), Vector2(6200,482),
		Vector2(6500,482), Vector2(6700,428), Vector2(6900,374), Vector2(7070,482),
		Vector2(7210,428), Vector2(7340,374), Vector2(7520,246), Vector2(7690,246), Vector2(8000,482),
		Vector2(8300,428), Vector2(8500,374), Vector2(8720,482)]
	var route_step := 0
	var debug_run := false

	func controls_for(game, frame: int) -> Dictionary:
		var controls := {"left":false,"right":false,"jump":false,"down":false,"shoot":false,"aim":false,"special":false}
		if route_step < ROUTE.size():
			var goal: Vector2 = ROUTE[route_step]
			if game.grounded and absf(game.player.x-goal.x) < 13 and absf(game.player.y-goal.y) < 1:
				route_step += 1
				if debug_run: print("Bonus waypoint=",route_step," frame=",frame," player=",game.player)
		if route_step >= ROUTE.size(): return controls
		var goal: Vector2 = ROUTE[route_step]
		var dx: float = goal.x-game.player.x
		controls.right = dx > 3; controls.left = dx < -3
		if not game.grounded or game.jump_held: return controls
		var direction := 1 if dx >= 0 else -1
		if goal.y < game.player.y-6 and absf(dx) < (220 if goal.y == 246 else 110): controls.jump = true
		for row in game.level.solids:
			if row[2] >= game.player.y-6: continue
			var edge: float = row[0] if direction > 0 else row[1]
			var distance: float = (edge-game.player.x)*direction
			if distance >= 0 and distance < 65 and absf(dx) > distance: controls.jump = true
		return controls
	func controls(game, frame: int) -> Dictionary:
		return controls_for(game, frame)

static func create(id: String):
	match id:
		"3-1": return Field.new()
		"3-2": return Queue.new()
		"3-3": return Night.new()
		"3-4": return BigTop.new()
		"3-5": return Hayride.new()
		"3-6": return Tout.new()
		"3-S": return Bonus.new()
	return null
