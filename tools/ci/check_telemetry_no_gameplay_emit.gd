#!/usr/bin/env -S godot --headless --script
## CI Lint — Telemetry (#28) G-TEL-2 no-gameplay-emit guard (AC-01, Pillar 2 命脈).
##
## Purpose (GDD Rule 1 — pure passive observer):
##   Telemetry subscribes to upstream gameplay signals, translates each into a buffered
##   de-identified event, and flushes to the backend. It emits ZERO gameplay signals,
##   calls ZERO upstream mutators, and writes to ZERO gameplay persistence namespace.
##   If telemetry could feed back into gameplay it would stop being an OBSERVER and
##   become an actor — the Pillar 2 (telemetry is invisible & inert) trust is destroyed.
##
## Scan target: telemetry source only —
##   res://src/autoload/telemetry.gd + res://src/telemetry/*.gd
##
## Three forbidden categories (matched on CODE lines only — full-comment lines are
## skipped, so the doc comments that *describe* these forbidden calls stay legal):
##   1. SIGNAL EMIT of anything that is NOT a telemetry-owned diagnostic meta.
##      `emit_signal("X"` / `emit_signal(&"X"` / `X.emit(` — the signal name X is
##      extracted; if X is in OWNED_META it is EXEMPT (telemetry may surface its own
##      diagnostic meta), otherwise it is a forbidden gameplay emit. Telemetry currently
##      records its meta via the buffer (`_record(&"telemetry_self_error", …)`), not via
##      signals, so clean source has ZERO emits — the exemption is a forward guard so a
##      future telemetry-owned diagnostic SIGNAL is not misread as a gameplay emit (AC-2).
##   2. GAMEPLAY PERSISTENCE NAMESPACE write — a string literal key in loot.* / stat.* /
##      ability.* / streak.* (only a telemetry-owned namespace would be legal).
##   3. GAMEPLAY MUTATOR method call — a known #11/#12/#15/#1/#9 state-mutating method.
##
## Exit codes: 0 = clean (observe-only); 1 = a gameplay emit / mutator / namespace write
##   found (CI MUST fail); 2 = internal error (no source / regex compile / unreadable).
extends SceneTree


const LINT_TAG: String = "check_telemetry_no_gameplay_emit"
const AUTOLOAD: String = "res://src/autoload/telemetry.gd"
const SRC_DIR: String = "res://src/telemetry"

## Telemetry-owned diagnostic meta — these may be surfaced by telemetry itself and are
## NOT gameplay signals. Kept in sync with the meta events telemetry records (Rule 15 /
## EC-03). A future telemetry-owned diagnostic signal must be added here (same discipline
## as the onboarding / mirror-moment owner-exempt allowlists).
const OWNED_META: Array[String] = [
	"telemetry_self_error",
	"duplicate_transition_observed",
	"out_of_order_observed",
	"dropped_count",
]

## A gameplay-namespace persistence write or a gameplay-state mutator. NONE of these may
## appear in telemetry source. (Read / subscribe methods — has_signal, is_connected,
## connect, connect_for_initial_state, has_method — are deliberately NOT here: a pure
## observer legally SUBSCRIBES to upstream signals.)
const NAMESPACE_WRITE_PATTERN: String = "\"(loot|stat|ability|streak)\\."
const MUTATOR_PATTERN: String = "\\b(set_stat|apply_stat_delta|unlock_ability|grant_ability|cast_ability|generate_drop|spawn_loot|claim_drop|claim_daily|force_transition|request_transition|start_workout|complete_workout)\\s*\\("

## Two signal-emit forms. Group 1 = the emitted signal name (for OWNED_META exemption).
const EMIT_SIGNAL_PATTERN: String = "\\bemit_signal\\s*\\(\\s*&?\"(\\w+)\""
const DOT_EMIT_PATTERN: String = "\\b(\\w+)\\.emit\\s*\\("


func _init() -> void:
	var targets := _collect_targets()
	if targets.is_empty():
		push_error("[%s] no telemetry source found (expected %s + %s/*.gd)" % [LINT_TAG, AUTOLOAD, SRC_DIR])
		quit(2)
		return

	var re_namespace := _compile(NAMESPACE_WRITE_PATTERN)
	var re_mutator := _compile(MUTATOR_PATTERN)
	var re_emit_signal := _compile(EMIT_SIGNAL_PATTERN)
	var re_dot_emit := _compile(DOT_EMIT_PATTERN)
	if re_namespace == null or re_mutator == null or re_emit_signal == null or re_dot_emit == null:
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
			var reason: String = _classify(line, re_namespace, re_mutator, re_emit_signal, re_dot_emit)
			if reason != "":
				violations.append({"path": path, "line": line_no, "snippet": stripped, "reason": reason})
		file.close()

	if violations.is_empty():
		print("[%s] PASS: telemetry source is a pure observer — 0 gameplay emits / mutators / namespace writes (G-TEL-2 / Pillar 2)" % LINT_TAG)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: %s FORBIDDEN in telemetry (G-TEL-2 / Pillar 1+2 — observe-only)" % [v["path"], v["line"], v["reason"]])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d violation(s). Telemetry must never emit/mutate gameplay (Rule 1)." % [LINT_TAG, violations.size()])
	quit(1)


## Classify a code line; "" = clean, else a short reason string. An emit of a
## telemetry-owned meta signal is EXEMPT.
func _classify(line: String, re_namespace: RegEx, re_mutator: RegEx,
		re_emit_signal: RegEx, re_dot_emit: RegEx) -> String:
	if re_namespace.search(line) != null:
		return "gameplay persistence namespace write (loot.*/stat.*/ability.*/streak.*)"
	if re_mutator.search(line) != null:
		return "gameplay mutator call"
	var m := re_emit_signal.search(line)
	if m != null and not OWNED_META.has(m.get_string(1)):
		return "gameplay signal emit ('%s')" % m.get_string(1)
	var d := re_dot_emit.search(line)
	if d != null and not OWNED_META.has(d.get_string(1)):
		return "gameplay signal emit ('%s.emit')" % d.get_string(1)
	return ""


func _compile(pattern: String) -> RegEx:
	var re := RegEx.new()
	if re.compile(pattern) != OK:
		push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
		return null
	return re


## The telemetry autoload + every helper under src/telemetry/.
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
