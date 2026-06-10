#!/usr/bin/env -S godot --headless --script
## CI Lint — AvatarRenderer tier thresholds are data-driven + BFCACHE parity (CR-4 / CI-2 /
## AC-24 / INV-5).
##
## Part A (CR-4 data-driven): tier thresholds (S_t / A_t / Sp_t / D_t) live in
##   avatar_evolution_config.tres and are read via `config.*_thresholds[t]`. A hardcoded
##   numeric threshold TABLE inlined in a .gd (e.g. `[0, 30, 60, 100]`) is a violation —
##   gameplay values must never be hardcoded (P1). Scans avatar_formulas.gd + the autoload.
##
## Part B (INV-5 / CF-4 parity): `BFCACHE_CONTINUE_THRESHOLD_MS` in avatar_renderer.gd MUST
##   equal the cross-system source of truth #15.Rule17
##   (src/core/loot_ttl_calc.gd::BFCACHE_CONTINUE_THRESHOLD_MS). A drift between the two is a
##   boot-correctness bug (a tab restored from bfcache would resume inconsistently).
##
## Exit codes: 0 = clean, 1 = violation (CI MUST fail), 2 = internal error.
## Governing: avatar-renderer.md CR-4 / INV-5 / AC-24, Story 017.
extends SceneTree

const LINT_TAG := "check_avatar_evolution_thresholds_data_driven"
const SCAN_FILES := [
	"res://src/autoload/avatar_renderer.gd",
	"res://src/core/avatar_formulas.gd",
]
const RENDERER := "res://src/autoload/avatar_renderer.gd"
const LOOT_TTL := "res://src/core/loot_ttl_calc.gd"
const PARITY_CONST := "BFCACHE_CONTINUE_THRESHOLD_MS"


func _init() -> void:
	var violations: Array[String] = []

	# Part A — no hardcoded numeric threshold table (>=3 int elements) in a tier .gd.
	var table_re := RegEx.new()
	if table_re.compile("\\[\\s*-?\\d+\\s*(,\\s*-?\\d+\\s*){2,}\\]") != OK:
		printerr("[%s] internal: regex compile failed" % LINT_TAG)
		quit(2)
		return
	for path: String in SCAN_FILES:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var i := 0
		while not file.eof_reached():
			var raw := file.get_line()
			i += 1
			if raw.strip_edges(true, false).begins_with("#"):
				continue
			if table_re.search(raw) != null:
				violations.append("%s:%d: hardcoded numeric threshold table FORBIDDEN — load from avatar_evolution_config.tres (CR-4/AC-24)" % [path, i])
		file.close()

	# Part B — BFCACHE_CONTINUE_THRESHOLD_MS parity (avatar == #15.Rule17).
	var avatar_v = _read_const_int(RENDERER, PARITY_CONST)
	var loot_v = _read_const_int(LOOT_TTL, PARITY_CONST)
	if avatar_v == null:
		violations.append("%s: %s not found (INV-5 parity anchor missing)" % [RENDERER, PARITY_CONST])
	elif loot_v == null:
		violations.append("%s: %s not found (INV-5 source-of-truth #15.Rule17 missing)" % [LOOT_TTL, PARITY_CONST])
	elif int(avatar_v) != int(loot_v):
		violations.append("INV-5 parity FAIL: %s=%d (avatar) != %d (#15 %s) — must match (AC-24/CF-4)" % [
			PARITY_CONST, int(avatar_v), int(loot_v), LOOT_TTL])

	if violations.is_empty():
		print("[%s] PASS: thresholds data-driven + %s parity (%s == #15.Rule17)" % [
			LINT_TAG, PARITY_CONST, str(avatar_v)])
		quit(0)
		return
	for v: String in violations:
		printerr(v)
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)


## Extract the integer value of `<name> ... = <int>` from a .gd file (first match,
## non-comment). Handles `:=`, `: int =`, `=`. Returns null when not found.
func _read_const_int(path: String, const_name: String):
	if not FileAccess.file_exists(path):
		return null
	var re := RegEx.new()
	re.compile("%s\\s*(:\\s*int\\s*)?:?=\\s*(-?\\d+)" % const_name)
	var file := FileAccess.open(path, FileAccess.READ)
	var result = null
	while not file.eof_reached():
		var raw := file.get_line()
		if raw.strip_edges(true, false).begins_with("#"):
			continue
		var m := re.search(raw)
		if m != null:
			result = int(m.get_string(2))
			break
	file.close()
	return result
