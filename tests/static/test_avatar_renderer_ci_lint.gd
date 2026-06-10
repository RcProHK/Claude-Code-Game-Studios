# AvatarRenderer (#26) — Story 017 CI lint verification.
#
# Verifies the scope-aware detection used by tools/ci/check_avatar_renderer_derivation.gd
# (CI-1 / AC-23 single fabrication boundary). Mirrors the lint's logic inline (tracking
# top-level `func` scope) rather than running the CLI script as a subprocess — the script
# calls quit(), which would tear down the GUT tree. Same approach as
# tests/static/test_particle_ci_lint.gd.
extends GutTest

const VIOLATION_FIXTURE: String = "res://tests/fixtures/avatar_renderer_derivation_violation.gd"
const REAL_SOURCE: String = "res://src/autoload/avatar_renderer.gd"
const WRITER_FUNC: String = "_derive_state_from_canonical"

## Must match the write pattern in check_avatar_renderer_derivation.gd exactly.
const WRITE_PATTERN: String = "_visual_state\\.\\w+\\s*=(?!=)"
const FUNC_PATTERN: String = "^func\\s+(\\w+)"


func _read_lines(res_path: String) -> PackedStringArray:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines


## Count _visual_state field writes that occur OUTSIDE the single-writer function
## (mirrors the lint's scope-aware scan).
func _count_out_of_scope_writes(lines: PackedStringArray) -> int:
	var write_re := RegEx.new()
	assert_eq(write_re.compile(WRITE_PATTERN), OK, "write regex must compile")
	var func_re := RegEx.new()
	assert_eq(func_re.compile(FUNC_PATTERN), OK, "func regex must compile")
	var current_func := "<file-scope>"
	var count := 0
	for line: String in lines:
		var fm := func_re.search(line)
		if fm != null:
			current_func = fm.get_string(1)
			continue
		if line.strip_edges(true, false).begins_with("#"):
			continue
		if write_re.search(line) != null and current_func != WRITER_FUNC:
			count += 1
	return count


func test_violation_fixture_flags_handler_write() -> void:
	var lines := _read_lines(VIOLATION_FIXTURE)
	assert_gt(lines.size(), 0, "violation fixture must exist")
	assert_eq(_count_out_of_scope_writes(lines), 1,
		"CI-1/AC-23: exactly the handler's out-of-scope _visual_state write is flagged "
		+ "(in-derive writes + == comparison are clean)")


func test_real_source_has_single_writer() -> void:
	var lines := _read_lines(REAL_SOURCE)
	assert_gt(lines.size(), 0, "real source must exist")
	assert_eq(_count_out_of_scope_writes(lines), 0,
		"CI-1/AC-23: avatar_renderer.gd writes _visual_state fields ONLY in %s()" % WRITER_FUNC)
