extends SceneTree
## Audio lifecycle fixtures in actual main. Boss/campaign gates are explicitly
## seeded for dispatch checks, not claimed as earned gameplay completion.
const Score = preload("res://src/original_score.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle() -> void: await create_timer(0.07).timeout
func fresh_save() -> Dictionary:
	return {"schema":1,"receipts":{},"cleared":{},"seen":{},"skills":[],"kitty":0}
func run() -> void:
	var g = load("res://main.tscn").instantiate(); root.add_child(g)
	g.set_physics_process(false); g.audio.set_process(false)
	await settle()
	check(g.audio is Score and g.audio.current_cue == "title" and g.audio.music_player.playing, "Actual boot menu starts original title")
	g.save = fresh_save()
	for world in range(1,7):
		for stage in ["1","2","3","4","5","6","S"]:
			var id: String = str(world) + "-" + str(stage)
			check(g.load_level(id), "actual main loads " + id)
			await settle()
			check(g.audio.current_cue == ("bonus" if stage == "S" else "world" + str(world)), id + " correct world/bonus cue")
			check(g.audio.music_player.stream is AudioStreamOggVorbis and g.audio.music_player.playing, id + " actual native music playback")
		g._pause()
		check(g.mode == "paused" and g.audio.music_player.stream_paused and g.audio.spare.stream_paused, "pause freezes both voices")
		var fade: float = g.audio.fade_remaining; g.audio._process(1)
		check(g.audio.fade_remaining == fade, "pause freezes crossfade clock")
		g._resume()
		check(not g.audio.music_player.stream_paused, "resume restores music")
		g.audio._process(1)
		g.audio.set_enabled(false)
		check(g.audio.music_player.stream_paused, "mute applies to original score")
		g._show_menu(); await settle()
		check(g.audio.current_cue == "title" and g.audio.music_player.stream_paused, "menu preserves mute preference")
		g.audio.set_enabled(true)
	for world in range(1,7):
		g.load_level(str(world)+"-6"); await settle()
		# Explicit boss-entry fixture, not an input traversal claim.
		g.camera.x = float(g.level.w) - g.view_width()
		for wave in g.combat.waves: wave.done = true
		match world:
			1: g.start_boss()
			2: g.world_two.objective_tick(0.016, g)
			3: g.world_three.after_pickups(0.016, g)
			4: g.world_four.before_combat(0.016, g); g.world_four.boss_tick(0.016, g)
			5: g.world_five.objective_tick(0.016, g)
			6: g.world_six.world_tick(0.016, g)
		await settle()
		check(g.audio.current_cue == ("final_boss" if world == 6 else "boss"), "real family boss start dispatch " + str(world))
		g._game_over()
		check(g.audio.music_player.stream_paused, "knockout freezes current boss cue")
		g._continue_level()
		check(not g.audio.music_player.stream_paused and g.audio.boss_music, "Continue resumes same boss cue")
	g.load_level("6-1"); await settle()
	g.combat.start_mini(g, "franker")
	await settle()
	check(g.audio.current_cue == "boss", "actual Franking-machine start switches shared boss")
	g.combat.mini_down(g); await settle()
	check(g.audio.current_cue == "world6", "actual miniboss defeat restores World 6 theme")
	g.load_level("1-1"); await settle()
	var before_story: String = g.audio.current_cue
	g._open_story("1-intro")
	check(g.audio.music_player.stream_paused and g.mode == "story", "source story semantics pause current music")
	g.story.skip()
	check(g.audio.current_cue == before_story and not g.audio.music_player.stream_paused, "story exit resumes cue without restart")
	# Explicit accounting fixture checks audio stop, not successful combat.
	g._complete_level(); await settle()
	check(not g.audio.music_requested and g.audio.music_player.stream == null and g.audio.spare.stream == null, "clear stops both music voices and keeps source win SFX")
	g._show_campaign(); await settle()
	check(g.campaign_map != null and g.audio.current_cue == "map", "painted campaign return restores its own map cue")
	g._show_title(true); await settle()
	check(g.audio.current_cue == "title", "explicit title menu restores title cue")
	g.save = fresh_save()
	for world in range(1,7):
		for stage in range(1,7): g.save.cleared[str(world)+"-"+str(stage)] = true
	check(g._show_credits(), "verified synthetic campaign opens credits")
	await settle()
	check(g.audio.current_cue == "ending" and not g.audio.music_player.stream.loop, "credits start actual one-shot ending")
	g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var credit_fade: float = g.audio.fade_remaining; g.audio._process(1)
	check(g.credits_roll.paused and g.audio.music_player.stream_paused and g.audio.fade_remaining == credit_fade, "credits focus loss freezes roll/music/fade")
	g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not g.credits_roll.paused and not g.audio.music_player.stream_paused, "credits focus return resumes roll/music")
	g.credits_roll.skip(); await settle()
	check(g.mode == "menu" and g.audio.current_cue == "title", "credits skip returns title without overlapping ending")
	g.audio.shutdown(); g.queue_free(); await process_frame; await create_timer(0.3).timeout
	print("Original score actual-main integration: ", checks, " checks, ", failures.size(), " failures. Audio lifecycle fixtures, not gameplay clears.")
	quit(0 if failures.is_empty() else 1)
