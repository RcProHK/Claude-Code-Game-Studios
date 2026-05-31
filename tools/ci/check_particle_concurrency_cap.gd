#!/usr/bin/env -S godot --headless --script
## CI Lint — particle concurrency cap immutability (Story 004 story-level AC; Story 015).
##
## Purpose:
##   The concurrent particle-emitter ceiling `MAX_CONCURRENT_PARTICLE_EMITTERS` governs
##   the ADR-0001 web-export GPU budget (auto-degrade when exceeded). It MUST be a
##   compile-time `const`, never a mutable `var`: a runtime-mutable cap could be raised
##   mid-session and silently blow the budget guarantee. This lint forbids the `var`
##   form and requires the `const` form.
##
## Scan target:
##   res://src/autoload/enemy_director.gd  (this single file ONLY).
##
## Forward-compat: `MAX_CONCURRENT_PARTICLE_EMITTERS` is declared by Story 015. Until
##   it ships, the symbol is absent and this lint exits 2 (graceful skip, NOT a fail).
##
## Detection:
##   - `var\s+MAX_CONCURRENT_PARTICLE_EMITTERS`   => violation (mutable cap) => exit 1
##   - `const\s+MAX_CONCURRENT_PARTICLE_EMITTERS` => clean => exit 0
##   - neither form present                       => exit 2 (Story 015 not yet shipped)
##
## Usage:
##   godot --headless --script tools/ci/check_particle_concurrency_cap.gd
##
## Exit codes:
##   0 = declared as const (clean)
##   1 = declared as var (CI MUST fail)
##   2 = symbol not declared (Story 015 not yet shipped — graceful skip), or
##       internal error (target missing / regex compile failure / unreadable)
##
## Governing docs: ADR-0001 (particle budget governance); design/gdd/enemy-director.md
##   (concurrency auto-degrade); Story 004; Story 015 (particle throttle).
extends SceneTree


const TARGET_FILE: String = "res://src/autoload/enemy_director.gd"
const LINT_TAG: String = "check_particle_concurrency_cap"
const SYMBOL: String = "MAX_CONCURRENT_PARTICLE_EMITTERS"

const CONST_PATTERN: String = "^\\s*const\\s+MAX_CONCURRENT_PARTICLE_EMITTERS\\b"
const VAR_PATTERN: String = "^\\s*var\\s+MAX_CONCURRENT_PARTICLE_EMITTERS\\b"


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_error("[%s] target not found: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var re_const := RegEx.new()
	if re_const.compile(CONST_PATTERN) != OK:
		push_error("[%s] const regex compile failed: %s" % [LINT_TAG, CONST_PATTERN])
		quit(2)
		return
	var re_var := RegEx.new()
	if re_var.compile(VAR_PATTERN) != OK:
		push_error("[%s] var regex compile failed: %s" % [LINT_TAG, VAR_PATTERN])
		quit(2)
		return

	var lines: PackedStringArray = _read_lines(abs_path)
	if lines.is_empty():
		push_error("[%s] unreadable or empty: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var const_line: int = -1
	var var_line: int = -1
	var var_snippet: String = ""
	for i: int in lines.size():
		var line: String = lines[i]
		if line.strip_edges(true, false).begins_with("#"):
			continue
		if const_line == -1 and re_const.search(line) != null:
			const_line = i + 1
		if var_line == -1 and re_var.search(line) != null:
			var_line = i + 1
			var_snippet = line.strip_edges()

	# A `var` declaration is the violation regardless of whether a const also exists.
	if var_line != -1:
		printerr("%s:%d: %s declared as `var` — the concurrency cap MUST be an immutable `const`" % [
			TARGET_FILE, var_line, SYMBOL,
		])
		printerr("  > %s" % var_snippet)
		printerr("")
		printerr("[%s] FAIL: mutable particle concurrency cap (ADR-0001 budget governance)." % LINT_TAG)
		quit(1)
		return

	if const_line != -1:
		print("[%s] PASS: %s — %s declared as const at line %d" % [
			LINT_TAG, TARGET_FILE, SYMBOL, const_line,
		])
		quit(0)
		return

	# Forward-compat: Story 015 has not declared the symbol yet — graceful skip.
	push_warning("[%s] %s not declared in %s — forward-compat skip (Story 015 not yet shipped)" % [
		LINT_TAG, SYMBOL, TARGET_FILE,
	])
	quit(2)


func _read_lines(abs_path: String) -> PackedStringArray:
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines
