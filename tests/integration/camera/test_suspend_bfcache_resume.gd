# CameraController — Story 007: Suspended cancel + bfcache resume.
#
# Coverage:
#   AC-17 — Focal mid-flight + GSM SUSPENDED → kill tween, snap to interpolated pos, zoom default,
#           cache target path, state Suspended.
#   AC-18 — resume with valid cached path → Following; stale path → Booting + camera_target_lost.
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
# AC-17 — Suspended cancel
# ---------------------------------------------------------------------------

func test_suspended_kills_focal_and_caches_target() -> void:
	_gsm.current_state = GameStateMachine.GameState.BOSS_ENCOUNTER
	_sut.request_focal(Vector2(500, 0), 0.6, 2.0)
	await get_tree().process_frame
	await get_tree().process_frame  # let entry tween advance (mid-flight)
	_sut._on_gsm_state_changed(GameStateMachine.GameState.BOSS_ENCOUNTER, GameStateMachine.GameState.SUSPENDED, null)
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.SUSPENDED, "AC-17: state Suspended")
	assert_eq(_cam.zoom, SE.DEFAULT_ZOOM, "AC-17: zoom reset to DEFAULT_ZOOM")
	assert_eq(_sut._cached_target_path, _avatar.get_path(), "AC-17: follow-target NodePath cached")
	# tween killed — a subsequent frame must not advance zoom away from DEFAULT_ZOOM.
	await get_tree().process_frame
	assert_eq(_cam.zoom, SE.DEFAULT_ZOOM, "AC-17: tween killed — no further interpolation")


# ---------------------------------------------------------------------------
# AC-18 — resume restore
# ---------------------------------------------------------------------------

func test_resume_with_valid_cached_path_restores_following() -> void:
	# Enter Suspended with a live target cached.
	_sut._on_gsm_state_changed(GameStateMachine.GameState.BOSS_ENCOUNTER, GameStateMachine.GameState.SUSPENDED, null)
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.SUSPENDED)
	_sut._on_gsm_state_changed(GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.IDLE, null)
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.FOLLOWING, "AC-18: valid cached path → Following")
	assert_eq(_sut._follow_target, _avatar, "AC-18: follow target re-resolved (identity)")


func test_resume_with_stale_cached_path_emits_target_lost() -> void:
	watch_signals(_sut)
	# Cache a target, then free it so the path goes stale.
	var doomed := Node2D.new()
	add_child(doomed)
	_sut.set_follow_target(doomed)
	_sut._on_gsm_state_changed(GameStateMachine.GameState.BOSS_ENCOUNTER, GameStateMachine.GameState.SUSPENDED, null)
	doomed.free()  # cached path now resolves to null
	_sut._on_gsm_state_changed(GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.IDLE, null)
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.BOOTING, "AC-18: stale cached path → Booting")
	assert_signal_emit_count(_sut, "camera_target_lost", 1, "AC-18: camera_target_lost emitted on stale resume")
