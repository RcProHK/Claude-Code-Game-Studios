# CameraController — Story 006: focal state gating + re-entry guard + force-clear.
#
# Coverage:
#   AC-16 — second request_focal during active Focal → reject + _focal_reentry_dropped_count++.
#   AC-19 — GSM non-(BOSS_ENCOUNTER/LOOT_DROP) → request_focal rejected + gating counter++.
#   AC-20 — GSM leaves focal-allowed state mid-Focal → force-clear (snap, skip exit tween).
extends GutTest

const SE := preload("res://src/autoload/camera_controller.gd")


class _CameraStub:
	extends Node2D
	var zoom: Vector2 = Vector2.ONE
	var position_smoothing_enabled: bool = false
	var position_smoothing_speed: float = 5.0


class _MockGSM:
	extends RefCounted
	var current_state: int = GameStateMachine.GameState.IDLE
	func connect_for_initial_state(_cb: Callable) -> void:
		pass


var _sut
var _cam: _CameraStub
var _avatar: Node2D
var _gsm: _MockGSM


func before_each() -> void:
	_sut = SE.new()
	add_child_autofree(_sut)
	await get_tree().process_frame
	_cam = _CameraStub.new()
	_avatar = Node2D.new()
	add_child_autofree(_cam)
	add_child_autofree(_avatar)
	_gsm = _MockGSM.new()
	_sut._gsm = _gsm
	_sut.register_camera(_cam)
	_sut.set_follow_target(_avatar)


func after_each() -> void:
	if get_tree().paused:
		get_tree().paused = false


# ---------------------------------------------------------------------------
# AC-16 — re-entry strict reject
# ---------------------------------------------------------------------------

func test_reentry_during_focal_rejected() -> void:
	_gsm.current_state = GameStateMachine.GameState.BOSS_ENCOUNTER
	_sut.request_focal(Vector2(100, 0))
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.FOCAL, "first request enters Focal")
	_sut.request_focal(Vector2(200, 0))  # re-entry
	assert_eq(_sut._focal_reentry_dropped_count, 1, "AC-16: second request rejected (strict depth 0)")
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.FOCAL, "AC-16: still in the original Focal")


# ---------------------------------------------------------------------------
# AC-19 — GSM gating (parametric over non-focal states)
# ---------------------------------------------------------------------------

func test_focal_rejected_in_non_focal_states() -> void:
	var non_focal := [
		GameStateMachine.GameState.IDLE,
		GameStateMachine.GameState.WORKOUT_ACTIVE,
		GameStateMachine.GameState.REST_PERIOD,
		GameStateMachine.GameState.COMBAT_ACTIVE,
	]
	var rejects := 0
	for state in non_focal:
		_gsm.current_state = state
		_sut.request_focal(Vector2(100, 0))
		rejects += 1
		assert_eq(_sut._lifecycle_state, SE.LifecycleState.FOLLOWING, "AC-19: stays Following in state %d" % state)
	assert_eq(_sut._focal_gating_rejected_count, rejects, "AC-19: every non-focal state rejected")


func test_focal_permitted_in_boss_and_loot() -> void:
	_gsm.current_state = GameStateMachine.GameState.BOSS_ENCOUNTER
	_sut.request_focal(Vector2(100, 0))
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.FOCAL, "AC-19: BOSS_ENCOUNTER permits Focal")
	_sut._force_clear_focal_sync()  # reset for the second sub-case
	_gsm.current_state = GameStateMachine.GameState.LOOT_DROP
	_sut.request_focal(Vector2(50, 0))
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.FOCAL, "AC-19: LOOT_DROP permits Focal")


# ---------------------------------------------------------------------------
# AC-20 — force-clear on GSM exit
# ---------------------------------------------------------------------------

func test_gsm_leaving_focal_state_force_clears() -> void:
	_gsm.current_state = GameStateMachine.GameState.BOSS_ENCOUNTER
	_sut.request_focal(Vector2(500, 0), 0.6, 2.0)
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.FOCAL, "in Focal under BOSS_ENCOUNTER")
	_sut._on_gsm_state_changed(GameStateMachine.GameState.BOSS_ENCOUNTER, GameStateMachine.GameState.IDLE, null)
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.FOLLOWING, "AC-20: force-clear → Following within 1 frame")
	assert_eq(_cam.zoom, SE.DEFAULT_ZOOM, "AC-20: zoom snapped to DEFAULT_ZOOM (skip exit tween)")
