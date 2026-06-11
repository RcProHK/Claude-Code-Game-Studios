#!/usr/bin/env -S godot --headless --script
## CI Lint — CombatVisualFeedback (#25) R-13 double-shake guard (AC-11).
##
## Purpose (GDD R-13 / TR-cvf-005):
##   #25 must NEVER direct-call screen shake. Shake for the HIT_HEAVY/DEATH presets is
##   provided by #6 ScreenEffects auto-dispatch (it self-subscribes #5 `burst_started`).
##   #25 only ever direct-calls `hit_pause` to fill the #6 auto-dispatch pause=0 gap.
##   A direct `.shake(` call in #25 = a double shake (the auto-dispatched one PLUS the
##   manual one) = the exact bug this guard exists to prevent.
##
## Scan target: res://src/autoload/combat_visual_feedback.gd (this single file ONLY —
##   not a gateway lint, so the #25 owner needs no exemption).
##
## Forbidden pattern (any direct shake call — seam or autoload form):
##   \.shake\s*\(    matches `_screen_fx.shake(` / `ScreenEffects.shake(` / `.shake (`
##   (a bare ` shake(` with no leading dot — e.g. inside a comment describing #6's
##   auto-dispatch — does NOT match, so doc comments stay legal.)
##
## Exit codes: 0 = clean (only hit_pause); 1 = a direct shake found (CI MUST fail);
##   2 = internal error (target missing / regex compile / unreadable).
extends SceneTree


const TARGET_FILE: String = "res://src/autoload/combat_visual_feedback.gd"
const LINT_TAG: String = "check_cvf_no_direct_shake"
const FORBIDDEN_PATTERN: String = "\\.shake\\s*\\("


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_error("[%s] target not found: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[%s] regex compile failed: %s" % [LINT_TAG, FORBIDDEN_PATTERN])
		quit(2)
		return

	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		push_error("[%s] unreadable: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var violations: Array[Dictionary] = []
	var line_no: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_no += 1
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		var m := re.search(line)
		if m != null:
			violations.append({"line": line_no, "col": m.get_start() + 1, "snippet": stripped})
	file.close()

	if violations.is_empty():
		print("[%s] PASS: %s — 0 direct shake calls (R-13; shake via #6 auto-dispatch only)" % [
			LINT_TAG, TARGET_FILE,
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: direct `.shake(` FORBIDDEN — #25 only calls hit_pause; shake is #6 auto-dispatch (R-13)" % [
			TARGET_FILE, v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d direct shake call(s). Remove — #6 auto-dispatch owns shake." % [LINT_TAG, violations.size()])
	quit(1)
