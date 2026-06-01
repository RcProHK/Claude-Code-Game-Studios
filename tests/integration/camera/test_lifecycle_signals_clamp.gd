# CameraController — Story 008: target-lost + viewport recompute + focal-clamp signal.
#
# Coverage:
#   AC-22 — _follow_target queue_free'd → _update freezes + camera_target_lost once (debounced).
#   AC-23 — viewport size change → dead-zone recompute; camera position unchanged (world-locked).
#   AC-26 — focal target outside limit_* → clamp + focal_target_clamped(requested, clamped) once.
extends GutTest

const SE := preload("res://src/autoload/camera_controller.gd")


class _CameraStub:
	extends Node2D
	var zoom: Vector2 = Vector2.ONE
	var position_smoothing_enabled: bool = false
	var position_smoothing_speed: float = 5.0
	var limit_left: int = -10000000
	var limit_right: int = 10000000
	var limit_top: int = -10000000
	var limit_bottom: int = 10000000


class _MockGSM:
	extends RefCounted
	var current_state: int = GameStateMachine.GameState.BOSS_ENCOUNTER
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
# AC-22 — target-lost debounced
# ---------------------------------------------------------------------------

func test_freed_target_freezes_and_emits_once() -> void:
	watch_signals(_sut)
	_sut._viewport_size_override = Vector2.ZERO
	_cam.position = Vector2(42, 7)
	var doomed := Node2D.new()
	add_child(doomed)
	_sut.set_follow_target(doomed)
	doomed.free()
	_sut._update(1.0 / 60.0)
	assert_eq(_cam.position, Vector2(42, 7), "AC-22: camera frozen at last position after target lost")
	assert_signal_emit_count(_sut, "camera_target_lost", 1, "AC-22: camera_target_lost emitted once")
	_sut._update(1.0 / 60.0)
	assert_signal_emit_count(_sut, "camera_target_lost", 1, "AC-22: NOT re-emitted on subsequent frames (debounced)")


# ---------------------------------------------------------------------------
# AC-23 — viewport resize recompute, no jolt
# ---------------------------------------------------------------------------

func test_viewport_resize_recomputes_deadzone_no_jolt() -> void:
	_sut._viewport_size_override = Vector2(1000, 1000)
	_cam.position = Vector2.ZERO
	_avatar.global_position = Vector2.ZERO  # target == camera (settled)
	var dz_before: Vector2 = _sut._dead_zone_half_extents()
	_sut._update(1.0 / 60.0)
	var pos_before := _cam.position
	_sut._viewport_size_override = Vector2(2000, 1500)  # resize
	var dz_after: Vector2 = _sut._dead_zone_half_extents()
	_sut._update(1.0 / 60.0)
	assert_ne(dz_before, dz_after, "AC-23: dead-zone extents recomputed after viewport resize")
	assert_eq(_cam.position, pos_before, "AC-23: camera position unchanged across resize (world-locked, no jolt)")


# ---------------------------------------------------------------------------
# AC-26 — focal target clamp signal
# ---------------------------------------------------------------------------

func test_focal_target_beyond_limit_clamps_and_signals() -> void:
	watch_signals(_sut)
	_cam.limit_right = 1024
	_gsm.current_state = GameStateMachine.GameState.BOSS_ENCOUNTER
	_sut.request_focal(Vector2(5000, 0), 0.6, 1.4)
	assert_signal_emit_count(_sut, "focal_target_clamped", 1, "AC-26: focal_target_clamped emitted once")
	var params: Array = get_signal_parameters(_sut, "focal_target_clamped", 0)
	assert_eq(params[0], Vector2(5000, 0), "AC-26: requested target reported")
	assert_eq(params[1], Vector2(1024, 0), "AC-26: clamped to limit_right")


func test_focal_target_within_limits_no_clamp_signal() -> void:
	watch_signals(_sut)
	_cam.limit_right = 1024
	_gsm.current_state = GameStateMachine.GameState.BOSS_ENCOUNTER
	_sut.request_focal(Vector2(500, 0), 0.6, 1.4)  # within limits
	assert_signal_emit_count(_sut, "focal_target_clamped", 0, "AC-26: no clamp signal when target within limits")
