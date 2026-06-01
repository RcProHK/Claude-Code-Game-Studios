# CameraController — Story 005: focal exit cubic ease + PAUSABLE freeze.
#
# Coverage:
#   AC-12 — cubic_ease_in_out_value(0.5, 0, 1) == 0.5 ±1e-6 (Formula 3 symmetric midpoint).
#   AC-14 — focal tween PAUSABLE: get_tree().paused freezes it; focal_completed not premature.
#
# AC-14 needs the real Tween/SceneTree (GUT runs it headless). after_each MUST restore
# get_tree().paused = false.
extends GutTest

const SE := preload("res://src/autoload/camera_controller.gd")


class _CameraStub:
	extends Node2D
	var zoom: Vector2 = Vector2.ONE
	var position_smoothing_enabled: bool = false
	var position_smoothing_speed: float = 5.0


class _MockGSM:
	extends RefCounted
	var current_state: int = GameStateMachine.GameState.BOSS_ENCOUNTER
	func connect_for_initial_state(_cb: Callable) -> void:
		pass


var _sut
var _cam: _CameraStub
var _avatar: Node2D


func before_each() -> void:
	_sut = SE.new()
	add_child_autofree(_sut)
	await get_tree().process_frame
	_cam = _CameraStub.new()
	_avatar = Node2D.new()
	add_child_autofree(_cam)
	add_child_autofree(_avatar)
	_sut._gsm = _MockGSM.new()  # BOSS_ENCOUNTER → request_focal gating passes
	_sut.register_camera(_cam)
	_sut.set_follow_target(_avatar)


func after_each() -> void:
	if get_tree().paused:
		get_tree().paused = false


# ---------------------------------------------------------------------------
# AC-12 — cubic symmetry (pure static)
# ---------------------------------------------------------------------------

func test_cubic_ease_in_out_symmetric_midpoint() -> void:
	assert_almost_eq(SE._cubic_ease_in_out_value(0.5, 0.0, 1.0), 0.5, 1e-6, "AC-12: f(0.5) == 0.5 exact")


func test_cubic_ease_endpoints_and_symmetry() -> void:
	assert_almost_eq(SE._cubic_ease_in_out_value(0.0, 0.0, 1.0), 0.0, 1e-6, "AC-12: t=0 → 0")
	assert_almost_eq(SE._cubic_ease_in_out_value(1.0, 0.0, 1.0), 1.0, 1e-6, "AC-12: t=1 → 1")
	var a: float = SE._cubic_ease_in_out_value(0.25, 0.0, 1.0)
	var b: float = SE._cubic_ease_in_out_value(0.75, 0.0, 1.0)
	assert_almost_eq(a + b, 1.0, 1e-6, "AC-12: f(0.25) + f(0.75) == 1 (symmetric)")


# ---------------------------------------------------------------------------
# AC-14 — PAUSABLE freeze
# ---------------------------------------------------------------------------

func test_focal_tween_freezes_under_pause() -> void:
	watch_signals(_sut)
	_sut.request_focal(Vector2(500, 0), 0.6, 2.0)  # long entry tween so it's mid-flight
	await get_tree().process_frame
	await get_tree().process_frame
	var zoom_before_pause: Vector2 = _cam.zoom
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var zoom_during_pause: Vector2 = _cam.zoom
	assert_eq(zoom_during_pause, zoom_before_pause, "AC-14: PAUSABLE tween frozen during get_tree().paused")
	assert_signal_emit_count(_sut, "focal_completed", 0, "AC-14: focal_completed NOT emitted while paused (no premature completion)")
	get_tree().paused = false
