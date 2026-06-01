# ScreenEffects — Story 007: re-entry guard + Suspended cancel-all + bfcache hardening.
#
# Coverage:
#   AC-16 — _apply_shake re-entry (depth > MAX_EMIT_DEPTH=0) → dropped + counter, no trauma.
#   AC-17 — GSM Suspended → trauma/pause/uniform/paused all reset; state SUSPENDED.
#   AC-18 — bfcache resume (NOTIFICATION_APPLICATION_RESUMED) → reset; delta clamped to 0.1.
#   AC-19 — Booting → shake/hit_pause/set_motion_intensity silently rejected; counter unchanged.
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


func after_each() -> void:
	if get_tree().paused:
		get_tree().paused = false


# ---------------------------------------------------------------------------
# AC-16 — re-entry depth guard (strict MAX_EMIT_DEPTH=0)
# ---------------------------------------------------------------------------

func test_reentry_guard_drops_nested_apply_shake() -> void:
	_sut._motion_intensity = 1.0
	_sut._trauma = 0.0
	_sut._emit_depth = 1  # simulate being inside an outer funnel (Rule 12 strict reject)
	_sut._apply_shake(0.5, 0.08)
	assert_eq(_sut._dropped_by_depth_guard, 1, "AC-16: nested _apply_shake (depth>0) dropped")
	assert_eq(_sut._trauma, 0.0, "AC-16: a dropped re-entry accrues no trauma")
	_sut._emit_depth = 0


func test_first_call_at_depth_zero_succeeds() -> void:
	_sut._motion_intensity = 1.0
	_sut._trauma = 0.0
	_sut._apply_shake(0.5, 0.08)  # depth 0 → proceeds, unwinds to 0
	assert_almost_eq(_sut._trauma, 0.5, 0.0001, "AC-16: outer (depth 0) call succeeds")
	assert_eq(_sut._dropped_by_depth_guard, 0, "AC-16: no drop for the legitimate outer call")
	assert_eq(_sut._emit_depth, 0)


# ---------------------------------------------------------------------------
# AC-17 — Suspended cancel-all
# ---------------------------------------------------------------------------

func test_suspended_cancels_everything() -> void:
	_sut._trauma = 0.5
	_sut._pause_remaining_sec = 0.03
	get_tree().paused = true
	_sut._on_gsm_state_changed(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.SUSPENDED, null)
	assert_eq(_sut._trauma, 0.0, "AC-17: trauma cleared")
	assert_eq(_sut._pause_remaining_sec, 0.0, "AC-17: pending pause cleared")
	assert_eq(_spy.last_value, Vector2.ZERO, "AC-17: shader uniform reset to ZERO")
	assert_false(get_tree().paused, "AC-17: freeze released")
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.SUSPENDED, "AC-17: state SUSPENDED")


func test_resume_from_suspended_returns_active() -> void:
	_sut._lifecycle_state = SE.LifecycleState.SUSPENDED
	_sut._on_gsm_state_changed(GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.IDLE, null)
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.ACTIVE, "AC-17: non-Suspended transition resumes Active")


# ---------------------------------------------------------------------------
# AC-18 — bfcache resume + delta clamp
# ---------------------------------------------------------------------------

func test_bfcache_resume_resets_and_clamps_delta() -> void:
	_sut._trauma = 0.5
	_sut._pause_remaining_sec = 0.04
	_sut._notification(SE.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(_sut._trauma, 0.0, "AC-18: no residual shake survives resume")
	assert_eq(_sut._pause_remaining_sec, 0.0, "AC-18: no pending pause carried across resume")
	_sut.set_process(false)
	_sut._process(8.0)  # huge bfcache-gap delta
	assert_almost_eq(_sut._last_clamped_delta, SE.MAX_FRAME_DELTA, 0.0001,
		"AC-18: delta clamped to MAX_FRAME_DELTA (0.1), not 8.0")


# ---------------------------------------------------------------------------
# AC-19 — Booting silent reject
# ---------------------------------------------------------------------------

func test_booting_silently_rejects_without_counting() -> void:
	_sut._lifecycle_state = SE.LifecycleState.BOOTING
	_sut._trauma = 0.0
	_sut._pause_remaining_sec = 0.0
	_sut._motion_intensity = 1.0
	_sut.shake(0.6, 0.08)
	_sut.hit_pause(0.06)
	_sut.set_motion_intensity(0.5)
	assert_eq(_sut._trauma, 0.0, "AC-19: no trauma in Booting")
	assert_eq(_sut._pause_remaining_sec, 0.0, "AC-19: no pause in Booting")
	assert_eq(_sut._rejected_calls, 0, "AC-19: Booting reject is SILENT (EC-07) — distinct from input-reject")
	assert_almost_eq(_sut._motion_intensity, 1.0, 0.0001, "AC-19: set_motion_intensity ignored in Booting (retain default)")
