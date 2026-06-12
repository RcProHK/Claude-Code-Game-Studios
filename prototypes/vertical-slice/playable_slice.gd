## Playable Vertical Slice — Mirror Hero (Production Sprint 1, VS-1).
##
## A RUNNABLE placeholder scene so a human can WATCH the core loop fire with real timing
## (the bridge from the headless harness to a Milestone-1 fun playtest). Press F5/F6 in
## Godot 4.6.3. A mock "push day" workout auto-loops, driving:
##   workout starts → sets logged → class derives → workout completes → boss kill →
##   LOOT DROP (rarity gem pops) + avatar reacts, with a live on-screen event log.
##
## PLACEHOLDER ART by design — the avatar is drawn from primitive shapes (Polygon2D),
## not real sprites. The point is feel / timing / readability of the LOOP, not final art.
## Replace the drawn avatar with a real sprite (design/assets/entity-inventory.md →
## avatar T1 STRIKE) when ready; that is the only thing between this and "looks like a game".
##
## Drives the loop at the proven FakeGymSysClient seam. Real autoloads do the rest.
## Headless: prints the trace and quit(0) after one pass (CI / quick self-check).
extends Node2D


## Fake #2 GymSysBackendClient — the 7 Locked ADR-0002 signals.
class FakeGymSysClient:
	signal workout_started()
	signal set_logged(exercise_id: StringName, reps: int, weight: float)
	signal rest_started(duration_seconds: int)
	signal rest_ended()
	signal workout_completed(completed_at: int)
	signal poll_failed(category: StringName)
	signal poll_recovered()


const STEP := 0.9
const GROUND_Y := 360.0          ## avatar feet baseline (screen-space-ish, scene is centered cam)

const CLASS_COLOR := {
	0: Color(0.90, 0.32, 0.26),   # STRIKE  — red
	1: Color(0.62, 0.36, 0.85),   # CONTROL — purple
	2: Color(0.30, 0.56, 0.92),   # MOBILITY— blue
	3: Color(0.62, 0.60, 0.58),   # UNKNOWN — grey
}
const RARITY_COLOR := {
	"COMMON": Color(0.85, 0.85, 0.82),
	"UNCOMMON": Color(0.40, 0.80, 0.42),
	"RARE": Color(0.30, 0.60, 0.95),
	"EPIC": Color(0.70, 0.40, 0.92),
	"LEGENDARY": Color(0.96, 0.62, 0.20),
}

var _fake_gym: FakeGymSysClient
var _log_label: Label
var _trace: Array[String] = []
var _headless: bool = false
var _avatar: Node2D
var _torso: Polygon2D
var _head: Polygon2D
var _avatar_base_y: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	await get_tree().process_frame
	await get_tree().process_frame
	_build_stage()
	_build_avatar()
	_build_hud()
	_build_event_log()
	_wire_observers()
	_run_demo()


func _process(delta: float) -> void:
	# Idle bob so the avatar reads as "alive", not a static box.
	if _avatar != null:
		_t += delta
		_avatar.position.y = _avatar_base_y + sin(_t * 3.0) * 3.0


# ── Stage (placeholder) ──────────────────────────────────────────────────────
func _build_stage() -> void:
	var cam := Camera2D.new()
	add_child(cam)
	cam.position = Vector2(640, 360)        # center on a 1280x720 layout
	cam.make_current()

	_rect(Color(0.13, 0.16, 0.20), Vector2(0, 0), Vector2(1280, 380), -10)      # sky
	_rect(Color(0.16, 0.20, 0.18), Vector2(0, 250), Vector2(1280, 130), -9)     # distant hills band
	_rect(Color(0.243, 0.357, 0.227), Vector2(0, 380), Vector2(1280, 340), -5)  # ground (world_moss)
	_rect(Color(0.30, 0.42, 0.27), Vector2(0, 380), Vector2(1280, 10), -4)      # bright platform top edge

	var title := Label.new()
	title.text = "鏡像勇者 Mirror Hero — Vertical Slice  ·  placeholder art"
	title.position = Vector2(640, 18)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(0, 0)
	var tl := CanvasLayer.new()
	tl.layer = 96
	add_child(tl)
	tl.add_child(title)
	title.position = Vector2(360, 18)


func _rect(c: Color, pos: Vector2, size: Vector2, z: int) -> void:
	var r := ColorRect.new()
	r.color = c
	r.position = pos
	r.size = size
	r.z_index = z
	add_child(r)


# ── Avatar (drawn placeholder humanoid) ──────────────────────────────────────
func _build_avatar() -> void:
	_avatar = Node2D.new()
	_avatar.position = Vector2(640, GROUND_Y)
	_avatar_base_y = GROUND_Y
	add_child(_avatar)

	# shadow
	var shadow := Polygon2D.new()
	shadow.polygon = _ellipse(26, 8)
	shadow.position = Vector2(0, 4)
	shadow.color = Color(0, 0, 0, 0.30)
	_avatar.add_child(shadow)
	# legs
	var legs := Polygon2D.new()
	legs.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(11, -36), Vector2(-11, -36)])
	legs.color = Color(0.22, 0.24, 0.28)
	_avatar.add_child(legs)
	# torso (class-colored)
	_torso = Polygon2D.new()
	_torso.polygon = PackedVector2Array([Vector2(-13, -34), Vector2(13, -34), Vector2(16, -74), Vector2(-16, -74)])
	_torso.color = CLASS_COLOR[3]
	_avatar.add_child(_torso)
	# weapon (held, low at T1 per art-bible §5.A)
	var weapon := Line2D.new()
	weapon.points = PackedVector2Array([Vector2(13, -58), Vector2(34, -40)])
	weapon.width = 5.0
	weapon.default_color = Color(0.70, 0.72, 0.74)
	_avatar.add_child(weapon)
	# head
	_head = Polygon2D.new()
	_head.polygon = _circle(12)
	_head.position = Vector2(0, -86)
	_head.color = CLASS_COLOR[3]
	_avatar.add_child(_head)

	var tag := Label.new()
	tag.text = "you"
	tag.position = Vector2(-12, -118)
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_avatar.add_child(tag)


func _recolor_avatar(c: int) -> void:
	if _torso != null:
		_torso.color = CLASS_COLOR.get(c, CLASS_COLOR[3])
	if _head != null:
		_head.color = (CLASS_COLOR.get(c, CLASS_COLOR[3]) as Color).lightened(0.25)


func _avatar_hop() -> void:
	if _avatar == null:
		return
	var tw := create_tween()
	tw.tween_property(_avatar, "position:y", _avatar_base_y - 28.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_avatar, "position:y", _avatar_base_y, 0.22).set_trans(Tween.TRANS_BOUNCE)


# ── Loot pop visual ──────────────────────────────────────────────────────────
func _spawn_loot_visual(rarity: String, item_type: String) -> void:
	var gem := Polygon2D.new()
	gem.polygon = PackedVector2Array([Vector2(0, -16), Vector2(13, 0), Vector2(0, 16), Vector2(-13, 0)])
	gem.color = RARITY_COLOR.get(rarity, Color.WHITE)
	gem.position = Vector2(700, GROUND_Y - 60)
	gem.scale = Vector2.ZERO
	add_child(gem)
	var lbl := Label.new()
	lbl.text = "%s %s" % [rarity, item_type]
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", RARITY_COLOR.get(rarity, Color.WHITE))
	lbl.position = Vector2(-30, 20)
	gem.add_child(lbl)

	var tw := create_tween()
	tw.tween_property(gem, "scale", Vector2(1.4, 1.4), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(gem, "scale", Vector2(1.0, 1.0), 0.12)
	tw.parallel().tween_property(gem, "position:y", GROUND_Y - 150.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(gem, "modulate:a", 0.0, 0.5)
	tw.tween_callback(gem.queue_free)
	_avatar_hop()


# ── HUD + event log ──────────────────────────────────────────────────────────
func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 50
	add_child(hud_layer)
	var hud_scene: PackedScene = load("res://src/ui/gym_mode_hud/GymModeHud.tscn")
	if hud_scene != null:
		hud_layer.add_child(hud_scene.instantiate())
		_stage_log("Gym-Mode HUD (#20) instantiated")


func _build_event_log() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.62)
	bg.size = Vector2(600, 380)
	bg.position = Vector2(16, 70)
	layer.add_child(bg)
	var hdr := Label.new()
	hdr.text = "LOOP TRACE (live)"
	hdr.position = Vector2(30, 80)
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
	layer.add_child(hdr)
	_log_label = Label.new()
	_log_label.position = Vector2(30, 104)
	_log_label.add_theme_font_size_override("font_size", 16)
	_log_label.add_theme_color_override("font_color", Color(0.949, 0.663, 0.231))  # ui_amber
	layer.add_child(_log_label)


# ── Observe the real downstream loop ─────────────────────────────────────────
func _wire_observers() -> void:
	_connect("WorkoutStateTracker", "dominant_class_changed", _on_class)
	_connect("WorkoutStateTracker", "workout_completed_forwarded", _on_completed)
	_connect("AvatarRenderer", "avatar_evolution_milestone", _on_evolution)
	_connect("LootDropSystem", "loot_dropped", _on_loot)
	_connect("MirrorMomentCoordinator", "ceremony_presented", _on_ceremony)


# ── Scripted demo (loops in windowed mode) ───────────────────────────────────
func _run_demo() -> void:
	var wst := _node("WorkoutStateTracker")
	if wst == null:
		_stage_log("FAIL — WorkoutStateTracker missing")
		_maybe_quit()
		return
	_fake_gym = FakeGymSysClient.new()
	wst.set(&"_gym_sys_client", _fake_gym)
	wst.call("_connect_gym_sys_signals")

	while true:
		_trace.clear()
		_stage_log("▶ mock 'push day' workout")
		await _wait()
		_stage_log("🏋 workout_started"); _fake_gym.workout_started.emit()
		await _wait()
		_stage_log("• bench_press ×8 @60kg (push → STRIKE)"); _fake_gym.set_logged.emit(&"bench_press", 8, 60.0)
		await _wait()
		_stage_log("• bench_press ×8 @62.5kg"); _fake_gym.set_logged.emit(&"bench_press", 8, 62.5)
		await _wait()
		_stage_log("• rest 90s → resume"); _fake_gym.rest_started.emit(90); _fake_gym.rest_ended.emit()
		await _wait()
		_stage_log("• overhead_press ×6 @40kg"); _fake_gym.set_logged.emit(&"overhead_press", 6, 40.0)
		await _wait()
		_stage_log("🏁 workout_completed"); _fake_gym.workout_completed.emit(1749700000)
		await _wait()
		_stage_log("⚔ boss kill → LOOT"); _simulate_kill()
		await _wait()
		await _wait()
		_stage_log("✔ loop complete — replace placeholder avatar w/ real sprite for the real feel")
		if _headless:
			_maybe_quit()
			return
		await _wait()
		await _wait()


func _simulate_kill() -> void:
	var ed := _node("EnemyDirector")
	if ed == null:
		return
	var payload := EnemyKilledPayload.new()
	payload.enemy_id = &"final_boss"
	payload.enemy_instance_id = 9001
	payload.killer_id = 1
	payload.killing_ability = &"strike_basic"
	payload.transition_id = "slice-kill-1"
	ed.enemy_killed.emit(payload)


# ── Observer handlers ────────────────────────────────────────────────────────
func _on_class(c: int) -> void:
	_recolor_avatar(c)
	_stage_log("   ↳ #10 class → %s (avatar recolored)" % _cname(c))
func _on_completed(_at: int, tid: String) -> void:
	_stage_log("   ↳ #9 workout forwarded")
func _on_evolution(tier: int, _m: Dictionary) -> void:
	_stage_log("   ↳ #26 avatar evolved → tier %d" % tier)
func _on_loot(_id: String, rarity: String, item_type: String, _tid: String) -> void:
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

func _circle(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _wait() -> void:
	await get_tree().create_timer(STEP).timeout

func _stage_log(msg: String) -> void:
	_trace.append(msg)
	if _log_label != null:
		var start: int = max(0, _trace.size() - 16)
		_log_label.text = "\n".join(_trace.slice(start))
	print("[slice] %s" % msg)

func _maybe_quit() -> void:
	if _headless:
		print("[playable_slice] headless self-check complete — quitting 0")
		get_tree().quit(0)
