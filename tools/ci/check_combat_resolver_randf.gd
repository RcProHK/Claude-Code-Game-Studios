#!/usr/bin/env -S godot --headless --script
## CI Lint — CombatResolver must NOT call global RNG (FR-1, GDD Rule, ADR-0006 C12)
##
## AC-randf-lint / Story 001: RNG must be CALLER-INJECTED via `ctx.rng`
## (a seeded RandomNumberGenerator the caller owns) so combat replays are
## deterministic (FR-1 binding). A bare `randf()` / `randi()` reads Godot's
## global, un-seeded generator — that makes resolve_hit non-reproducible.
##
## Forbidden in `src/core/combat_resolver.gd`:
##   randf(   randi(   randf_range(   RandomNumberGenerator.new(
##
## ALLOWED: `ctx.rng.randf()`, `ctx.rng.randi()` etc. — those call the INJECTED
## generator. The patterns below match the bare global calls and the in-file
## `.new()` construction (the resolver must never mint its own RNG).
##
## NOTE: `ctx.rng.randf()` contains the substring `randf(` but the regex
## `(?<![\w.])randf\(` uses a negative-lookbehind so a preceding `.` (method call
## on an object) does NOT match — only the bare global `randf(` is flagged.
##
## Usage:
##   godot --headless --script tools/ci/check_combat_resolver_randf.gd
##
## Exit codes:
##   0 = no global RNG calls (clean)
##   1 = one or more forbidden RNG calls (CI MUST fail)
##   2 = internal error (target file / src/ missing, regex compile failure)
##
## Governing docs: design/gdd/combat-resolver.md FR-1; ADR-0006 Contract 12;
##   story-001-ci-lints-purity-defense.md AC-randf-lint.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const TARGET_FILE: String = "res://src/core/combat_resolver.gd"
## Negative-lookbehind `(?<![\w.])` excludes `ctx.rng.randf(` (preceded by `.`)
## and identifiers ending in randf/randi. `RandomNumberGenerator\.new\(` bans
## in-file construction of a fresh generator.
const PATTERNS: PackedStringArray = [
	"(?<![\\w.])randf\\(",
	"(?<![\\w.])randi\\(",
	"(?<![\\w.])randf_range\\(",
	"RandomNumberGenerator\\.new\\(",
]
const FAIL_MESSAGE: String = "global/owned RNG forbidden — RNG must be caller-injected via ctx.rng (FR-1, ADR-0006 C12)"
const LINT_TAG: String = "check_combat_resolver_randf"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	if not FileAccess.file_exists(TARGET_FILE):
		push_error("[%s] target not found: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
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
			continue  # skip full-line comments (doc-comment mentions of randf are not code)
		for re: RegEx in regexes:
			var m := re.search(line)
			if m != null:
				violations.append({"line": i + 1, "col": m.get_start() + 1, "snippet": line.strip_edges()})
				break

	if violations.is_empty():
		print("[%s] PASS: %s makes no global/owned RNG calls" % [LINT_TAG, TARGET_FILE])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: %s" % [TARGET_FILE, v["line"], v["col"], FAIL_MESSAGE])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)
