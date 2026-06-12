## Playable Vertical Slice — Mirror Hero (Production Sprint 1, VS-1).
##
## A RUNNABLE placeholder scene so a human can WATCH the core loop fire with real timing
## (the bridge from the headless harness to a Milestone-1 fun playtest). Press F5/F6 in
## Godot 4.6.3 to run; a mock "push day" workout auto-drives the loop over a few seconds:
##   workout starts → sets logged → workout completes → boss kill → LOOT DROP ceremony,
## with a live on-screen event log + a placeholder avatar + the real Gym-Mode HUD (#20).
##
## Placeholder-art only: the avatar is a PlaceholderTexture2D, the stage is a ColorRect.
## The POINT is feel/timing/watchability, not final art. Replace the placeholder avatar
## with a real sprite (design/assets/entity-inventory.md → avatar T1 STRIKE) when ready.
##
## Drives the loop at the proven FakeGymSysClient seam (same as the headless harness +
## tests/integration/.../test_anti_fabrication_chain.gd). Real autoloads do the rest.
##
## Headless self-check: when run with --headless, prints the event trace and quit(0) after
## the demo so CI / a quick check can confirm it runs without crashing.
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


const STEP := 0.9            ## seconds between scripted workout events (watchable pacing)

var _fake_gym: FakeGymSysClient
var _log_label: Label
var _trace: Array[String] = []
var _headless: bool = false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	await get_tree().process_frame
	await get_tree().process_frame             # autoloads ready
	_build_stage()
	_build_avatar()
	_build_hud()
	_build_event_log()
	_wire_observers()
	_run_demo()


# ── Visuals (placeholder) ────────────────────────────────────────────────────
func _build_stage() -> void:
	var cam := Camera2D.new()
	cam.name = "SliceCamera"
	add_child(cam)
	cam.make_current()
	# Worn-wilderness placeholder ground band (art-bible §6 Quiet Grove stand-in).
	var ground := ColorRect.new()
	ground.color = Color(0.243, 0.357, 0.227)        # world_moss #3E5B3A
	ground.size = Vector2(1280, 220)
	ground.position = Vector2(-640, 120)
	add_child(ground)
	var sky := ColorRect.new()
	sky.color = Color(0.118, 0.137, 0.157)            # ui_ink_bg #1E2328-ish
	sky.size = Vector2(1280, 360)
	sky.position = Vector2(-640, -240)
	sky.z_index = -10
	add_child(sky)


func _build_avatar() -> void:
	var spr := AnimatedSprite2D.new()
	spr.name = "AvatarPlaceholder"
	var frames := SpriteFrames.new()                  # has a "default" animation
	var tex := PlaceholderTexture2D.new()
	tex.size = Vector2(64, 96)                         # egg-down T1 stand-in
	frames.add_frame(&"default", tex)
	spr.sprite_frames = frames
	spr.position = Vector2(0, 120)
	add_child(spr)
	spr.play(&"default")
	# Register with #26 AvatarRenderer (render-only view-registration seam).
	var avatar := _node("AvatarRenderer")
	if avatar != null and avatar.has_method("register_sprite"):
		avatar.register_sprite(spr)
		_stage_log("avatar placeholder registered with AvatarRenderer (#26)")


func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 50                              # ADR-0001 HUD layer
	add_child(hud_layer)
	var hud_scene: PackedScene = load("res://src/ui/gym_mode_hud/GymModeHud.tscn")
	if hud_scene != null:
		var hud: Node = hud_scene.instantiate()
		hud_layer.add_child(hud)
		_stage_log("Gym-Mode HUD (#20) instantiated under CanvasLayer 50")
	else:
		_stage_log("HUD scene missing — skipped")


func _build_event_log() -> void:
	var layer := CanvasLayer.new()
	layer.name = "EventLogLayer"
	layer.layer = 95
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.size = Vector2(560, 360)
	bg.position = Vector2(12, 12)
	layer.add_child(bg)
	_log_label = Label.new()
	_log_label.position = Vector2(24, 24)
	_log_label.add_theme_font_size_override("font_size", 15)
	_log_label.add_theme_color_override("font_color", Color(0.949, 0.663, 0.231))  # ui_amber #F2A93B
	layer.add_child(_log_label)
	_stage_log("▶ VERTICAL SLICE — mock 'push day' workout (placeholder art)")


# ── Observe the real downstream loop ─────────────────────────────────────────
func _wire_observers() -> void:
	_connect("WorkoutStateTracker", "dominant_class_changed", _on_class)
	_connect("WorkoutStateTracker", "workout_completed_forwarded", _on_completed)
	_connect("AvatarRenderer", "avatar_evolution_milestone", _on_evolution)
	_connect("LootDropSystem", "loot_dropped", _on_loot)
	_connect("MirrorMomentCoordinator", "ceremony_presented", _on_ceremony)


# ── Scripted demo ────────────────────────────────────────────────────────────
func _run_demo() -> void:
	var wst := _node("WorkoutStateTracker")
	if wst == null:
		_stage_log("FAIL — WorkoutStateTracker missing")
		_maybe_quit()
		return
	_fake_gym = FakeGymSysClient.new()
	wst.set(&"_gym_sys_client", _fake_gym)
	wst.call("_connect_gym_sys_signals")

	await _wait()
	_stage_log("🏋 workout_started")
	_fake_gym.workout_started.emit()
	await _wait()
	_stage_log("• set: bench_press ×8 @60kg (push → STRIKE)")
	_fake_gym.set_logged.emit(&"bench_press", 8, 60.0)
	await _wait()
	_stage_log("• set: bench_press ×8 @62.5kg")
	_fake_gym.set_logged.emit(&"bench_press", 8, 62.5)
	await _wait()
	_stage_log("• rest 90s → resume")
	_fake_gym.rest_started.emit(90)
	_fake_gym.rest_ended.emit()
	await _wait()
	_stage_log("• set: overhead_press ×6 @40kg")
	_fake_gym.set_logged.emit(&"overhead_press", 6, 40.0)
	await _wait()
	_stage_log("🏁 workout_completed")
	_fake_gym.workout_completed.emit(1749700000)
	await _wait()
	_stage_log("⚔ boss kill (sim) → expect LOOT DROP ceremony")
	_simulate_kill()
	await _wait()
	await _wait()
	_stage_log("✔ loop complete. (Replace placeholder avatar with real sprite for the real feel.)")
	_maybe_quit()


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
	_stage_log("   ↳ #10 dominant class → %s" % _class_name(c))
func _on_completed(_at: int, tid: String) -> void:
	_stage_log("   ↳ #9 workout forwarded (tid=%s)" % tid.left(18))
func _on_evolution(tier: int, _m: Dictionary) -> void:
	_stage_log("   ↳ #26 avatar evolution → tier %d (→ #29 ceremony)" % tier)
func _on_loot(_id: String, rarity: String, item_type: String, _tid: String) -> void:
	_stage_log("   ★ #15 LOOT DROP: %s %s  (Pillar 3 — watch the ceremony!)" % [rarity, item_type])
func _on_ceremony(_content: int, tier: int) -> void:
	_stage_log("   ✦ #29 Mirror Moment ceremony (tier %d)" % tier)


# ── helpers ──────────────────────────────────────────────────────────────────
func _node(n: String) -> Node:
	return get_tree().root.get_node_or_null(n)

func _connect(autoload_name: String, sig: String, cb: Callable) -> void:
	var n := _node(autoload_name)
	if n != null and n.has_signal(sig):
		n.connect(sig, cb)

func _class_name(c: int) -> String:
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
		# keep last ~18 lines visible
		var start: int = max(0, _trace.size() - 18)
		_log_label.text = "\n".join(_trace.slice(start))
	print("[slice] %s" % msg)

func _maybe_quit() -> void:
	if _headless:
		print("[playable_slice] headless self-check complete — scene ran end-to-end, quitting 0")
		get_tree().quit(0)
