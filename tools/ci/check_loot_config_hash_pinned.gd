#!/usr/bin/env -S godot --headless --script
## CI Lint — LootRarityConfig.tres SHA must match the value pinned in entities.yaml (AC-29)
##
## AC-29 / Story 001: ADR-0005 locks the loot rarity formula constants at build
## time and forbids hot-swap. To detect tampering, the SHA-256 of
## `LootRarityConfig.tres` is PINNED in `design/registry/entities.yaml`; CI fails
## if the on-disk config drifts from the pinned digest. This makes any silent edit
## to the formula constants a hard build break.
##
## ── DETECTION STRATEGY (entities.yaml LINE-SCAN + SPLIT) ──────────────────────
## entities.yaml is large and the loot config lives in a deeply-nested block; a
## full YAML parse is unnecessary. We line-scan for the pin key and split on ':':
##
##     loot_rarity_config_sha256: "<64-hex>"
##
## The first matching line wins. We take everything after the first ':' , strip
## quotes / whitespace / inline `# comment`, lowercase it, and compare to the
## SHA-256 of the .tres bytes. A 64-hex token is expected; a `TBD` / empty / absent
## pin means "not yet pinned" (pre-Story-002) → EXIT 0.
##
## ── TARGET-ABSENCE POLICY (per Story 001 + user decision 3) ──────────────────
## EXIT 0 (clean) when EITHER side is absent:
##   * LootRarityConfig.tres does not exist (created in Story 002), OR
##   * entities.yaml has no `loot_rarity_config_sha256` pin yet, OR
##   * the pin value is empty / "TBD" (placeholder).
## EXIT 1 only when BOTH a real .tres and a real 64-hex pin exist AND they DIFFER.
## EXIT 2 is reserved for internal errors (entities.yaml itself missing/unreadable).
##
## Usage:
##   godot --headless --script tools/ci/check_loot_config_hash_pinned.gd
##
## Exit codes:
##   0 = SHA matches, OR config/pin not yet present (pre-Story-002)
##   1 = config exists AND pinned SHA exists AND they DIFFER (CI MUST fail)
##   2 = internal error (entities.yaml missing/unreadable, regex compile failure)
##
## Governing docs: design/gdd/loot-drop-system.md AC-29; ADR-0005 (config SHA
##   pinned, no hot-swap); story-001-ci-lints-closed-api.md.
extends SceneTree


const LINT_TAG: String = "check_loot_config_hash_pinned"
const REGISTRY_FILE: String = "res://design/registry/entities.yaml"
const CONFIG_FILE: String = "res://assets/data/loot/loot_rarity_config.tres"
const PIN_KEY: String = "loot_rarity_config_sha256"
## Values that mean "not pinned yet" — treated as pre-creation, EXIT 0.
const PLACEHOLDER_PINS: PackedStringArray = ["", "tbd", "todo", "pending", "0", "none"]


func _init() -> void:
	# entities.yaml is committed and must exist; its absence is an internal error.
	if not FileAccess.file_exists(REGISTRY_FILE):
		push_error("[%s] registry not found: %s — cannot verify pin" % [LINT_TAG, REGISTRY_FILE])
		quit(2)
		return

	var pinned := _read_pinned_sha()
	if pinned == "__ERROR__":
		quit(2)
		return

	# No real pin yet (pre-Story-002 or placeholder) → clean by definition.
	if _is_placeholder(pinned):
		print("[%s] PASS (no pin yet): `%s` absent/placeholder in entities.yaml — config not yet locked" % [LINT_TAG, PIN_KEY])
		quit(0)
		return

	# Pin exists but config file not yet created (Story 002) → clean.
	if not FileAccess.file_exists(CONFIG_FILE):
		print("[%s] PASS (config absent): %s not yet created — pin will activate when config lands" % [LINT_TAG, CONFIG_FILE])
		quit(0)
		return

	var actual := _sha256_of(CONFIG_FILE)
	if actual == "__ERROR__":
		quit(2)
		return

	if actual.to_lower() == pinned.to_lower():
		print("[%s] PASS: %s SHA-256 matches pin (%s…)" % [LINT_TAG, CONFIG_FILE, actual.substr(0, 12)])
		quit(0)
		return

	printerr("%s: SHA-256 drift — LootRarityConfig was modified without re-pinning (AC-29, ADR-0005 no hot-swap)" % CONFIG_FILE)
	printerr("  pinned (entities.yaml `%s`): %s" % [PIN_KEY, pinned])
	printerr("  actual (%s):                 %s" % [CONFIG_FILE, actual])
	printerr("  → If this change is intentional, update the pin in design/registry/entities.yaml.")
	printerr("")
	printerr("[%s] FAIL: config SHA does not match pinned value." % LINT_TAG)
	quit(1)


## Line-scan entities.yaml for the first `loot_rarity_config_sha256:` line and
## split out its value (quotes / inline-comment / whitespace stripped, lowercased).
## Returns "" when the key is absent; "__ERROR__" on read failure.
func _read_pinned_sha() -> String:
	var file := FileAccess.open(REGISTRY_FILE, FileAccess.READ)
	if file == null:
		push_error("[%s] cannot read registry: %s" % [LINT_TAG, REGISTRY_FILE])
		return "__ERROR__"
	var found := ""
	while not file.eof_reached():
		var line: String = file.get_line()
		var trimmed := line.strip_edges()
		# Skip YAML comment lines; the key must be a real mapping entry.
		if trimmed.begins_with("#"):
			continue
		if not trimmed.begins_with(PIN_KEY):
			continue
		# Ensure it's `key:` not `key_something:` — char after key must be ':' .
		var after := trimmed.substr(PIN_KEY.length())
		if not after.strip_edges(true, false).begins_with(":"):
			continue
		var colon := trimmed.find(":")
		if colon < 0:
			continue
		var value := trimmed.substr(colon + 1)
		found = _clean_value(value)
		break
	file.close()
	return found


## Strip surrounding quotes, an inline `# comment`, and whitespace; lowercase.
func _clean_value(raw: String) -> String:
	var v := raw.strip_edges()
	# Remove an inline comment that is NOT inside quotes (conservative: only strip
	# a trailing ` #...` when the value is unquoted).
	if not (v.begins_with("\"") or v.begins_with("'")):
		var hash_pos := v.find("#")
		if hash_pos >= 0:
			v = v.substr(0, hash_pos).strip_edges()
	# Strip matching surrounding quotes.
	if v.length() >= 2:
		if (v.begins_with("\"") and v.ends_with("\"")) or (v.begins_with("'") and v.ends_with("'")):
			v = v.substr(1, v.length() - 2)
	return v.strip_edges().to_lower()


func _is_placeholder(value: String) -> bool:
	return PLACEHOLDER_PINS.has(value.strip_edges().to_lower())


## SHA-256 hex digest of the file's raw bytes. "__ERROR__" on read failure.
func _sha256_of(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[%s] cannot read config: %s" % [LINT_TAG, path])
		return "__ERROR__"
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var ctx := HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		push_error("[%s] HashingContext.start failed" % LINT_TAG)
		return "__ERROR__"
	ctx.update(bytes)
	var digest := ctx.finish()
	return digest.hex_encode()
