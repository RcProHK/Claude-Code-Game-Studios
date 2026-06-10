class_name AvatarEvolutionConfig
extends Resource
## Data-driven tier-derivation thresholds (CR-4 / Formula 2 / CI-2).
##
## `avatar_renderer.gd` reads every Formula-2 threshold from a loaded instance of
## this resource — it holds ZERO threshold literals itself (CI-2). Each array is
## indexed by tier 0..3. Two independent symmetric paths (Pass-4 F-2 fix):
##   generalist_ok(t) = stat_total >= stat_thresholds[t]  and ability_count   >= ability_thresholds[t]
##   specialist_ok(t) = peak_stat  >= peak_thresholds[t]  and max_class_depth >= depth_thresholds[t]
## See design/gdd/avatar-renderer.md Formula 2.

## S_t — generalist stat-sum gate. INV-G1: strictly increasing.
@export var stat_thresholds: Array[int] = [0, 30, 60, 100]
## A_t — generalist ability-breadth gate. INV-G1: monotonic non-decreasing.
@export var ability_thresholds: Array[int] = [0, 1, 3, 6]
## S_peak_t — specialist peak-stat gate. INV-G1: monotonic non-decreasing.
@export var peak_thresholds: Array[int] = [0, 20, 40, 70]
## D_t — specialist class-depth gate. INV-G1: monotonic non-decreasing.
@export var depth_thresholds: Array[int] = [0, 1, 2, 3]

## Drift detector — bump on any threshold change (EC-BOOT-3 config-version recovery).
@export var version_hash: String = "v1-2026-06-10"

## INV-G1 load-time validation. Returns "" when valid, else a diagnostic string.
## Called at boot (EC-BOOT-2 surrounds this); a non-empty result is a hard config error.
func validate() -> String:
	var arrays := {
		"stat_thresholds": stat_thresholds,
		"ability_thresholds": ability_thresholds,
		"peak_thresholds": peak_thresholds,
		"depth_thresholds": depth_thresholds,
	}
	for name in arrays:
		var arr: Array = arrays[name]
		if arr.size() != 4:
			return "%s must have exactly 4 entries (tier 0..3), got %d" % [name, arr.size()]
		if arr[0] != 0:
			return "%s[0] must be 0 (T0 always passes), got %d" % [name, arr[0]]
	# S_t strictly increasing; the rest monotonic non-decreasing (INV-G1).
	for i in range(1, 4):
		if stat_thresholds[i] <= stat_thresholds[i - 1]:
			return "stat_thresholds must be strictly increasing at index %d" % i
	for name in ["ability_thresholds", "peak_thresholds", "depth_thresholds"]:
		var arr: Array = arrays[name]
		for i in range(1, 4):
			if arr[i] < arr[i - 1]:
				return "%s must be monotonic non-decreasing at index %d" % [name, i]
	return ""
