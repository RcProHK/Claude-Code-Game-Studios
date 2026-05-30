#!/usr/bin/env -S godot --headless --script
## CI Lint — `_generate_loot_internal()` caller whitelist (AC-28, ADR-0005)
##
## AC-28 / Story 001: `_generate_loot_internal()` is the internal loot-minting
## chokepoint. It applies the ADR-0005 rarity formula, the source-event clamp
## (Formula 1), idempotency guards, and the daily-token gate. External systems
## MUST route through a public trigger / signal — they must NEVER call
## `_generate_loot_internal(...)` directly, which would bypass every gate.
##
## Whitelist (may call `_generate_loot_internal`):
##   res://src/autoload/loot_drop_system.gd   (self — internal pipeline)
##
## Fail condition: any OTHER `src/` .gd file matching `_generate_loot_internal(`.
##
## Usage:
##   godot --headless --script tools/ci/check_loot_generator_callers.gd
##
## Exit codes:
##   0 = no unauthorized callers (clean)
##   1 = one or more unauthorized callers found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: design/gdd/loot-drop-system.md AC-28; ADR-0005; ADR-0006 C12;
##   story-001-ci-lints-closed-api.md.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const LINT_TAG: String = "check_loot_generator_callers"
## Matches `_generate_loot_internal(` with optional whitespace before the paren.
const FORBIDDEN_PATTERN: String = "_generate_loot_internal\\s*\\("

## Full res:// path so a same-basename file elsewhere cannot slip through.
const WHITELISTED_FILES := [
	"res://src/autoload/loot_drop_system.gd",
]


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
		if WHITELISTED_FILES.has(file_path):
			continue
		violations.append_array(_scan_file(file_path, re))

	if violations.is_empty():
		print("[%s] PASS: scanned %d file(s), 0 unauthorized _generate_loot_internal() callers" % [LINT_TAG, scan_files.size()])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: Unauthorized _generate_loot_internal() call — route through a public trigger/signal (AC-28)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d unauthorized caller(s). Only loot_drop_system.gd internal pipeline may call _generate_loot_internal()." % [LINT_TAG, violations.size()])
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
		var line: String = lines[i]
		if line.strip_edges(true, false).begins_with("#"):
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
