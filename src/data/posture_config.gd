class_name PostureConfig
extends Resource
## (class_posture, evolution_tier) -> SpriteFrames resource-path LUT.
##
## Key format = "{CLASS}_T{tier}" (e.g. "STRIKE_T0"). 12 entries = 3 classes x 4 tiers.
## `avatar_renderer.gd` resolves a path then `load()`s it; a missing key or load
## failure falls back to EMERGENCY_AVATAR.tres (EC-ASSET-1) so the silhouette never
## breaks. MVP points all 12 at a shared placeholder SpriteFrames — distinct
## per-(class,tier) art is produced later via `/asset-spec` (G-AR-5). See
## design/gdd/avatar-renderer.md (Story 015 / AC-12).

const CLASSES: Array[StringName] = [&"STRIKE", &"CONTROL", &"MOBILITY"]
const TIER_COUNT: int = 4  # T0..T3

@export var posture_lut: Dictionary = {}

## Canonical key for a (class, tier) pair. Tier is clamped defensively to 0..3.
static func key_for(class_posture: StringName, evolution_tier: int) -> String:
	var t: int = clampi(evolution_tier, 0, TIER_COUNT - 1)
	return "%s_T%d" % [String(class_posture), t]

## Resolve the SpriteFrames res:// path for (class, tier), or "" if the key is absent.
func path_for(class_posture: StringName, evolution_tier: int) -> String:
	return posture_lut.get(key_for(class_posture, evolution_tier), "")

## True only when all 12 (class x tier) keys are present (AC-12).
func is_complete() -> bool:
	for c in CLASSES:
		for t in range(TIER_COUNT):
			if not posture_lut.has(key_for(c, t)):
				return false
	return true
