#!/usr/bin/env -S godot --headless --script
## CI Lint — BossAnchorState transition legality (Story 004 story-level AC; Rule 13, Formula 5).
##
## Purpose:
##   The boss-anchor sub-FSM walks IDLE→PRE_SPAWN→COMMIT_PENDING→COMMITTED→ENGAGED
##   with IDLE rollback paths (workout_abandoned, pre-spawn/commit cancel). Every
##   forward transition must go through the FSM transition helper that validates the
##   prior state; only the IDLE reset is a legal *direct* assignment (it is the safe
##   Family-A ordinal-0 default and the universal rollback target).
##
##   Approach A (lint heuristic): a direct assignment
##       _boss_anchor_state = BossAnchorState.IDLE
##   is ALWAYS legal (declaration init + every rollback path lands on IDLE). A direct
##   assignment to ANY OTHER BossAnchorState value is an illegal jump that bypasses the
##   FSM transition helper's prior-state validation, and is FORBIDDEN. Forward moves
##   must call the transition helper (which sets the field internally), not assign it.
##
## Scan target:
##   res://src/autoload/enemy_director.gd  (this single file ONLY).
##
## Detection:
##   Match `_boss_anchor_state\s*=\s*BossAnchorState\.<NAME>`. If <NAME> != "IDLE",
##   report a violation. (The transition helper is exempt: it mutates the field via a
##   parameterised local, not a literal `BossAnchorState.<value>` assignment, so it
##   never matches this pattern. Comparisons `==`/`!=` are not assignments and are
##   excluded by requiring a single `=` not preceded by `=`/`!`/`<`/`>`.)
##
## Usage:
##   godot --headless --script tools/ci/check_boss_anchor_state_transitions.gd
##
## Exit codes:
##   0 = no illegal direct transitions (only IDLE assignments present) (clean)
##   1 = one or more illegal direct transitions found (CI MUST fail)
##   2 = internal error (target missing / regex compile failure / unreadable)
##
## Governing docs: design/gdd/enemy-director.md Rule 13 / Formula 5; ADR-0006
##   (transition atomicity); ADR-0007 (BossAnchorState Family A); Story 004.
extends SceneTree


const TARGET_FILE: String = "res://src/autoload/enemy_director.gd"
const LINT_TAG: String = "check_boss_anchor_state_transitions"

## The only state a direct `_boss_anchor_state =` literal assignment may target.
const LEGAL_DIRECT_TARGET: String = "IDLE"

## Captures `_boss_anchor_state = BossAnchorState.<NAME>` as a true assignment.
## The `(?<![=!<>])` look-behind rejects comparison operators (==, !=, <=, >=).
const ASSIGN_PATTERN: String = "_boss_anchor_state\\s*(?<![=!<>])=\\s*BossAnchorState\\.([A-Z_]+)"


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_error("[%s] target not found: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(ASSIGN_PATTERN) != OK:
		push_error("[%s] regex compile failed: %s" % [LINT_TAG, ASSIGN_PATTERN])
		quit(2)
		return

	var lines: PackedStringArray = _read_lines(abs_path)
	if lines.is_empty():
		push_error("[%s] unreadable or empty: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var violations: Array[Dictionary] = []
	for i: int in lines.size():
		var line: String = lines[i]
		if line.strip_edges(true, false).begins_with("#"):
			continue
		var m := re.search(line)
		if m == null:
			continue
		var target_state: String = m.get_string(1)
		if target_state == LEGAL_DIRECT_TARGET:
			continue  # IDLE reset / init — always legal.
		violations.append({
			"line": i + 1,
			"col": m.get_start() + 1,
			"state": target_state,
			"snippet": line.strip_edges(),
		})

	if violations.is_empty():
		print("[%s] PASS: %s — 0 illegal direct BossAnchorState transitions (only IDLE assignments)" % [
			LINT_TAG, TARGET_FILE,
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: illegal direct boss-anchor transition to BossAnchorState.%s — forward moves MUST go through the FSM transition helper (only IDLE may be assigned directly)" % [
			TARGET_FILE, v["line"], v["col"], v["state"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d illegal direct transition(s)." % [LINT_TAG, violations.size()])
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
