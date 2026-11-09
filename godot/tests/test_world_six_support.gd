extends RefCounted
const Runtime = preload("res://src/world_six.gd")
const Combat = preload("res://src/billing_combat.gd")
class NullAbilities extends RefCounted:
	func enemy_is_bubbled(_b) -> bool: return false
var world_six = Runtime.new()
var combat = Combat.new()
var abilities = NullAbilities.new()
var level_id := "6-1"
var level: Dictionary = {}
var meta: Dictionary = {}
var player := Vector2(300, 482)
var velocity := Vector2.ZERO
var camera := Vector2.ZERO
var camera_speed := 0.0
var camera_lock = null
var checkpoint := Vector2.ZERO
var grounded := true
var on_platform := false
var invincible := 0.0
var hearts := 3
var crouching := false
var face := 1
var mode := "play"
var score := 0
var pop_count := 0
var elapsed := 0.0
var status := ""
var power := ""
var power_time := 0.0
var character := "jp"
var boss = null
var enemies: Array = []
var bullets: Array = []
var coins: Array = []
var items: Array = []
var crates: Array = []
var receipts: Array = []
var images: Dictionary = {}
var sheets: Dictionary = {}
var font: Font = ThemeDB.fallback_font
var hurt_calls := 0
var pickup_calls := 0
var sounds: Array = []
var recorded: Array = []
var banners: Array = []
var go_durations: Array = []
var music_modes: Array = []
func hud_banner(text: String, sub: String = "", warning: bool = false) -> void: banners.append({"text": text, "sub": sub, "warn": warning})
func hud_go(duration: float = 2.2) -> void: go_durations.append(duration)
func scene_music(boss_music: bool = false) -> void: music_modes.append(boss_music)
func load_stage(id: String) -> void:
	level_id = id
	banners.clear();go_durations.clear();music_modes.clear()
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % id))
	level = meta.level
	player = Vector2(level.start, meta.ground)
	camera = Vector2.ZERO
	velocity = Vector2.ZERO
	camera_lock = null
	hearts = 3
	invincible = 0
	grounded = true
	on_platform = false
	mode = "play"
	score = 0
	pop_count = 0
	boss = null
	enemies.clear()
	bullets.clear()
	coins.clear()
	items.clear()
	crates.clear()
	receipts.clear()
	for r in level.receipts: receipts.append({"position": Vector2(r[0], r[1]), "taken": false, "age": 0.0})
	world_six.reset(self)
	combat.reset(self)
	world_six.seed_pickups(self)
func view_width() -> float: return 960.0 / 1.3
func view_top() -> float: return camera.y + 540 - 540 / 1.3
func character_height() -> float: return 180.0
func _land(x: float, a: float, b: float, skip: bool = false) -> float:
	var q: Dictionary = world_six.land_on(self, x, a, b, skip)
	return INF if q.is_empty() else float(q.row[2])
func ability_inside_wall(p: Vector2) -> bool: return world_six.inside_wall(self, p)
func collect_level_pickups() -> void: pickup_calls += 1
func sfx(effect: String) -> void: sounds.append(effect)
func hurt_player(_from: float) -> void:
	hurt_calls += 1
	if invincible > 0 or hearts <= 0 or mode != "play": return
	hearts -= 1
	invincible = 1.5
func add_coins(p: Vector2, count: int) -> void:
	for i in range(count): coins.append({"p": p, "v": Vector2(0, -600), "age": 0.0, "rest": false})
func load_images() -> void:
	images.clear()
	for key in meta.imgs: images[key] = load(meta.imgs[key])
	sheets.bot = load("res://assets/sprites/bot-sheet.png")
func draw_texture_rect_region(t,r,s,c): recorded.append(["texture", t, r, s, c])
func draw_rect(r,c): recorded.append(["rect", r, c])
func draw_colored_polygon(p,c): recorded.append(["polygon", p, c])
func draw_polygon(p,c,uv = null,t = null): recorded.append(["gradient", p, c])
func draw_polyline(p,c,w): recorded.append(["line", p, c, w])
func draw_style_box(s,r): recorded.append(["style", s, r])
func draw_string(f,p,t,a,w,s,c): recorded.append(["text", f,p,t,a,w,s,c])
func draw_string_outline(f,p,t,a,w,s,o,c): recorded.append(["outline",f,p,t,a,w,s,o,c])
