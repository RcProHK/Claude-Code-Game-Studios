extends GutTest
## CombatVisualFeedback (#25) — Story 005 CI lint verification (AC-11 / R-13).
##
## Verifies the forbidden-pattern detection used by tools/ci/check_cvf_no_direct_shake.gd.
## Mirrors the lint's regex inline (the CLI script calls quit(), which would tear down the
## GUT tree — same approach as test_avatar_renderer_ci_lint.gd / test_particle_ci_lint.gd):
##   - the real #25 source has ZERO direct `.shake(` (AC-11 positive guard)
##   - the violation fixture is flagged (negative — proves the lint actually catches it)

const REAL_SOURCE: String = "res://src/autoload/combat_visual_feedback.gd"
const VIOLATION_FIXTURE: String = "res://tests/fixtures/cvf_direct_shake_violation.gd"
## Must match check_cvf_no_direct_shake.gd exactly.
const FORBIDDEN_PATTERN: String = "\\.shake\\s*\\("


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


## Count direct shake calls outside comment lines (mirrors the lint's scan).
func _count_direct_shake(lines: PackedStringArray) -> int:
	var re := RegEx.new()
	assert_eq(re.compile(FORBIDDEN_PATTERN), OK, "forbidden regex must compile")
	var count := 0
	for line: String in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		if re.search(line) != null:
			count += 1
	return count


## AC-11 (MUST-NOT-REGRESS): the shipped #25 source contains zero direct shake calls.
func test_real_source_has_zero_direct_shake() -> void:
	var lines := _read_lines(REAL_SOURCE)
	assert_gt(lines.size(), 0, "#25 source must be readable")
	assert_eq(_count_direct_shake(lines), 0,
		"AC-11/R-13: combat_visual_feedback.gd must NEVER direct-call .shake( — shake is #6 auto-dispatch")


## Negative: the deliberate violation fixture is flagged (proves the guard works).
func test_violation_fixture_is_flagged() -> void:
	var lines := _read_lines(VIOLATION_FIXTURE)
	assert_gt(lines.size(), 0, "violation fixture must exist")
	assert_eq(_count_direct_shake(lines), 1,
		"fixture's single `_screen_fx.shake(` must be detected (hit_pause line stays clean)")


## Mirrors check_cvf_no_runtime_alloc.gd forbidden patterns (R-19 / AC-29).
const ALLOC_PATTERNS: Array[String] = [
	"GPUParticles2D\\.new\\(",
	"create_tween\\(",
	"Tween\\.new\\(",
	"Timer\\.new\\(",
]


func _count_runtime_alloc(lines: PackedStringArray) -> int:
	var res: Array[RegEx] = []
	for p: String in ALLOC_PATTERNS:
		var re := RegEx.new()
		assert_eq(re.compile(p), OK, "alloc regex must compile")
		res.append(re)
	var count := 0
	for line: String in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		for re: RegEx in res:
			if re.search(line) != null:
				count += 1
	return count


## AC-29 (R-19): the shipped #25 source has zero per-hit runtime allocation
## (no GPUParticles2D.new / create_tween / Tween.new / Timer.new).
func test_real_source_has_zero_runtime_alloc() -> void:
	var lines := _read_lines(REAL_SOURCE)
	assert_gt(lines.size(), 0, "#25 source must be readable")
	assert_eq(_count_runtime_alloc(lines), 0,
		"AC-29/R-19: combat_visual_feedback.gd must not allocate per-hit (pool pre-instantiated at boot)")
