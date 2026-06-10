#!/usr/bin/env -S godot --headless --script
## CI Lint CI-MM-1 — MirrorMoment zero tier-derivation (ADR-0010 / CR-M14 / AC-20).
##
## Purpose:
##   #29 owns the ceremony, NOT the avatar's evolution tier. Every tier number must be
##   READ from #26.get_evolution_snapshot().tier or the milestone signal payload — never
##   computed. This lint is the structural enforcement of the ADR-0010 seam, symmetric
##   with #26's check_avatar_renderer_no_ceremony.gd (AC-30) guarding the other side.
##
## Scan target: every res://src/**/mirror_moment*.gd.
## Exit codes: 0 = clean, 1 = violation (CI MUST fail), 2 = internal error.
## Governing: ADR-0010, mirror-moment.md CR-M14 / CI-MM-1, Story 014.
extends SceneTree

const LINT_TAG := "check_mirror_moment_no_tier_compute"

## Tier-derivation signatures that must NEVER appear in #29 source. Reading a tier VALUE
## (snap.tier / pending_tier) is allowed — these tokens are the act of COMPUTING one.
const FORBIDDEN_PATTERNS: Array[String] = [
	"(?i)get_stat\\s*\\(",            # deriving tier from raw canonical stats (#26's job)
	"(?i)derive_tier",               # #26 Formula 2 entry point
	"(?i)effective_tier",            # the effective_tier = max(computed, historical) pattern
	"(?i)stat_thresholds",           # threshold tables live in #26 AvatarEvolutionConfig
	"(?i)peak_thresholds",
	"(?i)ability_thresholds",
	"(?i)depth_thresholds",
	"(?i)evolution_tier_history",    # #26-owned persistence key
	"(?i)historical_max",            # #26 monotonic tier lock state
	"(?i)AvatarFormulas",            # using #26's derivation formulas = deriving
]


func _init() -> void:
	var compiled: Array[RegEx] = []
	for pattern: String in FORBIDDEN_PATTERNS:
		var re := RegEx.new()
		if re.compile(pattern) != OK:
			push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
			quit(2)
			return
		compiled.append(re)

	var scan_files: Array[String] = []
	_collect("res://src/", scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		violations.append_array(_scan_file(file_path, compiled))

	if violations.is_empty():
		print("[%s] PASS: scanned %d #29 file(s), 0 tier-derivation (ADR-0010 / CR-M14)" % [LINT_TAG, scan_files.size()])
		quit(0)
		return
	for v: Dictionary in violations:
		printerr("%s:%d: tier-derivation FORBIDDEN in #29 (ADR-0010 / CR-M14 — read snapshot.tier instead) [%s]" % [
			v["file"], v["line"], v["pattern"]])
		printerr("  > %s" % v["snippet"])
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)


func _collect(dir_path: String, acc: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == "gd" and file_name.begins_with("mirror_moment"):
			acc.append(dir_path.path_join(file_name))
	for subdir: String in dir.get_directories():
		_collect(dir_path.path_join(subdir), acc)


func _scan_file(file_path: String, compiled: Array[RegEx]) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return violations
	var i := 0
	while not file.eof_reached():
		var raw := file.get_line()
		i += 1
		if raw.strip_edges(true, false).begins_with("#"):
			continue
		for j: int in compiled.size():
			if compiled[j].search(raw) != null:
				violations.append({"file": file_path, "line": i, "pattern": FORBIDDEN_PATTERNS[j], "snippet": raw.strip_edges()})
	file.close()
	return violations
