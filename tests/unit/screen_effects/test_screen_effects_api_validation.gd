# ScreenEffects — Story 001: API surface + input validation.
#
# Coverage:
#   AC-01 — shake() in Active funnels through _apply_shake; trauma += intensity × motion_intensity.
#   AC-02 — hit_pause(0.0) / hit_pause(-0.5) rejected + _rejected_calls; _pause_remaining_sec unchanged.
#   AC-03 — set_motion_intensity(1.5) silent clamp 1.0 (no counter); set_motion_intensity(NaN) reject + retain.
#   AC-04 — shake(NaN|±INF, ...) rejected + _rejected_calls += 1 per malformed call.
#
# Autoload has no class_name — preload the script. push_warning not directly assertable →
# use the _rejected_calls counter as the observable proxy (do NOT capture stderr).
extends GutTest

const SE := preload("res://src/autoload/screen_effects.gd")

var _sut


func before_each() -> void:
	_sut = SE.new()
	add_child_autofree(_sut)
	await get_tree().process_frame
	_sut._lifecycle_state = SE.LifecycleState.ACTIVE  # qa-lead precondition: force Active


# ---------------------------------------------------------------------------
# AC-01 — shake funnels + motion scaling
# ---------------------------------------------------------------------------

func test_shake_funnels_and_accrues_trauma() -> void:
	_sut._motion_intensity = 1.0
	_sut._trauma = 0.0
	_sut.shake(0.6, 0.08)
	assert_almost_eq(_sut._trauma, 0.6, 0.0001, "AC-01: trauma += 0.6 × motion_intensity(1.0)")
	assert_eq(_sut._rejected_calls, 0, "AC-01: a valid shake is not a rejection")
	assert_eq(_sut._emit_depth, 0, "AC-01: funnel entered and exited once (_emit_depth back to 0)")


# ---------------------------------------------------------------------------
# AC-02 — non-positive hit_pause rejected
# ---------------------------------------------------------------------------

func test_hit_pause_zero_and_negative_rejected() -> void:
	_sut._pause_remaining_sec = 0.0
	_sut.hit_pause(0.0)
	_sut.hit_pause(-0.5)
	assert_eq(_sut._pause_remaining_sec, 0.0, "AC-02: non-positive duration must not arm the pause")
	assert_eq(_sut._rejected_calls, 2, "AC-02: one rejection per non-positive call")


func test_hit_pause_smallest_positive_accepted() -> void:
	_sut._pause_remaining_sec = 0.0
	_sut.hit_pause(0.001)
	assert_gt(_sut._pause_remaining_sec, 0.0, "AC-02: smallest positive duration is accepted")
	assert_eq(_sut._rejected_calls, 0, "AC-02: a positive duration is not a rejection")


# ---------------------------------------------------------------------------
# AC-03 — motion_intensity clamp vs reject
# ---------------------------------------------------------------------------

func test_set_motion_intensity_overshoot_silent_clamp() -> void:
	_sut._motion_intensity = 1.0
	_sut.set_motion_intensity(1.5)
	assert_almost_eq(_sut._motion_intensity, 1.0, 0.0001, "AC-03: 1.5 silently clamped to 1.0")
	assert_eq(_sut._rejected_calls, 0, "AC-03: in-range overshoot is a silent clamp, NOT a rejection")


func test_set_motion_intensity_negative_silent_clamp() -> void:
	_sut.set_motion_intensity(-0.3)
	assert_almost_eq(_sut._motion_intensity, 0.0, 0.0001, "AC-03: -0.3 silently clamped to 0.0 (valid Reduce Motion)")
	assert_eq(_sut._rejected_calls, 0, "AC-03: negative in-range overshoot is silent")


func test_set_motion_intensity_nan_rejected_retains_prior() -> void:
	_sut.set_motion_intensity(0.7)  # establish a valid prior value
	_sut.set_motion_intensity(NAN)
	assert_almost_eq(_sut._motion_intensity, 0.7, 0.0001, "AC-03: NaN must NOT overwrite the prior valid value")
	assert_eq(_sut._rejected_calls, 1, "AC-03: NaN is a rejection (counter increments)")


# ---------------------------------------------------------------------------
# AC-04 — malformed shake rejected
# ---------------------------------------------------------------------------

func test_shake_nan_and_inf_rejected() -> void:
	_sut._trauma = 0.0
	_sut.shake(NAN, 0.08)
	_sut.shake(0.6, NAN)
	_sut.shake(INF, 0.08)
	_sut.shake(-INF, 0.08)
	assert_eq(_sut._trauma, 0.0, "AC-04: no trauma accrues from any rejected shake")
	assert_eq(_sut._rejected_calls, 4, "AC-04: one increment per malformed call (both arg positions + both INF signs)")
