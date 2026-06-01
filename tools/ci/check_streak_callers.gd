#!/usr/bin/env -S godot --headless --script
## CI Lint — Streak buff-multiplier caller whitelist (ADR-0003 FR-3; Story 009 AC-39).
##
## Purpose (Pillar 1 anti-pillar #1 — streak must NEVER become avatar power):
##   `get_streak_buff_multiplier()` feeds loot rarity (#15) + Mirror Moment ceremony (#29)
##   ONLY. ADR-0003 (Accepted 2026-05-30) confirms those two are the sole authorized
##   consumers. Any OTHER caller — especially under src/gameplay/stats/, abilities/, pr/,
##   zones/ — would route streak into the avatar-power path, violating the Real-Body-Real-
##   Power pillar. This lint scans ALL of src/ and fails on any non-whitelisted reference.
##
## This is the EXPANDED (GDScript, fixture-backed, GUT-suite) superset of the fast-path
## shell lint tools/ci/check_streak_caller_whitelist.sh (Story 007). CI runs both.
##
## Scan target:
##   res://src/   (recursive — every .gd file).
##
## Whitelist (may reference get_streak_buff_multiplier):
##   res://src/autoload/streak_system.gd      — owner (defines it)
##   **/loot_drop_system.gd                    — #15 Loot Drop System (rarity modifier)
##   **/mirror_moment_system.gd                — #29 Mirror Moment (ceremony intensity, future)
##   NOTE: GDD Section H AC-39 lists whitelist as src/gameplay/loot/ + src/gameplay/mirror_moment/;
##   that is STALE — the real authorized consumer lives at src/autoload/loot_drop_system.gd.
##   This lint whitelists the actual sanctioned files (basename-anchored, mirrors the .sh).
##
## Forbidden pattern (regex), on non-comment lines outside whitelisted files:
##   get_streak_buff_multiplier\s*\(   — any call site (the owner's `func` def is whitelisted)
##
## Usage:
##   godot --headless --script tools/ci/check_streak_callers.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more out-of-whitelist callers (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: ADR-0003 FR-3; ADR-0006 Contract 12; design/gdd/streak-system.md Rule 13;
##   TR-streak-002; Story 009.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const LINT_TAG: String = "check_streak_callers"

## Files permitted to reference get_streak_buff_multiplier. The owner is matched by exact
## res:// path; the two sanctioned consumers are matched by basename suffix so they stay
## whitelisted regardless of which directory they ultimately live in.
const EXEMPT_EXACT := [
	"res://src/autoload/streak_system.gd",
]
const EXEMPT_BASENAMES := [
	"loot_drop_system.gd",
	"mirror_moment_system.gd",
]

const FORBIDDEN_PATTERN: String = "get_streak_buff_multiplier\\s*\\("


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[%s] regex compile failed: %s" % [LINT_TAG, FORBIDDEN_PATTERN])
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if _is_whitelisted(file_path):
			continue
		violations.append_array(_scan_file(file_path, re))

	if violations.is_empty():
		print("[%s] PASS: scanned %d file(s), 0 out-of-whitelist callers of get_streak_buff_multiplier()" % [
			LINT_TAG, scan_files.size(),
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: get_streak_buff_multiplier() FORBIDDEN here — streak buff is NOT avatar power (ADR-0003 FR-3)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d out-of-whitelist caller(s). Only loot_drop_system.gd + mirror_moment_system.gd may read the streak buff (ADR-0003 FR-3)." % [
		LINT_TAG, violations.size(),
	])
	quit(1)


## A file is exempt if it is the owner (exact path) or one of the sanctioned consumers
## (basename suffix). Basename match uses a leading "/" anchor so e.g. a stray
## "loot_drop_system_helper.gd" would NOT be whitelisted.
func _is_whitelisted(file_path: String) -> bool:
	if EXEMPT_EXACT.has(file_path):
		return true
	for base: String in EXEMPT_BASENAMES:
		if file_path.ends_with("/" + base):
			return true
	return false


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[%s] cannot open directory: %s" % [LINT_TAG, dir_path])
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == FILE_EXTENSION:
			accumulator.append(dir_path.path_join(file_name))
	for subdir_name: String in dir.get_directories():
		_collect_gd_files(dir_path.path_join(subdir_name), accumulator)


func _scan_file(file_path: String, re: RegEx) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[%s] cannot read: %s" % [LINT_TAG, file_path])
		return violations
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	for i: int in lines.size():
		var raw_line: String = lines[i]
		if raw_line.strip_edges(true, false).begins_with("#"):
			continue
		var line: String = _strip_trailing_comment(raw_line)
		var m := re.search(line)
		if m != null:
			violations.append({
				"file": file_path,
				"line": i + 1,
				"col": m.get_start() + 1,
				"snippet": raw_line.strip_edges(),
			})
	return violations


## Remove a trailing `#` comment from a code line, ignoring `#` inside string literals.
func _strip_trailing_comment(line: String) -> String:
	var in_single: bool = false
	var in_double: bool = false
	for k: int in line.length():
		var ch: String = line[k]
		if ch == "\"" and not in_single:
			in_double = not in_double
		elif ch == "'" and not in_double:
			in_single = not in_single
		elif ch == "#" and not in_single and not in_double:
			return line.substr(0, k)
	return line
