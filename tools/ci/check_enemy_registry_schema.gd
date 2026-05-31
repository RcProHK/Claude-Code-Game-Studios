#!/usr/bin/env -S godot --headless --script
## CI Lint — EnemyRegistry.tres schema validation (Story 010 AC-17; TR-enemy-012).
##
## Purpose:
##   Validate that res://assets/data/EnemyRegistry.tres declares exactly the 3 wave
##   archetypes (STRIKE / CONTROL / MOBILITY), each WaveDescriptor sub-resource carries
##   all mandatory schema fields, faction == 1 (ENEMY) for every archetype, and
##   spawn_cadence_sec > 0 for every archetype. Keeps the data contract that Story 011
##   (wave scheduler) and Story 012 (spawn lifecycle) depend on from silently drifting.
##
## Scan target:
##   res://assets/data/EnemyRegistry.tres  (parsed as TEXT, not loaded as a Resource —
##   the lint runs headless without importing script/scene dependencies, matching
##   check_enemy_template_move_cap.gd).
##
## Detection:
##   - exactly 3 [sub_resource ...] WaveDescriptor blocks
##   - archetypes dict maps &"STRIKE" / &"CONTROL" / &"MOBILITY" to SubResource(...)
##   - each WaveDescriptor block contains every MANDATORY_FIELD
##   - every `faction = N` value == 1
##   - every `spawn_cadence_sec = N` value > 0
##
## Usage:
##   godot --headless --script tools/ci/check_enemy_registry_schema.gd
##
## Exit codes:
##   0 = schema valid (clean)
##   1 = schema violation (CI MUST fail)
##   2 = target file not found (forward-compat skip) or internal error
##
## Governing docs: design/gdd/enemy-director.md (Rule 12); TR-enemy-012;
##   Story 010 AC-17; ADR-0007 (faction ordinal).
extends SceneTree


const TARGET_FILE: String = "res://assets/data/EnemyRegistry.tres"
const LINT_TAG: String = "check_enemy_registry_schema"

## Archetype keys that MUST appear in the archetypes dict.
const REQUIRED_ARCHETYPES: Array[String] = ["STRIKE", "CONTROL", "MOBILITY"]

## Mandatory WaveDescriptor fields (AC-17). Presence-checked per sub-resource block.
const MANDATORY_FIELDS: Array[String] = [
	"enemy_templates",
	"spawn_cadence_sec",
	"archetype_cadence_mult",
	"spawn_count_per_set",
	"primary_outline_color",
	"faction",
	"max_hp",
	"defense",
	"_template_move_speed",
]

## Faction ordinal required for every enemy archetype (EnemyDirector.Faction.ENEMY).
const REQUIRED_FACTION: int = 1


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_warning("[%s] target not found: %s — forward-compat skip" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var lines: PackedStringArray = _read_lines(abs_path)
	if lines.is_empty():
		push_error("[%s] unreadable or empty: %s" % [LINT_TAG, TARGET_FILE])
		quit(2)
		return

	var violations: Array[String] = []

	# --- Split the file into [sub_resource] WaveDescriptor blocks. ---
	var blocks: Array[Dictionary] = _collect_sub_resource_blocks(lines)
	if blocks.size() != REQUIRED_ARCHETYPES.size():
		violations.append("expected %d WaveDescriptor sub_resource blocks, found %d" % [
			REQUIRED_ARCHETYPES.size(), blocks.size(),
		])

	# --- Per-block field presence + value validation. ---
	for block: Dictionary in blocks:
		var block_id: String = block["id"]
		var body: Array = block["lines"]
		for field: String in MANDATORY_FIELDS:
			if not _block_has_field(body, field):
				violations.append("sub_resource '%s' missing mandatory field: %s" % [block_id, field])
		# faction == 1
		var faction_val: Variant = _field_number(body, "faction")
		if faction_val != null and int(faction_val) != REQUIRED_FACTION:
			violations.append("sub_resource '%s' faction=%s (must be %d=ENEMY)" % [
				block_id, str(faction_val), REQUIRED_FACTION,
			])
		# spawn_cadence_sec > 0
		var cadence_val: Variant = _field_number(body, "spawn_cadence_sec")
		if cadence_val != null and float(cadence_val) <= 0.0:
			violations.append("sub_resource '%s' spawn_cadence_sec=%s (must be > 0)" % [
				block_id, str(cadence_val),
			])

	# --- archetypes dict key presence. ---
	var joined: String = "\n".join(lines)
	for archetype: String in REQUIRED_ARCHETYPES:
		var key_token: String = "&\"%s\"" % archetype
		if not joined.contains(key_token):
			violations.append("archetypes dict missing key: %s" % key_token)

	if violations.is_empty():
		print("[%s] PASS: %s — %d archetypes, all mandatory fields + faction/cadence valid" % [
			LINT_TAG, TARGET_FILE, blocks.size(),
		])
		quit(0)
		return

	for v: String in violations:
		printerr("%s: %s" % [TARGET_FILE, v])
	printerr("")
	printerr("[%s] FAIL: %d schema violation(s) (TR-enemy-012)." % [LINT_TAG, violations.size()])
	quit(1)


## Collect every [sub_resource ...] block as {id: String, lines: Array[String]}.
## A block runs from its [sub_resource] header to the next [section] header or EOF.
## NOTE: body lines use Array[String] (reference type), NOT PackedStringArray — packed
## arrays are value types, so appending via a Dictionary lookup would mutate a copy.
func _collect_sub_resource_blocks(lines: PackedStringArray) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var current_id: String = ""
	var current_lines: Array[String] = []
	var in_block: bool = false
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("[sub_resource"):
			if in_block:
				blocks.append({"id": current_id, "lines": current_lines})
			current_id = _extract_block_id(stripped)
			current_lines = []
			in_block = true
		elif stripped.begins_with("["):
			if in_block:
				blocks.append({"id": current_id, "lines": current_lines})
				current_lines = []
			in_block = false
		elif in_block:
			current_lines.append(line)
	if in_block:
		blocks.append({"id": current_id, "lines": current_lines})
	return blocks


## Extract the id="..." value from a [sub_resource ...] header line.
func _extract_block_id(header: String) -> String:
	var re := RegEx.new()
	if re.compile("id=\"([^\"]+)\"") != OK:
		return "?"
	var m := re.search(header)
	return m.get_string(1) if m != null else "?"


## True if any line in the block assigns `field = ...`.
func _block_has_field(body: Array, field: String) -> bool:
	for line: String in body:
		if line.strip_edges().begins_with("%s = " % field):
			return true
	return false


## Return the numeric value of `field = <number>` in the block, or null if absent/non-numeric.
func _field_number(body: Array, field: String) -> Variant:
	var re := RegEx.new()
	if re.compile("^%s\\s*=\\s*(-?[0-9]+(?:\\.[0-9]+)?)" % field) != OK:
		return null
	for line: String in body:
		var m := re.search(line.strip_edges())
		if m != null:
			return m.get_string(1).to_float()
	return null


func _read_lines(abs_path: String) -> PackedStringArray:
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines
