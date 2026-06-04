#!/usr/bin/env -S godot --headless --script
## CI Lint — GSM state_changed plain-connect ban (attention-budget #33 Story 004 AC-12).
##
## Purpose:
##   Subscribing to #1 GameStateMachine.state_changed with a PLAIN `.connect()` from an
##   autoload `_ready()` silently misses the initial state: GSM does NOT emit
##   state_changed from its own _ready() (downstream subscribers have not yet connected —
##   ADR-0006 Contract 4), so the only way to receive the current state is the
##   sentinel-delivery helper `connect_for_initial_state(callable)` (Contract 6).
##   Any `state_changed.connect(` plain form is therefore a boot-correctness bug and is
##   FORBIDDEN — use `connect_for_initial_state(...)` instead.
##
## Scan target:
##   res://src/   (recursive — every .gd file EXCEPT the exempt owner autoload).
##
## Exempt owner (MAJOR-5 owner-exempt — AC-12 + PR #12 debug_override lesson):
##   res://src/autoload/game_state_machine.gd
##   GSM legitimately contains `state_changed.connect(callable)` INSIDE its own
##   connect_for_initial_state() helper (the seam that every other file must use).
##   Banning the owner that DEFINES the seam would turn main RED on day one — the exact
##   failure mode of the over-broad debug_override lint (PR #12). The owner is exempt.
##
## Forbidden pattern (regex), on non-comment lines outside the exempt file:
##   state_changed\s*\.\s*connect\s*\(
##     - The trailing `\(` (after optional whitespace following `connect`) is what makes
##       this match ONLY the plain `.connect(` form. The legal helper
##       `state_changed.connect_for_initial_state(` does NOT match: after `connect` comes
##       `_for_initial_state`, i.e. `connect` is followed by `_`, never `(` → no match.
##     - Anchored on the `state_changed` token, so a legal `phase_changed.connect(`
##       (#9 WST 2-arg subscription, deliberately plain) is NOT matched.
##
## Usage:
##   godot --headless --script tools/ci/check_attention_subscription.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: ADR-0006 Contract 6 (connect_for_initial_state) + Contract 4 (boot
##   order); design/gdd/attention-budget-policy.md Rule 9 + AC-12.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const LINT_TAG: String = "check_attention_subscription"

## The sole owner permitted to call `state_changed.connect(` directly: it does so
## INSIDE connect_for_initial_state() — the seam every other file must route through.
const EXEMPT_FILES := [
	"res://src/autoload/game_state_machine.gd",
]

## Forbidden GSM plain-connect token. Matched on any non-comment line outside the
## exempt owner. `\(` after `connect` excludes `connect_for_initial_state(`; the
## `state_changed` anchor excludes the legal `phase_changed.connect(`.
const FORBIDDEN_PATTERNS: Array[String] = [
	"state_changed\\s*\\.\\s*connect\\s*\\(",
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
		print("[%s] PASS: scanned %d file(s), 0 plain state_changed.connect( outside game_state_machine.gd" % [
			LINT_TAG, scan_files.size(),
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: plain `state_changed.connect(` FORBIDDEN — use connect_for_initial_state() (pattern: %s)" % [
			v["file"], v["line"], v["col"], v["pattern"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d violation(s). Only game_state_machine.gd may connect state_changed directly (ADR-0006 C6)." % [
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
		# Strip trailing comment before matching so an inline comment that mentions
		# the forbidden token (e.g. "# FORBIDDEN: state_changed.connect(...)") does
		# not false-positive. Code before the comment is still scanned.
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


## Remove a trailing `#` comment from a code line, ignoring `#` inside string
## literals (single/double quote). Returns the code portion only.
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
