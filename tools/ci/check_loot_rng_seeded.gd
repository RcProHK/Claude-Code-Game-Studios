#!/usr/bin/env -S godot --headless --script
## CI Lint — LootDropSystem must NOT call global/un-seeded RNG (ADR-0005, GDD AC-26)
##
## AC-26 / Story 001: loot rarity rolls MUST go through `_rng` — a seeded
## RandomNumberGenerator the system owns and re-seeds on `transition_id`
## (ADR-0005 "RNG seeded on transition_id"). A bare `randf()` / `randi()` reads
## Godot's global, un-seeded generator, breaking Pillar 1 replay-determinism
## (same workout + same transition_id MUST produce the same loot tier).
##
## Forbidden in `src/autoload/loot_drop_system.gd`:
##   randf(   randi(   randf_range(   randi_range(   RandomNumberGenerator.new(
##
## ALLOWED: `_rng.randf()`, `_rng.randi()` etc. — those call the OWNED, seeded
## generator. The negative-lookbehind `(?<![\w.])` excludes any call preceded by
## a `.` (a method call on an object) or by identifier characters, so only the
## bare global calls are flagged. `RandomNumberGenerator.new(` is banned outright
## EXCEPT when assigned to the `_rng` member (the system mints exactly one, seeded
## per transition) — see ALLOW_RNG_CONSTRUCT below.
##
## Usage:
##   godot --headless --script tools/ci/check_loot_rng_seeded.gd
##
## Exit codes:
##   0 = no global RNG calls (clean) — OR target file does not yet exist (pre-Story-009)
##   1 = one or more forbidden RNG calls (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure, unreadable file)
##
## TARGET-ABSENCE POLICY: loot_drop_system.gd is created in Story 009, AFTER this
## lint (Story 001). Per Story 001 spec ("Scripts must gracefully handle missing
## target files — non-fail when file absent"), a missing target is EXIT 0, not 2.
## This deliberately differs from the combat/ability lints (whose targets already
## existed when those lints were written and use quit(2) on missing target).
##
## Governing docs: design/gdd/loot-drop-system.md AC-26; ADR-0005 (RNG seeded on
##   transition_id); story-001-ci-lints-closed-api.md.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const TARGET_FILE: String = "res://src/autoload/loot_drop_system.gd"
const LINT_TAG: String = "check_loot_rng_seeded"
## Negative-lookbehind `(?<![\w.])` excludes `_rng.randf(` (preceded by `.`) and
## identifiers ending in randf/randi. `RandomNumberGenerator\.new\(` bans loose
## construction (handled with an allow-line exception for the `_rng` member).
const PATTERNS: PackedStringArray = [
	"(?<![\\w.])randf\\(",
	"(?<![\\w.])randi\\(",
	"(?<![\\w.])randf_range\\(",
	"(?<![\\w.])randi_range\\(",
	"RandomNumberGenerator\\.new\\(",
]
const FAIL_MESSAGE: String = "global/un-seeded RNG forbidden — loot rolls must use the owned, transition_id-seeded `_rng` (ADR-0005, AC-26)"
## The single legitimate `RandomNumberGenerator.new(` site: assigning the `_rng`
## member. A line that both constructs RNG and assigns it to `_rng` is allowed.
const ALLOW_RNG_CONSTRUCT_HINT: String = "_rng"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	# Pre-Story-009: target does not exist yet. Clean by definition.
	if not FileAccess.file_exists(TARGET_FILE):
		print("[%s] PASS (target absent): %s not yet created — nothing to scan" % [LINT_TAG, TARGET_FILE])
		quit(0)
		return

	var regexes: Array[RegEx] = []
	for ps: String in PATTERNS:
		var re := RegEx.new()
		if re.compile(ps) != OK:
			push_error("[%s] regex compile failed: %s" % [LINT_TAG, ps])
			quit(2)
			return
		regexes.append(re)

	var file := FileAccess.open(TARGET_FILE, FileAccess.READ)
	if file == null:
		push_error("[%s] cannot read: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	var violations: Array[Dictionary] = []
	for i: int in lines.size():
		var line: String = lines[i]
		if line.strip_edges(true, false).begins_with("#"):
			continue  # skip full-line comments (doc-comment mentions are not code)
		for re: RegEx in regexes:
			var m := re.search(line)
			if m == null:
				continue
			# Allow the single legitimate RNG construction: the `_rng` member.
			if m.get_string().begins_with("RandomNumberGenerator") and line.contains(ALLOW_RNG_CONSTRUCT_HINT):
				continue
			violations.append({"line": i + 1, "col": m.get_start() + 1, "snippet": line.strip_edges()})
			break

	if violations.is_empty():
		print("[%s] PASS: %s makes no global/un-seeded RNG calls" % [LINT_TAG, TARGET_FILE])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: %s" % [TARGET_FILE, v["line"], v["col"], FAIL_MESSAGE])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)
