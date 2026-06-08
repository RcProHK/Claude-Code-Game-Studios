## ShellFormulas — #24 UI timing/display formulas (stories 006/007).
##
## Driving GDD: design/gdd/login-gymsys-connection-ui.md Formulas (F1/F2) + Tuning Knobs.
## Owner: LoginShellCoordinator (#24) — a pure logic helper (RefCounted, static funcs),
## NOT a node and NOT an autoload.
##
## Pure logic, NO engine clock: every timing function takes an injected `now_ms`
## (AC-51 — a formula path must never call Time.get_ticks_msec() directly, or
## advance(delta_ms) could not drive it = wall-clock phantom). Integer-ms internal
## comparison (knobs are float-sec declared but compared as int-ms) kills float
## boundary-flakiness (e.g. 2.49 not exactly representable).
extends RefCounted

## N ≤ 99 → inline「等 N 秒再試」; N > 99 (documented upper bound r=3600) → m:ss
## (a live per-second countdown in raw seconds is unreadable past ~99).
const COUNTDOWN_INLINE_MAX_SECONDS: int = 99


## ---- Formula 1 — Rate-Limited Countdown (Rule 4) ----

## display_seconds = max(0, ceili((r*1000 - (now_ms - t_start_ms)) / 1000.0)).
## `ceili` returns an int so the copy never reads「等 15.0 秒」. retry_after_sec <= 0
## (negative / absent) → 0 = immediate re-enable, no countdown copy (EC-D1 / N1).
static func display_seconds(retry_after_sec: int, t_start_ms: int, now_ms: int) -> int:
	if retry_after_sec <= 0:
		return 0
	var remaining_ms: int = retry_after_sec * 1000 - (now_ms - t_start_ms)
	if remaining_ms <= 0:
		return 0
	return ceili(remaining_ms / 1000.0)


## submit re-enables exactly when the countdown hits 0.
static func submit_enabled(retry_after_sec: int, t_start_ms: int, now_ms: int) -> bool:
	return display_seconds(retry_after_sec, t_start_ms, now_ms) == 0


## Countdown copy. The caller renders this ONLY while display_seconds > 0 — a zero
## N shows no copy at all (EC-D1). N ≤ 99 →「等 {N} 秒再試」; N > 99 →「等 {m}:{ss} 再試」.
static func format_countdown(display_secs: int) -> String:
	if display_secs <= COUNTDOWN_INLINE_MAX_SECONDS:
		return "等 %d 秒再試" % display_secs
	var m: int = display_secs / 60
	var ss: int = display_secs % 60
	return "等 %d:%02d 再試" % [m, ss]


## ---- Tuning knobs (story 007 — GDD Tuning Knobs; float-sec declared, safe ranges) ----

const SHELL_FADE_SEC: float = 0.25            ## [0.1, 0.5] — States cross-fade
const TRANSIENT_BANNER_TTL_SEC: float = 5.0   ## [3.0, 10.0] — F2 TRANSIENT TTL
const DRAIN_SUCCESS_EXPIRE_SEC: float = 2.0   ## [1.0, 3.0] — F2 drain/reconnect notice TTL
const BANNER_MAX_HEIGHT_PCT: float = 0.10     ## [0.06, 0.10] — peripheral class ceiling

const SHELL_FADE_MIN: float = 0.1
const SHELL_FADE_MAX: float = 0.5
const TRANSIENT_TTL_MIN: float = 3.0
const TRANSIENT_TTL_MAX: float = 10.0
const DRAIN_EXPIRE_MIN: float = 1.0
const DRAIN_EXPIRE_MAX: float = 3.0
const BANNER_HEIGHT_MIN: float = 0.06
const BANNER_HEIGHT_MAX: float = 0.10

## ttl_sec <= 0 is the PERSISTENT sentinel: ONGOING / WIPE / FEATURE_DEGRADED never
## auto-expire (Rule 6 — cleared by resolved / acknowledge / next-success, not by F2).
const PERSISTENT_TTL_SENTINEL: float = 0.0


## ---- Formula 2 — Banner Auto-Expire (TRANSIENT + 通知類, Rules 6/12) ----

## banner_visible = (now_ms - t_banner_start_ms) < ttl_ms  [STRICT <].
## Strict-< means the boundary t = t_b + TTL is already NOT visible (AC-19b — t=202.0
## exact = false). A ttl_sec <= 0 (the PERSISTENT sentinel) is always visible: F2 does
## not govern persistent classes (AC-20). Per-banner: each banner (incl. a「+N」
## collapsed one) runs its own t_banner_start timer.
static func banner_visible(now_ms: int, t_banner_start_ms: int, ttl_sec: float) -> bool:
	if ttl_sec <= PERSISTENT_TTL_SENTINEL:
		return true
	var ttl_ms: int = int(ttl_sec * 1000.0)
	return (now_ms - t_banner_start_ms) < ttl_ms


## ---- Knob validation (story 007 — release-safe, NOT raw assert) ----

## Validate the tuning knobs against their safe ranges + the 2 cross-knob invariants.
## Release-safe: Godot strips raw assert() in release builds and GUT cannot catch a
## raw assert failure (tautological phantom pass), so validation returns a bool +
## push_error instead. Defaults pass (AC-21a); injected violations fail (AC-21b).
## The `> 0` lower bound is load-bearing — DRAIN_SUCCESS=0 would make F2 never show (N4).
static func validate_knobs(
		shell_fade_sec: float = SHELL_FADE_SEC,
		transient_ttl_sec: float = TRANSIENT_BANNER_TTL_SEC,
		drain_expire_sec: float = DRAIN_SUCCESS_EXPIRE_SEC,
		banner_height_pct: float = BANNER_MAX_HEIGHT_PCT) -> bool:
	var ok: bool = true
	# Per-knob safe ranges.
	if shell_fade_sec < SHELL_FADE_MIN or shell_fade_sec > SHELL_FADE_MAX:
		push_error("ShellFormulas: SHELL_FADE_SEC %f out of [%f, %f]" % [shell_fade_sec, SHELL_FADE_MIN, SHELL_FADE_MAX])
		ok = false
	if transient_ttl_sec < TRANSIENT_TTL_MIN or transient_ttl_sec > TRANSIENT_TTL_MAX:
		push_error("ShellFormulas: TRANSIENT_BANNER_TTL_SEC %f out of [%f, %f]" % [transient_ttl_sec, TRANSIENT_TTL_MIN, TRANSIENT_TTL_MAX])
		ok = false
	if drain_expire_sec < DRAIN_EXPIRE_MIN or drain_expire_sec > DRAIN_EXPIRE_MAX:
		push_error("ShellFormulas: DRAIN_SUCCESS_EXPIRE_SEC %f out of [%f, %f] (>0 lower bound — F2 never-show guard)" % [drain_expire_sec, DRAIN_EXPIRE_MIN, DRAIN_EXPIRE_MAX])
		ok = false
	if banner_height_pct < BANNER_HEIGHT_MIN or banner_height_pct > BANNER_HEIGHT_MAX:
		push_error("ShellFormulas: BANNER_MAX_HEIGHT_PCT %f out of [%f, %f]" % [banner_height_pct, BANNER_HEIGHT_MIN, BANNER_HEIGHT_MAX])
		ok = false
	# Cross-knob invariant 1: a notice (drain/reconnect) must not outlast TRANSIENT.
	if drain_expire_sec > transient_ttl_sec:
		push_error("ShellFormulas: invariant 1 — DRAIN_SUCCESS_EXPIRE_SEC %f > TRANSIENT_BANNER_TTL_SEC %f" % [drain_expire_sec, transient_ttl_sec])
		ok = false
	# Cross-knob invariant 2: banner height hard ceiling (#20 peripheral contract).
	if banner_height_pct > BANNER_HEIGHT_MAX:
		push_error("ShellFormulas: invariant 2 — BANNER_MAX_HEIGHT_PCT %f > %f" % [banner_height_pct, BANNER_HEIGHT_MAX])
		ok = false
	return ok


## Clamp a knob into [lo, hi] (the「+ clamp」half of validate-then-clamp at load time).
static func clamp_knob(value: float, lo: float, hi: float) -> float:
	return clampf(value, lo, hi)
