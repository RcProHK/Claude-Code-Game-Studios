# Cross-GDD Review Report — 2026-05-27

**Date**: 2026-05-27
**GDDs Reviewed**: 12 (#1, #2, #3, #5, #6, #7, #8, #9, #11, #12, #13, #14)
**Systems Covered**: Foundation 8 + Core 4 (VS tier 11/13 complete — remaining #16 Boss + #26 Avatar Renderer)
**Pillars**: P1 Real Body Real Power / P2 Frictionless Companion / P3 Drop Euphoria / P4 Muscle=Class / P5 Mirror Moment
**Mode**: Inline lean (no spawned agents — Phase 2 leveraged just-completed `/consistency-check` PASS baseline)
**Verdict**: 🟢 **PASS** — 0 blocking, 4 warnings, 3 info items

---

## Scope

GDDs in scope (12 — all Approved status per systems-index 2026-05-27):

| # | System | Tier | Approved |
|---|--------|------|----------|
| 1 | Game State Machine | VS | 2026-05-25 |
| 2 | GymSys Backend Client | VS | 2026-05-26 |
| 3 | PersistenceLayer | VS | 2026-05-26 |
| 5 | Particle System Wrapper | VS | 2026-05-26 |
| 6 | Screen Effects System | VS | 2026-05-26 |
| 7 | Camera System | VS | 2026-05-26 |
| 8 | Streak System | Pre-MVP | 2026-05-26 |
| 9 | Workout State Tracker | VS | 2026-05-27 |
| 11 | Stat System | VS | 2026-05-27 |
| 12 | Ability System | VS | 2026-05-27 |
| 13 | CombatResolver | VS | 2026-05-27 |
| 14 | EnemyDirector | VS | 2026-05-27 |

Out of scope (Not Started — flagged as expected gap):
- VS tier remaining: #16 Boss System, #26 Avatar Renderer
- Pre-MVP: #10 Exercise→Class, #15 Loot Drop, #18 PR Detection, #21 Loot Drop Modal, #27 Onboarding Flow, #28 Telemetry, #33 Attention Budget
- MVP+: #4 Audio, #17 Equipment, #19 Zone, #20-25 Presentation, #29 Mirror Moment

---

## Phase 2 — Consistency

### 2a Dependency Bidirectionality
✅ **All edges verified bidirectional** via systems-index.md + registry referenced_by fields. #9 → #8 stale arrow removed (per /consistency-check 2026-05-27). All 12 GDDs cross-reference correctly.

### 2b Rule Contradictions
✅ **0 conflicts** — verified via just-completed `/consistency-check`. Registry 31 formulas + ~62 constants all align across 12 GDDs.

### 2c Stale References
✅ **0 stale refs remaining** — 4 registry stale entries + 3 GDD internal stale refs (all `transition_id` → `source_key` B-1 cascade) resolved inline 2026-05-27.

### 2d Tuning Knob Ownership
✅ **0 ownership conflicts** — registry `source:` field gives clear ownership boundaries:
- #11 owns stat knobs (MAX_STAT_VALUE, MOVE_CAP, MAX_CRIT_CHANCE)
- #9 owns workout knobs (WORKOUT_SNAPSHOT_TTL_HOURS, DOMINANT_CLASS_CHANGE_COOLDOWN_S, SET_PROGRESS_*)
- #14 owns wave knobs (BASE_SPAWN_INTERVAL, PRE_SPAWN_THRESHOLD)
- ADR-005 owns loot weights (LOOT_WORKOUT_WEIGHT, LOOT_RNG_WEIGHT)
- Cross-system invariants (INV-7 MOVE_CAP=420 shared by #11 + #14) explicit alias documented.

### 2e Formula Compatibility
✅ **All output→input ranges compatible**:
- #11 ATTACK_POWER [1, 4500] → #13 compute_hit_damage domain ✓
- #9 set_progress [0.0, 1.0] → #14 PRE_SPAWN_THRESHOLD=0.8 within domain ✓
- #11 CRIT_CHANCE [0, 0.50] → #13 roll_crit Bernoulli ✓
- #9 total_volume [0, 50000] → ADR-005 normalized volume_factor ✓

### 2f AC Cross-Check
✅ **0 cross-AC contradictions** — INV-7 (#11 MOVE_CAP = #14 ENEMY_MOVE_CAP = 420) explicit; INV-1 (#13 CRIT_MULTIPLIER × #11 MAX_CRIT_CHANCE ≤ 0.75) explicit.

### Consistency Warnings

⚠️ **C-1 — #8 / #9 sibling-consumer subscription order**
- `streak-system.md` + `workout-state-tracker.md` 都獨立 subscribe `#2.GymSysClient.workout_completed`
- 將來 `#15 Loot Drop` 設計時若依賴「streak milestone fired 之前 workout summary 已 available」會出 race
- **Resolution**: defer 至 #15 GDD authoring，#15 owns subscription order contract
- **Priority**: Info — already flagged in #9 Section F bidirectional sync gap

⚠️ **C-2 — #9 EC-37 referencing #2 GymSysClient signal buffer location**
- `workout-state-tracker.md` EC-37 寫：「resume 期間 incoming signals 入 #2 buffer」
- `gymsys-backend-client.md` 有 `_committed_transitions` FIFO (50 entries) 但只 cover loot signals，workout signals buffer 未明確
- **Resolution**: #2 next-revision batch 補一條 forward constraint「workout signal buffer during downstream INITIALISING」
- **Priority**: Advisory follow-up

---

## Phase 3 — Game Design Holism

### 3a Progression Loop Competition
✅ **Single primary loop** — 唔 competing：real workout → PR detection (#18 future) → stat increase (#11) → ability unlock (#12) → in-game progression. 所有 system 都係 sequenced support、唔 parallel-compete。

### 3b Player Attention Budget
✅ **Pillar 2 architecturally enforced**：
- WorkoutActive state: `is_input_permitted()` = false → 0 active systems
- RestPeriod: brief interactions only
- WorkoutComplete: loot drop modal + character screen (max 2 concurrent)
- #33 Attention Budget & Interaction Policy owns enforcement via `is_input_permitted_api`
- ✓ 完全在 ≤4 active systems limit 內

### 3c Dominant Strategy Detection
- Class identity 明確分工：STRIKE=damage king (STR scaling) / CONTROL=utility (DEX crit+move) / MOBILITY=tanky (VIT HP)
- INV-4 (#11 ATK_PER_DEX < ATK_PER_STR × 0.5) hardlocks STR damage dominance
- 見 D-1 below for DEX-asymmetry caveat。

### 3d Economic Loop Analysis
✅ **Currency-less by design** — Mirror Hero 冇 in-game gold/XP grind。Stats only grow via real PR_BREAKTHROUGH + VOLUME_TICK。
- Anti-snowball: PR_DIMINISH_EXP=2.0 (current_stat=MAX → δ=0), MAX_PR_FACTOR=1.25, MAX_STREAK_BONUS=0.20
- Hardcap: MAX_STAT_VALUE=999 ~1-2 year hardcore reach
- ADR-005 Pillar 1 anti-fabrication math proof: max RNG-only = 0.25 < EPIC=0.72

### 3e Difficulty Curve Consistency
- Player stat growth: PR-driven (irregular, real-world capped)
- Enemy scaling: **Not yet designed** (#14 has BASE_SPAWN_INTERVAL but no HP/damage curve; owned by #16 future GDD)
- 見 D-2 below。

### 3f Pillar Alignment
✅ **5/5 pillars 有 PRIMARY substrate**：
- P1 → anti-fabrication chain quintet (#2 + #3 + #11 + #14 + #9 全部 Approved)
- P2 → #33 (future) + #1/#9 architectural support (sub-500ms boss anchor, frictionless input gating)
- P3 → #15 (future) + #14 enemy_killed.transition_id chain (Approved input)
- P4 → #9 dominant_class derivation ✓ Approved + #12 Ability System ✓ Approved
- P5 → #29 (future)

所有 12 個 Approved GDD 都有 explicit `Implements Pillar:` header line。零 pillar drift。

### 3g Player Fantasy Coherence
✅ **Cohesive identity** — 「real-body warrior, gym→game bridge」across all 12 GDDs:
- #1 GSM: ms-scale temporal continuity
- #5 Particles: peripheral visual sensation
- #6 ScreenFX: peripheral kinaesthetic sensation
- #7 Camera: "Silent Showrunner" spatial framing
- #8 Streak: cross-day temporal accumulation
- #9 WST: 「肌群預言家 / The Muscle Oracle」 (Pillar 4 substrate)
- #11 Stat: anti-fabrication trio
- #12 Ability: Pillar 4 mechanical home
- #13 Combat: 「DNF 重擊指揮家」(Pillar 3)
- #14 EnemyDir: 「無形軍師」(Pillar 2 protector)

Foundation tier extended to 9-way vocabulary partition documented in #9 Section B。

### Design Theory Warnings

⚠️ **D-1 — Class stat-derivation asymmetry (DEX = 3 derived stats; STR/VIT = 1 each)**
- `stat-system.md` Formula 4-6：DEX 拎 ATK minor + MOVE_SPEED + CRIT_CHANCE 三項 derived effects；STR 只拎 ATK；VIT 只拎 MAX_HP
- **Counter-protection**: ATK_PER_DEX=0.3 < ATK_PER_STR × 0.5 = 0.75 (INV-4) — STR 仍係 raw damage king，DEX 嘅 crit + move 屬 utility identity
- **Concern**: Pillar 4 fairness perception — pull-day 玩家可能感覺「DEX = 多 reward」即使 raw damage 唔贏
- **Resolution**: 留俾 VS-tier `#9 FR-1` blind A/B playtest (n≥8 covering all 4 class types) 驗證；如 evidence 顯示 perceptual imbalance，retune ATK_PER_DEX / HP_PER_VIT
- **Priority**: Warning — flag for VS-tier playtest evidence

⚠️ **D-2 — Enemy difficulty scaling curve 未鎖定 (expected gap)**
- `#14 enemy-director.md`：spawn cadence 4Hz lock；enemy HP / damage 隨 progression scaling 未 design
- `#11 stat-system.md`：player stat growth PR-driven (irregular)
- **Risk**: 若 #16 將 enemy scaling 設成 exponential 而 player stat 線性，late-game inaccessibly difficult
- **Mitigation**: 屬 #16 Boss System (Not Started) authoring scope；#11 CF-1 baseline (4-5 hit survival vs starter mob) 已 lock baseline
- **Priority**: Info — expected gap

---

## Phase 4 — Cross-System Scenario Walkthrough

5 scenarios walked end-to-end:

### Scenario 1: `workout_completed` cascade
**Chain**: #2 GymSys poll → workout_completed signal → #8 Streak + #9 WST (sibling consumers) → #14 boss anchor commit → #15 LootDrop (future) RNG seed via transition_id

✅ #9 Rule 10 explicit emission order: phase_changed → workout_summary_available → workout_completed_forwarded → persistence → call_deferred(IDLE)
⚠️ See C-1 above (sibling-consumer order owned by future #15)

### Scenario 2: bfcache resume mid-workout
**Chain**: iOS Safari freeze 30s+ → pageshow → autoload re-boot sequential (#3 → #1 → #2 → ... → #9) → snapshot hydrate → set_progress recompute → #14 4Hz perception tick reads stable values

✅ #9 Rule 12 + #2 Rule 14 + ADR-006 Contract 6 (`connect_for_initial_state`) cover full handshake
✅ 24h TTL prevents stale resume (#9 EC-10/26)
⚠️ See C-2 above (workout signal buffer location in #2 unclear)

### Scenario 3: Boss anchor pre-spawn + commit race
**Chain**: #9 set_progress_changed(0.82) → #14 PRE_SPAWN state → 30s 後 #2 workout_completed → #9 transition_id acquire → #14 COMMITTED → boss visible

✅ FR Test #2 sub-500ms p95 covered (#9 AC-41)
✅ #14 fallback heuristic (reps × 0.5) when set_progress unreliable per CI-2

### Scenario 4: `poll_failed` during SET_ACTIVE → SUSPENDED → `poll_recovered`
**Chain**: GymSys offline → #9 _is_frozen=true → tab switches → #1 GSM Suspended → #9 SUSPENDED drops events → tab returns → READY → poll_recovered → _is_frozen=false → backfill processes

✅ #9 EC-12 explicit orthogonal frozen + suspended flag handling
✅ #2 backfill mechanism preserves Pillar 3 loot integrity (EC-11 AC-34)
✅ Pillar 1 anti-fabrication preserved during frozen window

### Scenario 5: First-boot fresh user (no history)
**Chain**: cold start → #11 default stats (STR=DEX=VIT=10) → #12 3× TIER_1 abilities auto-unlock (CF-1) → first workout → first set_logged → first stat update → first loot drop modal

✅ Pillar 1 anti-fabrication holds (no stat without real workout)

#### Scenario Warnings

⚠️ **S-1 — First-boot multi-event cluster on first workout_completed**
- 4 同時 events: 3× ability unlock + first stat update + first loot drop + first dominant_class derive
- **Mitigation**: `#27 Onboarding Flow` (Pre-MVP, Not Started) sequence events
- **Resolution**: defer 至 #27 authoring
- **Priority**: Info — owned by #27

#### Scenario Info

ℹ️ **S-2 — Autoload boot order tightly coupled to ADR-006 Contract 4**
- 12 positions sequential; ADR-006 Contract 6 sentinel protects against reshuffling
- Flag for `/create-architecture` phase — boot ordering will need explicit ADR validation

ℹ️ **S-3 — `enemy_killed.transition_id` 4-hop chain for #15 LootDrop seeds**
- Chain: #1 GSM → #9 acquire on workout_completed → #14 propagate via enemy_killed → #15 RNG seed
- Pillar 1 anti-fabrication quintet already covers integrity
- #15 authoring time verify chain end-to-end

---

## GDDs Flagged for Revision

✅ **None require revision.** 全部 12 Approved GDDs internally consistent + cross-coherent。

| Tracking ID | Issue | Type | Owner | Resolution Path |
|-------------|-------|------|-------|-----------------|
| C-1 | #8/#9 sibling subscription order | Consistency Info | #15 (future) | Defer to #15 authoring |
| C-2 | #2 signal buffer forward constraint | Consistency Advisory | #2 next-revision batch | #2 GDD update |
| D-1 | DEX class derivation asymmetry | Design Warning | Playtest evidence | VS-tier FR-1 blind A/B (n≥8) |
| D-2 | Enemy scaling curve gap | Design Info | #16 (future) | Defer to #16 authoring |
| S-1 | First-boot event cluster | Scenario Info | #27 (future) | Defer to #27 authoring |

---

## Verdict: 🟢 **PASS**

- **0 Blocking** consistency or design theory issues
- **2 Consistency warnings** (C-1, C-2) — all owned by future GDD authoring; do NOT block architecture
- **2 Design theory warnings** (D-1 deferred-to-playtest, D-2 expected-gap)
- **3 Scenario info items** — full mitigation paths exist
- **Anti-fabrication chain quintet** (#2 + #3 + #11 + #14 + #9) complete + architecturally enforced
- **Pillar coverage**: 5/5 pillars 有 PRIMARY substrate (Approved or pending future GDDs)

VS-tier GDD set (11/13 — 缺 #16 Boss + #26 Avatar Renderer) architecturally sound + cross-coherent。

**Architecture-readiness**: PASS gate criterion satisfied for current Approved GDD scope。`/create-architecture` 可以 proceed once #16 + #26 Approved (VS-tier 100% complete) — current 92% complete (12/13 VS systems if exclude #16 Boss which is Feature-layer 屬於 Core layer 完成後 cross-layer review)。

Note: Per systems-index.md "Recommended Design Order" VS tier list, the VS milestone requires 13 GDDs including #16 Boss + #26 Avatar Renderer. Continue `/design-system` for remaining systems before `/create-architecture` final gate.
