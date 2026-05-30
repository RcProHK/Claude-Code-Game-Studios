#!/usr/bin/env -S godot --headless --script
## CI Lint — Formula E3 loop must have a termination guard + monotonic assert
##
## Story 001 (GDD Rule enforcement): Formula E3
## (`expected_weekly_rarity_distribution`) iterates to converge a weekly rarity
## distribution. An un-bounded convergence loop in web-export GDScript is a hang
## risk (Pillar 2 — must never freeze a mid-set UI). The implementation MUST carry
## BOTH:
##   1. a `max_iterations` bound (the loop cannot run forever), AND
##   2. a monotonic-progress `assert(...)` (each pass moves toward convergence,
##      catching a stuck / oscillating loop in debug builds).
##
## ── DETECTION STRATEGY (file-level co-existence HEURISTIC, MVP precision) ──────
## We locate `func expected_weekly_rarity_distribution(` and scan its body (until
## the next func opener) for BOTH a `max_iterations` token AND an `assert(` token.
## This is a textual presence check — it does NOT verify the bound is actually
## applied to the loop condition or that the assert expresses true monotonicity.
## It catches the omission (a convergence function with no guard at all); the
## actual loop bound is the authoritative runtime defense.
##
## ── TARGET-ABSENCE POLICY ────────────────────────────────────────────────────
## loot_drop_system.gd is created in Story 009 → missing target = EXIT 0.
## The function is implemented in Story 008 (E3); until it appears, EXIT 0.
##
## Usage:
##   godot --headless --script tools/ci/check_loot_e3_termination_guard.gd
##
## Exit codes:
##   0 = E3 function has both guards, OR function/target absent (pre-Story-008/009)
##   1 = E3 function present but missing max_iterations or assert (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: design/gdd/loot-drop-system.md Formula E3 (Pillar 2 no-hang);
##   story-001-ci-lints-closed-api.md.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const TARGET_FILE: String = "res://src/autoload/loot_drop_system.gd"
const LINT_TAG: String = "check_loot_e3_termination_guard"
const E3_FUNC_PATTERN: String = "^[ \\t]*(static[ \\t]+)?func[ \\t]+expected_weekly_rarity_distribution\\b"
const FUNC_OPENER_PATTERN: String = "^[ \\t]*(static[ \\t]+)?func[ \\t]+"
const MAX_ITER_PATTERN: String = "max_iterations\\b"
const ASSERT_PATTERN: String = "\\bassert\\s*\\("


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	if not FileAccess.file_exists(TARGET_FILE):
		print("[%s] PASS (target absent): %s not yet created" % [LINT_TAG, TARGET_FILE])
		quit(0)
		return

	var re_e3 := _compile(E3_FUNC_PATTERN)
	var re_func := _compile(FUNC_OPENER_PATTERN)
	var re_max := _compile(MAX_ITER_PATTERN)
	var re_assert := _compile(ASSERT_PATTERN)
	if re_e3 == null or re_func == null or re_max == null or re_assert == null:
		quit(2)
		return

	var lines := _read_lines(TARGET_FILE)

	var found_e3 := false
	var violations: Array[Dictionary] = []
	var i := 0
	while i < lines.size():
		if re_e3.search(lines[i]) == null:
			i += 1
			continue
		found_e3 = true
		var func_start := i
		var body_end := lines.size()
		for j: int in range(i + 1, lines.size()):
			if re_func.search(lines[j]) != null:
				body_end = j
				break

		var has_max := false
		var has_assert := false
		for j: int in range(func_start, body_end):
			var bl: String = lines[j]
			if bl.strip_edges(true, false).begins_with("#"):
				continue
			if re_max.search(bl) != null:
				has_max = true
			if re_assert.search(bl) != null:
				has_assert = true

		if not has_max or not has_assert:
			var missing: PackedStringArray = []
			if not has_max:
				missing.append("max_iterations bound")
			if not has_assert:
				missing.append("monotonic assert(...)")
			violations.append({
				"line": func_start + 1,
				"snippet": lines[func_start].strip_edges(),
				"missing": ", ".join(missing),
			})
		i = body_end

	# Function not yet implemented (pre-Story-008) → clean.
	if not found_e3:
		print("[%s] PASS: expected_weekly_rarity_distribution not yet implemented — nothing to guard" % LINT_TAG)
		quit(0)
		return

	if violations.is_empty():
		print("[%s] PASS: Formula E3 has both a max_iterations bound and a monotonic assert" % LINT_TAG)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: Formula E3 missing termination guard — %s (Pillar 2 no-hang)" % [TARGET_FILE, v["line"], v["missing"]])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d E3 termination-guard violation(s)." % [LINT_TAG, violations.size()])
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
