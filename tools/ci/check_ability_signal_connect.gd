#!/usr/bin/env -S godot --headless --script
## CI Lint — ability signal plain .connect() detection (ADR-0006 Contract 6)
##
## AC-signal: Subscribers to the ability telemetry signals MUST use the Contract 6
##   helper (connect_for_initial_state) instead of a plain `.connect()`. Plain
##   connect in `_ready()` misses the initial-state delivery because the signal may
##   already have fired before the subscriber registered. This lint flags BOTH the
##   string-name connect (`connect("ability_unlocked", …)`) and the Godot 4
##   signal-object connect (`ability_unlocked.connect(…)`) for the four telemetry
##   signals guarded by Contract 6.
##
## Guarded signals: ability_unlocked, ability_cast, ability_cooldown_started,
##                   ability_cooldown_ended.
##
## Correct pattern:
##   ability_system.connect_for_initial_state(_on_ability_unlocked)
##
## Usage:
##   godot --headless --script tools/ci/check_ability_signal_connect.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure, unreadable file)
##
## Governing docs: ADR-0006 Contract 6; design/gdd/ability-system.md; TR-ability-016.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
## ability_system.gd owns the signals — internal connects are permitted.
const OWNER_FILE: String = "res://src/autoload/ability_system.gd"

## Per-file, signal-SPECIFIC exemptions (ADR-0006 Contract 6 + ADR-0010 #26).
## `ability_unlocked` has NO connect_for_initial_state path — AbilitySystem.cfis is bound to
## `ability_cast` (shipped reality, ability_system.gd:406). A subscriber that captures the
## initial unlock state another way is therefore permitted a plain `ability_unlocked.connect`.
## avatar_renderer.gd (#26) qualifies: its bootstrap derive sync-reads get_unlocked_abilities()
## (AC-16 erratum), so Contract 6's missed-initial-delivery concern does not apply. The exemption
## is signal-scoped: a plain `ability_cast.connect` in the same file is STILL flagged.
const ALLOWLIST := {
	"res://src/autoload/avatar_renderer.gd": ["ability_unlocked"],
}

## Combined pattern covering both connect styles:
##   1. .connect("ability_(unlocked|cast|cooldown_…)"   — string-name connect (legacy/self)
##   2. ability_(unlocked|cast|cooldown_started|cooldown_ended).connect(
##                                                       — Godot 4 signal-object connect
const FORBIDDEN_PATTERN: String = "(\\.connect\\(\\s*\"ability_(unlocked|cast|cooldown_)|ability_(unlocked|cast|cooldown_started|cooldown_ended)\\.connect\\()"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_ability_signal_connect] src/ not found at %s — cannot scan" % SCAN_ROOT)
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[check_ability_signal_connect] regex compile failed: %s" % FORBIDDEN_PATTERN)
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if file_path == OWNER_FILE:
			continue  # signal owner is permitted to connect its own signals internally.
		for v: Dictionary in _scan_file(file_path, re):
			if _is_allowlisted(file_path, v["snippet"]):
				continue  # signal-specific exemption (see ALLOWLIST rationale).
			violations.append(v)

	if violations.is_empty():
		print("[check_ability_signal_connect] PASS: scanned %d file(s), 0 plain-connect violations" % scan_files.size())
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: Plain .connect() on an ability signal FORBIDDEN — use connect_for_initial_state (see ADR-006 Contract 6)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
		printerr("  FIX: ability_system.connect_for_initial_state(_on_ability_unlocked)")
	printerr("")
	printerr("[check_ability_signal_connect] FAIL: %d violation(s). Use connect_for_initial_state — see ADR-006 Contract 6." % violations.size())
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[check_ability_signal_connect] cannot open directory: %s" % dir_path)
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
		push_error("[check_ability_signal_connect] cannot read: %s" % file_path)
		return violations
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	for i: int in lines.size():
		var line: String = lines[i]
		if _is_comment_line(line):
			continue
		var m := re.search(line)
		if m != null:
			violations.append({
				"file": file_path,
				"line": i + 1,
				"col": m.get_start() + 1,
				"snippet": line.strip_edges(),
			})
	return violations


## A line is a comment if its first non-whitespace character is `#`.
func _is_comment_line(line: String) -> bool:
	return line.strip_edges(true, false).begins_with("#")


## True when this file has a signal-specific exemption matching the violating snippet.
func _is_allowlisted(file_path: String, snippet: String) -> bool:
	if not ALLOWLIST.has(file_path):
		return false
	for allowed_signal: String in ALLOWLIST[file_path]:
		if allowed_signal in snippet:
			return true
	return false
