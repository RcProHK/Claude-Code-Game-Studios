#!/usr/bin/env -S godot --headless --script
## CI Lint — AvatarRenderer read-only public API (CR-11 / CI-3 / AC-25).
##
## The avatar_renderer.gd public surface exposes ONLY read getters + the #29 snapshot
## seam. No `set_*` / `mutate_*` / `force_*` / `inject_*` public method may exist —
## visible state derives from canonical data, never injected. (Private `_`-prefixed
## members and the untyped DI seams `_stat`/`_ability`/... are out of scope.)
##
## Exit codes: 0 = clean, 1 = violation, 2 = internal error.
extends SceneTree

const LINT_TAG := "check_avatar_renderer_no_setter_api"
const TARGET := "res://src/autoload/avatar_renderer.gd"
const FORBIDDEN := ["set_", "mutate_", "force_", "inject_"]


func _init() -> void:
	if not FileAccess.file_exists(TARGET):
		push_error("[%s] target missing: %s" % [LINT_TAG, TARGET])
		quit(2)
		return
	var re := RegEx.new()
	# public func name = func <name> not starting with underscore.
	re.compile("^func\\s+([a-zA-Z][a-zA-Z0-9_]*)\\s*\\(")
	var file := FileAccess.open(TARGET, FileAccess.READ)
	var i := 0
	var violations: Array[String] = []
	while not file.eof_reached():
		var line := file.get_line()
		i += 1
		var m := re.search(line)
		if m == null:
			continue
		var fn := m.get_string(1)
		for p: String in FORBIDDEN:
			if fn.begins_with(p):
				violations.append("%s:%d: forbidden public mutation method '%s' (CR-11/AC-25)" % [TARGET, i, fn])
	file.close()
	if violations.is_empty():
		print("[%s] PASS: 0 mutation-prefixed public methods on avatar_renderer.gd" % LINT_TAG)
		quit(0)
		return
	for v: String in violations:
		printerr(v)
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)
