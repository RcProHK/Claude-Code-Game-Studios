# CameraController — Story 004: focal entry tween + quart ease + defaults + invariants.
#
# Coverage:
#   AC-11 — quart_ease_out_value(0.3, 0, 100) ≥ 75.0 (Formula 2 front-load, decisive invitation).
#   AC-13 — request_focal(target) defaults: duration 0.6, zoom 1.4; exit 0.5; return DEFAULT_ZOOM.
#   AC-15 — FOCAL_ENTRY_DURATION > FOCAL_EXIT_DURATION (cinematographic invariant).
#   AC-31 — FOCAL_ZOOM_DEFAULT ≤ FOCAL_ZOOM_CAP.
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


func before_each() -> void:
	_sut = SE.new()
	add_child_autofree(_sut)
	await get_tree().process_frame
	_sut._gsm = _MockGSM.new()  # BOSS_ENCOUNTER → request_focal gating passes


func after_each() -> void:
	if get_tree().paused:
		get_tree().paused = false


# ---------------------------------------------------------------------------
# AC-11 — quart front-load (pure static)
# ---------------------------------------------------------------------------

func test_quart_ease_out_front_load() -> void:
	var v: float = SE._quart_ease_out_value(0.3, 0.0, 100.0)
	# 1 - (0.7)^4 = 0.7599 → 75.99 ≥ 75.0 (GDD AC-D2 authoritative threshold).
	assert_gte(v, 75.0, "AC-11: quart ease-out covers ≥75% of distance in 30% time (decisive invitation)")


func test_quart_ease_endpoints() -> void:
	assert_almost_eq(SE._quart_ease_out_value(0.0, 0.0, 100.0), 0.0, 0.0001, "AC-11: t=0 → start")
	assert_almost_eq(SE._quart_ease_out_value(1.0, 0.0, 100.0), 100.0, 0.0001, "AC-11: t=1 → end")


# ---------------------------------------------------------------------------
# AC-13 — default params
# ---------------------------------------------------------------------------

func test_request_focal_defaults() -> void:
	var cam := _CameraStub.new()
	var avatar := Node2D.new()
	add_child_autofree(cam)
	add_child_autofree(avatar)
	_sut.register_camera(cam)
	_sut.set_follow_target(avatar)
	_sut.request_focal(Vector2(100, 0))  # no explicit duration/zoom
	assert_almost_eq(_sut._resolved_focal_duration, 0.6, 0.0001, "AC-13: default duration FOCAL_ENTRY_DURATION")
	assert_almost_eq(_sut._resolved_focal_zoom, 1.4, 0.0001, "AC-13: default zoom FOCAL_ZOOM_DEFAULT")
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.FOCAL, "AC-13: entered Focal state")
	assert_almost_eq(SE.FOCAL_EXIT_DURATION, 0.5, 0.0001, "AC-13: exit duration constant")
	assert_eq(SE.DEFAULT_ZOOM, Vector2(1.0, 1.0), "AC-13: return zoom = DEFAULT_ZOOM")


# ---------------------------------------------------------------------------
# AC-15 / AC-31 — invariants
# ---------------------------------------------------------------------------

func test_entry_duration_exceeds_exit() -> void:
	assert_gt(SE.FOCAL_ENTRY_DURATION, SE.FOCAL_EXIT_DURATION, "AC-15: entry > exit (decisive invite, quick release)")


func test_zoom_default_within_cap() -> void:
	assert_lte(SE.FOCAL_ZOOM_DEFAULT, SE.FOCAL_ZOOM_CAP, "AC-31: FOCAL_ZOOM_DEFAULT ≤ FOCAL_ZOOM_CAP")
