extends GutTest
## Story 006: OnboardingFormulas.is_dismissed / is_visible (Formula 2 auto-dismiss + tap) —
## AC-11 auto-dismiss boundary, AC-12 tap-priority, integer-ms determinism. All comparisons
## integer ms (knob float-sec → int(sec*1000) at load). See design/gdd/onboarding-flow.md Formula 2.

const F := preload("res://src/core/onboarding_formulas.gd")

const AUTO_MS := 6000  # int(coach_auto_dismiss_sec 6.0 * 1000)
const SHOWN_AT := 10000


# --- AC-11 — auto-dismiss countdown -------------------------------------------

func test_auto_dismiss_fires_at_threshold() -> void:
	# Boundary: now - shown == 6000 → dismissed (>=).
	assert_true(F.is_dismissed(SHOWN_AT + AUTO_MS, SHOWN_AT, AUTO_MS, false),
		"AC-11: elapsed == COACH_AUTO_DISMISS_MS → dismissed (>= boundary)")


func test_auto_dismiss_fires_past_threshold() -> void:
	assert_true(F.is_dismissed(SHOWN_AT + AUTO_MS + 1, SHOWN_AT, AUTO_MS, false),
		"AC-11: elapsed > threshold → dismissed")


func test_not_dismissed_before_threshold() -> void:
	assert_false(F.is_dismissed(SHOWN_AT + AUTO_MS - 1, SHOWN_AT, AUTO_MS, false),
		"AC-11: elapsed < threshold and not tapped → still visible")


# --- AC-12 — tap priority -----------------------------------------------------

func test_tap_dismisses_before_timer() -> void:
	# now well before the auto threshold, but tapped → dismissed immediately (player-led, Pillar 2).
	assert_true(F.is_dismissed(SHOWN_AT + 2000, SHOWN_AT, AUTO_MS, true),
		"AC-12: tap dismisses immediately, ahead of the auto timer")


func test_no_tap_no_timeout_stays_visible() -> void:
	assert_false(F.is_dismissed(SHOWN_AT + 2000, SHOWN_AT, AUTO_MS, false),
		"AC-12: same time without tap → not yet dismissed")


# --- is_visible composition ---------------------------------------------------

func test_visible_is_shown_and_not_dismissed() -> void:
	assert_true(F.is_visible(true, SHOWN_AT + 2000, SHOWN_AT, AUTO_MS, false),
		"shown + not dismissed → visible")
	assert_false(F.is_visible(true, SHOWN_AT + AUTO_MS, SHOWN_AT, AUTO_MS, false),
		"shown + dismissed → not visible")
	assert_false(F.is_visible(false, SHOWN_AT, SHOWN_AT, AUTO_MS, false),
		"not shown → not visible regardless")


# --- Determinism --------------------------------------------------------------

func test_integer_ms_deterministic() -> void:
	for i in range(5):
		assert_false(F.is_dismissed(SHOWN_AT + AUTO_MS - 1, SHOWN_AT, AUTO_MS, false),
			"integer-ms comparison is deterministic — no float boundary flake")
