# ScreenEffects — Story 002: Trauma² decay + noise_sample + epsilon short-circuit.
#
# Coverage:
#   AC-05 — trauma=0.6, 1 frame (delta=1/60), decay_rate=12.5 → trauma≈0.391;
#           offset = pow(trauma,2) × MAX_OFFSET_PX × noise(seed).
#   AC-09 — trauma < TRAUMA_EPSILON → skip Formula 1; one-shot clear uniform to ZERO;
#           _trauma_just_zeroed disarmed; second idle tick writes nothing.
#
# noise_sample is deterministic (seeded by accumulated _shake_time, never wall-clock) — the
# test reads back _shake_time post-tick to compute the exact expected offset. _shader_sink is
# an injectable spy (NOT a native RenderingServer override — GUT phantom-pass guard).
extends GutTest

const SE := preload("res://src/autoload/screen_effects.gd")


## Spy shader sink — records last value + write count (proves the one-shot clear).
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
	_sut.set_process(false)  # drive _process manually (deterministic — no auto frame ticks)


# ---------------------------------------------------------------------------
# AC-05 — Trauma² decay one frame
# ---------------------------------------------------------------------------

func test_trauma_squared_decay_one_frame() -> void:
	_sut._trauma = 0.6
	_sut._decay_rate = 12.5
	_sut._shake_time = 0.0
	_sut._process(1.0 / 60.0)
	var expected_trauma: float = maxf(0.0, 0.6 - 12.5 / 60.0)  # ≈ 0.39167
	assert_almost_eq(_sut._trauma, expected_trauma, 0.0005, "AC-05: Trauma² decay = trauma - rate × delta")
	# offset uses the post-increment seed + the decremented trauma.
	var seed: float = _sut._shake_time
	var n := Vector2(sin(seed * 137.0), sin(seed * 211.0))
	var expected := pow(expected_trauma, 2.0) * SE.MAX_OFFSET_PX * n
	assert_almost_eq(_spy.last_value.x, expected.x, 0.001, "AC-05: offset.x = trauma² × MAX_OFFSET_PX × noise.x")
	assert_almost_eq(_spy.last_value.y, expected.y, 0.001, "AC-05: offset.y matches Formula 1")


func test_trauma_decay_clamps_at_zero() -> void:
	_sut._trauma = 0.05
	_sut._decay_rate = 100.0  # huge — would overshoot below 0
	_sut._process(1.0 / 60.0)
	assert_gte(_sut._trauma, 0.0, "AC-05: decay never produces negative trauma (max(0,…))")


# ---------------------------------------------------------------------------
# AC-09 — epsilon short-circuit + one-shot clear
# ---------------------------------------------------------------------------

func test_epsilon_short_circuit_one_shot_clear() -> void:
	# trauma below epsilon, armed (just decayed past the floor) → one-shot ZERO write.
	_sut._trauma = 0.005
	_sut._trauma_just_zeroed = true
	_sut._process(1.0 / 60.0)
	assert_true(_sut._trauma < SE.TRAUMA_EPSILON, "AC-09: trauma is below epsilon")
	assert_eq(_spy.last_value, Vector2.ZERO, "AC-09: one-shot clear writes Vector2.ZERO")
	assert_false(_sut._trauma_just_zeroed, "AC-09: latch disarmed after the one-shot clear")
	var count_after_clear: int = _spy.call_count
	# Second idle tick — still below epsilon, disarmed → no further write.
	_sut._process(1.0 / 60.0)
	assert_eq(_spy.call_count, count_after_clear, "AC-09: latched — no repeat uniform write while idle")


func test_trauma_at_epsilon_boundary_still_evaluates() -> void:
	# boundary is strict `<` — trauma exactly at epsilon is NOT below, so Formula 1 still runs.
	_sut._trauma = SE.TRAUMA_EPSILON
	_sut._decay_rate = 12.5
	_sut._process(1.0 / 60.0)
	# A write happened (offset path, not the elif clear) — call_count incremented.
	assert_eq(_spy.call_count, 1, "AC-09: trauma == epsilon evaluates Formula 1 (boundary is `<`, not `<=`)")
