## LoadoutScoreCalc — Formula 1 loadout_score for #17 auto-equip-if-better
##
## Driving GDD: design/gdd/equipment-inventory.md Formula 1 (Pass 1 rewrite)
## Driving Story: production/epics/equipment-inventory/story-007-loadout-score-formula.md
## Governing ADR: N/A — pure formula (stateless static, #13 CombatResolver precedent)
##
## WHY loadout-level + clamp-aware (vs raw item-vs-item):
## the comparison key is the POST-CLAMP effective aggregate of the whole loadout —
## when ATK is already at the AntiSnowball cap, swapping an HP item for more ATK
## yields zero marginal gain and would make the avatar strictly weaker. Comparing
## clamped loadout scores (swap iff strictly greater) closes that trap (AC-19).
##
## WHY per-key weight scales (not a uniform [0,2] range): CRIT deltas live at the
## 0.01 scale — a uniform range mathematically cannot normalize them against
## 100-scale HP deltas. Weights are "ATK-equivalents per unit delta".
class_name LoadoutScoreCalc


## Formula 1 weights — ATK-equivalent per unit delta (GDD Tuning Knobs; per-key
## safe ranges: ATK [0.5,2] / HP [0.1,0.5] / MOVE [0.2,1.2] / CRIT [100,800]).
const STAT_WEIGHT: Dictionary = {
	&"ATTACK_POWER": 1.0,
	&"MAX_HP": 0.25,
	&"MOVE_SPEED": 0.6,
	&"CRIT_CHANCE": 400.0,
}


## Formula 1 — loadout_score(effective_aggregate) = Σ STAT_WEIGHT[key] × delta.
## `effective_aggregate` is the Formula 4 POST-CLAMP dict (4 derived keys).
## Empty slots contribute nothing (empty dict ⇒ 0.0). Unknown keys score 0
## (weights.get default) — the D8 guard upstream should have dropped them.
## Golden vector (AC-18): 3×LEGENDARY fresh account {ATK 84, HP 160, MOVE 25,
## CRIT 0.06} → 84 + 40 + 15 + 24 = 163.0.
static func loadout_score(
		effective_aggregate: Dictionary,
		weights: Dictionary = STAT_WEIGHT) -> float:
	var score: float = 0.0
	for key: Variant in effective_aggregate:
		score += float(weights.get(key, 0.0)) * float(effective_aggregate[key])
	return score
