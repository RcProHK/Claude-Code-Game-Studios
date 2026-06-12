extends GutTest
## Story 003: OnboardingFormulas.resume_state (Formula 3 boot-resume) — all 5 branches +
## completed-first corruption guard (AC-05/EC-08) + four-latch self-heal (EC-09) +
## determinism. Pure static func, GSM-agnostic. See design/gdd/onboarding-flow.md Formula 3.

const F := preload("res://src/core/onboarding_formulas.gd")


# --- Branch coverage ----------------------------------------------------------

func test_fresh_all_false_resolves_welcome() -> void:
	assert_eq(F.resume_state(false, false, false, false, false), F.STATE_WELCOME,
		"all-false (genuine first run) → WELCOME")


func test_connect_done_preview_pending_resolves_preview() -> void:
	# AC-02 — player connected last session, never saw preview → resume PREVIEW.
	assert_eq(F.resume_state(false, true, false, false, false), F.STATE_PREVIEW,
		"AC-02: step_connect done, step_preview pending → PREVIEW")


func test_preview_done_class_pending_resolves_coaching() -> void:
	assert_eq(F.resume_state(false, true, true, false, true), F.STATE_COACHING,
		"connect+preview done, step_class pending → COACHING")


func test_preview_done_first_drop_pending_resolves_coaching() -> void:
	assert_eq(F.resume_state(false, true, true, true, false), F.STATE_COACHING,
		"connect+preview+class done, step_first_drop pending → COACHING")


func test_four_steps_done_completed_unwritten_resolves_complete() -> void:
	# EC-09 — crash window: four latches set but completed unwritten → COMPLETE (self-heal trigger).
	assert_eq(F.resume_state(false, true, true, true, true), F.STATE_COMPLETE,
		"EC-09: four steps set + completed unwritten → COMPLETE (coordinator self-heals)")


# --- completed-first corruption guard (AC-05 / EC-08) -------------------------

func test_completed_wins_over_corrupt_step_latch() -> void:
	# EC-08 — completed==true but a step latch is false (corruption) → still DORMANT (never re-onboard).
	assert_eq(F.resume_state(true, false, false, false, false), F.STATE_DORMANT,
		"AC-05/EC-08: completed-first — corrupt step latch does not re-trigger onboarding")
	assert_eq(F.resume_state(true, true, false, true, false), F.STATE_DORMANT,
		"AC-05/EC-08: completed wins regardless of any step latch combination")


# --- Determinism --------------------------------------------------------------

func test_resume_state_is_deterministic() -> void:
	for i in range(5):
		assert_eq(F.resume_state(false, true, false, false, false), F.STATE_PREVIEW,
			"same input → same output (no time / no randomness)")
