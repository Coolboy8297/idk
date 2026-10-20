extends Node2D
## PIXELBOUND: RIFT RUNNER  (v3.1 - Visual Overhaul)
## Godot 4.x — attach this single script to an otherwise-empty Node2D and press Play.
## Everything (rigged hero, 500 generated levels, UI, particles, synth audio) is built at runtime.
##
## CONTROLS
##   Move ........ A / D, arrows, left stick, D-pad
##   Jump ........ SPACE / W / UP / pad A     (hold = higher; buffered + coyote time)
##   Sword ....... J / X / pad X              (tap repeatedly for a 3-hit combo)
##   Dash ........ K / SHIFT / pad B          (invulnerable while dashing)
##   Drop down ... S / DOWN / stick down      (through thin platforms)
##   Pause ....... ESC / START      Music ... M      Save ... F5
## MENUS (keyboard, mouse or controller)
##   D-pad / stick navigate, A select, B back, LB / RB (or Q / E) change level page.

# ─────────────────────────────── Constants ───────────────────────────────
const SAVE_PATH := "user://pixelbound_save_v3.json"
const SAVE_VERSION := 3
const TOTAL_LEVELS := 500
const PAGE_SIZE := 25
const PAGE_COUNT := 20
const VIEW_SIZE := Vector2i(960, 540)
const MIX_RATE := 22050.0
const PIXEL := 2

const GRAVITY := 1500.0
const FALL_GRAVITY_MULT := 1.35
const MAX_FALL := 760.0
const MOVE_SPEED := 250.0
const GROUND_ACCEL := 2200.0
const GROUND_FRICTION := 2600.0
const AIR_ACCEL := 1500.0
const JUMP_SPEED := -520.0
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
const DASH_SPEED := 620.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.7
const INVULN_TIME := 1.1
const WALKER_SPEED := 60.0
const GROUND_TOP := 385.0
const PIT_Y := 720.0

const L_SOLID := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_ONEWAY := 8

const OUT := Color("#0e1424")

enum State { MENU, PLAYING, PAUSED, DEAD, WON }

## Sword combo styles: [start angle, end angle, damage, hit width, hit reach, duration]
const ATTACK_STYLES := [
	[-2.5, 0.7, 1, 66.0, 34.0, 0.30],
	[1.0, -1.3, 1, 66.0, 34.0, 0.30],
	[-3.0, 1.6, 2, 90.0, 42.0, 0.40]
]

## World themes (10 levels per world, 10 themes cycling)
const THEMES := [
	["NEON DUSK", "#0b1020", "#2a2f5e", "#2b3a52", "#243248", "#72d6a0", "#4fa47c", "#426b78", "#8be8c0", "#1b2547", "#17203d", "#111a31"],
	["CRIMSON RIFT", "#1a0a12", "#5e2a3a", "#4a2a35", "#3a1f29", "#ff8a65", "#cc5f45", "#7a4452", "#ffb199", "#3a1a28", "#2e1420", "#220e18"],
	["EMERALD DEPTHS", "#05140f", "#14503a", "#1f4a3a", "#183a2e", "#9be86a", "#6cb24a", "#2f7a5c", "#b6f2a0", "#0f3326", "#0c291f", "#081f17"],
	["FROZEN VOID", "#0a1224", "#2b5a8a", "#3b5878", "#2f4862", "#e6f6ff", "#a9d4f0", "#5a86ad", "#e6f6ff", "#1d3a5c", "#162e4a", "#102338"],
	["GOLDEN RUINS", "#1a1206", "#6b4a1a", "#5a4528", "#473620", "#ffd866", "#c9a23d", "#8a6a35", "#ffe9a6", "#3d2c12", "#2f220e", "#231a0a"],
	["VIOLET STORM", "#120a24", "#4a2a7a", "#3a2c5c", "#2e2349", "#c4a3ff", "#9a78e0", "#5b4bc4", "#d3c2ff", "#26194a", "#1d1338", "#150e2a"],
	["ASH PLAINS", "#121212", "#3d3d3d", "#3a3a3f", "#2e2e33", "#bdbdbd", "#8c8c8c", "#55555c", "#d0d0d0", "#262626", "#1e1e1e", "#161616"],
	["AQUA REEF", "#041a24", "#0f6b7a", "#1a5566", "#144552", "#6af0e0", "#3fb8aa", "#2b8a9a", "#a8fff3", "#0b3a47", "#093040", "#062530"],
	["ROSE NEBULA", "#1e0a24", "#8a3a7a", "#5c2f5a", "#4a2448", "#ff9ad5", "#d06aa8", "#8a4a86", "#ffc6ea", "#3a1740", "#2e1233", "#220d28"],
	["SOLAR FLARE", "#240a04", "#8a3a0a", "#5a2f14", "#48240f", "#ffb347", "#d98a1f", "#8a4a1f", "#ffd9a0", "#4a1a0a", "#3a1408", "#2a0e05"]
]

const MUSIC_NOTES := [
	220.0, 261.63, 329.63, 261.63, 196.0, 246.94, 293.66, 246.94,
	174.61, 220.0, 261.63, 220.0, 196.0, 246.94, 329.63, 246.94
]

# ─────────────────────────────── Higher-detail pixel art ───────────────────────────────
const WALKER_ROWS := [
	"..............",
	"....oooooo....",
	"...orrrrrro...",
	"..orrrrrrrro..",
	".orrrwwrrrrro.",
	".orrwkkwwrrro.",
	".orrrrrrrrrro.",
	".orrRRRRrrrro.",
	".orRwwRRwrro..",
	".orrrrrrrrro..",
	"..orrrrrrro...",
	"...oo..oo.....",
	".............."
]
const FLYER_ROWS := [
	"o............o",
	"opo...oo...opo",
	"oppo.oppo.oppo",
	"opppopppoppppo",
	".opppwkkwpppo.",
	"..oppppppppo..",
	"...ooppppoo...",
	".....oooo....."
]
const CRYSTAL_ROWS := [
	"...o...",
	"..oco..",
	".ocCco.",
	"occCcco",
	".occcco",
	"..occo.",
	"...oo.."
]
const HEART_ROWS := [
	".ooo.ooo.",
	"orwrorrro",
	"orrrrrrro",
	".orrrrro.",
	"..orrro..",
	"...oro...",
	"....o...."
]

# ─────────────────────────────── State ───────────────────────────────
var state: State = State.MENU
var rng := RandomNumberGenerator.new()

var world: Node2D
var level_root: Node2D
var dynamic: Node2D
var player: CharacterBody2D
var player_visual: Node2D
var camera: Camera2D
var backdrop: Node2D
var platform_tweens: Array[Tween] = []
var exit_node: Node2D
var exit_swirl: Polygon2D
var checkpoint_flags: Array[Polygon2D] = []
var spike_rects: Array[Rect2] = []
var enemies: Array[Node2D] = []
var items: Array[Dictionary] = []

var level_data: Dictionary = {}
var theme: Dictionary = {}
var ground_segs: Array = []
var world_end := 3000.0
var exit_x := 2900.0
var boss_ref: Node2D = null
var boss_alive := false
var shards_total := 0

var tex_walker: Texture2D
var tex_flyer: Texture2D
var tex_crystal: Texture2D
var tex_heart: Texture2D
var tex_heart_empty: Texture2D

# Hero rig
var rig := {}
var pose := {}
var scarf_nodes: Array[Node2D] = []
var hair_nodes: Array[Node2D] = []

# Progress (saved)
var max_health := 5
var unlocked := 1
var current_level := 1
var total_score := 0
var level_best := {}
var music_on := true
var unlock_all := false
var upgrade_levels := {"health": 0, "speed": 0, "dash": 0, "sword": 0}
var mouse_lock_enabled := false

# Per-level run state
var health := 5
var score := 0
var shards := 0
var checkpoint_idx := -1
var run_time := 0.0

# Player runtime
var facing := 1.0
var coyote := 0.0
var jump_buffer := 0.0
var attack_cd := 0.0
var attack_t := -1.0
var attack_style := 0
var combo_window := 0.0
var attack_hits := {}
var dash_cd := 0.0
var dash_time := 0.0
var dash_dir := 1.0
var invulnerable := 0.0
var hurt_stun := 0.0
var drop_time := 0.0
var input_lock := 0.0
var ghost_t := 0.0
var combo := 0
var combo_timer := 0.0

# Visual runtime
var anim_time := 0.0
var run_anim := 0.0
var squash := Vector2.ONE
var look := 0.0
var shake := 0.0
var message_text := ""
var message_time := 0.0

# Audio
var sound_player: AudioStreamPlayer
var sound_playback: AudioStreamGeneratorPlayback
var voices: Array[Dictionary] = []
var music_timer := 0.0
var music_step := 0

# UI
var hud: CanvasLayer
var ui_root: Control
var health_bar: ProgressBar
var health_label: Label
var score_label: Label
var time_label: Label
var best_label: Label
var dash_label: Label
var status_label: Label
var level_label: Label
var progress: ProgressBar
var boss_bar: ProgressBar
var menu_panel: PanelContainer
var menu_title: Label
var menu_hint: Label
var menu_mode := "start"
var screen_main: VBoxContainer
var screen_levels: VBoxContainer
var screen_upgrades: VBoxContainer
var upgrade_buttons: Array[Button] = []
var mouse_lock_btn: Button
var resume_btn: Button
var restart_btn: Button
var levels_btn: Button
var music_btn: Button
var quit_btn: Button
var level_buttons: Array[Button] = []
var level_page := 0
var page_label: Label
var unlock_btn: Button

# ─────────────────────────────── Setup ───────────────────────────────
func _ready() -> void:
	rng.randomize()
	_setup_window()
	_setup_input_map()
	_make_textures()
	_make_audio()
	world = Node2D.new()
	world.name = "GeneratedWorld"
	add_child(world)
	_make_player()
	_make_camera()
	_make_backdrop()
	_make_hud()
	_load_game()
	_build_level(current_level)
	_place_player_at_checkpoint()
	_refresh_music_button()
	_refresh_level_page()
	_update_hud()
	_set_state(State.MENU)
	_open_start_menu()

func _setup_window() -> void:
	var win := get_window()
	win.content_scale_size = VIEW_SIZE
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.set_default_clear_color(Color("#0b1020"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and state == State.PLAYING and menu_panel != null:
		_pause()

# ─────────────────────────────── Input map ───────────────────────────────
func _ensure_action(action: String, deadzone := 0.4) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)

func _add_key(action: String, keycode: Key) -> void:
	_ensure_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _add_pad_button(action: String, button: JoyButton) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _add_pad_axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure_action(action, 0.3)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)

func _setup_input_map() -> void:
	_ensure_action("move_left", 0.3)
	_ensure_action("move_right", 0.3)
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_pad_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_pad_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_key("jump", KEY_SPACE)
	_add_key("jump", KEY_W)
	_add_key("jump", KEY_UP)
	_add_pad_button("jump", JOY_BUTTON_A)
	_add_key("attack", KEY_J)
	_add_key("attack", KEY_X)
	_add_pad_button("attack", JOY_BUTTON_X)
	_add_key("dash", KEY_K)
	_add_key("dash", KEY_SHIFT)
	_add_pad_button("dash", JOY_BUTTON_B)
	_add_key("drop", KEY_S)
	_add_key("drop", KEY_DOWN)
	_add_pad_button("drop", JOY_BUTTON_DPAD_DOWN)
	_add_pad_axis("drop", JOY_AXIS_LEFT_Y, 1.0)
	_add_key("pause_game", KEY_ESCAPE)
	_add_pad_button("pause_game", JOY_BUTTON_START)
	_add_key("save_game", KEY_F5)
	_add_key("toggle_music", KEY_M)
	_add_key("page_prev", KEY_Q)
	_add_key("page_next", KEY_E)
	_add_pad_button("page_prev", JOY_BUTTON_LEFT_SHOULDER)
	_add_pad_button("page_next", JOY_BUTTON_RIGHT_SHOULDER)
	_add_key("ui_up", KEY_UP)
	_add_key("ui_up", KEY_W)
	_add_key("ui_down", KEY_DOWN)
	_add_key("ui_down", KEY_S)
	_add_key("ui_left", KEY_LEFT)
	_add_key("ui_left", KEY_A)
	_add_key("ui_right", KEY_RIGHT)
	_add_key("ui_right", KEY_D)
	_add_pad_button("ui_up", JOY_BUTTON_DPAD_UP)
	_add_pad_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_pad_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_pad_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_pad_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_pad_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_add_pad_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_pad_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_pad_button("ui_accept", JOY_BUTTON_A)
	_add_pad_button("ui_cancel", JOY_BUTTON_B)

# ─────────────────────────────── Drawing helpers ───────────────────────────────
func _tex(rows: Array, pal: Dictionary) -> ImageTexture:
	var h := rows.size()
	var w: int = String(rows[0]).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return ImageTexture.create_from_image(img)

func _sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(PIXEL, PIXEL)
	return s

func _make_textures() -> void:
	tex_walker = _tex(WALKER_ROWS, {
		"o": OUT, "r": Color("#f16d75"), "R": Color("#9c3341"), "w": Color.WHITE, "k": OUT
	})
	tex_flyer = _tex(FLYER_ROWS, {"o": OUT, "p": Color("#a78bfa"), "w": Color.WHITE, "k": OUT})
	tex_crystal = _tex(CRYSTAL_ROWS, {"o": Color("#1d6f86"), "c": Color("#7ef9ff"), "C": Color("#e6ffff")})
	tex_heart = _tex(HEART_ROWS, {"o": OUT, "r": Color("#ff5d6c"), "w": Color("#ffd1d6")})
	tex_heart_empty = _tex(HEART_ROWS, {"o": OUT, "r": Color("#39415a"), "w": Color("#4a5370")})

func _rect_poly(top_left: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		top_left, top_left + Vector2(size.x, 0.0), top_left + size, top_left + Vector2(0.0, size.y)
	])
	p.color = color
	return p

func _circle_poly(radius: float, color: Color, segs := 14) -> Polygon2D:
	var pts := PackedVector2Array()
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	return p

func _part(parent: Node2D, joint_pos: Vector2, rect: Rect2, fill: Color, outline := true) -> Node2D:
	var j := Node2D.new()
	j.position = joint_pos
	if outline:
		j.add_child(_rect_poly(rect.position - Vector2.ONE, rect.size + Vector2(2.0, 2.0), OUT))
	j.add_child(_rect_poly(rect.position, rect.size, fill))
	parent.add_child(j)
	return j

# ─────────────────────────────── Themes ───────────────────────────────
func _theme_for(n: int) -> Dictionary:
	var t: Array = THEMES[posmod(floori(float(n - 1) / 10.0), THEMES.size())]
	return {
		"name": String(t[0]),
		"sky_top": Color(String(t[1])), "sky_bottom": Color(String(t[2])),
		"ground": Color(String(t[3])), "ground_dark": Color(String(t[4])),
		"grass": Color(String(t[5])), "grass_dark": Color(String(t[6])),
		"plat": Color(String(t[7])), "plat_top": Color(String(t[8])),
		"ridge1": Color(String(t[9])), "ridge2": Color(String(t[10])), "ridge3": Color(String(t[11]))
	}

# ─────────────────────────────── Level generator ───────────────────────────────
func _is_blocked(lv: Dictionary, x: float, pad: float) -> bool:
	for b in lv["blocked"]:
		var v: Vector2 = b
		if x > v.x - pad and x < v.y + pad:
			return true
	return false

func _crystal_row(lv: Dictionary, x0: float, count: int, base_y := 350.0, arc := 26.0) -> void:
	for i in count:
		var k := float(i) / float(maxi(1, count - 1))
		lv["crystals"].append(Vector2(x0 + float(i) * 36.0, base_y - arc * sin(k * PI)))

func _generate_level(n: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = n * 7919 + 104729
	var d := clampf(float(n - 1) / 499.0, 0.0, 1.0)
	var boss := n % 10 == 0
	var target := 2200.0 + 3400.0 * minf(1.0, d * 1.6) + r.randf_range(0.0, 400.0)
	if boss:
		target *= 0.6
	var lv := {
		"n": n, "boss": boss, "grounds": [], "floats": [], "spikes": [], "walkers": [],
		"flyers": [], "crystals": [], "hearts": [], "movers": [], "checkpoints": [],
		"blocked": [], "exit_x": 0.0, "end": 0.0, "boss_pos": Vector2.ZERO,
		"last_cp": 0.0, "next_heart": 1000.0 + r.randf_range(0.0, 300.0)
	}
	var x := -100.0
	var kind := "first"
	while true:
		var a := x
		var b := a + 800.0
		if kind != "first":
			b = a + r.randf_range(380.0, 720.0 - 200.0 * d)
			if b >= target:
				kind = "final"
				b = a + (1000.0 if boss else 760.0)
		lv["grounds"].append([a, b])
		_gen_segment(lv, r, d, a, b, kind, boss)
		if kind == "final":
			lv["end"] = b
			lv["exit_x"] = b - 90.0
			break
		var gap := 0.0
		if kind != "first" and r.randf() < 0.06 + 0.16 * d:
			gap = 210.0
			lv["movers"].append([b, gap])
		else:
			gap = r.randf_range(85.0, 105.0 + 30.0 * d)
		var count := 4 if gap > 200.0 else 3
		for i in count:
			var k := float(i + 1) / float(count + 1)
			lv["crystals"].append(Vector2(b + gap * k, 350.0 - 55.0 * sin(k * PI)))
		x = b + gap
		kind = "mid"
	return lv

func _gen_segment(lv: Dictionary, r: RandomNumberGenerator, d: float, a: float, b: float, kind: String, boss: bool) -> void:
	var mid := (a + b) * 0.5
	var lo := a + 110.0
	var hi := b - 110.0
	if kind == "first":
		lo = 520.0
	if kind == "final":
		hi = b - 220.0
	var blocked: Array = lv["blocked"]
	if kind == "mid" and mid - float(lv["last_cp"]) > 1500.0 and b - a >= 420.0:
		lv["checkpoints"].append(mid)
		lv["last_cp"] = mid
		blocked.append(Vector2(mid - 70.0, mid + 70.0))
	if kind == "final" and boss:
		lv["checkpoints"].append(a + 90.0)
		blocked.append(Vector2(a + 20.0, a + 160.0))
		lv["boss_pos"] = Vector2(mid, 0.0)
		_crystal_row(lv, a + 240.0, 5)
		return
	if hi - lo < 150.0:
		_crystal_row(lv, lo, 3)
		return
	if kind != "final" and r.randf() < 0.35 + 0.4 * d:
		var groups := r.randi_range(1, 1 + int(2.0 * d))
		for gi in groups:
			var c := r.randi_range(3, 3 + int(3.0 * d))
			var half := float(c) * 8.0
			var cx := r.randf_range(lo + half, maxf(lo + half + 1.0, hi - half))
			if _is_blocked(lv, cx, half + 20.0):
				continue
			lv["spikes"].append([cx, c])
			blocked.append(Vector2(cx - half - 40.0, cx + half + 40.0))
	var nw := r.randi_range(0, 1 + int(1.0 + 2.0 * d))
	if kind == "final":
		nw = r.randi_range(0, 2)
	if b - a > 450.0 and nw == 0 and r.randf() < 0.5:
		nw = 1
	for wi in nw:
		for tries in 4:
			var wx := r.randf_range(lo, hi)
			if not _is_blocked(lv, wx, 50.0):
				lv["walkers"].append(wx)
				blocked.append(Vector2(wx - 50.0, wx + 50.0))
				break
	if r.randf() < 0.55 and hi - lo > 330.0:
		var cxf := r.randf_range(lo + 40.0, hi - 290.0)
		lv["floats"].append([cxf, 310.0, 140.0])
		lv["floats"].append([cxf + 170.0, 250.0, 120.0])
		lv["crystals"].append(Vector2(cxf, 282.0))
		lv["crystals"].append(Vector2(cxf + 170.0, 222.0))
		if hi - (cxf + 330.0) > 40.0 and r.randf() < 0.5:
			lv["floats"].append([cxf + 330.0, 310.0, 140.0])
			lv["crystals"].append(Vector2(cxf + 330.0, 282.0))
		if r.randf() < 0.2 + 0.5 * d:
			lv["flyers"].append([cxf + 90.0, 190.0])
	if r.randf() < 0.15 + 0.5 * d:
		lv["flyers"].append([r.randf_range(a + 80.0, b - 80.0), r.randf_range(190.0, 245.0)])
	var cn := r.randi_range(3, 6)
	_crystal_row(lv, r.randf_range(lo, maxf(lo + 1.0, hi - float(cn) * 36.0)), cn)
	if kind != "first" and mid > float(lv["next_heart"]):
		lv["hearts"].append(Vector2(mid + 40.0, 345.0))
		lv["next_heart"] = mid + 1100.0

# ─────────────────────────────── Level building ───────────────────────────────
func _build_level(n: int) -> void:
	if level_root != null:
		level_root.queue_free()
	for tw in platform_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	platform_tweens.clear()
	checkpoint_flags.clear()
	spike_rects.clear()
	enemies.clear()
	items.clear()
	boss_ref = null
	boss_alive = false
	level_data = _generate_level(n)
	theme = _theme_for(n)
	ground_segs = level_data["grounds"]
	exit_x = float(level_data["exit_x"])
	world_end = float(level_data["end"])
	level_root = Node2D.new()
	level_root.name = "Level%d" % n
	world.add_child(level_root)
	world.move_child(level_root, 0)
	for seg in ground_segs:
		_add_ground(seg[0], seg[1])
	for p in level_data["floats"]:
		_add_floating(p[0], p[1], p[2])
	for m in level_data["movers"]:
		_add_moving_platform(m[0], m[1])
	for s in level_data["spikes"]:
		_add_spikes(s[0], int(s[1]))
	for x in level_data["checkpoints"]:
		_add_checkpoint(x)
	_add_exit(bool(level_data["boss"]))
	if n == 1:
		_add_hint("A / D  MOVE        SPACE  JUMP  (HOLD = HIGHER)", Vector2(60, 290))
		_add_hint("J  SWORD  (TAP 3x FOR A COMBO)  -  STOMP ENEMIES FROM ABOVE", Vector2(260, 285))
		_add_hint("K  DASH  (INVULNERABLE WHILE DASHING)", Vector2(560, 300))
		_add_hint("S / DOWN  DROP THROUGH THIN PLATFORMS", Vector2(900, 330))
	dynamic = Node2D.new()
	level_root.add_child(dynamic)
	_spawn_dynamic()
	camera.limit_right = int(world_end)
	if backdrop != null:
		backdrop.apply_theme(theme["sky_top"], theme["sky_bottom"], theme["ridge1"], theme["ridge2"], theme["ridge3"])
	shards_total = level_data["crystals"].size()
	_refresh_checkpoints()

func _add_hint(text: String, pos: Vector2) -> void:
	var l := _label(text, 13, Color("#c5d1e6"))
	l.position = pos
	l.modulate.a = 0.75
	level_root.add_child(l)

func _add_ground(x0: float, x1: float) -> void:
	var w := x1 - x0
	var h := 220.0
	var body := StaticBody2D.new()
	body.position = Vector2(x0 + w * 0.5, GROUND_TOP + h * 0.5)
	body.collision_layer = L_SOLID
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	cs.shape = rect
	body.add_child(cs)
	var half := Vector2(w, h) * 0.5
	body.add_child(_rect_poly(-half, Vector2(w, h), theme["ground"]))
	var r := RandomNumberGenerator.new()
	r.seed = int(x0) + 7
	for i in int(w / 36.0):
		var px := -half.x + float(i) * 36.0 + r.randf_range(0.0, 20.0)
		var py := -half.y + 26.0 + r.randf_range(0.0, 120.0)
		body.add_child(_rect_poly(Vector2(px, py), Vector2(r.randf_range(10.0, 22.0), 6.0), theme["ground_dark"]))
	body.add_child(_rect_poly(-half, Vector2(w, 8.0), theme["grass"]))
	body.add_child(_rect_poly(-half + Vector2(0.0, 8.0), Vector2(w, 3.0), theme["grass_dark"]))
	level_root.add_child(body)

func _add_floating(cx: float, top: float, w: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(cx, top + 8.0)
	body.collision_layer = L_ONEWAY
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 16.0)
	cs.shape = rect
	cs.one_way_collision = true
	cs.one_way_collision_margin = 6.0
	body.add_child(cs)
	body.add_child(_rect_poly(Vector2(-w * 0.5, -8.0), Vector2(w, 16.0), theme["plat"]))
	body.add_child(_rect_poly(Vector2(-w * 0.5, 4.0), Vector2(w, 4.0), Color(0, 0, 0, 0.25)))
	body.add_child(_rect_poly(Vector2(-w * 0.5, -8.0), Vector2(w, 4.0), theme["plat_top"]))
	level_root.add_child(body)

func _add_moving_platform(gap_start: float, gap: float) -> void:
	var plat := AnimatableBody2D.new()
	plat.position = Vector2(gap_start + 50.0, GROUND_TOP + 11.0)
	plat.collision_layer = L_SOLID
	plat.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90.0, 16.0)
	cs.shape = rect
	plat.add_child(cs)
	plat.add_child(_rect_poly(Vector2(-45.0, -8.0), Vector2(90.0, 16.0), Color("#5b4bc4")))
	plat.add_child(_rect_poly(Vector2(-45.0, -8.0), Vector2(90.0, 4.0), Color("#7ef9ff")))
	plat.add_child(_rect_poly(Vector2(-30.0, 0.0), Vector2(60.0, 3.0), Color("#a78bfa")))
	level_root.add_child(plat)
	var tw := create_tween().set_loops()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(plat, "position:x", gap_start + gap - 50.0, 2.4)
	tw.tween_property(plat, "position:x", gap_start + 50.0, 2.4)
	platform_tweens.append(tw)

func _add_spikes(cx: float, count: int) -> void:
	var node := Node2D.new()
	var half := float(count) * 8.0
	for i in count:
		var x0 := cx - half + float(i) * 16.0
		var tri := Polygon2D.new()
		tri.polygon = PackedVector2Array([
			Vector2(x0, GROUND_TOP), Vector2(x0 + 8.0, GROUND_TOP - 17.0), Vector2(x0 + 16.0, GROUND_TOP)
		])
		tri.color = Color("#c9d3e6")
		node.add_child(tri)
		var tip := Polygon2D.new()
		tip.polygon = PackedVector2Array([
			Vector2(x0 + 5.0, GROUND_TOP - 10.0), Vector2(x0 + 8.0, GROUND_TOP - 17.0), Vector2(x0 + 11.0, GROUND_TOP - 10.0)
		])
		tip.color = Color("#ff7b86")
		node.add_child(tip)
	level_root.add_child(node)
	spike_rects.append(Rect2(cx - half + 2.0, GROUND_TOP - 12.0, half * 2.0 - 4.0, 12.0))

func _add_checkpoint(x: float) -> void:
	var node := Node2D.new()
	node.position = Vector2(x, GROUND_TOP)
	node.add_child(_rect_poly(Vector2(-2.0, -64.0), Vector2(4.0, 64.0), Color("#8d9ab8")))
	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([Vector2(2.0, -64.0), Vector2(28.0, -54.0), Vector2(2.0, -44.0)])
	flag.color = Color("#6b7a99")
	node.add_child(flag)
	checkpoint_flags.append(flag)
	level_root.add_child(node)

func _add_exit(locked: bool) -> void:
	exit_node = Node2D.new()
	exit_node.position = Vector2(exit_x, GROUND_TOP)
	exit_node.add_child(_rect_poly(Vector2(-28.0, -104.0), Vector2(56.0, 104.0), Color("#a78bfa")))
	exit_node.add_child(_rect_poly(Vector2(-20.0, -96.0), Vector2(40.0, 96.0), Color("#26314b")))
	exit_swirl = Polygon2D.new()
	exit_swirl.polygon = PackedVector2Array([
		Vector2(0.0, -26.0), Vector2(14.0, 0.0), Vector2(0.0, 26.0), Vector2(-14.0, 0.0)
	])
	exit_swirl.color = Color("#c4b5fd")
	exit_swirl.position = Vector2(0.0, -50.0)
	exit_node.add_child(exit_swirl)
	exit_node.modulate = Color(0.45, 0.45, 0.55) if locked else Color.WHITE
	level_root.add_child(exit_node)

func _segment_at(x: float) -> Vector2:
	for seg in ground_segs:
		if x >= seg[0] and x <= seg[1]:
			return Vector2(seg[0], seg[1])
	return Vector2(x - 100.0, x + 100.0)

# ─────────────────────────────── Dynamic entities ───────────────────────────────
func _spawn_dynamic() -> void:
	var n := int(level_data["n"])
	for x in level_data["walkers"]:
		_add_walker(x, n)
	for f in level_data["flyers"]:
		_add_flyer(Vector2(f[0], f[1]), n)
	for c in level_data["crystals"]:
		_add_item("crystal", c)
	for h in level_data["hearts"]:
		_add_item("heart", h)
	if bool(level_data["boss"]):
		var bp: Vector2 = level_data["boss_pos"]
		_add_boss(bp.x, n)

func _add_walker(x: float, n: int) -> void:
	var d := clampf(float(n - 1) / 499.0, 0.0, 1.0)
	var e := CharacterBody2D.new()
	e.position = Vector2(x, GROUND_TOP - 30.0)
	e.collision_layer = L_ENEMY
	e.collision_mask = L_SOLID
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24.0, 26.0)
	cs.shape = rect
	e.add_child(cs)
	e.add_child(_sprite(tex_walker))
	_style_enemy_for_level(e, n, "walker")
	var seg := _segment_at(x)
	e.set_meta("kind", "walker")
	e.set_meta("hp", 2 + int(n / 150))
	e.set_meta("speed", WALKER_SPEED * (1.0 + 0.6 * d))
	e.set_meta("dir", -1.0 if rng.randf() < 0.5 else 1.0)
	e.set_meta("min_x", maxf(seg.x + 24.0, x - 90.0))
	e.set_meta("max_x", minf(seg.y - 24.0, x + 90.0))
	e.set_meta("stun", 0.0)
	e.set_meta("dead", false)
	e.set_meta("jcd", 0.0)
	e.set_meta("size", Vector2(24.0, 26.0))
	dynamic.add_child(e)
	enemies.append(e)

func _add_boss(x: float, n: int) -> void:
	var seg := _segment_at(x)
	var e := CharacterBody2D.new()
	e.position = Vector2(x, GROUND_TOP - 48.0)
	e.collision_layer = L_ENEMY
	e.collision_mask = L_SOLID
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56.0, 52.0)
	cs.shape = rect
	e.add_child(cs)
	var spr := _sprite(tex_walker)
	spr.scale = Vector2(PIXEL, PIXEL) * 2.6
	e.add_child(spr)
	_style_enemy_for_level(e, n, "boss")
	var hp := 8 + int(n / 20)
	e.set_meta("kind", "boss")
	e.set_meta("hp", hp)
	e.set_meta("max_hp", hp)
	e.set_meta("speed", 75.0)
	e.set_meta("dir", -1.0)
	e.set_meta("min_x", seg.x + 60.0)
	e.set_meta("max_x", seg.y - 60.0)
	e.set_meta("stun", 0.0)
	e.set_meta("dead", false)
	e.set_meta("jcd", 1.0)
	e.set_meta("size", Vector2(56.0, 52.0))
	dynamic.add_child(e)
	enemies.append(e)
	boss_ref = e
	boss_alive = true

func _add_flyer(pos: Vector2, n: int) -> void:
	var e := Node2D.new()
	e.position = pos
	e.add_child(_sprite(tex_flyer))
	_style_enemy_for_level(e, n, "flyer")
	e.set_meta("kind", "flyer")
	e.set_meta("hp", 1 + int(n / 250))
	e.set_meta("home", pos)
	e.set_meta("phase", rng.randf() * TAU)
	e.set_meta("stun", 0.0)
	e.set_meta("dead", false)
	e.set_meta("size", Vector2(26.0, 16.0))
	dynamic.add_child(e)
	enemies.append(e)

func _style_enemy_for_level(e: Node2D, n: int, kind: String) -> void:
	var rank := posmod(floori(float(n - 1) / 10.0), 5)
	var palette: Array[Color] = [
		Color("#ff4d6d"), Color("#a78bfa"), Color("#4df0d0"),
		Color("#ffc857"), Color("#e6f1ff")
	]
	var accent: Color = palette[rank]
	var sprite: Sprite2D = null
	for child in e.get_children():
		if child is Sprite2D:
			sprite = child as Sprite2D
			break
	if sprite != null:
		sprite.modulate = accent.lightened(0.15)
		if kind == "boss":
			sprite.modulate = Color("#ff365d") if rank % 2 == 0 else Color("#c084fc")

	# Outer soft glow
	var outer := _circle_poly(22.0 if kind != "boss" else 38.0, Color(accent.r, accent.g, accent.b, 0.12), 16)
	outer.position = Vector2(0.0, 4.0)
	e.add_child(outer)
	e.move_child(outer, 0)

	# Core glow
	var core := _circle_poly(11.0 if kind != "boss" else 20.0, Color(accent.r, accent.g, accent.b, 0.28), 12)
	core.position = Vector2(0.0, 2.0)
	e.add_child(core)
	e.move_child(core, 1)

	# Armor plate
	var armor := _rect_poly(Vector2(-14.0, -14.0), Vector2(28.0, 6.0), accent.darkened(0.25))
	armor.position = Vector2(0.0, -4.0)
	e.add_child(armor)

	# Side spikes / horns
	var left := _rect_poly(Vector2(-14.0, -22.0), Vector2(5.0, 12.0 + float(rank % 3) * 3.0), accent.lightened(0.25))
	left.rotation = -0.42 - float(rank) * 0.05
	left.position = Vector2(-8.0, -11.0)
	e.add_child(left)
	var right := _rect_poly(Vector2(-14.0, -22.0), Vector2(5.0, 12.0 + float((rank + 1) % 3) * 3.0), accent.lightened(0.25))
	right.rotation = 0.42 + float(rank) * 0.05
	right.position = Vector2(8.0, -11.0)
	e.add_child(right)

	if kind == "flyer":
		left.position = Vector2(-14.0, -1.0)
		right.position = Vector2(14.0, -1.0)
		left.rotation = -0.9
		right.rotation = 0.9
		# Wing membranes
		var wing_l := _rect_poly(Vector2(-18.0, -4.0), Vector2(14.0, 3.0), Color(accent.r, accent.g, accent.b, 0.45))
		wing_l.rotation = -0.35
		e.add_child(wing_l)
		var wing_r := _rect_poly(Vector2(4.0, -4.0), Vector2(14.0, 3.0), Color(accent.r, accent.g, accent.b, 0.45))
		wing_r.rotation = 0.35
		e.add_child(wing_r)

	if kind == "boss":
		var crown := _rect_poly(Vector2(-20.0, -34.0), Vector2(40.0, 8.0), Color("#ffe28a"))
		e.add_child(crown)
		var eye_glow := _rect_poly(Vector2(-16.0, -16.0), Vector2(32.0, 6.0), Color("#fff4f4"))
		e.add_child(eye_glow)
		# Extra shoulder plates
		var shoulder_l := _rect_poly(Vector2(-26.0, -18.0), Vector2(10.0, 14.0), accent.darkened(0.15))
		e.add_child(shoulder_l)
		var shoulder_r := _rect_poly(Vector2(16.0, -18.0), Vector2(10.0, 14.0), accent.darkened(0.15))
		e.add_child(shoulder_r)

func _add_item(kind: String, pos: Vector2) -> void:
	var n := Node2D.new()
	n.position = pos
	n.add_child(_circle_poly(14.0, Color(0.5, 0.95, 1.0, 0.14) if kind == "crystal" else Color(1.0, 0.4, 0.5, 0.16)))
	n.add_child(_sprite(tex_crystal if kind == "crystal" else tex_heart))
	dynamic.add_child(n)
	items.append({"kind": kind, "node": n, "base": pos, "phase": rng.randf() * TAU, "mag": false})

# ─────────────────────────────── Hero rig (heavily upgraded) ───────────────────────────────
func _make_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = L_PLAYER
	player.collision_mask = L_SOLID | L_ONEWAY
	player.floor_snap_length = 6.0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18.0, 34.0)
	cs.shape = rect
	player.add_child(cs)
	player_visual = Node2D.new()
	player.add_child(player_visual)

	# Soft outer aura
	var hero_aura := _circle_poly(22.0, Color(0.25, 0.95, 1.0, 0.12), 18)
	hero_aura.name = "RiftAura"
	hero_aura.position = Vector2(0.0, 2.0)
	player_visual.add_child(hero_aura)

	_build_hero_rig()
	world.add_child(player)

func _build_hero_rig() -> void:
	var skin := Color("#f5c9a8")
	var skin_shadow := Color("#d4a88a")
	var hair := Color("#3d2a1f")
	var hair_hi := Color("#5c4030")
	var tunic := Color("#3d6fe0")
	var tunic_d := Color("#2a4fad")
	var tunic_hi := Color("#5b8cff")
	var gold := Color("#f5d06a")
	var gold_d := Color("#c9a23d")
	var pants := Color("#243356")
	var pants_d := Color("#1a253f")
	var boot := Color("#6b3a22")
	var boot_hi := Color("#8a5234")
	var cyan := Color("#7ef9ff")
	var cyan_d := Color("#3ec8d4")

	var body := Node2D.new()
	player_visual.add_child(body)
	rig["body"] = body

	# === BACK LEG ===
	var thigh_b := _part(body, Vector2(-3.0, 7.0), Rect2(-3.0, 0.0, 6.0, 5.5), pants_d)
	var shin_b := _part(thigh_b, Vector2(0.0, 5.5), Rect2(-2.6, 0.0, 5.2, 4.0), pants_d)
	var boot_b := _part(shin_b, Vector2(0.0, 4.0), Rect2(-3.5, 0.0, 7.5, 3.0), boot)
	boot_b.add_child(_rect_poly(Vector2(-3.0, 0.5), Vector2(6.5, 1.2), boot_hi))
	rig["thigh_b"] = thigh_b
	rig["shin_b"] = shin_b

	# === TORSO ===
	var torso := Node2D.new()
	torso.position = Vector2(0.0, 7.0)
	body.add_child(torso)
	rig["torso"] = torso

	# Back arm
	var arm_b1 := _part(torso, Vector2(-2.0, -9.0), Rect2(-2.4, 0.0, 4.8, 5.0), tunic_d)
	var arm_b2 := _part(arm_b1, Vector2(0.0, 5.0), Rect2(-2.1, 0.0, 4.2, 4.5), gold_d)
	rig["arm_b1"] = arm_b1
	rig["arm_b2"] = arm_b2

	# Main tunic body
	_part(torso, Vector2.ZERO, Rect2(-6.5, -11.0, 13.0, 12.0), tunic)
	# Tunic highlight stripe
	torso.add_child(_rect_poly(Vector2(-5.5, -10.0), Vector2(3.0, 10.0), tunic_hi.darkened(0.1)))
	# Gold belt
	_part(torso, Vector2.ZERO, Rect2(-6.5, -2.5, 13.0, 3.0), gold)
	# Cyan chest crystal
	torso.add_child(_rect_poly(Vector2(-1.5, -8.5), Vector2(4.0, 4.0), cyan))
	torso.add_child(_rect_poly(Vector2(-0.5, -7.5), Vector2(2.0, 2.0), Color.WHITE))

	# === HEAD ===
	var head := Node2D.new()
	head.position = Vector2(0.0, -11.0)
	torso.add_child(head)
	rig["head"] = head

	# Hair back
	_part(head, Vector2.ZERO, Rect2(-9.0, -13.0, 6.0, 11.0), hair)
	# Face
	_part(head, Vector2.ZERO, Rect2(-7.0, -13.0, 14.0, 13.0), skin)
	# Hair top / bangs
	_part(head, Vector2.ZERO, Rect2(-8.0, -14.5, 16.0, 5.5), hair)
	head.add_child(_rect_poly(Vector2(1.5, -10.0), Vector2(6.0, 2.5), hair_hi))
	# Cyan visor strip
	head.add_child(_rect_poly(Vector2(-7.5, -8.5), Vector2(15.0, 2.2), cyan_d))
	head.add_child(_rect_poly(Vector2(-6.5, -8.0), Vector2(13.0, 1.2), cyan))

	# Eye
	var eye := Node2D.new()
	eye.position = Vector2(3.8, -4.5)
	eye.add_child(_rect_poly(Vector2(-2.5, -2.5), Vector2(5.0, 5.0), Color.WHITE))
	eye.add_child(_rect_poly(Vector2(-0.5, -2.0), Vector2(2.5, 4.0), OUT))
	eye.add_child(_rect_poly(Vector2(0.5, -1.0), Vector2(1.2, 1.5), Color("#7ef9ff")))
	head.add_child(eye)
	rig["eye"] = eye

	# === SCARF (longer, more segments) ===
	var parent: Node2D = torso
	var pos := Vector2(-4.0, -10.0)
	for i in 4:
		var col := cyan.darkened(0.08 * float(i))
		var seg := _part(parent, pos, Rect2(-7.0, -2.0, 7.0, 4.0), col)
		scarf_nodes.append(seg)
		parent = seg
		pos = Vector2(-6.5, 0.2)

	# === FRONT LEG ===
	var thigh_f := _part(body, Vector2(3.0, 7.0), Rect2(-3.0, 0.0, 6.0, 5.5), pants)
	var shin_f := _part(thigh_f, Vector2(0.0, 5.5), Rect2(-2.6, 0.0, 5.2, 4.0), pants)
	var boot_f := _part(shin_f, Vector2(0.0, 4.0), Rect2(-3.5, 0.0, 7.5, 3.0), boot)
	boot_f.add_child(_rect_poly(Vector2(-3.0, 0.5), Vector2(6.5, 1.2), boot_hi))
	rig["thigh_f"] = thigh_f
	rig["shin_f"] = shin_f

	# === FRONT ARM + SWORD ===
	var arm_f1 := _part(torso, Vector2(2.0, -9.0), Rect2(-2.4, 0.0, 4.8, 5.0), tunic)
	var arm_f2 := _part(arm_f1, Vector2(0.0, 5.0), Rect2(-2.1, 0.0, 4.2, 4.5), gold)
	# Hand
	arm_f2.add_child(_rect_poly(Vector2(-1.8, 3.5), Vector2(3.6, 2.8), skin))
	rig["arm_f1"] = arm_f1
	rig["arm_f2"] = arm_f2

	var sword := Node2D.new()
	sword.position = Vector2(0.0, 5.0)
	arm_f2.add_child(sword)
	rig["sword"] = sword

	# Energy glow
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(0, -7), Vector2(32, -7), Vector2(38, 0), Vector2(32, 7), Vector2(0, 7)])
	glow.color = Color(0.4, 0.95, 1.0, 0.18)
	sword.add_child(glow)
	rig["glow"] = glow

	# Blade outline
	var blade_o := Polygon2D.new()
	blade_o.polygon = PackedVector2Array([Vector2(1, -3.5), Vector2(26, -3.5), Vector2(33, 0), Vector2(26, 3.5), Vector2(1, 3.5)])
	blade_o.color = OUT
	sword.add_child(blade_o)

	# Main blade
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([Vector2(2, -2.5), Vector2(25, -2.5), Vector2(31, 0), Vector2(25, 2.5), Vector2(2, 2.5)])
	blade.color = Color("#e8f4ff")
	sword.add_child(blade)

	# Edge highlight
	sword.add_child(_rect_poly(Vector2(3.0, -1.8), Vector2(22.0, 1.2), Color.WHITE))

	# Guard
	sword.add_child(_rect_poly(Vector2(-3.0, -8.0), Vector2(6.0, 16.0), OUT))
	sword.add_child(_rect_poly(Vector2(-2.0, -7.0), Vector2(4.0, 14.0), gold))

	# Handle
	sword.add_child(_rect_poly(Vector2(-9.0, -2.5), Vector2(8.0, 5.0), OUT))
	sword.add_child(_rect_poly(Vector2(-8.0, -1.5), Vector2(7.0, 3.0), boot))

	# Pommel
	var pommel := _circle_poly(2.8, gold, 8)
	pommel.position = Vector2(-10.0, 0.0)
	sword.add_child(pommel)

func _animate_player(delta: float) -> void:
	var on_floor := player.is_on_floor()
	var vx := player.velocity.x
	var vy := player.velocity.y
	var target_sq := Vector2.ONE
	if not on_floor:
		var k := clampf(absf(vy) / 700.0, 0.0, 1.0)
		target_sq = Vector2(1.0 - 0.13 * k, 1.0 + 0.18 * k)
	squash = squash.lerp(target_sq, minf(1.0, delta * 14.0))
	var t := anim_time
	var tg := {
		"lean": 0.02 + sin(t * 2.0) * 0.02, "head": 0.0,
		"thigh_f": 0.08, "shin_f": 0.0, "thigh_b": -0.1, "shin_b": 0.05,
		"arm_f1": -0.35, "arm_f2": -0.6, "arm_b1": 0.15, "arm_b2": 0.25,
		"blade": -0.9, "bob": sin(t * 2.0) * 0.7
	}
	var rate := 16.0
	if not on_floor:
		if vy < 0.0:
			tg["thigh_f"] = -0.75; tg["shin_f"] = 1.05; tg["thigh_b"] = 0.55; tg["shin_b"] = 0.95
			tg["lean"] = 0.1; tg["arm_f1"] = -2.4; tg["arm_f2"] = -0.25; tg["arm_b1"] = -1.7; tg["arm_b2"] = 0.25
			tg["blade"] = -1.35
		else:
			tg["thigh_f"] = -0.3; tg["shin_f"] = 0.45; tg["thigh_b"] = 0.4; tg["shin_b"] = 0.55
			tg["lean"] = 0.0; tg["arm_f1"] = -1.25; tg["arm_f2"] = -0.35; tg["arm_b1"] = 1.25; tg["arm_b2"] = 0.25
			tg["blade"] = -0.45
	elif absf(vx) > 20.0:
		run_anim += delta * (9.5 + absf(vx) * 0.034)
		var p := run_anim
		tg["thigh_f"] = sin(p) * 0.9
		tg["thigh_b"] = sin(p + PI) * 0.9
		tg["shin_f"] = (0.5 + 0.5 * sin(p - 1.4)) * 1.15
		tg["shin_b"] = (0.5 + 0.5 * sin(p + PI - 1.4)) * 1.15
		tg["lean"] = 0.2
		tg["bob"] = -absf(sin(p)) * 1.8
		tg["arm_f1"] = -0.55 + sin(p) * 0.18
		tg["arm_f2"] = -0.85
		tg["blade"] = -0.75 + sin(p * 2.0) * 0.06
		tg["arm_b1"] = -sin(p) * 0.85 + 0.1
		tg["arm_b2"] = 0.45
		rate = 24.0
	else:
		run_anim = 0.0
	if hurt_stun > 0.0:
		tg["lean"] = -0.4; tg["arm_f1"] = -1.1; tg["arm_f2"] = -0.25; tg["arm_b1"] = 1.1
		tg["thigh_f"] = -0.35; tg["thigh_b"] = 0.35; tg["blade"] = -0.35
	if dash_time > 0.0:
		tg["lean"] = 0.6; tg["thigh_f"] = 0.75; tg["shin_f"] = 0.45; tg["thigh_b"] = 1.15; tg["shin_b"] = 0.25
		tg["arm_f1"] = -1.55; tg["arm_f2"] = 0.05; tg["arm_b1"] = 1.25; tg["arm_b2"] = 0.15; tg["blade"] = -0.08
		rate = 42.0
	if attack_t >= 0.0:
		var st: Array = ATTACK_STYLES[attack_style]
		var s0: float = st[0]
		var s1: float = st[1]
		var p := clampf(attack_t / float(st[5]), 0.0, 1.0)
		var b := s1
		if p < 0.2:
			b = s0 - (s1 - s0) * 0.06 * (p / 0.2)
		elif p < 0.62:
			var u := (p - 0.2) / 0.42
			u = 1.0 - pow(1.0 - u, 3.0)
			b = lerpf(s0, s1, u)
		tg["arm_f1"] = b - PI * 0.5
		tg["arm_f2"] = -0.15
		tg["blade"] = b
		tg["lean"] = float(tg["lean"]) + (-0.15 if p < 0.2 else 0.35)
		rate = 58.0

	var k_rate := minf(1.0, delta * rate)
	for key in tg:
		pose[key] = lerpf(float(pose.get(key, tg[key])), float(tg[key]), k_rate)

	var torso: Node2D = rig["torso"]
	torso.rotation = pose["lean"]
	var head_n: Node2D = rig["head"]
	head_n.rotation = float(pose["head"]) - float(pose["lean"]) * 0.4
	(rig["thigh_f"] as Node2D).rotation = pose["thigh_f"]
	(rig["shin_f"] as Node2D).rotation = pose["shin_f"]
	(rig["thigh_b"] as Node2D).rotation = pose["thigh_b"]
	(rig["shin_b"] as Node2D).rotation = pose["shin_b"]
	(rig["arm_f1"] as Node2D).rotation = pose["arm_f1"]
	(rig["arm_f2"] as Node2D).rotation = pose["arm_f2"]
	(rig["arm_b1"] as Node2D).rotation = pose["arm_b1"]
	(rig["arm_b2"] as Node2D).rotation = pose["arm_b2"]
	var total := float(pose["lean"]) + float(pose["arm_f1"]) + float(pose["arm_f2"])
	(rig["sword"] as Node2D).rotation = float(pose["blade"]) - total
	(rig["body"] as Node2D).position.y = pose["bob"]

	var glow: Polygon2D = rig["glow"]
	glow.color.a = 0.55 if attack_t >= 0.0 else 0.12 + 0.06 * sin(t * 4.5)

	# Scarf physics
	var spd := clampf(absf(vx) / 250.0, 0.0, 1.0)
	if dash_time > 0.0:
		spd = 1.0
	for i in scarf_nodes.size():
		var ang := -0.6 * (1.0 - spd) - 0.08 * spd
		ang += sin(t * 10.0 + float(i) * 0.85) * 0.22 * (0.45 + spd)
		ang += clampf(vy / 900.0, -0.45, 0.45)
		scarf_nodes[i].rotation = ang

	# Eye blink
	(rig["eye"] as Node2D).scale.y = 0.12 if fmod(t, 3.6) > 3.45 else 1.0

	# Whole-model squash + flip
	player_visual.scale = Vector2(squash.x * facing, squash.y)
	player_visual.position = Vector2(0.0, 17.0 * (1.0 - squash.y))

	if state == State.DEAD:
		return
	if dash_time > 0.0:
		player_visual.visible = true
		player_visual.modulate = Color(0.55, 1.5, 1.6, 0.92)
	elif hurt_stun > 0.0:
		player_visual.visible = true
		player_visual.modulate = Color(1.7, 0.65, 0.65)
	else:
		player_visual.modulate = Color.WHITE
		player_visual.visible = invulnerable <= 0.0 or fmod(anim_time * 16.0, 2.0) < 1.0

func _ghost() -> void:
	var g := player_visual.duplicate() as Node2D
	world.add_child(g)
	g.global_position = player_visual.global_position
	g.modulate = Color(0.45, 1.1, 1.2, 0.6)
	var tw := create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.28)
	tw.tween_callback(g.queue_free)

# ─────────────────────────────── Camera / backdrop ───────────────────────────────
func _make_camera() -> void:
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_right = 3000
	camera.limit_top = 0
	camera.limit_bottom = VIEW_SIZE.y
	camera.position = Vector2(0.0, -30.0)
	player.add_child(camera)
	camera.make_current()

func _make_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var bd := Backdrop.new()
	bd.cam = camera
	layer.add_child(bd)
	backdrop = bd

func _checkpoint_pos() -> Vector2:
	var cps: Array = level_data.get("checkpoints", [])
	var x := 100.0
	if checkpoint_idx >= 0 and checkpoint_idx < cps.size():
		x = float(cps[checkpoint_idx])
	return Vector2(x, GROUND_TOP - 40.0)

func _place_player_at_checkpoint() -> void:
	player.global_position = _checkpoint_pos()
	player.velocity = Vector2.ZERO
	dash_time = 0.0
	hurt_stun = 0.0
	drop_time = 0.0
	attack_t = -1.0
	player.set_collision_mask_value(4, true)
	player_visual.visible = true
	camera.reset_smoothing()

func _refresh_checkpoints() -> void:
	for i in checkpoint_flags.size():
		checkpoint_flags[i].color = Color("#ffe28a") if i <= checkpoint_idx else Color("#6b7a99")

# ─────────────────────────────── HUD / menus (unchanged logic) ───────────────────────────────
func _label(text_value: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#0b1020"))
	l.add_theme_constant_override("outline_size", 4)
	return l

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	return sb

func _style_button(b: Button, min_size := Vector2(300, 34)) -> void:
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", _box(Color("#18233a"), Color("#3b4d73")))
	b.add_theme_stylebox_override("hover", _box(Color("#22335a"), Color("#7ef9ff")))
	b.add_theme_stylebox_override("pressed", _box(Color("#7ef9ff"), Color.WHITE))
	b.add_theme_stylebox_override("focus", _box(Color("#2b4278"), Color("#ffe28a")))
	b.add_theme_stylebox_override("disabled", _box(Color("#10151f"), Color("#232b3b")))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("#4a5370"))
	b.add_theme_color_override("font_pressed_color", Color("#111a2b"))

func _make_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ui_root)

	var tl := VBoxContainer.new()
	tl.position = Vector2(18, 14)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(tl)
	health_label = _label("VITALS  5 / 5", 15, Color("#ff667d"))
	tl.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(230.0, 19.0)
	health_bar.show_percentage = false
	health_bar.min_value = 0.0
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.add_theme_stylebox_override("background", _box(Color("#160f20"), Color("#5b344d")))
	health_bar.add_theme_stylebox_override("fill", _box(Color("#ff365d"), Color("#ff9aab")))
	tl.add_child(health_bar)
	score_label = _label("SCORE 0000", 18, Color("#7ef9ff"))
	tl.add_child(score_label)
	dash_label = _label("DASH READY", 14, Color("#c5d1e6"))
	tl.add_child(dash_label)

	level_label = _label("LEVEL 1", 16, Color("#ffe28a"))
	level_label.anchor_left = 0.5
	level_label.anchor_right = 0.5
	level_label.offset_left = -260.0
	level_label.offset_right = 260.0
	level_label.offset_top = 30.0
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_root.add_child(level_label)

	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.max_value = 100.0
	progress.anchor_left = 0.5
	progress.anchor_right = 0.5
	progress.offset_left = -150.0
	progress.offset_right = 150.0
	progress.offset_top = 16.0
	progress.offset_bottom = 24.0
	progress.add_theme_stylebox_override("background", _box(Color("#18233a"), Color("#3b4d73")))
	progress.add_theme_stylebox_override("fill", _box(Color("#7ef9ff"), Color("#7ef9ff")))
	ui_root.add_child(progress)

	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.anchor_left = 0.5
	boss_bar.anchor_right = 0.5
	boss_bar.offset_left = -200.0
	boss_bar.offset_right = 200.0
	boss_bar.offset_top = 80.0
	boss_bar.offset_bottom = 92.0
	boss_bar.add_theme_stylebox_override("background", _box(Color("#2a1018"), Color("#7a3340")))
	boss_bar.add_theme_stylebox_override("fill", _box(Color("#ff5d6c"), Color("#ff5d6c")))
	boss_bar.visible = false
	ui_root.add_child(boss_bar)

	status_label = _label("", 18, Color("#ffe28a"))
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.offset_left = -260.0
	status_label.offset_right = 260.0
	status_label.offset_top = 52.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_root.add_child(status_label)

	time_label = _label("TIME 00:00.0", 18, Color.WHITE)
	time_label.anchor_left = 1.0
	time_label.anchor_right = 1.0
	time_label.offset_left = -240.0
	time_label.offset_right = -18.0
	time_label.offset_top = 14.0
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui_root.add_child(time_label)
	best_label = _label("BEST --:--.-", 14, Color("#c5d1e6"))
	best_label.anchor_left = 1.0
	best_label.anchor_right = 1.0
	best_label.offset_left = -240.0
	best_label.offset_right = -18.0
	best_label.offset_top = 40.0
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui_root.add_child(best_label)

	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var ps := _box(Color(0.055, 0.086, 0.153, 0.94), Color("#7ef9ff"))
	ps.set_border_width_all(3)
	ps.set_content_margin_all(22)
	menu_panel.add_theme_stylebox_override("panel", ps)
	ui_root.add_child(menu_panel)
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 8)
	menu_panel.add_child(holder)
	menu_title = _label("PIXELBOUND", 38, Color("#7ef9ff"))
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(menu_title)
	menu_hint = _label("RIFT RUNNER", 16, Color.WHITE)
	menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(menu_hint)

	screen_main = VBoxContainer.new()
	screen_main.add_theme_constant_override("separation", 8)
	holder.add_child(screen_main)
	var help := _label("A/D move   SPACE jump   J sword   K dash   S drop\nPad: stick move   A jump   X sword   B dash   START pause\nMenus: D-pad / stick + A select + B back", 13, Color("#c5d1e6"))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_main.add_child(help)
	resume_btn = Button.new()
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn = Button.new()
	restart_btn.pressed.connect(_on_restart_pressed)
	levels_btn = Button.new()
	levels_btn.text = "LEVEL SELECT"
	levels_btn.pressed.connect(_show_levels)
	var upgrades_btn := Button.new()
	upgrades_btn.text = "UPGRADES"
	upgrades_btn.pressed.connect(_show_upgrades)
	music_btn = Button.new()
	music_btn.pressed.connect(_toggle_music)
	quit_btn = Button.new()
	quit_btn.text = "QUIT"
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	quit_btn.visible = not OS.has_feature("web")
	for b in [resume_btn, restart_btn, levels_btn, upgrades_btn, music_btn, quit_btn]:
		_style_button(b)
		screen_main.add_child(b)

	screen_levels = VBoxContainer.new()
	screen_levels.add_theme_constant_override("separation", 8)
	screen_levels.visible = false
	holder.add_child(screen_levels)
	page_label = _label("PAGE 1 / 20", 15, Color("#c5d1e6"))
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_levels.add_child(page_label)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	screen_levels.add_child(grid)
	for i in PAGE_SIZE:
		var lb := Button.new()
		_style_button(lb, Vector2(86, 34))
		lb.pressed.connect(_on_level_slot_pressed.bind(i))
		grid.add_child(lb)
		level_buttons.append(lb)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	screen_levels.add_child(nav)
	var prev_btn := Button.new()
	prev_btn.text = "< PREV"
	prev_btn.pressed.connect(_change_page.bind(-1))
	var next_btn := Button.new()
	next_btn.text = "NEXT >"
	next_btn.pressed.connect(_change_page.bind(1))
	unlock_btn = Button.new()
	unlock_btn.pressed.connect(_toggle_unlock_all)
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.pressed.connect(_back_to_main)
	for b in [prev_btn, next_btn, unlock_btn, back_btn]:
		_style_button(b, Vector2(100, 34))
		nav.add_child(b)
	unlock_btn.custom_minimum_size = Vector2(190, 34)
	var tip := _label("LB / RB or Q / E: change page      B: back", 12, Color("#8d9ab8"))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_levels.add_child(tip)

	screen_upgrades = VBoxContainer.new()
	screen_upgrades.add_theme_constant_override("separation", 8)
	screen_upgrades.visible = false
	holder.add_child(screen_upgrades)
	var upgrade_help := _label("Spend earned score on permanent upgrades.\nController: D-pad / stick, A buy, B back.", 13, Color("#c5d1e6"))
	upgrade_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_upgrades.add_child(upgrade_help)
	for id in ["health", "speed", "dash", "sword"]:
		var ub := Button.new()
		_style_button(ub, Vector2(330, 36))
		ub.pressed.connect(_buy_upgrade.bind(id))
		screen_upgrades.add_child(ub)
		upgrade_buttons.append(ub)
	var upgrade_back := Button.new()
	upgrade_back.text = "BACK"
	_style_button(upgrade_back)
	upgrade_back.pressed.connect(_back_to_main)
	screen_upgrades.add_child(upgrade_back)
	mouse_lock_btn = Button.new()
	mouse_lock_btn.pressed.connect(_toggle_mouse_lock)
	_style_button(mouse_lock_btn)
	screen_main.add_child(mouse_lock_btn)
	_refresh_mouse_lock_button()

func _open_menu(title: String, subtitle: String, resume_text: String, mode: String, restart_text := "") -> void:
	menu_mode = mode
	menu_title.text = title
	menu_hint.text = subtitle
	resume_btn.text = resume_text
	restart_btn.visible = restart_text != ""
	restart_btn.text = restart_text
	menu_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_screen("main")

func _open_start_menu() -> void:
	var txt := "PLAY"
	if unlocked > 1 or not level_best.is_empty():
		txt = "CONTINUE  -  LEVEL %d" % current_level
	_open_menu("PIXELBOUND", "R I F T   R U N N E R     500 LEVELS", txt, "start")

func _show_screen(which: String) -> void:
	screen_main.visible = which == "main"
	screen_levels.visible = which == "levels"
	screen_upgrades.visible = which == "upgrades"
	if which == "main":
		resume_btn.call_deferred("grab_focus")
	elif which == "levels":
		_focus_level(mini(current_level, maxi(1, unlocked)))
	elif which == "upgrades":
		_refresh_upgrades()
		if upgrade_buttons.size() > 0:
			upgrade_buttons[0].call_deferred("grab_focus")

func _show_upgrades() -> void:
	menu_title.text = "UPGRADES"
	menu_hint.text = "PERMANENT RIFT ENHANCEMENTS"
	_show_screen("upgrades")

func _upgrade_cost(id: String) -> int:
	var lvl := int(upgrade_levels.get(id, 0))
	var base := {"health": 150, "speed": 120, "dash": 140, "sword": 160}
	return int(base[id]) * (lvl + 1)

func _refresh_upgrades() -> void:
	var names := ["health", "speed", "dash", "sword"]
	var labels := ["MAX HEALTH", "MOVE SPEED", "DASH COOLDOWN", "SWORD DAMAGE"]
	for i in names.size():
		var id: String = names[i]
		var lvl := int(upgrade_levels.get(id, 0))
		var cost := _upgrade_cost(id)
		var effect := " +1 max HP" if id == "health" else (" +8% speed" if id == "speed" else (" -8% cooldown" if id == "dash" else " +1 sword damage"))
		upgrade_buttons[i].text = "%s  Lv.%d  |  %d score%s" % [labels[i], lvl, cost, effect]
		upgrade_buttons[i].disabled = (id == "health" and max_health >= 10) or (id == "speed" and lvl >= 5) or (id == "dash" and lvl >= 5) or (id == "sword" and lvl >= 5) or total_score < cost
	menu_hint.text = "AVAILABLE SCORE: %d" % total_score

func _buy_upgrade(id: String) -> void:
	var lvl := int(upgrade_levels.get(id, 0))
	if (id == "health" and max_health >= 10) or (id != "health" and lvl >= 5):
		return
	var cost := _upgrade_cost(id)
	if total_score < cost:
		_toast("NOT ENOUGH SCORE")
		return
	total_score -= cost
	upgrade_levels[id] = lvl + 1
	if id == "health":
		max_health = mini(10, max_health + 1)
		health = mini(max_health, health + 1)
		_update_hud()
	_save_game(false)
	_refresh_upgrades()
	_update_hud()
	_sfx(740.0, 0.12, 0.12)

func _refresh_health_bar() -> void:
	if health_bar == null or health_label == null:
		return
	health_bar.max_value = max_health
	health_bar.value = clampi(health, 0, max_health)
	health_label.text = "VITALS  %d / %d" % [health, max_health]
	var ratio := float(health) / maxf(1.0, float(max_health))
	var fill := Color("#ff365d")
	if ratio > 0.6:
		fill = Color("#58f2a5")
	elif ratio > 0.3:
		fill = Color("#ffd166")
	health_bar.add_theme_stylebox_override("fill", _box(fill, fill.lightened(0.25)))

func _toggle_mouse_lock() -> void:
	mouse_lock_enabled = not mouse_lock_enabled
	_refresh_mouse_lock_button()
	_apply_mouse_mode()
	_save_game(false)

func _refresh_mouse_lock_button() -> void:
	if mouse_lock_btn != null:
		mouse_lock_btn.text = "MOUSE LOCK: ON" if mouse_lock_enabled else "MOUSE LOCK: OFF"

func _apply_mouse_mode() -> void:
	if state == State.PLAYING and mouse_lock_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _show_levels() -> void:
	menu_title.text = "LEVEL SELECT"
	menu_hint.text = "WORLD  -  " + String(_theme_for(clampi(level_page * PAGE_SIZE + 1, 1, TOTAL_LEVELS))["name"])
	_show_screen("levels")
	_focus_level(mini(current_level, maxi(1, unlocked)))

func _back_to_main() -> void:
	match menu_mode:
		"pause":
			_open_menu("PAUSED", _run_summary(), "RESUME", "pause", "RESTART LEVEL")
		"dead":
			_open_menu("RIFT RUN ENDED", _run_summary(), "RETRY FROM CHECKPOINT", "dead", "RESTART LEVEL")
		"won":
			_open_win_menu(false)
		_:
			_open_start_menu()

func _is_unlocked(n: int) -> bool:
	return unlock_all or n <= unlocked

func _refresh_level_page() -> void:
	var cleared := level_best.size()
	page_label.text = "PAGE %d / %d      CLEARED %d / %d" % [level_page + 1, PAGE_COUNT, cleared, TOTAL_LEVELS]
	for i in PAGE_SIZE:
		var n := level_page * PAGE_SIZE + i + 1
		var b := level_buttons[i]
		b.text = str(n)
		b.disabled = not _is_unlocked(n)
		var col := Color.WHITE
		if level_best.has(n):
			col = Color("#7ef9ff")
		if n % 10 == 0:
			col = Color("#ffcf5a")
		b.add_theme_color_override("font_color", col)
	unlock_btn.text = "UNLOCK ALL: ON" if unlock_all else "UNLOCK ALL: OFF"

func _change_page(dir: int) -> void:
	level_page = clampi(level_page + dir, 0, PAGE_COUNT - 1)
	menu_hint.text = "WORLD  -  " + String(_theme_for(level_page * PAGE_SIZE + 1)["name"])
	_refresh_level_page()
	_focus_level(level_page * PAGE_SIZE + 1)

func _focus_level(n: int) -> void:
	level_page = clampi(floori(float(n - 1) / float(PAGE_SIZE)), 0, PAGE_COUNT - 1)
	_refresh_level_page()
	var idx := (n - 1) % PAGE_SIZE
	if level_buttons[idx].disabled:
		for b in level_buttons:
			if not b.disabled:
				b.call_deferred("grab_focus")
				return
		unlock_btn.call_deferred("grab_focus")
		return
	level_buttons[idx].call_deferred("grab_focus")

func _on_level_slot_pressed(slot: int) -> void:
	var n := level_page * PAGE_SIZE + slot + 1
	if _is_unlocked(n):
		_start_level(n)

func _toggle_unlock_all() -> void:
	unlock_all = not unlock_all
	_refresh_level_page()
	_save_game(false)
	_sfx(520.0, 0.05, 0.1)

func _refresh_music_button() -> void:
	music_btn.text = "MUSIC: ON" if music_on else "MUSIC: OFF"

func _fmt_time(t: float) -> String:
	return "%02d:%04.1f" % [floori(t / 60.0), fmod(t, 60.0)]

func _run_summary() -> String:
	return "Level %d      Score %d      Time %s" % [current_level, score, _fmt_time(run_time)]

func _update_hud() -> void:
	_refresh_health_bar()
	score_label.text = "SCORE %05d" % (total_score + score)
	time_label.text = "TIME " + _fmt_time(run_time)
	best_label.text = "BEST " + (_fmt_time(float(level_best[current_level])) if level_best.has(current_level) else "--:--.-")
	if dash_cd <= 0.0:
		dash_label.text = "DASH READY"
		dash_label.modulate = Color.WHITE
	else:
		dash_label.text = "DASH %.1f" % dash_cd
		dash_label.modulate = Color(1, 1, 1, 0.5)
	level_label.text = "LEVEL %d  -  %s%s" % [current_level, String(theme.get("name", "")), "   [ WARDEN ]" if bool(level_data.get("boss", false)) else ""]
	progress.value = clampf(player.global_position.x / exit_x, 0.0, 1.0) * 100.0
	if boss_alive and is_instance_valid(boss_ref) and absf(boss_ref.global_position.x - player.global_position.x) < 800.0:
		boss_bar.visible = true
		boss_bar.max_value = float(boss_ref.get_meta("max_hp"))
		boss_bar.value = maxf(0.0, float(boss_ref.get_meta("hp")))
	else:
		boss_bar.visible = false

func _toast(text: String, secs := 1.4) -> void:
	message_text = text
	message_time = secs
	status_label.text = text

# ─────────────────────────────── State flow ───────────────────────────────
func _set_state(s: State) -> void:
	state = s
	_apply_mouse_mode()
	for tw in platform_tweens:
		if tw != null and tw.is_valid():
			if s == State.PLAYING:
				tw.play()
			else:
				tw.pause()

func _start_playing() -> void:
	menu_panel.visible = false
	input_lock = 0.2
	_apply_mouse_mode()
	_set_state(State.PLAYING)
	_sfx(660.0, 0.08, 0.12)

func _pause() -> void:
	_set_state(State.PAUSED)
	_open_menu("PAUSED", _run_summary(), "RESUME", "pause", "RESTART LEVEL")
	_sfx(440.0, 0.06, 0.1)

func _on_resume_pressed() -> void:
	match menu_mode:
		"pause":
			_start_playing()
		"dead":
			_retry()
		"won":
			if current_level < TOTAL_LEVELS:
				_start_level(current_level + 1)
			else:
				_show_levels()
		_:
			_start_level(current_level)

func _on_restart_pressed() -> void:
	_start_level(current_level)

func _start_level(n: int) -> void:
	current_level = clampi(n, 1, TOTAL_LEVELS)
	_set_state(State.MENU)
	_build_level(current_level)
	health = max_health
	score = 0
	shards = 0
	combo = 0
	checkpoint_idx = -1
	run_time = 0.0
	invulnerable = 0.0
	attack_cd = 0.0
	dash_cd = 0.0
	_refresh_checkpoints()
	_place_player_at_checkpoint()
	_update_hud()
	_toast("LEVEL %d  -  %s" % [current_level, String(theme["name"])], 2.0)
	_save_game(false)
	_start_playing()

func _retry() -> void:
	health = max_health
	_place_player_at_checkpoint()
	invulnerable = 1.5
	_update_hud()
	_start_playing()

func _toggle_music() -> void:
	music_on = not music_on
	_refresh_music_button()
	_sfx(520.0, 0.05, 0.1)
	_save_game(false)

func _on_death(reason: String) -> void:
	health = 0
	_set_state(State.DEAD)
	player_visual.visible = false
	_burst(player.global_position, Color("#f3c969"), 26, 280.0, 0.9)
	shake = 10.0
	_sfx(300.0, 0.5, 0.14, -500.0, 1)
	_update_hud()
	_open_menu(reason, _run_summary(), "RETRY FROM CHECKPOINT", "dead", "RESTART LEVEL")

func _win() -> void:
	_set_state(State.WON)
	var new_best := not level_best.has(current_level) or run_time < float(level_best[current_level])
	if new_best:
		level_best[current_level] = run_time
	total_score += score
	score = 0
	unlocked = maxi(unlocked, mini(TOTAL_LEVELS, current_level + 1))
	_save_game(false)
	for i in 4:
		_sfx([523.25, 659.25, 783.99, 1046.5][i], 0.25, 0.12, 0.0, 0, 0.12 * float(i))
	_burst(player.global_position, Color("#c4b5fd"), 30, 260.0, 1.0)
	_update_hud()
	_open_win_menu(new_best)

func _open_win_menu(new_best: bool) -> void:
	var line := "Time %s    Shards %d / %d" % [_fmt_time(run_time), shards, shards_total]
	if new_best:
		line += "\nNEW BEST TIME!"
	if current_level >= TOTAL_LEVELS:
		_open_menu("ALL 500 LEVELS CLEARED!", line, "LEVEL SELECT", "won", "REPLAY LEVEL")
	else:
		_open_menu("LEVEL %d CLEAR!" % current_level, line, "NEXT LEVEL  (%d)" % (current_level + 1), "won", "REPLAY LEVEL")

func _boss_defeated() -> void:
	boss_alive = false
	score += 100
	shake = 12.0
	exit_node.modulate = Color.WHITE
	_toast("WARDEN DEFEATED - THE PORTAL OPENS!", 2.5)
	for i in 4:
		_sfx([392.0, 523.25, 659.25, 783.99][i], 0.2, 0.12, 0.0, 0, 0.1 * float(i))

func _input(event: InputEvent) -> void:
	if menu_panel != null and (screen_levels.visible or screen_upgrades.visible):
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
			_back_to_main()
			get_viewport().set_input_as_handled()
			return
	if menu_panel != null and screen_levels.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
			_back_to_main()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("page_prev"):
			_change_page(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("page_next"):
			_change_page(1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause_game"):
		if state == State.PLAYING:
			_pause()
		elif state == State.PAUSED:
			_start_playing()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and state == State.PAUSED:
		_start_playing()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("save_game"):
		_save_game(true)
	elif event.is_action_pressed("toggle_music"):
		_toggle_music()

# ─────────────────────────────── Main loop ───────────────────────────────
func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	run_time += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	hurt_stun = maxf(0.0, hurt_stun - delta)
	input_lock = maxf(0.0, input_lock - delta)
	combo_window = maxf(0.0, combo_window - delta)
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo = 0
	_update_player(delta)
	if state != State.PLAYING:
		return
	_update_sword(delta)
	_update_enemies(delta)
	if state != State.PLAYING:
		return
	_update_items(delta)
	_update_triggers()
	if state == State.PLAYING:
		_update_hud()

func _player_rect() -> Rect2:
	return Rect2(player.global_position - Vector2(9.0, 17.0), Vector2(18.0, 34.0))

func _update_player(delta: float) -> void:
	var locked := input_lock > 0.0
	var axis := 0.0 if locked else Input.get_axis("move_left", "move_right")
	var on_floor := player.is_on_floor()
	if hurt_stun <= 0.0 and dash_time <= 0.0:
		if axis > 0.1:
			facing = 1.0
		elif axis < -0.1:
			facing = -1.0

	if not locked and Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and dash_time <= 0.0 and hurt_stun <= 0.0:
		dash_time = DASH_TIME
		dash_cd = DASH_COOLDOWN * (1.0 - 0.08 * float(upgrade_levels.get("dash", 0)))
		dash_dir = facing
		attack_t = -1.0
		_sfx(300.0, 0.16, 0.08, 1200.0, 1)
		_burst(player.global_position + Vector2(-facing * 8.0, 8.0), Color("#7ef9ff"), 8, 120.0, 0.3)

	if dash_time > 0.0:
		dash_time -= delta
		player.velocity = Vector2(dash_dir * DASH_SPEED, 0.0)
		ghost_t -= delta
		if ghost_t <= 0.0:
			ghost_t = 0.04
			_ghost()
	else:
		if hurt_stun > 0.0:
			player.velocity.x = move_toward(player.velocity.x, 0.0, 600.0 * delta)
		else:
			var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
			if absf(axis) < 0.01:
				accel = GROUND_FRICTION if on_floor else AIR_ACCEL * 0.5
			player.velocity.x = move_toward(player.velocity.x, axis * (MOVE_SPEED * (1.0 + 0.08 * float(upgrade_levels.get("speed", 0)))), accel * delta)
		var g := GRAVITY
		if player.velocity.y > 0.0:
			g *= FALL_GRAVITY_MULT
		player.velocity.y = minf(player.velocity.y + g * delta, MAX_FALL)

	coyote = COYOTE_TIME if on_floor else coyote - delta
	if not locked and Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	else:
		jump_buffer -= delta
	if jump_buffer > 0.0 and coyote > 0.0 and dash_time <= 0.0 and hurt_stun <= 0.0:
		player.velocity.y = JUMP_SPEED
		jump_buffer = 0.0
		coyote = 0.0
		squash = Vector2(0.78, 1.28)
		_sfx(380.0, 0.12, 0.07, 700.0, 1)
		_burst(player.global_position + Vector2(0.0, 16.0), Color("#8d9ab8"), 5, 70.0, 0.3)
	if not locked and Input.is_action_just_released("jump") and player.velocity.y < 0.0:
		player.velocity.y *= JUMP_CUT

	if drop_time > 0.0:
		drop_time -= delta
		if drop_time <= 0.0:
			player.set_collision_mask_value(4, true)
	elif not locked and on_floor and Input.is_action_just_pressed("drop"):
		drop_time = 0.22
		player.set_collision_mask_value(4, false)

	if not locked and Input.is_action_just_pressed("attack") and dash_time <= 0.0 and (attack_t < 0.0 or attack_cd <= 0.0):
		_start_attack()

	var pre_vy := player.velocity.y
	player.move_and_slide()
	if not on_floor and player.is_on_floor() and pre_vy > 250.0:
		var k := clampf(pre_vy / 700.0, 0.0, 1.0)
		squash = Vector2(1.0 + 0.28 * k, 1.0 - 0.28 * k)
		_burst(player.global_position + Vector2(0.0, 16.0), Color("#8d9ab8"), 6, 80.0, 0.3)
		_sfx(110.0, 0.06, 0.08, -100.0, 2)

	if player.global_position.x < 16.0:
		player.global_position.x = 16.0
		player.velocity.x = maxf(0.0, player.velocity.x)
	if player.global_position.y > PIT_Y:
		_fall_into_pit()

# ─────────────────────────────── Sword ───────────────────────────────
func _start_attack() -> void:
	attack_style = (attack_style + 1) % 3 if combo_window > 0.0 else 0
	var st: Array = ATTACK_STYLES[attack_style]
	var dur: float = st[5]
	attack_t = 0.0
	attack_cd = dur * 0.7
	combo_window = dur + 0.35
	attack_hits.clear()
	_sfx(520.0 + 90.0 * float(attack_style), 0.1, 0.06, -900.0, 1)
	var a0: float = minf(float(st[0]), float(st[1]))
	var a1: float = maxf(float(st[0]), float(st[1]))
	var reach := 52.0 if attack_style == 2 else 46.0
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(a0, a1, float(i) / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * reach)
	for i in range(8, -1, -1):
		var a := lerpf(a0, a1, float(i) / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * (reach - 14.0))
	var slash := Polygon2D.new()
	slash.polygon = pts
	slash.color = Color("#e6ffff") if attack_style < 2 else Color("#ffe28a")
	slash.scale.x = facing
	slash.position = Vector2(2.0 * facing, -4.0)
	slash.modulate.a = 0.0
	player.add_child(slash)
	var tw := create_tween()
	tw.tween_interval(dur * 0.2)
	tw.tween_property(slash, "modulate:a", 0.9, 0.02)
	tw.tween_property(slash, "modulate:a", 0.0, dur * 0.4)
	tw.tween_callback(slash.queue_free)

func _update_sword(delta: float) -> void:
	if attack_t < 0.0:
		return
	attack_t += delta
	var st: Array = ATTACK_STYLES[attack_style]
	var dur: float = st[5]
	if attack_t >= dur * 0.2 and attack_t <= dur * 0.66:
		var size := Vector2(float(st[3]), 56.0 if attack_style == 2 else 46.0)
		var center := player.global_position + Vector2(facing * float(st[4]), -4.0)
		var box := Rect2(center - size * 0.5, size)
		for e in enemies:
			if bool(e.get_meta("dead")):
				continue
			var eid := e.get_instance_id()
			if attack_hits.has(eid):
				continue
			var esz: Vector2 = e.get_meta("size")
			if box.intersects(Rect2(e.global_position - esz * 0.5, esz)):
				attack_hits[eid] = true
				_damage_enemy(e, int(st[2]) + int(upgrade_levels.get("sword", 0)), facing)
				shake = maxf(shake, 4.0 if attack_style == 2 else 2.5)
	if attack_t >= dur:
		attack_t = -1.0

func _hurt_player(amount: int, from_x: float) -> void:
	if state != State.PLAYING or invulnerable > 0.0 or dash_time > 0.0:
		return
	health -= amount
	invulnerable = INVULN_TIME
	hurt_stun = 0.22
	attack_t = -1.0
	var dir := signf(player.global_position.x - from_x)
	if dir == 0.0:
		dir = -facing
	player.velocity = Vector2(dir * 280.0, -300.0)
	shake = maxf(shake, 6.0)
	_sfx(140.0, 0.2, 0.14, -200.0, 2)
	_burst(player.global_position, Color("#ff7b86"), 10, 160.0, 0.5)
	if health <= 0:
		_on_death("RIFT RUN ENDED")
	else:
		_update_hud()

func _fall_into_pit() -> void:
	health -= 1
	shake = 8.0
	_sfx(200.0, 0.4, 0.14, -400.0, 1)
	if health <= 0:
		_on_death("SWALLOWED BY THE RIFT")
	else:
		_toast("FELL INTO THE RIFT  -1 HP")
		_place_player_at_checkpoint()
		invulnerable = 1.5

# ─────────────────────────────── Enemies ───────────────────────────────
func _update_enemies(delta: float) -> void:
	var prect := _player_rect()
	var i := enemies.size() - 1
	while i >= 0:
		var e := enemies[i]
		if not is_instance_valid(e) or bool(e.get_meta("dead")):
			enemies.remove_at(i)
			i -= 1
			continue
		var kind := String(e.get_meta("kind"))
		if kind == "walker" or kind == "boss":
			for enemy_child in e.get_children():
				if enemy_child is Sprite2D:
					(enemy_child as Sprite2D).flip_h = float(e.get_meta("dir", 1.0)) < 0.0
		var stun := maxf(0.0, float(e.get_meta("stun")) - delta)
		e.set_meta("stun", stun)
		if kind == "walker" or kind == "boss":
			var w := e as CharacterBody2D
			var dir: float = e.get_meta("dir")
			var spd: float = e.get_meta("speed")
			var jcd := maxf(0.0, float(e.get_meta("jcd")) - delta)
			var minx: float = e.get_meta("min_x")
			var maxx: float = e.get_meta("max_x")
			if stun > 0.0:
				w.velocity.x = move_toward(w.velocity.x, 0.0, 500.0 * delta)
			else:
				var to_p := player.global_position.x - w.global_position.x
				if kind == "boss" and absf(to_p) < 340.0 and absf(player.global_position.y - w.global_position.y) < 140.0:
					dir = signf(to_p)
					spd *= 2.3
					if (w.global_position.x <= minx and dir < 0.0) or (w.global_position.x >= maxx and dir > 0.0):
						dir = 0.0
					if w.is_on_floor() and jcd <= 0.0 and player.global_position.y < w.global_position.y - 70.0 and absf(to_p) < 220.0:
						w.velocity.y = -640.0
						jcd = 1.6
				else:
					if w.global_position.x < minx:
						dir = 1.0
					elif w.global_position.x > maxx:
						dir = -1.0
					elif w.is_on_wall():
						dir = -dir
				w.velocity.x = dir * spd
			e.set_meta("dir", dir if dir != 0.0 else float(e.get_meta("dir")))
			e.set_meta("jcd", jcd)
			w.velocity.y = minf(w.velocity.y + GRAVITY * delta, MAX_FALL)
			w.move_and_slide()
		else:
			var home: Vector2 = e.get_meta("home")
			var ph: float = e.get_meta("phase")
			var target := home + Vector2(sin(anim_time * 1.3 + ph) * 50.0, sin(anim_time * 2.1 + ph) * 16.0)
			var chase := e.global_position.distance_to(player.global_position) < 240.0
			if chase:
				target = player.global_position + Vector2(0.0, -26.0)
			if stun <= 0.0:
				var boost := 1.0 + 0.4 * clampf(float(current_level - 1) / 499.0, 0.0, 1.0)
				e.global_position = e.global_position.move_toward(target, (95.0 if chase else 55.0) * boost * delta)
		var esz: Vector2 = e.get_meta("size")
		if prect.intersects(Rect2(e.global_position - esz * 0.5, esz)):
			var stomping := player.velocity.y > 30.0 and player.global_position.y + 6.0 < e.global_position.y - esz.y * 0.15
			if stomping:
				_damage_enemy(e, 2, signf(e.global_position.x - player.global_position.x))
				player.velocity.y = JUMP_SPEED * (0.95 if Input.is_action_pressed("jump") else 0.7)
				squash = Vector2(0.82, 1.22)
			else:
				_hurt_player(1, e.global_position.x)
		i -= 1

func _damage_enemy(e: Node2D, amount: int, push_dir: float) -> void:
	var kind := String(e.get_meta("kind"))
	var hp := int(e.get_meta("hp")) - amount
	e.set_meta("hp", hp)
	_sfx(200.0, 0.09, 0.1, -600.0, 1)
	_burst(e.global_position, Color("#f16d75"), 8, 170.0, 0.45)
	if hp <= 0:
		var pts := 10
		if kind == "flyer":
			pts = 15
		elif kind == "boss":
			pts = 50
		score += pts
		e.set_meta("dead", true)
		_float_text(e.global_position, "+%d" % pts, Color("#ffe28a"))
		_burst(e.global_position, Color("#ffe28a"), 24 if kind == "boss" else 12, 220.0, 0.7)
		e.queue_free()
		if kind == "boss":
			_boss_defeated()
	else:
		e.set_meta("stun", 0.12 if kind == "boss" else 0.3)
		if e is CharacterBody2D:
			(e as CharacterBody2D).velocity.x = push_dir * (60.0 if kind == "boss" else 220.0)
		e.modulate = Color(2.5, 2.5, 2.5)
		create_tween().tween_property(e, "modulate", Color.WHITE, 0.2)

# ─────────────────────────────── Items & triggers ───────────────────────────────
func _update_items(delta: float) -> void:
	var pc := player.global_position
	var i := items.size() - 1
	while i >= 0:
		var it: Dictionary = items[i]
		var n: Node2D = it["node"]
		var kind: String = it["kind"]
		var can_take := not (kind == "heart" and health >= max_health)
		var d := n.global_position.distance_to(pc)
		if can_take and (bool(it["mag"]) or d < 70.0):
			it["mag"] = true
			n.global_position = n.global_position.move_toward(pc, 300.0 * delta)
			d = n.global_position.distance_to(pc)
		if can_take and d < 20.0:
			_collect(it)
			items.remove_at(i)
		i -= 1

func _collect(it: Dictionary) -> void:
	var n: Node2D = it["node"]
	if String(it["kind"]) == "crystal":
		score += 5
		shards += 1
		combo += 1
		combo_timer = 0.9
		var f := 660.0 * pow(1.05946, float(mini(combo, 12)))
		_sfx(f, 0.09, 0.12)
		_sfx(f * 2.0, 0.07, 0.05, 0.0, 0, 0.04)
		_burst(n.global_position, Color("#7ef9ff"), 6, 110.0, 0.35)
	else:
		health = mini(max_health, health + 1)
		_toast("+1 HEART")
		_sfx(523.25, 0.12, 0.12)
		_sfx(783.99, 0.18, 0.12, 0.0, 0, 0.1)
		_burst(n.global_position, Color("#ff7b86"), 12, 140.0, 0.5)
		_float_text(n.global_position, "+1", Color("#ff7b86"))
	n.queue_free()

func _update_triggers() -> void:
	var prect := _player_rect()
	for r in spike_rects:
		if prect.intersects(r):
			_hurt_player(1, r.get_center().x)
			if state != State.PLAYING:
				return
	var px := player.global_position.x
	var cps: Array = level_data["checkpoints"]
	for i in cps.size():
		if i > checkpoint_idx and absf(px - float(cps[i])) < 26.0 and player.global_position.y < GROUND_TOP + 10.0:
			checkpoint_idx = i
			_refresh_checkpoints()
			health = mini(max_health, health + 1)
			_toast("CHECKPOINT SAVED")
			_sfx(740.0, 0.14, 0.12)
			_sfx(988.0, 0.2, 0.1, 0.0, 0, 0.1)
			_burst(Vector2(float(cps[i]), GROUND_TOP - 50.0), Color("#ffe28a"), 14, 150.0, 0.6)
	if absf(px - exit_x) < 28.0:
		if boss_alive:
			if message_time <= 0.0:
				_toast("DEFEAT THE WARDEN FIRST!", 1.5)
		else:
			_win()

# ─────────────────────────────── Visuals ───────────────────────────────
func _process(delta: float) -> void:
	anim_time += delta
	_mix_audio()
	_music(delta)
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message_text = ""
			status_label.text = ""
	_animate_player(delta)
	_animate_world()
	look = lerpf(look, facing * 50.0, minf(1.0, delta * 3.0))
	camera.position = Vector2(look, -30.0)
	shake = maxf(0.0, shake - 40.0 * delta)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake

func _animate_world() -> void:
	for it in items:
		if not bool(it["mag"]):
			var n: Node2D = it["node"]
			var base: Vector2 = it["base"]
			n.position.y = base.y + sin(anim_time * 3.0 + float(it["phase"])) * 3.0
	for e in enemies:
		if is_instance_valid(e) and String(e.get_meta("kind")) == "flyer":
			var spr: Sprite2D = null
			for child in e.get_children():
				if child is Sprite2D:
					spr = child as Sprite2D
					break
			if spr != null:
				spr.scale.y = PIXEL * (1.0 + 0.28 * sin(anim_time * 16.0 + float(e.get_meta("phase"))))
	if exit_swirl != null and is_instance_valid(exit_swirl):
		exit_swirl.rotation = anim_time * 1.5
		exit_swirl.scale = Vector2.ONE * (1.0 + 0.15 * sin(anim_time * 3.0))

func _burst(pos: Vector2, color: Color, amount := 10, speed := 140.0, life := 0.5) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0.0, 500.0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)

func _float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := _label(text, 14, color)
	l.position = pos - Vector2(12.0, 14.0)
	l.z_index = 20
	world.add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 34.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(l.queue_free)

# ─────────────────────────────── Audio ───────────────────────────────
func _make_audio() -> void:
	sound_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.1
	sound_player.stream = stream
	add_child(sound_player)
	sound_player.play()
	sound_playback = sound_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _sfx(freq: float, dur := 0.1, vol := 0.15, slide := 0.0, wave := 0, delay := 0.0) -> void:
	voices.append({"f": freq, "t": 0.0, "d": dur, "v": vol, "s": slide, "w": wave, "ph": 0.0, "dl": delay})
	if voices.size() > 32:
		voices.pop_front()

func _mix_audio() -> void:
	if sound_playback == null:
		return
	var frames := sound_playback.get_frames_available()
	if frames <= 0:
		return
	var dt := 1.0 / MIX_RATE
	var buf := PackedVector2Array()
	buf.resize(frames)
	for n in frames:
		var s := 0.0
		for v in voices:
			var dl: float = v["dl"]
			if dl > 0.0:
				v["dl"] = dl - dt
				continue
			var t: float = v["t"]
			var d: float = v["d"]
			if t >= d:
				continue
			var f: float = v["f"]
			var ph: float = v["ph"]
			var x := 0.0
			match int(v["w"]):
				0:
					x = sin(ph)
				1:
					x = 1.0 if sin(ph) >= 0.0 else -1.0
				_:
					x = randf() * 2.0 - 1.0
			s += x * float(v["v"]) * (1.0 - t / d)
			v["ph"] = ph + TAU * f * dt
			v["t"] = t + dt
			v["f"] = maxf(20.0, f + float(v["s"]) * dt)
		s = clampf(s, -0.9, 0.9)
		buf[n] = Vector2(s, s)
	sound_playback.push_buffer(buf)
	var i := voices.size() - 1
	while i >= 0:
		if float(voices[i]["t"]) >= float(voices[i]["d"]) and float(voices[i]["dl"]) <= 0.0:
			voices.remove_at(i)
		i -= 1

func _music(delta: float) -> void:
	if not music_on or state != State.PLAYING:
		return
	music_timer -= delta
	if music_timer > 0.0:
		return
	music_timer += 0.2
	var f: float = MUSIC_NOTES[music_step % MUSIC_NOTES.size()]
	_sfx(f * (1.0 if current_level < 250 else 2.0), 0.16, 0.025, 0.0, 1)
	if music_step % 4 == 0:
		_sfx(f * 0.5, 0.4, 0.05, 0.0, 0)
	music_step += 1

# ─────────────────────────────── Save / load ───────────────────────────────
func _save_game(show_toast := true) -> void:
	var best := {}
	for k in level_best:
		best[str(k)] = level_best[k]
	var data := {
		"version": SAVE_VERSION,
		"unlocked": unlocked,
		"current": current_level,
		"total_score": total_score,
		"best": best,
		"music": music_on,
		"unlock_all": unlock_all,
		"upgrade_levels": upgrade_levels,
		"max_health": max_health,
		"mouse_lock": mouse_lock_enabled
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		if show_toast:
			_toast("SAVE FAILED")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	if show_toast:
		_toast("PROGRESS SAVED")

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != SAVE_VERSION:
		return
	unlocked = clampi(int(d.get("unlocked", 1)), 1, TOTAL_LEVELS)
	current_level = clampi(int(d.get("current", 1)), 1, unlocked)
	total_score = maxi(0, int(d.get("total_score", 0)))
	music_on = bool(d.get("music", true))
	unlock_all = bool(d.get("unlock_all", false))
	mouse_lock_enabled = bool(d.get("mouse_lock", false))
	max_health = clampi(int(d.get("max_health", 5)), 5, 10)
	var saved_upgrades: Dictionary = d.get("upgrade_levels", {})
	for id in ["health", "speed", "dash", "sword"]:
		upgrade_levels[id] = clampi(int(saved_upgrades.get(id, 0)), 0, 5)
	upgrade_levels["health"] = max(0, max_health - 5)
	_refresh_mouse_lock_button()
	_refresh_health_bar()
	level_best.clear()
	var best: Dictionary = d.get("best", {})
	for k in best:
		level_best[int(k)] = float(best[k])

# ─────────────────────────────── Parallax backdrop ───────────────────────────────
class Backdrop extends Node2D:
	var cam: Camera2D
	var t := 0.0
	var sky_top := Color("#0b1020")
	var sky_bottom := Color("#2a2f5e")
	var ridge1 := Color("#1b2547")
	var ridge2 := Color("#17203d")
	var ridge3 := Color("#111a31")

	func apply_theme(top: Color, bottom: Color, r1: Color, r2: Color, r3: Color) -> void:
		sky_top = top
		sky_bottom = bottom
		ridge1 = r1
		ridge2 = r2
		ridge3 = r3

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var cx := 0.0
		if is_instance_valid(cam):
			cx = cam.get_screen_center_position().x
		var bands := 24
		for i in bands:
			var k := float(i) / float(bands - 1)
			var col := sky_top.lerp(sky_bottom, pow(k, 1.6))
			draw_rect(Rect2(0.0, vs.y * float(i) / float(bands), vs.x, vs.y / float(bands) + 1.0), col)
		for i in 70:
			var depth := 0.02 + 0.03 * float(i % 3)
			var sx := fposmod(float(i) * 173.0 - cx * depth, vs.x)
			var sy := fposmod(float(i) * 97.0, vs.y * 0.62)
			var tw := 0.5 + 0.5 * sin(t * 2.0 + float(i))
			draw_rect(Rect2(sx, sy, 2.0, 2.0), Color(1.0, 1.0, 1.0, 0.25 + 0.5 * tw))
		var moon := Vector2(vs.x * 0.78, 92.0)
		draw_circle(moon, 52.0, Color(0.55, 0.65, 1.0, 0.08))
		draw_circle(moon, 34.0, Color("#dfe8ff"))
		draw_circle(moon + Vector2(-9.0, -5.0), 7.0, Color("#c3cfee"))
		draw_circle(moon + Vector2(10.0, 9.0), 5.0, Color("#c3cfee"))
		_ridge(vs, cx * 0.10, vs.y * 0.62, 70.0, 0.0045, ridge1)
		_ridge(vs, cx * 0.22, vs.y * 0.72, 55.0, 0.007, ridge2)
		_ridge(vs, cx * 0.40, vs.y * 0.84, 40.0, 0.011, ridge3)

	func _ridge(vs: Vector2, off: float, base: float, amp: float, freq: float, col: Color) -> void:
		var pts := PackedVector2Array()
		var step := 20.0
		var x := 0.0
		while x <= vs.x + step:
			var wx := x + off
			var h := sin(wx * freq) * 0.6 + sin(wx * freq * 2.3 + 1.7) * 0.3 + sin(wx * freq * 5.1) * 0.1
			pts.append(Vector2(x, base - amp * h))
			x += step
		pts.append(Vector2(vs.x + step, vs.y))
		pts.append(Vector2(0.0, vs.y))
		draw_colored_polygon(pts, col)
