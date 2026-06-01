# Systems Index: 鏡像勇者 (Mirror Hero)

> **Status**: Draft (pending CD-SYSTEMS gate)
> **Created**: 2026-05-25
> **Last Updated**: 2026-05-27
> **Source Concept**: design/gdd/game-concept.md
> **Engine**: Godot 4.6 + Web Export (HIGH knowledge-gap risk)

---

## Gate History

| Gate | Verdict | Date | Resolution |
|------|---------|------|------------|
| **TD-SYSTEM-BOUNDARY** | CONCERNS | 2026-05-25 | Resolved: (1) Streak promoted Polish → Foundation to fix inverted dep; (2) Combat Resolution split into CombatResolver + EnemyDirector; (3) Save State renamed PersistenceLayer. |
| **PR-SCOPE** | UNREALISTIC | 2026-05-25 | Resolved: Adopted 6-tier with Pre-MVP slot (Pre-MVP @ Month 4 = hypothesis test, full MVP @ Month 7-9). Producer timeline rebase ×1.6 acknowledged. |
| **CD-SYSTEMS** | CONCERNS | 2026-05-25 | Resolved: (1) Added #33 Attention Budget & Interaction Policy to Pre-MVP for Pillar 2 enforcement; (2) Promoted Mirror Moment from v0.2 to MVP as minimum-viable (screenshot-only) scope; (3) Annotated #15 with loot RNG anti-pillar constraint; (4) Annotated #19 with zone-unlock anti-pillar constraint. CD's "telemetry missing" concern was a misread — #28 Telemetry was already at Pre-MVP. |

---

## Overview

Mirror Hero 係 2D side-scrolling action RPG，玩家嘅真實 gym 訓練數據驅動 in-game avatar 嘅力量。Game 喺 workout 期間 background auto-play，每完成一個動作 = 切換下一個關卡 = 玩家唯一輸入。

系統設計反映 5 條 game pillars：
- **Pillar 1 (Real Body, Real Power)** → PR Detection & Avatar Progression (#18) 鎖住
- **Pillar 2 (Frictionless Companion)** → Gym-Mode HUD (#20) 同 input minimization
- **Pillar 3 (Drop Euphoria)** → Loot Drop System (#15) + Loot Drop Modal (#21) signature ritual
- **Pillar 4 (Muscle = Class)** → Exercise → Class Mapping (#10) 同 Ability System (#12)
- **Pillar 5 (Mirror Moment)** → Mirror Moment System (#29) at v0.2+

技術上嘅最大 driver：**Godot 4.6 + Web Export + GymSys backend integration**。Foundation layer 有 8 個系統（多過正常嘅 3-5）係因為 Web Export 同 mobile Safari 強迫多 infra（GPU particles, mobile fallbacks, polling layer, audio unlock）。

---

## Systems Enumeration

| # | System Name | Layer | Tier | Status | Design Doc | Depends On |
|---|-------------|-------|------|--------|------------|------------|
| 1 | Game State Machine | Foundation | VS | **Approved 2026-05-25** (Pass 5 lean re-review) — 5 passes total; final verdict APPROVED with 0 blocking + 3 advisory; all 15 ADR-006 Contracts + 5 Decisions traced into prose + 45 ACs | [game-state-machine.md](game-state-machine.md) | (none) |
| 2 | GymSys Backend Client | Foundation | VS | **Approved 2026-05-26** (Pass 2 lean re-review) — 2 passes total; Pass 1 NEEDS REVISION (7 P0 from 5 specialists + CD synth), all resolved same session; Pass 2 lean: 0 blocking + 4 advisory resolved (AC-28 count 13→18, 3 undeclared signals declared, Rule 11.1 latch-200 clarified, 429+Draining edge case added); 18 signals, 6 substates, 31 ACs + CI static checks; CD-CASCADE-A/B/C flagged to ADR-002 ratification gate; inherits ADR-006 Contracts 2/4/5/11/15; ADR-002 input scope | [gymsys-backend-client.md](gymsys-backend-client.md) | (none) |
| 3 | PersistenceLayer (renamed from Save State per TD) | Foundation | VS | **Approved 2026-05-26** (Pass 2 lean re-review, fresh session) — 2 passes total; Pass 1 MAJOR REVISION NEEDED (7 blockers resolved same session); Pass 2 lean: 1 blocking (AC-03 missing flush=true on critical path) resolved inline → APPROVED; 13 Rules + 4 substates + 32 ACs; 1 owned formula `is_expired` (Contract 9); 4 owned knobs; ADR-006 Contracts 3/4/9/10/11/14 inherited; ADR-003 input scope; 4 advisory items deferred (stale knob derivation text, touch() absent-key edge case, AC-09 label, migrate() external AC); Q-X12/X13/X14/X15 open (gate to #24 GDD + ADR-003) | [persistence-layer.md](persistence-layer.md) | (none — Foundation leaf) |
| 4 | Audio Manager | Foundation | MVP | **Designed (pending review)** 2026-06-01 — lean pass, no specialist agents; 8 required + Visual/Audio + UI + 6 Open Questions; Q5 ADR-0008 BLOCKING stories | [audio-manager.md](audio-manager.md) | 1, 3 |
| 5 | Particle System Wrapper | Foundation | VS | **Approved 2026-05-26** (CD-GDD-ALIGN passed full mode, single pass) — re-review 2026-05-26 lean: 1 blocking resolved (Rule 5 `_select_tier()` LOOT→LARGE tier routing fix), 2 advisory resolved (Rule 15 Suspended note + section header); 16 Rules + 4 states + 3 formulas + 19 edge cases (incl. 2 ACCEPTED Rule 11/Rule 6 amendments) + 16 knobs + 27 ACs (23 BLOCKING + 4 ADVISORY incl. 3 ADR-001 ratification-gated) + 9-preset Visual Spec Table + audio direction co-trigger contract + 7 Open Questions; 1 formula + 4 constants registered in entities.yaml; ADR-001 input scope (FR-1/2/3 ratification gate-binding); inherits ADR-006 Contract 6 (`connect_for_initial_state` GSM subscription) | [particle-system-wrapper.md](particle-system-wrapper.md) | (none) |
| 6 | Screen Effects System | Foundation | VS | **Approved 2026-05-26** (CD-GDD-ALIGN passed full mode, single session, single pass) — paired sensation infrastructure with #5 (#5 owns 視覺 channel, #6 owns 體感 channel); 16 Rules + 4 states + 6 interactions + 3 formulas (Trauma² decay + additive combiner + pause max-remaining) + 19 edge cases + 9 knobs (1 player-facing motion_intensity a11y slider) + 29 ACs (25 BLOCKING + 1 ADVISORY + 3 ADR-001 RATIFICATION-GATED FR-1/FR-2/FR-3) + 6-subsection Visual/Audio (4 active preset feel spec table + audio direction full-duck recommendation) + UI Requirements (motion_intensity slider UX Flag for #22) + 7 Open Questions (Q-F1..Q-F5 + Q-V1..Q-V2); 3 formulas + 7 constants registered in entities.yaml; ADR-001 input scope (FR-1/2/3 ratification gate-binding); inherits ADR-006 Contract 6 (`connect_for_initial_state` GSM subscription) + Contract 4 (autoload sequential `_ready`); CD assessment: "達到 #5 確立嘅 strongest pillar-coherent GDD to-date precedent"; 8 CD findings (4 ALIGN + 4 ADVISORY); paired sensation infrastructure template now established (#5 + #6) | [screen-effects-system.md](screen-effects-system.md) | (none — subscribes to #5 burst_started + #1 state_changed) |
| 7 | Camera System (inferred) | Foundation | VS | **Approved 2026-05-26** (Pass 4 lean re-review — 4 items patched; Pass 3 full adversarial: 5 specialists + CD synthesis, 7 BLOCKING + accessibility fix; 17 total patches across 4 review passes; CD-GDD-ALIGN priorly passed full mode); "Silent Showrunner" indirect fantasy framing; 14 Rules + 4 states + 5 formulas + 24 edge cases + 9 knobs + 36 ACs (32 BLOCKING + 1 ADVISORY + 3 ADR-001 RATIFICATION-GATED); ADR-001 input scope (FR-1/2/3 gated); inherits ADR-006 Contract 4 + 6; decoupled from #6 via CI Rule 13; see [reviews/camera-system-review-log.md](reviews/camera-system-review-log.md) | [camera-system.md](camera-system.md) | (none — subscribes to #1 state_changed) |
| 8 | Streak System (promoted Polish→Foundation per TD) | Foundation | Pre-MVP | **Approved 2026-05-26** (CD-GDD-ALIGN passed full mode, single session, single pass — "sets a new bar for Foundation-tier GDD rigor"); 14 Rules + 5 states + 7 interactions + 3 formulas + 22 edge cases + 8 owned knobs + 33 ACs (28 BLOCKING + 2 ADVISORY + 3 ADR-003 RATIFICATION-GATED FR-1/FR-2/FR-3) + 7 Open Questions; 9 ALIGN + 2 ADVISORY + 0 BLOCKING CD findings; Pillar 1 primary (**4-layer architectural defense**: closed API + CI mutator ban + CI caller whitelist + namespace isolation); Pillar 3/5 supporting; Foundation tier fantasy vocabulary partition extended to 5-way (#1 ms-scale temporal continuity + #5 peripheral visual + #6 peripheral kinaesthetic + #7 spatial framing + **#8 cross-day temporal accumulation**); novel ADR-RATIFICATION-GATED AC class introduced (AC-37/38/39 gated on ADR-003); first cross-system consumer of `streak.*` PersistenceLayer namespace; ADR-003 input scope (FR-1 retro-credit + FR-2 drift FPR + FR-3 caller whitelist); inherits ADR-006 Contract 6 + Contract 9; 1 constant (`milestone_thresholds`) registered in entities.yaml; Streak added as referrer to existing `wall_clock_drift_tolerance_seconds` constant | [streak-system.md](streak-system.md) | 3 |
| 9 | Workout State Tracker (inferred) | Core | VS | **Approved 2026-05-27** (full mode single-pass — CD-GDD-ALIGN APPROVED with 8 ALIGN + 3 ADVISORY + 2 CONCERN inline-fixed same-session + 0 BLOCKING; CD assessment "Mirror Hero pre-production 至今最 architecturally sound 嘅 GDD"); 16 Core Rules + Rule 11.1 (workout_id defensive monotonicity for Q-X2) + 5 WorkoutPhase states (IDLE/WARM_UP/SET_ACTIVE/REST_PERIOD/WORKOUT_COMPLETE) + 3 Substates (INITIALISING/READY/SUSPENDED) + Frozen orthogonal flag + 10-row Interactions table + 4 formulas (set_progress derivation full-data + estimated paths / EWMA historical_avg / dominant_class set-count weighted / total_volume aggregation) + 37 ECs across 9 categories (9 CRITICAL + 13 HIGH + 11 MEDIUM + 4 LOW) + 11 owned knobs + 5 referenced knobs + 8 cross-knob INVs + 43 ACs (41 BLOCKING + 1 ADVISORY AC-40 playtest + 1 ADR-RATIFICATION-GATED AC-37) + 6 Open Questions (4 Q-X cross-system + 2 Q-A ADR-gated); Pillar 4 (Muscle = Class) PRIMARY substrate via「肌群預言家 / The Muscle Oracle」framing + Pillar 1 (Real Body, Real Power) supporting (anti-fabrication chain 第五件套 — #2 + #3 + #11 + #14 + #9 complete) + Pillar 2 (Frictionless Companion) supporting (sub-500ms boss anchor enabling via set_progress); ADR-002 input scope (7 #2 signal contract honored); ADR-003 input scope (`wst.*` namespace first adopter); ADR-005 input scope (provides completed_exercises_count for volume_factor — CI-5); ADR-006 inherits Contract 4 (autoload boot position 5) + Contract 6 (`connect_for_initial_state` helper) + Contract 9 (drift-tolerant is_expired for snapshot TTL) + Contract 2 (acquire_transition_id for workout_completed); 3 formulas + 4 constants + 2 enums + 1 signal contract registered in entities.yaml; 8 existing entries actualized with #9 as referrer (gymsys_client_signal_contract / state_changed_signal_signature / exercise_target_count / loot_rarity_score / volume_tick_delta / pre_spawn_threshold / boss_pre_spawn_trigger / actual_spawn_interval); systems-index dep arrow #9 → #8 flagged for removal (Section F clarification — actually sibling consumers of #2 workout_completed); 8 followup-tracked items (WST-AC-followup-01..08) including CD F-9 ADR-0007 class enum naming convention pre-VS-tier kickoff + CD F-12 bodyweight handling refinement pre-#15 hero-visual + CD F-13 immediate-poll-on-resume next-revision for #2 | [workout-state-tracker.md](workout-state-tracker.md) | 2, 3 (#8 dep removed — confirmed sibling consumers of #2, no direct call; /design-review 2026-05-27) |
| 10 | Exercise → Class Mapping | Core | Pre-MVP | Not Started | — | 3 |
| 11 | Stat System (inferred) | Core | VS | **Approved 2026-05-27** (Pass 2 lean re-review — 2 passes total; Pass 1 NEEDS REVISION: B-1 Formula 1 output range math error + B-2 session accumulation value incorrect, resolved same session with 7 patches; Pass 2 lean: 0 blocking + 0 advisory — APPROVED); 16 Rules + 4 substates (Initialising / Ready / Suspended / Reconciling) + 11 interactions + 6 formulas (V_TICK + PR_BREAKTHROUGH provisional + 4 derived) + 37 edge cases + 15 owned knobs + 4 cross-formula invariants + 9 cross-knob INVs (INV-7 PENDING Q-X4) + 37 ACs (24 BLOCKING + 10 ADVISORY + 3 ADR-RATIFICATION-GATED) + 8 Open Questions; Pillar 1 anti-fabrication trio member (paired with #2 GymSys + #3 PersistenceLayer); first Core-tier registration in entities.yaml; inherits ADR-003 (`stat.*` namespace) + ADR-006 Contracts 3/4/6 + ADR-005 (Accepted 2026-05-27 per registry — `PR_BASE` PROVISIONAL pending Q-A1); bidirectional sync gap flagged to #1 GSM + #3 PersistenceLayer for next-revision batch | [stat-system.md](stat-system.md) | 3 |
| 12 | Ability System | Core | VS | **Approved 2026-05-27** (Pass 2 lean re-review — 2 passes total; Pass 1 NEEDS REVISION: B-1 ability_cast signal damage param 冇 ownership + B-2 PR_BREAKTHROUGH caller path contradiction (Rule 3 vs Rule 7), resolved same session with 7 patches; Pass 2 accepted revisions — APPROVED); 16 Rules + 4 substates (Initialising / Ready / Suspended / Reconciling) + 11 interactions + 3 formulas (TIER_THRESHOLDS data-driven lookup + BASE_COOLDOWN_SEC fixed-per-tier + UNLOCK_EVENT_PRIORITY deterministic sort) + 39 edge cases + 8 owned knobs + 3 cross-formula invariants + 8 cross-knob INVs + 33 ACs (30 BLOCKING + 3 ADR-RATIFICATION-GATED) + 7 Open Questions; Pillar 4 primary substrate (Class-tiered unlock architecture: #10→#11→#12); signal subscription pattern confirmed for PR_BREAKTHROUGH path (unlock_ability caller whitelist = ability_system.gd only); ability_cast signal damage-free (B-1 fix — #13 owns combat math post-signal); 第二個 Core-tier entity registration in entities.yaml (3 formulas + 14 constants); inherits ADR-003 (`ability.unlocked.*` namespace) + ADR-006 Contracts 3/4/6; provisional dependency on #10 (Not Started — FR-1 binding); bidirectional sync gap flagged to #1 GSM + #3 PersistenceLayer + #11 Stat System for next-revision batch | [ability-system.md](ability-system.md) | 10, 11 |
| 13 | CombatResolver (split from Combat per TD) | Core | VS | **Approved 2026-05-27** (full mode Pass 2 — Pass 1 CD-GDD-ALIGN CONCERNS 4 CONCERN + 3 ADVISORY resolved inline same-session); 17 Rules + States as input-driven variation table + 11-row Interactions + 5 formulas + 50 ECs (10 categories) + 11 owned knobs + 1 data-driven knob (AbilityRegistry.tres) + 8 cross-knob invariants + 37 ACs (30 BLOCKING + 6 ADVISORY + 1 ADR-001 RATIFICATION-GATED) + 12 OQs (with Q-EnemyDirector-Contract upgraded to Risk Register FR-4); CD assessment "strongest pillar-coherent GDD to-date among Approved Core-tier set (#11, #12, #13)" + establishes 5 cross-system template patterns; Pillar 3 primary substrate (DNF重擊指揮家) + Pillar 4 supporting + Pillar 1 supporting (4th anti-fabrication quartet member) + Pillar 2 protection (receptive contract via stateless pure-function architecture); 4-layer CI lint defense (purity / autoload / engine-singleton-ref / randf-ban); ADR-001 input scope (FR-3 CPU 1.0ms budget binding); ADR-005 input scope (FR-2 enemy_killed transition_id → #15 LootDrop chain binding); ADR-006 inherits Contract 6 (subscription via EnemyDirector); 5 formulas + 16 constants (11 knobs + 3 signal signatures + 2 enums) registered in entities.yaml; 3 #11 entries updated with #13 as actual referrer | [combat-resolver.md](combat-resolver.md) | 11, 12 |
| 14 | EnemyDirector (split from Combat per TD) | Core | VS | **Approved 2026-05-27** (full mode single-pass — CD-GDD-ALIGN APPROVED first attempt with 10 ALIGN + 2 ADVISORY + 0 CONCERN + 0 BLOCKING findings); CD assessment "Strongest pillar-architecture coupling among Approved Core-tier set (#11 → #12 → #13 → #14)" + establishes 6 new cross-system template patterns (caller-side state owner architecture / architecture-as-narrative framing / quartet anti-fabrication chain extension trio→quartet→quintet / pre-spawn + late commit pattern / cross-knob INV table with violation-flag mechanism / forward constraint table for downstream contracts); 18 Core Rules + Wave Archetype Spec (3-class STRIKE/CONTROL/MOBILITY × 3-tier curve) + States and Transitions (6 substates Booting/Idle/WaveActive/BossEncounter/CatchingUp/Suspended) + 11-row Interactions (14 systems) + 12-layer CI Lint Suite + 6 formulas + 42 ECs (11 categories) + 17 owned knobs + 5 data-driven archetype knobs + 8 cross-knob INV (INV-8 inline-fixed DODGE_AMPLITUDE_PX 50→30) + 38 ACs (31 BLOCKING + 5 ADVISORY + 2 ADR-RATIFICATION-GATED) + 15 OQs (12 net new + 3 inherited from #13); Pillar 2 (Frictionless Companion) PRIMARY protector via「無形軍師」5-obligation framing — Pillar 3 (Drop Euphoria) PRIMARY substrate via `enemy_killed.transition_id` chain seed binding — Pillar 4 (Muscle = Class) supporting via data-driven wave archetype selection — Pillar 1 (Real Body, Real Power) supporting via anti-fabrication quartet 第四件套 (orchestration discipline guarantor); ADR-001 input scope (FR-4 mobile particle floor + 0.5ms p95 orchestration CPU budget binding); ADR-002 input scope (catch-up backlog cadence bound by 5s polling); ADR-005 input scope (FR-2 `enemy_killed.transition_id` → #15 LootDrop chain binding); ADR-006 inherits Contract 2 (transition_id atomicity) + Contract 4 (sequential autoload boot #14 LAST) + Contract 6 (`connect_for_initial_state` helper); 6 formulas + 13 constants + 3 enums (Faction / EnemyAIState / BossAnchorState) registered in entities.yaml; 3 #13 signal signature entries (hit_resolved / enemy_killed / combat_metric_anomaly) updated with #14 as actual emitter referrer (per #13 Rule 3 EnemyDirector owns signal emission); 9 cross-system forward constraints flagged for #9/#15/#16/#17/#28 GDD authoring | [enemy-director.md](enemy-director.md) | 5, 6, 7, 13 |
| 15 | Loot Drop System ⚠️ | Core | **VS** (upgraded from Pre-MVP 2026-05-27 per #16 /design-review CRIT-5) | **Pass 2 Revised 2026-05-28** — Pass 1 inline same-session APPROVED retrospectively rescinded by Pass 2 fresh-session /design-review re-review (MAJOR REVISION NEEDED, 8 BLOCKING F-1..F-8 convergent across 4 specialists)。Pass 2 inline-fixed all 8 BLOCKING per user autonomous mode + 4 followup-tracked (F-9..F-12)。Pass 2 key changes: (F-1) Rule 7.5 NEW workout_id resolution via `WorkoutStateTracker.get_active_workout_id()` with explicit null branch — closes UNANIMOUS signal payload schema gap (systems B1 + qa-lead AC-06); (F-2) ceremony cap split MINI_BOSS_CEREMONY_CAP=5 + FINAL_BOSS_RESERVED=1 — final boss ceremony guaranteed, restores P3 PRIMARY substrate; (F-3) NEW micro_ack ceremony tier — mini-boss #6 acknowledged via 0.15s toast + mailbox badge, restores P1 multi-effort acknowledgment; (F-4) Formula E3 while-loop with max_iterations=10 + monotonic invariant — anti-pillar soft-clamp termination guaranteed; (F-5) Rule 4 dual-gate with workout-score tier ceiling `floor(workout_score × 5)` — preserves「肉身決定 ceiling」P1 against mini-boss 100% drop fantasy contradiction; (F-6) rename「daily guaranteed」→「workout-locked daily」throughout — aligns game-concept anti-entitlement spirit; (F-7) NEW AC-43 daily token gate BLOCKING; (F-8) NEW AC-44 EC-22 unknown rarity tier BLOCKING; (F-9) AC-38/40/41 BLOCKING→ADVISORY downgrade per Testing Standards catch-22; (F-10) MAX_INVENTORY 60→120 interim raise (long-term defer #17); (F-11) Ceremony Choreography Sub-Document followup; (F-12) Followup ADR-007 candidate (signal payload schema convention)。Pass 2 totals: 18 Rules + 1 new (Rule 7.5) + 10 Formulas (F2 rewrite + E3 while-loop) + 48 ECs + 27 owned knobs (+2 MINI_BOSS_CEREMONY_CAP + FINAL_BOSS_RESERVED) + 14 INVs (+3 INV-9 revised + INV-12 + INV-13) + 10 CI lints (+3 NEW) + 44 ACs (34 BLOCKING + 4 ADR-RATIFICATION-GATED pending Pass 3 reclassify + 4 ADVISORY + 1 composite + 24/12/5/0+4/1 distribution)。CD Pass 2 assessment: "P1 anti-fabrication chain 第六件套 honest post-workout_id resolution / P3 PRIMARY substrate intact post-final-boss-reservation / P4 unchanged / P5 decoupled acceptable" + 4 anti-pattern guards established (signal payload contracts in Dependencies / floor+ceiling pattern for pillar tension / ceremony budget reservation logic / Testing-Standards-downgraded ACs need paired followup spec)。**Awaiting Pass 3 fresh-session re-review** per Pass 1 → Pass 2 precedent (inline approval insufficient for convergent structural defects). Review log at design/gdd/reviews/loot-drop-system-review-log.md | [loot-drop-system.md](loot-drop-system.md) | 8, 9, 14 (+ #16 boss_killed signal subscription) |
| 16 | Boss System | Feature | VS | **Pass 5 MAJOR REVISION NEEDED 2026-06-01** (fresh-session /design-review — game-designer + systems-designer + qa-lead + gameplay-programmer + CD synthesis. Pass 4「12 TIER A resolved」claim does NOT hold — 2 proofs: (1) AC-18 still asserts pre-Pass-4 `ATTACK_POWER=0→boss_max_hp=50` path that A3.3 bootstrap abolished → regression test fails (Pass 4 changed formula, no AC propagation); (2) **BossSystem autoload class never defined** [no class_name/extends Node/field section] yet `_spawned_transition_ids` lives on it. 4 domains CONVERGENT. **Tier 0 not-compilable**: BossSystem autoload undefined + `class_name BossVisualResource` nested = GDScript parse error + `_instantiate_boss` undefined. **Tier 1 death-wiring** (qa+gameplay convergent): `_on_enemy_killed_self_listen` never `.connect`ed + no `enemy_id==self.boss_id` filter + dual death path (Rule 12 `_enter_state` vs Rule 8 handler) double-queue_free risk. **Tier 2 pillar-breaking**: bfcache skip-to-kill betrays「我嗰rep殺boss」fantasy; set-count≤2 proxy inverted-reward (3×3 strength→mini-boss). **Tier 3**: AC-18 regression + INV-8 `RARE>RARE` operator bug + avatar-death no-spec + endgame 9-hit collapse + Rule 9 combine-pseudocode missing. **2 DESIGN DECISIONS for Pass 6**: (1) persist `current_hp` [CD-recommended, touches ADR-003] vs 30%-threshold hybrid; (2) reuse ADR-005 effort signal [CD-recommended] vs set-count proxy. **Epic creation BLOCKED until Approved.** Pass 6 fresh-session handoff at design/gdd/reviews/boss-system-review-log.md Pass 5 entry. — SUPERSEDED PRIOR: Pass 3 MAJOR REVISION NEEDED 2026-05-27** (4 passes total: Pass 1 lean autonomous; Pass 2 addressed MAJOR REVISION 20+ items; Pass 3 same-session inline addressed 7 fix-induced contradictions; **Pass 3 fresh-session full-mode re-review (this verdict)**: 6 adversarial specialists (game-designer + systems-designer + economy-designer + gameplay-programmer + qa-lead + godot-specialist) + creative-director synthesis = 25 BLOCKING (12 TIER A MVP-blocker + 9 TIER B pre-sprint + 4 TIER C cross-doc) + 8 RECOMMENDED + 5 ADVISORY; **net regression vs Pass 2** (fixed 4 / introduced 5 new — root cause: ownership migration without downstream grep + Web Export engine knowledge gap); 5 cross-specialist consensus patterns (BossInstance + _player_snapshot dual gap / GP3 fix itself buggy / loot rarity gap / test infra + NEVER gap / Web Export lifecycle gap); 1 specialist disagreement (Pillar 1 vs 2 mid-fight bfcache — CD adjudicated game-designer position correct, skip-to-kill hybrid); architecture direction sound but execution discipline systemic gaps; **fresh-session Pass 4 strongly recommended** (TIER A scope only, no 6-specialist re-review needed — handoff doc at design/gdd/reviews/boss-system-review-log.md). Pass 3 Original Inline Fixes were: Pass 3 key changes vs Pass 2: (a) **AC-03/AC-09 stale spec fixed** — mini-boss field validation moved to #14 forward-constraint (3-way consensus stale); (b) **Final boss loot floor raised UNCOMMON** — economy E3 anti-rarity-overlap with mini ceiling; (c) **CF-2 floor exception** — `≤ max(MIN_BOSS_DAMAGE, ⌊player_max_hp × 0.5⌋)` resolves CRIT-6 vs CF-2 contradiction; (d) **Rule 7 Camera-LEADING reorder** — Hades/Hollow Knight pattern, focal dispatched frame 0 before shake/particles (F2 Pillar 5 violation fix); (e) **Rule 11 wall-clock cleanup** — `Time.get_ticks_msec()` deadline + CONNECT_ONE_SHOT replaces non-existent Awaitable.race + bfcache-safe; (f) **Rule 7 GP3 position fix** — explicit `global_position = spawn_pos` BEFORE add_child + cached in signal payload; (g) **ArenaConfig.tres single source of truth** — Rule 14 spawn position via `#14 EnemyDirector.arena_config`; (h) **Rule 5 snapshot caching mechanism** — `BossInstance.player_stat_snapshot` frozen-at-spawn enforces CF-3 architecturally (AC-36); (i) **Formula 3 posmod fix** — pseudocode hardened against Godot 4.6 negative hash; (j) **Formula 4 categorical scope** — FINAL boss only; mini-boss dead path (F4 Weber-Fechner resolution); (k) **Orphan mini knobs migrated to #14** — TARGET_KILL_HITS_MINI / DAMAGE_RATIO_PER_HIT_MINI via Followup #14; EnemyTemplate.loot_rarity_ceiling field via Followup #15; (l) **AC-12/16/33 CI-dependent downgraded** — BLOCKING → ADVISORY with `BLOCKED-ON: BOSS-AC-followup-08` promotion path; (m) **AC-30b split** — vs (n=5 ADVISORY) + polish (n=30 BLOCKING); (n) **AC-36/37/38/39/40 added** — CF-3 caching + GP3 position + GP4 wallclock + F1 session 5+ retention + NEVER traceability matrix; (o) **TTK target band** 4-12s anti-bullet-sponge on MAX_BOSS_HP; (p) **Q-X6 loot sink + Followup #12** cross-doc to #17 Equipment & Inventory. **Pending /design-review fresh session for CD-GDD-ALIGN re-verification (recommended /clear first due to ~80% context usage)**. Status: 16 Core Rules + 4 formulas + 5 CF + 5 CI + 24 ECs + 9 owned knobs (was 11 — 2 mini knobs migrated to #14) + 46 effective ACs (was 40 — added 5 Pass 3 ACs; downgraded 3 CI-dependent) | [boss-system.md](boss-system.md) | 9, 13, 14, 15, 5, 6, 7 (visual ritual direct callers) |
| 17 | Equipment & Inventory (merged) | Feature | MVP | Not Started | — | 3, 11, 15 |
| 18 | PR Detection & Avatar Progression | Feature | Pre-MVP | Not Started | — | 2, 3, 12 |
| 19 | Zone System ⚠️ | Feature | MVP | Not Started | — | 3, 14 |
| 20 | Gym-Mode HUD (inferred) | Presentation | MVP | Not Started | — | 11, 12 |
| 21 | Loot Drop Modal | Presentation | Pre-MVP | Not Started | — | 5, 15, 17 |
| 22 | Character Screen (inferred) | Presentation | MVP | Not Started | — | 11, 17, 18, 26 |
| 23 | Inventory UI (inferred) | Presentation | MVP | Not Started | — | 17 |
| 24 | Login / GymSys Connection UI | Presentation | MVP | Not Started | — | 2 |
| 25 | Combat Visual Feedback (inferred) | Presentation | MVP | Not Started | — | 5, 6, 13, 14 |
| 26 | Avatar Renderer | Presentation | VS | **MAJOR REVISION NEEDED — BLOCKED 2026-05-28 (1 of 4 deps RESOLVED 2026-05-28 — Q-OQ2 cleared via Option C ground-truth verification; 3 deps remaining)** (Pass 4 fresh-session adversarial re-review verdict — REJECT inline-fix, BLOCKED on 4 dependencies, v2 fresh-template rewrite required after dependencies resolved): 4 specialists (game-designer + systems-designer + qa-lead + godot-gdscript-specialist) + creative-director senior synthesis surfaced 16 BLOCKING + 6 CONCERN — root cause: Pass 3 mandate「dedicated revision session」WAS IGNORED, GDD header still「Pass 2 Revised」, Pass 3 24 BLOCKING never addressed; Pass 4 unanimous patterns (Test Distribution 41 vs 52 mismatch / AnimationPlayer.pause() ghost / Formula 4 REST_BETWEEN_SETS still missing / CR-8 `AnimatedSprite2D.stop()` likely hallucination); Pass 4 first-discovery architectural faults (Q-OQ5 micro-evolution shader-only no silhouette delta → FT-2 share rate certain fail + Mirror Moment ceremony ownership chain broken to Not Started #29 + CR-8 fundamental API hallucination invalidating F-8 snapshot chain); Pillar substrate post-Pass 4: P1 CONCERN / P2 CONCERN / P4 CONCERN / **P5 FAILED** (substrate ownership broken + micro-evolution invisible at 16×16); **CD binding judgment: ADOPT Option (c) + (d) hybrid — BLOCKED state, v2 fresh-template rewrite after 4 deps resolved (1. ✅ **Q-OQ2 GSM COMBAT_TICK contract RESOLVED 2026-05-28 Option C** — ground-truth verification: GSM enum 冇 `COMBAT_TICK` (actual: `COMBAT_ACTIVE` + `BOSS_ENCOUNTER`) AND #14 EnemyDirector signal surface lock 死 3 signals (CI lint #3 enforced — `combat_started/ended` 不可加 violates #14 Rule 5); resolution = subscribe GSM `state_changed(from, to, payload)` filtered by `to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` (combat enter) + `from ∈ {…} AND to ∉ {…}` (combat exit); mirrors #14 own subscription pattern per GSM GDD line 230-231; zero cross-GDD blast radius; resolution seed text inline-edited to avatar-renderer.md CR-2 + AC-05 + States table + transition diagram + animation specs + Q-OQ2 entry for v2 rewrite reference (NOT Pass 5 inline-fix attempt — explicitly documented in review log) / 2. ADR-0006 `connect_for_initial_state` helper implementation / 3. #29 Mirror Moment sprint slot confirmation / 4. Godot 4.6 empirical API verification — `AnimatedSprite2D.stop()` vs `pause = true`); Pillar 5 substrate ownership reframe (binding): #26 limited to「render avatar evolution states」, ceremony composition migrates to #29 GDD, #26 only exposes `get_evolution_snapshot()` API; producer escalation required (reserve XL sprint slot). **Pass 1-3 GDD + review log preserved as reference material, NO MORE INLINE PATCHES**. Review log appended Pass 4 entry at design/gdd/reviews/avatar-renderer-review-log.md. — Pass 2 Revised 2026-05-28** — Pass 1 inline same-session APPROVED **RETROSPECTIVELY RESCINDED** by fresh-session /design-review (verdict MAJOR REVISION NEEDED, 16 BLOCKING convergent across 4 specialists — replicates #15 Pass 1→2 anti-pattern at higher severity)。Pass 2 inline-fixed 13 BLOCKING per user autonomous mode + 3 followup-tracked (F-9 connect_for_initial_state helper implementation prereq / F-13 #29 producer escalation / F-15 cumulative posture post-MVP tech-debt)。Pass 2 key changes: (F-1) Formula 3 first-boot epoch=0 guard (MIN_OBSERVED_SESSIONS + FIRST_BOOT_GRACE_SECONDS) - closes Pillar 1 anti-fabrication "cosplay" leak; (F-2) Formula 2 T3 specialist path (max_single_class_tier ≥ 3) - Pillar 4 specialist promise honored; (F-3) Formula 3 micro-evolution layer NEW (`avatar_micro_evolution` weekly cadence, shader-only delta) - Pillar 5 weekly cadence honored without ceremony budget; (F-4) AvatarVisualState schema NEW (Resource class with 12 fields + source signal mapping) - resolves spec ghost; (F-5) Autoload Boot Position corrected (#11 + #12 inserted explicitly, were ABSENT, effective #26 position = 11); (F-6) Formula 5 monotonic clock + max(0,delta) clamp - NTP/DST guard; (F-7) CR-9 + CR-15 hysteresis aligned (REST_BETWEEN_SETS coverage); (F-8) CR-8 API corrected (AnimatedSprite2D.stop() not AnimationPlayer + frame_progress field); (F-10) Q-OQ2 promoted BLOCKING sprint gate; (F-11) AC-14 reworked transition_id; (F-12) PostureConfig.tres LUT NEW (resolves posture_lut spec ghost); (F-14) AC-50 tier transition memory spike; (F-16) Q-OQ11 WebGL VRAM monitor replacement。AC count Pass 1: 41 → **Pass 2: 52** (24 unit + 14 integration + 10 static-analysis + 4 ADVISORY playtest, 41 BLOCKING + 7 ADR-RATIFICATION-GATED + 4 ADVISORY)。Pillar substrate post-fix: P1 第七件套 restored / P4 specialist honored / P5 weekly cadence delivered (pending F-13 #29 dependency) / P2 silhouette preserved。Cross-system anti-pattern guards established (Pass 1→2): epoch-zero gate test / pillar-promise vs trigger-gate audit / schema-before-signal rule / autoload-position ground-truth lock / helper-before-card rule。Project rule codified: "Inline same-session approval forbidden for cards touching ≥2 pillars OR ≥3 systems OR formula-bearing milestones" (#15 + #26 empirical validation)。**Awaiting Pass 3 fresh-session re-verification** per #15 Pass 1→2 precedent (inline approvals empirically insufficient for convergent structural defects — anti-pattern validated twice)。Review log at design/gdd/reviews/avatar-renderer-review-log.md。 16 Core Rules + 6 internal states + 5 Formulas (dominant_class_derivation / evolution_tier_derivation / milestone_two_gate_check / hysteresis_check / bfcache_resume_action) + 4 CF + 5 CI + 53 ECs (10 CRITICAL + 22 HIGH + 15 MEDIUM + 6 LOW) + 20 owned knobs + 8 referenced knobs + 5 INV-G + 4-tier stability + 41 ACs (31 BLOCKING + 6 ADR-RATIFICATION-GATED + 4 ADVISORY playtest per Testing Standards). CD assessment: "Strongest anti-fabrication closure to date (F-3 — 第七件套 chain coherent) + strongest cross-system voice consistency to date (F-1 — ledger metaphor inherits XX 唔講大話 vocabulary) + #15 Pass 2 catch-22 lesson correctly applied (F-6) + pillar-driven creative call on palette-swap rejection (F-5)". **Pillar 5 PRIMARY substrate** (visible weekly evolution via 4 evolution tiers + Mirror Moment milestone two-gate); Pillar 4 supporting (class-tagged silhouette per-class redrawn frames, NOT palette-swap — preserves FT-4 16×16 silhouette test substrate); **Pillar 1 supporting via anti-fabrication chain 第七件套 complete (#2 + #3 + #11 + #14 + #9 + #15 + #26)**; Pillar 2 supporting (silhouette-first 0.3s glance + 5-min posture hysteresis + workout-window milestone exclusion). MVP scope locked: single sprite avatar + 3 anim states (idle/combat/cast) + 3 class postures + 4 evolution tiers + screenshot-only Mirror Moment v1 (NO layered armor — v0.2 deferral honest). 7 CI lint scripts + 36 sprite sheets / 12 SpriteFrames resources / 3 #5 particle presets (avatar_stat_glow / avatar_cast_burst / avatar_evolution_reveal). ADR-0001 input scope (bfcache 30s parity with #15 + Mobile Safari sprite-unchanged) + ADR-0003 input scope (avatar.evolution_tier_history namespace + Private Mode degraded mode) + ADR-0006 inherits Contract 4 (autoload pos 8/9) + Contract 6 (connect_for_initial_state). 7 Open Questions including Q-OQ4 (sprite asset workload 36 sheets — F-7 PROMOTED pre-sprint scope decision gate with 3 fallback options) + Q-OQ5 (Mirror Moment cadence 4 tiers / 8-week max 4 moments — F-8 PROMOTED Pillar 5 retention substrate adequacy gate with 3 framing options). 5 formulas + 9 constants + 2 enums (ClassPosture / EvolutionTier) registered in entities.yaml. **VS tier complete 14/14 → 100%**. Pending /design-review fresh session for Pass 2 independent verification. | [avatar-renderer.md](avatar-renderer.md) | 11, 12 |
| 27 | Onboarding Flow | Polish | Pre-MVP | Not Started | — | 9, 10, 15, 24 |
| 28 | Telemetry / Analytics (inferred) | Polish | Pre-MVP | Not Started | — | 9, 13, 14, 15 |
| 29 | Mirror Moment System (MVP: screenshot-only; v0.2: full layered) | Polish | MVP | Not Started | — | 17, 18, 26 |
| 30 | Skill Tree System | Polish | v0.2 | Not Started | — | 12, 18 |
| 31 | SSE / Realtime Upgrade | Polish | v0.2 | Not Started | — | 2 |
| 32 | Friend Leaderboard | Polish | T3 | Not Started | — | 17, 18 |
| 33 | Attention Budget & Interaction Policy (added per CD-SYSTEMS) | Core | Pre-MVP | Not Started | — | 1, 9 |

> Systems marked **(inferred)** are not explicitly named in `game-concept.md` but are required by the explicit systems' implementation needs. Systems marked **(merged)**, **(split)**, **(renamed)**, or **(added per CD-SYSTEMS)** reflect changes from the original 34-system enumeration after director gate review.
> ⚠️ marks systems with anti-pillar drift risk — see [Anti-Pillar Constraints](#anti-pillar-constraints) section below.

---

## Anti-Pillar Constraints

These hard rules MUST be carried forward when authoring the flagged GDDs. They were identified during CD-SYSTEMS review.

### #15 Loot Drop System (⚠️ Pillar 1 drift risk)
**Constraint**: Loot quality function MUST take real-PR-signal as primary input; RNG is a secondary modifier only.

**Why**: If RNG alone can produce top-tier drops without real workout signal, **Pillar 1 (Real Body, Real Power) is dead**. The whole game's premise — "you can't fake your way to better gear" — collapses.

**How to apply in GDD**: In the Formulas section, the loot rarity equation MUST express:
- Real workout volume / PR breakthrough as PRIMARY multiplier (≥0.7 weight)
- RNG roll as SECONDARY modifier only (≤0.3 weight)
- No code path may generate a top-rarity item without a real-workout signal in the input.

### #19 Zone System (⚠️ Pillar 1 drift risk)
**Constraint**: Zones unlock via **real-body milestones** (PR thresholds, training consistency streaks, muscle-group coverage). NOT via play time, in-game kills, or generic XP.

**Why**: Standard RPG zone-unlock patterns (level X to enter, kill N enemies, etc.) violate Pillar 1. Pattern leakage from typical ARPG references (Hades, MapleStory) is the failure mode here.

**How to apply in GDD**: In the Detailed Rules section, every zone unlock condition MUST reference a `WorkoutMetric` (PR, streak, muscle-group ratio) — not a `GameMetric` (play time, kills, XP). The unlock check function signature should accept only `WorkoutHistoryData`, not `GameSessionData`.

---

## Categories (Layer)

| Layer | Description | This Game's Systems |
|-------|-------------|---------------------|
| **Foundation** | Infrastructure layer — no gameplay logic, just framework. | 1, 2, 3, 4, 5, 6, 7, 8 |
| **Core** | Gameplay rules — pure mechanics, no UI. | 9, 10, 11, 12, 13, 14, 15, 33 |
| **Feature** | Game features that combine multiple Core systems. | 16, 17, 18, 19 |
| **Presentation** | UI / visual feedback wrapping gameplay. | 20, 21, 22, 23, 24, 25, 26 |
| **Polish** | Meta-systems and post-MVP. | 27, 28, 29, 30, 31, 32 |

---

## Priority Tiers (6-tier, Producer-Adjusted)

> Original concept doc 4-tier (VS / MVP / v0.2 / v1.0 / T3) flagged UNREALISTIC by PR-SCOPE gate. Adopted 6-tier with **Pre-MVP** insertion for honest hypothesis test.

| Tier | Definition | Target | System Count (cumulative) | Design Urgency |
|------|------------|--------|---------------------------|----------------|
| **Vertical Slice (VS)** | Internal POC — 1 boss kill loop + GymSys polling. Not shippable; tech demo. | Week 6-8 | 13 | Design FIRST |
| **Pre-MVP** | First shippable. Minimum to validate MVP hypothesis (「玩家有冇 glance + 爆裝有冇覺爽」). | Month 4 | 21 | Design SECOND |
| **MVP / T0** | Full MVP per concept doc — adds equipment / inventory / UI polish / audio + minimum-viable Mirror Moment for retention. | Month 7-9 | 30 | Design THIRD |
| **v0.2 / Alpha** | Layered char system (full Mirror Moment scope extension) + skill trees + SSE. | Month 14-17 | 32 | Design FOURTH |
| **v1.0 / Beta** | Content scaling (5-10 zones, 20 bosses, 30-100 items, class spec) — **no new systems**, content within existing GDDs. | Month 24-25 | 32 | Content phase |
| **T3 / Full Vision** | Friend leaderboard + post-launch live-ops. | Post-v1.0 | 33 | Post-launch |

**Velocity context**: Solo + first-time game dev. 0.5× velocity already baseline-applied per concept doc. Producer recommends ×1.6 additional rebase due to engine learning curve (Godot 4.6 + Web Export to mobile Safari is a known pain point).

---

## Dependency Map

### Foundation Layer (8 systems)

```
1.  Game State Machine            → (no deps)
2.  GymSys Backend Client         → (no deps)
3.  PersistenceLayer              → (no deps — Foundation leaf; autoload position 1)
4.  Audio Manager                 → (no deps)
5.  Particle System Wrapper       → (no deps)
6.  Screen Effects System         → (no deps)
7.  Camera System                 → (no deps)
8.  Streak System                 → 3 (pure persisted counter; other systems call into it)
```

### Core Layer (8 systems)

```
9.  Workout State Tracker         → 2, 3 (sibling consumer of #2 with #8 — no direct #8 dep; GDD Section F confirmed #8 removed)
10. Exercise → Class Mapping      → 3
11. Stat System                   → 3
12. Ability System                → 10, 11
13. CombatResolver                → 11, 12 (pure stateless damage/HP/combo math)
14. EnemyDirector                 → 5, 6, 7, 13 (wave spawn + AI state machines + combat tick)
15. Loot Drop System              → 8, 9, 14 (streak + workout volume + enemy kill events) ⚠️
33. Attention Budget & Interaction Policy → 1, 9 (enforces Pillar 2 anti-pillar; +#4 Audio at MVP scope)
```

### Feature Layer (4 systems)

```
16. Boss System                   → 9, 13, 14, 15, 5, 6, 7 (visual ritual direct callers per #16 Rule 7)
17. Equipment & Inventory         → 3, 11, 15
18. PR Detection & Avatar Prog.   → 2, 3, 12
19. Zone System                   → 3, 14 ⚠️
```

### Presentation Layer (7 systems)

```
20. Gym-Mode HUD                  → 11, 12
21. Loot Drop Modal               → 5, 15, 17
22. Character Screen              → 11, 17, 18, 26
23. Inventory UI                  → 17
24. Login / GymSys Connection UI  → 2
25. Combat Visual Feedback        → 5, 6, 13, 14
26. Avatar Renderer               → 11, 12
```

### Polish Layer (6 systems)

```
27. Onboarding Flow               → 9, 10, 15, 24
28. Telemetry / Analytics         → 9, 13, 14, 15
29. Mirror Moment System (v0.2+)  → 17, 18, 26
30. Skill Tree System (v0.2+)     → 12, 18
31. SSE / Realtime Upgrade (v0.2+)→ 2
32. Friend Leaderboard (T3)       → 17, 18
```

---

## Recommended Design Order

Combine dependency sort + tier. Design top-to-bottom. Independent systems at the same layer can be designed in parallel.

### Vertical Slice Tier (14 GDDs — #15 LootDrop upgraded 2026-05-27 per #16 CRIT-5)

| Order | # | System | Layer | Agent(s) | Effort |
|-------|---|--------|-------|----------|--------|
| 1 | 1 | Game State Machine | Foundation | systems-designer | S |
| 2 | 2 | GymSys Backend Client | Foundation | systems-designer + network-programmer | L |
| 3 | 3 | PersistenceLayer | Foundation | systems-designer | L |
| 4 | 5 | Particle System Wrapper | Foundation | technical-artist + godot-shader-specialist | M |
| 5 | 6 | Screen Effects System | Foundation | technical-artist | S |
| 6 | 7 | Camera System | Foundation | gameplay-programmer | M |
| 7 | 11 | Stat System | Core | systems-designer | M |
| 8 | 12 | Ability System | Core | systems-designer + game-designer | M |
| 9 | 13 | CombatResolver | Core | systems-designer + gameplay-programmer | L |
| 10 | 14 | EnemyDirector | Core | ai-programmer + game-designer | L |
| 11 | 9 | Workout State Tracker | Core | systems-designer | L |
| 12 | 16 | Boss System | Feature | game-designer | M (Pass 1 lean) / L (Pass 2 revision Sept 2026) |
| 13 | **15** | **Loot Drop System** ⚠️ (upgraded VS 2026-05-27) | **Core** | **economy-designer + systems-designer** | **L** |
| 14 | 26 | Avatar Renderer | Presentation | art-director + technical-artist | M |

### Pre-MVP Tier (+7 GDDs — #15 moved to VS per 2026-05-27 tier upgrade)

| Order | # | System | Layer | Agent(s) | Effort |
|-------|---|--------|-------|----------|--------|
| 15 | 8 | Streak System | Foundation | systems-designer | S |
| 16 | 33 | Attention Budget & Interaction Policy (★ Pillar 2 owner) | Core | ux-designer + systems-designer | M |
| 17 | 10 | Exercise → Class Mapping | Core | game-designer | S |
| 18 | 18 | PR Detection & Avatar Progression | Feature | systems-designer | L |
| 19 | 21 | Loot Drop Modal (★ Pillar 3 signature) | Presentation | ux-designer + technical-artist | M |
| 20 | 27 | Onboarding Flow | Polish | ux-designer | M |
| 21 | 28 | Telemetry / Analytics | Polish | analytics-engineer | M |

### MVP Tier (+9 GDDs)

| Order | # | System | Layer | Agent(s) | Effort |
|-------|---|--------|-------|----------|--------|
| 22 | 4 | Audio Manager | Foundation | audio-director | M |
| 23 | 17 | Equipment & Inventory | Feature | systems-designer + economy-designer | M |
| 24 | 19 | Zone System ⚠️ | Feature | level-designer | M |
| 25 | 20 | Gym-Mode HUD | Presentation | ux-designer | M |
| 26 | 22 | Character Screen | Presentation | ux-designer | M |
| 27 | 23 | Inventory UI | Presentation | ux-designer | S |
| 28 | 24 | Login / GymSys Connection UI | Presentation | ux-designer | S |
| 29 | 25 | Combat Visual Feedback | Presentation | ux-designer + technical-artist | M |
| 30 | 29 | Mirror Moment System (★ Pillar 5, MVP minimum: screenshot-only) | Polish | game-designer + art-director | M (MVP scope; L for v0.2 layered extension) |

### v0.2 / Alpha Tier (+2 GDDs)

| Order | # | System | Layer | Agent(s) | Effort |
|-------|---|--------|-------|----------|--------|
| 31 | 30 | Skill Tree System | Polish | game-designer | M |
| 32 | 31 | SSE / Realtime Upgrade | Polish | network-programmer | M |

> Note: Mirror Moment (#29) was promoted to MVP at minimum scope. The v0.2 milestone instead **extends** #29's existing GDD with layered-character scope (+L effort estimate for the extension).

### T3 / Full Vision Tier (+1 GDD)

| Order | # | System | Layer | Agent(s) | Effort |
|-------|---|--------|-------|----------|--------|
| 33 | 32 | Friend Leaderboard | Polish | live-ops-designer | M |

> **Effort scale**: S = 1 session, M = 2-3 sessions, L = 4+ sessions. A "session" = one focused design conversation producing a complete GDD.

---

## Circular Dependencies

**None found** — dependency graph is acyclic.

> Per TD-SYSTEM-BOUNDARY review, the original Core→Polish inverted dependency (Loot Drop System → Streak) was resolved by promoting Streak System to Foundation layer.

---

## High-Risk Systems

| # | System | Risk Type | Risk Description | Mitigation |
|---|--------|-----------|------------------|------------|
| 3 | PersistenceLayer | Architectural | 7 dependents (highest) — interface change forces 7 GDD revisions. Backend+localStorage conflict resolution is non-trivial. | Spend extra design time on contract. Include conflict-resolution rules in GDD explicitly. |
| 11 | Stat System | Architectural | 6 dependents — formula change cascades to combat / equip / UI / progression / renderer. | Lock derived-stat formulas with example calculations in GDD. Treat as data-only with observer pattern. |
| 13 | CombatResolver + 14 EnemyDirector | Architectural + Technical | 5+5 combined dependents. Combat is the gamefeel-sensitive core; first-timer iterates 3-5x on this. | Keep CombatResolver stateless and pure-function. EnemyDirector owns lifecycle only. Mock CombatResolver in EnemyDirector tests. |
| 2 | GymSys Backend Client | Technical | 5 dependents. CORS + auth + Web Export + mobile Safari = compound risk. | ADR for cross-origin topology early (concept Q1). 2-3 day budget for CORS alone. |
| 9 | Workout State Tracker | Design | 5 dependents. Event model design errors propagate to loot / boss / onboarding / telemetry / streak. | Define event schema as enum with examples in GDD. Version the event protocol from day 1. |
| 14 | EnemyDirector | Technical (Web Export) | Mobile Safari particle perf is HIGH risk per concept doc. EnemyDirector orchestrates particle spawns. | Stress test with 200 particles + 8 enemies in VS. Auto-degrade rules in GDD. |
| 21 | Loot Drop Modal | Design (Pillar 3) | Pillar 3 signature feature. If this doesn't trigger 「值得截圖」reaction, MVP hypothesis fails. | Prototype standalone before MVP integration. Iterate visual ritual with playtester. |
| 18 | PR Detection & Avatar Progression | Design (Pillar 1) | Pillar 1 anchor — fakeable PR detection breaks the game's promise. | Server-side PR judging per concept Q3. ADR for PR detection logic. |
| 33 | Attention Budget & Interaction Policy | Design (Pillar 2) | Pillar 2 owner — added per CD-SYSTEMS. Risk: GDD authoring drift treats this as "just UI rules" and Pillar 2 enforcement collapses. | GDD must define hard contract: max interactions per set = 0, glance budget <2s, notification suppression rules, phone-lock/app-switch recovery behavior. |
| 15 | Loot Drop System | Design (Pillar 1) | Anti-pillar drift risk — see [Anti-Pillar Constraints](#anti-pillar-constraints). | Loot quality function MUST take real-PR-signal primary, RNG secondary. Cap RNG-only outcomes below top rarity. |
| 19 | Zone System | Design (Pillar 1) | Anti-pillar drift risk — see [Anti-Pillar Constraints](#anti-pillar-constraints). | Zone unlock check function MUST accept only WorkoutHistoryData, not GameSessionData. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 33 |
| Design docs started | 15 (#1, #2, #3, #5, #6, #7, #8, #9, #11, #12, #13, #14, #15, #16 — 13 Approved + #16 Designed pending review) |
| Design docs reviewed | 13 (#1–#3, #5–#8 Approved 2026-05-26; #9 + #11 + #12 + #13 + #14 Approved 2026-05-27; #15 Approved 2026-05-28 CD-GDD-ALIGN inline-resolved) |
| Design docs approved | 13 |
| VS systems designed | **12/14** (Approved: #1, #2, #3, #5, #6, #7, #9, #11, #12, #13, #14, #15; Designed-pending-review: #16; **#26 BLOCKED 2026-05-28 — MAJOR REVISION NEEDED, v2 rewrite pending 4 deps**; #8 promoted Polish → Foundation Pre-MVP also counted; **VS-tier 86% complete + 1 BLOCKED**) |
| Pre-MVP systems designed | 13/21 |
| MVP systems designed | 13/30 |
| v0.2 systems designed | 13/32 |
| T3 systems designed | 13/33 |

---

## Next Steps

- [x] Spawn **CD-SYSTEMS** gate (creative-director) — vision alignment check ✅ resolved
- [x] Address CD-SYSTEMS CONCERNS — 4 edits applied (added #33, promoted #29 to MVP minimum, annotated #15 + #19)
- [ ] Run `/design-system 1` to author first GDD (Game State Machine)
- [ ] Or `/map-systems next` to auto-pick highest-priority undesigned system
- [ ] Run `/design-review design/gdd/[system].md` after each GDD
- [ ] Run `/review-all-gdds` after VS-tier GDDs complete
- [ ] Run `/gate-check pre-production` when Pre-MVP GDDs complete
- [ ] Required ADRs (from concept doc Next Steps):
  - ADR-001: Godot Web Export budget caps (particles / draw call / bundle size)
  - ADR-002: GymSys integration protocol (polling MVP → SSE v0.2)
  - ADR-003: Save state strategy (backend-primary + localStorage cache) — supersedes Streak persistence model
  - ADR-004: CORS / cross-origin auth topology
  - ADR-005: Loot rarity formula

---

## Producer Hard Governance Rules

(Carry-forward from `game-concept.md`)

- **Velocity multiplier**: ×0.5 baseline (4 parallel production systems)
- **Producer adjustment**: ×1.6 timeline rebase recommended (engine learning curve)
- **Monthly hard checkpoint**: over 20% scope → trigger re-scope
- **VS failure criterion**: >8 weeks without basic loop → pivot to native desktop export or scope cut
- **Pre-MVP failure criterion**: Telemetry data after Month 4 fails to show「players glance + drop excitement」signals → PIVOT or KILL per concept hypothesis
