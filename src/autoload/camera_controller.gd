# CameraController — Autoload position 13 (#7)
#
# Status: PARTIAL — Story 001 (registration + closed API surface + DI seams) implemented.
#   Input validation: Story 002. Follow math + dead-zone + Pillar 2 lock-on: Story 003.
#   Focal entry quart: Story 004. Focal exit cubic + PAUSABLE: Story 005. Focal gating +
#   re-entry + force-clear: Story 006. Suspend + bfcache: Story 007. Lifecycle signals +
#   viewport + focal-clamp: Story 008. Boot + GSM + CI lint + persistence ban: Story 009.
#   Focal invitation playtest: Story 010. set_motion_reduction: Story 011 (BLOCKED #22).
#
# Driving GDD: design/gdd/camera-system.md (Approved 2026-05-26)
# Governing ADRs: ADR-0001 (Accepted-structural 2026-05-30) + ADR-0006 Contract 6
#
# Forbidden Pattern Gateway: ALL `Camera2D.position/zoom/make_current()` MUST route through
#   here (CI lint: tools/ci/check_camera_callers.gd). `Camera2D.offset` is owned by #6
#   ScreenEffects (shader uniform path) — Camera NEVER writes it (Rule 13 / EC-24 guard).
#
# NOTE: NO `class_name` — registered as the `CameraController` autoload singleton in
#   project.godot. Tests preload via `const SE := preload(...)` to reach enums / new() / consts.
#   Test seam `_update(delta)` is underscore-prefixed so the public API surface stays exactly the
#   5 methods (AC-06a); `_process` delegates to it; tests call `_sut._update(delta)` directly.
extends Node


# ── Lifecycle state (GDD State table) ───────────────────────────────────────────

## ADR-0007 Family A: ordinal 0 = BOOTING safe uninitialised default. Following on camera
## register; Focal on request_focal (Story 004/006); Suspended on GSM SUSPENDED (Story 007).
enum LifecycleState {
	BOOTING   = 0,  ## no Camera2D registered — request_focal silent reject
	FOLLOWING = 1,  ## critically-damped follow of _follow_target
	FOCAL     = 2,  ## boss/loot ritual zoom+recenter tween
	SUSPENDED = 3,  ## GSM suspended — cancel-all + reject
}

var _lifecycle_state: LifecycleState = LifecycleState.BOOTING


# ── Constants (GDD Section G Tuning Knobs / Formulas) ────────────────────────────

const POSITION_SMOOTHING_SPEED: float = 5.0   ## Formula 1 critically-damped decay rate (Story 003)
const LOCK_ON_TOLERANCE_PX: float = 3.0       ## Formula 4 Pillar 2 lock-on tolerance (Story 003)
const MAX_FRAME_DELTA: float = 0.1            ## bfcache resume delta clamp (Story 003/007)
const DRAG_HORIZONTAL_MARGIN: float = 0.04    ## dead-zone 8% total (Story 003)
const DRAG_VERTICAL_MARGIN: float = 0.06      ## dead-zone 12% total (Story 003)

const FOCAL_ENTRY_DURATION: float = 0.6       ## quart ease-out entry (Story 004)
const FOCAL_EXIT_DURATION: float = 0.5        ## cubic ease-in-out exit (Story 005)
const FOCAL_ZOOM_DEFAULT: float = 1.4         ## Focal target zoom (Story 004)
const FOCAL_ZOOM_CAP: float = 4.0             ## EC-05 hard ceiling (Story 002)
const MAX_FOCAL_DURATION: float = 10.0        ## EC-03 ceiling (Story 002)
const DEFAULT_ZOOM: Vector2 = Vector2(1.0, 1.0)  ## Rule 11 single source of truth

## HUD layer behaviour is owned by #6 ScreenEffects (Camera does not own topology).


# ── Signals (GDD Rule 1 / Interaction #5) ───────────────────────────────────────

## Emitted on Focal exit (tween complete or clear_focal) — caller chains follow-ups (Story 005).
signal focal_completed(target_position: Vector2)

## Unified target-loss signal: bfcache stale path (Story 007) / set_follow_target(null) (EC-01) /
## queue_free'd target mid-frame (Story 008 / EC-16).
signal camera_target_lost()

## Focal target clamped by Camera2D.limit_* (Story 008 / EC-23).
signal focal_target_clamped(requested: Vector2, clamped: Vector2)


# ── DI seams (untyped — typed Node fails compile-time member check) ──────────────
## Inject before add_child() in tests.

## The single Camera2D this autoload owns. Injected by the scene via register_camera; tests
## inject a duck-typed stub (position/zoom/offset/limit_*/position_smoothing_enabled/speed).
var _camera = null

## Followed avatar (Node2D-like with global_position). null = frozen (EC-01).
var _follow_target = null

## True while a non-null follow target has been set — the source of truth for target-lost
## detection (a freed Node reference is unreliable to null-check; is_instance_valid + this flag is).
var _has_follow_target: bool = false

## GameStateMachine seam (Story 006/009 — connect_for_initial_state + current_state gate).
var _gsm = null

## Debug-build override for the Camera2D.offset runtime guard (EC-24). null → OS.is_debug_build().
var _debug_build_override = null

## Viewport size override for deterministic dead-zone recompute tests (Story 003/008).
var _viewport_size_override = null

## PersistenceLayer seam (G-CS-2 — #22 story 013 boot self-read;tests inject).
var _persistence = null

## P-08 reduce-camera-motion (story 011 / #22 G-CS-2;#7 GDD AC-27/AC-06b)。
## ON ⇒ request_focal silent no-op(預期 opt-out,NOT push_warning)+ Following
## dead-zone 0% hard-lock + smoothing off(zero optical flow / stroboscopic edge)。
var _motion_reduction: bool = false
## Observability counter(silent no-op 嘅可測面)。
var _focal_motion_reduction_suppressed: int = 0

## Cached follow-target NodePath saved on Suspend, resolved on resume (Story 007).
var _cached_target_path: NodePath = NodePath("")


# ── Telemetry counters (test-readable) ──────────────────────────────────────────

var _rejected_calls: int = 0                ## NaN/INF/invalid-input rejections (Story 002)
var _focal_reentry_dropped_count: int = 0   ## Rule 5 strict re-entry drops (Story 006)
var _focal_gating_rejected_count: int = 0   ## Rule 4 GSM-state gating rejects (Story 006)
var _offset_violation_count: int = 0        ## EC-24 Camera2D.offset guard hits (Story 009)

## Resolved (clamped) focal params from the most recent request_focal (Story 002 — test seam).
var _resolved_focal_duration: float = 0.0
var _resolved_focal_zoom: float = 0.0

## Active focal tweens (Story 004 entry / Story 005 exit). Bound to the Camera2D.
var _active_tween: Tween = null
var _exit_tween: Tween = null


# ── Boot ────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# GSM subscription (ADR-0006 Contract 6): connect_for_initial_state, NO .bind. The scene
	# registers a Camera2D afterwards (register_camera) to exit Booting → Following.
	if _gsm == null:
		_gsm = GameStateMachine
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)
	# G-CS-2 / story 011 (#22 P-08): consumer self-read boot apply —
	# settings.reduce_camera_motion(#22 Rule 29 convention;canonical key pin
	# G-CS-3 — 「SettingsManager autoload」L697 措辭已 erratum)。
	_boot_read_motion_reduction()


## G-CS-2 boot self-read — 缺 key = documented default false;corrupt 型 skip。
func _boot_read_motion_reduction() -> void:
	if _persistence == null:
		_persistence = get_node_or_null("/root/PersistenceLayer")
	if _persistence == null or not _persistence.has_method("read"):
		return
	var v = _persistence.read("settings.reduce_camera_motion")
	if v is bool:
		set_motion_reduction(v)


## Engine per-frame hook delegates to the underscore-prefixed seam so the public API surface
## stays exactly the 5 methods (AC-06a). Tests drive frames via _sut._update(delta) directly.
func _process(delta: float) -> void:
	_update(delta)


# ── Public API (GDD Rule 1 — closed surface, exactly 5 methods) ─────────────────

## Scene bootstrap: inject the Camera2D node (once per scene). null / freed → reject (EC-19);
## double-register → reject + preserve first (EC-20). On first valid register → Booting→Following.
func register_camera(cam) -> void:
	if cam == null or not is_instance_valid(cam):
		push_error("CameraController.register_camera: invalid Camera2D instance")
		return
	if _camera != null:
		push_error("CameraController.register_camera: already registered; first=%s second=%s" % [_camera, cam])
		return
	_camera = cam
	_try_enter_following()


## Scene tear-down: unbind the Camera2D (kills tweens in Story 005/006, clears _camera).
func unregister_camera() -> void:
	_camera = null
	_lifecycle_state = LifecycleState.BOOTING


## Set the Following pursuit target. null is accepted (freeze + camera_target_lost — EC-01,
## wired in Story 008). On valid target with a registered camera → enter Following.
func set_follow_target(node) -> void:
	if node == null:
		# EC-01 — explicit null: freeze + emit camera_target_lost if a target was previously set.
		var had: bool = _has_follow_target
		_follow_target = null
		_has_follow_target = false
		if had:
			camera_target_lost.emit()
		return
	_follow_target = node
	_has_follow_target = true
	_try_enter_following()


## Request a Focal ritual push-in. Validation (Story 002), GSM-state gating + re-entry guard
## (Story 006), and the tween (Story 004/005) are layered on; Story 001 provides the surface.
func request_focal(target_position: Vector2, duration: float = FOCAL_ENTRY_DURATION, zoom_level: float = FOCAL_ZOOM_DEFAULT) -> void:
	# AC-27 (story 011 / #22 P-08): motion reduction ON → silent no-op。
	# NOT push_warning — 呢個係預期 user opt-out,唔係 caller bug。
	if _motion_reduction:
		_focal_motion_reduction_suppressed += 1
		return
	# Rule 4 / EC-02 — finite check first (NaN/INF poisons the tween matrix; fail-loud).
	if not _is_finite_vec2(target_position) or not is_finite(duration) or not is_finite(zoom_level):
		push_error("CameraController.request_focal: NaN/INF rejected")
		_rejected_calls += 1
		return
	# EC-04 — zoom ≤ 0 is a projection-matrix div-by-zero / inverted viewport. Reject (not clamp).
	if zoom_level <= 0.0:
		push_error("CameraController.request_focal: zoom_level must be > 0")
		_rejected_calls += 1
		return
	# EC-03 / EC-05 — over-limit duration/zoom are valid-but-clamped (warn, NOT a rejection).
	var resolved_duration: float = clampf(duration, 0.1, MAX_FOCAL_DURATION)
	if duration > MAX_FOCAL_DURATION or duration < 0.1:
		push_warning("CameraController.request_focal: duration %f clamped to %f" % [duration, resolved_duration])
	var resolved_zoom: float = minf(zoom_level, FOCAL_ZOOM_CAP)
	if zoom_level > FOCAL_ZOOM_CAP:
		push_warning("CameraController.request_focal: zoom %f clamped to %f" % [zoom_level, FOCAL_ZOOM_CAP])
	_resolved_focal_duration = resolved_duration
	_resolved_focal_zoom = resolved_zoom
	# Rule 4 — HARD gate to {BOSS_ENCOUNTER, LOOT_DROP} (Pillar 2 mid-set frictionless contract).
	# Only gated when a GSM is wired (production always wires it; focal-mechanic tests may omit it).
	if _gsm != null and not _is_focal_allowed_state(_gsm_state()):
		push_warning("CameraController.request_focal rejected: GSM state=%d (mid-set frictionless contract)" % _gsm_state())
		_focal_gating_rejected_count += 1
		return
	# Rule 5 — strict re-entry reject (depth 0). Caller chains via focal_completed.
	if _lifecycle_state == LifecycleState.FOCAL:
		push_warning("CameraController.request_focal rejected: active Focal in progress (strict reject)")
		_focal_reentry_dropped_count += 1
		return
	_enter_focal(target_position, resolved_duration, resolved_zoom)


## True if a GSM state permits Focal (Rule 4 whitelist).
func _is_focal_allowed_state(state) -> bool:
	var s: int = int(state)
	return s == GameStateMachine.GameState.BOSS_ENCOUNTER or s == GameStateMachine.GameState.LOOT_DROP


## Read the GSM's current state robustly: the real GameStateMachine exposes get_current_state();
## test mocks expose a `current_state` property. Returns -1 if neither is available.
func _gsm_state() -> int:
	if _gsm == null:
		return -1
	if _gsm.has_method("get_current_state"):
		return int(_gsm.get_current_state())
	var cs = _gsm.get("current_state")
	return int(cs) if cs != null else -1


## Explicit Focal early-exit (auto-fires on tween complete — Story 005).
func clear_focal() -> void:
	if _lifecycle_state != LifecycleState.FOCAL:
		return
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	var current_pos: Vector2 = _camera.position if _camera != null else Vector2.ZERO
	_on_focal_complete(current_pos)


# ── Internal ────────────────────────────────────────────────────────────────────

## GSM state-change handler (ADR-0006 Contract 6; wired in Story 009). Story 006: force-clear
## Focal when GSM leaves the focal-allowed states. Story 007 adds Suspended cancel + resume.
func _on_gsm_state_changed(_from: Variant, to: Variant, _payload: Variant = null) -> void:
	if int(to) == GameStateMachine.GameState.SUSPENDED:
		_enter_suspended()
		return
	if _lifecycle_state == LifecycleState.SUSPENDED:
		_restore_from_suspend()
		return
	# EC-07 — GSM leaves {BOSS_ENCOUNTER, LOOT_DROP} mid-Focal → force-clear (snap, skip exit tween).
	if _lifecycle_state == LifecycleState.FOCAL and not _is_focal_allowed_state(to):
		_force_clear_focal_sync()


## Synchronous Focal teardown (EC-07): kill tweens, snap zoom to default, re-enable smoothing,
## return to Following — NO exit tween (the GSM change is itself dramatic enough).
## G-CS-2 / story 011 公開 setter(#22 P-08 toggle 嘅 consumer 面;AC-06b 第 6
## 個 closed-API method)。ON:request_focal silent no-op + Following smoothing
## off + dead-zone 0%(hard-lock);即場生效(包括 flip 時 FOCAL 進行中 —
## 同步清 focal,returning 行為跟 motion policy)。OFF:恢復 smoothing。
func set_motion_reduction(enabled: bool) -> void:
	_motion_reduction = enabled
	if enabled and _lifecycle_state == LifecycleState.FOCAL:
		_force_clear_focal_sync()  # opt-out 即場退出 focal(零 push)
	if _camera != null:
		_camera.position_smoothing_enabled = _follow_smoothing_enabled()


## Smoothing policy — motion reduction ON ⇒ 永遠 false(hard-lock)。
func _follow_smoothing_enabled() -> bool:
	return not _motion_reduction


func _force_clear_focal_sync() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if _exit_tween != null and _exit_tween.is_valid():
		_exit_tween.kill()
	if _camera != null:
		_camera.zoom = DEFAULT_ZOOM
		_camera.position_smoothing_enabled = _follow_smoothing_enabled()
	_lifecycle_state = LifecycleState.FOLLOWING


## Suspended override (GDD Rule 8 — Story 007): kill tweens (camera stays at current interpolated
## position), reset zoom to default, re-enable smoothing, cache the follow-target NodePath.
func _enter_suspended() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if _exit_tween != null and _exit_tween.is_valid():
		_exit_tween.kill()
	if _camera != null:
		_camera.zoom = DEFAULT_ZOOM  # position untouched → snaps to current interpolated value
		_camera.position_smoothing_enabled = _follow_smoothing_enabled()
		if _camera.has_method("reset_smoothing"):
			_camera.reset_smoothing()
	_cached_target_path = _follow_target.get_path() if is_instance_valid(_follow_target) else NodePath("")
	_lifecycle_state = LifecycleState.SUSPENDED


## bfcache resume restore (GDD Rule 9 — Story 007): re-resolve the cached target NodePath. Stale
## (freed) → Booting + camera_target_lost so the scene re-registers.
func _restore_from_suspend() -> void:
	var resolved = get_node_or_null(_cached_target_path) if not _cached_target_path.is_empty() else null
	if resolved != null:
		_follow_target = resolved
		_has_follow_target = true
		if _camera != null:
			_camera.global_position = resolved.global_position  # snap before re-smoothing (no teleport)
			if _camera.has_method("reset_smoothing"):
				_camera.reset_smoothing()
		_lifecycle_state = LifecycleState.FOLLOWING
	else:
		_follow_target = null
		_has_follow_target = false
		_lifecycle_state = LifecycleState.BOOTING
		camera_target_lost.emit()


## Enter Following once a Camera2D is registered (GDD State table — Booting exits on register).
## Story 009 will additionally require the GSM subscription to have resolved.
func _try_enter_following() -> void:
	if _camera != null and _lifecycle_state == LifecycleState.BOOTING:
		_lifecycle_state = LifecycleState.FOLLOWING


## Per-frame follow smoothing (GDD Formula 1 + Rule 3 dead-zone). Story 007 adds Suspended
## early-return; Story 008 adds target-lost detection. delta clamped (bfcache safety).
func _update(delta: float) -> void:
	delta = minf(delta, MAX_FRAME_DELTA)
	_check_offset_guard()  # EC-24 — Camera2D.offset must stay zero (owned by #6 ScreenEffects)
	if _lifecycle_state == LifecycleState.SUSPENDED:
		return  # frozen — Suspended overrides all (Rule 8)
	# Target-lost detection (EC-16): a previously-set target that became invalid (queue_free'd) →
	# emit once (flag-debounced), then freeze. is_instance_valid + flag is reliable for freed refs.
	if _has_follow_target and not is_instance_valid(_follow_target):
		_follow_target = null
		_has_follow_target = false
		camera_target_lost.emit()
		return
	if _lifecycle_state != LifecycleState.FOLLOWING:
		return
	if _camera == null or _follow_target == null:
		return
	var target: Vector2 = _follow_target.global_position
	var cam_pos: Vector2 = _camera.position
	var dz: Vector2 = _dead_zone_half_extents()
	# Formula 1 critically-damped exponential decay (frame-rate-independent). Per-axis dead-zone
	# gate: only smooth an axis whose target offset exceeds the dead-zone half-extent (Rule 3).
	var factor: float = 1.0 - exp(-POSITION_SMOOTHING_SPEED * delta)
	var new_pos: Vector2 = cam_pos
	if absf(target.x - cam_pos.x) > dz.x:
		new_pos.x = cam_pos.x + (target.x - cam_pos.x) * factor
	if absf(target.y - cam_pos.y) > dz.y:
		new_pos.y = cam_pos.y + (target.y - cam_pos.y) * factor
	_camera.position = new_pos


## Dead-zone half-extents in world units (GDD Formula 5). One side = viewport × margin / zoom.
func _dead_zone_half_extents() -> Vector2:
	# AC-27 (story 011 / #22 P-08): dead-zone 0% hard-lock — camera 永遠正中
	# avatar,zero movement(殺 optical flow + stroboscopic edge-crossing)。
	if _motion_reduction:
		return Vector2.ZERO
	var vp: Vector2 = _viewport_size_override if _viewport_size_override != null else Vector2(get_viewport().get_visible_rect().size)
	var zoom: Vector2 = _camera.zoom if _camera != null else Vector2.ONE
	return Vector2(vp.x * DRAG_HORIZONTAL_MARGIN / zoom.x, vp.y * DRAG_VERTICAL_MARGIN / zoom.y)


# ── Focal tweens (GDD Rule 6/7 / Formula 2/3) ───────────────────────────────────

## Enter Focal: quart ease-out entry tween (GDD Rule 6). Disables follow smoothing; tween is
## PAUSABLE (Rule 12 — freezes with #6 hit_pause). Chains to _on_focal_complete on entry done.
func _enter_focal(target_position: Vector2, duration: float, zoom_level: float) -> void:
	_lifecycle_state = LifecycleState.FOCAL
	if _camera == null:
		return
	# EC-23 — clamp the focal target to Camera2D world bounds; emit focal_target_clamped if clamped.
	var clamped_target: Vector2 = _clamp_to_limits(target_position)
	if clamped_target != target_position:
		focal_target_clamped.emit(target_position, clamped_target)
	target_position = clamped_target
	_camera.position_smoothing_enabled = false
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	# Tween bound to the Camera2D inherits its process mode → freezes with get_tree().paused
	# (the Camera2D is PROCESS_MODE_INHERIT/PAUSABLE — Rule 12 DNF hit_pause freeze consistency).
	_active_tween = _camera.create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_camera, "position", target_position, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_active_tween.tween_property(_camera, "zoom", Vector2(zoom_level, zoom_level), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_active_tween.chain().tween_callback(_on_focal_complete.bind(target_position))


## Focal entry complete → emit focal_completed + start the cubic ease-in-out exit tween (GDD
## Rule 7). Exit returns to the follow target + DEFAULT_ZOOM, then re-enables follow smoothing.
func _on_focal_complete(target_position: Vector2) -> void:
	focal_completed.emit(target_position)
	if _camera == null:
		_lifecycle_state = LifecycleState.FOLLOWING
		return
	_exit_tween = _camera.create_tween()
	_exit_tween.set_parallel(true)
	var return_pos: Vector2 = _follow_target.global_position if is_instance_valid(_follow_target) else target_position
	_exit_tween.tween_property(_camera, "position", return_pos, FOCAL_EXIT_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_exit_tween.tween_property(_camera, "zoom", DEFAULT_ZOOM, FOCAL_EXIT_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_exit_tween.chain().tween_callback(_on_focal_exit_complete)


func _on_focal_exit_complete() -> void:
	_lifecycle_state = LifecycleState.FOLLOWING
	if _camera != null:
		_camera.position_smoothing_enabled = _follow_smoothing_enabled()


## Quart ease-out (GDD Formula 2 — decisive-invitation front-load). Pure static (underscore =
## off the public API surface, AC-06a). value(0.3) covers ≥75% of distance (AC-D2).
static func _quart_ease_out_value(t: float, start: float, end: float) -> float:
	return start + (end - start) * (1.0 - pow(1.0 - t, 4.0))


## Cubic ease-in-out (GDD Formula 3 — symmetric breath-out). Pure static. f(0.5) == 0.5 exact.
static func _cubic_ease_in_out_value(t: float, start: float, end: float) -> float:
	var f: float = (4.0 * t * t * t) if t < 0.5 else (1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0)
	return start + (end - start) * f


## Pillar 2 lock-on time (GDD Formula 4): ln(d_initial / d_tolerance) / smoothing_speed.
## Pure static — numerical proof of the < 500ms glance-back contract (AC-09 / AC-30).
## Underscore-prefixed so it stays off the closed public API surface (AC-06a).
static func _glance_lock_on_time(d_initial: float, d_tolerance: float, smoothing_speed: float) -> float:
	return log(d_initial / d_tolerance) / smoothing_speed


# ── Helpers ─────────────────────────────────────────────────────────────────────

func _is_finite_vec2(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)


## EC-24 runtime guard (debug build only): Camera2D.offset is owned by #6 ScreenEffects (shader
## uniform path) — Camera must NEVER write it. Detect a slipped mutation (e.g. an AnimationPlayer)
## and fail-loud. NOT assert() (crashes GUT). _camera.get() → null if the stub has no offset.
func _check_offset_guard() -> void:
	if _camera == null:
		return
	var dbg: bool = _debug_build_override if _debug_build_override != null else OS.is_debug_build()
	if not dbg:
		return
	var off = _camera.get("offset")
	if off != null and off != Vector2.ZERO:
		push_error("Camera.offset must be zero — owned by #6 ScreenEffects shader uniform")
		_offset_violation_count += 1


## Clamp a world position to the Camera2D limit_* bounds (Rule 10 / EC-23). Returns the input
## unchanged if the camera exposes no limits (test stub without them). Object.get → null if absent.
func _clamp_to_limits(pos: Vector2) -> Vector2:
	if _camera == null:
		return pos
	var ll = _camera.get("limit_left")
	var lr = _camera.get("limit_right")
	var lt = _camera.get("limit_top")
	var lb = _camera.get("limit_bottom")
	if ll == null or lr == null or lt == null or lb == null:
		return pos
	return Vector2(clampf(pos.x, float(ll), float(lr)), clampf(pos.y, float(lt), float(lb)))
