# ScreenEffects — Story 008 AC-21: closed-primitive CI lint verification.
#
# Verifies the regex set used by tools/ci/check_screen_effects_callers.gd (GDD Rule 15).
# Three-part: violation fixture flags all 4 banned forms; clean fixture flags none; the owner
# (screen_effects.gd) has none of the CALLER-only bans (it legally uses get_tree().paused +
# the uniform via a const, so those are excluded from the owner-scoped real-source check).
#
# Inline RegEx (the lint script calls quit() — running it as a subprocess would tear down GUT).
# Mirrors tests/static/test_particle_ci_lint.gd.
extends GutTest

const VIOLATION_FIXTURE: String = "res://tests/fixtures/screen_effects_violation.gd"
const CLEAN_FIXTURE: String = "res://tests/fixtures/screen_effects_clean.gd"
const REAL_SOURCE: String = "res://src/autoload/screen_effects.gd"

## All four patterns — must match FORBIDDEN_PATTERNS in check_screen_effects_callers.gd.
const ALL_PATTERNS: Array[String] = [
	"Camera2D[^\\n]*\\.offset\\s*=",
	"Engine\\.time_scale\\s*=",
	"get_tree\\(\\)\\.paused\\s*=",
	"RenderingServer\\.global_shader_parameter_set\\s*\\(\\s*[\"']u_shake_offset",
]

## Owner-scoped subset: patterns the OWNER must never use (paused + uniform are owner-legal).
const OWNER_FORBIDDEN: Array[String] = [
	"Camera2D[^\\n]*\\.offset\\s*=",
	"Engine\\.time_scale\\s*=",
	"RenderingServer\\.global_shader_parameter_set\\s*\\(\\s*[\"']u_shake_offset",
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


## Count total matches across a pattern set, skipping comment lines.
func _count_matches(lines: PackedStringArray, patterns: Array[String]) -> int:
	var count: int = 0
	for pattern in patterns:
		var re := RegEx.new()
		assert_eq(re.compile(pattern), OK, "Regex must compile: %s" % pattern)
		for line: String in lines:
			if line.strip_edges(true, false).begins_with("#"):
				continue
			if re.search(line) != null:
				count += 1
	return count


func test_violation_fixture_flags_all_four_bans() -> void:
	var lines := _read_lines(VIOLATION_FIXTURE)
	assert_gt(lines.size(), 0, "violation fixture must exist")
	assert_eq(_count_matches(lines, ALL_PATTERNS), 4,
		"AC-21: 4 banned forms (Camera2D.offset / Engine.time_scale / paused / uniform) flagged")


func test_clean_fixture_has_no_violations() -> void:
	var lines := _read_lines(CLEAN_FIXTURE)
	assert_gt(lines.size(), 0, "clean fixture must exist")
	assert_eq(_count_matches(lines, ALL_PATTERNS), 0,
		"AC-21: ScreenEffects API calls + commented bans + plain .offset must NOT be flagged")


func test_owner_source_has_no_caller_only_bans() -> void:
	# screen_effects.gd legally uses get_tree().paused + writes the uniform via a const, so those
	# are owner-exempt. It must still NOT mutate Camera2D.offset or Engine.time_scale or write the
	# uniform via a string literal.
	var lines := _read_lines(REAL_SOURCE)
	assert_gt(lines.size(), 0, "real source must exist")
	assert_eq(_count_matches(lines, OWNER_FORBIDDEN), 0,
		"AC-21: owner uses paused/uniform-via-const legally, but never Camera2D.offset / time_scale / uniform-literal")
