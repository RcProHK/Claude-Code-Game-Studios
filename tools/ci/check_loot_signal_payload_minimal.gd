#!/usr/bin/env -S godot --headless --script
## CI Lint — `loot_dropped` signal payload must be minimal + intrinsic (AC-30, ADR-0009)
##
## AC-30 / Story 001: per ADR-0009 (minimal + intrinsic signal payloads), the
## `loot_dropped` signal carries exactly four primitive fields:
##   (drop_id: String, rarity_tier: int, item_type: int, transition_id: String)
## Listeners must NOT receive a full `LootDrop` resource — passing one leaks the
## whole mutable object across the signal seam (ADR-0009 anti-pattern: "never
## stuff ambient context / fat objects into signal payloads").
##
## ── DETECTION STRATEGY (file-level HEURISTIC, MVP precision) ──────────────────
## This is a HEURISTIC text check, NOT a type checker. It flags any
## `emit_signal("loot_dropped", ...)` site (single OR multi-line) whose argument
## list contains a token that looks like a fat object rather than a primitive:
##   * a `LootDrop`-typed local/identifier (token `LootDrop` or `_drop`/`drop`
##     passed whole, i.e. NOT a `.field` access),
##   * a `.duplicate(`/`.new(` constructor passed inline,
##   * more or fewer than the 4 expected comma-separated args.
## Because it is file-level + token-based, it can have false negatives
## (e.g. an aliased var holding a LootDrop). The runtime contract + the typed
## `signal loot_dropped(drop_id: String, ...)` declaration are the authoritative
## second line of defense; this lint is the cheap pre-Godot tripwire.
##
## We also assert the signal DECLARATION, when present, has a 4-typed-param
## signature — a fat-object declaration is flagged regardless of emit sites.
##
## Usage:
##   godot --headless --script tools/ci/check_loot_signal_payload_minimal.gd
##
## Exit codes:
##   0 = payload minimal (clean) — OR target file absent (pre-Story-009)
##   1 = a fat / wrong-arity loot_dropped payload found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## TARGET-ABSENCE POLICY: loot_drop_system.gd is created in Story 009. Missing
## target = EXIT 0 (Story 001 "non-fail when file absent").
##
## Governing docs: design/gdd/loot-drop-system.md AC-30; ADR-0009 (minimal payload);
##   story-001-ci-lints-closed-api.md.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const TARGET_FILE: String = "res://src/autoload/loot_drop_system.gd"
const LINT_TAG: String = "check_loot_signal_payload_minimal"
const EXPECTED_ARG_COUNT: int = 4
## Tokens that, when passed as a WHOLE argument (not `token.field`), indicate a fat
## object rather than a primitive. Conservative on purpose (HEURISTIC).
const FAT_ARG_TOKENS: PackedStringArray = ["LootDrop", "_drop", "drop", "payload", "loot"]
const FAT_ARG_INLINE_CONSTRUCTS: PackedStringArray = [".duplicate(", ".new(", "LootDrop.new("]


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	if not FileAccess.file_exists(TARGET_FILE):
		print("[%s] PASS (target absent): %s not yet created" % [LINT_TAG, TARGET_FILE])
		quit(0)
		return

	var re_emit := _compile("emit_signal\\s*\\(\\s*[\"']loot_dropped[\"']")
	var re_decl := _compile("^[ \\t]*signal[ \\t]+loot_dropped\\b")
	if re_emit == null or re_decl == null:
		quit(2)
		return

	var file := FileAccess.open(TARGET_FILE, FileAccess.READ)
	if file == null:
		push_error("[%s] cannot read: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	var violations: Array[Dictionary] = []

	# (a) Declaration check: signal loot_dropped(...) must have 4 typed params.
	for i: int in lines.size():
		var line: String = lines[i]
		if line.strip_edges(true, false).begins_with("#"):
			continue
		if re_decl.search(line) == null:
			continue
		var decl_args := _extract_arg_list(lines, i, re_decl)
		var arg_count := _count_args(decl_args)
		if arg_count != EXPECTED_ARG_COUNT:
			violations.append(_v(i, line.strip_edges(),
				"signal loot_dropped declares %d param(s); ADR-0009 requires exactly %d (drop_id, rarity_tier, item_type, transition_id)" % [arg_count, EXPECTED_ARG_COUNT]))

	# (b) Emit-site check: each emit_signal("loot_dropped", ...) arg list.
	for i: int in lines.size():
		var line: String = lines[i]
		if line.strip_edges(true, false).begins_with("#"):
			continue
		if re_emit.search(line) == null:
			continue
		var emit_args := _extract_arg_list(lines, i, re_emit)
		var reason := _fat_payload_reason(emit_args)
		if reason != "":
			violations.append(_v(i, line.strip_edges(), reason))

	if violations.is_empty():
		print("[%s] PASS: loot_dropped payload is minimal (4 primitive fields)" % LINT_TAG)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: %s" % [TARGET_FILE, v["line"], v["reason"]])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d payload violation(s). loot_dropped must carry only (drop_id, rarity_tier, item_type, transition_id) — never a full LootDrop (AC-30, ADR-0009)." % [LINT_TAG, violations.size()])
	quit(1)


## Collect the parenthesised argument text starting at the line where `opener_re`
## matches, joining following lines until parens balance. Returns the text BETWEEN
## the outermost ( ) of the matched call (the arg list only).
func _extract_arg_list(lines: PackedStringArray, start_index: int, opener_re: RegEx) -> String:
	var m := opener_re.search(lines[start_index])
	if m == null:
		return ""
	# Find the first '(' at or after the match end on the start line.
	var joined := ""
	var depth := 0
	var capturing := false
	var collected := ""
	for i: int in range(start_index, lines.size()):
		var text: String = lines[i]
		var begin_col := 0
		if i == start_index:
			begin_col = m.get_start()
		for c: int in range(begin_col, text.length()):
			var ch := text[c]
			if ch == "(":
				depth += 1
				if depth == 1:
					capturing = true
					continue  # skip the outermost '('
			elif ch == ")":
				depth -= 1
				if depth == 0:
					return collected
			if capturing and depth >= 1:
				collected += ch
		collected += " "  # line break becomes a separator
		joined += text
	return collected


## Count top-level comma-separated args (depth-aware so nested calls/arrays count
## as one arg). The signal NAME for emit_signal is the first arg and is excluded
## by the caller via _fat_payload_reason; for declarations there is no name arg.
func _count_args(arg_text: String) -> int:
	var trimmed := arg_text.strip_edges()
	if trimmed.is_empty():
		return 0
	var args := _split_top_level(trimmed)
	return args.size()


## Split a parenthesised argument string on top-level commas (ignoring commas
## inside nested (), [], {}). Returns trimmed pieces.
func _split_top_level(arg_text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var depth := 0
	var current := ""
	for c: int in arg_text.length():
		var ch := arg_text[c]
		if ch == "(" or ch == "[" or ch == "{":
			depth += 1
		elif ch == ")" or ch == "]" or ch == "}":
			depth -= 1
		if ch == "," and depth == 0:
			out.append(current.strip_edges())
			current = ""
		else:
			current += ch
	if not current.strip_edges().is_empty():
		out.append(current.strip_edges())
	return out


## For an emit_signal arg list, the first arg is the signal name string. The
## REMAINING args are the payload. Returns a non-empty reason if the payload is
## fat / wrong-arity, else "".
func _fat_payload_reason(emit_arg_text: String) -> String:
	var all_args := _split_top_level(emit_arg_text.strip_edges())
	if all_args.is_empty():
		return ""  # malformed; let the declaration check / compiler handle it
	# Drop the first arg (the "loot_dropped" name literal).
	var payload: PackedStringArray = all_args.slice(1)
	if payload.size() != EXPECTED_ARG_COUNT:
		return "emit_signal(\"loot_dropped\") passes %d payload arg(s); ADR-0009 requires exactly %d primitives" % [payload.size(), EXPECTED_ARG_COUNT]
	for arg: String in payload:
		var a := arg.strip_edges()
		# Inline constructor passed whole → fat object.
		for frag: String in FAT_ARG_INLINE_CONSTRUCTS:
			if a.contains(frag):
				return "emit_signal(\"loot_dropped\") payload arg `%s` constructs/duplicates an object inline — pass primitive fields only" % a
		# A bare fat-object identifier (NOT a `.field` access) → suspect.
		if not a.contains("."):
			for tok: String in FAT_ARG_TOKENS:
				if a == tok or a == "_" + tok:
					return "emit_signal(\"loot_dropped\") payload arg `%s` looks like a whole object — pass `%s.<field>` primitives instead" % [a, a]
	return ""


func _compile(pattern: String) -> RegEx:
	var re := RegEx.new()
	if re.compile(pattern) != OK:
		push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
		return null
	return re


func _v(line_index: int, snippet: String, reason: String) -> Dictionary:
	return {"line": line_index + 1, "snippet": snippet, "reason": reason}
