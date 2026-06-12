class_name CombatAggregate extends RefCounted
## Telemetry (#28) — Formula 4: lossless combat aggregate accumulator.
##
## EVERY hit updates this accumulator, independent of Formula 3 sampling — so `total_hits`
## is the TRUE hit count, never the sampled count (AC-07 invariant). The aggregate is
## emitted as a single `combat_aggregate` event at flush / workout boundary (Story 009/011).
## Pure counters, deterministic, no RNG.
##
## Governing: design/gdd/telemetry.md Formula 4, AC-07.

var total_hits: int = 0
var total_damage: int = 0
var crit_count: int = 0
## damage_tier ordinal → count. Σ(values) == total_hits (every hit lands in exactly one tier).
var tier_counts: Dictionary = {}


## Record one hit. Called for EVERY hit (sampled or not) — this is what keeps the
## aggregate lossless (AC-07). damage_tier is the #13 DamageTier ordinal.
func accumulate(damage: int, is_crit: bool, damage_tier: int) -> void:
	total_hits += 1
	total_damage += damage
	if is_crit:
		crit_count += 1
	tier_counts[damage_tier] = int(tier_counts.get(damage_tier, 0)) + 1


## Sum of per-tier counts — must always equal total_hits (lossless cross-check).
func tier_total() -> int:
	var n: int = 0
	for v in tier_counts.values():
		n += int(v)
	return n


func to_dict() -> Dictionary:
	return {
		"total_hits": total_hits,
		"total_damage": total_damage,
		"crit_count": crit_count,
		"tier_counts": tier_counts.duplicate(),
	}


## Reset for the next aggregation window (e.g. after the aggregate is flushed).
func reset() -> void:
	total_hits = 0
	total_damage = 0
	crit_count = 0
	tier_counts.clear()
