## GymModeHud — Presentation HUD scaffold (Story 001)
##
## System #20 Gym-Mode HUD. NOT an autoload — instantiated under CanvasLayer 50
## in the main scene. All autoload _ready() calls have already completed by the
## time this node's _ready() runs (ADR-0006 Contract 4 per-autoload sequential boot).
##
## Responsibilities (Story 001 scope):
##   - Pull-then-subscribe GSM / StatSystem / AbilitySystem / AudioManager
##   - Apply GDD R8 state matrix on every GSM state_changed
##   - stat_changed: O(1) early-return for non-HUD stat_ids (AC-CR-3)
##   - Thin 3-state view (Booting / BannerGate / Active / Suspended), derive GSM
##   - _apply_state_matrix() pure injectable method (AC-UX-2 test seam)
##
## Out of scope this story:
##   - Bar/tween implementation (Story 002/003)
##   - Banner render + audio gate (Story 006)
##   - Dim alpha values / DIM_PRODUCT_FLOOR (Story 008)
##   - bfcache/resume generational guard (Story 010)
##
## Driving GDD: design/gdd/gym-mode-hud.md (R8 Approved 2026-06-03)
## Governing ADR: ADR-0006 State Machine Contract (Accepted 2026-05-28)
## UX spec: design/ux/gym-mode-hud.md (Approved)
extends Control


## Display emphasis for a HUD element. Ground truth = GDD §States matrix R8.
## Symbols: ◉ EMPHASIS  ○ AMBIENT  ○dim AMBIENT_DIM  ◐ DEEP_DIM
##           ▷ SURFACE  — HIDDEN  ▽ DEFER  ❄ FROZEN
enum Emphasis {
	HIDDEN,      ## — Not rendered
	AMBIENT,     ## ○ Normal ambient (glance-readable)
	AMBIENT_DIM, ## ○dim Dimmed ambient (Story 008 applies dim multiplier)
	EMPHASIS,    ## ◉ Full focus (glance-critical)
	DEEP_DIM,    ## ◐ Below glance threshold (對焦先見)
	SURFACE,     ## ▷ Elevated surface (REST_PERIOD focused elements)
	DEFER,       ## ▽ Deferred (LOOT_DROP — yield to #21 loot modal)
	FROZEN,      ## ❄ Frozen-dim (SUSPENDED state)
}

## Thin internal 3-state view. Does NOT duplicate GSM truth — derives from it.
## SM-D (GDD §States): Booting exits → branch audio_unlocked? → Active : BannerGate
## Story 006 owns banner render. Story 010 owns bfcache generational guard.
enum _HudState {
	BOOTING,
	BANNER_GATE,
	ACTIVE,
	SUSPENDED,
}

## HUD element keys — ground truth for state matrix and element_emphasis dict.
const ELEM_HP: StringName     = &"hp"
const ELEM_EXP: StringName    = &"exp"
const ELEM_STAT: StringName   = &"stat"
const ELEM_SKILLS: StringName = &"skills"
const ELEM_PROG: StringName   = &"prog"
const ELEM_BOSS: StringName   = &"boss"

## O(1) lookup set: stat_ids this HUD displays. stat_changed for others → early-return.
## AC-CR-3: non-HUD stat_changed MUST not trigger any redraw.
const _HUD_STAT_ID_SET: Dictionary = {
	&"max_hp": true, ## HP bar — StatSystem.StatId.MAX_HP
	&"exp":    true, ## EXP bar — planned StatId
	&"str":    true, ## STAT composite element
	&"dex":    true,
	&"vit":    true,
}

## stat_id for the EXP bar — drives Formula 1 fill (Story 002).
const STAT_ID_EXP: StringName = &"exp"

## stat_id for the HP bar — bound to MAX_HP (non-depleting, Story 004).
const STAT_ID_MAX_HP: StringName = &"max_hp"

## Skill cluster display cap (BOSS_ENCOUNTER glance budget — top-N strongest, rest collapse "+N").
const SKILL_CLUSTER_DISPLAY_CAP: int = 4

## #20-OWNED SkillIconRegistry (Story 004). 9 MVP-locked canonical ability_id → intrinsic
## icon slot metadata. tier_ordinal/class_ordinal mirror #12 published mapping (ability-system.md
## L386/L405) and are SLOT IDENTITY (e.g. strike_tier_3 is always tier 2), NOT runtime state.
## This is #20's own data — #20 NEVER reads #12 collection iteration order, timestamps, or
## internal state (ability-system.md L413 insertion-order-agnostic, L696 NEVER access internal).
## glyph_shape: Strike=diagonal/sharp · Control=symmetric/arc · Mobility=flowing/negative-space (P-04).
const SKILL_ICON_REGISTRY: Dictionary = {
	&"strike_tier_1_jab":          {"tier_ordinal": 0, "class_ordinal": 0, "glyph_shape": "diagonal_sharp"},
	&"strike_tier_2_hook":         {"tier_ordinal": 1, "class_ordinal": 0, "glyph_shape": "diagonal_sharp"},
	&"strike_tier_3_overhand":     {"tier_ordinal": 2, "class_ordinal": 0, "glyph_shape": "diagonal_sharp"},
	&"control_tier_1_parry":       {"tier_ordinal": 0, "class_ordinal": 1, "glyph_shape": "symmetric_arc"},
	&"control_tier_2_hook_pull":   {"tier_ordinal": 1, "class_ordinal": 1, "glyph_shape": "symmetric_arc"},
	&"control_tier_3_grapple":     {"tier_ordinal": 2, "class_ordinal": 1, "glyph_shape": "symmetric_arc"},
	&"mobility_tier_1_dash":       {"tier_ordinal": 0, "class_ordinal": 2, "glyph_shape": "flowing_negative_space"},
	&"mobility_tier_2_leap":       {"tier_ordinal": 1, "class_ordinal": 2, "glyph_shape": "flowing_negative_space"},
	&"mobility_tier_3_ground_pound": {"tier_ordinal": 2, "class_ordinal": 2, "glyph_shape": "flowing_negative_space"},
}

## Formula 2 base tween duration. Config-const (GDD F2 safe range [0.2, 0.5], default 0.3).
## reduce_motion overrides to 0.0 (instant set).
const BASE_TWEEN_DURATION: float = 0.3

## ADR-0001 burst cap — max concurrent SceneTreeTweens before low-priority motion
## degrades to instant set. Prevents mobile WASM GC stutter on reconnect bursts.
## Applies to NEW (cross-stat) tweens; same-stat high-frequency is handled by the
## circuit breaker (MAX_TWEEN_RESTART_COUNT), not this cap.
const MAX_CONCURRENT_TWEENS: int = 6

## Circuit breaker (Story 003) — after this many consecutive same-stat_id kill-restarts,
## the next event snaps instantly instead of restarting yet another tween. Guarantees a
## high-frequency reconnect burst settles in bounded time (no livelock). Spike B4: snap
## fires on the (MAX_TWEEN_RESTART_COUNT + 1)-th event — the first create is NOT a restart.
const MAX_TWEEN_RESTART_COUNT: int = 5

## Minimum EXP bar height in px (P-02 frameless-hud-bar floor — never collapses to invisible).
const MIN_BAR_HEIGHT_PX: float = 4.0

# ── Dim / alpha constants (Story 008) ──
# dim = HUD alpha/brightness layer (NOT desaturation — amber semantic preserved). Orthogonal to
# MoodController world_desaturation (different layer/channel — no joint danger).

## Base HUD dim multiplier — applied per-state, then floored at DIM_PRODUCT_FLOOR.
const BASE_DIM: float = 0.5

## State dim multipliers (config). effective_dim = max(BASE_DIM × state_mult, DIM_PRODUCT_FLOOR).
const LOOT_DIM_MULTIPLIER: float = 0.4        ## LOOT_DROP — yields to #21 ceremony
const SUSPENSION_DIM_MULTIPLIER: float = 0.7  ## SUSPENDED — freeze-dim extra layer
## DISCONNECTED dim. STRUCTURAL (1.0 = no extra dim) — kept only for formula uniformity, NOT a
## tuning knob (R6 RECOMMENDED — moved out of Tuning Knobs).
const DISCONNECT_DIM_MULTIPLIER: float = 1.0

## Effective-dim floor — prevents the HUD dimming toward near-black (looks like a crash).
## Clamp is applied to the FINAL product (KNOB-A: never back-solved into individual knobs).
const DIM_PRODUCT_FLOOR: float = 0.30

## Emphasis → element alpha (the 3-axis glance model). ◉/▷ full, ○ ambient, ◐ below threshold.
## Invariant: DEEP_DIM_ELEMENT_ALPHA < DEEP_DIM_ALPHA_THRESHOLD < AMBIENT_ALPHA (Story 009 CI-asserts).
const EMPHASIS_ALPHA: float = 1.0             ## ◉ / ▷ — focus layer, fully visible
const AMBIENT_ALPHA: float = 0.55             ## ○ — glance-readable (> threshold)
const DEEP_DIM_ELEMENT_ALPHA: float = 0.22    ## ◐ — exits glance band (< threshold, focus to see)
const DEEP_DIM_ALPHA_THRESHOLD: float = 0.35  ## glance/no-glance boundary (Story 009 counting rule)

## Max Tier-1 (glance-visible) elements allowed per counted state (Story 009 AC-U-3 budget).
const GLANCE_TIER1_MAX: int = 5

# ── Silent-mode banner constants (Story 006, Formula 3) ──
# Banner gates ONLY the audio buffer flush (B1 decouple) — NEVER workout count / EXP visuals.
# The pulse is alpha-only (not scale/position) so it never competes for peripheral glance.

const BANNER_BASE_ALPHA: float = 0.7    ## F3 base alpha [0.6, 0.8]
const BANNER_PULSE_AMP: float = 0.1     ## F3 pulse amplitude (alpha-only) [0.05, 0.15]
const BANNER_PULSE_PERIOD: float = 2.0  ## F3 breathing period seconds [1.5, 2.5]
const MIN_PULSE_PERIOD: float = 0.5     ## F3-A div-0 guard floor (period=0 → P=0.5, no NaN livelock)

## Banner Control focus_mode contract (AC-U-4 — one-tap touch, no hover/focus ring). The actual
## banner node (built in the HUD .tscn, Story 011) MUST apply this value. Control.FOCUS_NONE == 0.
const BANNER_FOCUS_MODE: int = 0  # Control.FOCUS_NONE

# ── Minimum visual floors + REST cockpit caps (Story 011) ──

const HP_BAR_HEIGHT_PX: float = 6.0    ## HP bar height (P-02; EXP derives at half this).
const MIN_FONT_SIZE_PX: float = 7.0    ## Hard font floor — peripheral readability (AC-U-6).
const BANNER_TOUCH_TARGET_PX: float = 44.0  ## Banner hit-area floor in CSS px (AC-UX-8).
const REST_SKILLS_LIST_CAP: int = 8    ## REST_PERIOD focus-layer skill list cap (bounded, +scroll).
const REST_STAT_BLOCK_CAP: int = 3     ## REST_PERIOD STAT block cap.

## stat_id → tween-target property name. Story 002 EXP only; Story 004 adds HP.
const _STAT_BAR_PROPERTY: Dictionary = {
	&"exp": "_exp_bar_value",
}

## Untyped DI seams — must remain untyped (typed Node fails compile-time member check).
var _gsm            ## GameStateMachine autoload (or test stub)
var _stat_system    ## StatSystem autoload (or test stub)
var _ability_system ## AbilitySystem autoload (or test stub)
var _audio_manager  ## AudioManager autoload (or test stub)
var _wst            ## WorkoutStateTracker autoload (or test stub) — #9-validated count source

## Current emphasis per HUD element. Driven by _apply_state_matrix.
## Test seam: read via get_element_emphasis().
var _element_emphasis: Dictionary = {}

## Current internal HUD state (thin 3-state view).
## Test seam: read via get_hud_state().
var _hud_state: _HudState = _HudState.BOOTING

## State matrix: GameState (int) → { elem_key: StringName → Emphasis }.
## Built once in _ready() from GDD R8 matrix. Kept as var (not const) because
## GDScript const dict keys must be literals; GameState enum values resolve at runtime.
var _state_matrix: Dictionary = {}

## Redraw call count per stat_id. Test seam for AC-CR-3 assertion.
var _redraw_counts: Dictionary = {}

## Pending SFX / banner queue — expanded by Story 006 (banner) and Story 007 (audio adapter).
var _pending: Array = []

# ── EXP bar tween state (Story 002) ──

## Master reduce-motion override. When true, every tween path snaps instantly (Formula 2).
## Story 011 wires this from #6 ScreenEffects motion_intensity. Default false (motion on).
var _reduce_motion: bool = false

## Handle-map: stat_id → live Tween (Story 003, spike F5). Single source of truth for
## in-flight tweens. _active_tween_count is DERIVED from .size() — no dual-truth drift.
## Invariant: get_active_tween_count() == _active_tweens.size() at all times.
var _active_tweens: Dictionary = {}

## stat_id → consecutive kill-restart count (circuit breaker, spike F9). Reset to 0 on
## natural finish (lifecycle ③) or on snap. Read via _get_restart_count_for_test().
var _restart_count: Dictionary = {}

## EXP bar fill ratio [0.0, 1.0] — tween target/current. Animated by _set_exp_fill.
var _exp_bar_value: float = 0.0

## Latest EXP stat value (from stat_changed). current_exp input to Formula 1.
var _current_exp: float = 0.0

## EXP required for next level. Formula 1 denominator. Seam — Story 011 wires #11 query.
## Default 1.0 keeps Formula 1 div-guard satisfied before the real value is wired.
var _exp_to_next: float = 1.0

## Latest MAX_HP value (Story 004). HP bar is non-depleting — it tracks MAX_HP only and
## steps up when MAX_HP grows. No current-HP owner in MVP (Q-OQ3 deferred to #25). Default
## 0.0 (non-NaN) is the first-frame fallback (AC-UX-4).
var _hp_max_value: float = 0.0

# ── #9-validated workout count / progress (Story 005) ──
# CR-8 收斂1: count + PROG copy come ONLY from #9-validated signals (set_progress_changed /
# phase_changed). #20 NEVER subscribes raw #2 set_logged for count/visual (that is audio-only,
# Story 007) — doing so would let the Silent Witness fabricate (Pillar 1 violation). #9 already
# runs WST Rule 8 anti-fabrication (drops IDLE-without-workout_started / SUSPENDED stray), so #20
# simply has no consumer-side fabrication path.

## Latest #9-validated set progress (monotonic, absolute). NOT interpolated between events
## (AC-CR-4 — no progress += elapsed during the 5s polling gap).
var _workout_progress: float = 0.0

## Latest #9 WorkoutPhase (int ordinal). Drives PROG copy (WARM_UP/SET_ACTIVE/REST/COMPLETE).
var _workout_phase: int = 0

## Banner dismissed this session (Story 006). In-memory, NON-persisted: a resume re-evaluates
## audio lock state, but once dismissed in THIS session the banner never re-appears (AC-CR-7).
var _banner_dismissed_this_session: bool = false


func _ready() -> void:
	_build_state_matrix()

	# Fall back to autoload globals when not injected (production path).
	if _gsm == null:
		_gsm = get_node_or_null("/root/GameStateMachine")
	if _stat_system == null:
		_stat_system = get_node_or_null("/root/StatSystem")
	if _ability_system == null:
		_ability_system = get_node_or_null("/root/AbilitySystem")
	if _audio_manager == null:
		_audio_manager = get_node_or_null("/root/AudioManager")
	if _wst == null:
		_wst = get_node_or_null("/root/WorkoutStateTracker")

	# Pull-then-subscribe (ADR-0006 Contract 6): fill initial UI first, then connect.
	if _gsm != null:
		var initial: int = _gsm.get_current_state()
		_apply_state_matrix(initial)
		# connect_for_initial_state: connects signal + delivers current state next frame.
		# Forbidden: stat_changed.connect() plain — CI lint check_stat_changed_connect.gd.
		_gsm.connect_for_initial_state(_on_state_changed)

	if _stat_system != null:
		# CI lint enforces connect_for_initial_state (check_stat_changed_connect.gd).
		_stat_system.connect_for_initial_state(_on_stat_changed)

	if _ability_system != null:
		_ability_system.connect_for_initial_state(_on_ability_unlocked)

	if _audio_manager != null:
		# audio_unlocked is a transient event — plain .connect + query pull for initial.
		_audio_manager.audio_unlocked.connect(_on_audio_unlocked)

	if _wst != null:
		# #9-validated count/progress. Transient events → plain .connect + pull initial
		# (GDD wiring rule #2). NEVER subscribe #2 set_logged here (count anti-fabrication).
		_workout_progress = _wst.get_set_progress()
		_workout_phase = _wst.get_current_phase()
		_wst.set_progress_changed.connect(_on_set_progress_changed)
		_wst.phase_changed.connect(_on_phase_changed)


func _exit_tree() -> void:
	# Kill tweens + clear pending to avoid dangling callbacks on a freed node.
	# Story 007 expands: clear audio buffer.
	for stat_id: StringName in _active_tweens.keys():
		var t: Tween = _active_tweens[stat_id]
		if t != null and t.is_valid():
			t.kill()
	_active_tweens.clear()
	_restart_count.clear()
	_pending.clear()


# ── Signal handlers ──

## GSM state_changed handler (initial + real transitions via connect_for_initial_state).
## Forbidden: driving any GSM transition from here (ADR-0006 / Presentation layer rule).
func _on_state_changed(from_state: Variant, to_state: Variant, _payload: Variant = null) -> void:
	_update_hud_state(int(to_state))
	_apply_state_matrix(int(to_state))


## stat_changed handler with O(1) early-return for non-HUD stat_ids (AC-CR-3).
## Plain stat_changed.connect() FORBIDDEN — use connect_for_initial_state (CI-enforced).
func _on_stat_changed(
		stat_id: StringName,
		_old_value: float,
		new_value: float,
		_source: int,
		_is_initial: bool,
) -> void:
	if not _HUD_STAT_ID_SET.has(stat_id):
		return  # non-HUD stat — O(1) early exit, no redraw
	if stat_id == STAT_ID_EXP:
		_current_exp = new_value
	elif stat_id == STAT_ID_MAX_HP:
		# HP bar is non-depleting: track MAX_HP, sanitise NaN/negative to 0.0 (AC-UX-4).
		_hp_max_value = maxf(new_value, 0.0) if not is_nan(new_value) else 0.0
	_redraw_stat(stat_id)


## Ability unlocked handler. Icon flash scaffold — Story 002/003 expand.
func _on_ability_unlocked(_ability_id: StringName, _source: int) -> void:
	pass  # seam — Story 002/003 add icon flash dispatch


## Audio unlocked handler. Drives SM-D BannerGate → Active transition + one-shot banner dismiss.
func _on_audio_unlocked() -> void:
	_banner_dismissed_this_session = true  # AC-CR-7: never re-appears this session
	if _hud_state == _HudState.BANNER_GATE:
		_hud_state = _HudState.ACTIVE
		# Story 007 expands: flush buffered SFX.


## Banner tap handler (AC-CR-7 / AC-EC-S5). ALWAYS honored — exempt from #33 is_input_permitted
## (the unlock gesture must never be gated, even before #33 lands). Calls the canonical unlock
## path (#4 audio_manager.gd L215: "#20's banner pressed is the canonical path"). Idempotent;
## the resulting audio_unlocked signal drives dismiss via _on_audio_unlocked.
func _on_banner_tapped() -> void:
	if _audio_manager != null and _audio_manager.has_method("_do_unlock"):
		_audio_manager._do_unlock()


## Whether the silent-mode banner should render now (CR-6 / SM-A). Banner is NOT an independent
## state — it overlays any non-Booting/non-Suspended state while audio is locked and not yet
## dismissed this session.
func should_show_banner() -> bool:
	if _banner_dismissed_this_session:
		return false
	if _hud_state == _HudState.BOOTING or _hud_state == _HudState.SUSPENDED:
		return false
	if _audio_manager == null:
		return false
	return not _audio_manager.is_audio_unlocked()


## Effective banner pulse amplitude — reduce_motion master override forces 0 (static, AC-U-4).
func get_banner_pulse_amp() -> float:
	return 0.0 if _reduce_motion else BANNER_PULSE_AMP


## Banner focus mode contract (AC-U-4). The .tscn banner node applies this (Control.FOCUS_NONE).
func get_banner_focus_mode() -> int:
	return BANNER_FOCUS_MODE


## Formula 3 — banner amber pulse alpha. Pure static (AC-F3).
## banner_alpha = clamp(base + amp × (0.5 + 0.5 × sin(2π × fmod(t, P) / P)), 0, 1), P = max(period, 0.5).
## Inlined fmod (long-session phase precision) + max P-guard (div-0 → no NaN livelock, F3-A).
static func compute_banner_alpha(base_alpha: float, pulse_amp: float, t: float, pulse_period: float) -> float:
	var p: float = maxf(pulse_period, MIN_PULSE_PERIOD)
	var phase: float = TAU * fmod(t, p) / p
	return clampf(base_alpha + pulse_amp * (0.5 + 0.5 * sin(phase)), 0.0, 1.0)


## #9-validated set progress (Story 005). Absolute monotonic value — stored verbatim, never
## interpolated. Independent of audio unlock state (B1 decouple — count is Pillar-1 real data).
func _on_set_progress_changed(new_progress: float) -> void:
	_workout_progress = new_progress


## #9 WorkoutPhase transition (Story 005). Drives PROG copy tier; does NOT itself bump count.
func _on_phase_changed(_from_phase: int, to_phase: int) -> void:
	_workout_phase = to_phase


# ── Core logic ──

## Apply GDD R8 state matrix row for the given GSM state.
## Pure method — test injectable (AC-UX-2). Updates _element_emphasis for all elements.
## No if-ladder: data-driven via _state_matrix dict.
func _apply_state_matrix(gsm_state: int) -> void:
	var row: Dictionary = _state_matrix.get(gsm_state, {})
	for elem_key: StringName in row:
		_element_emphasis[elem_key] = row[elem_key]


## Drive the thin 3-state view on GSM state change (SM-D / SM-B from GDD §States).
func _update_hud_state(new_gsm_state: int) -> void:
	if new_gsm_state == GameStateMachine.GameState.BOOTING:
		_hud_state = _HudState.BOOTING
		return
	if new_gsm_state == GameStateMachine.GameState.SUSPENDED:
		_hud_state = _HudState.SUSPENDED
		return
	# SM-D: first departure from BOOTING. SM-B: resume from SUSPENDED.
	# Both branch on audio unlock state (Story 006 owns banner rendering itself).
	if _hud_state == _HudState.BOOTING or _hud_state == _HudState.SUSPENDED:
		var unlocked: bool = _audio_manager != null and _audio_manager.is_audio_unlocked()
		_hud_state = _HudState.ACTIVE if unlocked else _HudState.BANNER_GATE


## Dispatch a stat sub-widget redraw. Increments _redraw_counts for AC-CR-3 test seam.
## Story 002: EXP stat → recompute Formula 1 fill + animate. Story 004 adds HP.
func _redraw_stat(stat_id: StringName) -> void:
	_redraw_counts[stat_id] = _redraw_counts.get(stat_id, 0) + 1
	if stat_id == STAT_ID_EXP:
		_set_exp_fill(compute_exp_fill(_current_exp, _exp_to_next))


## Formula 1 — EXP bar fill ratio. Pure static (test-injectable, AC-F1).
## exp_fill = clamp(current_exp / max(exp_to_next, 1), 0.0, 1.0)
##   - EC-F3: both inputs sanitised with max(.,0) before use (negative stale guard)
##   - F1 div-guard: max(exp_to_next, 1) prevents divide-by-zero (EC-F1)
##   - EC-F4: NaN/INF ratio → 0.0 fallback (no bar corruption on boot-time first NaN)
static func compute_exp_fill(current_exp: float, exp_to_next: float) -> float:
	var safe_exp: float = maxf(current_exp, 0.0)
	var safe_to_next: float = maxf(exp_to_next, 0.0)
	var ratio: float = safe_exp / maxf(safe_to_next, 1.0)
	if is_nan(ratio) or is_inf(ratio):
		return 0.0
	return clampf(ratio, 0.0, 1.0)


## Formula 2 — tween duration with reduce_motion gate. Pure static (AC-F2).
## reduce_motion ? 0.0 (instant set) : base. base is clamped to its safe range [0.2, 0.5].
static func compute_tween_duration(reduce_motion: bool, base: float) -> float:
	if reduce_motion:
		return 0.0
	return clampf(base, 0.2, 0.5)


## Animate the EXP bar to a target fill. Delegates to the generic handle-map
## circuit-breaker path (Story 003). Story 004 adds an HP equivalent.
func _set_exp_fill(target: float) -> void:
	_request_stat_tween(STAT_ID_EXP, target)


## Request a value tween for a HUD stat element, with circuit breaker + cap (Story 003).
## Spike-grounded ordering (SPIKE-FINDINGS.md PART B):
##   - reduce_motion OR DEEP_DIM emphasis (EC-R6) → instant set, no tween
##   - same-stat in-flight → kill-restart; _restart_count++ FIRST, then cap-check.
##     On the (MAX_TWEEN_RESTART_COUNT + 1)-th event → snap + reset (circuit breaker)
##   - new stat at/over MAX_CONCURRENT_TWEENS → instant set (cross-stat cap degrade)
##   - otherwise → create tween (restart from current interpolated value, no rewind)
func _request_stat_tween(stat_id: StringName, target_value: float) -> void:
	var dur: float = compute_tween_duration(_reduce_motion, BASE_TWEEN_DURATION)
	# F2 reduce_motion / EC-R6 deep-dim → instant set (never creates a tween).
	if dur <= 0.0 or get_element_emphasis(_emphasis_key_for_stat(stat_id)) == Emphasis.DEEP_DIM:
		_set_immediate(stat_id, target_value)
		return

	if _active_tweens.has(stat_id):
		# kill-restart path. Spike B3: increment FIRST, then compare cap.
		_restart_count[stat_id] = int(_restart_count.get(stat_id, 0)) + 1
		if _restart_count[stat_id] >= MAX_TWEEN_RESTART_COUNT:
			# Circuit breaker: snap to latest target, reset (spike B3/B4).
			_kill(stat_id)
			_set_immediate(stat_id, target_value)
			_restart_count[stat_id] = 0
			return
		_kill(stat_id)
		_create_stat_tween(stat_id, target_value, dur)
		return

	# New stat. Cross-stat burst cap (spike-distinct from same-stat circuit breaker).
	if _active_tweens.size() >= MAX_CONCURRENT_TWEENS:
		_set_immediate(stat_id, target_value)
		return
	_create_stat_tween(stat_id, target_value, dur)


## Kill a stat's live tween with INDEPENDENT erase (spike B2: kill() does NOT emit
## finished, so the handle-map cleanup must NOT rely on _on_tween_finished).
func _kill(stat_id: StringName) -> void:
	var t: Tween = _active_tweens.get(stat_id)
	if t != null and t.is_valid():
		t.kill()
	if _active_tweens.has(stat_id):
		_active_tweens.erase(stat_id)


## Create a SceneTreeTween for a stat (SceneTree-managed, NOT node _process).
## Wires the 2-param identity-guard finished seam (spike A4/B6).
func _create_stat_tween(stat_id: StringName, target_value: float, dur: float) -> void:
	var prop: String = _STAT_BAR_PROPERTY.get(stat_id, "")
	if prop.is_empty():
		return  # unmapped stat — no bar to animate (Story 004 adds HP)
	var t: Tween = create_tween()
	t.tween_property(self, prop, target_value, dur)
	t.finished.connect(_on_tween_finished.bind(stat_id, t), CONNECT_ONE_SHOT)
	_active_tweens[stat_id] = t


## Instant-set a stat's bar value (snap path / reduce_motion / deep-dim). No tween.
func _set_immediate(stat_id: StringName, value: float) -> void:
	var prop: String = _STAT_BAR_PROPERTY.get(stat_id, "")
	if not prop.is_empty():
		set(prop, value)


## Natural-finish seam (spike B5/B6): 2-param identity guard. Only the CURRENT live
## tween for this stat is cleaned up; stale/empty handles are a no-op (no double-decrement,
## no erasing a newer tween). Resets _restart_count (lifecycle ③).
func _on_tween_finished(stat_id: StringName, src_tween: Tween) -> void:
	if _active_tweens.get(stat_id) != src_tween:
		return  # stale residual finished, or already replaced by restart → no-op
	_active_tweens.erase(stat_id)
	_restart_count[stat_id] = 0


## Map a stat_id to its HUD element emphasis key (for EC-R6 deep-dim skip).
func _emphasis_key_for_stat(stat_id: StringName) -> StringName:
	if stat_id == STAT_ID_EXP:
		return ELEM_EXP
	return stat_id


# ── bfcache / resume reconcile (Story 010) ──

## Reconcile HUD to pulled truth after a resume (bfcache restore / focus-out). Pure logic —
## takes the already-pulled GSM state (does NOT trust a stale frame). Headless-testable (S9a).
## Sequence (GDD SM-A/B/C/D):
##   ① generational guard (SM-C): if GSM is mid-transition, defer one frame then re-pull — a
##      single-shot read during an in-flight transition could be mid-transition stale.
##   ② one-shot snap: apply the pulled-state matrix + snap bar values (NO missed-motion replay).
##   ③ leave Suspended ⟺ dom_visible AND gsm != SUSPENDED (AND guard, NOT OR).
##   ④ terminal branch (SM-D): is_audio_unlocked ? Active : BannerGate.
## Banner dismiss flag is NEVER reset here (防重彈, AC-CR-7). No SFX flush here (that is the
## adapter's audio_unlocked path — reconcile must not double-flush).
func reconcile(pulled_state: int, dom_visible: bool = true) -> void:
	if _gsm_in_flight():
		call_deferred("reconcile", pulled_state, dom_visible)  # SM-C defer one frame
		return
	_apply_state_matrix(pulled_state)
	_snap_bars_to_current()
	if pulled_state == GameStateMachine.GameState.SUSPENDED or not dom_visible:
		_hud_state = _HudState.SUSPENDED  # SM-B AND guard: stay suspended
	else:
		_hud_state = _HudState.ACTIVE if _is_audio_unlocked() else _HudState.BANNER_GATE


## True while the GSM is mid-transition (read-side generational guard seam, SM-C). Uses
## has_method so it is safe before the GSM exposes is_transitioning() — real wiring tracked
## as a follow-up (GSM currently keeps _transitioning private).
func _gsm_in_flight() -> bool:
	return _gsm != null and _gsm.has_method("is_transitioning") and _gsm.is_transitioning()


## Snap all bar values to their current truth (one-shot, no missed-motion replay). Kills any
## in-flight tween first so the resume does not animate from a frozen value.
func _snap_bars_to_current() -> void:
	for stat_id: StringName in _active_tweens.keys():
		_kill(stat_id)
	_exp_bar_value = compute_exp_fill(_current_exp, _exp_to_next)


func _is_audio_unlocked() -> bool:
	return _audio_manager != null and _audio_manager.is_audio_unlocked()


## Effective HUD dim for a state multiplier (AC-KNOB-B). Pure static.
## effective_dim = max(BASE_DIM × state_multiplier, DIM_PRODUCT_FLOOR). The clamp is on the
## FINAL product (KNOB-A) — never back-solved into the individual knobs.
static func compute_effective_dim(base_dim: float, state_multiplier: float, floor_value: float) -> float:
	return maxf(base_dim * state_multiplier, floor_value)


## State dim multiplier for a GSM state (config-driven, no literals). 1.0 = no extra dim.
func get_state_dim_multiplier(gsm_state: int) -> float:
	match gsm_state:
		GameStateMachine.GameState.LOOT_DROP:
			return LOOT_DIM_MULTIPLIER
		GameStateMachine.GameState.SUSPENDED:
			return SUSPENSION_DIM_MULTIPLIER
		GameStateMachine.GameState.DISCONNECTED:
			return DISCONNECT_DIM_MULTIPLIER
		_:
			return 1.0


## Effective dim for a GSM state (convenience — AC-KNOB-B production path).
func get_effective_dim_for_state(gsm_state: int) -> float:
	return compute_effective_dim(BASE_DIM, get_state_dim_multiplier(gsm_state), DIM_PRODUCT_FLOOR)


## Effective per-element alpha for an emphasis level (3-axis glance model).
## ◉/▷ full · ○ ambient (0.55) · ◐ deep-dim (0.22, exits glance) · —/▽ not drawn · ❄ ambient (frozen but visible).
func get_emphasis_alpha(emphasis: Emphasis) -> float:
	match emphasis:
		Emphasis.EMPHASIS, Emphasis.SURFACE:
			return EMPHASIS_ALPHA
		Emphasis.AMBIENT, Emphasis.AMBIENT_DIM, Emphasis.FROZEN:
			return AMBIENT_ALPHA
		Emphasis.DEEP_DIM:
			return DEEP_DIM_ELEMENT_ALPHA
		_:  # HIDDEN, DEFER — not rendered by the HUD
			return 0.0


## Count Tier-1 (glance-visible) elements in a GSM state row (Story 009 AC-U-3).
## An element counts if its effective alpha is ABOVE the deep-dim threshold (◉/○/▷ count;
## ◐/—/▽ do not). Cluster SKILLS is a single element key → counts as 1 grouped element.
func get_glance_tier1_count(gsm_state: int) -> int:
	var row: Dictionary = _state_matrix.get(gsm_state, {})
	var n: int = 0
	for elem_key: StringName in row:
		if get_emphasis_alpha(row[elem_key]) > DEEP_DIM_ALPHA_THRESHOLD:
			n += 1
	return n


## Alpha 3-axis invariant (Story 009 B7 boot-assert): deep_dim < threshold < ambient.
## Returns true when the glance bands are correctly ordered (no overlap).
static func alpha_invariants_hold() -> bool:
	return DEEP_DIM_ELEMENT_ALPHA < DEEP_DIM_ALPHA_THRESHOLD \
		and DEEP_DIM_ALPHA_THRESHOLD < AMBIENT_ALPHA


## Build GDD R8 state matrix (9 GSM states × 6 HUD elements).
## Called once from _ready() — separated to keep _ready() concise.
func _build_state_matrix() -> void:
	_state_matrix = {
		GameStateMachine.GameState.BOOTING: {
			ELEM_HP: Emphasis.HIDDEN, ELEM_EXP: Emphasis.HIDDEN,
			ELEM_STAT: Emphasis.HIDDEN, ELEM_SKILLS: Emphasis.HIDDEN,
			ELEM_PROG: Emphasis.HIDDEN, ELEM_BOSS: Emphasis.HIDDEN,
		},
		GameStateMachine.GameState.DISCONNECTED: {
			ELEM_HP: Emphasis.AMBIENT_DIM, ELEM_EXP: Emphasis.HIDDEN,
			ELEM_STAT: Emphasis.HIDDEN, ELEM_SKILLS: Emphasis.HIDDEN,
			ELEM_PROG: Emphasis.HIDDEN, ELEM_BOSS: Emphasis.HIDDEN,
		},
		GameStateMachine.GameState.IDLE: {
			ELEM_HP: Emphasis.AMBIENT, ELEM_EXP: Emphasis.AMBIENT,
			ELEM_STAT: Emphasis.AMBIENT, ELEM_SKILLS: Emphasis.AMBIENT,
			ELEM_PROG: Emphasis.HIDDEN, ELEM_BOSS: Emphasis.HIDDEN,
		},
		GameStateMachine.GameState.WORKOUT_ACTIVE: {
			ELEM_HP: Emphasis.EMPHASIS, ELEM_EXP: Emphasis.EMPHASIS,
			ELEM_STAT: Emphasis.DEEP_DIM, ELEM_SKILLS: Emphasis.DEEP_DIM,
			ELEM_PROG: Emphasis.AMBIENT, ELEM_BOSS: Emphasis.HIDDEN,
		},
		GameStateMachine.GameState.REST_PERIOD: {
			ELEM_HP: Emphasis.AMBIENT, ELEM_EXP: Emphasis.AMBIENT,
			ELEM_STAT: Emphasis.SURFACE, ELEM_SKILLS: Emphasis.SURFACE,
			ELEM_PROG: Emphasis.SURFACE, ELEM_BOSS: Emphasis.HIDDEN,
		},
		GameStateMachine.GameState.COMBAT_ACTIVE: {
			ELEM_HP: Emphasis.EMPHASIS, ELEM_EXP: Emphasis.EMPHASIS,
			ELEM_STAT: Emphasis.DEEP_DIM, ELEM_SKILLS: Emphasis.DEEP_DIM,
			ELEM_PROG: Emphasis.AMBIENT, ELEM_BOSS: Emphasis.HIDDEN,
		},
		GameStateMachine.GameState.BOSS_ENCOUNTER: {
			ELEM_HP: Emphasis.EMPHASIS, ELEM_EXP: Emphasis.AMBIENT,
			ELEM_STAT: Emphasis.DEEP_DIM, ELEM_SKILLS: Emphasis.EMPHASIS,
			ELEM_PROG: Emphasis.DEEP_DIM, ELEM_BOSS: Emphasis.EMPHASIS,
		},
		GameStateMachine.GameState.LOOT_DROP: {
			ELEM_HP: Emphasis.AMBIENT_DIM, ELEM_EXP: Emphasis.AMBIENT_DIM,
			ELEM_STAT: Emphasis.HIDDEN, ELEM_SKILLS: Emphasis.HIDDEN,
			ELEM_PROG: Emphasis.DEFER, ELEM_BOSS: Emphasis.HIDDEN,
		},
		GameStateMachine.GameState.SUSPENDED: {
			ELEM_HP: Emphasis.FROZEN, ELEM_EXP: Emphasis.FROZEN,
			ELEM_STAT: Emphasis.FROZEN, ELEM_SKILLS: Emphasis.FROZEN,
			ELEM_PROG: Emphasis.FROZEN, ELEM_BOSS: Emphasis.FROZEN,
		},
	}


# ── Test seams ──

## Current display emphasis for a HUD element.
## AC-UX-2 / AC-CR-5 assertion point.
func get_element_emphasis(elem_key: StringName) -> Emphasis:
	return _element_emphasis.get(elem_key, Emphasis.HIDDEN)


## Redraw call count for a stat_id (AC-CR-3 assertion point).
func get_redraw_count(stat_id: StringName) -> int:
	return _redraw_counts.get(stat_id, 0)


## Current internal HUD state (SM-D / SM-B assertion point).
func get_hud_state() -> _HudState:
	return _hud_state


## In-flight tween count (AC-CR-2 assertion point). DERIVED from the handle-map —
## single source of truth, so the spike invariant count == _active_tweens.size() holds
## by construction.
func get_active_tween_count() -> int:
	return _active_tweens.size()


## Consecutive kill-restart count for a stat (AC-EC-F4b circuit-breaker assertion point).
func _get_restart_count_for_test(stat_id: StringName) -> int:
	return int(_restart_count.get(stat_id, 0))


## Latest MAX_HP value (AC-CR-12 HP assertion point). Non-depleting — first-frame default 0.0.
func get_hp_max_value() -> float:
	return _hp_max_value


## Skill cluster display list (Story 004, AC-CR-12 / AC-CR-13⑨). Given a set of unlocked
## ability_ids (e.g. keys of #12 get_unlocked_abilities()), returns the top `cap` sorted by
## SkillIconRegistry (tier_ordinal DESC = strongest first, class_ordinal ASC tie-break).
## Deterministic + insertion-order-agnostic: the (tier, class) key is unique across the 9
## canonical abilities, so the total order is independent of input iteration order and sort
## stability. Unmapped ids are ignored (no crash on unknown — AC-UX-4). Empty input → [].
func get_skill_cluster_display(ability_ids: Array, cap: int = SKILL_CLUSTER_DISPLAY_CAP) -> Array:
	var known: Array = _known_abilities_sorted(ability_ids)
	return known.slice(0, cap)


## Overflow count beyond the display cap ("+N" collapse indicator). 0 when within cap.
func get_skill_overflow_count(ability_ids: Array, cap: int = SKILL_CLUSTER_DISPLAY_CAP) -> int:
	return maxi(_known_abilities_sorted(ability_ids).size() - cap, 0)


## Filter to registry-known ability_ids and sort by (tier_ordinal DESC, class_ordinal ASC).
func _known_abilities_sorted(ability_ids: Array) -> Array:
	var known: Array = []
	for id: Variant in ability_ids:
		if SKILL_ICON_REGISTRY.has(id):
			known.append(id)
	known.sort_custom(_compare_skill_slots)
	return known


## Sort comparator: tier_ordinal DESC (strongest first), class_ordinal ASC tie-break.
## anti-Stagnation (AC-CR-13⑨): strongest tier wins a cluster slot, never insertion order.
func _compare_skill_slots(a: StringName, b: StringName) -> bool:
	var ra: Dictionary = SKILL_ICON_REGISTRY[a]
	var rb: Dictionary = SKILL_ICON_REGISTRY[b]
	if ra["tier_ordinal"] != rb["tier_ordinal"]:
		return ra["tier_ordinal"] > rb["tier_ordinal"]  # DESC
	return ra["class_ordinal"] < rb["class_ordinal"]      # ASC tie-break


# ── Minimum visual floors + REST cockpit caps (Story 011) ──

## EXP bar height = half HP height × DPR, floored at MIN_BAR_HEIGHT_PX (AC-UX-5). Pure static.
## Never collapses to invisible regardless of DPR (P-02 frameless-hud-bar floor).
static func compute_exp_bar_height(hp_height_px: float, dpr: float, min_bar_height: float) -> float:
	return maxf(roundf(hp_height_px * 0.5 * dpr), min_bar_height)


## Effective font size = base × text_scale, floored at min_font_size (AC-U-6). Pure static.
## A text_scale of 0.8 must NOT push the effective size below the hard floor.
static func compute_effective_font_size(base_font_px: float, text_scale: float, min_font_size: float) -> float:
	return maxf(base_font_px * text_scale, min_font_size)


## REST_PERIOD focus-layer skill list (AC-UX-10 / AC-U-2) — bounded top-N (+scroll), NOT the
## BOSS 4-icon glance cap. Sorted by the same registry order (strongest first).
func get_rest_skills_display(ability_ids: Array) -> Array:
	return _known_abilities_sorted(ability_ids).slice(0, REST_SKILLS_LIST_CAP)


## Current EXP bar fill value (AC-CR-2 value-stability assertion point).
func get_exp_bar_value() -> float:
	return _exp_bar_value


## Latest #9-validated workout progress (AC-CR-8 / AC-EC-S1 assertion point).
func get_workout_progress() -> float:
	return _workout_progress


## Latest #9 WorkoutPhase ordinal (AC-CR-8 PROG copy assertion point).
func get_workout_phase() -> int:
	return _workout_phase
