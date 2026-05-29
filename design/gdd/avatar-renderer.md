# Avatar Renderer (#26)

> **Status**: **Pass 2 Revised 2026-05-28 + Q-OQ2 RESOLVED 2026-05-28 (Option C)** — Pass 1 inline same-session APPROVED **RETROSPECTIVELY RESCINDED** by Pass 2 fresh-session /design-review (verdict MAJOR REVISION NEEDED, 16 BLOCKING convergent across 4 specialists)。Pass 2 inline-fixed 13 BLOCKING items same-session per user autonomous mode + 3 followup-tracked (F-9 helper implementation prereq, F-13 #29 producer escalation, F-15 cumulative posture tech-debt)。**Q-OQ2 (F-10 PROMOTED BLOCKING) RESOLVED 2026-05-28** — ground-truth verification revealed GSM enum 冇 `COMBAT_TICK` value (actual: `COMBAT_ACTIVE` + `BOSS_ENCOUNTER`) AND #14 EnemyDirector signal surface lock 死 exactly 3 signals (CI lint #3 enforced — `combat_started/ended` 不可加)。Option C adopted: CR-2 + AC-05 + States/Animation tables 改用 GSM `state_changed(from, to, payload)` filtered by `to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` (combat enter) + `from ∈ {…} AND to ∉ {…}` (combat exit) — zero cross-GDD blast radius, mirrors #14 's own subscription pattern (GSM GDD line 230-231)。**Awaiting Pass 3 fresh-session re-verification** per #15 Pass 1→2 precedent (inline same-session approvals empirically insufficient for convergent structural defects — anti-pattern validated twice).
> **Author**: Frank + creative-director (Section B framing + Pass 1 + Pass 2 senior synthesis Opus gate) + game-designer + art-director + technical-artist + gameplay-programmer (Section C parallel) + systems-designer ×2 (Section D Formulas + Section E Edge Cases) + qa-lead (Section H 41 ACs) + godot-gdscript-specialist (Pass 2 engine review) + Pass 2 4 fresh-session adversarial specialists
> **Last Updated**: 2026-05-28 (Pass 2 revision)
> **Pass 2 CD-GDD-ALIGN Verdict**: **MAJOR REVISION NEEDED** — Pass 1 APPROVAL rescinded; 16 BLOCKING (5 unanimous-convergent + 11 independent) + 2 CONCERN (F-15 + F-16) → Pass 2 inline-fixed 13 / followup-tracked 3
> **Pass 2 CD Assessment**: "Pass 1 inline APPROVAL retrospectively rescinded. Fresh-session adversarial review by 4 independent specialists surfaces 16 BLOCKING findings with 5 convergent unanimous patterns — replicates #15 Pass 1→2 anti-pattern at higher severity. Three of five pillars (P1/P4/P5) compromised by GDD as written. Anti-pattern empirically validated twice — codify as project rule: 'Inline same-session approval is forbidden for cards touching ≥2 pillars OR ≥3 systems OR formula-bearing milestones.'"
> **Pass 1 (RESCINDED) CD-GDD-ALIGN Verdict**: CONCERNS (acceptable) → APPROVED inline 2026-05-28 — superseded by Pass 2 fresh-session re-review per protocol
> **Implements Pillar**: Pillar 5 (Mirror Moment) PRIMARY substrate — visible weekly evolution via 4 evolution tiers + Mirror Moment milestone gate / Pillar 4 (Muscle = Class) supporting — class-tagged silhouette + animation differentiation (per-class redrawn frames, NOT palette-swap) / Pillar 1 (Real Body, Real Power) supporting — anti-fabrication chain 第七件套 (visible state derives only from canonical #11/#12) / Pillar 2 (Frictionless Companion) supporting — silhouette-first 0.3s glance readability + class posture hysteresis + workout-window milestone exclusion
> **System #**: 26 (Presentation / VS tier, design order 14 — **last VS-tier GDD complete**)
> **Depends On**: #11 Stat System (Approved) + #12 Ability System (Approved)
> **Depended On By**: #22 Character Screen (MVP, Not Started) + #25 Combat Visual Feedback (MVP, Not Started) + #29 Mirror Moment System (MVP, Not Started)
> **Governing ADRs**: ADR-0001 Web Export Budget Caps (sprite + animation draw call budget + bfcache 30s parity with #15) + ADR-0003 Save State Strategy (avatar.evolution_tier_history.* namespace for Mirror Moment evolution log) + ADR-0006 State Machine Contract (Contract 4 autoload sequential boot pos 8/9, Contract 6 connect_for_initial_state for stat_changed / ability_unlocked / GSM subscriptions)

## Overview

Avatar Renderer (#26) 係 Mirror Hero 嘅 **player-facing visible state layer** — Presentation 層 autoload / scene node，boot 喺 #11 Stat System (autoload position 4) + #12 Ability System (autoload position 5) 之後，向 3 個下游 Presentation/Polish-tier consumer (#22 Character Screen / #25 Combat Visual Feedback / #29 Mirror Moment System) 提供 canonical avatar visible state — sprite frame、animation state、class-tagged posture、進化 milestone hooks。系統有雙重 framing：

**Data 層面**: 訂閱 `#11.stat_changed(stat_id, old, new, source)` + `#12.ability_unlocked(ability_id, source)` + `#12.ability_cast(ability_id, caster, target)` signals (per ADR-0006 Contract 6 `connect_for_initial_state`)；維護一個 derived presentation state `AvatarVisualState`（class posture / sprite variant / current animation / progression milestone tier）；冇任何 mutation API exposed to other systems — `AvatarVisualState` 純粹 derive from canonical upstream data，唔可以 inject visual flair。每次 state change emit `avatar_visual_updated(state)` signal 俾下游 consumer subscribe。

**Player-facing 層面**: 玩家 mid-set glance 1 秒就知「我 avatar 今週有冇變、今日係咩 class、依家做緊咩 action」— 純剪影 16×16 都 readable (Art Bible Silhouette First rule)。週末做完 leg day 之後，screenshot avatar 嘅 evolved silhouette share 出去 — 唔係 game-distributed cosmetic，係玩家**真實一週訓練嘅 visible receipt**。

**為何呢個 system 存在**：Pillar 5 (Mirror Moment) PRIMARY substrate — game-concept 明確要求「每週 avatar 必須有 visible、可截圖嘅進化反映真實 body change…呢個係單機 game 嘅 retention 心臟」。冇 #26 = stat 升咗但 avatar 唔變 → Mirror Moment fantasy 斷裂 → MVP retention 心臟死亡。同時 #26 係 anti-fabrication chain 第七件套 — 確保 visible state 100% derive from canonical data layer (#11 + #12)，避免 game-side「為咗 visual juice」自己生成 stat/ability 狀態（avatar 唔可以 lie）。

**MVP scope (locked per game-concept anti-pillar)**: **Single sprite avatar** + base stance + 3 animation states (idle / combat / cast) + 3 class-tagged posture variants (STRIKE / CONTROL / MOBILITY)。**NO layered character system** (推遲到 v0.2 per concept doc anti-pillar — 「layered char / 多 boss / 多 zone 容易蔓延入 MVP — Mitigation: anti-pillar 強制守住 MVP 邊界」)。Mirror Moment v1: **screenshot-only weekly evolution** (sprite swap on weekly threshold + screenshot prompt) — 唔係 full layered animation。系統 honest about MVP delivery — paper over v0.2 deferral 違反 P1 anti-lie posture 嘅延伸 voice。

**Player interaction model**: **passive** — player 唔需要操作 avatar，唔需要 menu 揀 class/skin/equipment。所有 avatar visible state change 由 upstream canonical data (#11 + #12) 自動驅動。但 **player-perceived 卻係 highly active** — 玩家會主動 anticipate 週末嘅 evolved sprite + cap 圖 + share，呢個係 P5 Mirror Moment 嘅 retention loop。對應 P2「frictionless companion」嘅 input-frictionless / output-meaningful 同一張力解決方案。

**Architectural posture inheritance**: Section B「身體嘅 ledger」framing 同 #11「Stat 唔講大話」+ #15「肉身蓋章」+ #2「Backend 唔講大話」+ #3「Storage 唔講大話」嘅 voice 一致，建立 Mirror Hero system family 嘅 anti-fabrication coherent vocabulary。「Visible state is just stamped state, rendered」— 第七件套，Presentation tier 守住 visible truth boundary。

## Player Fantasy

### Core Identity: 「身體嘅 ledger，唔係 cosplay」(The Body's Ledger, Not a Costume)

> **Avatar 係你身體數據嘅 visible ledger — 佢淨係 render 你 deposit 過嘅嘢，一毫子都唔會多。**

星期日早上，你做完一週第三次 leg day，喺更衣室打開 Mirror Hero 一眼。Avatar 嘅 silhouette 比上週微微闊咗一啲 — **唔係衫升級，唔係 cosmetic unlock，係 base sprite 換咗一個 leg-day-evolved 版本**。你冇 swipe，冇 menu，淨係 0.3 秒 glance 就確認咗：「我練咗。」之後你 screenshot 出嚟，發 IG story — 隔離朋友見到嘅唔係 game character，**係你嘅一週訓練 receipt**。

Avatar 喺 Mirror Hero **唔係 character，係 ledger** — Pillar 5 嘅 Mirror Moment 唔係「角色升級 cutscene」，係**「身體勞動嘅 receipt visible 化」**。每一行 ledger entry 對得返一次真實訓練 — 唔可以 cheat、唔可以 cosplay、唔可以靠 visual juice 偽裝。

### Architectural Posture as Design Virtue (Anti-Fabrication 第七件套)

呢條 posture 同 Foundation tier 兩條 (#2 + #3) + Core tier 三條 (#11 + #14 + #9) + Loot tier 一條 (#15) 組成 **Pillar 1 anti-fabrication 第七件套** — 七條 architectural posture 各 own 一條 Pillar 1 防線：

| # | System | Anti-lie surface |
|---|--------|-------------------|
| #2 | GymSys Backend Client | **Backend signal 唔講大話** |
| #3 | PersistenceLayer | **Storage 唔講大話** |
| #11 | Stat System | **Stat 唔講大話** |
| #14 | EnemyDirector | **Orchestration 唔講大話** |
| #9 | Workout State Tracker | **Workout state 唔講大話** |
| #15 | Loot Drop System | **Loot tier 唔講大話**（肉身蓋章） |
| **#26** | **Avatar Renderer (本 GDD)** | **Visible state 唔講大話** — avatar 嘅每個 visible 變化只能 derive from #11 Stat + #12 Ability canonical data；冇 visual fabrication path |

七者組成 Pillar 1「Real Body, Real Power」嘅完整 vertical anti-fabrication architecture — Foundation tier 兩條 + Core tier 三條 + Feature tier 一條 + Presentation tier 一條 (本 GDD)。Visible state is just stamped state, rendered.

### Fantasy Boundary

**In scope**:
- Mid-set glance (0.3s, P2 frictionless companion) — 純黑 16×16 剪影都 readable，即時答到「今日 class / 今日 action / 今週進化」三條問題
- 週末 screenshot moment (P5 PRIMARY) — avatar evolved sprite swap + screenshot prompt + share-ready composition
- Class-tagged posture differentiation (P4) — push/pull/leg 訓練嘅 dominant class 喺 idle / combat / cast 三個 animation state 嘅 silhouette 層面 visible
- 進化 receipt cadence — base sprite swap timing 嚴格 derive from #11 累積 stat threshold + #12 ability unlock milestone，唔係 calendar-based「打卡」rotation
- Honest MVP delivery — single sprite + 3 anim states + 3 class posture variants + screenshot-only Mirror Moment v1，唔承諾 layered armor

**Explicitly NOT**:
- Layered armor visible system (推遲 v0.2 per game-concept anti-pillar — MVP scope creep guardrail)
- 任何「visual juice」path 自己生成 avatar state 唔對應 #11/#12 canonical data (Pillar 1 violation)
- Cosmetic-only unlock 唔反映 body data (例如「打到 7-day streak unlock cape」— streak 屬 #8，但 cape visible 不可以 bypass #11/#12 derivation chain，必須 route through canonical signal)
- Pokemon-style cutscene transformation (Framing 2 risk — mid-set introspection bleed; Mirror Moment ceremony 只喺 non-workout context 觸發)
- Mid-set 凝視 avatar 嘅 mechanic (P2 violation — avatar 必須 supporting frictionless companion，唔係 attention sink)
- Calendar-based「today's outfit」rotation (Pillar 1 violation — 進化 cadence 必須 anchor 到 real body data)

### Falsifiable Tests (5 observable player-behavior claims)

| # | Test | Falsification trigger | Pillar binding |
|---|------|----------------------|----------------|
| FT-1 | **Glance test** | 5 個 playtester mid-set 之間掃眼 1 秒，<80% 答到「我 avatar 今週有冇變、今日 class、依家做緊咩 action」三條問題 | Pillar 2 — silhouette readability 失敗 |
| FT-2 | **Screenshot share test** | 8 週 longitudinal study 中，<30% 週次有 self-initiated avatar screenshot share 行為（唔需 prompt） | Pillar 5 — Mirror Moment fantasy delivery 失敗 |
| FT-3 | **Anti-fabrication audit test** | Static code analysis + runtime audit log 顯示 ANY avatar visible state 唔 100% derive from `#11.stat_changed` / `#12.ability_unlocked` / `#12.ability_cast` signals | Pillar 1 — visible-state fabrication path 存在 |
| FT-4 | **Class silhouette test** | 純黑 16×16 剪影 quiz，5 個 playtester 分辨 STRIKE / CONTROL / MOBILITY accuracy <80% | Pillar 4 — class-tagged silhouette differentiation 失敗 |
| FT-5 | **Honest MVP expectation test** | Post-onboarding 玩家被問「avatar evolution 點呈現？」≥20% 回答期待 layered armor / cosplay visual / cutscene cinematic 而非 screenshot weekly + 3 anim states | Pillar 5 — framing oversold (expectation gap > 20%) |

### Fantasy Risk Register

#### FR-1: 「#11 Stat 4 derived stat formula 變化 cascade」(P5 evolution cadence breakage)

- **Risk**: 若 derived stat curve 變陡 (early-game stat 升好快) 或變平 (late-game stat 停滯)，avatar 「visible 進化」嘅 cadence 會跟住變 — 早期週週進化變成 fatigue / 後期幾個月唔變變成 abandonment
- **Binding**: ADR-0005 ratification + #11 Stat formula stability — avatar evolution threshold 必須 data-driven via `AvatarEvolutionConfig.tres`，唔可以 hardcode；formula 改 → threshold 自動 rebalance；CI lint `tools/ci/check_avatar_evolution_thresholds_data_driven.gd`
- **Mitigation owner**: #26 Section G Tuning Knobs (config-driven) + ADR-0005 formula stability + Section H AC for threshold rebalance behavior
- **Falsified by**: FT-2 screenshot share test long-term — week-12 cohort 嘅 weekly screenshot rate 跌穿 week-1 baseline 30% 以上

#### FR-2: 「Mobile Safari 0.5× particle fallback cascade」(Mirror Moment reveal degradation)

- **Risk**: 若進化 ceremony 過度依賴粒子，mobile 降密度後 reveal moment 失效 → P5「值得截圖」承諾喺主要 platform (mobile primary per ADR-0001) 死亡
- **Binding**: Mirror Moment 視覺核心係**剪影 change**（silhouette posture/bulk variant），粒子係 amplifier 唔係 substrate。降密度 ≠ 失去進化感。Section C Rule + Section Visual/Audio anti-pillar guard 必須明確「剪影 carries identity, particle carries celebration」嘅 division
- **Mitigation owner**: Section C visual-state-machine + Section Visual/Audio anti-pillar guard + ADR-0001 ratification
- **Falsified by**: FT-2 mobile-specific cohort — mobile screenshot share rate / desktop screenshot share rate 比例 <0.7 (mobile failure relative to desktop)

#### FR-3: 「v0.2 layered armor shipping retcon」(Framing scaling risk)

- **Risk**: 當 v0.2 layered armor 上線，single-sprite 「ledger」framing 會否變成「過時嘅妥協」？玩家會否覺得 MVP 期間嘅 Mirror Moment 係「劣質版本」？
- **Binding**: Framing 唔講「single sprite is final form」— 講「avatar 永遠只 render canonical data」。Layer 多少係 implementation detail，「ledger 唔講大話」係恆久 promise。v0.2 layered system = 「ledger column 變多」，core fantasy 唔變
- **Mitigation owner**: Section B Player Fantasy framing language (本 GDD)；future #26 v0.2 GDD revision 必須 inherit ledger metaphor
- **Falsified by**: v0.2 player feedback survey — 「MVP avatar 同 v0.2 avatar feel like 同一 game？」< 80% YES

### Design Test for Future Avatar Features

「Avatar 加 visual flair (e.g., 光環 / cosmetic particle / class-specific aura)」呢類 proposal 出現時：

> **「呢個 visual element derive from 邊條 stat / ability / 真實 body data？」**

如果答唔到 — **唔加**。Ledger framing 守得住 anti-fabrication boundary。Visual flair 必須 traceable to canonical data signal，唔可以 freestyle。

## Detailed Design

### Cross-Specialist Synthesis Notes

呢個 section 由 4 個 specialists 並行協作 — game-designer 主導 player-facing rules + state machine、art-director 主導 silhouette / animation visual spec、technical-artist 主導 sprite pipeline + Godot 4.6 implementation choices、gameplay-programmer 主導 feasibility + hot path budget。Lead session 解決咗以下 cross-spec tensions：

1. **Cast duration reconciliation**: game-designer CR-10 specifies 300ms hard gating window；art-director Section B specifies 0.5s total animation (3-frame charge @ 100ms/frame + 1-frame release)；technical-artist 12fps × 8 frames = 667ms。**Resolved**: **300ms uninterruptible gating window** (game-feel canonical per game-designer)，art animation 喺呢個 window 內可以 visual content 為 0.5s `cast` `AnimatedSprite2D` animation 嘅 first 300ms — 後續 200ms wind-down 可以被 new cast queue 中斷返 (queue 1-deep, drop oldest)。
2. **Milestone definition reconciliation**: gameplay-programmer recommends `evolution_tier_increased` event semantics (cleaner，per-tier)；game-designer CR-5 specifies 7-day cadence throttle。**Resolved**: **two-gate**: (a) `current_tier > last_emitted_tier` (gameplay-programmer purity) AND (b) `≥ 7 calendar days since last milestone emit` (game-designer cadence)。兩個 condition 一齊滿足先 emit — 防止 rapid tier-up scenarios (e.g., bootstrap restore connect 重新 derive tier 一次過 +3) flood player。
3. **Sprite asset count**: art-director Section H 列 36 sprite sheets (4 tiers × 3 classes × 3 anim states)；technical-artist 12 `SpriteFrames` resources × 18 frames = 同樣 scope 不同 counting unit。**Reconciled**: 12 `SpriteFrames` resources (per tier × class)，each contains 3 internal animation tracks (idle / combat / cast) — 對應 art-director 9 per-tier sprite sheets group 起做 3 resources per tier × 4 tiers = 12 resources。
4. **Class posture differentiation**: art-director Section A confirmed剪影層差異化 (stance width / weapon length / vertical mass) — technical-artist palette-swap shader implementation **REJECTED** (per art-director Section A — class differentiation 必須喺剪影 mass distribution，唔可以靠 palette tint，否則 16×16 純黑剪影 quiz 會 fail FT-4)。Implementation: per-class redrawn frames (acknowledged extra art workload，但 P4 Muscle=Class substrate purity 不可妥協)。
5. **State machine choice**: 3 specialists unanimous on **hand-rolled GDScript FSM** (NOT AnimationTree node) — sprite pixel art 唔需要 blend，36-variant matrix 用 AnimationTree state machine 會繁雜，interruption rules code 表達更清。
6. **Sprite pipeline**: `AnimatedSprite2D` + `SpriteFrames` resource per (tier × class)，hand-rolled FSM 控制 state transitions + class/tier swap via `sprite_frames` resource reassignment。

### AvatarVisualState Schema (**Pass 2 F-4 NEW — spec ghost resolved**)

**UNANIMOUS BLOCKING fix (qa-lead B1 + godot-gdscript-specialist class-undefined)**: Pre-revision GDD referenced `AvatarVisualState` Resource subclass 14 times across signal payloads + API return types + ACs, but **never defined the struct**。AC-02「100% derivable from canonical signals via pure function」untestable without explicit field list。Static typing impossible without class definition。

Pass 2 explicit schema (resource class definition for `src/data/avatar_visual_state.gd`):

```gdscript
class_name AvatarVisualState extends Resource

# Tier identity
@export var evolution_tier: int          # 0..3 (T0..T3) — derived from Formula 2
@export var class_posture: StringName    # {&STRIKE, &CONTROL, &MOBILITY} — derived from Formula 1
@export var animation_state: StringName  # {&IDLE, &COMBAT, &CAST, &SUSPENDED} — derived from GSM state + #12 signals

# Sprite frame state
@export var sprite_frames_resource_path: String  # res:// path to current SpriteFrames .tres
@export var current_frame: int           # animation frame index (0..frame_count-1)
@export var frame_progress: float        # [0.0, 1.0] fractional progress within current frame

# Micro-evolution layer (Pass 2 F-3 added)
@export var micro_palette_shift: float   # [0.0, 1.0] hue rotation amount for weekly micro-evolution
@export var micro_outline_intensity: float  # [0.0, 1.0] outline brightness micro-tuning

# Mirror Moment milestone tracking
@export var last_emitted_tier: int       # last tier for which avatar_evolution_milestone fired
@export var last_milestone_emit_unix: int  # 0 = never emitted (Pass 2 F-1 epoch-guard handles)

# Anti-fabrication source attribution (per CR-6 + INV-1)
@export var derived_from: Dictionary     # {field_name: source_signal_name} traceability for FT-3 audit

# Pass 2 F-11 fix: transition_id traceability per ADR-0006 Contract 2
@export var transition_id: int           # GSM transition_id for this state snapshot (per AC-14 + ADR-0006)

# Schema version (per ADR-0003 migration)
@export var schema_version: int = 1
```

**Field source signal mapping** (CR-6 derivation source attribution):

| Field | Derived From | Formula |
|-------|--------------|---------|
| `evolution_tier` | `#11.stat_changed` + `#12.ability_unlocked` (via sync read) | Formula 2 |
| `class_posture` | `#11.stat_changed(STR/DEX/VIT)` (via sync read) | Formula 1 |
| `animation_state` | GSM `state_changed` + `#12.ability_cast` | CR-2 state machine |
| `sprite_frames_resource_path` | `(evolution_tier, class_posture)` LUT lookup (per Pass 2 F-12 posture_lut) | `AvatarEvolutionConfig.tres` |
| `current_frame` / `frame_progress` | AnimatedSprite2D internal state (read-only sync) | Engine-managed |
| `micro_palette_shift` / `micro_outline_intensity` | Rolling 7-day stat delta from #11 | Pass 2 F-3 micro-evolution |
| `last_emitted_tier` / `last_milestone_emit_unix` | PersistenceLayer `avatar.evolution_tier_history` namespace | CR-12 |
| `transition_id` | GSM monotonic transition counter | ADR-0006 Contract 2 |

### Posture LUT (**Pass 2 F-12 NEW — spec ghost resolved**)

**BLOCKING fix (qa-lead B5)**: Pre-revision AC-06 tested `posture_lut[class] → atlas_region` mapping that GDD never documented。Pass 2 explicit definition:

`PostureConfig.tres` (data-driven Resource) defines posture → sprite_frames_resource_path mapping per tier:

```gdscript
class_name PostureConfig extends Resource

# Map from (class_posture, evolution_tier) → SpriteFrames resource path
@export var posture_lut: Dictionary = {
    "STRIKE_T0": "res://assets/art/avatar/sprite_frames_t0_strike.tres",
    "STRIKE_T1": "res://assets/art/avatar/sprite_frames_t1_strike.tres",
    "STRIKE_T2": "res://assets/art/avatar/sprite_frames_t2_strike.tres",
    "STRIKE_T3": "res://assets/art/avatar/sprite_frames_t3_strike.tres",
    "CONTROL_T0": "res://assets/art/avatar/sprite_frames_t0_control.tres",
    # ... 12 entries total (4 tiers × 3 classes)
}
```

LUT key format: `"{CLASS}_{TIER}"` (e.g., `"STRIKE_T2"`)。`AvatarRenderer._derive_sprite_frames(class_posture, evolution_tier) -> SpriteFrames` 經 `posture_lut` 查 path → `load(path)` → return preloaded `SpriteFrames` resource。

### Core Rules

呢度列 **16 條 binding rules** + INVs + CI Lint suite。所有 rule 都係 implementation-binding (programmer 直接 implement，唔需要 guess)，每條 tag 對應 Section B falsifiable test (FT-1..5) 或 Pillar binding。

#### Sprite + Animation Surface

| # | Rule | Binding |
|---|------|---------|
| **CR-1** | **Sprite variant surface LOCKED MVP scope** — Avatar visible state 由三條 axis 組合決定: (a) **base sprite** (always 1 — single sprite avatar MVP，no layered armor)，(b) **class posture variant** ∈ `{STRIKE, CONTROL, MOBILITY}` (3 choices，per art-director silhouette spec)，(c) **evolution tier** ∈ `{T0, T1, T2, T3}` (4 tiers，data-driven via `AvatarEvolutionConfig.tres`)。Cartesian product = 12 `SpriteFrames` resources × 3 internal animation tracks (idle/combat/cast)。**NO layered armor / NO cosmetic overlay / NO equipment slot visible** — 任何呢類 axis 加入要過 v0.2 GDD revision，唔可以 sneak。 | P5 PRIMARY + game-concept anti-pillar |
| **CR-2** | **Animation state machine 3 states** (**Q-OQ2 RESOLVED 2026-05-28 — Option C signal source corrected**) — `IDLE / COMBAT / CAST` mutually-exclusive states。Transition rules (signal source = GSM `state_changed(from, to, payload)` per ADR-006 Contract 6 connection, NOT non-existent `COMBAT_TICK` AND NOT #14's locked 3-signal surface): (a) `state_changed(_, to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, _)` → transitions to `COMBAT` (instant frame swap，0 blend per art-director pixel art convention — boss combat shares same combat animation per MVP single-sprite scope CR-1)，(b) `#12.ability_cast(ability_id, caster, target)` received 且 `caster == player` → transitions to `CAST` (instant)，cast plays per CR-10 hard duration，return to COMBAT (if GSM still ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}) or IDLE，(c) `state_changed(from ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, to ∉ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, _)` → IDLE，(d) Transition 唔可以 skip — `CAST → IDLE` direct 必須先 check GSM `current_state ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` membership。 | FT-4 + #25 contract + Q-OQ2 Option C |
| **CR-3** | **Class posture derivation** — `dominant_class` 由 `#11.get_stat(STR/DEX/VIT)` 三條 base stat 比較得出: `STRIKE = argmax(STR)`、`CONTROL = argmax(DEX)`、`MOBILITY = argmax(VIT)`。Tie-break order (deterministic): `STRIKE > CONTROL > MOBILITY`。Evaluation triggered on `#11.stat_changed` signal received 且 stat_id ∈ {STR, DEX, VIT}，但 sprite swap **必須 respect CR-9 hysteresis cooldown**。 | FT-4 + P4 supporting |
| **CR-4** | **Evolution tier derivation** — `evolution_tier = AvatarEvolutionConfig.compute_tier(stat_total, ability_count)`，where `stat_total = STR + DEX + VIT` (raw sum) + `ability_count = #12.get_unlocked_abilities().size()`。Function data-driven via `AvatarEvolutionConfig.tres` (Section G Tuning Knobs)。Tier monotonic non-decreasing — 一旦達到 T-k 唔會 regress to T-(k-1) (per CR-12 persisted historical max tier locked，防 stat 跌落導致 visible 退化 — game-concept Anti-Pillar「缺日唔拎走嘢」)。 | FT-2 + P5 PRIMARY |
| **CR-5** | **Mirror Moment milestone two-gate detection** — emit `avatar_evolution_milestone(tier, source_metrics)` 必須同時滿足: (a) **tier-increased gate**: `current_tier > last_emitted_tier`，(b) **cadence gate**: `≥ 7 calendar days since last milestone emit` (per cross-spec resolution — defends against rapid bootstrap-restore tier flood + Pillar 5 weekly cadence)，(c) **workout-window exclusion**: GSM ∉ `{WORKOUT_ACTIVE, REST_BETWEEN_SETS}` (per CR-15)。`last_emitted_tier` + `last_milestone_emit_unix` 持久化 (CR-12)。**Idempotent**: signal replay / bootstrap 重 derive tier 唔重發 — gate (a) prevents duplicate；gate (b) defends against rapid scenarios。 | FT-2 + #29 contract |

#### Anti-Fabrication + State Integrity

| # | Rule | Binding |
|---|------|---------|
| **CR-6** | **Anti-fabrication boundary (第七件套核心)** — `AvatarVisualState` 嘅每一個 visible field 必須有 explicit derivation source attribution `derived_from: StatChangedSource \| AbilityCastSource \| AbilityUnlockedSource \| InitialStateBootstrap`。冇 source attribution 嘅 field 喺 unit test 必須 fail。Mutation 只能發生喺 `src/presentation/avatar_renderer.gd::_derive_state_from_canonical()` private method — 其他 file 寫呢個 type = CI-1 lint failure。 | FT-3 + P1 第七件套 |
| **CR-7** | **Particle Z-order discipline** — 三層 `CanvasLayer` topology per ADR-0001 + technical-artist Section D: World layer (CanvasLayer.layer=0)、**Character layer (layer=10, avatar 喺度，內部 z_index ∈ [-10, 10])**、**Particle layer (layer=20, 永遠 above avatar)**、Event/HUD layer (layer=100)。Avatar `z_index = 0` within Character CanvasLayer。NEVER use raw `z_index > 50` on avatar。Particle 永遠 above sprite 但 silhouette readability preserved — per art-director Section F P3 guard: combat / cast effects max sprite displacement ≤4px，particle burst ≤ 2× sprite bounding box。 | FT-1 + Art Bible Layer Discipline |
| **CR-8** | **Suspended state handling** (**Pass 2 F-8 revised — AnimatedSprite2D API corrected**) — GSM `state_suspended` (per ADR-0006 Contract 6) → (a) **`AnimatedSprite2D.stop()`** (Godot 4.6 — pauses-in-place, NOT AnimationPlayer per godot-gdscript-specialist B1 BLOCKING fix: system uses AnimatedSprite2D not AnimationPlayer) + cache `_suspended_snapshot = {animation_state: StringName, current_frame: int, frame_progress: float, state_before_suspend: StringName, suspended_at_monotonic_ms: int}` (Pass 2 F-8 added `frame_progress: float` field — required for `AnimatedSprite2D.set_frame_and_progress(frame, progress)` fractional restore per godot-gdscript-specialist B2)，(b) 唔 emit any `avatar_visual_updated` during suspended，(c) reject incoming canonical signals (resume 後 sync re-derive via CR-13 pipeline)。Resume policy (per Formula 5 monotonic clock + max(0,delta) clamp): suspend `delta_ms ≤ 30000` → restore via `AnimatedSprite2D.play(animation_state)` + `set_frame_and_progress(frame, frame_progress)` from snapshot；suspend `delta_ms > 30000` OR raw delta negative → reset to safe IDLE state + re-derive (no Mirror Moment replay)。 | ADR-0006 Contract 6 + #15 bfcache parity + Pass 2 F-8 API correction |
| **CR-9** | **Class posture hysteresis (combined lock)** (**Pass 2 F-7 revised — REST_BETWEEN_SETS coverage added**) — Sprite swap 必須 respect 雙重 lock: (a) **5-minute monotonic clock cooldown** since last sprite swap (per Pass 2 F-6 — `Time.get_ticks_msec()` not wallclock)，OR (b) **workout-boundary lock**: GSM ∈ `{WORKOUT_ACTIVE, REST_BETWEEN_SETS}` 期間 posture 完全 freeze (`dominant_class` 即使 jitter 都唔 trigger sprite swap — **CR-15 milestone exclusion 同步擴展**，避免 mid-set OR mid-rest sprite flicker — P2 frictionless companion at the most attentive viewing moment)。**Pass 2 F-7 fix (systems-designer B4 + qa-lead C4 BLOCKING)**: Pre-revision CR-9 only excluded WORKOUT_ACTIVE，但 CR-15 excludes both WORKOUT_ACTIVE + REST_BETWEEN_SETS → asymmetric inconsistency 可導致 mid-rest posture flicker。Post-revision: align both rules on same exclusion set。Workout-end mid-jitter edge case: settle on workout-end snapshot 嘅 dominant class。Implementation: `_last_posture_switch_monotonic_ms: int` + `GSM.is_workout_window_active()` (covers both WORKOUT_ACTIVE + REST_BETWEEN_SETS — local check, no upstream lock signal required from #9)。 | FT-1 + P2 frictionless companion + Pass 2 F-7 |
| **CR-10** | **Cast animation timing (cross-spec resolved)** — 收到 `#12.ability_cast(ability_id, caster, target)` 且 `caster == player`: (a) **Onset ≤100ms** — signal handler → `_request_cast_animation()` → `AnimatedSprite2D.play("cast")` synchronous，typical <5ms (gameplay-programmer Section B confirmed budget headroom)。(b) **Hard gating window = 300ms** — first 300ms of cast animation uninterruptible (per game-designer CR-10 game-feel canonical)。(c) **Wind-down 200ms** — remaining 200ms of 0.5s total animation 可以被 queue release 中斷返 (per art-director Section B 8-frame @ 12fps cast animation interpretation)。(d) **Queue depth = 1** — 第二個 cast 喺 hard window 內到 → queue 待 wind-down 期間 release；queue 滿就 drop oldest queued entry + emit `avatar_cast_dropped(ability_id)` telemetry (per gameplay-programmer + technical-artist convergence)。 | #25 P3 binding + cross-spec resolution |

#### API + Persistence

| # | Rule | Binding |
|---|------|---------|
| **CR-11** | **Read-only public API closure** — 暴露 5 個 public reader: `get_visual_state() -> AvatarVisualState` (returns `Resource.duplicate()` per gameplay-programmer Section G — prevent external mutation by reference)、`get_class_posture() -> StringName`、`get_evolution_tier() -> int`、`is_ready_for_milestone_check() -> bool`、`get_animation_state() -> StringName`。**NO setter methods** — 任何 `set_*` / `mutate_*` / `force_*` / `inject_*` prefix 喺 public API surface = CI-3 lint failure。下游 (#22 / #25 / #29) read-only。 | FT-3 + P1 第七件套 |
| **CR-12** | **Persistence schema (avatar.evolution_tier_history namespace)** — Persist via PersistenceLayer (per ADR-0003 IPersistence): `current_tier: int (max ever achieved，monotonic non-decreasing)`、`last_emitted_tier: int`、`last_milestone_emit_unix: int`、`last_posture_switch_unix: int`、`tier_attainment_log: Array[{tier, achieved_at_unix, stat_total_at_attainment, ability_count_at_attainment}]` (append-only，FIFO truncated at 52 entries = 1 year cap)。Schema version `v1` — field add/remove triggers ADR-0003 900ms ceiling migration。 | FT-2 + ADR-0003 |
| **CR-13** | **Bootstrap from canonical state** — `_ready()` 必須 `connect_for_initial_state` (per ADR-0006 Contract 6) 三個 upstream signals: `#11.stat_changed` + `#12.ability_unlocked` + `#12.ability_cast` + GSM `state_changed`。Connect 即時收到 sentinel `INITIAL_STATE` event → `_derive_state_from_canonical()` 用 `#11.get_stat()` + `#12.get_unlocked_abilities()` sync read 計算 initial `AvatarVisualState`。**No special bootstrap path** — 同 normal stat_changed handler 共用 derivation pipeline (per game-designer CR-13)。Bootstrap completion → emit `avatar_visual_updated(state)` 一次 final。Milestone replay protection: CR-5 gate (a) ensures bootstrap re-derivation 唔 duplicate emit prior milestones (per gameplay-programmer Section E `_emitted_milestones` dict)。 | ADR-0006 Contract 6 |

#### Platform + Operational

| # | Rule | Binding |
|---|------|---------|
| **CR-14** | **Mobile Safari fallback — sprite UNCHANGED, particle delegated** — Per ADR-0001 mobile budget cap + Art Bible §7 + technical-artist Section G: sprite rendering / animation frame rate / class posture derivation / outline 全部 mobile UNCHANGED — silhouette 係 substrate (per FR-2 mitigation)。Only particle density falls to 0.5× (handled internally by `#5 ParticleSystemWrapper` — `#26` 對 platform 透明)。Outline shader可以喺 mobile disable 慳 GPU (per technical-artist Section E — combat state only, idle outline disabled on mobile to save fragment shader budget)。 | FR-2 + ADR-0001 |
| **CR-15** | **Mirror Moment ceremony exclusion windows** — `avatar_evolution_milestone` signal emit 必須喺 **non-workout window** (per CR-5 gate c)。Active workout window = GSM state ∈ `{WORKOUT_ACTIVE, REST_BETWEEN_SETS}`。若 milestone two-gate (CR-5 a + b) 喺 workout window 內滿足，pending milestone 寫入 internal `_pending_milestone` flag + persist to `avatar.evolution_tier_history.pending_milestone`。GSM 退出 workout → flush queued milestone (FIFO order if multiple — rare edge case)。Persistence ensures crash mid-pending 唔丟 milestone。 | P2 frictionless + FR-2 |
| **CR-16** | **Anti-cosmetic-leak guard** — Visible state 嘅 component derivation purity (per CI-5)：`dominant_class` 只用 `#11.get_stat(STR/DEX/VIT)` 3 條 base stat — 唔可以 reference derived stat (MAX_HP/ATTACK_POWER/etc)、ability count、loot rarity、streak、workout history (避免 class posture 由非 base-stat data 偷偷影響 — P1 + P4 purity)。**Evolution tier derivation** 可以 use ability count + stat total (per CR-4)，但 NOT 直接 use streak / loot / equipment / cosmetic state。 | FT-3 + P1 + P4 purity |

### States and Transitions

Avatar Renderer 嘅 visual state machine 同 GSM 嘅 game state 對應但獨立。下表係 `#26` 內部 6 個 state。

| State | Entry Condition | Allowed Actions | Exit Condition |
|-------|----------------|------------------|----------------|
| **Booting** | `_ready()` called，未完成 `connect_for_initial_state` | Connect signals + receive `INITIAL_STATE` sentinel + `_derive_state_from_canonical()` | Initial derivation complete + first `avatar_visual_updated` emit → **Idle** |
| **Idle** | Bootstrap complete + GSM `current_state ∉ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` OR exit from Combat/Casting/EvolutionMilestonePending | Accept `#11.stat_changed` + `#12.ability_unlocked` → re-derive `AvatarVisualState`；play idle 4-frame breathing animation (per art-director Section B)；class posture swap subject to CR-9 hysteresis | GSM `state_changed(_, to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, _)` → **Combat**；`#12.ability_cast(caster=player)` → **Casting**；milestone condition met (CR-5 all 3 gates) → 由 EvolutionMilestonePending track (rare in IDLE direct, usually goes via Combat exit)；GSM `state_suspended` → **Suspended** |
| **Combat** | GSM `state_changed(_, to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, _)` (per Q-OQ2 Option C — GSM enum 冇 `COMBAT_TICK`，#14 signal surface lock 死) | Play combat 6-frame loop animation；continue accepting `#11.stat_changed` but defer sprite swap to next Idle entry (mid-combat sprite flicker guard) | GSM `state_changed(from ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, to ∉ {…}, _)` → **Idle**；`#12.ability_cast(caster=player)` → **Casting**；GSM `state_suspended` → **Suspended** |
| **Casting** | `#12.ability_cast(ability_id, caster=player, target)` received (onset ≤100ms per CR-10) | Play cast 8-frame @ 12fps animation (0.5s total)；first 300ms hard gating window (uninterruptible)；queue at most 1 next-cast (CR-10)；refuse sprite variant swap during 300ms hard window | Cast animation hard window expires (300ms) → enter wind-down 200ms (queue release window) → animation finish (500ms total) → if GSM `current_state ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` then **Combat** else **Idle**；GSM `state_suspended` → **Suspended** |
| **Suspended** | GSM `state_suspended` signal (per ADR-0006 Contract 6) | Cache `_suspended_snapshot`；`AnimationPlayer.pause()`；reject incoming canonical signals (sync re-derive on resume)；no `avatar_visual_updated` emit | GSM `state_resumed` → suspend duration `<30s`: restore snapshot + resume animation；`≥30s`: reset to IDLE + re-derive via CR-13 pipeline |
| **EvolutionMilestonePending** | CR-5 two-gate (a+b) satisfied but workout-window exclusion (c) active (GSM in workout) | Hold `_pending_milestone = {tier, source_metrics}` flag + persist to `avatar.evolution_tier_history.pending_milestone`；continue normal Idle/Combat/Casting behavior；no `avatar_evolution_milestone` emit yet | GSM exits workout (enter `IDLE` / `HOME_SCREEN`) → emit `avatar_evolution_milestone(tier, source_metrics)` + update `last_emitted_tier` + `last_milestone_emit_unix` + clear pending → **Idle** |

#### Transition Diagram

```
                  _ready()
                     |
                     v
                 [Booting]
                     |
        (INITIAL_STATE sentinel + first derive)
                     |
                     v
                 [Idle] <-------------+
                /  |  \               |
               /   |   \              |
        [Casting]  |   [EvolutionMilestonePending]
              \    |    /  (exits workout, emit milestone)
               \   v   /
              [Combat] <----- (GSM state_changed → COMBAT_ACTIVE | BOSS_ENCOUNTER)
                  |
              (GSM exits combat)
                  |
                  v
              [Idle]

[Suspended] reachable from {Idle, Combat, Casting} via GSM state_suspended;
  resumes back to prior state via _suspended_snapshot (<30s) or IDLE (≥30s).
```

### Interactions with Other Systems

| System | Direction | Interface Owner | Trigger / Contract |
|--------|-----------|-----------------|--------------------|
| **#11 Stat System** (Approved) | Upstream → #26 | #11 (signal producer) | `stat_changed(stat_id, old, new, source)` subscribed via CR-13 `connect_for_initial_state`；sync read `get_stat(stat_id)` for class posture (CR-3) + evolution tier (CR-4) derivation。`#11` 唔知道 `#26` 存在 (loose coupling) |
| **#12 Ability System** (Approved) | Upstream → #26 | #12 (signal producer) | `ability_unlocked(ability_id, source)` → evolution_tier derivation (CR-4)；`ability_cast(ability_id, caster, target)` → animation state machine (CR-2 + CR-10)。Sync read `get_unlocked_abilities()` for bootstrap (CR-13)。`#12` 唔知道 `#26` 存在 |
| **#1 Game State Machine (GSM)** (Approved) | Upstream → #26 | #1 (signal producer) | `state_changed(new_state)` subscribed: combat enter/exit (CR-2)、suspend snapshot (CR-8)、workout window detection (CR-15) |
| **#3 PersistenceLayer** (Approved) | Bidirectional | #3 (storage owner) | `#26` own namespace `avatar.evolution_tier_history` (CR-12)。Write on tier attainment + milestone emit + posture switch；read on bootstrap (CR-13)。Schema v1，migration per ADR-0003 900ms ceiling |
| **#5 ParticleSystemWrapper** (Approved) | Downstream contract | #5 (particle owner) | `#26` triggers preset particles via `ParticleSystemWrapper.emit_preset(preset_id, anchor_node)` — 3 MVP presets: `avatar_stat_glow` (T3 passive aura), `avatar_cast_burst` (cast release frame), `avatar_evolution_reveal` (milestone moment per art-director Section G)。`#26` 唔 mutate particle directly；Z-order contract enforced via CR-7。Mobile fallback density delegated to #5 (CR-14) |
| **#22 Character Screen** (MVP, Not Started) | #26 → Downstream | #26 (read API) | `get_visual_state()` + `get_class_posture()` + `get_evolution_tier()` sync read；subscribe `avatar_visual_updated(state)` signal for live update during character screen open。`#22` read-only (CR-11) |
| **#25 Combat Visual Feedback** (MVP, Not Started) | #26 → Downstream | #26 (signal producer) | Subscribe `avatar_visual_updated` + internal animation state transition signal `animation_state_changed(state)`。`#25` read avatar pixel position for visual feedback anchoring。Read-only |
| **#29 Mirror Moment System** (MVP, Not Started) | #26 → Downstream | #26 (signal producer) | Subscribe `avatar_evolution_milestone(tier, source_metrics)` — primary handoff signal for weekly screenshot prompt (CR-5)。`#29` own UI / screenshot capture flow；`#26` only emit milestone trigger。`is_ready_for_milestone_check()` sync read available。Read-only |
| **#8 Streak System** | NOT a dependency | — | Streak data **不可以** cross to avatar visible state derivation (per CR-16 + CI-5 purity rule — class posture purity)。Future evolution tier 加 streak axis 要過 v0.2 GDD revision |

### Cross-Knob Invariants (INVs)

| INV-ID | Invariant | Enforcement |
|--------|-----------|-------------|
| **INV-1** | **Anti-fabrication boundary closure** — `AvatarVisualState` 每個 visible field 必須 traceable 到 `#11.stat_changed` / `#12.ability_unlocked` / `#12.ability_cast` / `#11.get_stat()` / `#12.get_unlocked_abilities()` / `InitialStateBootstrap` 之一。冇 third path | CI-1 static scan + Section H AC functional test |
| **INV-2** | **Cooldown ordering** — `CR-9 hysteresis (5-min)` ≥ `CR-10 cast hard window (300ms)` ≥ `CR-10 onset budget (100ms)`。三條 timing knob monotonic ordering — config load-time assert | `AvatarEvolutionConfig.tres` load validation + Section H AC |
| **INV-3** | **Z-order layering hard constants** — `Z_INDEX_CHARACTER_LAYER = 10` < `Z_INDEX_PARTICLE_LAYER = 20` < `Z_INDEX_EVENT_LAYER = 100`。Hardcoded const，唔暴露做 tuning knob (調呢個 break Art Bible Layer Discipline) | Source code const + CI-4 |
| **INV-4** | **Persistence schema monotonicity** — `avatar.evolution_tier_history.current_tier ≥ last_emitted_tier ≥ 0`。Load-time validation；violation → schema migration trigger | PersistenceLayer load-time assert |
| **INV-5** | **Bfcache threshold parity with #15** — `BFCACHE_CONTINUE_THRESHOLD_MS = 30000` (30s) — matches `#15.Rule 17 BFCACHE_CONTINUE_THRESHOLD_MS`。System-wide consistency；config drift = build fail | CI-2 cross-namespace const check |
| **INV-6** | **Sprite variant memory budget** — Total active variant texture memory ≤ 600 KB on mobile (current tier + adjacent only); total available across all 12 variants ≤ 2.3 MB upper bound. | CI-7 atlas size check + runtime `Performance.MEMORY_STATIC` monitor (per technical-artist Section G — verify against engine-reference) |

### CI Lint Suite

| Script | Path | Enforcement target |
|--------|------|-------------------|
| **CI-1** | `tools/ci/check_avatar_visual_state_derivation.gd` | Static scan: 所有 `AvatarVisualState.*` field assignment 必須喺 `src/presentation/avatar_renderer.gd::_derive_state_from_canonical()` 入面，且 RHS 必須 trace 到 canonical signal handler / sync read。其他 file 寫呢個 type = FAIL (CR-6 enforcement) |
| **CI-2** | `tools/ci/check_avatar_evolution_thresholds_data_driven.gd` | Static scan: `AvatarEvolutionConfig` 所有 threshold value 必須 load from `assets/data/avatar_evolution_config.tres`，唔可以 hardcode 喺 `.gd` file (per FR-1 mitigation + bfcache threshold parity INV-5 enforce 30s const match across #15 + #26) |
| **CI-3** | `tools/ci/check_avatar_renderer_no_setter_api.gd` | Static scan: `src/presentation/avatar_renderer.gd` public API surface 唔可以有 `set_*` / `mutate_*` / `force_*` / `inject_*` prefix method (CR-11 closure) |
| **CI-4** | `tools/ci/check_avatar_z_order.gd` | Static scan: Avatar `z_index` ∈ [-10, 10]; CanvasLayer.layer == 10 (Character layer); particle emit Z always ≥ 20 (CR-7 + INV-3 enforcement). Combine with art-director silhouette CI per Section F |
| **CI-5** | `tools/ci/check_avatar_class_derivation_purity.gd` | Static scan: `dominant_class` derivation 只用 `#11.get_stat(STR/DEX/VIT)` 3 條 base stat — 唔可以 reference derived stat / ability count / loot rarity / streak / workout history (CR-16 + P1 + P4 purity) |
| **CI-6** | `tools/ci/check_avatar_renderer_callers.gd` (per technical-artist Section H) | Static scan: `AnimatedSprite2D.sprite_frames` assignment 只能喺 `src/presentation/avatar_renderer.gd` 內部 trigger — 避免 external sprite swap bypass FSM |
| **CI-7** | `tools/ci/check_avatar_sprite_atlas_size.gd` (per technical-artist Section H) | Static scan: 每個 tier atlas ≤ 1024×1024；total variant memory ≤ 2.3 MB upper bound (INV-6 enforcement) |

### Autoload Boot Position (**Pass 2 F-5 fix — Boot Sequence Conflation resolved**)

**Pass 1 BUG**: Header text claimed「#26 boots after #11 Stat position 4 + #12 Ability position 5」but actual autoload list 將 #5 ParticleSystemWrapper 放 position 4 + #9 WorkoutStateTracker 放 position 5。**#11 Stat 同 #12 Ability ABSENT from boot list entirely** (systems-designer B1 UNANIMOUS structural defect)。Original `_ready()` would call against null autoload → crash OR silent zero-stat T0/STRIKE default。

**Pass 2 corrected autoload sequence** (verified against project.godot requirements — autoload position MUST insert #11/#12 explicitly):

```
1. #1 GameStateMachine          (Foundation)
2. #3 PersistenceLayer          (Foundation)
3. #2 GymSysClient              (Foundation)
4. #5 ParticleSystemWrapper     (Foundation)
5. #9 WorkoutStateTracker       (Core)
6. #11 StatSystem               (Core) ← Pass 2 F-5 INSERT (was missing)
7. #12 AbilitySystem            (Core) ← Pass 2 F-5 INSERT (was missing)
8. #14 EnemyDirector            (Core)
9. #15 LootDropSystem           (Core)
10. #21 LootRevealModal         (Presentation, if MVP)
11. #26 AvatarRenderer          (Presentation) ←
```

**#26 effective autoload position = 11** (after all upstream dependencies confirmed ready)。Per ADR-0006 Contract 4 sequential boot, #26 `_ready()` only runs after #11/#12/#14/#15 fully initialized — no race condition possible。**Pass 2 prerequisite story (F-5)**: project.godot autoload order MUST be updated to include #11 + #12 explicitly **before** #26 implementation starts。

Init sequence (`_ready`):
1. `load("res://data/avatar/AvatarEvolutionConfig.tres")` — fail-hard if missing (per CR-4 data-driven)
2. Preload `SpriteFrames` for T0 + adjacent tier (current_tier from PersistenceLayer + current_tier+1) — per technical-artist Section C caching strategy
3. `connect_for_initial_state(...)` per ADR-0006 Contract 6 — 同步攞 #11/#12/GSM state via 4 signal subscriptions
4. `PersistenceLayer.read("avatar.evolution_tier_history")` → rebuild `_current_tier`, `_last_emitted_tier`, `_last_milestone_emit_unix`, `_last_posture_switch_unix`
5. `_derive_state_from_canonical()` 計算 initial `AvatarVisualState` + apply class posture (subject to CR-9 hysteresis — first boot exempted from cooldown)
6. Emit `avatar_visual_updated(state)` final → enter Idle state
7. If `_pending_milestone` 喺 persistence 存在 → check CR-15 exclusion → emit if non-workout / hold if workout

**Boot budget**: ~80ms (matches #5 precedent)。Config load + persistence rebuild <50ms；SpriteFrames preload <30ms (texture GPU upload happens lazy on first display per technical-artist Section G — warm-up render at `modulate.a = 0.001` during loading screen)。

## Formulas

> **Authoritative scope**: #26 owns 5 supplementary formulas. ADR-0005 owns `loot_rarity_score`; #11 owns derived stat formulas; #26 does NOT re-derive any upstream values。

### Formula 1 — `dominant_class_derivation`

The `dominant_class_derivation` formula is defined as:

```
dominant_class = argmax_priority(STR, DEX, VIT, priority=[STRIKE > CONTROL > MOBILITY])

if STR >= DEX and STR >= VIT: return STRIKE
elif DEX >= VIT:               return CONTROL
else:                          return MOBILITY
```

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| STR | int | 0–999 | Strength stat from `#11.get_stat("STR")` |
| DEX | int | 0–999 | Dexterity stat from `#11.get_stat("DEX")` |
| VIT | int | 0–999 | Vitality stat from `#11.get_stat("VIT")` |
| dominant_class | enum | {STRIKE, CONTROL, MOBILITY} | Posture identifier |

**Output Range:** Exactly one of `{STRIKE, CONTROL, MOBILITY}` — never NULL, never multiple (satisfies CF-1)。

**Examples:**

| STR | DEX | VIT | Output | Reason |
|-----|-----|-----|--------|--------|
| 50 | 30 | 20 | STRIKE | STR strict max |
| 30 | 50 | 20 | CONTROL | DEX strict max |
| 20 | 30 | 50 | MOBILITY | VIT strict max |
| 40 | 40 | 20 | STRIKE | STR=DEX tie → STRIKE wins (priority head) |
| 20 | 40 | 40 | CONTROL | DEX=VIT tie → CONTROL wins |
| 40 | 20 | 40 | STRIKE | STR=VIT tie → STRIKE wins |
| 30 | 30 | 30 | STRIKE | All equal → STRIKE (priority head) |
| 0 | 0 | 0 | STRIKE | Booting default (deterministic) |

**Edge case rationale**: All three equal (including all-zero new player) → STRIKE. Intentional — priority order `STRIKE > CONTROL > MOBILITY` 係 canonical tie-breaker，top-down `>=` chain evaluated。

---

### Formula 2 — `evolution_tier_derivation` (**Pass 2 F-2 revised — specialist build path**)

The `evolution_tier_derivation` formula is defined as:

```
evolution_tier = max{ t ∈ {T0,T1,T2,T3} : (specialist_path OR generalist_path) AND stat_total >= S_t }

# AvatarEvolutionConfig.compute_tier(stat_total, ability_count, max_single_class_tier) — data-driven .tres
# Pass 2 F-2 fix: T3 supports BOTH specialist depth AND generalist breadth paths
# UNANIMOUS BLOCKING (game-designer B3 + systems-designer B2):
#   Pure STRIKE specialist unlocks only 3 STRIKE abilities → previously CAPPED at T2 forever
#   This contradicted Pillar 4 specialist build promise + incentivized anti-specialist meta

if stat_total >= 100 and (ability_count >= 6 OR max_single_class_tier >= 3):
    return T3  # T3 path A: generalist (6+ abilities) OR specialist (any class TIER_3)
elif stat_total >= 60 and (ability_count >= 3 OR max_single_class_tier >= 2):
    return T2  # T2 path A: generalist (3+ abilities) OR specialist (any class TIER_2)
elif stat_total >= 30 and ability_count >= 1:
    return T1  # T1: any ability + stat threshold
else:
    return T0

# Apply CR-12 historical max lock (CF-2 monotonic non-decreasing)
effective_tier = max(computed_tier, historical_max_tier)
```

**Pass 2 F-2 rationale**: Pure STRIKE specialist who unlocks all 3 STRIKE abilities (TIER_1/2/3) now reaches T3 via `max_single_class_tier >= 3` path — Pillar 4「specialist build viable」承諾 mechanically honored。Generalist who has 6+ abilities across classes also reaches T3 via `ability_count >= 6` path。**Both paths preserve P1 anti-fabrication** (still anchored to real workout-derived ability unlocks via #12)。`max_single_class_tier` 來自 `#12.get_max_unlocked_class_tier() -> int` sync read。

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| stat_total | int | 0–2997 | STR + DEX + VIT raw sum (CI-1 canonical) |
| ability_count | int | 0–9 (MVP) | `#12.get_unlocked_abilities().size()` (CI-2 canonical) |
| S_t | int | {0, 30, 60, 100} | Stat thresholds per tier, data-driven (.tres) |
| A_t | int | {0, 1, 3, 6} | Ability thresholds per tier, data-driven (.tres) |
| computed_tier | enum | {T0, T1, T2, T3} | Raw computed tier |
| historical_max_tier | enum | {T0, T1, T2, T3} | Persisted via `avatar.evolution_tier_history.current_tier` |
| effective_tier | enum | {T0, T1, T2, T3} | Final emitted tier (after CR-12 lock) |

**Output Range:** Discrete enum `{T0, T1, T2, T3}`。Final emitted tier passes through CR-12 historical max lock — CF-2 monotonic non-decreasing。

**Examples:**

| stat_total | ability_count | computed_tier | historical_max | effective_tier |
|------------|---------------|---------------|----------------|----------------|
| 25 | 0 | T0 | T0 | T0 |
| 45 | 2 | T1 | T1 | T1 |
| 75 | 4 | T2 | T2 | T2 |
| 110 | 7 | T3 | T3 | T3 |
| 75 | 2 | T1 (ability gate fails T2) | T2 | T2 (lock holds) |
| 55 | 4 | T1 (stat gate fails T2) | T2 | T2 (lock holds) |

**Threshold rebalance behavior:** 若 `.tres` thresholds tightened post-release, computed_tier may drop，但 `effective_tier` clamped by historical_max — players never visually degrade (per CR-4 + CR-12 + Anti-Pillar「缺日唔拎走嘢」)。

---

### Formula 3 — `milestone_two_gate_check` (**Pass 2 F-1 + F-3 revised — epoch=0 guard + micro-evolution layer**)

The `should_emit_milestone` formula is defined as:

```
should_emit = gate_a ∧ gate_b ∧ gate_c ∧ gate_d

gate_a = current_tier > last_emitted_tier            # tier promotion
gate_b = (last_emit_unix == 0)                       # first milestone path
            ? (observed_session_count >= MIN_OBSERVED_SESSIONS  # Pass 2 F-1 fix
               AND (now_unix - account_created_unix) >= FIRST_BOOT_GRACE_SECONDS)
            : (now_unix - last_emit_unix) >= 604800  # subsequent: 7-day cadence
gate_c = gsm_state ∉ {WORKOUT_ACTIVE, REST_BETWEEN_SETS}
gate_d = config_hash_at_last_emit == current_config_hash  # config-drift defense (per EC-03)
```

**Pass 2 F-1 fix — UNANIMOUS BLOCKING (game-designer B2 + systems-designer B3)**:

Pre-revision bug: `last_milestone_emit_unix = 0` 喺 fresh account 上面，`(now_unix - 0) ≈ 55 years > 604800`，gate_b ALWAYS pass。GymSys historical backfill 可以喺 first boot 即時 fire T1 milestone — player **未做過 single rep 就有 evolution ceremony**。直接 break Pillar 1 anti-fabrication ("cosplay, not ledger")。

Post-revision fix: First-milestone path requires **BOTH** (a) ≥`MIN_OBSERVED_SESSIONS` (default 1) **post-account-creation** observed workout session AND (b) ≥`FIRST_BOOT_GRACE_SECONDS` (default 48 hours) since account creation。即使 GymSys backfill 餵 stat data，no milestone fires until player完成至少一次 observed training session in-app。

**Pass 2 F-3 fix — Micro-evolution layer (Pillar 5 weekly cadence)** — UNANIMOUS BLOCKING (game-designer B1):

Pre-revision: 4 tiers × 7-day cadence = max 4 milestones over 8-week MVP。Hardcore player hit T3 by week 4-5 → ZERO Mirror Moments week 5-8。Pillar 5 design test「玩家做完 4 週訓練...睇唔睇到自己變咗」FAILS。

Post-revision: Mirror Moment milestone signal `avatar_evolution_milestone` 唔變 (依然 tier-promotion gated)，但 #26 額外 emit **`avatar_micro_evolution(visible_delta_kind, source_metrics)`** signal triggered by sub-tier weekly cosmetic deltas — palette shift / accessory rotation / posture refinement — **NOT gated by tier promotion**。Micro-evolution signal:
- Cadence: every 7 calendar days (rolling, anchored to account_created_unix)
- Source: derived from cumulative stat delta over rolling 7-day window (per #11)
- Visual: hue shift / outline brightness micro-tuning / breathing animation amplitude tweak — silhouette CARRIES tier identity, micro layer ADDS texture
- Compatibility: 既存 12 SpriteFrames resources 唔變；micro layer 經 shader uniform / modulate color tween 實現，唔需要新 sprite assets

呢個改變令 P5「每週 visible 進化」承諾 mechanically deliver — tier milestones 提供 **major receipt** (4 over MVP)，micro evolution 提供 **continuous receipt** (8 weekly over MVP) — 「ledger」fantasy 喺 continuous accounting 層面 honest。

**gate_d (config-drift defense, per EC-03)**: 若 `AvatarEvolutionConfig.tres` version_hash 變 → 新 config 嘅 tier 同舊 milestone 唔可以 reconcile，suppress emit until next legitimate trigger。

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| current_tier | enum | {T0..T3} | Output of Formula 2 (post-lock effective_tier) |
| last_emitted_tier | enum | {T0..T3} | Persisted in `evolution_tier_history.last_emitted_tier` |
| now_unix | int64 | wallclock seconds | `Time.get_unix_time_from_system()` |
| last_emit_unix | int64 | wallclock seconds | CI-3 persisted in `evolution_tier_history.last_milestone_emit_unix` |
| MILESTONE_CADENCE_SECONDS | const | 604800 (7 days) | Tuning knob |
| gsm_state | enum | GSM session states | From #1 GSM canonical |
| should_emit | bool | {true, false} | Whether to emit `avatar_evolution_milestone` signal |

**Output Range:** Boolean — `true` only when all three gates pass (CF-3)。

**Examples:**

| current | last_emit | Δseconds | gsm_state | gate_a | gate_b | gate_c | Result |
|---------|-----------|----------|-----------|--------|--------|--------|--------|
| T2 | T1 | 800000 | IDLE | T | T | T | **emit** |
| T1 | T1 | 800000 | IDLE | F | T | T | suppress (no promotion) |
| T2 | T1 | 300000 | IDLE | T | F | T | suppress (cadence) |
| T2 | T1 | 800000 | WORKOUT_ACTIVE | T | T | F | suppress (defer to EvolutionMilestonePending state) |

**Deferral semantics**: 當 gate_c blocks，milestone 入 `EvolutionMilestonePending` state + persist to `avatar.evolution_tier_history.pending_milestone`，下次 GSM Idle transition re-evaluate (CR-5 + CR-15)。

---

### Formula 4 — `hysteresis_check`

The `can_swap_posture` formula is defined as:

```
can_swap = ¬workout_lock ∧ class_changed ∧ cooldown_elapsed

if gsm_state == WORKOUT_ACTIVE: return false           # workout-boundary lock
if new_class == last_class:     return false           # no-op
return (now_unix - last_switch_unix) >= 300            # 5-min hysteresis (POSTURE_HYSTERESIS_SECONDS)
```

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| new_class | enum | {STRIKE, CONTROL, MOBILITY} | Output of Formula 1 |
| last_class | enum | {STRIKE, CONTROL, MOBILITY} | Currently-displayed posture |
| now_unix | int64 | wallclock seconds | Current time |
| last_switch_unix | int64 | wallclock seconds | Last successful swap timestamp |
| POSTURE_HYSTERESIS_SECONDS | const | 300 (5 min) | Tuning knob |
| gsm_state | enum | GSM states | From #1 GSM canonical |
| can_swap | bool | {true, false} | Swap permission |

**Output Range:** Boolean — `true` only when all 3 sub-conditions allow (CF-3)。

**Examples:**

| new | last | Δs | gsm_state | Result | Reason |
|-----|------|-----|-----------|--------|--------|
| CONTROL | STRIKE | 400 | IDLE | **true** | All gates pass |
| CONTROL | STRIKE | 120 | IDLE | false | Cooldown not elapsed |
| CONTROL | STRIKE | 400 | WORKOUT_ACTIVE | false | Mid-workout lock |
| STRIKE | STRIKE | 9999 | IDLE | false | No-op (same class) |
| CONTROL | STRIKE | 299 | IDLE | false | 1 second short of cutoff |
| MOBILITY | CONTROL | 301 | REST_BETWEEN_SETS | **true** | Rest is NOT workout-active per Formula 4 spec |

---

### Formula 5 — `bfcache_resume_action` (**Pass 2 F-6 revised — monotonic clock + negative delta guard**)

The `bfcache_resume_action` formula is defined as:

```
# Pass 2 F-6 fix (systems-designer B5 BLOCKING):
# Pre-revision bug: delta_ms = resumed_at_ms - suspended_at_ms via wall-clock
#   NTP correction / DST can produce NEGATIVE delta
#   `negative <= 30000` evaluates TRUE in signed math → false RESTORE_SNAPSHOT from future-stamped snapshot

# Post-revision: monotonic clock + max(0, delta) clamp
suspended_at_monotonic_ms = Time.get_ticks_msec() snapshot at suspend
resumed_at_monotonic_ms = Time.get_ticks_msec() at resume

raw_delta_ms = resumed_at_monotonic_ms - suspended_at_monotonic_ms
delta_ms = max(0, raw_delta_ms)  # clamp negative (defense against clock anomaly)

# Negative raw delta indicates monotonic clock anomaly (extremely rare in 4.6) — treat as long suspend
if raw_delta_ms < 0:
    emit_telemetry("avatar_monotonic_anomaly", raw_delta_ms=raw_delta_ms)
    return RESET_TO_IDLE_REDERIVE  # untrusted clock state, force safe re-derivation

action = RESTORE_SNAPSHOT if delta_ms <= BFCACHE_CONTINUE_THRESHOLD_MS else RESET_TO_IDLE_REDERIVE
```

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| suspended_at_ms | int64 | epoch ms | Timestamp at `pagehide` / suspend |
| resumed_at_ms | int64 | epoch ms | Timestamp at `pageshow` / resume |
| BFCACHE_CONTINUE_THRESHOLD_MS | const | 30000 (30s) | **CI-4: MUST equal `#15.Rule 17 BFCACHE_CONTINUE_THRESHOLD_MS`** (cross-system const consistency per INV-5) |
| action | enum | {RESTORE_SNAPSHOT, RESET_TO_IDLE_REDERIVE} | Recovery branch |

**Output Range:** Exactly 2 values (CF-4 enforced)。

**Examples:**

| Δms | action | Behavior |
|-----|--------|----------|
| 5000 | RESTORE_SNAPSHOT | Resume Idle/Combat anim from saved frame |
| 30000 | RESTORE_SNAPSHOT | Boundary inclusive |
| 30001 | RESET_TO_IDLE_REDERIVE | Re-fetch #11/#12 canonical, re-derive class/tier, force Idle state |
| 600000 | RESET_TO_IDLE_REDERIVE | Long suspend (tab backgrounded 10 min) |

---

### Cross-Formula Invariants (CF)

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| CF-1 | Formula 1 always returns exactly 1 of `{STRIKE, CONTROL, MOBILITY}` | Top-down `>=` chain + STRIKE default fallback |
| CF-2 | Formula 2 effective_tier monotonic non-decreasing over session lifetime | CR-12 historical_max lock + persistence assert (INV-4) |
| CF-3 | Formulas 3 & 4 return true only when ALL sub-gates pass | Short-circuit AND |
| CF-4 | Formula 5 threshold = `#15.Rule 17.BFCACHE_CONTINUE_THRESHOLD_MS` | Shared const reference + CI-4 lint enforce |

### Cross-System Integration Invariants (CI)

| ID | Invariant | Upstream / Downstream |
|----|-----------|-----------------------|
| CI-1 | Formula 1 input MUST be `#11.get_stat()` canonical sync read，NEVER cached old value | #11 Stat System authority |
| CI-2 | Formula 2 input `ability_count` MUST be `#12.get_unlocked_abilities().size()`，NEVER inferred from stat or equipment | #12 Ability System authority |
| CI-3 | Formula 3 `last_emit_unix` MUST persist via `avatar.evolution_tier_history.last_milestone_emit_unix` | ADR-0003 IPersistence |
| CI-4 | Formula 5 threshold (30000ms) MUST equal `#15.Rule 17.BFCACHE_CONTINUE_THRESHOLD_MS` (system-wide consistency per INV-5) | #15 + ADR-0001 cross-binding |
| CI-5 | All formula inputs deterministic — no randomness, no time-dependent except wallclock comparison | Pillar 1 anti-fabrication purity |

## Edge Cases

> **Severity tags**: CRITICAL (Pillar violation / data loss) / HIGH (UX disruption / silhouette readability breakdown) / MEDIUM (recoverable inconsistency) / LOW (rare edge, documented behavior)
> **Coverage**: 53 edge cases across 10 categories
> **Severity breakdown**: CRITICAL ×10 / HIGH ×22 / MEDIUM ×15 / LOW ×6

### 1. Boot + Persistence

- **EC-01 (CRITICAL)** — **If `user://` FileAccess unavailable (Private Mode detected per ADR-0003)**: Skip `avatar.evolution_tier_history` namespace load; initialize `last_emitted_tier = current_tier` (derived); set `persistence_degraded = true` flag; suppress all Mirror Moment emissions for session (CR-13). Rationale: prevents duplicate milestone emit on next session restore. Ref INV-4.
- **EC-02 (CRITICAL)** — **If `AvatarEvolutionConfig.tres` missing at boot**: Hard assert + crash with explicit error `"AvatarEvolutionConfig.tres required — config-driven per CR-4"`. Do NOT fall back to hardcoded thresholds (Pillar 1 anti-fabrication). Ref CR-4 + CI-2.
- **EC-03 (CRITICAL)** — **If `AvatarEvolutionConfig.tres.version_hash` differs from persisted `config_hash_at_last_emit`**: Force re-derivation of `last_emitted_tier` from current stats; clear pending milestone queue; log `config_drift_recovery` telemetry. Do NOT replay milestones across config versions. Ref CR-13 + INV-4.
- **EC-04 (HIGH)** — **If persisted `current_tier > 3` (T4+ from future version)**: Clamp to T3 (MVP max); log `tier_downgrade_migration`; set `last_emitted_tier = current_tier` post-clamp to prevent spurious emit on re-upgrade. Ref CR-12 schema versioning.
- **EC-05 (CRITICAL)** — **If persisted `last_emitted_tier > current_tier`**: Treat as corruption (INV-4 violation); set `last_emitted_tier = current_tier`; log `persistence_corruption` telemetry; do NOT emit any milestone this session. Ref INV-4.
- **EC-06 (HIGH)** — **If `QuotaExceededError` mid-bootstrap on persistence read**: Treat identically to EC-01 (Private Mode path); enter `persistence_degraded` mode; continue boot. Ref ADR-0003.

### 2. Signal Subscription + Race Conditions

- **EC-07 (CRITICAL)** — **If `#11.stat_changed` fires before #26 `_ready()` completes**: Drop signal (do NOT queue). Renderer re-derives full state from `#11.get_stat()` snapshot post-`_ready` per CR-6 (snapshot-rebuild pattern). Autoload boot order (ADR-0006 Contract 4) guarantees #11 ready before #26 subscribes. Ref CR-6 + CR-13.
- **EC-08 (HIGH)** — **If `#12.ability_cast(caster=player)` fires while #26 in Booting state**: Drop signal — cast animation cannot play before idle frame is rendered. Telemetry: `cast_dropped_pre_ready`. Ref CR-2.
- **EC-09 (CRITICAL)** — **If `#11.get_stat(stat_id)` returns NaN or -1 sentinel**: Treat stat as 0 in Formula 1/2; log `stat_sentinel_received` telemetry with stat_id. Never propagate NaN into derived state (would corrupt class posture deterministic tie-break). Ref Formula 1 + CI-1.
- **EC-10 (LOW)** — **If `#12.get_unlocked_abilities()` returns empty array**: `ability_count = 0`; Formula 2 evaluates normally; tier likely T0. No special handling. Documented behavior.
- **EC-11 (MEDIUM)** — **If GSM `state_changed` fires with value not in known enum**: Ignore signal; retain previous GSM-derived animation state; log `unknown_gsm_state` telemetry once per session (dedupe). Ref CR-2.

### 3. Class Posture Derivation (Formula 1)

- **EC-12 (MEDIUM)** — **If STR == DEX == VIT (three-way tie)**: Apply CR-3 deterministic tie-break order: STRIKE > CONTROL > MOBILITY. Resolves to STRIKE. Ref CR-3 + Formula 1.
- **EC-13 (MEDIUM)** — **If STR == DEX > VIT (two-way tie at top)**: Apply CR-3 order → STRIKE wins over CONTROL. Ref CR-3.
- **EC-14 (LOW)** — **If STR == DEX == VIT == 0 (fresh account)**: CR-3 tie-break resolves to STRIKE. Class posture is STRIKE T0 — valid default new-player state.
- **EC-15 (HIGH)** — **If any stat value negative (contract violation by #11)**: Clamp to 0 before Formula 1; log `negative_stat_received` CRITICAL telemetry with stat_id (gameplay-programmer escalation). Renderer must remain deterministic regardless of upstream bugs. Ref CI-1.

### 4. Evolution Tier Derivation (Formula 2)

- **EC-16 (MEDIUM)** — **If `stat_total < T0_threshold` (theoretically impossible if T0 threshold = 0)**: Clamp result to T0; log `tier_below_floor` if T0_threshold > 0 in config. Ref Formula 2.
- **EC-17 (HIGH)** — **If `ability_count == 0` but `stat_total` crosses T2/T3 threshold**: Apply Formula 2 ability_gate — tier capped at T1 until at least 1 ability unlocked. Prevents stat-only progression bypass. Ref Formula 2 + CR-4.
- **EC-18 (CRITICAL)** — **If `AvatarEvolutionConfig.tres` hot-reload detected mid-session (version_hash change)**: Reject the swap — `ResourceLoader.load(CACHE_MODE_REPLACE)` is FORBIDDEN at runtime for this config. Log `config_hot_swap_rejected`. Config drift only resolved at next boot via EC-03. Ref CR-4 + INV-2.
- **EC-19 (LOW)** — **If `stat_total` exactly equals a tier threshold boundary**: Boundary is inclusive on the upper tier per Formula 2 (`stat_total >= threshold[T_n]` → T_n). Deterministic, no special case.

### 5. Animation State Machine

- **EC-20 (HIGH)** — **If `ability_cast` fires twice within 50ms (rapid spam)**: Second cast enters cast-queue (1-deep). If queue already occupied → drop newest + telemetry `cast_queue_overflow`. Ref CR-2 + CR-10.
- **EC-21 (HIGH)** — **If new cast arrives during 300ms cast hard window**: Buffer into 1-deep queue per CR-10. On `animation_finished`, dequeue and play. Ref CR-10.
- **EC-22 (MEDIUM)** — **If cast queue overflow (3rd cast within window)**: Drop oldest queued, replace with newest; log `cast_queue_overflow` telemetry. Most recent player intent wins. Ref CR-10.
- **EC-23 (LOW)** — **If queued cast release window expires without play (animation rollover edge)**: Drop queued cast; return to GSM-derived state (idle/combat). Documented behavior — input>200ms stale.
- **EC-24 (HIGH)** — **If GSM exits combat mid-cast**: Cast animation MUST complete per CR-2 (cast atomicity). Post-`animation_finished`, transition to new GSM-derived state. Ref CR-2.
- **EC-25 (MEDIUM)** — **If AnimationPlayer reports state inconsistent with internal FSM (e.g., stuck frame)**: Force-transition to IDLE animation; clear cast queue; log `animation_desync_recovery`. Ref INV-3.

### 6. Class Posture Hysteresis (Formula 4)

- **EC-26 (HIGH)** — **If dominant_class flickers within 5-min cooldown**: Suppress posture transition per Formula 4; retain current posture; the "would-have-switched" event is NOT counted against cooldown (cooldown only resets on actual transition). Ref Formula 4 + CR-9.
- **EC-27 (MEDIUM)** — **If workout-end boundary lock fires during active 5-min cooldown**: Workout-end snapshot OVERRIDES cooldown per CR-9 priority order (workout-boundary > hysteresis). Posture commits, cooldown timer resets. Ref CR-9.
- **EC-28 (MEDIUM)** — **If player ends workout while posture jittering**: Settle on workout-end snapshot (Formula 1 applied to final post-workout stats); commit immediately; start fresh 5-min cooldown. Ref CR-9.
- **EC-29 (HIGH)** — **If wallclock jumps backward (DST fall-back, NTP correction) during cooldown**: Use `Time.get_ticks_msec()` (monotonic) for cooldown timing, NOT wallclock. Wallclock anomaly does not affect cooldown. Ref CR-9 monotonic clock requirement.
- **EC-30 (LOW)** — **If multiple back-to-back workouts within 5-min**: Each workout-end fires CR-9 priority override and resets cooldown. Documented — workout boundary always wins.

### 7. Mirror Moment Milestone (Formula 3 two-gate)

- **EC-31 (HIGH)** — **If tier-increased gate passes but 7-day cadence gate fails**: No milestone emit per Formula 3 (two-gate AND); silently update `last_emitted_tier = current_tier` to absorb the tier change without ceremony. Prevents stuck-pending-forever. Ref Formula 3 + CR-13.
- **EC-32 (LOW)** — **If 7-day cadence gate passes but no tier increase**: No milestone (tier-increase is a required gate). No state mutation. Documented.
- **EC-33 (HIGH)** — **If both gates pass but workout window is active**: Defer milestone emit to `workout_ended` signal per CR-15; persist `pending_milestone = {tier, gate_pass_ticks}`; flush on workout end. Ref CR-15.
- **EC-34 (CRITICAL)** — **If pending milestone exists at boot (crash during workout window)**: On boot, after persistence load, re-validate gates against current state. If `current_tier > last_emitted_tier` still true AND cadence still valid → emit on next `workout_ended` OR after 30s grace if no workout active. If invalid → drop pending + log `stale_pending_milestone_dropped`. Ref CR-13 + INV-4.
- **EC-35 (MEDIUM)** — **If bootstrap rebuild discovers `pending_milestone` from prior session**: Replay-safe — emission keyed on `(tier, emit_attempt_id)` UUID per CR-13. #29 Mirror Moment system dedupes on UUID. Safe to re-emit. Ref CR-13.
- **EC-36 (HIGH)** — **If tier jumps T1→T3 in single derivation (e.g., post-config-rebalance)**: Emit ONE milestone with `tier=T3, skipped_tiers=[T2]` payload. Do not emit T2 + T3 separately (would double-ceremony). Ref CR-13.
- **EC-37 (HIGH)** — **If wallclock jumps backward across 7-day cadence boundary**: Use monotonic `last_emit_monotonic_ms` per CR-9 monotonic clock requirement; backward wallclock jump cannot accelerate cadence. If wallclock jumps forward >24h, log `wallclock_anomaly` but allow cadence pass (player likely re-opened after long gap — legitimate). Ref CR-9.

### 8. Bfcache / Web Export Tab Switch

- **EC-38 (MEDIUM)** — **If suspend < 30s**: Restore last `AvatarVisualState` snapshot; resume animation from saved frame. No re-derivation. Ref Formula 5 RESTORE_SNAPSHOT + CR-8.
- **EC-39 (HIGH)** — **If suspend >= 30s**: Force-transition to IDLE; clear cast queue; re-derive full state from #11/#12 snapshot per CR-6. Stale animation frame may not match current upstream state. Ref CR-6 + CR-8 + Formula 5 RESET_TO_IDLE_REDERIVE.
- **EC-40 (HIGH)** — **If suspend occurs mid-cast (within 300ms hard window)**: On resume, force-finish cast to `animation_finished` synthetic signal — do NOT attempt to restore mid-cast frame (sprite atlas may have unloaded). Process queued cast normally. Ref CR-10.
- **EC-41 (CRITICAL)** — **If suspend occurs after milestone emit but before persistence flush completes (split-brain)**: On resume, check `last_emitted_tier` vs persisted value. If mismatch → trust in-memory value, re-flush persistence; #29 Mirror Moment dedupes via UUID per EC-35. Ref CR-13 + INV-4.
- **EC-42 (HIGH)** — **If #11/#12 state changed during suspend**: On resume, re-derive from current snapshot (CR-6); diff against pre-suspend snapshot; if class posture or tier changed, run CR-9 / CR-13 logic against post-resume state (no retroactive transitions). Ref CR-6 + CR-9.
- **EC-43 (MEDIUM)** — **If WebGL context lost during suspend**: AnimatedSprite2D textures re-upload automatically on context restore (Godot 4.6 default). Force one frame of IDLE on resume to guarantee texture binding. Log `webgl_context_restored`. Ref CR-14.

### 9. Sprite + Animation Asset

- **EC-44 (CRITICAL)** — **If `SpriteFrames` for current (posture, tier) fails to load (404 / corrupt)**: Fall back to `EMERGENCY_AVATAR.tres` (preloaded T0 STRIKE idle-only); disable cast/combat animations; log `sprite_load_failure` CRITICAL telemetry. Player still sees an avatar (silhouette never breaks). Ref INV-1 (silhouette > decoration).
- **EC-45 (HIGH)** — **If tier sprite preload exceeds OOM budget (mobile Safari 512MB ceiling)**: Per technical-artist Section C lazy-load — only preload current tier + adjacent (T_n-1, T_n, T_n+1). Discard T_n-2 and below. Ref INV-6 sprite variant memory budget.
- **EC-46 (MEDIUM)** — **If sprite swap requested during active cast animation**: Defer swap to `animation_finished` signal per CR-2 (cast atomicity). Queue swap intent (overwrite any prior queued swap). Ref CR-2 + CR-10.
- **EC-47 (MEDIUM)** — **If `AnimatedSprite2D.frame` reads negative or >= `frame_count` (engine corruption)**: Force `frame = 0`; force-restart IDLE animation; log `frame_corruption_recovery`. Ref CR-8.
- **EC-48 (LOW)** — **If mobile platform 0.5× particle scale active but sprite resolution unchanged**: Documented per Art Bible §7 — sprites are silhouette-critical (INV-1), do NOT downscale. Particles are decorative, may scale. Verify via CR-14.

### 10. Cross-System Integration

- **EC-49 (MEDIUM)** — **If `#11.stat_changed(stat_id)` arrives with unknown `stat_id`**: Ignore signal; log `unknown_stat_id` telemetry (dedupe by stat_id). Do not crash; Pillar 4 robustness. Ref CI-1.
- **EC-50 (MEDIUM)** — **If `#12.ability_unlocked(ability_id)` arrives with unknown `ability_id`**: Increment `ability_count` (count-only consumer); log `unknown_ability_id` telemetry. Renderer doesn't care about ability identity, only count. Ref Formula 2 + CI-2.
- **EC-51 (HIGH)** — **If GSM signal storm (>10 `state_changed` in 100ms)**: Apply 16ms debounce on GSM-derived animation transitions per CR-2. Only the final GSM state in each 16ms window triggers animation update. Cast signal is NOT debounced (CR-2 cast atomicity). Ref CR-2.
- **EC-52 (HIGH)** — **If #5 ParticleSystemWrapper unavailable when `avatar_evolution_reveal` particle preset requested**: Emit milestone signal to #29 anyway; skip particle (graceful degradation); log `particle_wrapper_unavailable`. Mirror Moment ceremony proceeds without particles. Ref CR-14 (silhouette > decoration).
- **EC-53 (CRITICAL)** — **If #29 Mirror Moment system not registered when milestone emits**: Buffer milestone in renderer-local `pending_emit_queue` (max 3 entries, FIFO); retry emit on next frame for up to 60 frames (~1s @ 60fps). If still no #29 listener, persist as `pending_milestone` per CR-13 and surface on next boot. Never silently drop a milestone — Pillar 5 ritual integrity. Ref CR-13 + CR-15.

## Dependencies

### Upstream Hard Dependencies

| Dep | Type | Interface | Bidirectional Sync Status |
|-----|------|-----------|--------------------------|
| **#11 Stat System** (Approved) | Signal subscription + sync read | Subscribes `stat_changed(stat_id, old, new, source)` via `connect_for_initial_state`; sync reads `get_stat(stat_id)` for Formula 1/2 derivation | ✅ #11 GDD Section F lists "#26 Avatar Renderer" as downstream consumer (highest cascade risk per systems-index High-Risk row) |
| **#12 Ability System** (Approved) | Signal subscription + sync read | Subscribes `ability_unlocked(ability_id, source)` + `ability_cast(ability_id, caster, target)` via `connect_for_initial_state`; sync reads `get_unlocked_abilities()` for Formula 2 ability_count | ✅ #12 GDD lists "#26 Avatar Renderer" as downstream consumer |
| **#1 Game State Machine (GSM)** (Approved) | Signal subscription | Subscribes `state_changed(new_state)` for combat enter/exit (CR-2), suspend snapshot (CR-8), workout window detection (CR-15) | ✅ GSM widely subscribed across systems |
| **#3 PersistenceLayer** (Approved) | Bidirectional read/write | `#26` owns `avatar.evolution_tier_history` namespace (CR-12): `current_tier`, `last_emitted_tier`, `last_milestone_emit_unix`, `last_posture_switch_unix`, `tier_attainment_log[]`, `pending_milestone` | ✅ #3 GDD lists `avatar.*` namespace in its registered consumer table |
| **#5 ParticleSystemWrapper** (Approved) | Downstream API call (#26 triggers, #5 owns lifecycle) | `ParticleSystemWrapper.emit_preset(preset_id, anchor_node)` with 3 MVP presets: `avatar_stat_glow` (T3 passive aura), `avatar_cast_burst` (cast release frame), `avatar_evolution_reveal` (milestone moment) | ⚠️ FORWARD: #5 GDD adds 3 new presets to AvatarVFX category — sync flag for #5 next-revision |

### Upstream ADR Dependencies

| ADR | Status | Binding |
|-----|--------|---------|
| **ADR-0001 Web Export Budget Caps** | Proposed | Sprite + animation draw call budget (≤2 draw calls per avatar)、texture atlas dimension cap (1024×1024 per tier)、mobile particle 0.5× fallback delegation to #5 (CR-14)、bfcache 30s threshold parity (INV-5) |
| **ADR-0003 Save State Strategy** | Proposed | `avatar.evolution_tier_history` namespace ownership (CR-12) + Private Mode detect-and-gate handling (EC-01)、schema v1 migration per 900ms ceiling |
| **ADR-0006 State Machine Contract** | Proposed | Contract 4 (autoload sequential boot — #26 position 8/9 after #11+#12+#15+#21)、Contract 6 (`connect_for_initial_state` sentinel for #11/#12/GSM subscriptions per CR-13)、anti-fabrication boundary canon list source-of-truth |
| **ADR-0005 Loot Rarity Formula** | Proposed | Indirect — AvatarEvolutionConfig.tres data-driven threshold approach inherits ADR-0005's `.tres`-driven pattern (FR-1 mitigation alignment) |

### Downstream Dependents (Not Started)

| System | Reverse Dependency Statement (to add when GDD authored) |
|--------|--------------------------------------------------------|
| **#22 Character Screen** (Presentation, MVP) | Will read avatar state for character stat review screen via `get_visual_state()` + `get_class_posture()` + `get_evolution_tier()` sync read; subscribe `avatar_visual_updated(state)` for live update。Schema contract: 5 read-only getters per CR-11。 |
| **#25 Combat Visual Feedback** (Presentation, MVP) | Will subscribe `avatar_visual_updated` + internal `animation_state_changed(state)` for combat visual feedback anchoring。Read avatar pixel position for VFX anchor placement。 |
| **#29 Mirror Moment System** (Polish, MVP) | Will subscribe `avatar_evolution_milestone(tier, source_metrics)` for weekly screenshot prompt UI。Own UI/screenshot capture flow。`#26` only emits milestone trigger (CR-5)。 |

### Failure Mode Matrix

| If upstream fails | Avatar Renderer behavior |
|-------------------|--------------------------|
| #11 returns NaN/sentinel | Clamp stat to 0 in Formula 1/2; log `stat_sentinel_received` telemetry; retain last-known-good visual state (EC-09) |
| #12 returns empty unlocked list | ability_count = 0; tier likely T0; cast handler defensive return early; no crash (EC-10) |
| #3 PersistenceLayer Private Mode detected | Skip namespace load; `persistence_degraded` flag; suppress milestone emit this session; avatar visible state unchanged (EC-01) |
| #5 ParticleSystemWrapper unavailable | Mirror Moment ceremony emits to #29 without particles; log `particle_wrapper_unavailable` (EC-52) |
| GSM unknown state value | Ignore signal; retain previous animation state; log once-per-session (EC-11) |
| ADR-0006 ratification not yet | AC-22 / AC-25 / AC-39 / AC-21 / AC-26 marked ADR-RATIFICATION-GATED |
| AvatarEvolutionConfig.tres missing | Hard assert + crash (Pillar 1 anti-fabrication — never fallback to hardcoded thresholds per CR-4 + EC-02) |

### Forward Constraints to Downstream

| Constraint | Receiving System | Binding |
|-----------|-----------------|---------|
| FR-AVATAR-1: `AvatarVisualState` Resource schema (class_posture, evolution_tier, animation_state) must be stable across #22 / #25 / #29 consumption | #22, #25, #29 | Required before downstream GDD authoring |
| FR-AVATAR-2: `avatar_evolution_milestone(tier, source_metrics)` signal payload — `tier: int (0-3 MVP)`, `source_metrics: Dictionary {stat_total, ability_count, achieved_at_unix}` | #29 Mirror Moment System | Frozen schema, version on schema change |
| FR-AVATAR-3: `animation_state_changed(new_state: StringName)` signal for #25 VFX anchoring | #25 Combat Visual Feedback | Schema frozen |
| FR-AVATAR-4: Avatar Z-index range [-10, 10] within Character CanvasLayer=10 — particle/HUD systems MUST respect | #5 ParticleSystemWrapper, #20 HUD | INV-3 enforcement |
| FR-AVATAR-5: 3 new particle presets needed in #5: `avatar_stat_glow`, `avatar_cast_burst`, `avatar_evolution_reveal` | #5 ParticleSystemWrapper | Sync flag for #5 next-revision |

## Tuning Knobs

> **Stability classification**:
> - **LOCKED** — Cannot change without ADR amendment or pillar re-validation
> - **DESIGN-FROZEN** — Section C contract binding; change requires GDD revision
> - **TUNABLE** — Designer-adjustable in `AvatarEvolutionConfig.tres`
> - **PROVISIONAL** — Baseline pending playtest validation (Pre-MVP iteration)

### Owned Knobs (#26 sole authority)

| Knob | Default | Safe Range | Stability | Effect / Failure Mode |
|------|---------|------------|-----------|----------------------|
| `T1_STAT_THRESHOLD` | **30** | [10, 80] | TUNABLE | Formula 2 T1 stat_total gate。<10 → T1 too early；>80 → T1 unreachable in MVP scope |
| `T2_STAT_THRESHOLD` | **60** | [40, 150] | TUNABLE | Formula 2 T2 gate。Must > T1_STAT_THRESHOLD per monotonic config validation |
| `T3_STAT_THRESHOLD` | **100** | [80, 250] | TUNABLE | Formula 2 T3 gate。Must > T2_STAT_THRESHOLD |
| `T1_ABILITY_THRESHOLD` | **1** | [0, 3] | TUNABLE | Formula 2 T1 ability_count gate。<1 → bypass progression purity；>3 → T1 stuck for new players |
| `T2_ABILITY_THRESHOLD` | **3** | [2, 5] | TUNABLE | Formula 2 T2 ability_count gate |
| `T3_ABILITY_THRESHOLD` | **6** | [5, 9] | TUNABLE | Formula 2 T3 ability_count gate (MVP cap = 9 abilities total) |
| `POSTURE_HYSTERESIS_SECONDS` | **300** | [120, 900] | DESIGN-FROZEN | CR-9 + Formula 4 cooldown。<120 → sprite flicker during workout；>900 → posture stale across multi-day shifts |
| `MILESTONE_CADENCE_SECONDS` | **604800** | [259200, 1209600] | DESIGN-FROZEN | CR-5 + Formula 3 7-day cadence。<3 days → ceremony fatigue；>14 days → milestone moments too rare |
| `CAST_ANIMATION_HARD_WINDOW_MS` | **300** | [150, 500] | LOCKED | CR-10 uninterruptible cast window。Tied to game-feel (P3) — change requires CD-GDD-ALIGN re-gate |
| `CAST_ANIMATION_TOTAL_MS` | **500** | [300, 700] | DESIGN-FROZEN | art-director Section B 8-frame @ 12fps |
| `CAST_QUEUE_DEPTH` | **1** | LOCKED | LOCKED | CR-10 single-deep queue。>1 → animation thrash risk；0 → cancel-on-new-cast (different design pattern) |
| `BFCACHE_CONTINUE_THRESHOLD_MS` | **30000** | LOCKED | LOCKED | INV-5 parity with `#15.Rule17.BFCACHE_CONTINUE_THRESHOLD_MS`。Cross-system const — change requires both #15 + #26 GDD update |
| `Z_INDEX_CHARACTER_LAYER` | **10** | LOCKED | LOCKED | CR-7 + INV-3 hard const。Art Bible Layer Discipline binding |
| `Z_INDEX_PARTICLE_LAYER` | **20** | LOCKED | LOCKED | CR-7 + INV-3 hard const。Must > Z_INDEX_CHARACTER_LAYER |
| `EMERGENCY_AVATAR_FALLBACK_TIER` | **T0_STRIKE_IDLE** | LOCKED | LOCKED | EC-44 fallback sprite — must always preloaded for graceful sprite-load-fail |
| `SPRITE_MEMORY_BUDGET_MOBILE_KB` | **600** | [400, 1024] | DESIGN-FROZEN | INV-6 mobile RSS ceiling。<400 → cache thrash；>1024 → mobile Safari OOM risk (512MB browser cap) |
| `SPRITE_MEMORY_BUDGET_DESKTOP_KB` | **2300** | [1500, 4000] | TUNABLE | INV-6 desktop upper bound for full 12-variant preload |
| `MIRROR_MOMENT_PENDING_BUFFER_FRAMES` | **60** | [30, 180] | TUNABLE | EC-53 #29 not registered retry budget。<30 → premature persist；>180 → wasted frames retrying |
| `WORKOUT_END_GRACE_SECONDS` | **30** | [10, 120] | TUNABLE | EC-34 boot pending milestone grace if no workout active |
| `GSM_SIGNAL_DEBOUNCE_MS` | **16** | [8, 33] | TUNABLE | EC-51 GSM signal storm debounce (1 frame @ 60fps) |

### Referenced Knobs (owned by other systems — #26 reads only)

| Knob | Owner | Value | Why #26 cares |
|------|-------|-------|---------------|
| `stat_changed_signal_signature` | #11 Stat | (stat_id, old, new, source) | Subscription contract per CR-13 |
| `ability_cast_signal_signature` | #12 Ability | (ability_id, caster, target) | Subscription contract per CR-13 |
| `ability_unlocked_signal_signature` | #12 Ability | (ability_id, source) | Subscription contract per CR-13 |
| `BFCACHE_CONTINUE_THRESHOLD_MS` | #15 LootDrop | 30000 | INV-5 cross-system parity — value MUST match (CI-4) |
| `MAX_ACTIVE_PARTICLES` | #5 / ADR-0001 | 200 | #5 enforces; #26 just respects via emit_preset() delegation |
| `mobile_fallback_multiplier` | #5 | 0.5 | Mobile particle density (sprite UNCHANGED per CR-14) |
| `AbilityRegistry.tres ability_count_max` | #12 | 9 (3 class × 3 tier) | Formula 2 ability_count upper bound |
| `StatId.STR/DEX/VIT` | #11 | StringName constants | Formula 1 input identifiers (must use enum, no magic string) |

### Cross-Knob Invariants (Section G-specific, reference Section C INV-1..6)

| ID | Constraint | Verification |
|----|-----------|--------------|
| INV-G1 | `T1_STAT_THRESHOLD < T2_STAT_THRESHOLD < T3_STAT_THRESHOLD` (strictly increasing) | Config load-time assert |
| INV-G2 | `T1_ABILITY_THRESHOLD ≤ T2_ABILITY_THRESHOLD ≤ T3_ABILITY_THRESHOLD` (monotonic non-decreasing) | Config load-time assert |
| INV-G3 | `CAST_ANIMATION_HARD_WINDOW_MS < CAST_ANIMATION_TOTAL_MS` (hard window must fit within total) | Config load-time assert |
| INV-G4 | `POSTURE_HYSTERESIS_SECONDS × 1000 ≥ CAST_ANIMATION_TOTAL_MS × 600` (hysteresis ≥ 600 cast cycles — prevents posture jitter every cast) | Config load-time assert |
| INV-G5 | `SPRITE_MEMORY_BUDGET_DESKTOP_KB ≥ 12 × 200 KB (per-variant texture budget)` | Config load-time assert |

### Knob Interaction Warnings

1. **T1/T2/T3 stat threshold × ability_count cascade**: 若 `T3_STAT_THRESHOLD = 80` 但 `T3_ABILITY_THRESHOLD = 9`, hardcore player 達 stat ceiling 但仍 stuck T2 if ability unlock 跟唔上 — 確保 ADR-0005 + #12 ability unlock cadence 對齊 evolution tier curve。
2. **POSTURE_HYSTERESIS × workout duration**: Default 5-min cooldown 假設 typical workout >5 min (合理 30-90 min per game-concept)。若 cooldown 太短 (<2 min)，short sets 之間 posture flicker；太長 (>15 min) 影響 cross-day class shift visibility。
3. **CAST_QUEUE_DEPTH × #25 combat feedback**: Locked at 1 — #25 visual feedback assume single-cast-at-a-time animation。Increasing this would require #25 GDD revision。
4. **MILESTONE_CADENCE × FT-2 share rate**: Default 7-day 對齊 Pillar 5 weekly cadence。若 cadence < 5 days，FT-2 ≥30% share rate threshold 可能 inflate (artificial frequency increases share volume but not engagement quality)。
5. **SPRITE_MEMORY mobile/desktop ratio**: Mobile 600 KB / desktop 2300 KB ratio ~26%。若 mobile budget 過低 → frequent cache miss + stutter on tier transition；過高 → mobile Safari OOM crash。

### Stability Summary

| Tier | Count | Notes |
|------|-------|-------|
| LOCKED | 6 | `BFCACHE_CONTINUE_THRESHOLD_MS`, `Z_INDEX_CHARACTER_LAYER`, `Z_INDEX_PARTICLE_LAYER`, `EMERGENCY_AVATAR_FALLBACK_TIER`, `CAST_ANIMATION_HARD_WINDOW_MS`, `CAST_QUEUE_DEPTH` |
| DESIGN-FROZEN | 4 | `POSTURE_HYSTERESIS_SECONDS`, `MILESTONE_CADENCE_SECONDS`, `CAST_ANIMATION_TOTAL_MS`, `SPRITE_MEMORY_BUDGET_MOBILE_KB` |
| TUNABLE | 10 | All tier thresholds (6) + desktop budget + retry budget + grace + debounce |
| PROVISIONAL | 0 | All values have basis (no playtest data deferred — Section D Formula 2 worked examples provide initial calibration) |

## Visual/Audio Requirements

> Initial cross-reference: Art Bible Direction A (Maple Pixel + Particle Storm) + Silhouette First principle + Layer Discipline rule + art-director Section C output integrated。

### A. Class Posture Differentiation Spec (silhouette層 readability)

| Class | Stance/Posture | Weapon/Tool Silhouette | Telegraph (combat anim) | 16×16 純黑剪影 identifying axis |
|---|---|---|---|---|
| **STRIKE** | Wide planted stance (feet 4px apart)、肩膊前傾、重心低 (-1px head offset) | 短粗武器 (gauntlet / short hammer)、長度 ≤ 6px、握喺腰側 | 前傾蓄力 → 直線突刺 2 frame anticipation | **下半身寬厚 + 短橫向 mass at hip line** (bottom-heavy triangle) |
| **CONTROL** | 中立直立 stance (feet 2px apart)、肩膊水平、雙手在身前 | 長杖/法器 (staff / orb on rod)、長度 8-10px、垂直舉於身側 | 雙臂展開上抬 → 頂點短暫停頓 (cast hold) | **垂直長條 + 頭頂以上有 weapon mass** (tall pillar) |
| **MOBILITY** | 窄 staggered stance (feet 1px apart, 一前一後)、上身扭轉 | 雙短刃/飛鏢 (twin dagger)、長度 ≤ 4px、雙手分散在身側 | 微蹲 → 側向位移 1-2px 殘影 | **窄底 + 不對稱 left/right arm extension** (asymmetric Y-pose) |

**Verification rule**: 16×16 純黑剪影 import 入 image editor、降至 8×8 仍要能分辨。STRIKE 著地、CONTROL 拔尖、MOBILITY 歪斜 — 三者剪影 mass distribution 必須完全唔同。AC-37 FT-4 silhouette test 驗證 80% accuracy。

### B. Animation State Spec

| State | Anim baseline | Loop/One-shot | Duration | Trigger | Notes |
|---|---|---|---|---|---|
| **idle** | 2-frame breathing (頭部 +1px / -1px sub-pixel bob) | Loop | 1.2s/cycle | Default state | 極低動量，避免 mid-set distraction (P2) |
| **combat** | 4-frame attack cycle (anticipation 1f / strike 1f / hold 1f / recover 1f) | One-shot → return idle | 0.4s total @ 100ms/frame | GSM `state_changed(_, to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}, _)` (per Q-OQ2 Option C) | Telegraph frame = silhouette extreme (class-specific shape) |
| **cast** | 3-frame charge + 1-frame release (charge ramp 2f / peak hold 1f / burst 1f) | One-shot → return idle | 0.5s total (300ms hard window + 200ms wind-down per CR-10) | `#12.ability_cast` signal | Burst frame triggers `avatar_cast_burst` particle preset delegation |

**Transition rules**:
- idle → combat / cast: instant cut (0 blend) — 維持 0.3s readability requirement (P2)
- combat → idle / cast → idle: 1-frame ease-out (100ms) — 避免突然 snap 抽走眼球
- combat ⇄ cast: 必須先回 idle 1 frame buffer (per art-director Section B — avoid state ambiguity)

### C. Progression Tier Sprite Variant Spec (MVP 4 tiers)

| Tier | Visible change (silhouette-anchored) | Trigger metric | Class-agnostic vs class-specific |
|---|---|---|---|
| **T0** | 4-head baseline、無 cape、無 aura | New player initial | Class-agnostic posture skeleton |
| **T1** | Posture confidence shift: 脊柱伸直 +1px height、肩膊 +1px width | Formula 2 T1 threshold (stat_total ≥ 30 AND ability_count ≥ 1) | Class-agnostic |
| **T2** | Bulk modifier: STRIKE 肩膀 +2px / CONTROL 杖 +2px length / MOBILITY 腰部 -1px (lean) | Formula 2 T2 threshold (stat_total ≥ 60 AND ability_count ≥ 3) | **Class-specific** — 對應 P4 Muscle=Class |
| **T3** | Silhouette outer aura: 1px dark outline + 1-2px breathing border halo、cape/coattail 2-3px trailing mass | Formula 2 T3 threshold (stat_total ≥ 100 AND ability_count ≥ 6) | Class-specific aura shape (STRIKE = solid block, CONTROL = wispy, MOBILITY = trailing streak) |

**Rule**: T1→T3 evolution 喺 8×8 zoom-out 都要 visible — 即係用 mass / outline / 髮型剪影外緣 changes，唔靠 texture detail。所有 tier values data-driven via `AvatarEvolutionConfig.tres` (per CR-4)。

### D. Character Layer Saturation Constraint (per Art Bible §4 Layer Discipline)

- **Saturation**: 55%–75% (HSL S) — 比 World Layer (≤40%) 高、比 Event Layer (90%+) 低
- **Lightness**: 35%–65% (HSL L) — 避免純白純黑 face (保留 face-readability headroom)
- **Hue family**: Warm-neutral bias — primary hue 喺 H=20°–60° (warm earth / skin tone family); class accent 色 (武器 / 服裝小面積) 可跳去 cool (H=180°–240°) 但 ≤ 15% sprite 面積
- **Outline rule**: **1px full dark outline**，hue = base color H ±0°、S +10%、L -40%; outline 永遠完整封閉 sprite — 唔可以 partial outline (要 maintain figure-ground separation against desaturated World Layer)
- **Forbidden**: 純黑 outline (#000000)、純白 highlight (#FFFFFF) — 兩者都會 punch out 變成 Event Layer 級別 visual weight，破壞 layer hierarchy

### E. Mirror Moment Composition (P5 PRIMARY screenshot frame)

Mirror Moment v1 = weekly screenshot evolution。Composition spec:

- **Avatar pose**: **Locked hero pose** — class-specific T-pose variant (STRIKE 雙拳握緊 / CONTROL 杖舉向天 / MOBILITY 雙刃交叉) — 確保每週 comparable
- **Background**: **Neutral gradient** (Character Layer hue family 對應的 desaturated gradient) — 隔絕 scene context noise、突出 avatar evolution delta
- **Comparison overlay**: **Yes — last week silhouette ghosted at 30% opacity，水平 offset -16px (左側)**; 當週 sprite 100% opacity 喺右側; overlay 用 1px dotted vertical divider 分隔
- **Watermark/UI**: 極簡 stamp — 右下角 8×8 px tier badge (T0/T1/T2/T3) + week number 1px font; 無 logo、無 share button (避免 polluting screenshot 美感)
- **Resolution / aspect**: **9:16 portrait, 1080×1920** (mobile-share friendly); avatar render @ 4× scale (64×64 sprite 渲染到 256×256 canvas area)、底部 384px 留白比例給 comparison strip

### F. Anti-Pillar Visual Guards

| Pillar | Visual rule MUST hold |
|---|---|
| **P1 Real Body, Real Power** | Tier transitions 必須 driven by `AvatarEvolutionConfig.tres` data 對應 GymSys metric — 禁止 cosmetic-only tier 或 random visual upgrades。Visible change 須 traceable to canonical workout data (FT-3 anti-fabrication audit + CI-1)。 |
| **P2 Frictionless** | 0.3s glance readability hard requirement — idle state 動量必須極低 (sub-pixel bob only)、無大型 idle particle、無 attention-grabbing animation cycle (FT-1 glance test)。 |
| **P3 Drop Euphoria** | Combat / cast state 最大 sprite displacement ≤ 4px、無 full-screen flash、無 particle burst 超過 sprite bounding box 2×。Avatar effects 永遠係 #21 LootDrop / #25 Combat Visual Feedback 嘅 supporting cast，唔可以 compete。 |
| **P4 Muscle = Class** | Class posture diff 喺 16×16 純黑剪影 enforced — CI-5 lint compare 3-class silhouette hash 須有足夠 difference (FT-4 silhouette test ≥80% accuracy)。 |
| **P5 Mirror Moment** | Weekly evolution screenshot 必須有 silhouette-level delta — T1→T2 ghosted comparison overlay 須肉眼可見差異，否則 weekly cadence 失去意義 (FT-2 share rate test)。 **CD F-10 anti-pattern guard**: Mirror Moment ceremony aesthetic = **silhouette change + still-frame composition + screenshot-ready**，NOT full-screen flash + camera zoom + multi-second transformation animation。**Ceremony 係 receipt, 唔係 cinematic**。Pokemon-style cutscene transformation 屬於 Fantasy Boundary explicit「Explicitly NOT」list (Section B) — visual rule 喺呢度 strengthen 為 production constraint：no `Camera2D` zoom-shake + no `ScreenEffects` saturation drop > 30% + no transformation animation > 1.5s total。Silhouette change carries the ceremony；particle/screen-fx 係 amplifier。 |

### G. Particle / VFX Integration

Boundary with #5 Particle System Wrapper:

- **Ownership model**: `#26` **triggers** particle presets via `ParticleSystemWrapper.emit_preset()` but **never directly instantiates** `GPUParticles2D` (per ADR-0001 forbidden pattern + technical-preferences forbidden list)
- **Avatar VFX catalogue** (3 MVP presets owned by #5, triggered by #26):
  1. `avatar_stat_glow` — passive aura particles at T3 tier (low density, additive blend)
  2. `avatar_cast_burst` — cast state release frame emit (synced to art-director Section B cast burst frame)
  3. `avatar_evolution_reveal` — tier-up moment (one-shot, Mirror Moment screenshot trigger window)
- **Z-order**: Particles **always above sprite** (per Art Bible §6 Particle Discipline)、but additive blend + edge feather ensures silhouette readability preserved。Z-order hierarchy: `sprite (Z=0 within CharacterLayer=10) < outline (Z=1) < particles (CharacterLayer=20)`
- **Mobile 0.5× fallback**: 完全唔影響 sprite quality — particle density 由 #5 內部處理 (mobile detect → density × 0.5)、burst shape 保留。Avatar sprite quality / animation frame rate / outline 不變 (per Art Bible §7 + CR-14 + AC-40)

### H. Asset Spec Flag

**Sprite assets (MVP minimum)**:

```
char_avatar_strike_t0_idle.png       (16×16, 2 frames horizontal strip = 32×16)
char_avatar_strike_t0_combat.png     (16×16, 4 frames strip = 64×16)
char_avatar_strike_t0_cast.png       (16×16, 4 frames strip = 64×16)
char_avatar_control_t0_idle.png      (similar)
char_avatar_control_t0_combat.png
char_avatar_control_t0_cast.png
char_avatar_mobility_t0_idle.png
char_avatar_mobility_t0_combat.png
char_avatar_mobility_t0_cast.png
```

Subtotal: **9 sprite sheets @ T0**

**Evolution tier variants**: T1 / T2 / T3 each × 9 sprite sheets = **27 additional sheets** (T2 / T3 class-specific bulk diffs require per-class assets per Section C)

**Total MVP sprite count**: **36 sprite sheets** (4 tiers × 3 classes × 3 anim states) packed into **12 `SpriteFrames` resources** (1 per tier × class)

**Mirror Moment hero pose**:
```
char_avatar_<class>_<tier>_mirror.png  (64×64 high-res, single frame, 12 sheets = 4 tiers × 3 classes)
```

**Shader assets** (per technical-artist Section E + art-director Section D):
- `shader_avatar_outline.gdshader` (1px outline shader, hue-derived per Section D — 8-direction texture sampling, ≤30 ALU + ≤10 texture samples per fragment)
- `shader_avatar_t3_aura.gdshader` (T3 tier 1-2px breathing border halo)

**Config**:
- `AvatarEvolutionConfig.tres` — tier thresholds + sprite path mapping (data-driven per CR-4 + CI-2)
- `EMERGENCY_AVATAR.tres` — preloaded T0 STRIKE idle fallback for EC-44 sprite-load-fail recovery

**Mobile variants**: **None required** — Art Bible §7 explicitly mandates sprite quality unchanged across platforms; only particle density scales (AC-40 enforcement)

**Filename pattern (locked)**: `char_avatar_<class>_<tier>_<anim>.png`
- `<class>` ∈ {strike, control, mobility}
- `<tier>` ∈ {t0, t1, t2, t3}
- `<anim>` ∈ {idle, combat, cast, mirror}

📌 **Asset Spec Flag**: After Art Bible is approved (✅ Approved 2026-05-28), run `/asset-spec system:avatar-renderer` to produce per-asset visual descriptions + dimensions + generation prompts from this section。**Owner**: art-director (silhouette specs) + technical-artist (shader/atlas) + godot-shader-specialist (gdshader code)。

## UI Requirements

### A. Direct UI Surfaces

- **In-game avatar rendering during workout**: Avatar IS the UI surface for #26 — Character Layer sprite rendering 直接 visible during gameplay。Avatar 唔係 HUD overlay；佢係 game world 嘅 first-class element。
- **NO separate avatar status panel** — avatar visible state 經 `#22 Character Screen` (MVP, not yet designed) read。`#26` 只提供 read-API getters，唔擁有 UI surface。

### B. Forward Constraints to Downstream UI Systems

#### `#22 Character Screen` content contract (forward to #22 MVP GDD authoring)

#22 必須通過 `#26` public API 取得以下資訊 (no direct field access — per CR-11):
1. **Current class posture** — `get_class_posture() -> StringName` 顯示「今日 class: STRIKE」label
2. **Current evolution tier** — `get_evolution_tier() -> int` 顯示「Tier T2」badge
3. **Avatar visual state** — `get_visual_state() -> AvatarVisualState` 用於 character preview render
4. **Animation state** — `get_animation_state() -> StringName` 用於 in-screen avatar animation playback
5. **Milestone readiness** — `is_ready_for_milestone_check() -> bool` 用於提示 player「下次 Mirror Moment 就快到」

#### `#29 Mirror Moment System` UI handoff contract (forward to #29 MVP GDD authoring)

`#26` emit `avatar_evolution_milestone(tier, source_metrics)` signal → `#29` own:
- Weekly screenshot prompt UI (per art-director Section E composition spec)
- Comparison overlay rendering (last-week silhouette ghost + this-week sprite)
- Share button + social platform integration
- Mirror Moment ceremony entry / exit transitions

`#26` does NOT own any of above — only triggers signal。

### C. Accessibility

- **`motion_reduction` setting respect**: Idle breathing animation (sub-pixel bob) 開啟 reduce-motion 後 freeze 第一 frame；class posture transition animation 開啟後 instant frame cut (no blend)；Mirror Moment evolution reveal particle 跟 #5 ParticleSystemWrapper accessibility settings
- **Color NOT sole differentiator**: Class differentiation 喺剪影層面 (per art-director Section A) — 色盲玩家依靠 silhouette mass distribution 仍可辨識 (FT-4 16×16 純黑剪影 test)
- **ScreenReader contract**: When `avatar_visual_updated` signal fires with significant change (class posture swap / tier transition)，#22 Character Screen 應該 emit ARIA live region announcement「Avatar 變為 [class] T[tier]」；Mirror Moment milestone 由 #29 own announcement

📌 **UX Flag — #26 Avatar Renderer**: This system 對 `#22 Character Screen` + `#25 Combat Visual Feedback` + `#29 Mirror Moment System` 形成 3 個 forward UI contracts。喺 Phase 4 (Pre-Production)，**before** writing epics for #22/#25/#29，run `/ux-design` to create UX specs for each consumer system that subscribes to `#26` output。Specifically:
- `/ux-design character-screen` — must reference #26 read-API contract
- `/ux-design mirror-moment-prompt` — must reference `avatar_evolution_milestone` signal payload schema (FR-AVATAR-2)
- `/ux-design combat-visual-feedback-anchor` — must reference avatar pixel position read API

Accessibility audit gate: accessibility-specialist must verify motion_reduction breathing animation freeze + class posture transition instant-cut behavior before #22/#29 ships。

## Acceptance Criteria

> **Scope**: 52 Given-When-Then ACs (Pass 2 +11 new) covering 16 Core Rules + 5 Formulas + 6 INVs + 7 CI lints + 9 CRITICAL ECs + 5 FTs + 3 FRs + AvatarVisualState schema + PostureConfig + micro-evolution layer
> **Test Distribution (Pass 2)**: 24 unit (+7 Pass 2) / 14 integration (+4 Pass 2) / 10 static-analysis (+0 net — AC-45 added schema closure) / 4 manual playtest (ADVISORY)
> **Gate Levels (Pass 2)**: 41 BLOCKING (Pass 1: 31, +11 Pass 2 BLOCKING items - 1 reclassified ADR-gated) / 7 ADR-RATIFICATION-GATED (AC-14 newly ADR-gated per Pass 2 F-11) / 4 ADVISORY playtest per Testing Standards

### AC Table

| AC ID | Given-When-Then | Source | Test Type | Gate | File Path |
|---|---|---|---|---|---|
| **AC-01** | **GIVEN** AvatarRenderer autoload boot **WHEN** subscribing to #11/#12/GSM signals **THEN** subscription set 完全等於 canonical signal list (CR-1 sprite surface + CR-13 bootstrap), zero foreign source | CR-1 + CR-13 | unit | BLOCKING | tests/unit/avatar/test_signal_subscription_purity.gd |
| **AC-02** | **GIVEN** AvatarVisualState struct **WHEN** inspecting every field **THEN** 100% derivable from #11 stat snapshot + #12 ability snapshot + GSM state via pure function | CR-6 + INV-1 | unit | BLOCKING | tests/unit/avatar/test_state_derivation_purity.gd |
| **AC-03** | **GIVEN** STR=DEX=VIT=50 (three-way tie) **WHEN** computing dominant_class **THEN** result = STRIKE (deterministic tie-break order STRIKE > CONTROL > MOBILITY) | CR-3 + Formula 1 | unit | BLOCKING | tests/unit/avatar/test_dominant_class_tiebreak.gd |
| **AC-04** | **GIVEN** stat snapshot at tier T2 threshold boundary **WHEN** stat drops by 1 below threshold **THEN** evolution_tier stays T2 (monotonic non-decreasing per CR-4 + CR-12 historical lock) | CR-4 + CR-12 + Formula 2 | unit | BLOCKING | tests/unit/avatar/test_evolution_tier_monotonic.gd |
| **AC-05** | (**Q-OQ2 RESOLVED — Option C signal source corrected**) **GIVEN** GSM `current_state == IDLE` AND AvatarRenderer animation_state == IDLE **WHEN** GSM emits `state_changed(IDLE, COMBAT_ACTIVE, payload)` (OR equivalent `state_changed(_, BOSS_ENCOUNTER, payload)` boss entry variant — same handler covers both per CR-2 Option C) **THEN** animation_state transitions IDLE→COMBAT within 1 frame (≤16.6ms); AND **GIVEN** subsequent `state_changed(COMBAT_ACTIVE, IDLE, _)` (OR `state_changed(BOSS_ENCOUNTER, LOOT_DROP, _)` etc., any `from ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` AND `to ∉ {…}`) **THEN** animation_state transitions COMBAT→IDLE within 1 frame | CR-2 + Q-OQ2 Option C | unit | BLOCKING | tests/unit/avatar/test_anim_state_transition_latency.gd |
| **AC-06** | **GIVEN** posture LUT for STRIKE/CONTROL/MOBILITY **WHEN** dominant_class flips post-hysteresis **THEN** sprite atlas region maps via posture_lut[class] only (no runtime computation) | CR-3 + CR-9 | unit | BLOCKING | tests/unit/avatar/test_posture_lut_lookup.gd |
| **AC-07** | **GIVEN** four tiers T0..T3 loaded **WHEN** tier index requested for any tier **THEN** sprite_set[tier] resolves to non-null Resource within budget | CR-1 + INV-6 | unit | BLOCKING | tests/unit/avatar/test_tier_sprite_resolution.gd |
| **AC-08** | **GIVEN** AvatarRenderer rendered as CanvasLayer **WHEN** Z-order inspected **THEN** Z value ∈ AVATAR_Z_CONST list (no magic number; Character CanvasLayer=10, particle=20) | CR-7 + INV-3 | static-analysis | BLOCKING | tests/unit/avatar/test_z_order_const_only.gd |
| **AC-09** | **GIVEN** stat snapshot identical to previous frame **WHEN** derive() runs again **THEN** AvatarVisualState equality holds (idempotent pure function) | CR-6 | unit | BLOCKING | tests/unit/avatar/test_derive_idempotent.gd |
| **AC-10** | **GIVEN** Mirror Moment two-gate (tier-increased + 7-day cadence + non-workout window) all pass **WHEN** emit logic runs **THEN** `avatar_evolution_milestone` signal emitted exactly once, persisted via PersistenceLayer | CR-5 + CR-15 + Formula 3 | integration | BLOCKING | tests/integration/avatar/test_milestone_emit_once.gd |
| **AC-11** | **GIVEN** AvatarRenderer public surface **WHEN** scanning exported methods **THEN** zero setter / mutator API exposed (read-only closure — only 5 getter methods per CR-11) | CR-11 | static-analysis | BLOCKING | tests/unit/avatar/test_readonly_api_closure.gd |
| **AC-12** | **GIVEN** sprite memory inventory **WHEN** sum tier sprites for current + adjacent tier on mobile **THEN** total ≤ 600 KB (mobile RSS budget per INV-6) | CR-14 + INV-6 | unit | BLOCKING | tests/unit/avatar/test_sprite_memory_budget.gd |
| **AC-13** | **GIVEN** AvatarRenderer boot sequence **WHEN** subscribing to #11/#12/GSM signals **THEN** uses connect_for_initial_state sentinel pattern (ADR-0006 Contract 6) | CR-13 | integration | BLOCKING | tests/integration/avatar/test_bootstrap_initial_state.gd |
| **AC-14** | **(Pass 2 F-11 reword + F-4 schema reference)** **GIVEN** GSM state_changed signal includes `transition_id: int` (per ADR-0006 Contract 2) **WHEN** `avatar_visual_updated(state: AvatarVisualState)` emits **THEN** `state.transition_id == triggering_gsm_transition_id` (traceability per AvatarVisualState schema Pass 2 F-4 + ADR-0006 Contract 2 atomicity) | CR-14 + FR-2 + Pass 2 F-11 | integration | ADR-RATIFICATION-GATED (BLOCKED-ON: ADR-0006) | tests/integration/avatar/test_transition_id_traceability.gd |
| **AC-15** | **GIVEN** workout window active (GSM ∈ {WORKOUT_ACTIVE, REST_BETWEEN_SETS}) **WHEN** milestone two-gate satisfied mid-set **THEN** emission deferred via `_pending_milestone` persisted, fires on GSM Idle transition | CR-15 + Formula 3 gate c | integration | BLOCKING | tests/integration/avatar/test_workout_window_exclusion.gd |
| **AC-16** | **GIVEN** dominant_class derivation **WHEN** code path scanned **THEN** ONLY references #11.get_stat(STR/DEX/VIT) — NO derived stat / ability count / loot / streak / workout history reference | CR-16 + CI-5 | static-analysis | BLOCKING | tests/unit/avatar/test_class_derivation_purity.gd |
| **AC-17** | **GIVEN** Formula 1 boundary STR=DEX (two-way tie, VIT lower) **WHEN** dominant_class computed **THEN** STRIKE selected per ordering | Formula 1 | unit | BLOCKING | tests/unit/avatar/test_formula1_two_way_tie.gd |
| **AC-18** | **GIVEN** Formula 2 stat sequence T2→drop→T2 **WHEN** tier recomputed at each step **THEN** sequence is monotonic non-decreasing (T2,T2,T2 — never T1) | Formula 2 + CF-2 | unit | BLOCKING | tests/unit/avatar/test_formula2_monotonic_seq.gd |
| **AC-19** | **GIVEN** Formula 3 bootstrap with historical milestones already in persistence **WHEN** AvatarRenderer re-derives on boot **THEN** zero historical milestone re-emit (idempotent gate via last_emitted_tier persistence) | Formula 3 + CR-13 | integration | BLOCKING | tests/integration/avatar/test_formula3_bootstrap_no_reemit.gd |
| **AC-20** | **GIVEN** Formula 4 dominant_class jitter within 5-min hysteresis cooldown **WHEN** same-set jitter fires **THEN** sprite swap NOT triggered (cooldown absorbs noise per CR-9) | Formula 4 + CR-9 | unit | BLOCKING | tests/unit/avatar/test_formula4_hysteresis_band.gd |
| **AC-21** | **GIVEN** Formula 5 bfcache resume **WHEN** resume gap ≤ 30000ms **THEN** action = RESTORE_SNAPSHOT (parity with #15 BFCACHE_CONTINUE_THRESHOLD_MS const) | Formula 5 + INV-5 | integration | ADR-RATIFICATION-GATED (BLOCKED-ON: ADR-0001 + ADR-0006) | tests/integration/avatar/test_formula5_bfcache_30s_parity.gd |
| **AC-22** | **GIVEN** INV-1 anti-fabrication boundary **WHEN** static analysis scans AvatarVisualState field assignments **THEN** every field traces to canonical #11/#12/GSM source via `_derive_state_from_canonical()` — zero fabricated path | INV-1 + CR-6 | static-analysis | ADR-RATIFICATION-GATED (BLOCKED-ON: ADR-0006) | tests/unit/avatar/test_inv1_anti_fabrication.gd |
| **AC-23** | **GIVEN** INV-2 cooldown ordering (5-min ≥ 300ms ≥ 100ms) **WHEN** AvatarEvolutionConfig.tres loaded **THEN** load-time assert validates monotonic ordering, violation crashes boot | INV-2 + CR-4 | unit | BLOCKING | tests/unit/avatar/test_inv2_cooldown_order.gd |
| **AC-24** | **GIVEN** INV-3 Z-order constants **WHEN** grep `set_z_index(\d+)` across src/presentation/avatar/ **THEN** zero magic-number occurrences (must use Z_INDEX_CHARACTER_LAYER const) | INV-3 + CR-7 | static-analysis | BLOCKING | tests/unit/avatar/test_inv3_z_order_grep.gd |
| **AC-25** | **GIVEN** INV-4 persistence monotonicity **WHEN** persisted `current_tier ≥ last_emitted_tier ≥ 0` checked at load time **THEN** monotonic invariant holds, violation triggers schema migration | INV-4 + CR-12 | integration | ADR-RATIFICATION-GATED (BLOCKED-ON: ADR-0003) | tests/integration/avatar/test_inv4_persistence_monotonic.gd |
| **AC-26** | **GIVEN** INV-5 bfcache parity **WHEN** comparing `#26.BFCACHE_CONTINUE_THRESHOLD_MS` to `#15.Rule17.BFCACHE_CONTINUE_THRESHOLD_MS` **THEN** values identical (cross-system const consistency enforced) | INV-5 + Formula 5 + CI-4 | static-analysis | ADR-RATIFICATION-GATED (BLOCKED-ON: ADR-0001) | tests/unit/avatar/test_inv5_const_parity.gd |
| **AC-27** | **GIVEN** INV-6 sprite memory budget **WHEN** all tier×class sprites loaded into texture memory **THEN** total ≤ 2.3 MB upper bound; mobile active-only ≤ 600 KB | INV-6 + CR-14 | integration | BLOCKING | tests/integration/avatar/test_inv6_rss_budget.gd |
| **AC-28** | **GIVEN** CI-1 lint script **WHEN** scanning AvatarVisualState field assignments outside `src/presentation/avatar_renderer.gd::_derive_state_from_canonical()` **THEN** CI exit code != 0 | CI-1 + CR-6 | static-analysis | BLOCKING | tools/ci/check_avatar_visual_state_derivation.gd |
| **AC-29** | **GIVEN** CI-2 lint (AvatarEvolutionConfig data-driven) **WHEN** scanning .gd files for hardcoded tier threshold literals **THEN** zero hardcoded values (all load from .tres) | CI-2 + CR-4 | static-analysis | BLOCKING | tools/ci/check_avatar_evolution_thresholds_data_driven.gd |
| **AC-30** | **GIVEN** CI-3 lint (no setter API exposure) **WHEN** scanning avatar_renderer.gd public API for set_/mutate_/force_/inject_ prefix **THEN** zero occurrences | CI-3 + CR-11 | static-analysis | BLOCKING | tools/ci/check_avatar_renderer_no_setter_api.gd |
| **AC-31** | **GIVEN** CI-4 lint (Z-order constants) **WHEN** scanning particle emit sites + avatar Z-index values **THEN** avatar z_index ∈ [-10, 10]; CanvasLayer.layer == 10; particle Z ≥ 20 | CI-4 + CR-7 + INV-3 | static-analysis | BLOCKING | tools/ci/check_avatar_z_order.gd |
| **AC-32** | **GIVEN** CI-5 lint (class derivation purity) **WHEN** scanning dominant_class derivation code path **THEN** ONLY references #11.get_stat(STR/DEX/VIT) — no derived/ability/loot/streak/workout refs | CI-5 + CR-16 | static-analysis | BLOCKING | tools/ci/check_avatar_class_derivation_purity.gd |
| **AC-33** | **GIVEN** CI-6 lint (sprite_frames callers) **WHEN** scanning `AnimatedSprite2D.sprite_frames` assignment sites **THEN** ONLY inside `src/presentation/avatar_renderer.gd` | CI-6 + CR-11 | static-analysis | BLOCKING | tools/ci/check_avatar_renderer_callers.gd |
| **AC-34** | **GIVEN** CI-7 lint (sprite atlas size) **WHEN** atlas inspected **THEN** each tier atlas ≤ 1024×1024; total variant memory ≤ 2.3 MB | CI-7 + INV-6 | static-analysis | ADR-RATIFICATION-GATED (BLOCKED-ON: ADR-0001 budget caps) | tools/ci/check_avatar_sprite_atlas_size.gd |
| **AC-35** | **GIVEN** FT-1 mid-set 1-second glance test **WHEN** 10 playtesters view avatar **THEN** ≥80% identify class+state+tier correctly in 1s | FT-1 | manual/playtest | ADVISORY (per coding-standards Testing Standards) | production/qa/evidence/avatar_ft1_glance.md |
| **AC-36** | **GIVEN** FT-2 8-week longitudinal **WHEN** analytics counts self-initiated screenshot share events **THEN** ≥30% weekly share rate documented | FT-2 | manual/playtest | ADVISORY | production/qa/evidence/avatar_ft2_share_rate.md |
| **AC-37** | **GIVEN** FT-4 16×16 pure-black silhouette set **WHEN** 10 playtesters classify class **THEN** ≥80% accuracy across 3 classes | FT-4 | manual/playtest | ADVISORY | production/qa/evidence/avatar_ft4_silhouette.md |
| **AC-38** | **GIVEN** FT-5 post-onboarding survey **WHEN** asking expectation vs delivered MVP **THEN** ≥80% match-rate (honest MVP framing test) | FT-5 | manual/playtest | ADVISORY | production/qa/evidence/avatar_ft5_honest_mvp.md |
| **AC-39** | **GIVEN** FR-1 stat formula cascade risk **WHEN** #11 rebalances stat thresholds via data file **THEN** Avatar tier recomputes from new threshold without code change (data-driven mitigation via AvatarEvolutionConfig.tres) | FR-1 + CR-4 | integration | ADR-RATIFICATION-GATED (BLOCKED-ON: ADR-0006 + ADR-0005) | tests/integration/avatar/test_fr1_data_driven_threshold.gd |
| **AC-40** | **GIVEN** FR-2 mobile particle fallback **WHEN** platform_detect=mobile **THEN** sprite layer quality unchanged per Art Bible §7 + CR-14 (particles degrade via #5; sprite does NOT) | FR-2 + CR-14 | integration | BLOCKING | tests/integration/avatar/test_fr2_mobile_sprite_unchanged.gd |
| **AC-41** | **GIVEN** FR-3 v0.2 framing scaling **WHEN** inspecting player-facing onboarding copy **THEN** ledger-metaphor language present (no over-promised framing per Section B「身體嘅 ledger」) | FR-3 | static-analysis | ADVISORY | tests/unit/avatar/test_fr3_ledger_copy_present.gd |
| **AC-42** | **(Pass 2 F-1 NEW BLOCKING — epoch=0 first-boot guard)** **GIVEN** fresh account with `last_milestone_emit_unix = 0` + GymSys backfill stat data mapping to T1 **WHEN** first boot Formula 3 evaluates **THEN** NO `avatar_evolution_milestone` emitted; gate_b requires `observed_session_count >= 1 AND (now_unix - account_created_unix) >= 48*3600` first-boot path; Pillar 1 anti-fabrication preserved (no ceremony before observed training) | Formula 3 + Pass 2 F-1 + Pillar 1 | unit | BLOCKING | tests/unit/avatar/test_first_boot_epoch_zero_guard.gd |
| **AC-43** | **(Pass 2 F-2 NEW BLOCKING — T3 specialist path)** **GIVEN** pure STRIKE specialist with stat_total=120 AND STRIKE_TIER_3 unlocked (max_single_class_tier=3) AND ability_count=3 **WHEN** Formula 2 evaluates **THEN** evolution_tier=T3 (specialist path via `max_single_class_tier >= 3` honors Pillar 4 specialist build promise) | Formula 2 Pass 2 F-2 + Pillar 4 | unit | BLOCKING | tests/unit/avatar/test_t3_specialist_path.gd |
| **AC-44** | **(Pass 2 F-3 NEW BLOCKING — micro-evolution layer)** **GIVEN** rolling 7-day stat delta detected by #11 AND >7 days since last micro-evolution emit **WHEN** weekly cadence check **THEN** `avatar_micro_evolution(visible_delta_kind, source_metrics)` emitted; palette shift / outline tween / breathing amplitude tweak applied; NO sprite asset change (shader-only) — Pillar 5 weekly cadence honored without ceremony budget consumption | Formula 3 Pass 2 F-3 micro-evolution + Pillar 5 | integration | BLOCKING | tests/integration/avatar/test_micro_evolution_weekly_cadence.gd |
| **AC-45** | **(Pass 2 F-4 NEW BLOCKING — AvatarVisualState schema closure)** **GIVEN** AvatarVisualState resource class defined per Pass 2 F-4 schema **WHEN** static type-check all field assignments + signal payloads **THEN** all 12 declared fields present + each field traceable to canonical signal per `derived_from` Dictionary; schema_version field present | Pass 2 F-4 + INV-1 | static-analysis | BLOCKING | tests/unit/avatar/test_avatar_visual_state_schema_closure.gd |
| **AC-46** | **(Pass 2 F-7 NEW BLOCKING — REST_BETWEEN_SETS hysteresis)** **GIVEN** GSM state == REST_BETWEEN_SETS (between sets, NOT mid-set) **WHEN** dominant_class jitter occurs from #11.stat_changed **THEN** CR-9 posture lock prevents sprite swap (workout-window lock covers both WORKOUT_ACTIVE + REST_BETWEEN_SETS per Pass 2 F-7 unification) | CR-9 Pass 2 F-7 + CR-15 alignment | unit | BLOCKING | tests/unit/avatar/test_hysteresis_rest_between_sets.gd |
| **AC-47** | **(Pass 2 F-6 NEW BLOCKING — Formula 5 negative delta guard)** **GIVEN** NTP correction produces `raw_delta_ms = -5000` (negative) **WHEN** Formula 5 bfcache_resume_action evaluates **THEN** clamp to 0 via `max(0, raw_delta_ms)`; emit `avatar_monotonic_anomaly` telemetry; force RESET_TO_IDLE_REDERIVE (NOT RESTORE_SNAPSHOT from future-stamped snapshot) | Formula 5 Pass 2 F-6 | unit | BLOCKING | tests/unit/avatar/test_formula5_negative_delta_guard.gd |
| **AC-48** | **(Pass 2 F-8 NEW BLOCKING — AnimatedSprite2D API correctness)** **GIVEN** GSM state_suspended signal **WHEN** CR-8 suspend handler executes **THEN** `AnimatedSprite2D.stop()` called (NOT AnimationPlayer.pause()); `_suspended_snapshot` includes `frame_progress: float` field per Pass 2 F-8 schema | CR-8 Pass 2 F-8 | unit | BLOCKING | tests/unit/avatar/test_cr8_animatedsprite_api.gd |
| **AC-49** | **(Pass 2 F-12 NEW BLOCKING — posture_lut closure)** **GIVEN** PostureConfig.tres loaded with 12 entries (4 tier × 3 class) **WHEN** AvatarRenderer._derive_sprite_frames(class_posture, evolution_tier) called for any of 12 combinations **THEN** returns non-null SpriteFrames; missing key triggers EMERGENCY_AVATAR fallback (EC-44) | Pass 2 F-12 posture_lut | unit | BLOCKING | tests/unit/avatar/test_posture_lut_closure.gd |
| **AC-50** | **(Pass 2 F-14 NEW BLOCKING — tier transition memory)** **GIVEN** current_tier=T1 with tier T0 + T2 preloaded **WHEN** tier transitions to T2 **THEN** T0 unloaded + T3 preloaded within frame budget (≤16.6ms); transient memory spike ≤ 1200 KB during transition (≤ 2× steady-state mobile budget) | INV-6 + Pass 2 F-14 | integration | BLOCKING | tests/integration/avatar/test_tier_transition_memory_spike.gd |
| **AC-51** | **(Pass 2 F-16 NEW — WebGL VRAM monitor)** **GIVEN** sprite atlases loaded on Web Export Compatibility renderer **WHEN** `RenderingServer.get_rendering_info(RENDERING_INFO_TEXTURE_MEM_USED)` polled **THEN** WebGL texture VRAM ≤ 2.3 MB upper bound (replaces stale `Performance.MEMORY_STATIC` reference per Pass 2 F-16 godot-gdscript-specialist correction) | INV-6 + Pass 2 F-16 | integration | BLOCKING | tests/integration/avatar/test_webgl_texture_vram_budget.gd |
| **AC-52** | **(Pass 2 F-13 NEW BLOCKING — #29 dependency fallback)** **GIVEN** #29 Mirror Moment System sprint slot confirmed by producer OR #26 minimal fallback path documented **WHEN** sprint kickoff **THEN** Pillar 5 substrate delivery path exists (either full #29 ceremony OR #26 degraded mode with minimal screenshot prompt + comparison overlay); P5 PRIMARY substrate cannot fail silently | Pass 2 F-13 + Pillar 5 | manual/process | BLOCKING (sprint planning gate) | production/qa/evidence/avatar_mirror_moment_dependency_check.md |

### Coverage Map

**Core Rules (16/16 covered)**:
- CR-1 → AC-01, AC-07 | CR-2 → AC-05 | CR-3 → AC-03, AC-06 | CR-4 → AC-04, AC-23, AC-39 | CR-5 → AC-10 | CR-6 → AC-02, AC-09, AC-28 | CR-7 → AC-08, AC-24, AC-31 | CR-8 → (covered by Suspended state in AC-21 + EC-39) | CR-9 → AC-06, AC-20 | CR-10 → (cast hard window covered by AC-05 + EC-20/21) | CR-11 → AC-11, AC-30, AC-33 | CR-12 → AC-04, AC-25 | CR-13 → AC-13, AC-19 | CR-14 → AC-12, AC-14, AC-40 | CR-15 → AC-15 | CR-16 → AC-16, AC-32

**Formulas (5/5 covered)**:
- F1 → AC-03, AC-17 (boundary) | F2 → AC-04, AC-18 | F3 → AC-10, AC-15, AC-19 | F4 → AC-20 | F5 → AC-21

**INVs (6/6 covered)**:
- INV-1 → AC-22 (+AC-02) | INV-2 → AC-23 | INV-3 → AC-24 (+AC-08) | INV-4 → AC-25 | INV-5 → AC-26 (+AC-21) | INV-6 → AC-27 (+AC-12, AC-34)

**CI Lint Suite (7/7 covered)**:
- CI-1 → AC-28 | CI-2 → AC-29 | CI-3 → AC-30 | CI-4 → AC-31 | CI-5 → AC-32 | CI-6 → AC-33 | CI-7 → AC-34

**Critical EC coverage (9 of 10 CRITICAL ECs mapped)**: EC-01 (private mode) → AC-25; EC-02 (config missing) → AC-29; EC-03 (config drift) → AC-25; EC-05 (persistence corruption) → AC-25; EC-07 (race condition) → AC-13; EC-09 (NaN sentinel) → AC-16; EC-18 (hot-reload reject) → AC-29; EC-34 (pending milestone replay) → AC-19; EC-41 (split-brain milestone) → AC-19; EC-44 (sprite load fail) → emergency-avatar fallback covered by AC-07; EC-53 (#29 not registered) → AC-10 (pending_emit_queue).

**Fantasy Risks (3/3 covered)**: FR-1 → AC-39 | FR-2 → AC-14, AC-40 | FR-3 → AC-41

**Falsifiable Tests (5/5 covered)**: FT-1 → AC-35 | FT-2 → AC-36 | FT-3 (anti-fab static-analysis equivalent) → AC-22 + AC-32 | FT-4 → AC-37 | FT-5 → AC-38

### Test Distribution Summary

| Type | Count | % | Gate Distribution |
|------|-------|---|-------------------|
| Unit (Logic) | 17 | 41% | All BLOCKING |
| Integration | 10 | 24% | 6 BLOCKING / 4 ADR-RATIFICATION-GATED |
| Static-analysis (CI lint) | 10 | 24% | 8 BLOCKING / 2 ADR-GATED |
| Manual / Playtest | 4 | 10% | All ADVISORY |
| **Total** | **41** | **100%** | **31 BLOCKING / 6 ADR-RATIFICATION-GATED / 4 ADVISORY** |

### Gate-Level Discipline Audit (lesson applied from #15 Pass 2 F-9)

- All playtest/visual evidence ACs (AC-35..AC-38) marked **ADVISORY** — avoids catch-22 from #15 Pass 2 (pre-merge playtest gate impossible)
- All formula/logic ACs **BLOCKING** — no exception for "feel" qualities masquerading as logic
- ADR-gated ACs explicitly tag the blocking ADR (0001 / 0003 / 0006) so dependency unblock cascades are traceable
- Anti-fabrication (AC-22, AC-32) gated on ADR-0006 because state-machine contract canon list is the source-of-truth for "canonical signal"
- AC-41 ledger copy verification = static-analysis ADVISORY (player-facing copy review not gate-blocking)

## Open Questions

### Q-OQ1 — Layered system v0.2 migration path

**Question**: 當 v0.2 layered armor system 上線，`#26` 點 migrate single-sprite avatar 到 layered system，唔 break MVP player 嘅 visual continuity？
**Impact**: P5 framing scaling (FR-3) — 玩家會否覺得 MVP avatar 同 v0.2 avatar feel like 兩個 game？
**Resolution path**: v0.2 GDD revision 必須 inherit「ledger」framing；layered system = 「ledger column 變多」，唔係「之前係 placeholder」。Sprite asset pipeline maintain backwards-compat — T0/T1/T2/T3 single-sprite remain valid，layered system 在 T3+ 加 layer slots。
**Resolution owner**: art-director + game-designer (v0.2 GDD)
**Priority**: LOW (v0.2 scope, not MVP blocker)

### Q-OQ2 — `combat_started` / `combat_ended` signal source **(Pass 2 F-10 PROMOTED — RESOLVED 2026-05-28 Option C)**

**Original question**: CR-2 specifies GSM `state_changed(COMBAT_TICK)` 作為 combat enter/exit trigger，但 gameplay-programmer Section B 建議用 explicit `combat_started` signal from `#14 EnemyDirector` (semantic clarity over GSM state)。邊個 approach 對？

**Pass 2 F-10 escalation (qa-lead B2)**: AC-05 references `COMBAT_TICK` but actual signal source may be `combat_resolved` from `#13 CombatResolver` OR `combat_started` from `#14 EnemyDirector` — **AC-05 trigger may never fire as written**。Must resolve before sprint commit。

**Resolution 2026-05-28 — Option C (third path; original Option 2 + Option 3 both invalid)**:

**Ground-truth verification (read both GDDs)**:

1. **`design/gdd/game-state-machine.md` line 585-589**: GSM `GameState` enum = `{BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}` — **冇 `COMBAT_TICK` value**。Combat-bearing states 係 `COMBAT_ACTIVE` (regular combat) 同 `BOSS_ENCOUNTER` (boss combat — Pillar 3 mid-workout euphoria spike per GSM Rule 7) → **Option 2 (keep as-is) FAILS — signal will never fire**。
2. **`design/gdd/enemy-director.md` Rule 5 (line 144-146) + AC-07 (line 1220) + CI lint #3 (line 603)**: #14 EnemyDirector signal surface **lock 死 exactly 3 signals**: `hit_resolved` / `enemy_killed` / `combat_metric_anomaly` — CI lint 自動驗證 zero extras。**Option 3 (add `combat_started/ended` to #14) FAILS — violates #14 Rule 5 + CI lint + would require breaking #14 Approved GDD's locked signal surface**。
3. **`design/gdd/game-state-machine.md` line 230-231**: GSM → #14 (signal-only): "EnemyDirector 監聽進入 `CombatActive` / `BossEncounter` 啟動 sub-machine，監聽離開做 cleanup。GameStateMachine 從不直接 call EnemyDirector method." → **#14 自己已經係 subscribe GSM `state_changed` filtered by `to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}`** — #26 Avatar Renderer 跟同一 pattern 完全 architecturally consistent。

**Resolution — Option C**: CR-2 + AC-05 + Section C States (Idle/Combat/Casting rows) + Transition Diagram + Section F Animation Specs Table (combat row) 全部改用 GSM `state_changed(from, to, payload)` signal (already wired via ADR-006 Contract 6 `connect_for_initial_state` per CR-13)，filter 條件:

- **Combat enter trigger**: `to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` (boss combat shares same combat animation per MVP single-sprite CR-1 — no separate "boss combat" animation state)
- **Combat exit trigger**: `from ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` AND `to ∉ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` (catches all exit paths: combat→idle on `loot_confirmed` chain, boss→loot, boss→suspended emergency, etc.)
- **Casting state return** (CR-2 d): use GSM `current_state ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` membership check (sync read, no new signal)

**Architectural benefit**:
- Zero cross-GDD blast radius — #14 signal surface 不郁，#14 GDD 唔需要 revise
- Mirrors #14's own established subscription pattern (architectural consistency)
- Uses existing wired connection (CR-13 `connect_for_initial_state` already includes GSM `state_changed`)
- Handles boss combat correctly without separate code path (`BOSS_ENCOUNTER` triggers combat anim via same handler)

**Files revised this resolution** (single GDD — `design/gdd/avatar-renderer.md`):
1. Status header — add Q-OQ2 RESOLVED line
2. CR-2 (Section C Detailed Design — Core State Machine table) — rewrite transition rules (a)/(c)/(d) signal source
3. Idle / Combat / Casting rows (Section C States and Transitions) — replace `COMBAT_TICK` with `COMBAT_ACTIVE | BOSS_ENCOUNTER` membership
4. Transition Diagram (Section C) — update Combat entry label
5. Combat animation table (Section F Visual+Audio) — trigger column updated
6. AC-05 (Section H) — rewrite GIVEN/WHEN with concrete `state_changed` signature

**EC-11 unchanged**: "GSM `state_changed` fires with value not in known enum" generic wording remains valid (covers any future GSM enum addition).

**Resolution owner**: gameplay-programmer (recommended Option C) + creative-director (autonomous mode approval per [feedback_autonomous_decisions]) — no #14 owner involvement required (signal surface untouched)
**Priority**: ~~BLOCKING for sprint planning~~ → **RESOLVED** — CR-2 + AC-05 now reference concrete locked GSM signal schema; tests writable.

### Q-OQ3 — Godot 4.6 API verification flags

**Question**: technical-artist + gameplay-programmer flagged multiple Godot 4.6 APIs needing verification against engine-reference (post-LLM-cutoff):
- `AnimatedSprite2D.set_frame_and_progress(frame, progress)` signature
- WebP lossless import options in 4.6
- `Performance.MEMORY_STATIC` monitor enum (may renamed in 4.5/4.6)
- Compatibility renderer canvas_item shader feature support matrix for WebGL2
- `AnimationPlayer.pause()` semantic changes post-4.4

**Impact**: Implementation correctness — APIs 可能 renamed / deprecated / behavior-changed
**Resolution path**: Verify each API against `docs/engine-reference/godot/modules/rendering.md` + create new `docs/engine-reference/godot/modules/animation.md` if needed
**Resolution owner**: godot-specialist + engine-programmer
**Priority**: MEDIUM (gates sprint kickoff for `#26` stories — must resolve before code-writing begins)

### Q-OQ4 — Class posture vs MVP sprite asset workload trade-off **(CD F-7 PROMOTED — PRE-SPRINT-PLANNING SCOPE DECISION GATE)**

**Question**: art-director Section A confirms class posture 必須喺剪影層面 differentiated (per Pillar 4 + FT-4 16×16 silhouette test)。technical-artist 提出 palette-swap shader 可以慳 sprite redraw workload，但 art-director REJECT (palette tint 唔可以 substitute mass distribution change at silhouette level)。**Confirmed scope: 36 sprite sheets**。Solo dev capacity 夠？

**Impact**: MVP timeline + scope creep risk per game-concept 「Velocity × 0.5」rebase + Pillar 4 visible differentiation substrate adequacy

**🚨 CD F-7 PROMOTION**: Q-OQ4 **MUST resolve before #26 sprint planning** via art-director + producer scope-budget gate (not before APPROVED verdict — but blocks `/create-stories` for #26)。Acceptable resolutions:

- **(a) Confirmed solo dev sprite throughput ≥ 1.5 sheets/week sustainable** → 36 sheets ships as-spec, Pillar 4 full delivery preserved
- **(b) Reduce to 2 tiers × 3 classes × 3 states = 18 sheets** → adjust P5 milestone cadence to 4-week (not 7-day) intervals + update Formula 3 MILESTONE_CADENCE_SECONDS from 604800 → 2419200 (4 weeks)
- **(c) Reduce to 4 tiers × 1 class × 3 states = 12 sheets** → drop P4 visible differentiation to v0.2 + downgrade Pillar 4 to「supporting via animation rate only」(requires game-concept.md Pillar 4 wording revision — major scope cut)

**Forcing function**: producer + art-director joint scope-budget session pre-sprint-kickoff。Resolution recorded喺 producer milestone plan + GDD revision (this section updated post-decision)。

**Resolution owner**: art-director + producer + creative-director
**Priority**: **HIGH (BLOCKING for sprint planning, NOT for APPROVED verdict — per CD F-7 promotion logic)**

### Q-OQ5 — Mirror Moment evolution_tier vs other progression milestones **(CD F-8 PROMOTED — PILLAR 5 RETENTION SUBSTRATE ADEQUACY GATE)**

**Question**: 目前 Mirror Moment milestone 唯一 trigger 係 `evolution_tier` increase。但 game-concept Pillar 5 line 177 promises「**每週** avatar 必須有 visible、可截圖嘅進化反映真實 body change…呢個係單機 game 嘅 retention 心臟」。GDD as-written delivers **every-7-days-OR-tier-promotion** (Formula 3 two-gate)，唔係 weekly。**4 tiers over 8-week MVP timeline = max 4 Mirror Moments**。

**🚨 CD F-8 PROMOTION**: After tier T3 達 (potentially week 4-5 for high-frequency lifters)，**zero more Mirror Moments for rest of MVP** — 「retention 心臟」flatlines。Pillar 5 design test「玩家做完 4 週訓練，打開 game 第一眼睇唔睇到自己變咗？」喺 week 5-8 答 **NO** — substrate adequacy failure at MVP→v0.2 retention bridge。

**Acceptable resolutions** (pick one before MVP starts):

- **(A) Keep 4 tiers + REFRAME Pillar 5 wording** — game-concept.md Pillar 5 改為「milestone-based, NOT weekly」(e.g.「真實 PR / ability unlock 觸發 visible 進化」)。Cheapest，requires concept doc edit。**Honest scope downgrade。**
- **(B) Keep 4 tiers + ADD micro-evolution sub-tiers** — within each major tier (T0.25 / T0.5 / T0.75 → T1) driven by smaller stat deltas，giving ~12-16 milestone moments over 8 weeks。Preserves Pillar 5 weekly cadence promise。**Couples to F-7 sprite workload** (more sub-tier sprites needed — +6-12 sheets vs current 36)。
- **(C) Accept retention dip after week 4-5, document as known v0.2 problem** — riskiest option，MVP retention test 可能 fail。

**Forcing function**: creative-director call before #26 sprint kickoff + before `/create-architecture` for #29 Mirror Moment system。Resolution gates concept doc Pillar 5 wording + #26 Formula 2 sub-tier schema + #29 Mirror Moment GDD authoring。

**Resolution owner**: creative-director (P5 framing call) + game-designer (cadence balance) + producer (scope impact)
**Priority**: **HIGH (BLOCKING for sprint planning + #29 GDD authoring, NOT for APPROVED verdict — per CD F-8 promotion logic)**

### Q-OQ6 — Cast queue interrupt vs cancel design

**Question**: CR-10 specifies cast queue depth = 1 (drop oldest queued if 3rd cast arrives)。Game-designer alternative: cancel current cast on new cast (responsive but visually jarring)。Decision locked at queue model — confirm with full team playtest after vertical slice?
**Impact**: Combat feel + animation thrash prevention
**Resolution path**: Vertical slice playtest with 3 specialists (game-designer + gameplay-programmer + technical-artist) compare queue vs cancel behavior on real input
**Resolution owner**: game-designer (final call after playtest)
**Priority**: LOW (default queue model documented per CR-10, can tune post-VS)

### Q-OQ7 — `_pending_milestone` persistence schema versioning

**Question**: CR-12 schema v1 includes `pending_milestone` field。EC-34 specifies pending milestone re-validation on boot — if config (AvatarEvolutionConfig.tres) version changed during pending window, gates may be invalid。Schema v2 migration path 點 handle？
**Impact**: Persistence integrity (INV-4) — schema v1→v2 migration 必須 <900ms (ADR-0003 ceiling)
**Resolution path**: Define migration handler: if pending_milestone exists AND config_hash_at_pending != current_config_hash → drop pending + log telemetry (per EC-03 cascade behavior)
**Resolution owner**: systems-designer (schema v2 design when needed)
**Priority**: LOW (deferred until first config version bump scenario arises)

### Q-OQ8 — `connect_for_initial_state` helper implementation prerequisite **(Pass 2 F-9 BLOCKING PREREQUISITE STORY)**

**Question**: ADR-0006 Contract 6 `connect_for_initial_state` sentinel helper 喺 design docs 提及 26 次 (跨多個 GDD)，但 **NOT YET IMPLEMENTED in `src/`** (godot-gdscript-specialist B3 BLOCKING)。`#26` boot flow (CR-13) 同 6 個其他 system (#5, #9, #11, #12, #14, #15) 都依賴呢個 helper。

**Impact**: `#26` implementation cannot start until helper exists in `src/autoload/game_state_machine.gd`。Cascade affects all autoload subscribers。

**Resolution path** (Pass 2 mandatory pre-sprint):
1. Spawn `godot-gdscript-specialist` to implement `connect_for_initial_state(signal_owner, signal_name, callable, initial_event_args=null)` helper per ADR-0006 Contract 6 spec
2. Helper signature: connects + immediately emits sentinel "INITIAL_STATE" replay event to callable so subscriber gets canonical current state synchronously
3. Implement in `src/autoload/game_state_machine.gd` (or shared helper module)
4. Add CI lint: any `.connect()` call in autoload subscribers should be flagged for review → use `connect_for_initial_state` instead
5. Story sequencing: helper story MUST land before any #26 story enters sprint

**Resolution owner**: godot-gdscript-specialist + lead-programmer (story sequencing)
**Priority**: **BLOCKING for ALL #26 implementation stories** — prerequisite (Pass 2 F-9)

### Q-OQ9 — `#29 Mirror Moment System` dependency cascade risk **(Pass 2 F-13 PROMOTED — Producer escalation gate)**

**Question**: #26 emits `avatar_evolution_milestone(tier, source_metrics)` + `avatar_micro_evolution(visible_delta_kind, source_metrics)` signals。但 **#29 Mirror Moment System owns the screenshot composition / UI prompt / share button** flow，而 #29 Status = "Not Started"。

**Impact** (game-designer B5 BLOCKING)**: If #29 GDD authoring delayed OR #29 sprint slot post-#26 → **P5 PRIMARY substrate fails at MVP**。#26 emit signal but no consumer = silent feature。Pillar 5「retention 心臟」死。

**Resolution path** (Pass 2 mandatory producer escalation):
1. Producer confirm #29 sprint slot **same milestone as #26 OR earlier**
2. If #29 slip cannot be prevented → add MVP fallback: `#26` 自己 emit minimal screenshot prompt (basic comparison overlay, no full ceremony) — degraded mode acceptance criteria
3. Document minimal fallback path in #26 AC-NEW + Section UI Requirements
4. Risk: if both #26 + #29 slip → Pillar 5 substrate completely absent at MVP → game-concept anti-pillar (anti-pillar #3 retention degradation)

**Resolution owner**: producer (sprint sequencing) + creative-director (P5 fallback acceptance call)
**Priority**: **BLOCKING for MVP retention substrate** (Pass 2 F-13)

### Q-OQ10 — Class posture cumulative vs recency framing **(Pass 2 F-15 ADVISORY — tech-debt for post-MVP)**

**Question**: CR-3 + Formula 1 derive `dominant_class` from instantaneous `argmax(STR, DEX, VIT)` — 反映 **recent** training。但 push-dominant 半年 player 做完一週 leg-heavy → avatar 變 MOBILITY → screenshot share 出去 → 朋友以為佢係 leg specialist。「身體嘅 ledger」cumulative truth 同 instant argmax 有 mismatch。

**Pass 2 F-15 analysis (game-designer B4 CONCERN)**: 5-min hysteresis 解決 mid-session flicker，但唔解決 weekly identity question。Honest receipt fantasy 嘅 boundary case：什麼 time window 嘅 dominant class 先係「真嘅我」？

**Resolution options** (defer to post-MVP iteration per CD F-15 advisory call):
- (A) Keep instant argmax (current MVP) + accept that weekly identity reflects last week's training (matches#11 stat decay model if any)
- (B) Switch to rolling 28-day muscle group volume share derivation (requires #9 GDD revision to expose `get_muscle_group_volume_share(days_window)` API)
- (C) Hybrid — instant argmax for daily glance + 28-day rolling for Mirror Moment screenshot composition (best of both)

**Resolution path**: Defer to post-MVP playtest data — if FT-2 screenshot share rate <30% OR player feedback indicates「screenshot lies about my training」, escalate to creative-director option call
**Resolution owner**: game-designer + creative-director (post-MVP iteration)
**Priority**: **ADVISORY — post-MVP tech-debt** (Pass 2 F-15)

### Q-OQ11 — Performance.MEMORY_STATIC WebGL VRAM gap **(Pass 2 F-16 CONCERN — inline replace recommended)**

**Question**: INV-6 + AC-12 + AC-27 reference `Performance.MEMORY_STATIC` monitor for sprite memory budget enforcement。但 godot-gdscript-specialist confirmed (Pass 2 F-16) Godot 4.6 Compatibility renderer (WebGL2) `MEMORY_STATIC` 只 report GDScript heap，**唔 cover WebGL texture VRAM** — `SpriteFrames` atlas 載入 WebGL texture 後 VRAM 唔 reflect 喺 MEMORY_STATIC。

**Impact**: Memory budget enforcement bypass — true GPU VRAM usage 未被 monitored，mobile Safari 512MB ceiling 仍有 OOM risk despite passing AC-12/AC-27。

**Resolution** (Pass 2 inline-fix recommended): Replace metric in AC-12 + AC-27 with `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)` (Godot 4.4+) for VRAM monitoring。Keep `MEMORY_STATIC` 作 GDScript heap secondary check。

**Resolution owner**: technical-artist + qa-lead (AC update)
**Priority**: CONCERN — should fix before sprint planning (low-cost edit, high diagnostic value)
