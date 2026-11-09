extends SceneTree
## Actual holiday world/combat/Captain modules with the real mutable PartyCombat
## bridge and actor-owned abilities. These are integration fixtures, not routes.
const Fixtures = preload("res://tests/test_party_combat_integration.gd")
const Party = preload("res://src/party_runtime.gd")
const Bridge = preload("res://src/party_combat.gd")
const World = preload("res://src/world_four.gd")
const Combat = preload("res://src/holiday_combat.gd")

class Host extends Fixtures.Host:
	var world_four = World.new()
	var order: Array = []
	var events: Array = []
	func view_width(): return 738.0
	func view_top(): return camera.y + 540 - 540 / 1.3
	func _land(x, old_y, new_y):
		var surface: Dictionary = world_four.land_on(self, x, old_y, new_y)
		return INF if surface.is_empty() else float(surface.row[2])
	func ability_inside_wall(point): return world_four.inside_wall(self, point)
	func combat_participants(): return bridge.participants() if bridge != null else []
	func combat_owner_slot(): return bridge.active_slot
	func party_capture_scene(actor): actor.scene_state.safe_position = world_four.safe_position
	func party_apply_scene(actor): world_four.safe_position = actor.scene_state.get("safe_position", actor.player)
	func call_combat_participant(participant, operation, args): return bridge.call_for_actor(participant.slot, operation, args)
	func credit_combat_pop(slot := -1):
		if slot != -2: bridge.credit_pop(bridge.active_slot if slot == -1 else slot)
	func hurt_player(from_x):
		if invincible > 0 or hearts <= 0 or mode != "play": return
		if movement_skills.blocks_damage() or abilities.blocks_damage(self): return
		hits.append(bridge.active_slot)
		hearts -= 1
		invincible = 1.5
		velocity.x = -350 if player.x < from_x else 350
	func collect_level_pickups(): order.append("pick:%d" % bridge.active_slot)
	func holiday_dash_step(): order.append("dash:%d" % bridge.active_slot)
	func holiday_event(event): events.append(event)

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func fresh(id := "4-1", mode := "p2", mate := "maya") -> Dictionary:
	var host = Host.new()
	host.level_id = id
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % id))
	host.level = host.meta.level
	host.player = Vector2(host.level.start, host.meta.ground)
	host.combat = Combat.new()
	host.world_four.reset(host)
	var party = Party.new()
	party.configure(mode, "jp", mate)
	party.start(id, host.player)
	for actor in party.actors:
		actor.scene_state.safe_position = actor.player
	party.actors[0].apply_native(host)
	host.world_four.safe_position = party.actors[0].player
	var bridge = Bridge.new()
	host.bridge = bridge
	bridge.configure(party, host)
	bridge.begin_shared()
	host.world_four.party_start(host)
	host.combat.reset(host, party.actors.size())
	return {"host": host, "party": party, "bridge": bridge}

func bot(host, x := 630.0, hp := 1) -> Dictionary:
	return host.combat.new_bot(host, x, host.world_four.surfaces(host)[0], "rush", {"hp": hp, "entered": true, "speed": 100.0})

func shot(x := 630.0, y := 400.0, owner := 1, damage := 1) -> Dictionary:
	return {"p": Vector2(x, y), "v": Vector2(780, 0), "enemy": false, "life": 20.0,
		"damage": damage, "owner_slot": owner, "owner_x": 600.0}

func hostile(x := 600.0, y := 400.0) -> Dictionary:
	return {"p": Vector2(x, y), "v": Vector2.ZERO, "enemy": true, "life": 20.0, "gravity": 0.0}

func finish(f: Dictionary) -> void:
	f.bridge.end_shared()
	f.host.world_four.invalidate_run()

func _initialize() -> void:
	_test_source_scaling()
	_test_pre_motion()
	_test_actor_safe_floors()
	_test_scene_order_and_transitions()
	_test_targeting_damage_and_loot()
	_test_projectile_ownership()
	_test_towels_and_foes()
	_test_captain()
	print("Holiday party integration: %d checks, %d failures. Real PartyCombat fixtures, not complete party routes." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_source_scaling() -> void:
	for id in World.SUPPORTED_LEVELS:
		var f := fresh(id)
		var h = f.host
		var expected := 0
		var actual := 0
		for i in h.level.waves.size():
			var source: Dictionary = h.level.waves[i]
			var sequence: Array = source.g.duplicate(true)
			sequence.append_array(source.get("x2", []))
			expected += sequence.size()
			actual += h.combat.waves[i].group.size()
			check(h.combat.waves[i].group == sequence, "%s wave %d retains source unsorted g+x2 order" % [id, i])
		check(actual == expected and h.combat.participant_count == 2, id + " final party participant count")
		finish(f)
	var f := fresh("4-6")
	var h = f.host
	h.world_four.spawn_foe("r", "bailiff", h)
	check(h.world_four.foes.entries[-1].hp == 46, "party Bailiff has source 46 HP")
	h.world_four.captain.start(h)
	check(h.world_four.captain.boss.hp == 120, "Captain uses final pair roster despite solo-compatible initial reset")
	finish(f)

func _test_pre_motion() -> void:
	var f := fresh("4-5", "cpu")
	var h = f.host
	var w = h.world_four
	var b = f.bridge
	var a: Dictionary = b.record(0)
	var c: Dictionary = b.record(1)
	var origin: float = w.deck.row[0]
	check(a.p.x == origin + 120 and c.p.x == origin + 210, "pedalo source slot spawn spacing replaces generic minus80 mate spawn")
	check(a.safe_position == a.p and c.safe_position == c.p, "pedalo initial safe floors are per actor")
	var robot: Dictionary = h.combat.new_bot(h, origin + 160, w.deck, "rush")
	var before: Vector2 = robot.p
	h.camera.x = 100
	w.pre_motion(0.1, h)
	check(is_equal_approx(w.level_time, 0.1) and is_equal_approx(w.elapsed, 0.1), "shared W4 clock advances once")
	check(is_equal_approx(w.deck.row[0], origin + 100), "moving deck uses previous camera once")
	check(a.p.x == origin + 220 and c.p.x == origin + 310, "same deck displacement carries both supported actors")
	check(is_equal_approx(a.p.y, w.deck.row[2]) and is_equal_approx(c.p.y, w.deck.row[2]), "same bob height carries both actors")
	check(robot.p.x == before.x + 100 and is_equal_approx(robot.p.y, w.deck.row[2]), "supported bot carried once, not once per actor")
	check(a.px == a.p.x and c.px == c.p.x, "source previous-x carry stamps each record")
	c.p.x = -500
	w.pre_motion(0, h)
	check(c.p.x == w.deck.row[0] + 30, "grounded CPU kept inside deck")
	c.down = true
	c.hearts = 0
	c.p.x = 5000
	w.pre_motion(0, h)
	check(c.p.x == w.deck.row[1] - 30 and c.down and c.hearts == 0, "source CPU clamp also applies while down without revival")
	c.down = false
	c.hearts = 3
	for actor in [a, c]:
		actor.p.y = w.cfg.water + 21
		actor.grounded = false
		actor.invincible = 10.0
		actor.velocity = Vector2(900, 1000)
	var original_safe: Vector2 = c.safe_position
	w.pre_motion(0, h)
	var center: float = (w.deck.row[0] + w.deck.row[1]) / 2
	check(a.p == Vector2(center - 40, w.deck.row[2]) and c.p == Vector2(center + 40, w.deck.row[2]), "water rescue has independent source minus40/plus40 slot destinations")
	check(a.hearts == 2 and c.hearts == 2 and h.hits == [0, 1], "water clears each victim immunity and calls actual actor damage once")
	check(a.velocity == Vector2.ZERO and c.velocity == Vector2.ZERO and a.grounded and c.grounded, "water resets velocities after each hurt callback")
	check(c.safe_position == original_safe, "water rescue does not overwrite source safe checkpoint")
	check(h.character == "jp", "nested water victim callbacks restore bound actor")
	c.p.y = w.cfg.water + 21
	c.grounded = false
	w.pre_motion(0, h)
	check(c.hearts == 2 and c.invincible == 0.9 and f.party.actors[1].abilities._hits == 2, "Maya water rescue uses her own alternating-hit passive once")
	c.hearts = 0
	c.down = true
	c.p.y = w.cfg.water + 100
	var down_pos: Vector2 = c.p
	w.pre_motion(0, h)
	check(c.p == down_pos and c.hearts == 0, "downed water actor is not silently rescued or damaged")
	finish(f)

	f = fresh()
	h = f.host
	w = h.world_four
	b = f.bridge
	var belt: Dictionary = w.surfaces(h).filter(func(surface): return surface.has("belt"))[0]
	for actor in b.participants(): actor.p = Vector2(1800 + actor.slot * 80, belt.row[2])
	w.pre_motion(0.2, h)
	check(is_equal_approx(b.record(0).p.x, 1814) and is_equal_approx(b.record(1).p.x, 1894), "conveyor carries each grounded actor once at70px/s")
	finish(f)
	f = fresh("4-4")
	h = f.host
	w = h.world_four
	b = f.bridge
	var boat: Dictionary = w.surfaces(h).filter(func(surface): return surface.has("bob"))[0]
	for actor in b.participants(): actor.p = Vector2((boat.row[0] + boat.row[1]) / 2 + actor.slot * 10, boat.row[2])
	w.pre_motion(0.1, h)
	check(is_equal_approx(b.record(0).p.y, boat.row[2]) and is_equal_approx(b.record(1).p.y, boat.row[2]), "harbour bobbing boat supports both actors")
	finish(f)

func _test_actor_safe_floors() -> void:
	var f := fresh()
	var h = f.host
	var b = f.bridge
	b.record(0).p = Vector2(200, 482)
	b.record(1).p = Vector2(600, 482)
	for actor in b.participants(): h.call_combat_participant(actor, h.world_four.after_motion, [h])
	check(f.party.actors[0].scene_state.safe_position == Vector2(200, 482) and f.party.actors[1].scene_state.safe_position == Vector2(600, 482), "after-motion writes independent safe floor through actual scene hooks")
	b.record(1).p = Vector2(640, 900)
	h.call_combat_participant(b.record(1), h.world_four.fall_off, [h])
	check(b.record(1).p == Vector2(600, 482) and b.record(0).p == Vector2(200, 482), "fall recovery resolves the victim's own safe floor")
	check(b.record(1).hearts == 2 and b.record(0).hearts == 3 and h.hits == [1], "fall damage scopes to P2 and keeps P1 untouched")
	check(h.world_four.safe_position == Vector2(200, 482), "fall callback restores P1 safe-floor facade")
	finish(f)

func _test_scene_order_and_transitions() -> void:
	var f := fresh()
	var h = f.host
	var b = f.bridge
	h.world_four.before_combat(0.1, h)
	check(h.order == ["pick:0", "pick:1", "dash:0", "dash:1"], "all actor picks precede all early Dash calls")
	check(is_equal_approx(h.world_four.foes.entries[0].t, 0.1), "custom foe timer advances once despite two pickup/Dash callbacks")
	b.record(1).down = true
	b.record(1).hearts = 0
	b.record(0).hearts = 1
	h.camera.x = h.world_four.cfg.check
	h.world_four.before_combat(0, h)
	check(b.record(0).hearts == 3 and b.record(1).hearts == 3 and not b.record(1).down and b.record(1).invincible == 2, "shared checkpoint heals and revives entire roster once")
	b.record(0).hearts = 2
	h.world_four.before_combat(0, h)
	check(b.record(0).hearts == 2, "checkpoint latch prevents repeated healing")
	finish(f)

	f = fresh("4-1", "cpu")
	h = f.host
	b = f.bridge
	h.world_four.before_combat(0, h)
	check(h.order == ["pick:0", "pick:1", "dash:0"], "CPU can collect pickups but source early Dash is human-only")
	var gate: Dictionary = h.world_four.gates[0]
	h.world_four.foes.clear()
	h.camera.x = gate.x - h.view_width()
	b.record(0).p.x = gate.x - 200
	b.record(1).p.x = gate.x - 100
	h.world_four.camera_step(0, h)
	check(not h.world_four.wiping, "CPU alone does not trigger source camera gate")
	b.record(0).p.x = gate.x - 100
	b.record(0).down = true
	b.record(0).hearts = 0
	h.world_four.camera_step(0, h)
	check(h.world_four.wiping, "downed human remains in source gate camera roster")
	h.world_four.wipe_elapsed = 1.43
	h.world_four.finish_frame(h)
	check(b.record(0).p.x == gate.to + 140 and b.record(1).p.x == gate.to + 230, "gate relocates both actors with source90px spacing")
	check(b.record(0).hearts == 3 and not b.record(0).down and b.record(0).invincible == 2, "gate revives downed actor")
	check(b.record(0).safe_position == b.record(0).p and b.record(1).safe_position == b.record(1).p, "gate updates independent safe positions")
	check(is_equal_approx(h.world_four.wipe_focus_end.x, 260.0), "gate iris focus reads relocated P1 record before facade restore")
	var after: Vector2 = b.record(1).p
	b.record(1).p.x += 20
	h.world_four.finish_frame(h)
	check(b.record(1).p.x == after.x + 20, "gate midpoint applies once")
	finish(f)

	f = fresh("4-S")
	h = f.host
	b = f.bridge
	var bonus_gate: Dictionary = h.world_four.dash.gates[0]
	b.record(1).p.x = bonus_gate.x + 1
	b.record(1).down = true
	b.record(1).hearts = 0
	var left: float = h.world_four.dash.left
	h.world_four._dash_tick(0.25, h)
	check(bonus_gate.got and h.world_four.dash.mult == 2 and is_equal_approx(h.world_four.dash.left, left + 7.75), "sponsored gate deliberately checks all players including downed P2")
	h.world_four._dash_tick(0.25, h)
	check(h.world_four.dash.mult == 2 and is_equal_approx(h.world_four.dash.left, left + 7.5), "bonus timer and gate reward advance once")
	b.record(1).p.x = h.level.w - 159
	h.world_four._dash_tick(0, h)
	check(h.world_four.dash.over and h.score == h.world_four.dash.bonus, "P2 can end source sponsored dash and award one shared bonus")
	finish(f)

func _test_targeting_damage_and_loot() -> void:
	var f := fresh()
	var h = f.host
	var b = f.bridge
	b.record(0).p = Vector2(200, 482)
	b.record(1).p = Vector2(600, 482)
	var enemy := bot(h, 550, 3)
	var old_t: float = enemy.t
	h.combat.enemies_tick(0.1, h)
	check(enemy.p.x == 560 and enemy.face == 1 and is_equal_approx(enemy.t, old_t + 0.1), "ordinary AI targets nearer P2 while its clock runs once")
	check(h.combat._nearest(h, 400).slot == 0, "horizontal nearest tie retains source roster order")
	b.record(1).down = true
	check(h.combat._nearest(h, 600).slot == 0, "downed P2 is not an enemy target")
	b.record(1).down = false
	h.enemies.clear()
	h.bullets = [hostile()]
	h.combat.projectiles_tick(0, h)
	check(b.record(1).hearts == 2 and b.record(0).hearts == 3 and h.hits == [1], "bill damages only actual P2 victim")
	check(f.party.actors[1].abilities._hits == 1 and f.party.actors[0].abilities._hits == 0, "victim's own ability passive checked once")
	check(h.character == "jp" and h.hearts == 3, "bill victim facade restored")
	b.record(1).invincible = 0.0
	h.bullets = [hostile()]
	h.combat.projectiles_tick(0, h)
	check(b.record(1).hearts == 2 and b.record(1).invincible == 0.9 and h.hits == [1], "Maya blocks her second eligible bill with her own passive")
	h.coins = [{"p": Vector2(600, 420), "v": Vector2.ZERO, "rest": true, "age": 1.0}]
	h.items = [{"p": Vector2(600, 400), "vy": 0.0, "rest": true, "age": 1.0, "give": "split"}]
	h.combat.pickups_tick(0, h)
	check(h.score == 1 and b.record(1).coins == 1 and b.record(0).coins == 0, "P2 coin changes own contribution and shared kitty once")
	check(b.record(1).power == "split" and b.record(0).power == "", "weapon pickup writes actual P2")
	h.items = [{"p": Vector2(600, 400), "vy": 0.0, "rest": true, "age": 1.0, "give": "heart"}]
	h.combat.pickups_tick(0, h)
	check(b.record(1).hearts == 3, "heart pickup merges alongside scoped damage")
	finish(f)
	check(f.party.actors[1].coins == 1 and f.party.actors[1].power == "split" and f.party.actors[1].hearts == 3, "all pickup writes survive shared-phase finish")

	f = fresh("4-1", "p2", "theo")
	h = f.host
	b = f.bridge
	for actor in b.participants(): actor.p = Vector2(600, 482)
	h.bullets = [hostile()]
	h.combat.projectiles_tick(0, h)
	check(b.record(0).hearts == 2 and b.record(1).hearts == 2 and h.hits == [0, 1], "source overlapping bill loop can hurt both actors before culling")
	finish(f)

func _test_projectile_ownership() -> void:
	var f := fresh()
	var h = f.host
	var b = f.bridge
	b.record(0).p = Vector2(200, 482)
	b.record(1).p = Vector2(600, 482)
	var enemy := bot(h, 350)
	var projectile := shot(650)
	projectile.first_frame = true
	projectile.owner_x = 200.0
	h.bullets = [projectile]
	h.combat.projectiles_tick(0, h)
	check(enemy.hp == 1, "first shot sweep starts at current owner record, not stamped oldx or bound P1")
	enemy.p.x = 630
	projectile.first_frame = true
	h.combat.projectiles_tick(0, h)
	check(enemy.state == "pop" and b.record(1).pop_count == 1 and b.record(0).pop_count == 0, "ordinary shot credits P2 pop")
	h.enemies.clear()
	enemy = bot(h, 630)
	projectile = shot()
	projectile.erase("owner_slot")
	h.bullets = [projectile]
	h.combat.projectiles_tick(0, h)
	check(enemy.state == "pop" and b.record(1).pop_count == 1 and b.record(0).pop_count == 0, "unowned party shot deals damage without accidental active-actor credit")
	h.enemies.clear()
	enemy = bot(h, 630)
	b.record(1).down = true
	b.record(1).hearts = 0
	h.bullets = [shot()]
	h.combat.projectiles_tick(0, h)
	check(b.record(1).pop_count == 2, "projectile fired before down still credits its original owner")
	h.enemies.clear()
	enemy = bot(h, 630)
	h.call_combat_participant(b.record(0), h.combat.damage_enemy, [h, enemy, 1])
	check(b.record(0).pop_count == 1 and b.record(1).pop_count == 2, "direct actor callback credits bound actor when owner sentinel is current")
	finish(f)
	check(f.party.actors[0].pop_count == 1 and f.party.actors[1].pop_count == 2, "all ownership credits persist after bridge end")

func _test_towels_and_foes() -> void:
	var f := fresh("4-3", "p2", "theo")
	var h = f.host
	var b = f.bridge
	var w = h.world_four
	h.camera.x = w.cfg.hold.cam
	for wave in h.combat.waves: wave.done = true
	w.before_combat(0.25, h)
	check(w.hold.on and is_equal_approx(w.hold.left, float(w.cfg.hold.time) / 1000 - 0.25), "shared hold clock advances once after source wave predicate")
	w.spawn_foe("r", "grab", h)
	var grab: Dictionary = w.foes.entries[-1]
	var towel: Dictionary = w.hold.towels[0]
	grab.x = towel.x
	grab.y = h.meta.ground
	grab.target = towel
	w.foes._grab_tick(grab, 0, h, w)
	check(is_same(grab.carry, towel) and is_same(towel.held, grab), "grabber owns exactly one source towel reference")
	grab.hp = 1
	var projectile := shot(grab.x, grab.y - 60)
	w.intercept_shot(projectile, grab.x - 1, h)
	check(grab.dead and towel.held == null and towel.back == 0.6, "P2 shot saves carried towel through real interceptor")
	check(b.record(1).pop_count == 1 and b.record(0).pop_count == 0, "towel grabber pop belongs to firing P2")
	w.foes.clear()
	w.spawn_foe("r", "ring", h)
	var ring: Dictionary = w.foes.entries[-1]
	ring.x = h.camera.x + 200
	ring.y = 482
	ring.vx = 0.0
	for actor in b.participants(): actor.p = Vector2(ring.x, 482)
	w.foes.tick(0, h, w)
	check(h.hits == [0, 1], "one custom foe contact pass iterates both real victims")
	w.foes.clear()
	w.spawn_foe("r", "banana", h)
	var banana: Dictionary = w.foes.entries[-1]
	banana.x = h.camera.x + 400
	banana.y = 482
	var seat: Dictionary = banana.seats[0]
	seat.hp = 1
	projectile = shot(banana.x + seat.offset, 382)
	w.intercept_shot(projectile, projectile.p.x - 1, h)
	check(seat.dead and b.record(1).pop_count == 2, "banana seat credits explicit P2 owner")
	var second: Dictionary = banana.seats[1]
	second.hp = 1
	projectile = shot(banana.x + second.offset, 382)
	projectile.erase("owner_slot")
	w.intercept_shot(projectile, projectile.p.x - 1, h)
	check(second.dead and b.record(1).pop_count == 2 and b.record(0).pop_count == 0, "unowned banana seat does not credit bound facade")
	var third: Dictionary = banana.seats[2]
	third.hp = 1
	projectile = shot(banana.x + third.offset, 382, 0)
	w.intercept_shot(projectile, projectile.p.x - 1, h)
	check(third.dead and b.record(0).pop_count == 1, "different banana seats independently credit distinct firing owners")
	w.foes.clear()
	w.spawn_foe("r", "melon", h)
	var melon: Dictionary = w.foes.entries[-1]
	projectile = shot(melon.x, melon.y - 20)
	projectile.erase("owner_slot")
	w.intercept_shot(projectile, melon.x - 1, h)
	check(melon.dead and b.record(0).pop_count == 1 and b.record(1).pop_count == 2, "unowned generic custom foe pop is uncredited")
	for t in w.hold.towels: t.gone = true
	var left: float = w.hold.left
	w._hold_tick(0, h)
	check(w.hold.resets == 1 and w.hold.towels.all(func(t): return not t.gone), "all towels reset once for party, not once per actor")
	check(w.hold.left == minf(float(w.cfg.hold.time) / 1000, left + 40), "source towel reset time cap preserved")
	w.hold.left = float(w.cfg.hold.time) / 1000
	w.hold.next = 0.0
	w.rng.seed = 411
	w._hold_tick(0, h)
	var pair_next: float = w.hold.next
	w.hold.next = 0.0
	w.rng.seed = 411
	h.combat.participant_count = 1
	w._hold_tick(0, h)
	check(is_equal_approx(pair_next, w.hold.next * 0.8), "party hold spawner retains source80percent interval")
	w.hold.left = 0
	var score_before: int = h.score
	w._hold_tick(0, h)
	check(w.hold.over and h.score == score_before + 40, "four kept towels award one shared40 reward")
	finish(f)

	f = fresh()
	h = f.host
	b = f.bridge
	w = h.world_four
	var suitcase: Dictionary = w.foes.entries[0]
	b.record(0).p = Vector2(200, 482)
	b.record(1).p = Vector2(suitcase.x + 20, suitcase.y)
	w.foes.tick(0, h, w)
	check(suitcase.dead and h.enemies.size() == 1, "P2 proximity opens source suitcase once")
	check(b.record(0).pop_count == 0 and b.record(1).pop_count == 0, "suitcase ambush never awards a pop")
	finish(f)

func _test_captain() -> void:
	var f := fresh("4-6", "p2", "theo")
	var h = f.host
	var b = f.bridge
	var w = h.world_four
	var c = w.captain
	h.camera.x = h.level.w - h.view_width()
	c.start(h)
	var boss: Dictionary = c.boss
	boss.x = h.level.w - 300
	boss.state = "throw"
	boss.t = 0.38
	b.record(0).p = Vector2(boss.x - 400, 482)
	b.record(1).p = Vector2(boss.x - 100, 482)
	c.tick(0.01, h, w)
	check(h.bullets.size() == 3, "Captain throws source phase1 three-bill volley once")
	check(is_equal_approx(h.bullets[1].v.x, (b.record(1).p.x - (boss.x - 60)) / 0.95), "Captain volley aims at nearest P2")
	check(is_equal_approx(boss.t, 0.39), "Captain clock advances once")
	h.bullets.clear()
	boss.state = "drift"
	boss.hp = 120
	var projectile := shot(boss.x, boss.y - 100, 1, 99)
	check(c.intercept_shot(projectile, boss.x - 1, h, w) and boss.hp == 119, "Captain body keeps fixed one-point damage")
	check(b.record(1).boss_hits == 1 and not b.record(0).has("boss_hits"), "Captain counts hit on stable firing owner")
	boss.phase = 3
	boss.face = -1
	projectile = shot(boss.x + 70, boss.y - 120, 0, 99)
	check(c.intercept_shot(projectile, projectile.p.x - 1, h, w) and boss.hp == 116 and b.record(0).boss_hits == 1, "phase3 valve retains fixed3 damage and credits P1 separately")
	projectile = shot(boss.x, boss.y - 100)
	projectile.erase("owner_slot")
	c.intercept_shot(projectile, boss.x - 1, h, w)
	check(b.record(0).boss_hits == 1 and b.record(1).boss_hits == 1, "unowned Captain hit cannot borrow active actor")
	b.record(1).down = true
	b.record(1).hearts = 0
	projectile = shot(boss.x, boss.y - 100)
	c.intercept_shot(projectile, boss.x - 1, h, w)
	check(b.record(1).boss_hits == 2, "Captain hit retains downed projectile owner")
	b.record(1).down = false
	b.record(1).hearts = 3
	boss.hp = 29
	boss.called = {"a": true, "b": true}
	c.tick(0, h, w)
	check(w.foes.entries.filter(func(foe): return foe.kind == "jet").size() == 2, "party Captain quarter-health call spawns both source jet skis")
	boss.wave = [{"x": h.camera.x + 300, "vx": 400.0, "t": 0.0}]
	for actor in b.participants():
		actor.p = Vector2(h.camera.x + 340, 482)
		actor.invincible = 0.0
	boss.state = "rear"
	boss.t = 0.0
	c.tick(0.1, h, w)
	check(b.record(0).hearts == 2 and b.record(1).hearts == 2 and h.hits == [0, 1], "Captain wave applies per-actor victim damage in one shared pass")
	check(boss.wave[0].x == h.camera.x + 340 and is_equal_approx(boss.wave[0].t, 0.1), "shared boss wave moves only once")
	boss.wave.clear()
	boss.state = "charge"
	boss.dir = -1
	boss.x = h.level.w - 300
	for actor in b.participants():
		actor.p = Vector2(boss.x - 60, 482)
		actor.invincible = 0.0
	c.tick(0, h, w)
	check(b.record(0).hearts == 1 and b.record(1).hearts == 1 and h.hits == [0, 1, 0, 1], "Captain charge neck sweep separately damages both actual actors")
	c.jar = {"p": Vector2(h.camera.x + 500, 452), "v": Vector2.ZERO, "t": 0.61, "got": false}
	b.record(0).p.x = h.camera.x + 100
	b.record(1).p.x = c.jar.p.x
	check(w.jar_tick(0, h) == "clear" and c.jar.got, "P2 can collect physical Captain jar")
	check(w.jar_tick(1, h) == "", "Captain jar clear reports once")
	finish(f)
	check(f.party.actors[0].scene_state.boss_hits == 1 and f.party.actors[1].scene_state.boss_hits == 2, "Captain boss-hit counters persist in actor scene state")
