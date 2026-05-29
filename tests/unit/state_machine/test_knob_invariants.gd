# GameStateMachine — Story 005 AC-17a/20a/knob-1 Knob Invariants
#
# Scope: verifies the ADR-0006 Contract 8 boot-time knob invariant assertions.
#
# AC-17a: default knob values pass all 8 invariants without crash
# AC-20a: violating Invariant 1 (FALLBACK > MIN_REVEAL × 100) trips assert
# AC-gsm-knob-1: ATTEMPT_CAP must equal 30 (Invariant 5 — FIXED constant)
#
# Test strategy: GUT cannot directly capture `assert()` violations because
# debug-build assert crashes the engine. Tests verify (a) the constants are at
# safe-range values, (b) the runtime invariants ALL hold for production
# defaults, and (c) the documented invariant math is correct (i.e., if a
# designer were to set FALLBACK=1500, the assertion expression would evaluate
# false). The actual crash behavior is engine-level and validated implicitly:
# autoload boot must succeed in CI for any other GSM test to run.
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 8 (Knob Invariants)
extends GutTest


# ===========================================================================
# AC-17a: production defaults — all 8 invariants must hold
# ===========================================================================

func test_gsm_invariant1_fallback_less_than_or_equal_min_reveal_times_100() -> void:
	# Invariant 1: STATE_TRANSITION_FALLBACK_MS ≤ MIN_REVEAL_WINDOW_SECONDS × 100
	assert_true(
		GameStateMachine.STATE_TRANSITION_FALLBACK_MS <=
			GameStateMachine.MIN_REVEAL_WINDOW_SECONDS * 100,
		"Production defaults must satisfy Invariant 1 (1000 ≤ 15 × 100 = 1500)"
	)


func test_gsm_invariant2_tombstone_ttl_strictly_less_than_suspension_ttl() -> void:
	# Invariant 2: TOMBSTONE_TTL_SECONDS < SUSPENSION_TTL_SECONDS (strict)
	assert_true(
		GameStateMachine.TOMBSTONE_TTL_SECONDS < GameStateMachine.SUSPENSION_TTL_SECONDS,
		"Invariant 2: tombstone TTL must be strictly less than suspension TTL"
	)


func test_gsm_invariant3_loot_soft_ttl_strictly_less_than_hard_cap() -> void:
	# Invariant 3: LOOTDROP_PENDING_TTL_DAYS < LOOTDROP_PENDING_HARD_CAP_DAYS
	assert_true(
		GameStateMachine.LOOTDROP_PENDING_TTL_DAYS <
			GameStateMachine.LOOTDROP_PENDING_HARD_CAP_DAYS,
		"Invariant 3: loot soft TTL must be strictly less than hard cap"
	)


func test_gsm_invariant4_base_delay_positive_and_retry_cap_geq_base() -> void:
	# Invariant 4a: BASE_DELAY > 0
	assert_gt(GameStateMachine.BASE_DELAY, 0.0, "Invariant 4a: BASE_DELAY must be > 0")
	# Invariant 4b: RETRY_CAP ≥ BASE_DELAY
	assert_true(
		GameStateMachine.RETRY_CAP >= GameStateMachine.BASE_DELAY,
		"Invariant 4b: RETRY_CAP must be ≥ BASE_DELAY"
	)


# ===========================================================================
# AC-gsm-knob-1: ATTEMPT_CAP must equal 30 (Invariant 5 — FIXED constant)
# ===========================================================================

func test_gsm_invariant5_attempt_cap_is_fixed_at_30() -> void:
	# Invariant 5: ATTEMPT_CAP == 30 (IEEE 754 overflow guard for 2^n in
	# Formula 1 backoff — changing this requires ADR revision)
	assert_eq(
		GameStateMachine.ATTEMPT_CAP,
		30,
		"AC-gsm-knob-1 (Invariant 5): ATTEMPT_CAP must be exactly 30 (IEEE 754 guard)"
	)


func test_gsm_invariant6_weekly_tick_catchup_at_most_52() -> void:
	# Invariant 6: MAX_WEEKLY_TICK_CATCHUP ≤ 52 (1-year sanity ceiling)
	assert_true(
		GameStateMachine.MAX_WEEKLY_TICK_CATCHUP <= 52,
		"Invariant 6: MAX_WEEKLY_TICK_CATCHUP must be ≤ 52 (1 year max)"
	)


# ===========================================================================
# AC-17a (continued): cross-system invariant — PersistenceLayer drift tolerance
# ===========================================================================

func test_gsm_invariant7_persistence_layer_drift_tolerance_positive() -> void:
	# Invariant 7: PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS > 0
	# (cross-system check — GSM uses is_expired() which depends on this)
	assert_gt(
		PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS,
		0,
		"Invariant 7: PersistenceLayer drift tolerance must be > 0"
	)


# ===========================================================================
# AC-20a: invariant 1 math validation — if a designer set FALLBACK=1500,
# the assertion expression would evaluate false (i.e., the invariant is
# correctly formulated to catch the documented violation case).
# ===========================================================================

func test_gsm_ac20a_invariant1_math_catches_violating_value() -> void:
	# This test does NOT mutate the constant (can't change a `const`). Instead
	# we simulate the Invariant 1 assertion math with a hypothetical violating
	# FALLBACK value to prove the assertion expression is correct.
	var hypothetical_violating_fallback: int = 1500
	var min_reveal: int = GameStateMachine.MIN_REVEAL_WINDOW_SECONDS  # default 15
	var assertion_would_pass: bool = hypothetical_violating_fallback <= min_reveal * 100
	# 1500 ≤ 15 × 100 = 1500 → TRUE (boundary). Now test the violation case:
	var clearly_violating_fallback: int = 1501
	var clearly_violating_passes: bool = clearly_violating_fallback <= min_reveal * 100
	assert_false(
		clearly_violating_passes,
		"AC-20a: FALLBACK=1501 with default MIN_REVEAL=15 must FAIL Invariant 1"
	)
	# Verify our default is safe:
	var default_passes: bool = GameStateMachine.STATE_TRANSITION_FALLBACK_MS <=
		GameStateMachine.MIN_REVEAL_WINDOW_SECONDS * 100
	assert_true(default_passes, "Production defaults must always pass Invariant 1")


# ===========================================================================
# AC-17a final: boot succeeded — implicit proof all 8 invariants held
# (if any had failed at _ready(), the autoload would have crashed and no
# test in this file could run).
# ===========================================================================

func test_gsm_autoload_boot_succeeded_proves_all_invariants_passed() -> void:
	# If we got here, _ready() ran to completion → _assert_knob_invariants()
	# returned without tripping any assert. This is the strongest end-to-end
	# proof that all 8 production-default invariants hold.
	assert_not_null(GameStateMachine, "GameStateMachine autoload must be accessible")
	assert_eq(
		GameStateMachine.get_current_state(),
		GameStateMachine.GameState.BOOTING,
		"Autoload boot completed without invariant trip — all 8 defaults safe"
	)
