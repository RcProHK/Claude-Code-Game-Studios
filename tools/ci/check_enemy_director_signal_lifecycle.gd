#!/usr/bin/env -S godot --headless --script
## CI Lint — EnemyDirector signal lifecycle: no connect/disconnect in hot path (AC-10).
##
## Purpose (GDD Rule 2 / TR-enemy-008 / ADR-0006 Contract 6):
##   All signal connections are one-time, established in `_ready()`. Calling
##   `.connect(` or `.disconnect(` inside a per-frame / per-cast hot path
##   (`_physics_process` or `_on_ability_cast`) is FORBIDDEN — it churns
##   connection tables every frame/cast (CPU spike against the ADR-001 budget) and
##   risks dropping the order-resilient initial-state subscription mid-combat.
##
## Scan target:
##   res://src/autoload/enemy_director.gd  (this single file ONLY).
##
## Forbidden inside HOT-PATH method bodies only:
##   \.connect\(        \.disconnect\(
##
## Hot-path method scope heuristic (mirrors the scope-aware randf/stat lints):
##   A method opens at a line matching `^\s*func\s+<name>\b` for name in
##   {_physics_process, _on_ability_cast}. The body is every more-indented line
##   after the declaration; the method ends at the first zero-indented non-blank
##   non-comment line (GDScript dedent = end of block). `.connect(`/`.disconnect(`
##   anywhere outside these two method bodies is allowed (e.g. in `_ready()`).
##
## Usage:
##   godot --headless --script tools/ci/check_enemy_director_signal_lifecycle.gd
##
## Exit codes:
##   0 = no connect/disconnect in hot-path bodies (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (target file missing, regex compile failure, unreadable)
##
## Governing docs: design/gdd/enemy-director.md Rule 2; ADR-0006 Contract 6;
##   TR-enemy-008; story-003-ci-lint-suite-b.md AC-10.
extends SceneTree


const TARGET_FILE: String = "res://src/autoload/enemy_director.gd"
const LINT_TAG: String = "check_enemy_director_signal_lifecycle"

## Forbidden connection-mutation patterns inside hot-path bodies.
const FORBIDDEN_PATTERNS: Array[String] = [
	"\\.connect\\(",
	"\\.disconnect\\(",
]

## Method names whose bodies are hot-path zones (connect/disconnect forbidden).
const HOT_PATH_METHODS: Array[String] = [
	"_physics_process",
	"_on_ability_cast",
]


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_error("[%s] target not found: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	# Compile one func-declaration regex matching any hot-path method.
	var func_pattern: String = "^\\s*func\\s+(%s)\\b" % "|".join(HOT_PATH_METHODS)
	var re_func := RegEx.new()
	if re_func.compile(func_pattern) != OK:
		push_error("[%s] hot-path func regex compile failed: %s" % [LINT_TAG, func_pattern])
		quit(2)
		return

	# Generic func-declaration regex (to detect ANY method opening, which closes scope).
	var re_any_func := RegEx.new()
	if re_any_func.compile("^\\s*func\\s+\\w+") != OK:
		push_error("[%s] generic func regex compile failed" % LINT_TAG)
		quit(2)
		return

	var compiled: Array[RegEx] = []
	for pattern: String in FORBIDDEN_PATTERNS:
		var re := RegEx.new()
		if re.compile(pattern) != OK:
			push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
			quit(2)
			return
		compiled.append(re)

	var lines: PackedStringArray = _read_lines(abs_path)
	if lines.is_empty():
		push_error("[%s] unreadable or empty: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var violations: Array[Dictionary] = []
	var inside_hot_path: bool = false

	for i: int in lines.size():
		var line: String = lines[i]
		var stripped: String = line.strip_edges()

		# Comments / blanks never open or close scope and never violate.
		if stripped.begins_with("#") or stripped == "":
			continue

		# Scope end: a zero-indented non-blank non-comment line ends the current method.
		if inside_hot_path and not line.begins_with("\t") and not line.begins_with(" "):
			inside_hot_path = false

		# A new func declaration (any) closes the previous hot-path body...
		if re_any_func.search(line) != null:
			# ...and re-opens scope only if THIS func is a hot-path method.
			inside_hot_path = re_func.search(line) != null
			continue  # the `func ...:` line itself is never a violation

		if not inside_hot_path:
			continue

		for j: int in compiled.size():
			var m := compiled[j].search(line)
			if m != null:
				violations.append({
					"line": i + 1,
					"col": m.get_start() + 1,
					"pattern": FORBIDDEN_PATTERNS[j],
					"snippet": stripped,
				})

	if violations.is_empty():
		print("[%s] PASS: %s — 0 connect/disconnect in hot-path bodies" % [LINT_TAG, TARGET_FILE])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: signal connect/disconnect FORBIDDEN in hot path — connect once in _ready() (pattern: %s)" % [
			TARGET_FILE, v["line"], v["col"], v["pattern"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d hot-path connection-mutation violation(s)." % [LINT_TAG, violations.size()])
	quit(1)


func _read_lines(abs_path: String) -> PackedStringArray:
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines
