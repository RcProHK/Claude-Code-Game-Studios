#!/usr/bin/env -S godot --headless --script
## CI Lint — Onboarding (#27) G-OB-2 no-gameplay-mutator guard (AC-15, Pillar 1 命脈).
##
## Purpose (GDD Rule 5 / Rule 6 / Rule 8):
##   Onboarding is a pure downstream observe-only consumer. It must NEVER mutate gameplay
##   state: no persistence write to a gameplay namespace (loot.* / stat.* / ability.* /
##   streak.* — only onboarding.* is legal), no #15 daily-claim / drop-generation, no
##   #11/#12 stat/ability mutators. The "first item" must be a REAL #15 daily drop the
##   player earned — onboarding scripting / fabricating it would destroy the Pillar 1 trust.
##
## Scan target: onboarding source only —
##   res://src/autoload/onboarding_coordinator.gd + res://src/ui/onboarding/*.gd
##   (onboarding owns no seam, so no owner-exemption is needed — it is a pure consumer.)
##
## Forbidden patterns (matched on CODE lines only — full-comment lines are skipped, so the
## doc comments that *describe* these forbidden calls stay legal):
##   "(loot|stat|ability|streak)\.   a string literal in a gameplay persistence namespace
##   claim[_-]daily                  the #15 daily-claim API (method or path)
##   \b(set_stat|unlock_ability|grant_ability|generate_drop|spawn_loot|claim_drop)\s*\(
##                                   a #11/#12/#15 gameplay mutator call
##
## Exit codes: 0 = clean (observe-only); 1 = a gameplay mutator found (CI MUST fail);
##   2 = internal error (no source found / regex compile / unreadable).
extends SceneTree


const LINT_TAG: String = "check_onboarding_no_gameplay_mutator"
const COORDINATOR: String = "res://src/autoload/onboarding_coordinator.gd"
const UI_DIR: String = "res://src/ui/onboarding"

const FORBIDDEN_PATTERNS: Array[String] = [
	"\"(loot|stat|ability|streak)\\.",
	"claim[_-]daily",
	"\\b(set_stat|unlock_ability|grant_ability|generate_drop|spawn_loot|claim_drop)\\s*\\(",
]


func _init() -> void:
	var targets := _collect_targets()
	if targets.is_empty():
		push_error("[%s] no onboarding source found (expected %s + %s/*.gd)" % [LINT_TAG, COORDINATOR, UI_DIR])
		quit(2)
		return

	var regexes: Array[RegEx] = []
	for pat: String in FORBIDDEN_PATTERNS:
		var re := RegEx.new()
		if re.compile(pat) != OK:
			push_error("[%s] regex compile failed: %s" % [LINT_TAG, pat])
			quit(2)
			return
		regexes.append(re)

	var violations: Array[Dictionary] = []
	for path: String in targets:
		var abs_path: String = ProjectSettings.globalize_path(path)
		var file := FileAccess.open(abs_path, FileAccess.READ)
		if file == null:
			push_error("[%s] unreadable: %s" % [LINT_TAG, path])
			quit(2)
			return
		var line_no: int = 0
		while not file.eof_reached():
			var line: String = file.get_line()
			line_no += 1
			var stripped: String = line.strip_edges()
			# Skip full-comment lines and blanks (doc comments describe the forbidden calls).
			if stripped.begins_with("#") or stripped == "":
				continue
			for re: RegEx in regexes:
				var m := re.search(line)
				if m != null:
					violations.append({"path": path, "line": line_no, "snippet": stripped})
					break
		file.close()

	if violations.is_empty():
		print("[%s] PASS: onboarding source is observe-only — 0 gameplay mutators (G-OB-2 / Pillar 1)" % LINT_TAG)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: gameplay mutator FORBIDDEN in onboarding (G-OB-2 / Pillar 1 — observe-only)" % [v["path"], v["line"]])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d gameplay mutator(s). Onboarding must never mutate gameplay (Rule 5/6/8)." % [LINT_TAG, violations.size()])
	quit(1)


## Onboarding coordinator + every helper under src/ui/onboarding/.
func _collect_targets() -> Array[String]:
	var out: Array[String] = []
	if FileAccess.file_exists(ProjectSettings.globalize_path(COORDINATOR)):
		out.append(COORDINATOR)
	var dir := DirAccess.open(UI_DIR)
	if dir != null:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir() and name.ends_with(".gd"):
				out.append(UI_DIR + "/" + name)
			name = dir.get_next()
		dir.list_dir_end()
	return out
