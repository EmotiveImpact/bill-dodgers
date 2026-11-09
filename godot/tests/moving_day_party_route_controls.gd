extends RefCounted
## Exact existing solo normal-input controller, isolated state for each human.
var goal: Dictionary = {}
var collect_all := true
func controls(g, tick: int, stuck: int) -> Dictionary:
	var c := {"left": false, "right": false, "jump": false, "down": false, "shoot": true, "aim": false, "special": false}
	if g.world_five.wiping: return c
	if collect_all:
		var pickup := pickup_controls(g)
		if not pickup.is_empty(): return pickup
	var targets: Array = g.enemies.filter(func(b): return b.state != "pop" and not b.get("lost", false) and b.p.x > g.camera.x - 40 and b.p.x < g.camera.x + g.view_width() + 40 and absf(b.p.y - g.player.y) < 220)
	targets.sort_custom(func(a,b): return absf(a.p.x-g.player.x) < absf(b.p.x-g.player.x))
	var target: Dictionary = targets[0] if not targets.is_empty() else {}
	if g.boss != null:
		var b: Dictionary = g.boss.state
		if not b.jar.is_empty():
			c.left = g.player.x > b.jar.x + 8; c.right = g.player.x < b.jar.x - 8; return c
		if b.state not in ["collapse", "rebuild", "down", "enter"]: target = {"p": Vector2(b.x, 482), "big": true}
	if g.level_id == "5-5":
		var want := 280.0
		if not target.is_empty():
			var face := signf(target.p.x - g.player.x)
			if absf(g.player.x - want) > 20: c.left = g.player.x > want; c.right = g.player.x < want
			elif g.face != face: c.left = face < 0; c.right = face > 0
		else: c.left = g.player.x > want + 4; c.right = g.player.x < want - 4
		c.down = g.world_five.beams.any(func(b): return b.warn <= 0 and absf(b.x - g.player.x) < 140)
		return c
	if not target.is_empty():
		var dx: float = target.p.x - g.player.x
		var dy: float = target.p.y - g.player.y
		if absf(dy) < 70 or target.get("big", false):
			var advance: bool = absf(dx) > 240 or (stuck > 120 and absf(dx) > 65)
			if advance: c.left = dx < 0; c.right = dx > 0
			elif g.face != signf(dx): c.left = dx < 0; c.right = dx > 0
			if advance and (stuck > 8 or tick % 42 == 0): c.jump = not g.jump_held
			return c
	if g.level_id == "5-3":
		if g.grounded:
			var next: Dictionary = {}; var rank := INF
			for q in g.world_five.surfaces(g):
				if q.get("lift", false) or q.row[2] >= g.player.y - 5 or q.row[2] < g.player.y - 150: continue
				var x := clampf(g.player.x, q.row[0] + 35, q.row[1] - 35)
				var distance := absf(x - g.player.x)
				if distance <= 230 and distance < rank: next = {"x": x, "y": q.row[2]}; rank = distance
			if not next.is_empty(): goal = next
		if not goal.is_empty():
			c.left = g.player.x > goal.x + 8; c.right = g.player.x < goal.x - 8
			if g.grounded and absf(g.player.x - goal.x) < 110 and not g.jump_held: c.jump = true
		return c
	if not g.world_five.sofa.is_empty():
		var sofa: Dictionary = g.world_five.sofa
		if g.player.x > sofa.x + 115:
			c.left = true; return c
		if sofa.door != null and not sofa.tip and absf(g.player.x - sofa.x) < 160: c.down = true; return c
	c.right = true
	if g.grounded and not g.jump_held:
		var wall: float = g._wall_clamp(g.player.x, g.player.x + 58, g.player.y)
		if wall < g.player.x + 58 or stuck > 8: c.jump = true
	elif not g.grounded and tick % 16 == 0 and not g.jump_held: c.jump = true
	return c

func observe(g, seen: Dictionary) -> void:
	if g.world_five.end_time > 0 and seen.end_started < 0: seen.end_started = g.elapsed
	if not g.world_five.sofa.is_empty():
		seen.sofa_tip = seen.sofa_tip or g.world_five.sofa.tip
		seen.sofa_carry = seen.sofa_carry or g.world_five.carrying
	seen.beams = seen.beams or not g.world_five.beams.is_empty()
	seen.beam_active = seen.beam_active or g.world_five.beams.any(func(b): return b.warn <= 0)
	for q in g.world_five.movers:
		if not q.off and q.get("state", "") in ["in", "hold", "out"]: seen["vehicle_" + q.state] = true
	if g.boss != null:
		var b: Dictionary = g.boss.state
		if b.phase not in seen.king_phases: seen.king_phases.append(b.phase); seen.king_max_hp.append(b.max)
		if b.state in ["collapse", "rebuild"]: seen.king_armour = seen.king_armour and b.armour
		if b.state == "collapse" and g.enemies.any(func(e): return e.state != "pop"): seen.king_helpers = true
		if b.state in ["collapse", "rebuild"] and b.phase not in seen["king_" + b.state]: seen["king_" + b.state].append(b.phase)
		seen.king_down = seen.king_down or b.state == "down"
		seen.jar = seen.jar or not b.jar.is_empty()

func pickup_controls(g) -> Dictionary:
	var remaining: Array = g.receipts.filter(func(r): return not r.taken)
	if remaining.is_empty(): return {}
	remaining.sort_custom(func(a, b): return a.position.y > b.position.y if g.level_id == "5-3" else a.position.x < b.position.x)
	var target: Vector2 = remaining[0].position
	if g.level_id == "5-3":
		if g.player.y > target.y + 85 or g.player.y < target.y - 120: return {}
	elif g.level_id != "5-5" and target.x - g.player.x > 240: return {}
	var direction := signf(target.x - g.player.x) if absf(target.x - g.player.x) > 5 else 0.0
	var wall: bool = direction != 0 and absf(g._wall_clamp(g.player.x, g.player.x + direction * 35, g.player.y) - (g.player.x + direction * 35)) > 0.5
	var jump: bool = not g.jump_held and ((g.grounded and (g.player.y - target.y > 40 or wall)) or (not g.grounded and g.velocity.y >= 0 and g.player.y > target.y + 70 and not g.movement_skills.double_jumped))
	return {"left": direction < 0, "right": direction > 0, "jump": jump, "shoot": true}
