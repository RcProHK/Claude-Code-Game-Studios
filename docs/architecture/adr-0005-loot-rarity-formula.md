# ADR-0005: Loot Rarity Formula

## Status
**Accepted 2026-05-30** — ratified via `/architecture-review` focused ratification. Formula is fully specified, deterministic (RNG seeded on transition_id), and has no ADR dependencies (Depends On: None). Cross-ADR conflict scan clean. Reconciles the prior discrepancy (systems-index marked "Accepted 2026-05-27" while this ADR + technical-preferences still read "Proposed"). #11 Stat System already ships `PR_BASE` as a provisional VS-tier value consuming this formula's contract; retune lands when VS playtest data confirms Q-A1.
*(Previously: Proposed)*

## Date
2026-05-27

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (game balance formula — GDScript math, no engine-API sensitivity) |
| **Knowledge Risk** | LOW — formula uses `float`, `clamp()`, `RandomNumberGenerator` — all stable APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | `RandomNumberGenerator.seed` (stable); GDScript `float` = IEEE 754 double on both native + WASM in Godot 4.6 (verified — no precision concern for threshold comparisons) |
| **Verification Required** | VS-tier: (1) Simulate 1000 workout sessions with varied inputs — verify distribution matches tier intention table; (2) Seed determinism: same `transition_id` → same `rng_roll` → same tier (replay safety); (3) Pillar 3 floor: `workout_completed` always yields ≥ COMMON even at minimum workout (1/5 exercises, no PR, no streak) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (formula defines input contracts; upstream GDDs must satisfy them) |
| **Enables** | #15 Loot Drop System GDD (formula is prerequisite before authoring loot drop math); #8 Streak System GDD (must expose `streak_count` per formula contract); #9 Workout State Tracker GDD (must expose `completed_exercises` + `workout_volume`); #18 PR Detection GDD (must expose `pr_breakthrough_count`) |
| **Blocks** | #15 Loot Drop System GDD authoring — formula contract must be established first to prevent GDD Pillar 1 drift |
| **Ordering Note** | ADR-005 is a prerequisite for #15 GDD. Upstream data systems (#8, #9, #18) must be designed to expose the formula inputs this ADR specifies. |

## Context

### Problem Statement
Mirror Hero's loot drop is the primary DNF dopamine moment (Pillar 3). The rarity formula must be designed to: (1) guarantee that real workout effort drives rarity — no path to top tier without genuine training (Pillar 1 hard constraint); (2) preserve enough RNG surprise to maintain dopamine uncertainty; (3) guarantee any completed workout yields at least Common loot (Pillar 3 ritual guarantee). This ADR resolves game-concept.md Q2 ("Loot rarity 公式具體 weight 點分配？") and locks the anti-Pillar-1 architecture constraint from systems-index.md #15.

### Constraints
- **Pillar 1 hard constraint** (systems-index Anti-Pillar #15): workout signal MUST be primary input (≥0.7 weight); RNG secondary modifier only (≤0.3 weight); no code path may generate a top-rarity item without workout signal in the input
- **Pillar 3 hard constraint**: `workout_completed` signal MUST produce at least one loot item of Common or better — no zero-item outcomes for a completed workout session
- **Anti-Pillar constraints**: loot quality CANNOT be improved by in-game grinding, real-money, or non-resistance-training inputs (cardio, steps, etc.)
- Upstream data systems (#8 Streak, #9 Workout State Tracker, #18 PR Detection) not yet designed — ADR-005 defines the input contract they must satisfy

### Requirements
- Must satisfy WORKOUT_WEIGHT ≥ 0.70 (Pillar 1 anti-drift invariant)
- Must satisfy RNG_WEIGHT ≤ 0.30 (secondary modifier only)
- Must guarantee minimum COMMON rarity for any `workout_completed` (Pillar 3)
- Must be deterministic given a fixed seed (replay safety + test reproducibility)
- Must be data-driven (designer-tunable via exported Resource, not hardcoded)
- Must be computable from data already collected at `workout_completed` event

## Decision

### Loot Rarity Formula (Two-Stage: Score → Floor-Guaranteed Tier)

**Stage 1 — Compute `loot_rarity_score`**:

```gdscript
loot_rarity_score = clamp(
    workout_score * WORKOUT_WEIGHT + rng_roll * RNG_WEIGHT,
    0.0, 1.0
)
```

**Stage 2 — Apply Pillar 3 floor guarantee**:

```gdscript
raw_tier  = tier_from_score(loot_rarity_score)      # may be below COMMON
final_tier = max(raw_tier, RarityTier.COMMON)        # Pillar 3: workout_completed ≥ COMMON always
```

---

### Component Definitions

#### `workout_score` (Pillar 1 signal — drives 0.75 of formula)

```gdscript
workout_score = clamp(volume_factor * pr_factor * streak_factor, 0.0, 1.0)
```

| Factor | Formula | Range | Data source |
|--------|---------|-------|-------------|
| `volume_factor` | `min(1.0, completed_exercises / TARGET_EXERCISES)` | [0.0, 1.0] | #9 Workout State Tracker |
| `pr_factor` | `min(MAX_PR_FACTOR, 1.0 + PR_BONUS_PER_PR × pr_breakthrough_count)` | [1.0, MAX_PR_FACTOR] | #18 PR Detection |
| `streak_factor` | `1.0 + min(streak_count / STREAK_SCALE, MAX_STREAK_BONUS)` | [1.0, 1.0 + MAX_STREAK_BONUS] | #8 Streak System |

**Multiplicative rationale**: multiplying factors means ALL signals must contribute for high `workout_score`. A player who does full volume, breaks a PR, AND maintains streak gets the highest `workout_score`. Missing any factor reduces the score — this naturally enforces Pillar 1 (diverse, real training is rewarded).

#### `rng_roll` (secondary excitement — drives 0.25 of formula)

```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = hash(transition_id)    # deterministic: same workout session → same roll
rng_roll = rng.randf()             # uniform [0.0, 1.0]
```

**Determinism**: seeding on `transition_id` (per ADR-006 Contract 2) ensures the drop is reproducible for forward-recovery and replay testing. Same workout = same tier every time (no re-rolling on page reload).

---

### Tuning Knob Values (all in `LootRarityConfig.tres`)

| Knob | Default | Safe Range | Effect |
|------|---------|-----------|--------|
| `WORKOUT_WEIGHT` | **0.75** | [0.70, 0.85] | Must stay ≥ 0.70 (Pillar 1 invariant). Raising above 0.80 makes RNG feel irrelevant. |
| `RNG_WEIGHT` | **0.25** | [0.15, 0.30] | Must stay ≤ 0.30 (Pillar 1 invariant). Must equal `1.0 - WORKOUT_WEIGHT` (sum to 1.0). |
| `TARGET_EXERCISES` | **5** | [3, 8] | Exercises for `volume_factor = 1.0`. Matches game-concept "5-8 exercises per workout". |
| `PR_BONUS_PER_PR` | **0.12** | [0.08, 0.20] | Per-PR multiplicative bonus. At default: 1 PR → 1.12, 2 PRs → 1.24, capped at MAX. |
| `MAX_PR_FACTOR` | **1.25** | [1.15, 1.40] | Cap on `pr_factor`. Prevents single PR day from guaranteeing top tier. |
| `STREAK_SCALE` | **28** | [14, 60] | Days to reach ~half of MAX_STREAK_BONUS. |
| `MAX_STREAK_BONUS` | **0.20** | [0.10, 0.35] | Maximum `streak_factor` bonus. At 60 days: streak contribution fully maxes. |

**Cross-knob invariant**: `WORKOUT_WEIGHT + RNG_WEIGHT == 1.0` MUST hold (enforced at LootRarityConfig load). CI: assert on load.

---

### Rarity Tier Table (in `LootRarityConfig.tres`)

| Tier | Min Score | Max Score | Color | Typical Condition |
|------|-----------|-----------|-------|-------------------|
| `COMMON` | 0.00 | 0.35 | White | Floor (any workout → Common minimum) |
| `UNCOMMON` | 0.35 | 0.55 | Green | Average workout (3/5 exercises, no PR) |
| `RARE` | 0.55 | 0.72 | Blue | Good workout (4/5 exercises, or streak) |
| `EPIC` | 0.72 | 0.88 | Purple | Great workout (5/5 exercises, streak, avg RNG) |
| `LEGENDARY` | 0.88 | 1.00 | Orange | Outstanding (max workout × max RNG) |

**Tier lookup implementation** (godot-specialist recommendation — data-driven, not if-elif):
```gdscript
func tier_from_score(score: float) -> RarityTier:
    # thresholds sorted ascending in LootRarityConfig.tres
    for i in range(tier_thresholds.size() - 1, -1, -1):
        if score >= tier_thresholds[i]:
            return tier_values[i]
    return RarityTier.COMMON  # fallback (should not reach)
```

**Interval convention**: half-open `[min, max)` for all tiers except LEGENDARY which uses `[0.88, 1.0]` closed.

---

### Worked Distribution Examples

| Scenario | volume | pr_count | streak | workout_score | loot_score (avg RNG 0.5) | Final Tier |
|----------|--------|----------|--------|---------------|--------------------------|------------|
| Minimal (1/5 exercises) | 0.2 | 0 | 0 | 0.20 | 0.20×0.75 + 0.5×0.25 = 0.275 → below Common | **COMMON** (floor) |
| Light (3/5 exercises) | 0.6 | 0 | 0 | 0.60 | 0.45 + 0.125 = **0.575** | RARE |
| Average (4/5, 7d streak) | 0.8 | 0 | 7 | 0.8×1.25 = 1.0→clamp 1.0 | 0.75 + 0.125 = **0.875** | EPIC |
| PR breakthrough (5/5, 1 PR) | 1.0 | 1 | 0 | 1.0×1.12 = 1.12→clamp 1.0 | 0.75 + 0.125 = **0.875** | EPIC |
| Outstanding (5/5, PR, 30d streak) | 1.0 | 1 | 30 | clamp(1.0×1.12×1.20, 0, 1) = **1.0** | 0.75 + 0.5×0.25 = **0.875** | EPIC |
| Perfect + lucky RNG | 1.0 | 1+ | 60+ | 1.0 | 0.75 + 0.9×0.25 = **0.975** | **LEGENDARY** |

**Pillar 1 verification (anti-drift boundary check)**:
- Max RNG alone (workout_score = 0): `0 + 1.0 × 0.25 = 0.25 → below COMMON threshold` — impossible to get ANY tier above Common floor without workout ✓
- Minimum tier without floor: 0.25 < 0.35 → raw_tier = below COMMON → lifted to COMMON by floor guarantee ✓
- Top tier (LEGENDARY) requires score ≥ 0.88 → minimum workout contribution needed = `(0.88 - 0.25) / 0.75 = 0.84` → `workout_score ≥ 0.84` → approximately full exercises + PR or streak required ✓

---

### Data Architecture (godot-specialist recommendation)

Formula parameters stored in exported Resource (not hardcoded):

```gdscript
# res://data/loot_rarity_config.tres
class_name LootRarityConfig extends Resource

@export var workout_weight: float = 0.75
@export var rng_weight: float = 0.25
@export var target_exercises: int = 5
@export var pr_bonus_per_pr: float = 0.12
@export var max_pr_factor: float = 1.25
@export var streak_scale: float = 28.0
@export var max_streak_bonus: float = 0.20
@export var tier_thresholds: Array[float] = [0.0, 0.35, 0.55, 0.72, 0.88]  # ascending
@export var tier_values: Array[int] = [0, 1, 2, 3, 4]  # maps to RarityTier enum

func _validate() -> void:
    assert(abs(workout_weight + rng_weight - 1.0) < 1e-6, "Weights must sum to 1.0")
    assert(workout_weight >= 0.70, "Pillar 1 violation: workout_weight < 0.70")
    assert(rng_weight <= 0.30, "Pillar 1 violation: rng_weight > 0.30")
```

Designer edits `.tres` file in editor; changes take effect without code rebuild.

---

### Input Contract (upstream GDDs must expose these)

| Input | Type | Source GDD | Description |
|-------|------|-----------|-------------|
| `completed_exercises: int` | int | #9 Workout State Tracker | Count of exercises completed this session |
| `pr_breakthrough_count: int` | int | #18 PR Detection & Avatar Progression | Number of PRs hit during this session |
| `streak_count: int` | int | #8 Streak System | Active consecutive-day workout streak at time of `workout_completed` |
| `transition_id: String` | String | #1 GSM (ADR-006 Contract 2) | Transition ID for RNG seeding (determinism) |

---

### Architecture Diagram

```
workout_completed event fires (#1 GSM → #15 Loot Drop System)
         │
         ▼
    LootRarityCalc (owned by #15 Loot Drop System)
         │
    ┌────┼──────────────────────────────────┐
    ▼    ▼                                  ▼
volume_factor  pr_factor  streak_factor   rng_roll
(#9 WST)      (#18 PR)   (#8 Streak)    (RNG.seed=hash(transition_id))
    │    │       │             │               │
    └────┴───────┴─────────────┘               │
              │                                │
        workout_score                          │
      (clamp 0–1)                              │
              │                                │
              └──× 0.75────────+ ──× 0.25──────┘
                                   │
                          loot_rarity_score (0–1)
                                   │
                          tier_from_score()
                                   │
                         max(raw_tier, COMMON)
                                   │
                              final_tier → #21 Loot Drop Modal
```

---

### Key Interfaces

```gdscript
# LootRarityCalc (owned by #15 Loot Drop System)
func compute_rarity(
    completed_exercises: int,
    pr_breakthrough_count: int,
    streak_count: int,
    transition_id: String,
    config: LootRarityConfig = null  # defaults to res://data/loot_rarity_config.tres
) -> RarityTier:
    # Returns final_tier (COMMON minimum guaranteed)

enum RarityTier { COMMON = 0, UNCOMMON = 1, RARE = 2, EPIC = 3, LEGENDARY = 4 }
```

## Alternatives Considered

### Alternative 1: Pure Multiplicative (no additive RNG)
- **Description**: `loot_rarity_score = workout_score` only; RNG used only to pick which item within a tier, not the tier itself
- **Pros**: Strongest Pillar 1 enforcement — tier entirely determined by workout
- **Cons**: Removes the excitement/uncertainty element of "will I get Epic today?"; every workout of same quality always yields same tier — predictable, lower dopamine peaks (Pillar 3 weakened)
- **Rejection Reason**: Pillar 3 requires dopamine uncertainty; predictable tiers reduce daily motivation. Additive RNG at 0.25 weight preserves excitement without breaking Pillar 1.

### Alternative 2: Additive with Raw Score (no floor guarantee)
- **Description**: `final_tier = tier_from_score(loot_rarity_score)` without `max(raw_tier, COMMON)` floor
- **Pros**: More "authentic" — minimal workout might only get Common or nothing
- **Cons**: TD BLOCKING finding: 1/5 exercise completion yields score 0.15 → below Common threshold → NO ITEM. Pillar 3 violation: `workout_completed` must produce at least one loot item
- **Rejection Reason**: Direct Pillar 3 violation. workout_completed = daily guaranteed ritual (game-concept §). Zero-item outcome for any completed workout is forbidden.

### Alternative 3: Separate tier rolls per factor (gacha-style)
- **Description**: Roll separately for volume tier, PR tier, streak tier; take highest
- **Pros**: Each factor feels independently rewarded
- **Cons**: Mathematically equivalent to a more complex version of the current formula; harder to balance; doesn't enforce the Pillar 1 "workout signal as primary" constraint cleanly
- **Rejection Reason**: Current formula is simpler, has mathematically provable Pillar 1 constraint, and can be balanced with two weight parameters.

## Consequences

### Positive
- Mathematical proof that top-tier loot is impossible without workout signal — Pillar 1 architecturally enforced
- Pillar 3 guaranteed: any workout_completed yields ≥ Common (floor mechanism)
- Data-driven via `LootRarityConfig.tres` — designer can tune without code changes
- Deterministic (seeded on transition_id) — consistent across sessions, replay-safe
- Three upstream GDD input contracts defined — #8, #9, #18 authors know exactly what to expose

### Negative
- #8 Streak, #9 Workout State Tracker, #18 PR Detection must be designed before formula can be fully implemented
- `streak_count` behavior during first workout (no prior streak) → streak_count = 0 → streak_factor = 1.0 (no bonus) — acceptable but designers should be aware
- MAX_PR_FACTOR = 1.25 means a single PR barely moves workout_score above 1.0 (gets clamped anyway) — PR breakthrough impact may feel underwhelming without visual emphasis

### Risks
- **Risk 1**: #18 PR Detection takes longer than expected to implement — `pr_breakthrough_count` input unavailable. **Mitigation**: formula accepts `pr_breakthrough_count = 0` gracefully (pr_factor = 1.0); formula is fully functional without PR data
- **Risk 2**: Target exercises calibration — game-concept says "5-8 exercises per typical workout"; if players consistently do 6-7 exercises, volume_factor will saturate at 1.0 frequently. **Mitigation**: `TARGET_EXERCISES` knob adjustable; VS-tier playtest with real GymSys data calibrates this
- **Risk 3**: LEGENDARY feels too rare for retention (if only ~5% of peak workout days hit it). **Mitigation**: tier threshold tuning post-VS-tier playtest; threshold table in .tres file (hot-tunable)

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| systems-index.md (#15 Anti-Pillar constraint) | "Loot quality function MUST take real-PR-signal as primary input (≥0.7 weight); RNG secondary (≤0.3 weight); no code path can generate top-rarity without workout signal" | WORKOUT_WEIGHT = 0.75 ≥ 0.70 ✓; RNG_WEIGHT = 0.25 ≤ 0.30 ✓; mathematical proof in § Worked Examples |
| game-concept.md (§ Session-Level loop) | "Loot rarity 公式：base rarity × (workout volume modifier) × (PR breakthrough modifier) × (streak modifier)" | workout_score = clamp(volume_factor × pr_factor × streak_factor, 0, 1) — direct implementation |
| game-concept.md (§ Core Fantasy, Pillar 3) | "Every workout completion = daily guaranteed drop" | Pillar 3 floor: final_tier = max(raw_tier, COMMON) — guaranteed ≥ COMMON |
| game-concept.md (§ Anti-Pillars) | "NOT 氪金 / in-game currency 加速進度" | Formula has no payment input; RNG seeded on transition_id (not purchasable) |

## Performance Implications
- **CPU**: Formula called once per `workout_completed` event (~once per 60-90 minute session). All operations O(1): 3 multiplications + 2 clamps + 1 randf + 1 linear scan over 5 thresholds. Total: <0.01ms — negligible
- **Memory**: `LootRarityConfig.tres` ≈ 200 bytes; `RandomNumberGenerator` instance allocated per drop, freed after
- **Load Time**: No impact
- **Network**: RNG seed from `transition_id` (already computed) — no additional backend call

## Migration Plan

**ADR-005 is a new ADR.** Applies immediately to #15 Loot Drop System GDD authoring.

**Downstream GDD contracts created by this ADR** (upstream systems must implement):
1. **#9 Workout State Tracker**: Must expose `completed_exercises: int` at `workout_completed` event
2. **#8 Streak System**: Must expose `streak_count: int` (current streak at workout completion time)
3. **#18 PR Detection & Avatar Progression**: Must expose `pr_breakthrough_count: int` (number of PRs this session)

**#15 Loot Drop System GDD**: In Formulas section, cite this ADR and formula directly. Do not re-define the formula — reference ADR-005 as source of truth.

## Validation Criteria
1. Unit test: `compute_rarity(0, 0, 0, "tx_any")` → final_tier = COMMON (Pillar 3 floor with minimum workout)
2. Unit test: `compute_rarity(5, 0, 0, "tx")` × 1000 iterations — distribution: ~0% below Common, majority Uncommon-Rare, <20% Epic, <5% Legendary
3. Unit test: `loot_rarity_score` with `workout_score = 0` → max score = 0.25 < Common threshold (0.35) — raw_tier below COMMON (floor kicks in) → Pillar 1 boundary confirmed
4. Unit test: same inputs + same `transition_id` → always same `rng_roll` → same tier (determinism)
5. Invariant check: `LootRarityConfig._validate()` passes at all tuning-knob safe-range boundaries
6. Formula output: `WORKOUT_WEIGHT + RNG_WEIGHT == 1.0` assertion fires on misconfigured .tres
7. VS-tier playtest: 20+ workout sessions with real GymSys data → validate tier distribution feels "exciting" vs "predictable"

## Related Decisions
- **ADR-006**: State Machine Contract — `transition_id` used as RNG seed (Contract 2); `workout_completed` signal triggers loot roll
- **ADR-002**: GymSys Integration Protocol — `workout_completed` event received from GymSys backend; `completed_exercises` data in poll response
- **systems-index.md Anti-Pillar Constraints #15**: Direct architectural requirement that this ADR formalizes
- **game-concept.md Q2** (resolved): "Loot rarity 公式具體 weight 點分配？" → Answer: WORKOUT_WEIGHT = 0.75, RNG_WEIGHT = 0.25
