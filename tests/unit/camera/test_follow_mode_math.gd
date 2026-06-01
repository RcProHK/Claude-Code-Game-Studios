# CameraController — Story 003: follow mode math + dead-zone + Pillar 2 lock-on.
#
# Coverage:
#   AC-07 — Formula 1 exponential decay: +200px, 6 frames @60fps → ≈78.69px.
#   AC-08 — target inside dead-zone → camera delta == 0.
#   AC-09 — 30px offset → lock within 3px in < 500ms (Pillar 2, via _update DI seam).
#   AC-10 — jitter ±5px inside dead-zone 120 frames → variance < 0.5px².
#   AC-30 — Formula 4 safe-range corners (pure static).
#
# All pure Formula 1+4+5. Dead-zone controlled via _viewport_size_override (ZERO = no dead-zone).
extends GutTest

const SE := preload("res://src/autoload/camera_controller.gd")


class _CameraStub:
	extends Node2D
	var zoom: Vector2 = Vector2.ONE


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
	_sut.register_camera(_cam)
	_sut.set_follow_target(_avatar)  # → Following


# ---------------------------------------------------------------------------
# AC-07 — Formula 1 exponential decay
# ---------------------------------------------------------------------------

func test_exponential_decay_over_six_frames() -> void:
	_sut._viewport_size_override = Vector2.ZERO  # disable dead-zone → pure smoothing
	_cam.position = Vector2.ZERO
	_avatar.global_position = Vector2(200, 0)
	for _i in 6:
		_sut._update(1.0 / 60.0)
	# 200 × (1 - exp(-5.0 × 0.1)) ≈ 78.69
	assert_almost_eq(_cam.position.x, 78.69, 1.0, "AC-07: Formula 1 cumulative decay ≈ 78.69px")
	assert_almost_eq(_cam.position.y, 0.0, 0.001, "AC-07: no vertical movement")


# ---------------------------------------------------------------------------
# AC-08 — dead-zone no-move
# ---------------------------------------------------------------------------

func test_target_inside_deadzone_no_move() -> void:
	_sut._viewport_size_override = Vector2(1000, 1000)  # dead-zone half-extent.x = 1000×0.04 = 40px
	_cam.position = Vector2.ZERO
	_avatar.global_position = Vector2(30, 0)  # 30 < 40 → inside dead-zone
	for _i in 10:
		_sut._update(1.0 / 60.0)
	assert_eq(_cam.position, Vector2.ZERO, "AC-08: target inside dead-zone → camera does not move")


# ---------------------------------------------------------------------------
# AC-09 — Pillar 2 lock-on < 500ms
# ---------------------------------------------------------------------------

func test_glance_back_locks_on_under_500ms() -> void:
	_sut._viewport_size_override = Vector2.ZERO  # pure smoothing (no dead-zone)
	_cam.position = Vector2.ZERO
	_avatar.global_position = Vector2(30, 0)
	var frames: int = 0
	while frames < 200:
		_sut._update(1.0 / 60.0)
		frames += 1
		if absf(_cam.position.x - 30.0) < SE.LOCK_ON_TOLERANCE_PX:
			break
	var t_ms: float = frames * (1000.0 / 60.0)
	assert_lt(frames, 200, "AC-09: must lock on (not hit the iteration guard)")
	assert_lt(t_ms, 500.0, "AC-09: Pillar 2 lock-on within 500ms (expected ≈461ms)")


# ---------------------------------------------------------------------------
# AC-10 — dead-zone jitter stability
# ---------------------------------------------------------------------------

func test_jitter_inside_deadzone_no_oscillation() -> void:
	_sut._viewport_size_override = Vector2(1000, 1000)  # dead-zone 40px
	_cam.position = Vector2.ZERO
	var samples: Array = []
	for i in 120:
		_avatar.global_position = Vector2(5.0 if i % 2 == 0 else -5.0, 0)  # ±5px, deterministic
		_sut._update(1.0 / 60.0)
		samples.append(_cam.position.x)
	var mean: float = 0.0
	for s in samples:
		mean += s
	mean /= samples.size()
	var variance: float = 0.0
	for s in samples:
		variance += (s - mean) * (s - mean)
	variance /= samples.size()
	assert_lt(variance, 0.5, "AC-10: ±5px jitter inside dead-zone → camera position variance < 0.5px²")


# ---------------------------------------------------------------------------
# AC-30 — Formula 4 safe-range corners (pure static)
# ---------------------------------------------------------------------------

func test_lock_on_formula_safe_range_corners() -> void:
	# 4 safe-range corners (k∈[5,8], d_tol∈[3,8]) — exact values from ln(30/d_tol)/k.
	assert_almost_eq(SE._glance_lock_on_time(30.0, 3.0, 5.0) * 1000.0, 460.5, 5.0, "AC-30: (k=5,d=3) ≈461ms")
	assert_almost_eq(SE._glance_lock_on_time(30.0, 8.0, 5.0) * 1000.0, 264.3, 5.0, "AC-30: (k=5,d=8) ≈264ms")
	assert_almost_eq(SE._glance_lock_on_time(30.0, 3.0, 8.0) * 1000.0, 287.8, 5.0, "AC-30: (k=8,d=3) ≈288ms")
	assert_almost_eq(SE._glance_lock_on_time(30.0, 8.0, 8.0) * 1000.0, 165.2, 5.0, "AC-30: (k=8,d=8) ≈165ms")
	# All 4 in-range corners satisfy the Pillar 2 < 500ms contract.
	assert_lt(SE._glance_lock_on_time(30.0, 3.0, 5.0) * 1000.0, 500.0, "AC-30: worst in-range corner < 500ms")
	# Out-of-range NEGATIVE: d_tol=2.0 (below the 3.0 floor) at k=5.0 → ln(15)/5 = 541.6ms > 500ms,
	# proving the LOCK_ON_TOLERANCE_PX floor is load-bearing.
	# NOTE: GDD AC-30/AC-G1 cite (k=4.9, d_tol=2.9) → "527ms" as the negative corner, but that is a
	# math error — actual ln(30/2.9)/4.9 = 476.8ms (< 500). The real just-outside corner that breaks
	# the contract is a sub-floor d_tol. Flagged for designer (see Completion Notes).
	assert_gt(SE._glance_lock_on_time(30.0, 2.0, 5.0) * 1000.0, 500.0, "AC-30: out-of-range (d_tol<3.0) > 500ms (floor justified)")
