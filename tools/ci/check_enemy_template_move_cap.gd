#!/usr/bin/env -S godot --headless --script
## CI Lint — EnemyRegistry template move-speed cap (Story 004 AC-31; TR-enemy-004).
##
## Purpose:
##   Every enemy template's `_template_move_speed` MUST be ≤ ENEMY_MOVE_CAP (420).
##   The cap keeps locomotion inside the readable-wave envelope (STRIKE=120,
##   CONTROL=90, MOBILITY=280 all pass). A template above the cap would let an enemy
##   outrun the player camera framing and break Pillar 2 wave readability.
##
## Scan target:
##   res://assets/data/EnemyRegistry.tres  (parsed as TEXT, not loaded as a Resource —
##   the lint must run headless without importing scene/script dependencies).
##
## Forward-compat (AC-31): EnemyRegistry.tres is created by Story 010. Until it ships,
##   the target file does NOT exist and this lint exits 2 (graceful skip, NOT a CI
##   fail). Once Story 010 lands, the lint enforces the cap on every template value.
##
## Detection:
##   Extract every `_template_move_speed = <number>` assignment (any number form:
##   int or float). Assert each value ≤ ENEMY_MOVE_CAP. Any value above => violation.
##
## Usage:
##   godot --headless --script tools/ci/check_enemy_template_move_cap.gd
##
## Exit codes:
##   0 = all template move speeds ≤ cap (clean)
##   1 = one or more templates exceed the cap (CI MUST fail)
##   2 = target file not found (Story 010 not yet shipped — graceful skip), or
##       internal error (regex compile failure / unreadable)
##
## Governing docs: design/gdd/enemy-director.md (move cap); TR-enemy-004;
##   Story 004 AC-31; Story 010 (EnemyRegistry.tres).
extends SceneTree


const TARGET_FILE: String = "res://assets/data/EnemyRegistry.tres"
const LINT_TAG: String = "check_enemy_template_move_cap"

## Maximum permitted per-template move speed (px/s). GDD locked value.
const ENEMY_MOVE_CAP: float = 420.0

## Matches `_template_move_speed = <number>` (int or float, optional sign).
const MOVE_SPEED_PATTERN: String = "_template_move_speed\\s*=\\s*(-?[0-9]+(?:\\.[0-9]+)?)"


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		# Forward-compat: Story 010 has not created EnemyRegistry.tres yet — graceful skip.
		push_warning("[%s] target not found: %s — forward-compat skip (Story 010 not yet shipped)" % [
			LINT_TAG, TARGET_FILE,
		])
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(MOVE_SPEED_PATTERN) != OK:
		push_error("[%s] regex compile failed: %s" % [LINT_TAG, MOVE_SPEED_PATTERN])
		quit(2)
		return

	var lines: PackedStringArray = _read_lines(abs_path)
	if lines.is_empty():
		push_error("[%s] unreadable or empty: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var violations: Array[Dictionary] = []
	var checked: int = 0
	for i: int in lines.size():
		var line: String = lines[i]
		if line.strip_edges(true, false).begins_with("#") or line.strip_edges(true, false).begins_with(";"):
			continue
		var m := re.search(line)
		if m == null:
			continue
		checked += 1
		var value: float = m.get_string(1).to_float()
		if value > ENEMY_MOVE_CAP:
			violations.append({
				"line": i + 1,
				"col": m.get_start() + 1,
				"value": value,
				"snippet": line.strip_edges(),
			})

	if violations.is_empty():
		print("[%s] PASS: %s — %d template move-speed value(s), all ≤ cap %d" % [
			LINT_TAG, TARGET_FILE, checked, int(ENEMY_MOVE_CAP),
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: _template_move_speed=%s exceeds ENEMY_MOVE_CAP=%d (TR-enemy-004)" % [
			TARGET_FILE, v["line"], v["col"], str(v["value"]), int(ENEMY_MOVE_CAP),
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d template(s) exceed the move cap." % [LINT_TAG, violations.size()])
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
