## ExerciseEntry — authoring-time schema for a single exercise registry row.
##
## Governing story : #10 Story 001 (Registry schema + core exercise lookup)
## Governing ADRs  : ADR-0007 (AbilityClass Classification enum — zero-default FORBIDDEN),
##                   ADR-0003 (no per-player persistence — static config)
##
## ⚠️ SENTINEL DEFAULTS (-1, NOT 0):
##   `ability_class` and `movement_pattern` default to -1 (UNSET sentinel).
##   GDScript `int` unset default = 0 = STRIKE — silent fabrication of a REAL class
##   (ADR-0007 zero-default FORBIDDEN). -1 ∉ {0,1,2,3} is detectable by boot validation
##   (Story 003 _validate_entries() loop). Never change these defaults to 0.
##
## This Resource is the AUTHORING schema only — used in ExerciseRegistry.tres.
## At runtime, ExerciseClassMapping._build_lookup() flattens all entries into
## internal Dictionaries (_class_by_id, _canonical_by_alias). Runtime lookups
## never touch ExerciseEntry objects again after boot.
class_name ExerciseEntry
extends Resource

## GymSys canonical exercise id (e.g. "bench_press"). Must be unique across registry.
## Normalized at boot (lowercase, trimmed, spaces→_). Source: #2 GymSysBackendClient.
@export var exercise_id: String = ""

## Movement pattern ordinal (MovementPattern enum — Story 002).
## UNSET sentinel = -1. Valid range: 0..7 (PUSH/PULL/LEG/CORE/CARDIO/FLEXIBILITY/COMPOUND/UNKNOWN_PATTERN).
## Formula 1a (get_class_for_exercise) does NOT read this field — only get_class_for_movement_pattern does.
@export var movement_pattern: int = -1

## AbilitySystem.AbilityClass ordinal — UNSET sentinel = -1.
## Valid values: 0=STRIKE, 1=CONTROL, 2=MOBILITY, 3=UNKNOWN (authored-intentional).
## Boot validation (Story 003) pushes error + forces to 3 if this remains -1 or ∉ {0,1,2,3}.
@export var ability_class: int = -1

## Human-readable muscle group label (e.g. "chest", "back"). Informational only — not used in lookup.
@export var muscle_group: String = ""

## Alternate GymSys id spellings that map to this canonical exercise_id.
## Stored as String (not StringName) — alias normalization applied at boot.
## Collision policy (Story 004): first-listed canonical wins; duplicate aliases skipped.
@export var aliases: Array[String] = []
