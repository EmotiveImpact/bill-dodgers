extends Node2D
## Native Godot port, not a wrapper. Only explicitly supported solo stages
## can grant completion; unported stages remain labelled layout previews.
const SaveStore = preload("res://src/save_store.gd")
const Combat = preload("res://src/combat.gd")
const Boss = preload("res://src/jar_thief.gd")
const Abilities = preload("res://src/abilities.gd")
const Story = preload("res://src/story_player.gd")
const GameAudio = preload("res://src/original_score.gd")
const WorldOne = preload("res://src/world_one.gd")
const MovementSkills = preload("res://src/movement_skills.gd")
const RooftopRenderer = preload("res://src/rooftop_renderer.gd")
const BusRide = preload("res://src/bus_ride.gd")
const BusRenderer = preload("res://src/bus_renderer.gd")
const StreetRenderer = preload("res://src/street_renderer.gd")
const Binman = preload("res://src/binman.gd")
const BinmanRenderer = preload("res://src/binman_renderer.gd")
const NativeLevels = preload("res://src/native_levels.gd")
const WorldTwo = preload("res://src/world_two.gd")
const SupermarketCombat = preload("res://src/supermarket_combat.gd")
const SupermarketRenderer = preload("res://src/supermarket_renderer.gd")
const AisleRenderer = preload("res://src/aisle_renderer.gd")
const ShoppingStreetRenderer = preload("res://src/shopping_street_renderer.gd")
const StockroomRenderer = preload("res://src/stockroom_renderer.gd")
const BakeryRenderer = preload("res://src/bakery_renderer.gd")
const TrolleyDashRenderer = preload("res://src/trolley_dash_renderer.gd")
const CheckoutRenderer = preload("res://src/checkout_renderer.gd")
const WorldThree = preload("res://src/world_three.gd")
const WorldFour = preload("res://src/world_four.gd")
const HolidayCombat = preload("res://src/holiday_combat.gd")
const HolidayRenderer = preload("res://src/holiday_renderer.gd")
const HolidayCaptainRenderer = preload("res://src/holiday_captain_renderer.gd")
const WorldFive = preload("res://src/world_five.gd")
const MovingDayCombat = preload("res://src/moving_day_combat.gd")
const MovingDayRenderer = preload("res://src/moving_day_renderer.gd")
const WorldSix = preload("res://src/world_six.gd")
const BillingCombat = preload("res://src/billing_combat.gd")
const BillingRenderer = preload("res://src/billing_renderer.gd")
const FestivalCombat = preload("res://src/festival_combat.gd")
const FestivalRenderer = preload("res://src/festival_renderer.gd")
const FestivalQueueRenderer = preload("res://src/festival_queue_renderer.gd")
const FestivalNightRenderer = preload("res://src/festival_night_renderer.gd")
const FestivalNightOverlay = preload("res://src/festival_night_overlay.gd")
const FestivalBigTopRenderer = preload("res://src/festival_big_top_renderer.gd")
const FestivalHayrideRenderer = preload("res://src/festival_hayride_renderer.gd")
const FestivalToutRenderer = preload("res://src/festival_tout_renderer.gd")
const FestivalBonusRenderer = preload("res://src/festival_bonus_renderer.gd")
const SceneOverlay = preload("res://src/scene_overlay.gd")
const PlayerHUD = preload("res://src/player_hud.gd")
const MobileGameMenu = preload("res://src/mobile_game_menu.gd")
const ActionControls = preload("res://src/action_controls_renderer.gd")
const SharedEffectsRenderer = preload("res://src/shared_effects_renderer.gd")
const VisualFeedback = preload("res://src/visual_feedback.gd")
const TouchControls = preload("res://src/touch_controls.gd")
const CampaignMap = preload("res://src/campaign_map.gd")
const TitleMenu = preload("res://src/title_menu.gd")
const CreditsRoll = preload("res://src/credits_roll.gd")
const PartySession = preload("res://src/party_session.gd")
const Campaign = preload("res://src/campaign_progression.gd")
const NATIVE_LEVELS = NativeLevels.SUPPORTED
const GOLD := Color("f4c542")
const INK := Color("14102a")
const ZOOM := 1.3
const SPEED := 270.0
const GRAVITY := 3300.0
const JUMP_SPEED := -980.0
const CHARACTERS := ["jp", "maya", "ama", "leo", "theo", "mei"]
const NAMES := ["Jean Phil", "Maya", "Ama", "Leo", "Theo", "Mei"]

var catalog: Dictionary = {}
var meta: Dictionary = {}
var level: Dictionary = {}
var level_id := ""
var character := "jp"
var mode := "menu"
var images: Dictionary = {}
var sheets: Dictionary = {}
var sheet_meta: Dictionary = {}
var player := Vector2.ZERO
var velocity := Vector2.ZERO
var checkpoint := Vector2.ZERO
var camera := Vector2.ZERO
var face := 1
var grounded := true
var jump_held := false
var cooldown := 0.0
var invincible := 0.0
var elapsed := 0.0
var hearts := 3
var score := 0
var receipt_score := 0 # Kitty rewards are not collected coins in the source HUD.
var bullets: Array = []
var enemies: Array = []
var pending_spawns: Array = []
var fired_waves: Dictionary = {}
var receipts: Array = []
var save: Dictionary = {}
var touches: Dictionary = {}
var gameplay_contacts: Dictionary = {} # Keep neutral/dragged-off contacts until lift.
var dpad_rect := Rect2()
var touch_control_style := "joystick" # User-selected translucent virtual stick.
var joystick_contacts: Dictionary = {}
var status := ""
var world_selected := 1
var safe_padding := Vector2(18, 14)
var ui: Control
var player_hud
var credits_roll
var campaign_map
var title_menu
var shared_effects_renderer = SharedEffectsRenderer.new()
var visual_feedback = VisualFeedback.new()
var hud_controls: Array[Button] = []
var status_label: Label
var buttons: Dictionary = {}
var title: Texture2D
var font: Font
var ui_font: Font
var street_combat = Combat.new()
var supermarket_combat = SupermarketCombat.new()
var combat = street_combat
var abilities = Abilities.new()
var movement_skills = MovementSkills.new()
var world_one = WorldOne.new()
var world_two = WorldTwo.new()
var world_three = WorldThree.new()
var world_four = WorldFour.new()
var holiday_combat = HolidayCombat.new()
var holiday_renderer = HolidayRenderer.new()
var holiday_captain_renderer = HolidayCaptainRenderer.new()
var world_five = WorldFive.new()
var moving_day_combat = MovingDayCombat.new()
var moving_day_renderer = MovingDayRenderer.new()
var world_six = WorldSix.new()
var billing_combat = BillingCombat.new()
var billing_renderer = BillingRenderer.new()
var festival_combat = FestivalCombat.new()
var festival_field_renderer = FestivalRenderer.new()
var festival_queue_renderer = FestivalQueueRenderer.new()
var festival_night_renderer = FestivalNightRenderer.new()
var festival_big_top_renderer = FestivalBigTopRenderer.new()
var festival_hayride_renderer = FestivalHayrideRenderer.new()
var festival_tout_renderer = FestivalToutRenderer.new()
var festival_bonus_renderer = FestivalBonusRenderer.new()
var festival_night_level
var festival_night_front
var festival_renderer = festival_field_renderer
var scene_runtime = world_one
var supermarket_renderers := {"2-1": SupermarketRenderer.new(), "2-2": AisleRenderer.new(), "2-3": StockroomRenderer.new(), "2-4": TrolleyDashRenderer.new(), "2-5": BakeryRenderer.new(), "2-6": CheckoutRenderer.new(), "2-S": ShoppingStreetRenderer.new()}
var supermarket_renderer = supermarket_renderers["2-1"]
var rooftop_renderer = RooftopRenderer.new()
var bus_ride = BusRide.new()
var bus_renderer = BusRenderer.new()
var street_renderer = StreetRenderer.new()
var binman_renderer = BinmanRenderer.new()
var boss = null
var story
var audio
var mobile_game_menu
var camera_lock = null
var camera_speed := 0.0
var on_platform := false
var drop_time := 0.0
var crouching := false
var hurt_lock := 0.0
var lock_animation := "hit"
var shoot_time := 0.0
var shoot_diagonal := false
var aim_time := 0.0
var aim_up := false
var up_pose_cache: Dictionary = {}
var animation_time := 0.0
var player_animation := "idle"
var pop_count := 0
var crates: Array = []
var coins: Array = []
var items: Array = []
var power := ""
var power_time := 0.0
var bus_departure := -1.0
var campaign_run := false
var campaign_view := false
var campaign_target := ""
var _paused_mode := "play"
var _story_return_mode := "play"
var _last_floor := 482.0
var _defer_knockout := false
var _pre_grounded := true
var _step_delta := 0.0
var party_session = PartySession.new()

func _ready() -> void:
	font = ThemeDB.fallback_font
	ui_font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/fonts/silk.woff2"):
		font = load("res://assets/fonts/silk.woff2")
		font.fallbacks = [ThemeDB.fallback_font]
	if ResourceLoader.exists("res://assets/fonts/pixelify.woff2"):
		ui_font = load("res://assets/fonts/pixelify.woff2")
		ui_font.fallbacks = [ThemeDB.fallback_font]
	var file := FileAccess.open("res://content/catalog.json", FileAccess.READ)
	if file == null:
		status = "Content missing. Run scripts/import-godot-content.py first."
		queue_redraw()
		return
	catalog = JSON.parse_string(file.get_as_text())
	save = SaveStore.read_save()
	character = str(save.get("friend", "jp"))
	party_session.configure(self, str(save.get("party_mode", "solo")), str(save.get("party_mate", "maya" if character != "maya" else "jp")))
	for key in CHARACTERS + ["bot", "thief"]:
		var path := "res://assets/sprites/%s-sheet.png" % key
		if ResourceLoader.exists(path):
			sheets[key] = load(path)
		var data_path := "res://assets/sprites/%s-sheet.json" % key
		if FileAccess.file_exists(data_path):
			sheet_meta[key] = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if ResourceLoader.exists("res://assets/title.jpg"):
		title = load("res://assets/title.jpg")
	var layer := CanvasLayer.new()
	add_child(layer)
	player_hud = PlayerHUD.new()
	player_hud.game = self
	layer.add_child(player_hud)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	audio = GameAudio.new()
	add_child(audio)
	if FileAccess.file_exists("res://content/story.json"):
		story = Story.new()
		layer.add_child(story)
		story.finished.connect(_story_finished)
	festival_night_level = FestivalNightOverlay.new()
	festival_night_level.configure(self, festival_night_renderer, "level")
	add_child(festival_night_level)
	festival_night_front = FestivalNightOverlay.new()
	festival_night_front.configure(self, festival_night_renderer, "front")
	add_child(festival_night_front)
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 2
	add_child(overlay_layer)
	var overlay := SceneOverlay.new()
	overlay.game = self
	overlay_layer.add_child(overlay)
	credits_roll = CreditsRoll.new()
	layer.add_child(credits_roll)
	credits_roll.finished.connect(_credits_finished)
	get_viewport().size_changed.connect(_resize)
	_resize()
	_show_title()

func _resize(release_input: bool = true) -> void:
	var size := get_viewport_rect().size
	var native_size := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if native_size.x > 0 and safe.size.x > 0:
		# Both landscape notch sides and bottom home indicator are respected.
		safe_padding.x = maxf(18, maxf(safe.position.x, native_size.x - safe.end.x) * size.x / native_size.x)
		safe_padding.y = maxf(14, (native_size.y - safe.end.y) * size.y / native_size.y)
	var touch_layout := TouchControls.layout(size, safe_padding, movement_skills.has_skill("dash"))
	buttons = touch_layout.buttons
	dpad_rect = touch_layout.pad
	if release_input: _release_input()
	_layout_game_hud()
	queue_redraw()

func _clear_ui() -> void:
	mobile_game_menu = null
	campaign_map = null
	title_menu = null
	hud_controls.clear()
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()

func _label(text: String, pos: Vector2, size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_font_override("font", ui_font)
	ui.add_child(label)
	return label

func _button(text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_font_override("font", ui_font)
	button.pressed.connect(callback, CONNECT_DEFERRED)
	ui.add_child(button)
	return button

func _show_menu() -> void:
	if is_instance_valid(credits_roll): credits_roll.stop()
	# Keep the chosen cast/mode, but end the live actor session outside gameplay.
	party_session.active = false
	campaign_view = false
	campaign_run = false
	world_two.invalidate_run()
	world_three.invalidate_run()
	world_four.invalidate_run()
	world_five.invalidate_run()
	world_six.invalidate_run()
	if story != null and story.playing:
		_story_return_mode = "menu"
		story.stop()
	if audio != null:
		audio.stop_music()
		audio.set_paused(false)
		if audio.has_method("start_title"): audio.start_title()
	mode = "menu"
	ui.show()
	ui.z_index = 0
	_release_input()
	_clear_ui()
	_label("BILL DODGERS", Vector2(30, 15), 32).modulate = GOLD
	_button("Play campaign", Rect2(756, 18, 160, 38), _show_campaign)
	_label("Native Godot port • development preview", Vector2(30, 56), 18)
	_label("%d native solo stages. Full mobile QA is in progress." % NativeLevels.SUPPORTED.size(), Vector2(30, 83), 16)
	for i in range(6):
		var n := i + 1
		_button("WORLD %d" % n, Rect2(30 + i * 150, 116, 140, 44), func(): world_selected = n; _show_menu())
	var filtered: Array = catalog.get("levels", []).filter(func(item): return int(item.world) == world_selected)
	for i in range(filtered.size()):
		var item: Dictionary = filtered[i]
		var text := "%s  %s" % [item.id, item.title]
		_button(text, Rect2(30 + (i % 2) * 450, 176 + (i / 2) * 52, 435, 46), func(): load_level(item.id, true))
	_label("Choose a housemate", Vector2(30, 395), 18)
	for i in range(6):
		var key: String = CHARACTERS[i]
		_button(("✓ " if character == key else "") + NAMES[i], Rect2(30 + i * 150, 426, 140, 44), func(): _choose_preview_character(key); _show_menu())
	_label("Move ← → / A D    Jump Z    Aim ↑    Duck ↓    Shoot Space    Special C", Vector2(30, 488), 17)
	if story != null:
		_button("World story", Rect2(756, 383, 160, 36), _story_menu)
	queue_redraw()

func _choose_preview_character(key: String) -> bool:
	# Preview/fallback selectors must preserve the same distinct party as the map.
	if mode != "menu" or key not in CHARACTERS: return false
	var previous: String = character
	var party = party_session.runtime
	if party.mode != "solo" and key == party.p2: party.p2 = previous
	character = key
	party.p1 = key
	save.friend = key
	save.party_mode = party.mode
	save.party_mate = party.p2
	_save_progress()
	return true

func _show_title(menu: bool = false) -> void:
	_show_menu() # Reuse run/story/input teardown, not its development layout.
	_clear_ui()
	title_menu = TitleMenu.new()
	title_menu.configure(self, menu)
	ui.add_child(title_menu)
	queue_redraw()

func _show_campaign(target: String = "") -> void:
	# Development level inspection remains separate from source campaign locks.
	_show_menu()
	campaign_view = true
	campaign_target = target
	if not target.is_empty(): world_selected = int(target[0])
	_clear_ui()
	var state: Dictionary = Campaign.snapshot(save, catalog, NativeLevels.SUPPORTED)
	campaign_map = CampaignMap.new()
	if campaign_map.configure(self, target):
		ui.add_child(campaign_map)
		if audio != null and audio.has_method("play_cue"): audio.play_cue("map")
		queue_redraw()
		return
	# Keep a functional, honest fallback if the generated map file is missing.
	campaign_map.free()
	campaign_map = null
	_label("BILL DODGERS · CAMPAIGN", Vector2(30, 15), 30).modulate = GOLD
	_label("%d / 36 main stages cleared · %d receipts · Kitty £%d" % [state.verified_cleared.keys().filter(func(id): return not id.ends_with("-S")).size(), state.receipt_count, int(save.get("kitty", 0))], Vector2(30, 58), 18)
	_button("Stage previews", Rect2(756, 18, 160, 38), _show_menu)
	for i in range(6):
		var n := i + 1
		var world: Dictionary = state.worlds[i]
		var button := _button("WORLD %d%s" % [n, "" if world.unlocked else " · locked"], Rect2(30 + i * 150, 106, 140, 44), func(): world_selected = n; _show_campaign())
		button.disabled = not world.unlocked
	for i in range(7):
		var id := "%d-%s" % [world_selected, str(i + 1) if i < 6 else "S"]
		var item: Dictionary = state.levels[id]
		var prefix := "✓ " if item.cleared else ("→ " if id == target else "")
		var suffix := " · preview" if not item.supported else (" · locked" if not item.unlocked else "")
		var button := _button(prefix + item.label + suffix, Rect2(30 + (i % 2) * 450, 168 + (i / 2) * 52, 435, 46), func(): start_campaign_level(id))
		button.disabled = not item.playable
		button.tooltip_text = item.reason if not item.playable else "%d / 3 receipts" % item.receipts.size()
	var route: Dictionary = state.next_route
	var note := "Bonus paths open through stage clears. Receipts are optional."
	if not target.is_empty() and not state.levels.get(target, {}).get("supported", false):
		note = "%s is the next destination. Its native gameplay is still being ported." % target
	elif route.kind == "blocked":
		note = "%s is next. Its native gameplay is still being ported; unlocked stages can be replayed." % route.level_id
	_label(note, Vector2(30, 380), 17)
	for i in range(6):
		var key: String = CHARACTERS[i]
		_button(("✓ " if character == key else "") + NAMES[i], Rect2(30 + i * 150, 420, 140, 44), func(): _choose_preview_character(key); _show_campaign(campaign_target))
	if route.kind == "level": _button(state.menu_label, Rect2(300, 478, 360, 44), func(): start_campaign_level(route.level_id))
	if state.credits_unlocked:
		_button("The credits", Rect2(728, 478, 200, 44), _show_credits)
	queue_redraw()

func start_campaign_level(id: String) -> bool:
	# Deferred GUI presses may arrive twice; an active run is not another entry.
	if mode not in ["menu", "clear"] or (story != null and story.playing): return false
	var item: Dictionary = Campaign.level_state(save, catalog, NativeLevels.SUPPORTED, id)
	if not item.get("playable", false): return false
	var before: Array = Campaign.story_before_level(save, catalog, NativeLevels.SUPPORTED, id)
	if not load_level(id, false): return false
	campaign_run = true
	campaign_view = true
	_show_game_hud()
	if not before.is_empty(): _open_story(before[0])
	return true

func _return_to_map() -> void:
	if campaign_run or campaign_view: _show_campaign(level_id)
	else: _show_menu()

func _campaign_next() -> void:
	if mode != "clear" or not campaign_run: return
	var route: Dictionary = Campaign.next_route(save, catalog, NativeLevels.SUPPORTED, level_id)
	# Map focus is the source handoff. Never load a preview or skip its boundary.
	if route.kind in ["level", "blocked"]: _show_campaign(route.level_id)
	elif route.kind == "credits": _show_credits()
	else: _show_campaign()

func _show_credits() -> bool:
	if not Campaign.snapshot(save, catalog, NativeLevels.SUPPORTED).credits_unlocked: return false
	if mode not in ["menu", "clear"] or (story != null and story.playing): return false
	mode = "credits"
	_release_input()
	ui.hide()
	# Supplied source has only a bd-crunch credit read, no repayment producer.
	credits_roll.play(false)
	if audio != null:
		audio.stop_music()
		if audio.has_method("start_ending"): audio.start_ending()
	queue_redraw()
	return true

func _credits_finished() -> void:
	if mode != "credits": return
	_show_title(true)

func load_level(id: String, play_intro: bool = false) -> bool:
	var path := "res://content/levels/%s.json" % id
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("level") is Dictionary:
		return false
	if is_instance_valid(credits_roll): credits_roll.stop()
	if story != null and story.playing:
		_story_return_mode = "play"
		story.stop()
	world_two.invalidate_run()
	world_three.invalidate_run()
	world_four.invalidate_run()
	world_five.invalidate_run()
	world_six.invalidate_run()
	campaign_run = false
	campaign_view = false
	party_session.active = false # Never leak the previous level roster into reset.
	meta = parsed
	level = meta.level
	level_id = id
	scene_runtime = world_six if _native_world_six() else (world_five if _native_world_five() else (world_four if _native_world_four() else (world_three if _native_world_three() else (world_two if _native_world_two() else world_one))))
	combat = billing_combat if _native_world_six() else (moving_day_combat if _native_world_five() else (holiday_combat if _native_world_four() else (festival_combat if _native_world_three() else (supermarket_combat if _native_world_two() else street_combat))))
	_defer_knockout = false
	festival_renderer.clear_cache()
	holiday_renderer.clear_cache()
	holiday_captain_renderer.clear_cache()
	moving_day_renderer.clear_cache()
	billing_renderer.clear_cache()
	if _native_world_three() and not festival_renderer.supports(id):
		festival_renderer = {"3-2": festival_queue_renderer, "3-3": festival_night_renderer, "3-4": festival_big_top_renderer, "3-5": festival_hayride_renderer, "3-6": festival_tout_renderer, "3-S": festival_bonus_renderer}.get(id, festival_field_renderer)
		festival_renderer.clear_cache()
	rooftop_renderer.clear_cache()
	bus_renderer.clear_cache()
	street_renderer.clear_cache()
	binman_renderer.clear_cache()
	for painter in supermarket_renderers.values(): painter.clear_cache()
	supermarket_renderer = supermarket_renderers.get(id, supermarket_renderers["2-1"])
	images.clear()
	for key in meta.get("imgs", {}):
		var asset: String = meta.imgs[key]
		if ResourceLoader.exists(asset):
			images[key] = load(asset)
	player = Vector2(float(level.get("start", 220)), float(level.get("startY", meta.get("ground", 482))))
	elapsed = 0
	scene_runtime.reset(self)
	var spawn_query_y := player.y - 10
	if _native_world_five(): spawn_query_y = float(meta.get("ground", 482)) - (10 if level.get("vert", false) else 3000)
	player.y = floor_at(player.x, spawn_query_y)
	scene_runtime.safe_position = player
	checkpoint = player
	velocity = Vector2.ZERO
	face = 1
	crouching = false
	grounded = true
	hearts = 3
	lock_animation = "hit"
	score = 0
	receipt_score = 0
	cooldown = 0
	invincible = 0
	hurt_lock = 0
	shoot_time = 0
	shoot_diagonal = false
	aim_time = 0
	aim_up = false
	animation_time = 0
	player_animation = "idle"
	pop_count = 0
	camera = Vector2(0, player.y - float(meta.get("ground", 482)))
	camera_speed = 0
	camera_lock = null
	_last_floor = player.y
	boss = null
	bus_departure = -1
	on_platform = false
	drop_time = 0
	power = ""
	power_time = 0
	crates.clear()
	coins.clear()
	items.clear()
	abilities.reset(character, save.get("skills", []))
	movement_skills.reset(id, save.get("skills", []))
	_resize()
	party_session.start(self)
	if party_session.active and scene_runtime.has_method("party_start"):
		party_session.bridge.begin_shared(0)
		scene_runtime.party_start(self)
		party_session.bridge.end_shared(0)
	var participants: int = party_session.runtime.actors.size() if party_session.active else 1
	if _native_world_six(): combat.reset(self, participants, 61)
	elif _native_world_five(): combat.reset(self, participants, 51)
	elif _native_world_four(): combat.reset(self, participants, 41)
	elif _native_world_three(): combat.reset(self, participants, 31)
	elif _native_world_two(): combat.reset(self, participants, 21)
	elif _native_world_one(): combat.reset(self, 11, party_session.runtime.actors.size() if party_session.active else 1)
	else: combat.waves.clear(); combat.checks.clear()
	if _native_world_four(): world_four.seed_pickups(self)
	if _native_world_five(): world_five.seed_pickups(self)
	if _native_world_six(): world_six.seed_pickups(self)
	bus_ride.reset(self)
	bullets.clear()
	enemies.clear()
	pending_spawns.clear()
	fired_waves.clear()
	receipts.clear()
	var saved_receipts: Array = save.receipts.get(id, [])
	for p in level.get("receipts", []):
		# Source picksStart resets every run; persistent history is a separate flag.
		var taken := false
		var receipt_position := world_four.receipt_position(self, receipts.size()) if _native_world_four() else Vector2(p[0], p[1] - (0 if (_native_world_three() or _native_world_five() or _native_world_six()) else (40 if _native_world_two() else 60)))
		if _native_world_five(): receipt_position = world_five.corrected_receipt_position(self, receipts.size())
		if _native_world_six(): receipt_position = world_six.receipt_position(self, receipts.size(), receipt_position)
		receipts.append({"position": receipt_position, "taken": taken, "age": 0.0, "previously_collected": receipts.size() in saved_receipts})
	mode = "play"
	status = "SOLO PLAYTEST · device/fidelity QA pending." if is_native_supported() else "LAYOUT PREVIEW · this level's special mechanics are not ported"
	if party_session.active: status = "PARTY INTEGRATION · full mode/device QA pending."
	player_hud.notifications.reset()
	visual_feedback.reset()
	var stage_text: Dictionary = meta.get("l3", {}).get("txt", {}) if _native_world_three() else (meta.get("txt", {}) if _native_world_four() or _native_world_five() else meta.get("text", {}))
	if _native_world_six(): hud_banner("Stage " + id + ": " + str(level.get("name", "")).to_lower(), str(level.get("sub", "")))
	else: hud_banner(str(stage_text.get("banner", "")), str(stage_text.get("sub", "")))
	_release_input()
	_show_game_hud()
	audio.set_paused(false)
	if audio.has_method("set_level"): audio.set_level(level_id)
	if is_native_supported(): audio.start_music(false)
	else: audio.stop_music()
	if play_intro and id in ["1-1", "2-1"] and not save.get("seen", {}).get(id[0] + "-intro", false): _open_story(id[0] + "-intro")
	queue_redraw()
	return true

func _show_game_hud() -> void:
	_clear_ui()
	# Keep both player HUD panels clear; secondary actions live in one menu.
	status_label = _label(status, Vector2(safe_padding.x, 132), 12)
	status_label.modulate = GOLD
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_color_override("font_outline_color", Color("0e1726"))
	status_label.add_theme_constant_override("outline_size", 3)
	var replay_id := "%s-intro" % level_id[0]
	var can_replay: bool = story != null
	if campaign_run:
		var replay: Array = Campaign.story_replay_for_level(save, catalog, NativeLevels.SUPPORTED, level_id)
		can_replay = can_replay and not replay.is_empty()
		if can_replay: replay_id = replay[-1]
	mobile_game_menu = MobileGameMenu.new()
	mobile_game_menu.configure(ui_font, can_replay, audio == null or audio.enabled)
	mobile_game_menu.set_meta("gameplay", true)
	ui.add_child(mobile_game_menu)
	mobile_game_menu.action_requested.connect(func(action): _game_menu_action(action, replay_id))
	hud_controls.append(mobile_game_menu.launcher)
	_layout_game_hud()

func _layout_game_hud() -> void:
	if is_instance_valid(mobile_game_menu): mobile_game_menu.relayout(get_viewport_rect().size, safe_padding)
	if is_instance_valid(status_label): status_label.position = Vector2(safe_padding.x, 132)

func _game_menu_action(action: String, replay_id: String = "") -> void:
	if action == "open":
		_pause()
		return
	if mode != "paused": return
	match action:
		"resume": _resume()
		"sound":
			if audio != null:
				audio.set_enabled(not audio.enabled)
				if is_instance_valid(mobile_game_menu): mobile_game_menu.set_sound_enabled(audio.enabled)
		"map": _return_to_map()
		"story":
			if _paused_mode != "play" or replay_id.is_empty() or story == null: return
			# One synchronous transition, with no gameplay tick between these calls.
			_resume()
			_open_story(replay_id)

func is_native_supported() -> bool:
	return NativeLevels.supports(level_id)

func _native_world_one() -> bool:
	return NativeLevels.family(level_id) == 1

func _native_world_two() -> bool:
	return NativeLevels.family(level_id) == 2

func _native_world_three() -> bool:
	return NativeLevels.family(level_id) == 3

func _native_world_four() -> bool:
	return NativeLevels.family(level_id) == 4

func _native_world_five() -> bool:
	return NativeLevels.family(level_id) == 5

func _native_world_six() -> bool:
	return NativeLevels.family(level_id) == 6

func _later_world() -> bool:
	return NativeLevels.family(level_id) >= 2

func _finishes_base_frame() -> bool:
	return NativeLevels.family(level_id) >= 3

func family_base_step_active(family: int) -> bool:
	return NativeLevels.family(level_id) == family and _defer_knockout

func holiday_dash_step() -> void:
	if _native_world_four() and hearts > 0: movement_skills.late_step(self, player_animation, actor_is_cpu())

func _source_ability_shots() -> bool:
	return NativeLevels.source_ability_shots(level_id)

func floor_at(x: float, from_y: float) -> float:
	if is_native_supported():
		var surface: Dictionary = scene_runtime.below(self, x, from_y)
		return float(surface.row[2]) if not surface.is_empty() else float(meta.get("ground", 482))
	var found := INF
	for row in level.get("solids", []) + level.get("plats", []):
		if x >= float(row[0]) and x <= float(row[1]) and float(row[2]) >= from_y:
			found = minf(found, float(row[2]))
	return found if found != INF else float(meta.get("ground", 482))

func _land(x: float, old_y: float, new_y: float, skip_platforms: bool = false) -> float:
	if is_native_supported():
		var surface: Dictionary = scene_runtime.land_on(self, x, old_y, new_y, skip_platforms)
		return float(surface.row[2]) if not surface.is_empty() else INF
	var found := INF
	for row in level.get("solids", []) + ([] if skip_platforms else level.get("plats", [])):
		if x >= float(row[0]) and x <= float(row[1]) and old_y <= float(row[2]) + 2 and new_y >= float(row[2]):
			found = minf(found, float(row[2]))
	return found

func _held(action: String) -> bool:
	if TouchControls.held(touches, action):
		return true
	match action:
		"left": return Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
		"right": return Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
		"jump": return Input.is_physical_key_pressed(KEY_Z)
		"aim": return Input.is_physical_key_pressed(KEY_UP)
		"down": return Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)
		"special": return Input.is_physical_key_pressed(KEY_C)
		"dash": return Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_Q)
		"shoot": return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_X) or Input.is_physical_key_pressed(KEY_K)
	return false

func _release_input() -> void:
	touches.clear()
	gameplay_contacts.clear()
	joystick_contacts.clear()
	jump_held = true # Require a fresh release after focus/rotation.
	if party_session.active: party_session.input.release_all()

func _release_contact(id: int) -> void:
	touches.erase(id)
	gameplay_contacts.erase(id)
	joystick_contacts.erase(id)

func _touch(id: int, position: Vector2) -> void:
	touches.erase(id)
	if mode != "play":
		return
	gameplay_contacts[id] = true
	# Retain the steering thumb outside its base, but suspend directions over
	# native HUD controls. A drag must neither activate GUI nor keep moving.
	if joystick_contacts.has(id):
		for control in hud_controls:
			if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(position):
				joystick_contacts[id] = dpad_rect.get_center()
				return
	if touch_control_style == "joystick" and (joystick_contacts.has(id) or (dpad_rect.has_point(position) and joystick_contacts.is_empty())):
		joystick_contacts[id] = position
		var direction := TouchControls.joystick_direction(dpad_rect, position)
		if not direction.is_empty(): touches[id] = direction
		return
	if dpad_rect.has_point(position):
		if touch_control_style == "joystick": return # One steering thumb owns the stick.
		var direction := TouchControls.direction_at(dpad_rect, position)
		if not direction.is_empty(): touches[id] = direction
		return
	for action in buttons:
		if buttons[action].has_point(position):
			touches[id] = action
			return

func _input(event: InputEvent) -> void:
	# A held gameplay contact must update even when it crosses a GUI control.
	# GUI may consume drag events before _unhandled_input; leaving the old
	# action latched there keeps moving/firing after the finger leaves its pad.
	# New presses still go through GUI first, so HUD buttons keep their input.
	if event is InputEventScreenTouch and (not event.pressed or event.canceled):
		_release_contact(event.index)
	elif event is InputEventScreenDrag and gameplay_contacts.has(event.index):
		_touch(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		_release_contact(-1)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and gameplay_contacts.has(-1):
		_touch(-1, event.position)
	# Source bag mash counts each key-down/touch-start, not held-state polls.
	# Count before GUI handling; ignore mouse emulation to avoid double taps.
	if mode != "play" or not _native_world_two() or world_two.checkout == null: return
	if (event is InputEventKey and event.pressed) or (event is InputEventScreenTouch and event.pressed): world_two.checkout.input_event(self)

func scene_music(boss_music: bool = false) -> void:
	if audio != null: audio.start_music(boss_music)

func checkout_event(event: Dictionary) -> void:
	# Defeat only changes the source flag. Music stops on actual jar clear.
	if event.type == "boss_music" and event.get("enabled", false): audio.start_music(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_P]:
		if mode == "play": _pause()
		elif mode == "paused": _resume()
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled: _touch(event.index, event.position)
		else: _release_contact(event.index)
	elif event is InputEventScreenDrag:
		if gameplay_contacts.has(event.index): _touch(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed: _touch(-1, event.position)
		else: _release_contact(-1)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and gameplay_contacts.has(-1):
		_touch(-1, event.position)

func _notification(what: int) -> void:
	if mode == "credits" and is_instance_valid(credits_roll):
		if what == NOTIFICATION_WM_GO_BACK_REQUEST: credits_roll.skip()
		elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
			credits_roll.set_paused(true)
			if audio != null: audio.set_paused(true)
		elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
			credits_roll.set_paused(false)
			if audio != null: audio.set_paused(false)
	# Web exports signal canvas/window focus, rather than application focus.
	# Both routes must pause and release held touches/keys before resuming.
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST]:
		_release_input()
		if mode in ["play", "story"] and is_instance_valid(ui): _pause()

func _pause() -> void:
	if mode not in ["play", "story"]: return
	_paused_mode = mode
	mode = "paused"
	if story != null:
		story.set_paused(true)
		if story.playing: story.hide() # Hidden Control descendants cannot swallow pause GUI taps.
	if audio != null: audio.set_paused(true)
	ui.show()
	ui.z_index = 200
	_release_input()
	if not is_instance_valid(mobile_game_menu):
		mobile_game_menu = MobileGameMenu.new()
		mobile_game_menu.configure(ui_font, false, audio == null or audio.enabled)
		ui.add_child(mobile_game_menu)
		mobile_game_menu.action_requested.connect(_game_menu_action)
		_layout_game_hud()
	mobile_game_menu.open(_paused_mode, audio == null or audio.enabled)
	queue_redraw()

func _resume() -> void:
	if mode != "paused": return
	if is_instance_valid(mobile_game_menu):
		mobile_game_menu.close()
		if not mobile_game_menu.get_meta("gameplay", false): mobile_game_menu.launcher.hide()
	_release_input()
	mode = _paused_mode
	ui.z_index = 0
	if mode == "story": ui.hide()
	if story != null:
		story.set_paused(false)
		if mode == "story" and story.playing: story.show()
	if audio != null: audio.set_paused(mode == "story")

func _process(_delta: float) -> void:
	if is_instance_valid(festival_night_level): festival_night_level.refresh(world_three)
	if is_instance_valid(festival_night_front): festival_night_front.refresh(world_three)

func _physics_process(delta: float) -> void:
	if mode != "play": return
	if party_session.active:
		var touch: Dictionary = {}
		for action in party_session.input.ACTIONS: touch[action] = TouchControls.held(touches, action)
		var p1: Dictionary = party_session.input.read(0, party_session.runtime.mode, touch)
		var p2: Dictionary = party_session.input.read(1, party_session.runtime.mode)
		party_session.step(self, minf(delta, 0.034) if _later_world() else delta, p1, p2)
	else:
		step(minf(delta, 0.034) if _later_world() else delta, {"left": _held("left"), "right": _held("right"), "jump": _held("jump"), "shoot": _held("shoot"), "aim": _held("aim"), "down": _held("down"), "special": _held("special"), "dash": _held("dash")})
	if is_instance_valid(status_label): status_label.text = status
	queue_redraw()

func character_height() -> float:
	return float(meta.get("heights", {}).get(character, 180))

func view_width() -> float:
	return roundf(960.0 / ZOOM)

func view_top() -> float:
	return camera.y + 540.0 - 540.0 / ZOOM

func _wall_clamp(from_x: float, to_x: float, feet: float) -> float:
	if _native_world_six(): return world_six.wall_clamp(self, from_x, to_x, feet)
	if _native_world_five(): return world_five.wall_clamp(self, from_x, to_x, feet)
	if _native_world_four(): return world_four.wall_clamp(self, from_x, to_x, feet)
	if _native_world_three(): return world_three.wall_clamp(self, from_x, to_x, feet)
	if _native_world_two(): return world_two.wall_clamp(self, from_x, to_x, feet)
	for row in level.get("solids", []):
		if float(row[2]) >= feet - 6: continue
		if to_x > from_x and from_x <= float(row[0]) and to_x > float(row[0]) - 14: to_x = minf(to_x, float(row[0]) - 14)
		if to_x < from_x and from_x >= float(row[1]) and to_x < float(row[1]) + 14: to_x = maxf(to_x, float(row[1]) + 14)
	return to_x

func ability_inside_wall(point: Vector2) -> bool:
	if _native_world_six(): return world_six.inside_wall(self, point)
	if _native_world_five(): return world_five.inside_wall(self, point)
	if _native_world_four(): return world_four.inside_wall(self, point)
	if _native_world_three(): return world_three.inside_wall(self, point)
	if _native_world_two(): return world_two.inside_wall(self, point)
	for row in level.get("solids", []):
		if point.x > float(row[0]) and point.x < float(row[1]) and point.y > float(row[2]) + 4: return true
	return false

func ability_land_on(x: float, old_bottom: float, new_bottom: float) -> float:
	return _land(x, old_bottom, new_bottom)

func nudge_player(dx: float) -> void:
	var x := _wall_clamp(player.x, player.x + dx, player.y)
	x = clampf(x, camera.x + 30, camera.x + view_width() - 30)
	if not ability_inside_wall(Vector2(x, player.y - 20)): player.x = x

func step(delta: float, controls: Dictionary) -> void:
	if mode != "play": return
	if party_session.active:
		party_session.step(self, delta, controls)
		return
	player_hud.notifications.step(delta)
	# Source resolves global knockout only after boss clear/objective events.
	_defer_knockout = _source_ability_shots()
	_pre_grounded = grounded
	_step_delta = delta
	elapsed += delta
	if _native_world_four(): world_four.pre_motion(delta, self)
	if _native_world_six(): world_six.pre_motion(delta, self)
	_actor_step(delta, controls)
	if mode != "play": return
	if _native_world_five(): world_five.before_camera(delta, self, controls)
	if hearts > 0 or (_native_world_three() and float(level.get("auto", 0)) > 0): _update_camera(delta)
	if _native_world_one(): world_one.after_camera(delta, self)
	if _native_world_three(): world_three.after_camera(delta, self)
	if _later_world():
		combat.waves_tick(delta, self)
		scene_objective(delta)
		if _native_world_four(): world_four.before_combat(delta, self)
		if _native_world_six(): world_six.world_tick(delta, self)
		if mode == "play" or _finishes_base_frame():
			combat.enemies_tick(delta, self)
			abilities.bubbles_tick(delta, self)
			combat.projectiles_tick(delta, self)
			combat.pickups_tick(delta, self)
	elif _native_world_one(): combat.tick(delta, self)
	else: combat.projectiles(delta, self)
	if mode != "play" and not _finishes_base_frame():
		_finish_step()
		return
	if _native_world_one():
		world_one.crumble_step(delta, self)
		combat.bob_flyers(delta, self)
		world_one.chimney_step(self)
		combat.bailiff_volleys(delta, self)
	if _native_world_two():
		world_two.after_pickups(delta, self)
		if mode != "play":
			_finish_step()
			return
	elif _native_world_three(): world_three.after_pickups(delta, self)
	elif not (_native_world_four() or _native_world_five() or _native_world_six()): collect_level_pickups()
	if hearts > 0 and not _native_world_four(): movement_skills.late_step(self, player_animation, actor_is_cpu())
	if _native_world_one(): world_one.after_pickups(self)
	if _native_world_one(): bus_ride.tick(delta, self)
	if _native_world_three():
		if combat.boss_tick(delta, self) == "mini_done": world_three.mini_done = true
		if combat.jar_tick(delta, self) == "clear": _complete_level()
		combat.visuals_tick(delta, self)
		if level_id == "3-6": world_three.finale.sync_visuals(self, world_three)
		_finish_step() # W3 base all-down precedes the unconditional ability wrapper.
	elif _native_world_four():
		world_four.boss_tick(delta, self)
		if world_four.jar_tick(delta, self) == "clear": _complete_level()
		combat.visuals_tick(delta, self)
		_finish_step()
	elif _native_world_five():
		combat.boss_tick(delta, self)
		if combat.jar_tick(delta, self) == "clear": _complete_level()
		combat.visuals_tick(delta, self)
		_finish_step()
	elif _native_world_six():
		world_six.boss_tick(delta, self)
		if world_six.jar_tick(delta, self) == "clear": _complete_level()
		combat.visuals_tick(delta, self)
		_finish_step()
	elif boss != null:
		var participants: Array[Dictionary] = [{"position": player, "alive": hearts > 0, "height": character_height(), "crouching": crouching}]
		var events: Array = boss.tick(delta, participants, bullets, view_top(), mode == "play") if level_id == "1-6" else boss.tick(delta, participants)
		for event in events: _boss_event(event)
	visual_feedback.tick(delta)
	if _source_ability_shots(): abilities.effects_tick(delta, self)
	_expire_ability_zaps(delta)
	if _native_world_three(): world_three.finish_frame(self)
	if _native_world_four(): world_four.finish_frame(self)
	if _native_world_five(): world_five.finish_frame(self)
	if _native_world_six(): world_six.finish_frame(self)
	if _native_world_two():
		# Source all-down resolution precedes the render-phase scene callback.
		# Native pending callbacks freeze while over and resume on Continue.
		_finish_step()
		world_two.finish_frame(self)
	if mode != "play":
		_finish_step()
		return
	for event in movement_skills.events:
		if event in ["double-jump", "wall-jump"]: sfx("jump")
		elif event == "ground-pound-land": sfx("stomp")
		elif event.begins_with("card:"): sfx("power")
	_finish_step()

func _actor_step(delta: float, controls: Dictionary) -> void:
	# Shared verbatim by solo and the bounded party integration; no world clock.
	invincible = maxf(0, invincible - delta)
	hurt_lock = maxf(0, hurt_lock - delta)
	drop_time = maxf(0, drop_time - delta)
	power_time = maxf(0, power_time - delta)
	if power_time == 0: power = ""
	cooldown -= delta
	movement_skills.begin_step(delta, controls, self)
	var direction := int(controls.get("right", false)) - int(controls.get("left", false))
	var jump: bool = controls.get("jump", false)
	var down: bool = controls.get("down", false)
	var jumped := false
	# W3 updatePlayer caches lock before squash/fall can apply new damage.
	var cached_base_lock := hurt_lock > 0
	crouching = down and not jump and grounded and hurt_lock <= 0
	var movement := 0 if crouching or hurt_lock > 0 else direction
	if direction != 0 and hurt_lock <= 0: face = direction
	var speed: float = abilities.speed_multiplier() if grounded else abilities.airborne_speed_multiplier()
	var displacement: float = scene_runtime.base_displacement(delta, self, movement) if _later_world() else movement * SPEED * speed * delta
	var intended_x := player.x + displacement + velocity.x * delta
	var from_x := player.x
	if _native_world_six():
		# Source evaluates w6Push against the old support before assigning x.
		world_six.carry_player(delta, self)
		intended_x += player.x - from_x
		player.x = from_x
	if _native_world_three():
		player.x = intended_x
		world_three.carry_player(delta, self)
		intended_x = player.x
	var wall_x := _wall_clamp(from_x, intended_x, player.y)
	player.x = wall_x
	player.x = clampf(player.x, camera.x + 30, camera.x + view_width() - 30)
	if _native_world_three(): world_three.squash_player(self)
	var wall_hit := movement if movement != 0 and absf(player.x - intended_x) > 0.3 and player.x > camera.x + 31 and player.x < camera.x + view_width() - 31 else 0
	velocity.x *= pow(0.992, delta * 1000)
	if absf(velocity.x) < 10: velocity.x = 0
	var base_locked: bool = cached_base_lock if _native_world_three() else hurt_lock > 0
	if jump and down and grounded and on_platform and not jump_held and not base_locked and (not _native_world_three() or world_three.allow_drop(self)):
		grounded = false
		velocity.y = 120
		drop_time = 0.26
	elif jump and not jump_held and grounded and not base_locked and (not _native_world_three() or world_three.can_jump(self)):
		velocity.y = JUMP_SPEED * (world_three.jump_multiplier(self) if _native_world_three() else 1.0)
		jumped = true
		grounded = false
		sfx("jump")
	jump_held = jump
	movement_skills.jump_step(self, wall_hit)
	if grounded and _land(player.x, player.y - 2, player.y + 2) == INF:
		grounded = false
		velocity.y = 20
	if _native_world_five(): world_five.carry_player(delta, self)
	if not grounded:
		var old_y := player.y
		velocity.y = minf(1500, velocity.y + GRAVITY * delta)
		player.y += velocity.y * delta
		var landing := _land(player.x, old_y, player.y, drop_time > 0) if velocity.y > 0 else INF
		if landing != INF:
			player.y = landing
			fx_puff(player - Vector2(0,4), Color(1,1,1,.8), 3, 120)
			velocity.y = 0
			grounded = true
			if is_native_supported():
				var surface: Dictionary = scene_runtime.below(self, player.x, player.y)
				on_platform = not surface.is_empty() and surface.plat
				if _native_world_five(): world_five.landing(self, surface)
			else: on_platform = level.get("plats", []).any(func(row): return player.x >= row[0] and player.x <= row[1] and absf(row[2] - player.y) < 1)
		if player.y > float(level.get("fall", 882)): _fall_off()
	if mode != "play":
		_finish_step()
		return
	if is_native_supported(): scene_runtime.after_motion(self)
	# Source passives run after the base motion, not before this frame's gravity.
	if not _later_world():
		if jumped: velocity.y *= abilities.jump_multiplier()
		if not grounded: velocity.y = minf(velocity.y, abilities.max_fall_speed(jump))
	base_locked = cached_base_lock if _native_world_three() else hurt_lock > 0
	if controls.get("shoot", false) and cooldown <= 0 and not base_locked:
		cooldown = 0.26 if power == "split" else 0.21
		shoot_time = 0.3
		shoot_diagonal = controls.get("aim", false) and not crouching
		_fire(controls)
	shoot_time = maxf(0, shoot_time - delta)
	_update_player_animation(delta, controls, movement, cached_base_lock if _native_world_three() else null)
	if hearts > 0: abilities.tick(delta, controls, self, _source_ability_shots() or party_session.active)
	# The source glider intentionally uses the up row in midair, unlike aim input.
	if abilities.active == "leo" and not grounded and hurt_lock <= 0 and player_animation == "jump": player_animation = "up"
	if hearts > 0: movement_skills.post_step(self, abilities.active, player_animation, actor_is_cpu())


# Party APIs expose stable mutable records only inside the once-per-world phase.
# Solo keeps the original host_player branch and never creates a second facade.
func party_capture_scene(actor) -> void:
	actor.scene_state.safe_position = scene_runtime.safe_position
	if _native_world_three():
		actor.scene_state.tied = world_three.tied
		actor.scene_state.standing_surface = world_three._standing_surface
	if _native_world_five(): actor.scene_state.carrying = world_five.carrying

func party_apply_scene(actor) -> void:
	scene_runtime.safe_position = actor.scene_state.get("safe_position", actor.player)
	if _native_world_three():
		world_three.tied = float(actor.scene_state.get("tied", 0))
		world_three._standing_surface = actor.scene_state.get("standing_surface", {})
	if _native_world_five(): world_five.carrying = bool(actor.scene_state.get("carrying", false))

func configure_party(selected_mode: String, mate: String = "maya") -> bool:
	return party_session.configure(self, selected_mode, mate)

func actor_is_cpu() -> bool:
	if not party_session.active: return false
	var actor = party_session.runtime.actor_at(combat_owner_slot())
	return actor != null and actor.cpu

func combat_owner_slot() -> int:
	return party_session.bridge.active_slot if party_session.active and party_session.bridge.shared_phase else (party_session.active_slot if party_session.active else -1)

func combat_participants() -> Array:
	if party_session.active: return party_session.bridge.participants()
	return [{"host_player": true, "slot": -1, "p": player, "hearts": hearts, "down": hearts <= 0,
		"height": character_height(), "crouching": crouching, "grounded": grounded, "invincible": invincible,
		"hurt_lock": hurt_lock, "player_animation": player_animation, "face": face, "power": power,
		"power_time": power_time, "velocity": velocity}]

func call_combat_participant(record: Dictionary, operation: Callable, arguments: Array = []) -> Variant:
	if not party_session.active or record.get("host_player", false): return operation.callv(arguments)
	return party_session.bridge.call_for_actor(int(record.slot), operation, arguments)

func hurt_combat_participant(record: Dictionary, from_x: float) -> void:
	call_combat_participant(record, hurt_player, [from_x])

func credit_combat_pop(owner_slot: int = -1) -> void:
	if owner_slot == -2: return
	if not party_session.active:
		pop_count += 1
		return
	var slot := combat_owner_slot() if owner_slot < 0 else owner_slot
	if party_session.bridge.shared_phase: party_session.bridge.credit_pop(slot)
	elif slot == party_session.active_slot: pop_count += 1
	else: party_session.runtime.record_pop(slot)

func combat_bubbles_tick(delta: float) -> void:
	if party_session.active: party_session.bubbles_tick(self, delta)
	else: abilities.bubbles_tick(delta, self)

func combat_participant_blocks_damage(record: Dictionary) -> bool:
	return bool(call_combat_participant(record, _active_actor_blocks_damage))

func _active_actor_blocks_damage() -> bool:
	return hearts <= 0 or invincible > 0 or movement_skills.blocks_damage() or abilities.blocks_damage(self)

func festival_base_step_active() -> bool:
	return _native_world_three() and _defer_knockout

func festival_event(event: Dictionary) -> void:
	if event.get("type", "") == "firework": sfx("firework")
	if event.get("type", "") == "spotlight_on": status = str(event.get("text", "Lights on!"))
	if event.has("banner"): status = str(event.banner) + (". " + str(event.sub) if event.has("sub") else "")
	if event.has("banner"): hud_banner(str(event.banner), str(event.get("sub", "")), bool(event.get("warn", false)))
	if event.has("music") and audio != null: audio.start_music(bool(event.music))
	if event.has("boss_music") and audio != null: audio.start_music(bool(event.boss_music))

func hud_banner(text: String, sub := "", warning := false) -> void:
	player_hud.notifications.show_banner(text, sub, warning)

func hud_go(duration := 2.2) -> void:
	player_hud.notifications.show_go(duration)

func holiday_event(event: Dictionary) -> void:
	# Captain already applies sounds, coins and combat changes. Only present them.
	match str(event.get("type", "")):
		"shake": fx_shake(float(event.get("amount", 0)))
		"bits": fx_bits(event.p)
		"text": fx_float(str(event.text), event.p, Color("ffb3b3") if event.text == "Crew!" else Color("ffd2e6"))
		"hit":
			if event.get("valve", false) and not world_four.captain.boss.is_empty():
				var captain: Dictionary = world_four.captain.boss
				fx_puff(Vector2(captain.x + 70 * (1 if captain.face < 0 else -1), captain.y - 120), Color("ffd2e6"), 5, 250)
			fx_puff(event.p, Color.WHITE, 4, 200)
	if event.get("type", "") == "warning": hud_banner(str(event.get("text", "Warning!")), str(event.get("sub", "")), bool(event.get("warn", false)))
	if event.has("banner"): hud_banner(str(event.banner), str(event.get("sub", "")), bool(event.get("warn", false)))
	if event.has("music") and audio != null: audio.start_music(bool(event.music))

# Presentation callbacks are guarded at world/combat call sites so isolated
# physics fixtures do not need UI or renderer state. W6 owns its source floats.
func fx_puff(at: Vector2, colour: Color, count := 6, speed := 250.0) -> void:
	visual_feedback.puff(at, colour, count, speed)

func fx_bits(at: Vector2) -> void: visual_feedback.bits(at)
func fx_coin(at: Vector2) -> void: visual_feedback.coin_pickup(at)
func fx_item(at: Vector2, give: String) -> void:
	var text: String = {"heart":"+1 heart", "split":"Split shot!", "wellies":"Wellies! Jump on them"}.get(give, "Direct debit!")
	fx_float(text, at - Vector2(0,40), Color("ffb3b3") if give == "heart" else GOLD)
func fx_shake(amount: float) -> void: visual_feedback.shake_screen(amount)
func fx_burst(at: Vector2, colour: Color, count := 16) -> void: visual_feedback.burst(at, colour, count)
func fx_float(text: String, at: Vector2, colour := GOLD) -> void:
	if _native_world_six(): world_six.add_float(text, at, colour)
	else: visual_feedback.add_float(text, at, colour)

func _finish_step() -> void:
	_defer_knockout = false
	if not party_session.active and mode == "play" and hearts <= 0: _game_over()

func _up_pose_ok(key: String) -> bool:
	if up_pose_cache.has(key): return up_pose_cache[key]
	up_pose_cache[key] = false
	var data: Dictionary = sheet_meta.get(key, {})
	if not sheets.has(key) or not data.get("anims", {}).has("up") or not data.anims.has("idle"): return false
	var pixels: Image = sheets[key].get_image()
	if pixels == null or pixels.is_empty(): return false
	if pixels.is_compressed() and pixels.decompress() != OK: return false
	var up_height := _opaque_frame_height(pixels, data, "up", mini(1, int(data.anims.up.frames) - 1))
	var idle_height := _opaque_frame_height(pixels, data, "idle", 0)
	up_pose_cache[key] = up_height > idle_height * 0.8
	return up_pose_cache[key]

func _opaque_frame_height(pixels: Image, data: Dictionary, animation: String, frame: int) -> int:
	var top := -1
	var bottom := -1
	var width := int(data.w)
	var height := int(data.h)
	var row := int(data.anims[animation].row)
	for y in range(height):
		for x in range(width):
			if pixels.get_pixel(frame * width + x, row * height + y).a * 255 > 40:
				if top < 0: top = y
				bottom = y
				break
	return 0 if top < 0 else bottom - top

func _update_player_animation(delta: float, controls: Dictionary, movement: int, base_lock_override: Variant = null) -> void:
	var animation := "jump" if not grounded else ("crouch" if crouching else ("run" if movement else "idle"))
	var locked: bool = hurt_lock > 0 if base_lock_override == null else bool(base_lock_override)
	if locked: animation = lock_animation
	elif grounded and not crouching and shoot_time > 0:
		if shoot_diagonal: animation = "rundiag" if movement else "diag"
		elif movement == 0: animation = "shoot"
	if player_animation != animation:
		var stride := player_animation in ["run", "rundiag"] and animation in ["run", "rundiag"]
		player_animation = animation
		if not stride: animation_time = 0
	animation_time += delta
	aim_up = false
	if actor_is_cpu() or not grounded or hurt_lock > 0 or not controls.get("aim", false) or controls.get("down", false):
		aim_time = 0
		return
	if movement != 0:
		if player_animation != "rundiag" and player_animation != "run": animation_time = 0
		player_animation = "rundiag"
		aim_time = 0
	else:
		aim_time += delta
		aim_up = _up_pose_ok(character)
		player_animation = "up" if aim_up else "diag"

func _player_frame(animation: String = "") -> int:
	if animation.is_empty(): animation = player_animation
	var data: Dictionary = sheet_meta.get(character, {})
	var count := int(data.get("anims", {}).get(animation, {"frames": 1}).frames)
	if animation == "up" and aim_up:
		return mini(3, 1 + int((0.3 - shoot_time) / 0.1)) if shoot_time > 0 else (0 if aim_time < 0.09 else 3)
	if animation == "jump": return 1 if velocity.y < -500 else (2 if velocity.y < 350 else 3)
	if animation in ["shoot", "diag"]: return mini(3, 1 + int((0.3 - shoot_time) / 0.1)) if shoot_time > 0 else 0
	if animation == "crouch": return mini(3, 1 + int((0.3 - shoot_time) / 0.1)) if shoot_time > 0 else mini(1, int(animation_time / 0.08))
	if animation == "hit": return mini(count - 1, int(animation_time / 0.11))
	var fps: int = {"idle": 5, "run": 15, "jump": 6, "shoot": 12, "crouch": 8, "up": 10, "hit": 8, "win": 7, "diag": 12, "rundiag": 15}.get(animation, 7)
	return int(animation_time * fps) % count

func _fire(controls: Dictionary) -> void:
	var height := character_height()
	var aim: bool = controls.get("aim", false) and not crouching
	var moving: bool = controls.get("left", false) or controls.get("right", false)
	var upward: bool = aim and not moving and not actor_is_cpu()
	var origin := player + Vector2(face * height * (0.38 if crouching else 0.32), -height * (0.34 if crouching else 0.53))
	var speed := Vector2(face * 780, 0)
	if aim and not crouching:
		if upward:
			origin = player + Vector2(face * height * 0.05, -height * 0.97)
			speed = Vector2(face * 0.1, -780)
		else:
			origin = player + Vector2(face * height * 0.36, -height * 0.7)
			speed = Vector2(face * 780 * 0.71, -780 * 0.71)
	_add_shot(origin, speed, power == "debit" and not upward)
	if power == "split":
		if upward:
			_add_shot(origin, Vector2(200, -741)); _add_shot(origin, Vector2(-200, -741))
		elif aim:
			_add_shot(origin, Vector2(face * 741, -200)); _add_shot(origin, Vector2(face * 296.4, -686.4))
		else:
			_add_shot(origin, Vector2(face * 741, -200)); _add_shot(origin, Vector2(face * 741, 120))
	elif power == "debit" and upward: _add_shot(origin, Vector2(face * 0.1, -897))
	sfx({"jp":"coin", "maya":"flower", "ama":"bubble", "leo":"plane", "theo":"ball", "mei":"sweet"}[character])

func _add_shot(position: Vector2, speed: Vector2, homing: bool = false) -> void:
	bullets.append({"p": position, "v": speed, "life": 20.0, "enemy": false, "damage": 1, "homing": homing, "kind": character, "first_frame": true, "owner_slot": combat_owner_slot(), "owner_x": player.x})

func collect_level_pickups() -> void:
	if (_native_world_two() or _native_world_four()) and not party_session.active:
		for receipt in receipts: receipt.age += _step_delta
	_collect_receipts()
	if is_native_supported():
		var collected: String = movement_skills.collect_card(player, character, hearts > 0)
		if not collected.is_empty():
			save.skills = movement_skills.skills.duplicate()
			abilities.skills = movement_skills.skills.duplicate()
			if party_session.active:
				party_session.runtime.grant_skill(collected)
				for actor in party_session.runtime.actors: actor.movement_skills.card_collected = true
			_save_progress()
			# Adding a skill control must not cancel stationary held fingers.
			_resize(false)
			status = "Skill card: Slide! Run, then press down." if collected == "slide" else "Skill card: " + collected
			var captions := {
				"slide":["Skill card: Slide!","Run, then press down to slide under things and through robots"],
				"double-jump":["Skill card: double jump!","Press jump again in the air to jump higher"],
				"ground-pound":["Skill card!","Ground pound: everyone can use it now"],
				"dash":["Skill card: Dash!","Tap a direction twice quickly (or Shift) to dash"],
				"wall-jump":["Skill card: wall jump!","Jump into a wall, then jump again to kick off it" if DisplayServer.is_touchscreen_available() else "Jump into a wall, then press jump again to kick off it"],
				"super":["Skill card!","Super special: every friend's special hits twice as hard"]}
			if captions.has(collected): hud_banner(captions[collected][0],captions[collected][1])

func ability_movement_locked() -> bool:
	return hurt_lock > 0

func ability_post_motion(delta: float, controls: Dictionary) -> void:
	# Source W3 bonus nudges sample current mud/tie after base physics; W2 uses its own policy.
	if not _later_world() or hearts <= 0: return
	var direction := int(controls.get("right", false)) - int(controls.get("left", false))
	var extra: float = (abilities.speed_multiplier() if grounded else abilities.airborne_speed_multiplier()) - 1.0
	if direction != 0 and not crouching and hurt_lock <= 0:
		# Only W3 defines source spdMul. W2 movement mutates ice momentum;
		# never call it twice. W5 carry slows base motion, not this passive nudge.
		var bonus: float = world_three.base_displacement(delta, self, direction) * extra if _native_world_three() else direction * SPEED * extra * delta
		nudge_player(bonus)
	if _pre_grounded and not grounded and velocity.y < -500: velocity.y *= abilities.jump_multiplier()
	if not grounded: velocity.y = minf(velocity.y, abilities.max_fall_speed(controls.get("jump", false)))

func _collect_receipts() -> void:
	if hearts <= 0: return
	for i in range(receipts.size()):
		var receipt: Dictionary = receipts[i]
		var original_y: float = receipt.position.y + (0 if (_native_world_four() or _native_world_five()) else (40 if _native_world_two() else 60))
		var near: bool = world_three.finds_near(self, receipt.position) if _native_world_three() else (absf(player.x - receipt.position.x) < 42 and player.y > original_y - (30 if _native_world_two() else 120) and player.y - character_height() < original_y)
		if _native_world_five(): near = world_five.finds_near(self, receipt.position)
		if _native_world_six(): near = world_six.finds_near(self, receipt.position)
		if not receipt.taken and near:
			receipt.taken = true
			receipt.age = 0.0
			if _native_world_six(): world_six.add_float("Secret receipt %d/3" % receipts.filter(func(r): return r.taken).size(), receipt.position - Vector2(0,40), Color("9fe0b8"))
			var receipt_reward := 0 if (_native_world_three() or _native_world_five() or _native_world_six()) else 5
			score += receipt_reward
			receipt_score += receipt_reward
			var saved: Array = save.receipts.get(level_id, [])
			if not i in saved: saved.append(i)
			save.receipts[level_id] = saved
			_save_progress()
			sfx("power")

func hurt_player(from_x: float) -> void:
	if invincible > 0 or hearts <= 0 or mode != "play": return
	if movement_skills.blocks_damage() or abilities.blocks_damage(self): return
	hearts -= 1
	invincible = 1.5
	hurt_lock = 0.42
	lock_animation = "hit"
	velocity.x = -350 if player.x < from_x else 350
	player_animation = "hit"
	animation_time = 0
	sfx("hurt")
	fx_shake(6)
	fx_puff(player - Vector2(0, character_height() * .6), Color.WHITE, 8)
	if hearts <= 0 and party_session.active:
		fx_float("Help!", player - Vector2(0, character_height() + 20), Color("ffb3b3"))
		status = NAMES[CHARACTERS.find(character)] + " is down. Stand next to them to help them up."
	if hearts <= 0 and not _defer_knockout and not party_session.active: _game_over()

func _fall_off() -> void:
	if _native_world_six():
		world_six.fall_off(self)
		return
	if _native_world_four():
		world_four.fall_off(self)
		return
	if is_native_supported():
		scene_runtime.recover_from_fall(self)
		return
	player.x = clampf(checkpoint.x, camera.x + 70, camera.x + view_width() - 70)
	player.y = floor_at(player.x, -9999)
	velocity = Vector2.ZERO
	grounded = true
	invincible = 0
	hurt_player(player.x - face)
	status = "Mind the gap!"

func _game_over() -> void:
	movement_skills.cancel_on_death()
	mode = "over"
	hurt_lock = 0
	_release_input()
	audio.set_paused(true)
	_clear_ui()
	_label("Knocked out", Vector2(345, 150), 36)
	_label("Carry on with the current encounter", Vector2(284, 208), 22)
	_button("Continue", Rect2(350, 270, 260, 60), _continue_level)
	_button("Back to worlds", Rect2(350, 346, 260, 60), _return_to_map)

func _continue_level() -> void:
	# Source revives players in place. It does not reload the level, rewind the
	# camera, erase collected coins or reset an in-flight bus encounter.
	if mode != "over": return
	if party_session.active: party_session.continue_in_place(self)
	hearts = 3
	invincible = 2.5
	hurt_lock = 0
	mode = "play"
	if _native_world_five():
		if party_session.active: party_session.bridge.begin_shared(0)
		world_five.respawn(self)
		if party_session.active: party_session.bridge.end_shared(0)
	_release_input()
	_show_game_hud()
	audio.set_paused(false)
	sfx("revive")
	status = "Back in the chase!"

func _update_camera(delta: float) -> void:
	if _native_world_six() and world_six.camera_override(delta, self): pass
	elif _native_world_four() and world_four.camera_step(delta, self): pass
	elif _native_world_three() and float(level.get("auto", 0)) > 0:
		# World 3 auto replaces follow entirely, including during warmup/wipes.
		camera.x = minf(float(level.w) - view_width(), camera.x + world_three.auto_displacement(delta, self))
	elif _native_world_two() and float(level.get("auto", 0)) > 0:
		# Source trolley dash is variable camera scrolling, never a moving deck.
		camera.x = minf(float(level.w) - view_width(), camera.x + world_two.auto_displacement(delta, self))
		camera_speed = 0
	else:
		var want: float = party_session.runtime.camera_follow_x(camera.x, view_width(), float(level.w), camera_lock) if party_session.active else maxf(camera.x, minf(player.x - view_width() * 0.45, player.x - 60))
		if camera_lock != null: want = minf(want, float(camera_lock))
		if _native_world_two(): want = minf(want, world_two.camera_cap(self))
		if _native_world_five(): want = minf(want, world_five.camera_cap(self))
		want = minf(float(level.w) - view_width(), want)
		var difference := want - camera.x
		var target := minf(420, difference / 0.24) if difference > 0 else 0.0
		camera_speed = maxf(0, move_toward(camera_speed, target, 1200 * delta))
		camera.x = minf(maxf(camera.x, want), camera.x + camera_speed * delta)
	if hearts <= 0: return # Auto horizontal still advances on the final lethal base frame.
	if _native_world_five() and level_id == "5-5":
		camera.y = 0
		return
	if grounded or player.y > _last_floor: _last_floor = player.y
	var foot := minf(_last_floor, player.y + 170)
	var target_y: float = party_session.runtime.camera_follow_y(float(meta.get("ground", 482)), 540.0 / ZOOM) if party_session.active else minf(0, foot - float(meta.get("ground", 482)) + 30)
	camera.y += (target_y - camera.y) * minf(1, delta / 0.26)

func damage_enemy(enemy: Dictionary, damage: int) -> void:
	if _source_ability_shots(): _ability_zap(enemy.p - Vector2(0, 56), damage, _target_direction(enemy.p.x))
	else: combat.damage_enemy(self, enemy, damage)

func skill_wall_clamp(from_x: float, to_x: float, feet: float) -> float:
	return _wall_clamp(from_x, to_x, feet)

func skill_floor_below(x: float, y: float) -> float:
	if is_native_supported():
		var surface: Dictionary = scene_runtime.below(self, x, y)
		return float(surface.row[2]) if not surface.is_empty() else INF
	var nearest := INF
	for row in level.get("solids", []) + level.get("plats", []):
		if x >= float(row[0]) and x <= float(row[1]) and float(row[2]) >= y - 2:
			nearest = minf(nearest, float(row[2]))
	return nearest

func skill_slide_hit(enemy: Dictionary, damage: int, shove_dx: float) -> void:
	if enemy.state == "pop": return
	enemy.hp -= damage
	enemy.flash = 0.09
	enemy.p.x += shove_dx
	if enemy.hp <= 0: combat.kill_enemy(self, enemy)

func scene_objective(delta: float) -> void:
	if not is_native_supported(): return
	var event: String = scene_runtime.objective_tick(delta, self) if _later_world() else (bus_ride.objective_tick(delta, self) if level_id == "1-3" else world_one.objective_tick(delta, self))
	match event:
		"boss": start_boss()
		"ending":
			status = meta.get("l3", {}).get("txt", {}).get("end", "The way ahead is clear!") if _native_world_three() else (meta.get("text", {}).get("end", "The way ahead is clear!") if _native_world_two() else meta.get("text", {}).get("endBanner", "The way ahead is clear!"))
			if _native_world_four() or _native_world_five(): status = meta.get("txt", {}).get("end", "The way ahead is clear!")
			if _native_world_six(): status = str(level.get("endText", "The way ahead is clear!"))
			var ending_text: Dictionary = meta.get("l3", {}).get("txt", {}) if _native_world_three() else (meta.get("txt", {}) if _native_world_four() or _native_world_five() else meta.get("text", {}))
			hud_banner(status, str(level.get("endSub", "")) if _native_world_six() else str(ending_text.get("endSub", "")))
			sfx("honk")
		"clear": _complete_level()

func damage_boss(damage: int) -> void:
	if boss == null: return
	var point := Vector2(boss.state.x, boss.state.fy - 120)
	if _source_ability_shots(): _ability_zap(point, damage, _target_direction(point.x))
	else: boss.hit(point, damage)

func hit_crate(crate: Dictionary, damage: int) -> void:
	if _source_ability_shots(): _ability_zap(crate.p - Vector2(0, 30), damage)
	else: combat.hit_crate(self, crate, damage)

func _target_direction(x: float) -> float:
	var direction := signf(x - player.x)
	return direction if direction != 0 else float(face)

func ability_free_zap(point: Vector2, direction: float) -> bool:
	if not _source_ability_shots(): return false
	_ability_zap(point, 1, direction)
	return true

func _ability_zap(point: Vector2, damage: int, direction: float = 0) -> void:
	# Original abilities are invisible shots, so helpers/lid/crates can intercept.
	bullets.append({"p": point, "v": Vector2((direction if direction != 0 else float(face)) * 0.1, 0), "life": 20.0, "enemy": false, "damage": damage, "ghost": true, "ghost_age": 0.0, "owner_slot": combat_owner_slot(), "owner_x": player.x})

func _expire_ability_zaps(delta: float) -> void:
	# Source wrapper expires ghosts AFTER the ordinary shot and boss-bin passes.
	for bullet in bullets.duplicate():
		if bullet.get("ghost", false):
			bullet.ghost_age += delta
			if bullet.ghost_age > 0.07: bullet.life = 0
		if bullet.life <= 0 or bullet.get("dead", false): bullets.erase(bullet)

func add_coins(position: Vector2, count: int) -> void:
	for i in range(count):
		coins.append({"p": position + Vector2(combat.rng.randf_range(-15, 15), 0), "v": Vector2(combat.rng.randf_range(-175, 175), combat.rng.randf_range(-1000, -550)), "age": 0.0, "rest": false})

func start_boss() -> void:
	if boss != null or level_id not in ["1-1", "1-6"]: return
	camera_lock = float(level.w) - view_width()
	boss = Binman.new() if level_id == "1-6" else Boss.new()
	boss.reset(float(level.w), view_width(), float(meta.ground), party_session.runtime.actors.size() if party_session.active else 1, 31)
	status = meta.get("text", {}).get("boss", "Warning! The jar thief is here.")
	hud_banner("Warning!", "The jar thief is here" if level_id == "1-1" else "The Binman Bot. Shoot inside the lid!", true)
	audio.start_music(true)

func _boss_event(event: Dictionary) -> void:
	match event.type:
		"bill": bullets.append({"p": event.position, "v": event.velocity, "gravity": event.gravity, "big": event.big, "enemy": true, "life": 20.0})
		"spawn_bot": combat.spawn(self, event.side, event.kind)
		"hurt_player":
			if party_session.active: hurt_combat_participant(party_session.bridge.record(int(event.get("player_index", 0))), event.source_x)
			else: hurt_player(event.source_x)
		"drop_coins": add_coins(event.position, event.count)
		"kill_bots":
			for enemy in enemies: combat.kill_enemy(self, enemy, false)
		"down":
			bus_departure = elapsed + event.bus_delay
			status = meta.get("text", {}).get("bossDown", "Binman is down!") if level_id == "1-6" else "The thief is down. Grab the jar!"
			if level_id == "1-6": sfx("pop")
			sfx("stomp")
		"clear": _complete_level()
		"warning": sfx("warn")
		"hit", "clang", "bin_hit": sfx("hitBot")
		"jar_spawn": sfx("power")
		"stomp", "bin_land": sfx("stomp")
		"throw": sfx("throw")

func _complete_level() -> void:
	if mode != "play" or not is_native_supported(): return
	if party_session.active:
		party_session.settle_coins(self)
		party_session.settle_clear(self)
	# Original stageClear revives a down player for the celebration.
	if hearts <= 0: hearts = 1
	score += coins.size()
	coins.clear()
	mode = "clear"
	_release_input()
	audio.stop_music()
	sfx("win")
	var cleared: Dictionary = save.get("cleared", {})
	cleared[level_id] = true
	save.cleared = cleared
	save.kitty = int(save.get("kitty", 0)) + score
	_save_progress()
	_clear_ui()
	var clear_text: String = meta.get("l3", {}).get("txt", {}).get("clear", "Stage cleared!") if _native_world_three() else meta.get("text", {}).get("clear" if _native_world_two() else "cleared", "Stage cleared!")
	if _native_world_four() or _native_world_five(): clear_text = meta.get("txt", {}).get("clear", "Stage cleared!")
	if _native_world_six(): clear_text = str(level.get("clear", "Stage cleared!"))
	_label(clear_text, Vector2(300, 135), 38).modulate = GOLD
	_label("£%d returned to the shared jar" % score, Vector2(300, 200), 24)
	_label("%d robots popped · native solo playtest" % pop_count, Vector2(300, 242), 20)
	_button("Settle up", Rect2(350, 305, 260, 60), _settle_up)
	if campaign_run:
		var after: Array = Campaign.story_after_clear(save, catalog, NativeLevels.SUPPORTED, level_id)
		if not after.is_empty(): _open_story(after[0])

func _settle_up() -> void:
	if mode != "clear": return
	_clear_ui()
	_label("All back in the jar.", Vector2(300, 160), 34).modulate = GOLD
	_label("Next time bring a mate. Co-op is still being ported.", Vector2(225, 225), 20)
	if campaign_run:
		_button("Play again", Rect2(90, 300, 240, 60), func(): start_campaign_level(level_id))
		_button("Next level", Rect2(360, 300, 240, 60), _campaign_next)
		_button("Back to worlds", Rect2(630, 300, 240, 60), _return_to_map)
	else:
		_button("Play again", Rect2(220, 300, 240, 60), func(): load_level(level_id))
		_button("Back to worlds", Rect2(490, 300, 240, 60), _show_menu)

func _save_progress() -> void:
	if SaveStore.write_save(save) != OK: status = "Progress could not be saved on this device."

func sfx(effect: String) -> void:
	if audio != null: audio.play_effect(effect)

func _story_menu() -> void:
	_clear_ui()
	_label("World %d story" % world_selected, Vector2(310, 100), 32)
	var ids: Array = ["%d-intro" % world_selected, "%d-clue" % world_selected, "%d-boss" % world_selected]
	if world_selected == 6: ids.append("6-ending")
	for i in range(ids.size()):
		var id: String = ids[i]
		_button(story.data.scenes.get(id, {}).get("title", id), Rect2(200, 170 + i * 60, 560, 50), func(): _open_story(id))
	_button("Back", Rect2(350, 430, 260, 50), _show_menu)

func _open_story(id: String) -> void:
	if story == null or story.playing: return
	_story_return_mode = mode
	_release_input()
	if not story.play(id): return
	mode = "story"
	ui.hide()
	audio.set_paused(true)
	var seen: Dictionary = save.get("seen", {})
	seen[id] = true
	save.seen = seen
	_save_progress()

func _story_finished(_id: String, _skipped: bool) -> void:
	mode = _story_return_mode
	ui.show()
	ui.z_index = 0
	_release_input()
	audio.set_paused(false)

func _draw() -> void:
	if mode in ["menu", "credits"]:
		if title: draw_texture_rect(title, Rect2(0, 0, 960, 540), false, Color(1, 1, 1, 0.22))
		if not status.is_empty() and catalog.is_empty(): draw_string(ThemeDB.fallback_font, Vector2(25, 100), status)
		return
	if meta.is_empty(): return
	draw_set_transform(Vector2(-camera.x * ZOOM, 540 * (1 - ZOOM) - camera.y * ZOOM) + visual_feedback.offset, 0, Vector2.ONE * ZOOM)
	if _native_world_four():
		holiday_renderer.draw_sky(self, world_four)
		holiday_renderer.draw_level(self, world_four)
	elif _native_world_six():
		billing_renderer.draw_sky(self, world_six)
		billing_renderer.draw_level(self, world_six)
	elif _native_world_five():
		moving_day_renderer.draw_sky(self, world_five)
		moving_day_renderer.draw_level(self, world_five)
	elif _native_world_three():
		if level_id != "3-3":
			festival_renderer.draw_sky(self, world_three)
			festival_renderer.draw_level(self, world_three)
	elif _native_world_two():
		supermarket_renderer.draw_sky(self, world_two)
		supermarket_renderer.draw_level(self, world_two)
	elif level_id == "1-2": rooftop_renderer.draw_scene(self, world_one)
	elif level_id == "1-3": bus_renderer.draw_scene(self, bus_ride)
	elif street_renderer.supports(level_id): street_renderer.draw_scene(self, world_one, _draw_pickups)
	else: _draw_background()
	if not is_native_supported():
		for row in level.get("solids", []) + level.get("plats", []):
			draw_rect(Rect2(row[0], row[2], float(row[1]) - float(row[0]), 20), Color("586d72"))
	if _native_world_four():
		holiday_renderer.draw_mid(self, world_four)
		for crate in crates: holiday_renderer.draw_crate(self, crate)
		for item in items: holiday_renderer.draw_item(self, item)
		for coin in coins: holiday_renderer.draw_coin(self, coin)
		holiday_captain_renderer.draw_boss(self, world_four)
		_draw_enemy_actors()
		holiday_renderer.draw_foes(self, world_four)
		holiday_captain_renderer.draw_jar(self, world_four)
		_draw_player_actor()
	elif _native_world_six():
		for crate in crates: billing_renderer.draw_crate(self, crate)
		for item in items: billing_renderer.draw_item(self, item)
		for coin in coins: billing_renderer.draw_coin(self, coin)
		billing_renderer.draw_boss(self, world_six)
		_draw_enemy_actors()
		billing_renderer.draw_mid(self, world_six)
		billing_renderer.draw_jar(self, world_six)
		_draw_player_actor()
	elif _native_world_five():
		for crate in crates: moving_day_renderer.draw_crate(self, crate)
		for item in items: moving_day_renderer.draw_item(self, item)
		for coin in coins: moving_day_renderer.draw_coin(self, coin)
		moving_day_renderer.draw_boss(self, world_five)
		_draw_enemy_actors()
		moving_day_renderer.draw_mid(self, world_five)
		moving_day_renderer.draw_jar(self, world_five)
		_draw_player_actor()
	elif _native_world_three():
		festival_renderer.draw_mid(self, world_three)
		for crate in crates: festival_renderer.draw_crate(self, crate)
		for item in items: festival_renderer.draw_item(self, item)
		for coin in coins: festival_renderer.draw_coin(self, coin)
		festival_renderer.draw_boss(self, world_three)
		_draw_enemy_actors()
		if level_id == "3-6": festival_tout_renderer.draw_jar(self, world_three)
		if not party_session.active: festival_renderer.draw_player_back(self, player)
		_draw_player_actor()
		if not party_session.active: festival_renderer.draw_player_front(self, player)
	elif _native_world_two():
		_draw_crates()
		supermarket_renderer.draw_mid(self, world_two, _draw_pickups)
		_draw_loot()
		_draw_enemy_actors()
		if supermarket_renderer.has_method("draw_jar"): supermarket_renderer.draw_jar(self, world_two)
		if not party_session.active: supermarket_renderer.draw_player_back(self, player)
		_draw_player_actor()
		if not party_session.active: supermarket_renderer.draw_player_front(self, player)
	else:
		if not street_renderer.supports(level_id): _draw_pickups()
		_draw_world_objects()
		_draw_boss()
		_draw_enemy_actors()
		_draw_player_actor()
	for bullet in bullets:
		if bullet.get("ghost", false): continue
		if bullet.enemy and _native_world_three(): festival_renderer.draw_bill(self, bullet)
		elif bullet.enemy and _native_world_six(): billing_renderer.draw_bill(self, bullet)
		elif bullet.enemy and _native_world_five(): moving_day_renderer.draw_bill(self, bullet)
		elif bullet.enemy: shared_effects_renderer.draw_bill(self, bullet)
		else: shared_effects_renderer.draw_shot(self, bullet)
	visual_feedback.draw(self, font, camera)
	if _native_world_three():
		if level_id != "3-3": festival_renderer.draw_front(self, world_three)
	elif _native_world_four(): holiday_renderer.draw_front(self, world_four)
	elif _native_world_six(): billing_renderer.draw_front(self, world_six)
	elif _native_world_five(): moving_day_renderer.draw_front(self, world_five)
	elif _native_world_two(): supermarket_renderer.draw_front(self, world_two)
	elif level_id == "1-2": rooftop_renderer.draw_front(self, world_one)
	elif level_id == "1-3": bus_renderer.draw_front(self, bus_ride)
	elif street_renderer.supports(level_id): street_renderer.draw_front(self, world_one)
	var movement_effects: Array = movement_skills.effects
	if party_session.active:
		movement_effects = []
		for actor in party_session.runtime.actors: movement_effects.append_array(actor.movement_skills.effects)
	for effect in movement_effects:
		if effect.kind == "ring":
			var radius: float = 30 + effect.age / effect.life * 180
			var points := PackedVector2Array()
			for i in range(49): points.append(effect.p + Vector2(cos(TAU * i / 48) * radius, -4 + sin(TAU * i / 48) * radius * 0.22))
			draw_polyline(points, Color(1, 1, 1, maxf(0, 1 - effect.age / effect.life)), 5)
	draw_set_transform(Vector2.ZERO)
	if _finishes_base_frame(): pass # SceneOverlay paints the source HUD over the native UI.
	elif boss != null and level_id == "1-6": binman_renderer.draw_hud(self, boss)
	elif boss != null and level_id != "1-1" and boss.state.state != "down":
		draw_rect(Rect2(280, 83, 400, 16), INK)
		draw_rect(Rect2(280, 83, 400 * maxf(0, float(boss.state.hp) / boss.state.max), 16), GOLD if boss.state.dizzy > 0 else Color("e23b3b"))
		draw_string(font, Vector2(280, 78), "Jar thief", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	if mode not in ["play", "paused"]: return
	if level_id != "3-3": draw_touch_controls(self)

func draw_touch_controls(canvas: CanvasItem) -> void:
	if touch_control_style == "joystick": TouchControls.draw_joystick(canvas, dpad_rect, joystick_contacts)
	else: TouchControls.draw_dpad(canvas, dpad_rect, touches)
	ActionControls.draw(canvas, self)

func _draw_player_actor() -> void:
	if not party_session.active:
		_draw_single_player_actor()
		return
	var original: Dictionary = {}
	for key in party_session.runtime.Actor.NATIVE_FIELDS: original[key] = get(key)
	var order: Array = party_session.runtime.actors.duplicate()
	order.sort_custom(func(a, b): return a.down and not b.down)
	# Source global ability FX draw once before the first actor. Owned balls from
	# both actors share that pass, then each body receives its own aura.
	for i in order.size():
		order[i].apply_native(self)
		shared_effects_renderer.draw_fx(self, i == 0)
	for actor in order:
		actor.apply_native(self)
		if _native_world_three(): festival_renderer.draw_player_back(self, player)
		elif _native_world_two(): supermarket_renderer.draw_player_back(self, player)
		if actor.down: _draw_down_actor(actor)
		else: _draw_single_player_actor(false, actor.slot, actor.cpu)
		if _native_world_three(): festival_renderer.draw_player_front(self, player)
		elif _native_world_two(): supermarket_renderer.draw_player_front(self, player)
	for key in original: set(key, original[key])

func _draw_single_player_actor(with_fx := true, slot := 0, cpu := false) -> void:
	var animation := "win" if mode == "clear" else player_animation
	var player_frame := _player_frame(animation)
	var feet := player - Vector2(0, float(level.get("ride", 0))) if _native_world_two() else player
	if with_fx: shared_effects_renderer.draw_fx(self)
	_draw_actor_shadow(feet)
	shared_effects_renderer.draw_aura(self, true, feet)
	var blink: bool = invincible > 0 and int(invincible / .09) % 2 == 0
	_sprite(character, animation, feet, face, float(sheet_meta[character].h), player_frame, animation_time, .45 if blink else 1.0)
	shared_effects_renderer.draw_aura(self, false, feet)
	_draw_actor_tag(feet, slot, cpu)

func _world_draw_transform() -> Transform2D:
	return Transform2D(0, Vector2.ONE * ZOOM, 0, Vector2(-camera.x * ZOOM, 540 * (1 - ZOOM) - camera.y * ZOOM) + visual_feedback.offset)

func _draw_actor_shadow(feet: Vector2) -> void:
	var surface: Dictionary = scene_runtime.below(self, feet.x, feet.y - 2)
	if surface.is_empty(): return
	var floor_y: float = surface.row[2]
	if floor_y - feet.y >= 400: return
	var radius := maxf(16, 48 * (1 - (floor_y - feet.y) / 600))
	var points := PackedVector2Array()
	for i in 48: points.append(Vector2(feet.x + cos(TAU*i/48)*radius, floor_y-2+sin(TAU*i/48)*6))
	draw_colored_polygon(points, Color(14/255.0,23/255.0,38/255.0,.28))

func _draw_actor_tag(feet: Vector2, slot: int, cpu: bool) -> void:
	var p := feet - Vector2(0, character_height() + 22)
	var colour := GOLD if slot == 0 else Color("ff8fc7")
	var style := StyleBoxFlat.new()
	style.bg_color = colour; style.set_corner_radius_all(6)
	draw_style_box(style, Rect2(p-Vector2(19,10),Vector2(38,20)))
	var label := "CPU" if cpu else "P%d" % (slot+1)
	var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	draw_string(font,p+Vector2(-width/2,5),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("14243b"))
	draw_colored_polygon(PackedVector2Array([p+Vector2(-6,10),p+Vector2(6,10),p+Vector2(0,16)]),colour)

func _draw_down_actor(actor) -> void:
	_draw_actor_shadow(player)
	var transform := _world_draw_transform()
	draw_set_transform_matrix(transform * Transform2D(-PI/2*face, player-Vector2(0,22)))
	_sprite(character,"hit",Vector2(0,character_height()*.45),face,float(sheet_meta[character].h),1)
	draw_set_transform_matrix(transform)
	var center := player - Vector2(0,character_height()*.55)
	draw_arc(center,26,0,TAU,48,Color(14/255.0,23/255.0,38/255.0,.6),6)
	if actor.revive>0: draw_arc(center,26,-PI/2,-PI/2+TAU*minf(1,actor.revive/1.4),48,Color("9fe0b8"),6)
	if int(elapsed/.4)%2:
		var width := font.get_string_size("Help!",HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		draw_string(font,center+Vector2(-width/2,4),"Help!",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffb3b3"))

func _draw_enemy_actors() -> void:
	for enemy in enemies:
		if _native_world_four(): holiday_renderer.draw_enemy(self, enemy)
		elif _native_world_six(): billing_renderer.draw_enemy(self, enemy)
		elif _native_world_five(): moving_day_renderer.draw_enemy(self, enemy)
		elif _native_world_three(): festival_renderer.draw_enemy(self, enemy)
		elif _native_world_two(): supermarket_renderer.draw_enemy(self, enemy)
		elif enemy.kind == "fly" and enemy.state != "pop" and images.has("drone"):
			var drone: Texture2D = images.drone
			draw_texture(drone, enemy.p - Vector2(drone.get_width() / 2.0, drone.get_height()))
		else:
			var enemy_animation: String = "pop" if enemy.state == "pop" else ("throw" if enemy.state == "throw" else "walk")
			var enemy_frame := mini(3, int(enemy.t / 0.11)) if enemy_animation != "walk" else -1
			_sprite("bot", enemy_animation, enemy.p, -int(enemy.face), float(sheet_meta.bot.h) * enemy.scale, enemy_frame, enemy.t)
		if enemy.kind == "mini" and enemy.state != "pop":
			draw_rect(Rect2(enemy.p - Vector2(45, 265), Vector2(90, 8)), INK)
			draw_rect(Rect2(enemy.p - Vector2(45, 265), Vector2(90 * maxf(0, float(enemy.hp) / enemy.max_hp), 8)), Color("e23b3b"))

func _draw_world_objects() -> void:
	if level_id == "1-1":
		var bus: Dictionary = meta.get("bus", {})
		if not bus.is_empty() and images.has("bus"):
			var t := maxf(0, elapsed - bus_departure) if bus_departure >= 0 else 0.0
			draw_texture(images.bus, Vector2(bus.x + minf(t * t * 120, 3000), bus.y - bus.h))
			if bus.has("lamp") and images.has("lamp"): draw_texture(images.lamp, Vector2(bus.lamp.x, bus.lamp.y))
	if _native_world_one() and not street_renderer.supports(level_id):
		for check_point in combat.checks:
			var feet := floor_at(check_point.x, -9999)
			draw_line(Vector2(check_point.x, feet), Vector2(check_point.x, feet - 150), Color("2a2f3d"), 6)
			draw_colored_polygon(PackedVector2Array([Vector2(check_point.x + 3, feet - 146), Vector2(check_point.x + 58, feet - 132), Vector2(check_point.x + 3, feet - 112)]), Color("2d6a4f") if check_point.hit else Color("7a8aa8"))
	_draw_crates()
	_draw_loot()

func _draw_crates() -> void:
	const Loot = preload("res://src/shared_loot_renderer.gd")
	Loot.draw_crates(self, crates, elapsed)

func _draw_loot() -> void:
	const Loot = preload("res://src/shared_loot_renderer.gd")
	Loot.draw(self, coins, items)

func _draw_pickups() -> void:
	for receipt in receipts:
		if _native_world_two():
			if receipt.taken and receipt.age > 0.9: continue
			if receipt.position.x < camera.x - 30 or receipt.position.x > camera.x + view_width() + 30: continue
			var p: Vector2 = receipt.position + Vector2(0, sin(receipt.age / 0.26) * 4 - (receipt.age * 80 if receipt.taken else 0.0))
			var alpha := maxf(0, 1 - receipt.age / 0.9) if receipt.taken else 1.0
			draw_circle(p, 24 + sin(receipt.age / 0.15) * 3, Color(1, 241.0 / 255, 168.0 / 255, 0.35 * alpha))
			draw_rect(Rect2(p - Vector2(11, 18), Vector2(22, 34)), Color(1, 1, 1, alpha))
			for k in 5: draw_rect(Rect2(p + Vector2(-7, -13 + k * 6), Vector2(10 if k % 2 else 14, 2)), Color(154.0 / 255, 165.0 / 255, 184.0 / 255, alpha))
			for k in 4: draw_colored_polygon(PackedVector2Array([p + Vector2(-11 + k * 5.5, 16), p + Vector2(-8 + k * 5.5, 20), p + Vector2(-5.5 + k * 5.5, 16)]), Color(1, 1, 1, alpha))
			if not receipt.taken and int(receipt.age / 0.2) % 3 == 0:
				draw_rect(Rect2(p + Vector2(14, -22), Vector2(3, 3)), Color.WHITE)
				draw_rect(Rect2(p + Vector2(-18, 8), Vector2(3, 3)), Color.WHITE)
		elif not receipt.taken:
			draw_circle(receipt.position, 21, Color(1, 0.83, 0.3, 0.3))
			draw_rect(Rect2(receipt.position - Vector2(9, 14), Vector2(18, 28)), Color.FLORAL_WHITE)
	_draw_skill_card()

func _draw_skill_card() -> void:
	if not is_native_supported() or movement_skills.card_collected or not MovementSkills.CARDS.has(level_id): return
	var card: Dictionary = MovementSkills.CARDS[level_id]
	var p: Vector2 = card.p + Vector2(0, -60 + sin(elapsed / 0.2 + card.p.x) * 4)
	if p.x < camera.x - 40 or p.x > camera.x + view_width() + 40: return
	draw_circle(p, 30 + sin(elapsed / 0.12) * 3, Color(0.62, 0.88, 0.72, 0.4))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2d6a4f")
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	draw_style_box(style, Rect2(p - Vector2(20, 26), Vector2(40, 52)))
	var caption: String = card.skill.to_upper()
	var icon := "__" if card.skill == "slide" else "+"
	draw_string(font, p + Vector2(-font.get_string_size(icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x / 2, -3), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
	draw_string(font, p + Vector2(-font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x / 2, 17), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

func _draw_boss() -> void:
	if boss == null: return
	if level_id == "1-6":
		binman_renderer.draw_world(self, boss)
		return
	var b: Dictionary = boss.state
	var animation := "run"
	var frame := int(b.t / (0.08 if b.state == "enter" else 0.13)) % 6
	if b.dizzy > 0: animation = "down"; frame = int(b.t / 0.22) % 2
	elif b.state in ["throw", "stomp"]:
		animation = "throw"
		frame = mini(3, int(b.t / 0.16)) if b.state == "throw" else (0 if b.t < 0.32 else 1)
	if b.state == "down": animation = "down"; frame = mini(3, int(b.t / 0.3)) if b.jar.is_empty() else 2
	_sprite("thief", animation, Vector2(b.x, b.fy), -int(b.face), float(sheet_meta.thief.h), frame, b.t)
	for wave in b.waves:
		for i in range(4): draw_rect(Rect2(wave.x - 6 - i * 8 * signf(wave.vx), b.fy - 10 - (3 - i) * 7, 12, 10 + (3 - i) * 4), Color("e8e1d2"))
	if not b.jar.is_empty():
		var position := Vector2(b.jar.x, b.jar.y)
		if not b.jar.got: draw_circle(position, 44, Color(1, 0.83, 0.25, 0.3))
		draw_rect(Rect2(position - Vector2(18, 25), Vector2(36, 44)), Color("a0cfce"), false, 4)
		draw_rect(Rect2(position - Vector2(21, 30), Vector2(42, 8)), GOLD)
		draw_circle(position, 10, GOLD)

func _control_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.38, 0.09, 0.88) if active else Color(0.07, 0.05, 0.14, 0.67)
	style.set_corner_radius_all(18)
	style.set_border_width_all(2)
	style.border_color = GOLD if active else Color(1, 1, 1, 0.5)
	return style

func _draw_background() -> void:
	if meta.has("chunk"):
		var chunk := float(meta.chunk)
		for i in range(int(camera.x / chunk), int(camera.x / chunk) + 2):
			var key := "st%d" % i
			if images.has(key): draw_texture(images[key], Vector2(i * chunk, 0))
		return
	# Deliberately a layout preview for scene-specific renderers not yet ported.
	var preferred := ["wall", "wall2", "hallA", "far_board", "sky", "bg", "view"]
	for key in preferred:
		if not images.has(key): continue
		var texture: Texture2D = images[key]
		var width := maxf(100, texture.get_width() * 540.0 / texture.get_height())
		var start := floorf(camera.x / width) * width
		for i in range(3): draw_texture_rect(texture, Rect2(start + i * width, camera.y, width, 540), false)
		return

func _sprite(key: String, animation: String, feet: Vector2, facing: int, height: float, frame_override: int = -1, time_override: float = -1, opacity: float = 1.0) -> void:
	if not sheets.has(key): return
	var data: Dictionary = meta.get("sheets", {}).get(key, sheet_meta.get(key, {}))
	if data.is_empty(): return
	var frames: Dictionary = data.anims.get(animation, data.anims.values()[0])
	var frame := int((elapsed if time_override < 0 else time_override) * (15 if animation == "run" else 7)) % int(frames.frames)
	if frame_override >= 0: frame = mini(frame_override, int(frames.frames) - 1)
	var source := Rect2(frame * float(data.w), float(frames.row) * float(data.h), data.w, data.h)
	var width := height * float(data.w) / float(data.h)
	var anchor := 0.45 if key in CHARACTERS else 0.5
	var dest := Rect2(feet.x - width * anchor, feet.y - height + 3 * height / float(data.h), width, height)
	if facing < 0:
		# Godot flips in place; preserve the source asymmetric foot anchor.
		dest.position.x = feet.x + width * anchor - width
		dest.size.x = -width
	draw_texture_rect_region(sheets[key], dest, source, Color(1,1,1,clampf(opacity,0,1)))
