# WorkoutStateTracker — Story 009 CI Lint Script Pattern Verification
#
# This static test verifies the regex patterns used by the three WST CI lint scripts.
# It tests both DETECTION (fixture file contains violations) and ABSENCE (clean code
# does not match forbidden patterns). This replaces running the CLI scripts as subprocesses.
#
# Coverage:
#   AC-06(a) — check_workout_state_caller.gd: WorkoutStateTracker.(set_|_) pattern
#   AC-06(b) — check_wst_namespace.gd: PersistenceLayer.write("wst.*") pattern
#   AC-17(a) — check_wst_singleton_and_nevers.gd: preload(...).new() pattern
#   AC-17(b) — check_wst_singleton_and_nevers.gd: _workout_phase = pattern
#   AC-17(c) — check_wst_singleton_and_nevers.gd: Stat.get_* pattern (inside owner)
extends GutTest

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

## Count regex matches in a set of lines (excluding comment lines).
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

# ---------------------------------------------------------------------------
# AC-06(a): check_workout_state_caller — WorkoutStateTracker.(set_|_) detection
# ---------------------------------------------------------------------------

## Pattern detects violations in the fixture file.
func test_ac06a_pattern_detects_violations_in_fixture() -> void:
	var lines := _read_lines("res://tests/fixtures/wst_ci_violation_sample.gd")
	assert_true(lines.size() > 0, "Precondition: fixture file must be readable")

	var count: int = _count_matches(lines, "WorkoutStateTracker\\.(?:set_|_)")
	assert_true(count > 0,
		"AC-06(a): pattern must detect WorkoutStateTracker.(set_|_) violations in fixture")


## Pattern does NOT flag WorkoutStateTracker.get_*() calls (whitelist).
func test_ac06a_pattern_allows_get_calls() -> void:
	var clean_lines: PackedStringArray = [
		"var phase = WorkoutStateTracker.get_current_phase()",
		"var cls = WorkoutStateTracker.get_dominant_ability_class()",
		"WorkoutStateTracker.bfcache_resumed.connect(_on_resume)",
	]
	var count: int = _count_matches(clean_lines, "WorkoutStateTracker\\.(?:set_|_)")
	# Note: get_* does NOT start with _ or set_, so these would not match.
	# Verify manually: "get_current_phase" starts with "g", not "s" or "_".
	assert_eq(count, 0,
		"AC-06(a): pattern must NOT flag WorkoutStateTracker.get_*() (allowed reads)")


## Pattern does NOT flag the owner file path reference in clean code.
func test_ac06a_clean_src_has_no_external_violations() -> void:
	# Spot-check: stat_system.gd should not mutate WST internals
	var lines := _read_lines("res://src/autoload/stat_system.gd")
	if lines.size() == 0:
		pending("stat_system.gd not found — skipping")
		return
	var count: int = _count_matches(lines, "WorkoutStateTracker\\.(?:set_|_)")
	assert_eq(count, 0,
		"AC-06(a): stat_system.gd must not have WorkoutStateTracker.(set_|_) calls")

# ---------------------------------------------------------------------------
# AC-06(b): check_wst_namespace — PersistenceLayer.write("wst.*") detection
# ---------------------------------------------------------------------------

## Pattern detects violations in the fixture file.
func test_ac06b_pattern_detects_wst_namespace_violation_in_fixture() -> void:
	var lines := _read_lines("res://tests/fixtures/wst_ci_violation_sample.gd")
	var count: int = _count_matches(lines, "PersistenceLayer\\.write\\([\"']wst\\.")
	assert_true(count > 0,
		"AC-06(b): pattern must detect PersistenceLayer.write(\"wst.*\") violations in fixture")


## Pattern does NOT flag PersistenceLayer.write() with non-wst keys.
func test_ac06b_pattern_allows_non_wst_write_calls() -> void:
	var clean_lines: PackedStringArray = [
		'PersistenceLayer.write("gsm._transition_id_counter", counter)',
		'PersistenceLayer.write("loot.pending_drop", payload)',
		'var val = PersistenceLayer.read("wst.current_workout.phase")',
	]
	var count: int = _count_matches(clean_lines, "PersistenceLayer\\.write\\([\"']wst\\.")
	assert_eq(count, 0,
		"AC-06(b): pattern must NOT flag non-wst PersistenceLayer.write() calls")


## Pattern DOES flag the wst write key explicitly.
func test_ac06b_pattern_matches_wst_write_exactly() -> void:
	var violation_lines: PackedStringArray = [
		'PersistenceLayer.write("wst.current_workout.phase", phase)',
		"PersistenceLayer.write('wst.history.avg_sets', avg)",
	]
	var count: int = _count_matches(violation_lines, "PersistenceLayer\\.write\\([\"']wst\\.")
	assert_eq(count, 2,
		"AC-06(b): pattern must match both single- and double-quoted wst.* write calls")

# ---------------------------------------------------------------------------
# AC-17(a): preload(...).new() instantiation detection
# ---------------------------------------------------------------------------

## Pattern detects preload-new violation in fixture.
func test_ac17a_pattern_detects_preload_new_in_fixture() -> void:
	var lines := _read_lines("res://tests/fixtures/wst_ci_violation_sample.gd")
	var count: int = _count_matches(lines, "preload\\(.*workout_state_tracker.*\\)\\.new\\(\\)")
	assert_true(count > 0,
		"AC-17(a): pattern must detect preload(...workout_state_tracker...).new() in fixture")


## Pattern does NOT flag WorkoutStateTracker.xxx autoload usage.
func test_ac17a_pattern_allows_autoload_usage() -> void:
	var clean_lines: PackedStringArray = [
		"WorkoutStateTracker.get_current_phase()",
		"WorkoutStateTracker.workout_completed_forwarded.connect(_on_complete)",
		'var ref = preload("res://src/autoload/stat_system.gd").new()  # different script',
	]
	var count: int = _count_matches(clean_lines, "preload\\(.*workout_state_tracker.*\\)\\.new\\(\\)")
	assert_eq(count, 0,
		"AC-17(a): pattern must NOT flag non-WST preload.new() calls")

# ---------------------------------------------------------------------------
# AC-17(b): _workout_phase = outside owner detection
# ---------------------------------------------------------------------------

## Pattern detects ._workout_phase = member-access assignment in fixture.
## Member-access form (leading dot) matches the narrowed production lint.
func test_ac17b_pattern_detects_phase_assignment_in_fixture() -> void:
	var lines := _read_lines("res://tests/fixtures/wst_ci_violation_sample.gd")
	var count: int = _count_matches(lines, "\\._workout_phase\\s*=")
	assert_true(count > 0,
		"AC-17(b): pattern must detect `WorkoutStateTracker._workout_phase =` member-access write in fixture")


## Stat.get_* FORBIDDEN inside workout_state_tracker.gd (Rule 16 NEVER #6).
func test_ac17c_wst_source_has_no_stat_get_calls() -> void:
	var lines := _read_lines("res://src/autoload/workout_state_tracker.gd")
	if lines.size() == 0:
		pending("workout_state_tracker.gd not found — skipping")
		return
	var count: int = _count_matches(lines, "Stat\\.get_")
	assert_eq(count, 0,
		"AC-17(c): workout_state_tracker.gd must NOT contain Stat.get_* calls (Rule 16 NEVER #6)")


## Pattern detects ._dominant_class = member-access write in fixture (AC-17b second branch).
## Member-access form (leading dot) — matches production lint which narrowed the pattern
## to avoid false positives on same-named backing vars in RO resources.
func test_ac17b_pattern_detects_dominant_class_write_in_fixture() -> void:
	var lines := _read_lines("res://tests/fixtures/wst_ci_violation_sample.gd")
	# Pattern: `\._dominant_class\s*=` (member-access write, not a bare self-assignment)
	var count: int = _count_matches(lines, "\\._dominant_class\\s*=")
	assert_true(count > 0,
		"AC-17(b): pattern must detect `WorkoutStateTracker._dominant_class =` member-access write in fixture")


## Bare `_dominant_class = v` self-assignment must NOT match the narrowed member-access pattern.
## This guards against the false positive that failed CI (RO resource backing-var setters).
func test_ac17b_bare_self_assignment_not_flagged() -> void:
	var clean_lines: PackedStringArray = [
		"\t\t_dominant_class = v",  # RO resource inline setter — self-scoped, not a violation
		"var _dominant_class: int = 3",  # backing var declaration
	]
	var count: int = _count_matches(clean_lines, "\\._dominant_class\\s*=")
	assert_eq(count, 0,
		"AC-17(b): bare `_dominant_class = v` self-assignment must NOT match (no leading dot)")


## Pattern also detects explicit WorkoutStateTracker.set_* call (BLOCKING-1 coverage).
func test_ac06a_pattern_detects_set_method_call_in_fixture() -> void:
	var lines := _read_lines("res://tests/fixtures/wst_ci_violation_sample.gd")
	# set_ branch: WorkoutStateTracker.set_deferred(...)
	var count: int = _count_matches(lines, "WorkoutStateTracker\\.(?:set_|_)")
	assert_true(count >= 2,
		"AC-06(a): pattern must detect BOTH _field access AND set_* method calls in fixture (≥2 matches)")


## WorkoutStateTracker.get_*() in any file must NOT be flagged (allowed read).
func test_ac17_get_calls_not_flagged_by_caller_check() -> void:
	var clean_lines: PackedStringArray = [
		"var d = WorkoutStateTracker.get_dominant_ability_class()",
		"var p = WorkoutStateTracker.get_set_progress()",
		"var s = WorkoutStateTracker.get_workout_snapshot()",
	]
	# Verify none of these match the forbidden pattern (set_|_)
	var count: int = _count_matches(clean_lines, "WorkoutStateTracker\\.(?:set_|_)")
	assert_eq(count, 0,
		"AC-17: WorkoutStateTracker.get_*() calls must NOT be flagged by caller check")
