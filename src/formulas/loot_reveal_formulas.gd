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


# ── F3 — catchup_duration (story 014; provable bound 15.8s @ defaults) ──

## Partitions a tier list into the contact-sheet model: sub-RARE stream
## (capped — overflow joins the grid), RARE+ ceremonies (tier-DESC top-K,
## chronological within tier; revealed ASCENDING — peak-end rule), RARE+
## overflow (own grid cell, C-1 identity). Pure — caller maps drops↔tiers.
static func catchup_partition(tiers: Array, config: LootRevealTimingConfig) -> Dictionary:
	var sub: Array = []
	var rare_plus: Array = []  # [ [tier, original_index], ... ]
	for i: int in range(tiers.size()):
		var tier: int = int(tiers[i])
		if tier < LootEnums.RarityTier.RARE:
			sub.append(i)
		else:
			rare_plus.append([tier, i])
	var stream: Array = sub.slice(0, config.max_stream_beats)
	var grid: Array = sub.slice(config.max_stream_beats)
	# Selection: tier DESC, stable (chronological inside a tier).
	var sorted_rp: Array = rare_plus.duplicate()
	sorted_rp.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	var selected: Array = sorted_rp.slice(0, config.k_ceremony_max)
	var overflow: Array = sorted_rp.slice(config.k_ceremony_max)
	# Reveal order: ASCENDING tier (chronological inside a tier).
	selected.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var ceremonies: Array = []
	for pair: Array in selected:
		ceremonies.append(pair[1])
	for pair: Array in overflow:
		grid.append(pair[1])  # C-1: RARE+ overflow keeps its own cell
	return {"stream": stream, "ceremonies": ceremonies, "grid_overflow": grid}


## F3 machine time (excl. player taps; assumes #7 emits focal_completed —
## the watchdog-degraded path is explicitly outside this bound).
static func catchup_machine_time_sec(config: LootRevealTimingConfig, n_sub: int,
		ceremony_tiers_ascending: Array) -> float:
	var t: float = config.banner_beat_sec
	t += float(mini(n_sub, config.max_stream_beats)) * config.stream_beat_sec
	var prev_tier: int = -1
	for tier: int in ceremony_tiers_ascending:
		t += successor_gap_sec(config, prev_tier) if prev_tier >= 0 else config.inter_reveal_gap_sec
		t += float(t_block_ms(config, tier)) / 1000.0
		prev_tier = tier
	t += config.grid_entry_sec
	return t


# ── F2 — breakdown_bar_geometry (story 008; ADR-0005 75/25 binding 可視化) ──

const BREAKDOWN_IDENTITY_EPS: float = 0.001

## EC-M15 display gate — runs BEFORE the geometry (corrupt input never enters
## the math): identity |0.75ws + 0.25rr − score| ≤ ε AND tier/score consistent
## against the ADR-0005 thresholds AND tier ≥ RARE (bar is RARE+ only).
## Inputs are the RAW (unclamped) values — clamping is the geometry's job;
## an out-of-range raw value that still satisfies identity post-clamp is
## handled by the caller passing clamped values here too. #15's tier wins:
## on mismatch the bar hides — a bar contradicting the tier hurts the Pillar 1
## claim more than no bar.
static func breakdown_visible(ws: float, rr: float, score: float, tier: int, rarity_config) -> bool:
	if tier < LootEnums.RarityTier.RARE:
		return false
	var cws: float = clampf(ws, 0.0, 1.0)
	var crr: float = clampf(rr, 0.0, 1.0)
	if absf(0.75 * cws + 0.25 * crr - score) > BREAKDOWN_IDENTITY_EPS:
		return false
	if rarity_config != null and "tier_thresholds" in rarity_config:
		var thresholds: Array = rarity_config.tier_thresholds
		if tier < thresholds.size() and score < float(thresholds[tier]) - BREAKDOWN_IDENTITY_EPS:
			return false  # score-tier contradiction — trust the #15 tier, hide the bar
	return true


## F2 geometry (evaluation order pinned: ① clamp-on-read ② [gate ran already]
## ③ geometry + honest-endpoint clamp + floor clause + display gate).
## Returns { stacked, px_w, px_r, pct_w, pct_r } — pct sums to 100 always;
## both contribs > 0 ⇒ pct ∈ [1, 99] (a true zero is the only honest 0/100).
static func breakdown_geometry(ws: float, rr: float, score: float, w_bar: int,
		min_delta_px: int = 8, w_bar_min: int = 120) -> Dictionary:
	var cws: float = clampf(ws, 0.0, 1.0)
	var crr: float = clampf(rr, 0.0, 1.0)
	var contrib_w: float = 0.75 * cws
	var contrib_r: float = 0.25 * crr
	var frac_w: float = contrib_w / score if score > 0.0 else 0.0
	var px_w: int = int(roundf(frac_w * float(w_bar)))
	var px_r: int = w_bar - px_w
	var pct_w: int = int(roundf(frac_w * 100.0))  # round-half-up for positives
	# Honest-endpoint clamp: rr=0.01 rounding to 100/0 is a false claim; only a
	# true zero contribution may show the endpoint.
	if contrib_r > 0.0:
		pct_w = mini(pct_w, 99)
		px_r = maxi(px_r, 1)
		px_w = w_bar - px_r  # Pass 2 closure — px_w+px_r == w_bar invariant holds
	if contrib_w > 0.0:
		pct_w = maxi(pct_w, 1)
	var pct_r: int = 100 - pct_w  # sum == 100 always
	# Floor clause — corrupt-input defense ONLY (provably unreachable for legal
	# input at w_bar ≥ 120; AC-43 pins the unreachability).
	if (px_w - px_r) < min_delta_px:
		px_w = int(ceilf(float(w_bar + min_delta_px) / 2.0))
		px_r = w_bar - px_w
	return {
		"stacked": w_bar < w_bar_min,  # display gate — text-only variant, % mandatory
		"px_w": px_w,
		"px_r": px_r,
		"pct_w": pct_w,
		"pct_r": pct_r,
	}
