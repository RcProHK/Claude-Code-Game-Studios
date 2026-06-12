#!/usr/bin/env -S godot --headless --script
## CI Lint — Telemetry (#28) G-TEL-4 frozen-schema guard (AC-11 / EC-16, #15 FR-LOOT-3 binding).
##
## Purpose (GDD Rule 14 — frozen schema + version-on-change):
##   A versioned telemetry event's on-wire field set is FROZEN. `loot_dropped_v1` is the
##   exact 4-field set {drop_id, rarity_tier, item_type, transition_id} — the #15
##   FR-LOOT-3 contract. The backend pins this shape; changing it silently would corrupt
##   the historical series. Any field add/remove on a frozen event WITHOUT bumping
##   `schema_version` (e.g. → `loot_dropped_v2`) is a CI failure (EC-16). A bump is only
##   accepted once its new version is registered in the frozen table below.
##
## Scan target: res://src/autoload/telemetry.gd + res://src/telemetry/*.gd. For each
## `_record(&"<event>", …)` / `_record_dedup(&"<event>", …, schema_version)` whose event
## name is in FROZEN_SCHEMA, the payload dict keys and the schema_version integer are
## parsed (paren-balanced over the full call), then compared to the frozen field set.
##
## Data-driven (AC-2): adding an event_name → version → field-set entry below brings that
## event under the same frozen comparison.
##
## Exit codes: 0 = every frozen event matches its registered field set; 1 = drift without
##   a version bump, or an unregistered version (CI MUST fail); 2 = internal error.
extends SceneTree


const LINT_TAG: String = "check_telemetry_frozen_schema"
const AUTOLOAD: String = "res://src/autoload/telemetry.gd"
const SRC_DIR: String = "res://src/telemetry"

## Frozen registry: event_name → schema_version → exact field set (order-independent).
## loot_dropped_v1 = the #15 FR-LOOT-3 4-field contract (grep-verified vs shipped #15).
const FROZEN_SCHEMA: Dictionary = {
	"loot_dropped": {
		1: ["drop_id", "rarity_tier", "item_type", "transition_id"],
	},
}


func _init() -> void:
	# `(?:_record|_record_dedup)(  &"event"` — capture the frozen event name. Both the
	# 3-arg _record and the 4-arg _record_dedup put the StringName event first.
	var re_call := _compile("\\b_record(?:_dedup)?\\s*\\(\\s*&?\"(\\w+)\"")
	var re_key := _compile("\"(\\w+)\"\\s*:")
	var re_version := _compile("Priority\\.\\w+\\s*,\\s*(\\d+)\\s*\\)")
	if re_call == null or re_key == null or re_version == null:
		quit(2)
		return

	var targets := _collect_targets()
	if targets.is_empty():
		push_error("[%s] no telemetry source found (expected %s + %s/*.gd)" % [LINT_TAG, AUTOLOAD, SRC_DIR])
		quit(2)
		return

	var violations: Array[String] = []
	var checked: int = 0
	for path: String in targets:
		var text := _read_text(path)
		if text == "":
			continue
		for call_info: Dictionary in _extract_frozen_calls(text, re_call, re_key, re_version):
			checked += 1
			var problem := _check_call(call_info)
			if problem != "":
				violations.append("%s: %s" % [path, problem])

	if not violations.is_empty():
		for v: String in violations:
			printerr("[%s] %s" % [LINT_TAG, v])
		printerr("")
		printerr("[%s] FAIL: %d frozen-schema violation(s). Bump schema_version (loot_dropped_v2) and register the new field set; never mutate a frozen set in place (EC-16)." % [LINT_TAG, violations.size()])
		quit(1)
		return

	print("[%s] PASS: %d frozen event serialize point(s) match their registered field set (G-TEL-4 / Rule 14)" % [LINT_TAG, checked])
	quit(0)


## Compare one parsed serialize call against the frozen registry.
func _check_call(info: Dictionary) -> String:
	var event: String = info["event"]
	var version: int = info["version"]
	var keys: Array = info["keys"]
	var versions: Dictionary = FROZEN_SCHEMA[event]
	if not versions.has(version):
		return "%s serialized at unregistered schema_version %d — a frozen-set change must register the new version here" % [event, version]
	var frozen: Array = versions[version]
	var got := keys.duplicate()
	var want := frozen.duplicate()
	got.sort()
	want.sort()
	if got != want:
		return "%s_v%d field set drifted from frozen %s — got %s (EC-16: bump version, do not mutate in place)" % [event, version, str(want), str(got)]
	return ""


## Extract every frozen-event serialize call from source text. Returns
## [{event, version, keys:[...]}]. The call body is captured by paren-balancing from the
## opening `(` so a multi-line dict payload is fully spanned.
func _extract_frozen_calls(text: String, re_call: RegEx, re_key: RegEx, re_version: RegEx) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var search_from: int = 0
	while true:
		var m := re_call.search(text, search_from)
		if m == null:
			break
		var event: String = m.get_string(1)
		# The opening paren is the last `(` inside the matched prefix.
		var open_paren: int = text.rfind("(", m.get_end())
		if open_paren < 0:
			open_paren = m.get_end() - 1
		var close_paren: int = _match_paren(text, open_paren)
		search_from = m.get_end()
		if close_paren < 0:
			continue  # unbalanced (truncated source) — skip rather than miscount
		if not FROZEN_SCHEMA.has(event):
			continue
		var body: String = text.substr(open_paren + 1, close_paren - open_paren - 1)
		var keys: Array[String] = []
		for km: RegExMatch in re_key.search_all(body):
			keys.append(km.get_string(1))
		var version: int = 1  # _record default schema_version is 1 when not passed
		var vm := re_version.search(body)
		if vm != null:
			version = int(vm.get_string(1))
		out.append({"event": event, "version": version, "keys": keys})
	return out


## Index of the `)` matching the `(` at open_idx, or -1 if unbalanced. Quotes are tracked
## so a paren inside a string literal does not affect the depth.
func _match_paren(text: String, open_idx: int) -> int:
	var depth: int = 0
	var i: int = open_idx
	var in_str: bool = false
	var quote: String = ""
	while i < text.length():
		var c: String = text[i]
		if in_str:
			if c == "\\":
				i += 2
				continue
			if c == quote:
				in_str = false
		else:
			if c == "\"" or c == "'":
				in_str = true
				quote = c
			elif c == "(":
				depth += 1
			elif c == ")":
				depth -= 1
				if depth == 0:
					return i
		i += 1
	return -1


func _read_text(res_path: String) -> String:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


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
