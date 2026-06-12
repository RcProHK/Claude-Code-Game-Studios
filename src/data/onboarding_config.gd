class_name OnboardingConfig
extends Resource
## Data-driven tuning knobs for #27 Onboarding Flow (Tuning Knobs §). The
## `onboarding_coordinator.gd` reads every timing knob from a loaded instance of this
## resource — it holds ZERO timing literals itself. Knobs are declared in float seconds
## (designer-facing); the coordinator converts to integer ms once at load (Formula 2
## integer-ms discipline). See design/gdd/onboarding-flow.md.

## Coach-mark auto-dismiss countdown (sec). Formula 2 — too high: card lingers; too low:
## player misses the copy. Safe [3.0, 12.0].
@export var coach_auto_dismiss_sec: float = 6.0
## Coach-mark defer ceiling (sec). EC-12 — past this with no non-critical window, the step
## is silently latched (stale teaching worse than none). Safe [30.0, 600.0].
@export var coach_max_defer_sec: float = 120.0
## Coach-mark fade in/out duration (sec). reduced-motion ⇒ 0 (hard cut). Safe [0.0, 0.6].
@export var coach_fade_sec: float = 0.25
## Non-binding combat preview length (Step 2, sec). Safe [8.0, 60.0].
@export var preview_duration_sec: float = 24.0
## Master switch for Step 2 preview. false ⇒ step_preview latches immediately, no preview.
@export var preview_enabled: bool = true
## Master switch for all coach-marks (a11y / replay-test escape hatch). false ⇒ every step
## silent-latches; onboarding degrades to a pure latch tracker (steps still complete).
@export var coach_marks_enabled: bool = true

## Drift detector — bump on any knob change (mirrors #26/#29 config_version convention).
@export var version_hash: String = "v1-2026-06-12"


## Load-time validation. Returns "" when valid, else a diagnostic string. A non-empty
## result is a hard config error (EC surrounds the boot read).
func validate() -> String:
	if coach_auto_dismiss_sec < 3.0 or coach_auto_dismiss_sec > 12.0:
		return "coach_auto_dismiss_sec out of [3.0,12.0], got %f" % coach_auto_dismiss_sec
	if coach_max_defer_sec < 30.0 or coach_max_defer_sec > 600.0:
		return "coach_max_defer_sec out of [30.0,600.0], got %f" % coach_max_defer_sec
	if coach_fade_sec < 0.0 or coach_fade_sec > 0.6:
		return "coach_fade_sec out of [0.0,0.6], got %f" % coach_fade_sec
	if preview_duration_sec < 8.0 or preview_duration_sec > 60.0:
		return "preview_duration_sec out of [8.0,60.0], got %f" % preview_duration_sec
	# Knob-interaction invariant: auto-dismiss (single card lifetime) must be ≪ max-defer
	# (display-window wait) — different axes (Tuning Knobs §Knob 互動).
	if coach_auto_dismiss_sec >= coach_max_defer_sec:
		return "coach_auto_dismiss_sec (%f) must be < coach_max_defer_sec (%f)" % [coach_auto_dismiss_sec, coach_max_defer_sec]
	return ""
