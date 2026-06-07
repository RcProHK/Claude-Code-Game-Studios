## LootRevealFormulas — #21 presentation formulas, pure static (story 004: F1).
##
## F1 — blocking_attention_timeline: the three tracks (S1 entry / S2a hold /
## S2b freeze) run CONCURRENTLY from T=0; S2 is internally sequential
## (hold → freeze @ peak, D2 freeze-as-hold). Writing this as max() is the
## satisfiability proof — an additive reading puts LEGENDARY at
## 450+800+400 = 1650ms > the 1200ms ceiling.
##
## NO runtime clamp anywhere in this file (F1: clamping silently flattens the
## ladder — validity is LootRevealTimingConfig.validate()'s data-load job).
class_name LootRevealFormulas
extends RefCounted


## T_block(tier) = max(D_entry, D_hold + D_timestop).
## motion_reduction variant: D_timestop = 0 for every tier (EC-M4) —
## T_block = max(D_entry, D_hold); ladder monotonicity is preserved.
static func t_block_ms(config: LootRevealTimingConfig, tier: int, motion_reduction: bool = false) -> int:
	var timestop: int = 0 if motion_reduction else config.timestop_ms[tier]
	return maxi(config.entry_ms[tier], config.hold_ms[tier] + timestop)


## EC-M9 — deterministic successor gap: previous reveal was EPIC+ ⇒ wait out
## the #7 pause-bound focal exit tween via a fixed margin (no "focal remaining"
## API exists — re-entry would be a silent DROP). Zero #7 state queries.
static func successor_gap_sec(config: LootRevealTimingConfig, prev_tier: int) -> float:
	if prev_tier >= LootEnums.RarityTier.EPIC:
		return maxf(config.inter_reveal_gap_sec, config.focal_exit_margin_sec)
	return config.inter_reveal_gap_sec
