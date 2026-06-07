## LootRevealTimingConfig — #21 F1 per-tier timeline data (story 004).
##
## Data-driven carrier for the reveal timeline budget. Index = LootEnums.RarityTier
## ordinal (COMMON..LEGENDARY, 0..4). hold/timestop values are #15 Visual Spec
## Table OWNED numbers (this resource is the single code carrier — #21 never
## prints its own copies into logic); entry is a #21-owned knob.
##
## Validation = CI/data-load assert (F1: runtime clamp is FORBIDDEN — a clamp
## would silently flatten the rarity ladder). Invalid config must fail loud.
class_name LootRevealTimingConfig
extends Resource

## #15 Pillar 2 attention ceiling — LOCKED. The ceiling check is `<=` by design:
## LEGENDARY touches equality (1200 == 1200); a `<` would be an unreachable
## binding (satisfiability lesson).
const ATTENTION_CEILING_MS: int = 1200

## S1 entry duration per tier, ms (#21 knob; safe range bound by C1).
@export var entry_ms: Array[int] = [150, 200, 300, 380, 450]

## S2a hold/focal-push window per tier, ms (#15 ladder LOCKED).
@export var hold_ms: Array[int] = [200, 350, 500, 650, 800]

## S2b freeze @ peak window per tier, ms (#15 ladder LOCKED; D2 order).
@export var timestop_ms: Array[int] = [0, 0, 150, 300, 400]

## S4 exit anim (knob 0.1–0.2) + inter-reveal gap (knob 0.2–0.8) — used by the
## cross-reveal flash budget assert (Tuning Knobs matrix) and stories 010/011.
@export var exit_anim_sec: float = 0.2
@export var inter_reveal_gap_sec: float = 0.3

## EPIC+ successor gap (EC-M9 deterministic margin; lower bound locked to
## #7 FOCAL_EXIT_DURATION − exit_anim_sec + 0.1 — G-flag-4).
@export var focal_exit_margin_sec: float = 0.6


## Data-load assert (F1 + Tuning Knobs flash budget). Empty result == valid.
func validate() -> Array[String]:
	var errors: Array[String] = []
	for arr_pair: Array in [["entry_ms", entry_ms], ["hold_ms", hold_ms], ["timestop_ms", timestop_ms]]:
		var arr: Array = arr_pair[1]
		if arr.size() != 5:
			errors.append("%s must have exactly 5 per-tier entries (got %d)" % [arr_pair[0], arr.size()])
			return errors  # structural — later checks index by tier
		for v: int in arr:
			if v < 0:
				errors.append("%s contains a negative duration (%d)" % [arr_pair[0], v])
	var t_block_min_ms: int = ATTENTION_CEILING_MS
	for tier: int in range(5):
		var t_block: int = maxi(entry_ms[tier], hold_ms[tier] + timestop_ms[tier])
		# Constraint C1: entry must not exceed the S2 window — overlap model only
		# holds (and T_block == hold+timestop matches #15 arithmetic) under C1.
		if entry_ms[tier] > hold_ms[tier] + timestop_ms[tier]:
			errors.append(
				"C1 violated @ tier %d: entry %dms > hold %dms + timestop %dms (F1 — fix data, no runtime clamp)" % [
					tier, entry_ms[tier], hold_ms[tier], timestop_ms[tier],
				])
		# Attention ceiling — `<=` (equality reachable, LEGENDARY touches it).
		if t_block > ATTENTION_CEILING_MS:
			errors.append(
				"attention ceiling violated @ tier %d: T_block %dms > %dms" % [
					tier, t_block, ATTENTION_CEILING_MS,
				])
		t_block_min_ms = mini(t_block_min_ms, t_block)
	# Cross-reveal flash budget (WCAG 2.3.1 — ≤3 flash/s across back-to-back
	# COMMON cycles: S0 burst + S4 shutter flash per cycle).
	var cycle_sec: float = float(t_block_min_ms) / 1000.0 + exit_anim_sec + inter_reveal_gap_sec
	if cycle_sec > 0.0 and (2.0 / cycle_sec) > 3.0:
		errors.append(
			"flash budget violated: 2 transients / %.3fs cycle = %.2f/s > 3/s (raise exit_anim/gap or T_block floor)" % [
				cycle_sec, 2.0 / cycle_sec,
			])
	return errors
