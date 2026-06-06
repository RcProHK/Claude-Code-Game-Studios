#!/usr/bin/env -S godot --headless --script
## CI Lint — InventorySystem re-entrancy discipline (#17 Rule 6 / EC-15; Story 016).
##
## Purpose:
##   StatSystem emits `stat_changed` SYNCHRONOUSLY inside #17's own call stack
##   (apply_equipment_modifier → emit). A handler that synchronously calls back
##   into an InventorySystem mutation API re-enters mid-operation — the exact
##   bug class ADR-0006 Contract 1's generational lock exists for. The runtime
##   `_mutating` guard catches it live; this lint catches it statically:
##   any `stat_changed` handler must DEFER its InventorySystem mutation calls
##   (process_frame ONE_SHOT / call_deferred), never call them synchronously.
##
## Scan target:
##   res://src/ (recursive .gd) — every function whose name starts with
##   `_on_stat_changed` (the project's stat_changed handler naming convention).
##
## Exempt (owner — defines and guards the seam; main-RED owner-exempt lesson):
##   res://src/autoload/inventory_system.gd
##
## Forbidden inside a stat_changed handler body (non-comment, non-deferred line):
##   InventorySystem.(receive_loot|salvage|bulk_salvage|equip|unequip|claim|set_lock)(
##
## Usage:   godot --headless --script tools/ci/check_inventory_reentrancy.gd
## Exit:    0 clean | 1 violations | 2 internal error
##
## Governing docs: equipment-inventory.md Rule 6 / EC-15; ADR-0006 Contract 5.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const LINT_TAG: String = "check_inventory_reentrancy"

const EXEMPT_FILES := [
	"res://src/autoload/inventory_system.gd",
]

const HANDLER_PREFIX: String = "func _on_stat_changed"
const MUTATION_PATTERN: String = \
	"InventorySystem\\.(receive_loot|salvage|bulk_salvage|equip|unequip|claim|set_lock)\\s*\\("
const DEFER_TOKENS := ["call_deferred", "process_frame", "_defer"]


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	var mutation_re := RegEx.new()
	if mutation_re.compile(MUTATION_PATTERN) != OK:
		push_error("[%s] regex compile failed" % LINT_TAG)
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if EXEMPT_FILES.has(file_path):
			continue
		violations.append_array(_scan_file(file_path, mutation_re))

	if violations.is_empty():
		print("[%s] PASS: scanned %d file(s), 0 synchronous InventorySystem mutations inside stat_changed handlers" % [
			LINT_TAG, scan_files.size(),
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: synchronous InventorySystem mutation inside a stat_changed handler FORBIDDEN (EC-15) — defer it" % [
			v["file"], v["line"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d violation(s). stat_changed handlers must defer InventorySystem mutations (Rule 6 / Contract 5)." % [
		LINT_TAG, violations.size(),
	])
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[%s] cannot open directory: %s" % [LINT_TAG, dir_path])
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == "gd":
			accumulator.append(dir_path.path_join(file_name))
	for subdir_name: String in dir.get_directories():
		_collect_gd_files(dir_path.path_join(subdir_name), accumulator)


## Track whether each line sits inside a `func _on_stat_changed*` body (function
## scope ends at the next top/class-level `func `/`class ` declaration or a
## dedent to column 0 with content). Within scope, a mutation call on a line
## without a defer token is a violation.
func _scan_file(file_path: String, mutation_re: RegEx) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[%s] cannot read: %s" % [LINT_TAG, file_path])
		return violations
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	var in_handler: bool = false
	var handler_indent: int = 0
	for i: int in lines.size():
		var raw_line: String = lines[i]
		var stripped: String = raw_line.strip_edges(true, false)
		if stripped.begins_with("#"):
			continue
		var indent: int = raw_line.length() - stripped.length()
		if stripped.begins_with("func ") or stripped.begins_with("static func ") \
				or stripped.begins_with("class "):
			in_handler = stripped.begins_with(HANDLER_PREFIX)
			handler_indent = indent
			continue
		if not in_handler:
			continue
		if indent <= handler_indent and not stripped.is_empty():
			in_handler = false
			continue
		var line: String = raw_line.get_slice("#", 0)
		if mutation_re.search(line) == null:
			continue
		var deferred: bool = false
		for token: String in DEFER_TOKENS:
			if line.contains(token):
				deferred = true
				break
		if not deferred:
			violations.append({
				"file": file_path, "line": i + 1, "snippet": stripped,
			})
	return violations
