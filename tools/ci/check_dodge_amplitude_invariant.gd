#!/usr/bin/env -S godot --headless --script
## CI Lint — dodge amplitude invariant INV-8 (Story 004 AC-32; TR-enemy-011).
##
## Purpose:
##   The MOBILITY dodge sidestep must NOT push an enemy out of melee threat range.
##   INV-8 (post-fix): a full dodge swing is 2× the amplitude, and that swing MUST
##   stay strictly inside MELEE_RANGE:
##       DODGE_AMPLITUDE_PX * 2  <  MELEE_RANGE
##   With the GDD-locked values: 30 * 2 = 60  <  80  ✓ (clean).
##   A larger amplitude (e.g. 50 → 100 > 80) lets the dodge escape melee and breaks
##   the perception/locomotion contract.
##
## Scan target:
##   res://src/autoload/enemy_director.gd  (this single file ONLY).
##
## Forward-compat (AC-32): `DODGE_AMPLITUDE_PX` is declared by Story 015. Until it
##   ships, the const is absent and this lint exits 2 (graceful skip, NOT a CI fail).
##
## Detection:
##   - Extract `const DODGE_AMPLITUDE_PX = <number>`  (required; absent => exit 2).
##   - MELEE_RANGE: read `const MELEE_RANGE = <number>` if present in the file;
##     otherwise fall back to the GDD-locked default (80). This keeps the lint usable
##     before Story 015 wires the real MELEE_RANGE const.
##   - Assert DODGE_AMPLITUDE_PX * 2 < MELEE_RANGE.
##
## Usage:
##   godot --headless --script tools/ci/check_dodge_amplitude_invariant.gd
##
## Exit codes:
##   0 = invariant holds (amplitude*2 < melee range) (clean)
##   1 = invariant violated (CI MUST fail)
##   2 = DODGE_AMPLITUDE_PX const not declared (Story 015 not yet shipped — graceful
##       skip), or internal error (target missing / regex compile failure / unreadable)
##
## Governing docs: design/gdd/enemy-director.md INV-8; TR-enemy-011;
##   Story 004 AC-32; Story 015 (dodge amplitude / particle throttle).
extends SceneTree


const TARGET_FILE: String = "res://src/autoload/enemy_director.gd"
const LINT_TAG: String = "check_dodge_amplitude_invariant"

## GDD-locked default melee range used when the file does not (yet) declare MELEE_RANGE.
const MELEE_RANGE_DEFAULT: float = 80.0

## Captures `const DODGE_AMPLITUDE_PX = <number>` (int or float).
const DODGE_PATTERN: String = "^\\s*const\\s+DODGE_AMPLITUDE_PX\\s*(?::\\s*\\w+\\s*)?=\\s*(-?[0-9]+(?:\\.[0-9]+)?)"
## Captures `const MELEE_RANGE = <number>` (int or float) if present.
const MELEE_PATTERN: String = "^\\s*const\\s+MELEE_RANGE\\s*(?::\\s*\\w+\\s*)?=\\s*(-?[0-9]+(?:\\.[0-9]+)?)"


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_error("[%s] target not found: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var re_dodge := RegEx.new()
	if re_dodge.compile(DODGE_PATTERN) != OK:
		push_error("[%s] dodge regex compile failed: %s" % [LINT_TAG, DODGE_PATTERN])
		quit(2)
		return
	var re_melee := RegEx.new()
	if re_melee.compile(MELEE_PATTERN) != OK:
		push_error("[%s] melee regex compile failed: %s" % [LINT_TAG, MELEE_PATTERN])
		quit(2)
		return

	var lines: PackedStringArray = _read_lines(abs_path)
	if lines.is_empty():
		push_error("[%s] unreadable or empty: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var dodge_value: float = NAN
	var dodge_line: int = -1
	var dodge_snippet: String = ""
	var melee_value: float = MELEE_RANGE_DEFAULT
	var melee_found: bool = false

	for i: int in lines.size():
		var line: String = lines[i]
		if line.strip_edges(true, false).begins_with("#"):
			continue
		if is_nan(dodge_value):
			var md := re_dodge.search(line)
			if md != null:
				dodge_value = md.get_string(1).to_float()
				dodge_line = i + 1
				dodge_snippet = line.strip_edges()
		if not melee_found:
			var mm := re_melee.search(line)
			if mm != null:
				melee_value = mm.get_string(1).to_float()
				melee_found = true

	if is_nan(dodge_value):
		# Forward-compat: Story 015 has not declared DODGE_AMPLITUDE_PX yet — graceful skip.
		push_warning("[%s] const DODGE_AMPLITUDE_PX not declared in %s — forward-compat skip (Story 015 not yet shipped)" % [
			LINT_TAG, TARGET_FILE,
		])
		quit(2)
		return

	var full_swing: float = dodge_value * 2.0
	if full_swing < melee_value:
		print("[%s] PASS: %s — DODGE_AMPLITUDE_PX=%s ×2=%s < MELEE_RANGE=%s (INV-8 holds%s)" % [
			LINT_TAG, TARGET_FILE, str(dodge_value), str(full_swing), str(melee_value),
			"" if melee_found else " — default",
		])
		quit(0)
		return

	printerr("%s:%d: INV-8 VIOLATION — DODGE_AMPLITUDE_PX=%s ×2=%s is NOT < MELEE_RANGE=%s%s" % [
		TARGET_FILE, dodge_line, str(dodge_value), str(full_swing), str(melee_value),
		"" if melee_found else " (default)",
	])
	printerr("  > %s" % dodge_snippet)
	printerr("")
	printerr("[%s] FAIL: dodge full-swing escapes melee range (TR-enemy-011)." % LINT_TAG)
	quit(1)


func _read_lines(abs_path: String) -> PackedStringArray:
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines
