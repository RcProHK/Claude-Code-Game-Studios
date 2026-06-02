#!/usr/bin/env -S godot --headless --script
## CI Lint — Audio gateway caller ban (GDD Rule 1; Story 001 AC-01).
##
## Purpose:
##   Direct AudioServer mutation / AudioStreamPlayer instantiation / bus assignment is
##   FORBIDDEN outside `src/autoload/audio_manager.gd`. ALL SFX/BGM playback + bus volume
##   control MUST route through the AudioManager closed gateway (play_sfx / play_bgm /
##   set_bus_volume_db / set_bus_muted), so the web-export audio budget + unlock + ducking
##   governance stays centralised — the same single-gateway posture as #5/#6/#7.
##
## Scan target:
##   res://src/   (recursive — every .gd file EXCEPT the exempt gateway autoload).
##
## Exempt gateway (may touch AudioServer / AudioStreamPlayer / .bus directly):
##   res://src/autoload/audio_manager.gd
##
## Forbidden patterns (regex), on non-comment lines outside the exempt file:
##   AudioServer\.                      — any AudioServer mutation/read outside the gateway
##   AudioStreamPlayer\.new\s*\(        — direct AudioStreamPlayer instantiation
##   AudioStreamPlayer[^\n]*\.bus\s*=   — direct bus assignment on an AudioStreamPlayer
##                                        (anchored to the AudioStreamPlayer token so unrelated
##                                         identifiers like `event_bus =` are NOT false-positives)
##
## Usage:
##   godot --headless --script tools/ci/check_audio_callers.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: GDD design/gdd/audio-manager.md Rule 1 + AC-01;
##   .claude/docs/technical-preferences.md Forbidden Patterns; ADR-0008 (gateway autoload).
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const LINT_TAG: String = "check_audio_callers"

## Full res:// path of the sole gateway permitted to touch AudioServer / AudioStreamPlayer.
const EXEMPT_FILES := [
	"res://src/autoload/audio_manager.gd",
]

## Forbidden AudioServer / AudioStreamPlayer mutation tokens.
const FORBIDDEN_PATTERNS: Array[String] = [
	"AudioServer\\.",
	"AudioStreamPlayer\\.new\\s*\\(",
	"AudioStreamPlayer[^\\n]*\\.bus\\s*=",
]


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	var compiled: Array[RegEx] = []
	for pattern: String in FORBIDDEN_PATTERNS:
		var re := RegEx.new()
		if re.compile(pattern) != OK:
			push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
			quit(2)
			return
		compiled.append(re)

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if EXEMPT_FILES.has(file_path):
			continue
		violations.append_array(_scan_file(file_path, compiled))

	if violations.is_empty():
		print("[%s] PASS: scanned %d file(s), 0 direct AudioServer/AudioStreamPlayer use outside audio_manager.gd" % [
			LINT_TAG, scan_files.size(),
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: direct audio engine use FORBIDDEN — route through AudioManager (pattern: %s)" % [
			v["file"], v["line"], v["col"], v["pattern"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d violation(s). Only audio_manager.gd may touch AudioServer/AudioStreamPlayer (GDD Rule 1)." % [
		LINT_TAG, violations.size(),
	])
	quit(1)


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


func _scan_file(file_path: String, compiled: Array[RegEx]) -> Array[Dictionary]:
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
		# Strip trailing comment before matching (an inline comment naming a forbidden token
		# must not false-positive). Code before the comment is still scanned.
		var line: String = _strip_trailing_comment(raw_line)
		for j: int in compiled.size():
			var m := compiled[j].search(line)
			if m != null:
				violations.append({
					"file": file_path,
					"line": i + 1,
					"col": m.get_start() + 1,
					"pattern": FORBIDDEN_PATTERNS[j],
					"snippet": raw_line.strip_edges(),
				})
	return violations


## Remove a trailing `#` comment, ignoring `#` inside string literals.
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
