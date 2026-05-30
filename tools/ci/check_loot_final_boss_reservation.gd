#!/usr/bin/env -S godot --headless --script
## CI Lint — FINAL_BOSS drops must use the reserved final pool, not the mini pool
##
## Story 001 (GDD Rule enforcement): the final-boss loot ceremony draws from a
## RESERVED emit counter pool (`_emit_counter_final`) so its guaranteed-quality
## reward (ADR-0005 final-boss floor = UNCOMMON, Formula 1) cannot be starved by
## the same per-window cap that throttles mini-boss / regular drops
## (`_emit_counter_mini`). A FINAL_BOSS code path that decrements / consults the
## MINI counter would let a busy session exhaust the cap before the final reward,
## breaking the Pillar 3 "the big moment always lands" guarantee.
##
## ── DETECTION STRATEGY (file-level co-existence HEURISTIC, MVP precision) ──────
## We locate each function whose body references `FINAL_BOSS` (the source-event
## kind) and flag it if that SAME function body ALSO references `_emit_counter_mini`
## without referencing `_emit_counter_final`. Symmetrically, a function dealing
## with FINAL_BOSS should touch `_emit_counter_final`. This is a textual
## intra-function co-existence check — it does NOT prove which counter the runtime
## branch actually decrements. It catches the wiring mistake (final path reaching
## for the mini pool); the runtime pool selection is the authoritative defense.
##
## ── TARGET-ABSENCE POLICY ────────────────────────────────────────────────────
## loot_drop_system.gd is created in Story 009 → missing target = EXIT 0.
##
## Usage:
##   godot --headless --script tools/ci/check_loot_final_boss_reservation.gd
##
## Exit codes:
##   0 = no FINAL_BOSS function reaches for the mini pool (clean) — OR target absent
##   1 = a FINAL_BOSS path uses _emit_counter_mini (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: design/gdd/loot-drop-system.md (final boss reservation, Pillar 3);
##   ADR-0005 (final boss floor); story-001-ci-lints-closed-api.md.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const TARGET_FILE: String = "res://src/autoload/loot_drop_system.gd"
const LINT_TAG: String = "check_loot_final_boss_reservation"
const FUNC_OPENER_PATTERN: String = "^[ \\t]*(static[ \\t]+)?func[ \\t]+"
const FINAL_BOSS_PATTERN: String = "\\bFINAL_BOSS\\b"
const MINI_COUNTER_PATTERN: String = "_emit_counter_mini\\b"
const FINAL_COUNTER_PATTERN: String = "_emit_counter_final\\b"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	if not FileAccess.file_exists(TARGET_FILE):
		print("[%s] PASS (target absent): %s not yet created" % [LINT_TAG, TARGET_FILE])
		quit(0)
		return

	var re_func := _compile(FUNC_OPENER_PATTERN)
	var re_final_kind := _compile(FINAL_BOSS_PATTERN)
	var re_mini := _compile(MINI_COUNTER_PATTERN)
	var re_final_counter := _compile(FINAL_COUNTER_PATTERN)
	if re_func == null or re_final_kind == null or re_mini == null or re_final_counter == null:
		quit(2)
		return

	var lines := _read_lines(TARGET_FILE)

	var violations: Array[Dictionary] = []
	var i := 0
	while i < lines.size():
		if re_func.search(lines[i]) == null:
			i += 1
			continue
		var func_start := i
		var body_end := lines.size()
		for j: int in range(i + 1, lines.size()):
			if re_func.search(lines[j]) != null:
				body_end = j
				break

		var has_final_kind := false
		var has_mini := false
		var has_final_counter := false
		var mini_line := -1
		for j: int in range(func_start, body_end):
			var bl: String = lines[j]
			if bl.strip_edges(true, false).begins_with("#"):
				continue
			if re_final_kind.search(bl) != null:
				has_final_kind = true
			if re_mini.search(bl) != null:
				has_mini = true
				if mini_line < 0:
					mini_line = j
			if re_final_counter.search(bl) != null:
				has_final_counter = true

		# A function that handles FINAL_BOSS and touches the mini pool but NOT the
		# final pool is reaching for the wrong reservation.
		if has_final_kind and has_mini and not has_final_counter:
			violations.append({
				"line": mini_line + 1,
				"func_line": func_start + 1,
				"func_snippet": lines[func_start].strip_edges(),
				"snippet": lines[mini_line].strip_edges(),
			})
		i = body_end

	if violations.is_empty():
		print("[%s] PASS: no FINAL_BOSS code path reaches for the mini emit pool" % LINT_TAG)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: FINAL_BOSS path uses _emit_counter_mini (function at line %d) — final boss drops must use the reserved _emit_counter_final pool (Pillar 3, ADR-0005 floor)" % [TARGET_FILE, v["line"], v["func_line"]])
		printerr("  func > %s" % v["func_snippet"])
		printerr("  use  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d FINAL_BOSS path(s) using the mini pool." % [LINT_TAG, violations.size()])
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
