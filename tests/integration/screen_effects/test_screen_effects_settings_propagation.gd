# ScreenEffects — Story 009 AC-24: SettingsManager motion_intensity propagation.
#
# set_motion_intensity(scale) stores immediately; the very next shake() uses the new multiplier
# in Formula 2 (input-side composition). No frame delay between set and effect.
extends GutTest

const SE := preload("res://src/autoload/screen_effects.gd")

var _sut


func before_each() -> void:
	_sut = SE.new()
	add_child_autofree(_sut)
	await get_tree().process_frame
	_sut._lifecycle_state = SE.LifecycleState.ACTIVE


# ---------------------------------------------------------------------------
# AC-24 — setter propagation is live for the next shake
# ---------------------------------------------------------------------------

func test_motion_intensity_propagates_to_next_shake() -> void:
	_sut._motion_intensity = 1.0
	_sut._trauma = 0.0
	_sut.set_motion_intensity(0.5)
	assert_almost_eq(_sut._motion_intensity, 0.5, 0.0001, "AC-24: setter stores the value")
	_sut.shake(0.6, 0.08)
	assert_almost_eq(_sut._trauma, 0.3, 0.0001, "AC-24: next shake uses 0.5 → 0.6 × 0.5 = 0.3 (live propagation)")


func test_motion_intensity_zero_via_settings_kills_shake() -> void:
	_sut._trauma = 0.0
	_sut.set_motion_intensity(0.0)  # full Reduce Motion via settings path
	_sut.shake(0.6, 0.08)
	assert_eq(_sut._trauma, 0.0, "AC-24: settings-driven motion=0 → no shake accrual (mirrors AC-08 via setter path)")


func test_propagation_is_immediate_no_frame_delay() -> void:
	_sut._motion_intensity = 1.0
	_sut._trauma = 0.0
	_sut.set_motion_intensity(0.25)
	_sut.shake(0.8, 0.08)  # immediately after — no await
	assert_almost_eq(_sut._trauma, 0.2, 0.0001, "AC-24: 0.8 × 0.25 = 0.2 with no intervening frame")
