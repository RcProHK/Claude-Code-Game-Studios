#!/usr/bin/env -S godot --headless --script
## CI Lint — EnemyDirector damage chokepoint enforcement (GDD Rule, Story 002 AC-03).
##
## Purpose:
##   All damage computation MUST flow through `CombatResolver.resolve_hit()`.
##   Inline arithmetic resembling damage math (e.g. `caster.attack_power * 1.5`,
##   `target.hp -= damage`) bypasses the #13 stateless resolver chokepoint and is
##   FORBIDDEN inside EnemyDirector.
##
## Scan target:
##   res://src/autoload/enemy_director.gd  (this single file ONLY — not all of src/).
##
## Forbidden patterns (regex):
##   attack_power\s*\*   — inline attack-power multiplication
##   \.hp\s*-=           — direct HP decrement
##   \.hp\s*\+=          — direct HP increment
##   \.defense\s*-=      — direct defense decrement
##   target\.hp\s*=      — direct HP assignment
##
## Usage:
##   godot --headless --script tools/ci/check_enemy_director_chokepoint.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (target file missing, regex compile failure, unreadable)
##
## Governing docs: design/gdd/enemy-director.md (damage chokepoint Rule);
##   ADR-0009 (#13 CombatResolver as sole damage authority); Story 002 AC-03.
extends SceneTree


const TARGET_FILE: String = "res://src/autoload/enemy_director.gd"

## Forbidden inline-damage-math patterns. Order is not significant.
const FORBIDDEN_PATTERNS: Array[String] = [
	"attack_power\\s*\\*",
	"\\.hp\\s*-=",
	"\\.hp\\s*\\+=",
	"\\.defense\\s*-=",
	"target\\.hp\\s*=",
]


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_error("[check_enemy_director_chokepoint] target not found: %s" % TARGET_FILE)
		quit(2)
		return

	var compiled: Array[RegEx] = []
	for pattern: String in FORBIDDEN_PATTERNS:
		var re := RegEx.new()
		if re.compile(pattern) != OK:
			push_error("[check_enemy_director_chokepoint] regex compile failed: %s" % pattern)
			quit(2)
			return
		compiled.append(re)

	var lines: PackedStringArray = _read_lines(abs_path)
	if lines.is_empty():
		push_error("[check_enemy_director_chokepoint] unreadable or empty: %s" % TARGET_FILE)
		quit(2)
		return

	var violations: Array[Dictionary] = []
	for i: int in lines.size():
		var line: String = lines[i]
		if _is_comment_line(line):
			continue
		for j: int in compiled.size():
			var m := compiled[j].search(line)
			if m != null:
				violations.append({
					"line": i + 1,
					"col": m.get_start() + 1,
					"pattern": FORBIDDEN_PATTERNS[j],
					"snippet": line.strip_edges(),
				})

	if violations.is_empty():
		print("[check_enemy_director_chokepoint] PASS: %s — 0 inline-damage-math violations" % TARGET_FILE)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: inline damage math FORBIDDEN — use CombatResolver.resolve_hit() (pattern: %s)" % [
			TARGET_FILE, v["line"], v["col"], v["pattern"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_enemy_director_chokepoint] FAIL: %d violation(s)." % violations.size())
	quit(1)


func _read_lines(abs_path: String) -> PackedStringArray:
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines


func _is_comment_line(line: String) -> bool:
	return line.strip_edges(true, false).begins_with("#")
