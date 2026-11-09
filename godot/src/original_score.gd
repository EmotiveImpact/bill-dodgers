extends "res://src/game_audio.gd"
## Optional original-score adapter. Inherits all source effects and fallback music
## unchanged. Composed audio is separate from source parity and opt-in at host.
const CUES := ["title", "world1", "world2", "world3", "world4", "world5", "world6", "boss", "final_boss", "bonus", "victory", "select", "map", "story", "cutscene", "party", "gameover", "ending"]
const SCORE_DIR := "res://assets/music/"
const CROSSFADE := 0.18
var level_id := "1-1"
var current_cue := ""
var gameplay_gain_db := -18.0
var screen_gain_db := -9.0
var score_gain_db := -9.0
var spare: AudioStreamPlayer
var fade_remaining := 0.0
var old_gain_db := -9.0
var score_cache: Dictionary = {}

func _ready() -> void:
	super._ready()
	spare = AudioStreamPlayer.new()
	add_child(spare)

func set_level(id: String) -> void:
	level_id = id

func cue_for_level(id: String, boss: bool = false) -> String:
	if boss: return "final_boss" if id == "6-6" else "boss"
	if id.ends_with("-S"): return "bonus"
	var world := int(id.get_slice("-", 0))
	return "world" + str(world) if world >= 1 and world <= 6 else "title"

func score_stream(cue: String) -> AudioStreamOggVorbis:
	if cue not in CUES: return null
	if score_cache.has(cue): return score_cache[cue] as AudioStreamOggVorbis
	var path := SCORE_DIR + cue + ".res"
	if not ResourceLoader.exists(path): return null
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null or stream.get_length() <= 0 or stream.loop != (cue not in ["victory", "gameover", "ending"]): return null
	score_cache[cue] = stream
	return stream

func start_music(boss: bool = false) -> void:
	var cue := cue_for_level(level_id, boss)
	if music_requested and current_cue == cue: return
	var stream := score_stream(cue)
	if stream == null:
		stop_music()
		music_player.volume_db = 0
		super.start_music(boss)
		return
	music_requested = true
	boss_music = boss
	_start_score(cue, stream)

func play_cue(cue: String) -> bool:
	var stream := score_stream(cue)
	if stream == null: return false
	if music_requested and current_cue == cue: return true
	music_requested = true
	boss_music = cue in ["boss", "final_boss"]
	_start_score(cue, stream)
	return true

func _start_score(cue: String, stream: AudioStreamOggVorbis) -> void:
	if not is_instance_valid(music_player) or not is_instance_valid(spare): return
	spare.stream_paused = false
	spare.stop()
	spare.stream = null
	if music_player.playing:
		var old := music_player
		music_player = spare
		spare = old
		old_gain_db = spare.volume_db
		fade_remaining = CROSSFADE
	else:
		fade_remaining = 0
	score_gain_db = gameplay_gain_db if cue.begins_with("world") or cue in ["boss", "final_boss", "bonus"] else screen_gain_db
	music_player.stream = stream
	music_player.volume_db = -80 if fade_remaining > 0 else score_gain_db
	music_player.play()
	current_cue = cue
	_sync_pause()

func _process(delta: float) -> void:
	if paused or fade_remaining <= 0: return
	fade_remaining = maxf(0, fade_remaining - delta)
	var ratio := fade_remaining / CROSSFADE
	music_player.volume_db = score_gain_db + linear_to_db(maxf(0.0001, 1.0 - ratio))
	spare.volume_db = old_gain_db + linear_to_db(maxf(0.0001, ratio))
	if fade_remaining == 0:
		spare.stream_paused = false
		spare.stop()
		spare.stream = null

func _sync_pause() -> void:
	super._sync_pause()
	if is_instance_valid(spare): spare.stream_paused = paused or not enabled

func stop_music() -> void:
	super.stop_music()
	_stop_spare()
	current_cue = ""

func _stop_spare() -> void:
	fade_remaining = 0
	if is_instance_valid(spare):
		spare.stream_paused = false
		spare.stop()
		spare.stream = null

func shutdown() -> void:
	super.shutdown()
	_stop_spare()
	current_cue = ""
	score_cache.clear()

func start_title() -> void:
	play_cue("title")

func start_ending() -> void:
	play_cue("ending")
