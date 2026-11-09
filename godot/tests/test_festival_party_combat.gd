extends SceneTree
## Real W3 combat, world/boss modules, actor abilities and mutable PartyCombat.
## Isolated shared phases, not certification of main's complete party scheduler.
const Fixtures = preload("res://tests/test_party_combat_integration.gd")
const Party = preload("res://src/party_runtime.gd")
const Bridge = preload("res://src/party_combat.gd")
const Combat = preload("res://src/festival_combat.gd")
const World = preload("res://src/world_three.gd")

class Host extends Fixtures.Host:
	var world_three = World.new()
	var bubble_calls := 0
	var fx: Array = []
	func combat_owner_slot(): return bridge.active_slot
	func hurt_player(from_x):
		# Match main: damage eligibility, then each actor's immunity, exactly once.
		if invincible > 0 or hearts <= 0 or mode != "play": return
		if movement_skills.blocks_damage() or abilities.blocks_damage(self): return
		hits.append(bridge.active_slot)
		hearts -= 1
		invincible = 1.5
		velocity.x = -350 if player.x < from_x else 350
	func damage_enemy(enemy, damage):
		bullets.append({"p": enemy.p - Vector2(0, 56), "v": Vector2(0.1, 0), "life": 20.0,
			"ghost": true, "ghost_age": 0.0, "enemy": false, "damage": damage,
			"owner_slot": combat_owner_slot(), "owner_x": player.x})
	func combat_bubbles_tick(dt):
		bubble_calls += 1
		# Source has one distinct Ama. Global held state advances just once.
		for participant in combat_participants():
			if participant.character == "ama":
				bridge.call_for_actor(participant.slot, _bubbles, [dt])
				return
	func _bubbles(dt): abilities.bubbles_tick(dt, self)
	func charge_meter(): abilities.tick(0, {}, self, true)
	func fx_puff(_p, _color, _count, _speed): fx.append("puff")
	func fx_bits(_p): fx.append("bits")
	func fx_shake(_strength): fx.append("shake")
	func fx_coin(_p): fx.append("coin")
	func fx_item(_p, _give): fx.append("item")

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func fresh(mode := "p2", mate := "maya") -> Dictionary:
	var host = Host.new()
	host.level_id = "3-1"
	host.level = {"w": 2000.0, "fall": 742.0, "solids": [[-400, 2400, 482]], "plats": [], "crates": []}
	host.meta = {"ground": 482.0, "l3": {"waves": [[0, [[0, "r", "rush"], [100, "l", "flat", 1]]]]}}
	var party = Party.new()
	party.configure(mode, "jp", mate)
	party.start(host.level_id, Vector2(200, 482))
	party.actors[1].player = Vector2(600, 482)
	party.actors[0].apply_native(host)
	host.world_three.reset(host)
	host.combat = Combat.new()
	host.combat.reset(host, 2)
	var bridge = Bridge.new()
	host.bridge = bridge
	bridge.configure(party, host)
	bridge.begin_shared()
	return {"host": host, "party": party, "bridge": bridge}

func bot(host, x := 630.0, hp := 1) -> Dictionary:
	return host.combat.new_bot(host, x, host.world_three.surfaces(host)[0], "rush", {"hp": hp, "entered": true, "speed": 100.0})

func shot(x := 630.0, owner := 1, ghost := false) -> Dictionary:
	return {"p": Vector2(x, 400), "v": Vector2(0.1 if ghost else 780.0, 0), "enemy": false,
		"life": 20.0, "damage": 1, "owner_slot": owner, "owner_x": 600.0, "ghost": ghost}

func hostile(x := 600.0, y := 400.0) -> Dictionary:
	return {"p": Vector2(x, y), "v": Vector2(-100, 0), "enemy": true, "life": 20.0, "gravity": 0.0}

func _initialize() -> void:
	_test_targeting_and_victims()
	_test_pickups_and_stomps()
	_test_projectile_ownership()
	_test_boss_attribution()
	_test_bubbles()
	_test_source_scaling()
	print("Festival party combat: %d checks, %d failures. Isolated shared phases, not complete party routes." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_targeting_and_victims() -> void:
	var f := fresh()
	var h = f.host
	var b = f.bridge
	var enemy := bot(h, 550.0, 3)
	var previous_t: float = enemy.t
	h.combat.enemies_tick(0.1, h)
	check(enemy.p.x == 560 and enemy.face == 1, "nearest bot target is P2 rather than bound P1")
	check(is_equal_approx(enemy.t, previous_t + 0.1), "enemy tick remains a single shared invocation")
	check(h.combat._nearest(h, 400).slot == 0, "nearest horizontal tie preserves source actor order")
	b.record(1).down = true
	check(h.combat._nearest(h, 600).slot == 0, "downed actors excluded from targeting")
	b.record(1).down = false
	h.enemies.clear()
	h.bullets = [hostile()]
	h.combat.projectiles_tick(0, h)
	check(f.party.actors[1].hearts == 2 and f.party.actors[0].hearts == 3 and h.hits == [1], "bill hurts the actual P2 victim")
	check(f.party.actors[1].abilities._hits == 1 and f.party.actors[0].abilities._hits == 0, "one eligible Maya hit checks her own passive exactly once")
	check(h.character == "jp" and h.hearts == 3 and h.player == Vector2(200, 482), "damage callback restores P1 facade")
	b.record(1).invincible = 0.0
	h.bullets = [hostile()]
	h.combat.projectiles_tick(0, h)
	check(f.party.actors[1].hearts == 2 and f.party.actors[1].invincible == 0.9 and h.hits == [1], "Maya blocks her second eligible hit")
	check(f.party.actors[1].abilities._hits == 2, "Maya passive is not double-called by collision prechecks")
	f.party.actors[0].movement_skills.dash_remaining = 0.2
	h.bullets = [hostile(200)]
	h.combat.projectiles_tick(0, h)
	check(b.record(0).hearts == 3 and h.hits == [1], "P1 dash immunity belongs to P1")
	b.record(1).invincible = 0.0
	h.bullets = [hostile()]
	h.combat.projectiles_tick(0, h)
	check(b.record(1).hearts == 1 and h.hits == [1, 1], "P1 dash does not protect P2")
	b.record(1).invincible = 0.0
	b.record(1).crouching = true
	h.bullets = [hostile(600, 380)]
	h.combat.projectiles_tick(0, h)
	check(b.record(1).hearts == 1 and h.bullets.size() == 1, "bill uses P2 Maya height and crouching silhouette")
	b.record(1).crouching = false
	b.record(1).invincible = 2.0
	var tied_bill := hostile()
	tied_bill.tie = true
	h.bullets = [tied_bill]
	h.combat.projectiles_tick(0, h)
	check(b.record(1).get("tied", 0) == 2.2 and not b.record(0).has("tied"), "tie belongs to P2 even when invulnerability rejects damage")
	# A bill can touch both source actors in one loop, even after marked dead.
	b.record(0).p = Vector2(600, 482)
	f.party.actors[0].movement_skills.dash_remaining = 0.0
	b.record(1).invincible = 0.0
	h.bullets = [hostile()]
	h.combat.projectiles_tick(0, h)
	check(b.record(0).hearts == 2 and b.record(1).hearts == 1 and f.party.actors[1].abilities._hits == 4, "overlapping actors receive independent damage/passive resolution")
	b.end_shared()

func _test_pickups_and_stomps() -> void:
	for mode in ["p2", "cpu"]:
		var f := fresh(mode)
		var h = f.host
		var b = f.bridge
		h.coins = [{"p": Vector2(600, 420), "v": Vector2.ZERO, "age": 1.0, "rest": true}]
		h.items = [{"p": Vector2(600, 400), "vy": 0.0, "age": 1.0, "rest": true, "give": "wellies"}]
		h.combat.pickups_tick(0, h)
		check(h.score == 1 and b.record(1).coins == 1 and b.record(0).coins == 0, mode + " coin increments shared kitty once and P2 contribution once")
		check(b.record(1).power == "wellies" and b.record(1).power_time == 12 and b.record(0).power == "", mode + " P2 alone receives weapon pickup")
		check(h.fx == ["coin", "item"], mode + " pickup presentation hooks remain once per pickup")
		b.record(1).hearts = 1
		h.items = [{"p": Vector2(600, 400), "vy": 0.0, "age": 1.0, "rest": true, "give": "heart"}]
		h.combat.pickups_tick(0, h)
		check(b.record(1).hearts == 2 and b.record(0).hearts == 3, mode + " heart belongs to collecting actor")
		b.record(1).p.y = 400
		b.record(1).grounded = false
		b.record(1).velocity = Vector2(0, 101)
		var enemy := bot(h, 600)
		h.combat.enemies_tick(0, h)
		check(enemy.state == "pop" and b.record(1).pop_count == 1 and b.record(0).pop_count == 0, mode + " Wellies credits the stomper")
		check(b.record(1).velocity.y == -800 and h.velocity.y == 0, mode + " Wellies rebound changes only stomper velocity")
		b.end_shared()
		check(f.party.actors[1].coins == 1 and f.party.actors[1].pop_count == 1 and f.party.actors[1].power == "wellies", mode + " credits and pickups persist at phase end")

func _test_projectile_ownership() -> void:
	var f := fresh()
	var h = f.host
	var b = f.bridge
	var wrong_bot := bot(h, 350)
	var fired := shot(650)
	fired.first_frame = true
	fired.owner_x = 200.0 # Owner moved before this shared shot pass.
	h.bullets = [fired]
	h.combat.projectiles_tick(0, h)
	check(wrong_bot.hp == 1, "first-frame sweep uses current owner record rather than stale owner_x or P1")
	h.enemies.clear()
	var enemy := bot(h)
	fired.first_frame = true
	h.combat.projectiles_tick(0, h)
	check(enemy.state == "pop" and b.record(1).pop_count == 1 and b.record(0).pop_count == 0, "ordinary shot credits P2")
	b.call_for_actor(1, h.charge_meter)
	b.call_for_actor(0, h.charge_meter)
	check(is_equal_approx(f.party.actors[1].abilities.meter, 0.57) and f.party.actors[0].abilities.meter == 0.5, "kill charge reaches owner's own ability meter")
	check(enemy.p.x == 636 and h.coins[0].p.x == 636, "source shove still precedes death drop")
	check(h.fx.count("bits") == 1 and h.fx.count("shake") == 1 and h.fx.count("puff") == 1, "ordinary kill retains single presentation calls")
	h.enemies.clear()
	enemy = bot(h)
	b.record(1).hearts = 0
	b.record(1).down = true
	h.bullets = [shot(630, 1, true)]
	h.combat.projectiles_tick(0, h)
	check(enemy.state == "pop" and b.record(1).pop_count == 2, "ghost keeps explicit owner even after owner goes down")
	for owner in [-2, 99]:
		h.enemies.clear()
		enemy = bot(h)
		h.bullets = [shot(630, owner, true)]
		h.combat.projectiles_tick(0, h)
		check(enemy.state == "pop" and b.record(0).pop_count == 0 and b.record(1).pop_count == 2, "unowned or absent owner never credits bound actor " + str(owner))
	h.enemies.clear()
	enemy = bot(h)
	var unowned := shot()
	unowned.erase("owner_slot")
	h.bullets = [unowned]
	h.combat.projectiles_tick(0, h)
	check(enemy.state == "pop" and b.record(0).pop_count == 0 and b.record(1).pop_count == 2, "missing-owner shot can damage but cannot invent ownership")
	h.enemies.clear()
	enemy = bot(h)
	b.call_for_actor(1, Callable(h.combat, "damage_enemy"), [h, enemy, 1])
	check(b.record(1).pop_count == 3 and b.record(0).pop_count == 0, "direct actor damage defaults to its bound owner")
	h.enemies.clear()
	enemy = bot(h)
	h.combat.kill_enemy(h, enemy, false)
	check(enemy.state == "pop" and b.record(1).pop_count == 3, "boss cleanup pops remain uncredited")
	b.end_shared()
	check(f.party.actors[1].pop_count == 3 and f.party.actors[0].pop_count == 0, "explicit and actor callback kill writes survive phase merge")

func _test_boss_attribution() -> void:
	var f := fresh()
	var h = f.host
	var b = f.bridge
	h.combat.start_boss(h, {"cam": 0, "kind": "seller", "name": "Seller", "hp": 60, "hp2": 80, "mini": "Sorted"})
	check(h.boss.state.hp == 80 and h.boss.state.max == 80, "boss receives source participant-count HP")
	h.boss.state.x = 630.0
	h.boss.state.state = "walk"
	h.bullets = [shot(630), shot(630, 1, true)]
	h.combat.projectiles_tick(0, h)
	check(h.boss.state.hp == 78 and b.record(1).boss_hits == 2 and b.record(0).get("boss_hits", 0) == 0, "ordinary and ghost boss hits credit actual owner")
	check(h.world_three.cheer == 0.6, "source boss-hit cheer remains active")
	h.boss.state.state = "enter"
	h.bullets = [shot(630)]
	h.combat.projectiles_tick(0, h)
	check(b.record(1).boss_hits == 2, "rejected boss hit does not award contribution")
	h.boss.state.state = "walk"
	h.bullets = [shot(630, -2)]
	h.combat.projectiles_tick(0, h)
	check(h.boss.state.hp == 77 and b.record(1).boss_hits == 2 and b.record(0).get("boss_hits", 0) == 0, "unowned boss damage remains uncredited")
	b.record(0).hearts = 0
	b.record(0).down = true
	b.record(1).p = Vector2(600, 482)
	h.boss.state.x = 600.0
	h.boss.state.waves = [{"x": 600.0, "vx": 0.0, "t": 0.0}]
	h.combat.boss_tick(0, h)
	check(h.hits == [1] and b.record(1).hearts == 2, "filtered boss victim index resolves P2 even when leader is down")
	b.end_shared()
	check(f.party.actors[1].scene_state.boss_hits == 2, "boss contribution persists in P2 scene state")

func _test_bubbles() -> void:
	var f := fresh("cpu", "ama")
	var h = f.host
	var b = f.bridge
	var held := bot(h, 600)
	held.ab_bubble = 0.15
	held.ab_bubble_total = 4.2
	held.ab_floor = 482.0
	var ordinary := bot(h, 800, 3)
	var ordinary_t: float = ordinary.t
	var held_t: float = held.t
	h.combat.enemies_tick(0.1, h)
	check(held.t == held_t and held.ab_bubble == 0.15 and is_equal_approx(ordinary.t, ordinary_t + 0.1), "combat skips held AI and never advances global bubble clock")
	h.combat_bubbles_tick(0.1)
	check(h.bubble_calls == 1 and is_equal_approx(held.ab_bubble, 0.05) and h.enemies.back() == held, "one global bubble pass decrements once and appends held bots in source order")
	h.combat.enemies_tick(0.1, h)
	h.combat_bubbles_tick(0.1)
	check(h.bullets.size() == 1 and h.bullets[0].ghost and h.bullets[0].owner_slot == 1, "bubble release produces CPU Ama-owned ghost through scoped facade")
	h.combat.projectiles_tick(0, h)
	check(held.state == "pop" and b.record(1).pop_count == 1 and b.record(0).pop_count == 0, "bubble-release ghost kill credits Ama")
	check(h.character == "jp" and h.bubble_calls == 2, "bubble ownership callback restores facade without second world tick")
	b.end_shared()
	check(f.party.actors[1].pop_count == 1, "bubble kill survives shared phase merge")

func _test_source_scaling() -> void:
	for id in ["3-1", "3-2", "3-3", "3-4", "3-5", "3-6", "3-S"]:
		var f := fresh()
		var h = f.host
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/" + id + ".json"))
		h.level_id = id
		h.meta = data
		h.level = data.level
		h.world_three.reset(h)
		h.combat.reset(h, 2)
		var expected: Array = []
		for source in data.l3.get("waves", []):
			var entries: Array = []
			for entry in source[1]: entries.append(entry.slice(0, 3))
			expected.append(entries)
		var actual: Array = []
		for wave in h.combat.waves: actual.append(wave.group)
		check(actual == expected, id + " party preserves all flagged wave entries in authored order")
		if id == "3-5":
			h.camera.x = float(data.l3.harv.cam)
			h.world_three.hayride.harvester_tick(0, h, h.world_three)
			check(is_equal_approx(h.world_three.hayride.harvester.hp, float(data.l3.harv.hp) * 1.3), "3-5 harvester retains source 1.3x party HP")
		for key in ["mini", "boss"]:
			var config: Variant = data.l3.get(key, null)
			if config is not Dictionary or config.is_empty(): continue
			h.boss = null
			var entry: Dictionary = config.duplicate(true)
			if key == "boss": entry.cam = float(h.level.w) - h.view_width()
			h.combat.start_boss(h, entry)
			check(h.boss.state.hp == config.hp2, id + " " + key + " uses exact source hp2")
		f.bridge.end_shared()
