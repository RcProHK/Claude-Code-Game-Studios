#!/usr/bin/env -S godot --headless --script
## CI Lint — kill handlers must branch on get_active_workout_id() null (ADR-0009 late-bind)
##
## Story 001 (GDD Rule enforcement): per ADR-0009 §7.5 / INV-12, the cross-cutting
## `workout_id` context is LATE-BOUND at the handler and MUST have an explicit
## null branch — loot can drop from a boss/enemy kill that happens OUTSIDE an
## active workout (e.g. catch-up combat), and the system must handle the
## "no active workout" case deliberately rather than crashing or fabricating one.
## Each `_on_boss_killed` / `_on_enemy_killed` handler MUST reference
## `get_active_workout_id()` AND contain an explicit null check on its result.
##
## ── DETECTION STRATEGY (file-level co-existence HEURISTIC, MVP precision) ──────
## We locate each handler function (`func _on_boss_killed` / `func _on_enemy_killed`)
## and scan its BODY (until the next func opener / dedent to depth 0) for BOTH:
##   1. a `get_active_workout_id(` call, AND
##   2. an explicit null branch — one of:
##        `== null`, `!= null`, `is_empty()`, `is_valid()`, `if not ` on the id var.
## A handler missing either is flagged. This is a textual intra-function check, NOT
## a control-flow proof; it catches the structural omission (handler ignores the
## null case entirely). The runtime null guard is the authoritative defense.
##
## ── TARGET-ABSENCE POLICY ────────────────────────────────────────────────────
## loot_drop_system.gd is created in Story 009 → missing target = EXIT 0.
##
## Usage:
##   godot --headless --script tools/ci/check_loot_workout_id_resolution.gd
##
## Exit codes:
##   0 = every kill handler resolves + null-branches workout_id (clean) — OR target absent
##   1 = a handler missing the resolution or the null branch (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: design/gdd/loot-drop-system.md (EC workout-id); ADR-0009 §7.5
##   late-bind + explicit null branch; story-001-ci-lints-closed-api.md.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const TARGET_FILE: String = "res://src/autoload/loot_drop_system.gd"
const LINT_TAG: String = "check_loot_workout_id_resolution"
const HANDLER_PATTERN: String = "^[ \\t]*func[ \\t]+_on_(boss|enemy)_killed\\b"
const FUNC_OPENER_PATTERN: String = "^[ \\t]*(static[ \\t]+)?func[ \\t]+"
const RESOLVE_PATTERN: String = "get_active_workout_id\\s*\\("
## Any one of these in the handler body counts as an explicit null branch.
const NULL_BRANCH_PATTERNS: PackedStringArray = [
	"==\\s*null",
	"!=\\s*null",
	"\\.is_empty\\s*\\(",
	"\\.is_valid\\s*\\(",
	"if[ \\t]+not[ \\t]",
	"is_instance_valid\\s*\\(",
]


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	if not FileAccess.file_exists(TARGET_FILE):
		print("[%s] PASS (target absent): %s not yet created" % [LINT_TAG, TARGET_FILE])
		quit(0)
		return

	var re_handler := _compile(HANDLER_PATTERN)
	var re_func := _compile(FUNC_OPENER_PATTERN)
	var re_resolve := _compile(RESOLVE_PATTERN)
	if re_handler == null or re_func == null or re_resolve == null:
		quit(2)
		return
	var null_res: Array[RegEx] = []
	for ps: String in NULL_BRANCH_PATTERNS:
		var r := _compile(ps)
		if r == null:
			quit(2)
			return
		null_res.append(r)

	var lines := _read_lines(TARGET_FILE)

	var violations: Array[Dictionary] = []
	var i := 0
	while i < lines.size():
		var line: String = lines[i]
		if re_handler.search(line) == null:
			i += 1
			continue
		# Found a handler; its body runs until the next func opener.
		var handler_start := i
		var body_end := lines.size()
		for j: int in range(i + 1, lines.size()):
			if re_func.search(lines[j]) != null:
				body_end = j
				break
		var has_resolve := false
		var has_null_branch := false
		for j: int in range(handler_start, body_end):
			var body_line: String = lines[j]
			if body_line.strip_edges(true, false).begins_with("#"):
				continue
			if re_resolve.search(body_line) != null:
				has_resolve = true
			for r: RegEx in null_res:
				if r.search(body_line) != null:
					has_null_branch = true
					break
		if not has_resolve or not has_null_branch:
			var missing := ""
			if not has_resolve:
				missing = "no get_active_workout_id() call"
			elif not has_null_branch:
				missing = "no explicit null branch on workout_id"
			violations.append({
				"line": handler_start + 1,
				"snippet": lines[handler_start].strip_edges(),
				"missing": missing,
			})
		i = body_end

	if violations.is_empty():
		print("[%s] PASS: every _on_boss/enemy_killed handler resolves + null-branches workout_id" % LINT_TAG)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: kill handler missing workout_id resolution — %s (ADR-0009 §7.5 late-bind + explicit null branch)" % [TARGET_FILE, v["line"], v["missing"]])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d handler(s) missing workout_id null-branch." % [LINT_TAG, violations.size()])
	quit(1)


func _read_lines(file_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[%s] cannot read: %s" % [LINT_TAG, file_path])
		return out
	while not file.eof_reached():
		out.append(file.get_line())
	file.close()
	return out


func _compile(pattern: String) -> RegEx:
	var re := RegEx.new()
	if re.compile(pattern) != OK:
		push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
		return null
	return re
