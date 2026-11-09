extends RefCounted
## Read-only normal-input drivers copied verbatim from existing solo full runs.
## SceneTree runners/assertions omitted. The aisle ice lookup reads slot instead
## of solo instance identity; route decisions and source CPU remain unchanged.
## Source equality is checked by test_party_world_two_source_contract.py.

class Parking extends RefCounted:
	## Bounded source-authored 2-1 input progression regression, NOT difficulty QA.
	## Only movement/jump/down/aim/shoot/special inputs advance the run. The sole
	## assist is invulnerability. Never edit actors, health, positions, geometry,
	## waves, timers, power, pickups or completion. The lift's own teleport is real.
	## Use fresh HOME/XDG paths in /tmp; each housemate also gets a fresh save.
	const SaveStore = preload("res://src/save_store.gd")
	const DT := 1.0 / 60.0
	const MAX_TICKS := 36000
	const EXPECTED_WAVES := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	const WAVE_AT := [500, 1500, 3000, 4300, 5600, 6880, 8200, 9700, 11900, 13300, 15262]
	const NUMERIC_SPAWNS := [1720, 3320, 4520, 6120, 8420, 9920, 12720, 14120]
	const ENEMY_COUNTS := {"rush": 21, "throw": 11, "cart": 10, "flat": 5, "drone": 3, "big": 2}
	const RECEIPTS := [[80, 482], [3920, 269], [12120, 269]]
	var failures: Array[String] = []
	var debug_run := false

	func controls_for(game, frame: int, wipe_start: int) -> Dictionary:
		var controls := {"left": false, "right": false, "jump": false, "down": false, "aim": false, "shoot": true, "special": false}
		# Demonstrate real left/right input continues under the closed lift wipe.
		if game.world_two.wiping and game.world_two.scene_index == 0:
			controls.left = (frame - wipe_start) < 25
			controls.right = not controls.left
			return controls
		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.state == "pop": continue
			if target.is_empty() or absf(enemy.p.x - game.player.x) < absf(target.p.x - game.player.x): target = enemy
		if not target.is_empty():
			var dx: float = target.p.x - game.player.x
			if game.grounded and game.on_platform:
				# Fight ordinary robots from their floor, rather than shooting above
				# them from a car roof. This uses the public down+jump drop control.
				controls.down = true
				controls.jump = not game.jump_held
			elif target.kind == "drone" or target.p.y < game.player.y - 130:
				controls.aim = true
				# The source has a straight-up standing shot. Chase to just beneath
				# the drone, then release direction to shoot vertically.
				controls.right = dx > 24
				controls.left = dx < -24
			else:
				if game.grounded and frame % 120 == 0: controls.down = true
				# A direction tap changes facing without manufacturing player state.
				if game.face != (1 if dx >= 0 else -1):
					controls.right = dx >= 0
					controls.left = dx < 0
			if game.abilities.meter >= 1: controls.special = true
			return controls
		var target_x: float = game.level.w - 40
		var receipt_index := -1
		for i in range(game.receipts.size()):
			if not game.receipts[i].taken:
				receipt_index = i
				target_x = float(RECEIPTS[i][0])
				break
		var dx := target_x - float(game.player.x)
		controls.right = dx > 3
		controls.left = dx < -3
		# The body overlaps the elevated receipt during an ordinary ground jump.
		# No car/van platform, skill card or upward position edit is necessary.
		if receipt_index > 0 and absf(dx) < 25 and game.grounded and not game.jump_held:
			controls.jump = true
		return controls

class Aisle extends RefCounted:
	## Input-only 2-2 Aisle seven progression, NOT difficulty or device QA.
	## Invulnerability is the sole assist. The controller may only supply ordinary
	## move/jump/down/aim/shoot/special inputs; all gameplay state is observed only.
	const SaveStore = preload("res://src/save_store.gd")
	const DT := 1.0 / 60.0
	const MAX_TICKS := 36000
	const EXPECTED_WAVES := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	const WAVE_AT := [400, 1250, 2800, 4800, 6800, 7800, 9900, 11000, 12600, 14462]
	const ENEMY_COUNTS := {"rush": 19, "throw": 11, "drone": 4, "cart": 4, "flat": 3, "big": 2}
	const RECEIPTS := [[3700, 246], [8300, 246], [12880, 246]]
	const ISLANDS := [[900, 1400], [3600, 4150], [5200, 5700], [7000, 7500], [8100, 8500], [11100, 11500], [12500, 12950]]
	const GATES := [[2500, 482, 560, 0], [4500, 482, 560, 1], [6500, 482, 560, 2], [9200, 482, 560, 3], [9700, 482, 560, 4], [12000, 482, 560, 5], [14000, 482, 560, 6]]
	const PLATES := [[1900, 482, 0], [5950, 482, 2], [8750, 482, 3], [9450, 482, 4], [13450, 482, 6]]
	const BUTTONS := [[4370, 152, 1], [11650, 372, 5]]
	var failures: Array[String] = []
	var debug_run := false
	var route_step := 0
	var seen_shelves: Array[int] = []

	func walk_toward(game, controls: Dictionary, target_x: float, tolerance: float = 4) -> void:
		var dx := target_x - float(game.player.x)
		# Countersteer through ordinary left/right input when crossing the icy
		# floor. This predicts braking only; it never edits actual ice momentum.
		if game.grounded and game.player.x > 10800 and game.player.x < 13700 and absf(game.player.y - 482) < 4:
			var momentum: float = game.world_two.hazard_controller.ice_velocity.get(game.combat_owner_slot(), 0.0)
			dx -= momentum * 0.3
		controls.right = dx > tolerance
		controls.left = dx < -tolerance

	func plate_gate(game, controls: Dictionary, id: int) -> bool:
		var hazards = game.world_two.hazard_controller
		var gate: Dictionary = hazards.gates.filter(func(g): return int(g.id) == id)[0]
		if game.player.x > gate.x + 70: return true
		var plate: Dictionary = hazards.plates.filter(func(p): return int(p.id) == id)[0]
		var time_to_cross := maxf(0, gate.x + 80 - game.player.x) / 270.0 + 0.35
		walk_toward(game, controls, gate.x + 95 if gate.timer > time_to_cross else plate.x)
		return false

	func climb_shelf(game, controls: Dictionary, x: float, shelf_index: int, receipt_index: int) -> bool:
		if shelf_index in seen_shelves and game.receipts[receipt_index].taken: return true
		walk_toward(game, controls, x)
		if absf(game.player.x - x) < 22 and game.grounded and game.player.y > 246.1 and not game.jump_held:
			controls.jump = true
		return false

	func button_gate(game, controls: Dictionary, id: int) -> bool:
		var hazards = game.world_two.hazard_controller
		var gate: Dictionary = hazards.gates.filter(func(g): return int(g.id) == id)[0]
		if game.player.x > gate.x + 70: return true
		var enough_time: bool = gate.timer > maxf(0, gate.x + 80 - game.player.x) / 270.0 + 0.4
		if enough_time:
			walk_toward(game, controls, gate.x + 95)
		elif id == 1:
			# Normal standing shots from the actual upper shelf hit y152 for all
			# six authored character heights. Do not replace this with a hook call.
			walk_toward(game, controls, 4050)
			if game.grounded and game.player.y > 246.1 and not game.jump_held: controls.jump = true
			if game.face < 0: controls.right = true; controls.left = false
		else:
			walk_toward(game, controls, 11550)
			if game.grounded and game.on_platform:
				controls.down = true
				controls.jump = not game.jump_held
			if game.face < 0: controls.right = true; controls.left = false
		return false

	func controls_for(game, frame: int, wipe_start: int) -> Dictionary:
		var controls := {"left": false, "right": false, "jump": false, "down": false, "aim": false, "shoot": true, "special": false}
		if game.world_two.wiping and game.world_two.scene_index == 0:
			controls.left = (frame - wipe_start) < 25
			controls.right = not controls.left
			return controls
		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.state == "pop": continue
			if target.is_empty() or absf(enemy.p.x - game.player.x) < absf(target.p.x - game.player.x): target = enemy
		if not target.is_empty():
			var dx: float = target.p.x - game.player.x
			if game.grounded and game.on_platform:
				controls.down = true
				controls.jump = not game.jump_held
			elif target.kind == "drone" or target.p.y < game.player.y - 130:
				controls.aim = true
				walk_toward(game, controls, target.p.x, 24)
			else:
				if game.grounded and frame % 120 == 0: controls.down = true
				if game.face != (1 if dx >= 0 else -1):
					controls.right = dx >= 0
					controls.left = dx < 0
				# A green button also absorbs shots fired back toward an enemy.
				# Walk past it instead of endlessly reactivating the shelf gate.
				for button in game.world_two.hazard_controller.buttons:
					if button.x > minf(game.player.x, target.p.x) and button.x < maxf(game.player.x, target.p.x) and absf(game.player.y - game.character_height() * 0.53 - button.y) < 30:
						controls.down = false
						walk_toward(game, controls, button.x + signf(dx) * 90)
			if game.abilities.meter >= 1: controls.special = true
			return controls
		match route_step:
			0:
				if plate_gate(game, controls, 0): route_step += 1
			1:
				if climb_shelf(game, controls, 3700, 1, 0): route_step += 1
			2:
				if button_gate(game, controls, 1): route_step += 1
			3:
				if plate_gate(game, controls, 2): route_step += 1
			4:
				if climb_shelf(game, controls, 8300, 4, 1): route_step += 1
			5:
				if plate_gate(game, controls, 3): route_step += 1
			6:
				if plate_gate(game, controls, 4): route_step += 1
			7:
				if game.world_two.scene_index == 1: route_step += 1
				else: walk_toward(game, controls, 10400)
			8:
				if button_gate(game, controls, 5): route_step += 1
			9:
				if climb_shelf(game, controls, 12870, 6, 2): route_step += 1
			10:
				# The original spawnBot consumes an entry if the ground is outside
				# its vertical camera window. Descend by actual down+jump before
				# advancing to camera12600, so the final shelf cannot skip a bot.
				walk_toward(game, controls, 12870)
				if game.grounded and game.on_platform:
					controls.down = true
					controls.jump = not game.jump_held
				if game.grounded and absf(game.player.y - 482) < 1 and game.camera.y > -60: route_step += 1
			11:
				if plate_gate(game, controls, 6): route_step += 1
			_:
				walk_toward(game, controls, game.level.w - 40)
		return controls

class Stockroom extends RefCounted:
	## Input-driven 2-3 progression, not difficulty/device QA. Explicit invulnerability
	## is the sole assist. Never edit actor, wave, geometry, ability, or objective state.
	const SaveStore = preload("res://src/save_store.gd")
	const DT := 1.0 / 60.0
	const MAX_TICKS := 36000
	const EXPECTED_WAVES := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	const WAVE_AT := [300, 1600, 3100, 4500, 6000, 6900, 8150, 9700, 10900, 12300, 13862]
	const ENEMY_COUNTS := {"rush": 22, "throw": 11, "drone": 4, "cart": 4, "flat": 3, "big": 2}
	const RECEIPTS := [[9305, 422], [8760, 122], [11620, 2]]
	const TOWERS := [[3000, 4400, 360], [4650, 5600, 240], [6000, 7400, 240], [7700, 8800, 360], [10500, 11700, 480], [12100, 13000, 360]]
	const STACKS := [[1000, 1230, 110], [1700, 2000, 110], [2300, 2560, 220], [9900, 10130, 110], [13500, 13760, 110]]
	const PLATFORMS := [[2150, 2296, 367], [2850, 2994, 362], [2870, 2994, 242], [4500, 4644, 362], [4400, 4650, 122], [5850, 5994, 362], [7550, 7694, 362], [7570, 7694, 242], [7400, 7700, 242], [9110, 9200, 452], [9270, 9340, 422], [10350, 10494, 362], [10370, 10494, 242], [10350, 10494, 122], [11700, 12100, 122], [11950, 12094, 362], [11970, 12094, 242], [13006, 13150, 362], [13006, 13130, 242]]
	const BELTS := [[4400, 4650, 122, 0.08], [7400, 7700, 242, -0.07], [11700, 12100, 122, 0.1]]
	const DROPS := [[3000, 5600, 1900, "box"], [10400, 13000, 1600, "box"]]
	const LOWER_ROUTE := [Vector2(1070,372), Vector2(1770,372), Vector2(2210,367), Vector2(2340,262), Vector2(2530,262), Vector2(2925,362), Vector2(2935,242), Vector2(3030,122), Vector2(4340,122), Vector2(4520,122), Vector2(4680,242), Vector2(5575,242), Vector2(5910,362), Vector2(6050,242), Vector2(7350,242), Vector2(7520,242), Vector2(7650,242), Vector2(7730,122), Vector2(8760,122), Vector2(8865,482)]
	const UPPER_ROUTE := [Vector2(8987,482), Vector2(9180,452), Vector2(9320,422), Vector2(9480,482), Vector2(9970,372), Vector2(10200,482), Vector2(10425,362), Vector2(10430,242), Vector2(10430,122), Vector2(10535,2), Vector2(11620,2), Vector2(11680,2), Vector2(11800,122), Vector2(12160,122), Vector2(12970,122), Vector2(13060,242), Vector2(13060,362), Vector2(13180,482), Vector2(13570,372), Vector2(13830,482), Vector2(14550,482)]
	var failures: Array[String] = []
	var debug_run := false
	var route_step := 0
	var route_scene := 0

	func walk_toward(game, controls: Dictionary, x: float, tolerance := 4.0) -> void:
		controls.right = x-game.player.x > tolerance
		controls.left = x-game.player.x < -tolerance

	func navigate(game, controls: Dictionary, goal: Vector2) -> void:
		# If combat displaced us below a tall goal, take its real lower rungs
		# again rather than trying to jump through a220/360/480px solid wall.
		if goal.y < game.player.y-145:
			var best := INF
			var rung := goal
			for row in PLATFORMS:
				if row[2] < game.player.y-140 or row[2] >= game.player.y-6 or row[2] <= goal.y: continue
				var x := (float(row[0])+float(row[1]))*0.5
				if x < game.camera.x+35 or x > game.camera.x+game.view_width()-35: continue
				var distance: float = absf(x-goal.x)+absf(x-game.player.x)*0.25
				if distance < best:
					best = distance
					rung = Vector2(x,row[2])
			goal = rung
		walk_toward(game,controls,goal.x)
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
		# Ground ends at9000. The two pallets are static one-way ledges, so
		# approaching each actual edge is essential before an ordinary jump.
		if game.player.x >= 8975 and game.player.x < 9440 and goal.x > game.player.x:
			var surface: Dictionary = game.world_two.below(game,game.player.x,game.player.y)
			if not surface.is_empty() and game.player.x >= float(surface.row[1])-23: controls.jump = true

	func controls_for(game, frame: int, wipe_start: int) -> Dictionary:
		var controls := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
		if game.world_two.wiping and game.world_two.scene_index == 0:
			controls.left = frame-wipe_start < 25
			controls.right = not controls.left
			return controls
		if route_scene != game.world_two.scene_index:
			route_scene = game.world_two.scene_index
			route_step = 0
		# Leo's active glider clamps upward speed. Let the actual special expire
		# on the safe bank before attempting the first30px-up pallet jump.
		if route_scene == 1 and game.player.x < 9000 and game.grounded and game.abilities.active == "leo": return controls
		var route: Array = LOWER_ROUTE if route_scene == 0 else UPPER_ROUTE
		if route_step < route.size():
			var goal: Vector2 = route[route_step]
			if game.grounded and absf(game.player.x-goal.x) < 15 and absf(game.player.y-goal.y) < 1:
				route_step += 1
				if debug_run: print("Stockroom route=",route_scene,"/",route_step," frame=",frame," p=",game.player)
		if route_step < route.size(): navigate(game,controls,route[route_step])
		else: walk_toward(game,controls,8910 if route_scene == 0 else 14550)
		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.state == "pop": continue
			if target.is_empty() or (target.kind == "drone" and enemy.kind != "drone") or (target.kind == enemy.kind or (target.kind != "drone" and enemy.kind != "drone")) and absf(enemy.p.x-game.player.x) < absf(target.p.x-game.player.x): target = enemy
		if not target.is_empty():
			var dx: float = target.p.x-game.player.x
			var dy: float = target.p.y-game.player.y
			if absf(dy) < 80 and game.grounded:
				controls.left = false
				controls.right = false
				controls.jump = false
				if game.face != (1 if dx >= 0 else -1):
					controls.right = dx >= 0
					controls.left = dx < 0
				if frame%180 == 0: controls.down = true
			elif dy > 80:
				# Descend/backtrack through real ledges to a lower stranded bot.
				navigate(game,controls,Vector2(target.p.x,target.p.y))
			elif target.kind == "drone" and game.grounded:
				controls.aim = true
				var obstructed := false
				var height: float = target.base_y
				for row in game.level.solids:
					if row[2] < game.player.y-6 and row[0] < maxf(game.player.x,target.p.x) and row[1] > minf(game.player.x,target.p.x):
						obstructed = true
						height = minf(height,row[2])
				if obstructed:
					# Reach the actual intervening shelf before aiming through it.
					navigate(game,controls,Vector2(target.p.x,height))
				else:
					var support: Dictionary = game.world_two.below(game,game.player.x,game.player.y)
					if not support.is_empty():
						var x: float = clampf(target.p.x,maxf(support.row[0]+30,game.camera.x+35),minf(support.row[1]-30,game.camera.x+game.view_width()-40))
						walk_toward(game,controls,x,20)
					controls.jump = false
			if game.abilities.meter >= 1 and absf(dy) < 100: controls.special = true
		return controls

class Bakery extends RefCounted:
	## Input-driven 2-5 progression, not difficulty/device QA. Explicit invulnerability
	## is the sole assist. It DOES retain the source wet-block bounce; no course bypass.
	const SaveStore = preload("res://src/save_store.gd")
	const DT := 1.0 / 60.0
	const MAX_TICKS := 36000
	const EXPECTED_WAVES := [0,1,2,3,4,5,6,7,8,9,10]
	const WAVE_AT := [400,1700,3300,4800,6200,7200,8800,10600,12000,13300,14262]
	const ENEMY_COUNTS := {"rush":19,"throw":11,"cart":5,"drone":4,"flat":3,"big":3}
	const RECEIPTS := [[3350,352],[7600,292],[13600,370]]
	const PLATFORMS := [[804,1296,370],[5004,5596,370],[9804,10496,370],[13204,13696,370],[2000,2900,352],[3300,4400,352],[6400,7400,352],[7800,8900,232],[7500,7700,292]]
	const BELTS := [[2000,2900,352,-0.09],[3300,4400,352,-0.09],[6400,7400,352,0.1],[7800,8900,232,-0.08]]
	const FLAMES := [[1920,482,2600,2200],[2440,482,2600,640],[2960,482,2600,1680],[3480,482,2600,120],[4000,482,2600,1160],[4520,482,2600,2200],[6320,482,2200,1000],[6780,482,2200,180],[7240,482,2200,1560],[7700,482,2200,740],[8160,482,2200,2120],[8620,482,2200,1300],[9080,482,2200,480]]
	const BLOCKS := [[12600,482,62,84,"wet"],[14250,482,62,84,"wet"]]
	const COINS := [[2050,2850,302,7,0],[3350,4350,302,8,0],[6450,7350,302,7,0],[7850,8850,182,8,0],[850,1250,322,4,0],[9850,10450,322,5,0],[13250,13650,322,4,0],[12900,13100,422,3,0]]
	# Ground approaches at wave thresholds preserve the actual camera-dependent
	# spawn search. The third belt is revisited after the two security bots so the
	# card is earned via352 ->292 rack ->232 belt using only the ordinary jump.
	const BAKEHOUSE_ROUTE := [Vector2(1100,370),Vector2(2050,352),Vector2(2830,352),Vector2(3350,352),Vector2(4330,352),Vector2(5300,370),Vector2(6500,482),Vector2(6500,352),Vector2(7320,352),Vector2(7350,482),Vector2(7660,482),Vector2(7350,352),Vector2(7380,352),Vector2(7600,292),Vector2(7665,292),Vector2(7850,232),Vector2(8850,232),Vector2(8870,482),Vector2(9400,482)]
	const SHOP_ROUTE := [Vector2(10350,370),Vector2(10530,482),Vector2(11000,482),Vector2(12250,482),Vector2(12700,482),Vector2(13600,370),Vector2(13600,482),Vector2(14400,482),Vector2(14950,482)]
	var failures: Array[String] = []
	var debug_run := false
	var route_step := 0
	var route_scene := 0
	var card_frame := -1
	var live_double_jump_frame := -1
	var double_jump_probe := 0
	var recovery_rung := Vector2.INF
	var recovery_target := Vector2.INF

	func walk_toward(game, controls: Dictionary, x: float, tolerance := 4.0) -> void:
		controls.right = x-game.player.x > tolerance
		controls.left = x-game.player.x < -tolerance

	func navigate(game, controls: Dictionary, goal: Vector2) -> void:
		if recovery_target != goal:
			recovery_rung = Vector2.INF
			recovery_target = goal
		if recovery_rung != Vector2.INF and game.grounded and absf(game.player.x-recovery_rung.x) < 20 and absf(game.player.y-recovery_rung.y) < 1:
			recovery_rung = Vector2.INF
		if recovery_rung != Vector2.INF:
			goal = recovery_rung
		elif goal.y < game.player.y-145:
			var best := INF
			var rung := goal
			for row in PLATFORMS:
				if row[2] < game.player.y-140 or row[2] >= game.player.y-6 or row[2] <= goal.y: continue
				var x := clampf(goal.x,float(row[0])+30,float(row[1])-30)
				if x < game.camera.x+35 or x > game.camera.x+game.view_width()-35: continue
				var distance: float = absf(x-goal.x)+absf(x-game.player.x)*0.25
				if distance < best:
					best = distance
					rung = Vector2(x,row[2])
			if rung != goal: recovery_rung = rung
			goal = rung
		walk_toward(game,controls,goal.x)
		if not game.grounded or game.jump_held: return
		var dx: float = goal.x-game.player.x
		if goal.y < game.player.y-6 and absf(dx) < 110: controls.jump = true
		if goal.y > game.player.y+6 and game.on_platform and absf(dx) < 10:
			controls.down = true
			controls.jump = true
		# Raised rack/belt gaps require launching from the actual surface edge.
		if goal.y < game.player.y-6 and game.on_platform:
			var surface: Dictionary = game.world_two.below(game,game.player.x,game.player.y)
			if not surface.is_empty():
				if dx > 0 and game.player.x >= float(surface.row[1])-28: controls.jump = true
				if dx < 0 and game.player.x <= float(surface.row[0])+28: controls.jump = true
		# Wet signs are hazard rectangles, not artificial solid ledges. Jump using
		# ordinary input; any incidental invulnerable bounce remains source state.
		for block in BLOCKS:
			if dx > 0 and block[0]-game.player.x > 0 and block[0]-game.player.x < 95 and goal.x > block[0]: controls.jump = true

	func controls_for(game, frame: int, wipe_start: int) -> Dictionary:
		var controls := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
		if game.world_two.wiping and game.world_two.scene_index == 0:
			controls.left = frame-wipe_start < 25
			controls.right = not controls.left
			return controls
		if route_scene != game.world_two.scene_index:
			route_scene = game.world_two.scene_index
			route_step = 0
		var route: Array = BAKEHOUSE_ROUTE if route_scene == 0 else SHOP_ROUTE
		if route_step < route.size():
			var goal: Vector2 = route[route_step]
			if game.grounded and absf(game.player.x-goal.x) < 15 and absf(game.player.y-goal.y) < 1 and not (route_scene == 0 and route_step == 10 and not game.combat.waves[5].done):
				route_step += 1
				if debug_run: print("Bakery route=",route_scene,"/",route_step," frame=",frame," p=",game.player)
		if route_step < route.size(): navigate(game,controls,route[route_step])
		else: walk_toward(game,controls,9400 if route_scene == 0 else 14950)
		# Hold the real ground approach until camera y returns into the source
		# spawn window. This does not change the camera or consume a wave early.
		if route_scene == 0 and route_step == 10 and game.grounded and game.camera.y < -50:
			controls.left = false; controls.right = false
		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.state == "pop": continue
			if target.is_empty() or (target.kind == "drone" and enemy.kind != "drone") or (target.kind == enemy.kind or (target.kind != "drone" and enemy.kind != "drone")) and absf(enemy.p.x-game.player.x) < absf(target.p.x-game.player.x): target = enemy
		if not target.is_empty():
			var dx: float = target.p.x-game.player.x
			var dy: float = target.p.y-game.player.y
			if absf(dy) < 80 and game.grounded:
				controls.left = false
				controls.right = false
				controls.jump = false
				if game.face != (1 if dx >= 0 else -1):
					controls.right = dx >= 0
					controls.left = dx < 0
				if frame%180 == 0: controls.down = true
			elif dy > 80:
				navigate(game,controls,Vector2(target.p.x,target.p.y))
			elif target.kind == "drone" and game.grounded:
				controls.aim = true
				walk_toward(game,controls,target.p.x,20)
				controls.jump = false
			if game.abilities.meter >= 1 and absf(dy) < 100: controls.special = true
			return controls
		# Perform an explicit two-press double jump only AFTER real card contact.
		# Wait for active glider expiry, rather than modifying a special's lifetime.
		if card_frame >= 0 and live_double_jump_frame < 0 and route_scene == 0:
			controls.left = false; controls.right = false
			controls.jump = false; controls.down = false
			if game.abilities.active == "leo": return controls
			if double_jump_probe == 0 and game.grounded and not game.jump_held:
				controls.jump = true
				double_jump_probe = 1
			elif double_jump_probe == 1 and not game.grounded and not game.jump_held and game.velocity.y > -700:
				controls.jump = true
			return controls
		return controls

class Trolley extends RefCounted:
	## Actual 2-4 input progression, not difficulty/device QA. Invulnerability is
	## the sole assist and retains source block bounces. No actor, damage, wave,
	## geometry, timer, spawn, ability-meter or skill edits are allowed in this run.
	const SaveStore = preload("res://src/save_store.gd")
	const DT := 1.0 / 60.0
	const MAX_TICKS := 30000
	const RECEIPTS := [[9000,312],[21000,312],[33000,312]]
	const WAVE_AT := [2000,5100,8200,11300,14400,17500,20600,23700,26800,29900,33000,36100,39262]
	const ENEMIES := {"cart":22,"throw":9,"rush":4,"drone":2,"flat":2,"big":1}
	const BOOSTS := [[4884,5684],[10048,10848],[15435,16235],[20576,21376],[25619,26419],[30934,31734],[36237,37037]]
	const BLOCKS := [[1500,482,62,84,"wet"],[2316,482,112,104,"pallet"],[3760,482,62,84,"wet"],[4465,482,96,44,"cones"],[6230,482,62,84,"wet"],[6556,482,62,84,"wet"],[7253,482,112,104,"pallet"],[8644,482,62,84,"wet"],[9489,482,96,44,"cones"],[11367,482,62,84,"wet"],[11661,482,62,84,"wet"],[12367,482,112,104,"pallet"],[14085,482,62,84,"wet"],[14860,482,96,44,"cones"],[16738,482,62,84,"wet"],[17148,482,62,84,"wet"],[17848,482,112,104,"pallet"],[19411,482,62,84,"wet"],[20069,482,96,44,"cones"],[21853,482,62,84,"wet"],[22242,482,62,84,"wet"],[23023,482,112,104,"pallet"],[24471,482,62,84,"wet"],[25250,482,96,44,"cones"],[27004,482,62,84,"wet"],[27362,482,62,84,"wet"],[28232,482,112,104,"pallet"],[29753,482,62,84,"wet"],[30513,482,96,44,"cones"],[32241,482,62,84,"wet"],[32774,482,62,84,"wet"],[33472,482,112,104,"pallet"],[34951,482,62,84,"wet"],[35816,482,96,44,"cones"],[37564,482,62,84,"wet"],[38087,482,62,84,"wet"]]
	const LOWS := [[3029,482,128,0,2],[5890,482,128,0,0],[8018,482,128,0,0],[11027,482,128,0,1],[13238,482,128,0,1],[16398,482,128,0,2],[18635,482,128,0,2],[21513,482,128,0,0],[23816,482,128,0,0],[26664,482,128,0,1],[28997,482,128,0,1],[31901,482,128,0,2],[34165,482,128,0,2],[37224,482,128,0,0]]
	var failures: Array[String] = []
	var debug_run := false

	func controls_for(game, frame: int) -> Dictionary:
		var c := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.state == "pop": continue
			if target.is_empty() or absf(enemy.p.x-game.player.x) < absf(target.p.x-game.player.x): target = enemy
		var destination: float = game.camera.x+390
		if not target.is_empty():
			var dx: float = target.p.x-game.player.x
			destination = target.p.x-(150 if dx >= 0 else -150)
			if target.kind == "drone":
				destination = target.p.x-(100 if dx >= 0 else -100)
				c.aim = true
			if game.face != (1 if dx >= 0 else -1): destination = game.player.x+(10 if dx >= 0 else -10)
			if game.abilities.meter >= 1 and game.combat.waves.filter(func(w): return w.started and not w.done).all(func(w): return w.index == w.group.size()): c.special = true
		else:
			if frame%120 < 10: c.aim = true
		destination = clampf(destination,game.camera.x+75,game.camera.x+650)
		c.right = destination-game.player.x > 4
		c.left = destination-game.player.x < -4
		if not target.is_empty() and target.p.x < game.player.x and c.right: c.right = false
		if not target.is_empty() and target.p.x > game.player.x and c.left: c.left = false
		# Normal down lands Leo's glider before the next sign/dispatch. No y edits.
		if game.abilities.active == "leo" and not game.grounded: c.down = true
		# Let the continuously moving camera carry its ordinary left-edge clamp
		# through each sign while down prevents walking. This is not a fixed arena.
		for h in LOWS:
			if h[0]-game.player.x < 105 and h[0]-game.player.x > -60:
				c.down = true
				c.aim = false
				c.jump = false
				c.special = false
				return c
		for h in BLOCKS:
			var dx: float = h[0]-game.player.x
			var lead: float = 110 if h[4] == "pallet" else 80
			if dx > -float(h[2])/2-14 and dx < lead:
				c.right = true
				c.left = false
				c.aim = false
				if game.grounded and not game.jump_held and dx > 0:
					c.jump = true
					c.down = false
				return c
		for i in range(3):
			if game.receipts[i].taken: continue
			var dx: float = RECEIPTS[i][0]-game.player.x
			if dx < 100 and dx > -38:
				c.right = dx > 5
				c.left = dx < -5
				if game.grounded and not game.jump_held:
					c.jump = true
					c.down = false
				return c
		return c

class Checkout extends RefCounted:
	## Input-driven 2-6 progression, not difficulty/device QA. Invulnerability is
	## the only assist; it suppresses bags and cannot replace real-damage fixtures.
	## Use detached controller snapshots to choose ordinary inputs. No state writes.
	const SaveStore = preload("res://src/save_store.gd")
	const DT := 1.0/60.0
	const MAX_TICKS := 24000
	const RECEIPTS := [[1100,390],[2900,390],[3500,390]]
	const LANES := [[700,1080,390],[1300,1680,390],[1900,2280,390],[2500,2880,390],[3100,3480,390]]
	const STEPS := [[4385,4475,412],[4465,4555,347],[4545,4635,282]]
	const WAVE_AT := [500,1700,3000]
	const ENEMY_COUNTS := {"rush":5,"throw":3,"cart":4,"drone":1,"big":1}
	const TRAY_TARGETS := [Vector2(4846,354),Vector2(4906,354),Vector2(4876,292)]
	var failures: Array[String] = []
	var trace := false
	var trace_limit := 160
	var trace_count := 0
	var climbed := 0
	var special_used := false

	func walk(game, controls: Dictionary, x: float, tolerance := 4.0) -> void:
		controls.right = x-game.player.x > tolerance
		controls.left = x-game.player.x < -tolerance

	func face_right(game, controls: Dictionary) -> void:
		if game.face != 1: controls.right = true

	func controls_for(game, frame: int, state: Dictionary) -> Dictionary:
		var controls := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
		var b: Dictionary = state.boss
		if b.is_empty():
			var target: Dictionary = {}
			for enemy in game.enemies:
				if enemy.state == "pop": continue
				if target.is_empty() or (target.kind == "drone" and enemy.kind != "drone") or ((target.kind == "drone") == (enemy.kind == "drone") and absf(enemy.p.x-game.player.x) < absf(target.p.x-game.player.x)): target = enemy
			if not target.is_empty():
				var dx: float = target.p.x-game.player.x
				if target.kind == "drone":
					controls.aim = true
					walk(game,controls,target.p.x,20)
				elif game.player.y < target.p.y-80 and game.on_platform:
					controls.down = true
					controls.jump = not game.jump_held
				else:
					if game.face != (1 if dx >= 0 else -1):
						controls.right = dx >= 0; controls.left = dx < 0
					if frame%180 == 0: controls.down = true
				return controls
			var destination := 4510.0
			for i in range(3):
				if not game.receipts[i].taken:
					destination = float(RECEIPTS[i][0]); break
			walk(game,controls,destination)
			return controls
		if b.state == "down":
			controls.shoot = false
			if not state.jar.is_empty(): walk(game,controls,state.jar.p.x,5)
			else: walk(game,controls,4590)
			return controls
		if b.phase == 1:
			walk(game,controls,4390)
			if absf(game.player.x-4390) < 8: face_right(game,controls)
			if b.state == "fight" and not special_used and game.abilities.meter >= 1: controls.special = true
			if b.beam != null:
				if b.beam.y < 382 and b.beam.t > 0.5 and b.beam.t < 1.5:
					controls.down = true; controls.left = false; controls.right = false
				elif b.beam.y > 382 and b.beam.t > 0.78 and b.beam.t < 1.0 and game.grounded and not game.jump_held: controls.jump = true
			return controls
		if b.phase == 2:
			if b.frozen > 0:
				walk(game,controls,4390)
				face_right(game,controls)
				if game.grounded and not game.jump_held: controls.jump = true
				return controls
			controls.shoot = false
			if b.crates.any(func(c): return c.st == "carry"): walk(game,controls,4375)
			else:
				var ground: Array = b.crates.filter(func(c): return c.st == "ground")
				ground.sort_custom(func(a,c): return absf(a.p.x-game.player.x) < absf(c.p.x-game.player.x))
				if not ground.is_empty(): walk(game,controls,ground[0].p.x)
			return controls
		# Do not chip TB from the floor and skip the intended receipt climb.
		controls.shoot = false
		if climbed < 3:
			var row: Array = STEPS[climbed]
			if game.grounded and absf(game.player.y-row[2]) < 0.01 and game.player.x >= row[0] and game.player.x <= row[1]:
				climbed += 1
				if climbed == 3: return controls
				row = STEPS[climbed]
			if b.steps <= climbed: return controls
			var destination: float = (float(row[0])+float(row[1]))/2.0
			walk(game,controls,destination,3)
			if game.grounded and not game.jump_held and absf(destination-game.player.x) < 110: controls.jump = true
			return controls
		face_right(game,controls)
		controls.shoot = true
		return controls

class Shopping extends RefCounted:
	## Source-authored 2-S input progression, NOT unassisted difficulty QA.
	## Invulnerability is the sole assist. No actor/geometry/wave/timer/power edits,
	## no direct damage, no earned skills, no forced pickups or synthetic clear.
	## A separately labelled idle fixture verifies that timer100000 is dormant.
	const SaveStore = preload("res://src/save_store.gd")
	const DT := 1.0 / 60.0
	const MAX_TICKS := 12000
	const RECEIPTS := [[2000, 362], [5300, 362], [8200, 482]]
	const STALLS := [700, 1600, 2500, 3400, 4300, 5200, 6100, 7000, 7900]
	const WAVE_AT := [2000, 5200]
	const GROUPS := [[[0, "r", "rush"], [900, "r", "rush"]], [[0, "r", "cart"], [800, "r", "rush"]]]
	var failures: Array[String] = []
	var debug_run := false

	func controls_for(game, frame: int) -> Dictionary:
		var controls := {"left": false, "right": false, "jump": false, "down": false, "aim": false, "shoot": true, "special": false}
		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.state == "pop": continue
			if target.is_empty() or absf(enemy.p.x - game.player.x) < absf(target.p.x - game.player.x): target = enemy
		if not target.is_empty():
			var dx: float = target.p.x - game.player.x
			if game.face != (1 if dx >= 0 else -1):
				controls.right = dx >= 0
				controls.left = dx < 0
			if game.abilities.meter >= 1: controls.special = true
			return controls
		# The crate is low: standing shots pass over it, crouching is genuine input.
		if not game.crates[0].broken and game.player.x > 4290 and game.player.x < 4500:
			if game.face != 1: controls.right = true
			else: controls.down = true
			return controls
		for item in game.items:
			if item.give != "split": continue
			controls.right = item.p.x - game.player.x > 3
			controls.left = item.p.x - game.player.x < -3
			return controls
		var target_x: float = game.level.w - 40
		for i in range(game.receipts.size()):
			if not game.receipts[i].taken:
				target_x = RECEIPTS[i][0]
				break
		var dx := target_x - float(game.player.x)
		controls.right = dx > 3
		controls.left = dx < -3
		# Collect elevated samples by normal jumps, away from the low crate.
		if game.grounded and not game.jump_held and frame % 95 == 0 and (game.player.x < 4000 or game.player.x > 4700): controls.jump = true
		# Brief upward/diagonal shots while travelling, never an alternate damage path.
		if frame % 120 < 12: controls.aim = true
		return controls
