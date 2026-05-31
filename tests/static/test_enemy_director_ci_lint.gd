# EnemyDirector — Story 002 CI Lint Script Pattern Verification
#
# This static test verifies the regex patterns + scope-aware logic used by the three
# EnemyDirector CI lint scripts. It tests both DETECTION (positive fixture contains
# violations) and ABSENCE (clean fixture + real source do not match forbidden patterns).
# This mirrors test_wst_ci_lint.gd — patterns are exercised inline via RegEx rather than
# running the CLI scripts as subprocesses.
#
# Coverage:
#   AC-03         — check_enemy_director_chokepoint.gd: inline-damage-math patterns
#   AC-14         — check_enemy_director_randf.gd: direct-RNG patterns (scope-aware, RNGFactory)
#   Story-level AC — check_enemy_director_stat_calls.gd: StatSystem.get_stat() locality
#                    (scope-aware, _build_stat_snapshot)
extends GutTest

const VIOLATION_FIXTURE: String = "res://tests/fixtures/enemy_director_violation_a.gd"
const CLEAN_FIXTURE: String = "res://tests/fixtures/enemy_director_clean_a.gd"
const REAL_SOURCE: String = "res://src/autoload/enemy_director.gd"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Read lines from a file. Returns empty array if file not found.
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


## Count regex matches in a set of lines (excluding comment lines). Flat scan — no scope.
func _count_matches(lines: PackedStringArray, pattern: String) -> int:
	var re := RegEx.new()
	assert_eq(re.compile(pattern), OK, "Regex must compile: %s" % pattern)
	var count: int = 0
	for line: String in lines:
		if line.strip_edges(true, false).begins_with("#"):
			continue  # Skip comment lines
		if re.search(line) != null:
			count += 1
	return count


## Scope-aware match counter mirroring the randf / stat lint scripts.
## Counts forbidden_pattern hits ONLY on lines OUTSIDE the scope opened by
## scope_start_re. Scope opens at a line matching scope_start_re and closes at the
## first zero-indented non-blank non-comment line after entering.
func _count_matches_scope_aware(lines: PackedStringArray, forbidden_pattern: String,
		scope_start_re: String, _zero_indent_ends_scope: bool) -> int:
	var re_forbidden := RegEx.new()
	assert_eq(re_forbidden.compile(forbidden_pattern), OK, "forbidden regex must compile")
	var re_scope_start := RegEx.new()
	assert_eq(re_scope_start.compile(scope_start_re), OK, "scope-start regex must compile")
	var inside_scope: bool = false
	var count: int = 0
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		# Scope end: zero-indent non-blank non-comment line (after entering scope).
		if inside_scope and not line.begins_with("\t") and not line.begins_with(" "):
			inside_scope = false
		# Scope start check (skip the declaration line itself).
		if re_scope_start.search(line) != null:
			inside_scope = true
			continue
		# Violation check (only outside scope).
		if not inside_scope and re_forbidden.search(line) != null:
			count += 1
	return count

# ---------------------------------------------------------------------------
# AC-03 — chokepoint: inline damage math detection
# ---------------------------------------------------------------------------

func test_ac03_chokepoint_detects_hp_decrement_in_violation_fixture() -> void:
	# Arrange
	var lines := _read_lines(VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: violation fixture must be readable")
	# Act
	var count: int = _count_matches(lines, "\\.hp\\s*-=")
	# Assert
	assert_true(count > 0,
		"AC-03: chokepoint must detect direct `.hp -=` decrement in violation fixture")


func test_ac03_chokepoint_detects_attack_power_multiply_in_violation_fixture() -> void:
	# Arrange
	var lines := _read_lines(VIOLATION_FIXTURE)
	# Act
	var count: int = _count_matches(lines, "attack_power\\s*\\*")
	# Assert
	assert_true(count > 0,
		"AC-03: chokepoint must detect `attack_power *` inline multiplication in violation fixture")


func test_ac03_chokepoint_clean_fixture_has_zero_violations() -> void:
	# Arrange
	var lines := _read_lines(CLEAN_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: clean fixture must be readable")
	# Act + Assert — every chokepoint pattern must be absent from clean code.
	var patterns: Array[String] = [
		"attack_power\\s*\\*",
		"\\.hp\\s*-=",
		"\\.hp\\s*\\+=",
		"\\.defense\\s*-=",
		"target\\.hp\\s*=",
	]
	for pattern: String in patterns:
		var count: int = _count_matches(lines, pattern)
		assert_eq(count, 0,
			"AC-03: clean fixture must have 0 matches for pattern `%s`" % pattern)


func test_ac03_real_enemy_director_has_no_inline_damage_math() -> void:
	# Arrange
	var lines := _read_lines(REAL_SOURCE)
	if lines.size() == 0:
		pending("enemy_director.gd not found — skipping")
		return
	# Act + Assert
	var patterns: Array[String] = [
		"attack_power\\s*\\*",
		"\\.hp\\s*-=",
		"\\.hp\\s*\\+=",
		"\\.defense\\s*-=",
		"target\\.hp\\s*=",
	]
	for pattern: String in patterns:
		var count: int = _count_matches(lines, pattern)
		assert_eq(count, 0,
			"AC-03: real enemy_director.gd must have 0 inline-damage-math for `%s`" % pattern)

# ---------------------------------------------------------------------------
# AC-14 — randf: direct-RNG detection (scope-aware, RNGFactory body excluded)
# ---------------------------------------------------------------------------

func test_ac14_randf_detected_outside_rng_factory_in_violation_fixture() -> void:
	# Arrange
	var lines := _read_lines(VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: violation fixture must be readable")
	# Act — randf() lives in a plain func (no RNGFactory scope) in the violation fixture.
	var count: int = _count_matches_scope_aware(
		lines, "randf\\(", "^\\s*class\\s+RNGFactory", true)
	# Assert
	assert_true(count > 0,
		"AC-14: scope-aware check must detect randf() outside RNGFactory in violation fixture")


func test_ac14_randf_inside_rng_factory_not_detected_in_clean_fixture() -> void:
	# This is the KEY scope-aware test (qa-lead ADVISORY-1): the clean fixture contains
	# randf() INSIDE the RNGFactory class body and MUST NOT be counted as a violation.
	# Arrange
	var lines := _read_lines(CLEAN_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: clean fixture must be readable")
	# Precondition sanity: a flat scan WOULD find the in-class randf (proving scope matters).
	var flat_count: int = _count_matches(lines, "randf\\(")
	assert_true(flat_count > 0,
		"Precondition: clean fixture must contain randf() inside RNGFactory (proves scope logic)")
	# Act — scope-aware scan must exclude the RNGFactory body.
	var scoped_count: int = _count_matches_scope_aware(
		lines, "randf\\(", "^\\s*class\\s+RNGFactory", true)
	# Assert
	assert_eq(scoped_count, 0,
		"AC-14: randf() inside RNGFactory class body must NOT be counted (scope-aware)")


func test_ac14_random_number_generator_new_outside_rng_factory_detected() -> void:
	# Arrange — synthetic lines: a RandomNumberGenerator.new() in a plain func (no scope).
	var lines: PackedStringArray = [
		"func _bad() -> void:",
		"\tvar rng = RandomNumberGenerator.new()",
	]
	# Act
	var count: int = _count_matches_scope_aware(
		lines, "RandomNumberGenerator\\.new\\(", "^\\s*class\\s+RNGFactory", true)
	# Assert
	assert_eq(count, 1,
		"AC-14: RandomNumberGenerator.new() outside RNGFactory must be detected")
	# And inside RNGFactory (clean fixture) it must NOT be counted.
	var clean_lines := _read_lines(CLEAN_FIXTURE)
	var clean_count: int = _count_matches_scope_aware(
		clean_lines, "RandomNumberGenerator\\.new\\(", "^\\s*class\\s+RNGFactory", true)
	assert_eq(clean_count, 0,
		"AC-14: RandomNumberGenerator.new() inside RNGFactory must NOT be counted")


func test_ac14_real_enemy_director_clean_check() -> void:
	# Arrange
	var lines := _read_lines(REAL_SOURCE)
	if lines.size() == 0:
		pending("enemy_director.gd not found — skipping")
		return
	# Act + Assert — all direct-RNG patterns must be absent outside any RNGFactory body.
	var patterns: Array[String] = [
		"randf\\(",
		"randi\\(",
		"randf_range\\(",
		"Time\\.get_ticks_msec\\(",
		"RandomNumberGenerator\\.new\\(",
	]
	for pattern: String in patterns:
		var count: int = _count_matches_scope_aware(
			lines, pattern, "^\\s*class\\s+RNGFactory", true)
		assert_eq(count, 0,
			"AC-14: real enemy_director.gd must have 0 direct-RNG outside RNGFactory for `%s`" % pattern)

# ---------------------------------------------------------------------------
# Story-level AC — stat: StatSystem.get_stat() locality (scope-aware, _build_stat_snapshot)
# ---------------------------------------------------------------------------

func test_stat_calls_detected_outside_build_snapshot_in_violation_fixture() -> void:
	# Arrange
	var lines := _read_lines(VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: violation fixture must be readable")
	# Act — stat call lives in a plain func (no _build_stat_snapshot scope).
	var count: int = _count_matches_scope_aware(
		lines, "StatSystem\\.get_stat\\(", "^\\s*func\\s+_build_stat_snapshot", true)
	# Assert
	assert_true(count > 0,
		"Story-AC: must detect StatSystem.get_stat() outside _build_stat_snapshot in violation fixture")


func test_stat_calls_inside_build_snapshot_not_detected_in_clean_fixture() -> void:
	# Arrange
	var lines := _read_lines(CLEAN_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: clean fixture must be readable")
	# Precondition sanity: flat scan WOULD find the in-method stat calls.
	var flat_count: int = _count_matches(lines, "StatSystem\\.get_stat\\(")
	assert_true(flat_count > 0,
		"Precondition: clean fixture must contain StatSystem.get_stat() inside _build_stat_snapshot")
	# Act — scope-aware scan must exclude the _build_stat_snapshot body.
	var scoped_count: int = _count_matches_scope_aware(
		lines, "StatSystem\\.get_stat\\(", "^\\s*func\\s+_build_stat_snapshot", true)
	# Assert
	assert_eq(scoped_count, 0,
		"Story-AC: StatSystem.get_stat() inside _build_stat_snapshot must NOT be counted (scope-aware)")


func test_real_enemy_director_has_no_stat_calls_outside_snapshot() -> void:
	# Arrange
	var lines := _read_lines(REAL_SOURCE)
	if lines.size() == 0:
		pending("enemy_director.gd not found — skipping")
		return
	# Act — real file has no _build_stat_snapshot yet (Story 008), so ANY stat call would
	# be flagged. Clean scan expects zero.
	var count: int = _count_matches_scope_aware(
		lines, "StatSystem\\.get_stat\\(", "^\\s*func\\s+_build_stat_snapshot", true)
	# Assert
	assert_eq(count, 0,
		"Story-AC: real enemy_director.gd must have 0 StatSystem.get_stat() outside _build_stat_snapshot")
