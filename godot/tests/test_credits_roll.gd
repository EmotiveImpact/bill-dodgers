extends SceneTree
const Credits = preload("res://src/credits_roll.gd")
var checks := 0
var failures: Array[String] = []
var completions := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)
func run() -> void:
	var credits = Credits.new()
	root.add_child(credits); credits.set_process(false)
	credits.finished.connect(func(): completions += 1)
	credits.play()
	check(credits.playing and credits.visible and credits.clip_contents, "Roll opens in clipped visible viewport")
	check(credits.content.has(Credits.INTRO) and credits.content.has(Credits.WORLDS), "Original epilogue and six-world wording retained")
	check(credits.content.has(Credits.CRUNCH_UNPAID) and not credits.content.has(Credits.CRUNCH_PAID), "Default source Crunch line is not falsely paid")
	for row in Credits.CAST: check(credits.content.has(row[1]), "Original cast name " + row[1])
	for line in ["Bill Dodgers", "Starring", "And", "Six worlds", "A Commune game", "for people who do life, together.", "ourcommune.io", "Thanks for playing"]:
		check(credits.content.has(line), "Source credit text: " + line)
	check(credits.painting != null, "Original title painting available")
	var portraits := 0
	for child in credits.roll.find_children("*", "TextureRect", true, false):
		if child is TextureRect:
			portraits += 1
			check(child.get_parent().clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW and child.get_parent().get_theme_stylebox("panel").corner_radius_top_left == 48, "Source circular portrait mask clips weapons and arms")
			check(child.texture is AtlasTexture and child.texture.atlas != null and child.texture.region.position == Vector2.ZERO and child.texture.region.size.x * 8 == child.texture.atlas.get_width(), "Portrait uses original first source face frame")
	check(portraits == 6, "All six original portraits drawn")
	check(credits.roll.position.y == 540 and credits.duration >= 22 and credits.duration <= 40, "Source starts below viewport with 22–40 second duration clamp")
	check(credits.skip_button.size.y >= 44, "Native Skip is touch-sized")
	credits.tick(credits.duration * 0.5)
	check(is_equal_approx(credits.roll.position.y, (540.0 - credits.roll_height) * 0.5), "Linear midpoint follows complete roll height")
	credits.set_paused(true)
	var old: float = credits.elapsed
	credits.tick(20); credits.skip()
	check(credits.elapsed == old and credits.playing and completions == 0 and credits.skip_button.disabled, "Background pause freezes timer and skip")
	credits.set_paused(false)
	credits.tick(-1); credits.tick(NAN)
	check(credits.elapsed == old, "Invalid delta cannot corrupt position")
	credits.tick(credits.duration - old)
	check(credits.playing and is_equal_approx(credits.roll.position.y, -credits.roll_height), "Source roll finishes before 600ms return delay")
	credits.tick(0.599)
	check(credits.playing, "Completion waits full source600ms")
	credits.tick(0.002)
	check(not credits.playing and not credits.visible and completions == 1, "Finished emits once after roll and delay")
	credits.skip(); credits.tick(100)
	check(completions == 1, "Late timer and duplicate skip do not emit again")
	var normal: float = credits.duration
	credits.play(true, true)
	check(credits.content.has(Credits.CRUNCH_PAID) and is_equal_approx(credits.duration, normal * 1.6), "Source paid variant and reduced-motion multiplier retained")
	credits.skip()
	check(completions == 2 and not credits.playing, "Replay can skip independently")
	credits.play(); credits.stop()
	check(completions == 2 and not credits.visible, "Host replacement stops without navigation callback")
	credits.play(); await process_frame # Native CanvasItem drawing callback.
	credits.stop(); credits.queue_free(); await process_frame
	print("Credits roll: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
