class_name AvatarFormulas
extends RefCounted
## Pure, deterministic Avatar Renderer (#26) formulas — no autoload, no RNG, no
## wall-clock except where explicitly passed in. GSM-agnostic: callers compute
## membership booleans (e.g. in_workout_window) so these stay unit-testable in
## isolation. See design/gdd/avatar-renderer.md Formulas 1-5.

const STRIKE: StringName = &"STRIKE"
const CONTROL: StringName = &"CONTROL"
const MOBILITY: StringName = &"MOBILITY"

## Formula 5 result codes.
const RESTORE_SNAPSHOT: int = 0
const RESET_TO_IDLE_REDERIVE: int = 1

## Sanitise a raw stat read: NaN / sentinel / negative -> 0.0 (EC-SIG-3/4).
static func sanitize_stat(v: float) -> float:
	if is_nan(v) or v < 0.0:
		return 0.0
	return v


## Formula 1 — dominant_class_derivation. Deterministic tie-break STRIKE>CONTROL>MOBILITY
## via the top-down `>=` chain. Always returns exactly one class (CF-1). AC-03.
static func dominant_class(str_v: float, dex_v: float, vit_v: float) -> StringName:
	var s := sanitize_stat(str_v)
	var d := sanitize_stat(dex_v)
	var v := sanitize_stat(vit_v)
	if s >= d and s >= v:
		return STRIKE
	elif d >= v:
		return CONTROL
	return MOBILITY


## Formula 2 — evolution_tier_derivation. Two independent SYMMETRIC paths so a pure
## specialist is never locked by the generalist sum gate (Pass-4 F-2 fix). AC-04/AC-05.
##   generalist_ok(t) = stat_total >= S_t  and ability_count   >= A_t
##   specialist_ok(t) = peak_stat  >= Sp_t and max_class_depth >= D_t
## effective_tier = max(computed, historical_max) — monotonic (CF-2 / CR-12). AC-05.
static func derive_tier(
	stat_total: float,
	peak_stat: float,
	ability_count: int,
	max_class_depth: int,
	config: AvatarEvolutionConfig,
	historical_max_tier: int = 0,
) -> int:
	if config == null:
		return historical_max_tier  # defensive — EC-BOOT-2 hard-crashes before this
	var computed := 0
	for t in range(config.stat_thresholds.size()):
		var generalist_ok := (
			stat_total >= float(config.stat_thresholds[t])
			and ability_count >= config.ability_thresholds[t]
		)
		var specialist_ok := (
			peak_stat >= float(config.peak_thresholds[t])
			and max_class_depth >= config.depth_thresholds[t]
		)
		if generalist_ok or specialist_ok:
			computed = t
	return maxi(computed, historical_max_tier)


## Formula 3 — milestone_two_gate_check. Returns {should_emit, defer}.
##   gate_a = current_tier > last_emitted_tier (promotion)
##   gate_b = epoch-zero-guarded cadence / first-boot (AC-08)
##   gate_c = not in_workout_window (else defer, NOT drop — CR-15 / EC-MILE-2)
## EC-MILE-1: cadence fail with promotion true = suppress-only (should_emit=false,
## defer=false) — caller leaves last_emitted_tier unchanged, NO absorb.
static func milestone_gate(
	current_tier: int,
	last_emitted_tier: int,
	last_emit_unix: int,
	now_unix: int,
	account_created_unix: int,
	observed_sessions: int,
	in_workout_window: bool,
	cadence_seconds: int,
	first_boot_grace_seconds: int,
	min_observed_sessions: int,
) -> Dictionary:
	var gate_a := current_tier > last_emitted_tier
	if not gate_a:
		return {"should_emit": false, "defer": false}
	var gate_b: bool
	if last_emit_unix == 0:
		gate_b = (
			observed_sessions >= min_observed_sessions
			and (now_unix - account_created_unix) >= first_boot_grace_seconds
		)
	else:
		gate_b = (now_unix - last_emit_unix) >= cadence_seconds
	if not gate_b:
		return {"should_emit": false, "defer": false}  # suppress-only (EC-MILE-1)
	if in_workout_window:
		return {"should_emit": false, "defer": true}  # CR-15 defer
	return {"should_emit": true, "defer": false}


## Formula 3b — micro_evolution_cadence_check. AC-15.
static func should_micro(
	now_unix: int,
	last_micro_emit_unix: int,
	micro_cadence_seconds: int,
	rolling_7day_stat_delta: float,
	in_workout_window: bool,
) -> bool:
	return (
		(now_unix - last_micro_emit_unix) >= micro_cadence_seconds
		and rolling_7day_stat_delta > 0.0
		and not in_workout_window
	)


## Formula 4 — hysteresis_check. workout-window lock covers BOTH WORKOUT_ACTIVE and
## REST_PERIOD (Pass-4 F4 drift fix). Monotonic clock only (EC-HYST-3). AC-09/AC-10.
static func hysteresis_can_swap(
	new_class: StringName,
	last_class: StringName,
	now_monotonic_ms: int,
	last_switch_monotonic_ms: int,
	hysteresis_seconds: int,
	workout_window_lock: bool,
) -> bool:
	if workout_window_lock:
		return false
	if new_class == last_class:
		return false
	return (now_monotonic_ms - last_switch_monotonic_ms) >= hysteresis_seconds * 1000


## Formula 5 — bfcache_resume_action. Negative delta (untrusted clock) -> safe
## re-derive. AC-11/AC-18. Returns RESTORE_SNAPSHOT or RESET_TO_IDLE_REDERIVE.
static func bfcache_resume_action(raw_delta_ms: int, threshold_ms: int) -> int:
	if raw_delta_ms < 0:
		return RESET_TO_IDLE_REDERIVE
	var delta := maxi(0, raw_delta_ms)
	return RESTORE_SNAPSHOT if delta <= threshold_ms else RESET_TO_IDLE_REDERIVE
