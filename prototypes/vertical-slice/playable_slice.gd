## Playable Vertical Slice — Mirror Hero (Production Sprint 1, VS-1).
##
## Runnable scene so a human can WATCH the full core loop with real timing. F5/F6.
## A mock "push day" workout auto-loops: each set spawns a skeleton that walks in from
## the right → avatar STRIKES → skeleton dies → on workout-complete a boss kill drops LOOT.
## The class/loot/mirror LOGIC is the REAL autoload loop; the combat VISUALS are puppeted
## for the glance demo (no full combat scene yet).
##
## Avatars/enemies = REAL LPC sprites (CC-BY-SA, see README + .license.md). Classic LPC
## layout: walk-down y640 (9f) / walk-left y576 (9f) / slash-down y896 (6f).
## Project default texture filter = Nearest so pixel art stays crisp.
##
## Headless: prints the trace and quit(0) after one pass.
extends Node2D


const STEP := 0.9
const GROUND_Y := 615.0       ## avatar/enemy feet baseline — aligned to map.png's foreground path
const FRAME := 64
const MAP_PATH := "res://prototypes/vertical-slice/art/map.png"
const BGM_PATH := "res://prototypes/vertical-slice/audio/bgm.wav"
const HIT_PATH := "res://prototypes/vertical-slice/audio/hit.wav"
const LOOT_PATH := "res://prototypes/vertical-slice/audio/loot.wav"
const WALK_LEFT_Y := 576      ## LPC walk, facing left — row 9 (enemy approaching from right)
const HERO_WALK_Y := 704      ## LPC walk, facing right — row 11 (hero faces the incoming enemies, side view)
const HERO_SLASH_Y := 960     ## LPC slash, facing right — row 15
const HERO_PATH := "res://prototypes/vertical-slice/art/hero_strike_lpc_sheet.png"
const MONSTER_PATH := "res://prototypes/vertical-slice/art/monster.png"
const SCALE := 2.6
const AVATAR_X := 430.0

# ── REAL GymSys connection (edit for your own account; don't commit real creds) ──
const GYM_BASE := "http://127.0.0.1:8090"   ## GYM = 8090 HTTP; 127.0.0.1 NOT localhost (IPv4-only bind)
const GYM_USER := "mh_e2e"                   ## throwaway test account (has a seeded workout)
const GYM_PASS := "pass1234"

const RARITY_COLOR := {
	"COMMON": Color(0.85, 0.85, 0.82), "UNCOMMON": Color(0.40, 0.80, 0.42),
	"RARE": Color(0.30, 0.60, 0.95), "EPIC": Color(0.70, 0.40, 0.92),
	"LEGENDARY": Color(0.96, 0.62, 0.20),
}

var _log_label: Label
var _trace: Array[String] = []
var _headless: bool = false
var _sprite: AnimatedSprite2D
var _base_y: float = 0.0
var _t: float = 0.0
var _enemy_frames: SpriteFrames
var _bgm: AudioStreamPlayer
var _sfx_hit: AudioStreamPlayer
var _sfx_loot: AudioStreamPlayer


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	await get_tree().process_frame
	await get_tree().process_frame
	_build_stage()
	_build_avatar()
	_build_enemy_frames()
	_build_hud()
	_build_event_log()
	_build_audio()
	_wire_observers()
	_run_demo()


func _process(delta: float) -> void:
	if _sprite != null:
		_t += delta
		_sprite.position.y = _base_y + sin(_t * 2.5) * 2.5


# ── Stage ────────────────────────────────────────────────────────────────────
func _build_stage() -> void:
	var cam := Camera2D.new()
	add_child(cam)
	cam.position = Vector2(640, 360)
	cam.make_current()
	var bg_tex: Texture2D = load(MAP_PATH)
	if bg_tex != null:
		var bg := Sprite2D.new()
		bg.texture = bg_tex
		bg.position = Vector2(640, 360)
		var sc: float = maxf(1280.0 / bg_tex.get_width(), 720.0 / bg_tex.get_height()) * 1.06  # cover + crop border
		bg.scale = Vector2(sc, sc)
		bg.z_index = -100
		add_child(bg)
		_stage_log("background = map.png")
	else:
		_rect(Color(0.13, 0.16, 0.20), Vector2(0, 0), Vector2(1280, 720), -100)  # fallback
		_stage_log("⚠ map.png missing — flat fallback")
	var tl := CanvasLayer.new()
	tl.layer = 96
	add_child(tl)
	var title := Label.new()
	title.text = "鏡像勇者 Mirror Hero — Vertical Slice  ·  LPC placeholder art"
	title.position = Vector2(330, 18)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	tl.add_child(title)


func _rect(c: Color, pos: Vector2, size: Vector2, z: int) -> void:
	var r := ColorRect.new()
	r.color = c; r.position = pos; r.size = size; r.z_index = z
	add_child(r)


# ── Avatar (LPC hero) ────────────────────────────────────────────────────────
func _build_avatar() -> void:
	var sheet: Texture2D = load(HERO_PATH)
	_sprite = AnimatedSprite2D.new()
	_sprite.position = Vector2(AVATAR_X, GROUND_Y - 84)
	_base_y = GROUND_Y - 84
	_sprite.scale = Vector2(SCALE, SCALE)
	_sprite.z_index = 1
	if sheet != null:
		_sprite.sprite_frames = _hero_frames(sheet)
		_sprite.play(&"idle")
		_stage_log("avatar = LPC hero")
	else:
		_stage_log("⚠ hero sheet missing")
	add_child(_sprite)
	var avatar := _node("AvatarRenderer")
	if avatar != null and avatar.has_method("register_sprite"):
		avatar.register_sprite(_sprite)


func _hero_frames(sheet: Texture2D) -> SpriteFrames:
	var f := SpriteFrames.new()
	f.add_animation(&"idle"); f.set_animation_loop(&"idle", true); f.set_animation_speed(&"idle", 1)
	f.add_frame(&"idle", _atlas(sheet, 0, HERO_WALK_Y))
	f.add_animation(&"walk"); f.set_animation_speed(&"walk", 9)
	for i in range(9): f.add_frame(&"walk", _atlas(sheet, i * FRAME, HERO_WALK_Y))
	f.add_animation(&"strike"); f.set_animation_loop(&"strike", false); f.set_animation_speed(&"strike", 12)
	for i in range(6): f.add_frame(&"strike", _atlas(sheet, i * FRAME, HERO_SLASH_Y))
	return f


# ── Enemy (LPC skeleton) ─────────────────────────────────────────────────────
func _build_enemy_frames() -> void:
	var sheet: Texture2D = load(MONSTER_PATH)
	if sheet == null:
		_stage_log("⚠ monster sheet missing — enemies disabled")
		return
	_enemy_frames = SpriteFrames.new()
	_enemy_frames.add_animation(&"walk"); _enemy_frames.set_animation_speed(&"walk", 6)
	for i in range(9): _enemy_frames.add_frame(&"walk", _atlas(sheet, i * FRAME, WALK_LEFT_Y))
	_stage_log("enemy = LPC skeleton")


## One self-contained combat beat: a skeleton runs in from the right, the hero strikes,
## the skeleton flashes / falls / fades. Fire-and-forget (its own coroutine) so beats
## don't pile up — at most one or two on screen at once, none left standing.
func _fight_one() -> void:
	if _enemy_frames == null:
		return
	var e := AnimatedSprite2D.new()
	e.sprite_frames = _enemy_frames
	e.scale = Vector2(SCALE, SCALE)
	e.position = Vector2(1080.0, GROUND_Y - 84)
	e.z_index = 1
	e.play(&"walk")
	add_child(e)
	var tin := create_tween()
	tin.tween_property(e, "position:x", AVATAR_X + 175.0, 0.9).set_trans(Tween.TRANS_SINE)
	await tin.finished
	if not is_instance_valid(e):
		return
	_play(&"strike", 0.5)                          # hero swings
	_play_sfx(_sfx_hit)
	await get_tree().create_timer(0.16).timeout
	if not is_instance_valid(e):
		return
	e.modulate = Color(1.0, 0.5, 0.5)              # hit flash
	var td := create_tween()
	td.tween_property(e, "rotation", deg_to_rad(80), 0.30).set_trans(Tween.TRANS_QUAD)
	td.parallel().tween_property(e, "position:y", GROUND_Y - 40.0, 0.30)
	td.parallel().tween_property(e, "modulate:a", 0.0, 0.35)
	td.tween_callback(e.queue_free)


# ── shared sprite helpers ────────────────────────────────────────────────────
func _atlas(sheet: Texture2D, x: int, y: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(x, y, FRAME, FRAME)
	return a


func _play(anim: StringName, back_to_idle: float = 0.0) -> void:
	if _sprite == null or _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(anim):
		return
	_sprite.play(anim)
	if back_to_idle > 0.0:
		await get_tree().create_timer(back_to_idle).timeout
		if _sprite != null:
			_sprite.play(&"idle")


func _hop() -> void:
	if _sprite == null:
		return
	var tw := create_tween()
	tw.tween_property(_sprite, "position:y", _base_y - 26.0, 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "position:y", _base_y, 0.20).set_trans(Tween.TRANS_BOUNCE)


# ── Loot gem pop ─────────────────────────────────────────────────────────────
func _spawn_loot_visual(rarity: String, item_type: String) -> void:
	var col: Color = RARITY_COLOR.get(rarity, Color.WHITE)
	var cx := 640.0
	var cy := 320.0
	var layer := CanvasLayer.new()
	layer.layer = 110                              # above HUD(50) + log(95) for full impact
	add_child(layer)

	# 1. freeze backdrop — darken the world so the loot pops (mimics the real loot modal)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.04, 0.0)
	back.size = Vector2(1280, 720)
	layer.add_child(back)
	var bt := create_tween()
	bt.tween_property(back, "color:a", 0.5, 0.10)
	bt.tween_interval(0.55)
	bt.tween_property(back, "color:a", 0.0, 0.5)

	# 2. rarity-tinted flash
	var flash := ColorRect.new()
	flash.color = Color(col.r, col.g, col.b, 0.75)
	flash.size = Vector2(1280, 720)
	layer.add_child(flash)
	create_tween().tween_property(flash, "color:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)

	# 3. shockwave ring
	var ring := Line2D.new()
	ring.width = 6.0
	ring.default_color = col
	ring.closed = true
	var rp := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		rp.append(Vector2(cos(a), sin(a)) * 40.0)
	ring.points = rp
	ring.position = Vector2(cx, cy)
	ring.scale = Vector2(0.3, 0.3)
	layer.add_child(ring)
	var rt := create_tween()
	rt.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.5).set_ease(Tween.EASE_OUT)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)

	# 4. shard burst
	for i in range(8):
		var sh := Polygon2D.new()
		sh.polygon = PackedVector2Array([Vector2(0, -7), Vector2(5, 0), Vector2(0, 7), Vector2(-5, 0)])
		sh.color = col
		sh.position = Vector2(cx, cy)
		layer.add_child(sh)
		var ang := TAU * i / 8.0
		var dest := Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * 220.0
		var st := create_tween()
		st.tween_property(sh, "position", dest, 0.6).set_ease(Tween.EASE_OUT)
		st.parallel().tween_property(sh, "modulate:a", 0.0, 0.6)

	# 5. gem — big overshoot pop, hold, float + fade
	var gem := Polygon2D.new()
	gem.polygon = PackedVector2Array([Vector2(0, -26), Vector2(20, 0), Vector2(0, 26), Vector2(-20, 0)])
	gem.color = col
	gem.position = Vector2(cx, cy)
	gem.scale = Vector2.ZERO
	layer.add_child(gem)
	var lbl := Label.new()
	lbl.text = "%s\n%s" % [rarity, item_type]
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", col)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-60, 36)
	lbl.size = Vector2(120, 0)
	gem.add_child(lbl)
	var gt := create_tween()
	gt.tween_property(gem, "scale", Vector2(2.3, 2.3), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gt.tween_property(gem, "scale", Vector2(1.7, 1.7), 0.14)
	gt.tween_interval(0.5)
	gt.tween_property(gem, "position:y", cy - 90.0, 0.5).set_ease(Tween.EASE_OUT)
	gt.parallel().tween_property(gem, "modulate:a", 0.0, 0.5)
	gt.tween_callback(layer.queue_free)            # tear down the whole ceremony layer at the end


# ── HUD + event log ──────────────────────────────────────────────────────────
func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 50
	add_child(hud_layer)
	var s: PackedScene = load("res://src/ui/gym_mode_hud/GymModeHud.tscn")
	if s != null:
		hud_layer.add_child(s.instantiate())
		_stage_log("Gym-Mode HUD (#20) instantiated")


func _build_event_log() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.62); bg.size = Vector2(560, 340); bg.position = Vector2(16, 72)
	layer.add_child(bg)
	var hdr := Label.new()
	hdr.text = "LOOP TRACE (live)"; hdr.position = Vector2(30, 82)
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
	layer.add_child(hdr)
	_log_label = Label.new()
	_log_label.position = Vector2(30, 106)
	_log_label.add_theme_font_size_override("font_size", 16)
	_log_label.add_theme_color_override("font_color", Color(0.949, 0.663, 0.231))
	layer.add_child(_log_label)


# ── Audio (placeholder synthesized SFX/BGM) ──────────────────────────────────
## Direct AudioStreamPlayer nodes (prototype-relaxed) — bypasses the production
## AudioManager catalog (#4), whose sfx_catalog.tres/bgm_catalog.tres aren't authored yet.
func _build_audio() -> void:
	var bgm: AudioStream = load(BGM_PATH)
	if bgm != null:
		_bgm = AudioStreamPlayer.new()
		_bgm.stream = bgm
		_bgm.volume_db = -8.0
		add_child(_bgm)
		_bgm.finished.connect(_loop_bgm)               # loop
		_bgm.play()
		_stage_log("audio: bgm loop + sfx (placeholder)")
	_sfx_hit = _make_sfx(HIT_PATH, -4.0)
	_sfx_loot = _make_sfx(LOOT_PATH, -2.0)


func _make_sfx(path: String, db: float) -> AudioStreamPlayer:
	var s: AudioStream = load(path)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	add_child(p)
	return p


func _play_sfx(p: AudioStreamPlayer) -> void:
	if p != null:
		p.play()


func _loop_bgm() -> void:
	if is_instance_valid(_bgm):
		_bgm.play()


# ── Observe real downstream loop ─────────────────────────────────────────────
func _wire_observers() -> void:
	_connect("WorkoutStateTracker", "dominant_class_changed", _on_class)
	_connect("WorkoutStateTracker", "workout_completed_forwarded", _on_completed)
	_connect("AvatarRenderer", "avatar_evolution_milestone", _on_evolution)
	_connect("LootDropSystem", "loot_dropped", _on_loot)
	_connect("MirrorMomentCoordinator", "ceremony_presented", _on_ceremony)


# ── REAL GymSys feed drives the loop (Option B) ──────────────────────────────
# WST is already bound to the GymSysBackendClient autoload at boot; we log in to start
# the live feed, then observe the client's signals to puppet the combat/loot visuals.
# A real completed workout (cursor starts at 0 → first poll returns this account's saved
# workouts) replays as set_logged ×N → workout_completed; afterwards the client idles and
# reacts to any NEW workout you save in GYM (within the poll interval).
func _run_demo() -> void:
	var gym := _node("GymSysBackendClient")
	if gym == null:
		_stage_log("FAIL — GymSysBackendClient missing"); _maybe_quit(); return
	gym.logged_in.connect(_on_gym_login)
	gym.workout_started.connect(_on_gym_workout_started)
	gym.set_logged.connect(_on_gym_set)
	gym.workout_completed.connect(_on_gym_completed)
	gym.poll_failed.connect(_on_gym_poll_failed)
	_stage_log("▶ 連接真 GYM %s as %s …" % [GYM_BASE, GYM_USER])
	gym.login(GYM_BASE, GYM_USER, GYM_PASS, 3.0)
	if _headless:
		await get_tree().create_timer(9.0).timeout
		_maybe_quit()


func _on_gym_login(ok: bool) -> void:
	_stage_log("GYM login " + ("OK — 等緊 workout feed" if ok else "FAILED — 開咗 GYM (8090)?"))

func _on_gym_workout_started() -> void:
	_stage_log("🏋 workout 開始")

func _on_gym_set(eid: StringName, reps: int, w: float) -> void:
	_stage_log("• set %s ×%d @%.1f" % [eid, reps, w])
	_fight_one()

func _on_gym_completed(_at: int) -> void:
	_stage_log("🏁 workout 完成 → 爆裝")
	_simulate_kill()

func _on_gym_poll_failed(cat: StringName) -> void:
	_stage_log("⚠ GYM poll fail: " + str(cat))


func _simulate_kill() -> void:
	var ed := _node("EnemyDirector")
	if ed == null:
		return
	var p := EnemyKilledPayload.new()
	p.enemy_id = &"final_boss"; p.enemy_instance_id = 9001; p.killer_id = 1
	p.killing_ability = &"strike_basic"; p.transition_id = "slice-kill-" + str(Time.get_ticks_msec())
	ed.enemy_killed.emit(p)


# ── Observer handlers ────────────────────────────────────────────────────────
func _on_class(c: int) -> void:
	_stage_log("   ↳ #10 class → %s" % _cname(c))
func _on_completed(_at: int, _tid: String) -> void:
	_stage_log("   ↳ #9 workout forwarded")
func _on_evolution(tier: int, _m: Dictionary) -> void:
	_stage_log("   ↳ #26 avatar evolved → tier %d" % tier)
func _on_loot(_id: String, rarity: String, item_type: String, _tid: String) -> void:
	_hop()
	_play_sfx(_sfx_loot)
	_spawn_loot_visual(rarity, item_type)
	_stage_log("   ★ #15 LOOT: %s %s" % [rarity, item_type])
func _on_ceremony(_content: int, tier: int) -> void:
	_stage_log("   ✦ #29 Mirror Moment (tier %d)" % tier)


# ── helpers ──────────────────────────────────────────────────────────────────
func _node(n: String) -> Node:
	return get_tree().root.get_node_or_null(n)

func _connect(autoload_name: String, sig: String, cb: Callable) -> void:
	var n := _node(autoload_name)
	if n != null and n.has_signal(sig):
		n.connect(sig, cb)

func _cname(c: int) -> String:
	match c:
		0: return "STRIKE"
		1: return "CONTROL"
		2: return "MOBILITY"
		_: return "UNKNOWN"

func _wait() -> void:
	await get_tree().create_timer(STEP).timeout

func _stage_log(msg: String) -> void:
	_trace.append(msg)
	if _log_label != null:
		_log_label.text = "\n".join(_trace.slice(max(0, _trace.size() - 15)))
	print("[slice] %s" % msg)

func _maybe_quit() -> void:
	if _headless:
		print("[playable_slice] headless self-check complete — quitting 0")
		get_tree().quit(0)
