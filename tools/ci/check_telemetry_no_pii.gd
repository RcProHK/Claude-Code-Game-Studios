#!/usr/bin/env -S godot --headless --script
## CI Lint — Telemetry (#28) G-TEL-3 no-PII de-identification guard (AC-02, privacy 命脈).
##
## Purpose (GDD Rule 4 — de-identification):
##   Telemetry NEVER records raw body data. Body metrics are normalized at the SOURCE
##   (#9 WST / GymSys) into self-relative / bucketed forms before they ever reach
##   telemetry: PR is recorded as `pr_magnitude` ∈ [0, 2.0] (self-relative ratio),
##   volume as a completed-exercise COUNT, loot rarity as an enum. A raw absolute weight
##   (kg lifted), bodyweight, or absolute 1RM must NEVER appear in a telemetry payload —
##   this is the last static gate before data can leave the device.
##
## Scan target: telemetry source only —
##   res://src/autoload/telemetry.gd + res://src/telemetry/*.gd
##
## Forbidden field-name denylist (matched on CODE lines only — full-comment lines are
## skipped, so the doc comments that NAME these forbidden fields to explain the rule stay
## legal). Two forms are caught:
##   * a quoted dict key:      "weight_kg" / "one_rep_max" / …
##   * a bare field assign:    var bodyweight :=  /  bodyweight =  /  bodyweight:
##
## The normalized / de-identified values that telemetry DOES record are word-distinct from
## every denylist token, so they are not false-positives: pr_magnitude, rarity_tier,
## item_type, completed_exercises_count, volume_exercise_count, damage_dealt (an IN-GAME
## damage number, not a body metric), damage_tier, is_crit, dominant_class, progress.
##
## Exit codes: 0 = clean (de-identified); 1 = a raw body-data field found (CI MUST fail);
##   2 = internal error (no source / regex compile / unreadable).
extends SceneTree


const LINT_TAG: String = "check_telemetry_no_pii"
const AUTOLOAD: String = "res://src/autoload/telemetry.gd"
const SRC_DIR: String = "res://src/telemetry"

## Raw body-data field names that must never be serialized into a payload (Rule 4).
## Compound, unambiguous names only — never bare "kg" / "weight" (too broad). Joined into
## an alternation and matched both as a quoted dict key and as a bare assigned field.
const FORBIDDEN_FIELDS: Array[String] = [
	"weight_kg", "bodyweight", "body_weight", "body_mass",
	"one_rep_max", "raw_weight", "absolute_weight",
	"absolute_1rm", "raw_1rm", "set_weight",
	"kg_lifted", "lbs_lifted", "lift_kg",
]


func _init() -> void:
	var alt := "|".join(FORBIDDEN_FIELDS)
	# Quoted dict key:  "<field>"   ·   Bare assigned field:  <field> followed by := / = / :
	var re_quoted := _compile("\"(%s)\"" % alt)
	var re_bare := _compile("\\b(%s)\\b\\s*(:=|[:=])" % alt)
	if re_quoted == null or re_bare == null:
		quit(2)
		return

	var targets := _collect_targets()
	if targets.is_empty():
		push_error("[%s] no telemetry source found (expected %s + %s/*.gd)" % [LINT_TAG, AUTOLOAD, SRC_DIR])
		quit(2)
		return

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
			if stripped.begins_with("#") or stripped == "":
				continue
			var m := re_quoted.search(line)
			if m == null:
				m = re_bare.search(line)
			if m != null:
				violations.append({"path": path, "line": line_no, "snippet": stripped, "field": m.get_string(1)})
		file.close()

	if violations.is_empty():
		print("[%s] PASS: telemetry payloads carry only normalized / de-identified values — 0 raw body data (G-TEL-3 / Rule 4)" % LINT_TAG)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: raw body-data field '%s' FORBIDDEN in telemetry payload (G-TEL-3 / Rule 4 — de-identify at source)" % [v["path"], v["line"], v["field"]])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d raw body-data field(s). Record only normalized values (pr_magnitude / counts / enums)." % [LINT_TAG, violations.size()])
	quit(1)


func _compile(pattern: String) -> RegEx:
	var re := RegEx.new()
	if re.compile(pattern) != OK:
		push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
		return null
	return re


func _collect_targets() -> Array[String]:
	var out: Array[String] = []
	if FileAccess.file_exists(ProjectSettings.globalize_path(AUTOLOAD)):
		out.append(AUTOLOAD)
	var dir := DirAccess.open(SRC_DIR)
	if dir != null:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir() and name.ends_with(".gd"):
				out.append(SRC_DIR + "/" + name)
			name = dir.get_next()
		dir.list_dir_end()
	return out
