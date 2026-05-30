#!/usr/bin/env -S godot --headless --script
## CI Lint — only LootDropSystem may write the `loot.*` persistence namespace (AC-27)
##
## AC-27 / Story 001: the `loot.*` PersistenceLayer namespace is OWNED by
## LootDropSystem. Any other `src/` file calling `PersistenceLayer.write("loot...")`
## bypasses LootDrop's idempotency + optimistic-persist pipeline (ADR-0003 5-step
## persist) and the daily-token/Private-Mode gates. Cross-system writes to the loot
## namespace are forbidden — emit a signal LootDropSystem subscribes to instead.
##
## Whitelist (may write `loot.*`):
##   res://src/autoload/loot_drop_system.gd
##
## Fail condition: any OTHER `src/` .gd file matching `PersistenceLayer.write("loot.`
## (or `'loot.` — single-quoted). `PersistenceLayer.write("player.` etc. do NOT match.
##
## Usage:
##   godot --headless --script tools/ci/check_loot_namespace_writers.gd
##
## Exit codes:
##   0 = no unauthorized loot-namespace writers (clean)
##   1 = one or more unauthorized writers found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: design/gdd/loot-drop-system.md AC-27; ADR-0003 (loot.pending
##   namespace); story-001-ci-lints-closed-api.md.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const LINT_TAG: String = "check_loot_namespace_writers"
## Matches PersistenceLayer.write with a "loot. / 'loot. namespace key as the first
## string argument. Whitespace tolerated around the paren.
const FORBIDDEN_PATTERN: String = "PersistenceLayer\\.write\\s*\\(\\s*[\"']loot\\."

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
		print("[%s] PASS: scanned %d file(s), 0 unauthorized loot.* namespace writers" % [LINT_TAG, scan_files.size()])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: Unauthorized write to loot.* namespace — only loot_drop_system.gd owns it; emit a signal instead (AC-27)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d unauthorized loot-namespace writer(s)." % [LINT_TAG, violations.size()])
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
