#!/usr/bin/env -S godot --headless --script
## CI Lint — CombatResolver must NOT read StatSystem directly (GDD Rule 6, ADR-0006 C12)
##
## AC-stat-calls-lint / Story 001: caster stats arrive PRE-SNAPSHOTTED in
## `ctx.caster_stats` (a StatSnapshot). The resolver must never call
## `StatSystem.get_stat(...)` (or any `StatSystem.` member) — a live read voids
## replay determinism and the Pillar-1 anti-fabrication snapshot chain (Rule 6).
##
## This is a NARROWER, dedicated lint (separate from check_combat_resolver_engine_
## singletons, which also covers StatSystem) so CI output names the exact rule:
## "stats arrive via snapshot, not via StatSystem".
##
## Forbidden in `src/core/combat_resolver.gd`:
##   StatSystem.
##
## Usage:
##   godot --headless --script tools/ci/check_combat_resolver_stat_calls.gd
##
## Exit codes:
##   0 = no StatSystem references (clean)
##   1 = one or more StatSystem references (CI MUST fail)
##   2 = internal error (target file / src/ missing, regex compile failure)
##
## Governing docs: design/gdd/combat-resolver.md Rule 6; ADR-0006 Contract 12;
##   story-001-ci-lints-purity-defense.md AC-stat-calls-lint.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const TARGET_FILE: String = "res://src/core/combat_resolver.gd"
const PATTERN: String = "StatSystem\\."
const FAIL_MESSAGE: String = "direct StatSystem read forbidden — caster stats arrive via ctx.caster_stats snapshot (GDD Rule 6, ADR-0006 C12)"
const LINT_TAG: String = "check_combat_resolver_stat_calls"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	if not FileAccess.file_exists(TARGET_FILE):
		push_error("[%s] target not found: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(PATTERN) != OK:
		push_error("[%s] regex compile failed: %s" % [LINT_TAG, PATTERN])
		quit(2)
		return

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
			continue  # skip full-line comments (doc-comment mentions of StatSystem are not code)
		var m := re.search(line)
		if m != null:
			violations.append({"line": i + 1, "col": m.get_start() + 1, "snippet": line.strip_edges()})

	if violations.is_empty():
		print("[%s] PASS: %s makes no direct StatSystem reads" % [LINT_TAG, TARGET_FILE])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: %s" % [TARGET_FILE, v["line"], v["col"], FAIL_MESSAGE])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)
