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
