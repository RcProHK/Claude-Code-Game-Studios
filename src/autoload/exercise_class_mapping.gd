## ExerciseClassMapping — Autoload #10, position 5 (ADR-0008).
##
## Governing story : #10 Story 001 (Registry schema + core exercise lookup)
## GDD             : design/gdd/exercise-class-mapping.md (Approved 2026-06-02)
## Governing ADRs  : ADR-0007 (AbilityClass Classification enum — zero-default FORBIDDEN),
##                   ADR-0008 (Autoload position 5 — after GymSys pos 4, before StatSystem pos 6),
##                   ADR-0003 (no per-player persistence — static config, read-only)
##
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## PURPOSE
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## Canonical data layer for Pillar 4 「Muscle = Class」 — maps gym exercise ids to
## RPG ability class ordinals {STRIKE=0, CONTROL=1, MOBILITY=2, UNKNOWN=3}.
## Exposes two INDEPENDENT entry points (GDD Formula 1a / 1b); they never call each other.
## Pure lookup: no mutation, no persistence, no GSM subscription.
##
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## ⚠️ BOOT-ORDER GUARD — DO NOT import AbilitySystem.AbilityClass here
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## This autoload is at position 5; AbilitySystem is at position 6 (ADR-0008).
## Referencing AbilitySystem.AbilityClass.* here would crash at boot (singleton not yet
## initialised). Instead we use private int-literal constants with doc-comments that name
## the corresponding AbilityClass member. Consumers call AbilitySystem.AbilityClass.*
## normally; we just return the int ordinal they expect.
##
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## Story ownership map (expansion hooks — do NOT implement without the owning story)
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## Story 002: get_class_for_movement_pattern() + MovementPattern enum + _pattern_map
## Story 003: full boot validation (sentinel / ordinal / dup / authored-UNKNOWN push_error branches)
## Story 004: alias resolution path (_canonical_by_alias lookup) + is_known_exercise()
## Story 005: project.godot autoload registration at pos 5 + CI mutator-ban lint
extends Node

# ── AbilitySystem.AbilityClass ordinal constants (boot-order safe) ───────────
# These mirror AbilitySystem.AbilityClass exactly: STRIKE=0, CONTROL=1, MOBILITY=2, UNKNOWN=3.
# We use private constants to avoid redeclaring STRIKE|CONTROL|MOBILITY enum members,
# which would be a CI error (control-manifest.md line 93).
const _ABILITY_STRIKE: int = 0    ## AbilitySystem.AbilityClass.STRIKE
const _ABILITY_CONTROL: int = 1   ## AbilitySystem.AbilityClass.CONTROL
const _ABILITY_MOBILITY: int = 2  ## AbilitySystem.AbilityClass.MOBILITY
const _ABILITY_UNKNOWN: int = 3   ## AbilitySystem.AbilityClass.UNKNOWN (anti-fabrication sentinel)

# ── MovementPattern Classification enum (GDD Rule 4 / 4b; ADR-0007) ──────────
## A NEW Classification-family enum owned by #10 — distinct TYPE from AbilityClass.
## Declaration order is LOAD-BEARING (ADR-0007): the first three ordinals 0/1/2
## deliberately align 1:1:1 with AbilityClass {STRIKE,CONTROL,MOBILITY} and with
## target_stat (the Pillar 4 "Muscle = Class" spine), but this is a DISTINCT type —
## never conflate it with AbilityClass. UNKNOWN_PATTERN is the sentinel and MUST stay
## last (zero-default fabrication FORBIDDEN — an unset field never silently becomes PUSH).
## `LEG` is singular to match entities.yaml. Embedded here (not a shared `class_name`
## file) so the script stays headless-GUT safe and avoids the autoload/class_name
## collision Story 005 would hit at registration; full 7-member entities.yaml
## registration is a separate cross-system gate (systems-designer), not this story.
enum MovementPattern {
	PUSH = 0,             ## → STRIKE   (spine row 1)
	PULL = 1,             ## → CONTROL  (spine row 2)
	LEG = 2,              ## → MOBILITY (spine row 3)
	CORE = 3,            ## non-spine → UNKNOWN (consumer must use registry id-lookup)
	CARDIO = 4,          ## non-spine → UNKNOWN
	FLEXIBILITY = 5,     ## non-spine → UNKNOWN
	COMPOUND = 6,        ## non-spine → UNKNOWN (compound MUST have an explicit registry entry)
	UNKNOWN_PATTERN = 7, ## sentinel (declaration order: MUST stay last)
}

# ── Registry resource path ───────────────────────────────────────────────────
const _REGISTRY_PATH: String = "res://assets/data/exercise_registry.tres"

# ── Internal state ──────────────────────────────────────────────────────────
## FAILED state: true when registry is missing/corrupt. All lookups return UNKNOWN safely.
var _failed: bool = false

## Test seam (AC-06): when set to a valid Callable, _load_registry() delegates to it instead
## of touching the filesystem. Lets a headless test force the FAILED path (return null) without
## a .tres on disk. Production leaves this unset. Set it BEFORE the node enters the tree.
var _registry_loader_override: Callable = Callable()

## Runtime lookup: normalized exercise_id (String) → AbilityClass ordinal (int).
## Built from ExerciseRegistry.entries at boot. Read-only after _build_lookup().
var _class_by_id: Dictionary = {}

## Runtime lookup: normalized alias String → canonical normalized exercise_id String.
## Populated by alias resolution (Story 004 — scaffold only, empty at Story 001).
## ⚠️ EXPANSION HOOK (Story 004): _build_lookup() must populate this dict from
##   ExerciseEntry.aliases, applying _normalize() to each alias, with first-listed
##   canonical winning on collision (ADR-0007 no-fabrication + AC-15).
var _canonical_by_alias: Dictionary = {}


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	var raw_resource: Resource = _load_registry()
	if raw_resource == null:
		_failed = true
		push_error("ExerciseClassMapping: registry missing or corrupt at '%s' — all lookups will return UNKNOWN" % _REGISTRY_PATH)
		return

	# ExerciseRegistry.entries is Array[ExerciseEntry]
	var registry: ExerciseRegistry = raw_resource as ExerciseRegistry
	if registry == null:
		_failed = true
		push_error("ExerciseClassMapping: loaded resource is not an ExerciseRegistry — all lookups will return UNKNOWN")
		return

	_validate_and_build(registry.entries)


# ── Public API ───────────────────────────────────────────────────────────────

## Formula 1a — exercise_id lookup (GDD Rule 5, two independent entry points).
##
## Returns AbilitySystem.AbilityClass ordinal (int):
##   0=STRIKE, 1=CONTROL, 2=MOBILITY, 3=UNKNOWN
##
## Steps: normalize input → resolve canonical (direct id OR alias) → return ability_class.
##        No movement_pattern fallback (GDD Rule 5: two entry points independent).
##        Miss / empty / FAILED → UNKNOWN(3) (GDD Rule 6: no fabrication).
func get_class_for_exercise(exercise_id: StringName) -> int:
	if _failed:
		return _ABILITY_UNKNOWN

	var normalized: String = _normalize(exercise_id)

	if normalized.is_empty():
		# AC-11: empty input can never match a registry entry. Warn once (not an error — a caller
		# passing "" is recoverable) and return UNKNOWN without crashing.
		push_warning("ExerciseClassMapping: empty exercise_id — returning UNKNOWN")
		return _ABILITY_UNKNOWN

	# AC-05/05b: _resolve_canonical follows the alias table (normalize already applied), so a
	# title-case / spaced alias resolves the same as the canonical id.
	var canonical: String = _resolve_canonical(normalized)
	if canonical.is_empty():
		return _ABILITY_UNKNOWN
	return _class_by_id[canonical]


## Returns true if exercise_id resolves to a known registry entry (directly or via an alias).
##
## Shares the exact _normalize + _resolve_canonical path with get_class_for_exercise() — they
## must never diverge (Control Manifest: same resolution path). Empty input → false WITHOUT a
## push_warning (AC-14d): warning ownership belongs to get_class_for_exercise per AC-11.
## FAILED state → false (nothing is known when the registry never loaded).
func is_known_exercise(exercise_id: StringName) -> bool:
	if _failed:
		return false
	var normalized: String = _normalize(exercise_id)
	if normalized.is_empty():
		return false
	return not _resolve_canonical(normalized).is_empty()


## Resolve a normalized id to its canonical registry key, following the alias table.
## Returns the canonical normalized id (found directly in _class_by_id, or via _canonical_by_alias)
## or "" when nothing matches. The single source of truth for id↔alias resolution so that
## get_class_for_exercise() and is_known_exercise() can never disagree.
## ⚠️ Private contract: consumers MUST call get_class_for_exercise() / is_known_exercise(),
##   never this directly — those entry points own the FAILED guard, normalize, and empty/warn.
func _resolve_canonical(normalized: String) -> String:
	if _class_by_id.has(normalized):
		return normalized
	if _canonical_by_alias.has(normalized):
		var canonical: String = _canonical_by_alias[normalized]
		if _class_by_id.has(canonical):
			return canonical
	return ""

## Formula 1b — movement_pattern lookup (GDD Rule 4b / 5).
##
## Independent entry point: maps a MovementPattern ordinal to an AbilitySystem.AbilityClass
## ordinal via the 1:1:1 spine. Does NOT call get_class_for_exercise() — the two entry
## points never fall back to each other (GDD Rule 5).
##
## Spine (the only mapped rows):
##   PUSH(0) → STRIKE(0), PULL(1) → CONTROL(1), LEG(2) → MOBILITY(2)
##
## Everything else — CORE(3)/CARDIO(4)/FLEXIBILITY(5)/COMPOUND(6)/UNKNOWN_PATTERN(7),
## plus any out-of-range int (negative, >7, MAX_INT) — returns UNKNOWN(3). No fabrication
## (GDD Rule 6): we never guess a class for a non-spine pattern. COMPOUND in particular is
## intentionally unmapped — compound exercises must carry an explicit registry entry and be
## resolved through get_class_for_exercise(), not this pattern API.
##
## Implemented with `match` rather than a `const Dictionary`: GDScript `const Dictionary`
## is not truly immutable, whereas a literal `match` cannot be mutated and reads cleaner.
func get_class_for_movement_pattern(pattern: int) -> int:
	match pattern:
		MovementPattern.PUSH:
			return _ABILITY_STRIKE
		MovementPattern.PULL:
			return _ABILITY_CONTROL
		MovementPattern.LEG:
			return _ABILITY_MOBILITY
		_:
			return _ABILITY_UNKNOWN


# ── Factory (GUT test entry point) ──────────────────────────────────────────

## Test factory — bypasses _load_registry() and class_name resolution entirely.
##
## Accepts Array[Dictionary] directly — zero ExerciseEntry.new() instantiation,
## zero class_name cache dependency → headless GUT safe (CI green without Godot import).
##
## Each dict must have: exercise_id (String), ability_class (int), movement_pattern (int).
## Optional: muscle_group (String), aliases (Array[String]).
##
## Runs the same _validate_and_build() path as _ready() — boot validation is tested
## through this factory (coding-standards: fixtures use factory functions, same code path).
func _create_test_registry(entries: Array) -> void:
	_failed = false
	_class_by_id = {}
	_canonical_by_alias = {}
	_validate_and_build(entries)


# ── Private helpers ──────────────────────────────────────────────────────────

## Normalize an exercise id or alias to a canonical lookup key.
##
## Step 1: String(raw) — force StringName→String cast.
##   GDScript 4.x Dictionary: &"bench_press" != "bench_press" as dict key.
##   Without this cast, StringName input silently misses all String-keyed lookups.
## Step 2: to_lower().strip_edges() — case-fold + trim leading/trailing whitespace.
## Step 3: collapse consecutive whitespace/underscores to a single underscore.
##
## Both get_class_for_exercise() and is_known_exercise() call this first.
func _normalize(raw: Variant) -> String:
	var s: String = String(raw)  # Force StringName → String cast (GDScript 4.x StringName dict key issue)
	s = s.to_lower().strip_edges()
	# Collapse consecutive spaces to single underscore, then collapse repeated underscores.
	# Example: "BENCH  PRESS" → "bench  press" → "bench__press" (after join) → "bench_press"
	var parts: PackedStringArray = s.split(" ", false)  # false = skip empty strings
	s = "_".join(parts)
	# Collapse consecutive underscores (handles "Bench_Press" → "bench_press" already OK,
	# and edge case "bench__press" from double-underscore input).
	while s.contains("__"):
		s = s.replace("__", "_")
	return s


## Shared build path — called by both _ready() and _create_test_registry().
## Accepts either Array[ExerciseEntry] (production) or Array[Dictionary] (test factory).
## Both go through the same _validate_entries() + _build_lookup() sequence.
func _validate_and_build(rows: Array) -> void:
	var validated: Array = _validate_entries(rows)
	_build_lookup(validated)


## Boot validation loop (Story 003) — GDD Rule 3. Shared by _ready() and the test factory.
## Returns validated rows with coerced ability_class / movement_pattern values. Per ADR-0007
## (zero-default fabrication FORBIDDEN), an unset/invalid Classification field is detected and
## forced to its sentinel rather than silently passing through as ordinal 0.
func _validate_entries(rows: Array) -> Array:
	var validated: Array = []
	for row in rows:
		var entry: Dictionary = _row_to_dict(row)
		var exercise_id: String = entry.get("exercise_id", "")
		var ability_class: int = entry.get("ability_class", -1)

		# AC-07: ability_class == -1 (unset sentinel) OR ∉ {0,1,2,3} → push_error once naming the
		# exercise_id, then force UNKNOWN(3). The -1 default exists precisely so a forgotten field
		# is detectable here instead of fabricating STRIKE via a zero default.
		# AC-12: authored UNKNOWN(3) is LEGAL (== 3 is neither < 0 nor > 3) → no push_error.
		if ability_class < 0 or ability_class > 3:
			push_error("ExerciseClassMapping: invalid/unset ability_class %d for '%s' — forcing to UNKNOWN" % [ability_class, exercise_id])
			ability_class = _ABILITY_UNKNOWN

		# AC-07b (Story 003): movement_pattern ∉ {0..7} → push_error once + force UNKNOWN_PATTERN(7).
		# The -1 default IS the "author forgot to set it" sentinel (GDD Rule 3) and is itself an
		# authoring error — so it errors too, exactly like an out-of-range value. Crucially the
		# entry is NOT discarded: get_class_for_exercise reads ability_class (Formula 1a), so a
		# valid ability_class is still served even when movement_pattern was invalid.
		var movement_pattern: int = entry.get("movement_pattern", -1)
		if movement_pattern < 0 or movement_pattern > MovementPattern.UNKNOWN_PATTERN:
			push_error("ExerciseClassMapping: invalid/unset movement_pattern %d for '%s' — forcing to UNKNOWN_PATTERN(7)" % [movement_pattern, exercise_id])
			movement_pattern = MovementPattern.UNKNOWN_PATTERN

		var coerced: Dictionary = entry.duplicate()
		coerced["ability_class"] = ability_class
		coerced["movement_pattern"] = movement_pattern
		validated.append(coerced)

	return validated


## Build the two runtime lookup Dictionaries from validated rows in two passes:
##   Pass 1 — canonical exercise_id → ability_class (first-wins on duplicate id, AC-09).
##   Pass 2 — alias → canonical id, with collision detection (AC-15).
## Two passes so that alias-vs-canonical collisions resolve with canonical priority regardless
## of entry array order (every canonical id is known before any alias is added).
func _build_lookup(validated_rows: Array) -> void:
	# Pass 1: canonical ids.
	for entry in validated_rows:
		var raw_id: String = entry.get("exercise_id", "")
		var normalized_id: String = _normalize(raw_id)
		if normalized_id.is_empty():
			continue
		# AC-09: duplicate exercise_id (after normalize) → push_error naming the id; the
		# first-listed entry (lower array index) wins, later duplicates are skipped.
		if not _class_by_id.has(normalized_id):
			_class_by_id[normalized_id] = entry.get("ability_class", _ABILITY_UNKNOWN)
		else:
			push_error("ExerciseClassMapping: duplicate exercise_id '%s' — first entry wins; this duplicate is skipped" % normalized_id)

	# Pass 2: aliases (AC-15 — canonical priority, then first-listed alias wins).
	for entry in validated_rows:
		var normalized_id: String = _normalize(entry.get("exercise_id", ""))
		if normalized_id.is_empty():
			continue
		var aliases: Array = entry.get("aliases", [])
		for raw_alias in aliases:
			var normalized_alias: String = _normalize(raw_alias)
			if normalized_alias.is_empty():
				continue
			# Canonical priority: an alias that collides with a real exercise_id is dropped.
			if _class_by_id.has(normalized_alias):
				push_error("ExerciseClassMapping: alias '%s' collides with a canonical exercise_id — alias skipped (canonical wins)" % normalized_alias)
				continue
			# Alias-vs-alias: first-listed (lower entry/alias index) wins; later collisions dropped.
			if _canonical_by_alias.has(normalized_alias):
				push_error("ExerciseClassMapping: duplicate alias '%s' — first-listed wins; this one skipped" % normalized_alias)
				continue
			_canonical_by_alias[normalized_alias] = normalized_id


## Coerce a row (ExerciseEntry Resource or Dictionary) to Dictionary.
## Allows _validate_entries() and _build_lookup() to be format-agnostic.
func _row_to_dict(row: Variant) -> Dictionary:
	if row is Dictionary:
		return row as Dictionary
	# ExerciseEntry Resource (production path)
	var result: Dictionary = {}
	if row.has_method("get"):
		result["exercise_id"] = row.get("exercise_id") if row.get("exercise_id") != null else ""
		result["movement_pattern"] = row.get("movement_pattern") if row.get("movement_pattern") != null else -1
		result["ability_class"] = row.get("ability_class") if row.get("ability_class") != null else -1
		result["muscle_group"] = row.get("muscle_group") if row.get("muscle_group") != null else ""
		result["aliases"] = row.get("aliases") if row.get("aliases") != null else []
	return result


## Injectable seam for registry loading (AC-06 headless verify).
## When _registry_loader_override is a valid Callable, delegate to it (a test sets it to
## `func(): return null` to force the FAILED state without a .tres on disk). Otherwise load
## from _REGISTRY_PATH. Returns null → ExerciseClassMapping enters FAILED → all lookups UNKNOWN.
func _load_registry() -> Resource:
	if _registry_loader_override.is_valid():
		return _registry_loader_override.call()
	if not ResourceLoader.exists(_REGISTRY_PATH):
		return null
	return load(_REGISTRY_PATH)
