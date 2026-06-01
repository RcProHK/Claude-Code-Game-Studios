# ParticleSystemWrapper — Story 006 AC-14: magic preset-id CI lint verification.
#
# Verifies the regex + comment-skip logic used by tools/ci/check_particle_preset_magic.gd
# (TR-particle-013). Tests DETECTION (violation fixture matches) + ABSENCE (clean fixture,
# real source). Patterns are exercised inline via RegEx rather than running the CLI script
# as a subprocess (the script calls quit(), which would tear down the GUT tree).
#
# Mirrors tests/static/test_enemy_director_ci_lint.gd.
extends GutTest

const VIOLATION_FIXTURE: String = "res://tests/fixtures/particle_preset_magic_violation.gd"
const CLEAN_FIXTURE: String = "res://tests/fixtures/particle_preset_magic_clean.gd"
const REAL_SOURCE: String = "res://src/autoload/particle_system_wrapper.gd"

## Must match the FORBIDDEN_PATTERN in check_particle_preset_magic.gd exactly.
const MAGIC_PATTERN: String = "ParticleSystemWrapper\\.play\\s*\\(\\s*[\"'0-9]"


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


## Count regex matches, skipping comment lines (mirrors the lint's _scan_file).
func _count_matches(lines: PackedStringArray, pattern: String) -> int:
	var re := RegEx.new()
	assert_eq(re.compile(pattern), OK, "Regex must compile: %s" % pattern)
	var count: int = 0
	for line: String in lines:
		if line.strip_edges(true, false).begins_with("#"):
			continue
		if re.search(line) != null:
			count += 1
	return count


func test_violation_fixture_flags_all_magic_calls() -> void:
	var lines := _read_lines(VIOLATION_FIXTURE)
	assert_gt(lines.size(), 0, "violation fixture must exist")
	assert_eq(_count_matches(lines, MAGIC_PATTERN), 3,
		"AC-14: 3 magic preset-id play() calls (int, string, int+mult) must be flagged")


func test_clean_fixture_has_no_violations() -> void:
	var lines := _read_lines(CLEAN_FIXTURE)
	assert_gt(lines.size(), 0, "clean fixture must exist")
	assert_eq(_count_matches(lines, MAGIC_PATTERN), 0,
		"AC-14: PresetId-enum calls + AnimationPlayer.play + commented magic must NOT be flagged")


func test_real_source_has_no_magic_preset_calls() -> void:
	var lines := _read_lines(REAL_SOURCE)
	assert_gt(lines.size(), 0, "real source must exist")
	assert_eq(_count_matches(lines, MAGIC_PATTERN), 0,
		"AC-14: particle_system_wrapper.gd has no magic ParticleSystemWrapper.play() calls")
