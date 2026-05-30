#!/usr/bin/env -S godot --headless --script
## CI Lint — CombatResolver purity enforcement (GDD Rule 1, ADR-0006 Contract 12)
##
## AC-01-lint / Story 001: CombatResolver MUST be a stateless pure-function class
## (`class_name CombatResolver extends RefCounted`, `static func`/`const`/inner
## `class` only). The CLASS BODY (top level, after `class_name CombatResolver`)
## must NOT contain any of:
##   * instance `var` (class-scope mutable state)
##   * `@onready` / `@export`
##   * class-scope `signal`
##   * `func _ready` / `func _process` / `func _physics_process`
##
## ALLOWED at class scope: `const`, `static func`, inner `class ... :`.
## ALLOWED inside an inner `class` block: `var` (POD struct data members).
## ALLOWED inside a `static func` body: `var` (local variables).
##
## ── DETECTION STRATEGY (line-by-line indentation + block tracking) ────────────
## The hard part is distinguishing a BAD class-scope `var` from a GOOD inner-class
## `var` or a GOOD static-func-local `var`. Pure regex cannot do this, so we walk
## the file line by line tracking nesting via indentation:
##
##   1. We only consider lines AFTER the `class_name CombatResolver` declaration.
##   2. We track whether we are currently INSIDE an inner-class block or a func
##      body. An inner `class Foo extends X:` (or a `func ...:`) at indent depth D
##      OPENS a block; any subsequent non-blank line whose indent > D is INSIDE
##      that block. The block CLOSES when a line returns to indent <= D.
##   3. A `var` / `@onready` / `signal` declaration is a CLASS-SCOPE VIOLATION
##      only when it is NOT inside any inner-class or func block (i.e. at the
##      class top level — indent depth 0 in tab units, or the resolver's base
##      indent).
##   4. `@onready`, `@export`, `func _ready`, `func _process`, `func _physics_process`
##      are UNCONDITIONAL violations anywhere in the file — they have no legitimate
##      use in a pure static class (this is the unambiguous, robust layer).
##
## Indentation is measured in LEADING TAB COUNT (the codebase uses tabs). The
## class body sits at tab depth 0; inner-class / func members sit at depth 1;
## their bodies at depth >= 1 relative to the opener.
##
## Usage:
##   godot --headless --script tools/ci/check_combat_resolver_purity.gd
##
## Exit codes:
##   0 = pure (clean)
##   1 = one or more purity violations found (CI MUST fail)
##   2 = internal error (target file / src/ missing, regex compile failure)
##
## Governing docs: design/gdd/combat-resolver.md Rule 1; ADR-0006 Contract 12;
##   story-001-ci-lints-purity-defense.md AC-01-lint.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const TARGET_FILE: String = "res://src/core/combat_resolver.gd"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_combat_resolver_purity] src/ not found at %s — cannot scan" % SCAN_ROOT)
		quit(2)
		return

	if not FileAccess.file_exists(TARGET_FILE):
		push_error("[check_combat_resolver_purity] target not found: %s" % TARGET_FILE)
		quit(2)
		return

	var file := FileAccess.open(TARGET_FILE, FileAccess.READ)
	if file == null:
		push_error("[check_combat_resolver_purity] cannot read: %s" % TARGET_FILE)
		quit(2)
		return
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	# Unconditional-violation regexes (illegal anywhere in this file).
	var re_onready := _compile("^[ \\t]*@onready\\b")
	var re_export := _compile("^[ \\t]*@export\\b")
	var re_lifecycle := _compile("^[ \\t]*func[ \\t]+_(ready|process|physics_process)\\b")
	# Class-scope-only-violation regexes (legal inside inner class / func body).
	var re_var := _compile("^[ \\t]*var[ \\t]")
	var re_signal := _compile("^[ \\t]*signal[ \\t]")
	if re_onready == null or re_export == null or re_lifecycle == null or re_var == null or re_signal == null:
		quit(2)
		return

	var violations: Array[Dictionary] = []

	# Block-tracking state. `block_indent` is the indent depth (tab count) of the
	# CURRENTLY-OPEN inner-class/func opener line; -1 means "at class scope".
	var seen_class_name: bool = false
	var open_block_indent: int = -1

	for i: int in lines.size():
		var raw_line: String = lines[i]
		var stripped: String = raw_line.strip_edges()

		# Skip blanks and full-line comments — they never open/close blocks nor violate.
		if stripped.is_empty() or stripped.begins_with("#"):
			continue

		# Only start scanning once we've passed `class_name CombatResolver`.
		if not seen_class_name:
			if stripped.begins_with("class_name CombatResolver"):
				seen_class_name = true
			continue

		var indent: int = _leading_tabs(raw_line)

		# Close the current block when we dedent back to (or past) its opener indent.
		if open_block_indent >= 0 and indent <= open_block_indent:
			open_block_indent = -1

		var in_block: bool = open_block_indent >= 0

		# ── Unconditional violations (anywhere) ──────────────────────────────
		if re_onready.search(raw_line) != null:
			violations.append(_v(i, stripped, "@onready forbidden — CombatResolver is a pure static class"))
		elif re_export.search(raw_line) != null:
			violations.append(_v(i, stripped, "@export forbidden — CombatResolver holds no instance state"))
		elif re_lifecycle.search(raw_line) != null:
			violations.append(_v(i, stripped, "node lifecycle method forbidden — CombatResolver is not a Node"))

		# ── Class-scope-only violations (legal inside inner class / func body) ─
		elif not in_block and re_var.search(raw_line) != null:
			violations.append(_v(i, stripped, "class-scope `var` forbidden — no instance state (inner-class/func-local var is OK)"))
		elif not in_block and re_signal.search(raw_line) != null:
			violations.append(_v(i, stripped, "class-scope `signal` forbidden — CombatResolver emits no signals"))

		# ── Block opener detection (AFTER violation check on this line) ───────
		# A top-level `class ...:` or `static func ...:`/`func ...:` opens a block
		# whose body (indent > this line's indent) is exempt from class-scope rules.
		if not in_block and indent == 0 and _opens_block(stripped):
			open_block_indent = indent

	if violations.is_empty():
		print("[check_combat_resolver_purity] PASS: %s is pure (static func / const / inner class only)" % TARGET_FILE)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: %s" % [TARGET_FILE, v["line"], v["reason"]])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_combat_resolver_purity] FAIL: %d purity violation(s). CombatResolver must be static func / const / inner class only (GDD Rule 1, ADR-0006 C12)." % violations.size())
	quit(1)


## True when a top-level line opens an inner-class or func block (ends in `:`).
func _opens_block(stripped: String) -> bool:
	if stripped.begins_with("class ") and stripped.ends_with(":"):
		return true
	if stripped.begins_with("static func ") and stripped.ends_with(":"):
		return true
	if stripped.begins_with("func ") and stripped.ends_with(":"):
		return true
	return false


## Count leading TAB characters (the codebase indents with tabs).
func _leading_tabs(line: String) -> int:
	var count: int = 0
	for ch: String in line:
		if ch == "\t":
			count += 1
		else:
			break
	return count


func _compile(pattern: String) -> RegEx:
	var re := RegEx.new()
	if re.compile(pattern) != OK:
		push_error("[check_combat_resolver_purity] regex compile failed: %s" % pattern)
		return null
	return re


func _v(line_index: int, snippet: String, reason: String) -> Dictionary:
	return {"line": line_index + 1, "snippet": snippet, "reason": reason}
