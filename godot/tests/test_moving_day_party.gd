extends SceneTree
## Actual Moving Day controllers and mutable PartyCombat bridge. Focused source
## fixtures deliberately position actors; these are not complete party routes.
const Fixtures = preload("res://tests/test_party_combat_integration.gd")
const Party = preload("res://src/party_runtime.gd")
const Bridge = preload("res://src/party_combat.gd")
const World = preload("res://src/world_five.gd")
const Combat = preload("res://src/moving_day_combat.gd")

class Host extends Fixtures.Host:
	var world_five = World.new()
	var order: Array = []
	func view_width(): return 738.0
	func view_top(): return camera.y + 540 - 540 / 1.3
	func floor_at(x, y):
		var q: Dictionary = world_five.below(self, x, y)
		return float(meta.ground) if q.is_empty() else float(q.row[2])
	func _land(x, old_y, new_y):
		var q: Dictionary = world_five.land_on(self, x, old_y, new_y)
		return INF if q.is_empty() else float(q.row[2])
	func ability_inside_wall(point): return world_five.inside_wall(self, point)
	func combat_participants(): return bridge.participants() if bridge != null else []
	func combat_owner_slot(): return bridge.active_slot
	func party_capture_scene(actor):
		actor.scene_state.safe_position = world_five.safe_position
		actor.scene_state.carrying = world_five.carrying
	func party_apply_scene(actor):
		world_five.safe_position = actor.scene_state.get("safe_position", actor.player)
		world_five.carrying = actor.scene_state.get("carrying", false)
	func call_combat_participant(p, operation, args): return bridge.call_for_actor(p.slot, operation, args)
	func credit_combat_pop(slot := -1):
		if slot != -2: bridge.credit_pop(bridge.active_slot if slot == -1 else slot)
	func collect_level_pickups(): order.append("pick:%d" % bridge.active_slot)

var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func fresh(id := "5-1", mode := "p2", mate := "maya") -> Dictionary:
	var h = Host.new()
	h.level_id = id
	h.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % id))
	h.level = h.meta.level
	h.player = Vector2(h.level.start, h.meta.ground)
	h.combat = Combat.new()
	h.world_five.reset(h)
	var p = Party.new()
	p.configure(mode, "jp", mate)
	p.start(id, h.player)
	for a in p.actors: a.scene_state.safe_position = a.player; a.scene_state.carrying = false
	p.actors[0].apply_native(h)
	h.world_five.safe_position = p.actors[0].player
	var b = Bridge.new()
	h.bridge = b
	b.configure(p, h)
	b.begin_shared()
	h.world_five.party_start(h)
	h.combat.reset(h, p.actors.size())
	return {"host": h, "party": p, "bridge": b}
func finish(f: Dictionary) -> void:
	f.bridge.end_shared()
	f.host.world_five.invalidate_run()
func bot(h, x := 630.0, hp := 1) -> Dictionary:
	return h.combat.new_bot(h, x, h.world_five.surfaces(h)[0], "rush", {"hp": hp, "entered": true, "speed": 100.0})
func shot(x := 630.0, y := 400.0, owner := 1, damage := 1) -> Dictionary:
	return {"p": Vector2(x, y), "v": Vector2(780, 0), "enemy": false, "life": 20.0, "damage": damage, "owner_slot": owner, "owner_x": 600.0}
func hostile(x := 600.0, y := 400.0) -> Dictionary:
	return {"p": Vector2(x, y), "v": Vector2.ZERO, "enemy": true, "life": 20.0, "gravity": 0.0}
func _initialize() -> void:
	_test_scaling_and_start()
	_test_sofa()
	_test_surfaces_and_lift()
	_test_shared_scene()
	_test_contacts_and_pickups()
	_test_ownership()
	_test_king()
	print("Moving Day party controllers: %d checks, %d failures. Real mutable bridge fixtures, not complete party routes." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_scaling_and_start() -> void:
	for id in World.SUPPORTED_LEVELS:
		var f := fresh(id)
		var h = f.host
		check(h.combat.participant_count == 2, id + " final roster controls scaling")
		for i in h.level.waves.size():
			var source: Dictionary = h.level.waves[i]
			var expected: Array = source.g.duplicate(true)
			if source.get("extra", true): expected.append([expected[-1][0] + 600, "l" if expected.size() % 2 else "r", "rush"])
			check(h.combat.waves[i].group == expected, "%s wave%d exact source extra entry" % [id, i])
		for a in f.bridge.participants():
			var q: Dictionary = h.world_five.below(h, a.p.x, h.meta.ground - (10 if h.level.get("vert", false) else 3000))
			check(a.p.y == q.row[2] and a.safe_position == a.p and a.checkpoint == a.p, "%s slot%d floor resolved independently" % [id, a.slot])
		finish(f)
	var f := fresh("5-5")
	var h = f.host
	h.combat.spawn(h, "r", "van")
	check(h.enemies.size() == 3 and h.enemies.all(func(e): return e.hp == 3), "pair van has three source3HP riders")
	h.enemies.clear()
	h.combat.spawn(h, "r", "big")
	check(h.enemies.size() == 1 and h.enemies[0].hp == 34, "pair removal man has34HP")
	finish(f)

func _test_sofa() -> void:
	var f := fresh("5-2")
	var h = f.host
	var b = f.bridge
	var w = h.world_five
	w.sofa.x = 2940
	b.record(0).p = Vector2(2500, 482)
	b.record(1).p = Vector2(2940, 482)
	w.controls = {0: {}, 1: {"down": true}}
	w._tick_sofa(0.45, h)
	check(not w.sofa.tip, "P2 down holds source strict450ms tip boundary")
	check(not f.party.actors[0].scene_state.carrying and f.party.actors[1].scene_state.carrying, "only actual nearby actor carries sofa")
	check(not w.carrying, "P1 carry facade restored after P2 assignment")
	w._tick_sofa(0.001, h)
	check(w.sofa.tip and w.sofa_rect().size.x == 92, "P2 independent down input tips sofa")
	var dx: float = h.call_combat_participant(b.record(1), w.base_displacement, [1.0, h, 1.0])
	check(is_equal_approx(dx, 210.6) and w.base_displacement(1, h, 1) == 270, "carrying slows P2 only")
	b.record(0).p = Vector2(2900, 482)
	w._tick_sofa(0, h)
	check(f.party.actors[0].scene_state.carrying and f.party.actors[1].scene_state.carrying and w.sofa.carriers.size() == 2, "both nearby grounded actors share one sofa")
	var min_height: float = minf(b.record(0).height, b.record(1).height)
	check(is_equal_approx(w.sofa_rect().end.y, w.sofa.fy - w.sofa.lift * min_height * 0.28), "sofa uses shorter real carrier height")
	b.record(1).hearts = 0; b.record(1).down = true
	w._tick_sofa(0, h)
	check(not f.party.actors[1].scene_state.carrying and w.sofa.carriers.size() == 1, "downed mate carry cleared without revival")
	b.record(0).p.x = 2000
	w._tick_sofa(0.1, h)
	check(w.sofa.carriers.is_empty() and not w.blocks(Vector2(w.sofa.x, w.sofa.fy - 20)), "dropped sofa has no bullet shield")
	finish(f)

func _test_surfaces_and_lift() -> void:
	var f := fresh("5-4")
	var h = f.host
	var b = f.bridge
	var w = h.world_five
	b.record(0).p = Vector2(200, 482)
	b.record(1).p = Vector2(6100, 242)
	h.call_combat_participant(b.record(1), w.carry_player, [0.1, h])
	check(is_equal_approx(b.record(1).p.x, 6114) and b.record(0).p.x == 200, "actor-only raised conveyor applies P2 displacement once")
	for a in b.participants():
		a.p = Vector2(1000 + a.slot * 100, 482); a.grounded = true; a.on_platform = false
		h.call_combat_participant(a, w.after_motion, [h])
	check(b.record(0).safe_position == Vector2(1000, 482) and b.record(1).safe_position == Vector2(1100, 482), "safe floor capture remains independent")
	b.record(1).p = Vector2(1000, 2000); b.record(1).invincible = 99.0
	h.call_combat_participant(b.record(1), w.recover_from_fall, [h])
	check(b.record(1).hearts == 2 and b.record(0).hearts == 3 and b.record(1).grounded, "fall recovery scopes actual victim and own passive")
	check(b.record(1).safe_position == Vector2(1100, 482) and b.record(1).velocity.x == 0, "recovery preserves saved safe point and removes knockback")
	finish(f)
	f = fresh("5-3", "cpu")
	h = f.host; b = f.bridge; w = h.world_five
	var q: Dictionary = w.lift.surface
	for a in b.participants(): a.p = Vector2(q.row[0] + 40 + a.slot * 50, q.row[2]); a.grounded = true
	w.lift.state = "move"; w.lift.to = q.row[2] - 330
	var y: float = q.row[2]
	w._tick_lift(0.1, h)
	check(q.row[2] == y - 16 and b.record(0).p.y == y - 16 and b.record(1).p.y == y - 16, "one lift step carries both riders by same16px")
	check(is_equal_approx(w.lift.t, 0.1), "lift timer advances once")
	b.record(1).down = true; b.record(1).hearts = 0
	w._tick_lift(0.1, h)
	check(b.record(0).p.y == y - 32 and b.record(1).p.y == y - 16, "source downed actor is not a lift rider")
	w.lift.floor = 3; w.lift.dir = 1; w.lift.to = h.level.liftBase - 4 * h.level.storey
	q.row[2] = w.lift.to + 1; b.record(0).p.y = q.row[2]
	w._tick_lift(0.01, h)
	check(w.lift.state == "shake" and w.lift.floor == 4, "fourth floor rider break condition")
	w._tick_lift(0.91, h)
	check(w.lift.state == "drop", "shared lift shake transitions to two-floor drop")
	var top: float = q.row[2]
	w._tick_lift(0.1, h)
	check(b.record(0).p.y > top and b.record(0).p.y == q.row[2], "living rider follows broken lift downward")
	finish(f)
	f = fresh("5-5")
	h = f.host; w = h.world_five
	h.combat.spawn(h, "r", "van")
	q = w.movers.filter(func(m): return not m.off)[0]
	var old: float = q.row[0]
	w._tick_movers(0.1, h)
	check(is_equal_approx(q.t, 0.1) and is_equal_approx(q.row[0] - old, q.vx * 0.1), "one van motion updates source platform once")
	finish(f)

func _test_shared_scene() -> void:
	var f := fresh("5-2")
	var h = f.host
	var w = h.world_five
	var b = f.bridge
	b.record(0).hearts = 0; b.record(0).down = true
	b.record(1).p = Vector2(float(h.level.check) + 1, 482)
	w.before_camera(0.1, h, {0: {}, 1: {}})
	check(b.record(0).hearts == 3 and not b.record(0).down and b.record(0).invincible == 1.2, "checkpoint revives downed P1 when P2 reaches it")
	check(b.record(1).hearts == 3 and b.record(1).invincible == 1.2, "checkpoint heals living trigger too")
	check(h.order == ["pick:0", "pick:1"] and is_equal_approx(w.level_time, 0.1), "once shared world scopes picks in roster order")
	b.record(1).down = true; b.record(1).hearts = 0
	b.record(0).safe_position = Vector2(100, 482); b.record(1).safe_position = Vector2(200, 482)
	b.record(1).velocity = Vector2(90, 20)
	w._start_wipe(h, {"to": 4910.0})
	w.wipe_elapsed = w.WIPE_CALLBACK; w._wipe_callback_due = true
	var generation: int = w.run_generation
	w.finish_frame(h)
	check(b.record(0).p.x == 4910 and b.record(1).p.x == 4970, "wipe relocates all actors with source plus60 spacing")
	check(b.record(0).px == 4910 and b.record(1).px == 4970 and b.record(1).velocity == Vector2.ZERO, "wipe writes per-actor previousx and resets motion")
	check(b.record(1).down and b.record(1).hearts == 0 and b.record(1).grounded, "wipe moves downed mate without healing")
	check(b.record(0).safe_position == Vector2(100, 482) and b.record(1).safe_position == Vector2(200, 482), "source scene wipe preserves own safe checkpoints")
	check(w.sofa.x == 5110 and h.camera == Vector2(4710, b.record(0).p.y - 482), "one wipe places sofa and camera from slot0 floor")
	check(not w._apply_scene_transition(h, generation) and w.scene_index == 1, "wipe midpoint cannot execute twice")
	b.record(0).p.x = 100; b.record(1).p.x = 150; h.camera.x = 0
	w.checkpoint = {"x": 1000.0, "y": 420.0}
	w.respawn(h)
	check(b.record(0).p == Vector2(1000, 420) and b.record(1).p == Vector2(1000, 420), "checkpoint Continue relocates whole roster")
	check(b.record(1).down and b.record(1).hearts == 0, "world respawn itself never revives")
	w.invalidate_run()
	check(not w._apply_scene_transition(h, generation), "invalidated old scene callback rejected")
	finish(f)
	f = fresh("5-S"); h = f.host; w = h.world_five
	var clock_before: float = w.clock_left
	w.before_camera(0.25, h, {0: {}, 1: {}})
	check(is_equal_approx(w.clock_left, clock_before - 0.25), "bonus countdown advances once for pair")
	finish(f)

func _test_contacts_and_pickups() -> void:
	var f := fresh()
	var h = f.host
	var b = f.bridge
	b.record(0).p = Vector2(200, 482); b.record(1).p = Vector2(600, 482)
	var e := bot(h, 550, 3)
	var t: float = e.t
	h.combat.enemies_tick(0.1, h)
	check(e.p.x == 560 and e.face == 1 and is_equal_approx(e.t, t + 0.1), "ordinary bot targets nearer P2 and ticks once")
	check(h.combat._nearest(h, 400).slot == 0, "nearest tie keeps roster order")
	b.record(1).down = true
	check(h.combat._nearest(h, 600).slot == 0, "nearest ignores downed P2")
	b.record(1).down = false
	h.enemies.clear(); h.bullets = [hostile()]
	h.combat.projectiles_tick(0, h)
	check(b.record(1).hearts == 2 and b.record(0).hearts == 3 and h.hits == [1], "bill scopes actual P2 victim")
	check(f.party.actors[1].abilities._hits == 1 and f.party.actors[0].abilities._hits == 0, "bill consults actual victim passive")
	b.record(1).invincible = 0; h.bullets = [hostile()]
	h.combat.projectiles_tick(0, h)
	check(b.record(1).hearts == 2 and b.record(1).invincible == 0.9, "P2 Maya passive blocks her second hit")
	h.coins = [{"p": Vector2(600, 420), "v": Vector2.ZERO, "rest": true, "age": 1.0}]
	h.items = [{"p": Vector2(600, 400), "vy": 0.0, "rest": true, "age": 1.0, "give": "split"}]
	h.combat.pickups_tick(0, h)
	check(h.score == 1 and b.record(1).coins == 1 and b.record(0).coins == 0, "coin awards shared kitty once and actual collector once")
	check(b.record(1).power == "split" and b.record(0).power == "", "weapon goes to P2 only")
	finish(f)
	check(f.party.actors[1].coins == 1 and f.party.actors[1].power == "split", "pickup writes survive shared phase")
	f = fresh("5-1", "p2", "theo"); h = f.host; b = f.bridge
	for a in b.participants(): a.p = Vector2(600, 482)
	h.bullets = [hostile()]
	h.combat.projectiles_tick(0, h)
	check(h.hits == [0, 1], "overlapping bill source loop hurts both before culling")
	for a in b.participants(): a.invincible = 0
	h.world_five.drops = [{"x": 600.0, "top": 482.0, "state": "fall", "t": 1.0, "y": 300.0, "vy": 1000.0}]
	h.world_five._tick_drops(0.1, h)
	check(b.record(0).hearts == 1 and b.record(1).hearts == 1, "one falling box can hit both source victims")
	finish(f)
	f = fresh("5-5", "p2", "theo"); h = f.host; b = f.bridge
	for a in b.participants(): a.p = Vector2(500, 420)
	b.record(1).crouching = true
	h.world_five.beams = [{"x": 500.0, "warn": 0.0, "t": 0.0}]
	h.world_five._tick_beams(0, h)
	check(b.record(0).hearts == 2 and b.record(1).hearts == 3, "low bridge checks each actor own crouching/height")
	finish(f)

func _test_ownership() -> void:
	var f := fresh()
	var h = f.host
	var b = f.bridge
	b.record(0).p = Vector2(200, 482); b.record(1).p = Vector2(600, 482)
	var e := bot(h, 350)
	var s := shot(650); s.first_frame = true; s.owner_x = 200.0
	h.bullets = [s]; h.combat.projectiles_tick(0, h)
	check(e.hp == 1, "shot first sweep uses current owner position not P1 or stale ownerx")
	e.p.x = 630; s.first_frame = true
	h.combat.projectiles_tick(0, h)
	check(e.state == "pop" and b.record(1).pop_count == 1 and b.record(0).pop_count == 0, "shot kill credits P2")
	h.enemies.clear(); e = bot(h)
	s = shot(); s.erase("owner_slot"); h.bullets = [s]
	h.combat.projectiles_tick(0, h)
	check(e.state == "pop" and b.record(0).pop_count == 0 and b.record(1).pop_count == 1, "unowned projectile kills without active facade credit")
	h.enemies.clear(); e = bot(h)
	b.record(1).hearts = 0; b.record(1).down = true
	h.bullets = [shot()]; h.combat.projectiles_tick(0, h)
	check(b.record(1).pop_count == 2, "downed firing actor retains projectile ownership")
	h.enemies.clear(); e = bot(h)
	h.call_combat_participant(b.record(0), h.combat.damage_enemy, [h, e, 1])
	check(b.record(0).pop_count == 1, "direct ability callback credits bound actor")
	h.enemies.clear(); e = bot(h)
	h.combat.kill_enemy(h, e, false)
	check(b.record(0).pop_count == 1 and b.record(1).pop_count == 2, "environment cleanup cannot credit any actor")
	finish(f)
	check(f.party.actors[0].pop_count == 1 and f.party.actors[1].pop_count == 2, "ownership persists across shared close")

func _test_king() -> void:
	var f := fresh("5-6", "p2", "theo")
	var h = f.host
	var b = f.bridge
	h.camera.x = h.level.w - h.view_width()
	h.combat.start_boss(h)
	var k = h.boss
	check(k.state.hp == 34 and is_finite(k.state.fy) and k.state.fy == 482, "King pair34HP and intentional finitefeet repair")
	k.state.x = h.level.w - 300; k.state.state = "throw"; k.state.t = 0.33; k.state.pending = true
	b.record(0).p = Vector2(k.state.x - 400, 482); b.record(1).p = Vector2(k.state.x - 150, 482)
	h.combat.boss_tick(0.01, h)
	check(h.bullets.size() == 2 and is_equal_approx(k.state.t, 0.34), "King volley and clock advance once")
	check(is_equal_approx(h.bullets[0].v.x, (b.record(1).p.x - 65 - k.state.x) / 1.05), "King throw aims at nearest P2")
	h.bullets = [shot(k.state.x, 400, 1, 99)]
	h.combat.projectiles_tick(0, h)
	check(k.state.hp == 33 and b.record(1).boss_hits == 1, "King fixed body hit ignores99 damage and credits P2 boss tally")
	k.state.dizzy = 1
	h.bullets = [shot(k.state.x, k.state.crown_y - 1, 0, 99)]
	h.combat.projectiles_tick(0, h)
	check(k.state.hp == 29 and b.record(0).boss_hits == 1, "King dizzy crown hit is source4 points with separate P1 tally")
	var s := shot(k.state.x, 400); s.erase("owner_slot"); h.bullets = [s]
	h.combat.projectiles_tick(0, h)
	check(b.record(0).boss_hits == 1 and b.record(1).boss_hits == 1, "unowned boss hit never borrows active actor")
	b.record(1).hearts = 0; b.record(1).down = true
	h.bullets = [shot(k.state.x, 400)]; h.combat.projectiles_tick(0, h)
	check(b.record(1).boss_hits == 2, "boss tally remains owned after shooter falls")
	b.record(1).hearts = 3; b.record(1).down = false
	k.state.hp = 1; k.state.dizzy = 0
	h.bullets = [shot(k.state.x, 400)]; h.combat.projectiles_tick(0, h)
	check(k.state.state == "collapse" and k.state.armour, "pair first phase collapses into armour")
	h.combat.boss_tick(0.9, h)
	check(h.enemies.size() == 3, "pair first collapse spawns3 source helpers")
	h.combat.boss_tick(1.31, h)
	check(k.state.state == "collapse", "living helpers hold rebuilding until source timeout")
	for e in h.enemies: e.state = "pop"
	h.combat.boss_tick(0, h); h.combat.boss_tick(1.71, h)
	check(k.state.phase == 1 and k.state.hp == 42, "pair second phase source rounded42HP")
	k._set_phase(2); k.state.state = "walk"
	check(k.state.hp == 49, "pair final phase source rounded49HP")
	k.state.waves = [{"x": h.camera.x + 300, "vx": 400.0, "t": 0.0}]
	for a in b.participants(): a.p = Vector2(h.camera.x + 340, 482); a.invincible = 0
	k.state.state = "throw"; k.state.t = 0.0; k.state.pending = false
	h.combat.boss_tick(0.1, h)
	check(b.record(0).hearts == 2 and b.record(1).hearts == 2 and h.hits == [0, 1], "King shockwave hurts both scoped victims")
	check(k.state.waves[0].x == h.camera.x + 340 and is_equal_approx(k.state.waves[0].t, 0.1), "King shared shockwave moves once")
	k.state.waves.clear(); k.state.hp = 1
	h.bullets = [shot(k.state.x, 400)]; h.combat.projectiles_tick(0, h)
	check(k.state.state == "down", "final phase down occurs once")
	h.combat.boss_tick(1.51, h)
	check(not k.state.jar.is_empty(), "physical jar appears after final defeat")
	k.state.jar.t = 0.61
	b.record(0).p.x = h.camera.x + 100; b.record(1).p.x = k.state.jar.x
	check(h.combat.jar_tick(0, h) == "clear" and k.state.jar.got, "P2 can collect King jar")
	check(h.combat.jar_tick(1, h) == "", "King jar clear only once")
	finish(f)
	check(f.party.actors[0].scene_state.boss_hits == 1 and f.party.actors[1].scene_state.boss_hits == 4, "King hit counts persist in each actor scene state")
