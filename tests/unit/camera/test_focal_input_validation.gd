# CameraController — Story 002: request_focal input validation + parameter guards.
#
# Coverage:
#   AC-02 — NaN/±INF in position/duration/zoom → reject + _rejected_calls++.
#   AC-03 — over-limit duration/zoom → clamp to MAX_FOCAL_DURATION/FOCAL_ZOOM_CAP (+ warn, NOT reject).
#   EC-04 — zoom ≤ 0 → reject (projection div-by-zero).
extends GutTest

const SE := preload("res://src/autoload/camera_controller.gd")

var _sut


func before_each() -> void:
	_sut = SE.new()
	add_child_autofree(_sut)
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# AC-02 — non-finite rejected
# ---------------------------------------------------------------------------

func test_non_finite_args_rejected() -> void:
	_sut.request_focal(Vector2(NAN, 0.0))
	_sut.request_focal(Vector2(10, 10), NAN)
	_sut.request_focal(Vector2(10, 10), 0.6, INF)
	_sut.request_focal(Vector2(10, 10), 0.6, -INF)
	assert_eq(_sut._rejected_calls, 4, "AC-02: each non-finite call rejected (NaN pos, NaN dur, ±INF zoom)")


# ---------------------------------------------------------------------------
# AC-03 — over-limit clamp (not reject)
# ---------------------------------------------------------------------------

func test_over_limit_duration_and_zoom_clamped() -> void:
	_sut.request_focal(Vector2(10, 10), 15.0, 5.0)
	assert_almost_eq(_sut._resolved_focal_duration, 10.0, 0.0001, "AC-03: duration clamped to MAX_FOCAL_DURATION")
	assert_almost_eq(_sut._resolved_focal_zoom, 4.0, 0.0001, "AC-03: zoom clamped to FOCAL_ZOOM_CAP")
	assert_eq(_sut._rejected_calls, 0, "AC-03: over-limit is valid-but-clamped, NOT a rejection")


func test_boundary_values_not_clamped() -> void:
	_sut.request_focal(Vector2(10, 10), 10.0, 4.0)  # exactly at ceilings
	assert_almost_eq(_sut._resolved_focal_duration, 10.0, 0.0001, "AC-03: duration == ceiling accepted")
	assert_almost_eq(_sut._resolved_focal_zoom, 4.0, 0.0001, "AC-03: zoom == cap accepted")
	assert_eq(_sut._rejected_calls, 0)


# ---------------------------------------------------------------------------
# EC-04 — zoom ≤ 0 rejected
# ---------------------------------------------------------------------------

func test_zoom_zero_or_negative_rejected() -> void:
	_sut.request_focal(Vector2(10, 10), 0.6, 0.0)
	_sut.request_focal(Vector2(10, 10), 0.6, -1.0)
	assert_eq(_sut._rejected_calls, 2, "EC-04: zoom ≤ 0 rejected (projection div-by-zero)")
