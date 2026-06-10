# Avatar Renderer (#26) — v2 (fresh-template rewrite)

> **Status**: **v2 DRAFT 2026-06-10 — awaiting Pass 5 fresh-session /design-review**. This is a **clean-template rewrite** mandated by Pass 4 (2026-05-28): Passes 1–4 of the prior single-file GDD are preserved as reference material in `design/gdd/reviews/avatar-renderer-review-log.md` + git history; this v2 does NOT inherit the prior file's body text. All 4 v2-rewrite blockers RESOLVED before this draft (review-log Resolution Notes 2026-05-28 Q-OQ2 + 2026-06-10 deps 2/3/4). **Scope reframed to render-only per ADR-0010** — Mirror Moment ceremony composition migrates to #29; #26 renders avatar evolution state and exposes a snapshot API + milestone trigger signals.
> **Author**: Frank + creative-director (autonomous mode per [feedback_auto_advance]) — v2 authored against ground-truth-verified upstream APIs (#11/#12 shipped, Godot 4.6.3 empirical)
> **Last Updated**: 2026-06-10
> **Implements Pillar**: **Pillar 5 (Mirror Moment)** PRIMARY *render* substrate — #26 produces the visible evolution state that #29 ceremonies / **Pillar 4 (Muscle = Class)** supporting — class-tagged silhouette differentiation across 3 postures / **Pillar 1 (Real Body, Real Power)** supporting — anti-fabrication 第七件套: every visible field derives only from canonical #11/#12 data / **Pillar 2 (Frictionless Companion)** supporting — 0.3s mid-set silhouette glance + posture hysteresis
> **System #**: 26 (Presentation tier)
> **Depends On**: #11 Stat System (Approved, shipped) · #12 Ability System (Approved, shipped) · #1 GSM (Approved, shipped) · #3 PersistenceLayer (Approved, shipped) · #5 ParticleSystemWrapper (Approved, shipped)
> **Depended On By**: #22 Character Screen (shipped — reads avatar state via read-API) · #25 Combat Visual Feedback (Not Started) · **#29 Mirror Moment System** (Not Started — owns ceremony, consumes `avatar_evolution_milestone` + `get_evolution_snapshot()`)
> **Governing ADRs**: ADR-0001 Web Export Budget Caps (sprite draw-call + texture-atlas budget + bfcache 30s parity) · ADR-0003 Save State Strategy (`avatar.evolution_tier_history.*` namespace) · ADR-0006 State Machine Contract (Contract 4 sequential boot, Contract 6 `connect_for_initial_state`) · ADR-0008 Autoload Position Map (absolute boot position — ground truth, NOT hardcoded here) · **ADR-0010 Mirror Moment Ceremony Ownership Split** (render-vs-ceremony seam — Proposed, this GDD + #29 ratify it) · ADR-0011 (derivation-client-side pattern, applied to `max_class_depth`)

---

## Representation Map (anti-drift scaffold — Pass 3 "Avatar Renderer Rule" mandatory)

> **Why this section exists**: Passes 1→4 all failed for the *same* reason — fixes applied to a rule's PRIMARY statement but not propagated to its SECONDARY representations (formula bodies, States table, EC entries, INV/AC tables, Coverage Map). This table is the **single source of truth** for every load-bearing constant / formula / API fact and *every* place it appears. Any edit to a row MUST update all listed sites in the same change. A Pass-5 reviewer verifies each row by grep.

### Engine API facts (empirically verified — Godot 4.6.3, evidence `production/qa/evidence/avatar-renderer/`)

| Fact | Ground truth (4.6.3) | Appears in |
|------|----------------------|-----------|
| **Freeze sprite at current frame** | `AnimatedSprite2D.pause()` (method; holds `frame`). `stop()` RESETS `frame`→0 — MUST NOT be used for snapshot. | CR-8 · States "Suspended" row · EC-SUS-2 · Formula 5 · AC-26 |
| **Fractional frame restore** | `set_frame_and_progress(frame: int, progress: float)` — exists, signature confirmed | CR-8 · Formula 5 · AvatarVisualState `frame_progress` · AC-26 |
| **Texture VRAM monitor** | `Performance.RENDER_TEXTURE_MEM_USED` (15) / `RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED` (3). `MEMORY_STATIC` measures total static heap — MUST NOT be used for texture budget. | INV-6 · CR-14 · AC-29 · Q-OQ-VRAM |
| **Sprite + animation node** | `AnimatedSprite2D` + `SpriteFrames` (hand-rolled FSM drives it). NO `AnimationPlayer` anywhere in #26. | CR-2 · CR-8 · States table · EC-ANIM-* · CI-6 |

### Constants (single definition site = Tuning Knobs §; every reference must match)

| Constant | Value | Owner / parity | Appears in |
|----------|-------|----------------|-----------|
| `POSTURE_HYSTERESIS_SECONDS` | 300 | #26 (DESIGN-FROZEN) | CR-9 · Formula 4 · INV-2 · Tuning Knobs · AC-12 |
| `MILESTONE_CADENCE_SECONDS` | 604800 | #26 (DESIGN-FROZEN) | CR-5 · Formula 3 · Tuning Knobs · AC-09 |
| `MICRO_EVOLUTION_CADENCE_SECONDS` | 604800 | #26 (TUNABLE) | CR-5b · Formula 3b · Tuning Knobs · AC-10 |
| `BFCACHE_CONTINUE_THRESHOLD_MS` | 30000 | **MUST == #15.Rule17 + #12.MAX_FRAME_DELTA-class** (INV-5/CI-4) | CR-8 · Formula 5 · INV-5 · Tuning Knobs · AC-26 |
| `CAST_HARD_WINDOW_MS` | 300 | #26 (LOCKED) | CR-10 · Formula(none) · INV-2 · Tuning Knobs · AC-06 |
| `CAST_TOTAL_MS` | 500 | #26 (DESIGN-FROZEN) | CR-10 · Visual B · Tuning Knobs |
| `CAST_QUEUE_DEPTH` | 1 | #26 (LOCKED) | CR-10 · EC-ANIM-2 · Tuning Knobs |
| `Z_INDEX_CHARACTER_LAYER` | 10 | ADR-0001 (LOCKED) | CR-7 · INV-3 · Tuning Knobs · AC-07 |
| `Z_INDEX_PARTICLE_LAYER` | 20 | ADR-0001 (LOCKED) | CR-7 · INV-3 · Tuning Knobs · AC-07 |
| `S_t` stat thresholds | {0,30,60,100} | #26 (TUNABLE, .tres) | Formula 2 · CR-4 · Tuning Knobs · AC-03/04 |
| `A_t` ability thresholds | {0,1,3,6} | #26 (TUNABLE, .tres) | Formula 2 · CR-4 · Tuning Knobs · AC-03 |
| `D_t` class-depth thresholds | {0,1,2,3} | #26 (TUNABLE, .tres) | Formula 2 · CR-4 · Tuning Knobs · AC-03b |
| `FIRST_BOOT_GRACE_SECONDS` | 172800 (48h) | #26 (TUNABLE) | Formula 3 gate_b · CR-5 · AC-08 |
| `MIN_OBSERVED_SESSIONS` | 1 | #26 (TUNABLE) | Formula 3 gate_b · CR-5 · AC-08 |

### Upstream read contracts (ground-truth-verified against shipped src/)

| #26 needs | Shipped source (verified) | Derivation |
|-----------|---------------------------|-----------|
| base stats STR/DEX/VIT | `#11.get_stat(stat_id)` (lowercase StringName ids) | Formula 1 + Formula 2 stat_total |
| ability_count | `#12.get_unlocked_abilities() -> Dictionary` → `.size()` | Formula 2 generalist path |
| **max_class_depth** | derived client-side from `#12.get_unlocked_abilities()` keys → (class,tier) | Formula 2 specialist path — **(class,tier) resolution = Q-OQ-DEPTH forward dep on #12; `get_max_unlocked_class_tier()` does NOT exist (phantom in v1)** |
| combat enter/exit | `#1 GSM.state_changed(from,to,payload)`, filter `to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` | CR-2 (Q-OQ2 Option C — `COMBAT_TICK` does not exist) |
| workout window | `#1 GSM.current_state ∈ {WORKOUT_ACTIVE, REST_PERIOD}` | CR-9 + Formula 4 + CR-5 gate_c |
| suspend/resume | `#1 GSM` SUSPENDED state + ADR-0006 Contract 6 | CR-8 + Formula 5 |

> **GSM enum note (grep-verified `game-state-machine.md`)**: `GameState = {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}`. The workout window is `{WORKOUT_ACTIVE, REST_PERIOD}` (the enum value is **REST_PERIOD**, renamed from EXERCISE_SWITCHING per GSM Decision #3 — the v1 GDD's `REST_BETWEEN_SETS` was itself a stale name; v2 uses the shipped `REST_PERIOD` everywhere).

## Overview

Avatar Renderer (#26) 係 Mirror Hero 嘅 **player-facing visible-state render layer** — 一個 Presentation-tier autoload，boot 喺 #11 Stat System + #12 Ability System 之後。佢訂閱 canonical upstream signals，derive 一個 presentation-only state `AvatarVisualState`（class posture / evolution tier / animation state / sprite frame），render 出嚟，並向下游(#22 Character Screen / #25 Combat Visual Feedback / #29 Mirror Moment)expose **read-only** API + snapshot + milestone trigger signals。

**單一職責(ADR-0010 reframe)**:#26 **render avatar evolution states** — 佢唔擁有任何 ceremony。週末 Mirror Moment 嘅 screenshot 構圖、hero pose 編排、上週 ghost 對比、share UI、celebration choreography 全部由 **#29 Mirror Moment System** 擁有。#26 對 #29 嘅 contract 係兩件嘢:(1) emit `avatar_evolution_milestone(tier, source_metrics)` 做 ceremony trigger;(2) expose `get_evolution_snapshot() -> AvatarEvolutionSnapshot` 俾 #29 拎當前 render state 去砌 ceremony portrait。**#26 唔 render 9:16 portrait、唔 render ghost overlay、唔彈 screenshot prompt** — 嗰啲係 #29。

**Data 層面**:訂閱 `#11.stat_changed` + `#12.ability_unlocked` + `#12.ability_cast` + GSM `state_changed`(全部經 ADR-0006 Contract 6 `connect_for_initial_state`)。維護 derived `AvatarVisualState`,**冇任何 mutation API exposed** — visible state 純粹 derive from canonical data,唔可以注入 visual flair。每次 state change emit `avatar_visual_updated(state)`。

**Player-facing 層面**:玩家 mid-set glance 1 秒就知「今日係咩 class、依家做緊咩 action、今週 tier 有冇升」— 純黑 16×16 剪影都 readable(Art Bible Silhouette First)。週末 tier 升級 = avatar base sprite 換成 evolved 版本 = 玩家**真實一週訓練嘅 visible receipt**(由 #29 ceremony 呈現)。

**為何存在**:Pillar 5 (Mirror Moment) 嘅 *render* substrate。冇 #26 = stat 升咗但 avatar 唔變 → Mirror Moment fantasy 斷裂。同時 #26 係 Pillar 1 anti-fabrication 第七件套 — 確保 visible state 100% derive from canonical data layer,avatar 唔可以 lie。

**MVP scope(locked per game-concept anti-pillar)**:**single sprite avatar** + 3 animation states(idle / combat / cast)+ 3 class-tagged posture variants(STRIKE / CONTROL / MOBILITY)+ 4 evolution tiers(T0–T3)。**NO layered armor / NO cosmetic overlay / NO equipment-slot visible**(推遲 v0.2)。Mirror Moment v1 = screenshot-only weekly evolution(#29 owns the screenshot;#26 owns the sprite swap that makes it worth screenshotting)。

**Player interaction model**:**passive** — player 唔操作 avatar、唔揀 skin/equipment。所有 visible change 由 upstream canonical data 自動驅動。但 player-perceived 卻 highly active — 玩家主動 anticipate 週末 evolved sprite(P5 retention loop,ceremony 由 #29 交付)。

## Player Fantasy

### Core Identity:「身體嘅 ledger,唔係 cosplay」(The Body's Ledger, Not a Costume)

> **Avatar 係你身體數據嘅 visible ledger — 佢淨係 render 你 deposit 過嘅嘢,一毫子都唔會多。**

星期日早上,你做完一週第三次 leg day,喺更衣室打開 Mirror Hero 一眼。Avatar 嘅 silhouette 比上週微微闊咗 — 唔係衫升級,唔係 cosmetic unlock,**係 base sprite 換咗一個 evolved 版本**。你冇 swipe、冇 menu,0.3 秒 glance 就確認:「我練咗。」(嗰個截圖 + 對比 + share 嘅 ceremony 由 #29 交付 — #26 負責令 avatar 真係變咗。)

Avatar 喺 Mirror Hero **唔係 character,係 ledger** — 每一行 entry 對得返一次真實訓練,唔可以 cheat、唔可以 cosplay、唔可以靠 visual juice 偽裝。

### Anti-Fabrication 第七件套

#26 同 #2 / #3 / #11 / #14 / #9 / #15 組成 Pillar 1 anti-fabrication 七件套 — 各 own 一條防線。#26 嘅防線:**Visible state 唔講大話** — avatar 每個 visible 變化只能 derive from #11 Stat + #12 Ability canonical data;冇 visual fabrication path。Visible state is just stamped state, rendered.

### Fantasy Boundary

**In scope**:mid-set 0.3s glance readability(P2)· class-tagged posture differentiation 喺剪影層(P4)· tier evolution = base sprite swap derive from #11/#12 threshold(P5 render)· honest MVP delivery(single sprite + 3 anim + 3 posture + 4 tier)· **expose `get_evolution_snapshot()` + emit milestone trigger 俾 #29**。

**Explicitly NOT**(#26 唔做):layered armor visible system(v0.2)· 任何 visual-juice path 自己生成 avatar state(P1 violation)· cosmetic-only unlock 唔反映 body data · **Mirror Moment ceremony 構圖 / screenshot prompt / ghost overlay / share UI(→ #29)** · mid-set 凝視 avatar 嘅 mechanic(P2 violation)· calendar-based「today's outfit」rotation(P1 violation)。

### Falsifiable Tests (render-scope — ceremony tests moved to #29)

| # | Test | Falsification trigger | Pillar | Owner |
|---|------|----------------------|--------|-------|
| FT-1 | **Glance test** | 5 playtester mid-set 掃眼 1s,<80% 答到「class / action / tier 升咗冇」 | P2 | #26 |
| FT-3 | **Anti-fabrication audit** | static + runtime audit 顯示 ANY visible field 唔 100% derive from #11/#12 canonical signals | P1 | #26 |
| FT-4 | **Class silhouette test** | 純黑 16×16 剪影 quiz,<80% 分辨 STRIKE/CONTROL/MOBILITY | P4 | #26 |
| FT-5 | **Honest MVP expectation** | post-onboarding ≥20% 期待 layered armor / cutscene 而非 screenshot weekly + 3 anim | P5 | #26 (framing) |
| ~~FT-2~~ | **Screenshot share rate** | (≥30% weekly self-initiated share) — **MOVED TO #29** (ceremony owns the share funnel; #26 cannot be falsified by a behaviour it does not render) | P5 | **#29** |

### Design Test for Future Avatar Features

「Avatar 加 visual flair(光環 / cosmetic particle / class aura)」proposal 出現時問:**「呢個 visual element derive from 邊條 stat / ability / 真實 body data？」** 答唔到 → 唔加。Ledger framing 守住 anti-fabrication boundary。

## Detailed Design

### Ownership Seam with #29 Mirror Moment (ADR-0010)

| Concern | Owner | Interface |
|---------|-------|-----------|
| Derive + render avatar visible state (posture / tier / anim / sprite) | **#26** | internal |
| Tier-promotion detection + milestone trigger | **#26** | emit `avatar_evolution_milestone(tier, source_metrics)` |
| Weekly micro-evolution delta | **#26** | emit `avatar_micro_evolution(delta_kind, source_metrics)` + shader apply |
| Current render-state snapshot for ceremony | **#26** | `get_evolution_snapshot() -> AvatarEvolutionSnapshot` (read-only) |
| Ceremony composition (9:16 portrait, hero pose, ghost overlay, divider, tier badge) | **#29** | consumes snapshot + signal |
| Screenshot prompt UI / capture / share funnel | **#29** | own |
| Celebration VFX choreography + cadence-vs-ceremony framing | **#29** | own |
| FT-2 share-rate falsifiable test | **#29** | own |

This seam is the binding output of **ADR-0010**. #26 has **zero** ceremony render code; #29 has **zero** state-derivation code. The dependency is one-directional: #29 → #26.

### Core Rules

15 binding rules + INVs + 6 CI lints. Every rule is implementation-binding and tagged to a falsifiable test or pillar. Every constant referenced here is single-defined in **Tuning Knobs** and tracked in the **Representation Map**.

#### Sprite + Animation Surface

| # | Rule | Binding |
|---|------|---------|
| **CR-1** | **Sprite variant surface LOCKED** — visible state = (a) single base sprite (no layered armor), (b) class posture ∈ `{STRIKE, CONTROL, MOBILITY}`, (c) evolution tier ∈ `{T0,T1,T2,T3}`. Cartesian = 12 `SpriteFrames` resources, each with 3 internal animation tracks (idle/combat/cast). NO cosmetic overlay / equipment slot — adding an axis requires a v0.2 GDD revision. | P5 + game-concept anti-pillar |
| **CR-2** | **Animation FSM = 3 states** `IDLE / COMBAT / CAST` (mutually exclusive), driven by `AnimatedSprite2D` + hand-rolled FSM (NO `AnimationPlayer`). Signal source (Q-OQ2 Option C — `COMBAT_TICK` does not exist in GSM): (a) GSM `state_changed(_, to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, _)` → COMBAT (instant cut, boss shares combat anim per CR-1); (b) `#12.ability_cast(ability_id, caster, target)` with `caster == player` → CAST (instant), plays per CR-10, returns to COMBAT if GSM `current_state ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` else IDLE; (c) GSM `state_changed(from ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, to ∉ {…}, _)` → IDLE. | FT-4 + #25 contract + Q-OQ2 |
| **CR-3** | **Class posture derivation** — `dominant_class` from `#11.get_stat(STR/DEX/VIT)` 3 base stats: STRIKE=argmax(STR), CONTROL=argmax(DEX), MOBILITY=argmax(VIT). Deterministic tie-break `STRIKE > CONTROL > MOBILITY`. Re-evaluated on `#11.stat_changed` (stat_id ∈ {STR,DEX,VIT}); sprite swap respects CR-9 hysteresis. Per Formula 1. | FT-4 + P4 |
| **CR-4** | **Evolution tier derivation** — `evolution_tier` per **Formula 2** (generalist OR specialist path, data-driven via `AvatarEvolutionConfig.tres`). Monotonic non-decreasing — once T-k reached, never regresses (CR-12 historical-max lock; anti-pillar「缺日唔拎走嘢」). | FT-render + P5 |

#### Milestone + Micro-Evolution (triggers for #29)

| # | Rule | Binding |
|---|------|---------|
| **CR-5** | **Milestone trigger two-gate** — emit `avatar_evolution_milestone(tier, source_metrics)` (the #29 ceremony trigger) iff: (a) `current_tier > last_emitted_tier`; (b) cadence/first-boot gate per **Formula 3**; (c) **emit-deferral**: GSM ∉ `{WORKOUT_ACTIVE, REST_PERIOD}` (per CR-15 — defer, don't drop). `last_emitted_tier` + `last_milestone_emit_unix` persisted (CR-12). Idempotent on bootstrap re-derivation (gate a). **#26 only emits the trigger — #29 owns what happens next.** | P5 render + #29 contract |
| **CR-5b** | **Micro-evolution weekly delta** — emit `avatar_micro_evolution(delta_kind, source_metrics)` every `MICRO_EVOLUTION_CADENCE_SECONDS` (rolling, anchored to `account_created_unix`), derived from rolling 7-day stat delta (#11). Visual = **shader-only** (hue shift / outline brightness / breathing amplitude) — NOT a silhouette change, NO new sprite assets, NO tier change. **Honest framing**: silhouette CARRIES tier identity (major receipt, ≤4 over MVP); micro layer ADDS texture (minor, ~8 over MVP). Whether the micro layer is "enough" weekly retention is a **#29 ceremony-design question** (Q-OQ-RETENTION), not a #26 claim. | P5 render |

#### Anti-Fabrication + State Integrity

| # | Rule | Binding |
|---|------|---------|
| **CR-6** | **Anti-fabrication boundary (第七件套核心)** — every visible field of `AvatarVisualState` carries explicit derivation source attribution in `derived_from`. A field with no source attribution fails unit test. Mutation only inside `src/autoload/avatar_renderer.gd::_derive_state_from_canonical()` — any other file writing this type = CI-1 failure. | FT-3 + P1 |
| **CR-7** | **Z-order discipline** — CanvasLayer topology per ADR-0001: World (layer 0), **Character (layer `Z_INDEX_CHARACTER_LAYER`=10, avatar here, internal z_index ∈ [-10,10])**, **Particle (layer `Z_INDEX_PARTICLE_LAYER`=20, always above avatar)**, Event/HUD (layer 100). Avatar `z_index=0` within Character layer. NEVER raw z_index > 50. Combat/cast effect sprite displacement ≤4px; particle burst ≤2× sprite bbox. | FT-1 + Art Bible |
| **CR-8** | **Suspended handling** — GSM SUSPENDED (ADR-0006 Contract 6) → (a) **`AnimatedSprite2D.pause()`** (holds current frame — verified 4.6.3; `stop()` is FORBIDDEN here, it resets frame→0) + cache `_suspended_snapshot = {animation_state, current_frame:int, frame_progress:float, state_before_suspend, suspended_at_monotonic_ms:int}`; (b) emit no `avatar_visual_updated`; (c) reject incoming canonical signals (resume re-derives via CR-13). Resume per **Formula 5**: `delta_ms ≤ BFCACHE_CONTINUE_THRESHOLD_MS` → `play(animation_state)` + `set_frame_and_progress(current_frame, frame_progress)`; else / negative-delta → reset IDLE + re-derive. | ADR-0006 + #15 bfcache parity |
| **CR-9** | **Class posture hysteresis (combined lock)** — sprite swap respects: (a) `POSTURE_HYSTERESIS_SECONDS` (300) monotonic-clock cooldown since last swap (`Time.get_ticks_msec()`, NOT wallclock), OR (b) **workout-window lock**: GSM ∈ `{WORKOUT_ACTIVE, REST_PERIOD}` freezes posture entirely (no swap even on dominant_class jitter — avoids mid-set OR mid-rest flicker, P2 at the most attentive viewing moment). Workout-end mid-jitter: settle on workout-end snapshot's dominant class. Per **Formula 4**. **Aligned with CR-15** (both exclude the same `{WORKOUT_ACTIVE, REST_PERIOD}` set — no asymmetry). | FT-1 + P2 |
| **CR-10** | **Cast animation timing** — on `#12.ability_cast(…, caster==player)`: (a) onset ≤100ms (`play("cast")` synchronous); (b) hard gating window `CAST_HARD_WINDOW_MS`=300 uninterruptible; (c) wind-down to `CAST_TOTAL_MS`=500 interruptible by queue release; (d) `CAST_QUEUE_DEPTH`=1 — 2nd cast in hard window queues, queue-full drops oldest + `avatar_cast_dropped(ability_id)` telemetry. | #25 P3 + cross-spec |

#### API + Persistence

| # | Rule | Binding |
|---|------|---------|
| **CR-11** | **Read-only public API closure** — exactly these readers: `get_visual_state() -> AvatarVisualState` (returns `.duplicate()` — no external mutation by ref), `get_class_posture() -> StringName`, `get_evolution_tier() -> int`, `get_animation_state() -> StringName`, `is_ready_for_milestone_check() -> bool`, **`get_evolution_snapshot() -> AvatarEvolutionSnapshot`** (#29 ceremony seam). NO `set_*` / `mutate_*` / `force_*` / `inject_*` — any such prefix on public surface = CI-3 failure. Downstream (#22/#25/#29) read-only. | FT-3 + P1 + ADR-0010 |
| **CR-12** | **Persistence schema (`avatar.evolution_tier_history`)** — via PersistenceLayer (ADR-0003 IPersistence): `current_tier:int` (max ever, monotonic), `last_emitted_tier:int`, `last_milestone_emit_unix:int`, `last_micro_emit_unix:int`, `last_posture_switch_unix:int`, `tier_attainment_log: Array` (append-only, FIFO cap 52 = 1yr), `pending_milestone`. Schema v1; field change → ADR-0003 900ms migration. | P5 + ADR-0003 |
| **CR-13** | **Bootstrap from canonical state** — `_ready()` uses `connect_for_initial_state` (ADR-0006 Contract 6) for `#11.stat_changed` + `#12.ability_unlocked` + `#12.ability_cast` + GSM `state_changed`. On the `INITIAL_STATE` sentinel → `_derive_state_from_canonical()` via `#11.get_stat()` + `#12.get_unlocked_abilities()` sync read. No special bootstrap path — shares the normal derivation pipeline. Emits one final `avatar_visual_updated`. Milestone replay-safe via CR-5 gate (a). | ADR-0006 Contract 6 |

#### Platform + Operational + Ownership

| # | Rule | Binding |
|---|------|---------|
| **CR-14** | **Mobile fallback — sprite UNCHANGED, particle delegated** — per ADR-0001 + Art Bible §7: sprite render / frame rate / posture derivation UNCHANGED on mobile (silhouette is substrate). Only particle density → 0.5× (delegated to #5 internally; #26 platform-transparent). Idle outline shader MAY disable on mobile (combat-only) to save fragment budget. Texture-VRAM budget monitored via `Performance.RENDER_TEXTURE_MEM_USED` / `RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED` (NOT `MEMORY_STATIC`). | FT-1 + ADR-0001 |
| **CR-15** | **Milestone-emit deferral window** (NOT a ceremony rule — ceremony is #29) — `avatar_evolution_milestone` emit deferred while GSM ∈ `{WORKOUT_ACTIVE, REST_PERIOD}`. If CR-5 (a)+(b) satisfied mid-workout, set `_pending_milestone` + persist to `…pending_milestone`. On GSM exit of workout window → flush (FIFO if multiple). Persistence survives crash mid-pending. #26 still never renders a ceremony — it just times the *trigger* so #29 never receives one mid-set. | P2 + #29 contract |
| **CR-16** | **Class-derivation purity** — `dominant_class` uses ONLY `#11.get_stat(STR/DEX/VIT)` 3 base stats — never derived stat / ability count / loot / streak / workout history. Tier derivation (Formula 2) MAY use ability_count + stat_total + max_class_depth, but never streak / loot / equipment / cosmetic. Per CI-5. | FT-3 + P1 + P4 |
| **CR-17** | **Render-only ownership boundary (ADR-0010)** — #26 contains zero ceremony composition: no 9:16 portrait render, no hero-pose layout, no ghost-overlay compositing, no screenshot prompt, no share UI. Any such code in `src/autoload/avatar_renderer.gd` or `src/ui/avatar*` = design violation (CI-AVATAR-OWNERSHIP candidate / Pass-5 review check). #26 expresses the ceremony seam only as `get_evolution_snapshot()` + the two emit signals. | ADR-0010 + P5 ownership |

### AvatarVisualState Schema (`src/data/avatar_visual_state.gd`)

```gdscript
class_name AvatarVisualState extends Resource

# Identity (derived)
@export var evolution_tier: int            # 0..3 — Formula 2
@export var class_posture: StringName      # {&"STRIKE", &"CONTROL", &"MOBILITY"} — Formula 1
@export var animation_state: StringName    # {&"IDLE", &"COMBAT", &"CAST"} — CR-2 (SUSPENDED is engine pause, not a render state)

# Sprite frame state
@export var sprite_frames_resource_path: String  # res:// to current SpriteFrames .tres (PostureConfig LUT)
@export var current_frame: int             # 0..frame_count-1
@export var frame_progress: float          # [0.0,1.0] — for set_frame_and_progress() fractional restore

# Micro-evolution (shader-only delta — CR-5b)
@export var micro_palette_shift: float     # [0.0,1.0] hue rotation
@export var micro_outline_intensity: float # [0.0,1.0] outline brightness

# Milestone tracking
@export var last_emitted_tier: int
@export var last_milestone_emit_unix: int  # 0 = never (Formula 3 epoch-zero guard)

# Anti-fabrication traceability (CR-6 / INV-1)
@export var derived_from: Dictionary       # {field_name: source_signal_name} for FT-3 audit

# ADR-0006 Contract 2 traceability
@export var transition_id: int             # triggering GSM transition_id
@export var schema_version: int = 1
```

### AvatarEvolutionSnapshot Schema (the #29 ceremony seam — `src/data/avatar_evolution_snapshot.gd`)

```gdscript
class_name AvatarEvolutionSnapshot extends Resource
# A read-only, self-contained snapshot #29 uses to compose the weekly ceremony portrait.
# #26 produces it; #29 renders from it. #26 never renders the ceremony itself.
@export var tier: int                      # current evolution_tier
@export var class_posture: StringName
@export var sprite_frames_resource_path: String  # current (posture,tier) SpriteFrames
@export var hero_pose_frame: int           # the "mirror" pose frame index within that SpriteFrames (still-frame)
@export var prior_tier: int                # for #29 ghost-overlay comparison (last ceremonied tier)
@export var prior_sprite_frames_resource_path: String  # prior (posture,tier) for the ghost
@export var source_metrics: Dictionary     # {stat_total, ability_count, max_class_depth, achieved_at_unix}
@export var snapshot_taken_unix: int
```

> **Note**: the snapshot exposes a `hero_pose_frame` index + the SpriteFrames paths — it does NOT render anything. #29 decides the 9:16 canvas, the gradient background, the 30%-opacity ghost offset, the divider, the tier badge, the share affordance. This keeps Pillar-5 ceremony composition entirely in #29 (ADR-0010).

### PostureConfig LUT (`assets/data/posture_config.tres`)

```gdscript
class_name PostureConfig extends Resource
# (class_posture, evolution_tier) → SpriteFrames resource path. Key = "{CLASS}_{TIER}".
@export var posture_lut: Dictionary = {
    "STRIKE_T0": "res://assets/art/avatar/sprite_frames_t0_strike.tres",
    # … 12 entries total (3 classes × 4 tiers)
}
```
`_derive_sprite_frames(class_posture, evolution_tier) -> SpriteFrames` looks up `posture_lut["{CLASS}_T{tier}"]` → `load(path)`. Missing key → `EMERGENCY_AVATAR.tres` fallback (EC-ASSET-1).

### States and Transitions

#26 internal render-FSM = 4 states (IDLE / COMBAT / CAST / SUSPENDED) + a Booting bootstrap phase + an internal `_pending_milestone` flag (NOT a render state — it's emit-timing). Suspended is an engine `pause()`, not a distinct sprite.

| State | Entry | Allowed actions | Exit |
|-------|-------|-----------------|------|
| **Booting** | `_ready()`, before `connect_for_initial_state` completes | connect signals + receive `INITIAL_STATE` sentinel + `_derive_state_from_canonical()` | initial derive done + first `avatar_visual_updated` → **IDLE** |
| **IDLE** | bootstrap done + GSM `current_state ∉ {COMBAT_ACTIVE, BOSS_ENCOUNTER}`, OR exit from COMBAT/CAST | accept `#11.stat_changed` + `#12.ability_unlocked` → re-derive; play idle breathing; posture swap subject to CR-9 | GSM `state_changed(_, to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, _)` → COMBAT; `#12.ability_cast(caster==player)` → CAST; GSM SUSPENDED → SUSPENDED |
| **COMBAT** | GSM `state_changed(_, to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, _)` (Option C; boss shares this anim) | play combat loop; accept `#11.stat_changed` but defer sprite swap to next IDLE (mid-combat flicker guard) | GSM `state_changed(from ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, to ∉ {…}, _)` → IDLE; `#12.ability_cast(caster==player)` → CAST; GSM SUSPENDED → SUSPENDED |
| **CAST** | `#12.ability_cast(…, caster==player)` (onset ≤100ms) | play cast (300ms hard window uninterruptible; queue ≤1; refuse sprite swap during hard window) | hard window expires → wind-down (queue release) → finish at `CAST_TOTAL_MS` → COMBAT if GSM `current_state ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` else IDLE; GSM SUSPENDED → SUSPENDED |
| **SUSPENDED** | GSM SUSPENDED | cache `_suspended_snapshot`; **`AnimatedSprite2D.pause()`** (holds frame); reject canonical signals; no emit | GSM resume → Formula 5: `≤30s` restore snapshot (`play` + `set_frame_and_progress`); `>30s` / negative → IDLE + re-derive (CR-13) |

```
            _ready() → [Booting] → (INITIAL_STATE + derive) → [IDLE] ⇄ [COMBAT] ⇄ [CAST]
                                                                  └──────────────┘
            [SUSPENDED] reachable from {IDLE, COMBAT, CAST} via GSM SUSPENDED;
              resumes to prior state (≤30s snapshot) or IDLE (>30s re-derive).
            _pending_milestone flag holds a tier-promotion trigger while GSM ∈ workout window;
              flushes (emit avatar_evolution_milestone) on workout-window exit (CR-15).
```

### Autoload Boot Position (ADR-0008 ground truth — NOT hardcoded here)

**Anti-pattern guard (Pass 2 F-5 / Pass 3)**: the v1 GDD hardcoded "#26 position 11" and got it wrong (it had #11/#12 absent from the list). v2 states **only the partial-order constraints**; the absolute position is owned by `project.godot` + **ADR-0008 Autoload Position Map** (the sole ground truth — many autoloads shipped since 2026-05-28).

- **Hard predecessors** (must boot before #26): #11 StatSystem, #12 AbilitySystem (sync reads in `_derive_state_from_canonical`), #3 PersistenceLayer (CR-12 read), #1 GSM (cfis), #5 ParticleSystemWrapper (CR-7 emit target). Per ADR-0006 Contract 4 sequential boot, #26 `_ready()` runs after these.
- **No constraint** vs #14/#15/#21/#22/#23/#24 ordering — #26 only reads #11/#12/#3/#1/#5.
- **Action for epic**: insert #26 into `project.godot` after its predecessors and add the ADR-0008 amendment recording the absolute position chosen (do not assert a number in this GDD).

Init sequence (`_ready`): (1) `load(AvatarEvolutionConfig.tres)` fail-hard if missing (EC-BOOT-2); (2) preload current + adjacent tier SpriteFrames (lazy GPU upload); (3) `connect_for_initial_state(…)` 4 subscriptions; (4) `PersistenceLayer.read("avatar.evolution_tier_history")` rebuild counters; (5) `_derive_state_from_canonical()` + apply posture (first-boot exempt from CR-9 cooldown); (6) emit one `avatar_visual_updated` → IDLE; (7) if persisted `_pending_milestone` → CR-15 check.

### CI Lint Suite

| Script | Path | Target |
|--------|------|--------|
| **CI-1** | `tools/ci/check_avatar_visual_state_derivation.gd` | every `AvatarVisualState.*` field write is inside `avatar_renderer.gd::_derive_state_from_canonical()` and traces to a canonical handler/sync-read (CR-6) |
| **CI-2** | `tools/ci/check_avatar_evolution_thresholds_data_driven.gd` | tier thresholds load from `avatar_evolution_config.tres` — zero hardcoded literals in `.gd` (CR-4); + `BFCACHE_CONTINUE_THRESHOLD_MS` parity assert (INV-5) |
| **CI-3** | `tools/ci/check_avatar_renderer_no_setter_api.gd` | no `set_*/mutate_*/force_*/inject_*` on `avatar_renderer.gd` public surface (CR-11) |
| **CI-4** | `tools/ci/check_avatar_z_order.gd` | avatar `z_index ∈ [-10,10]`; CanvasLayer.layer==10; particle Z≥20 (CR-7 + INV-3) |
| **CI-5** | `tools/ci/check_avatar_class_derivation_purity.gd` | `dominant_class` path references ONLY `#11.get_stat(STR/DEX/VIT)` (CR-16) |
| **CI-6** | `tools/ci/check_avatar_renderer_callers.gd` | `AnimatedSprite2D.sprite_frames` assignment only inside `avatar_renderer.gd`; **and zero `AnimationPlayer` usage in #26 source** (Representation Map API fact) |

## Formulas

> #26 owns 5 supplementary formulas (+1 micro-evolution cadence helper). It re-derives NO upstream value — ADR-0005 owns loot rarity, #11 owns derived stats, #12 owns ability unlocks.

### Formula 1 — `dominant_class_derivation`

```
# inputs: STR, DEX, VIT from #11.get_stat (lowercase ids "str"/"dex"/"vit")
if STR >= DEX and STR >= VIT: return STRIKE
elif DEX >= VIT:              return CONTROL
else:                         return MOBILITY
```

| Symbol | Type | Range | Source |
|--------|------|-------|--------|
| STR / DEX / VIT | int | 0–999 | `#11.get_stat("str"/"dex"/"vit")` (CI-1 sync read) |
| dominant_class | enum | {STRIKE, CONTROL, MOBILITY} | output |

**Output**: exactly one of {STRIKE, CONTROL, MOBILITY} — never null/multiple (CF-1). Deterministic tie-break `STRIKE > CONTROL > MOBILITY` via the top-down `>=` chain.

| STR | DEX | VIT | Out | Reason |
|-----|-----|-----|-----|--------|
| 50 | 30 | 20 | STRIKE | STR max |
| 30 | 50 | 20 | CONTROL | DEX max |
| 20 | 30 | 50 | MOBILITY | VIT max |
| 40 | 40 | 20 | STRIKE | STR=DEX tie → head |
| 20 | 40 | 40 | CONTROL | DEX=VIT tie → CONTROL |
| 0 | 0 | 0 | STRIKE | fresh account default |

### Formula 2 — `evolution_tier_derivation` (specialist/generalist symmetric — fixes Pass-4 F-2)

> **Pass-4 F-2 defect (the one that survived 4 passes)**: the v1 specialist path gated T3 on `#12.get_max_unlocked_class_tier()` — **a method that does NOT exist in shipped #12** (grep-verified: #12 exposes only `get_unlocked_abilities()` + `get_ability_state()`). Worse, the *generalist* `stat_total` SUM gate structurally penalised pure specialists (one stat grows slower than three summed) → a pure specialist could be locked below max tier, then frozen there by the CR-12 monotonic lock. v2 gives the two builds **independent, symmetric paths** that never route through each other's gate.

```
# Canonical inputs (all from shipped read APIs — no phantom):
stat_total      = #11.get_stat("str") + #11.get_stat("dex") + #11.get_stat("vit")   # breadth volume
peak_stat       = max(#11.get_stat("str"), #11.get_stat("dex"), #11.get_stat("vit")) # depth volume
ability_count   = #12.get_unlocked_abilities().size()                                # breadth count
max_class_depth = max tier ordinal (1..3) reached in ANY single class, 0 if none     # depth mastery
                  # derived client-side from get_unlocked_abilities() keys (ADR-0011);
                  # (class,tier)-of-ability_id resolution = Q-OQ-DEPTH forward contract on #12.

# Two complete, independent paths. Generalist = breadth; specialist = concentrated mastery.
generalist_ok(t) = (stat_total >= S_t)      and (ability_count   >= A_t)
specialist_ok(t) = (peak_stat  >= S_peak_t) and (max_class_depth >= D_t)
computed_tier    = max{ t in {0,1,2,3} : generalist_ok(t) or specialist_ok(t) }   # T0 always passes
effective_tier   = max(computed_tier, historical_max_tier)                        # CR-12 monotonic lock
```

| Threshold | T0 | T1 | T2 | T3 | Knob |
|-----------|----|----|----|----|------|
| `S_t` (stat_total) | 0 | 30 | 60 | 100 | TUNABLE |
| `A_t` (ability_count) | 0 | 1 | 3 | 6 | TUNABLE |
| `S_peak_t` (peak_stat) | 0 | 20 | 40 | 70 | TUNABLE |
| `D_t` (max_class_depth) | 0 | 1 | 2 | 3 | TUNABLE |

| Build | stat_total | peak | ability_count | depth | tier | path |
|-------|-----------|------|---------------|-------|------|------|
| generalist | 102 | 34 | 6 | 2 | **T3** | generalist (sum≥100 ∧ count≥6) |
| pure STRIKE specialist | 80 | 70 | 3 | 3 | **T3** | specialist (peak≥70 ∧ depth≥3) — *not* locked |
| early specialist | 45 | 40 | 2 | 2 | **T2** | specialist (peak≥40 ∧ depth≥2) |
| new player | 20 | 12 | 0 | 0 | **T0** | neither path past T0 |
| tier-drop after rebalance | 55 | 30 | 2 | 1 | **T2** | computed T1 but historical_max T2 lock holds |

Both paths anchor only to canonical #11/#12 data (P1) and both deliver the Pillar-4 「specialist build viable」promise. `effective_tier` is monotonic non-decreasing (CF-2); a tightened `.tres` can lower `computed_tier` but never `effective_tier` (anti-pillar「缺日唔拎走嘢」).

### Formula 3 — `milestone_two_gate_check` (the #29 trigger gate; epoch-zero guarded)

```
should_emit = gate_a and gate_b and gate_c
gate_a = current_tier > last_emitted_tier
gate_b = (last_emit_unix == 0)
            ? (observed_session_count >= MIN_OBSERVED_SESSIONS              # first-boot path
               and (now_unix - account_created_unix) >= FIRST_BOOT_GRACE_SECONDS)
            : (now_unix - last_emit_unix) >= MILESTONE_CADENCE_SECONDS      # subsequent: 7-day cadence
gate_c = gsm_state not in {WORKOUT_ACTIVE, REST_PERIOD}                     # emit-deferral (CR-15)
```

> **Epoch-zero guard (Pass-2 F-1, kept)**: a fresh account has `last_emit_unix == 0`, so `now - 0 ≈ 55 years > cadence` would ALWAYS pass the naive cadence test — GymSys historical backfill could fire a tier-up ceremony before the player does a single observed rep (Pillar-1「cosplay」leak). gate_b's first-boot branch requires ≥`MIN_OBSERVED_SESSIONS` (1) observed in-app session AND ≥`FIRST_BOOT_GRACE_SECONDS` (48h) since account creation.

| current | last_emit | Δs | gsm_state | result |
|---------|-----------|-----|-----------|--------|
| T2 | T1 | 800000 | IDLE | **emit** |
| T1 | T1 | 800000 | IDLE | suppress (no promotion) |
| T2 | T1 | 300000 | IDLE | suppress (cadence) |
| T2 | T1 | 800000 | WORKOUT_ACTIVE | defer → `_pending_milestone` (CR-15) |
| T1 | T0 (first, Δ=0/epoch) | — | IDLE, 0 sessions | suppress (epoch-zero guard) |

**Output**: bool — true only when all gates pass (CF-3). gate_c=false → defer to `_pending_milestone`, flush on workout-window exit.

### Formula 3b — `micro_evolution_cadence_check` (weekly shader delta — CR-5b)

```
should_micro = (now_unix - last_micro_emit_unix) >= MICRO_EVOLUTION_CADENCE_SECONDS
                and (rolling_7day_stat_delta > 0)         # only if real training happened
                and gsm_state not in {WORKOUT_ACTIVE, REST_PERIOD}
```
Emits `avatar_micro_evolution(delta_kind, source_metrics)` → shader uniform tween (hue/outline/breathing). NOT gated by tier promotion; NOT a silhouette change; NO sprite asset. Honest: this is texture, not a new tier.

### Formula 4 — `hysteresis_check` (workout-window aligned with CR-9/CR-15 — fixes Pass-4 drift)

```
# Pass-3/4 drift: v1 Formula 4 body still tested only WORKOUT_ACTIVE while CR-9/CR-15 excluded
# BOTH workout states. v2 aligns all three on {WORKOUT_ACTIVE, REST_PERIOD} (shipped enum names).
can_swap = (not workout_window_lock) and (new_class != last_class) and cooldown_elapsed

workout_window_lock = gsm_state in {WORKOUT_ACTIVE, REST_PERIOD}              # both states
cooldown_elapsed    = (now_monotonic_ms - last_switch_monotonic_ms) >= POSTURE_HYSTERESIS_SECONDS * 1000
                      # monotonic clock (Time.get_ticks_msec()), NOT wallclock
```

| new | last | Δ(monotonic) | gsm_state | result | reason |
|-----|------|-------------|-----------|--------|--------|
| CONTROL | STRIKE | 400s | IDLE | **true** | all gates pass |
| CONTROL | STRIKE | 120s | IDLE | false | cooldown not elapsed |
| CONTROL | STRIKE | 400s | WORKOUT_ACTIVE | false | workout-window lock |
| MOBILITY | CONTROL | 400s | **REST_PERIOD** | **false** | workout-window lock (v1 bug: this wrongly returned true) |
| STRIKE | STRIKE | 9999s | IDLE | false | no-op (same class) |

### Formula 5 — `bfcache_resume_action` (monotonic + negative-delta guard + verified pause/restore API)

```
suspended_at_monotonic_ms = Time.get_ticks_msec() at suspend
resumed_at_monotonic_ms   = Time.get_ticks_msec() at resume
raw_delta_ms = resumed_at_monotonic_ms - suspended_at_monotonic_ms
if raw_delta_ms < 0:                                # monotonic anomaly (extremely rare)
    emit_telemetry("avatar_monotonic_anomaly", raw_delta_ms)
    return RESET_TO_IDLE_REDERIVE                   # untrusted clock → safe re-derive
delta_ms = max(0, raw_delta_ms)
action = RESTORE_SNAPSHOT if delta_ms <= BFCACHE_CONTINUE_THRESHOLD_MS else RESET_TO_IDLE_REDERIVE
```

- `RESTORE_SNAPSHOT` → `AnimatedSprite2D.play(animation_state)` + `set_frame_and_progress(current_frame, frame_progress)` (verified 4.6.3 API).
- `RESET_TO_IDLE_REDERIVE` → re-fetch #11/#12 canonical, re-derive, force IDLE.
- `BFCACHE_CONTINUE_THRESHOLD_MS` = 30000, MUST equal `#15.Rule17` (INV-5 / CI-4).

| Δms | action |
|-----|--------|
| 5000 | RESTORE_SNAPSHOT |
| 30000 | RESTORE_SNAPSHOT (inclusive) |
| 30001 | RESET_TO_IDLE_REDERIVE |
| −5000 (NTP) | RESET_TO_IDLE_REDERIVE + anomaly telemetry |

### Cross-Formula / Cross-System Invariants

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| CF-1 | F1 returns exactly 1 of {STRIKE,CONTROL,MOBILITY} | top-down `>=` chain + STRIKE default |
| CF-2 | F2 `effective_tier` monotonic non-decreasing | CR-12 historical_max lock + INV-4 |
| CF-3 | F3 / F4 true only when ALL sub-gates pass | short-circuit AND |
| CF-4 | F5 threshold == `#15.Rule17.BFCACHE_CONTINUE_THRESHOLD_MS` | shared const + CI-4 |
| CI-INV-1 | F1/F2 stat inputs are `#11.get_stat()` sync reads, never cached | #11 authority (CI-1) |
| CI-INV-2 | F2 `ability_count`/`max_class_depth` from `#12.get_unlocked_abilities()`, never inferred from stat/equipment | #12 authority (CI-5) |
| CI-INV-5 | all formula inputs deterministic — no RNG, no time-dependent except explicit wallclock cadence | P1 purity |

### Cross-Knob Invariants (config load-time asserts)

| ID | Invariant |
|----|-----------|
| INV-1 | every `AvatarVisualState` visible field traces to a canonical source in `derived_from` (CI-1) |
| INV-2 | `POSTURE_HYSTERESIS_SECONDS*1000 ≥ CAST_TOTAL_MS` and `CAST_HARD_WINDOW_MS < CAST_TOTAL_MS` (timing monotonic) |
| INV-3 | `Z_INDEX_CHARACTER_LAYER(10) < Z_INDEX_PARTICLE_LAYER(20) < 100` (hardcoded const, not a knob) |
| INV-4 | persisted `current_tier ≥ last_emitted_tier ≥ 0` (load-time assert → migration on violation) |
| INV-5 | `BFCACHE_CONTINUE_THRESHOLD_MS == #15.Rule17` (cross-system const, CI-4) |
| INV-6 | texture VRAM ≤ 600 KB mobile (current+adjacent tier) / ≤ 2.3 MB desktop (all 12), measured via `RENDER_TEXTURE_MEM_USED` (NOT `MEMORY_STATIC`) |
| INV-G1 | `S_t` strictly increasing; `A_t`, `S_peak_t`, `D_t` monotonic non-decreasing |

## Edge Cases

> 28 edge cases, mnemonic category IDs (stable for Representation-Map references — avoids the v1 "41 vs 52" numeric-count drift that bit Passes 3/4). Severity: CRITICAL (pillar/data) / HIGH (UX) / MEDIUM (recoverable) / LOW (documented).

### Boot + Persistence
- **EC-BOOT-1 (CRITICAL)** — `user://` unavailable (Private Mode, ADR-0003): skip `avatar.evolution_tier_history` load; `last_emitted_tier = current_tier`; `persistence_degraded = true`; suppress all milestone + micro emits this session (prevents dup on next restore). Ref CR-13/INV-4.
- **EC-BOOT-2 (CRITICAL)** — `AvatarEvolutionConfig.tres` missing: hard assert + crash (NO hardcoded fallback — P1). Ref CR-4/CI-2.
- **EC-BOOT-3 (CRITICAL)** — config `version_hash` ≠ persisted `config_hash_at_last_emit`: re-derive `last_emitted_tier` from current stats; clear pending; log `config_drift_recovery`; do NOT replay across config versions.
- **EC-BOOT-4 (HIGH)** — persisted `current_tier > 3` (future T4+): clamp to T3; `last_emitted_tier = current_tier` post-clamp; log `tier_downgrade_migration`.
- **EC-BOOT-5 (CRITICAL)** — persisted `last_emitted_tier > current_tier` (INV-4 violation): treat as corruption; `last_emitted_tier = current_tier`; no emit this session; log `persistence_corruption`.

### Signal Subscription + Race
- **EC-SIG-1 (CRITICAL)** — `#11.stat_changed` fires before `_ready()` completes: drop (do NOT queue); re-derive from `get_stat()` snapshot post-ready (CR-6). ADR-0006 Contract 4 guarantees #11 boots first.
- **EC-SIG-2 (HIGH)** — `#12.ability_cast(caster==player)` while Booting: drop; telemetry `cast_dropped_pre_ready`.
- **EC-SIG-3 (CRITICAL)** — `#11.get_stat()` returns NaN / −1 sentinel: treat as 0 in F1/F2; never propagate NaN into deterministic tie-break; log `stat_sentinel_received`.
- **EC-SIG-4 (HIGH)** — any stat negative (upstream bug): clamp to 0 before F1/F2; log `negative_stat_received` CRITICAL.
- **EC-SIG-5 (MEDIUM)** — GSM `state_changed` value not in known enum: ignore; retain previous anim state; log `unknown_gsm_state` once/session.

### Class Posture (Formula 1)
- **EC-CLASS-1 (MEDIUM)** — three-way tie STR=DEX=VIT: → STRIKE (CR-3 order). Fresh account (all 0) → STRIKE T0 valid.
- **EC-CLASS-2 (MEDIUM)** — two-way top tie STR=DEX>VIT: → STRIKE per order.

### Evolution Tier (Formula 2)
- **EC-TIER-1 (HIGH)** — neither path past T0 despite some stat: stay T0 (both gates require ability_count≥1 OR depth≥1 at T1). Documented — stat-only never advances (P1: tier needs *earned* ability/depth, not just volume).
- **EC-TIER-2 (CRITICAL)** — `AvatarEvolutionConfig.tres` hot-reload mid-session (version_hash change): REJECT (`CACHE_MODE_REPLACE` forbidden at runtime); log `config_hot_swap_rejected`; resolve only at next boot via EC-BOOT-3.
- **EC-TIER-3 (LOW)** — `stat_total`/`peak_stat` exactly on a threshold: inclusive on the upper tier (`>=`). Deterministic.
- **EC-TIER-4 (HIGH)** — tier jumps T1→T3 in one derivation (post-rebalance / bootstrap): emit ONE milestone `{tier:T3, skipped_tiers:[T2]}` — never two ceremonies (#29 gets one trigger). Ref CR-5.
- **EC-TIER-5 (MEDIUM)** — `max_class_depth` unresolvable (Q-OQ-DEPTH contract returns ambiguous (class,tier)): treat depth as 0 (specialist path off); generalist path still works; log `class_depth_unresolved`. Fail-safe — never crashes tier derivation.

### Animation FSM
- **EC-ANIM-1 (HIGH)** — `ability_cast` twice within 50ms: 2nd enters 1-deep queue; queue full → drop newest + `cast_queue_overflow`. Ref CR-10.
- **EC-ANIM-2 (HIGH)** — new cast during 300ms hard window: buffer into 1-deep queue; play on `animation_finished`. 3rd → drop oldest queued (most-recent intent wins).
- **EC-ANIM-3 (HIGH)** — GSM exits combat mid-cast: cast MUST complete (atomicity); transition to GSM-derived state post-finish.
- **EC-ANIM-4 (MEDIUM)** — `AnimatedSprite2D` reports frame inconsistent with FSM (stuck/desync): force IDLE animation; clear cast queue; log `animation_desync_recovery`. (`AnimatedSprite2D`-only — no `AnimationPlayer` in #26.)
- **EC-ANIM-5 (MEDIUM)** — sprite swap requested during active cast: defer to `animation_finished` (atomicity); overwrite any queued swap intent.

### Class Posture Hysteresis (Formula 4)
- **EC-HYST-1 (HIGH)** — dominant_class flickers within cooldown: suppress; "would-have-switched" does NOT reset cooldown (only an actual swap does).
- **EC-HYST-2 (MEDIUM)** — workout-end while posture jittering: settle on workout-end snapshot's dominant class; commit; start fresh cooldown.
- **EC-HYST-3 (HIGH)** — wallclock jumps backward (DST/NTP) during cooldown: cooldown uses `Time.get_ticks_msec()` monotonic — wallclock anomaly cannot affect it.

### Milestone Trigger (Formula 3)
- **EC-MILE-1 (HIGH)** — tier-up gate passes but cadence fails: no emit; silently set `last_emitted_tier = current_tier` (absorb without ceremony — prevents stuck-pending-forever).
- **EC-MILE-2 (HIGH)** — both gates pass but workout window active: defer via `_pending_milestone` (persist); flush on workout-window exit (CR-15).
- **EC-MILE-3 (CRITICAL)** — pending milestone exists at boot (crash mid-workout): re-validate gate_a + cadence against current state; valid → emit on next workout-exit OR after `WORKOUT_END_GRACE_SECONDS` if no workout; invalid → drop + log `stale_pending_milestone_dropped`.
- **EC-MILE-4 (MEDIUM)** — bootstrap finds prior-session `pending_milestone`: replay-safe — emission keyed `(tier, emit_attempt_id)` UUID; #29 dedupes on UUID.
- **EC-MILE-5 (CRITICAL)** — #29 not registered when milestone emits: buffer in `pending_emit_queue` (max 3 FIFO); retry up to `MIRROR_MOMENT_PENDING_BUFFER_FRAMES`; still no listener → persist as `pending_milestone`, surface next boot. **Never silently drop** (P5 ritual integrity). Ref CR-15.

### Bfcache / Tab Switch (Formula 5)
- **EC-SUS-1 (MEDIUM)** — suspend < 30s: restore snapshot via `play` + `set_frame_and_progress`. No re-derive.
- **EC-SUS-2 (HIGH)** — suspend ≥ 30s OR negative delta: reset IDLE + re-derive (CR-6). Note: resume restore uses `pause()`-cached frame (NOT `stop()`, which would have reset frame→0 — verified 4.6.3).
- **EC-SUS-3 (HIGH)** — suspend mid-cast (within hard window): on resume, synthesize `animation_finished` — do NOT restore mid-cast frame (atlas may have unloaded); process queued cast normally.
- **EC-SUS-4 (CRITICAL)** — suspend after milestone emit but before persistence flush (split-brain): on resume trust in-memory `last_emitted_tier`, re-flush; #29 UUID-dedupes (EC-MILE-4).
- **EC-SUS-5 (MEDIUM)** — WebGL context lost during suspend: textures re-upload on restore (4.6 default); force one IDLE frame to guarantee binding; log `webgl_context_restored`.

### Sprite Asset + Cross-System
- **EC-ASSET-1 (CRITICAL)** — `SpriteFrames` for (posture,tier) fails to load: fall back to `EMERGENCY_AVATAR.tres` (preloaded T0 STRIKE idle); disable cast/combat anim; log `sprite_load_failure`. Silhouette never breaks (INV-1).
- **EC-ASSET-2 (HIGH)** — tier preload exceeds mobile budget: lazy-load current + adjacent (T_n-1/T_n/T_n+1) only; discard ≤ T_n-2 (INV-6).
- **EC-XSYS-1 (HIGH)** — #5 ParticleSystemWrapper unavailable for an avatar preset: emit milestone to #29 anyway; skip particle; log `particle_wrapper_unavailable` (silhouette > decoration, CR-14).
- **EC-XSYS-2 (HIGH)** — GSM signal storm (>10 `state_changed`/100ms): 16ms debounce on GSM-derived anim transitions (only final state per window). Cast NOT debounced (atomicity).

## Dependencies

### Upstream Hard Dependencies (all shipped + grep-verified)

| Dep | Type | Interface (verified) | Bidirectional sync |
|-----|------|----------------------|--------------------|
| **#11 Stat System** (shipped) | signal + sync read | `stat_changed(stat_id, old, new, source)` via cfis; `get_stat(stat_id)` (lowercase ids) for F1/F2 | #11 GDD lists #26 downstream (highest cascade row) |
| **#12 Ability System** (shipped) | signal + sync read | `ability_unlocked(ability_id, source)` + `ability_cast(ability_id, caster, target)` via cfis; **`get_unlocked_abilities() -> Dictionary`** for ability_count + max_class_depth (NO `get_max_unlocked_class_tier()` — that was a v1 phantom) | #12 GDD lists #26 downstream |
| **#1 GSM** (shipped) | signal + sync read | `state_changed(from, to, payload)` (CR-2 Option C), `current_state` membership (CR-9/CR-15), SUSPENDED (CR-8); cfis Contract 6 | widely subscribed |
| **#3 PersistenceLayer** (shipped) | bidirectional | owns `avatar.evolution_tier_history` namespace (CR-12); ADR-0003 IPersistence; 900ms migration | #3 registers `avatar.*` consumer |
| **#5 ParticleSystemWrapper** (shipped) | downstream API call | `emit_preset(preset_id, anchor)` — 3 presets `avatar_stat_glow` / `avatar_cast_burst` / `avatar_evolution_reveal`; Z-order CR-7; mobile 0.5× delegated | ⚠️ FORWARD: 3 new presets → flag for #5 next revision |

### Downstream Dependents

| System | Reverse dependency |
|--------|--------------------|
| **#22 Character Screen** (shipped) | reads `get_visual_state()` / `get_class_posture()` / `get_evolution_tier()`; subscribes `avatar_visual_updated`. **Note**: #22 shipped before #26 — its avatar read calls are an integration seam to wire when #26 lands (verify #22's stubs against CR-11 API names during the #26 epic). |
| **#25 Combat Visual Feedback** (Not Started) | subscribes `avatar_visual_updated` + `animation_state_changed(new_state)`; reads avatar pixel position for VFX anchor |
| **#29 Mirror Moment System** (Not Started) | subscribes `avatar_evolution_milestone(tier, source_metrics)`; calls `get_evolution_snapshot()` to compose ceremony. **#29 owns ALL ceremony render** (ADR-0010). |

### Forward Constraints to Downstream

| ID | Constraint | Receiver |
|----|-----------|----------|
| FC-1 | `AvatarVisualState` schema stable (posture/tier/anim) | #22, #25, #29 |
| FC-2 | `avatar_evolution_milestone(tier:int 0-3, source_metrics:Dictionary {stat_total, ability_count, max_class_depth, achieved_at_unix})` frozen | #29 |
| FC-3 | `AvatarEvolutionSnapshot` schema frozen (the ceremony seam) | #29 |
| FC-4 | `animation_state_changed(new_state: StringName)` frozen | #25 |
| FC-5 | avatar z_index ∈ [-10,10] within Character CanvasLayer=10 | #5, #20 HUD |
| FC-6 | 3 new #5 particle presets | #5 |

### ADR Dependencies

ADR-0001 (sprite draw-call + atlas budget + bfcache 30s parity) · ADR-0003 (`avatar.*` namespace + Private Mode) · ADR-0006 (Contract 4 boot, Contract 6 cfis) · ADR-0008 (absolute autoload position — ground truth) · **ADR-0010 (render-vs-ceremony ownership split — this GDD + #29 ratify; currently Proposed)** · ADR-0011 (client-side derivation pattern for `max_class_depth`).

## Tuning Knobs

> Stability: **LOCKED** (ADR/pillar to change) · **DESIGN-FROZEN** (GDD revision) · **TUNABLE** (`.tres`).

### Owned (single definition site — must match Representation Map)

| Knob | Default | Safe range | Stability | Effect |
|------|---------|-----------|-----------|--------|
| `S_t` stat thresholds | {0,30,60,100} | per-tier, strictly increasing | TUNABLE | F2 generalist stat gate |
| `A_t` ability thresholds | {0,1,3,6} | monotonic | TUNABLE | F2 generalist breadth gate |
| `S_peak_t` peak thresholds | {0,20,40,70} | monotonic | TUNABLE | F2 specialist peak gate |
| `D_t` class-depth thresholds | {0,1,2,3} | monotonic | TUNABLE | F2 specialist depth gate |
| `POSTURE_HYSTERESIS_SECONDS` | 300 | [120,900] | DESIGN-FROZEN | CR-9/F4 cooldown |
| `MILESTONE_CADENCE_SECONDS` | 604800 | [259200,1209600] | DESIGN-FROZEN | CR-5/F3 cadence |
| `MICRO_EVOLUTION_CADENCE_SECONDS` | 604800 | [259200,1209600] | TUNABLE | CR-5b/F3b weekly micro |
| `CAST_HARD_WINDOW_MS` | 300 | [150,500] | LOCKED | CR-10 uninterruptible window (P3 game-feel) |
| `CAST_TOTAL_MS` | 500 | [300,700] | DESIGN-FROZEN | CR-10 total cast anim |
| `CAST_QUEUE_DEPTH` | 1 | LOCKED | LOCKED | CR-10 (>1 → thrash; 0 → cancel model) |
| `BFCACHE_CONTINUE_THRESHOLD_MS` | 30000 | LOCKED | LOCKED | INV-5 parity with #15.Rule17 |
| `Z_INDEX_CHARACTER_LAYER` | 10 | LOCKED | LOCKED | CR-7/INV-3 |
| `Z_INDEX_PARTICLE_LAYER` | 20 | LOCKED | LOCKED | CR-7/INV-3 (> character) |
| `FIRST_BOOT_GRACE_SECONDS` | 172800 | [86400,604800] | TUNABLE | F3 epoch-zero guard |
| `MIN_OBSERVED_SESSIONS` | 1 | [1,5] | TUNABLE | F3 epoch-zero guard |
| `SPRITE_MEMORY_BUDGET_MOBILE_KB` | 600 | [400,1024] | DESIGN-FROZEN | INV-6 mobile (512MB browser cap) |
| `SPRITE_MEMORY_BUDGET_DESKTOP_KB` | 2300 | [1500,4000] | TUNABLE | INV-6 desktop all-12 |
| `MIRROR_MOMENT_PENDING_BUFFER_FRAMES` | 60 | [30,180] | TUNABLE | EC-MILE-5 retry budget |
| `WORKOUT_END_GRACE_SECONDS` | 30 | [10,120] | TUNABLE | EC-MILE-3 boot grace |
| `GSM_SIGNAL_DEBOUNCE_MS` | 16 | [8,33] | TUNABLE | EC-XSYS-2 storm debounce |
| `EMERGENCY_AVATAR_FALLBACK` | T0_STRIKE_IDLE | — | LOCKED | EC-ASSET-1 fallback (always preloaded) |

### Referenced (other systems own; #26 reads)

`#15.BFCACHE_CONTINUE_THRESHOLD_MS` (30000, INV-5 parity) · `#5.mobile_fallback_multiplier` (0.5) · `#5.MAX_ACTIVE_PARTICLES` (200, ADR-0001) · `#11.StatId` lowercase StringName ids · `#12 ability_count_max` (9 = 3 class × 3 tier).

## Visual / Audio Requirements

> Art Bible Direction A (Maple Pixel + Particle Storm) + Silhouette First + Layer Discipline. **Mirror Moment ceremony composition is NOT here — it migrated to #29 per ADR-0010.** This section covers only what #26 renders: postures, animation states, tier sprite variants.

### A. Class Posture Differentiation (16×16 silhouette)

| Class | Stance | Weapon silhouette | 16×16 黑剪影 identifying axis |
|-------|--------|-------------------|------------------------------|
| **STRIKE** | wide planted (feet 4px), 重心低 | short thick (gauntlet/hammer ≤6px), at hip | **bottom-heavy triangle** (下半身寬厚) |
| **CONTROL** | neutral upright (feet 2px), hands forward | long staff/orb 8-10px, vertical | **tall pillar** (垂直長條 + 頭頂 weapon mass) |
| **MOBILITY** | narrow staggered (feet 1px, 一前一後), torso twist | twin short blades ≤4px, split | **asymmetric Y-pose** (窄底 + 不對稱手伸展) |

**Verification**: 純黑 16×16 剪影降至 8×8 仍要分辨 — STRIKE 著地 / CONTROL 拔尖 / MOBILITY 歪斜。AC-32 / FT-4 ≥80% accuracy.

### B. Animation State Spec

| State | Baseline | Loop | Duration | Trigger |
|-------|----------|------|----------|---------|
| idle | 2-frame breathing (sub-pixel bob) | loop | 1.2s/cycle | default (P2 low-momentum) |
| combat | 4-frame attack cycle | one-shot→idle | 0.4s @100ms/frame | GSM `state_changed(_, to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, _)` (Option C) |
| cast | 3-frame charge + 1 release | one-shot→idle | `CAST_TOTAL_MS`=500 (300 hard + 200 wind-down) | `#12.ability_cast` |

idle→combat/cast: instant cut (0.3s readability, P2). combat/cast→idle: 1-frame ease-out. combat⇄cast: via 1 idle buffer frame.

### C. Tier Sprite Variant Spec (silhouette-anchored, visible at 8×8)

| Tier | Visible change | Trigger | Class-specific? |
|------|----------------|---------|-----------------|
| T0 | 4-head baseline, no aura | new player | agnostic skeleton |
| T1 | spine straighten +1px height, shoulder +1px | F2 T1 | agnostic |
| T2 | bulk: STRIKE shoulder +2px / CONTROL staff +2px / MOBILITY waist −1px lean | F2 T2 | **class-specific** (P4) |
| T3 | 1px outline + breathing halo + cape/trail 2-3px (STRIKE solid / CONTROL wispy / MOBILITY streak) | F2 T3 | class-specific aura |

All tier values data-driven via `AvatarEvolutionConfig.tres` (CR-4). **Micro-evolution (CR-5b) is shader-only** (hue/outline/breathing) — NOT a sprite asset, NOT a silhouette change.

### D. Anti-Pillar Visual Guards

| Pillar | Rule |
|--------|------|
| P1 | tier transitions driven by `.tres` data ↔ GymSys metric — no cosmetic-only / random upgrade (FT-3 + CI-1) |
| P2 | 0.3s glance: idle sub-pixel bob only, no large idle particle, no attention-grab cycle (FT-1) |
| P3 | combat/cast sprite displacement ≤4px, no full-screen flash, particle ≤2× bbox — avatar supports #21/#25, never competes |
| P4 | class diff enforced at 16×16 黑剪影 (FT-4 ≥80%) |
| P5 | **#26 delivers the silhouette-level tier delta** that makes the weekly screenshot worth taking; the ceremony framing / "is it enough" is #29's (Q-OQ-RETENTION). #26 must NOT itself do Pokemon-cutscene transformation: no `Camera2D` zoom-shake, no `ScreenEffects` saturation drop >30%, no transformation anim >1.5s. Silhouette change carries it; particle amplifies. |

### E. Particle / VFX Integration

`#26` **triggers** presets via `ParticleSystemWrapper.emit_preset()`, never instantiates `GPUParticles2D` (ADR-0001 forbidden). 3 MVP presets: `avatar_stat_glow` (T3 passive aura) / `avatar_cast_burst` (cast release frame) / `avatar_evolution_reveal` (tier-up moment — but the *ceremony* around it is #29). Z-order: sprite (Z0 in layer 10) < outline (Z1) < particles (layer 20). Mobile 0.5× density delegated to #5; sprite quality unchanged (CR-14 / AC-20).

### F. Asset Spec Flag

36 sprite sheets (4 tiers × 3 classes × 3 anim) → 12 `SpriteFrames` resources + 12 `<class>_<tier>_mirror` hero-pose still-frames (64×64, for #29's ceremony — #26 only exposes the frame index in the snapshot). Shaders: `shader_avatar_outline.gdshader` + `shader_avatar_t3_aura.gdshader`. Config: `AvatarEvolutionConfig.tres` + `posture_config.tres` + `EMERGENCY_AVATAR.tres`. Filename: `char_avatar_<class>_<tier>_<anim>.png`. **Run `/asset-spec system:avatar-renderer`** after this GDD is APPROVED (owner: art-director + technical-artist + godot-shader-specialist). Sprite-asset workload (36 sheets, solo dev) = Q-OQ-ASSET.

## UI Requirements

- **In-game avatar IS the render surface** — Character Layer sprite during gameplay; not a HUD overlay. #26 owns NO panel UI.
- **#22 Character Screen** reads via the 6 CR-11 getters (no direct field access).
- **#29 Mirror Moment** consumes `avatar_evolution_milestone` + `get_evolution_snapshot()` and owns ALL ceremony UI (prompt / portrait / ghost overlay / share). #26 owns none of it (ADR-0010 / CR-17).

### Accessibility
- `motion_reduction`: idle breathing freezes frame 0; posture transitions instant-cut (no blend); micro-evolution shader tween disabled.
- Color NOT sole differentiator — class read from silhouette mass (FT-4 16×16 黑剪影).
- ScreenReader: on `avatar_visual_updated` significant change, **#22** emits the ARIA live region announce; milestone announce owned by **#29**. #26 emits the signals, not the announcements.

## Acceptance Criteria

> **33 ACs** — 13 unit / 9 integration / 8 static-analysis / 3 manual-playtest. **30 BLOCKING / 3 ADVISORY.** (No separate ADR-ratification-gated bucket: #26's governing ADRs 0001/0003/0006/0008 are Accepted; ADR-0010 is ratified by this GDD + #29. Web-runtime VRAM accuracy is the only deferred item → Q-OQ-VRAM VS-tier, scoped out of AC-19's desktop-measurable assertion.)

| AC | Given-When-Then | Source | Type | Gate |
|----|-----------------|--------|------|------|
| AC-01 | autoload boot → subscription set == exactly {#11.stat_changed, #12.ability_unlocked, #12.ability_cast, GSM.state_changed}, zero foreign | CR-1+CR-13 | unit | BLOCKING |
| AC-02 | inspect every AvatarVisualState field → 100% derivable from #11/#12/GSM snapshot via pure fn (re-run on identical input = equal output) | CR-6+INV-1 | unit | BLOCKING |
| AC-03 | STR=DEX=VIT=50 → dominant_class==STRIKE (tie-break order) | CR-3+F1 | unit | BLOCKING |
| AC-04 | pure STRIKE specialist peak_stat=70, max_class_depth=3, stat_total=80, ability_count=3 → evolution_tier==T3 (specialist path, NOT locked — Pass-4 F-2 fix) | F2+CR-4+P4 | unit | BLOCKING |
| AC-05 | stat at T2 then drop 1 below threshold → tier stays T2 (monotonic + historical lock) | CR-4+CR-12+CF-2 | unit | BLOCKING |
| AC-06 | GSM `state_changed(IDLE, COMBAT_ACTIVE, p)` (and `(_, BOSS_ENCOUNTER, p)`) → anim IDLE→COMBAT ≤1 frame; `(COMBAT_ACTIVE, IDLE, _)` → COMBAT→IDLE ≤1 frame | CR-2 Option C | unit | BLOCKING |
| AC-07 | 2nd cast within 300ms hard window → queued (depth 1); 3rd → drop oldest + `avatar_cast_dropped` | CR-10 | unit | BLOCKING |
| AC-08 | fresh account last_emit_unix=0 + backfill mapping to T1 + 0 observed sessions → NO milestone (epoch-zero guard: needs ≥1 session AND ≥48h) | F3+P1 | unit | BLOCKING |
| AC-09 | GSM==REST_PERIOD + dominant_class jitter → NO sprite swap (workout-window lock covers BOTH WORKOUT_ACTIVE + REST_PERIOD — Pass-4 F4 drift fix) | CR-9+F4 | unit | BLOCKING |
| AC-10 | dominant_class jitter within `POSTURE_HYSTERESIS_SECONDS` cooldown (monotonic clock) → no swap; wallclock backward jump does not affect cooldown | CR-9+F4+EC-HYST-3 | unit | BLOCKING |
| AC-11 | GSM SUSPENDED → `AnimatedSprite2D.pause()` called (NOT `stop()`); `_suspended_snapshot` has `frame_progress:float`; resume ≤30s → `play`+`set_frame_and_progress(frame, frame_progress)` restores exact frame (CR-8 hallucination fix — verified 4.6.3) | CR-8+F5 | unit | BLOCKING |
| AC-12 | PostureConfig.tres has 12 entries (3 class × 4 tier); `_derive_sprite_frames` returns non-null for all 12; missing key → EMERGENCY_AVATAR fallback | PostureConfig+EC-ASSET-1 | unit | BLOCKING |
| AC-13 | `get_evolution_snapshot()` → valid AvatarEvolutionSnapshot {tier, class_posture, sprite_frames path, hero_pose_frame, prior_tier, prior path, source_metrics} for #29 — and #26 renders NO ceremony from it | CR-11+ADR-0010 | unit | BLOCKING |
| AC-14 | CR-5 two-gate (promotion + cadence + non-workout) all pass → `avatar_evolution_milestone` emitted exactly once + persisted | CR-5+F3 | integration | BLOCKING |
| AC-15 | rolling 7-day stat delta > 0 + >7 days since last micro → `avatar_micro_evolution` emitted; shader uniform tween applied; ZERO sprite asset / tier change | CR-5b+F3b | integration | BLOCKING |
| AC-16 | boot uses `connect_for_initial_state` sentinel for all 4 subscriptions (ADR-0006 Contract 6) | CR-13 | integration | BLOCKING |
| AC-17 | workout window active + two-gate satisfied mid-set → emission deferred via persisted `_pending_milestone`, fires on workout-window exit | CR-15+F3 gate_c | integration | BLOCKING |
| AC-18 | bfcache resume Δ≤30000ms → RESTORE_SNAPSHOT; Δ=−5000 (NTP) → clamp + `avatar_monotonic_anomaly` + RESET_TO_IDLE_REDERIVE; threshold == #15.Rule17 | F5+INV-5 | integration | BLOCKING |
| AC-19 | sum current+adjacent tier texture VRAM via `Performance.RENDER_TEXTURE_MEM_USED` (NOT `MEMORY_STATIC`) ≤ 600 KB mobile / ≤ 2.3 MB desktop (desktop Vulkan measurable; web-runtime → Q-OQ-VRAM) | INV-6+CR-14 | integration | BLOCKING |
| AC-20 | platform_detect==mobile → sprite layer quality/frame-rate/posture UNCHANGED; only particle degrades via #5 | CR-14 | integration | BLOCKING |
| AC-21 | milestone emits while #29 not registered → buffered in `pending_emit_queue` (max 3), retried, then persisted; NEVER silently dropped | EC-MILE-5+P5 | integration | BLOCKING |
| AC-22 | bootstrap with historical milestones in persistence → re-derive on boot emits ZERO historical milestone (idempotent via last_emitted_tier) | F3+CR-13 | integration | BLOCKING |
| AC-23 | CI-1: any AvatarVisualState field write outside `avatar_renderer.gd::_derive_state_from_canonical()` → exit≠0 | CI-1+CR-6 | static | BLOCKING |
| AC-24 | CI-2: zero hardcoded tier-threshold literals in `.gd` (all from .tres) + BFCACHE const parity assert | CI-2+CR-4+INV-5 | static | BLOCKING |
| AC-25 | CI-3: zero `set_/mutate_/force_/inject_` prefix on `avatar_renderer.gd` public surface | CI-3+CR-11 | static | BLOCKING |
| AC-26 | CI-4: avatar z_index ∈ [-10,10]; CanvasLayer.layer==10; particle Z≥20 | CI-4+CR-7+INV-3 | static | BLOCKING |
| AC-27 | CI-5: `dominant_class` path references ONLY #11.get_stat(STR/DEX/VIT) — no derived/ability/loot/streak/workout | CI-5+CR-16 | static | BLOCKING |
| AC-28 | CI-6: `AnimatedSprite2D.sprite_frames` assignment only in `avatar_renderer.gd` AND zero `AnimationPlayer` token in #26 source | CI-6+Representation-Map | static | BLOCKING |
| AC-29 | AvatarVisualState resource: all declared fields present + each traces to a canonical source in `derived_from`; `schema_version` present | schema+INV-1 | static | BLOCKING |
| AC-30 | CR-17 ADR-0010: grep #26 source (`src/autoload/avatar_renderer.gd` + `src/ui/avatar*`) → zero ceremony composition (no 9:16 canvas, no ghost-overlay compositing, no screenshot prompt, no share UI) | CR-17+ADR-0010 | static | BLOCKING |
| AC-31 | FT-1: 10 playtesters mid-set 1s glance → ≥80% identify class+state+tier | FT-1 | playtest | ADVISORY |
| AC-32 | FT-4: 16×16 黑剪影 → ≥80% classify class across 3 | FT-4 | playtest | ADVISORY |
| AC-33 | FT-5: post-onboarding expectation vs delivered MVP → ≥80% match (honest framing) | FT-5 | playtest | ADVISORY |

### Coverage Map

- **Core Rules (17/17)**: CR-1→AC-01; CR-2→AC-06; CR-3→AC-03; CR-4→AC-04,AC-05,AC-24; CR-5→AC-14,AC-17; CR-5b→AC-15; CR-6→AC-02,AC-23; CR-7→AC-26; CR-8→AC-11; CR-9→AC-09,AC-10; CR-10→AC-07; CR-11→AC-13,AC-25; CR-12→AC-05; CR-13→AC-16,AC-22; CR-14→AC-19,AC-20; CR-15→AC-17; CR-16→AC-27; **CR-17→AC-30**.
- **Formulas (5+1)**: F1→AC-03; F2→AC-04,AC-05; F3→AC-08,AC-14,AC-17,AC-22; F3b→AC-15; F4→AC-09,AC-10; F5→AC-11,AC-18.
- **INVs (6+G1)**: INV-1→AC-02,AC-29; INV-2→AC-24(timing assert); INV-3→AC-26; INV-4→AC-05; INV-5→AC-18,AC-24; INV-6→AC-19.
- **CI lints (6/6)**: CI-1→AC-23; CI-2→AC-24; CI-3→AC-25; CI-4→AC-26; CI-5→AC-27; CI-6→AC-28.
- **Critical ECs**: EC-BOOT-1/2/3/5→AC-24/AC-29 (+config); EC-SIG-1/3→AC-02/AC-16; EC-TIER-2→AC-24; EC-MILE-3/5→AC-21; EC-SUS-4→AC-18; EC-ASSET-1→AC-12.
- **Falsifiable (render-scope)**: FT-1→AC-31; FT-3→AC-02+AC-27 (static); FT-4→AC-32; FT-5→AC-33. **FT-2 (share rate) owned by #29.**

### Test Distribution Summary

| Type | Count | Gate |
|------|-------|------|
| Unit (logic) | 13 (AC-01..AC-13) | all BLOCKING |
| Integration | 9 (AC-14..AC-22) | all BLOCKING |
| Static-analysis | 8 (AC-23..AC-30) | all BLOCKING |
| Manual / playtest | 3 (AC-31..AC-33) | all ADVISORY |
| **Total** | **33** | **30 BLOCKING / 3 ADVISORY** |

## Open Questions

> Render-scope only. Resolved-and-banked items (Q-OQ2 GSM signal, the 4 v2-rewrite blockers) live in the review-log Resolution Notes — not repeated here.

### Q-OQ-DEPTH — `max_class_depth` (class,tier) resolution contract on #12 **(forward dependency, recommend resolve before #26 epic)**
**Question**: Formula 2 specialist path needs `max_class_depth` = max tier ordinal reached in any single class. Shipped #12 exposes `get_unlocked_abilities() -> Dictionary` (keyed by ability_id; value = UnlockRecord {first_unlocked_at_unix, source, source_event_id} — NO class/tier field). #12 has NO `get_max_unlocked_class_tier()` (the v1 phantom). How does #26 resolve (class, tier) per unlocked ability_id?
**Options**: (A) **[Recommended]** small additive #12 read `get_max_unlocked_class_tier() -> int` (or `get_unlocked_class_tiers() -> Dictionary`) — clean, zero string-parse coupling, #12-erratum (additive, no behaviour change); (B) #26 parses the `tier_1/2/3` marker embedded in each ability_id StringName client-side (ADR-0011 derivation pattern) — works today but couples #26 to #12's id-naming convention (CI-lint-guard the convention). 
**Fail-safe**: EC-TIER-5 — unresolved depth → treat as 0 (generalist path still functions). So this is NOT a hard blocker, but Option A is the clean architecture.
**Owner**: godot-gdscript-specialist + #12 owner. **Priority**: MEDIUM (gates Pillar-4 specialist-path delivery, not boot).

### Q-OQ-RETENTION — post-T3 weekly retention adequacy **(→ #29, NOT #26)**
**Question**: 4 tiers over MVP = ≤4 milestone ceremonies; a fast lifter hits T3 by week 4-5 → no more tier milestones. Is the weekly `avatar_micro_evolution` (shader delta) + #29 ceremony composition enough to keep the「retention 心臟」beating weeks 5-8?
**Reframe (ADR-0010)**: #26's responsibility ends at emitting both signals with honest semantics (tier = silhouette receipt; micro = shader receipt). Whether the **ceremony** makes the weekly micro feel worth screenshotting is a **#29 ceremony-design question** — #29 may compose the weekly screenshot from accumulated micro deltas + the ghost-overlay comparison. FT-2 (share rate) is therefore a **#29** falsifiable test. **Resolution owner: #29 GDD + creative-director.** #26 carries no further obligation here.
**Priority**: gates #29 GDD design, not #26.

### Q-OQ-VRAM — WebGL texture-VRAM monitor accuracy on Compatibility renderer **(VS-tier empirical)**
**Question**: AC-19 / INV-6 use `Performance.RENDER_TEXTURE_MEM_USED` / `RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED` — both confirmed present in 4.6.3 (empirical, this rewrite). But the desktop probe ran on Vulkan; whether the **Compatibility / GLES3 / WebGL2** web backend reports a meaningful non-zero figure is a web-runtime question a headless desktop cannot settle.
**Resolution**: VS-tier empirical (real Web Export build). Enum name verified → code is written correctly now; the *number's* web-trustworthiness is gated VS-tier (consistent with ADR-0001 web-empirical gating pattern). **Priority**: LOW (VS-tier), does not block code.

### Q-OQ-ASSET — sprite-asset workload (36 sheets, solo dev) **(pre-epic scope gate)**
**Question**: 36 sprite sheets (4 tier × 3 class × 3 anim) + 12 hero-pose stills, class-specific bulk diffs (palette-swap REJECTED by art-director — silhouette mass change required for FT-4). Solo-dev throughput?
**Options**: (a) confirm ≥1.5 sheets/week sustainable → ships as-spec; (b) reduce to 2 tiers × 3 class × 3 anim = 18 sheets → widen `MILESTONE_CADENCE_SECONDS` to 4-week; (c) 4 tier × 1 class = 12 sheets → drop P4 visible differentiation to v0.2 (game-concept Pillar-4 wording revision).
**Owner**: art-director + producer. **Priority**: HIGH — blocks `/create-stories` for #26, NOT the APPROVED verdict.

### Q-OQ-CLASS-WINDOW — instant argmax vs rolling-window class identity **(post-MVP tech-debt)**
**Question**: CR-3/F1 derive `dominant_class` from instantaneous `argmax(STR,DEX,VIT)` = recent training. A long-term push specialist who does one leg-heavy week flips to MOBILITY → the screenshot "lies" about their training identity. 5-min hysteresis fixes mid-session flicker, not the weekly-identity question.
**Options**: (A) keep instant argmax (MVP); (B) rolling 28-day muscle-volume share (needs #9 API); (C) hybrid (instant for glance, 28-day for #29 ceremony snapshot).
**Resolution**: defer to post-MVP playtest — if #29's FT-2 share rate <30% OR feedback says「screenshot lies」, escalate. **Priority**: ADVISORY post-MVP.

