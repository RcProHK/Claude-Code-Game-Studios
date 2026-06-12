#!/usr/bin/env -S godot --headless --script
## CI Lint — EnemyDirector autoload boot order (AC-04, ADR-0008 canonical map).
##
## Purpose:
##   `project.godot` is the SOLE ground-truth for absolute autoload positions
##   (F-SETUP-4 / ADR-0008). This lint parses the `[autoload]` section, extracts
##   the listing order of autoload registration keys, and verifies EnemyDirector's
##   boot position against ADR-0008's partial-order constraints.
##
## Two enforcement tiers (per Story 003 Implementation Notes):
##   HARD (exit 1) — `LootDropSystem ≺ EnemyDirector`. This is the ONLY ordering
##     pair that fails CI. Binding source: ADR-0008 Constraint 3 / #13 EC-43 /
##     GDD Rule 9. LootDrop MUST be fully booted before EnemyDirector wires its
##     enemy_killed → loot chain (transition_id seed propagation, ADR-0005).
##   SOFT (warn-only, exit 0) — EnemyDirector's other gameplay-state predecessors
##     (PersistenceLayer, GameStateMachine, PlatformDetect, GymSysBackendClient,
##     StatSystem, AbilitySystem, StreakSystem, WorkoutStateTracker). Most use the
##     `connect_for_initial_state` helper (ADR-0008 Constraint 6 — order-resilient),
##     so strict ordering is advisory. Flagging them as exit-1 would cause
##     false-positive regressions on legitimate autoload-map reorders.
##
## NOTE (ADR-0008 reclassification): presentation-layer autoloads
##   (AvatarRenderer, ParticleSystemWrapper, CameraController, ScreenEffects)
##   correctly boot AFTER EnemyDirector (positions 11-14). The GDD Rule 9 prose
##   "after #5/#6/#7" is superseded — they are presentation layer, not predecessors.
##   There is NO CombatResolver autoload (#13 is a pure static func). The #28
##   Telemetry autoload DOES exist (key `Telemetry`, registered Last per ADR-0008
##   G-TEL-1, 2026-06-12) but it boots AFTER EnemyDirector and is a pure passive
##   observer — it is NOT a predecessor and is intentionally absent from the
##   HARD/SOFT lists below (do not require it here).
##
## Scan target:
##   res://project.godot  — `[autoload]` section only.
##
## Usage:
##   godot --headless --script tools/ci/check_autoload_boot_order.gd
##
## Exit codes:
##   0 = LootDropSystem ≺ EnemyDirector satisfied (clean; soft warnings allowed)
##   1 = HARD constraint violated (EnemyDirector before LootDropSystem, OR a
##       required autoload entirely absent)
##   2 = internal error (project.godot missing / unreadable / no [autoload] section)
##
## Governing docs: design/gdd/enemy-director.md Rule 9; ADR-0008 Constraint 3;
##   ADR-0006 Contract 4 + Contract 6; #13 EC-43; story-003-ci-lint-suite-b.md AC-04.
extends SceneTree


const PROJECT_FILE: String = "res://project.godot"
const LINT_TAG: String = "check_autoload_boot_order"

## The one autoload whose order is a HARD CI gate against EnemyDirector.
const HARD_PREDECESSOR: String = "LootDropSystem"
const SUBJECT: String = "EnemyDirector"

## Advisory-soft predecessors (warn-only). Order-resilient via connect_for_initial_state.
const SOFT_PREDECESSORS: Array[String] = [
	"PersistenceLayer",
	"GameStateMachine",
	"PlatformDetect",
	"GymSysBackendClient",
	"StatSystem",
	"AbilitySystem",
	"StreakSystem",
	"WorkoutStateTracker",
]


func _init() -> void:
	if not FileAccess.file_exists(PROJECT_FILE):
		push_error("[%s] project.godot not found at %s" % [LINT_TAG, PROJECT_FILE])
		quit(2)
		return

	var lines: PackedStringArray = _read_lines(PROJECT_FILE)
	if lines.is_empty():
		push_error("[%s] project.godot unreadable or empty" % LINT_TAG)
		quit(2)
		return

	# order[name] = first 1-based listing index inside [autoload]. -1 = absent.
	var order: Dictionary = _parse_autoload_order(lines)
	if order.is_empty():
		push_error("[%s] no [autoload] section found in project.godot" % LINT_TAG)
		quit(2)
		return

	var hard_errors: Array[String] = []
	var soft_warnings: Array[String] = []

	# --- HARD gate: LootDropSystem ≺ EnemyDirector ---
	var subject_pos: int = order.get(SUBJECT, -1)
	var hard_pred_pos: int = order.get(HARD_PREDECESSOR, -1)

	if subject_pos == -1:
		hard_errors.append("%s is not registered in [autoload] — cannot verify boot order" % SUBJECT)
	if hard_pred_pos == -1:
		hard_errors.append("%s (hard predecessor of %s) is not registered in [autoload]" % [HARD_PREDECESSOR, SUBJECT])
	if subject_pos != -1 and hard_pred_pos != -1 and hard_pred_pos > subject_pos:
		hard_errors.append(
			"%s (pos %d) MUST boot before %s (pos %d) — ADR-0008 Constraint 3 / #13 EC-43 / GDD Rule 9 hard binding" % [
				HARD_PREDECESSOR, hard_pred_pos, SUBJECT, subject_pos,
			])

	# --- SOFT gate: advisory predecessors (warn-only, never exit 1) ---
	if subject_pos != -1:
		for name: String in SOFT_PREDECESSORS:
			var pos: int = order.get(name, -1)
			if pos == -1:
				soft_warnings.append("%s (advisory predecessor) not found in [autoload] — order not verified" % name)
			elif pos > subject_pos:
				soft_warnings.append(
					"%s (pos %d) boots AFTER %s (pos %d) — advisory only (order-resilient via connect_for_initial_state)" % [
						name, pos, SUBJECT, subject_pos,
					])

	# Print soft warnings regardless of pass/fail — they never affect exit code.
	for w: String in soft_warnings:
		printerr("[%s] WARN: %s" % [LINT_TAG, w])

	if hard_errors.is_empty():
		print("[%s] PASS: %s ≺ %s satisfied (%d advisory warning(s))" % [
			LINT_TAG, HARD_PREDECESSOR, SUBJECT, soft_warnings.size(),
		])
		quit(0)
		return

	for e: String in hard_errors:
		printerr("[%s] FAIL: %s" % [LINT_TAG, e])
	printerr("")
	printerr("[%s] FAIL: %d hard boot-order violation(s). Fix [autoload] order in project.godot." % [LINT_TAG, hard_errors.size()])
	quit(1)


## Parse the [autoload] section. Returns {autoload_key: 1-based_position}.
## Position is the listing order within the section (comments + blanks skipped).
## Empty Dictionary => no [autoload] section present.
func _parse_autoload_order(lines: PackedStringArray) -> Dictionary:
	var order: Dictionary = {}
	var in_autoload_section: bool = false
	var seen_section: bool = false
	var position: int = 0

	for raw_line: String in lines:
		var stripped: String = raw_line.strip_edges()

		# Skip blank lines and INI comments (; …).
		if stripped.is_empty() or stripped.begins_with(";"):
			continue

		# Section header transitions (e.g. [autoload], [display]).
		if stripped.begins_with("[") and stripped.ends_with("]"):
			in_autoload_section = stripped == "[autoload]"
			if in_autoload_section:
				seen_section = true
			continue

		if not in_autoload_section:
			continue

		# Entry form: Key="*res://path.gd". Key is everything before the first '='.
		var eq_index: int = stripped.find("=")
		if eq_index <= 0:
			continue
		var key: String = stripped.substr(0, eq_index).strip_edges()
		if key.is_empty():
			continue
		position += 1
		# First occurrence wins (defensive against duplicate keys).
		if not order.has(key):
			order[key] = position

	if not seen_section:
		return {}
	return order


func _read_lines(res_path: String) -> PackedStringArray:
	var file := FileAccess.open(res_path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines
