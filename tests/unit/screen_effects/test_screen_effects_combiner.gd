# ScreenEffects — Story 003: trauma combiner + motion composition + hierarchy invariant.
#
# Coverage:
#   AC-06 — additive combiner min(1.0, old+new); decay_rate monotonic non-decreasing.
#   AC-07 — 8× HIT_HEAVY saturates trauma at 1.0; shader offset never exceeds MAX_OFFSET_PX.
#   AC-08 — motion_intensity=0 → shake zero-accrual + uniform ZERO; hit_pause still fires.
#   AC-26 — PARRY amplitude ≥ 2× HIT_HEAVY (AC-D6 hierarchy gap); LOOT_RARE_BURST raw² > epsilon.
extends GutTest

const SE := preload("res://src/autoload/screen_effects.gd")


class _ShaderSpy:
	extends RefCounted
	var last_value: Variant = null
	var call_count: int = 0
	func sink(_uniform: StringName, value: Variant) -> void:
		last_value = value
		call_count += 1


var _sut
var _spy: _ShaderSpy


func before_each() -> void:
	_spy = _ShaderSpy.new()
	_sut = SE.new()
	_sut._shader_sink = _spy.sink
	add_child_autofree(_sut)
	await get_tree().process_frame
	_sut._lifecycle_state = SE.LifecycleState.ACTIVE
	_sut.set_process(false)


# ---------------------------------------------------------------------------
# AC-06 — additive combiner + monotonic decay_rate
# ---------------------------------------------------------------------------

func test_additive_combiner_and_monotonic_decay_rate() -> void:
	_sut._motion_intensity = 1.0
	_sut._trauma = 0.4
	_sut._decay_rate = 12.5
	_sut.shake(0.4, 0.12)
	assert_almost_eq(_sut._trauma, 0.8, 0.0001, "AC-06: additive min(1.0, 0.4+0.4) = 0.8")
	assert_almost_eq(_sut._decay_rate, 12.5, 0.0001,
		"AC-06: decay_rate = max(existing 12.5, new 8.33) = 12.5 (monotonic non-decreasing)")


func test_faster_shake_raises_decay_rate() -> void:
	_sut._motion_intensity = 1.0
	_sut._decay_rate = 8.0
	_sut.shake(0.4, 0.04)  # 1/0.04 = 25 > 8 → decay_rate rises
	assert_almost_eq(_sut._decay_rate, 25.0, 0.0001, "AC-06: a faster (shorter) shake raises decay_rate")


# ---------------------------------------------------------------------------
# AC-07 — saturation + budget cap
# ---------------------------------------------------------------------------

func test_eight_hit_heavy_saturates_and_caps_offset() -> void:
	_sut._motion_intensity = 1.0
	_sut._trauma = 0.0
	for _i in 8:
		_sut.shake(0.4, 0.12)
	assert_almost_eq(_sut._trauma, 1.0, 0.0001, "AC-07: 8 × 0.4 saturates at 1.0 (not 3.2)")
	_sut._process(1.0 / 60.0)
	assert_lte(absf(_spy.last_value.x), SE.MAX_OFFSET_PX + 0.0001, "AC-07: offset.x ≤ MAX_OFFSET_PX")
	assert_lte(absf(_spy.last_value.y), SE.MAX_OFFSET_PX + 0.0001, "AC-07: offset.y ≤ MAX_OFFSET_PX")


# ---------------------------------------------------------------------------
# AC-08 — motion=0 shake bypass, hit_pause alive
# ---------------------------------------------------------------------------

func test_motion_zero_bypasses_shake_but_hit_pause_fires() -> void:
	_sut._motion_intensity = 0.0
	_sut._trauma = 0.0
	_sut._pause_remaining_sec = 0.0
	_sut.shake(0.6, 0.08)
	assert_eq(_sut._trauma, 0.0, "AC-08: motion=0 → zero trauma accrual (Reduce Motion full off)")
	assert_eq(_spy.last_value, Vector2.ZERO, "AC-08: motion=0 latch-clears the uniform to ZERO")
	_sut.hit_pause(0.06)
	assert_almost_eq(_sut._pause_remaining_sec, 0.06, 0.0001,
		"AC-08: hit_pause is NOT gated by motion_intensity (time perturbation ≠ vestibular)")


# ---------------------------------------------------------------------------
# AC-26 — hierarchy gap (pure arithmetic)
# ---------------------------------------------------------------------------

func test_peripheral_hierarchy_gap() -> void:
	var amp_parry: float = pow(0.6, 2.0) * SE.MAX_OFFSET_PX   # 1.44
	var amp_heavy: float = pow(0.4, 2.0) * SE.MAX_OFFSET_PX   # 0.64
	assert_gte(amp_parry, 2.0 * amp_heavy, "AC-26: PARRY amplitude ≥ 2× HIT_HEAVY (1.44 ≥ 1.28, AC-D6)")
	assert_gt(pow(0.2, 2.0), SE.TRAUMA_EPSILON, "AC-26: LOOT_RARE_BURST raw² (0.04) > TRAUMA_EPSILON (0.01)")
