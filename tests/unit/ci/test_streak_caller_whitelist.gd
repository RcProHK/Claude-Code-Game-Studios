# StreakSystem — Story 009 AC-39: streak buff-multiplier caller-whitelist CI lint.
#
# Verifies the regex + whitelist predicate used by tools/ci/check_streak_callers.gd
# (ADR-0003 FR-3 / GDD Rule 13). Violation fixture flags the banned call; clean fixture
# (commented ban + non-buff reads) flags none; the real src/ tree scanned WITH the
# whitelist predicate yields zero out-of-whitelist callers (owner def + loot consumer
# are exempt). Logic mirrored inline (the lint extends SceneTree and calls quit()).
extends GutTest

const VIOLATION_FIXTURE: String = "res://tests/fixtures/streak_callers_violation.gd"
const CLEAN_FIXTURE: String = "res://tests/fixtures/streak_callers_clean.gd"
const SCAN_ROOT: String = "res://src/"

## Must match FORBIDDEN_PATTERN in check_streak_callers.gd.
const PATTERN: String = "get_streak_buff_multiplier\\s*\\("

## Must match EXEMPT_EXACT + EXEMPT_BASENAMES in check_streak_callers.gd.
const EXEMPT_EXACT: Array[String] = ["res://src/autoload/streak_system.gd"]
const EXEMPT_BASENAMES: Array[String] = ["loot_drop_system.gd", "mirror_moment_system.gd"]


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
	if EXEMPT_EXACT.has(file_path):
		return true
	for base: String in EXEMPT_BASENAMES:
		if file_path.ends_with("/" + base):
			return true
	return false


func _collect_gd_files(dir_path: String, acc: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == "gd":
			acc.append(dir_path.path_join(file_name))
	for subdir_name: String in dir.get_directories():
		_collect_gd_files(dir_path.path_join(subdir_name), acc)


# --- AC-39a: fixtures ---------------------------------------------------------------

func test_violation_fixture_flags_the_banned_call() -> void:
	assert_eq(_count_raw_matches(_read_lines(VIOLATION_FIXTURE)), 1,
		"AC-39a: the single out-of-whitelist get_streak_buff_multiplier() call is flagged")


func test_clean_fixture_has_no_violations() -> void:
	assert_eq(_count_raw_matches(_read_lines(CLEAN_FIXTURE)), 0,
		"AC-39a: commented ban + non-buff streak reads must NOT be flagged")


# --- AC-39 / AC-39b: real source with whitelist ------------------------------------

func test_real_src_has_zero_out_of_whitelist_callers() -> void:
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
		"AC-39/AC-39b: no out-of-whitelist caller of get_streak_buff_multiplier() in src/ (owner def + loot consumer exempt)")


func test_owner_definition_is_whitelisted() -> void:
	# The owner DEFINES the method (its `func` line matches PATTERN); it must be exempt
	# so the lint never flags its own declaration.
	assert_true(_is_whitelisted("res://src/autoload/streak_system.gd"),
		"AC-39b: streak_system.gd (owner/definition) is whitelisted")
	assert_gt(_count_raw_matches(_read_lines("res://src/autoload/streak_system.gd")), 0,
		"sanity: owner file does contain the method token (the func definition)")


# --- AC-39b edge: whitelist precision ----------------------------------------------

func test_whitelist_basename_anchor_is_exact() -> void:
	# A look-alike file must NOT be whitelisted by a basename suffix collision.
	assert_false(_is_whitelisted("res://src/gameplay/abilities/loot_drop_system_helper.gd"),
		"AC-39b: 'loot_drop_system_helper.gd' is NOT the sanctioned 'loot_drop_system.gd'")
	assert_true(_is_whitelisted("res://src/autoload/loot_drop_system.gd"),
		"AC-39b: the real loot_drop_system.gd consumer IS whitelisted")
	assert_false(_is_whitelisted("res://src/gameplay/stats/stat_system.gd"),
		"AC-39b: an avatar-power system path is NOT whitelisted")
