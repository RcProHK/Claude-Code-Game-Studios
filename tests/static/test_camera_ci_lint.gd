# CameraController — Story 009 AC-28: closed Camera2D-mutation CI lint verification.
#
# Verifies the regex set used by tools/ci/check_camera_callers.gd (GDD Rule 13). Violation
# fixture flags all 4 banned forms; clean fixture flags none; real source (owner) → 0 (it uses
# the untyped _camera var, not the "Camera2D.*" literal forms). Inline RegEx (lint calls quit()).
extends GutTest

const VIOLATION_FIXTURE: String = "res://tests/fixtures/camera_callers_violation.gd"
const CLEAN_FIXTURE: String = "res://tests/fixtures/camera_callers_clean.gd"
const REAL_SOURCE: String = "res://src/autoload/camera_controller.gd"

## Must match FORBIDDEN_PATTERNS in check_camera_callers.gd.
const PATTERNS: Array[String] = [
	"Camera2D[^\\n]*\\.position\\s*=",
	"Camera2D[^\\n]*\\.zoom\\s*=",
	"\\.make_current\\s*\\(",
	"get_viewport\\(\\)\\.get_camera_2d\\(\\)",
]


func _read_lines(res_path: String) -> PackedStringArray:
	var file := FileAccess.open(ProjectSettings.globalize_path(res_path), FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines


func _count_matches(lines: PackedStringArray) -> int:
	var count: int = 0
	for pattern in PATTERNS:
		var re := RegEx.new()
		assert_eq(re.compile(pattern), OK, "Regex must compile: %s" % pattern)
		for line: String in lines:
			if line.strip_edges(true, false).begins_with("#"):
				continue
			if re.search(line) != null:
				count += 1
	return count


func test_violation_fixture_flags_all_four() -> void:
	assert_eq(_count_matches(_read_lines(VIOLATION_FIXTURE)), 4,
		"AC-28: 4 banned Camera2D forms (position/zoom/make_current/get_camera_2d) flagged")


func test_clean_fixture_has_no_violations() -> void:
	assert_eq(_count_matches(_read_lines(CLEAN_FIXTURE)), 0,
		"AC-28: CameraController API + commented bans + non-Camera2D .position must NOT be flagged")


func test_real_source_has_no_violations() -> void:
	assert_eq(_count_matches(_read_lines(REAL_SOURCE)), 0,
		"AC-28: camera_controller.gd uses the untyped _camera var, never the Camera2D.* literal forms")
