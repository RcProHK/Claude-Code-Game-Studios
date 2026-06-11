class_name CombatVisualFeedbackFormulas extends RefCounted
## Pure presentation curves + lookups for #25 CombatVisualFeedback. No balance math
## (that is #13 CombatResolver) — these are deterministic presentation timings only.
## Static, GSM-agnostic, no side effects. Knobs are consts here (presentation curves,
## not balance values per GDD §Formulas); story 016 (G-CV-5) registers them in
## entities.yaml. All pause values < MAX_PAUSE_SEC so #6 never clamps.


# --- damage-number knobs (R-19 / Formula 1) -----------------------------------
const MAX_CONCURRENT_DAMAGE_NUMBERS: int = 12   ## Label pool size (oldest-recycle when full)
const DAMAGE_NUMBER_RISE_PX: float = 40.0       ## total upward drift (−y)
const DAMAGE_NUMBER_LIFETIME_SEC: float = 0.8   ## number lifespan
const DAMAGE_NUMBER_FADE_START_RATIO: float = 0.5 ## lifetime fraction at which fade begins


## Formula 1 — damage number rise. y_offset(t) = -RISE_PX × ease_out(clamp(t/LIFETIME)).
## ease_out(x) = 1-(1-x)². The ratio is clamped [0,1] FIRST (robustness: a >1 ratio would
## flip ease_out negative). Output ∈ [-RISE_PX, 0].
static func number_y_offset(t: float) -> float:
	var x: float = clampf(t / DAMAGE_NUMBER_LIFETIME_SEC, 0.0, 1.0)
	var ease_out: float = 1.0 - (1.0 - x) * (1.0 - x)
	return -DAMAGE_NUMBER_RISE_PX * ease_out


## Formula 1 — damage number fade. alpha(t) = 1 - smoothstep(FADE_START, 1, clamp(t/LIFETIME)).
## Output ∈ [0, 1]; 1.0 until FADE_START, decaying to 0 at lifetime end.
static func number_alpha(t: float) -> float:
	var x: float = clampf(t / DAMAGE_NUMBER_LIFETIME_SEC, 0.0, 1.0)
	return 1.0 - smoothstep(DAMAGE_NUMBER_FADE_START_RATIO, 1.0, x)


# --- overlay flash knobs (R-11 / Formula 2) -----------------------------------
const OVERLAY_MAX_OPACITY_CRITICAL: float = 0.35  ## CRITICAL flash peak opacity (fillrate knob)
const OVERLAY_MAX_OPACITY_OVERKILL: float = 0.6   ## OVERKILL can be higher (shorter-lived)
const CRITICAL_FLASH_DURATION_SEC: float = 0.18
const OVERKILL_FLASH_DURATION_SEC: float = 0.12


## Formula 2 — overlay flash alpha. Linear decay from peak opacity to 0 over the duration.
## overlay_alpha(t) = max_opacity × max(0, 1 - t/duration). Output ∈ [0, max_opacity].
static func overlay_alpha(t: float, max_opacity: float, duration: float) -> float:
	if duration <= 0.0:
		return 0.0
	return max_opacity * maxf(0.0, 1.0 - t / duration)


# --- anchor knobs (R-17 / Formula 5) ------------------------------------------
const ANCHOR_FORWARD_PX: float = 40.0   ## anchor distance in front of the avatar (facing-scaled)
const ANCHOR_VERTICAL_PX: float = -16.0 ## vertical tweak (torso height; −y = up)
const ANCHOR_JITTER_PX: float = 24.0    ## per-hit spread to avoid overlap (cosmetic RNG)


## Formula 5 (deterministic part) — anchor base spawn position from the focal base + the
## facing-scaled forward/vertical offset. Cosmetic jitter is added by the coordinator
## (RNG, excluded from deterministic assertions). MVP focal_base = camera-relative point,
## facing = +1 (#26 exposes no anchor/facing API — render-only per ADR-0010, v0.2 only).
static func anchor_base(focal_base: Vector2, facing: int) -> Vector2:
	return focal_base + Vector2(facing * ANCHOR_FORWARD_PX, ANCHOR_VERTICAL_PX)


# --- coalescing knob (R-15 / Formula 3) ---------------------------------------
## Minimum interval between #25-issued particles for the same target. Protects #5's
## 200 cap from LIGHT spam evicting climax particles; aligns #5 EVICTION_MIN_LIFE_MS=150
## + #6 peripheral 200ms register threshold. The gate is stateful (per-target dict on
## the coordinator) so the F3 lookup lives there; only the knob is a const here.
const HIT_PARTICLE_COALESCE_MS: int = 200

# --- hit_pause tuning knobs (seconds) -----------------------------------------
const HIT_PAUSE_HEAVY_SEC: float = 0.065       ## R-7 HEAVY tier freeze
const HIT_PAUSE_CRITICAL_SEC: float = 0.080    ## R-8 CRITICAL tier + OVERKILL (flash-ratified mode)
const CRITICAL_DEGRADE_PAUSE_SEC: float = 0.100 ## EC-20: flash unavailable → carries the tier separation alone
const MAX_PAUSE_SEC: float = 0.12              ## #6 clamp ceiling — every value above is ≤ this


## Formula 4 — (outcome, damage_tier) → #25 direct hit_pause duration (fills the #6
## auto-dispatch pause=0 gap). `overlay_enabled` selects ratified (flash present, 0.080)
## vs EC-20 degrade (flash absent, 0.100) for the top-tier cases — the 2-arg call
## (default true) is the ratified-mode lookup tested by AC-22.
##
## Piecewise (GDD §Formula 4):
##   OVERKILL                  → critical pause
##   KILLED + CRITICAL tier    → critical pause   (R-9 climax-kill carve-out — 招牌一刀劈死)
##   KILLED + lower tier       → 0.0              (#14 owns death VFX; #25 does not pause)
##   non-kill CRITICAL tier    → critical pause
##   non-kill HEAVY tier       → HIT_PAUSE_HEAVY_SEC
##   else                      → 0.0
static func hit_pause_sec(outcome: int, damage_tier: int, overlay_enabled: bool = true) -> float:
	var critical: float = HIT_PAUSE_CRITICAL_SEC if overlay_enabled else CRITICAL_DEGRADE_PAUSE_SEC
	if outcome == CombatResolver.HitOutcome.OVERKILL:
		return critical
	if outcome == CombatResolver.HitOutcome.KILLED:
		if damage_tier == CombatResolver.DamageTier.CRITICAL:
			return critical
		return 0.0
	match damage_tier:
		CombatResolver.DamageTier.CRITICAL:
			return critical
		CombatResolver.DamageTier.HEAVY:
			return HIT_PAUSE_HEAVY_SEC
		_:
			return 0.0


## R-8/R-10/R-9: which (outcome, tier) combinations fire the CRITICAL/OVERKILL flash
## overlay. Screen-feel is keyed on damage_tier (R-12), with the kill carve-out. Used by
## the router to decide flash (when overlay ratified) vs degrade-pause (when not).
static func wants_flash(outcome: int, damage_tier: int) -> bool:
	if outcome == CombatResolver.HitOutcome.OVERKILL:
		return true
	if outcome == CombatResolver.HitOutcome.KILLED:
		return damage_tier == CombatResolver.DamageTier.CRITICAL  # R-9 critical-kill carve-out
	return damage_tier == CombatResolver.DamageTier.CRITICAL
