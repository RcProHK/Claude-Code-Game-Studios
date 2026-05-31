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
#
# Story 003 (CI Lint Suite B) coverage appended below:
#   AC-04         — check_autoload_boot_order.gd: LootDropSystem ≺ EnemyDirector HARD
#                   constraint (_parse_autoload_order helper) + soft predecessors warn-only
#   AC-10         — check_enemy_director_signal_lifecycle.gd: .connect()/.disconnect()
#                   inside _physics_process / _on_ability_cast hot-path bodies (method-scope-aware)
#   Story-level AC — check_enemy_director_state_locality.gd: 8 state containers present
#   Story-level AC — check_enemy_director_signal_subscription.gd: raw .connect() on
#                   AbilitySystem.ability_cast / GameStateMachine.state_changed forbidden
extends GutTest

const VIOLATION_FIXTURE: String = "res://tests/fixtures/enemy_director_violation_a.gd"
const CLEAN_FIXTURE: String = "res://tests/fixtures/enemy_director_clean_a.gd"
const REAL_SOURCE: String = "res://src/autoload/enemy_director.gd"

# Story 003 fixtures (CI Lint Suite B).
const BOOT_ORDER_VIOLATION_FIXTURE: String = "res://tests/fixtures/enemy_director_boot_order_violation.gd"
const SIGNAL_VIOLATION_FIXTURE: String = "res://tests/fixtures/enemy_director_signal_violation.gd"
const SIGNAL_CLEAN_FIXTURE: String = "res://tests/fixtures/enemy_director_signal_clean.gd"
const LOCALITY_VIOLATION_FIXTURE: String = "res://tests/fixtures/enemy_director_locality_violation.gd"
const PROJECT_FILE: String = "res://project.godot"

# The 8 Rule 1 state containers (mirrors check_enemy_director_state_locality.gd).
const REQUIRED_CONTAINERS: Array[String] = [
	"_catch_up_queue", "_anomaly_rate_tracker", "_enemy_state_pool",
	"_killed_dedupe_set", "_spawn_pool", "_rng_factory",
	"_active_wave", "_boss_anchor_state",
]

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
	# Act + Assert — BARE global RNG + ad-hoc RNG construction must be absent outside any
	# RNGFactory body. Patterns mirror the refined check_enemy_director_randf.gd (Story 012):
	# negative lookbehind exempts seeded-instance `.randf_range(` calls; Time.get_ticks_msec()
	# is NOT forbidden (legitimate rate-limiter boundary read, cannot seed RNG).
	var patterns: Array[String] = [
		"(?<![\\w.])randf\\(",
		"(?<![\\w.])randi\\(",
		"(?<![\\w.])randf_range\\(",
		"(?<![\\w.])randi_range\\(",
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

# ===========================================================================
# Story 003 helpers
# ===========================================================================

## Extract the SIM_AUTOLOAD_BLOCK triple-quoted string content from a fixture, then
## parse its [autoload] section into {key: 1-based position}. Mirrors the
## check_autoload_boot_order.gd _parse_autoload_order() logic so the helper test
## exercises the exact ordering rule. Returns {} if no [autoload] section.
func _parse_autoload_order_from_block(block_lines: PackedStringArray) -> Dictionary:
	var order: Dictionary = {}
	var in_autoload_section: bool = false
	var seen_section: bool = false
	var position: int = 0
	for raw_line: String in block_lines:
		var stripped: String = raw_line.strip_edges()
		if stripped.is_empty() or stripped.begins_with(";"):
			continue
		if stripped.begins_with("[") and stripped.ends_with("]"):
			in_autoload_section = stripped == "[autoload]"
			if in_autoload_section:
				seen_section = true
			continue
		if not in_autoload_section:
			continue
		var eq_index: int = stripped.find("=")
		if eq_index <= 0:
			continue
		var key: String = stripped.substr(0, eq_index).strip_edges()
		if key.is_empty():
			continue
		position += 1
		if not order.has(key):
			order[key] = position
	if not seen_section:
		return {}
	return order


## Extract the multi-line text held in the SIM_AUTOLOAD_BLOCK const of the boot-order
## fixture. The fixture stores the simulated project.godot text as a `const ... = """..."""`
## block; we slice the lines between the opening and closing triple-quote.
func _extract_sim_autoload_block(fixture_lines: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	var inside: bool = false
	for line: String in fixture_lines:
		if not inside:
			if line.contains("\"\"\""):
				inside = true  # opening triple-quote line (no content after it in our fixture)
			continue
		if line.contains("\"\"\""):
			break  # closing triple-quote
		out.append(line)
	return out


## Method-scope-aware match counter for AC-10. Counts forbidden_pattern hits ONLY on
## lines INSIDE a hot-path method body. A hot-path method opens at a line matching
## hot_func_re; ANY `func` declaration closes the current hot-path scope; scope also
## ends at a zero-indent non-blank non-comment line. Mirrors
## check_enemy_director_signal_lifecycle.gd.
func _count_matches_hot_path(lines: PackedStringArray, forbidden_pattern: String,
		hot_func_re_str: String) -> int:
	var re_forbidden := RegEx.new()
	assert_eq(re_forbidden.compile(forbidden_pattern), OK, "forbidden regex must compile")
	var re_hot := RegEx.new()
	assert_eq(re_hot.compile(hot_func_re_str), OK, "hot-func regex must compile")
	var re_any_func := RegEx.new()
	assert_eq(re_any_func.compile("^\\s*func\\s+\\w+"), OK, "any-func regex must compile")
	var inside_hot: bool = false
	var count: int = 0
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		if inside_hot and not line.begins_with("\t") and not line.begins_with(" "):
			inside_hot = false
		if re_any_func.search(line) != null:
			inside_hot = re_hot.search(line) != null
			continue
		if inside_hot and re_forbidden.search(line) != null:
			count += 1
	return count


## Count `var <name>` declarations present in a set of lines (comment lines skipped).
## Returns the subset of `names` that are MISSING.
func _missing_var_declarations(lines: PackedStringArray, names: Array[String]) -> Array[String]:
	var found: Dictionary = {}
	for name: String in names:
		var re := RegEx.new()
		assert_eq(re.compile("^\\s*var\\s+%s\\b" % name), OK, "var regex must compile")
		for line: String in lines:
			if line.strip_edges().begins_with("#"):
				continue
			if re.search(line) != null:
				found[name] = true
				break
	var missing: Array[String] = []
	for name: String in names:
		if not found.has(name):
			missing.append(name)
	return missing

# ===========================================================================
# AC-04 — autoload boot order: LootDropSystem ≺ EnemyDirector (HARD)
# ===========================================================================

func test_ac04_boot_order_parser_extracts_ordered_autoload_keys() -> void:
	# Arrange — read the simulated [autoload] block from the violation fixture.
	var fixture_lines := _read_lines(BOOT_ORDER_VIOLATION_FIXTURE)
	assert_true(fixture_lines.size() > 0, "Precondition: boot-order fixture must be readable")
	var block := _extract_sim_autoload_block(fixture_lines)
	assert_true(block.size() > 0, "Precondition: SIM_AUTOLOAD_BLOCK must be extractable")
	# Act
	var order := _parse_autoload_order_from_block(block)
	# Assert — keys parsed with 1-based positions; comments/blanks excluded.
	assert_true(order.has("EnemyDirector"), "AC-04: parser must capture EnemyDirector key")
	assert_true(order.has("LootDropSystem"), "AC-04: parser must capture LootDropSystem key")
	assert_eq(order.get("PersistenceLayer", -1), 1,
		"AC-04: PersistenceLayer must be position 1 in parsed order")


func test_ac04_boot_order_violation_fixture_enemy_director_before_lootdrop() -> void:
	# Arrange
	var fixture_lines := _read_lines(BOOT_ORDER_VIOLATION_FIXTURE)
	var order := _parse_autoload_order_from_block(_extract_sim_autoload_block(fixture_lines))
	# Act
	var ed_pos: int = order.get("EnemyDirector", -1)
	var loot_pos: int = order.get("LootDropSystem", -1)
	# Assert — this is the HARD violation the lint must exit-1 on.
	assert_true(ed_pos != -1 and loot_pos != -1, "Precondition: both keys present")
	assert_true(loot_pos > ed_pos,
		"AC-04: violation fixture must place LootDropSystem AFTER EnemyDirector (HARD violation => exit 1)")


func test_ac04_real_project_godot_lootdrop_precedes_enemy_director() -> void:
	# Arrange — the real project.godot is the clean/PASS case.
	var lines := _read_lines(PROJECT_FILE)
	if lines.size() == 0:
		pending("project.godot not found — skipping")
		return
	var order := _parse_autoload_order_from_block(lines)
	# Act
	var ed_pos: int = order.get("EnemyDirector", -1)
	var loot_pos: int = order.get("LootDropSystem", -1)
	# Assert — HARD constraint satisfied (exit 0).
	assert_true(ed_pos != -1, "AC-04: EnemyDirector must be registered in project.godot")
	assert_true(loot_pos != -1, "AC-04: LootDropSystem must be registered in project.godot")
	assert_true(loot_pos < ed_pos,
		"AC-04: real project.godot must place LootDropSystem BEFORE EnemyDirector (clean => exit 0)")


func test_ac04_soft_predecessors_present_in_real_project_godot() -> void:
	# Arrange — soft predecessors are advisory; this asserts they exist (warn-only path).
	var lines := _read_lines(PROJECT_FILE)
	if lines.size() == 0:
		pending("project.godot not found — skipping")
		return
	var order := _parse_autoload_order_from_block(lines)
	# Act + Assert — every advisory predecessor is registered (so warn path is exercised, not exit-1).
	var soft: Array[String] = [
		"PersistenceLayer", "GameStateMachine", "PlatformDetect", "GymSysBackendClient",
		"StatSystem", "AbilitySystem", "StreakSystem", "WorkoutStateTracker",
	]
	for name: String in soft:
		assert_true(order.has(name),
			"AC-04: advisory predecessor `%s` should exist in project.godot (warn-only ordering)" % name)

# ===========================================================================
# AC-10 — signal lifecycle: no connect/disconnect in hot-path bodies
# ===========================================================================

func test_ac10_connect_detected_inside_physics_process_in_violation_fixture() -> void:
	# Arrange
	var lines := _read_lines(SIGNAL_VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: signal violation fixture must be readable")
	# Act — .connect( inside _physics_process body.
	var count: int = _count_matches_hot_path(
		lines, "\\.connect\\(", "^\\s*func\\s+(_physics_process|_on_ability_cast)\\b")
	# Assert
	assert_true(count > 0,
		"AC-10: must detect .connect() inside a hot-path body in violation fixture")


func test_ac10_disconnect_detected_inside_on_ability_cast_in_violation_fixture() -> void:
	# Arrange
	var lines := _read_lines(SIGNAL_VIOLATION_FIXTURE)
	# Act — .disconnect( inside _on_ability_cast body.
	var count: int = _count_matches_hot_path(
		lines, "\\.disconnect\\(", "^\\s*func\\s+(_physics_process|_on_ability_cast)\\b")
	# Assert
	assert_true(count > 0,
		"AC-10: must detect .disconnect() inside _on_ability_cast in violation fixture")


func test_ac10_clean_fixture_has_no_hot_path_connect_or_disconnect() -> void:
	# Arrange
	var lines := _read_lines(SIGNAL_CLEAN_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: signal clean fixture must be readable")
	# Precondition sanity: the clean fixture DOES contain .connect( outside hot path
	# (in _ready + _spawn_enemy) — proving scope matters, not a flat absence.
	var flat: int = _count_matches(lines, "\\.connect\\(")
	assert_true(flat > 0,
		"Precondition: clean fixture has non-hot-path .connect() (proves method-scope logic)")
	# Act — hot-path-scoped scan must find ZERO.
	var hot_connect: int = _count_matches_hot_path(
		lines, "\\.connect\\(", "^\\s*func\\s+(_physics_process|_on_ability_cast)\\b")
	var hot_disconnect: int = _count_matches_hot_path(
		lines, "\\.disconnect\\(", "^\\s*func\\s+(_physics_process|_on_ability_cast)\\b")
	# Assert
	assert_eq(hot_connect, 0, "AC-10: clean fixture must have 0 .connect() in hot-path bodies")
	assert_eq(hot_disconnect, 0, "AC-10: clean fixture must have 0 .disconnect() in hot-path bodies")


func test_ac10_real_enemy_director_has_no_hot_path_connect_disconnect() -> void:
	# Arrange
	var lines := _read_lines(REAL_SOURCE)
	if lines.size() == 0:
		pending("enemy_director.gd not found — skipping")
		return
	# Act + Assert
	for pattern: String in ["\\.connect\\(", "\\.disconnect\\("]:
		var count: int = _count_matches_hot_path(
			lines, pattern, "^\\s*func\\s+(_physics_process|_on_ability_cast)\\b")
		assert_eq(count, 0,
			"AC-10: real enemy_director.gd must have 0 `%s` in hot-path bodies" % pattern)

# ===========================================================================
# Story-AC — state locality: 8 containers in EnemyDirector class body
# ===========================================================================

func test_locality_violation_fixture_is_missing_rng_factory() -> void:
	# Arrange
	var lines := _read_lines(LOCALITY_VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: locality violation fixture must be readable")
	# Act
	var missing := _missing_var_declarations(lines, REQUIRED_CONTAINERS)
	# Assert — fixture omits exactly 2 containers (multi-missing per qa advisory #3);
	# both must be detected so the test locks the fixture's full omission surface.
	assert_eq(missing.size(), 2,
		"Story-AC: locality violation fixture omits exactly 2 containers")
	assert_true(missing.has("_rng_factory"),
		"Story-AC: locality violation fixture must omit _rng_factory specifically")
	assert_true(missing.has("_boss_anchor_state"),
		"Story-AC: _boss_anchor_state omission must also be detected (multi-container)")


func test_locality_real_enemy_director_has_all_8_containers() -> void:
	# Arrange
	var lines := _read_lines(REAL_SOURCE)
	if lines.size() == 0:
		pending("enemy_director.gd not found — skipping")
		return
	# Act
	var missing := _missing_var_declarations(lines, REQUIRED_CONTAINERS)
	# Assert — clean => exit 0.
	assert_eq(missing.size(), 0,
		"Story-AC: real enemy_director.gd must declare all 8 state containers (missing: %s)" % str(missing))

# ===========================================================================
# Story-AC — signal subscription: raw .connect() on governed signals forbidden
# ===========================================================================

func test_subscription_raw_ability_cast_connect_detected_in_violation_fixture() -> void:
	# Arrange
	var lines := _read_lines(SIGNAL_VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: signal violation fixture must be readable")
	# Act
	var count: int = _count_matches(lines, "AbilitySystem\\.ability_cast\\.connect\\(")
	# Assert
	assert_true(count > 0,
		"Story-AC: must detect raw AbilitySystem.ability_cast.connect() in violation fixture")


func test_subscription_raw_state_changed_connect_detected_in_violation_fixture() -> void:
	# Arrange
	var lines := _read_lines(SIGNAL_VIOLATION_FIXTURE)
	# Act
	var count: int = _count_matches(lines, "GameStateMachine\\.state_changed\\.connect\\(")
	# Assert
	assert_true(count > 0,
		"Story-AC: must detect raw GameStateMachine.state_changed.connect() in violation fixture")


func test_subscription_clean_fixture_uses_helper_not_raw_connect() -> void:
	# Arrange
	var lines := _read_lines(SIGNAL_CLEAN_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: signal clean fixture must be readable")
	# Act — neither governed-signal raw form may appear...
	var raw_ability: int = _count_matches(lines, "AbilitySystem\\.ability_cast\\.connect\\(")
	var raw_state: int = _count_matches(lines, "GameStateMachine\\.state_changed\\.connect\\(")
	# ...and the sanctioned helper MUST be present.
	var helper: int = _count_matches(lines, "connect_for_initial_state\\(")
	# Assert
	assert_eq(raw_ability, 0, "Story-AC: clean fixture must have 0 raw ability_cast.connect()")
	assert_eq(raw_state, 0, "Story-AC: clean fixture must have 0 raw state_changed.connect()")
	assert_true(helper > 0, "Story-AC: clean fixture must subscribe via connect_for_initial_state helper")


func test_subscription_real_enemy_director_has_no_raw_governed_connect() -> void:
	# Arrange
	var lines := _read_lines(REAL_SOURCE)
	if lines.size() == 0:
		pending("enemy_director.gd not found — skipping")
		return
	# Act + Assert — Story 005 wires subscriptions via the helper; raw forms must be absent.
	for pattern: String in [
		"AbilitySystem\\.ability_cast\\.connect\\(",
		"GameStateMachine\\.state_changed\\.connect\\(",
	]:
		var count: int = _count_matches(lines, pattern)
		assert_eq(count, 0,
			"Story-AC: real enemy_director.gd must have 0 raw governed-signal connect for `%s`" % pattern)


# ===========================================================================
# Story 004 — CI Lint Suite C: Forbidden Patterns / Move Cap / Dodge Invariant
# ===========================================================================
# Coverage:
#   AC-05 — check_camera_callers.gd: Camera2D.position/zoom/make_current mutation
#   AC-26 — check_particle_callers.gd: GPUParticles2D.new() + emitting=true
#   AC-31 — check_enemy_template_move_cap.gd: _template_move_speed ≤ 420 (exit2 if .tres absent)
#   AC-32 — check_dodge_amplitude_invariant.gd: DODGE_AMPLITUDE_PX*2 < MELEE_RANGE (exit2 if const absent)
#   Story-AC boss — check_boss_anchor_state_transitions.gd: only IDLE direct assignment legal
#   Story-AC cap — check_particle_concurrency_cap.gd: const not var (exit2 if absent)

const CAMERA_VIOLATION_FIXTURE: String = "res://tests/fixtures/enemy_director_camera_violation.gd"
const PARTICLE_VIOLATION_FIXTURE: String = "res://tests/fixtures/enemy_director_particle_violation.gd"
const CAMERA_PARTICLE_CLEAN_FIXTURE: String = "res://tests/fixtures/enemy_director_camera_particle_clean.gd"
const MOVE_CAP_VIOLATION_FIXTURE: String = "res://tests/fixtures/enemy_director_move_cap_violation.gd"
const MOVE_CAP_CLEAN_FIXTURE: String = "res://tests/fixtures/enemy_director_move_cap_clean.gd"
const DODGE_VIOLATION_FIXTURE: String = "res://tests/fixtures/enemy_director_dodge_violation.gd"
const DODGE_CLEAN_FIXTURE: String = "res://tests/fixtures/enemy_director_dodge_clean.gd"
const BOSS_TRANSITION_VIOLATION_FIXTURE: String = "res://tests/fixtures/enemy_director_boss_transition_violation.gd"
const CONCURRENCY_VIOLATION_FIXTURE: String = "res://tests/fixtures/enemy_director_concurrency_violation.gd"
const CONCURRENCY_CLEAN_FIXTURE: String = "res://tests/fixtures/enemy_director_concurrency_clean.gd"


## Extract all _template_move_speed values from simulated .tres text lines.
func _extract_template_speeds(lines: PackedStringArray) -> Array[float]:
	var re := RegEx.new()
	assert_eq(re.compile("_template_move_speed\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)"), OK)
	var speeds: Array[float] = []
	for line: String in lines:
		if line.strip_edges(true, false).begins_with("#"):
			continue
		var m := re.search(line)
		if m != null:
			speeds.append(float(m.get_string(1)))
	return speeds


## Extract the integer value of a named const from lines. Returns -1 if not found.
func _extract_const_value(lines: PackedStringArray, const_name: String) -> int:
	var re := RegEx.new()
	assert_eq(re.compile("const\\s+" + const_name + "\\s*(?::\\s*\\w+\\s*)?=\\s*(-?[0-9]+)"), OK)
	for line: String in lines:
		if line.strip_edges(true, false).begins_with("#"):
			continue
		var m := re.search(line)
		if m != null:
			return int(m.get_string(1))
	return -1


# ---------------------------------------------------------------------------
# AC-05 — Camera2D mutation detection
# ---------------------------------------------------------------------------

func test_ac05_camera_position_mutation_detected() -> void:
	var lines := _read_lines(CAMERA_VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: camera violation fixture must be readable")
	var count: int = _count_matches(lines, "Camera2D[^\\n]*\\.position\\s*=")
	assert_true(count > 0,
		"AC-05: Camera2D.position mutation must be detected in camera violation fixture")


func test_ac05_camera_zoom_mutation_detected() -> void:
	var lines := _read_lines(CAMERA_VIOLATION_FIXTURE)
	var count: int = _count_matches(lines, "Camera2D[^\\n]*\\.zoom\\s*=")
	assert_true(count > 0,
		"AC-05: Camera2D.zoom mutation must be detected in camera violation fixture")


func test_ac05_camera_make_current_detected() -> void:
	var lines := _read_lines(CAMERA_VIOLATION_FIXTURE)
	var count: int = _count_matches(lines, "Camera2D[^\\n]*\\.make_current\\s*\\(")
	assert_true(count > 0,
		"AC-05: Camera2D.make_current() must be detected in camera violation fixture")


func test_ac05_clean_fixture_no_camera_violations() -> void:
	var lines := _read_lines(CAMERA_PARTICLE_CLEAN_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: clean fixture must be readable")
	for pattern: String in [
		"Camera2D[^\\n]*\\.position\\s*=",
		"Camera2D[^\\n]*\\.zoom\\s*=",
		"Camera2D[^\\n]*\\.make_current\\s*\\(",
	]:
		assert_eq(_count_matches(lines, pattern), 0,
			"AC-05: clean fixture must have 0 Camera2D violations for pattern")


func test_ac05_real_enemy_director_no_camera_violations() -> void:
	var lines := _read_lines(REAL_SOURCE)
	if lines.size() == 0:
		pending("enemy_director.gd not found — skipping")
		return
	for pattern: String in [
		"Camera2D[^\\n]*\\.position\\s*=",
		"Camera2D[^\\n]*\\.zoom\\s*=",
		"Camera2D[^\\n]*\\.make_current\\s*\\(",
	]:
		assert_eq(_count_matches(lines, pattern), 0,
			"AC-05: real enemy_director.gd must have 0 Camera2D mutation")


# ---------------------------------------------------------------------------
# AC-26 — GPUParticles2D.new() + emitting=true detection
# ---------------------------------------------------------------------------

func test_ac26_gpu_particles_new_detected() -> void:
	var lines := _read_lines(PARTICLE_VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: particle violation fixture must be readable")
	assert_true(_count_matches(lines, "GPUParticles2D\\.new\\(") > 0,
		"AC-26: GPUParticles2D.new() must be detected in particle violation fixture")


func test_ac26_emitting_true_detected() -> void:
	var lines := _read_lines(PARTICLE_VIOLATION_FIXTURE)
	assert_true(_count_matches(lines, "GPUParticles2D[^\\n]*\\.emitting\\s*=") > 0,
		"AC-26: .emitting = true must be detected in particle violation fixture")


func test_ac26_clean_fixture_no_particle_violations() -> void:
	var lines := _read_lines(CAMERA_PARTICLE_CLEAN_FIXTURE)
	for pattern: String in ["GPUParticles2D\\.new\\(", "GPUParticles2D[^\\n]*\\.emitting\\s*="]:
		assert_eq(_count_matches(lines, pattern), 0,
			"AC-26: clean fixture must have 0 particle violations")


func test_ac26_real_enemy_director_no_particle_violations() -> void:
	var lines := _read_lines(REAL_SOURCE)
	if lines.size() == 0:
		pending("enemy_director.gd not found — skipping")
		return
	for pattern: String in ["GPUParticles2D\\.new\\(", "GPUParticles2D[^\\n]*\\.emitting\\s*="]:
		assert_eq(_count_matches(lines, pattern), 0,
			"AC-26: real enemy_director.gd must have 0 direct particle instantiation")


# ---------------------------------------------------------------------------
# AC-31 — _template_move_speed ≤ 420 (exit2 if target absent)
# ---------------------------------------------------------------------------

func test_ac31_speed_above_420_detected() -> void:
	var lines := _read_lines(MOVE_CAP_VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: move cap violation fixture must be readable")
	var speeds := _extract_template_speeds(lines)
	assert_true(speeds.size() > 0, "Precondition: fixture must contain speed values")
	var any_violation: bool = false
	for s: float in speeds:
		if s > 420.0:
			any_violation = true
	assert_true(any_violation,
		"AC-31: violation fixture must contain at least one _template_move_speed > 420")


func test_ac31_all_speeds_within_420_passes() -> void:
	var lines := _read_lines(MOVE_CAP_CLEAN_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: clean fixture must be readable")
	var speeds := _extract_template_speeds(lines)
	assert_true(speeds.size() > 0, "Precondition: clean fixture must contain speed values")
	for s: float in speeds:
		assert_true(s <= 420.0, "AC-31: all speeds in clean fixture must be ≤ 420")


## AC-31 unblocked by Story 010: EnemyRegistry.tres now exists, so the move-cap lint
## enforces on a real target. Verify the file is present AND every real _template_move_speed
## is within the cap (the lint's exit-0 condition).
func test_ac31_real_registry_tres_present_and_within_cap() -> void:
	var abs_path: String = ProjectSettings.globalize_path("res://assets/data/EnemyRegistry.tres")
	assert_true(FileAccess.file_exists(abs_path),
		"AC-31: EnemyRegistry.tres must exist (Story 010 done) — move-cap lint now enforces")
	var lines := _read_lines("res://assets/data/EnemyRegistry.tres")
	var speeds := _extract_template_speeds(lines)
	assert_true(speeds.size() > 0, "AC-31: real registry must declare _template_move_speed values")
	for s: float in speeds:
		assert_true(s <= 420.0, "AC-31: real registry speed %f must be ≤ 420 (INV-7)" % s)


# ---------------------------------------------------------------------------
# AC-32 — DODGE_AMPLITUDE_PX * 2 < MELEE_RANGE=80 (exit2 if const absent)
# ---------------------------------------------------------------------------

func test_ac32_dodge_amplitude_50_violates_inv8() -> void:
	var lines := _read_lines(DODGE_VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: dodge violation fixture must be readable")
	var value: int = _extract_const_value(lines, "DODGE_AMPLITUDE_PX")
	assert_eq(value, 50, "AC-32: violation fixture must declare DODGE_AMPLITUDE_PX = 50")
	assert_true(value * 2 >= 80, "AC-32: 50*2=100 >= MELEE_RANGE=80 — INV-8 violation confirmed")


func test_ac32_dodge_amplitude_30_satisfies_inv8() -> void:
	var lines := _read_lines(DODGE_CLEAN_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: dodge clean fixture must be readable")
	var value: int = _extract_const_value(lines, "DODGE_AMPLITUDE_PX")
	assert_eq(value, 30, "AC-32: clean fixture must declare DODGE_AMPLITUDE_PX = 30")
	assert_true(value * 2 < 80, "AC-32: 30*2=60 < MELEE_RANGE=80 — INV-8 satisfied")


func test_ac32_const_absent_in_real_source_confirms_exit2_path() -> void:
	var lines := _read_lines(REAL_SOURCE)
	if lines.size() == 0:
		pending("enemy_director.gd not found — skipping")
		return
	assert_eq(_extract_const_value(lines, "DODGE_AMPLITUDE_PX"), -1,
		"AC-32: DODGE_AMPLITUDE_PX must not yet exist in real source (Story 015 scope — exit-2 path active)")


# ---------------------------------------------------------------------------
# Story-AC — boss anchor state transitions
# ---------------------------------------------------------------------------

func test_boss_transition_illegal_non_idle_direct_detected() -> void:
	var lines := _read_lines(BOSS_TRANSITION_VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: boss transition violation fixture must be readable")
	var count: int = _count_matches(lines,
		"_boss_anchor_state\\s*=\\s*BossAnchorState\\.(?!IDLE)[A-Z_]+")
	assert_true(count > 0,
		"Story-AC: illegal non-IDLE direct BossAnchorState assignment must be detected")


func test_boss_transition_idle_init_legal_in_real_source() -> void:
	var lines := _read_lines(REAL_SOURCE)
	if lines.size() == 0:
		pending("enemy_director.gd not found — skipping")
		return
	var idle_count: int = _count_matches(lines,
		"_boss_anchor_state\\s*=\\s*BossAnchorState\\.IDLE")
	var non_idle_count: int = _count_matches(lines,
		"_boss_anchor_state\\s*=\\s*BossAnchorState\\.(?!IDLE)[A-Z_]+")
	assert_true(idle_count > 0,
		"Story-AC: real source must have at least one IDLE init assignment")
	assert_eq(non_idle_count, 0,
		"Story-AC: real source must have 0 direct non-IDLE assignments (Story 016 implements FSM helpers)")


# ---------------------------------------------------------------------------
# Story-AC — particle concurrency cap: const not var (exit2 if absent)
# ---------------------------------------------------------------------------

func test_particle_cap_var_declaration_detected() -> void:
	var lines := _read_lines(CONCURRENCY_VIOLATION_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: concurrency violation fixture must be readable")
	var var_count: int = _count_matches(lines, "^\\s*var\\s+MAX_CONCURRENT_PARTICLE_EMITTERS\\b")
	assert_true(var_count > 0,
		"Story-AC: var MAX_CONCURRENT_PARTICLE_EMITTERS must be detected as violation")


func test_particle_cap_const_declaration_passes() -> void:
	var lines := _read_lines(CONCURRENCY_CLEAN_FIXTURE)
	assert_true(lines.size() > 0, "Precondition: concurrency clean fixture must be readable")
	var const_count: int = _count_matches(lines, "^\\s*const\\s+MAX_CONCURRENT_PARTICLE_EMITTERS\\b")
	assert_true(const_count > 0,
		"Story-AC: const MAX_CONCURRENT_PARTICLE_EMITTERS must be present in clean fixture")
	var var_count: int = _count_matches(lines, "^\\s*var\\s+MAX_CONCURRENT_PARTICLE_EMITTERS\\b")
	assert_eq(var_count, 0,
		"Story-AC: clean fixture must have 0 var MAX_CONCURRENT_PARTICLE_EMITTERS")


func test_particle_cap_absent_in_real_source_confirms_exit2_path() -> void:
	var lines := _read_lines(REAL_SOURCE)
	if lines.size() == 0:
		pending("enemy_director.gd not found — skipping")
		return
	assert_eq(_extract_const_value(lines, "MAX_CONCURRENT_PARTICLE_EMITTERS"), -1,
		"Story-AC: MAX_CONCURRENT_PARTICLE_EMITTERS must not yet exist in real source (Story 015 scope)")
