#!/usr/bin/env -S godot --headless --script
## CI Lint — receive_loot() caller whitelist (#21 story 009, AC-21 owner-exempt).
##
## Purpose:
##   InventorySystem.receive_loot() is the INV-M3 banking seam. Its callers are
##   locked to: (a) the OWNER's internal re-entrancy/boot-drain sites inside
##   inventory_system.gd (PR #12 lesson — gateway lints MUST exempt the owner
##   that defines+guards the seam, or main goes RED), and (b) the SOLE external
##   caller: loot_reveal_coordinator.gd (#21 — S3 commit + micro_ack banking).
##   Any other caller bypasses the reveal-queue commit-point discipline.
##
## Usage:
##   godot --headless --script tools/ci/check_receive_loot_callers.gd
##
## Exit codes:
##   0 = clean; 1 = violation; 2 = internal error
extends SceneTree

const LINT_TAG: String = "check_receive_loot_callers"
const SCAN_ROOT: String = "res://src"
const EXEMPT_FILES: Array[String] = [
	"res://src/autoload/inventory_system.gd",       # owner — internal call sites
	"res://src/autoload/loot_reveal_coordinator.gd", # #21 — sole external caller (AC-21)
]


func _init() -> void:
	var violations: Array[String] = []
	var regex := RegEx.new()
	if regex.compile("(?<![a-zA-Z0-9_])receive_loot\\s*\\(") != OK:
		push_error("[%s] regex compile failure" % LINT_TAG)
		quit(2)
		return
	var files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, files)
	if files.is_empty():
		push_error("[%s] no .gd files under %s" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return
	for path: String in files:
		if path in EXEMPT_FILES:
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var line_no: int = 0
		while not f.eof_reached():
			var line: String = f.get_line()
			line_no += 1
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#") or stripped.begins_with("##"):
				continue
			if stripped.contains("func receive_loot"):
				continue
			if regex.search(line) != null:
				violations.append("%s:%d — receive_loot() caller outside the whitelist" % [path, line_no])
	if violations.is_empty():
		print("[%s] PASS — receive_loot callers locked to owner + #21 coordinator" % LINT_TAG)
		quit(0)
	else:
		for v: String in violations:
			push_error("[%s] %s" % [LINT_TAG, v])
		quit(1)


func _collect_gd_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_files(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
