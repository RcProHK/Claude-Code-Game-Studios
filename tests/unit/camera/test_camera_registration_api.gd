# CameraController — Story 001: registration + closed API surface.
#
# Coverage:
#   AC-01 — register_camera(valid) + set_follow_target(avatar) → Booting→Following within 1 frame.
#   AC-04 — register_camera(null) / register_camera(freed) → reject; state stays Booting.
#   AC-05 — second register_camera() → reject; first Camera2D reference preserved.
#   AC-06a — public surface == exactly {register_camera, unregister_camera, set_follow_target,
#            request_focal, clear_focal} + 3 signals; set_motion_reduction MUST NOT exist.
#
# Autoload has no class_name — preload. Camera2D is a duck-typed stub (NOT a real Camera2D node).
extends GutTest

const SE := preload("res://src/autoload/camera_controller.gd")


## Duck-typed Camera2D stub. Node2D gives position/global_position; the rest are added for
## later stories. Story 001 only needs a valid Object for register + identity assertions.
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


var _sut


func before_each() -> void:
	_sut = SE.new()
	add_child_autofree(_sut)
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# AC-01 — register + follow → Following
# ---------------------------------------------------------------------------

func test_register_and_follow_enters_following() -> void:
	var cam := _CameraStub.new()
	add_child_autofree(cam)
	var avatar := Node2D.new()
	add_child_autofree(avatar)
	_sut.register_camera(cam)
	_sut.set_follow_target(avatar)
	await get_tree().process_frame
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.FOLLOWING, "AC-01: Booting→Following")
	assert_eq(_sut._camera, cam, "AC-01: registered camera stored (identity)")
	assert_eq(_sut._follow_target, avatar, "AC-01: follow target stored (identity)")


# ---------------------------------------------------------------------------
# AC-04 — invalid register rejected, stays Booting
# ---------------------------------------------------------------------------

func test_register_null_rejected_stays_booting() -> void:
	_sut.register_camera(null)
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.BOOTING, "AC-04: null register keeps Booting")
	assert_null(_sut._camera, "AC-04: _camera remains null after null register")


func test_register_freed_instance_rejected() -> void:
	var freed := _CameraStub.new()  # not added to tree
	freed.free()
	_sut.register_camera(freed)
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.BOOTING, "AC-04: freed register keeps Booting")
	assert_null(_sut._camera, "AC-04: _camera remains null after freed register")


# ---------------------------------------------------------------------------
# AC-05 — double register preserves first
# ---------------------------------------------------------------------------

func test_double_register_preserves_first() -> void:
	var cam_a := _CameraStub.new()
	var cam_b := _CameraStub.new()
	add_child_autofree(cam_a)
	add_child_autofree(cam_b)
	_sut.register_camera(cam_a)
	_sut.register_camera(cam_b)
	assert_eq(_sut._camera, cam_a, "AC-05: first Camera2D preserved (cam_b rejected)")


# ---------------------------------------------------------------------------
# AC-06a — closed public surface
# ---------------------------------------------------------------------------

func test_public_api_surface_is_exactly_five_methods() -> void:
	var public: Array = []
	for m in _sut.get_script().get_script_method_list():
		if not String(m.name).begins_with("_"):
			public.append(String(m.name))
	public.sort()
	var expected := ["clear_focal", "register_camera", "request_focal", "set_follow_target", "unregister_camera"]
	expected.sort()
	assert_eq(public, expected, "AC-06a: exactly the 5 closed-API methods are public")


func test_required_signals_present() -> void:
	assert_true(_sut.has_signal("focal_completed"), "AC-06a: focal_completed signal")
	assert_true(_sut.has_signal("camera_target_lost"), "AC-06a: camera_target_lost signal")
	assert_true(_sut.has_signal("focal_target_clamped"), "AC-06a: focal_target_clamped signal")


func test_set_motion_reduction_absent_in_vs_tier_scope() -> void:
	assert_false(_sut.has_method("set_motion_reduction"),
		"AC-06a: set_motion_reduction MUST NOT exist until #22 GDD (Story 011 BLOCKED)")
