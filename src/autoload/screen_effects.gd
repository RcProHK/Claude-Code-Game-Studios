# ScreenEffects — Autoload position 14 (#6)
#
# Status: PARTIAL — Story 001 (API surface + input validation + _apply_shake funnel)
#   implemented. Trauma² decay + noise + epsilon: Story 002. Combiner + motion composition
#   + hierarchy: Story 003. Hit pause max-remaining + ceiling: Story 004. Selective freeze
#   + hit_pause_started signal: Story 005. burst_started dispatch table: Story 006. Re-entry
#   guard + Suspended + bfcache: Story 007. Boot + GSM subscription + CI lint + persistence
#   ban: Story 008. SettingsManager propagation: Story 009. HUD toggle: Story 010.
#
# Driving GDD: design/gdd/screen-effects-system.md (Approved 2026-05-26)
# Governing ADRs: ADR-0001 (Accepted-structural 2026-05-30) + ADR-0006 Contract 6
#
# Forbidden Pattern Gateway: ALL screen shake MUST route through here via the shader uniform
#   `u_shake_offset` (NOT `Camera2D.offset`); hit pause uses `get_tree().paused` (NOT
#   `Engine.time_scale`). CI lint: tools/ci/check_screen_effects_callers.gd (Story 008).
#
# NOTE: NO `class_name` — registered as the `ScreenEffects` autoload singleton in
#   project.godot (a matching class_name would error "hides an autoload singleton").
#   Tests preload this script via `const SE := preload(...)` to reach enums / new() / consts.
extends Node


# ── Lifecycle state (minimal — Story 007 owns GSM subscription + full transitions) ──

## ADR-0007 Family A (Outcome/State): ordinal 0 = BOOTING safe uninitialised default.
## Story 001 boots straight to ACTIVE; Story 005 adds HitPaused, Story 007 adds Suspended
## transitions + the Booting/Suspended API-reject gate.
enum LifecycleState {
	BOOTING    = 0,  ## pre-_ready — API rejected (Story 007)
	ACTIVE     = 1,  ## normal service
	HIT_PAUSED = 2,  ## selective freeze in progress (Story 005)
	SUSPENDED  = 3,  ## GSM Suspended — cancel-all + reject (Story 007)
}

var _lifecycle_state: LifecycleState = LifecycleState.BOOTING


# ── Constants (GDD Section G Tuning Knobs / Formulas) ────────────────────────────

## shake() argument clamp bounds (GDD Rule 1).
const SHAKE_INTENSITY_MIN: float = 0.0
const SHAKE_INTENSITY_MAX: float = 1.0
const SHAKE_DURATION_MAX: float = 0.5

## Max shake amplitude at trauma=1.0 (Formula 1, peripheral receivability band).
const MAX_OFFSET_PX: float = 4.0

## Decay floor — trauma below this skips Formula 1 (zero idle cost). Story 002.
const TRAUMA_EPSILON: float = 0.01

## Denominator floor preventing division-by-zero in decay_rate (Formula 2). Story 003.
const MIN_SHAKE_DURATION: float = 0.01

## Hit-pause safety ceiling (GDD Rule 2 — user-detectable freeze threshold). Story 004.
const MAX_PAUSE_SEC: float = 0.12

## Re-entry guard depth — 0 = strict reject of any nesting (GDD Rule 12). Story 007.
const MAX_EMIT_DEPTH: int = 0

## bfcache resume delta clamp (GDD Rule 13 / EC-12). Story 007.
const MAX_FRAME_DELTA: float = 0.1

## Dropped/rejected warning throttle (GDD Section G).
const WARNING_THROTTLE_MS: int = 1000

## Shader uniform name for the shake offset (GDD Rule 4). Story 002 writes it.
const SHAKE_UNIFORM: StringName = &"u_shake_offset"

## HUD layer behaviour knob (GDD Rule 14 / Story 010). true (default) = HUDLayer sits BELOW
## ScreenEffectsLayer → HUD shakes with the world (DNF unified feel); false = HUDLayer above →
## HUD immune (readability). ScreenEffects does NOT own the CanvasLayer topology — the master
## scene (ADR-0001 input scope) reads this knob to assign layer ordering. Compile-time in v1
## (no runtime swap — Q-F5). Exposed here for traceability + a single source of truth.
const HUD_SHAKES_WITH_WORLD: bool = true


# ── Signals ─────────────────────────────────────────────────────────────────────

## Emitted on HitPaused entry (Story 005) for #4 AudioManager ducking (AudioServer does
## not observe SceneTree.paused). Payload clamped ≤ MAX_PAUSE_SEC × 1000 (Rule 2).
signal hit_pause_started(duration_ms: int)


# ── DI seams (untyped — typed Node fails compile-time member check) ──────────────
## Inject before add_child() in tests.

## Shader uniform write sink (GDD Rule 4). Default routes to RenderingServer; tests inject
## a recording spy Callable. NOT a native-method override (GUT phantom-pass guard) — the
## wrapper owns this seam so a stub can capture (name, value) without patching RenderingServer.
var _shader_sink: Callable = Callable()

## GameStateMachine seam (Story 007 — connect_for_initial_state). Default = GSM autoload.
var _gsm = null

## SettingsManager seam (Story 009 — set_motion_intensity propagation). Default = autoload.
var _settings = null

## Warning sink (default push_warning). Tests inject to assert warnings deterministically.
var _warn_sink: Callable = Callable()


# ── State ───────────────────────────────────────────────────────────────────────

## Accumulated shake trauma ∈ [0, 1] (decays each frame — Story 002).
var _trauma: float = 0.0

## Decay rate set by the most recent shake (Story 003 Formula 2).
var _decay_rate: float = 0.0

## Remaining hit-pause seconds (Story 004 Formula 3).
var _pause_remaining_sec: float = 0.0

## Player accessibility multiplier ∈ [0, 1] (Rule 3). Default 1.0 (EC-15).
var _motion_intensity: float = 1.0

## Re-entry depth counter (Rule 12 — Story 007).
var _emit_depth: int = 0

## One-shot uniform-clear latch (Story 002 — Rule 4).
var _trauma_just_zeroed: bool = false

## Deterministic noise seed accumulator (Story 002 — `_shake_time += delta`, never wall-clock).
var _shake_time: float = 0.0

## Last per-frame delta after MAX_FRAME_DELTA clamp (Story 007 — bfcache observable for AC-18).
var _last_clamped_delta: float = 0.0

# ── Telemetry counters (test-readable) ──────────────────────────────────────────

var _rejected_calls: int = 0          ## malformed-input rejections (EC-01..04)
var _dropped_by_depth_guard: int = 0  ## re-entry drops (Rule 12 — Story 007)
var _dispatch_missed_count: int = 0   ## burst_started with an unmapped PresetId (EC-14)


# ── burst_started dispatch table (GDD Rule 9 — Story 006) ───────────────────────
## preset_id → { "shake": Vector2(intensity, duration), "pause": float }. Built at _ready
## because PresetId lives on the ParticleSystemWrapper autoload (no class_name → not a
## compile-time const). 4 active + 5 explicit no-op entries (distinguish known-no-op from
## unknown). CI drift check (_DISPATCH keys ⊆ PresetId) is Story 008.
var _dispatch: Dictionary = {}


# ── Boot ────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if not _shader_sink.is_valid():
		_shader_sink = _default_shader_sink
	# Selective freeze (Rule 10): this autoload must keep ticking while get_tree().paused
	# so the hit-pause timer drains + GymSys/GSM autoloads are not desynced.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_dispatch()
	# Auto-react to particle bursts (Rule 9). Direct .connect() — ParticleSystemWrapper (pos 12)
	# boots before ScreenEffects (pos 14), so the signal exists (Q-V6 RECOMMENDED).
	if ParticleSystemWrapper != null and ParticleSystemWrapper.has_signal("burst_started"):
		if not ParticleSystemWrapper.burst_started.is_connected(_on_burst_started):
			ParticleSystemWrapper.burst_started.connect(_on_burst_started)
	# GSM subscription (ADR-0006 Contract 6): connect_for_initial_state, NO .bind. The
	# initial-state sentinel may immediately move us to Suspended (Rule 13).
	if _gsm == null:
		_gsm = GameStateMachine
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)
	# Boot done → Active (GDD state table). Story 007 Suspended override can flip this.
	if _lifecycle_state == LifecycleState.BOOTING:
		_lifecycle_state = LifecycleState.ACTIVE


## Build the burst_started → effect dispatch table (Rule 9). Keyed by the live
## ParticleSystemWrapper.PresetId enum. 4 active presets + 5 explicit no-op entries.
func _build_dispatch() -> void:
	var pid = ParticleSystemWrapper.PresetId
	_dispatch = {
		pid.HIT_HEAVY:       {"shake": Vector2(0.4, 0.12), "pause": 0.0},
		pid.PARRY:           {"shake": Vector2(0.6, 0.08), "pause": 0.06},
		pid.DEATH:           {"shake": Vector2(0.3, 0.18), "pause": 0.0},
		pid.LOOT_RARE_BURST: {"shake": Vector2(0.2, 0.15), "pause": 0.0},
		# Explicit no-op presets (sensation noise floor) — present so they read as
		# known-no-op, NOT as an unknown miss (EC-14 / AC-15).
		pid.HIT_LIGHT:     {},
		pid.LOOT_BURST:    {},
		pid.STATUS_BURN:   {},
		pid.STATUS_FREEZE: {},
		pid.STATUS_STUN:   {},
	}


## Default shader-uniform writer (the one permitted RenderingServer call site for shake).
func _default_shader_sink(uniform: StringName, value: Variant) -> void:
	RenderingServer.global_shader_parameter_set(uniform, value)


# ── Per-frame shake decay (GDD Rule 4 / Formula 1) ──────────────────────────────

## Trauma² decay (Yoshi/Vlachos). Story 007 adds: delta clamp, Suspended/HitPaused early-
## return, motion_intensity==0 short-circuit. Story 001/002 assume Active service.
func _process(delta: float) -> void:
	# bfcache resume large-delta clamp (Rule 13 / EC-12) — observable for AC-18.
	delta = minf(delta, MAX_FRAME_DELTA)
	_last_clamped_delta = delta
	if _lifecycle_state == LifecycleState.SUSPENDED:
		return  # frozen — Suspended overrides all (Rule 13)
	# HitPaused (Rule 4): shake amplitude is frozen at entry value — only drain the pause timer.
	if _lifecycle_state == LifecycleState.HIT_PAUSED:
		_pause_remaining_sec -= delta
		if _pause_remaining_sec <= 0.0:
			_exit_hit_paused()
		return
	# Skip Formula 1 only when STRICTLY below epsilon (GDD prose + AC-09: boundary is `<`,
	# so trauma == epsilon still evaluates).
	if _trauma >= TRAUMA_EPSILON:
		_shake_time += delta  # deterministic noise seed (never wall-clock — replay/test safe)
		_trauma = maxf(0.0, _trauma - _decay_rate * delta)
		var offset: Vector2 = pow(_trauma, 2.0) * MAX_OFFSET_PX * _noise_sample(_shake_time)
		_shader_sink.call(SHAKE_UNIFORM, offset)
		_trauma_just_zeroed = true  # armed — one-shot clear fires when trauma drops below epsilon
	elif _trauma_just_zeroed:
		# One-shot clear: trauma just fell below epsilon — write ZERO once, then disarm.
		_shader_sink.call(SHAKE_UNIFORM, Vector2.ZERO)
		_trauma_just_zeroed = false


## Exit HitPaused → Active (Rule 10): release the freeze. Does NOT re-emit hit_pause_started
## (signal fires on entry only). Story 007 Suspended override force-releases independently.
func _exit_hit_paused() -> void:
	_pause_remaining_sec = 0.0
	if get_tree().paused:
		get_tree().paused = false
	_lifecycle_state = LifecycleState.ACTIVE


## Cheap deterministic 2D hash (GDD Formula 4) — NOT Perlin (mobile WebGL2 dependent-texture
## read is expensive; peripheral 12-frame shake can't perceive smoothness). 137/211 co-prime
## multipliers decorrelate the axes. Deterministic in `t` → replay-safe + test-reproducible.
func _noise_sample(t: float) -> Vector2:
	return Vector2(sin(t * 137.0), sin(t * 211.0))


# ── Public API (GDD Rules 1-3) ──────────────────────────────────────────────────

## Primary shake primitive (GDD Rule 1). intensity ∈ [0, 1], duration ∈ [0, 0.5s] clamped.
## NaN / ±INF rejected (fail-loud, Foundation never throws — Pillar 2). Funnels through
## _apply_shake (Rule 11 single point of truth). No return value (closed library).
func shake(intensity: float, duration: float) -> void:
	if not _is_serviceable():
		return  # Booting / Suspended → silent reject (EC-07, NOT counted)
	# Rule 1 — finite check BEFORE clamp (INF silent-clamp would mask caller bugs, EC-02).
	if not is_finite(intensity) or not is_finite(duration):
		_rejected_calls += 1
		_warn("ScreenEffects.shake: non-finite argument rejected (intensity=%s duration=%s)" % [intensity, duration])
		return
	var clamped_intensity: float = clampf(intensity, SHAKE_INTENSITY_MIN, SHAKE_INTENSITY_MAX)
	var clamped_duration: float = clampf(duration, 0.0, SHAKE_DURATION_MAX)
	if duration > SHAKE_DURATION_MAX:
		_warn("ScreenEffects.shake: duration %f clamped to %f" % [duration, SHAKE_DURATION_MAX])
	_apply_shake(clamped_intensity, clamped_duration)


## Hit-pause primitive (GDD Rule 2). duration ∈ (0, 0.12s]. Non-positive / NaN / INF rejected
## (EC-03). Over-ceiling is valid-but-clamped (Story 004) — NOT a rejection. No return value.
func hit_pause(duration: float) -> void:
	if not _is_serviceable():
		return  # Booting / Suspended → silent reject (EC-07, NOT counted)
	if not is_finite(duration) or duration <= 0.0:
		_rejected_calls += 1
		_warn("ScreenEffects.hit_pause: non-positive / non-finite duration rejected (%s)" % duration)
		return
	# Over-ceiling is valid-but-clamped (Rule 2 / AC-D3) — warn, but NOT a rejection.
	if duration > MAX_PAUSE_SEC:
		_warn("ScreenEffects.hit_pause: duration %f exceeds MAX_PAUSE_SEC, clamped to %f" % [duration, MAX_PAUSE_SEC])
	var requested: float = minf(duration, MAX_PAUSE_SEC)
	# Formula 3 — max-remaining: overlapping pauses do NOT stack/extend; strongest wins.
	_pause_remaining_sec = minf(MAX_PAUSE_SEC, maxf(_pause_remaining_sec, requested))
	# Selective freeze entry (Rule 10): pause the gameplay tree (autoloads are PROCESS_MODE_ALWAYS
	# so keep ticking). Emit hit_pause_started ONLY on a fresh entry (not on a re-entry that just
	# extends an already-active pause), synchronously with paused=true (no call_deferred).
	var entering: bool = _lifecycle_state != LifecycleState.HIT_PAUSED
	_lifecycle_state = LifecycleState.HIT_PAUSED
	get_tree().paused = true
	if entering:
		hit_pause_started.emit(int(round(_pause_remaining_sec * 1000.0)))


## Accessibility multiplier setter (GDD Rule 3). In-range overshoot silently clamps (EC-05);
## NaN rejected + previous value retained (EC-04). Does NOT cancel an active shake (Rule 3).
func set_motion_intensity(scale: float) -> void:
	if not _is_serviceable():
		return  # Booting / Suspended → silent reject (EC-07/AC-19; SettingsManager boot call is post-Active)
	if not is_finite(scale):
		_rejected_calls += 1
		_warn("ScreenEffects.set_motion_intensity: non-finite value rejected (%s)" % scale)
		return
	_motion_intensity = clampf(scale, 0.0, 1.0)  # in-range overshoot = silent clamp (EC-05, no log)


# ── Internal funnel (GDD Rule 11) ───────────────────────────────────────────────

## Single mutation path for both the public shake() and the dispatch table (Story 006).
## Re-entry guard (Rule 12) + motion composition (Rule 7) + Formula 2 combiner (Rule 5):
## additive saturate `min(1.0, …)` + monotonic non-decreasing decay_rate. motion_intensity==0
## fully short-circuits shake (Reduce Motion honest endpoint) while leaving hit_pause untouched.
func _apply_shake(intensity: float, duration: float) -> void:
	if _emit_depth > MAX_EMIT_DEPTH:
		_dropped_by_depth_guard += 1
		_warn("ScreenEffects: re-entry depth=%d — dropped" % _emit_depth)
		return
	_emit_depth += 1
	if _motion_intensity == 0.0:
		# Reduce Motion full off (Rule 7 / Section B Test #2): zero accrual + latch-clear the
		# uniform so no residual offset lingers. hit_pause is NOT gated by motion (separate path).
		_shader_sink.call(SHAKE_UNIFORM, Vector2.ZERO)
		_trauma_just_zeroed = false
		_emit_depth -= 1
		return
	var effective: float = intensity * _motion_intensity  # Rule 7 input-side composition
	_trauma = minf(1.0, _trauma + effective)              # Rule 5 additive saturate
	_decay_rate = maxf(_decay_rate, 1.0 / maxf(MIN_SHAKE_DURATION, duration))  # monotonic non-decreasing
	_emit_depth -= 1


# ── burst_started auto-dispatch (GDD Rule 9 / Interaction #1) ───────────────────

## Auto-react to a particle burst per the dispatch table. Active preset → shake (+ optional
## hit_pause); known no-op preset → silent skip; unmapped preset → telemetry counter (EC-14).
## `position` reserved for future positional shake. O(1) lookup, await-free (AC-23).
func _on_burst_started(preset_id: int, position: Vector2) -> void:
	if not _is_serviceable():
		return  # Booting / Suspended → ignore particle dispatch
	var _pos_reserved: Vector2 = position  # reserved for future positional shake
	if not _dispatch.has(preset_id):
		_dispatch_missed_count += 1  # unmapped PresetId (EC-14) — telemetry only, no warning
		return
	var entry: Dictionary = _dispatch[preset_id]
	if entry.is_empty():
		return  # known no-op preset (sensation noise floor) — not a miss
	var sh: Vector2 = entry["shake"]
	_apply_shake(sh.x, sh.y)
	var pause: float = entry.get("pause", 0.0)
	if pause > 0.0:
		hit_pause(pause)


# ── GSM lifecycle + bfcache (GDD Rule 13 — Story 007) ───────────────────────────

## Serviceable = accepts shake/hit_pause/dispatch. Booting + Suspended reject (EC-07).
func _is_serviceable() -> bool:
	return _lifecycle_state == LifecycleState.ACTIVE or _lifecycle_state == LifecycleState.HIT_PAUSED


## GSM state-change handler (ADR-0006 Contract 6; wired in Story 008). Suspended → force
## cancel-all + reject; any non-Suspended transition out of Suspended → resume Active.
func _on_gsm_state_changed(_from: Variant, to: Variant, _payload: Variant = null) -> void:
	if _is_suspended_state(to):
		_enter_suspended()
	elif _lifecycle_state == LifecycleState.SUSPENDED:
		_lifecycle_state = LifecycleState.ACTIVE  # resume / initial-state activation


func _is_suspended_state(state: Variant) -> bool:
	return int(state) == GameStateMachine.GameState.SUSPENDED


## Suspended override (Rule 13): hard cancel everything — trauma, pause, freeze, uniform.
func _enter_suspended() -> void:
	_trauma = 0.0
	_decay_rate = 0.0
	_pause_remaining_sec = 0.0
	_emit_depth = 0
	_trauma_just_zeroed = false
	if get_tree().paused:
		get_tree().paused = false
	_shader_sink.call(SHAKE_UNIFORM, Vector2.ZERO)
	_lifecycle_state = LifecycleState.SUSPENDED


## bfcache resume hardening (Rule 13 / EC-10/11): Safari snapshot restore may leave a latched
## paused tree / stale shader uniform — force a clean Active state on resume/focus.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_trauma = 0.0
		_decay_rate = 0.0
		_pause_remaining_sec = 0.0
		_emit_depth = 0
		_trauma_just_zeroed = false
		if is_inside_tree() and get_tree().paused:
			get_tree().paused = false
		if _shader_sink.is_valid():
			_shader_sink.call(SHAKE_UNIFORM, Vector2.ZERO)
		if _lifecycle_state == LifecycleState.HIT_PAUSED:
			_lifecycle_state = LifecycleState.ACTIVE


# ── Helpers ─────────────────────────────────────────────────────────────────────

func _warn(msg: String) -> void:
	if _warn_sink.is_valid():
		_warn_sink.call(msg)
	else:
		push_warning(msg)
