# ScreenEffects — Story 004: hit pause formulas (max-remaining + ceiling).
#
# Coverage:
#   AC-10 — Formula 3 max-remaining: overlapping pauses do NOT stack/extend; strongest wins.
#   AC-11 — over-MAX_PAUSE_SEC clamps + push_warning; NOT a rejection (counter unchanged).
extends GutTest

const SE := preload("res://src/autoload/screen_effects.gd")

var _sut


func before_each() -> void:
	_sut = SE.new()
	add_child_autofree(_sut)
	await get_tree().process_frame
	_sut._lifecycle_state = SE.LifecycleState.ACTIVE


# ---------------------------------------------------------------------------
# AC-10 — max-remaining (no extend)
# ---------------------------------------------------------------------------

func test_shorter_pause_does_not_shorten_or_extend() -> void:
	_sut._pause_remaining_sec = 0.06
	_sut.hit_pause(0.04)
	assert_almost_eq(_sut._pause_remaining_sec, 0.06, 0.0001,
		"AC-10: max(0.06, 0.04) = 0.06 — shorter new pause neither shortens nor extends")


func test_longer_pause_wins_within_ceiling() -> void:
	_sut._pause_remaining_sec = 0.06
	_sut.hit_pause(0.10)
	assert_almost_eq(_sut._pause_remaining_sec, 0.10, 0.0001,
		"AC-10: max(0.06, 0.10) = 0.10 — longer pause wins, still ≤ MAX_PAUSE_SEC")


# ---------------------------------------------------------------------------
# AC-11 — ceiling clamp + warning (not a rejection)
# ---------------------------------------------------------------------------

func test_over_ceiling_clamps_with_warning_not_rejection() -> void:
	_sut._pause_remaining_sec = 0.0
	var warnings: Array = []
	_sut._warn_sink = func(m): warnings.append(m)
	_sut.hit_pause(0.5)
	assert_almost_eq(_sut._pause_remaining_sec, 0.12, 0.0001, "AC-11: 0.5 clamped to MAX_PAUSE_SEC (0.12)")
	assert_eq(_sut._rejected_calls, 0, "AC-11: over-ceiling is valid-but-clamped, NOT a rejection")
	assert_eq(warnings.size(), 1, "AC-11: a clamp warning is emitted")


func test_exact_ceiling_accepted_no_warning() -> void:
	_sut._pause_remaining_sec = 0.0
	var warnings: Array = []
	_sut._warn_sink = func(m): warnings.append(m)
	_sut.hit_pause(0.12)
	assert_almost_eq(_sut._pause_remaining_sec, 0.12, 0.0001, "AC-11: exactly MAX_PAUSE_SEC accepted")
	assert_eq(warnings.size(), 0, "AC-11: no warning at the inclusive ceiling boundary")
