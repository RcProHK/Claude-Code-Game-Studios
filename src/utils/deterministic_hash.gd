## DeterministicHash — FNV-1a 32-bit string hash (BOSS-AC-followup-19)
##
## Driving GDD:
##   * design/gdd/boss-system.md — Formula 3 (Pass 4 A2.2 deterministic_hash)
##
## Driving Story: production/epics/boss-system/story-005-formula3-attack-pattern.md
## Implementing TR: TR-boss-005 (cross-platform deterministic selection)
##
## WHY this exists (NOT Godot's built-in hash()):
## Godot's `hash()` is build-implementation-dependent — different Web Export
## (WASM) and Desktop builds, and different 4.6 patch versions, may produce
## DIFFERENT values for the same input. FNV-1a is a FIXED-algorithm, pure-GDScript
## impl — identical output cross-platform + cross-version (AC-34). Single source
## of truth for any「seed a deterministic choice from a String」operation
## (Formula 3 attack-pattern selection, Rule 2 spawn selection, future formulas).
##
## Golden vector: `deterministic_hash("abc") == 1454761972` (AC-34).
class_name DeterministicHash extends RefCounted

const FNV_OFFSET_BASIS_32: int = 2166136261
const FNV_PRIME_32: int = 16777619
const FNV_MASK_32: int = 0xFFFFFFFF


## FNV-1a 32-bit hash of a UTF-8 string. Always returns a non-negative 32-bit
## value (masked), so `% n` is safe without posmod (posmod kept as defense-in-depth
## at call sites).
##
## @param s  Input string (e.g. "%s_pattern_%d" % [transition_id, attack_count]).
## @return   Non-negative 32-bit FNV-1a hash.
static func deterministic_hash(s: String) -> int:
	var h: int = FNV_OFFSET_BASIS_32
	for byte in s.to_utf8_buffer():
		h = (h ^ byte) & FNV_MASK_32
		h = (h * FNV_PRIME_32) & FNV_MASK_32
	return h
