#!/usr/bin/env -S godot --headless --script
## CI Lint CI-MM-3 — MirrorMoment cadence is data-driven + #26-parity (CR-M1 / G-MM-4 / AC).
##
## Purpose (two guarantees):
##   (a) The coordinator + formulas hold ZERO cadence/bfcache literals — every value is
##       loaded from mirror_moment_config.tres (CR-M1). The config resource (.tres) and its
##       schema-default .gd are the data-driven SOURCE, so they are intentionally excluded.
##   (b) Runtime parity MIRROR_CADENCE_SECONDS == #26.MILESTONE_CADENCE_SECONDS is asserted
##       in the coordinator (_load_config_or_crash); this lint additionally verifies the
##       .tres value equals #26's constant statically so a config edit can't silently break
##       parity before boot.
##
## Scan target (literal ban): mirror_moment_coordinator.gd + mirror_moment_formulas.gd.
## Parity check: assets/data/mirror_moment_config.tres cadence_seconds == #26 const.
## Exit codes: 0 = clean, 1 = violation, 2 = internal error.
## Governing: mirror-moment.md CR-M1 / CI-MM-3 / G-MM-4, Story 014.
extends SceneTree

const LINT_TAG := "check_mirror_moment_cadence_data_driven"

## Cadence-family literals that must NOT be hardcoded in the executable logic.
const FORBIDDEN_PATTERNS: Array[String] = [
	"604800",   # MIRROR_CADENCE_SECONDS — must come from config
	"\\b30000\\b",  # BFCACHE_CONTINUE_THRESHOLD_MS — must come from config
]

const LOGIC_FILES := [
	"res://src/autoload/mirror_moment_coordinator.gd",
	"res://src/core/mirror_moment_formulas.gd",
]
const CONFIG_TRES := "res://assets/data/mirror_moment_config.tres"
const EXPECTED_CADENCE := 604800  # #26 MILESTONE_CADENCE_SECONDS (entities.yaml milestone_cadence_seconds)


func _init() -> void:
	var compiled: Array[RegEx] = []
	for pattern: String in FORBIDDEN_PATTERNS:
		var re := RegEx.new()
		if re.compile(pattern) != OK:
			push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
			quit(2)
			return
		compiled.append(re)

	var violations: Array[Dictionary] = []
	for file_path: String in LOGIC_FILES:
		if FileAccess.file_exists(file_path):
			violations.append_array(_scan_file(file_path, compiled))

	# Parity: load the config and read #26's constant; they must match.
	var parity_err := _check_parity()

	if violations.is_empty() and parity_err == "":
		print("[%s] PASS: 0 cadence literals in logic + config cadence == #26 (%d)" % [LINT_TAG, EXPECTED_CADENCE])
		quit(0)
		return
	for v: Dictionary in violations:
		printerr("%s:%d: hardcoded cadence literal FORBIDDEN (load from mirror_moment_config.tres — CR-M1) [%s]" % [
			v["file"], v["line"], v["pattern"]])
		printerr("  > %s" % v["snippet"])
	if parity_err != "":
		printerr("[%s] PARITY: %s" % [LINT_TAG, parity_err])
	printerr("[%s] FAIL: %d literal violation(s)%s." % [LINT_TAG, violations.size(), " + parity" if parity_err != "" else ""])
	quit(1)


func _check_parity() -> String:
	if not FileAccess.file_exists(CONFIG_TRES):
		return "config missing at " + CONFIG_TRES
	var cfg = load(CONFIG_TRES)
	if cfg == null:
		return "config failed to load at " + CONFIG_TRES
	var cadence := int(cfg.cadence_seconds)
	if cadence != EXPECTED_CADENCE:
		return "cadence_seconds %d != #26 MILESTONE_CADENCE_SECONDS %d (G-MM-4)" % [cadence, EXPECTED_CADENCE]
	# Cross-check against #26's actual shipped constant by reading the source text (never
	# load() it — avatar_renderer.gd references autoload singletons that don't compile in a
	# standalone --script SceneTree).
	var avatar_path := "res://src/autoload/avatar_renderer.gd"
	if FileAccess.file_exists(avatar_path):
		var src := FileAccess.get_file_as_string(avatar_path)
		if not src.contains("MILESTONE_CADENCE_SECONDS := %d" % EXPECTED_CADENCE):
			return "#26 MILESTONE_CADENCE_SECONDS no longer == %d — parity anchor drifted" % EXPECTED_CADENCE
	return ""


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
