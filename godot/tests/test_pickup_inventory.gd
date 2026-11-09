extends SceneTree
## No main scene, textures, sounds or renderers: audit real runtime loot paths
## across all 42 imported source stages using a small host-state adapter.
const WORLDS = [preload("res://src/world_one.gd"), preload("res://src/world_two.gd"), preload("res://src/world_three.gd"), preload("res://src/world_four.gd"), preload("res://src/world_five.gd"), preload("res://src/world_six.gd")]
const COMBATS = [preload("res://src/combat.gd"), preload("res://src/supermarket_combat.gd"), preload("res://src/festival_combat.gd"), preload("res://src/holiday_combat.gd"), preload("res://src/moving_day_combat.gd"), preload("res://src/billing_combat.gd")]
const COIN_COUNTS = [0,0,0,0,0,0,312,73,70,40,243,46,25,128,29,80,15,20,0,0,179,0,0,0,0,0,0,258,0,0,0,0,0,0,484,95,72,111,165,28,12,139]
const HEIGHTS = [180.0,162.0,171.0,187.0,178.0,160.0]
var checks := 0
var failures: Array[String] = []

class Host extends RefCounted:
	var world_one
	var world_two
	var world_three
	var world_four
	var world_five
	var world_six
	var runtime
	var combat
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var level_id := ""
	var player := Vector2(300,482)
	var camera := Vector2.ZERO
	var velocity := Vector2.ZERO
	var camera_lock = null
	var grounded := true
	var on_platform := false
	var crouching := false
	var invincible := 0.0
	var face := 1
	var mode := "play"
	var hearts := 3
	var score := 0
	var pop_count := 0
	var power := ""
	var power_time := 0.0
	var elapsed := 0.0
	var height := 180.0
	var boss = null
	var enemies: Array = []
	var bullets: Array = []
	var crates: Array = []
	var coins: Array = []
	var items: Array = []
	var roster: Array = []
	func view_width() -> float: return 738.0
	func character_height() -> float: return height
	func combat_participants() -> Array:
		if not roster.is_empty(): return roster
		return [{"host_player":true,"p":player,"height":height,"hearts":hearts,"grounded":grounded,"power":power,"crouching":crouching,"velocity":velocity,"face":face,"invincible":invincible}]
	func floor_at(x: float, y: float) -> float:
		var s: Dictionary = runtime.below(self,x,y)
		return float(meta.ground) if s.is_empty() else float(s.row[2])
	func _land(x: float, a: float, b: float) -> float:
		var s: Dictionary = runtime.land_on(self,x,a,b)
		return INF if s.is_empty() else float(s.row[2])
	func sfx(_name: String) -> void: pass

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func pickups(h: Host, world: int, dt: float = 0.0) -> void:
	if world == 1: h.combat._pickups(dt,h)
	else: h.combat.pickups_tick(dt,h)

func make_coin(p: Vector2, age: float = .3) -> Dictionary:
	return {"p":p,"v":Vector2.ZERO,"age":age,"rest":true}

func _initialize() -> void:
	var index := 0
	var crate_count := 0
	var path_coins := 0
	for world in range(1,7):
		for stage in ["1","2","3","4","5","6","S"]:
			var h := Host.new()
			h.level_id = "%d-%s" % [world,stage]
			h.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % h.level_id))
			h.level = h.meta.level
			h.player = Vector2(h.level.start,h.meta.ground)
			h.runtime = WORLDS[world-1].new()
			h.set("world_"+["one","two","three","four","five","six"][world-1],h.runtime)
			h.combat = COMBATS[world-1].new()
			h.runtime.reset(h)
			h.combat.reset(h)
			check(h.crates.size()==h.level.get("crates",[]).size(),h.level_id+" loads every crate")
			for n in h.crates.size():
				var c: Dictionary = h.crates[n]
				var source: Array = h.level.crates[n]
				var floor: Dictionary = h.runtime.below(h,source[0],source[1])
				check(not floor.is_empty() and c.p==Vector2(source[0],floor.row[2]),h.level_id+" crate floor "+str(n))
				check(c.hp==3 and c.give==source[2] and not c.broken,h.level_id+" crate content "+str(n))
				h.combat.hit_crate(h,c,1)
				h.combat.hit_crate(h,c,1)
				check(c.hp==1 and not c.broken and h.items.is_empty(),h.level_id+" crate needs third hit "+str(n))
				h.combat.hit_crate(h,c,1)
				check(c.broken and h.items.size()==1,h.level_id+" crate opens once "+str(n))
				var item: Dictionary = h.items[0]
				check(item.give==source[2] and item.p==c.p-Vector2(0,40) and item.vy==-600,h.level_id+" item pop "+str(n))
				h.combat.hit_crate(h,c,1)
				check(h.items.size()==1,h.level_id+" no duplicate crate drop "+str(n))
				# The source deliberately uses horizontal pickup distance only.
				item.age = .3
				item.rest = true
				h.player = Vector2(item.p.x,item.p.y+2000)
				h.hearts = 2
				h.power = ""
				h.power_time = 0
				pickups(h,world)
				check(h.items.size()==1,h.level_id+" strict 300ms item delay "+str(n))
				pickups(h,world,.001)
				check(h.items.is_empty(),h.level_id+" released item collected "+str(n))
				check((h.hearts==3 and h.power=="") if source[2]=="heart" else (h.power==source[2] and h.power_time==12),h.level_id+" correct pickup effect "+str(n))
				crate_count += 1
			# Exercise actual authored spawning without advancing combat/routes.
			h.camera.x = float(h.level.w)-h.view_width()
			match world:
				1:
					if stage=="S": h.runtime._spawn_bonus_coins(h)
				2: h.runtime._authored_coins(h)
				3: h.runtime._authored_coins(h)
				_: h.runtime.seed_pickups(h)
			check(h.coins.size()==COIN_COUNTS[index],h.level_id+" authored coin count")
			var authored := h.coins.duplicate(true)
			var expected := source_coin_positions(h,world)
			check(authored.size()==expected.size(),h.level_id+" source position count")
			for n in mini(authored.size(),expected.size()):
				check(authored[n].p.is_equal_approx(expected[n]),h.level_id+" source coin coordinate "+str(n))
			path_coins += authored.size()
			# Check every emitted coin is collectable by every source height.
			# This is contact/effect coverage, NOT an input-driven route claim.
			for coin in authored:
				for height in HEIGHTS:
					h.height = height
					h.coins = [coin.duplicate(true)]
					h.player = coin.p+Vector2(0,height*.4)
					h.camera.x = coin.p.x-300
					h.score = 0
					pickups(h,world)
					check(h.score==1 and h.coins.is_empty(),h.level_id+" coin contact at "+str(coin.p)+" height "+str(height))
			print("PICKUP_STAGE ",h.level_id," crates=",h.crates.size()," coins=",authored.size()," receipts=",h.level.receipts.size())
			if stage=="1": check_boundaries(h,world)
			index += 1
	check(index==42 and crate_count==116 and path_coins==2624,"all-stage inventory totals")
	if failures.is_empty(): print("PASS pickup inventory: ",checks," checks; 42 stages, 116 crates, 2624 path coins, six character heights")
	else:
		for failure in failures: push_error(failure)
		print("FAIL pickup inventory: ",failures.size()," of ",checks)
	quit(0 if failures.is_empty() else 1)

func check_boundaries(h: Host, world: int) -> void:
	h.player = Vector2(300,482)
	h.camera = Vector2.ZERO
	h.height = 180
	h.hearts = 3
	for age in [10.999,11.0,11.001]:
		h.coins = [make_coin(Vector2(700,410),age)]
		pickups(h,world)
		check(h.coins.size()==(1 if age<11 else 0),"W%d coin age %s" % [world,age])
	for x in [-60.001,-60.0,-59.999]:
		h.coins = [make_coin(Vector2(x,410))]
		pickups(h,world)
		check(h.coins.size()==(1 if x> -60 else 0),"W%d camera boundary %s" % [world,x])
	h.score = 0
	h.coins = [make_coin(Vector2(300,410),.25)]
	pickups(h,world)
	check(h.score==0 and h.coins.size()==1,"W%d strict coin spawn delay" % world)
	pickups(h,world,.001)
	check(h.score==1 and h.coins.is_empty(),"W%d live coin awards once" % world)
	# First living participant wins once. A down participant never consumes.
	h.roster = [{"p":Vector2(300,482),"height":180.0,"hearts":0,"down":true,"coins":0}, {"p":Vector2(300,482),"height":160.0,"hearts":2,"down":false,"coins":0}]
	h.coins = [make_coin(Vector2(300,410))]
	h.items = [{"p":Vector2(300,456),"age":.31,"rest":true,"give":"heart","vy":0.0}]
	h.score = 0
	pickups(h,world)
	check(h.score==1 and h.roster[0].coins==0 and h.roster[1].coins==1,"W%d per-player coin credit" % world)
	check(h.roster[0].hearts==0 and h.roster[1].hearts==3 and h.items.is_empty(),"W%d living-player heart credit" % world)
	h.roster.clear()

func source_coin_positions(h: Host, world: int) -> Array[Vector2]:
	# Independent expectations expanded from untouched META arrays, preserving
	# source row order, spacing and sine arcs. The runtime spawners run above.
	var result: Array[Vector2] = []
	match world:
		1:
			if h.level_id!="1-S": return result
			var pattern := 0
			for x in range(700,int(h.level.w)+120,560):
				for i in 8:
					var y := float(h.meta.ground)
					match pattern%4:
						0: y-=40
						1: y-=70+sin(i/7.0*PI)*170
						2: y-=200
						3: y-=40+(i%2)*80
					result.append(Vector2(x+i*46,y))
				pattern+=1
		2:
			for row in h.level.get("hz",[]):
				if row[0]!="coins": continue
				for i in int(row[4]):
					var fraction: float = i/float(row[4]-1) if row[4]>1 else .5
					var arc: float = sin(PI*i/maxf(1,row[4]-1))*float(row[5]) if row.size()>5 else 0
					result.append(Vector2(row[1]+(row[2]-row[1])*fraction,row[3]-arc))
		3:
			for row in h.level.get("coinRows",[]):
				for i in int(row[3]):
					var arc: float = sin(i/maxf(1,row[3]-1)*PI)*float(row[4]) if row.size()>4 else 0
					result.append(Vector2(row[0]+i*row[2],row[1]-arc))
		4:
			for row in h.level.get("cfg",{}).get("dash",{}).get("coins",[]): result.append(Vector2(row[0],row[1]))
		5:
			for row in h.level.get("coins",[]): result.append(Vector2(row[0],row[1]))
		6:
			for row in h.level.get("coinRows",[]): result.append(Vector2(row[0],row[1]))
	return result
