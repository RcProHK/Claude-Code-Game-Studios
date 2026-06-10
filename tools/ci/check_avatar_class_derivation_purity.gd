#!/usr/bin/env -S godot --headless --script
## CI Lint — class-derivation purity (CR-16 / CI-5 / AC-27).
##
## Invariant: Formula 1 `dominant_class` derives posture from ONLY the three #11 base stats
## (STR / DEX / VIT). It must NEVER reference a derived stat, ability count, loot, streak, or
## workout history — posture is an honest read of who the player physically is (P1/P4).
##
## Scan: the body of `dominant_class()` in src/core/avatar_formulas.gd (top-level func scope).
## Any forbidden domain token on a non-comment line inside that function is a violation.
##
## Exit codes: 0 = clean, 1 = violation (CI MUST fail), 2 = internal error.
## Governing: avatar-renderer.md CR-16 / AC-27, Story 017.
extends SceneTree

const LINT_TAG := "check_avatar_class_derivation_purity"
const FORMULAS := "res://src/core/avatar_formulas.gd"
const TARGET_FUNC := "dominant_class"

## Domain inputs forbidden inside the dominant_class body (case-insensitive). STR/DEX/VIT
## base-stat reads + sanitize_stat + class names are the only legal vocabulary.
const FORBIDDEN_TOKENS: Array[String] = [
	"ability", "loot", "streak", "workout", "equipment", "rarity",
	"get_unlocked", "cosmetic", "derived",
]


func _init() -> void:
	if not FileAccess.file_exists(FORMULAS):
		printerr("[%s] internal: %s not found" % [LINT_TAG, FORMULAS])
		quit(2)
		return

	var func_re := RegEx.new()
	func_re.compile("^(static\\s+)?func\\s+(\\w+)")

	var violations: Array[String] = []
	var in_target := false
	var file := FileAccess.open(FORMULAS, FileAccess.READ)
	var i := 0
	while not file.eof_reached():
		var raw := file.get_line()
		i += 1
		var fm := func_re.search(raw)
		if fm != null:
			in_target = fm.get_string(2) == TARGET_FUNC
			continue
		if not in_target:
			continue
		if raw.strip_edges(true, false).begins_with("#"):
			continue
		var lower := raw.to_lower()
		for tok: String in FORBIDDEN_TOKENS:
			if tok in lower:
				violations.append("%s:%d: forbidden token '%s' in %s() — class derivation must use ONLY #11 STR/DEX/VIT (CR-16/AC-27)" % [
					FORMULAS, i, tok, TARGET_FUNC])
	file.close()

	if violations.is_empty():
		print("[%s] PASS: %s() references only #11 base stats (CR-16)" % [LINT_TAG, TARGET_FUNC])
		quit(0)
		return
	for v: String in violations:
		printerr(v)
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)
