#!/usr/bin/env -S godot --headless --script
## CI Lint — AvatarRenderer single fabrication boundary (CR-6 / CI-1 / AC-23).
##
## Invariant: `_visual_state.<field>` is the presentation snapshot, and the ONLY method
## permitted to WRITE its fields is `_derive_state_from_canonical()`. Event-driven state
## (animation, micro-evolution deltas) lives in backing vars (`_current_anim`, `_micro_*`)
## and is synced INTO `_visual_state` at the derive tail — never written from a handler.
## A stray `_visual_state.<field> =` outside the derive is exactly the clobber/desync class
## that the derive-tail sync would silently fight (the combat-exit re-derive bug).
##
## Scan: res://src/autoload/avatar_renderer.gd. Tracks top-level `func` scope; any
## `_visual_state.<field> =` assignment (not `==`) outside `_derive_state_from_canonical`
## is a violation. Comment lines are skipped.
##
## Exit codes: 0 = clean, 1 = violation (CI MUST fail), 2 = internal error.
## Governing: ADR-0010 render-only, avatar-renderer.md CR-6 / AC-23, Story 017.
extends SceneTree

const LINT_TAG := "check_avatar_visual_state_derivation"
const RENDERER := "res://src/autoload/avatar_renderer.gd"
## The ONLY function permitted to write _visual_state fields.
const WRITER_FUNC := "_derive_state_from_canonical"


func _init() -> void:
	if not FileAccess.file_exists(RENDERER):
		printerr("[%s] internal: source not found at %s" % [LINT_TAG, RENDERER])
		quit(2)
		return

	# `_visual_state.<field> =` assignment, excluding `==` (comparison) via negative lookahead.
	var write_re := RegEx.new()
	if write_re.compile("_visual_state\\.\\w+\\s*=(?!=)") != OK:
		printerr("[%s] internal: regex compile failed" % LINT_TAG)
		quit(2)
		return
	# Top-level function declarations (column 0).
	var func_re := RegEx.new()
	func_re.compile("^func\\s+(\\w+)")

	var violations: Array[String] = []
	var current_func := "<file-scope>"
	var file := FileAccess.open(RENDERER, FileAccess.READ)
	var i := 0
	while not file.eof_reached():
		var raw := file.get_line()
		i += 1
		var fm := func_re.search(raw)
		if fm != null:
			current_func = fm.get_string(1)
			continue
		if raw.strip_edges(true, false).begins_with("#"):
			continue
		if write_re.search(raw) != null and current_func != WRITER_FUNC:
			violations.append("%s:%d: _visual_state field write outside %s() (CI-1/AC-23 single-writer) [in %s()]" % [
				RENDERER, i, WRITER_FUNC, current_func])
	file.close()

	if violations.is_empty():
		print("[%s] PASS: all _visual_state field writes confined to %s() (CR-6 / AC-23)" % [
			LINT_TAG, WRITER_FUNC])
		quit(0)
		return
	for v: String in violations:
		printerr(v)
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)
