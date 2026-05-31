#!/usr/bin/env -S godot --headless --script
## CI Lint — EnemyDirector signal subscription via Contract 6 helper (GDD Rule 2).
##
## Purpose (GDD Rule 2 / ADR-0006 Contract 6 / TR-enemy-005):
##   Subscriptions to #12 AbilitySystem.ability_cast and #1 GameStateMachine.
##   state_changed MUST go through the `connect_for_initial_state` helper, never a
##   raw `.connect()`. The helper back-fills the initial state for a late-booting
##   subscriber (EnemyDirector boots last) — a raw `.connect()` would miss the
##   initial state emitted before EnemyDirector's `_ready()` runs.
##
## Scan target:
##   res://src/autoload/enemy_director.gd  (this single file ONLY).
##
## Forbidden patterns (raw signal-object .connect on the two governed signals):
##   AbilitySystem\.ability_cast\.connect\(
##   GameStateMachine\.state_changed\.connect\(
##
## Sanctioned alternative (NOT matched — passes): the helper call form
##   AbilitySystem.connect_for_initial_state(self, &"_on_ability_cast", &"ability_cast")
##   GameStateMachine.connect_for_initial_state(self, &"_on_state_changed", &"state_changed")
##   These do not contain `.ability_cast.connect(` / `.state_changed.connect(`, so
##   they never match the forbidden patterns.
##
## Usage:
##   godot --headless --script tools/ci/check_enemy_director_signal_subscription.gd
##
## Exit codes:
##   0 = no raw .connect() on governed signals (clean)
##   1 = one or more raw subscriptions found (CI MUST fail)
##   2 = internal error (target file missing, regex compile failure, unreadable)
##
## Governing docs: design/gdd/enemy-director.md Rule 2; ADR-0006 Contract 6;
##   TR-enemy-005; story-003-ci-lint-suite-b.md.
extends SceneTree


const TARGET_FILE: String = "res://src/autoload/enemy_director.gd"
const LINT_TAG: String = "check_enemy_director_signal_subscription"

## Raw subscription patterns that bypass the connect_for_initial_state helper.
const FORBIDDEN_PATTERNS: Array[String] = [
	"AbilitySystem\\.ability_cast\\.connect\\(",
	"GameStateMachine\\.state_changed\\.connect\\(",
]


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_error("[%s] target not found: %s" % [LINT_TAG, TARGET_FILE])
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
	for i: int in lines.size():
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
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
		print("[%s] PASS: %s — 0 raw subscriptions; all governed signals via connect_for_initial_state" % [
			LINT_TAG, TARGET_FILE,
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: raw signal .connect() FORBIDDEN — use connect_for_initial_state (Contract 6) (pattern: %s)" % [
			TARGET_FILE, v["line"], v["col"], v["pattern"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d raw subscription(s). Route through connect_for_initial_state helper." % [LINT_TAG, violations.size()])
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
