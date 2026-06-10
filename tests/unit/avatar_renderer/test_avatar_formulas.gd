extends GutTest
## Pure-formula unit tests for #26 Avatar Renderer (Formulas 1-5).
## Covers the five must-not-regress guards: AC-04 (specialist not locked),
## AC-08 (epoch-zero), AC-09 (REST_PERIOD lock), AC-10 (monotonic cooldown),
## AC-18 (bfcache resume). Deterministic — no autoload boot, no RNG, no wall-clock.

const CADENCE := 604800
const FIRST_BOOT_GRACE := 172800
const MIN_SESSIONS := 1

func _config() -> AvatarEvolutionConfig:
	return AvatarEvolutionConfig.new()  # canonical @export defaults

# --- Formula 1: dominant_class (AC-03) ---

func test_dominant_class_golden_table() -> void:
	assert_eq(AvatarFormulas.dominant_class(50, 30, 20), &"STRIKE", "STR max")
	assert_eq(AvatarFormulas.dominant_class(30, 50, 20), &"CONTROL", "DEX max")
	assert_eq(AvatarFormulas.dominant_class(20, 30, 50), &"MOBILITY", "VIT max")
	assert_eq(AvatarFormulas.dominant_class(40, 40, 20), &"STRIKE", "STR=DEX tie -> head")
	assert_eq(AvatarFormulas.dominant_class(20, 40, 40), &"CONTROL", "DEX=VIT tie -> CONTROL")
	assert_eq(AvatarFormulas.dominant_class(0, 0, 0), &"STRIKE", "fresh account default")

func test_dominant_class_sanitizes_nan_and_negative() -> void:
	# NaN / negative treated as 0 (EC-SIG-3/4), never crash the tie-break.
	assert_eq(AvatarFormulas.dominant_class(NAN, 10, 5), &"CONTROL", "NaN STR -> 0 -> DEX wins")
	assert_eq(AvatarFormulas.dominant_class(-5, -5, -5), &"STRIKE", "all negative -> 0 -> default")

# --- Formula 2: derive_tier (AC-04 the F-2 fix, AC-05 monotonic) ---

func test_derive_tier_generalist_reaches_t3() -> void:
	assert_eq(AvatarFormulas.derive_tier(102, 34, 6, 2, _config(), 0), 3, "generalist sum>=100 & count>=6")

func test_derive_tier_pure_specialist_not_locked() -> void:
	# THE Pass-4 F-2 regression guard: pure STRIKE specialist reaches T3 via the
	# specialist path WITHOUT being gated by the generalist sum.
	assert_eq(AvatarFormulas.derive_tier(80, 70, 3, 3, _config(), 0), 3, "specialist peak>=70 & depth>=3 -> T3")

func test_derive_tier_early_specialist() -> void:
	assert_eq(AvatarFormulas.derive_tier(45, 40, 2, 2, _config(), 0), 2, "specialist peak>=40 & depth>=2 -> T2")

func test_derive_tier_new_player_t0() -> void:
	assert_eq(AvatarFormulas.derive_tier(20, 12, 0, 0, _config(), 0), 0, "neither path past T0")

func test_derive_tier_monotonic_historical_lock() -> void:
	# computed would be T1 but historical max T2 holds (CR-12 / CF-2 / AC-05).
	assert_eq(AvatarFormulas.derive_tier(55, 30, 2, 1, _config(), 2), 2, "historical T2 lock")

func test_derive_tier_threshold_inclusive() -> void:
	# Exactly on the T1 generalist boundary (sum 30, count 1) is inclusive (EC-TIER-3).
	assert_eq(AvatarFormulas.derive_tier(30, 0, 1, 0, _config(), 0), 1, ">= boundary inclusive")

# --- Formula 3: milestone_gate (AC-08 epoch-zero) ---

func _gate(cur: int, last: int, dlast: int, in_wk: bool, sessions := 5, acct_age := 1_000_000) -> Dictionary:
	# now = acct_age + (last==0 ? 0 : dlast) keeps both branches expressible.
	var now := 2_000_000
	var last_emit := (now - dlast) if last >= 0 and dlast > 0 else 0
	if last == 0 and dlast == 0:
		last_emit = 0
	return AvatarFormulas.milestone_gate(
		cur, last, last_emit, now, now - acct_age, sessions, in_wk,
		CADENCE, FIRST_BOOT_GRACE, MIN_SESSIONS)

func test_milestone_emits_when_all_gates_pass() -> void:
	var r := _gate(2, 1, 800000, false)
	assert_true(r["should_emit"], "promotion + cadence + non-workout -> emit")
	assert_false(r["defer"])

func test_milestone_suppress_no_promotion() -> void:
	var r := _gate(1, 1, 800000, false)
	assert_false(r["should_emit"], "no promotion -> suppress")

func test_milestone_suppress_cadence_only() -> void:
	var r := _gate(2, 1, 300000, false)
	assert_false(r["should_emit"], "cadence not elapsed -> suppress-only")
	assert_false(r["defer"], "EC-MILE-1 suppress is NOT defer")

func test_milestone_defer_in_workout() -> void:
	var r := _gate(2, 1, 800000, true)
	assert_false(r["should_emit"], "workout window -> not emit")
	assert_true(r["defer"], "CR-15 defer")

func test_milestone_epoch_zero_guard() -> void:
	# Fresh account last_emit=0, promotion to T1, but 0 observed sessions -> suppress.
	var r := AvatarFormulas.milestone_gate(
		1, 0, 0, 2_000_000, 2_000_000 - 1000, 0, false,
		CADENCE, FIRST_BOOT_GRACE, MIN_SESSIONS)
	assert_false(r["should_emit"], "epoch-zero: needs >=1 session AND >=48h")

func test_milestone_first_boot_passes_after_grace() -> void:
	# last_emit=0, >=1 session, account older than 48h grace -> emit.
	var r := AvatarFormulas.milestone_gate(
		1, 0, 0, 2_000_000, 2_000_000 - (FIRST_BOOT_GRACE + 10), 1, false,
		CADENCE, FIRST_BOOT_GRACE, MIN_SESSIONS)
	assert_true(r["should_emit"], "first-boot path after grace + session")

# --- Formula 4: hysteresis_can_swap (AC-09 REST lock, AC-10 monotonic) ---

func test_hysteresis_swaps_when_all_gates_pass() -> void:
	assert_true(AvatarFormulas.hysteresis_can_swap(&"CONTROL", &"STRIKE", 400_000, 0, 300, false))

func test_hysteresis_blocks_within_cooldown() -> void:
	assert_false(AvatarFormulas.hysteresis_can_swap(&"CONTROL", &"STRIKE", 120_000, 0, 300, false))

func test_hysteresis_workout_active_lock() -> void:
	assert_false(AvatarFormulas.hysteresis_can_swap(&"CONTROL", &"STRIKE", 400_000, 0, 300, true))

func test_hysteresis_rest_period_lock_f4_drift_guard() -> void:
	# Pass-4 F4 drift regression: REST_PERIOD must lock too (caller passes
	# workout_window_lock=true for REST_PERIOD). v1 wrongly returned true here.
	assert_false(AvatarFormulas.hysteresis_can_swap(&"MOBILITY", &"CONTROL", 400_000, 0, 300, true))

func test_hysteresis_same_class_noop() -> void:
	assert_false(AvatarFormulas.hysteresis_can_swap(&"STRIKE", &"STRIKE", 9_999_000, 0, 300, false))

# --- Formula 5: bfcache_resume_action (AC-18) ---

func test_bfcache_restore_under_threshold() -> void:
	assert_eq(AvatarFormulas.bfcache_resume_action(5000, 30000), AvatarFormulas.RESTORE_SNAPSHOT)

func test_bfcache_restore_inclusive_boundary() -> void:
	assert_eq(AvatarFormulas.bfcache_resume_action(30000, 30000), AvatarFormulas.RESTORE_SNAPSHOT)

func test_bfcache_reset_over_threshold() -> void:
	assert_eq(AvatarFormulas.bfcache_resume_action(30001, 30000), AvatarFormulas.RESET_TO_IDLE_REDERIVE)

func test_bfcache_reset_negative_delta() -> void:
	assert_eq(AvatarFormulas.bfcache_resume_action(-5000, 30000), AvatarFormulas.RESET_TO_IDLE_REDERIVE)
