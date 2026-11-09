extends SceneTree
## Actual W1/W2 combat with scoped native actor facades, isolated fixture world.
## No route skips are advertised as progression; main party scheduling is separate.
const Party = preload("res://src/party_runtime.gd")
const Bridge = preload("res://src/party_combat.gd")
const Combat = preload("res://src/combat.gd")
const Market = preload("res://src/supermarket_combat.gd")
const WorldOne = preload("res://src/world_one.gd")
const WorldTwo = preload("res://src/world_two.gd")
const Bus = preload("res://src/bus_ride.gd")
class Host:
	extends RefCounted
	var character := "jp"
	var player := Vector2.ZERO
	var velocity := Vector2.ZERO
	var checkpoint := Vector2.ZERO
	var face := 1
	var grounded := true
	var jump_held := false
	var cooldown := 0.0
	var invincible := 0.0
	var hearts := 3
	var on_platform := false
	var drop_time := 0.0
	var crouching := false
	var hurt_lock := 0.0
	var lock_animation := "hit"
	var shoot_time := 0.0
	var shoot_diagonal := false
	var aim_time := 0.0
	var aim_up := false
	var animation_time := 0.0
	var player_animation := "idle"
	var pop_count := 0
	var power := ""
	var power_time := 0.0
	var _last_floor := 482.0
	var _pre_grounded := true
	var abilities = preload("res://src/abilities.gd").new()
	var movement_skills = preload("res://src/movement_skills.gd").new()

	var level_id := "1-1"
	var meta := {"ground": 482.0}
	var level := {"w": 2000.0, "fall": 882.0, "solids": [[0, 2000, 482]], "plats": [], "waves": [[0, [[0, "r", "rush"]]]], "crates": [], "checks": []}
	var camera := Vector2.ZERO
	var camera_speed := 0.0
	var camera_lock = null
	var score := 0
	var elapsed := 0.0
	var mode := "play"
	var status := ""
	var enemies: Array = []
	var bullets: Array = []
	var coins: Array = []
	var crates: Array = []
	var items: Array = []
	var boss = null
	var combat
	var world_one = WorldOne.new()
	var world_two = WorldTwo.new()
	var bus_ride = Bus.new()
	var bridge
	var hits: Array = []
	var hop_calls: Array = []
	func character_height(): return float(preload("res://src/abilities.gd").HEIGHTS.get(character, 180.0))
	func view_width(): return 960.0
	func view_top(): return 0.0
	func floor_at(_x, _y): return 482.0
	func _land(_x, old_y, new_y): return 482.0 if old_y <= 482 and new_y >= 482 else INF
	func ability_inside_wall(_p): return false
	func sfx(_effect): pass
	func add_coins(p, count):
		for i in count: coins.append({"p": p, "v": Vector2.ZERO, "age": 0.0, "rest": false})
	func scene_objective(_dt): pass
	func combat_participants(): return bridge.participants()
	func hurt_combat_participant(participant, from_x): bridge.call_for_actor(participant.slot, hurt_player, [from_x])
	func call_combat_participant(participant, operation, args):
		hop_calls.append(participant.slot)
		return bridge.call_for_actor(participant.slot, operation, args)
	func credit_combat_pop(owner_slot := -1): bridge.credit_pop(bridge.active_slot if owner_slot == -1 else owner_slot)
	func hurt_player(from_x):
		if invincible > 0 or hearts <= 0 or abilities.blocks_damage(self): return
		hits.append(bridge.active_slot)
		hearts -= 1
		invincible = 1.5
		velocity.x = -350 if player.x < from_x else 350
	func combat_bubbles_tick(_dt): pass
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func fresh(world: int) -> Dictionary:
	var host = Host.new()
	host.level_id = "%d-1" % world
	var party = Party.new()
	party.configure("p2", "jp", "maya")
	party.start(host.level_id, Vector2(200, 482))
	party.actors[1].player = Vector2(600, 482)
	party.actors[0].apply_native(host)
	var bridge = Bridge.new()
	host.bridge = bridge
	bridge.configure(party, host)
	bridge.begin_shared()
	if world == 1:
		host.combat = Combat.new()
		host.world_one.reset(host)
		host.combat.reset(host, 11, 2)
	else:
		host.level.waves = [{"at": 0.0, "g": [[0, "r", "rush"]], "x": [[100, "l", "throw"]]}]
		host.combat = Market.new()
		host.world_two.reset(host)
		host.combat.reset(host, 2)
	return {"host": host, "party": party, "bridge": bridge}
func _initialize() -> void:
	for world in [1, 2]:
		var setup := fresh(world)
		var host = setup.host
		var party = setup.party
		var bridge = setup.bridge
		var name := "W%d " % world
		check(host.combat.waves[0].group.size() == 2, name + "party wave addition")
		if world == 1: check(host.combat.waves[0].group[1] == [600.0, "l", "rush"], "W1 source extra copies last kind with opposite side and 600ms delay")
		host.combat.spawn(host, "r", "mini" if world == 1 else "big")
		check(host.enemies[0].hp == (46 if world == 1 else 34), name + "source party mini health")
		host.enemies.clear()
		host.combat.spawn(host, "r", "rush")
		var bot: Dictionary = host.enemies[0]
		bot.p = Vector2(550, 482)
		bot.entered = true
		bot.stop = 0.0
		bot.speed = 100.0
		if world == 1: host.combat._update_enemies(0.1, host)
		else: host.combat.enemies_tick(0.1, host)
		check(bot.p.x > 550 and bot.face == 1, name + "enemy selects nearer P2 instead of active P1")
		if world == 1: check(host.hop_calls == [1], "W1 gap-hop helper bound to selected target")
		host.enemies.clear()
		host.bullets = [{"p": Vector2(600, 400), "v": Vector2(-100, 0), "gravity": 0.0, "enemy": true, "life": 3.0}]
		if world == 1: host.combat.projectiles(0, host)
		else: host.combat.projectiles_tick(0, host)
		check(party.actors[1].hearts == 2 and party.actors[0].hearts == 3 and host.hits == [1], name + "hostile shot damages actual P2 through facade")
		check(host.character == "jp" and host.hearts == 3, name + "victim facade restored")
		bridge.record(1).invincible = 0.0
		host.bullets = [{"p": Vector2(600, 400), "v": Vector2(-100, 0), "gravity": 0.0, "enemy": true, "life": 3.0}]
		if world == 1: host.combat.projectiles(0, host)
		else: host.combat.projectiles_tick(0, host)
		check(party.actors[1].hearts == 2 and party.actors[1].invincible == 0.9 and host.hits == [1], name + "P2 Maya passive blocks her second hit using her own ability instance")

		host.coins = [{"p": Vector2(600, 420), "v": Vector2.ZERO, "rest": true, "age": 1.0}]
		host.items = [{"p": Vector2(600, 400), "vy": 0.0, "rest": true, "age": 1.0, "give": "split"}]
		if world == 1: host.combat._pickups(0, host)
		else: host.combat.pickups_tick(0, host)
		check(host.score == 1 and bridge.record(1).coins == 1 and bridge.record(0).coins == 0, name + "P2 coin counted once in kitty and personal tally")
		check(bridge.record(1).power == "split" and bridge.record(0).power == "", name + "P2 receives own weapon")
		# First-frame sweep must start at P2, not at P1 on the far left. The
		# unrelated robot at x=350 would be hit by the old P1-origin sweep.
		host.combat.spawn(host, "r", "rush")
		bot = host.enemies[0]
		bot.p = Vector2(350, 482)
		bot.hp = 1
		host.bullets = [{"p": Vector2(650, 400), "v": Vector2(780, 0), "enemy": false, "life": 3.0, "damage": 1, "first_frame": true, "owner_slot": 1, "owner_x": 600.0}]
		if world == 1: host.combat.projectiles(0, host)
		else: host.combat.projectiles_tick(0, host)
		check(bot.hp == 1, name + "first-frame sweep uses correct owner")
		bot.p.x = 630
		host.bullets[0].first_frame = true
		if world == 1: host.combat.projectiles(0, host)
		else: host.combat.projectiles_tick(0, host)
		check(bot.state == "pop" and bridge.record(1).pop_count == 1 and bridge.record(0).pop_count == 0, name + "friendly shot credits P2 kill")
		host.enemies.clear()
		host.combat.spawn(host, "r", "rush")
		bot = host.enemies[0]
		bot.p = Vector2(650, 482)
		bot.hp = 1
		host.bullets = [{"p": Vector2(650, 400), "v": Vector2.ZERO, "enemy": false, "life": 3.0, "damage": 1}]
		if world == 1: host.combat.projectiles(0, host)
		else: host.combat.projectiles_tick(0, host)
		check(bot.state == "pop" and bridge.record(1).pop_count == 1 and bridge.record(0).pop_count == 0, name + "missing-owner projectile never credits active actor")
		bridge.end_shared()
		check(party.actors[1].coins == 1 and party.actors[1].pop_count == 1 and party.actors[1].power == "split", name + "all pickup and kill writes survive shared-phase finish")
	print("W1/W2 party combat: %d checks, %d failures. Isolated facade integration, not complete party routes." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
