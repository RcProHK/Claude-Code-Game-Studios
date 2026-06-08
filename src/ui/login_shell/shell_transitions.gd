## ShellTransitions — #24 shell cross-fade transition helper (story 003 scaffold).
##
## Driving GDD: design/gdd/login-gymsys-connection-ui.md Rule 14 (ScreenLifecycleFsm)
## + States table (claim success → cross-fade to landing state).
## Owner: LoginShellCoordinator (#24) — a plain logic helper (RefCounted), NOT a node
## and NOT an autoload.
##
## Why a separate file (AC-01 / AC-35a): this is where the LEGITIMATE animated
## transition lives — the state-to-state cross-fade between shell states. Splitting
## it out keeps the AC-35a banner-static grep (banner_stack.gd is zero-animation)
## from ever mistaking a valid shell cross-fade for a forbidden banner pulse. The
## banner is static; shell transitions are animated — different files, different rules.
##
## SCAFFOLD SCOPE: cross-fade timing constant + a pure progress helper only. Story 004
## wires this into the 5-state ScreenLifecycleFsm dispatch (injected-clock timing
## discipline — no engine Tween for state-bearing timing, #22/#23 precedent).
extends RefCounted

## Cross-fade duration knob (GDD Tuning Knobs — shell state transition). Data-driven
## default; story 004 may relocate to a config resource.
const CROSS_FADE_MS: float = 200.0


## Pure cross-fade progress (0.0 → 1.0) for a given elapsed time. Story 004 drives an
## injected clock through here. Clamped; deterministic; no side effects.
static func cross_fade_alpha(elapsed_ms: float) -> float:
	if CROSS_FADE_MS <= 0.0:
		return 1.0
	return clampf(elapsed_ms / CROSS_FADE_MS, 0.0, 1.0)
