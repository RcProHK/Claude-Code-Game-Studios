#!/usr/bin/env -S godot --headless --script
## CI Lint — EnemyDirector 8 state-container locality (AC-01 complement, GDD Rule 1).
##
## Purpose (GDD Rule 1 / TR-enemy-001):
##   EnemyDirector is the caller-side state owner (inverse of #13 CombatResolver's
##   stateless purity). All 8 hidden-state containers MUST be declared in the
##   EnemyDirector class body. If any container is migrated to another class (or
##   simply removed), state leaks out of the single ownership chokepoint and the
##   5-obligation availability guarantee (Falsifiable Test #4) breaks silently.
##
## Scan target:
##   res://src/autoload/enemy_director.gd  (this single file ONLY).
##
## Required declarations (each must appear as a `var <name>` declaration):
##   _catch_up_queue        _anomaly_rate_tracker   _enemy_state_pool
##   _killed_dedupe_set     _spawn_pool             _rng_factory
##   _active_wave           _boss_anchor_state
##
## Detection: each container must match `^\s*var\s+<name>\b` on some non-comment
##   line. Missing ANY one => violation. (This lint asserts presence, not type —
##   types are DI seams per project convention, intentionally untyped.)
##
## Usage:
##   godot --headless --script tools/ci/check_enemy_director_state_locality.gd
##
## Exit codes:
##   0 = all 8 state containers declared in the class body (clean)
##   1 = one or more containers missing (CI MUST fail)
##   2 = internal error (target file missing, regex compile failure, unreadable)
##
## Governing docs: design/gdd/enemy-director.md Rule 1; TR-enemy-001;
##   story-001-core-class-state-containers.md; story-003-ci-lint-suite-b.md.
extends SceneTree


const TARGET_FILE: String = "res://src/autoload/enemy_director.gd"
const LINT_TAG: String = "check_enemy_director_state_locality"

## The 8 caller-side state containers required by GDD Rule 1.
const REQUIRED_CONTAINERS: Array[String] = [
	"_catch_up_queue",
	"_anomaly_rate_tracker",
	"_enemy_state_pool",
	"_killed_dedupe_set",
	"_spawn_pool",
	"_rng_factory",
	"_active_wave",
	"_boss_anchor_state",
]


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_error("[%s] target not found: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	# Pre-compile one `var <name>` declaration regex per required container.
	var compiled: Dictionary = {}  # name -> RegEx
	for name: String in REQUIRED_CONTAINERS:
		var re := RegEx.new()
		var pattern: String = "^\\s*var\\s+%s\\b" % name
		if re.compile(pattern) != OK:
			push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
			quit(2)
			return
		compiled[name] = re

	var lines: PackedStringArray = _read_lines(abs_path)
	if lines.is_empty():
		push_error("[%s] unreadable or empty: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var found: Dictionary = {}  # name -> true once a declaration is seen
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		for name: String in REQUIRED_CONTAINERS:
			if found.has(name):
				continue
			if compiled[name].search(line) != null:
				found[name] = true

	var missing: Array[String] = []
	for name: String in REQUIRED_CONTAINERS:
		if not found.has(name):
			missing.append(name)

	if missing.is_empty():
		print("[%s] PASS: %s — all %d state containers declared in class body" % [
			LINT_TAG, TARGET_FILE, REQUIRED_CONTAINERS.size(),
		])
		quit(0)
		return

	for name: String in missing:
		printerr("%s: REQUIRED state container `%s` not declared — Rule 1 caller-side state locality" % [
			TARGET_FILE, name,
		])
	printerr("")
	printerr("[%s] FAIL: %d of %d state container(s) missing from EnemyDirector class body." % [
		LINT_TAG, missing.size(), REQUIRED_CONTAINERS.size(),
	])
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
