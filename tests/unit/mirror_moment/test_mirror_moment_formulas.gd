extends GutTest
## Story 003/004/007: pure #29 gating/selection formulas (Formula 1/2/3 + CR-M12 resume).
## All inputs supplied by the caller — these functions NEVER derive a tier (CI-MM-1).
## Covers AC-01 (arm gate), AC-05/06/07/08 (content selection + priority), AC-12 (first-ever
## ghost), and the AC-18 resume continue-vs-collapse logic. See mirror-moment.md Formulas.

const F := preload("res://src/core/mirror_moment_formulas.gd")
const CADENCE := 604800


# --- Formula 1 — ceremony_arm_check (AC-01) -----------------------------------

func test_arm_when_cadence_open_and_pending() -> void:
	# GDD table row 1: Δ=700000 > 604800, pending → arm.
	assert_true(F.ceremony_arm_check(1_000_000, 300_000, CADENCE, true, false),
		"AC-01: cadence open + tier-up pending → should_arm")


func test_arm_when_cadence_open_and_micro_only() -> void:
	assert_true(F.ceremony_arm_check(1_000_000, 300_000, CADENCE, false, true),
		"AC-01: cadence open + micro-only change → should_arm (REFLECTION-eligible)")


func test_no_arm_when_no_change() -> void:
	assert_false(F.ceremony_arm_check(1_000_000, 300_000, CADENCE, false, false),
		"AC-01: cadence open but zero change → no arm (CR-M15 honest skip)")


func test_no_arm_when_cadence_unmet() -> void:
	# Δ=300000 < 604800 — window already presented this cycle.
	assert_false(F.ceremony_arm_check(600_000, 300_000, CADENCE, true, true),
		"AC-01: cadence window not yet reopened → no re-present even with change")


func test_cadence_open_boundary_is_inclusive() -> void:
	assert_true(F.cadence_open(604_800, 0, CADENCE), "exactly one window elapsed → open")
	assert_false(F.cadence_open(604_799, 0, CADENCE), "one second short → closed")


# --- Formula 2 — content_tier_selection (AC-05/06/07/08) ----------------------

func test_content_evolution_when_pending() -> void:
	assert_eq(F.content_tier_selection(true, false), F.CONTENT_EVOLUTION,
		"AC-05: pending tier-up → EVOLUTION")


func test_content_reflection_when_micro_only() -> void:
	assert_eq(F.content_tier_selection(false, true), F.CONTENT_REFLECTION,
		"AC-06: micro-only week → REFLECTION")


func test_content_none_when_no_change() -> void:
	assert_eq(F.content_tier_selection(false, false), F.CONTENT_NONE,
		"AC-07: zero change → NONE (defense-in-depth honest skip)")


func test_content_evolution_priority_over_reflection() -> void:
	assert_eq(F.content_tier_selection(true, true), F.CONTENT_EVOLUTION,
		"AC-08: both tier-up and micro → EVOLUTION wins (tier-up shadows micro)")


# --- Formula 3 — should_show_ghost (AC-12 / EC-MM-7/9) ------------------------

func test_ghost_when_evolution_with_real_prior() -> void:
	assert_true(F.should_show_ghost(F.CONTENT_EVOLUTION, 1, 2, "res://after.tres"),
		"EVOLUTION T1→T2 with a prior sprite → before→after ghost")


func test_ghost_collapse_jumps_intermediate_tiers() -> void:
	assert_true(F.should_show_ghost(F.CONTENT_EVOLUTION, 0, 3, "res://t0.tres"),
		"CR-M5 collapse: T0→T3 still a single ghost (prior=last-ceremonied)")


func test_no_ghost_first_ever_tier_up() -> void:
	assert_false(F.should_show_ghost(F.CONTENT_EVOLUTION, 0, 1, ""),
		"AC-12/EC-MM-7: first-ever tier-up (empty prior sprite) → no ghost, no crash")


func test_no_ghost_for_reflection_same_tier() -> void:
	assert_false(F.should_show_ghost(F.CONTENT_REFLECTION, 2, 2, "res://t2.tres"),
		"EC-MM-9: REFLECTION same tier → single frame, no ghost")


# --- CR-M12 — resume_action (AC-18 logic) -------------------------------------

func test_resume_continue_within_threshold() -> void:
	assert_eq(F.resume_action(15_000, 30_000), F.RESUME_CONTINUE,
		"AC-18: Δ ≤ 30s → continue the frozen ceremony")


func test_resume_continue_at_exact_threshold() -> void:
	assert_eq(F.resume_action(30_000, 30_000), F.RESUME_CONTINUE,
		"AC-18: Δ == threshold is inclusive → continue")


func test_resume_collapse_over_threshold() -> void:
	assert_eq(F.resume_action(31_000, 30_000), F.RESUME_COLLAPSE,
		"AC-18: Δ > 30s → collapse + keep window marker")


func test_resume_collapse_on_negative_delta() -> void:
	assert_eq(F.resume_action(-5_000, 30_000), F.RESUME_COLLAPSE,
		"AC-18: negative delta (untrusted clock) → collapse")
