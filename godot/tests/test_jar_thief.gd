extends SceneTree
const Boss = preload("res://src/jar_thief.gd")
var assertions := 0
var failures := 0
func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		push_error(message)
		failures += 1
func count(events: Array[Dictionary], kind: String) -> int:
	return events.filter(func(e): return e.type == kind).size()
func _initialize() -> void:
	var b = Boss.new()
	var players: Array[Dictionary] = [{"position": Vector2(9100, 482), "alive": true}]
	b.reset(10000, 1000, 482)
	check(b.state.hp == 70, "Solo health")
	check(not b.hit(Vector2(10160, 400)), "Entrance immune")
	b.tick(0.016, players)
	check(b.state.x == 9910, "Source first frame entrance clamp")
	for i in 40:
		b.tick(0.016, players)
	check(b.state.state == "walk", "Entrance completes")
	b.state.state = "throw"
	b.state.t = 0.0
	b.state.pending_throw = true
	check(count(b.tick(0.319, players), "bill") == 0, "Windup")
	var events = b.tick(0.0011, players)
	check(count(events, "bill") == 3, "Three throws at 320ms")
	check(events[0].velocity.y == -700 and events[2].velocity.y == -860, "Throw velocity")
	check(events[0].gravity == 1600, "Throw gravity")
	check(count(b.tick(0.01, players), "bill") == 0, "Throw only once")
	b.tick(0.32, players)
	check(b.state.state == "walk", "Recover after 640ms")
	b.state.x = 9700.0
	check(not b.hit(Vector2(b.state.x + 70, 400)), "Strict horizontal bounds")
	check(not b.hit(Vector2(b.state.x, 232)), "Strict vertical bounds")
	check(b.hit(Vector2(b.state.x, 400), 999), "Valid hit")
	check(b.state.hp == 69, "Source ignores damage argument")
	b.state.hp = 46
	check(count(b.tick(0, players), "spawn_bot") == 2, "First backup")
	check(count(b.tick(0, players), "spawn_bot") == 0, "Backup once")
	b.state.hp = 34
	b.tick(0, players)
	check(b.state.dizzy == 2.6, "Dizzy threshold")
	b.hit(Vector2(b.state.x, 400))
	check(b.state.hp == 32, "Double damage")
	b.state.hp = 22
	check(count(b.tick(0, players), "spawn_bot") == 2, "Second backup solo")
	b.state.hp = 1
	b.hit(Vector2(b.state.x, 400))
	events = b.tick(1.5, players)
	check(b.state.state == "down" and b.state.waves.is_empty(), "Defeated")
	check(count(events, "drop_coins") == 1 and count(events, "kill_bots") == 1, "Defeat events")
	check(b.state.jar.is_empty(), "Jar strictly after 1500ms")
	b.tick(0.001, players)
	check(not b.state.jar.is_empty(), "Jar spawned")
	players[0].position.x = b.state.jar.x - 60
	b.tick(0.5, players)
	players[0].position.x = b.state.jar.x
	events = b.tick(0.11, players)
	check(count(events, "clear") == 1, "Pickup after 600ms, no vertical test")
	check(count(b.tick(1, players), "clear") == 0, "Clear once")
	b.reset(10000, 1000, 482, 2)
	check(b.state.hp == 90, "Duo health")
	b.state.state = "walk"
	b.state.hp = 20
	check(count(b.tick(0, players), "spawn_bot") == 5, "Both thresholds and duo bonus")
	b.reset(10000, 1000, 482)
	b.state.state = "stomp"
	b.state.pending_throw = true
	b.tick(0.32, players)
	check(b.state.waves.size() == 2, "Two waves")
	players[0].position = Vector2(b.state.waves[0].x - 4.2, 482)
	check(count(b.tick(0.01, players), "hurt_player") >= 1, "Ground wave hurts")
	print("Jar thief parity: %d checks passed" % assertions)
	quit(1 if failures else 0)
