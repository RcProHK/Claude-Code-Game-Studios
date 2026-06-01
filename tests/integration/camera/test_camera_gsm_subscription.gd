# CameraController — Story 009: GSM connect_for_initial_state + ScreenEffects decoupling + offset guard.
#
# Coverage:
#   AC-24 — _ready uses connect_for_initial_state exactly once (ADR-0006 Contract 6).
#   AC-25 — Camera never writes Camera2D.offset (owned by #6 ScreenEffects) — stays ZERO every frame.
#   AC-29 — debug build: a slipped Camera2D.offset mutation → push_error + _offset_violation_count++.
extends GutTest

const SE := preload("res://src/autoload/camera_controller.gd")


class _CameraStub:
	extends Node2D
	var zoom: Vector2 = Vector2.ONE
	var offset: Vector2 = Vector2.ZERO
	var position_smoothing_enabled: bool = false
	var position_smoothing_speed: float = 5.0
	var limit_left: int = -10000000
	var limit_right: int = 10000000
	var limit_top: int = -10000000
	var limit_bottom: int = 10000000


class _MockGSM:
	extends RefCounted
	var connect_for_initial_state_count: int = 0
	var current_state: int = GameStateMachine.GameState.IDLE
	func connect_for_initial_state(_cb: Callable) -> void:
		connect_for_initial_state_count += 1


func after_each() -> void:
	if get_tree().paused:
		get_tree().paused = false


# ---------------------------------------------------------------------------
# AC-24 — connect_for_initial_state once
# ---------------------------------------------------------------------------

func test_ready_uses_connect_for_initial_state_once() -> void:
	var sut = SE.new()
	var gsm := _MockGSM.new()
	sut._gsm = gsm  # inject before add_child so _ready uses the stub
	add_child_autofree(sut)
	await get_tree().process_frame
	assert_eq(gsm.connect_for_initial_state_count, 1, "AC-24: connect_for_initial_state called exactly once (ADR-0006 C6)")


# ---------------------------------------------------------------------------
# AC-25 — Camera never writes offset
# ---------------------------------------------------------------------------

func test_camera_offset_stays_zero() -> void:
	var sut = SE.new()
	add_child_autofree(sut)
	await get_tree().process_frame
	var cam := _CameraStub.new()
	var avatar := Node2D.new()
	add_child_autofree(cam)
	add_child_autofree(avatar)
	sut.register_camera(cam)
	sut.set_follow_target(avatar)
	sut._viewport_size_override = Vector2.ZERO
	avatar.global_position = Vector2(300, 200)
	for _i in 12:
		sut._update(1.0 / 60.0)
		assert_eq(cam.offset, Vector2.ZERO, "AC-25: Camera never writes Camera2D.offset (owned by #6 ScreenEffects)")


# ---------------------------------------------------------------------------
# AC-29 — debug offset guard
# ---------------------------------------------------------------------------

func test_debug_build_offset_violation_detected() -> void:
	var sut = SE.new()
	add_child_autofree(sut)
	await get_tree().process_frame
	var cam := _CameraStub.new()
	add_child_autofree(cam)
	sut.register_camera(cam)
	sut._debug_build_override = true
	cam.offset = Vector2(1, 0)  # simulate a slipped Rule 13 violation (e.g. AnimationPlayer)
	sut._update(1.0 / 60.0)
	assert_eq(sut._offset_violation_count, 1, "AC-29: debug build detects nonzero Camera2D.offset")


func test_release_build_offset_guard_skipped() -> void:
	var sut = SE.new()
	add_child_autofree(sut)
	await get_tree().process_frame
	var cam := _CameraStub.new()
	add_child_autofree(cam)
	sut.register_camera(cam)
	sut._debug_build_override = false  # release context
	cam.offset = Vector2(1, 0)
	sut._update(1.0 / 60.0)
	assert_eq(sut._offset_violation_count, 0, "AC-29: release build skips the guard (zero overhead)")
