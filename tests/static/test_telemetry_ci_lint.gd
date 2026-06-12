extends GutTest
## Telemetry (#28) — Stories 013/014/015 CI lint verification.
##
## Mirrors the forbidden-pattern detection of the three telemetry CI lints inline (the CLI
## scripts call quit(), which would tear down the GUT tree — same approach as
## test_onboarding_ci_lint.gd / test_cvf_ci_lint.gd). For each lint it verifies:
##   * the shipped telemetry source is clean (must-not-regress), and
##   * a deliberate violation fixture is flagged (proves the guard actually fires).
##
## The mirrored constants/patterns MUST stay byte-identical to the CLI scripts:
##   - tools/ci/check_telemetry_no_gameplay_emit.gd   (G-TEL-2, Story 013)
##   - tools/ci/check_telemetry_no_pii.gd             (G-TEL-3, Story 014)
##   - tools/ci/check_telemetry_frozen_schema.gd      (G-TEL-4, Story 015)

const AUTOLOAD: String = "res://src/autoload/telemetry.gd"
const SRC_DIR: String = "res://src/telemetry"
const EMIT_FIXTURE: String = "res://tests/fixtures/telemetry_gameplay_emit_violation.gd"
const PII_FIXTURE: String = "res://tests/fixtures/telemetry_pii_violation.gd"
const FROZEN_FIXTURE: String = "res://tests/fixtures/telemetry_frozen_schema_violation.gd"

# --- G-TEL-2 mirror (check_telemetry_no_gameplay_emit.gd) ----------------------
const OWNED_META: Array[String] = [
	"telemetry_self_error", "duplicate_transition_observed",
	"out_of_order_observed", "dropped_count",
]
const NAMESPACE_WRITE_PATTERN: String = "\"(loot|stat|ability|streak)\\."
const MUTATOR_PATTERN: String = "\\b(set_stat|apply_stat_delta|unlock_ability|grant_ability|cast_ability|generate_drop|spawn_loot|claim_drop|claim_daily|force_transition|request_transition|start_workout|complete_workout)\\s*\\("
const EMIT_SIGNAL_PATTERN: String = "\\bemit_signal\\s*\\(\\s*&?\"(\\w+)\""
const DOT_EMIT_PATTERN: String = "\\b(\\w+)\\.emit\\s*\\("

# --- G-TEL-3 mirror (check_telemetry_no_pii.gd) --------------------------------
const FORBIDDEN_FIELDS: Array[String] = [
	"weight_kg", "bodyweight", "body_weight", "body_mass",
	"one_rep_max", "raw_weight", "absolute_weight",
	"absolute_1rm", "raw_1rm", "set_weight",
	"kg_lifted", "lbs_lifted", "lift_kg",
]

# --- G-TEL-4 mirror (check_telemetry_frozen_schema.gd) -------------------------
const FROZEN_SCHEMA: Dictionary = {
	"loot_dropped": {
		1: ["drop_id", "rarity_tier", "item_type", "transition_id"],
	},
}


# --- helpers ------------------------------------------------------------------

func _read_lines(res_path: String) -> PackedStringArray:
	var file := FileAccess.open(ProjectSettings.globalize_path(res_path), FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines


func _read_text(res_path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(res_path), FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _telemetry_sources() -> Array[String]:
	var out: Array[String] = [AUTOLOAD]
	var dir := DirAccess.open(SRC_DIR)
	if dir != null:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir() and name.ends_with(".gd"):
				out.append(SRC_DIR + "/" + name)
			name = dir.get_next()
		dir.list_dir_end()
	return out


func _compile(pattern: String) -> RegEx:
	var re := RegEx.new()
	assert_eq(re.compile(pattern), OK, "pattern must compile: %s" % pattern)
	return re


# --- G-TEL-2: no gameplay emit ------------------------------------------------

func _count_gameplay_emits(lines: PackedStringArray) -> int:
	var re_ns := _compile(NAMESPACE_WRITE_PATTERN)
	var re_mut := _compile(MUTATOR_PATTERN)
	var re_emit := _compile(EMIT_SIGNAL_PATTERN)
	var re_dot := _compile(DOT_EMIT_PATTERN)
	var count := 0
	for line: String in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		if re_ns.search(line) != null or re_mut.search(line) != null:
			count += 1
			continue
		var m := re_emit.search(line)
		if m != null and not OWNED_META.has(m.get_string(1)):
			count += 1
			continue
		var d := re_dot.search(line)
		if d != null and not OWNED_META.has(d.get_string(1)):
			count += 1
	return count


func test_telemetry_source_has_zero_gameplay_emit() -> void:
	for path: String in _telemetry_sources():
		var lines := _read_lines(path)
		assert_gt(lines.size(), 0, "telemetry source must be readable: %s" % path)
		assert_eq(_count_gameplay_emits(lines), 0,
			"G-TEL-2/Rule 1: %s must be a pure observer (zero gameplay emit/mutator/namespace write)" % path)


func test_gameplay_emit_violation_fixture_is_flagged() -> void:
	var lines := _read_lines(EMIT_FIXTURE)
	assert_gt(lines.size(), 0, "emit violation fixture must exist")
	assert_eq(_count_gameplay_emits(lines), 3,
		"fixture's 3 violations (stat.* write / claim_drop / loot_dropped emit) detected; 2 owned-meta emits exempt")


# --- G-TEL-3: no PII ----------------------------------------------------------

func _count_pii(lines: PackedStringArray) -> int:
	var alt := "|".join(FORBIDDEN_FIELDS)
	var re_quoted := _compile("\"(%s)\"" % alt)
	var re_bare := _compile("\\b(%s)\\b\\s*(:=|[:=])" % alt)
	var count := 0
	for line: String in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		if re_quoted.search(line) != null or re_bare.search(line) != null:
			count += 1
	return count


func test_telemetry_source_has_zero_pii() -> void:
	for path: String in _telemetry_sources():
		var lines := _read_lines(path)
		assert_gt(lines.size(), 0, "telemetry source must be readable: %s" % path)
		assert_eq(_count_pii(lines), 0,
			"G-TEL-3/Rule 4: %s must carry only de-identified values (zero raw body data)" % path)


func test_pii_violation_fixture_is_flagged() -> void:
	var lines := _read_lines(PII_FIXTURE)
	assert_gt(lines.size(), 0, "PII violation fixture must exist")
	assert_eq(_count_pii(lines), 3,
		"fixture's 3 raw body fields (weight_kg / one_rep_max / bodyweight) detected; normalized values exempt")


# --- G-TEL-4: frozen schema ---------------------------------------------------

func _match_paren(text: String, open_idx: int) -> int:
	var depth := 0
	var i := open_idx
	var in_str := false
	var quote := ""
	while i < text.length():
		var c: String = text[i]
		if in_str:
			if c == "\\":
				i += 2
				continue
			if c == quote:
				in_str = false
		else:
			if c == "\"" or c == "'":
				in_str = true
				quote = c
			elif c == "(":
				depth += 1
			elif c == ")":
				depth -= 1
				if depth == 0:
					return i
		i += 1
	return -1


## Returns [{event, version, keys:[...]}] for every frozen-event serialize call.
func _extract_frozen_calls(text: String) -> Array[Dictionary]:
	var re_call := _compile("\\b_record(?:_dedup)?\\s*\\(\\s*&?\"(\\w+)\"")
	var re_key := _compile("\"(\\w+)\"\\s*:")
	var re_version := _compile("Priority\\.\\w+\\s*,\\s*(\\d+)\\s*\\)")
	var out: Array[Dictionary] = []
	var from := 0
	while true:
		var m := re_call.search(text, from)
		if m == null:
			break
		var event: String = m.get_string(1)
		var open_paren: int = text.rfind("(", m.get_end())
		if open_paren < 0:
			open_paren = m.get_end() - 1
		var close_paren: int = _match_paren(text, open_paren)
		from = m.get_end()
		if close_paren < 0 or not FROZEN_SCHEMA.has(event):
			continue
		var body: String = text.substr(open_paren + 1, close_paren - open_paren - 1)
		var keys: Array[String] = []
		for km: RegExMatch in re_key.search_all(body):
			keys.append(km.get_string(1))
		var version := 1
		var vm := re_version.search(body)
		if vm != null:
			version = int(vm.get_string(1))
		out.append({"event": event, "version": version, "keys": keys})
	return out


func _frozen_violation_count(text: String) -> int:
	var count := 0
	for info: Dictionary in _extract_frozen_calls(text):
		var versions: Dictionary = FROZEN_SCHEMA[info["event"]]
		if not versions.has(info["version"]):
			count += 1
			continue
		var got: Array = (info["keys"] as Array).duplicate()
		var want: Array = (versions[info["version"]] as Array).duplicate()
		got.sort()
		want.sort()
		if got != want:
			count += 1
	return count


func test_telemetry_loot_dropped_matches_frozen_v1() -> void:
	var text := _read_text(AUTOLOAD)
	assert_ne(text, "", "telemetry.gd must be readable")
	var calls := _extract_frozen_calls(text)
	assert_eq(calls.size(), 1, "exactly one loot_dropped frozen serialize point expected")
	assert_eq(int(calls[0]["version"]), 1, "loot_dropped must serialize at schema_version 1 (loot_dropped_v1)")
	var got: Array = (calls[0]["keys"] as Array).duplicate()
	got.sort()
	var want: Array = ["drop_id", "item_type", "rarity_tier", "transition_id"]
	assert_eq(got, want, "G-TEL-4/FR-LOOT-3: loot_dropped_v1 field set frozen to exactly 4 fields")
	assert_eq(_frozen_violation_count(text), 0, "shipped telemetry has zero frozen-schema drift")


func test_frozen_schema_violation_fixture_is_flagged() -> void:
	var text := _read_text(FROZEN_FIXTURE)
	assert_ne(text, "", "frozen-schema violation fixture must exist")
	assert_eq(_frozen_violation_count(text), 1,
		"fixture's 5th-field loot_dropped (still v1) is flagged as frozen-set drift (EC-16)")
