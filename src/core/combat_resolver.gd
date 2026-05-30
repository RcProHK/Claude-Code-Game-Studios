## CombatResolver — stateless pure-function combat math core (#13)
##
## ⚠️ ARCHITECTURE CONTRACT (GDD Rule 1 / Rule 2 / ADR-0006 Contract 12):
## CombatResolver is NOT an autoload. It is `class_name CombatResolver extends
## RefCounted` exposing ONLY `static func` + `const` + inner POD `class`
## declarations. The class body MUST NOT contain any instance `var`, `@onready`,
## `@export`, class-scope `signal`, `_ready`, `_process`, or `_physics_process`
## — purity is CI-enforced by `tools/ci/check_combat_resolver_purity.gd`.
##
## WHY pure-function (no state, no autoload):
##   * Replay determinism — `resolve_hit(ctx)` is a referentially-transparent
##     function of its CombatContext. Same ctx (same injected rng seed) → same
##     HitResult, every time. This is the FR-1 binding for #13's replay tests.
##   * No global reads — stats arrive PRE-SNAPSHOTTED in ctx.caster_stats
##     (StatSnapshot). The resolver never touches StatSystem / AbilitySystem /
##     GameStateMachine directly (CI lint: check_combat_resolver_engine_singletons).
##   * RNG is CALLER-INJECTED via ctx.rng — never `randf()` / `randi()` inside
##     this file (CI lint: check_combat_resolver_randf). The caller owns the
##     seeded RandomNumberGenerator so replays reproduce.
##
## Single entry point (Rule 2): `static func resolve_hit(ctx) -> HitResult`.
##
## Driving GDD: design/gdd/combat-resolver.md (Rules 1,2,4,5,6,9; Formula 1)
## Governing ADRs: ADR-0006 Contract 12 (pure function); ADR-0007 (enum families);
##   ADR-0006 Contract 3 (EnemyKilledPayload serialization — separate file)
## Stories: story-001 (CI lints), story-002 (data structures), story-003 (Formula 1)
##
## NOTE: Batch B complete. Stage 3 (crit roll — Formula 2), Stage 4 (crit
## multiplier — Formula 3), Stage 5a (overkill — Formula 5) and Stage 5b (tier —
## Formula 4) are now FULLY IMPLEMENTED per the GDD (Story 004 crit / Story 005
## tier+overkill). The 5-stage pipeline is real: resolve_hit returns a populated
## HitResult deterministically as a pure function of its CombatContext.
class_name CombatResolver extends RefCounted


# ──────────────────────────────────────────────────────────────────────────────
# Enums (Story 002 — AC-21 / AC-09)
# ──────────────────────────────────────────────────────────────────────────────

## HitOutcome — ADR-0007 Family A (ordinal 0 = NORMAL_HIT = safe default).
## A zero-initialised HitResult.outcome is the conservative NORMAL_HIT — a
## resolver bug that forgets to set outcome will NOT fabricate a KILL.
## DODGED is intentionally absent (Rule 5 — out of MVP scope).
enum HitOutcome {
	NORMAL_HIT,    # 0 — safe default
	CRITICAL_HIT,  # 1
	KILLED,        # 2
	OVERKILL,      # 3
}

## DamageTier — ADR-0007 Family A (ordinal 0 = NEGLIGIBLE = safe default).
## damage_tier must NEVER be null (FR Test #4) — NEGLIGIBLE is the zero-init
## fallback so an unset tier degrades safely rather than crashing consumers.
enum DamageTier {
	NEGLIGIBLE,  # 0 — safe default
	LIGHT,       # 1
	MEDIUM,      # 2
	HEAVY,       # 3
	CRITICAL,    # 4
}

## AnomalyReason — ADR-0007 Family A. Combat metric anomaly payloads emit one of
## these enum values — NEVER a free-form string (TR-combat-007). Ordinal 0
## (GSM_SUSPENDED) is the safe default.
enum AnomalyReason {
	GSM_SUSPENDED,         # 0
	INVALID_ABILITY_ID,    # 1
	NEGATIVE_DAMAGE,       # 2
	CLAMP_TRIGGERED,       # 3
	DEAD_TARGET_RESOLVE,   # 4
	RNG_INJECTION_MISSING, # 5
}


# ──────────────────────────────────────────────────────────────────────────────
# Constants (Story 003)
# ──────────────────────────────────────────────────────────────────────────────

## Crit damage multiplier applied in Stage 4 (Formula 3, Q-D2 [A] fixed 1.5×).
## Anti-snowball HARD invariant: CRIT_MULTIPLIER × MAX_CRIT_CHANCE(0.50) ≤ 0.75.
const CRIT_MULTIPLIER: float = 1.5

## Formula 4 DamageTier ratio thresholds (Section G knobs — `damage_dealt /
## max(1, target_max_hp)`). Strict monotonic T_CRITICAL > T_HEAVY > T_MEDIUM >
## T_LIGHT > 0. Lower-bound checks are `>=` inclusive (a hit landing EXACTLY on a
## threshold promotes to the higher tier — see AC-16 boundary tests).
const T_CRITICAL: float = 0.40
const T_HEAVY: float = 0.15
const T_MEDIUM: float = 0.05
const T_LIGHT: float = 0.01

## Upper bound for ctx.hit_seq (replay determinism guard — Story 007).
const MAX_HIT_SEQ: int = 1_000_000

## Maximum targets a single cast may resolve against (AoE clamp — Story 007).
const MAX_TARGETS_PER_CAST: int = 8


# ──────────────────────────────────────────────────────────────────────────────
# POD struct inner classes (Story 002)
#
# These extend RefCounted and are PURE DATA — instance `var` fields are ALLOWED
# here (they are data-struct members, not resolver state). The purity CI lint
# explicitly does NOT flag `var` declared inside an inner `class ... :` block.
# ──────────────────────────────────────────────────────────────────────────────

## CombatContext — the complete, self-contained input to resolve_hit.
## Everything the resolver needs is here; it reads NO globals. The caller
## (EnemyDirector, Story 009) snapshots StatSystem into caster_stats and injects
## a seeded rng before calling.
class CombatContext extends RefCounted:
	var ability_id: StringName = &""
	var caster: Node2D
	var target: Node2D
	var caster_stats: StatSnapshot
	var target_state: EnemyState
	var rng: RandomNumberGenerator
	var transition_id: String = ""
	var gsm_state: StringName = &""
	var hit_seq: int = 0
	## Loaded from AbilityRegistry by the caller (NOT read from AbilitySystem here).
	var ability_damage_multiplier: float = 1.0


## HitResult — the transient output of resolve_hit. Non-serialized (RefCounted).
## Defaults are the safe-failure values: NORMAL_HIT / NEGLIGIBLE / 0 damage.
class HitResult extends RefCounted:
	var outcome: HitOutcome = HitOutcome.NORMAL_HIT
	var damage_tier: DamageTier = DamageTier.NEGLIGIBLE
	var damage_dealt: int = 0
	var damage_raw: float = 0.0
	var target_hp_after: int = 0
	var is_kill: bool = false
	var overkill_excess: int = 0
	var is_crit: bool = false
	var ability_id: StringName = &""
	var transition_id: String = ""


## StatSnapshot — caster stats captured at cast time. The resolver reads ONLY
## this snapshot, never StatSystem live state (Rule 6).
class StatSnapshot extends RefCounted:
	var attack_power: float = 0.0
	var crit_chance: float = 0.0


## EnemyState — target hp/defense snapshot at cast time. max_hp defaults to 1
## (not 0) so engagement-% derivation never divides by zero downstream.
class EnemyState extends RefCounted:
	var hp: int = 0
	var max_hp: int = 1
	var defense: float = 0.0
	var faction: StringName = &""
	var instance_id: int = 0


## HitResolvedPayload — 12-field broadcast struct (AC-07). EnemyDirector (Story
## 009) builds this from a HitResult and emits it on the `hit_resolved` signal.
## Transient (RefCounted) — NOT persisted, so plain struct (not SerializableResource).
## damage_tier must NEVER be null (FR Test #4) — defaults to NEGLIGIBLE.
class HitResolvedPayload extends RefCounted:
	var ability_id: StringName = &""
	var caster_id: int = 0
	var target_id: int = 0
	var outcome: HitOutcome = HitOutcome.NORMAL_HIT
	var damage_tier: DamageTier = DamageTier.NEGLIGIBLE  # NEVER null
	var damage_dealt: int = 0
	var damage_raw: float = 0.0
	var target_hp_after: int = 0
	var is_crit: bool = false
	var is_kill: bool = false
	var transition_id: String = ""
	var resolved_at_tick: int = 0


# ──────────────────────────────────────────────────────────────────────────────
# Public API — single entry point (Story 003, Rule 2)
# ──────────────────────────────────────────────────────────────────────────────

## resolve_hit — THE single combat entry point (Rule 2 / TR-combat-004).
##
## Synchronous, pure, no await (ADR-0006 Contract 12). Executes the fixed
## 5-stage pipeline (TR-combat-015 / AC-20):
##   Stage 1 — validate (null ctx / dead target / GSM suspended / missing rng)
##   Stage 2 — compute_hit_damage (Formula 1)
##   Stage 3 — roll_crit             (Formula 2 — deterministic sub-seeded crit)
##   Stage 4 — apply_crit_multiplier (Formula 3 — ×1.5 on crit)
##   Stage 5a — detect_overkill (Formula 5 — clamp + overflow on damage_raw)
##   Stage 5b — classify_damage_tier (Formula 4 — ratio-of-max_hp + crit override)
##   → outcome assignment
##
## Stage order is LOAD-BEARING and must not be reordered: validation gates run
## BEFORE any math (Rule 4), crit is rolled before the multiplier is applied, and
## overkill/tier classification runs last on the final damage figure.
##
## Returns a fully-populated HitResult even on the validation-fail paths (safe
## default HitResult), so callers never receive null.
##
## Usage:
## [codeblock]
## var ctx := CombatResolver.CombatContext.new()
## ctx.caster_stats = my_snapshot
## ctx.target_state = enemy_state
## ctx.rng = seeded_rng
## ctx.gsm_state = &"Playing"
## var result := CombatResolver.resolve_hit(ctx)
## [/codeblock]
static func resolve_hit(ctx: CombatContext) -> HitResult:
	# ── Stage 1: Validate (gates fire BEFORE any math — Rule 4) ──────────────
	# Gate ORDER is load-bearing:
	#   1. null ctx        — MUST be first; every later gate dereferences ctx.
	#   2. hit_seq bound    — replay-determinism guard (Story 007 / AC-25).
	#   3. NaN/INF mult     — data-corruption reject BEFORE any math (Story 008 /
	#                         AC-28); placed ahead of the dead-target gate so a
	#                         corrupt multiplier is reported as INVALID_ABILITY_ID
	#                         rather than masked by an incidental dead target.
	#   4. dead target      — already-dead → NORMAL_HIT, zero damage (AC-27).
	#   5. GSM suspended    — no combat while the state machine is suspended.
	#   6. missing rng      — FR-1 requires a caller-injected seeded generator.
	if ctx == null:
		return _null_ctx_result()
	if ctx.hit_seq > MAX_HIT_SEQ:
		push_error("[CombatResolver] hit_seq %d exceeds MAX_HIT_SEQ %d — returning CLAMP_TRIGGERED anomaly result" % [ctx.hit_seq, MAX_HIT_SEQ])
		return _anomaly_result(AnomalyReason.CLAMP_TRIGGERED)
	if is_nan(ctx.ability_damage_multiplier) or is_inf(ctx.ability_damage_multiplier):
		push_error("[CombatResolver] non-finite ability_damage_multiplier (NaN/INF) for '%s' — returning INVALID_ABILITY_ID anomaly result" % ctx.ability_id)
		return _anomaly_result(AnomalyReason.INVALID_ABILITY_ID)
	if ctx.target_state == null or ctx.target_state.hp <= 0:
		return _dead_target_result()
	if ctx.gsm_state == &"Suspended":
		return _suspended_result()
	if ctx.rng == null:
		return _missing_rng_result()

	# ── Stage 2: Base damage (Formula 1) ─────────────────────────────────────
	var base_damage: int = compute_hit_damage(ctx)

	# ── Stage 3: Crit roll (Formula 2 — deterministic sub-seeded Bernoulli) ──
	var is_crit: bool = roll_crit(ctx)

	# ── Stage 4: Crit multiplier (Formula 3 — applied to the float damage) ───
	# Crit scales the pre-clamp damage figure; Formula 5 then rounds + clamps it.
	var damage_raw: float = apply_crit_multiplier(float(base_damage), is_crit)

	# ── Stage 5a: Overkill detect (Formula 5 — clamp damage_dealt at hp) ─────
	var overkill_info: Dictionary = detect_overkill(damage_raw, ctx.target_state.hp)
	var damage_dealt: int = overkill_info["damage_dealt"]
	var overkill_excess: int = overkill_info["overkill_excess"]
	var target_hp_after: int = overkill_info["target_hp_after"]
	var is_kill: bool = overkill_info["is_kill"]

	# ── Stage 5b: Tier classify (Formula 4 — ratio of max_hp + crit override) ─
	var tier: DamageTier = classify_damage_tier(damage_dealt, ctx.target_state.max_hp, is_crit)

	# ── Stage 6: Outcome assignment ──────────────────────────────────────────
	var result: HitResult = HitResult.new()
	result.damage_raw = damage_raw
	result.damage_dealt = damage_dealt
	result.is_crit = is_crit
	result.is_kill = is_kill
	result.overkill_excess = overkill_excess
	result.target_hp_after = target_hp_after
	result.damage_tier = tier
	result.ability_id = ctx.ability_id
	result.transition_id = ctx.transition_id
	result.outcome = _classify_outcome(is_crit, is_kill, overkill_excess)
	return result


## compute_hit_damage — Formula 1 (TR-combat-009 / AC-12 / AC-13).
##
##   base_damage = maxi(1, int(round(attack_power × multiplier − defense)))
##
## The `maxi(1, ...)` floor guarantees every hit deals at least 1 damage even
## against defense ≥ attack (guaranteed-hit rule). `round()` returns float in
## Godot 4.x, so `int(round(...))` is required for an integer result.
##
## Example: attack=100, multiplier=2.0, defense=50 → maxi(1, round(150)) = 150.
## Example: attack=10, multiplier=1.0, defense=100 → maxi(1, round(-90)) = 1.
static func compute_hit_damage(ctx: CombatContext) -> int:
	var raw: float = ctx.caster_stats.attack_power * ctx.ability_damage_multiplier - ctx.target_state.defense
	return maxi(1, int(round(raw)))


# ──────────────────────────────────────────────────────────────────────────────
# Pipeline stage helpers (Stage 3/4/5 — Formula 2/3/4/5, fully implemented).
#
# All four are pure static functions. roll_crit is the ONLY randomised stage and
# it reads EXCLUSIVELY from ctx.rng (caller-injected, seeded) — never the global
# randf() (CI lint: check_combat_resolver_randf).
# ──────────────────────────────────────────────────────────────────────────────

## Stage 3 — roll_crit (Formula 2, FR-1 deterministic crit decision).
##
##   sub_seed = hash("%s:%s:%d" % [transition_id, ability_id, hit_seq])
##   is_crit  = ctx.rng.randf() < ctx.caster_stats.crit_chance
##
## The sub-seed mixes transition_id (FR-1 replay binding) with a per-call
## discriminator (ability_id + hit_seq) so an AOE / multi-hit frame does NOT
## share one rng state and degenerate into all-crit or all-miss. The caller owns
## ctx.rng; we re-seed it from the sub-seed so the same (transition_id, ability_id,
## hit_seq, crit_chance) tuple ALWAYS yields the same is_crit (Rule 1 determinism).
##
## RNG purity: the randf() call is `ctx.rng.randf()` — the injected generator,
## never the global. This file must never call bare randf()/randi() (FR-1).
##
## Example: crit_chance=0.30, sub-seeded rng.randf()=0.18 → 0.18 < 0.30 → true.
static func roll_crit(ctx: CombatContext) -> bool:
	var sub_seed: int = hash("%s:%s:%d" % [ctx.transition_id, ctx.ability_id, ctx.hit_seq])
	ctx.rng.seed = sub_seed
	return ctx.rng.randf() < ctx.caster_stats.crit_chance


## Stage 4 — apply_crit_multiplier (Formula 3, Q-D2 [A] fixed ×1.5).
##
##   post_crit = round(base_damage × (CRIT_MULTIPLIER if is_crit else 1.0))
##
## Operates on the float damage figure; the result stays float so Formula 5 owns
## the final round + clamp. On a non-crit the base damage passes through unchanged.
##
## Example: base 100, crit → round(150.0) = 150.0. base 1, crit → round(1.5) = 2.0.
static func apply_crit_multiplier(base_damage: float, is_crit: bool) -> float:
	if is_crit:
		return round(base_damage * CRIT_MULTIPLIER)
	return base_damage


## Stage 5a — detect_overkill (Formula 5, Q-D7 [A] clamp + expose overflow).
##
## Rounds + floors damage_raw to a min-1 integer, clamps the recorded
## damage_dealt at target_hp, and exposes overkill_excess for the OVERKILL
## outcome + downstream loot/achievement hooks. Conservation invariant holds:
## `damage_dealt + target_hp_after == target_hp`.
##
## is_kill is true iff damage_int >= target_hp (exact-HP hit is a clean KILLED,
## not OVERKILL — overkill_excess is 0 there).
##
## Example: raw=200.0, hp=50 → {dealt:50, excess:150, hp_after:0, is_kill:true}.
## Example: raw=50.0,  hp=50 → {dealt:50, excess:0,   hp_after:0, is_kill:true}.
static func detect_overkill(damage_raw: float, target_hp: int) -> Dictionary:
	var damage_int: int = maxi(1, roundi(damage_raw))
	return {
		"damage_dealt": mini(damage_int, target_hp),
		"overkill_excess": maxi(0, damage_int - target_hp),
		"target_hp_after": maxi(0, target_hp - damage_int),
		"is_kill": damage_int >= target_hp,
	}


## Stage 5b — classify_damage_tier (Formula 4, Q-D4 [B] ratio-of-MAX_HP).
##
##   damage_pct = damage_dealt / max(1, target_max_hp)
##   pct >= T_CRITICAL(0.40) → CRITICAL
##   pct >= T_HEAVY(0.15)    → HEAVY
##   pct >= T_MEDIUM(0.05)   → MEDIUM
##   pct >= T_LIGHT(0.01)    → LIGHT
##   else                    → NEGLIGIBLE
##   if is_crit and tier < HEAVY: tier = HEAVY   # FR Test #4 crit override
##
## Lower-bound comparisons are `>=` inclusive: a hit landing EXACTLY on a
## threshold promotes to the higher tier. max(1, target_max_hp) guards against a
## div-by-zero / negative max_hp (max_hp=1 → any damage ≥ 1 yields pct ≥ 1.0 →
## CRITICAL). The crit override guarantees every crit reads ≥ HEAVY so #6
## ScreenEffects / #5 ParticleSystem fire their heavy-hit presets (FR Test #4).
##
## Example: dealt=18, max_hp=80 → 0.225 → HEAVY.
## Example: dealt=27, max_hp=5000, is_crit → 0.0054 (NEGLIGIBLE) → override → HEAVY.
static func classify_damage_tier(damage_dealt: int, target_max_hp: int, is_crit: bool) -> DamageTier:
	var damage_pct: float = float(damage_dealt) / float(maxi(1, target_max_hp))
	var tier: DamageTier = DamageTier.NEGLIGIBLE
	if damage_pct >= T_CRITICAL:
		tier = DamageTier.CRITICAL
	elif damage_pct >= T_HEAVY:
		tier = DamageTier.HEAVY
	elif damage_pct >= T_MEDIUM:
		tier = DamageTier.MEDIUM
	elif damage_pct >= T_LIGHT:
		tier = DamageTier.LIGHT
	if is_crit and tier < DamageTier.HEAVY:
		tier = DamageTier.HEAVY
	return tier


# ──────────────────────────────────────────────────────────────────────────────
# Private helpers — safe-failure HitResult factories (Story 003)
#
# Each returns a fully-populated default HitResult (NORMAL_HIT / NEGLIGIBLE / 0
# damage / no kill) so resolve_hit never returns null on a validation failure.
# Stories 007/008 extend these with full anomaly-reporting semantics.
# ──────────────────────────────────────────────────────────────────────────────

## Outcome classifier — maps the staged booleans to a HitOutcome. KILLED vs
## OVERKILL is distinguished by overkill_excess; CRITICAL_HIT takes precedence
## only for non-kill crits (Story 005 may refine this precedence).
static func _classify_outcome(is_crit: bool, is_kill: bool, overkill_excess: int) -> HitOutcome:
	if is_kill:
		if overkill_excess > 0:
			return HitOutcome.OVERKILL
		return HitOutcome.KILLED
	if is_crit:
		return HitOutcome.CRITICAL_HIT
	return HitOutcome.NORMAL_HIT


## Generic anomaly result (Story 007/008) — used by the boundary / data-corruption
## reject paths (hit_seq > MAX_HIT_SEQ → CLAMP_TRIGGERED; NaN/INF multiplier →
## INVALID_ABILITY_ID). Returns the SAME safe-default HitResult as the other
## guards: NORMAL_HIT / NEGLIGIBLE / 0 damage / no kill (FR Test #4 — damage_tier
## is NEVER null). `reason` is currently log-only: HitResult deliberately carries
## NO anomaly_reason field (the 12-field HitResolvedPayload contract is fixed), so
## the caller (EnemyDirector, Story 009) derives the anomaly from the call site /
## returned zero-damage metadata and emits combat_metric_anomaly(reason=...).
##
## Usage:
## [codeblock]
## if ctx.hit_seq > MAX_HIT_SEQ:
##     return _anomaly_result(AnomalyReason.CLAMP_TRIGGERED)
## [/codeblock]
static func _anomaly_result(_reason: AnomalyReason) -> HitResult:
	# _reason is intentionally not stored on HitResult (fixed 12-field payload schema); it is
	# logged at the call site (push_error) and the caller emits combat_metric_anomaly from the
	# zero-damage result. A fresh HitResult.new() carries the safe NORMAL_HIT/NEGLIGIBLE defaults.
	return HitResult.new()


## Null-context failure (defensive — should never happen via the normal caller).
static func _null_ctx_result() -> HitResult:
	push_error("[CombatResolver] resolve_hit received null ctx — returning safe NORMAL_HIT result")
	return HitResult.new()


## Dead/invalid target — caster swung at an already-dead target. Story 008 maps
## this to AnomalyReason.DEAD_TARGET_RESOLVE telemetry.
static func _dead_target_result() -> HitResult:
	push_warning("[CombatResolver] resolve_hit on dead/invalid target — returning zero-damage result")
	return HitResult.new()


## GSM is Suspended — combat must not resolve while the game state machine is
## suspended (Rule / AC-31). Story 009 maps this to AnomalyReason.GSM_SUSPENDED.
static func _suspended_result() -> HitResult:
	push_warning("[CombatResolver] resolve_hit while GSM Suspended — returning zero-damage result")
	return HitResult.new()


## Missing injected RNG — FR-1 binding requires a caller-injected rng. Story 008
## maps this to AnomalyReason.RNG_INJECTION_MISSING.
static func _missing_rng_result() -> HitResult:
	push_error("[CombatResolver] resolve_hit missing ctx.rng (caller must inject seeded RNG) — returning safe result")
	return HitResult.new()
