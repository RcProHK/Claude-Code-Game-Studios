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

# ── #15 Visual Spec Table ceremony values (story 006 — #15 OWNED numbers,
#    this resource is the single code carrier; logic never prints copies) ──

## Camera zoom per tier (—/—/1.02 pulse/1.05 focal/1.08 focal).
@export var focal_zoom: Array[float] = [1.0, 1.0, 1.02, 1.05, 1.08]

## Focal duration per tier, sec. EPIC/LEG == hold (D2: push-in IS S2a, 同源);
## RARE = its own 0.3s pulse (freeze still anchors at clock T=D_hold).
@export var focal_duration_sec: Array[float] = [0.0, 0.0, 0.3, 0.65, 0.8]

## Screen shake per tier (#6 shake(intensity, duration)): 2px/4px/6px.
@export var shake_intensity: Array[float] = [0.0, 0.0, 2.0, 4.0, 6.0]
@export var shake_duration_sec: Array[float] = [0.0, 0.0, 0.2, 0.35, 0.5]

## Particle burst multiplier per tier (1×/1×/1.5×/2×/3× — ADR-0001 cap applies;
## EC-M4 motion_reduction halves this at call time).
@export var particle_multiplier: Array[float] = [1.0, 1.0, 1.5, 2.0, 3.0]

## World saturation during ceremony — flat across tiers by design (#15: tier
## differentiation comes from hold + particle density, not colour drift).
@export var saturation_drop: float = 0.6
@export var saturation_recovery_sec: float = 2.0

## Freeze-anchor fallback grace after D_hold when focal_completed never
## arrives (F1: fallback timer T = D_hold + 0.2s — #7 bug still freezes).
@export var focal_fallback_grace_ms: int = 200

# ── F5 two-stage tap knobs (story 005) ──

## Fast-complete in-flight tween snap duration (F5 — 0-frame is reserved for
## rollback; a snap that instant reads as a glitch). Safe range 0.05–0.2.
@export var snap_sec: float = 0.1

## Two-stage tap lockout, anchored at S3 ENTRY (F5/AC-15 unified anchor) —
## min-readable window so a sweat-handed mash can't blind-skip the terminal
## frame. Only applies after a fast-complete; natural S3 has zero lockout.
## Safe range 0.15–0.4.
@export var dismiss_debounce_sec: float = 0.25

## EC-M1 — suspend→resume continue-vs-cancel threshold (#15 GDD Formula 4
## number, mirrored here until #15 ships a code carrier). Safe [10000, 60000].
@export var bfcache_continue_threshold_ms: int = 30000

## F6 — post-S3 stash-exit collapse anim. Safe 0.1–0.2 (Pass 1: upper bound
## capped so collapse + 0.1s jitter margin stays ≤ the 0.3s budget).
@export var stash_collapse_sec: float = 0.2


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
