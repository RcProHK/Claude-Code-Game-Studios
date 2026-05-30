#!/usr/bin/env -S godot --headless --script
## CI Lint — CombatResolver must read NO engine/global singletons (GDD Rule 6, ADR-0006 C12)
##
## AC-singletons-lint / Story 001: CombatResolver is a pure function — every input
## arrives PRE-SNAPSHOTTED in CombatContext (stats via ctx.caster_stats, target
## via ctx.target_state, rng via ctx.rng, gsm phase via ctx.gsm_state). It must
## NEVER reach out to a live singleton, because a global read makes the result
## non-deterministic and breaks replay (FR-1).
##
## Forbidden references in `src/core/combat_resolver.gd`:
##   StatSystem.  AbilitySystem.  GameStateMachine.  ScreenEffects.  ParticleSystemWrapper.
##
## Usage:
##   godot --headless --script tools/ci/check_combat_resolver_engine_singletons.gd
##
## Exit codes:
##   0 = no singleton references (clean)
##   1 = one or more forbidden singleton references (CI MUST fail)
##   2 = internal error (target file / src/ missing, regex compile failure)
##
## Governing docs: design/gdd/combat-resolver.md Rule 6; ADR-0006 Contract 12;
##   story-001-ci-lints-purity-defense.md AC-singletons-lint.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const TARGET_FILE: String = "res://src/core/combat_resolver.gd"
const PATTERNS: PackedStringArray = [
	"StatSystem\\.",
	"AbilitySystem\\.",
	"GameStateMachine\\.",
	"ScreenEffects\\.",
	"ParticleSystemWrapper\\.",
]
const FAIL_MESSAGE: String = "forbidden engine/global singleton reference — inputs must arrive via CombatContext snapshot (GDD Rule 6, ADR-0006 C12)"
const LINT_TAG: String = "check_combat_resolver_engine_singletons"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	if not FileAccess.file_exists(TARGET_FILE):
		push_error("[%s] target not found: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var regexes: Array[RegEx] = []
	for ps: String in PATTERNS:
		var re := RegEx.new()
		if re.compile(ps) != OK:
			push_error("[%s] regex compile failed: %s" % [LINT_TAG, ps])
			quit(2)
			return
		regexes.append(re)

	var file := FileAccess.open(TARGET_FILE, FileAccess.READ)
	if file == null:
		push_error("[%s] cannot read: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	var violations: Array[Dictionary] = []
	for i: int in lines.size():
		var line: String = lines[i]
		if line.strip_edges(true, false).begins_with("#"):
			continue  # skip full-line comments (doc-comment mentions are not code)
		for re: RegEx in regexes:
			var m := re.search(line)
			if m != null:
				violations.append({"line": i + 1, "col": m.get_start() + 1, "snippet": line.strip_edges()})
				break

	if violations.is_empty():
		print("[%s] PASS: %s reads no engine/global singletons" % [LINT_TAG, TARGET_FILE])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: %s" % [TARGET_FILE, v["line"], v["col"], FAIL_MESSAGE])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)
