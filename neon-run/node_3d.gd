extends Node2D
## PIXELBOUND: RIFT RUNNER  (v6) — Title menu + Multiplayer + Mobile controls
## Godot 4.x — attach this single script to an otherwise-empty Node2D and press Play.
## Everything (rigged hero + monsters, 500 generated levels, traps, UI, particles, synth audio)
## is built at runtime. No assets needed.
##
## CONTROLS
##   Move ........ A / D, arrows, left stick, D-pad
##   Jump ........ SPACE / W / UP / pad A     (hold = higher; buffered + coyote time)
##   Sword ....... J / X / pad X              (tap repeatedly for a 3-hit combo)
##   Dash ........ K / SHIFT / pad B          (invulnerable while dashing)
##   Drop down ... S / DOWN / stick down      (through thin platforms)
##   Pause ....... ESC / START      Music ... M      Save ... F5
## MENUS (own navigation system — works with keyboard, mouse and ANY controller)
##   D-pad / left stick = move     A / Enter = select     B / Esc = back
##   LB / RB (or Q / E) = change level page      START = resume / confirm

# ─────────────────────────────── Constants ───────────────────────────────
const SAVE_PATH := "user://pixelbound_save_v3.json"
const SAVE_VERSION := 5
const TOTAL_LEVELS := 500
const PAGE_SIZE := 25
const PAGE_COUNT := 20
const VIEW_SIZE := Vector2i(960, 540)
const MIX_RATE := 22050.0

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
const GROUND_TOP := 385.0
const ROOF_Y := 48.0
const PIT_Y := 720.0

const L_SOLID := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_ONEWAY := 8

const OUT := Color("#141a2c")
const PAD_BUTTONS := [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_B, JOY_BUTTON_Y]

enum State { MENU, PLAYING, PAUSED, DEAD, WON }

## Sword combo styles: [start angle, end angle, damage, hit width, hit reach, duration]
const ATTACK_STYLES := [
	[-2.5, 0.7, 1, 70.0, 36.0, 0.30],
	[1.0, -1.3, 1, 70.0, 36.0, 0.30],
	[-3.0, 1.6, 2, 96.0, 44.0, 0.40]
]

## name, sky top, sky bottom, ground, ground dark, grass, grass dark, platform, platform top,
## ridge 1/2/3, accent, weather, props
const THEMES := [
	["NEON DUSK", "#0b1020", "#2a2f5e", "#2b3a52", "#243248", "#72d6a0", "#4fa47c", "#426b78", "#8be8c0", "#1b2547", "#17203d", "#111a31", "#7ef9ff", "motes", "forest"],
	["CRIMSON RIFT", "#1a0a12", "#5e2a3a", "#4a2a35", "#3a1f29", "#ff8a65", "#cc5f45", "#7a4452", "#ffb199", "#3a1a28", "#2e1420", "#220e18", "#ff6b6b", "embers", "wasteland"],
	["EMERALD DEPTHS", "#05140f", "#14503a", "#1f4a3a", "#183a2e", "#9be86a", "#6cb24a", "#2f7a5c", "#b6f2a0", "#0f3326", "#0c291f", "#081f17", "#b6f2a0", "spores", "forest"],
	["FROZEN VOID", "#0a1224", "#2b5a8a", "#3b5878", "#2f4862", "#e6f6ff", "#a9d4f0", "#5a86ad", "#e6f6ff", "#1d3a5c", "#162e4a", "#102338", "#bfe6ff", "snow", "pine"],
	["GOLDEN RUINS", "#1a1206", "#6b4a1a", "#5a4528", "#473620", "#ffd866", "#c9a23d", "#8a6a35", "#ffe9a6", "#3d2c12", "#2f220e", "#231a0a", "#ffd866", "motes", "ruins"],
	["VIOLET STORM", "#120a24", "#4a2a7a", "#3a2c5c", "#2e2349", "#c4a3ff", "#9a78e0", "#5b4bc4", "#d3c2ff", "#26194a", "#1d1338", "#150e2a", "#c4a3ff", "sparks", "ruins"],
	["ASH PLAINS", "#121212", "#3d3d3d", "#3a3a3f", "#2e2e33", "#bdbdbd", "#8c8c8c", "#55555c", "#d0d0d0", "#262626", "#1e1e1e", "#161616", "#d0d0d0", "ash", "wasteland"],
	["AQUA REEF", "#041a24", "#0f6b7a", "#1a5566", "#144552", "#6af0e0", "#3fb8aa", "#2b8a9a", "#a8fff3", "#0b3a47", "#093040", "#062530", "#6af0e0", "bubbles", "crystal"],
	["ROSE NEBULA", "#1e0a24", "#8a3a7a", "#5c2f5a", "#4a2448", "#ff9ad5", "#d06aa8", "#8a4a86", "#ffc6ea", "#3a1740", "#2e1233", "#220d28", "#ff9ad5", "petals", "crystal"],
	["SOLAR FLARE", "#240a04", "#8a3a0a", "#5a2f14", "#48240f", "#ffb347", "#d98a1f", "#8a4a1f", "#ffd9a0", "#4a1a0a", "#3a1408", "#2a0e05", "#ffb347", "embers", "ruins"]
]

## main, dark, light, glow
const ENEMY_PALS := [
	["#c0453c", "#7a2a2a", "#ff8a6b", "#ffd24a"],
	["#6b4fb3", "#3d2b73", "#a98aff", "#7ef9ff"],
	["#2f8f83", "#1d5a58", "#6fe0c8", "#fff27a"],
	["#c28a2c", "#7a4f16", "#ffd27a", "#ff5d6c"]
]

const ENEMY_BASE := {
	"crawler": {"hp": 2, "size": Vector2(26, 20), "pts": 10},
	"bat": {"hp": 1, "size": Vector2(26, 16), "pts": 15},
	"slime": {"hp": 2, "size": Vector2(22, 18), "pts": 12},
	"spitter": {"hp": 3, "size": Vector2(20, 34), "pts": 20},
	"brute": {"hp": 5, "size": Vector2(36, 30), "pts": 30},
	"boss": {"hp": 10, "size": Vector2(56, 52), "pts": 100}
}

const MOD_NAMES := ["LOW GRAVITY", "SWARM", "IRON HIDE", "FRENZY", "TREASURE", "HAZARD RUSH"]
const MOD_INFO := {
	"LOW GRAVITY": "Floaty jumps",
	"SWARM": "Bats everywhere",
	"IRON HIDE": "Tougher monsters",
	"FRENZY": "Faster monsters",
	"TREASURE": "Double crystals",
	"HAZARD RUSH": "Extra traps"
}

const MUSIC_NOTES := [
	220.0, 261.63, 329.63, 261.63, 196.0, 246.94, 293.66, 246.94,
	174.61, 220.0, 261.63, 220.0, 196.0, 246.94, 329.63, 246.94
]

# ───── Bow & Upgrades ─────
const BOW_DRAW_MAX := 0.55
const BOW_COOLDOWN := 0.28
const ARROW_GRAV := 980.0
const MAX_HEARTS_CAP := 12
const UPGRADE_PAGE_SIZE := 12

const UPGRADE_LINES := [
	# SWORD (10 lines × 10 = 100 ranks)
	["sw_dmg", "SWORD", "Blade Edge", "+%d sword damage", 10, 25, 1.55, "sword_dmg", 1],
	["sw_spd", "SWORD", "Combo Tempo", "-%.2fs attack cooldown", 10, 30, 1.5, "sword_cd", -0.02],
	["sw_reach", "SWORD", "Long Reach", "+%d sword reach", 10, 40, 1.55, "sword_reach", 3],
	["sw_crit", "SWORD", "Critical Edge", "+%d%% crit chance", 10, 45, 1.55, "sword_crit", 4],
	["sw_life", "SWORD", "Bloodthirst", "+%d%% lifesteal", 10, 55, 1.6, "sword_lifesteal", 3],
	["sw_wide", "SWORD", "Wide Slash", "+%d hit width", 8, 40, 1.55, "sword_width", 6],
	["sw_knock", "SWORD", "Heavy Blow", "+%d knockback", 8, 35, 1.5, "sword_knock", 20],
	["sw_combo", "SWORD", "Combo Window", "+%.2fs combo window", 8, 40, 1.55, "sword_combo", 0.05],
	["sw_finisher", "SWORD", "Finisher", "+%d finisher damage", 8, 50, 1.6, "sword_finisher", 1],
	["sw_parry", "SWORD", "Parry Window", "+%.2fs parry frames", 6, 60, 1.65, "sword_parry", 0.03],
	# BOW (12 lines)
	["bw_dmg", "BOW", "Hook Barbs", "+%d grapple pull", 10, 25, 1.55, "bow_dmg", 1],
	["bw_draw", "BOW", "Quick Hook", "-%.2fs grapple cooldown", 10, 35, 1.5, "bow_draw", -0.03],
	["bw_spd", "BOW", "Winch Speed", "+%d hook speed", 10, 30, 1.5, "bow_spd", 40],
	["bw_pierce", "BOW", "Deep Bite", "+%d latch strength", 8, 50, 1.65, "bow_pierce", 1],
	["bw_multi", "BOW", "Dual Hooks", "+%d extra hooks", 6, 80, 1.75, "bow_multi", 1],
	["bw_fire", "BOW", "Burn Latch", "Burn on latch rank %d", 6, 70, 1.7, "bow_fire", 1],
	["bw_ice", "BOW", "Frost Latch", "Slow on latch rank %d", 6, 70, 1.7, "bow_ice", 1],
	["bw_explo", "BOW", "Shock Hook", "Blast on latch rank %d", 6, 90, 1.75, "bow_explo", 1],
	["bw_home", "BOW", "Smart Hook", "Aim assist rank %d", 5, 100, 1.85, "bow_home", 1],
	["bw_rico", "BOW", "Rebound", "+%d rope swings", 5, 85, 1.8, "bow_rico", 1],
	["bw_range", "BOW", "Long Line", "+%.2fs rope length", 8, 40, 1.55, "bow_life", 0.15],
	["bw_crit", "BOW", "Power Reel", "+%d%% reel speed", 8, 45, 1.55, "bow_crit", 5],
	# MOVEMENT (8 lines)
	["mv_spd", "MOVEMENT", "Swift Boots", "+%d move speed", 10, 30, 1.5, "move_spd", 12],
	["mv_jmp", "MOVEMENT", "Spring Legs", "+%d jump power", 10, 35, 1.5, "jump_spd", -18],
	["mv_air", "MOVEMENT", "Air Control", "+%d air accel", 10, 40, 1.5, "air_accel", 100],
	["mv_coy", "MOVEMENT", "Coyote Grace", "+%.2fs coyote", 8, 45, 1.55, "coyote", 0.02],
	["mv_dbl", "MOVEMENT", "Double Jump", "Extra jumps +%d", 4, 120, 1.9, "double_jump", 1],
	["mv_fall", "MOVEMENT", "Soft Landing", "-%d%% fall damage", 6, 40, 1.55, "fall_red", 10],
	["mv_buf", "MOVEMENT", "Jump Buffer", "+%.2fs jump buffer", 6, 40, 1.55, "jump_buf", 0.02],
	["mv_wall", "MOVEMENT", "Wall Cling", "Wall slide rank %d", 4, 80, 1.8, "wall_cling", 1],
	# DEFENSE (8 lines)
	["df_hp", "DEFENSE", "Vitality", "+1 max heart", 7, 80, 1.65, "max_hp", 1],
	["df_arm", "DEFENSE", "Iron Skin", "+%d%% damage reduction", 10, 50, 1.55, "armor", 4],
	["df_inv", "DEFENSE", "Ghost Veil", "+%.2fs i-frames", 10, 55, 1.55, "invuln", 0.06],
	["df_reg", "DEFENSE", "Regen", "Regen rank %d", 8, 70, 1.6, "regen", 0.12],
	["df_rev", "DEFENSE", "Second Wind", "Revives +%d", 2, 250, 1.5, "revive", 1],
	["df_thorn", "DEFENSE", "Thorns", "Reflect rank %d", 6, 60, 1.6, "thorns", 1],
	["df_stun", "DEFENSE", "Steady Feet", "-%d%% hurt stun", 6, 45, 1.55, "stun_red", 10],
	["df_hp2", "DEFENSE", "Tough Heart", "Hearts heal +%d", 5, 70, 1.65, "heart_heal", 1],
	# DASH (6 lines)
	["ds_dist", "DASH", "Long Dash", "+%d dash speed", 10, 40, 1.5, "dash_spd", 35],
	["ds_cd", "DASH", "Quick Dash", "-%.2fs dash cooldown", 10, 45, 1.5, "dash_cd", -0.04],
	["ds_dmg", "DASH", "Dash Strike", "Dash damage rank %d", 6, 60, 1.65, "dash_dmg", 1],
	["ds_ifr", "DASH", "Phase Dash", "+%.2fs dash i-frames", 8, 55, 1.55, "dash_ifr", 0.03],
	["ds_air", "DASH", "Air Dash", "Air dashes +%d", 3, 100, 1.9, "dash_air", 1],
	["ds_trail", "DASH", "Afterimage", "Trail rank %d", 5, 50, 1.6, "dash_trail", 1],
	# LOOT (6 lines)
	["lt_val", "LOOT", "Crystal Sense", "+%d crystal value", 10, 35, 1.5, "crystal_val", 1],
	["lt_mag", "LOOT", "Magnet", "+%d magnet range", 10, 40, 1.5, "magnet", 16],
	["lt_hrt", "LOOT", "Heart Finder", "+%d%% heart drop", 8, 50, 1.55, "heart_drop", 5],
	["lt_clr", "LOOT", "Clear Bonus", "+%d clear crystals", 10, 45, 1.5, "clear_bonus", 6],
	["lt_boss", "LOOT", "Boss Bounty", "+%d boss crystals", 8, 55, 1.55, "boss_bonus", 10],
	["lt_start", "LOOT", "Pocket Change", "+%d start crystals", 6, 60, 1.6, "start_crystals", 15],
	# TRAPS (6 lines)
	["tr_saw", "TRAPS", "Saw Guard", "Saw resist rank %d", 6, 55, 1.6, "trap_saw", 1],
	["tr_flm", "TRAPS", "Flame Ward", "Flame resist rank %d", 6, 55, 1.6, "trap_flame", 1],
	["tr_lsr", "TRAPS", "Laser Shield", "Laser resist rank %d", 6, 55, 1.6, "trap_laser", 1],
	["tr_spk", "TRAPS", "Spike Guard", "Spike resist rank %d", 6, 50, 1.55, "trap_spike", 1],
	["tr_pit", "TRAPS", "Pit Forgive", "Pit cost -%d", 4, 90, 1.75, "pit_forgive", 1],
	["tr_all", "TRAPS", "Hazard Master", "All traps resist +%d", 5, 100, 1.8, "trap_all", 1],
	# SPECIAL (6 lines)
	["sp_scor", "SPECIAL", "Score Surge", "+%d%% score", 10, 40, 1.5, "score_mul", 5],
	["sp_time", "SPECIAL", "Time Stretch", "Hazards -%d%% speed", 6, 100, 1.8, "hazard_slow", 5],
	["sp_luck", "SPECIAL", "Lucky Find", "+%d%% rare drops", 8, 50, 1.55, "luck", 4],
	["sp_xp", "SPECIAL", "Rift Affinity", "+%d%% crystal bank gain", 8, 55, 1.55, "bank_mul", 5],
	["sp_ghost", "SPECIAL", "Near Death", "Low-HP power rank %d", 5, 80, 1.7, "near_death", 1],
	["sp_cap", "SPECIAL", "Overcap", "Stat softcap +%d", 5, 120, 1.85, "overcap", 1],
]


var crystal_bank := 0
var owned_upgrades := {}
var stats := {}
var weapon_mode := "sword"  # "sword" | "grapple"
var bow_draw := 0.0
var bow_cd := 0.0
var player_arrows: Array[Dictionary] = []
var grapple_state := "idle"  # idle, flying, stuck, reeling
var grapple_pos := Vector2.ZERO
var grapple_vel := Vector2.ZERO
var grapple_anchor := Vector2.ZERO
var grapple_rope: Line2D
var grapple_hook: Node2D
var roof_body: StaticBody2D
var double_jumps_left := 0
var revive_used := false
var last_hazard := ""
var regen_t := 0.0
var upgrade_page := 0
var upgrade_cat := 0
var upgrade_cats := ["SWORD", "BOW", "MOVEMENT", "DEFENSE", "DASH", "LOOT", "TRAPS", "SPECIAL"]  # BOW tab = GRAPPLE
var screen_upgrades: VBoxContainer
var screen_title: VBoxContainer
var screen_mp: VBoxContainer
var title_rows: Array = []
var mp_rows: Array = []
var sp_btn: Button
var mp_menu_btn: Button
var title_quit_btn: Button
var mp_back_btn: Button
var upgrade_buttons: Array[Button] = []
var upgrade_tooltip: PanelContainer
var upgrade_tooltip_label: Label
var upgrade_rows: Array = []
var crystal_label: Label
var bow_charge_bar: ProgressBar
var upgrade_title: Label
var upgrade_hint: Label
var respec_btn: Button
var bow_node: Node2D
var string_line: Line2D
var nocked_arrow: Node2D
var upgrades_btn: Button

# ───── Mobile + Multiplayer ─────
var is_touch_device := false
var mobile_layer: CanvasLayer
var mob_joy_origin := Vector2(90, 430)
var mob_joy_center := Vector2(90, 430)
var mob_joy_active := false
var mob_joy_touch_idx := -1
var mob_axis := Vector2.ZERO
var mob_jump := false
var mob_sword := false
var mob_dash := false
var mob_grapple := false
var mob_pause_pressed := false
var mob_weapon_pressed := false
var mob_btns: Dictionary = {}
var mp_mode := "solo"  # solo, local2, host, client
var mp_peer: MultiplayerPeer
var mp_ip_edit: LineEdit
var mp_battle_btn: Button
var mp_start_btn: Button
var mp_battle_mode := false
var mp_remote_players: Dictionary = {} # peer_id -> remote avatar Node2D
var mp_remote_anim_data: Dictionary = {} # peer_id -> copied rig and synchronized animation state
var mp_remote_anim_accum := 0.0
var mp_battle_hp := 3
var mp_battle_wins := 0
var mp_sync_accum := 0.0
var low_power_mode := false
var player2: CharacterBody2D
var player2_visual: Node2D
var p2_facing := 1.0
var p2_health := 3
var p2_invuln := 0.0
var host_btn: Button
var join_btn: Button
var local2_btn: Button
var mp_status_lbl: Label


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
var weather_layer: CanvasLayer
var shadow: Polygon2D
var platform_tweens: Array[Tween] = []
var exit_node: Node2D
var exit_swirl: Polygon2D
var checkpoint_flags: Array[Polygon2D] = []
var spike_rects: Array[Rect2] = []
var enemies: Array[Node2D] = []
var items: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var flickers: Array[Dictionary] = []

var level_data: Dictionary = {}
var theme: Dictionary = {}
var ground_segs: Array = []
var world_end := 3000.0
var exit_x := 2900.0
var boss_ref: Node2D = null
var boss_alive := false
var shards_total := 0
var level_seed := 0
var modifier := ""
var grav_mul := 1.0
var enemy_speed_mul := 1.0
var enemy_hp_bonus := 0
var score_mul := 1

var tex_glow: Texture2D
var tex_heart: Texture2D
var tex_heart_empty: Texture2D
var mat_add: CanvasItemMaterial

# Hero rig
var rig := {}
var pose := {}
var cape_nodes: Array[Node2D] = []
var tail_nodes: Array[Node2D] = []
var dust_t := 0.0

# Progress (saved)
var max_health := 5
var unlocked := 1
var current_level := 1
var total_score := 0
var level_best := {}
var music_on := true
var unlock_all := false
var randomize_layout := true

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
var hitstop := 0.0
var shadow_y := -1000.0

# Controller fallback polling
var pad_state := {}
var pad_just := {}
var pad_released := {}

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
var heart_icons: Array[TextureRect] = []
var score_label: Label
var time_label: Label
var best_label: Label
var dash_label: Label
var status_label: Label
var level_label: Label
var mod_label: Label
var progress: ProgressBar
var boss_bar: ProgressBar
var menu_panel: PanelContainer
var menu_title: Label
var menu_hint: Label
var menu_mode := "start"
var screen_main: VBoxContainer
var screen_levels: VBoxContainer
var resume_btn: Button
var restart_btn: Button
var levels_btn: Button
var music_btn: Button
var random_btn: Button
var quit_btn: Button
var level_buttons: Array[Button] = []
var level_page := 0
var page_label: Label
var unlock_btn: Button
var pad_status: Label
var pad_hint: Label
var style_norm: StyleBoxFlat
var style_sel: StyleBoxFlat

# Menu navigation (our own system — does not rely on Godot GUI focus)
var menu_rows: Array = []
var menu_r := 0
var menu_c := 0
var nav_last := Vector2i.ZERO
var nav_timer := 0.0
var main_rows: Array = []
var level_rows: Array = []

# ─────────────────────────────── Setup ───────────────────────────────
func _ready() -> void:
	rng.randomize()
	low_power_mode = OS.has_feature("mobile") or OS.has_feature("android")
	if low_power_mode:
		# Prioritize stable frame pacing on phones; visual effects are also reduced below.
		Engine.max_fps = 45
	_setup_window()
	_setup_input_map()
	_make_materials()
	_make_textures()
	_make_audio()
	world = Node2D.new()
	world.name = "GeneratedWorld"
	add_child(world)
	_make_player()
	_make_camera()
	_make_backdrop()
	_make_weather_layer()
	_make_hud()
	_setup_mobile_and_mp()
	_load_game()
	if crystal_bank <= 0 and owned_upgrades.is_empty():
		crystal_bank = 150  # starter crystals so upgrades are testable immediately
	_rebuild_stats()
	_build_level(current_level, _new_seed(current_level))
	_place_player_at_checkpoint()
	_refresh_toggles()
	_refresh_level_page()
	_update_hud()
	_set_state(State.MENU)
	_open_start_menu()
	_toast("v6 loaded — pick SINGLEPLAYER or MULTIPLAYER")
	Input.joy_connection_changed.connect(_on_joy_changed)
	_update_pad_status()

func _setup_window() -> void:
	var win := get_window()
	win.content_scale_size = VIEW_SIZE
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.set_default_clear_color(Color("#0b1020"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and state == State.PLAYING and menu_panel != null:
		_pause()

func _new_seed(n: int) -> int:
	var extra := 0
	if randomize_layout:
		extra = int(rng.randi() % 900000) + 1
	return n * 7919 + 104729 + extra

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
	ev.device = -1
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _add_pad_axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure_action(action, 0.3)
	var ev := InputEventJoypadMotion.new()
	ev.device = -1
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
	_add_key("bow", KEY_L)
	_add_key("bow", KEY_C)
	_add_pad_button("bow", JOY_BUTTON_Y)
	_add_pad_axis("bow", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_key("drop", KEY_S)
	_add_key("drop", KEY_DOWN)
	_add_pad_button("drop", JOY_BUTTON_DPAD_DOWN)
	_add_pad_axis("drop", JOY_AXIS_LEFT_Y, 1.0)
	_add_key("save_game", KEY_F5)
	_add_key("toggle_music", KEY_M)

## Direct polling of every connected pad (fallback that always works, even if the
## action map is not matching a particular controller).
func _poll_pad() -> void:
	var pads := Input.get_connected_joypads()
	for b in PAD_BUTTONS:
		var now := false
		for dev in pads:
			if Input.is_joy_button_pressed(dev, b):
				now = true
		var prev: bool = pad_state.get(b, false)
		pad_just[b] = now and not prev
		pad_released[b] = prev and not now
		pad_state[b] = now

func _pad_axis_x() -> float:
	var best := 0.0
	for dev in Input.get_connected_joypads():
		var ax := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		if absf(ax) > 0.25 and absf(ax) > absf(best):
			best = ax
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT):
			best = -1.0
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT):
			best = 1.0
	return best

func _pad_down() -> bool:
	for dev in Input.get_connected_joypads():
		if Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y) > 0.65 or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN):
			return true
	return false

func _btn_just(b: int) -> bool:
	return bool(pad_just.get(b, false))

func _btn_held(b: int) -> bool:
	return bool(pad_state.get(b, false))

func _btn_released(b: int) -> bool:
	return bool(pad_released.get(b, false))

# ─────────────────────────────── Drawing helpers ───────────────────────────────
func _make_materials() -> void:
	mat_add = CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

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

func _make_textures() -> void:
	tex_heart = _tex(HEART_ROWS, {"o": OUT, "r": Color("#ff5d6c"), "w": Color("#ffd1d6")})
	tex_heart_empty = _tex(HEART_ROWS, {"o": OUT, "r": Color("#39415a"), "w": Color("#4a5370")})
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	tex_glow = gt

func _pts_rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position, r.position + Vector2(r.size.x, 0.0), r.position + r.size, r.position + Vector2(0.0, r.size.y)
	])

func _pts_ellipse(c: Vector2, rx: float, ry: float, n := 16, a0 := 0.0, a1 := TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var count := n if absf(a1 - a0) >= TAU - 0.001 else n + 1
	for i in count:
		var a := lerpf(a0, a1, float(i) / float(n))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _dome(c: Vector2, rx: float, ry: float, n := 14) -> PackedVector2Array:
	return _pts_ellipse(c, rx, ry, n, PI, TAU)

## Filled, gradient-shaded polygon with an outline. Returns the Polygon2D.
func _shape(parent: Node, pts: PackedVector2Array, fill: Color, shade := 0.22, line_w := 1.5, line_col := OUT) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.antialiased = not low_power_mode
	var miny := 1000000.0
	var maxy := -1000000.0
	for v in pts:
		miny = minf(miny, v.y)
		maxy = maxf(maxy, v.y)
	var span := maxf(0.001, maxy - miny)
	var cols := PackedColorArray()
	for v in pts:
		var t := (v.y - miny) / span
		cols.append(fill.lightened(shade * (1.0 - t)).darkened(shade * t))
	p.vertex_colors = cols
	parent.add_child(p)
	if line_w > 0.0:
		var l := Line2D.new()
		l.points = pts
		l.closed = true
		l.width = line_w
		l.default_color = line_col
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		l.antialiased = not low_power_mode
		p.add_child(l)
	return p

func _line(parent: Node, pts: PackedVector2Array, color: Color, width := 1.5) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.width = width
	l.default_color = color
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.antialiased = not low_power_mode
	parent.add_child(l)
	return l

func _joint(parent: Node, pos: Vector2) -> Node2D:
	var j := Node2D.new()
	j.position = pos
	parent.add_child(j)
	return j

func _glow(parent: Node, pos: Vector2, radius: float, color: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex_glow
	s.material = mat_add
	s.position = pos
	s.scale = Vector2.ONE * (radius * 2.0 / 64.0)
	s.modulate = color
	parent.add_child(s)
	return s

func _flicker(node: Node2D, base: float, speed: float) -> void:
	flickers.append({"node": node, "base": base, "speed": speed, "phase": rng.randf() * TAU})

## Two-segment limb. Returns [upper joint, lower joint]. Segments point down (+y).
func _limb(parent: Node, pos: Vector2, l1: float, l2: float, w: float, col: Color, foot := 0.0) -> Array:
	var j1 := _joint(parent, pos)
	_shape(j1, _pts_rect(Rect2(-w * 0.5, -1.0, w, l1 + 1.5)), col, 0.25, 1.2)
	var j2 := _joint(j1, Vector2(0.0, l1))
	_shape(j2, _pts_rect(Rect2(-w * 0.4, -1.0, w * 0.8, l2 + 1.0)), col.darkened(0.12), 0.25, 1.2)
	if foot > 0.0:
		_shape(j2, PackedVector2Array([
			Vector2(-w * 0.4, l2 - 1.0), Vector2(foot, l2 + 0.5), Vector2(foot, l2 + 2.2), Vector2(-w * 0.4, l2 + 2.2)
		]), col.darkened(0.3), 0.2, 1.2)
	return [j1, j2]

func _theme_for(n: int) -> Dictionary:
	var t: Array = THEMES[posmod(floori(float(n - 1) / 10.0), THEMES.size())]
	return {
		"name": String(t[0]),
		"sky_top": Color(String(t[1])), "sky_bottom": Color(String(t[2])),
		"ground": Color(String(t[3])), "ground_dark": Color(String(t[4])),
		"grass": Color(String(t[5])), "grass_dark": Color(String(t[6])),
		"plat": Color(String(t[7])), "plat_top": Color(String(t[8])),
		"ridge1": Color(String(t[9])), "ridge2": Color(String(t[10])), "ridge3": Color(String(t[11])),
		"accent": Color(String(t[12])), "weather": String(t[13]), "props": String(t[14])
	}

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
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", style_norm)
	b.add_theme_stylebox_override("hover", style_sel)
	b.add_theme_stylebox_override("pressed", _box(Color("#7ef9ff"), Color.WHITE))
	b.add_theme_stylebox_override("disabled", _box(Color("#10151f"), Color("#232b3b")))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("#4a5370"))
	b.add_theme_color_override("font_pressed_color", Color("#111a2b"))
	b.mouse_entered.connect(_on_btn_hover.bind(b))

# ─────────────────────────────── Menu navigation (controller-proof) ───────────────────────────────
func _btn_ok(b: Button) -> bool:
	return b.visible and not b.disabled

func _set_menu_rows(rows: Array, r := 0, c := 0) -> void:
	menu_rows = rows
	menu_r = clampi(r, 0, maxi(0, rows.size() - 1))
	menu_c = c
	_fix_selection()
	_apply_selection()

func _fix_selection() -> void:
	if menu_rows.is_empty():
		return
	for step in menu_rows.size():
		var r := posmod(menu_r + step, menu_rows.size())
		var row: Array = menu_rows[r]
		var c := _nearest_enabled(row, clampi(menu_c, 0, row.size() - 1))
		if c >= 0:
			menu_r = r
			menu_c = c
			return

func _nearest_enabled(row: Array, c: int) -> int:
	for off in row.size():
		for sgn in [1, -1]:
			var cc: int = c + off * sgn
			if cc >= 0 and cc < row.size() and _btn_ok(row[cc] as Button):
				return cc
	return -1

func _apply_selection() -> void:
	for row in menu_rows:
		for b in row:
			(b as Button).add_theme_stylebox_override("normal", style_norm)
	if menu_r < menu_rows.size():
		var row: Array = menu_rows[menu_r]
		if menu_c < row.size():
			var sel: Button = row[menu_c]
			sel.add_theme_stylebox_override("normal", style_sel)
			# Controller: show upgrade tooltip for focused upgrade button
			if is_instance_valid(upgrade_tooltip) and sel.has_meta("udesc"):
				upgrade_tooltip_label.text = str(sel.get_meta("udesc"))
				upgrade_tooltip.visible = true
				var gp := sel.get_global_rect()
				var tip_w := 300.0
				var tip_x := clampf(gp.position.x + gp.size.x * 0.5 - tip_w * 0.5, 8.0, float(VIEW_SIZE.x) - tip_w - 8.0)
				var tip_y := gp.position.y - 70.0
				if tip_y < 8.0:
					tip_y = gp.position.y + gp.size.y + 6.0
				upgrade_tooltip.position = Vector2(tip_x, tip_y)
			elif is_instance_valid(upgrade_tooltip) and screen_upgrades != null and not screen_upgrades.visible:
				upgrade_tooltip.visible = false

func _menu_move(dir: Vector2i) -> void:
	if menu_rows.is_empty():
		return
	if dir.y != 0:
		var r := menu_r
		for step in menu_rows.size():
			r = posmod(r + dir.y, menu_rows.size())
			var row: Array = menu_rows[r]
			var c := _nearest_enabled(row, clampi(menu_c, 0, row.size() - 1))
			if c >= 0:
				menu_r = r
				menu_c = c
				break
	elif dir.x != 0:
		var row2: Array = menu_rows[menu_r]
		var c2 := menu_c
		for step in row2.size():
			c2 = posmod(c2 + dir.x, row2.size())
			if _btn_ok(row2[c2] as Button):
				menu_c = c2
				break
	_apply_selection()
	_sfx(700.0, 0.03, 0.05, 0.0, 1)

func _menu_accept() -> void:
	if menu_rows.is_empty() or menu_r >= menu_rows.size():
		return
	var row: Array = menu_rows[menu_r]
	if menu_c >= row.size():
		return
	var b := row[menu_c] as Button
	if _btn_ok(b):
		_sfx(880.0, 0.05, 0.08)
		b.pressed.emit()

func _menu_back() -> void:
	if screen_levels.visible:
		_back_to_main()
	elif menu_mode == "pause":
		_start_playing()

func _menu_start_button() -> void:
	if screen_levels.visible:
		_back_to_main()
	elif menu_mode == "pause":
		_start_playing()
	else:
		_on_resume_pressed()

func _on_btn_hover(b: Button) -> void:
	if not menu_panel.visible:
		return
	for r in menu_rows.size():
		var row: Array = menu_rows[r]
		for c in row.size():
			if row[c] == b and _btn_ok(b) and (menu_r != r or menu_c != c):
				menu_r = r
				menu_c = c
				_apply_selection()
				return

func _poll_menu_pad(delta: float) -> void:
	if menu_panel == null or not menu_panel.visible:
		nav_last = Vector2i.ZERO
		return
	var dir := Vector2i.ZERO
	for dev in Input.get_connected_joypads():
		var ax := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT):
			dir = Vector2i(-1, 0)
		elif Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT):
			dir = Vector2i(1, 0)
		elif Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP):
			dir = Vector2i(0, -1)
		elif Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN):
			dir = Vector2i(0, 1)
		elif maxf(absf(ax), absf(ay)) > 0.55:
			if absf(ax) > absf(ay):
				dir = Vector2i(signi(int(signf(ax))), 0)
			else:
				dir = Vector2i(0, int(signf(ay)))
	if dir != nav_last:
		nav_last = dir
		nav_timer = 0.38
		if dir != Vector2i.ZERO:
			_menu_move(dir)
	elif dir != Vector2i.ZERO:
		nav_timer -= delta
		if nav_timer <= 0.0:
			nav_timer = 0.11
			_menu_move(dir)

func _on_joy_changed(_device: int, _connected: bool) -> void:
	_update_pad_status()

func _update_pad_status() -> void:
	if pad_status == null:
		return
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		pad_status.text = "NO CONTROLLER DETECTED  -  press a button on your pad"
		pad_status.add_theme_color_override("font_color", Color("#ff9aa5"))
	else:
		pad_status.text = "CONTROLLER: " + Input.get_joy_name(pads[0])
		pad_status.add_theme_color_override("font_color", Color("#8bf5b5"))

func _handle_menu_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		var k: Key = event.physical_keycode
		if k == KEY_UP or k == KEY_W:
			_menu_move(Vector2i(0, -1))
		elif k == KEY_DOWN or k == KEY_S:
			_menu_move(Vector2i(0, 1))
		elif k == KEY_LEFT or k == KEY_A:
			_menu_move(Vector2i(-1, 0))
		elif k == KEY_RIGHT or k == KEY_D:
			_menu_move(Vector2i(1, 0))
		elif (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE) and not event.echo:
			_menu_accept()
		elif k == KEY_ESCAPE and not event.echo:
			_menu_back()
		elif k == KEY_Q and not event.echo and screen_levels.visible:
			_change_page(-1)
		elif k == KEY_E and not event.echo and screen_levels.visible:
			_change_page(1)
		else:
			return false
		return true
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				_menu_accept()
			JOY_BUTTON_B:
				_menu_back()
			JOY_BUTTON_START:
				_menu_start_button()
			JOY_BUTTON_LEFT_SHOULDER:
				if screen_levels.visible:
					_change_page(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				if screen_levels.visible:
					_change_page(1)
			_:
				return false
		return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9:
		is_touch_device = not is_touch_device
		if is_touch_device:
			_make_mobile_controls()
			if mobile_layer:
				mobile_layer.visible = true
			_toast("MOBILE UI ON (force)")
		elif mobile_layer:
			mobile_layer.visible = false
			_toast("MOBILE UI OFF")
	if is_touch_device:
		_handle_mobile_touch(event)
	if event is InputEventJoypadButton and event.pressed:
		_update_pad_status()
		# LB / Left Shoulder = weapon switch (works even in menus)
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_toggle_weapon()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		_toggle_weapon()
		get_viewport().set_input_as_handled()
		return
	if menu_panel != null and menu_panel.visible:
		if _handle_menu_event(event):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if state == State.PLAYING:
			_pause()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		if state == State.PLAYING:
			_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("save_game"):
		_save_game(true)
	elif event.is_action_pressed("toggle_music"):
		_toggle_music()


# ─────────────────────────────── Level generator (deterministic per seed) ───────────────────────────────
var checkpoint_glows: Array[Sprite2D] = []
var exit_extra: Array[Node2D] = []

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

func _pick_weighted(r: RandomNumberGenerator, table: Array) -> String:
	var total := 0.0
	for e in table:
		total += float(e[1])
	var roll := r.randf() * total
	for e in table:
		roll -= float(e[1])
		if roll <= 0.0:
			return String(e[0])
	return String(table[0][0])

func _pick_enemy(r: RandomNumberGenerator, n: int, d: float) -> String:
	var table: Array = [["crawler", 4.0]]
	if n >= 2:
		table.append(["bat", 1.5 + 2.0 * d])
	if n >= 6:
		table.append(["slime", 1.0 + 1.5 * d])
	if n >= 12:
		table.append(["spitter", 0.8 + 1.5 * d])
	if n >= 20:
		table.append(["brute", 0.5 + 1.5 * d])
	return _pick_weighted(r, table)

func _pick_hazard(r: RandomNumberGenerator, n: int, d: float) -> String:
	var table: Array = [["saw", 2.0], ["spring", 0.8]]
	if n >= 6:
		table.append(["flame", 2.0])
	if n >= 10:
		table.append(["pendulum", 1.6])
	if n >= 16:
		table.append(["laser", 1.6])
	if n >= 22:
		table.append(["rock", 1.2])
	return _pick_weighted(r, table)

func _generate_level(n: int, seed_v: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var d := clampf(float(n - 1) / 499.0, 0.0, 1.0)
	var boss := n % 10 == 0
	var mod := ""
	if n >= 3 and not boss and r.randf() < 0.5:
		mod = String(MOD_NAMES[r.randi() % MOD_NAMES.size()])
	var target := 2400.0 + 3400.0 * minf(1.0, d * 1.6) + r.randf_range(0.0, 500.0)
	if boss:
		target *= 0.6
	var lv := {
		"n": n, "boss": boss, "mod": mod, "seed": seed_v, "grounds": [], "floats": [], "spikes": [],
		"enemies": [], "hazards": [], "crystals": [], "hearts": [], "movers": [], "checkpoints": [],
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
	var n: int = lv["n"]
	var mod: String = lv["mod"]
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
	# Spikes
	var spike_p := 0.35 + 0.4 * d + (0.3 if mod == "HAZARD RUSH" else 0.0)
	if kind != "final" and r.randf() < spike_p:
		var groups := r.randi_range(1, 1 + int(2.0 * d))
		for gi in groups:
			var c := r.randi_range(3, 3 + int(3.0 * d))
			var half := float(c) * 8.0
			var cx := r.randf_range(lo + half, maxf(lo + half + 1.0, hi - half))
			if _is_blocked(lv, cx, half + 20.0):
				continue
			lv["spikes"].append([cx, c])
			blocked.append(Vector2(cx - half - 40.0, cx + half + 40.0))
	# Traps
	_gen_hazards(lv, r, d, lo, hi, kind)
	# Monsters
	var ne := r.randi_range(0, 1 + int(1.0 + 2.0 * d))
	if kind == "final":
		ne = r.randi_range(0, 2)
	if b - a > 450.0 and ne == 0 and r.randf() < 0.5:
		ne = 1
	for ei in ne:
		var t := _pick_enemy(r, n, d)
		if t == "brute" and b - a < 480.0:
			t = "crawler"
		for tries in 4:
			var ex := r.randf_range(lo, hi)
			if _is_blocked(lv, ex, 55.0):
				continue
			var ey := r.randf_range(190.0, 250.0) if t == "bat" else 0.0
			var elite := n >= 5 and r.randf() < 0.04 + 0.2 * d
			lv["enemies"].append({"t": t, "x": ex, "y": ey, "elite": elite})
			if t != "bat":
				blocked.append(Vector2(ex - 55.0, ex + 55.0))
			break
	if mod == "SWARM" and r.randf() < 0.75:
		lv["enemies"].append({"t": "bat", "x": r.randf_range(a + 60.0, b - 60.0), "y": r.randf_range(180.0, 250.0), "elite": false})
	# Floating platforms (staircase), some crumble
	if r.randf() < 0.55 and hi - lo > 330.0:
		var cxf := r.randf_range(lo + 40.0, hi - 290.0)
		var crumble := r.randf() < 0.1 + 0.3 * d
		lv["floats"].append([cxf, 310.0, 140.0, false])
		lv["floats"].append([cxf + 170.0, 250.0, 120.0, crumble])
		lv["crystals"].append(Vector2(cxf, 282.0))
		lv["crystals"].append(Vector2(cxf + 170.0, 222.0))
		if hi - (cxf + 330.0) > 40.0 and r.randf() < 0.5:
			lv["floats"].append([cxf + 330.0, 310.0, 140.0, r.randf() < 0.15 * d])
			lv["crystals"].append(Vector2(cxf + 330.0, 282.0))
		if n >= 2 and r.randf() < 0.2 + 0.5 * d:
			lv["enemies"].append({"t": "bat", "x": cxf + 90.0, "y": 185.0, "elite": false})
	if n >= 2 and r.randf() < 0.15 + 0.5 * d:
		lv["enemies"].append({"t": "bat", "x": r.randf_range(a + 80.0, b - 80.0), "y": r.randf_range(190.0, 245.0), "elite": false})
	# Crystals
	var cn := r.randi_range(3, 6)
	_crystal_row(lv, r.randf_range(lo, maxf(lo + 1.0, hi - float(cn) * 36.0)), cn)
	if mod == "TREASURE":
		_crystal_row(lv, r.randf_range(lo, maxf(lo + 1.0, hi - 216.0)), 6, 320.0, 36.0)
	# Hearts
	if kind != "first" and mid > float(lv["next_heart"]):
		lv["hearts"].append(Vector2(mid + 40.0, 345.0))
		lv["next_heart"] = mid + 1100.0

func _gen_hazards(lv: Dictionary, r: RandomNumberGenerator, d: float, lo: float, hi: float, kind: String) -> void:
	var n: int = lv["n"]
	if n < 4 or kind == "final":
		return
	var chance := clampf(float(n - 3) / 60.0, 0.0, 1.0) * 0.55 + 0.25 * d
	if String(lv["mod"]) == "HAZARD RUSH":
		chance += 0.3
	var count := 0
	if r.randf() < chance:
		count = 1
		if r.randf() < chance * 0.6 * (0.3 + d):
			count = 2
	var blocked: Array = lv["blocked"]
	for hi_i in count:
		var t := _pick_hazard(r, n, d)
		for tries in 5:
			match t:
				"saw":
					var rg := r.randf_range(40.0, 90.0)
					if hi - lo < rg * 2.0 + 120.0:
						break
					var sx := r.randf_range(lo + rg, hi - rg)
					if _is_blocked(lv, sx, rg + 40.0):
						continue
					lv["hazards"].append({"t": "saw", "x": sx, "range": rg, "speed": r.randf_range(1.3, 2.3), "phase": r.randf() * TAU})
					blocked.append(Vector2(sx - rg - 40.0, sx + rg + 40.0))
				"flame":
					var fx := r.randf_range(lo, hi)
					if _is_blocked(lv, fx, 55.0):
						continue
					lv["hazards"].append({"t": "flame", "x": fx, "phase": r.randf() * 3.4})
					blocked.append(Vector2(fx - 55.0, fx + 55.0))
				"laser":
					var span := r.randf_range(110.0, 180.0)
					if hi - lo < span + 100.0:
						break
					var lx := r.randf_range(lo, hi - span)
					if _is_blocked(lv, lx + span * 0.5, span * 0.5 + 40.0):
						continue
					var ly := GROUND_TOP - (28.0 if r.randf() < 0.6 else 64.0)
					lv["hazards"].append({"t": "laser", "x1": lx, "x2": lx + span, "y": ly, "phase": r.randf() * 3.0})
					blocked.append(Vector2(lx - 40.0, lx + span + 40.0))
				"pendulum":
					if hi - lo < 300.0:
						break
					var px := r.randf_range(lo + 150.0, hi - 150.0)
					if _is_blocked(lv, px, 175.0):
						continue
					lv["hazards"].append({"t": "pendulum", "x": px, "len": 330.0, "amp": r.randf_range(0.38, 0.5), "period": r.randf_range(2.3, 3.1), "phase": r.randf() * TAU})
					blocked.append(Vector2(px - 175.0, px + 175.0))
				"rock":
					var rx := r.randf_range(lo, hi)
					if _is_blocked(lv, rx, 70.0):
						continue
					lv["hazards"].append({"t": "rock", "x": rx})
					blocked.append(Vector2(rx - 70.0, rx + 70.0))
				"spring":
					var spx := r.randf_range(lo, hi)
					if _is_blocked(lv, spx, 45.0):
						continue
					lv["hazards"].append({"t": "spring", "x": spx})
					blocked.append(Vector2(spx - 45.0, spx + 45.0))
					_crystal_row(lv, spx - 54.0, 4, 300.0, 80.0)
			break

# ─────────────────────────────── Level building ───────────────────────────────
func _apply_modifier() -> void:
	grav_mul = 1.0
	enemy_speed_mul = 1.0
	enemy_hp_bonus = 0
	score_mul = 1
	match modifier:
		"LOW GRAVITY":
			grav_mul = 0.72
		"FRENZY":
			enemy_speed_mul = 1.45
		"IRON HIDE":
			enemy_hp_bonus = 1
		"TREASURE":
			score_mul = 2

func _rebuild_stats() -> void:
	stats = {
		"sword_dmg": 0, "sword_cd": 0.0, "sword_reach": 0.0, "sword_crit": 0, "sword_lifesteal": 0,
		"bow_dmg": 0, "bow_draw": 0.0, "bow_spd": 0, "bow_pierce": 0, "bow_multi": 0,
		"bow_fire": 0, "bow_ice": 0, "bow_explo": 0, "bow_home": 0, "bow_rico": 0,
		"move_spd": 0, "jump_spd": 0, "air_accel": 0, "coyote": 0.0, "double_jump": 0,
		"max_hp": 0, "armor": 0, "invuln": 0.0, "regen": 0.0, "revive": 0,
		"dash_spd": 0, "dash_cd": 0.0, "dash_dmg": 0, "dash_ifr": 0.0,
		"crystal_val": 0, "magnet": 0, "heart_drop": 0, "clear_bonus": 0,
		"trap_saw": 0, "trap_flame": 0, "trap_laser": 0, "trap_spike": 0, "pit_forgive": 0,
		"score_mul": 0, "hazard_slow": 0.0
	}
	for line in UPGRADE_LINES:
		var id: String = line[0]
		var rank: int = int(owned_upgrades.get(id, 0))
		if rank <= 0: continue
		var key: String = line[7]
		var per = line[8]
		if not stats.has(key):
			stats[key] = 0.0 if typeof(per) == TYPE_FLOAT else 0
		if typeof(per) == TYPE_FLOAT:
			stats[key] = float(stats[key]) + float(per) * float(rank)
		else:
			stats[key] = int(stats[key]) + int(per) * rank
	max_health = clampi(5 + int(stats.get("max_hp", 0)), 1, MAX_HEARTS_CAP)

func _build_level(n: int, seed_v: int) -> void:
	if level_root != null:
		level_root.queue_free()
	for tw in platform_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	platform_tweens.clear()
	checkpoint_flags.clear()
	checkpoint_glows.clear()
	exit_extra.clear()
	spike_rects.clear()
	enemies.clear()
	items.clear()
	hazards.clear()
	projectiles.clear()
	flickers.clear()
	boss_ref = null
	boss_alive = false
	level_seed = seed_v
	level_data = _generate_level(n, seed_v)
	modifier = String(level_data["mod"])
	_apply_modifier()
	theme = _theme_for(n)
	ground_segs = level_data["grounds"]
	exit_x = float(level_data["exit_x"])
	world_end = float(level_data["end"])
	level_root = Node2D.new()
	level_root.name = "Level%d" % n
	world.add_child(level_root)
	world.move_child(level_root, 0)
	var pr := RandomNumberGenerator.new()
	pr.seed = seed_v + 77
	_add_props(pr)
	for seg in ground_segs:
		_add_ground(seg[0], seg[1])
	_add_roof()
	for p in level_data["floats"]:
		_add_floating(p[0], p[1], p[2], bool(p[3]))
	for m in level_data["movers"]:
		_add_moving_platform(m[0], m[1])
	for s in level_data["spikes"]:
		_add_spikes(s[0], int(s[1]))
	for x in level_data["checkpoints"]:
		_add_checkpoint(x)
	for h in level_data["hazards"]:
		_add_hazard(h)
	_add_exit(bool(level_data["boss"]))
	if n == 1:
		_add_hint("A / D  MOVE        SPACE  JUMP  (HOLD = HIGHER)", Vector2(60, 290))
		_add_hint("J  SWORD  (TAP 3x FOR A COMBO)  -  STOMP MONSTERS FROM ABOVE", Vector2(260, 285))
		_add_hint("K  DASH  (INVULNERABLE WHILE DASHING)", Vector2(560, 300))
		_add_hint("S / DOWN  DROP THROUGH THIN PLATFORMS", Vector2(900, 330))
	dynamic = Node2D.new()
	level_root.add_child(dynamic)
	_spawn_dynamic()
	camera.limit_right = int(world_end)
	camera.limit_top = int(ROOF_Y - 80)
	if backdrop != null:
		backdrop.apply_theme(theme)
	_set_weather(theme)
	shards_total = level_data["crystals"].size()
	_refresh_checkpoints()

func _add_hint(text: String, pos: Vector2) -> void:
	var l := _label(text, 13, Color("#c5d1e6"))
	l.position = pos
	l.modulate.a = 0.75
	level_root.add_child(l)

func _add_roof() -> void:
	# Cave ceiling across the whole level — does not touch the backdrop
	var x0 := -200.0
	var x1 := world_end + 400.0
	var h := 56.0
	roof_body = StaticBody2D.new()
	roof_body.position = Vector2((x0 + x1) * 0.5, ROOF_Y - h * 0.5)
	roof_body.collision_layer = L_SOLID
	roof_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, h)
	cs.shape = rect
	roof_body.add_child(cs)
	level_root.add_child(roof_body)
	# Visual underside of cave rock
	var vis := Node2D.new()
	vis.z_index = -1
	level_root.add_child(vis)
	var w := x1 - x0
	var base := Color("#1a1520")
	var mid := Color("#2a2235")
	var lip := Color("#3a3148")
	# Main mass
	_shape(vis, PackedVector2Array([
		Vector2(x0, ROOF_Y - h), Vector2(x1, ROOF_Y - h),
		Vector2(x1, ROOF_Y), Vector2(x0, ROOF_Y)
	]), base, 0.15, 0.0)
	# Jagged lip
	var jag := PackedVector2Array()
	jag.append(Vector2(x0, ROOF_Y))
	var x := x0
	var r := RandomNumberGenerator.new()
	r.seed = level_seed + 99
	while x < x1:
		jag.append(Vector2(x, ROOF_Y + r.randf_range(2.0, 14.0)))
		x += r.randf_range(18.0, 36.0)
	jag.append(Vector2(x1, ROOF_Y))
	jag.append(Vector2(x1, ROOF_Y - 8.0))
	jag.append(Vector2(x0, ROOF_Y - 8.0))
	_shape(vis, jag, mid, 0.2, 1.2)
	# Stalactites
	x = x0 + 40.0
	while x < x1 - 40.0:
		if r.randf() < 0.45:
			var st_h := r.randf_range(12.0, 34.0)
			var st_w := r.randf_range(4.0, 9.0)
			_shape(vis, PackedVector2Array([
				Vector2(x - st_w, ROOF_Y), Vector2(x, ROOF_Y + st_h), Vector2(x + st_w, ROOF_Y)
			]), lip, 0.25, 1.1)
			if r.randf() < 0.3:
				_glow(vis, Vector2(x, ROOF_Y + st_h * 0.4), 8.0, Color(theme.get("accent", Color("#7ef9ff")).r, theme.get("accent", Color("#7ef9ff")).g, theme.get("accent", Color("#7ef9ff")).b, 0.2))
		x += r.randf_range(40.0, 90.0)

func _add_ground(x0: float, x1: float) -> void:
	var w := x1 - x0
	var h := 220.0
	var gd := GroundDraw.new()
	gd.position = Vector2(x0, GROUND_TOP)
	gd.w = w
	gd.h = h
	gd.th = theme
	gd.seed_v = int(x0) * 13 + (level_seed % 9973)
	level_root.add_child(gd)
	var body := StaticBody2D.new()
	body.position = Vector2(x0 + w * 0.5, GROUND_TOP + h * 0.5)
	body.collision_layer = L_SOLID
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	cs.shape = rect
	body.add_child(cs)
	level_root.add_child(body)

func _add_floating(cx: float, top: float, w: float, crumbly: bool) -> void:
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
	var pd := PlatDraw.new()
	pd.position = Vector2(-w * 0.5, -8.0)
	pd.w = w
	pd.th = theme
	pd.crumbly = crumbly
	pd.seed_v = int(cx) * 7 + (level_seed % 997)
	body.add_child(pd)
	level_root.add_child(body)
	if crumbly:
		hazards.append({"t": "crumble", "body": body, "shape": cs, "base": body.position, "cx": cx, "top": top, "w": w, "state": "solid", "timer": 0.0})

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
	_shape(plat, PackedVector2Array([
		Vector2(-45, -6), Vector2(-40, -8), Vector2(40, -8), Vector2(45, -6),
		Vector2(45, 4), Vector2(38, 8), Vector2(-38, 8), Vector2(-45, 4)
	]), Color("#5b4bc4"), 0.3, 1.6)
	_shape(plat, _pts_rect(Rect2(-40, -8, 80, 3.5)), Color("#7ef9ff"), 0.15, 0.0)
	for i in 5:
		_shape(plat, _pts_ellipse(Vector2(-32.0 + float(i) * 16.0, 0.0), 1.6, 1.6, 6), Color("#c4b5fd"), 0.1, 0.8)
	for sx in [-26.0, 26.0]:
		var gl := _glow(plat, Vector2(sx, 9.0), 14.0, Color(0.5, 0.9, 1.0, 0.8))
		_flicker(gl, 0.8, 9.0)
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
	_shape(node, _pts_rect(Rect2(cx - half - 1.0, GROUND_TOP - 3.0, half * 2.0 + 2.0, 5.0)), Color("#4a5370"), 0.25, 1.2)
	for i in count:
		var x0 := cx - half + float(i) * 16.0
		var ht := 17.0 + float((i * 7) % 4)
		_shape(node, PackedVector2Array([
			Vector2(x0 + 1.0, GROUND_TOP - 2.0), Vector2(x0 + 8.0, GROUND_TOP - ht), Vector2(x0 + 15.0, GROUND_TOP - 2.0)
		]), Color("#c9d3e6"), 0.35, 1.2)
		_line(node, PackedVector2Array([Vector2(x0 + 6.0, GROUND_TOP - 4.0), Vector2(x0 + 8.0, GROUND_TOP - ht + 3.0)]), Color(1, 1, 1, 0.8), 1.2)
		_shape(node, PackedVector2Array([
			Vector2(x0 + 6.0, GROUND_TOP - ht + 5.0), Vector2(x0 + 8.0, GROUND_TOP - ht), Vector2(x0 + 10.0, GROUND_TOP - ht + 5.0)
		]), Color("#ff5d6c"), 0.2, 0.0)
	level_root.add_child(node)
	spike_rects.append(Rect2(cx - half + 2.0, GROUND_TOP - 12.0, half * 2.0 - 4.0, 12.0))

func _add_checkpoint(x: float) -> void:
	var node := Node2D.new()
	node.position = Vector2(x, GROUND_TOP)
	_shape(node, PackedVector2Array([
		Vector2(-14, 0), Vector2(-11, -8), Vector2(11, -8), Vector2(14, 0)
	]), Color("#5a6685"), 0.3, 1.5)
	_shape(node, _pts_rect(Rect2(-3, -64, 6, 56)), Color("#8d9ab8"), 0.3, 1.4)
	var flag := _shape(node, PackedVector2Array([
		Vector2(3, -62), Vector2(16, -60), Vector2(28, -56), Vector2(24, -50), Vector2(29, -45), Vector2(16, -47), Vector2(3, -44)
	]), Color("#6b7a99"), 0.25, 1.3)
	checkpoint_flags.append(flag)
	_shape(node, _pts_ellipse(Vector2(0, -68), 5.0, 5.0, 10), Color("#cdd6ee"), 0.35, 1.3)
	var gl := _glow(node, Vector2(0, -68), 22.0, Color(0.5, 0.55, 0.7, 0.25))
	checkpoint_glows.append(gl)
	level_root.add_child(node)

func _add_exit(locked: bool) -> void:
	exit_node = Node2D.new()
	exit_node.position = Vector2(exit_x, GROUND_TOP)
	var stone := Color("#7a6aa8")
	_shape(exit_node, _pts_rect(Rect2(-34, -112, 14, 112)), stone, 0.3, 1.6)
	_shape(exit_node, _pts_rect(Rect2(20, -112, 14, 112)), stone, 0.3, 1.6)
	_shape(exit_node, PackedVector2Array([
		Vector2(-38, -108), Vector2(-26, -126), Vector2(0, -136), Vector2(26, -126), Vector2(38, -108), Vector2(22, -108), Vector2(0, -118), Vector2(-22, -108)
	]), stone.lightened(0.1), 0.3, 1.6)
	_shape(exit_node, _pts_rect(Rect2(-20, -108, 40, 108)), Color("#1a1f38"), 0.2, 0.0)
	for i in 4:
		var ry := -90.0 + float(i) * 22.0
		_line(exit_node, PackedVector2Array([Vector2(-27, ry), Vector2(-27, ry + 8.0)]), Color("#c4b5fd"), 2.0)
		_line(exit_node, PackedVector2Array([Vector2(27, ry), Vector2(27, ry + 8.0)]), Color("#c4b5fd"), 2.0)
	exit_swirl = _shape(exit_node, PackedVector2Array([
		Vector2(0, -26), Vector2(8, -8), Vector2(26, 0), Vector2(8, 8), Vector2(0, 26), Vector2(-8, 8), Vector2(-26, 0), Vector2(-8, -8)
	]), Color("#c4b5fd"), 0.1, 0.0)
	exit_swirl.position = Vector2(0, -56)
	exit_swirl.modulate.a = 0.85
	var inner := _shape(exit_swirl, PackedVector2Array([
		Vector2(0, -15), Vector2(5, -5), Vector2(15, 0), Vector2(5, 5), Vector2(0, 15), Vector2(-5, 5), Vector2(-15, 0), Vector2(-5, -5)
	]), Color("#ffffff"), 0.0, 0.0)
	exit_extra.append(inner)
	var gl := _glow(exit_node, Vector2(0, -56), 60.0, Color(0.7, 0.55, 1.0, 0.8))
	_flicker(gl, 0.9, 3.0)
	exit_node.modulate = Color(0.45, 0.45, 0.55) if locked else Color.WHITE
	level_root.add_child(exit_node)

func _segment_at(x: float) -> Vector2:
	for seg in ground_segs:
		if x >= seg[0] and x <= seg[1]:
			return Vector2(seg[0], seg[1])
	return Vector2(x - 100.0, x + 100.0)

# ─────────────────────────────── Scenery props ───────────────────────────────
func _add_props(pr: RandomNumberGenerator) -> void:
	var style: String = theme["props"]
	var kinds: Array = []
	match style:
		"forest":
			kinds = ["tree", "tree", "mushroom", "torch", "rock", "tree"]
		"pine":
			kinds = ["pine", "pine", "rock", "torch", "crystal", "pine"]
		"ruins":
			kinds = ["arch", "pillar", "statue", "torch", "banner", "rock"]
		"crystal":
			kinds = ["crystal", "crystal", "mushroom", "rock", "torch", "crystal"]
		_:
			kinds = ["rock", "bones", "deadtree", "torch", "banner", "deadtree"]
	for seg in ground_segs:
		var x: float = float(seg[0]) + pr.randf_range(60.0, 120.0)
		while x < float(seg[1]) - 50.0:
			if x > 260.0 or float(seg[0]) > 0.0:
				var k: String = kinds[pr.randi() % kinds.size()]
				var pn := PropDraw.new()
				pn.kind = k
				pn.th = theme
				pn.seed_v = int(x) * 31 + (level_seed % 1013)
				pn.position = Vector2(x, GROUND_TOP + 2.0)
				pn.z_index = -2
				var sc := pr.randf_range(0.8, 1.35)
				pn.scale = Vector2(sc * (1.0 if pr.randf() < 0.5 else -1.0), sc)
				level_root.add_child(pn)
				if k == "torch":
					var gl := _glow(pn, Vector2(0, -52), 34.0, Color(1.0, 0.65, 0.25, 0.7))
					_flicker(gl, 0.9, 11.0)
				elif k == "crystal":
					var gl2 := _glow(pn, Vector2(0, -26), 40.0, Color(theme["accent"].r, theme["accent"].g, theme["accent"].b, 0.45))
					_flicker(gl2, 0.8, 2.0)
				elif k == "mushroom":
					var gl3 := _glow(pn, Vector2(0, -30), 30.0, Color(theme["accent"].r, theme["accent"].g, theme["accent"].b, 0.4))
					_flicker(gl3, 0.8, 1.5)
			x += pr.randf_range(95.0, 190.0)
		# Foreground grass tufts / rocks (drawn in front of the hero for depth)
		var fx: float = float(seg[0]) + pr.randf_range(30.0, 90.0)
		while fx < float(seg[1]) - 30.0:
			var tf := PropDraw.new()
			tf.kind = "tuft"
			tf.th = theme
			tf.seed_v = int(fx) * 17
			tf.position = Vector2(fx, GROUND_TOP + 6.0)
			tf.z_index = 4
			level_root.add_child(tf)
			fx += pr.randf_range(150.0, 320.0)

func _set_weather(th: Dictionary) -> void:
	for c in weather_layer.get_children():
		c.queue_free()
	var kind: String = th["weather"]
	var accent: Color = th["accent"]
	var p := CPUParticles2D.new()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.amount = 12 if low_power_mode else 90
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.position = Vector2(480, 270)
	p.emission_rect_extents = Vector2(500, 280)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 25.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	var col := accent
	match kind:
		"snow":
			p.position = Vector2(480, -10)
			p.emission_rect_extents = Vector2(520, 4)
			p.direction = Vector2(0.25, 1)
			p.spread = 15.0
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 70.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.5
			p.amount = 38 if low_power_mode else 140
			col = Color(1, 1, 1)
		"embers":
			p.position = Vector2(480, 550)
			p.emission_rect_extents = Vector2(520, 4)
			p.direction = Vector2(0.3, -1)
			p.spread = 25.0
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 120.0
			p.gravity = Vector2(0, -15)
			col = Color(1.0, 0.6, 0.25)
		"ash":
			p.position = Vector2(480, -10)
			p.emission_rect_extents = Vector2(520, 4)
			p.direction = Vector2(0.5, 1)
			p.spread = 25.0
			p.initial_velocity_min = 20.0
			p.initial_velocity_max = 45.0
			p.scale_amount_max = 2.5
			col = Color(0.8, 0.8, 0.8)
		"petals":
			p.position = Vector2(480, -10)
			p.emission_rect_extents = Vector2(520, 4)
			p.direction = Vector2(0.6, 1)
			p.spread = 30.0
			p.initial_velocity_min = 25.0
			p.initial_velocity_max = 55.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
		"bubbles":
			p.direction = Vector2(0, -1)
			p.spread = 20.0
			p.initial_velocity_min = 15.0
			p.initial_velocity_max = 40.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 5.0
		"sparks":
			p.lifetime = 2.0
			p.preprocess = 2.0
			p.amount = 24 if low_power_mode else 60
			p.initial_velocity_min = 20.0
			p.initial_velocity_max = 80.0
			col = accent.lightened(0.4)
	p.color = col
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	p.color_ramp = g
	weather_layer.add_child(p)
	p.emitting = true

# ─────────────────────────────── Trap construction ───────────────────────────────
func _add_hazard(h: Dictionary) -> void:
	match String(h["t"]):
		"saw":
			_add_saw(h)
		"flame":
			_add_flame(h)
		"laser":
			_add_laser(h)
		"pendulum":
			_add_pendulum(h)
		"rock":
			_add_rocktrap(h)
		"spring":
			_add_spring(h)

func _add_saw(h: Dictionary) -> void:
	var x: float = h["x"]
	var rg: float = h["range"]
	var track := Node2D.new()
	level_root.add_child(track)
	_shape(track, _pts_rect(Rect2(x - rg - 20.0, GROUND_TOP - 3.0, rg * 2.0 + 40.0, 4.0)), Color("#2a3148"), 0.3, 1.0)
	for i in int((rg * 2.0 + 40.0) / 10.0):
		_line(track, PackedVector2Array([Vector2(x - rg - 18.0 + float(i) * 10.0, GROUND_TOP - 2.5), Vector2(x - rg - 18.0 + float(i) * 10.0, GROUND_TOP)]), Color("#566082"), 1.0)
	var node := Node2D.new()
	node.position = Vector2(x, GROUND_TOP - 12.0)
	node.z_index = 1
	var blade := SawDraw.new()
	node.add_child(blade)
	var gl := _glow(node, Vector2.ZERO, 30.0, Color(1.0, 0.35, 0.35, 0.35))
	_flicker(gl, 0.8, 8.0)
	level_root.add_child(node)
	hazards.append({"t": "saw", "node": node, "blade": blade, "x": x, "range": rg, "speed": h["speed"], "phase": h["phase"], "spark": 0.0})

func _flame_pts(w: float, ht: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-w, 0), Vector2(-w * 0.9, -ht * 0.35), Vector2(-w * 0.45, -ht * 0.7), Vector2(0, -ht),
		Vector2(w * 0.35, -ht * 0.65), Vector2(w * 0.9, -ht * 0.3), Vector2(w, 0)
	])

func _add_flame(h: Dictionary) -> void:
	var node := Node2D.new()
	node.position = Vector2(float(h["x"]), GROUND_TOP)
	_shape(node, PackedVector2Array([Vector2(-16, 1), Vector2(-13, -5), Vector2(13, -5), Vector2(16, 1)]), Color("#3a3f55"), 0.3, 1.4)
	for i in 5:
		_line(node, PackedVector2Array([Vector2(-9.0 + float(i) * 4.5, -4.5), Vector2(-9.0 + float(i) * 4.5, -1.0)]), Color("#ff7a30"), 1.4)
	var fire := Node2D.new()
	fire.position = Vector2(0, -4)
	fire.z_index = 2
	node.add_child(fire)
	_shape(fire, _flame_pts(13.0, 100.0), Color("#ff6a1f"), 0.2, 0.0)
	_shape(fire, _flame_pts(8.5, 78.0), Color("#ffb22e"), 0.2, 0.0)
	_shape(fire, _flame_pts(4.5, 52.0), Color("#fff3b0"), 0.1, 0.0)
	var gl := _glow(node, Vector2(0, -6), 40.0, Color(1.0, 0.5, 0.15, 0.0))
	var embers := CPUParticles2D.new()
	embers.position = Vector2(0, -8)
	embers.amount = 5 if low_power_mode else 18
	embers.lifetime = 0.9
	embers.direction = Vector2(0, -1)
	embers.spread = 25.0
	embers.initial_velocity_min = 60.0
	embers.initial_velocity_max = 160.0
	embers.gravity = Vector2(0, 100)
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 3.0
	embers.color = Color(1.0, 0.7, 0.2)
	embers.emitting = false
	node.add_child(embers)
	level_root.add_child(node)
	hazards.append({"t": "flame", "node": node, "fire": fire, "glow": gl, "embers": embers, "x": h["x"], "phase": h["phase"], "int": 0.0})

func _add_laser(h: Dictionary) -> void:
	var x1: float = h["x1"]
	var x2: float = h["x2"]
	var y: float = h["y"]
	var node := Node2D.new()
	level_root.add_child(node)
	var orbs: Array = []
	for px in [x1, x2]:
		_shape(node, PackedVector2Array([Vector2(px - 12.0, GROUND_TOP), Vector2(px - 8.0, GROUND_TOP - 10.0), Vector2(px + 8.0, GROUND_TOP - 10.0), Vector2(px + 12.0, GROUND_TOP)]), Color("#3a3f55"), 0.3, 1.4)
		_shape(node, _pts_rect(Rect2(px - 4.0, y - 8.0, 8.0, GROUND_TOP - y - 2.0)), Color("#566082"), 0.3, 1.4)
		var orb := _shape(node, _pts_ellipse(Vector2(px, y), 6.0, 6.0, 12), Color("#ff5d6c"), 0.3, 1.4)
		orbs.append(orb)
	var warn := _line(node, PackedVector2Array([Vector2(x1, y), Vector2(x2, y)]), Color(1, 0.4, 0.45, 0.25), 1.0)
	var beam := _line(node, PackedVector2Array([Vector2(x1, y), Vector2(x2, y)]), Color(1, 0.9, 0.9), 3.0)
	var beam_glow := _line(node, PackedVector2Array([Vector2(x1, y), Vector2(x2, y)]), Color(1, 0.25, 0.3, 0.5), 12.0)
	beam_glow.material = mat_add
	beam.z_index = 2
	beam_glow.z_index = 2
	beam.visible = false
	beam_glow.visible = false
	hazards.append({"t": "laser", "node": node, "beam": beam, "beam_glow": beam_glow, "warn": warn, "orbs": orbs, "x1": x1, "x2": x2, "y": y, "phase": h["phase"], "on": false})

func _add_pendulum(h: Dictionary) -> void:
	var x: float = h["x"]
	var ln: float = h["len"]
	var mount := Node2D.new()
	mount.position = Vector2(x, 20.0)
	mount.z_index = 1
	level_root.add_child(mount)
	_shape(mount, PackedVector2Array([Vector2(-18, -14), Vector2(18, -14), Vector2(22, 4), Vector2(0, 12), Vector2(-22, 4)]), Color("#4a5370"), 0.3, 1.6)
	for bx in [-12.0, 12.0]:
		_shape(mount, _pts_ellipse(Vector2(bx, -4.0), 2.2, 2.2, 8), Color("#c9d3e6"), 0.3, 1.0)
	var swing := _joint(mount, Vector2(0, 4))
	var links := int(ln / 9.0)
	for i in links:
		var lk := _shape(swing, _pts_ellipse(Vector2(0, 6.0 + float(i) * 9.0), 2.6, 4.6, 8), Color("#8d9ab8"), 0.3, 1.0)
		lk.rotation = 0.0
	var head := _joint(swing, Vector2(0, ln))
	_shape(head, PackedVector2Array([
		Vector2(0, -10), Vector2(6, -6), Vector2(26, -20), Vector2(32, 0), Vector2(26, 20), Vector2(6, 6),
		Vector2(0, 10), Vector2(-6, 6), Vector2(-26, 20), Vector2(-32, 0), Vector2(-26, -20), Vector2(-6, -6)
	]), Color("#aab8d8"), 0.35, 1.8)
	_line(head, PackedVector2Array([Vector2(26, -18), Vector2(30, 0), Vector2(26, 18)]), Color(1, 0.4, 0.45), 2.0)
	_line(head, PackedVector2Array([Vector2(-26, -18), Vector2(-30, 0), Vector2(-26, 18)]), Color(1, 0.4, 0.45), 2.0)
	_shape(head, _pts_ellipse(Vector2.ZERO, 6.5, 6.5, 12), Color("#6f7fa6"), 0.3, 1.4)
	var gl := _glow(head, Vector2.ZERO, 40.0, Color(1.0, 0.4, 0.45, 0.35))
	_flicker(gl, 0.8, 6.0)
	hazards.append({"t": "pendulum", "swing": swing, "head": head, "x": x, "len": ln, "amp": h["amp"], "period": h["period"], "phase": h["phase"]})

func _add_rocktrap(h: Dictionary) -> void:
	var x: float = h["x"]
	var node := Node2D.new()
	node.position = Vector2(x, 26.0)
	node.z_index = 1
	level_root.add_child(node)
	_shape(node, PackedVector2Array([
		Vector2(-18, -14), Vector2(-6, -22), Vector2(10, -20), Vector2(20, -8), Vector2(18, 8), Vector2(6, 16), Vector2(-12, 14), Vector2(-20, 2)
	]), Color("#6a6f85"), 0.35, 1.8)
	_line(node, PackedVector2Array([Vector2(-8, -16), Vector2(-2, -4), Vector2(-8, 6)]), Color("#2a2f44"), 1.5)
	_line(node, PackedVector2Array([Vector2(6, -14), Vector2(10, -2), Vector2(4, 8)]), Color("#2a2f44"), 1.5)
	var cr := _glow(node, Vector2(0, -2), 26.0, Color(1.0, 0.45, 0.2, 0.5))
	_flicker(cr, 0.8, 5.0)
	var mark := _shape(level_root, _pts_ellipse(Vector2(x, GROUND_TOP - 1.0), 18.0, 3.5, 12), Color(1, 0.2, 0.2, 0.0), 0.0, 0.0)
	hazards.append({"t": "rock", "node": node, "mark": mark, "x": x, "state": "armed", "timer": 0.0, "vy": 0.0, "y0": 26.0})

func _add_spring(h: Dictionary) -> void:
	var x: float = h["x"]
	var node := Node2D.new()
	node.position = Vector2(x, GROUND_TOP)
	_shape(node, PackedVector2Array([Vector2(-14, 0), Vector2(-11, -5), Vector2(11, -5), Vector2(14, 0)]), Color("#5b4bc4"), 0.3, 1.5)
	var pad := _joint(node, Vector2(0, -5))
	var coil := PackedVector2Array()
	for i in 9:
		coil.append(Vector2(-8.0 if i % 2 == 0 else 8.0, -float(i) * 1.7))
	_line(pad, coil, Color("#c9d3e6"), 2.0)
	var plate := _joint(pad, Vector2(0, -15))
	_shape(plate, PackedVector2Array([Vector2(-15, 0), Vector2(-12, -5), Vector2(12, -5), Vector2(15, 0)]), Color("#7ef9ff"), 0.3, 1.5)
	var gl := _glow(node, Vector2(0, -10), 26.0, Color(0.4, 0.9, 1.0, 0.45))
	_flicker(gl, 0.7, 4.0)
	level_root.add_child(node)
	hazards.append({"t": "spring", "node": node, "pad": pad, "x": x, "anim": 0.0})


# ─────────────────────────────── Hero ───────────────────────────────
func _make_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = L_PLAYER
	player.collision_mask = L_SOLID | L_ONEWAY
	player.floor_snap_length = 6.0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20.0, 32.0)
	cs.shape = rect
	player.add_child(cs)
	player_visual = Node2D.new()
	player.add_child(player_visual)
	_build_hero_rig()
	world.add_child(player)
	shadow = Polygon2D.new()
	shadow.polygon = _pts_ellipse(Vector2.ZERO, 11.0, 3.0, 14)
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.z_index = -1
	world.add_child(shadow)

func _hero_boot(shin: Node2D, col: Color, gold: Color) -> void:
	_shape(shin, PackedVector2Array([
		Vector2(-2.9, 2.4), Vector2(2.9, 2.4), Vector2(3.3, 4.0), Vector2(7.0, 4.6), Vector2(7.3, 5.5), Vector2(-3.3, 5.5)
	]), col, 0.3, 1.3)
	_shape(shin, _pts_rect(Rect2(-3.1, 1.7, 6.2, 1.5)), gold, 0.2, 1.0)

func _build_hero_rig() -> void:
	var skin := Color("#f4c9a1")
	var hair_c := Color("#7a4a2e")
	var steel := Color("#aab8d8")
	var steel_d := Color("#6f7fa6")
	var tunic := Color("#3f6fd8")
	var gold := Color("#f3c969")
	var pants := Color("#2b3866")
	var boot_c := Color("#6b4226")
	var cyan := Color("#7ef9ff")
	var cape_c := Color("#b02a4a")
	var body := _joint(player_visual, Vector2.ZERO)
	rig["body"] = body
	# ── back leg
	var tb := _joint(body, Vector2(-2.0, 6.0))
	_shape(tb, _pts_rect(Rect2(-2.6, -1.0, 5.2, 5.8)), pants.darkened(0.3), 0.25, 1.3)
	var sb := _joint(tb, Vector2(0.0, 4.5))
	_shape(sb, _pts_rect(Rect2(-2.3, -1.0, 4.6, 4.0)), pants.darkened(0.3), 0.25, 1.3)
	_hero_boot(sb, boot_c.darkened(0.3), gold.darkened(0.3))
	rig["thigh_b"] = tb
	rig["shin_b"] = sb
	# ── torso (leans from the hips)
	var torso := _joint(body, Vector2(0.0, 6.0))
	rig["torso"] = torso
	var cparent: Node2D = torso
	var cpos := Vector2(-3.5, -9.0)
	for i in 3:
		var cj := _joint(cparent, cpos)
		_shape(cj, PackedVector2Array([Vector2(-3.5, -0.5), Vector2(3.5, -0.5), Vector2(4.4, 6.8), Vector2(-4.4, 6.8)]), cape_c.darkened(0.1 * float(i)), 0.3, 1.3)
		if i == 2:
			_line(cj, PackedVector2Array([Vector2(-4.2, 6.2), Vector2(4.2, 6.2)]), gold, 1.3)
		cape_nodes.append(cj)
		cparent = cj
		cpos = Vector2(0.0, 6.5)
	# back arm
	var ab1 := _joint(torso, Vector2(-1.5, -8.0))
	_shape(ab1, _pts_rect(Rect2(-2.0, -1.0, 4.0, 5.6)), tunic.darkened(0.3), 0.25, 1.2)
	var ab2 := _joint(ab1, Vector2(0.0, 4.5))
	_shape(ab2, _pts_rect(Rect2(-1.9, -0.5, 3.8, 4.4)), steel_d.darkened(0.2), 0.25, 1.2)
	_shape(ab2, _pts_ellipse(Vector2(0.0, 4.4), 1.9, 1.9, 8), skin.darkened(0.2), 0.2, 1.0)
	_shape(ab1, _pts_ellipse(Vector2.ZERO, 3.2, 2.6, 10), steel_d, 0.3, 1.2)
	rig["arm_b1"] = ab1
	rig["arm_b2"] = ab2
	# chest
	_shape(torso, PackedVector2Array([
		Vector2(-6.2, -10.0), Vector2(6.2, -10.0), Vector2(5.6, -4.5), Vector2(4.8, 0.6), Vector2(-4.8, 0.6), Vector2(-5.6, -4.5)
	]), tunic, 0.3, 1.5)
	_shape(torso, PackedVector2Array([Vector2(-5.0, -9.6), Vector2(5.0, -9.6), Vector2(4.4, -3.8), Vector2(-4.4, -3.8)]), steel, 0.3, 1.2)
	_shape(torso, _pts_rect(Rect2(-3.2, -10.8, 6.4, 2.0)), gold, 0.2, 1.2)
	_shape(torso, PackedVector2Array([Vector2(0, -8.4), Vector2(1.8, -6.4), Vector2(0, -4.4), Vector2(-1.8, -6.4)]), cyan, 0.2, 0.9)
	rig["gem_glow"] = _glow(torso, Vector2(0, -6.4), 10.0, Color(0.5, 0.95, 1.0, 0.7))
	_shape(torso, _pts_rect(Rect2(-5.4, -1.6, 10.8, 2.4)), gold.darkened(0.15), 0.3, 1.2)
	_shape(torso, _pts_ellipse(Vector2(1.8, -0.4), 1.3, 1.3, 8), steel, 0.3, 0.9)
	_shape(torso, PackedVector2Array([Vector2(-5.0, 0.6), Vector2(-0.5, 0.6), Vector2(-1.2, 4.8), Vector2(-5.4, 4.2)]), steel_d, 0.3, 1.1)
	_shape(torso, PackedVector2Array([Vector2(0.5, 0.6), Vector2(4.8, 0.6), Vector2(5.2, 4.2), Vector2(1.0, 4.8)]), steel_d, 0.3, 1.1)
	# ── head
	var head := _joint(torso, Vector2(0.0, -10.0))
	rig["head"] = head
	_shape(head, PackedVector2Array([
		Vector2(-7, -1), Vector2(-9.6, -6), Vector2(-8.6, -10), Vector2(-10.4, -14.5), Vector2(-6, -13.5), Vector2(-5, -17),
		Vector2(-1, -15), Vector2(2.5, -17.5), Vector2(4, -14.5), Vector2(7, -14), Vector2(7, -8), Vector2(5, -1)
	]), hair_c.darkened(0.15), 0.3, 1.4)
	_shape(head, PackedVector2Array([
		Vector2(-5.6, -12.2), Vector2(5.4, -12.2), Vector2(6.3, -6.5), Vector2(5.6, -2.0), Vector2(2.4, 0.2), Vector2(-3.4, 0.2), Vector2(-6.0, -3.5)
	]), skin, 0.18, 1.4)
	_shape(head, _pts_ellipse(Vector2(-2.0, -5.2), 1.4, 2.0, 8), skin.darkened(0.12), 0.2, 0.9)
	_shape(head, PackedVector2Array([
		Vector2(-6.6, -13.2), Vector2(6.6, -13.2), Vector2(7.0, -9.2), Vector2(4.6, -11.2), Vector2(2.6, -8.4),
		Vector2(0.2, -11.0), Vector2(-3.0, -9.4), Vector2(-5.2, -11.4), Vector2(-6.8, -8.6)
	]), hair_c, 0.3, 1.3)
	_shape(head, _pts_rect(Rect2(-6.6, -8.4, 13.2, 1.8)), cyan, 0.2, 1.0)
	var tp: Node2D = head
	var tpos := Vector2(-6.4, -7.5)
	for i in 3:
		var tj := _joint(tp, tpos)
		_shape(tj, _pts_rect(Rect2(-5.0, -1.2, 5.0, 2.4)), cyan.darkened(0.12 * float(i)), 0.2, 0.9)
		tail_nodes.append(tj)
		tp = tj
		tpos = Vector2(-5.0, 0.0)
	var eye := _joint(head, Vector2(3.4, -5.4))
	_shape(eye, PackedVector2Array([Vector2(-2.6, 0.2), Vector2(-1.2, -1.8), Vector2(1.6, -2.0), Vector2(2.8, 0.0), Vector2(1.4, 1.8), Vector2(-1.2, 1.8)]), Color.WHITE, 0.0, 0.9)
	_shape(eye, _pts_ellipse(Vector2(0.5, 0.0), 1.7, 1.7, 10), Color("#2f8fe0"), 0.3, 0.0)
	_shape(eye, _pts_ellipse(Vector2(0.7, 0.0), 0.9, 0.9, 8), OUT, 0.0, 0.0)
	_shape(eye, _pts_ellipse(Vector2(1.3, -0.7), 0.45, 0.45, 6), Color.WHITE, 0.0, 0.0)
	rig["eye"] = eye
	_line(head, PackedVector2Array([Vector2(1.2, -8.0), Vector2(5.2, -7.4)]), hair_c.darkened(0.3), 1.3)
	_line(head, PackedVector2Array([Vector2(6.2, -4.6), Vector2(6.8, -3.0), Vector2(5.6, -3.0)]), skin.darkened(0.3), 1.0)
	_line(head, PackedVector2Array([Vector2(3.2, -1.6), Vector2(5.0, -1.8)]), Color("#a05050"), 1.0)
	# ── front leg
	var tf := _joint(body, Vector2(2.0, 6.0))
	_shape(tf, _pts_rect(Rect2(-2.6, -1.0, 5.2, 5.8)), pants, 0.25, 1.3)
	_shape(tf, _pts_ellipse(Vector2(0.8, 4.4), 2.6, 2.2, 8), steel, 0.3, 1.0)
	var sf := _joint(tf, Vector2(0.0, 4.5))
	_shape(sf, _pts_rect(Rect2(-2.3, -1.0, 4.6, 4.0)), pants, 0.25, 1.3)
	_shape(sf, _pts_rect(Rect2(-2.5, 0.0, 5.0, 2.4)), steel, 0.3, 1.0)
	_hero_boot(sf, boot_c, gold)
	rig["thigh_f"] = tf
	rig["shin_f"] = sf
	# ── front arm + sword
	var af1 := _joint(torso, Vector2(1.5, -8.0))
	_shape(af1, _pts_rect(Rect2(-2.1, -1.0, 4.2, 5.6)), tunic, 0.25, 1.3)
	var af2 := _joint(af1, Vector2(0.0, 4.5))
	_shape(af2, _pts_rect(Rect2(-2.0, -0.5, 4.0, 4.4)), steel, 0.3, 1.3)
	_shape(af2, _pts_rect(Rect2(-2.0, 1.4, 4.0, 1.0)), gold, 0.1, 0.0)
	_shape(af2, _pts_ellipse(Vector2(0, 4.4), 2.1, 2.1, 8), skin, 0.2, 1.1)
	_shape(af1, _pts_ellipse(Vector2.ZERO, 3.6, 2.9, 10), steel, 0.35, 1.4)
	_shape(af1, _pts_ellipse(Vector2(0.0, -1.2), 1.0, 1.0, 6), gold, 0.1, 0.0)
	rig["arm_f1"] = af1
	rig["arm_f2"] = af2
	var sword := _joint(af2, Vector2(0.0, 4.4))
	rig["sword"] = sword
	var sglow := _glow(sword, Vector2(17.0, 0.0), 26.0, Color(0.5, 0.95, 1.0, 0.18))
	rig["glow"] = sglow
	_shape(sword, PackedVector2Array([Vector2(2, -2.8), Vector2(28, -2.4), Vector2(35, 0), Vector2(28, 2.4), Vector2(2, 2.8)]), Color("#e8f0ff"), 0.3, 1.5)
	_line(sword, PackedVector2Array([Vector2(4, 0), Vector2(29, 0)]), Color("#8fa4d4"), 1.2)
	_line(sword, PackedVector2Array([Vector2(3, -2.0), Vector2(28, -1.7)]), Color(1, 1, 1, 0.9), 1.0)
	_shape(sword, PackedVector2Array([
		Vector2(-1.5, -7.5), Vector2(2.2, -5.2), Vector2(2.8, -2.6), Vector2(2.8, 2.6), Vector2(2.2, 5.2), Vector2(-1.5, 7.5), Vector2(-0.8, 3.0), Vector2(-0.8, -3.0)
	]), gold, 0.3, 1.4)
	_shape(sword, _pts_ellipse(Vector2(0.9, 0.0), 1.3, 1.3, 8), cyan, 0.2, 0.0)
	_shape(sword, _pts_rect(Rect2(-8.0, -1.7, 7.0, 3.4)), boot_c, 0.3, 1.2)
	for i in 3:
		_line(sword, PackedVector2Array([Vector2(-7.0 + float(i) * 2.2, -1.6), Vector2(-6.2 + float(i) * 2.2, 1.6)]), Color("#3a2414"), 1.0)
	_shape(sword, _pts_ellipse(Vector2(-9.6, 0.0), 2.5, 2.5, 8), gold, 0.3, 1.2)
	# Grapple launcher on front arm (replaces bow)
	bow_node = Node2D.new()
	bow_node.name = "GrappleGun"
	bow_node.position = Vector2(2, 4)
	bow_node.z_index = 3
	bow_node.visible = false
	rig["arm_f2"].add_child(bow_node)
	# Launcher body
	_shape(bow_node, _pts_rect(Rect2(-2, -3, 10, 6)), Color("#6f7fa6"), 0.3, 1.2)
	_shape(bow_node, _pts_rect(Rect2(6, -2, 5, 4)), Color("#aab8d8"), 0.25, 1.0)
	_shape(bow_node, _pts_ellipse(Vector2(0, 0), 2.0, 2.0, 8), Color("#3a2414"), 0.2, 1.0)
	_shape(bow_node, _pts_ellipse(Vector2(1, 0), 1.0, 1.0, 6), Color("#7ef9ff"), 0.15, 0.0)
	_glow(bow_node, Vector2(8, 0), 8.0, Color(0.5, 0.9, 1.0, 0.4))
	# Rope line (world-space, added to world later; placeholder child)
	string_line = _line(bow_node, PackedVector2Array([Vector2(10, 0), Vector2(10, 0)]), Color("#c9d3e6"), 1.6)
	string_line.visible = false
	# Hook tip visual (child, hidden until fired — actual hook is world node)
	nocked_arrow = Node2D.new()
	nocked_arrow.visible = false
	bow_node.add_child(nocked_arrow)
	_shape(nocked_arrow, PackedVector2Array([
		Vector2(0, -3), Vector2(6, 0), Vector2(0, 3), Vector2(2, 0)
	]), Color("#e8f0ff"), 0.3, 1.1)
	_shape(nocked_arrow, PackedVector2Array([Vector2(5, -2), Vector2(9, 0), Vector2(5, 2)]), Color("#ff5d6c"), 0.2, 0.0)

func _animate_player(delta: float) -> void:
	var on_floor := player.is_on_floor()
	var vx := player.velocity.x
	var vy := player.velocity.y
	var target_sq := Vector2.ONE
	if not on_floor:
		var k := clampf(absf(vy) / 700.0, 0.0, 1.0)
		target_sq = Vector2(1.0 - 0.12 * k, 1.0 + 0.16 * k)
	squash = squash.lerp(target_sq, minf(1.0, delta * 14.0))
	var t := anim_time
	var tg := {
		"lean": 0.02 + sin(t * 2.0) * 0.02, "head": 0.0,
		"thigh_f": 0.08, "shin_f": 0.0, "thigh_b": -0.1, "shin_b": 0.05,
		"arm_f1": -0.35, "arm_f2": -0.6, "arm_b1": 0.15, "arm_b2": 0.25,
		"blade": -0.9, "bob": sin(t * 2.0) * 0.6
	}
	var rate := 16.0
	if not on_floor:
		if vy < 0.0:
			tg["thigh_f"] = -0.7; tg["shin_f"] = 1.0; tg["thigh_b"] = 0.5; tg["shin_b"] = 0.9
			tg["lean"] = 0.08; tg["arm_f1"] = -2.3; tg["arm_f2"] = -0.2; tg["arm_b1"] = -1.6; tg["arm_b2"] = 0.2
			tg["blade"] = -1.3
		else:
			tg["thigh_f"] = -0.25; tg["shin_f"] = 0.4; tg["thigh_b"] = 0.35; tg["shin_b"] = 0.5
			tg["lean"] = 0.0; tg["arm_f1"] = -1.2; tg["arm_f2"] = -0.3; tg["arm_b1"] = 1.2; tg["arm_b2"] = 0.2
			tg["blade"] = -0.4
	elif absf(vx) > 20.0:
		run_anim += delta * (9.0 + absf(vx) * 0.032)
		var p := run_anim
		tg["thigh_f"] = sin(p) * 0.85
		tg["thigh_b"] = sin(p + PI) * 0.85
		tg["shin_f"] = (0.5 + 0.5 * sin(p - 1.4)) * 1.1
		tg["shin_b"] = (0.5 + 0.5 * sin(p + PI - 1.4)) * 1.1
		tg["lean"] = 0.18
		tg["bob"] = -absf(sin(p)) * 1.6
		tg["arm_f1"] = -0.5 + sin(p) * 0.15
		tg["arm_f2"] = -0.8
		tg["blade"] = -0.7 + sin(p * 2.0) * 0.05
		tg["arm_b1"] = -sin(p) * 0.8 + 0.1
		tg["arm_b2"] = 0.4
		rate = 22.0
		dust_t -= delta
		if dust_t <= 0.0 and state == State.PLAYING:
			dust_t = 0.17
			_burst(player.global_position + Vector2(-facing * 4.0, 16.0), Color(theme.get("grass", Color.WHITE)).lightened(0.2), 2, 35.0, 0.3)
	else:
		run_anim = 0.0
	if hurt_stun > 0.0:
		tg["lean"] = -0.35; tg["arm_f1"] = -1.0; tg["arm_f2"] = -0.2; tg["arm_b1"] = 1.0
		tg["thigh_f"] = -0.3; tg["thigh_b"] = 0.3; tg["blade"] = -0.3
	if dash_time > 0.0:
		tg["lean"] = 0.55; tg["thigh_f"] = 0.7; tg["shin_f"] = 0.4; tg["thigh_b"] = 1.1; tg["shin_b"] = 0.2
		tg["arm_f1"] = -1.5; tg["arm_f2"] = 0.0; tg["arm_b1"] = 1.2; tg["arm_b2"] = 0.1; tg["blade"] = -0.05
		rate = 40.0
	if attack_t >= 0.0:
		var st: Array = ATTACK_STYLES[attack_style]
		var s0: float = st[0]
		var s1: float = st[1]
		var p2 := clampf(attack_t / float(st[5]), 0.0, 1.0)
		var b := s1
		if p2 < 0.2:
			b = s0 - (s1 - s0) * 0.06 * (p2 / 0.2)
		elif p2 < 0.62:
			var u := (p2 - 0.2) / 0.42
			u = 1.0 - pow(1.0 - u, 3.0)
			b = lerpf(s0, s1, u)
		tg["arm_f1"] = b - PI * 0.5
		tg["arm_f2"] = -0.15
		tg["blade"] = b
		tg["lean"] = float(tg["lean"]) + (-0.12 if p2 < 0.2 else 0.3)
		rate = 55.0
	# Grapple pose: arms aim upward toward roof when hook is out
	if weapon_mode == "grapple" and dash_time <= 0.0 and attack_t < 0.0:
		if grapple_state == "flying" or grapple_state == "stuck":
			tg["arm_f1"] = -2.2
			tg["arm_f2"] = -0.3
			tg["arm_b1"] = -1.8
			tg["arm_b2"] = 0.2
			tg["lean"] = -0.05
			tg["blade"] = 0.0
			rate = 30.0
		else:
			tg["arm_f1"] = -0.5
			tg["arm_f2"] = -0.4
			tg["arm_b1"] = 0.2
			tg["arm_b2"] = 0.15
			tg["blade"] = 0.0
			rate = 20.0
	var k_rate := minf(1.0, delta * rate)
	for key in tg:
		pose[key] = lerpf(float(pose.get(key, tg[key])), float(tg[key]), k_rate)
	var torso: Node2D = rig["torso"]
	torso.rotation = pose["lean"]
	(rig["head"] as Node2D).rotation = float(pose["head"]) - float(pose["lean"]) * 0.4
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
	(rig["glow"] as Sprite2D).modulate.a = 0.55 if attack_t >= 0.0 else 0.16 + 0.05 * sin(t * 4.0)
	(rig["gem_glow"] as Sprite2D).modulate.a = 0.5 + 0.3 * sin(t * 3.0)
	var spd := clampf(absf(vx) / 250.0, 0.0, 1.0)
	if dash_time > 0.0:
		spd = 1.0
	var cape_total := 0.2 + 0.8 * spd + clampf(vy / 1200.0, -0.25, 0.5)
	for i in cape_nodes.size():
		cape_nodes[i].rotation = cape_total / 3.0 + sin(t * 6.0 + float(i) * 0.9) * 0.12 * (0.5 + spd)
	for i in tail_nodes.size():
		var ang := -0.35 * (1.0 - spd) - 0.05 * spd
		ang += sin(t * 9.0 + float(i) * 0.9) * 0.18 * (0.4 + spd)
		ang += clampf(vy / 900.0, -0.3, 0.3) * 0.4
		tail_nodes[i].rotation = ang
	(rig["eye"] as Node2D).scale.y = 0.1 if fmod(t, 3.4) > 3.28 else 1.0
	player_visual.scale = Vector2(squash.x * facing, squash.y)
	player_visual.position = Vector2(0.0, 16.0 * (1.0 - squash.y))
	if state == State.DEAD:
		return
	if dash_time > 0.0:
		player_visual.visible = true
		player_visual.modulate = Color(0.6, 1.4, 1.5, 0.9)
	elif hurt_stun > 0.0:
		player_visual.visible = true
		player_visual.modulate = Color(1.6, 0.7, 0.7)
	else:
		player_visual.modulate = Color.WHITE
		player_visual.visible = invulnerable <= 0.0 or fmod(anim_time * 16.0, 2.0) < 1.0

func _ghost() -> void:
	var g := player_visual.duplicate() as Node2D
	world.add_child(g)
	g.global_position = player_visual.global_position
	g.modulate = Color(0.5, 1.0, 1.0, 0.5)
	var tw := create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)

# ─────────────────────────────── Camera / backdrop / checkpoints ───────────────────────────────
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
		var on := i <= checkpoint_idx
		checkpoint_flags[i].modulate = Color("#ffe28a") if on else Color.WHITE
		if i < checkpoint_glows.size():
			checkpoint_glows[i].modulate = Color(1.0, 0.85, 0.35, 0.8) if on else Color(0.5, 0.55, 0.7, 0.25)

# ─────────────────────────────── Monsters: rigs ───────────────────────────────
func _enemy_pal() -> Dictionary:
	var t: Array = ENEMY_PALS[rng.randi() % ENEMY_PALS.size()]
	return {"main": Color(String(t[0])), "dark": Color(String(t[1])), "light": Color(String(t[2])), "glow": Color(String(t[3]))}

func _build_crawler(vis: Node2D, p: Dictionary, rg: Dictionary) -> void:
	var main: Color = p["main"]
	var dark: Color = p["dark"]
	var light: Color = p["light"]
	var glow_c: Color = p["glow"]
	var far: Array = []
	for i in 3:
		far.append(_limb(vis, Vector2(-8.0 + 8.0 * float(i), 1.5), 4.5, 4.5, 2.8, dark.darkened(0.3), 2.5))
	rg["far"] = far
	var body := _joint(vis, Vector2.ZERO)
	rg["body"] = body
	_shape(body, _dome(Vector2(0, 1.5), 13.0, 10.5), main, 0.32, 1.7)
	for xo in [-6.5, 0.0, 6.5]:
		_line(body, PackedVector2Array([Vector2(xo, 1.5), Vector2(xo * 1.05, -4.0), Vector2(xo * 0.82, -8.4 + absf(xo) * 0.35)]), dark, 1.2)
	_shape(body, _pts_ellipse(Vector2(-5, -5), 4.0, 2.0, 8), Color(1, 1, 1, 0.35), 0.0, 0.0)
	for xo in [-7.0, -1.0, 5.0]:
		var yb := 1.5 - 10.5 * sqrt(maxf(0.0, 1.0 - pow(xo / 13.0, 2.0)))
		_shape(body, PackedVector2Array([Vector2(xo - 2.6, yb + 1.0), Vector2(xo + 0.6, yb - 6.5), Vector2(xo + 2.6, yb + 1.0)]), light, 0.25, 1.2)
	_shape(body, _pts_rect(Rect2(-13.5, 0.5, 27.0, 3.2)), dark, 0.3, 1.3)
	var head := _joint(vis, Vector2(11.5, 0.5))
	rg["head"] = head
	_shape(head, _pts_ellipse(Vector2.ZERO, 6.2, 5.6, 12), main.lightened(0.08), 0.3, 1.5)
	var mt := _joint(head, Vector2(4.0, 1.5))
	_shape(mt, PackedVector2Array([Vector2(0, -1.3), Vector2(5.5, 0.4), Vector2(0, 1.0)]), light, 0.2, 1.0)
	var mb := _joint(head, Vector2(4.0, 3.2))
	_shape(mb, PackedVector2Array([Vector2(0, -1.0), Vector2(5.0, -0.3), Vector2(0, 1.3)]), light, 0.2, 1.0)
	rg["mand_t"] = mt
	rg["mand_b"] = mb
	var eye := _joint(head, Vector2(1.5, -1.8))
	_shape(eye, _pts_ellipse(Vector2.ZERO, 2.6, 2.6, 10), Color.WHITE, 0.0, 1.0)
	rg["pupil"] = _shape(eye, _pts_ellipse(Vector2.ZERO, 1.3, 1.3, 8), OUT, 0.0, 0.0)
	var gl := _glow(eye, Vector2.ZERO, 9.0, Color(glow_c.r, glow_c.g, glow_c.b, 0.7))
	_flicker(gl, 0.8, 7.0)
	var ant := _joint(head, Vector2(0, -5.0))
	_line(ant, PackedVector2Array([Vector2(0, 0), Vector2(2, -5), Vector2(1, -9)]), dark, 1.3)
	_shape(ant, _pts_ellipse(Vector2(1, -9.5), 1.4, 1.4, 6), glow_c, 0.1, 0.8)
	rg["ant"] = ant
	var near: Array = []
	for i in 3:
		near.append(_limb(vis, Vector2(-9.0 + 8.0 * float(i), 2.0), 4.5, 4.5, 3.2, dark, 3.0))
	rg["near"] = near

func _bat_wing(j: Node2D, col: Color, bone: Color) -> void:
	_shape(j, PackedVector2Array([
		Vector2(0, -1), Vector2(-8, -3), Vector2(-15, -1), Vector2(-13, 3), Vector2(-14.5, 7), Vector2(-10, 5),
		Vector2(-9, 10), Vector2(-5, 5.5), Vector2(-2, 4.5), Vector2(0, 2)
	]), col, 0.3, 1.2)
	_line(j, PackedVector2Array([Vector2(0, 0), Vector2(-8, -2.5), Vector2(-15, -1)]), bone, 1.6)
	_line(j, PackedVector2Array([Vector2(-8, -2.5), Vector2(-14, 6.5)]), bone, 1.2)
	_line(j, PackedVector2Array([Vector2(-8, -2.5), Vector2(-9, 9.5)]), bone, 1.2)
	_line(j, PackedVector2Array([Vector2(-8, -2.5), Vector2(-4, 5)]), bone, 1.2)

func _build_bat(vis: Node2D, p: Dictionary, rg: Dictionary) -> void:
	var main: Color = p["main"]
	var dark: Color = p["dark"]
	var light: Color = p["light"]
	var glow_c: Color = p["glow"]
	var wf := _joint(vis, Vector2(-1.0, -3.0))
	_bat_wing(wf, dark.darkened(0.25), light.darkened(0.3))
	rg["wing_f"] = wf
	var tail1 := _joint(vis, Vector2(-6.0, 2.0))
	_shape(tail1, _pts_rect(Rect2(-6.0, -1.0, 6.5, 2.0)), dark, 0.2, 1.0)
	var tail2 := _joint(tail1, Vector2(-6.0, 0.0))
	_shape(tail2, PackedVector2Array([Vector2(1, -1), Vector2(-5, -1), Vector2(-9, -3.5), Vector2(-8, 0), Vector2(-9, 3.5), Vector2(-5, 1), Vector2(1, 1)]), dark, 0.2, 1.0)
	rg["tail1"] = tail1
	rg["tail2"] = tail2
	var body := _joint(vis, Vector2.ZERO)
	rg["body"] = body
	_shape(body, _pts_ellipse(Vector2.ZERO, 8.0, 6.0, 14), main, 0.35, 1.6)
	_shape(body, _pts_ellipse(Vector2(1, 1.5), 4.8, 3.2, 10), light, 0.25, 0.0)
	_shape(body, PackedVector2Array([Vector2(-3, -5.0), Vector2(-1, -8.5), Vector2(1, -5.2)]), main.darkened(0.1), 0.2, 1.0)
	var head := _joint(vis, Vector2(7.5, -2.5))
	rg["head"] = head
	_shape(head, _pts_ellipse(Vector2.ZERO, 5.2, 4.6, 12), main.lightened(0.05), 0.3, 1.5)
	_shape(head, PackedVector2Array([Vector2(-3, -3), Vector2(-2.5, -9), Vector2(0.5, -3.8)]), main, 0.2, 1.2)
	_shape(head, PackedVector2Array([Vector2(0.8, -3.6), Vector2(3.2, -9.5), Vector2(4.2, -2.8)]), main, 0.2, 1.2)
	_shape(head, PackedVector2Array([Vector2(-2.2, -4), Vector2(-2.1, -7.2), Vector2(-0.2, -4.2)]), light, 0.1, 0.0)
	_shape(head, PackedVector2Array([Vector2(1.6, -4), Vector2(3.0, -7.6), Vector2(3.4, -3.6)]), light, 0.1, 0.0)
	var eye := _joint(head, Vector2(2.0, -0.8))
	_shape(eye, _pts_ellipse(Vector2.ZERO, 1.9, 1.9, 8), glow_c.lightened(0.3), 0.0, 0.8)
	var gl := _glow(eye, Vector2.ZERO, 8.0, Color(glow_c.r, glow_c.g, glow_c.b, 0.9))
	_flicker(gl, 0.8, 9.0)
	_shape(head, PackedVector2Array([Vector2(4.5, 1.0), Vector2(6.4, 1.8), Vector2(4.8, 3.0)]), dark, 0.2, 1.0)
	_shape(head, PackedVector2Array([Vector2(2.2, 3.4), Vector2(3.0, 6.2), Vector2(3.8, 3.6)]), Color.WHITE, 0.0, 0.8)
	_shape(head, PackedVector2Array([Vector2(0.0, 3.8), Vector2(0.6, 5.8), Vector2(1.4, 3.8)]), Color.WHITE, 0.0, 0.8)
	var wn := _joint(vis, Vector2(-1.0, -3.0))
	_bat_wing(wn, main.darkened(0.1), light)
	rg["wing_n"] = wn
	var aura := _glow(vis, Vector2.ZERO, 22.0, Color(glow_c.r, glow_c.g, glow_c.b, 0.22))
	_flicker(aura, 0.8, 3.0)

func _build_slime(vis: Node2D, p: Dictionary, rg: Dictionary) -> void:
	var main: Color = p["main"]
	var dark: Color = p["dark"]
	var light: Color = p["light"]
	var glow_c: Color = p["glow"]
	var j := _joint(vis, Vector2(0, 9.0))
	rg["jelly"] = j
	_shape(j, _pts_ellipse(Vector2(0, 0), 13.5, 2.8, 14), dark, 0.3, 1.3)
	_shape(j, _dome(Vector2(0, 0), 12.5, 18.0, 16), Color(main.r, main.g, main.b, 0.9), 0.35, 1.7)
	_shape(j, _pts_ellipse(Vector2(-2, -7), 4.8, 4.0, 10), Color(dark.r, dark.g, dark.b, 0.75), 0.2, 0.0)
	for b in [Vector2(5, -3), Vector2(-7, -3), Vector2(2, -13)]:
		_shape(j, _pts_ellipse(b, 1.6, 1.6, 8), Color(1, 1, 1, 0.5), 0.1, 0.8)
	_shape(j, PackedVector2Array([Vector2(-9, -9), Vector2(-5, -14), Vector2(-1, -15.5), Vector2(-4, -12), Vector2(-7, -8)]), Color(1, 1, 1, 0.5), 0.0, 0.0)
	var gl := _glow(j, Vector2(-2, -7), 14.0, Color(glow_c.r, glow_c.g, glow_c.b, 0.35))
	_flicker(gl, 0.8, 2.5)
	var pupils: Array = []
	for ex in [3.5, 8.5]:
		var eye := _joint(j, Vector2(ex, -10.0))
		_shape(eye, _pts_ellipse(Vector2.ZERO, 2.6, 3.2, 10), Color.WHITE, 0.0, 1.0)
		pupils.append(_shape(eye, _pts_ellipse(Vector2.ZERO, 1.3, 1.6, 8), OUT, 0.0, 0.0))
	rg["pupils"] = pupils
	_line(j, PackedVector2Array([Vector2(4.5, -5.5), Vector2(6.5, -4.6), Vector2(8.5, -5.5)]), OUT, 1.2)

func _build_spitter(vis: Node2D, p: Dictionary, rg: Dictionary) -> void:
	var main: Color = p["main"]
	var dark: Color = p["dark"]
	var light: Color = p["light"]
	var glow_c: Color = p["glow"]
	var base := _joint(vis, Vector2(0, 17.0))
	_shape(base, PackedVector2Array([Vector2(-12, 0), Vector2(-9, -5), Vector2(-3, -7), Vector2(3, -7), Vector2(9, -5), Vector2(12, 0)]), dark.darkened(0.2), 0.3, 1.4)
	_shape(base, PackedVector2Array([Vector2(-2, -4), Vector2(-14, -12), Vector2(-18, -5), Vector2(-7, -1)]), main.darkened(0.1), 0.3, 1.3)
	_shape(base, PackedVector2Array([Vector2(2, -4), Vector2(14, -10), Vector2(17, -4), Vector2(7, -1)]), main.darkened(0.1), 0.3, 1.3)
	var stalk: Array = []
	var parent: Node2D = base
	var pos := Vector2(0, -5.0)
	for i in 3:
		var s := _joint(parent, pos)
		_shape(s, PackedVector2Array([Vector2(-2.8, 0.8), Vector2(2.8, 0.8), Vector2(2.1, -8.6), Vector2(-2.1, -8.6)]), main, 0.3, 1.3)
		_shape(s, PackedVector2Array([Vector2(2.5, -3), Vector2(5.5, -4.5), Vector2(2.5, -5.5)]), light, 0.2, 1.0)
		stalk.append(s)
		parent = s
		pos = Vector2(0, -8.0)
	rg["stalk"] = stalk
	var head := _joint(parent, Vector2(0, -8.0))
	rg["head"] = head
	_shape(head, _pts_ellipse(Vector2(0, -4), 9.0, 8.0, 14), light, 0.3, 1.6)
	for sp in [Vector2(-4, -7), Vector2(1, -10), Vector2(-5, -2)]:
		_shape(head, _pts_ellipse(sp, 1.8, 1.8, 8), main.darkened(0.15), 0.2, 0.0)
	_shape(head, PackedVector2Array([Vector2(1, -2), Vector2(10, -2.5), Vector2(10, 2), Vector2(1, 2.5)]), Color("#7a1730"), 0.3, 0.0)
	var ju := _joint(head, Vector2(1.5, -2.5))
	_shape(ju, PackedVector2Array([Vector2(0, 0), Vector2(9, -0.5), Vector2(11.5, -5), Vector2(5, -8), Vector2(-1, -5)]), light, 0.25, 1.4)
	for tx in [3.0, 6.5, 9.5]:
		_shape(ju, PackedVector2Array([Vector2(tx - 1.2, -0.2), Vector2(tx, 2.4), Vector2(tx + 1.2, -0.2)]), Color.WHITE, 0.0, 0.7)
	var jl := _joint(head, Vector2(1.5, 2.5))
	_shape(jl, PackedVector2Array([Vector2(0, 0), Vector2(9, 0.5), Vector2(10, 4.5), Vector2(4, 6.5), Vector2(-1, 3)]), main, 0.25, 1.4)
	for tx in [3.5, 7.0]:
		_shape(jl, PackedVector2Array([Vector2(tx - 1.2, 0.2), Vector2(tx, -2.4), Vector2(tx + 1.2, 0.2)]), Color.WHITE, 0.0, 0.7)
	rg["jaw_u"] = ju
	rg["jaw_l"] = jl
	var eye := _joint(head, Vector2(-1.5, -8.5))
	_shape(eye, _pts_ellipse(Vector2.ZERO, 2.4, 2.4, 10), Color.WHITE, 0.0, 1.0)
	rg["pupil"] = _shape(eye, _pts_ellipse(Vector2.ZERO, 1.2, 1.2, 8), OUT, 0.0, 0.0)
	_line(head, PackedVector2Array([Vector2(-4.5, -11.5), Vector2(0.5, -10.2)]), dark, 1.5)
	rg["mouth_glow"] = _glow(head, Vector2(7, 0), 14.0, Color(glow_c.r, glow_c.g, glow_c.b, 0.0))

func _build_brute(vis: Node2D, p: Dictionary, rg: Dictionary) -> void:
	var main: Color = p["main"]
	var dark: Color = p["dark"]
	var light: Color = p["light"]
	var glow_c: Color = p["glow"]
	var far: Array = []
	for lx in [-11.0, 5.0]:
		far.append(_limb(vis, Vector2(lx, 6.0), 4.5, 4.5, 6.5, dark.darkened(0.3), 4.0))
	rg["far"] = far
	var body := _joint(vis, Vector2.ZERO)
	rg["body"] = body
	_shape(body, PackedVector2Array([
		Vector2(-18, 6), Vector2(-20, -4), Vector2(-14, -13), Vector2(-4, -16), Vector2(8, -14), Vector2(16, -8),
		Vector2(19, 0), Vector2(17, 8), Vector2(8, 10), Vector2(-10, 10)
	]), main, 0.32, 1.9)
	_shape(body, _pts_ellipse(Vector2(2, 3), 11.0, 5.5, 12), light.darkened(0.15), 0.2, 0.0)
	for i in 5:
		var sx := -15.0 + float(i) * 5.5
		var sy := -12.0 - 2.0 * sin(float(i) * 0.7)
		_shape(body, PackedVector2Array([Vector2(sx - 3.0, sy + 3.0), Vector2(sx + 0.5, sy - 8.0), Vector2(sx + 3.5, sy + 3.0)]), light, 0.25, 1.3)
	for ax in [-8.0, 2.0, 11.0]:
		_line(body, PackedVector2Array([Vector2(ax, -12.0), Vector2(ax + 1.5, -2.0), Vector2(ax, 8.0)]), dark, 1.5)
		_shape(body, _pts_ellipse(Vector2(ax + 1.5, -2.0), 1.2, 1.2, 6), light, 0.1, 0.8)
	_shape(body, _pts_ellipse(Vector2(-6, -9), 7.5, 5.5, 12), dark.lightened(0.1), 0.3, 1.5)
	var head := _joint(vis, Vector2(17.0, -2.0))
	rg["head"] = head
	_shape(head, PackedVector2Array([Vector2(-6, -7), Vector2(2, -8.5), Vector2(8.5, -4), Vector2(10.5, 2), Vector2(6, 7), Vector2(-4, 7), Vector2(-7, 0)]), main.lightened(0.1), 0.3, 1.7)
	_shape(head, PackedVector2Array([Vector2(-3, -7), Vector2(2.5, -17), Vector2(6.5, -6.5)]), light, 0.3, 1.5)
	_shape(head, PackedVector2Array([Vector2(5.5, 3.5), Vector2(11.5, -3.5), Vector2(9.0, 5.5)]), Color("#f4ecd8"), 0.2, 1.2)
	_shape(head, PackedVector2Array([Vector2(1.5, 4.5), Vector2(5.0, -2.5), Vector2(4.0, 6.0)]), Color("#f4ecd8"), 0.2, 1.2)
	var eye := _joint(head, Vector2(3.5, -2.2))
	_shape(eye, _pts_ellipse(Vector2.ZERO, 1.8, 1.5, 8), glow_c, 0.1, 0.9)
	rg["eye_glow"] = _glow(eye, Vector2.ZERO, 10.0, Color(1.0, 0.25, 0.2, 0.6))
	_line(head, PackedVector2Array([Vector2(0.5, -4.8), Vector2(6.2, -2.8)]), OUT, 1.8)
	_shape(head, _pts_ellipse(Vector2(8.8, -0.2), 1.1, 1.1, 6), OUT, 0.0, 0.0)
	var near: Array = []
	for lx in [-9.0, 7.0]:
		near.append(_limb(vis, Vector2(lx, 7.0), 4.0, 4.0, 7.0, dark, 4.5))
	rg["near"] = near

func _build_boss(vis: Node2D, p: Dictionary, rg: Dictionary) -> void:
	var stone := Color("#7d7a96")
	var stone_d := Color("#4d4a66")
	var stone_l := Color("#aaa6c8")
	var rune := Color("#ffb347")
	var far: Array = []
	far.append(_limb(vis, Vector2(-14.0, 9.0), 8.0, 8.5, 13.0, stone_d, 8.0))
	rg["far"] = far
	# banner rags behind
	var rags: Array = []
	var rp: Node2D = vis
	var rpos := Vector2(-24.0, -20.0)
	for i in 3:
		var rj := _joint(rp, rpos)
		_shape(rj, PackedVector2Array([Vector2(-4, 0), Vector2(5, 0), Vector2(6, 9), Vector2(-5, 9)]), Color("#8a2a3a").darkened(0.1 * float(i)), 0.3, 1.3)
		rags.append(rj)
		rp = rj
		rpos = Vector2(0, 8.5)
	rg["rags"] = rags
	var arm_far := _joint(vis, Vector2(-18.0, -16.0))
	_shape(arm_far, _pts_rect(Rect2(-5, -2, 10, 17)), stone_d, 0.3, 1.6)
	_shape(arm_far, _pts_ellipse(Vector2(0, 17), 7.0, 7.0, 10), stone_d.lightened(0.05), 0.3, 1.6)
	rg["arm_far"] = arm_far
	var body := _joint(vis, Vector2.ZERO)
	rg["body"] = body
	_shape(body, PackedVector2Array([
		Vector2(-26, 12), Vector2(-30, -8), Vector2(-20, -22), Vector2(-8, -28), Vector2(12, -28), Vector2(24, -20),
		Vector2(30, -6), Vector2(26, 12), Vector2(14, 17), Vector2(-14, 17)
	]), stone, 0.3, 2.2)
	_shape(body, PackedVector2Array([Vector2(-20, -18), Vector2(-6, -24), Vector2(10, -24), Vector2(20, -16), Vector2(14, -4), Vector2(-14, -4)]), stone_l.darkened(0.15), 0.3, 1.6)
	for i in 4:
		var ly := -14.0 + float(i) * 8.0
		var rl := _line(body, PackedVector2Array([Vector2(-16.0, ly), Vector2(-6.0, ly + 2.0), Vector2(6.0, ly - 2.0), Vector2(16.0, ly + 1.0)]), rune, 1.8)
		rl.material = mat_add
	rg["core"] = _joint(body, Vector2(0, -8.0))
	_shape(rg["core"], _pts_ellipse(Vector2.ZERO, 7.0, 7.0, 12), Color("#3a2a20"), 0.2, 1.6)
	rg["core_glow"] = _glow(rg["core"], Vector2.ZERO, 26.0, Color(1.0, 0.6, 0.2, 0.9))
	_shape(rg["core"], _pts_ellipse(Vector2.ZERO, 4.0, 4.0, 10), Color("#ffd27a"), 0.2, 0.0)
	_shape(body, PackedVector2Array([Vector2(-24, 6), Vector2(24, 6), Vector2(20, 18), Vector2(-20, 18)]), stone_d, 0.3, 1.6)
	for i in 5:
		_line(body, PackedVector2Array([Vector2(-16.0 + float(i) * 8.0, 6.0), Vector2(-16.0 + float(i) * 8.0, 17.0)]), OUT, 1.2)
	var head := _joint(body, Vector2(6.0, -30.0))
	rg["head"] = head
	_shape(head, PackedVector2Array([Vector2(-10, -14), Vector2(-18, -28), Vector2(-6, -19)]), stone_l, 0.3, 1.6)
	_shape(head, PackedVector2Array([Vector2(10, -14), Vector2(18, -28), Vector2(6, -19)]), stone_l, 0.3, 1.6)
	_shape(head, PackedVector2Array([Vector2(-10, 0), Vector2(-11, -11), Vector2(-5, -17), Vector2(5, -17), Vector2(11, -11), Vector2(10, 0), Vector2(4, 6), Vector2(-4, 6)]), stone, 0.3, 1.9)
	_shape(head, _pts_rect(Rect2(-8, -9, 16, 4)), Color("#20182a"), 0.2, 0.0)
	var eye_l := _line(head, PackedVector2Array([Vector2(-7, -7), Vector2(7, -7)]), Color("#ffd27a"), 3.0)
	eye_l.material = mat_add
	rg["eye_line"] = eye_l
	rg["eye_glow"] = _glow(head, Vector2(2, -7), 18.0, Color(1.0, 0.55, 0.2, 0.9))
	for i in 3:
		_line(head, PackedVector2Array([Vector2(-5.0 + float(i) * 5.0, 0.0), Vector2(-5.0 + float(i) * 5.0, 4.0)]), OUT, 1.4)
	var near := _limb(vis, Vector2(6.0, 9.0), 8.0, 8.5, 14.0, stone, 9.0)
	rg["near"] = [near]
	_shape(vis, PackedVector2Array([Vector2(-26, -20), Vector2(-34, -30), Vector2(-20, -28), Vector2(-14, -26)]), stone_l, 0.3, 1.5)
	var sh := _shape(vis, _pts_ellipse(Vector2(20, -20), 10.0, 7.5, 12), stone_l, 0.35, 1.8)
	for sx in [14.0, 20.0, 26.0]:
		_shape(vis, PackedVector2Array([Vector2(sx - 2.5, -24), Vector2(sx, -33), Vector2(sx + 2.5, -24)]), stone_l.lightened(0.1), 0.25, 1.3)
	var arm_n := _joint(vis, Vector2(20.0, -18.0))
	_shape(arm_n, _pts_rect(Rect2(-5.5, -2, 11, 16)), stone, 0.3, 1.8)
	var fore := _joint(arm_n, Vector2(0, 14.0))
	_shape(fore, _pts_rect(Rect2(-5.0, -1, 10, 13)), stone_l.darkened(0.1), 0.3, 1.8)
	_shape(fore, _pts_ellipse(Vector2(0, 14), 6.5, 6.5, 10), stone_d.lightened(0.1), 0.3, 1.8)
	rg["arm_n"] = arm_n
	var sword := _joint(fore, Vector2(0, 14.0))
	_shape(sword, PackedVector2Array([Vector2(3, -5), Vector2(62, -4), Vector2(76, 0), Vector2(62, 4), Vector2(3, 5)]), Color("#d2d6ee"), 0.35, 2.0)
	_line(sword, PackedVector2Array([Vector2(8, 0), Vector2(66, 0)]), Color("#8a8fb0"), 1.6)
	var swl := _line(sword, PackedVector2Array([Vector2(8, 0), Vector2(70, 0)]), Color(1.0, 0.6, 0.25), 2.4)
	swl.material = mat_add
	_shape(sword, PackedVector2Array([Vector2(-2, -13), Vector2(5, -9), Vector2(5, 9), Vector2(-2, 13), Vector2(-4, 0)]), Color("#f3c969"), 0.3, 1.8)
	_shape(sword, _pts_rect(Rect2(-18, -3, 16, 6)), Color("#4a3224"), 0.3, 1.6)
	_shape(sword, _pts_ellipse(Vector2(-20, 0), 4.0, 4.0, 8), Color("#f3c969"), 0.3, 1.5)
	rg["sword"] = sword
	rg["sword_glow"] = _glow(sword, Vector2(36, 0), 40.0, Color(1.0, 0.5, 0.2, 0.0))

func _make_enemy(type: String, pos: Vector2, elite: bool, n: int) -> Node2D:
	var base: Dictionary = ENEMY_BASE[type]
	var size: Vector2 = base["size"]
	var d := clampf(float(n - 1) / 499.0, 0.0, 1.0)
	var hp: int = int(base["hp"]) + enemy_hp_bonus + int(n / 150)
	if type == "boss":
		hp = 8 + int(n / 20)
	var e: Node2D
	if type != "bat":
		var cb := CharacterBody2D.new()
		cb.collision_layer = L_ENEMY
		cb.collision_mask = L_SOLID
		e = cb
	else:
		e = Node2D.new()
	var sc := 1.0
	if elite and type != "boss":
		sc = 1.25
		hp = hp * 2 + 1
		size *= 1.25
	if type != "bat":
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		e.add_child(cs)
		if pos.y == 0.0:
			pos.y = GROUND_TOP - size.y * 0.5 - 4.0
	e.position = pos
	var pal := _enemy_pal()
	var rg := {}
	var vis := _joint(e, Vector2.ZERO)
	vis.scale = Vector2(sc, sc)
	match type:
		"crawler":
			_build_crawler(vis, pal, rg)
		"bat":
			_build_bat(vis, pal, rg)
		"slime":
			_build_slime(vis, pal, rg)
		"spitter":
			_build_spitter(vis, pal, rg)
		"brute":
			_build_brute(vis, pal, rg)
		"boss":
			_build_boss(vis, pal, rg)
	if elite and type != "boss":
		var ag := _glow(vis, Vector2.ZERO, size.x * 0.9, Color(1.0, 0.8, 0.2, 0.55))
		_flicker(ag, 0.9, 4.0)
		_shape(vis, PackedVector2Array([
			Vector2(-5, -size.y * 0.5 / sc - 1), Vector2(-5, -size.y * 0.5 / sc - 6), Vector2(-2.5, -size.y * 0.5 / sc - 3),
			Vector2(0, -size.y * 0.5 / sc - 7), Vector2(2.5, -size.y * 0.5 / sc - 3), Vector2(5, -size.y * 0.5 / sc - 6), Vector2(5, -size.y * 0.5 / sc - 1)
		]), Color("#ffd24a"), 0.3, 1.1)
	if type != "bat":
		var sh := Polygon2D.new()
		sh.polygon = _pts_ellipse(Vector2(0, size.y * 0.5), size.x * 0.5, 3.0, 12)
		sh.color = Color(0, 0, 0, 0.3)
		sh.z_index = -1
		e.add_child(sh)
	var bar := _joint(e, Vector2(0, -size.y * 0.5 - 12.0))
	bar.add_child(_rect_poly_c(Vector2(-13, -2.5), Vector2(26, 5), Color(0, 0, 0, 0.7)))
	var fill := _rect_poly_c(Vector2(-12, -1.5), Vector2(24, 3), Color("#7ef5a0"))
	bar.add_child(fill)
	bar.visible = false
	var seg := _segment_at(pos.x)
	var spd := 60.0 * enemy_speed_mul * (1.0 + 0.6 * d)
	if type == "brute":
		spd = 45.0 * enemy_speed_mul
	elif type == "boss":
		spd = 75.0 * enemy_speed_mul
	var st := {
		"kind": type, "hp": hp, "max_hp": hp, "dir": -1.0 if rng.randf() < 0.5 else 1.0, "face": 1.0, "speed": spd,
		"min_x": seg.x + 28.0, "max_x": seg.y - 28.0, "stun": 0.0, "dead": false, "size": size, "home": pos,
		"phase": rng.randf() * TAU, "state": "patrol", "timer": rng.randf_range(0.3, 1.2), "elite": elite, "rig": rg,
		"vis": vis, "vscale": sc, "jcd": 0.0, "bar": bar, "bar_fill": fill, "bar_t": 0.0, "flash": 0.0, "pal": pal,
		"pts": int(base["pts"]), "squash": 0.0, "pending": ""
	}
	if type == "crawler" or type == "brute":
		st["min_x"] = maxf(seg.x + 28.0, pos.x - 110.0)
		st["max_x"] = minf(seg.y - 28.0, pos.x + 110.0)
	if type == "slime":
		st["min_x"] = maxf(seg.x + 28.0, pos.x - 140.0)
		st["max_x"] = minf(seg.y - 28.0, pos.x + 140.0)
	if type == "boss":
		st["min_x"] = seg.x + 70.0
		st["max_x"] = seg.y - 70.0
		st["state"] = "idle"
		st["timer"] = 1.2
	e.set_meta("st", st)
	dynamic.add_child(e)
	enemies.append(e)
	if type == "boss":
		boss_ref = e
		boss_alive = true
	return e

func _rect_poly_c(top_left: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = _pts_rect(Rect2(top_left, size))
	p.color = color
	return p

func _st(e: Node2D) -> Dictionary:
	return e.get_meta("st")

func _spawn_dynamic() -> void:
	var n := int(level_data["n"])
	for en in level_data["enemies"]:
		_make_enemy(String(en["t"]), Vector2(float(en["x"]), float(en["y"])), bool(en["elite"]), n)
	for c in level_data["crystals"]:
		_add_item("crystal", c)
	for h in level_data["hearts"]:
		_add_item("heart", h)
	if bool(level_data["boss"]):
		var bp: Vector2 = level_data["boss_pos"]
		_make_enemy("boss", Vector2(bp.x, GROUND_TOP - 60.0), false, n)

func _add_item(kind: String, pos: Vector2, magnet := false) -> void:
	var n := Node2D.new()
	n.position = pos
	var inner := Node2D.new()
	n.add_child(inner)
	if kind == "crystal":
		var c := Color("#6ae8ff")
		_shape(inner, PackedVector2Array([Vector2(0, -9), Vector2(6, -3), Vector2(5, 5), Vector2(0, 9), Vector2(-5, 5), Vector2(-6, -3)]), c, 0.35, 1.3)
		_shape(inner, PackedVector2Array([Vector2(0, -9), Vector2(6, -3), Vector2(0, 0)]), Color("#d8ffff"), 0.1, 0.0)
		_line(inner, PackedVector2Array([Vector2(-6, -3), Vector2(0, 0), Vector2(5, 5)]), Color(1, 1, 1, 0.55), 1.0)
		_line(inner, PackedVector2Array([Vector2(0, 0), Vector2(0, 9)]), Color(1, 1, 1, 0.45), 1.0)
		var gl := _glow(n, Vector2.ZERO, 18.0, Color(0.4, 0.9, 1.0, 0.55))
		_flicker(gl, 0.8, 4.0)
	else:
		_shape(inner, PackedVector2Array([Vector2(0, 7), Vector2(-8, -1), Vector2(-8, -5), Vector2(-4, -8), Vector2(0, -4), Vector2(4, -8), Vector2(8, -5), Vector2(8, -1)]), Color("#ff5d6c"), 0.3, 1.4)
		_shape(inner, PackedVector2Array([Vector2(-6, -5), Vector2(-4, -6.5), Vector2(-3, -4.5)]), Color(1, 1, 1, 0.8), 0.0, 0.0)
		var gl2 := _glow(n, Vector2.ZERO, 20.0, Color(1.0, 0.35, 0.45, 0.5))
		_flicker(gl2, 0.8, 5.0)
	dynamic.add_child(n)
	items.append({"kind": kind, "node": n, "inner": inner, "base": pos, "phase": rng.randf() * TAU, "mag": magnet})

func _drop_loot(pos: Vector2, count: int, heart: bool) -> void:
	for i in count:
		_add_item("crystal", pos + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 6)), true)
	if heart and health < max_health:
		_add_item("heart", pos + Vector2(0, -10), true)

# ─────────────────────────────── Monsters: AI ───────────────────────────────
func _update_enemies(delta: float) -> void:
	var prect := _player_rect()
	var i := enemies.size() - 1
	while i >= 0:
		var e := enemies[i]
		if not is_instance_valid(e):
			enemies.remove_at(i)
			i -= 1
			continue
		var st := _st(e)
		if bool(st["dead"]):
			enemies.remove_at(i)
			i -= 1
			continue
		var kind: String = st["kind"]
		var stun := maxf(0.0, float(st["stun"]) - delta)
		st["stun"] = stun
		st["flash"] = maxf(0.0, float(st["flash"]) - delta)
		st["bar_t"] = maxf(0.0, float(st["bar_t"]) - delta)
		match kind:
			"crawler":
				_ai_crawler(e, st, delta, stun)
			"slime":
				_ai_slime(e, st, delta, stun)
			"brute":
				_ai_brute(e, st, delta, stun)
			"spitter":
				_ai_spitter(e, st, delta, stun)
			"bat":
				_ai_bat(e, st, delta, stun)
			"boss":
				_ai_boss(e, st, delta, stun)
		if bool(st["dead"]):
			i -= 1
			continue
		var esz: Vector2 = st["size"]
		if prect.intersects(Rect2(e.global_position - esz * 0.5, esz)):
			var stomping := player.velocity.y > 30.0 and player.global_position.y + 6.0 < e.global_position.y - esz.y * 0.15
			if stomping:
				_damage_enemy(e, 2, signf(e.global_position.x - player.global_position.x))
				player.velocity.y = JUMP_SPEED * (0.95 if (Input.is_action_pressed("jump") or _btn_held(JOY_BUTTON_A)) else 0.7)
				squash = Vector2(0.85, 1.2)
			else:
				_hurt_player(1, e.global_position.x)
		i -= 1

func _gravity_step(w: CharacterBody2D, delta: float) -> void:
	w.velocity.y = minf(w.velocity.y + GRAVITY * delta, MAX_FALL)

func _ai_crawler(e: Node2D, st: Dictionary, delta: float, stun: float) -> void:
	var w := e as CharacterBody2D
	var dir: float = st["dir"]
	var minx: float = st["min_x"]
	var maxx: float = st["max_x"]
	if stun > 0.0:
		w.velocity.x = move_toward(w.velocity.x, 0.0, 500.0 * delta)
	else:
		if w.global_position.x < minx:
			dir = 1.0
		elif w.global_position.x > maxx:
			dir = -1.0
		elif w.is_on_wall():
			dir = -dir
		w.velocity.x = dir * float(st["speed"])
	st["dir"] = dir
	st["face"] = dir
	_gravity_step(w, delta)
	w.move_and_slide()

func _ai_slime(e: Node2D, st: Dictionary, delta: float, stun: float) -> void:
	var w := e as CharacterBody2D
	st["timer"] = float(st["timer"]) - delta
	if w.is_on_floor():
		w.velocity.x = move_toward(w.velocity.x, 0.0, 1200.0 * delta)
		if st["state"] == "air":
			st["state"] = "idle"
			st["timer"] = rng.randf_range(0.5, 1.1)
			st["squash"] = 0.35
			_burst(e.global_position + Vector2(0, 9), Color(st["pal"]["main"]), 5, 70.0, 0.3)
		if float(st["timer"]) <= 0.0 and stun <= 0.0:
			var to_p := player.global_position.x - w.global_position.x
			var dir: float = st["dir"]
			if absf(to_p) < 320.0 and absf(player.global_position.y - w.global_position.y) < 160.0:
				dir = signf(to_p)
			elif rng.randf() < 0.4:
				dir = -dir
			if w.global_position.x < float(st["min_x"]) + 8.0:
				dir = 1.0
			elif w.global_position.x > float(st["max_x"]) - 8.0:
				dir = -1.0
			st["dir"] = dir
			st["face"] = dir
			w.velocity = Vector2(dir * 125.0 * enemy_speed_mul, -390.0)
			st["state"] = "air"
			st["squash"] = -0.3
	_gravity_step(w, delta)
	w.move_and_slide()

func _ai_brute(e: Node2D, st: Dictionary, delta: float, stun: float) -> void:
	var w := e as CharacterBody2D
	var state: String = st["state"]
	var dir: float = st["dir"]
	var minx: float = st["min_x"]
	var maxx: float = st["max_x"]
	st["timer"] = float(st["timer"]) - delta
	if stun > 0.0:
		w.velocity.x = move_toward(w.velocity.x, 0.0, 600.0 * delta)
	else:
		match state:
			"patrol":
				if w.global_position.x < minx:
					dir = 1.0
				elif w.global_position.x > maxx:
					dir = -1.0
				elif w.is_on_wall():
					dir = -dir
				w.velocity.x = dir * float(st["speed"])
				var to_p := player.global_position.x - w.global_position.x
				if absf(to_p) < 360.0 and absf(player.global_position.y - w.global_position.y) < 70.0 and float(st["timer"]) <= 0.0:
					st["state"] = "tele"
					st["timer"] = 0.6
					dir = signf(to_p)
					_sfx(160.0, 0.3, 0.1, 80.0, 1)
			"tele":
				w.velocity.x = 0.0
				st["face"] = signf(player.global_position.x - w.global_position.x)
				if float(st["timer"]) <= 0.0:
					st["state"] = "charge"
					st["timer"] = 1.3
					dir = float(st["face"])
					shake = maxf(shake, 3.0)
			"charge":
				w.velocity.x = dir * 300.0 * enemy_speed_mul
				if int(anim_time * 20.0) % 2 == 0:
					_burst(e.global_position + Vector2(-dir * 14.0, 12.0), Color("#c9b99a"), 2, 60.0, 0.3)
				if w.is_on_wall() or float(st["timer"]) <= 0.0 or w.global_position.x < minx - 70.0 or w.global_position.x > maxx + 70.0:
					st["state"] = "recover"
					st["timer"] = 1.0
					w.velocity.x = 0.0
					if w.is_on_wall():
						shake = maxf(shake, 5.0)
						_sfx(100.0, 0.2, 0.15, -100.0, 2)
			"recover":
				w.velocity.x = 0.0
				if float(st["timer"]) <= 0.0:
					st["state"] = "patrol"
					st["timer"] = 1.5
	if st["state"] == "patrol":
		st["face"] = dir
	elif st["state"] == "charge":
		st["face"] = dir
	st["dir"] = dir
	_gravity_step(w, delta)
	w.move_and_slide()

func _ai_spitter(e: Node2D, st: Dictionary, delta: float, stun: float) -> void:
	var w := e as CharacterBody2D
	var to_p := player.global_position - w.global_position
	st["face"] = signf(to_p.x) if absf(to_p.x) > 4.0 else float(st["face"])
	st["timer"] = float(st["timer"]) - delta
	var near := absf(to_p.x) < 400.0 and absf(to_p.y) < 240.0
	match String(st["state"]):
		"patrol", "idle":
			if near and float(st["timer"]) <= 0.0 and stun <= 0.0:
				st["state"] = "tele"
				st["timer"] = 0.6
				_sfx(300.0, 0.4, 0.06, 500.0, 1)
		"tele":
			if float(st["timer"]) <= 0.0:
				var from := w.global_position + Vector2(float(st["face"]) * 12.0, -14.0)
				var aim := (player.global_position - from)
				var v := aim.normalized() * 250.0 + Vector2(0.0, -70.0)
				_spawn_projectile(from, v, 240.0, 3.0, "orb", Color(st["pal"]["glow"]), 6.0)
				_sfx(260.0, 0.1, 0.1, -300.0, 1)
				st["state"] = "recover"
				st["timer"] = 0.35
		"recover":
			if float(st["timer"]) <= 0.0:
				st["state"] = "idle"
				st["timer"] = 2.2 / enemy_speed_mul
	_gravity_step(w, delta)
	w.velocity.x = 0.0
	w.move_and_slide()

func _ai_bat(e: Node2D, st: Dictionary, delta: float, stun: float) -> void:
	var home: Vector2 = st["home"]
	var ph: float = st["phase"]
	var target := home + Vector2(sin(anim_time * 1.3 + ph) * 50.0, sin(anim_time * 2.1 + ph) * 16.0)
	var dist := e.global_position.distance_to(player.global_position)
	var chase := dist < 250.0
	if chase:
		target = player.global_position + Vector2(0.0, -26.0)
	var before := e.global_position.x
	if stun <= 0.0:
		var boost := (1.0 + 0.4 * clampf(float(current_level - 1) / 499.0, 0.0, 1.0)) * enemy_speed_mul
		e.global_position = e.global_position.move_toward(target, (100.0 if chase else 55.0) * boost * delta)
	var mv := e.global_position.x - before
	if absf(mv) > 0.05:
		st["face"] = signf(mv)

func _ai_boss(e: Node2D, st: Dictionary, delta: float, stun: float) -> void:
	var w := e as CharacterBody2D
	var enraged := float(st["hp"]) < float(st["max_hp"]) * 0.5
	var speed_k := (1.35 if enraged else 1.0) * enemy_speed_mul
	var to_p := player.global_position.x - w.global_position.x
	var dist := absf(to_p)
	var minx: float = st["min_x"]
	var maxx: float = st["max_x"]
	var state: String = st["state"]
	st["timer"] = float(st["timer"]) - delta
	st["jcd"] = maxf(0.0, float(st["jcd"]) - delta)
	if stun > 0.0 and state != "slam":
		w.velocity.x = move_toward(w.velocity.x, 0.0, 400.0 * delta)
	else:
		match state:
			"idle":
				st["face"] = signf(to_p) if dist > 5.0 else float(st["face"])
				var dir := signf(to_p)
				if dist > 120.0:
					w.velocity.x = dir * float(st["speed"]) * 0.7
				else:
					w.velocity.x = 0.0
				if (w.global_position.x <= minx and dir < 0.0) or (w.global_position.x >= maxx and dir > 0.0):
					w.velocity.x = 0.0
				if float(st["timer"]) <= 0.0:
					var roll := rng.randf()
					if dist < 200.0 and roll < 0.5:
						st["state"] = "slam_tele"
						st["timer"] = 0.55
					elif dist < 520.0 and roll < 0.8:
						st["state"] = "charge_tele"
						st["timer"] = 0.6
					else:
						st["state"] = "volley_tele"
						st["timer"] = 0.7
			"charge_tele":
				w.velocity.x = 0.0
				st["face"] = signf(to_p)
				if float(st["timer"]) <= 0.0:
					st["state"] = "charge"
					st["timer"] = 1.0
					st["dir"] = float(st["face"])
					shake = maxf(shake, 3.0)
			"charge":
				var cd: float = st["dir"]
				w.velocity.x = cd * 320.0 * speed_k
				if (w.global_position.x <= minx and cd < 0.0) or (w.global_position.x >= maxx and cd > 0.0) or w.is_on_wall() or float(st["timer"]) <= 0.0:
					w.velocity.x = 0.0
					st["state"] = "recover"
					st["timer"] = 0.7
					shake = maxf(shake, 5.0)
				if int(anim_time * 24.0) % 2 == 0:
					_burst(e.global_position + Vector2(-cd * 24.0, 24.0), Color("#c9b99a"), 2, 70.0, 0.3)
			"slam_tele":
				w.velocity.x = 0.0
				st["face"] = signf(to_p)
				if float(st["timer"]) <= 0.0:
					w.velocity = Vector2(clampf(to_p / 0.85, -280.0, 280.0), -780.0)
					st["state"] = "slam"
					st["timer"] = 0.3
			"slam":
				if w.is_on_floor() and float(st["timer"]) <= 0.0:
					shake = 12.0
					_sfx(70.0, 0.4, 0.2, -40.0, 2)
					_burst(e.global_position + Vector2(0, 26), Color("#c9b99a"), 22, 220.0, 0.6)
					_spawn_projectile(e.global_position + Vector2(30, 24), Vector2(260.0, 0.0), 0.0, 1.5, "wave", Color("#ffb347"), 14.0)
					_spawn_projectile(e.global_position + Vector2(-30, 24), Vector2(-260.0, 0.0), 0.0, 1.5, "wave", Color("#ffb347"), 14.0)
					st["state"] = "recover"
					st["timer"] = 0.8
					w.velocity.x = 0.0
			"volley_tele":
				w.velocity.x = 0.0
				st["face"] = signf(to_p)
				if float(st["timer"]) <= 0.0:
					var from := w.global_position + Vector2(float(st["face"]) * 30.0, -24.0)
					var base := (player.global_position - from).angle()
					var shots := 5 if enraged else 3
					for k in shots:
						var ang := base + (float(k) - float(shots - 1) * 0.5) * 0.28
						_spawn_projectile(from, Vector2(cos(ang), sin(ang)) * 250.0, 0.0, 3.5, "orb", Color("#ffb347"), 8.0)
					_sfx(240.0, 0.25, 0.12, -200.0, 1)
					st["state"] = "recover"
					st["timer"] = 0.7
			"recover":
				w.velocity.x = move_toward(w.velocity.x, 0.0, 800.0 * delta)
				if float(st["timer"]) <= 0.0:
					st["state"] = "idle"
					st["timer"] = (0.5 if enraged else 1.0) + rng.randf_range(0.0, 0.6)
	if w.global_position.x < minx - 20.0:
		w.global_position.x = minx - 20.0
	elif w.global_position.x > maxx + 20.0:
		w.global_position.x = maxx + 20.0
	_gravity_step(w, delta)
	w.move_and_slide()

func _damage_enemy(e: Node2D, amount: int, push_dir: float) -> void:
	var st := _st(e)
	if bool(st["dead"]):
		return
	var kind: String = st["kind"]
	var pal: Dictionary = st["pal"]
	# Knockback from sword upgrades
	var kb := float(stats.get("sword_knock", 0))
	if kb > 0.0 and absf(push_dir) > 0.01:
		e.position.x += push_dir * kb * 0.15
		if st.has("vx"):
			st["vx"] = float(st.get("vx", 0.0)) + push_dir * kb
	var hp := int(st["hp"]) - amount
	st["hp"] = hp
	st["flash"] = 0.15
	st["bar_t"] = 1.8
	var fill: Polygon2D = st["bar_fill"]
	fill.scale.x = clampf(float(hp) / float(st["max_hp"]), 0.0, 1.0)
	_sfx(200.0, 0.09, 0.1, -600.0, 1)
	_burst(e.global_position, Color(pal["main"]), 8, 170.0, 0.45)
	_burst(e.global_position, Color.WHITE, 4, 220.0, 0.2)
	_float_text(e.global_position + Vector2(0, -14), "-%d" % amount, Color("#ffffff"))
	hitstop = maxf(hitstop, 0.06)
	if hp <= 0:
		var pts: int = int(st["pts"]) * (2 if bool(st["elite"]) else 1)
		score += pts * score_mul
		st["dead"] = true
		_float_text(e.global_position, "+%d" % (pts * score_mul), Color("#ffe28a"))
		_burst(e.global_position, Color(pal["glow"]), 24 if kind == "boss" else 14, 240.0, 0.8)
		_burst(e.global_position, Color(pal["main"]), 12, 160.0, 0.6)
		_drop_loot(e.global_position, 12 if kind == "boss" else (4 if bool(st["elite"]) else 2), bool(st["elite"]) and rng.randf() < 0.6)
		hitstop = maxf(hitstop, 0.18 if kind == "boss" else 0.08)
		e.queue_free()
		if kind == "boss":
			_boss_defeated()
	else:
		if String(st["kind"]) != "boss" or int(amount) >= 2:
			st["stun"] = 0.1 if kind == "boss" else 0.3
		if e is CharacterBody2D:
			(e as CharacterBody2D).velocity.x = push_dir * (60.0 if kind == "boss" else (110.0 if kind == "brute" else 220.0))

# ─────────────────────────────── Monsters: animation ───────────────────────────────
func _look_offset(e: Node2D, st: Dictionary, mx: float) -> Vector2:
	var d := player.global_position - e.global_position
	var vis: Node2D = st["vis"]
	var sx := signf(vis.scale.x)
	return Vector2(clampf(d.x * sx / 70.0, -1.0, 1.0), clampf(d.y / 70.0, -1.0, 1.0)) * mx

func _animate_enemies(delta: float) -> void:
	var t := anim_time
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var st := _st(e)
		if bool(st["dead"]):
			continue
		var kind: String = st["kind"]
		var rg: Dictionary = st["rig"]
		var vis: Node2D = st["vis"]
		var sc: float = st["vscale"]
		var face: float = st["face"]
		vis.scale.x = sc * (1.0 if face >= 0.0 else -1.0)
		var fl := clampf(float(st["flash"]) / 0.15, 0.0, 1.0)
		e.modulate = Color.WHITE.lerp(Color(2.6, 2.6, 2.6), fl)
		var bar: Node2D = st["bar"]
		bar.visible = float(st["bar_t"]) > 0.0
		var cb := e as CharacterBody2D
		var vx := cb.velocity.x if cb != null else 0.0
		var ph: float = st["phase"]
		match kind:
			"crawler":
				var mv := clampf(absf(vx) / 60.0, 0.0, 1.5)
				var cph := t * 10.0 * (0.5 + mv) + ph
				var far: Array = rg["far"]
				var near: Array = rg["near"]
				for i in 3:
					var a := cph + float(i) * 2.1
					var jf: Array = far[i]
					(jf[0] as Node2D).rotation = sin(a + PI) * 0.6 * mv + 0.25
					(jf[1] as Node2D).rotation = (0.2 - 0.6 * maxf(0.0, cos(a + PI))) * (0.4 + 0.6 * mv)
					var jn: Array = near[i]
					(jn[0] as Node2D).rotation = sin(a) * 0.6 * mv + 0.25
					(jn[1] as Node2D).rotation = (0.2 - 0.6 * maxf(0.0, cos(a))) * (0.4 + 0.6 * mv)
				(rg["body"] as Node2D).position.y = sin(cph * 2.0) * 0.6 * mv + sin(t * 3.0 + ph) * 0.4
				var chomp := 0.5 + 0.5 * sin(t * 6.0 + ph)
				(rg["mand_t"] as Node2D).rotation = -0.15 - 0.25 * chomp
				(rg["mand_b"] as Node2D).rotation = 0.15 + 0.25 * chomp
				(rg["ant"] as Node2D).rotation = sin(t * 4.0 + ph) * 0.25
				(rg["pupil"] as Node2D).position = _look_offset(e, st, 0.9)
			"bat":
				var fp := t * 14.0 + ph
				(rg["wing_n"] as Node2D).rotation = sin(fp) * 0.85
				(rg["wing_f"] as Node2D).rotation = sin(fp + 0.5) * 0.85
				(rg["body"] as Node2D).position.y = sin(fp) * 1.2
				(rg["tail1"] as Node2D).rotation = sin(t * 5.0 + ph) * 0.35
				(rg["tail2"] as Node2D).rotation = sin(t * 5.0 + ph - 0.8) * 0.45
				(rg["head"] as Node2D).rotation = sin(t * 3.0 + ph) * 0.12
			"slime":
				var j: Node2D = rg["jelly"]
				var sq: float = st["squash"]
				sq = lerpf(sq, 0.0, minf(1.0, delta * 9.0))
				st["squash"] = sq
				var br := sin(t * 3.0 + ph) * 0.05
				var air_k := 0.0
				if cb != null and not cb.is_on_floor():
					air_k = clampf(-cb.velocity.y / 900.0, -0.3, 0.3)
				j.scale = Vector2(1.0 - sq * 0.5 - br - air_k * 0.5, 1.0 + sq + br + air_k)
				var pu: Array = rg["pupils"]
				for pn in pu:
					(pn as Node2D).position = _look_offset(e, st, 0.8)
			"spitter":
				var stalk: Array = rg["stalk"]
				for i in stalk.size():
					(stalk[i] as Node2D).rotation = sin(t * 1.6 + float(i) * 0.7 + ph) * 0.13
				var state: String = st["state"]
				var open := 0.0
				if state == "tele":
					open = 1.0 - float(st["timer"]) / 0.6
				elif state == "recover":
					open = 0.2
				(rg["jaw_u"] as Node2D).rotation = -0.65 * open - 0.05 * sin(t * 4.0)
				(rg["jaw_l"] as Node2D).rotation = 0.65 * open + 0.05 * sin(t * 4.0)
				(rg["mouth_glow"] as Sprite2D).modulate.a = open * 0.9
				(rg["head"] as Node2D).rotation = sin(t * 2.0 + ph) * 0.1 - 0.15 * open
				(rg["pupil"] as Node2D).position = _look_offset(e, st, 0.8)
			"brute":
				var mv2 := clampf(absf(vx) / 90.0, 0.0, 3.0)
				var bph := t * 7.0 * (0.4 + mv2) + ph
				var far2: Array = rg["far"]
				var near2: Array = rg["near"]
				for i in 2:
					var a2 := bph + float(i) * PI
					var jf2: Array = far2[i]
					(jf2[0] as Node2D).rotation = sin(a2 + PI) * 0.5 * minf(mv2, 1.2) + 0.1
					(jf2[1] as Node2D).rotation = (0.1 - 0.5 * maxf(0.0, cos(a2 + PI))) * minf(mv2, 1.2)
					var jn2: Array = near2[i]
					(jn2[0] as Node2D).rotation = sin(a2) * 0.5 * minf(mv2, 1.2) + 0.1
					(jn2[1] as Node2D).rotation = (0.1 - 0.5 * maxf(0.0, cos(a2))) * minf(mv2, 1.2)
				var shake_x := 0.0
				var bstate: String = st["state"]
				var lean := 0.0
				if bstate == "tele":
					shake_x = sin(t * 60.0) * 1.2
					lean = -0.1
				elif bstate == "charge":
					lean = 0.12
				(rg["body"] as Node2D).position = Vector2(shake_x, sin(bph * 2.0) * 0.8 * minf(mv2, 1.0) + sin(t * 2.0 + ph) * 0.5)
				(rg["body"] as Node2D).rotation = lean
				(rg["head"] as Node2D).rotation = lean * 1.5 + sin(t * 2.5 + ph) * 0.05 + (0.15 if bstate == "charge" else 0.0)
				(rg["eye_glow"] as Sprite2D).modulate.a = 0.9 if bstate == "tele" or bstate == "charge" else 0.45 + 0.2 * sin(t * 4.0)
			"boss":
				var bs: String = st["state"]
				var mvb := clampf(absf(vx) / 80.0, 0.0, 3.0)
				var wph := t * 5.0 * (0.4 + mvb) + ph
				var farb: Array = rg["far"]
				var jfb: Array = farb[0]
				(jfb[0] as Node2D).rotation = sin(wph + PI) * 0.35 * minf(mvb, 1.0)
				(jfb[1] as Node2D).rotation = (0.05 - 0.3 * maxf(0.0, cos(wph + PI))) * minf(mvb, 1.0)
				var nearb: Array = rg["near"]
				var jnb: Array = nearb[0]
				(jnb[0] as Node2D).rotation = sin(wph) * 0.35 * minf(mvb, 1.0)
				(jnb[1] as Node2D).rotation = (0.05 - 0.3 * maxf(0.0, cos(wph))) * minf(mvb, 1.0)
				var arm_rot := 0.1 + sin(t * 1.5 + ph) * 0.05
				var blade_abs := -0.5
				var lean_b := 0.0
				var tp := float(st["timer"])
				match bs:
					"slam_tele":
						var u := clampf(1.0 - tp / 0.55, 0.0, 1.0)
						arm_rot = lerpf(0.1, -3.0, u)
						blade_abs = lerpf(-0.5, -1.7, u)
						lean_b = -0.12 * u
					"slam":
						arm_rot = lerpf(-3.0, -0.4, clampf((0.3 - tp) / 0.3 + 0.4, 0.0, 1.0))
						blade_abs = 0.6
						lean_b = 0.15
					"charge_tele":
						arm_rot = -1.6
						blade_abs = -0.2
						lean_b = -0.1
					"charge":
						arm_rot = -1.4
						blade_abs = 0.0
						lean_b = 0.2
					"volley_tele":
						arm_rot = -1.2 - 0.4 * sin(t * 12.0)
						blade_abs = -1.4
					"recover":
						arm_rot = 0.3
						blade_abs = 0.5
				var an := rg["arm_n"] as Node2D
				an.rotation = lerpf(an.rotation, arm_rot, minf(1.0, delta * 18.0))
				(rg["sword"] as Node2D).rotation = lerpf((rg["sword"] as Node2D).rotation, blade_abs - an.rotation, minf(1.0, delta * 18.0))
				(rg["arm_far"] as Node2D).rotation = -0.1 + sin(t * 1.6 + 1.0) * 0.06 + (0.4 if bs == "charge" else 0.0)
				(rg["body"] as Node2D).rotation = lerpf((rg["body"] as Node2D).rotation, lean_b, minf(1.0, delta * 10.0))
				(rg["body"] as Node2D).position.y = sin(t * 2.0) * 0.8
				(rg["head"] as Node2D).rotation = sin(t * 1.4) * 0.04 - lean_b * 0.5
				var enr := float(st["hp"]) < float(st["max_hp"]) * 0.5
				(rg["core_glow"] as Sprite2D).modulate = Color(1.0, 0.25, 0.2, 0.9) if enr else Color(1.0, 0.6, 0.2, 0.7 + 0.2 * sin(t * 3.0))
				(rg["eye_glow"] as Sprite2D).modulate = Color(1.0, 0.2, 0.2, 0.95) if enr else Color(1.0, 0.55, 0.2, 0.9)
				(rg["sword_glow"] as Sprite2D).modulate.a = 0.55 if (bs == "slam_tele" or bs == "slam" or bs == "charge_tele") else 0.12
				var rags: Array = rg["rags"]
				for i in rags.size():
					(rags[i] as Node2D).rotation = 0.25 + sin(t * 4.0 + float(i)) * 0.15 + (0.5 if bs == "charge" else 0.0)

# ─────────────────────────────── Projectiles ───────────────────────────────
func _spawn_projectile(pos: Vector2, vel: Vector2, grav: float, life: float, kind: String, col: Color, radius: float) -> void:
	var n := Node2D.new()
	n.position = pos
	n.z_index = 2
	if kind == "wave":
		_shape(n, PackedVector2Array([
			Vector2(-14, 0), Vector2(-10, -10), Vector2(-4, -22), Vector2(2, -12), Vector2(8, -26), Vector2(12, -10), Vector2(16, 0)
		]), col, 0.25, 1.4)
		_shape(n, PackedVector2Array([Vector2(-8, 0), Vector2(-3, -12), Vector2(3, -6), Vector2(8, 0)]), Color("#fff3b0"), 0.1, 0.0)
		_glow(n, Vector2(0, -8), 30.0, Color(1.0, 0.6, 0.2, 0.7))
	else:
		_shape(n, _pts_ellipse(Vector2.ZERO, radius, radius, 12), col, 0.3, 1.5)
		_shape(n, _pts_ellipse(Vector2(-radius * 0.2, -radius * 0.2), radius * 0.5, radius * 0.5, 8), Color(1, 1, 1, 0.8), 0.0, 0.0)
		_glow(n, Vector2.ZERO, radius * 3.2, Color(col.r, col.g, col.b, 0.6))
	dynamic.add_child(n)
	projectiles.append({"node": n, "vel": vel, "grav": grav, "life": life, "kind": kind, "r": radius, "trail": 0.0})

func _update_projectiles(delta: float) -> void:
	var prect := _player_rect()
	var i := projectiles.size() - 1
	while i >= 0:
		var pr: Dictionary = projectiles[i]
		var n: Node2D = pr["node"]
		var kill := false
		if not is_instance_valid(n):
			projectiles.remove_at(i)
			i -= 1
			continue
		var vel: Vector2 = pr["vel"]
		vel.y += float(pr["grav"]) * delta
		pr["vel"] = vel
		n.position += vel * delta
		pr["life"] = float(pr["life"]) - delta
		var kind: String = pr["kind"]
		var r: float = pr["r"]
		if kind == "wave":
			n.position.y = GROUND_TOP
			if prect.intersects(Rect2(n.position.x - 14.0, GROUND_TOP - 26.0, 28.0, 26.0)):
				_hurt_player(1, n.position.x)
				if state != State.PLAYING:
					return
		else:
			pr["trail"] = float(pr["trail"]) - delta
			if float(pr["trail"]) <= 0.0:
				pr["trail"] = 0.06
				_burst(n.global_position, Color(1.0, 0.8, 0.4), 1, 20.0, 0.25)
			n.rotation += delta * 8.0
			if player.global_position.distance_to(n.position) < r + 11.0:
				_hurt_player(1, n.position.x)
				kill = true
				if state != State.PLAYING:
					return
			elif n.position.y > GROUND_TOP - r and _segment_at(n.position.x).y - _segment_at(n.position.x).x < 400.0 and n.position.y < GROUND_TOP + 10.0:
				if _on_ground(n.position.x):
					kill = true
		if float(pr["life"]) <= 0.0 or n.position.y > PIT_Y:
			kill = true
		if kill:
			_burst(n.global_position, Color(1.0, 0.7, 0.3), 6, 90.0, 0.3)
			n.queue_free()
			projectiles.remove_at(i)
		i -= 1

func _on_ground(x: float) -> bool:
	for seg in ground_segs:
		if x >= seg[0] and x <= seg[1]:
			return true
	return false


# ─────────────────────────────── HUD / menus ───────────────────────────────
var pad_down_prev := false
var mod_banner_t := 0.0

func _make_weather_layer() -> void:
	weather_layer = CanvasLayer.new()
	weather_layer.layer = 2
	add_child(weather_layer)

func _make_hud() -> void:
	style_norm = _box(Color("#18233a"), Color("#3b4d73"))
	style_sel = _box(Color("#2b4278"), Color("#ffe28a"))
	style_sel.set_border_width_all(3)
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ui_root)

	var vg := Gradient.new()
	vg.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	vg.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.62)])
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.0, 0.5)
	vt.width = 256
	vt.height = 256
	var vig := TextureRect.new()
	vig.texture = vt
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(vig)

	var tl := VBoxContainer.new()
	tl.position = Vector2(18, 14)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(tl)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	tl.add_child(hb)
	for i in max_health:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(27, 21)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.texture = tex_heart
		hb.add_child(tr)
		heart_icons.append(tr)
	score_label = _label("SCORE 0000", 18, Color("#7ef9ff"))
	tl.add_child(score_label)
	dash_label = _label("DASH READY", 14, Color("#c5d1e6"))
	tl.add_child(dash_label)
	crystal_label = _label("CRYSTALS 0", 15, Color("#ffe28a"))
	tl.add_child(crystal_label)
	var weapon_label_ref = _label("WEAPON: SWORD [TAB/LB]", 13, Color("#c5d1e6"))
	weapon_label_ref.name = "WeaponLabel"
	tl.add_child(weapon_label_ref)

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

	level_label = _label("LEVEL 1", 16, Color("#ffe28a"))
	level_label.anchor_left = 0.5
	level_label.anchor_right = 0.5
	level_label.offset_left = -300.0
	level_label.offset_right = 300.0
	level_label.offset_top = 28.0
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_root.add_child(level_label)

	mod_label = _label("", 14, Color("#ff9aa5"))
	mod_label.anchor_left = 0.5
	mod_label.anchor_right = 0.5
	mod_label.offset_left = -300.0
	mod_label.offset_right = 300.0
	mod_label.offset_top = 50.0
	mod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_root.add_child(mod_label)

	status_label = _label("", 18, Color("#ffe28a"))
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.offset_left = -300.0
	status_label.offset_right = 300.0
	status_label.offset_top = 72.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_root.add_child(status_label)

	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.anchor_left = 0.5
	boss_bar.anchor_right = 0.5
	boss_bar.offset_left = -200.0
	boss_bar.offset_right = 200.0
	boss_bar.offset_top = 104.0
	boss_bar.offset_bottom = 116.0
	boss_bar.add_theme_stylebox_override("background", _box(Color("#2a1018"), Color("#7a3340")))
	boss_bar.add_theme_stylebox_override("fill", _box(Color("#ff5d6c"), Color("#ff5d6c")))
	boss_bar.visible = false
	ui_root.add_child(boss_bar)

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

	var ver := Label.new()
	ver.text = "v6 TITLE+MP+MOBILE"
	ver.position = Vector2(8, 520)
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color("#ffe28a"))
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(ver)

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

	# ── Title: Singleplayer / Multiplayer ──
	screen_title = VBoxContainer.new()
	screen_title.add_theme_constant_override("separation", 10)
	screen_title.visible = true
	holder.add_child(screen_title)
	var title_note := _label("— SELECT MODE —", 14, Color("#ffe28a"))
	title_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_title.add_child(title_note)
	sp_btn = Button.new()
	sp_btn.text = "SINGLEPLAYER"
	sp_btn.pressed.connect(_on_title_singleplayer)
	mp_menu_btn = Button.new()
	mp_menu_btn.text = "MULTIPLAYER"
	mp_menu_btn.pressed.connect(_on_title_multiplayer)
	title_quit_btn = Button.new()
	title_quit_btn.text = "QUIT"
	title_quit_btn.pressed.connect(func() -> void: get_tree().quit())
	title_quit_btn.visible = not OS.has_feature("web")
	for b in [sp_btn, mp_menu_btn, title_quit_btn]:
		_style_button(b, Vector2(340, 48))
		screen_title.add_child(b)
	title_rows = [[sp_btn], [mp_menu_btn], [title_quit_btn]]

	# ── Multiplayer submenu ──
	screen_mp = VBoxContainer.new()
	screen_mp.add_theme_constant_override("separation", 8)
	screen_mp.visible = false
	holder.add_child(screen_mp)
	local2_btn = Button.new()
	local2_btn.text = "LOCAL CO-OP (2 PLAYERS)"
	local2_btn.pressed.connect(_start_local_coop)
	host_btn = Button.new()
	host_btn.text = "HOST LAN (PORT 7777)"
	host_btn.pressed.connect(_mp_host)
	mp_ip_edit = LineEdit.new()
	mp_ip_edit.placeholder_text = "Host IP, e.g. 192.168.1.25"
	mp_ip_edit.text = ""
	mp_ip_edit.custom_minimum_size = Vector2(320, 38)
	mp_ip_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_btn = Button.new()
	join_btn.text = "JOIN LAN (ENTER HOST IP BELOW)"
	join_btn.pressed.connect(_mp_join)
	mp_battle_btn = Button.new()
	mp_battle_btn.text = "BATTLE MODE: OFF"
	mp_battle_btn.pressed.connect(_mp_toggle_battle)
	mp_start_btn = Button.new()
	mp_start_btn.text = "START GAME (HOST)"
	mp_start_btn.pressed.connect(_mp_start_battle)
	mp_back_btn = Button.new()
	mp_back_btn.text = "BACK"
	mp_back_btn.pressed.connect(_on_title_show)
	mp_status_lbl = Label.new()
	mp_status_lbl.text = "Pick a mode — same Wi-Fi for LAN"
	mp_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_status_lbl.add_theme_font_size_override("font_size", 13)
	mp_status_lbl.add_theme_color_override("font_color", Color("#7ef9ff"))
	for b in [local2_btn, host_btn, join_btn, mp_battle_btn, mp_start_btn, mp_back_btn]:
		_style_button(b, Vector2(320, 38))
		screen_mp.add_child(b)
	screen_mp.add_child(mp_ip_edit)
	screen_mp.move_child(mp_ip_edit, screen_mp.get_child_count() - 2)
	screen_mp.add_child(mp_status_lbl)
	mp_rows = [[local2_btn], [host_btn], [join_btn], [mp_battle_btn], [mp_start_btn], [mp_back_btn]]

	screen_main = VBoxContainer.new()
	screen_main.add_theme_constant_override("separation", 8)
	screen_main.visible = false
	holder.add_child(screen_main)
	var help := _label("A/D move  SPACE jump  J sword  L grapple  K dash  TAB weapon\nPad: stick  A jump  X sword  Y/RT grapple  B dash  LB weapon  START pause", 12, Color("#c5d1e6"))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_main.add_child(help)
	# Always-visible mode buttons inside main as backup
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	screen_main.add_child(mode_row)
	var sp2 := Button.new()
	sp2.text = "SINGLEPLAYER"
	sp2.pressed.connect(_on_title_singleplayer)
	var mp2 := Button.new()
	mp2.text = "MULTIPLAYER"
	mp2.pressed.connect(_on_title_multiplayer)
	for b in [sp2, mp2]:
		_style_button(b, Vector2(160, 36))
		mode_row.add_child(b)
	resume_btn = Button.new()
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn = Button.new()
	restart_btn.pressed.connect(_on_restart_pressed)
	levels_btn = Button.new()
	levels_btn.text = "LEVEL SELECT"
	levels_btn.pressed.connect(_show_levels)
	upgrades_btn = Button.new()
	upgrades_btn.text = "UPGRADES"
	upgrades_btn.pressed.connect(_show_upgrades)
	music_btn = Button.new()
	music_btn.pressed.connect(_toggle_music)
	random_btn = Button.new()
	random_btn.pressed.connect(_toggle_random)
	quit_btn = Button.new()
	quit_btn.text = "QUIT"
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	quit_btn.visible = not OS.has_feature("web")
	for b in [resume_btn, restart_btn, levels_btn, upgrades_btn, music_btn, random_btn, quit_btn]:
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

	main_rows = [[resume_btn], [restart_btn], [levels_btn], [upgrades_btn], [music_btn], [random_btn], [quit_btn]]
	level_rows = []
	for r in 5:
		var row: Array = []
		for c in 5:
			row.append(level_buttons[r * 5 + c])
		level_rows.append(row)
	level_rows.append([prev_btn, next_btn, unlock_btn, back_btn])

	# ── Upgrade screen (same custom nav as level select) ──
	screen_upgrades = VBoxContainer.new()
	screen_upgrades.add_theme_constant_override("separation", 6)
	screen_upgrades.visible = false
	holder.add_child(screen_upgrades)
	upgrade_title = _label("UPGRADES", 18, Color("#7ef9ff"))
	upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_upgrades.add_child(upgrade_title)
	upgrade_hint = _label("CRYSTALS: 0", 14, Color("#ffe28a"))
	upgrade_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_upgrades.add_child(upgrade_hint)
	var ugrid := GridContainer.new()
	ugrid.columns = 2
	ugrid.add_theme_constant_override("h_separation", 8)
	ugrid.add_theme_constant_override("v_separation", 6)
	screen_upgrades.add_child(ugrid)
	upgrade_buttons.clear()
	for i in UPGRADE_PAGE_SIZE:
		var ub := Button.new()
		_style_button(ub, Vector2(360, 40))
		ub.pressed.connect(_on_upgrade_slot_pressed.bind(i))
		ub.mouse_entered.connect(_on_upgrade_hover.bind(i))
		ub.mouse_exited.connect(_on_upgrade_unhover)
		ugrid.add_child(ub)
		upgrade_buttons.append(ub)
	# Hover tooltip (dark box)
	upgrade_tooltip = PanelContainer.new()
	upgrade_tooltip.visible = false
	upgrade_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_tooltip.z_index = 50
	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0.04, 0.05, 0.09, 0.96)
	tip_sb.set_border_width_all(1)
	tip_sb.border_color = Color("#7ef9ff")
	tip_sb.set_corner_radius_all(6)
	tip_sb.content_margin_left = 12
	tip_sb.content_margin_right = 12
	tip_sb.content_margin_top = 8
	tip_sb.content_margin_bottom = 8
	upgrade_tooltip.add_theme_stylebox_override("panel", tip_sb)
	upgrade_tooltip_label = Label.new()
	upgrade_tooltip_label.add_theme_font_size_override("font_size", 13)
	upgrade_tooltip_label.add_theme_color_override("font_color", Color("#e8f0ff"))
	upgrade_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_tooltip_label.custom_minimum_size = Vector2(280, 0)
	upgrade_tooltip.add_child(upgrade_tooltip_label)
	ui_root.add_child(upgrade_tooltip)
	var unav := HBoxContainer.new()
	unav.add_theme_constant_override("separation", 6)
	unav.alignment = BoxContainer.ALIGNMENT_CENTER
	screen_upgrades.add_child(unav)
	var uprev := Button.new()
	uprev.text = "< PREV"
	uprev.pressed.connect(_change_upgrade_page.bind(-1))
	var unext := Button.new()
	unext.text = "NEXT >"
	unext.pressed.connect(_change_upgrade_page.bind(1))
	var ucat := Button.new()
	ucat.text = "CATEGORY"
	ucat.pressed.connect(_cycle_upgrade_cat)
	respec_btn = Button.new()
	respec_btn.text = "RESPEC"
	respec_btn.pressed.connect(_respec_upgrades)
	var uback := Button.new()
	uback.text = "BACK"
	uback.pressed.connect(_back_to_main)
	for b in [uprev, unext, ucat, respec_btn, uback]:
		_style_button(b, Vector2(100, 34))
		unav.add_child(b)
	upgrade_rows = []
	for r in 6:
		var row2: Array = []
		for c in 2:
			var idx2 := r * 2 + c
			if idx2 < UPGRADE_PAGE_SIZE:
				row2.append(upgrade_buttons[idx2])
		if row2.size() > 0:
			upgrade_rows.append(row2)
	upgrade_rows.append([uprev, unext, ucat, respec_btn, uback])

	pad_status = _label("", 13, Color("#8bf5b5"))
	pad_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(pad_status)
	pad_hint = _label("D-PAD / STICK move     A select     B back     START resume     LB / RB page", 12, Color("#8d9ab8"))
	pad_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(pad_hint)

func _open_menu(title: String, subtitle: String, resume_text: String, mode: String, restart_text := "") -> void:
	menu_mode = mode
	menu_title.text = title
	menu_hint.text = subtitle
	resume_btn.text = resume_text
	restart_btn.visible = restart_text != ""
	restart_btn.text = restart_text
	# Fail-safe: guarantee UPGRADES button is in the tree and visible
	if upgrades_btn == null or not is_instance_valid(upgrades_btn):
		upgrades_btn = Button.new()
		upgrades_btn.text = "UPGRADES"
		upgrades_btn.pressed.connect(_show_upgrades)
		_style_button(upgrades_btn)
		screen_main.add_child(upgrades_btn)
	upgrades_btn.visible = true
	upgrades_btn.text = "UPGRADES"
	# Rebuild main_rows so nav always includes it
	main_rows = [[resume_btn], [restart_btn], [levels_btn], [upgrades_btn], [music_btn], [random_btn], [quit_btn]]
	menu_panel.visible = true
	_show_screen("main")
	_update_pad_status()

func _open_start_menu() -> void:
	menu_mode = "start"
	menu_panel.visible = true
	menu_title.text = "PIXELBOUND v6"
	menu_hint.text = "SINGLEPLAYER  or  MULTIPLAYER"
	resume_btn.text = "PLAY"
	restart_btn.visible = false
	_show_screen("title")
	_update_pad_status()

func _show_screen(which: String) -> void:
	if screen_title != null:
		screen_title.visible = which == "title"
	if screen_mp != null:
		screen_mp.visible = which == "mp"
	screen_main.visible = which == "main"
	screen_levels.visible = which == "levels"
	if screen_upgrades != null:
		screen_upgrades.visible = which == "upgrades"
	if which != "upgrades" and is_instance_valid(upgrade_tooltip):
		upgrade_tooltip.visible = false
	if which == "title" and title_rows.size() > 0:
		_set_menu_rows(title_rows, 0, 0)
	elif which == "mp" and mp_rows.size() > 0:
		_set_menu_rows(mp_rows, 0, 0)
	elif which == "main":
		_set_menu_rows(main_rows, 0, 0)
	elif which == "levels":
		_set_menu_rows(level_rows, 0, 0)
	elif which == "upgrades" and upgrade_rows.size() > 0:
		_set_menu_rows(upgrade_rows, 0, 0)

func _show_levels() -> void:
	menu_title.text = "LEVEL SELECT"
	_show_screen("levels")
	_focus_level(mini(current_level, maxi(1, unlocked)))

func _back_to_main() -> void:
	if screen_upgrades != null:
		screen_upgrades.visible = false
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
	page_label.text = "PAGE %d / %d      CLEARED %d / %d" % [level_page + 1, PAGE_COUNT, level_best.size(), TOTAL_LEVELS]
	menu_hint.text = "WORLD  -  " + String(_theme_for(level_page * PAGE_SIZE + 1)["name"]) if screen_levels.visible else menu_hint.text
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
		b.add_theme_color_override("font_hover_color", col)
	_refresh_toggles()

func _change_page(dir: int) -> void:
	level_page = clampi(level_page + dir, 0, PAGE_COUNT - 1)
	_refresh_level_page()
	_fix_selection()
	_apply_selection()
	_sfx(600.0, 0.04, 0.06)

func _focus_level(n: int) -> void:
	level_page = clampi(floori(float(n - 1) / float(PAGE_SIZE)), 0, PAGE_COUNT - 1)
	_refresh_level_page()
	var idx := (n - 1) % PAGE_SIZE
	_set_menu_rows(level_rows, idx / 5, idx % 5)

func _on_level_slot_pressed(slot: int) -> void:
	var n := level_page * PAGE_SIZE + slot + 1
	if _is_unlocked(n):
		_start_level(n)

func _toggle_unlock_all() -> void:
	unlock_all = not unlock_all
	_refresh_level_page()
	_fix_selection()
	_apply_selection()
	_save_game(false)

func _toggle_random() -> void:
	randomize_layout = not randomize_layout
	_refresh_toggles()
	_save_game(false)

func _refresh_toggles() -> void:
	if music_btn == null:
		return
	music_btn.text = "MUSIC: ON" if music_on else "MUSIC: OFF"
	random_btn.text = "LEVEL LAYOUTS: NEW EVERY RUN" if randomize_layout else "LEVEL LAYOUTS: FIXED"
	unlock_btn.text = "UNLOCK ALL: ON" if unlock_all else "UNLOCK ALL: OFF"

func _fmt_time(t: float) -> String:
	return "%02d:%04.1f" % [floori(t / 60.0), fmod(t, 60.0)]

func _run_summary() -> String:
	return "Level %d      Score %d      Time %s" % [current_level, score, _fmt_time(run_time)]

func _update_hud() -> void:
	for i in heart_icons.size():
		heart_icons[i].texture = tex_heart if i < health else tex_heart_empty
	score_label.text = "SCORE %05d" % (total_score + score)
	time_label.text = "TIME " + _fmt_time(run_time)
	best_label.text = "BEST " + (_fmt_time(float(level_best[current_level])) if level_best.has(current_level) else "--:--.-")
	if dash_cd <= 0.0:
		dash_label.text = "DASH READY"
		dash_label.modulate = Color.WHITE
	else:
		dash_label.text = "DASH %.1f" % dash_cd
		dash_label.modulate = Color(1, 1, 1, 0.5)
	if crystal_label != null:
		crystal_label.text = "CRYSTALS %d" % crystal_bank
	var wl = ui_root.find_child("WeaponLabel", true, false)
	if wl != null:
		wl.text = "WEAPON: %s  [TAB / LB]" % ("GRAPPLE" if weapon_mode == "grapple" else "SWORD")
	level_label.text = "LEVEL %d  -  %s%s" % [current_level, String(theme.get("name", "")), "   [ WARDEN ]" if bool(level_data.get("boss", false)) else ""]
	mod_label.text = ("MODIFIER: %s  -  %s" % [modifier, String(MOD_INFO[modifier])]) if modifier != "" else ""
	progress.value = clampf(player.global_position.x / exit_x, 0.0, 1.0) * 100.0
	if boss_alive and is_instance_valid(boss_ref) and absf(boss_ref.global_position.x - player.global_position.x) < 800.0:
		var bs := _st(boss_ref)
		boss_bar.visible = true
		boss_bar.max_value = float(bs["max_hp"])
		boss_bar.value = maxf(0.0, float(bs["hp"]))
	else:
		boss_bar.visible = false

func _toast(text: String, secs := 1.4) -> void:
	message_text = text
	message_time = secs
	status_label.text = text

# ─────────────────────────────── State flow ───────────────────────────────
func _set_state(s: State) -> void:
	state = s
	for tw in platform_tweens:
		if tw != null and tw.is_valid():
			if s == State.PLAYING:
				tw.play()
			else:
				tw.pause()
	_refresh_mobile_visibility()

func _start_playing() -> void:
	menu_panel.visible = false
	input_lock = 0.2
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
			_start_level(current_level, true)

func _on_restart_pressed() -> void:
	_start_level(current_level, true)

func _start_level(n: int, reuse_seed := false) -> void:
	var same := reuse_seed and int(level_data.get("n", 0)) == clampi(n, 1, TOTAL_LEVELS)
	current_level = clampi(n, 1, TOTAL_LEVELS)
	_set_state(State.MENU)
	_build_level(current_level, level_seed if same else _new_seed(current_level))
	health = max_health
	score = 0
	shards = 0
	crystal_bank += int(stats.get("start_crystals", 0))
	combo = 0
	checkpoint_idx = -1
	run_time = 0.0
	if grapple_state != "idle":
		_detach_grapple()
	revive_used = false
	invulnerable = 0.0
	attack_cd = 0.0
	dash_cd = 0.0
	hitstop = 0.0
	_refresh_checkpoints()
	_place_player_at_checkpoint()
	_update_hud()
	var banner := "LEVEL %d  -  %s" % [current_level, String(theme["name"])]
	if modifier != "":
		banner += "     MODIFIER: " + modifier
	_toast(banner, 2.6)
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
	_refresh_toggles()
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
	var clear_cr := 15 + int(stats.get("clear_bonus", 0))
	if bool(level_data.get("boss", false)): clear_cr += 40
	crystal_bank += clear_cr
	score = 0
	unlocked = maxi(unlocked, mini(TOTAL_LEVELS, current_level + 1))
	_save_game(false)
	for i in 4:
		_sfx([523.25, 659.25, 783.99, 1046.5][i], 0.25, 0.12, 0.0, 0, 0.12 * float(i))
	_burst(player.global_position, Color("#c4b5fd"), 30, 260.0, 1.0)
	_update_hud()
	_refresh_level_page()
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
	crystal_bank += 40 + int(stats.get("boss_bonus", 0))
	shake = 14.0
	exit_node.modulate = Color.WHITE
	_toast("WARDEN DEFEATED - THE PORTAL OPENS!", 2.5)
	for i in 4:
		_sfx([392.0, 523.25, 659.25, 783.99][i], 0.2, 0.12, 0.0, 0, 0.1 * float(i))

# ─────────────────────────────── Main loop ───────────────────────────────
func _physics_process(delta: float) -> void:
	_poll_pad()
	if state != State.PLAYING or hitstop > 0.0:
		return
	run_time += delta
	# HP regen from upgrades
	var reg := float(stats.get("regen", 0.0))
	if reg > 0.0 and health < max_health and health > 0:
		regen_t += delta * reg
		if regen_t >= 1.0:
			regen_t = 0.0
			health = mini(max_health, health + 1)
			_update_hud()
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
	_update_player2(delta)
	_mp_sync_tick()
	if state != State.PLAYING:
		return
	_update_sword(delta)
	_update_enemies(delta)
	if state != State.PLAYING:
		return
	_update_projectiles(delta)
	if state != State.PLAYING:
		return
	_update_player_arrows(delta)
	if state != State.PLAYING:
		return
	_update_hazards(delta)
	if state != State.PLAYING:
		return
	_update_items(delta)
	_update_triggers()
	if state == State.PLAYING:
		_update_hud()

func _player_rect() -> Rect2:
	return Rect2(player.global_position - Vector2(10.0, 16.0), Vector2(20.0, 32.0))

func _update_player(delta: float) -> void:
	var locked := input_lock > 0.0
	var axis := 0.0
	if not locked:
		axis = Input.get_axis("move_left", "move_right")
		var pa := _pad_axis_x()
		if absf(pa) > absf(axis):
			axis = pa
		if is_touch_device and absf(mob_axis.x) > absf(axis):
			axis = mob_axis.x
	var jump_pressed := not locked and (Input.is_action_just_pressed("jump") or _btn_just(JOY_BUTTON_A) or mob_jump)
	var jump_released := not locked and (Input.is_action_just_released("jump") or _btn_released(JOY_BUTTON_A) or (is_touch_device and not mob_jump and not Input.is_action_pressed("jump")))
	var dash_pressed := not locked and (Input.is_action_just_pressed("dash") or _btn_just(JOY_BUTTON_B) or mob_dash)
	var attack_pressed := not locked and (Input.is_action_just_pressed("attack") or _btn_just(JOY_BUTTON_X) or mob_sword)
	var pdown := _pad_down()
	if is_touch_device and mob_axis.y > 0.55:
		pdown = true
	var drop_pressed := not locked and (Input.is_action_just_pressed("drop") or (pdown and not pad_down_prev))
	pad_down_prev = pdown
	# consume one-shot mobile buttons
	mob_dash = false
	mob_sword = false
	if mob_pause_pressed:
		mob_pause_pressed = false
		if state == State.PLAYING:
			_pause()
		elif state == State.PAUSED:
			_on_resume_pressed()
	if mob_weapon_pressed:
		mob_weapon_pressed = false
		_toggle_weapon()
	var on_floor := player.is_on_floor()
	if hurt_stun <= 0.0 and dash_time <= 0.0:
		if axis > 0.1:
			facing = 1.0
		elif axis < -0.1:
			facing = -1.0

	if dash_pressed and dash_cd <= 0.0 and dash_time <= 0.0 and hurt_stun <= 0.0:
		dash_time = DASH_TIME
		dash_cd = maxf(0.15, DASH_COOLDOWN + float(stats.get("dash_cd", 0.0)))
		dash_dir = facing
		attack_t = -1.0
		_sfx(300.0, 0.16, 0.08, 1200.0, 1)
		_burst(player.global_position + Vector2(-facing * 8.0, 8.0), Color("#7ef9ff"), 8, 120.0, 0.3)

	if dash_time > 0.0:
		dash_time -= delta
		player.velocity = Vector2(dash_dir * (DASH_SPEED + float(stats.get("dash_spd", 0))), 0.0)
		# Dash i-frames extension
		if float(stats.get("dash_ifr", 0.0)) > 0.0:
			invulnerable = maxf(invulnerable, float(stats.get("dash_ifr", 0.0)))
		# Dash damage
		var dd := int(stats.get("dash_dmg", 0))
		if dd > 0:
			for e in enemies:
				if not is_instance_valid(e): continue
				var es := _st(e)
				if bool(es.get("dead", false)): continue
				if e.global_position.distance_to(player.global_position) < 28.0:
					_damage_enemy(e, dd, dash_dir)
		ghost_t -= delta
		if ghost_t <= 0.0:
			ghost_t = 0.04
			_ghost()
	else:
		if hurt_stun > 0.0:
			player.velocity.x = move_toward(player.velocity.x, 0.0, 600.0 * delta)
		else:
			var accel := GROUND_ACCEL if on_floor else (AIR_ACCEL + float(stats.get("air_accel", 0)))
			if absf(axis) < 0.01:
				accel = GROUND_FRICTION if on_floor else AIR_ACCEL * 0.5
			player.velocity.x = move_toward(player.velocity.x, axis * (MOVE_SPEED + float(stats.get("move_spd", 0))), accel * delta)
		var g := GRAVITY * grav_mul
		if player.velocity.y > 0.0:
			g *= FALL_GRAVITY_MULT
		player.velocity.y = minf(player.velocity.y + g * delta, MAX_FALL)

	if on_floor:
		coyote = COYOTE_TIME + float(stats.get("coyote", 0.0))
		double_jumps_left = int(stats.get("double_jump", 0))
	else:
		coyote -= delta
	if jump_pressed:
		jump_buffer = JUMP_BUFFER + float(stats.get("jump_buf", 0.0))
	else:
		jump_buffer -= delta
	if jump_buffer > 0.0 and coyote > 0.0 and dash_time <= 0.0 and hurt_stun <= 0.0:
		player.velocity.y = JUMP_SPEED + float(stats.get("jump_spd", 0))
		jump_buffer = 0.0
		coyote = 0.0
		double_jumps_left = int(stats.get("double_jump", 0))
	elif jump_buffer > 0.0 and double_jumps_left > 0 and not on_floor and dash_time <= 0.0 and hurt_stun <= 0.0:
		player.velocity.y = JUMP_SPEED + float(stats.get("jump_spd", 0))
		jump_buffer = 0.0
		double_jumps_left -= 1
		squash = Vector2(0.8, 1.2)
		_sfx(420.0, 0.1, 0.07, 500.0, 1)
		squash = Vector2(0.8, 1.25)
		_sfx(380.0, 0.12, 0.07, 700.0, 1)
		_burst(player.global_position + Vector2(0.0, 16.0), Color("#8d9ab8"), 5, 70.0, 0.3)
	if jump_released and player.velocity.y < 0.0:
		player.velocity.y *= JUMP_CUT

	if drop_time > 0.0:
		drop_time -= delta
		if drop_time <= 0.0:
			player.set_collision_mask_value(4, true)
	elif drop_pressed and on_floor:
		drop_time = 0.22
		player.set_collision_mask_value(4, false)

	if attack_pressed and dash_time <= 0.0 and (attack_t < 0.0 or attack_cd <= 0.0):
		if weapon_mode == "sword":
			_start_attack()
			if mp_battle_mode and (mp_mode == "host" or mp_mode == "client") and multiplayer.multiplayer_peer != null:
				_rpc_player_attack.rpc(multiplayer.get_unique_id(), player.global_position, facing)
		# bow draw is handled by the hold path below (attack counts as hold)

	# Grapple: tap/hold fire to shoot hook at roof; hold while stuck to reel in; release to detach
	var rt_held := false
	for dev in Input.get_connected_joypads():
		if Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.4:
			rt_held = true
			break
	var grap_held := not locked and weapon_mode == "grapple" and (
		Input.is_action_pressed("bow")
		or Input.is_action_pressed("attack")
		or _btn_held(JOY_BUTTON_Y)
		or _btn_held(JOY_BUTTON_X)
		or rt_held
		or mob_grapple
	)
	if weapon_mode == "grapple":
		_update_grapple(delta, grap_held)
	else:
		if grapple_state != "idle":
			_detach_grapple()
	bow_cd = maxf(0.0, bow_cd - delta)
	_apply_weapon_visuals()

	var pre_vy := player.velocity.y
	player.move_and_slide()
	if not on_floor and player.is_on_floor() and pre_vy > 250.0:
		var k := clampf(pre_vy / 700.0, 0.0, 1.0)
		squash = Vector2(1.0 + 0.25 * k, 1.0 - 0.25 * k)
		_burst(player.global_position + Vector2(0.0, 16.0), Color("#8d9ab8"), 6, 80.0, 0.3)
		_sfx(110.0, 0.06, 0.08, -100.0, 2)

	if player.global_position.x < 16.0:
		player.global_position.x = 16.0
		player.velocity.x = maxf(0.0, player.velocity.x)
	# ground shadow
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(player.global_position, player.global_position + Vector2(0.0, 600.0), L_SOLID | L_ONEWAY)
	var res := space.intersect_ray(q)
	shadow_y = float(res["position"].y) if not res.is_empty() else -1000.0
	if player.global_position.y > PIT_Y:
		_fall_into_pit()

# ─────────────────────────────── Sword ───────────────────────────────
func _start_attack() -> void:
	attack_style = (attack_style + 1) % 3 if combo_window > 0.0 else 0
	var st: Array = ATTACK_STYLES[attack_style]
	var dur: float = st[5]
	attack_t = 0.0
	attack_cd = maxf(0.08, dur * 0.7 + float(stats.get("sword_cd", 0.0)))
	combo_window = dur + 0.35 + float(stats.get("sword_combo", 0.0))
	attack_hits.clear()
	_sfx(520.0 + 90.0 * float(attack_style), 0.1, 0.06, -900.0, 1)
	var a0: float = minf(float(st[0]), float(st[1]))
	var a1: float = maxf(float(st[0]), float(st[1]))
	var reach := 54.0 if attack_style == 2 else 47.0
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var base_col := Color("#bff6ff") if attack_style < 2 else Color("#ffe28a")
	for i in 9:
		var a := lerpf(a0, a1, float(i) / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * reach)
		cols.append(Color(base_col.r, base_col.g, base_col.b, 0.9 * (0.25 + 0.75 * float(i) / 8.0)))
	for i in range(8, -1, -1):
		var a := lerpf(a0, a1, float(i) / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * (reach - 16.0))
		cols.append(Color(base_col.r, base_col.g, base_col.b, 0.0))
	var slash := Polygon2D.new()
	slash.polygon = pts
	slash.vertex_colors = cols
	slash.material = mat_add
	slash.scale.x = facing
	slash.position = Vector2(2.0 * facing, -4.0)
	slash.modulate.a = 0.0
	player.add_child(slash)
	var tw := create_tween()
	tw.tween_interval(dur * 0.2)
	tw.tween_property(slash, "modulate:a", 1.0, 0.02)
	tw.tween_property(slash, "modulate:a", 0.0, dur * 0.4)
	tw.tween_callback(slash.queue_free)

func _update_sword(delta: float) -> void:
	if attack_t < 0.0:
		return
	attack_t += delta
	var st: Array = ATTACK_STYLES[attack_style]
	var dur: float = st[5]
	if attack_t >= dur * 0.2 and attack_t <= dur * 0.66:
		var size := Vector2(float(st[3]) + float(stats.get("sword_width", 0)), 58.0 if attack_style == 2 else 48.0)
		var center := player.global_position + Vector2(facing * (float(st[4]) + float(stats.get("sword_reach", 0))), -4.0)
		var box := Rect2(center - size * 0.5, size)
		for e in enemies:
			if not is_instance_valid(e):
				continue
			var es := _st(e)
			if bool(es["dead"]):
				continue
			var eid := e.get_instance_id()
			if attack_hits.has(eid):
				continue
			var esz: Vector2 = es["size"]
			if box.intersects(Rect2(e.global_position - esz * 0.5, esz)):
				attack_hits[eid] = true
				var dmg := int(st[2]) + int(stats.get("sword_dmg", 0))
				if attack_style == 2:
					dmg += int(stats.get("sword_finisher", 0))
				if rng.randf() * 100.0 < float(stats.get("sword_crit", 0)):
					dmg = int(dmg * 1.75)
					_float_text(e.global_position, "CRIT!", Color("#ffe28a"))
				_damage_enemy(e, dmg, facing)
				# lifesteal
				var ls := int(stats.get("sword_lifesteal", 0))
				if ls > 0 and rng.randf() * 100.0 < float(ls):
					health = mini(max_health, health + 1)
					_float_text(player.global_position, "+1", Color("#ff7b86"))
				shake = maxf(shake, 4.0 if attack_style == 2 else 2.5)
		var pi := projectiles.size() - 1
		while pi >= 0:
			var pr: Dictionary = projectiles[pi]
			var pn: Node2D = pr["node"]
			if String(pr["kind"]) == "orb" and is_instance_valid(pn) and box.has_point(pn.position):
				_burst(pn.global_position, Color.WHITE, 8, 140.0, 0.3)
				_sfx(900.0, 0.06, 0.1)
				score += 2
				pn.queue_free()
				projectiles.remove_at(pi)
			pi -= 1
	if attack_t >= dur:
		attack_t = -1.0

func _hurt_player(amount: int, from_x: float) -> void:
	if state != State.PLAYING or invulnerable > 0.0 or dash_time > 0.0:
		return
	# Trap-specific resists
	var trap_red := float(stats.get("trap_all", 0)) * 0.08
	match last_hazard:
		"saw": trap_red += float(stats.get("trap_saw", 0)) * 0.12
		"flame": trap_red += float(stats.get("trap_flame", 0)) * 0.12
		"laser": trap_red += float(stats.get("trap_laser", 0)) * 0.12
		"spike": trap_red += float(stats.get("trap_spike", 0)) * 0.12
	last_hazard = ""
	var red := clampf(float(stats.get("armor", 0)) / 100.0 + trap_red, 0.0, 0.75)
	# Near-death power: less damage when low HP
	if health <= 2:
		red = minf(0.85, red + float(stats.get("near_death", 0)) * 0.08)
	amount = maxi(1, int(ceil(float(amount) * (1.0 - red))))
	# Thorns: tiny reflect chance toward nearest enemy handled after
	var thorn_rank := int(stats.get("thorns", 0))
	health -= amount
	invulnerable = INVULN_TIME + float(stats.get("invuln", 0.0))
	hurt_stun = maxf(0.05, 0.22 * (1.0 - float(stats.get("stun_red", 0)) / 100.0))
	attack_t = -1.0
	hitstop = maxf(hitstop, 0.07)
	var dir := signf(player.global_position.x - from_x)
	if dir == 0.0:
		dir = -facing
	player.velocity = Vector2(dir * 280.0, -300.0)
	shake = maxf(shake, 7.0)
	_sfx(140.0, 0.2, 0.14, -200.0, 2)
	_burst(player.global_position, Color("#ff7b86"), 12, 170.0, 0.5)
	if health <= 0:
		if not revive_used and int(stats.get("revive", 0)) > 0:
			revive_used = true
			health = maxi(1, max_health // 2)
			invulnerable = 2.0
			_toast("SECOND WIND!")
			_sfx(660.0, 0.2, 0.12)
			_burst(player.global_position, Color("#ffe28a"), 16, 200.0, 0.6)
			_update_hud()
		else:
			_on_death("RIFT RUN ENDED")
	else:
		# Thorns reflect
		if thorn_rank > 0:
			for e in enemies:
				if is_instance_valid(e) and e.global_position.distance_to(player.global_position) < 50.0:
					_damage_enemy(e, thorn_rank, signf(e.global_position.x - player.global_position.x))
					break
		_update_hud()

func _fall_into_pit() -> void:
	var pit_dmg := maxi(0, 1 - int(stats.get("pit_forgive", 0)))
	health -= pit_dmg
	shake = 8.0
	_sfx(200.0, 0.4, 0.14, -400.0, 1)
	if health <= 0:
		_on_death("SWALLOWED BY THE RIFT")
	else:
		_toast("FELL INTO THE RIFT  -1 HEART")
		_place_player_at_checkpoint()
		invulnerable = 1.5

# ─────────────────────────────── Traps ───────────────────────────────
func _update_hazards(delta: float) -> void:
	var prect := _player_rect()
	var t := run_time
	for h in hazards:
		if state != State.PLAYING:
			return
		match String(h["t"]):
			"saw":
				var x := float(h["x"]) + float(h["range"]) * sin(t * float(h["speed"]) + float(h["phase"]))
				(h["node"] as Node2D).position.x = x
				(h["blade"] as Node2D).rotation += delta * 14.0
				if prect.intersects(Rect2(x - 15.0, GROUND_TOP - 30.0, 30.0, 30.0)):
					last_hazard = "saw"
					_hurt_player(1, x)
				h["spark"] = float(h["spark"]) - delta
				if float(h["spark"]) <= 0.0:
					h["spark"] = 0.14
					_burst(Vector2(x, GROUND_TOP - 2.0), Color(1.0, 0.8, 0.4), 2, 90.0, 0.25)
			"flame":
				var ph := fposmod(t + float(h["phase"]), 3.4)
				var inten := 0.0
				var glow_a := 0.08
				if ph >= 1.8 and ph < 2.4:
					glow_a = 0.15 + 0.4 * (ph - 1.8) / 0.6
					inten = 0.12 + 0.04 * sin(t * 40.0)
				elif ph >= 2.4:
					var u := (ph - 2.4) / 1.0
					inten = clampf(minf(u * 6.0, (1.0 - u) * 6.0), 0.0, 1.0)
					glow_a = 0.9 * inten
				var fire: Node2D = h["fire"]
				fire.visible = inten > 0.03
				fire.scale = Vector2(1.0 + 0.06 * sin(t * 40.0), maxf(0.03, inten * (1.0 + 0.06 * sin(t * 33.0 + 1.0))))
				(h["glow"] as Sprite2D).modulate.a = glow_a
				(h["embers"] as CPUParticles2D).emitting = inten > 0.5
				if inten > 0.5:
					var fx := float(h["x"])
					if prect.intersects(Rect2(fx - 12.0, GROUND_TOP - 100.0 * inten, 24.0, 100.0 * inten)):
						last_hazard = "flame"
						_hurt_player(1, fx)
			"laser":
				var ph2 := fposmod(t + float(h["phase"]), 3.0)
				var on := ph2 < 1.4
				var warn := ph2 >= 2.55
				(h["beam"] as Line2D).visible = on
				(h["beam_glow"] as Line2D).visible = on
				(h["warn"] as Line2D).default_color.a = (0.3 + 0.5 * absf(sin(t * 30.0))) if warn else 0.22
				for orb in h["orbs"]:
					(orb as Node2D).modulate = Color(1.8, 1.8, 1.8) if (on or warn) else Color.WHITE
				if on and not bool(h["on"]):
					_sfx(1200.0, 0.2, 0.06, -900.0, 1)
				h["on"] = on
				if on and prect.intersects(Rect2(float(h["x1"]), float(h["y"]) - 3.0, float(h["x2"]) - float(h["x1"]), 6.0)):
					last_hazard = "laser"
					_hurt_player(1, (float(h["x1"]) + float(h["x2"])) * 0.5)
			"pendulum":
				var ang := float(h["amp"]) * sin(t * TAU / float(h["period"]) + float(h["phase"]))
				(h["swing"] as Node2D).rotation = ang
				var hp := (h["head"] as Node2D).global_position
				if prect.intersects(Rect2(hp - Vector2(26.0, 22.0), Vector2(52.0, 44.0))):
					_hurt_player(1, hp.x)
			"rock":
				_update_rock(h, delta, prect)
			"spring":
				var sx := float(h["x"])
				h["anim"] = maxf(0.0, float(h["anim"]) - delta)
				var an := float(h["anim"])
				(h["pad"] as Node2D).scale.y = 1.0 - 0.5 * clampf(an / 0.25, 0.0, 1.0) + 0.15 * sin(an * 40.0) * clampf(an / 0.25, 0.0, 1.0)
				var feet := player.global_position.y + 16.0
				if an <= 0.0 and absf(player.global_position.x - sx) < 17.0 and feet > GROUND_TOP - 34.0 and feet < GROUND_TOP + 4.0 and player.velocity.y >= -50.0:
					player.velocity.y = -900.0
					squash = Vector2(0.75, 1.3)
					h["anim"] = 0.25
					_sfx(500.0, 0.25, 0.1, 1400.0, 1)
					_burst(Vector2(sx, GROUND_TOP - 20.0), Color("#7ef9ff"), 10, 150.0, 0.4)
			"crumble":
				_update_crumble(h, delta)

func _update_rock(h: Dictionary, delta: float, prect: Rect2) -> void:
	var node: Node2D = h["node"]
	var mark: Polygon2D = h["mark"]
	var rx := float(h["x"])
	match String(h["state"]):
		"armed":
			node.position = Vector2(rx, float(h["y0"]))
			if absf(player.global_position.x - rx) < 130.0:
				h["state"] = "warn"
				h["timer"] = 0.55
				_sfx(120.0, 0.5, 0.08, 0.0, 2)
		"warn":
			h["timer"] = float(h["timer"]) - delta
			node.position.x = rx + sin(run_time * 70.0) * 2.0
			mark.color = Color(1.0, 0.25, 0.2, 0.3 + 0.25 * sin(run_time * 30.0))
			if float(h["timer"]) <= 0.0:
				h["state"] = "fall"
				h["vy"] = 0.0
		"fall":
			h["vy"] = float(h["vy"]) + 2200.0 * delta
			node.position.y += float(h["vy"]) * delta
			if prect.intersects(Rect2(node.position - Vector2(18.0, 18.0), Vector2(36.0, 36.0))):
				_hurt_player(1, node.position.x)
			if node.position.y >= GROUND_TOP - 18.0:
				shake = maxf(shake, 7.0)
				_sfx(90.0, 0.35, 0.18, -60.0, 2)
				_burst(Vector2(rx, GROUND_TOP - 8.0), Color("#8a8fa8"), 18, 200.0, 0.6)
				node.visible = false
				mark.color = Color(1, 0.2, 0.2, 0.0)
				h["state"] = "cool"
				h["timer"] = 4.5
		"cool":
			h["timer"] = float(h["timer"]) - delta
			if float(h["timer"]) <= 0.0 and absf(player.global_position.x - rx) > 220.0:
				node.position = Vector2(rx, float(h["y0"]))
				node.visible = true
				h["state"] = "armed"

func _update_crumble(h: Dictionary, delta: float) -> void:
	var body: StaticBody2D = h["body"]
	var base: Vector2 = h["base"]
	match String(h["state"]):
		"solid":
			var cx := float(h["cx"])
			var on := player.is_on_floor() and absf(player.global_position.x - cx) < float(h["w"]) * 0.5 and absf(player.global_position.y + 16.0 - float(h["top"])) < 6.0
			if on:
				h["state"] = "shake"
				h["timer"] = 0.5
				_sfx(150.0, 0.5, 0.06, 0.0, 2)
		"shake":
			h["timer"] = float(h["timer"]) - delta
			body.position.x = base.x + sin(run_time * 70.0) * 1.6
			if float(h["timer"]) <= 0.0:
				h["state"] = "fall"
				h["timer"] = 0.0
				(h["shape"] as CollisionShape2D).set_deferred("disabled", true)
				_burst(body.global_position, Color(theme["plat_top"]), 10, 120.0, 0.5)
		"fall":
			h["timer"] = float(h["timer"]) + delta
			body.position.y += 520.0 * delta
			body.modulate.a = maxf(0.0, body.modulate.a - 1.8 * delta)
			if float(h["timer"]) > 3.0:
				body.position = base
				body.modulate.a = 1.0
				(h["shape"] as CollisionShape2D).set_deferred("disabled", false)
				h["state"] = "solid"

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
		if can_take and (bool(it["mag"]) or d < 70.0 + float(stats.get("magnet", 0))):
			it["mag"] = true
			n.global_position = n.global_position.move_toward(pc, 320.0 * delta)
			d = n.global_position.distance_to(pc)
		if can_take and d < 20.0:
			_collect(it)
			items.remove_at(i)
		i -= 1

func _collect(it: Dictionary) -> void:
	var n: Node2D = it["node"]
	if String(it["kind"]) == "crystal":
		var val := 5 + int(stats.get("crystal_val", 0))
		score += int(val * score_mul * (1.0 + float(stats.get("score_mul", 0)) / 100.0))
		shards += 1
		crystal_bank += int(val * (1.0 + float(stats.get("bank_mul", 0)) / 100.0))
		combo += 1
		combo_timer = 0.9
		var f := 660.0 * pow(1.05946, float(mini(combo, 12)))
		_sfx(f, 0.09, 0.12)
		_sfx(f * 2.0, 0.07, 0.05, 0.0, 0, 0.04)
		_burst(n.global_position, Color("#7ef9ff"), 6, 110.0, 0.35)
	else:
		health = mini(max_health, health + 1 + int(stats.get("heart_heal", 0)))
		_toast("+%d HEART" % (1 + int(stats.get("heart_heal", 0))))
		_sfx(523.25, 0.12, 0.12)
		_sfx(783.99, 0.18, 0.12, 0.0, 0, 0.1)
		_burst(n.global_position, Color("#ff7b86"), 12, 140.0, 0.5)
		_float_text(n.global_position, "+1", Color("#ff7b86"))
	n.queue_free()

func _update_triggers() -> void:
	var prect := _player_rect()
	for r in spike_rects:
		if prect.intersects(r):
			last_hazard = "spike"
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
	hitstop = maxf(0.0, hitstop - delta)
	_poll_menu_pad(delta)
	_mix_audio()
	_music(delta)
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message_text = ""
			status_label.text = ""
	_animate_player(delta)
	if not low_power_mode or Engine.get_process_frames() % 2 == 0:
		_animate_enemies(delta)
		_animate_world(delta)
	_animate_remote_players(delta)
	look = lerpf(look, facing * 50.0, minf(1.0, delta * 3.0))
	camera.position = Vector2(look, -30.0)
	shake = maxf(0.0, shake - 40.0 * delta)
	if low_power_mode:
		camera.offset = Vector2.ZERO
	else:
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake

func _animate_world(_delta: float) -> void:
	for it in items:
		var n: Node2D = it["node"]
		var inner: Node2D = it["inner"]
		if not bool(it["mag"]):
			var base: Vector2 = it["base"]
			n.position.y = base.y + sin(anim_time * 3.0 + float(it["phase"])) * 3.0
		if String(it["kind"]) == "crystal":
			inner.scale.x = 0.35 + 0.65 * absf(cos(anim_time * 2.0 + float(it["phase"])))
		else:
			var s := 1.0 + 0.1 * sin(anim_time * 6.0 + float(it["phase"]))
			inner.scale = Vector2(s, s)
	var i := flickers.size() - 1
	while i >= 0:
		var f: Dictionary = flickers[i]
		var node: Node2D = f["node"] if is_instance_valid(f["node"]) else null
		if node == null:
			flickers.remove_at(i)
		else:
			var k := 0.78 + 0.22 * sin(anim_time * float(f["speed"]) + float(f["phase"])) + 0.08 * sin(anim_time * 23.0 + float(f["phase"]))
			node.modulate.a = float(f["base"]) * k
		i -= 1
	if exit_swirl != null and is_instance_valid(exit_swirl):
		exit_swirl.rotation = anim_time * 1.5
		exit_swirl.scale = Vector2.ONE * (1.0 + 0.15 * sin(anim_time * 3.0))
	for x in exit_extra:
		if is_instance_valid(x):
			x.rotation = -anim_time * 3.0
	if shadow != null:
		var show := shadow_y > -999.0 and state != State.DEAD
		shadow.visible = show
		if show:
			shadow.global_position = Vector2(player.global_position.x, shadow_y)
			var s2 := clampf(1.0 - (shadow_y - player.global_position.y - 16.0) / 260.0, 0.3, 1.0)
			shadow.scale = Vector2(s2, s2)

func _burst(pos: Vector2, color: Color, amount := 10, speed := 140.0, life := 0.5) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(2, int(amount * (0.18 if low_power_mode else 1.0)))
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

# ─────────────────────────────── Audio (tiny synth) ───────────────────────────────
func _make_audio() -> void:
	sound_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.1
	sound_player.stream = stream
	add_child(sound_player)
	sound_player.play()
	sound_playback = sound_player.get_stream_playback() as AudioStreamGeneratorPlayback

## wave: 0 = sine, 1 = square, 2 = noise.  slide = Hz per second.
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
		"randomize": randomize_layout,
		"crystal_bank": crystal_bank,
		"owned_upgrades": owned_upgrades,
		"weapon_mode": weapon_mode
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
	if int(d.get("version", 0)) < 3:
		return
	unlocked = clampi(int(d.get("unlocked", 1)), 1, TOTAL_LEVELS)
	current_level = clampi(int(d.get("current", 1)), 1, unlocked)
	total_score = maxi(0, int(d.get("total_score", 0)))
	music_on = bool(d.get("music", true))
	unlock_all = bool(d.get("unlock_all", false))
	randomize_layout = bool(d.get("randomize", true))
	level_best.clear()
	var best: Dictionary = d.get("best", {})
	for k in best:
		level_best[int(k)] = float(best[k])
	crystal_bank = maxi(0, int(d.get("crystal_bank", 0)))
	owned_upgrades = d.get("owned_upgrades", {})
	if typeof(owned_upgrades) != TYPE_DICTIONARY:
		owned_upgrades = {}
	weapon_mode = String(d.get("weapon_mode", "sword"))
	_rebuild_stats()


# ─────────────────────────────── Scenery draw classes ───────────────────────────────

# ───── Bow & Upgrades runtime ─────
func _show_upgrades() -> void:
	# Ensure menu panel is open
	if menu_panel != null:
		menu_panel.visible = true
	menu_title.text = "UPGRADES"
	menu_hint.text = "A buy   B back   LB/RB page   CATEGORY cycles type"
	screen_main.visible = false
	screen_levels.visible = false
	if screen_upgrades != null:
		screen_upgrades.visible = true
	else:
		_toast("UPGRADE UI MISSING")
		return
	_refresh_upgrade_page()
	if upgrade_rows.size() > 0:
		_set_menu_rows(upgrade_rows, 0, 0)
	else:
		_toast("NO UPGRADE ROWS")
	_sfx(660.0, 0.06, 0.1)

func _refresh_upgrade_page() -> void:
	if upgrade_buttons.is_empty():
		_toast("NO UPGRADE BUTTONS")
		return
	var cat: String = upgrade_cats[upgrade_cat]
	var lines: Array = []
	for line in UPGRADE_LINES:
		if String(line[1]) == cat:
			lines.append(line)
	# Clamp page
	var max_page := maxi(0, (lines.size() - 1) / UPGRADE_PAGE_SIZE)
	upgrade_page = clampi(upgrade_page, 0, max_page)
	var start := upgrade_page * UPGRADE_PAGE_SIZE
	if upgrade_title != null:
		var cat_label := "GRAPPLE" if cat == "BOW" else cat
		upgrade_title.text = "UPGRADES - %s (%d/%d)" % [cat_label, upgrade_page + 1, max_page + 1]
	if upgrade_hint != null:
		upgrade_hint.text = "CRYSTALS: %d" % crystal_bank
	for i in UPGRADE_PAGE_SIZE:
		var b := upgrade_buttons[i]
		var idx := start + i
		if idx >= lines.size():
			b.text = "—"
			b.disabled = true
			if b.has_meta("uline"):
				b.remove_meta("uline")
			continue
		var line: Array = lines[idx]
		var id: String = line[0]
		var rank: int = int(owned_upgrades.get(id, 0))
		var maxr: int = int(line[4])
		var cost := _upgrade_cost(line, rank)
		var nm: String = String(line[2])
		var desc_tmpl: String = String(line[3])
		var per = line[8]
		var cur_val = float(per) * float(rank)
		var next_val = float(per) * float(rank + 1)
		var desc: String = desc_tmpl
		if desc_tmpl.find("%") >= 0:
			var show_v = next_val if rank < maxr else cur_val
			if rank > 0 and rank < maxr:
				var da: String
				var db: String
				if desc_tmpl.find("%.2f") >= 0:
					da = desc_tmpl % cur_val
					db = desc_tmpl % next_val
				else:
					da = desc_tmpl % int(cur_val)
					db = desc_tmpl % int(next_val)
				desc = da + "  →  " + db
			else:
				if desc_tmpl.find("%.2f") >= 0:
					desc = desc_tmpl % show_v
				else:
					desc = desc_tmpl % int(show_v)
		var st: String
		if rank >= maxr:
			st = "MAX"
			b.disabled = true
		elif crystal_bank < cost:
			st = "NEED %d" % cost
			b.disabled = false
		else:
			st = "BUY %d" % cost
			b.disabled = false
		# Button shows name/rank/cost only; full desc on hover
		b.text = "%s  %d/%d   %s" % [nm, rank, maxr, st]
		b.set_meta("uline", line)
		b.set_meta("udesc", "%s\n%s\nRank %d / %d" % [nm, desc, rank, maxr])

func _upgrade_cost(line: Array, rank: int) -> int:
	return int(float(line[5]) * pow(float(line[6]), float(rank)))

func _on_upgrade_hover(slot: int) -> void:
	if slot < 0 or slot >= upgrade_buttons.size():
		return
	var b: Button = upgrade_buttons[slot]
	if not b.has_meta("udesc"):
		return
	upgrade_tooltip_label.text = str(b.get_meta("udesc"))
	upgrade_tooltip.visible = true
	# Position near the button
	var gp := b.get_global_rect()
	var tip_w := 300.0
	var tip_x := clampf(gp.position.x + gp.size.x * 0.5 - tip_w * 0.5, 8.0, float(VIEW_SIZE.x) - tip_w - 8.0)
	var tip_y := gp.position.y - 70.0
	if tip_y < 8.0:
		tip_y = gp.position.y + gp.size.y + 6.0
	upgrade_tooltip.position = Vector2(tip_x, tip_y)

func _on_upgrade_unhover() -> void:
	if is_instance_valid(upgrade_tooltip):
		upgrade_tooltip.visible = false

func _on_upgrade_slot_pressed(slot: int) -> void:
	var b := upgrade_buttons[slot]
	if not b.has_meta("uline"): return
	var line: Array = b.get_meta("uline")
	var id: String = line[0]
	var rank: int = int(owned_upgrades.get(id, 0))
	if rank >= int(line[4]): return
	var cost := _upgrade_cost(line, rank)
	if crystal_bank < cost:
		_sfx(160.0, 0.15, 0.12, -80.0, 2)
		_toast("NOT ENOUGH CRYSTALS")
		return
	crystal_bank -= cost
	owned_upgrades[id] = rank + 1
	_rebuild_stats()
	health = mini(health, max_health)
	_update_hud()
	_refresh_upgrade_page()
	_sfx(880.0, 0.08, 0.14, 400.0, 0)
	_save_game(false)
	_toast("UPGRADED")

func _change_upgrade_page(dir: int) -> void:
	upgrade_page = maxi(0, upgrade_page + dir)
	_refresh_upgrade_page()
	_sfx(600.0, 0.04, 0.06)

func _cycle_upgrade_cat() -> void:
	upgrade_cat = (upgrade_cat + 1) % upgrade_cats.size()
	upgrade_page = 0
	_refresh_upgrade_page()
	_sfx(720.0, 0.05, 0.08)

func _respec_upgrades() -> void:
	var refund := 0
	for line in UPGRADE_LINES:
		var id: String = line[0]
		var rank: int = int(owned_upgrades.get(id, 0))
		for r in rank:
			refund += _upgrade_cost(line, r)
	crystal_bank += refund
	owned_upgrades.clear()
	_rebuild_stats()
	_refresh_upgrade_page()
	_sfx(400.0, 0.2, 0.12, -200.0, 1)
	_toast("RESPEC +%d" % refund)
	_save_game(false)

func _toggle_weapon() -> void:
	weapon_mode = "grapple" if weapon_mode == "sword" else "sword"
	_apply_weapon_visuals()
	_toast("WEAPON: " + weapon_mode.to_upper())
	_sfx(500.0, 0.06, 0.08)
	_update_hud()

func _apply_weapon_visuals() -> void:
	var bow_on := weapon_mode == "grapple"
	if is_instance_valid(bow_node):
		bow_node.visible = bow_on
		bow_node.modulate = Color.WHITE
		bow_node.z_index = 12
		if bow_on and grapple_state == "idle":
			bow_node.position = Vector2(2, 4)
			var ad := _get_grapple_aim_dir()
			var ang := ad.angle()
			# Convert world aim into arm-local rotation (visual faces +x of arm)
			bow_node.rotation = ang if facing >= 0.0 else (PI - ang)
	if rig.has("sword") and is_instance_valid(rig["sword"]):
		(rig["sword"] as Node2D).visible = not bow_on
	if rig.has("glow") and is_instance_valid(rig["glow"]):
		(rig["glow"] as Node2D).visible = not bow_on

func _update_grapple(delta: float, held: bool) -> void:
	match grapple_state:
		"idle":
			if held and bow_cd <= 0.0:
				_fire_grapple()
		"flying":
			grapple_pos += grapple_vel * delta
			_draw_grapple_rope()
			# Hit roof?
			if grapple_pos.y <= ROOF_Y + 4.0:
				grapple_pos.y = ROOF_Y + 2.0
				grapple_state = "stuck"
				grapple_anchor = grapple_pos
				_sfx(700.0, 0.08, 0.1, -200.0, 1)
				_burst(grapple_pos, Color("#aab8d8"), 6, 80.0, 0.3)
			# Miss / out of range
			elif grapple_pos.y < -40.0 or grapple_pos.distance_to(player.global_position) > 420.0:
				_detach_grapple()
			elif not held:
				_detach_grapple()
		"stuck":
			_draw_grapple_rope()
			if held:
				# Reel in — pull player toward anchor
				var to := grapple_anchor - player.global_position
				var dist := to.length()
				if dist > 12.0:
					var pull_spd := (520.0 + float(stats.get("bow_spd", 0)) * 0.5) * (1.0 + float(stats.get("bow_crit", 0)) / 100.0)
					var pull_str := 8.0 + float(stats.get("bow_dmg", 0)) * 0.8
					player.velocity = player.velocity.lerp(to.normalized() * pull_spd, minf(1.0, delta * pull_str))
					# slight upward bias so you climb
					if player.velocity.y > -80.0:
						player.velocity.y -= 400.0 * delta
				if dist < 28.0 and player.global_position.y < ROOF_Y + 40.0:
					# close to roof — stick-ish
					player.velocity *= 0.9
			else:
				_detach_grapple()
		"reeling":
			_detach_grapple()

func _get_grapple_aim_dir() -> Vector2:
	# Right stick aim
	var aim := Vector2.ZERO
	for dev in Input.get_connected_joypads():
		var rx := Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y)
		if absf(rx) > 0.25 or absf(ry) > 0.25:
			aim = Vector2(rx, ry)
			break
	# Mouse aim (world)
	if aim.length() < 0.25:
		var mouse := player.get_global_mouse_position()
		var to_m := mouse - player.global_position
		if to_m.length() > 8.0:
			aim = to_m
	# Default: up-forward toward roof
	if aim.length() < 0.25:
		aim = Vector2(facing * 0.35, -1.0)
	return aim.normalized()

func _fire_grapple() -> void:
	grapple_state = "flying"
	bow_cd = maxf(0.12, 0.35 + float(stats.get("bow_draw", 0.0)))
	var origin := player.global_position + Vector2(facing * 10.0, -8.0)
	var dir := _get_grapple_aim_dir()
	# Prefer upward component so roof shots work even with slight aim error
	if dir.y > -0.15:
		dir = (dir + Vector2(0, -0.5)).normalized()
	grapple_pos = origin
	grapple_vel = dir * (620.0 + float(stats.get("bow_spd", 0)))
	_ensure_grapple_hook()
	_sfx(480.0, 0.1, 0.08, 600.0, 1)

func _ensure_grapple_hook() -> void:
	if grapple_hook != null and is_instance_valid(grapple_hook):
		return
	grapple_hook = Node2D.new()
	grapple_hook.z_index = 20
	world.add_child(grapple_hook)
	_shape(grapple_hook, PackedVector2Array([
		Vector2(-4, -3), Vector2(5, 0), Vector2(-4, 3), Vector2(-1, 0)
	]), Color("#e8f0ff"), 0.3, 1.2)
	_shape(grapple_hook, PackedVector2Array([
		Vector2(3, -2.5), Vector2(8, 0), Vector2(3, 2.5)
	]), Color("#ff5d6c"), 0.2, 0.0)
	if grapple_rope == null or not is_instance_valid(grapple_rope):
		grapple_rope = Line2D.new()
		grapple_rope.width = 1.6
		grapple_rope.default_color = Color("#aab8d8")
		grapple_rope.z_index = 19
		world.add_child(grapple_rope)

func _draw_grapple_rope() -> void:
	_ensure_grapple_hook()
	if is_instance_valid(grapple_hook):
		grapple_hook.visible = true
		grapple_hook.global_position = grapple_pos
		grapple_hook.rotation = grapple_vel.angle() if grapple_state == "flying" else PI * 0.5
	if is_instance_valid(grapple_rope):
		grapple_rope.visible = true
		var hand := player.global_position + Vector2(facing * 8.0, -6.0)
		grapple_rope.points = PackedVector2Array([hand, grapple_pos])

func _detach_grapple() -> void:
	grapple_state = "idle"
	bow_draw = 0.0
	if is_instance_valid(grapple_hook):
		grapple_hook.visible = false
	if is_instance_valid(grapple_rope):
		grapple_rope.visible = false
	_sfx(300.0, 0.06, 0.06, -100.0, 1)

func _fire_arrow(charge: float) -> void:
	# legacy no-op (grapple replaced arrows)
	pass

func _update_player_arrows(delta: float) -> void:
	var i := player_arrows.size() - 1
	while i >= 0:
		var ar: Dictionary = player_arrows[i]
		var n: Node2D = ar["node"]
		if not is_instance_valid(n):
			player_arrows.remove_at(i); i -= 1; continue
		var vel: Vector2 = ar["vel"]
		if bool(ar.get("home", false)):
			var best_d := 9999.0
			var best_p := n.position
			for e in enemies:
				if is_instance_valid(e) and not bool(_st(e).get("dead", false)):
					var d := n.position.distance_to(e.global_position)
					if d < best_d and d < 280.0:
						best_d = d; best_p = e.global_position
			if best_d < 900.0:
				vel = vel.lerp((best_p - n.position).normalized() * vel.length(), 0.07)
		vel.y += ARROW_GRAV * delta
		ar["vel"] = vel
		n.position += vel * delta
		n.rotation = vel.angle() + PI * 0.5
		ar["life"] = float(ar["life"]) - delta
		var kill := false
		for e in enemies:
			if not is_instance_valid(e): continue
			var es := _st(e)
			if bool(es.get("dead", false)): continue
			var eid := e.get_instance_id()
			if ar["hits"].has(eid): continue
			var esz: Vector2 = es.get("size", Vector2(22, 22))
			if Rect2(e.global_position - esz * 0.5, esz).has_point(n.position):
				ar["hits"][eid] = true
				_damage_enemy(e, int(ar["dmg"]), signf(vel.x))
				if bool(ar.get("explo", false)):
					_burst(n.position, Color("#ff9a3c"), 12, 160.0, 0.35)
				if int(ar["pierce"]) <= 0:
					kill = true; break
				else:
					ar["pierce"] = int(ar["pierce"]) - 1
		if n.position.y >= GROUND_TOP - 4.0 and _on_ground(n.position.x):
			if int(ar.get("bounce", 0)) > 0:
				ar["bounce"] = int(ar["bounce"]) - 1
				vel.y = -absf(vel.y) * 0.6
				ar["vel"] = vel
			else:
				kill = true
				_burst(n.position, Color("#aab8d8"), 4, 70.0, 0.25)
		if float(ar["life"]) <= 0.0 or n.position.y > PIT_Y:
			kill = true
		if kill:
			n.queue_free()
			player_arrows.remove_at(i)
		i -= 1



func _handle_mobile_touch(event: InputEvent) -> void:
	if not is_touch_device:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and st.position.distance_to(mob_joy_origin) < 95.0 and mob_joy_touch_idx < 0:
			mob_joy_active = true
			mob_joy_touch_idx = st.index
			_mob_joy_update(st.position)
		elif not st.pressed and st.index == mob_joy_touch_idx:
			mob_joy_active = false
			mob_joy_touch_idx = -1
			mob_axis = Vector2.ZERO
			_mob_joy_set_knob(mob_joy_origin)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == mob_joy_touch_idx and mob_joy_active:
			_mob_joy_update(sd.position)

func _setup_mobile_and_mp() -> void:
	# Auto-detect phones / tablets — controls appear by themselves on Android/iOS
	var osn := OS.get_name()
	is_touch_device = (
		osn == "Android" or osn == "iOS"
		or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")
		or (DisplayServer.is_touchscreen_available() and osn not in ["Windows", "macOS", "Linux", "FreeBSD"])
	)
	# Small window + touch often means a phone/emulator
	if DisplayServer.is_touchscreen_available() and DisplayServer.window_get_size().x <= 1280:
		if osn == "Android" or OS.has_feature("mobile"):
			is_touch_device = true
	if is_touch_device:
		_make_mobile_controls()
		if mobile_layer:
			mobile_layer.visible = false  # show only while playing
	_make_mp_menu_buttons()

func _refresh_mobile_visibility() -> void:
	if not is_touch_device or mobile_layer == null:
		return
	# On-screen buttons only during gameplay (not menus)
	mobile_layer.visible = (state == State.PLAYING)

func _make_mobile_controls() -> void:
	if mobile_layer != null:
		return
	mobile_layer = CanvasLayer.new()
	mobile_layer.layer = 60
	add_child(mobile_layer)
	var joy_bg := ColorRect.new()
	joy_bg.name = "JoyBG"
	joy_bg.position = Vector2(30, 360)
	joy_bg.size = Vector2(140, 140)
	joy_bg.color = Color(0.08, 0.1, 0.16, 0.55)
	joy_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_layer.add_child(joy_bg)
	var joy_knob := ColorRect.new()
	joy_knob.name = "JoyKnob"
	joy_knob.position = Vector2(70, 400)
	joy_knob.size = Vector2(60, 60)
	joy_knob.color = Color(0.49, 0.97, 1.0, 0.5)
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_layer.add_child(joy_knob)
	mob_joy_origin = Vector2(100, 430)
	var specs: Array = [
		["JUMP", Vector2(820, 400), Vector2(110, 80), "jump"],
		["SWORD", Vector2(690, 400), Vector2(110, 80), "sword"],
		["DASH", Vector2(820, 300), Vector2(110, 80), "dash"],
		["HOOK", Vector2(690, 300), Vector2(110, 80), "grapple"],
		["II", Vector2(870, 16), Vector2(70, 54), "pause"],
		["SWAP", Vector2(780, 16), Vector2(80, 54), "weapon"],
	]
	for s in specs:
		var b := Button.new()
		b.text = str(s[0])
		b.position = s[1]
		b.size = s[2]
		b.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.14, 0.22, 0.72)
		sb.set_border_width_all(2)
		sb.border_color = Color("#7ef9ff")
		sb.set_corner_radius_all(14)
		b.add_theme_stylebox_override("normal", sb)
		var sb2: StyleBoxFlat = sb.duplicate()
		sb2.bg_color = Color(0.25, 0.4, 0.5, 0.9)
		b.add_theme_stylebox_override("pressed", sb2)
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", Color("#e8f0ff"))
		var action: String = str(s[3])
		b.button_down.connect(_on_mob_btn.bind(action, true))
		b.button_up.connect(_on_mob_btn.bind(action, false))
		mobile_layer.add_child(b)
		mob_btns[action] = b

func _on_mob_btn(action: String, down: bool) -> void:
	match action:
		"jump":
			mob_jump = down
		"sword":
			if down: mob_sword = true
		"dash":
			if down: mob_dash = true
		"grapple":
			mob_grapple = down
		"pause":
			if down: mob_pause_pressed = true
		"weapon":
			if down: mob_weapon_pressed = true

func _mob_joy_update(pos: Vector2) -> void:
	var d := pos - mob_joy_origin
	if d.length() > 55.0:
		d = d.normalized() * 55.0
	mob_axis = d / 55.0
	_mob_joy_set_knob(mob_joy_origin + d)

func _mob_joy_set_knob(pos: Vector2) -> void:
	if mobile_layer and mobile_layer.has_node("JoyKnob"):
		var k: ColorRect = mobile_layer.get_node("JoyKnob")
		k.position = pos - k.size * 0.5

func _make_mp_menu_buttons() -> void:
	# Title + MP screens are built in _make_hud
	pass

func _on_title_show() -> void:
	menu_title.text = "PIXELBOUND"
	menu_hint.text = "RIFT RUNNER  ·  500 LEVELS"
	_show_screen("title")
	_sfx(400.0, 0.05, 0.06)

func _on_title_singleplayer() -> void:
	# Preserve active local co-op / LAN sessions when returning to the gameplay menu.
	if mp_mode != "local2" and mp_mode != "host" and mp_mode != "client":
		mp_mode = "solo"
	if is_instance_valid(player2):
		player2.visible = false
	if mp_status_lbl:
		mp_status_lbl.text = "MP: solo"
	menu_title.text = "SINGLEPLAYER"
	menu_hint.text = "Choose a level or continue"
	# Show in-game main menu (play / levels)
	var txt := "PLAY"
	if unlocked > 1 or not level_best.is_empty():
		txt = "CONTINUE  -  LEVEL %d" % current_level
	resume_btn.text = txt
	_show_screen("main")
	_sfx(520.0, 0.06, 0.07)

func _on_title_multiplayer() -> void:
	menu_title.text = "MULTIPLAYER"
	menu_hint.text = "Local co-op or LAN"
	_show_screen("mp")
	_sfx(520.0, 0.06, 0.07)

func _start_local_coop() -> void:
	mp_mode = "local2"
	if mp_status_lbl: mp_status_lbl.text = "Mode: LOCAL CO-OP"
	_ensure_player2()
	_toast("CO-OP ON — P2: LEFT/RIGHT + UP jump")
	_sfx(520.0, 0.08, 0.1)
	_on_title_singleplayer()
	if mp_status_lbl:
		mp_status_lbl.text = "Mode: LOCAL CO-OP"

func _ensure_player2() -> void:
	if is_instance_valid(player2):
		player2.visible = true
		return
	player2 = CharacterBody2D.new()
	player2.collision_layer = L_PLAYER
	player2.collision_mask = L_SOLID | L_ONEWAY
	var cs := CollisionShape2D.new()
	var cap := RectangleShape2D.new()
	cap.size = Vector2(16, 28)
	cs.shape = cap
	cs.position = Vector2(0, -6)
	player2.add_child(cs)
	player2_visual = Node2D.new()
	player2.add_child(player2_visual)
	var poly := Polygon2D.new()
	poly.color = Color("#ff9ad5")
	poly.polygon = PackedVector2Array([Vector2(0, -28), Vector2(12, -8), Vector2(8, 8), Vector2(-8, 8), Vector2(-12, -8)])
	player2_visual.add_child(poly)
	if is_instance_valid(player):
		player2.position = player.global_position + Vector2(-48, 0)
	world.add_child(player2)
	p2_health = 3
	p2_facing = 1.0

func _update_player2(delta: float) -> void:
	if mp_mode != "local2" or not is_instance_valid(player2):
		return
	if state != State.PLAYING:
		return
	var axis := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		axis -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		axis += 1.0
	if Input.get_connected_joypads().size() > 1:
		var lx := Input.get_joy_axis(1, JOY_AXIS_LEFT_X)
		if absf(lx) > 0.2:
			axis = lx
	var on_floor := player2.is_on_floor()
	var spd := MOVE_SPEED + float(stats.get("move_spd", 0))
	var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
	player2.velocity.x = move_toward(player2.velocity.x, axis * spd, accel * delta)
	if not on_floor:
		player2.velocity.y = minf(player2.velocity.y + GRAVITY * delta, MAX_FALL)
	else:
		if player2.velocity.y > 0.0:
			player2.velocity.y = 0.0
	if (Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_SLASH)) and on_floor:
		player2.velocity.y = JUMP_SPEED + float(stats.get("jump_spd", 0))
	if axis > 0.1:
		p2_facing = 1.0
	elif axis < -0.1:
		p2_facing = -1.0
	player2.move_and_slide()
	if player2.global_position.y > PIT_Y:
		player2.global_position = player.global_position + Vector2(-30, -40)
		player2.velocity = Vector2.ZERO

func _get_lan_ip() -> String:
	# Choose the first non-loopback IPv4 address. This is the address friends on
	# the same Wi-Fi should enter; it is not an internet/public IP.
	for address in IP.get_local_addresses():
		var parts := address.split(".")
		if parts.size() != 4 or address.begins_with("127."):
			continue
		var valid := true
		for part in parts:
			if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
				valid = false
				break
		if valid and not address.begins_with("169.254."):
			return address
	return "192.168.1.x"

func _mp_toggle_battle() -> void:
	mp_battle_mode = not mp_battle_mode
	if is_instance_valid(mp_battle_btn):
		mp_battle_btn.text = "BATTLE MODE: ON" if mp_battle_mode else "BATTLE MODE: OFF"
	if is_instance_valid(mp_status_lbl):
		mp_status_lbl.text = ("Battle mode ON — sword hits damage players" if mp_battle_mode else "Co-op mode — same Wi-Fi, port 7777")
	_sfx(520.0, 0.06, 0.08)

func _mp_host() -> void:
	_mp_disconnect()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(7777, 8)
	if err != OK:
		if mp_status_lbl: mp_status_lbl.text = "HOST FAILED (error %d)" % err
		_toast("HOST FAILED — check firewall/Wi-Fi")
		return
	mp_peer = peer
	multiplayer.multiplayer_peer = peer
	mp_mode = "host"
	mp_battle_hp = 3
	if not multiplayer.peer_connected.is_connected(_on_mp_peer_connected):
		multiplayer.peer_connected.connect(_on_mp_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_mp_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_mp_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_mp_connected_to_server):
		multiplayer.connected_to_server.connect(_on_mp_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_mp_connection_failed):
		multiplayer.connection_failed.connect(_on_mp_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_mp_server_disconnected):
		multiplayer.server_disconnected.connect(_on_mp_server_disconnected)
	if mp_status_lbl:
		mp_status_lbl.text = "HOSTING: %s:7777 — waiting for friends" % _get_lan_ip()
	if is_instance_valid(mp_ip_edit):
		mp_ip_edit.text = _get_lan_ip()
	_toast("LAN HOST READY — share %s" % _get_lan_ip())
	_sfx(600.0, 0.1, 0.1)

func _mp_join() -> void:
	var address := ""
	if is_instance_valid(mp_ip_edit):
		address = mp_ip_edit.text.strip_edges()
	if address.is_empty() or address == "192.168.1.x":
		if mp_status_lbl: mp_status_lbl.text = "Enter the HOST'S Wi-Fi IPv4 address first"
		return
	_mp_disconnect()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, 7777)
	if err != OK:
		if mp_status_lbl: mp_status_lbl.text = "JOIN FAILED (error %d)" % err
		_toast("JOIN FAILED — check IP and Wi-Fi")
		return
	mp_peer = peer
	multiplayer.multiplayer_peer = peer
	mp_mode = "client"
	mp_battle_hp = 3
	if not multiplayer.connected_to_server.is_connected(_on_mp_connected_to_server):
		multiplayer.connected_to_server.connect(_on_mp_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_mp_connection_failed):
		multiplayer.connection_failed.connect(_on_mp_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_mp_server_disconnected):
		multiplayer.server_disconnected.connect(_on_mp_server_disconnected)
	if mp_status_lbl: mp_status_lbl.text = "CONNECTING TO %s:7777…" % address
	_toast("CONNECTING TO %s" % address)
	_sfx(500.0, 0.1, 0.1)

func _mp_disconnect() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	mp_peer = null
	mp_mode = "solo"
	for key in mp_remote_players.keys():
		var node: Node = mp_remote_players[key]
		if is_instance_valid(node): node.queue_free()
	mp_remote_players.clear()
	mp_remote_anim_data.clear()

func _mp_start_battle() -> void:
	if mp_mode != "host":
		if mp_status_lbl: mp_status_lbl.text = "Only the host can start the match"
		return
	mp_battle_hp = 3
	_rpc_lobby_settings.rpc(mp_battle_mode)
	_rpc_start_game.rpc(current_level, level_seed, mp_battle_mode)
	_start_lan_game(current_level, level_seed, mp_battle_mode)

func _start_lan_game(level_number: int, seed_value: int, battle_enabled: bool) -> void:
	mp_battle_mode = battle_enabled
	current_level = clampi(level_number, 1, TOTAL_LEVELS)
	level_seed = seed_value
	_build_level(current_level, level_seed)
	_place_player_at_checkpoint()
	_refresh_toggles()
	_refresh_level_page()
	_update_hud()
	_on_title_singleplayer()
	_on_resume_pressed()
	if mp_status_lbl:
		mp_status_lbl.text = "BATTLE MATCH" if mp_battle_mode else "LAN CO-OP MATCH"

func _on_mp_connected_to_server() -> void:
	if mp_status_lbl: mp_status_lbl.text = "CONNECTED — waiting for host to start"
	_toast("CONNECTED TO LAN HOST")
	_sfx(720.0, 0.08, 0.1)

func _on_mp_connection_failed() -> void:
	if mp_status_lbl: mp_status_lbl.text = "CONNECTION FAILED — check host IP and Wi-Fi"
	_toast("LAN CONNECTION FAILED")
	_mp_disconnect()

func _on_mp_server_disconnected() -> void:
	if mp_status_lbl: mp_status_lbl.text = "HOST DISCONNECTED"
	_toast("HOST DISCONNECTED")
	_mp_disconnect()

func _on_mp_peer_connected(id: int) -> void:
	_toast("PLAYER %d JOINED" % id)
	if mp_status_lbl: mp_status_lbl.text = "HOSTING %s:7777 — %d player(s) connected" % [_get_lan_ip(), multiplayer.get_peers().size()]
	_rpc_lobby_settings.rpc_id(id, mp_battle_mode)

func _on_mp_peer_disconnected(id: int) -> void:
	if mp_remote_players.has(id):
		var node: Node = mp_remote_players[id]
		if is_instance_valid(node): node.queue_free()
		mp_remote_players.erase(id)
	mp_remote_anim_data.erase(id)
	if mp_status_lbl: mp_status_lbl.text = "PLAYER LEFT — %d connected" % multiplayer.get_peers().size()
	_toast("PLAYER %d LEFT" % id)

func _make_remote_player(pid: int) -> Node2D:
	if mp_remote_players.has(pid) and is_instance_valid(mp_remote_players[pid]):
		return mp_remote_players[pid]

	var avatar := Node2D.new()
	avatar.name = "LANPlayer_%d" % pid
	avatar.z_index = 5
	var hero_copy: Node2D
	if is_instance_valid(player_visual):
		hero_copy = player_visual.duplicate() as Node2D
		if hero_copy != null:
			hero_copy.name = "RemoteHero"
			hero_copy.position = Vector2.ZERO
			hero_copy.rotation = 0.0
			hero_copy.scale = Vector2.ONE
			hero_copy.modulate = Color.WHITE
			avatar.add_child(hero_copy)
	else:
		hero_copy = Node2D.new()
		var body := Polygon2D.new()
		body.color = Color("#ff9ad5") if pid % 2 == 0 else Color("#ffe28a")
		body.polygon = PackedVector2Array([Vector2(0, -28), Vector2(12, -8), Vector2(8, 8), Vector2(-8, 8), Vector2(-12, -8)])
		hero_copy.add_child(body)
		hero_copy.name = "RemoteHero"
		avatar.add_child(hero_copy)

	# Keep the label outside the mirrored hero. Counter-flipping the label keeps
	# text readable while the character faces left or right.
	var tag := Label.new()
	tag.name = "PlayerTag"
	tag.text = "P%d  HP:3" % pid
	tag.position = Vector2(-42, -60)
	tag.custom_minimum_size = Vector2(84, 18)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color.WHITE)
	tag.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.09, 0.95))
	tag.add_theme_constant_override("shadow_offset_x", 1)
	tag.add_theme_constant_override("shadow_offset_y", 1)
	avatar.add_child(tag)

	var remote_rig := {}
	if is_instance_valid(player_visual) and hero_copy != null:
		for key in rig.keys():
			var source_node: Node = rig[key]
			if is_instance_valid(source_node) and player_visual.is_ancestor_of(source_node):
				var rel_path := player_visual.get_path_to(source_node)
				var copied_node := hero_copy.get_node_or_null(rel_path)
				if copied_node is Node2D:
					remote_rig[key] = copied_node
	var remote_cape: Array = []
	for source_node in cape_nodes:
		if is_instance_valid(source_node) and is_instance_valid(player_visual):
			var copied_node := hero_copy.get_node_or_null(player_visual.get_path_to(source_node))
			if copied_node is Node2D:
				remote_cape.append(copied_node)
	var remote_tail: Array = []
	for source_node in tail_nodes:
		if is_instance_valid(source_node) and is_instance_valid(player_visual):
			var copied_node := hero_copy.get_node_or_null(player_visual.get_path_to(source_node))
			if copied_node is Node2D:
				remote_tail.append(copied_node)

	world.add_child(avatar)
	mp_remote_players[pid] = avatar
	mp_remote_anim_data[pid] = {"hero": hero_copy, "rig": remote_rig, "cape": remote_cape, "tail": remote_tail, "vx": 0.0, "vy": 0.0, "grounded": true, "attack_t": -1.0, "attack_style": 0, "dash": false, "phase": 0.0, "hp": 3}
	return avatar

func _animate_remote_players(delta: float) -> void:
	if mp_remote_anim_data.is_empty():
		return
	for pid_variant in mp_remote_anim_data.keys():
		var pid := int(pid_variant)
		var data: Dictionary = mp_remote_anim_data[pid]
		var hero: Node2D = data.get("hero")
		var rg: Dictionary = data.get("rig", {})
		if not is_instance_valid(hero) or rg.is_empty():
			continue
		var vx := float(data.get("vx", 0.0))
		var vy := float(data.get("vy", 0.0))
		var grounded := bool(data.get("grounded", true))
		var attacking := float(data.get("attack_t", -1.0)) >= 0.0
		var dashing := bool(data.get("dash", false))
		var phase := float(data.get("phase", 0.0))
		phase += delta * (9.0 + minf(absf(vx), 250.0) * 0.032) if absf(vx) > 20.0 else delta * 2.0
		data["phase"] = phase
		var walk := absf(vx) > 20.0 and grounded
		var tg := {"lean": 0.02 + sin(phase * 0.22) * 0.02, "head": 0.0, "thigh_f": 0.08, "shin_f": 0.0, "thigh_b": -0.1, "shin_b": 0.05, "arm_f1": -0.35, "arm_f2": -0.6, "arm_b1": 0.15, "arm_b2": 0.25, "blade": -0.9, "bob": sin(phase * 0.22) * 0.6}
		if not grounded:
			if vy < 0.0:
				tg["thigh_f"] = -0.7; tg["shin_f"] = 1.0; tg["thigh_b"] = 0.5; tg["shin_b"] = 0.9
				tg["lean"] = 0.08; tg["arm_f1"] = -2.3; tg["arm_f2"] = -0.2; tg["arm_b1"] = -1.6
			else:
				tg["thigh_f"] = -0.25; tg["shin_f"] = 0.4; tg["thigh_b"] = 0.35; tg["shin_b"] = 0.5
				tg["lean"] = 0.0; tg["arm_f1"] = -1.2; tg["arm_b1"] = 1.2
		elif walk:
			tg["thigh_f"] = sin(phase) * 0.85
			tg["thigh_b"] = sin(phase + PI) * 0.85
			tg["shin_f"] = (0.5 + 0.5 * sin(phase - 1.4)) * 1.1
			tg["shin_b"] = (0.5 + 0.5 * sin(phase + PI - 1.4)) * 1.1
			tg["lean"] = 0.18
			tg["bob"] = -absf(sin(phase)) * 1.6
			tg["arm_b1"] = -sin(phase) * 0.8 + 0.1
		if dashing:
			tg["lean"] = 0.55; tg["thigh_f"] = 0.7; tg["thigh_b"] = 1.1; tg["arm_f1"] = -1.5; tg["arm_b1"] = 1.2
		if attacking:
			var style_idx := clampi(int(data.get("attack_style", 0)), 0, ATTACK_STYLES.size() - 1)
			var style: Array = ATTACK_STYLES[style_idx]
			var attack_phase := clampf(float(data.get("attack_t", 0.0)) / float(style[5]), 0.0, 1.0)
			var swing := lerpf(float(style[0]), float(style[1]), 1.0 - pow(1.0 - attack_phase, 2.0))
			tg["arm_f1"] = swing - PI * 0.5
			tg["arm_f2"] = -0.15
			tg["blade"] = swing
			tg["lean"] = 0.25
		# Blend and apply the pose to the duplicated rig's actual joint nodes.
		for key in ["thigh_f", "shin_f", "thigh_b", "shin_b", "arm_f1", "arm_f2", "arm_b1", "arm_b2"]:
			if not rg.has(key):
				continue
			var joint: Node2D = rg[key]
			var target := float(tg[key])
			var old := float(data.get("pose_" + key, target))
			var next_value := lerpf(old, target, minf(1.0, delta * (35.0 if dashing or attacking else 16.0)))
			data["pose_" + key] = next_value
			joint.rotation = next_value
		var lean_value := lerpf(float(data.get("pose_lean", 0.0)), float(tg["lean"]), minf(1.0, delta * 16.0))
		data["pose_lean"] = lean_value
		if rg.has("torso"):
			(rg["torso"] as Node2D).rotation = lean_value
		if rg.has("head"):
			(rg["head"] as Node2D).rotation = float(tg["head"]) - lean_value * 0.4
		if rg.has("body"):
			(rg["body"] as Node2D).position.y = float(tg["bob"])
		if rg.has("sword"):
			var blade_value := float(tg["blade"])
			(rg["sword"] as Node2D).rotation = blade_value - lean_value - float(data.get("pose_arm_f1", -0.35)) - float(data.get("pose_arm_f2", -0.6))
		if rg.has("glow"):
			(rg["glow"] as Sprite2D).modulate.a = 0.55 if attacking else 0.2
		if rg.has("gem_glow"):
			(rg["gem_glow"] as Sprite2D).modulate.a = 0.5 + 0.2 * sin(phase * 0.4)
		var face_sign := -1.0 if float(data.get("facing", 1.0)) < 0.0 else 1.0
		hero.scale.x = face_sign
		hero.scale.y = 1.0
		hero.position.y = 0.0
		var cape: Array = data.get("cape", [])
		for i in cape.size():
			(cape[i] as Node2D).rotation = 0.25 + 0.15 * sin(phase * 0.8 + float(i)) + minf(absf(vx) / 250.0, 1.0) * 0.3
		var tail: Array = data.get("tail", [])
		for i in tail.size():
			(tail[i] as Node2D).rotation = -0.25 + 0.12 * sin(phase + float(i))
		var avatar: Node2D = mp_remote_players.get(pid)
		if is_instance_valid(avatar):
			var tag := avatar.get_node_or_null("PlayerTag") as Label
			if tag != null:
				tag.scale.x = 1.0
				tag.position.x = -42.0

@rpc("authority", "call_remote", "reliable")
func _rpc_lobby_settings(battle_enabled: bool) -> void:
	mp_battle_mode = battle_enabled
	if is_instance_valid(mp_battle_btn):
		mp_battle_btn.text = "BATTLE MODE: ON" if mp_battle_mode else "BATTLE MODE: OFF"


@rpc("authority", "call_remote", "reliable")
func _rpc_start_game(level_number: int, seed_value: int, battle_enabled: bool) -> void:
	_start_lan_game(level_number, seed_value, battle_enabled)

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_player_pose(pid: int, pos: Vector2, fac: float, hp: int, vx: float, vy: float, grounded: bool, attack_value: float, attack_kind: int, dashing: bool) -> void:
	if multiplayer.multiplayer_peer == null or pid == multiplayer.get_unique_id():
		return
	# ENet clients communicate through the host. Relay each client's pose so every
	# other player receives the same movement and animation state.
	var sender_id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and sender_id > 0 and sender_id == pid:
		for peer_id in multiplayer.get_peers():
			if int(peer_id) != sender_id:
				_rpc_player_pose.rpc_id(int(peer_id), pid, pos, fac, hp, vx, vy, grounded, attack_value, attack_kind, dashing)
	var avatar := _make_remote_player(pid)
	avatar.global_position = avatar.global_position.lerp(pos, 0.65) if avatar.global_position != Vector2.ZERO else pos
	var data: Dictionary = mp_remote_anim_data.get(pid, {})
	data["vx"] = vx
	data["vy"] = vy
	data["grounded"] = grounded
	data["attack_t"] = attack_value
	data["attack_style"] = attack_kind
	data["dash"] = dashing
	data["facing"] = fac
	data["hp"] = hp
	mp_remote_anim_data[pid] = data
	var tag := avatar.get_node_or_null("PlayerTag") as Label
	if tag != null:
		tag.text = "P%d  HP:%d" % [pid, hp]

@rpc("any_peer", "call_remote", "reliable")
func _rpc_player_attack(pid: int, attack_pos: Vector2, fac: float) -> void:
	if multiplayer.multiplayer_peer == null or not mp_battle_mode or state != State.PLAYING:
		return
	if multiplayer.get_remote_sender_id() != pid:
		return
	var to_player := player.global_position - attack_pos
	if absf(to_player.y) < 42.0 and to_player.length() < 74.0 and (to_player.x * fac) > -12.0:
		mp_battle_hp -= 1
		_toast("HIT! %d HP LEFT" % maxi(mp_battle_hp, 0))
		_sfx(180.0, 0.12, 0.12)
		if mp_battle_hp <= 0:
			mp_battle_wins += 1
			mp_battle_hp = 3
			player.global_position = Vector2(480.0, GROUND_TOP - 50.0)
			player.velocity = Vector2.ZERO
			_toast("KNOCKOUT! WINS: %d" % mp_battle_wins, 2.0)

func _mp_sync_tick() -> void:
	if mp_mode != "host" and mp_mode != "client":
		return
	if multiplayer.multiplayer_peer == null or state != State.PLAYING:
		return
	# 15 Hz is enough for LAN movement and reduces CPU/network work on phones.
	mp_sync_accum += get_physics_process_delta_time()
	if mp_sync_accum < (1.0 / 15.0):
		return
	mp_sync_accum = 0.0
	_rpc_player_pose.rpc(multiplayer.get_unique_id(), player.global_position, facing, mp_battle_hp, player.velocity.x, player.velocity.y, player.is_on_floor(), attack_t, attack_style, dash_time > 0.0)


class GroundDraw extends Node2D:
	var w := 100.0
	var h := 220.0
	var th := {}
	var seed_v := 1

	func _closed(pts: PackedVector2Array) -> PackedVector2Array:
		var c := pts.duplicate()
		c.append(pts[0])
		return c

	func _draw() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = seed_v
		var ground: Color = th["ground"]
		var dark: Color = th["ground_dark"]
		var grass: Color = th["grass"]
		var grass_d: Color = th["grass_dark"]
		var accent: Color = th["accent"]
		var strips := 14
		for i in strips:
			var k := float(i) / float(strips)
			draw_rect(Rect2(0.0, h * k, w, h / float(strips) + 1.0), ground.lerp(dark.darkened(0.55), pow(k, 0.85)))
		for s in 6:
			var y := 34.0 + float(s) * 30.0 + r.randf_range(-6.0, 6.0)
			var pts := PackedVector2Array()
			var x := 0.0
			while x <= w + 20.0:
				pts.append(Vector2(minf(x, w), y + sin(x * 0.04 + float(s)) * 4.0 + r.randf_range(-1.5, 1.5)))
				x += 20.0
			draw_polyline(pts, Color(dark.r, dark.g, dark.b, 0.55), 2.0)
		var rx := 20.0
		while rx < w - 10.0:
			var ry := r.randf_range(36.0, h - 16.0)
			var rs := r.randf_range(5.0, 15.0)
			var rp := PackedVector2Array()
			for k in 7:
				var a := TAU * float(k) / 7.0
				rp.append(Vector2(rx, ry) + Vector2(cos(a) * rs * r.randf_range(0.7, 1.1), sin(a) * rs * r.randf_range(0.55, 0.9)))
			draw_colored_polygon(rp, ground.lerp(dark, 0.55))
			draw_polyline(_closed(rp), dark.darkened(0.4), 1.2)
			draw_circle(Vector2(rx - rs * 0.25, ry - rs * 0.25), rs * 0.28, ground.lightened(0.18))
			if r.randf() < 0.2:
				draw_circle(Vector2(rx + 4.0, ry + 3.0), 7.0, Color(accent.r, accent.g, accent.b, 0.22))
				draw_colored_polygon(PackedVector2Array([Vector2(rx + 4.0, ry - 1.5), Vector2(rx + 7.0, ry + 3.0), Vector2(rx + 4.0, ry + 7.5), Vector2(rx + 1.0, ry + 3.0)]), accent)
			rx += r.randf_range(34.0, 70.0)
		var lip := PackedVector2Array()
		lip.append(Vector2(0.0, 0.0))
		lip.append(Vector2(w, 0.0))
		var gx := w
		while gx > 0.0:
			lip.append(Vector2(gx, 10.0 + r.randf_range(0.0, 7.0)))
			gx -= 7.0
		lip.append(Vector2(0.0, 12.0))
		draw_colored_polygon(lip, grass_d)
		draw_rect(Rect2(0.0, 0.0, w, 9.0), grass)
		draw_rect(Rect2(0.0, 0.0, w, 2.5), grass.lightened(0.3))
		var bx := 0.0
		while bx < w:
			var bh := r.randf_range(3.0, 9.0)
			var lean := r.randf_range(-3.0, 3.0)
			var c := grass.lerp(grass_d, r.randf()) if r.randf() < 0.5 else grass.lightened(r.randf_range(0.0, 0.25))
			draw_line(Vector2(bx, 3.0), Vector2(bx + lean, -bh), c, 1.8)
			bx += r.randf_range(2.5, 5.0)
		var petals: Array = [accent, Color("#ffffff"), Color("#ff9ad5"), Color("#ffe28a")]
		var fx := r.randf_range(15.0, 50.0)
		while fx < w - 10.0:
			var stem := r.randf_range(8.0, 16.0)
			var fc: Color = petals[r.randi() % petals.size()]
			draw_line(Vector2(fx, 2.0), Vector2(fx + 1.0, -stem), grass_d.darkened(0.2), 1.5)
			for pt in 5:
				var pa := TAU * float(pt) / 5.0
				draw_circle(Vector2(fx + 1.0, -stem) + Vector2(cos(pa), sin(pa)) * 2.2, 1.6, fc)
			draw_circle(Vector2(fx + 1.0, -stem), 1.4, Color("#ffe28a"))
			fx += r.randf_range(40.0, 120.0)
		for i in 8:
			var a := 0.28 * (1.0 - float(i) / 8.0)
			draw_rect(Rect2(float(i) * 2.0, 0.0, 2.0, h), Color(0, 0, 0, a))
			draw_rect(Rect2(w - float(i + 1) * 2.0, 0.0, 2.0, h), Color(0, 0, 0, a))
		for sp in [10.0, w - 10.0]:
			var vp := PackedVector2Array()
			for k in 8:
				vp.append(Vector2(sp + sin(float(k) * 0.9 + sp) * 3.0, 10.0 + float(k) * 6.0))
			draw_polyline(vp, grass_d.darkened(0.2), 2.0)
			for k in 3:
				draw_circle(vp[2 + k * 2] + Vector2(2.5, 0.0), 2.2, grass_d)

class PlatDraw extends Node2D:
	var w := 140.0
	var th := {}
	var seed_v := 1
	var crumbly := false

	func _draw() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = seed_v
		var plat: Color = th["plat"]
		var top: Color = th["plat_top"]
		var grass: Color = th["grass"]
		var accent: Color = th["accent"]
		if crumbly:
			plat = plat.darkened(0.2)
		var body := PackedVector2Array([
			Vector2(0, 3), Vector2(5, 0), Vector2(w - 5, 0), Vector2(w, 3), Vector2(w, 12), Vector2(w - 7, 16), Vector2(7, 16), Vector2(0, 12)
		])
		draw_colored_polygon(body, plat)
		draw_rect(Rect2(3.0, 9.0, w - 6.0, 6.0), plat.darkened(0.25))
		draw_rect(Rect2(5.0, 0.0, w - 10.0, 4.0), top)
		draw_rect(Rect2(5.0, 0.0, w - 10.0, 1.4), top.lightened(0.35))
		var bx := 14.0
		while bx < w - 8.0:
			draw_line(Vector2(bx, 5.0), Vector2(bx, 14.0), plat.darkened(0.4), 1.2)
			bx += r.randf_range(22.0, 34.0)
		for i in 4:
			var mx := r.randf_range(8.0, w - 8.0)
			draw_circle(Vector2(mx, 0.5), r.randf_range(2.0, 4.0), grass)
		if r.randf() < 0.7:
			var rx := r.randf_range(24.0, w - 30.0)
			draw_rect(Rect2(rx, 7.0, 7.0, 2.0), Color(accent.r, accent.g, accent.b, 0.8))
			draw_rect(Rect2(rx + 2.5, 5.5, 2.0, 5.0), Color(accent.r, accent.g, accent.b, 0.8))
		for i in 3:
			var vx := r.randf_range(10.0, w - 10.0)
			var vl := r.randf_range(6.0, 20.0)
			var vp := PackedVector2Array()
			for k in 5:
				vp.append(Vector2(vx + sin(float(k) + vx) * 1.5, 14.0 + vl * float(k) / 4.0))
			draw_polyline(vp, grass.darkened(0.3), 1.6)
			draw_circle(vp[4], 1.8, grass)
		if crumbly:
			for i in 3:
				var cx := r.randf_range(14.0, w - 14.0)
				draw_polyline(PackedVector2Array([Vector2(cx, 1.0), Vector2(cx + 3.0, 6.0), Vector2(cx - 2.0, 10.0), Vector2(cx + 2.0, 15.0)]), Color(0, 0, 0, 0.55), 1.4)
		var edge := body.duplicate()
		edge.append(body[0])
		draw_polyline(edge, Color("#141a2c"), 1.6)

class SawDraw extends Node2D:
	func _draw() -> void:
		var teeth := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			var rr := 20.0 if i % 2 == 0 else 15.0
			teeth.append(Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(teeth, Color("#c9d3e6"))
		var outline := teeth.duplicate()
		outline.append(teeth[0])
		draw_polyline(outline, Color("#141a2c"), 1.6)
		draw_circle(Vector2.ZERO, 12.5, Color("#8d9ab8"))
		draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 20, Color("#566082"), 2.0)
		for i in 4:
			var a := TAU * float(i) / 4.0 + 0.4
			draw_line(Vector2(cos(a), sin(a)) * 4.0, Vector2(cos(a), sin(a)) * 11.5, Color("#566082"), 2.0)
			draw_circle(Vector2(cos(a + 0.78), sin(a + 0.78)) * 8.0, 1.2, Color("#e6eefc"))
		draw_arc(Vector2.ZERO, 17.0, 0.2, 1.0, 8, Color("#ff5d6c"), 2.0)
		draw_arc(Vector2.ZERO, 17.0, PI + 0.2, PI + 1.0, 8, Color("#ff5d6c"), 2.0)
		draw_circle(Vector2.ZERO, 3.5, Color("#ff5d6c"))

class PropDraw extends Node2D:
	var kind := "rock"
	var th := {}
	var seed_v := 1

	func _ell(c: Vector2, rx: float, ry: float, n := 14) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n:
			var a := TAU * float(i) / float(n)
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return pts

	func _draw() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = seed_v
		match kind:
			"tree":
				_tree(r)
			"deadtree":
				_deadtree(r)
			"pine":
				_pine(r)
			"arch":
				_arch(r)
			"pillar":
				_pillar(r)
			"crystal":
				_crystal(r)
			"mushroom":
				_mushroom(r)
			"rock":
				_rock(r)
			"statue":
				_statue(r)
			"banner":
				_banner(r)
			"torch":
				_torch()
			"bones":
				_bones(r)
			"tuft":
				_tuft(r)

	func _tree(r: RandomNumberGenerator) -> void:
		var grass: Color = th["grass"]
		var gd: Color = th["grass_dark"]
		var dark: Color = th["ground_dark"]
		var accent: Color = th["accent"]
		var ht := r.randf_range(70.0, 110.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(-4, -ht * 0.4), Vector2(-3.2, -ht), Vector2(3.2, -ht), Vector2(4, -ht * 0.4), Vector2(6, 0)]), dark.darkened(0.25))
		for i in 4:
			draw_line(Vector2(-2.5 + float(i) * 1.6, -4.0), Vector2(-2.0 + float(i) * 1.3, -ht * 0.9), dark.darkened(0.55), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(-14, 3), Vector2(-5, -8)]), dark.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(14, 3), Vector2(5, -8)]), dark.darkened(0.25))
		for i in 7:
			var a := TAU * float(i) / 7.0
			draw_circle(Vector2(cos(a) * 20.0, -ht - 6.0 + sin(a) * 13.0), r.randf_range(16.0, 24.0), gd)
		for i in 7:
			var a := TAU * float(i) / 7.0 + 0.4
			draw_circle(Vector2(cos(a) * 16.0 - 3.0, -ht - 10.0 + sin(a) * 10.0), r.randf_range(10.0, 16.0), grass.darkened(0.15))
		for i in 6:
			draw_circle(Vector2(r.randf_range(-22.0, 10.0), -ht - r.randf_range(8.0, 26.0)), r.randf_range(4.0, 8.0), grass.lightened(0.15))
		for i in 6:
			var fp := Vector2(r.randf_range(-24.0, 24.0), -ht - r.randf_range(-6.0, 20.0))
			draw_circle(fp, 3.4, Color(accent.r, accent.g, accent.b, 0.35))
			draw_circle(fp, 1.8, accent)

	func _branch(r: RandomNumberGenerator, from: Vector2, ang: float, ln: float, depth: int, col: Color) -> void:
		var to := from + Vector2(cos(ang), sin(ang)) * ln
		draw_line(from, to, col, maxf(1.2, float(depth) * 1.3))
		if depth > 0:
			_branch(r, to, ang - r.randf_range(0.3, 0.7), ln * 0.72, depth - 1, col)
			_branch(r, to, ang + r.randf_range(0.3, 0.7), ln * 0.72, depth - 1, col)

	func _deadtree(r: RandomNumberGenerator) -> void:
		var dark: Color = th["ground_dark"]
		var col := dark.darkened(0.35)
		_branch(r, Vector2(0, 0), -PI * 0.5 + r.randf_range(-0.12, 0.12), r.randf_range(32.0, 46.0), 3, col)

	func _pine(r: RandomNumberGenerator) -> void:
		var grass: Color = th["grass"]
		var gd: Color = th["grass_dark"]
		var snow: Color = th["plat_top"]
		draw_rect(Rect2(-3.0, -18.0, 6.0, 18.0), Color("#3a2a20"))
		for i in 4:
			var wd := 36.0 - float(i) * 7.5
			var y0 := -14.0 - float(i) * 22.0
			var c := gd.lerp(grass, float(i) / 4.0).darkened(0.1)
			draw_colored_polygon(PackedVector2Array([Vector2(-wd, y0), Vector2(0, y0 - 34.0), Vector2(wd, y0)]), c)
			draw_colored_polygon(PackedVector2Array([Vector2(-wd * 0.55, y0 - 15.0), Vector2(0, y0 - 34.0), Vector2(wd * 0.55, y0 - 15.0), Vector2(0, y0 - 11.0)]), Color(snow.r, snow.g, snow.b, 0.85))

	func _arch(r: RandomNumberGenerator) -> void:
		var stone: Color = th["plat"]
		var top: Color = th["plat_top"]
		var accent: Color = th["accent"]
		var grass: Color = th["grass_dark"]
		for sx in [-34.0, 34.0]:
			var hh := 92.0 if sx < 0.0 else r.randf_range(60.0, 80.0)
			draw_rect(Rect2(sx - 8.0, -hh, 16.0, hh), stone)
			draw_rect(Rect2(sx - 8.0, -hh, 5.0, hh), stone.lightened(0.15))
			draw_rect(Rect2(sx - 11.0, -hh - 6.0, 22.0, 7.0), stone.lightened(0.1))
			draw_rect(Rect2(sx - 11.0, -5.0, 22.0, 5.0), stone.darkened(0.15))
			for k in 3:
				draw_line(Vector2(sx - 4.0 + float(k) * 4.0, -hh + 4.0), Vector2(sx - 4.0 + float(k) * 4.0, -6.0), stone.darkened(0.3), 1.2)
		draw_colored_polygon(PackedVector2Array([Vector2(-44, -98), Vector2(-20, -112), Vector2(0, -104), Vector2(8, -98)]), stone.lightened(0.05))
		draw_polyline(PackedVector2Array([Vector2(-34, -90), Vector2(-30, -60), Vector2(-33, -30)]), grass, 2.0)
		draw_circle(Vector2(-33, -30), 3.0, grass)
		draw_circle(Vector2(0, -60), 22.0, Color(accent.r, accent.g, accent.b, 0.08))
		draw_arc(Vector2(0, -60), 10.0, 0.0, TAU, 20, Color(accent.r, accent.g, accent.b, 0.6), 1.6)

	func _pillar(r: RandomNumberGenerator) -> void:
		var stone: Color = th["plat"]
		var grass: Color = th["grass"]
		var hh := r.randf_range(50.0, 90.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), Vector2(-8, -hh), Vector2(-3, -hh - 5.0), Vector2(2, -hh + 3.0), Vector2(8, -hh - 2.0), Vector2(9, 0)]), stone)
		draw_rect(Rect2(-9.0, -hh, 5.0, hh), stone.lightened(0.15))
		draw_rect(Rect2(-12.0, -5.0, 24.0, 5.0), stone.darkened(0.2))
		for k in 3:
			draw_line(Vector2(-4.0 + float(k) * 4.0, -hh + 3.0), Vector2(-4.0 + float(k) * 4.0, -6.0), stone.darkened(0.3), 1.2)
		draw_circle(Vector2(-2, -hh), 5.0, grass)

	func _crystal(r: RandomNumberGenerator) -> void:
		var accent: Color = th["accent"]
		for i in 5:
			var cx := float(i - 2) * 9.0 + r.randf_range(-3.0, 3.0)
			var ch := r.randf_range(26.0, 66.0) * (1.0 - absf(float(i - 2)) * 0.18)
			var cw := r.randf_range(5.0, 8.0)
			var lean := r.randf_range(-6.0, 6.0)
			var tip := Vector2(cx + lean, -ch)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - cw, 0), Vector2(cx - cw * 0.9 + lean * 0.4, -ch * 0.72), tip, Vector2(cx, 0)]), accent.darkened(0.35))
			draw_colored_polygon(PackedVector2Array([Vector2(cx, 0), tip, Vector2(cx + cw * 0.9 + lean * 0.4, -ch * 0.72), Vector2(cx + cw, 0)]), accent)
			draw_line(Vector2(cx, 0), tip, Color(1, 1, 1, 0.45), 1.0)
			draw_line(Vector2(cx - cw * 0.9 + lean * 0.4, -ch * 0.72), Vector2(cx + cw * 0.9 + lean * 0.4, -ch * 0.72), Color(1, 1, 1, 0.3), 1.0)

	func _mushroom(r: RandomNumberGenerator) -> void:
		var accent: Color = th["accent"]
		var gd: Color = th["grass_dark"]
		var ht := r.randf_range(24.0, 44.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-4, 0), Vector2(-3, -ht), Vector2(3, -ht), Vector2(4, 0)]), Color("#d9d2c0"))
		var cap := PackedVector2Array()
		for i in 13:
			var a := PI + PI * float(i) / 12.0
			cap.append(Vector2(0, -ht) + Vector2(cos(a) * 17.0, sin(a) * 11.0))
		draw_colored_polygon(cap, gd.lerp(accent, 0.35))
		for i in 4:
			draw_circle(Vector2(r.randf_range(-11.0, 11.0), -ht - r.randf_range(2.0, 8.0)), r.randf_range(1.6, 3.0), Color(accent.r, accent.g, accent.b, 0.95))

	func _rock(r: RandomNumberGenerator) -> void:
		var ground: Color = th["ground"]
		var dark: Color = th["ground_dark"]
		var grass: Color = th["grass_dark"]
		for k in 3:
			var cx := float(k - 1) * 11.0 + r.randf_range(-3.0, 3.0)
			var rs := r.randf_range(8.0, 16.0)
			var pts := PackedVector2Array()
			for i in 8:
				var a := PI + PI * float(i) / 7.0
				pts.append(Vector2(cx, 0) + Vector2(cos(a) * rs * r.randf_range(0.8, 1.15), sin(a) * rs * r.randf_range(0.7, 1.0)))
			draw_colored_polygon(pts, ground.lerp(dark, 0.4 + 0.2 * float(k)))
			draw_circle(Vector2(cx - rs * 0.3, -rs * 0.45), rs * 0.28, ground.lightened(0.2))
			draw_line(Vector2(cx + 2.0, -rs * 0.8), Vector2(cx + 4.0, -rs * 0.3), dark.darkened(0.4), 1.2)
			if r.randf() < 0.6:
				draw_circle(Vector2(cx, -rs * 0.85), 3.0, grass)

	func _statue(r: RandomNumberGenerator) -> void:
		var stone: Color = th["plat"]
		var accent: Color = th["accent"]
		draw_rect(Rect2(-14.0, -8.0, 28.0, 8.0), stone.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -8), Vector2(-8, -42), Vector2(-4, -62), Vector2(4, -62), Vector2(8, -42), Vector2(10, -8)]), stone)
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -8), Vector2(-8, -42), Vector2(-4, -62), Vector2(-1, -62), Vector2(-3, -8)]), stone.lightened(0.15))
		draw_circle(Vector2(0, -66), 8.0, stone.lightened(0.05))
		draw_colored_polygon(PackedVector2Array([Vector2(-9, -62), Vector2(0, -78), Vector2(9, -62), Vector2(5, -58), Vector2(-5, -58)]), stone.darkened(0.1))
		draw_circle(Vector2(-2.5, -66), 1.4, accent)
		draw_circle(Vector2(2.5, -66), 1.4, accent)
		draw_circle(Vector2(0, -50), 5.0, Color(accent.r, accent.g, accent.b, 0.25))

	func _banner(r: RandomNumberGenerator) -> void:
		var accent: Color = th["accent"]
		draw_rect(Rect2(-1.5, -86.0, 3.0, 86.0), Color("#3a2a20"))
		draw_circle(Vector2(0, -87), 3.0, Color("#f3c969"))
		var cloth := PackedVector2Array()
		for i in 7:
			cloth.append(Vector2(2.0 + float(i) * 4.0, -82.0 + sin(float(i) * 1.2) * 2.0))
		for i in 7:
			var j := 6 - i
			cloth.append(Vector2(2.0 + float(j) * 4.0, -52.0 + sin(float(j) * 1.2 + 1.0) * 2.0 + (6.0 if j == 3 else 0.0)))
		draw_colored_polygon(cloth, accent.darkened(0.45))
		draw_polyline(cloth, accent.darkened(0.7), 1.2)
		draw_circle(Vector2(14, -67), 5.0, Color(accent.r, accent.g, accent.b, 0.9))

	func _torch() -> void:
		draw_rect(Rect2(-2.0, -48.0, 4.0, 48.0), Color("#4a3224"))
		draw_colored_polygon(PackedVector2Array([Vector2(-7, -52), Vector2(7, -52), Vector2(4, -46), Vector2(-4, -46)]), Color("#5a4a44"))
		draw_colored_polygon(PackedVector2Array([Vector2(-5, -52), Vector2(-6, -62), Vector2(-1, -58), Vector2(1, -70), Vector2(4, -58), Vector2(6, -62), Vector2(5, -52)]), Color("#ff7a1f"))
		draw_colored_polygon(PackedVector2Array([Vector2(-3, -52), Vector2(0, -64), Vector2(3, -52)]), Color("#ffd24a"))

	func _bones(r: RandomNumberGenerator) -> void:
		var bone := Color("#d9d2c0")
		draw_arc(Vector2(0, 0), 20.0, PI, TAU, 14, bone.darkened(0.2), 3.0)
		for i in 5:
			var a := PI + 0.4 + float(i) * 0.5
			draw_arc(Vector2(cos(a) * 4.0, 0), 16.0 - float(i) * 1.5, PI, TAU - 0.4, 10, bone, 2.2)
		draw_circle(Vector2(26, -6), 6.0, bone)
		draw_circle(Vector2(24.5, -7), 1.6, Color("#141a2c"))
		draw_circle(Vector2(28, -7), 1.6, Color("#141a2c"))

	func _tuft(r: RandomNumberGenerator) -> void:
		var grass: Color = th["grass"]
		var gd: Color = th["grass_dark"]
		for i in 9:
			var bx := float(i - 4) * 2.6 + r.randf_range(-1.0, 1.0)
			var bh := r.randf_range(10.0, 24.0)
			var lean := (float(i) - 4.0) * 1.6 + r.randf_range(-2.0, 2.0)
			var c := gd.lerp(grass, r.randf())
			draw_polyline(PackedVector2Array([Vector2(bx, 0), Vector2(bx + lean * 0.5, -bh * 0.55), Vector2(bx + lean, -bh)]), c, 2.2)

class Backdrop extends Node2D:
	var cam: Camera2D
	var t := 0.0
	var th := {}
	var sky_top := Color("#0b1020")
	var sky_bottom := Color("#2a2f5e")
	var ridge1 := Color("#1b2547")
	var ridge2 := Color("#17203d")
	var ridge3 := Color("#111a31")
	var accent := Color("#7ef9ff")

	func apply_theme(d: Dictionary) -> void:
		th = d
		sky_top = d["sky_top"]
		sky_bottom = d["sky_bottom"]
		ridge1 = d["ridge1"]
		ridge2 = d["ridge2"]
		ridge3 = d["ridge3"]
		accent = d["accent"]

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _hash(i: int) -> float:
		return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)

	func _rh(wx: float, freq: float) -> float:
		return sin(wx * freq) * 0.6 + sin(wx * freq * 2.3 + 1.7) * 0.3 + sin(wx * freq * 5.1) * 0.1

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var cx := 0.0
		if is_instance_valid(cam):
			cx = cam.get_screen_center_position().x
		var bands := 32
		for i in bands:
			var k := float(i) / float(bands - 1)
			draw_rect(Rect2(0.0, vs.y * float(i) / float(bands), vs.x, vs.y / float(bands) + 1.0), sky_top.lerp(sky_bottom, pow(k, 1.5)))
		for b in 3:
			var top_pts := PackedVector2Array()
			var bot_pts := PackedVector2Array()
			var y0 := vs.y * (0.16 + 0.09 * float(b))
			for i in 25:
				var x := vs.x * float(i) / 24.0
				var y := y0 + sin(x * 0.012 + t * 0.4 + float(b) * 2.0) * 22.0 + sin(x * 0.03 - t * 0.3) * 8.0
				top_pts.append(Vector2(x, y))
				bot_pts.append(Vector2(x, y + 36.0 + 14.0 * sin(x * 0.02 + float(b))))
			var poly := top_pts.duplicate()
			for i in range(24, -1, -1):
				poly.append(bot_pts[i])
			draw_colored_polygon(poly, Color(accent.r, accent.g, accent.b, 0.055))
		for i in 90:
			var depth := 0.02 + 0.03 * float(i % 3)
			var sx := fposmod(float(i) * 173.0 - cx * depth, vs.x)
			var sy := fposmod(float(i) * 97.0, vs.y * 0.62)
			var tw := 0.5 + 0.5 * sin(t * 2.0 + float(i))
			var sz := 3.0 if i % 11 == 0 else 2.0
			draw_rect(Rect2(sx, sy, sz, sz), Color(1.0, 1.0, 1.0, 0.25 + 0.5 * tw))
			if i % 11 == 0:
				draw_line(Vector2(sx - 4.0, sy + 1.0), Vector2(sx + 6.0, sy + 1.0), Color(1, 1, 1, 0.25 * tw), 1.0)
				draw_line(Vector2(sx + 1.0, sy - 4.0), Vector2(sx + 1.0, sy + 6.0), Color(1, 1, 1, 0.25 * tw), 1.0)
		var moon := Vector2(vs.x * 0.78, 92.0)
		draw_circle(moon, 70.0, Color(0.55, 0.65, 1.0, 0.04))
		draw_circle(moon, 52.0, Color(0.55, 0.65, 1.0, 0.07))
		draw_circle(moon, 34.0, Color("#dfe8ff"))
		draw_circle(moon + Vector2(-9.0, -5.0), 7.0, Color("#c3cfee"))
		draw_circle(moon + Vector2(10.0, 9.0), 5.0, Color("#c3cfee"))
		draw_circle(moon + Vector2(6.0, -12.0), 3.0, Color("#c3cfee"))
		var sph := fposmod(t, 9.0)
		if sph < 0.7:
			var u := sph / 0.7
			var sp := Vector2(vs.x * 0.15, 40.0).lerp(Vector2(vs.x * 0.55, 150.0), u)
			draw_line(sp, sp - Vector2(34.0, 10.0), Color(1, 1, 1, 1.0 - u), 2.0)
		for i in 6:
			var x := fposmod(float(i) * 260.0 - cx * 0.04 + t * 6.0, vs.x + 300.0) - 150.0
			var y := 50.0 + fposmod(float(i) * 53.0, 150.0)
			var cc := sky_bottom.lightened(0.35)
			cc.a = 0.1
			for k in 4:
				draw_circle(Vector2(x + float(k) * 22.0, y + sin(float(k) * 1.7) * 6.0), 18.0 - float(k % 2) * 5.0, cc)
		for i in 3:
			var x := fposmod(float(i) * 420.0 - cx * 0.08, vs.x + 400.0) - 200.0
			var y := 130.0 + fposmod(float(i) * 70.0, 80.0)
			var ic := ridge1.lightened(0.12)
			ic.a = 0.75
			draw_colored_polygon(PackedVector2Array([Vector2(x - 50, y), Vector2(x + 50, y), Vector2(x + 30, y + 14), Vector2(x + 12, y + 40), Vector2(x - 4, y + 60), Vector2(x - 22, y + 30), Vector2(x - 40, y + 14)]), ic)
			draw_rect(Rect2(x - 50.0, y - 3.0, 100.0, 4.0), Color(ridge3.r + 0.05, ridge3.g + 0.15, ridge3.b + 0.05, 0.8))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 6, y - 3), Vector2(x, y - 22), Vector2(x + 6, y - 3)]), ridge2)
		var off1 := cx * 0.10
		var base1 := vs.y * 0.62
		_ridge(vs, off1, base1, 70.0, 0.0045, ridge1)
		for i in 9:
			var px := fposmod(float(i) * 230.0 + _hash(i) * 120.0 - off1, vs.x + 240.0) - 120.0
			var gy := base1 - 70.0 * _rh(px + off1, 0.0045)
			var tw1 := 9.0 + 7.0 * _hash(i + 3)
			var th1 := 36.0 + 60.0 * _hash(i + 7)
			var tc := ridge1.darkened(0.25)
			draw_rect(Rect2(px - tw1 * 0.5, gy - th1, tw1, th1 + 6.0), tc)
			draw_colored_polygon(PackedVector2Array([Vector2(px - tw1 * 0.7, gy - th1), Vector2(px, gy - th1 - 20.0), Vector2(px + tw1 * 0.7, gy - th1)]), tc)
			if _hash(i + 11) < 0.7:
				draw_rect(Rect2(px - 1.5, gy - th1 * 0.6, 3.0, 5.0), Color(accent.r, accent.g, accent.b, 0.55 + 0.25 * sin(t * 2.0 + float(i))))
		var off2 := cx * 0.22
		var base2 := vs.y * 0.72
		_ridge(vs, off2, base2, 55.0, 0.007, ridge2)
		for i in 14:
			var px2 := fposmod(float(i) * 120.0 + _hash(i + 20) * 60.0 - off2, vs.x + 160.0) - 80.0
			var gy2 := base2 - 55.0 * _rh(px2 + off2, 0.007)
			var hh := 22.0 + 28.0 * _hash(i + 30)
			var pc := ridge2.darkened(0.2)
			for k in 3:
				var wd := 12.0 - float(k) * 3.0
				var yy := gy2 - float(k) * hh * 0.3
				draw_colored_polygon(PackedVector2Array([Vector2(px2 - wd, yy), Vector2(px2, yy - hh * 0.5), Vector2(px2 + wd, yy)]), pc)
		_ridge(vs, cx * 0.40, vs.y * 0.84, 40.0, 0.011, ridge3)
		for i in 7:
			var my := vs.y * 0.7 + float(i) * 14.0
			draw_rect(Rect2(0.0, my, vs.x, 14.0), Color(sky_bottom.r, sky_bottom.g, sky_bottom.b, 0.045))
		for i in 22:
			var fx := fposmod(float(i) * 97.0 + t * (6.0 + float(i % 5)) - cx * 0.12, vs.x)
			var fy := vs.y * (0.42 + 0.5 * _hash(i + 50)) + sin(t * 0.8 + float(i)) * 14.0
			var fa := 0.25 + 0.5 * (0.5 + 0.5 * sin(t * 2.0 + float(i)))
			draw_circle(Vector2(fx, fy), 4.0, Color(accent.r, accent.g, accent.b, fa * 0.25))
			draw_circle(Vector2(fx, fy), 1.4, Color(accent.r, accent.g, accent.b, fa))

	func _ridge(vs: Vector2, off: float, base: float, amp: float, freq: float, col: Color) -> void:
		var pts := PackedVector2Array()
		var step := 20.0
		var x := 0.0
		while x <= vs.x + step:
			pts.append(Vector2(x, base - amp * _rh(x + off, freq)))
			x += step
		pts.append(Vector2(vs.x + step, vs.y))
		pts.append(Vector2(0.0, vs.y))
		draw_colored_polygon(pts, col)
