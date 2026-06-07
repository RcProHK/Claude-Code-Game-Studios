## #7 story 011 / #22 G-CS-2 — set_motion_reduction (camera-system.md AC-27/AC-06b)。
extends GutTest

const CameraScript := preload("res://src/autoload/camera_controller.gd")


class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	func read(key: String):
		return store.get(key, null)


class StubCamera:
	extends Camera2D


## Focal-allowed GSM stub(BOSS_ENCOUNTER=6)— 冇 cfis(plain object,
## _ready 嘅 has_method check 自然 skip subscription)。
class StubGSM:
	extends RefCounted
	var state: int = 6  # GameState.BOSS_ENCOUNTER — focal allowed
	func get_current_state() -> int:
		return state


var _sut = null


func _make(persisted = null) -> void:
	_sut = CameraScript.new()
	var mock := MockPersistence.new()
	if persisted != null:
		mock.store["settings.reduce_camera_motion"] = persisted
	_sut._persistence = mock
	_sut._gsm = StubGSM.new()  # 防 _ready re-resolve 真 GSM(IDLE 會 gate focal)
	add_child_autofree(_sut)


func test_boot_reads_persisted_reduction() -> void:
	_make(true)
	assert_true(_sut._motion_reduction, "boot self-read settings.reduce_camera_motion")


func test_boot_missing_key_defaults_false() -> void:
	_make(null)
	assert_false(_sut._motion_reduction)


func test_ac27_request_focal_silent_noop_when_reduced() -> void:
	_make(true)
	var cam := StubCamera.new()
	add_child_autofree(cam)
	_sut.register_camera(cam)
	_sut.request_focal(Vector2(100, 100))
	assert_eq(_sut._lifecycle_state, CameraScript.LifecycleState.FOLLOWING,
		"focal 唔入 — silent no-op(預期 opt-out)")
	assert_eq(_sut._focal_motion_reduction_suppressed, 1)
	assert_eq(_sut._rejected_calls, 0, "唔計入 rejected(唔係 caller bug)")


func test_ac27_dead_zone_hard_lock_zero() -> void:
	_make(true)
	var cam := StubCamera.new()
	add_child_autofree(cam)
	_sut.register_camera(cam)
	_sut._viewport_size_override = Vector2(1280, 720)
	assert_eq(_sut._dead_zone_half_extents(), Vector2.ZERO,
		"dead-zone 0% — camera 永遠正中 avatar")


func test_ac27_following_smoothing_disabled_and_restored() -> void:
	_make(false)
	var cam := StubCamera.new()
	add_child_autofree(cam)
	_sut.register_camera(cam)
	_sut.set_motion_reduction(true)
	assert_false(cam.position_smoothing_enabled, "ON → smoothing off(同 frame 生效)")
	_sut.set_motion_reduction(false)
	assert_true(cam.position_smoothing_enabled, "OFF → smoothing 恢復")


func test_flip_on_during_focal_exits_focal() -> void:
	_make(false)
	var cam := StubCamera.new()
	add_child_autofree(cam)
	_sut.register_camera(cam)
	_sut.request_focal(Vector2(50, 50))
	assert_eq(_sut._lifecycle_state, CameraScript.LifecycleState.FOCAL)
	_sut.set_motion_reduction(true)
	assert_eq(_sut._lifecycle_state, CameraScript.LifecycleState.FOLLOWING,
		"flip ON mid-focal → 即場退出(opt-out 即時兌現)")
