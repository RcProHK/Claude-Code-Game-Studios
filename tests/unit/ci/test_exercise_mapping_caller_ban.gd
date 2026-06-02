# ExerciseClassMapping — #10 Story 005: read-only closed-API caller-ban CI lint.
#
# Verifies the regex + whitelist predicate used by tools/ci/check_exercise_mapping_callers.gd
# (ADR-0007 read-only posture). Violation fixture flags the banned mutation; clean fixture
# (read-only API + commented ban) flags none; the real src/ tree scanned WITH the whitelist
# yields zero external mutators (owner exempt). Logic mirrored inline (the lint extends
# SceneTree and calls quit(), so it cannot be invoked directly from GUT).
extends GutTest

const VIOLATION_FIXTURE: String = "res://tests/fixtures/exercise_mapping_callers_violation.gd"
const CLEAN_FIXTURE: String = "res://tests/fixtures/exercise_mapping_callers_clean.gd"
const SCAN_ROOT: String = "res://src/"

## Must match FORBIDDEN_PATTERN in check_exercise_mapping_callers.gd.
const PATTERN: String = "ExerciseClassMapping\\s*\\.\\s*(?:_[A-Za-z0-9_]+|[A-Za-z0-9_]+\\s*=(?!=))"

## Must match EXEMPT_EXACT in check_exercise_mapping_callers.gd.
const EXEMPT_EXACT: Array[String] = ["res://src/autoload/exercise_class_mapping.gd"]


func _read_lines(res_path: String) -> PackedStringArray:
	var file := FileAccess.open(ProjectSettings.globalize_path(res_path), FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines


func _strip_trailing_comment(line: String) -> String:
	var in_single: bool = false
	var in_double: bool = false
	for k: int in line.length():
		var ch: String = line[k]
		if ch == "\"" and not in_single:
			in_double = not in_double
		elif ch == "'" and not in_double:
			in_single = not in_single
		elif ch == "#" and not in_single and not in_double:
			return line.substr(0, k)
	return line


func _count_raw_matches(lines: PackedStringArray) -> int:
	var re := RegEx.new()
	assert_eq(re.compile(PATTERN), OK, "Regex must compile: %s" % PATTERN)
	var count: int = 0
	for line: String in lines:
		if line.strip_edges(true, false).begins_with("#"):
			continue
		if re.search(_strip_trailing_comment(line)) != null:
			count += 1
	return count


func _is_whitelisted(file_path: String) -> bool:
	return EXEMPT_EXACT.has(file_path)


func _collect_gd_files(dir_path: String, acc: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == "gd":
			acc.append(dir_path.path_join(file_name))
	for subdir_name: String in dir.get_directories():
		_collect_gd_files(dir_path.path_join(subdir_name), acc)


# --- TC-005-03: fixtures -----------------------------------------------------------

func test_violation_fixture_flags_the_banned_mutation() -> void:
	assert_eq(_count_raw_matches(_read_lines(VIOLATION_FIXTURE)), 1,
		"TC-005-03: the single external ExerciseClassMapping mutator call is flagged")


func test_clean_fixture_has_no_violations() -> void:
	assert_eq(_count_raw_matches(_read_lines(CLEAN_FIXTURE)), 0,
		"TC-005-03: read-only API + commented ban must NOT be flagged")


# --- TC-005-03: real source with whitelist -----------------------------------------

func test_real_src_has_zero_external_mutators() -> void:
	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)
	assert_gt(scan_files.size(), 0, "src/ must contain .gd files to scan")
	var offenders: Array[String] = []
	for file_path: String in scan_files:
		if _is_whitelisted(file_path):
			continue
		if _count_raw_matches(_read_lines(file_path)) > 0:
			offenders.append(file_path)
	assert_eq(offenders, ([] as Array[String]),
		"TC-005-03: no external mutator/private-access of ExerciseClassMapping in src/ (owner exempt)")


# --- TC-005-04: self-exempt + whitelist precision ----------------------------------

func test_owner_is_whitelisted() -> void:
	assert_true(_is_whitelisted("res://src/autoload/exercise_class_mapping.gd"),
		"TC-005-04: owner exercise_class_mapping.gd is whitelisted (exact path)")


func test_whitelist_exact_path_anchor_is_precise() -> void:
	# A look-alike file must NOT be whitelisted — exact res:// path match only.
	assert_false(_is_whitelisted("res://src/gameplay/exercise_class_mapping_helper.gd"),
		"TC-005-04: a look-alike basename is NOT the owner — must not self-exempt")
	assert_false(_is_whitelisted("res://src/other/exercise_class_mapping.gd"),
		"TC-005-04: same basename at a different path is NOT the owner")
