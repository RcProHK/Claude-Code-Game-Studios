#!/usr/bin/env -S godot --headless --script
## CI Lint — every `loot_dropped` emit must be cap-checked first (GDD ceremony cap)
##
## Story 001 (GDD Rule enforcement): the loot ceremony has a per-window cap so a
## flood of kills cannot spam reveals (Pillar 2 — non-intrusive during a workout;
## Pillar 3 — ceremony stays meaningful). The function `_ceremony_cap_check()`
## gates each reveal. Every `emit_signal("loot_dropped", ...)` site MUST be
## preceded by a `_ceremony_cap_check` call within the SAME enclosing function.
##
## ── DETECTION STRATEGY (file-level co-existence HEURISTIC, MVP precision) ──────
## For each `emit_signal("loot_dropped")` line in loot_drop_system.gd, we look
## BACKWARD within the SAME function body (delimited by `func ` openers at the
## emit's-or-lower indent) for a `_ceremony_cap_check` reference. If none precedes
## the emit in that function, it is flagged. This is a textual, intra-function
## co-existence check — NOT a control-flow proof that the cap actually returned
## true / branched. It catches the structural mistake (an emit in a function that
## never consults the cap); the runtime cap (an early-return inside
## `_ceremony_cap_check`) is the authoritative second line of defense.
##
## ── TARGET-ABSENCE POLICY ────────────────────────────────────────────────────
## loot_drop_system.gd is created in Story 009 → missing target = EXIT 0.
##
## Usage:
##   godot --headless --script tools/ci/check_loot_ceremony_cap.gd
##
## Exit codes:
##   0 = every loot_dropped emit is preceded by a cap check (clean) — OR target absent
##   1 = an emit lacks a preceding _ceremony_cap_check in its function (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: design/gdd/loot-drop-system.md (ceremony cap, Pillar 2/3);
##   story-001-ci-lints-closed-api.md.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const TARGET_FILE: String = "res://src/autoload/loot_drop_system.gd"
const LINT_TAG: String = "check_loot_ceremony_cap"
const EMIT_PATTERN: String = "emit_signal\\s*\\(\\s*[\"']loot_dropped[\"']"
const CAP_PATTERN: String = "_ceremony_cap_check\\b"
const FUNC_OPENER_PATTERN: String = "^[ \\t]*(static[ \\t]+)?func[ \\t]+"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	if not FileAccess.file_exists(TARGET_FILE):
		print("[%s] PASS (target absent): %s not yet created" % [LINT_TAG, TARGET_FILE])
		quit(0)
		return

	var re_emit := _compile(EMIT_PATTERN)
	var re_cap := _compile(CAP_PATTERN)
	var re_func := _compile(FUNC_OPENER_PATTERN)
	if re_emit == null or re_cap == null or re_func == null:
		quit(2)
		return

	var lines := _read_lines(TARGET_FILE)

	# Map each line index → the start line index of its enclosing function.
	var enclosing_func: Array[int] = []
	enclosing_func.resize(lines.size())
	var current_func := -1
	for i: int in lines.size():
		if re_func.search(lines[i]) != null:
			current_func = i
		enclosing_func[i] = current_func

	var violations: Array[Dictionary] = []
	for i: int in lines.size():
		var line: String = lines[i]
		if line.strip_edges(true, false).begins_with("#"):
			continue
		if re_emit.search(line) == null:
			continue
		var func_start: int = enclosing_func[i]
		if func_start < 0:
			func_start = 0  # emit at module scope (unexpected) — scan from top
		# Look backward within [func_start, i) for a cap check.
		var capped := false
		for j: int in range(func_start, i):
			var prior: String = lines[j]
			if prior.strip_edges(true, false).begins_with("#"):
				continue
			if re_cap.search(prior) != null:
				capped = true
				break
		if not capped:
			violations.append({"line": i + 1, "snippet": line.strip_edges()})

	if violations.is_empty():
		print("[%s] PASS: every loot_dropped emit is preceded by a _ceremony_cap_check in its function" % LINT_TAG)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: emit_signal(\"loot_dropped\") with no preceding _ceremony_cap_check in this function — every reveal must consult the cap (Pillar 2/3)" % [TARGET_FILE, v["line"]])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d un-capped loot_dropped emit(s)." % [LINT_TAG, violations.size()])
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
