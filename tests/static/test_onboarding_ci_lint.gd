extends GutTest
## Onboarding (#27) — Story 012 CI lint verification (AC-15 / G-OB-2, Pillar 1 命脈).
##
## Mirrors the forbidden-pattern detection of tools/ci/check_onboarding_no_gameplay_mutator.gd
## inline (the CLI script calls quit(), which would tear down the GUT tree — same approach as
## test_cvf_ci_lint.gd). Verifies:
##   - the shipped onboarding source has ZERO gameplay mutators (observe-only must-not-regress)
##   - the deliberate violation fixture is flagged (proves the guard works)

const COORDINATOR: String = "res://src/autoload/onboarding_coordinator.gd"
const PREVIEW_DIRECTOR: String = "res://src/ui/onboarding/preview_director.gd"
const VIOLATION_FIXTURE: String = "res://tests/fixtures/onboarding_gameplay_mutator_violation.gd"

## Must match check_onboarding_no_gameplay_mutator.gd exactly.
const FORBIDDEN_PATTERNS: Array[String] = [
	"\"(loot|stat|ability|streak)\\.",
	"claim[_-]daily",
	"\\b(set_stat|unlock_ability|grant_ability|generate_drop|spawn_loot|claim_drop)\\s*\\(",
]


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


## Count gameplay-mutator violations on code lines (mirrors the lint's scan).
func _count_mutators(lines: PackedStringArray) -> int:
	var res: Array[RegEx] = []
	for p: String in FORBIDDEN_PATTERNS:
		var re := RegEx.new()
		assert_eq(re.compile(p), OK, "forbidden regex must compile")
		res.append(re)
	var count := 0
	for line: String in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		for re: RegEx in res:
			if re.search(line) != null:
				count += 1
				break
	return count


# --- AC-15 (must-not-regress) — shipped source is observe-only ----------------

func test_coordinator_has_zero_gameplay_mutator() -> void:
	var lines := _read_lines(COORDINATOR)
	assert_gt(lines.size(), 0, "coordinator source must be readable")
	assert_eq(_count_mutators(lines), 0,
		"AC-15/G-OB-2: onboarding_coordinator.gd must be observe-only (zero gameplay mutator)")


func test_preview_director_has_zero_gameplay_mutator() -> void:
	var lines := _read_lines(PREVIEW_DIRECTOR)
	assert_gt(lines.size(), 0, "preview_director source must be readable")
	assert_eq(_count_mutators(lines), 0,
		"AC-15/G-OB-2: preview_director.gd is a non-binding showcase (zero gameplay mutator, Pillar 1)")


# --- Negative — the violation fixture is flagged ------------------------------

func test_violation_fixture_is_flagged() -> void:
	var lines := _read_lines(VIOLATION_FIXTURE)
	assert_gt(lines.size(), 0, "violation fixture must exist")
	assert_eq(_count_mutators(lines), 3,
		"fixture's 3 violations (loot.* write / claim_daily / unlock_ability) must all be detected")
