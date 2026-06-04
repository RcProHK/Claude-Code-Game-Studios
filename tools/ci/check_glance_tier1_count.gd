#!/usr/bin/env -S godot --headless --script
## CI Lint — Gym-Mode HUD glance Tier-1 budget (Story 009, GDD AC-U-3 + B7 alpha invariant)
##
## Enforces the design-time glance budget so a future matrix edit cannot silently push more
## than the allowed glance-visible elements into the peripheral band (Pillar 2 anti-pattern ③
## "cockpit"). Counts elements whose effective alpha is ABOVE the deep-dim threshold per state.
##
## Scope (GDD AC-U-3): only the three counted states are exact-checked —
##   WORKOUT_ACTIVE == 3, COMBAT_ACTIVE == 3, BOSS_ENCOUNTER == 4.
## The other 6 states are exempt by state-rule (REST_PERIOD focus window, SUSPENDED/DISCONNECTED/
## LOOT_DROP dim, IDLE ambient, BOOTING not rendered) and are NOT per-element counted here.
##
## Also boot-asserts the alpha 3-axis invariant (B7): deep_dim < threshold < ambient.
##
## Usage:
##   godot --headless --script tools/ci/check_glance_tier1_count.gd
##
## Exit codes:
##   0 = budget satisfied + invariant holds
##   1 = a counted state exceeds/mismatches its exact budget, or the alpha invariant fails
##   2 = internal error (HUD script missing / cannot instantiate)
##
## Governing docs: design/gdd/gym-mode-hud.md AC-U-3 / EC-S7 / B7; ADR-0001 CI family.
extends SceneTree


const HUD_SCRIPT_PATH: String = "res://src/ui/gym_mode_hud/gym_mode_hud.gd"

## GSM GameState enum ordinals (game_state_machine.gd: BOOTING0 DISCONNECTED1 IDLE2
## WORKOUT_ACTIVE3 REST_PERIOD4 COMBAT_ACTIVE5 BOSS_ENCOUNTER6 LOOT_DROP7 SUSPENDED8).
## Hardcoded ordinals keep this tool independent of autoload availability.
const EXPECTED_COUNT: Dictionary = {
	3: 3,  # WORKOUT_ACTIVE
	5: 3,  # COMBAT_ACTIVE
	6: 4,  # BOSS_ENCOUNTER
}


func _init() -> void:
	if not ResourceLoader.exists(HUD_SCRIPT_PATH):
		push_error("[check_glance_tier1_count] HUD script not found at %s" % HUD_SCRIPT_PATH)
		quit(2)
		return

	var hud_script: GDScript = load(HUD_SCRIPT_PATH)
	if hud_script == null:
		push_error("[check_glance_tier1_count] failed to load HUD script")
		quit(2)
		return

	var hud: Object = hud_script.new()
	if hud == null:
		push_error("[check_glance_tier1_count] failed to instantiate HUD")
		quit(2)
		return

	# Build the matrix without entering the tree (avoids autoload signal wiring).
	hud._build_state_matrix()

	var failures: Array[String] = []

	var tier1_max: int = hud.GLANCE_TIER1_MAX
	for state: int in EXPECTED_COUNT:
		var expected: int = EXPECTED_COUNT[state]
		var actual: int = hud.get_glance_tier1_count(state)
		if actual != expected:
			failures.append("state %d: glance Tier-1 count == %d, expected exactly %d (AC-U-3)" % [state, actual, expected])
		if actual > tier1_max:
			failures.append("state %d: glance Tier-1 count %d exceeds GLANCE_TIER1_MAX %d" % [state, actual, tier1_max])

	if not hud.alpha_invariants_hold():
		failures.append("alpha invariant FAILED: deep_dim(%.2f) < threshold(%.2f) < ambient(%.2f) does not hold" % [
			hud.DEEP_DIM_ELEMENT_ALPHA, hud.DEEP_DIM_ALPHA_THRESHOLD, hud.AMBIENT_ALPHA,
		])

	if hud is RefCounted:
		pass  # ref-counted auto-frees
	else:
		hud.free()

	if failures.is_empty():
		print("[check_glance_tier1_count] PASS: 3 counted states within exact budget; alpha invariant holds")
		quit(0)
		return

	for f: String in failures:
		printerr("[check_glance_tier1_count] %s" % f)
	printerr("[check_glance_tier1_count] FAIL: %d violation(s). See GDD AC-U-3 / B7." % failures.size())
	quit(1)
