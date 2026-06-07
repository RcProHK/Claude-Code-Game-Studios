# Loot Drop System (#15)

> **Status**: **Pass 2 Revised 2026-05-28** — Fresh-session /design-review verdict MAJOR REVISION NEEDED → 8 BLOCKING items (F-1..F-8) inline-fixed same-session per user autonomous mode + 4 items followup-tracked (F-9..F-12). Awaiting Pass 3 fresh-session re-verification.
> **Author**: creative-director (Section B Player Fantasy + Phase 5a-bis Opus gate + Pass 2 senior synthesis) + game-designer + economy-designer + systems-designer ×3 (Section C parallel) + systems-designer + economy-designer (Section D parallel) + systems-designer (Section E) + lead session (Section G + CD inline fixes + Pass 2 inline revision) + qa-lead (Section H) + art-director (Visual/Audio + UI)
> **Last Updated**: 2026-05-28 (Pass 2)
> **Pass 2 CD-GDD-ALIGN Verdict**: MAJOR REVISION NEEDED (8 BLOCKING convergent across 4 specialists) → inline-fixed pending Pass 3 verification
> **Implements Pillar**: Pillar 3 (DNF 式爆裝刺激) PRIMARY substrate / Pillar 1 (Real Body, Real Power) supporting (anti-fabrication chain 第六件套 — #2 + #3 + #11 + #14 + #9 + #15) / Pillar 4 (Muscle = Class) supporting (Formula E2 class_affinity bias) / Pillar 5 (Mirror Moment) supporting (LEGENDARY ceremony 截圖 composition)
> **Tier**: Vertical Slice (upgraded Pre-MVP → VS 2026-05-27 per #16 Boss System CRIT-5 cascade)
> **Layer**: Core
> **Section completion**: A Overview ✓ / B Player Fantasy ✓ / C Detailed Design ✓ (18 Rules + 6 States + 11 INVs + 7 CI lints) / D Formulas ✓ (10 formulas: F1-F6 systems + E1-E4 economy + 8 CF + 7 CI) / E Edge Cases ✓ (48 ECs / 10 categories) / F Dependencies ✓ / G Tuning Knobs ✓ (25 owned + 14 referenced + 5 INV-G + 4-tier stability) / H Acceptance Criteria ✓ (41 ACs — 34 BLOCKING + 4 ADR-RATIFICATION-GATED + 3 ADVISORY) / Visual+Audio ✓ / UI ✓ / Open Questions ✓

---

## Pre-Authoring Context (from Phase 2 gather)

### Dependencies (all Approved)
- **#8 Streak System** — provides `get_streak_buff_multiplier()` for streak modifier in rarity formula
- **#9 Workout State Tracker** — provides `workout_completed(workout_id, completed_exercises)` signal for daily guaranteed drop trigger + `set_progress` for in-session drop frequency
- **#14 EnemyDirector** — emits `enemy_killed(transition_id, faction, tier)` signal (loot chain seed); mini-boss kill triggers per-encounter drops

### Anti-Pillar Constraints (HARD requirement from systems-index)
**Pillar 1 drift risk** — Loot quality function MUST take real-PR-signal as primary input:
- Real workout volume / PR breakthrough as PRIMARY multiplier (≥0.7 weight)
- RNG roll as SECONDARY modifier only (≤0.3 weight)
- No code path may generate top-rarity item without real-workout signal in input

### Already-Locked Decisions (ADR-0005 Loot Rarity Formula)
- `loot_rarity_score = workout_score × 0.75 + rng_roll × 0.25`
- `workout_score = clamp(volume × PR × streak, 0, 1)`
- Pillar 1 floor: max RNG contribution = 0.25 < EPIC threshold (0.72) — proven
- Pillar 3 floor: `final_tier = max(raw_tier, COMMON)` — workout always produces ≥ COMMON
- Data-driven `LootRarityConfig.tres` (designer-adjustable thresholds)
- RNG seeded on `transition_id` (deterministic from #14 EnemyDirector kill signal)

### Already-Locked Decisions (from #16 Boss System)
- Final boss loot floor: **UNCOMMON minimum** (Pass 3 economy E3 anti-rarity-overlap fix)
- Mini-boss loot ceiling: **UNCOMMON-RARE band**
- `boss_killed` signal payload `transition_id` (Pillar 1 anti-fabrication chain seed)
- Q-X6 loot sink cross-doc to #17 Equipment & Inventory (tracked Followup #12)

### Art Bible Locked Decisions
- 5-tier rarity color ladder: white → green (Uncommon) → blue (Rare) → purple (Epic) → orange (Legendary)
- Particle multiplier: 3× combat baseline (P-05 loot-drop-modal pattern)
- Rarity-calibrated hold time: COMMON 0.2s → LEGENDARY 0.8s
- Time-stop window: 0.4s (Section 2.1 mood table)
- Saturation override: World −60% during burst, recover 2.0s total

### UX Pattern Library Locked Decisions
- P-05 loot-drop-modal (full spec'd)
- P-06 rarity-color-tier (5-tier system with shape + animation + audio backup per accessibility)

### Cross-System Forward Constraints (from #14 EnemyDirector FR table)
- FR-2 binding: `enemy_killed.transition_id → #15 LootDrop chain seed`
- ADR-0005 FR-2 ratification gate

### Open Questions (to resolve during design)
- Q-OQ1: 每個 mini-boss kill 嘅 loot drop rate （always vs sometimes）— affects Pillar 3 ritual cadence
- Q-OQ2: Daily guaranteed drop vs per-workout-session drop — once-per-day rule clarification
- Q-OQ3: Private Mode loot disable contract (ADR-0003 detect-and-gate)
- Q-OQ4: Loot pending state durability (ADR-0003 Tier 1 backend-primary handling)
- Q-OQ5: Equipment item generation contract (#17 dependency)

---

## Overview

> **⚠️ Anti-Pillar Drift Guard (F-10)**: 任何修改 ADR-0005 formula weights 嘅 PR 必須 trigger CD-PILLARS re-gate。`WORKOUT_WEIGHT` 不得低於 0.70，`RNG_WEIGHT` 不得高於 0.30。違反 → Pillar 1「Real Body, Real Power」承諾即時 collapse。CI lint `check_loot_config_hash_pinned.gd` (AC-29) 鎖死 `LootRarityConfig.tres` SHA — drift = build fail。

Loot Drop System (#15) 係 **Core layer** 嘅 data + ritual hybrid system，負責將真實 workout signal 轉化為 in-game 裝備獎勵。佢由兩個獨立但 coupled 嘅 sub-responsibility 組成：

1. **Data layer（loot generation）**: 收到 `boss_killed.transition_id`（#14/#16）或 `workout_completed.workout_id`（#9）signal 之後，根據 ADR-0005 嘅 deterministic formula 計算 `loot_rarity_score`、決定 rarity tier、生成 LootDrop instance、寫入 PersistenceLayer（`loot.pending`）+ POST 去 GymSys backend（per ADR-0003 backend-primary contract）。
2. **Player-facing layer（drop ritual trigger）**: 通過 `loot_dropped(drop_id, rarity_tier, item_type)` signal 通知 #21 Loot Drop Modal + #5 ParticleSystemWrapper + #6 ScreenEffects，触发 Pillar 3 dopamine ceremony。

**為何呢個 system 存在**：Pillar 3 (DNF 式爆裝刺激) 嘅核心承諾係「每次 workout 都有值得截圖嘅 loot drop」。冇 #15 = boss 死咗但冇 loot → 整個遊戲嘅 reward loop 斷裂。同時 Pillar 1 (Real Body, Real Power) 要求「冇 cheat 路徑去頂級裝備」— 呢個約束令 #15 唔可以單純 RNG-based，必須用 ADR-0005 嘅 workout-weighted formula。

**Player interaction model**: **automatic**（player 唔需要 mid-set 操作 loot drop trigger，由 boss kill / workout complete event passive 触发）。但 **player-perceived 卻係 highly active**——爆裝 ritual 嘅 visual+audio peak 係 P3 嘅 dopamine delivery，玩家會主動 anticipate + cap 圖 + share。呢個係 Pillar 2 (無壓力陪伴) 同 Pillar 3 (爆裝刺激) 嘅張力解決方案：**input frictionless，output ceremonial**。

**Implementation reference**: 完整 rarity calculation formula、PersistenceLayer namespace (`loot.*`)、deterministic RNG seeding (per `transition_id`) 同 anti-fabrication enforcement 喺 [ADR-0005 Loot Rarity Formula](../../docs/architecture/adr-0005-loot-rarity-formula.md) 已 ratified — 本 GDD 唔重複 formula 數學定義，只引用同延伸 player-facing 行為。

---

## Player Fantasy

### Core Identity: 「肉身蓋章」(The Body's Stamp)

> 你做完最後一組 deadlift，set down barbell，抹下汗，望住手機。一條金光由畫面底升起，世界飽和度跌咗一截，時間停 0.4 秒——粒 LEGENDARY 喺你 avatar 手上發光 0.8 秒。你冇撳過任何掣。呢粒裝備存在嘅理由，係你頭先撐起咗嗰 180kg。

Loot 喺 Mirror Hero **唔係 reward，係身體勞動嘅憑證**。Pillar 3 嘅 drop euphoria 唔係「賭場式 jackpot」嘅情緒——係**「我做到」嘅 ceremonialization**。

### Architectural Tension as Design Virtue (Pillar 1 ↔ Pillar 3)

RNG 嘅 0.25 weight 唔係決定「你今日好唔好彩」，係決定「你今次嘅功績**用咩戲劇形式呈現**」。Workout score 0.75 weight 係 floor 同 ceiling 嘅雙重保障：

- **大 PR + 連勝 streak 注定見到頂級 tier**——workout effort 上限直接決定 ceiling
- **純 RNG 永遠攞唔到 EPIC**（ADR-0005 已 proof: max RNG=0.25 < EPIC 0.72 threshold）——架構性鎖死 Pillar 1
- **workout_completed 永遠 ≥COMMON**（Pillar 3 floor guarantee）——做咗就一定有

呢三層保證令「RNG ≤ 0.3」由「constraint」變成「**dramatic interpretation layer**」：workout 決定咗「應該有幾勁嘅嘢出」，RNG 只係決定「呢次嘅 reveal 戲劇張力點」。

### Fantasy Boundary

**In scope**:
- 每次 workout completion 都有 ceremonial drop，rarity 嘅 surprise 喺 RNG 嘅 interpretation 上，唔喺 existence 上
- Screenshot-worthy reveal moment（hold time 0.2s→0.8s + time-stop 0.4s + saturation drop tier 分明）
- **Workout-locked daily drop**（per CD F-6 Pass 2 rename）作為「你今日有做」嘅 ritual confirmation（rarity 隨 workout_score 浮動，無 pity bonus）。**呢個 drop 係 workout-conditional，唔係 calendar-conditional**——zero-workout 日唔會「拎走」任何 entitlement，因為從來冇 entitlement 存在。Aligns game-concept anti-pillar「缺日只係 delay bonus」。
- Boss kill 嘅 differentiated reveal（mini-boss UNCOMMON-RARE band / final boss UNCOMMON+ floor）

**Explicitly NOT**:
- 純 RNG 攞到 LEGENDARY（架構鎖死，唔可能）
- Loot box 課金、付費 re-roll、加 RNG 嘅 boost
- Skip workout 攞 drop / grind-for-loot 嘅 farming loop
- Mid-set loot 干擾 player attention（Pillar 2 violation — 等 workout_completed / boss_killed 邊界先 trigger）
- Screenshot 出嚟睇唔出「呢個人付出咗幾多」嘅 generic trophy

### Falsifiable Tests (5 observable player-behavior claims)

| # | Test | Falsification trigger | Pillar binding |
|---|------|----------------------|----------------|
| FT-1 | **Screenshot test** | 50%+ players 喺 first week 攞到 RARE+ 之後**冇 screenshot** | Pillar 3 — ceremony 唔夠 share-worthy |
| FT-2 | **Attribution test** | Players 形容 LEGENDARY drop 嗰陣用「好彩」(lucky) 多過「值得」(earned) | Pillar 1 — RNG weight 感受上超過 workout weight |
| FT-3 | **Skip test** | 30%+ players 喺 hold time 期間 tab 走 / 撳掣想 skip | Pillar 2 ↔ 3 — ceremony length 超過 attention budget |
| FT-4 | **Workout-day differentiation test** | Heavy PR day vs light recovery day 嘅 drop 感受冇分別 | Pillar 1 — workout_score 0.75 weight 喺感官層面冇 expressed |
| FT-5 | **Private Mode acceptance test** | Private Mode 用戶見到「loot disabled」banner 之後 >20% 即時 churn 或投訴 | Pillar 3 — fantasy 太依賴 loot 作為唯一 reward channel |

### Fantasy Risk Register

#### FR-1: 「RNG-fabrication leak」(Pillar 1 violation)

- **Risk**: Player 感受到 RNG 可以 override workout effort（即使 math 上唔可以）
- **Binding**: ADR-0005 ratification gate — formula proof（max RNG=0.25 < EPIC 0.72）必須喺 UI/tooltip 層 expose。建議 #21 Loot Drop Modal 喺 RARE+ drop 顯示「workout contribution: X% / chance: Y%」micro-breakdown
- **F-5 emotional reinforcement (NEW per CD)**: 純 informational breakdown 唔夠 — player 睇到「workout 貢獻 87%」會諗「哦」，唔會 internalize「呢件係我嘅身體 unlock」。EPIC/LEGENDARY 必須加 narrative microcopy variant：
  - LEGENDARY: 「呢件 RNG 唔到 0.25，係你嘅身體 unlock 嘅」
  - EPIC: 「Stamped by [exercise×weight×reps]」(e.g., 「Stamped by 180kg × 5」)
  - RARE: 「Earned through [N] sets across [muscle group]」
- **Mitigation owner**: #15 Section H (AC-38 promoted BLOCKING) + #21 GDD authoring time
- **Falsified by**: FT-2 attribution test — AC-38 extended to require player 喺 post-session interview 主動表達「呢件 loot 因為我做咗 X」(verbal attribution test)

#### FR-2: 「Ceremony 太重 / 太輕」(Pillar 2 ↔ Pillar 3 collision)

- **Risk**: COMMON 0.2s hold time 感覺「未開始已完」(under-ceremony)，或 LEGENDARY 累計 ~3.2s（0.8s hold + 0.4s time-stop + 2.0s recovery）喺 mid-set transition 變成干擾
- **Binding**: #21 Loot Drop Modal 100ms timing window — actual time-from-trigger-to-visual-onset 必須 ≤100ms。Binding 到 #5 Particles + #6 ScreenEffects 嘅 saturation recovery curve 必須 ease-out
- **Mitigation owner**: #21 GDD + ADR-0001 (FR-2 RATIFICATION-GATED)
- **Falsified by**: FT-3 skip test

#### FR-3: 「Daily guaranteed drop 退化為 chore」(Pillar 3 erosion)

- **Risk**: 「每日一定有 drop」變成「打卡攞嘢」心態，drop 失去 ceremonial weight
- **Binding**: ADR-0003 backend-primary server-authoritative daily flag + #15 rarity floor logic。Guaranteed drop 嘅 rarity 完全跟 workout_score（**唔加 pity bonus**）— daily 係 existence guarantee，唔係 quality guarantee。Server-side validation：daily drop 唔可以由 client trigger
- **Mitigation owner**: Section C Core Rules + ADR-0003 + GymSys backend contract
- **Falsified by**: Long-term retention metric — week-4 players 嘅 average workout_score 跌穿 week-1 baseline

---

> **CD assessment**: Framing A 將 Pillar 1 ↔ Pillar 3 tension 直接 reframe 成 fantasy 嘅核心定義——「loot 係 body work 嘅憑證」呢句 phrase 本身就否定咗 generic loot box framing，同時為 ADR-0005 嘅 0.75/0.25 weighting 提供 narrative justification。Downstream benefit: phrase 可以直接喺 #21 Loot Drop Modal 嘅 micro-copy 用（例如 RARE+ subtitle：「Stamped by 180kg × 5」）令 fantasy 渗透到 UI 層。

---

## Detailed Design

### Cross-Specialist Synthesis Notes

呢個 section 由 3 個 specialists 並行協作 — game-designer 主導 player-facing rules、economy-designer 主導 frequency/distribution/sink contracts、systems-designer 主導 boot/signal/persistence/CI。Lead session 解決咗以下 cross-spec tensions：

1. **Mini-boss signal source**：mini-boss kill 經 `#14 enemy_killed`（per #16 Pass 2「Mini-boss = EnemyTemplate via #14 wave system」），final boss 經 `#16 boss_killed`。
2. **Mini-boss drop rate × per-workout cap**：100% drop per kill + per-workout LootDrop ceremony cap = **6**（economy rec 1.1 — protects Pillar 3 「值得截圖」ceremony budget）。第 7+ boss kill 唔 trigger ceremony 但 boss XP 照計。
3. **`workout_score = 0` fabrication guard**：無論來自 workout_completed 或 boss_killed，rarity 強制 `final_tier = COMMON`（economy rec 1.2 + game rule 18 OPEN auto-resolution）。
4. **Daily token anchoring**：first `workout_completed` per UTC day claim token；subsequent same-day workouts 無 extra workout drop（boss drops 仍然觸發，受 cap 6）。
5. **Reveal queue race**：Revealing → Revealing(next) enqueue tail（game-designer rule 11 OPEN auto-resolution — protects current ceremony UX）。
6. **30-day TTL handling**：auto-reveal-on-load next session boot（game-designer rule 12 OPEN auto-resolution — Pillar 3 ritual integrity）。
7. **systems-designer 3 OPENs auto-resolved**：(a) `#15` autoload **position 7** (after `#14`)；(b) IndexedDB write >100ms 用 **optimistic emit + rollback-on-write-fail** pattern；(c) `_drops_by_transition` cache 跟 `loot.committed` 一齊 drop。

### Core Rules

#### Trigger & Generation

1. **Trigger sources (closed list)**：LootDrop 只可由以下三類 upstream event 生成 — (a) `#9 workout_completed` → daily guaranteed drop；(b) `#14 enemy_killed` 當 `boss_id` 屬 mini-boss → mini-boss drop；(c) `#16 boss_killed` 當 tier = final → final boss drop。其他 enemy_killed event **唔產生 LootDrop**（保護 Pillar 3 ceremony budget）。

2. **Daily guaranteed drop scoping**：每個 UTC day 最多一次 workout-triggered LootDrop。由 GymSys backend 嘅 `POST /api/game/loot/claim-daily` 回 `{eligible: bool, daily_token}` 授權。Token 已用 → 同日後續 `workout_completed` event 唔再產生 workout drop（boss drops 唔受影響，仍受 Rule 7 cap）。

   **F-4 boundary 強化 (Pillar 1 anti-fabrication)**: Daily guaranteed drop 嘅 rarity **嚴格 follow workout_score**，無 pity bonus / 無 streak floor / 無 PR auto-promotion / 無 minimum tier guarantee 超出 ADR-0005 Pillar 3 COMMON floor。當日 workout_score=0.2 就攞 COMMON，唔會 trigger 額外 RARE/EPIC「daily bonus」。Mihoyo daily commission anti-pattern (打卡攞 free EPIC) 喺架構層面阻擋。

3. **Daily drop timing rule**：Daily drop 由 `workout_completed` event 即時 trigger，**唔係** UTC midnight 自動發放。冇做 workout 嗰日就冇 drop（Pillar 1 anti-fabrication core — loot 跟 workout 行為，唔係跟日曆）。

4. **Mini-boss loot rule** (**Pass 2 F-5 revision**)：Mini-boss kill **100% drop**（per Q-OQ1 + economy rec 1.1），但 final rarity tier 受 **dual-gate**：
   - **(a) Source-event ceiling cap = RARE**（即使 raw formula 計到 EPIC 都 clamp 落 RARE，per Formula 1）
   - **(b) Workout-score tier ceiling (F-5 NEW)**: `max_tier_from_workout = floor(clamp(workout_score, 0.0, 1.0) × 5)` mapped to {COMMON=0, UNCOMMON=1, RARE=2, EPIC=3, LEGENDARY=4}。即係 workout_score=0.2 → max_tier=COMMON ceiling；workout_score=0.6 → max_tier=RARE ceiling；workout_score=0.9 → max_tier=EPIC ceiling（仍受 mini ceiling cap RARE 約束，所以 effective ceiling = min(RARE, EPIC) = RARE）。
   - Pillar 3 floor 同時生效，最低 = COMMON。
   - **Rationale (Pass 2)**: 100% drop preserves P3 「every mini-boss = something drops」floor，**但** workout-score gate ensures P1「肉身決定 ceiling」substrate honest — 低 workout_score 唔可以靠 RNG 攞到 RARE。對抗 game-designer B1 「loot 變 exercise-completion token」風險。

5. **Final boss loot rule**：Final boss kill **100% drop**，rarity **floor = UNCOMMON**（per #16 Pass 5），ceiling = LEGENDARY (無 cap，唔受 F-5 workout-score gate 限制 — final boss 係 session 高潮，full rarity range 開放給玩家完成完整 workout 嘅 reward)。Player progression milestone moment。

6. **Per-workout LootDrop ceremony cap = 6 with final-boss reservation** (**Pass 2 F-2 revision**)：一個 workout session 內，**ceremony budget 拆兩個獨立 slot pool**：
   - **MINI_BOSS_CEREMONY_CAP = 5** (mini-boss 同 workout-locked daily 共享)
   - **FINAL_BOSS_RESERVED = 1** (final boss 永遠有 ceremony slot — 唔可以被 mini-boss 食走)
   - **Total ceremony budget = 6** 不變
   - **Behavior**: 第 6 個 mini-boss kill 命中 MINI_BOSS_CEREMONY_CAP → routes to **micro_ack tier** (F-3 NEW，見下); final boss kill **無論幾多 mini-boss 喺前** 永遠 trigger full ceremony; 第 7+ mini-boss 同樣 micro_ack。
   - **Why reservation, not preemption**: preemption 會破壞 chronological causality (player 見到 mini #N 死靜咗、跟住 final boss 大放 → 順序合理；反過來 final boss 先大放、跟住 mini #(N-1) 重新出 ceremony → 違反時間直覺)。
   - `[CI lint: emit `loot_ceremony_capped` telemetry when MINI_BOSS_CEREMONY_CAP hit; emit `loot_final_boss_ceremony_reserved_triggered` when reservation slot used]`

   **F-3 micro_ack tier (NEW ceremony state)**: 當 mini-boss kill 命中 MINI_BOSS_CEREMONY_CAP，drop **仍然 generate + persist to inventory/mailbox**，但 visual ceremony 由 full reveal 降為 **micro_ack**：
   - 0.15s 細 toast notification (top-right corner，唔遮 combat area)
   - Mailbox badge increment animation (+1)
   - 無 time-stop / saturation drop / camera focal lock / particle burst peak
   - 維持 audio sting (降一 tier — RARE micro_ack 用 UNCOMMON sting)
   - **Rationale**: P1「multi-effort 應該被 acknowledged」satisfied (drop 唔 disappear)，P2 attention budget protected (15-frame micro 唔搶 set 注意力)，P3 ceremony 高峰仍然 reserved (final boss)。
   - Telemetry `loot_micro_ack_triggered(workout_id, mini_boss_seq_num)` for FT-1 screenshot test cohort analysis。

   **F-3 Design rationale for cap=6** (revised Pass 2): 平均 45-min gym session 預期 3-5 ceremony-worthy events (1 workout-locked daily drop + 2-4 boss kills typical for a 4-5 exercise session)。Split 5+1 reservation：5-exercise session 最多 5 ceremony (4 mini + 1 final + 1 daily — 等等，5+1+1=7 over budget) ←— **important clarification**: daily workout drop 屬 MINI_BOSS_CEREMONY_CAP=5 pool (因為 daily drop 同 mini-boss 一齊喺 mid-session 出，share attention budget)；final boss reservation 獨立。所以 5-exercise session = 4 mini + 1 daily = 5 (剛滿 mini pool) + 1 final = 6 total ceremony，剛滿 budget。6-exercise session = 5 mini + 1 daily = 6 over mini pool by 1 → 第 5/6 mini-boss 其一 micro_ack + 1 final ceremony = 5 full ceremonies + 1 micro_ack + 1 final = 不超總 attention budget。**AC-40 (FT-1 screenshot test, promoted BLOCKING)** 將 validate baseline；TUNABLE range MINI_BOSS_CEREMONY_CAP [2, 11], FINAL_BOSS_RESERVED LOCKED at 1。

7. **Per-boss-encounter idempotency**：同一個 `boss_killed.transition_id` / `enemy_killed.transition_id` 最多一個 LootDrop（per INV-7 + idempotency rule 9）。

7.5. **workout_id resolution for ceremony cap** (**Pass 2 F-1 NEW** — unanimous structural defect fix)：因為 `boss_killed = (transition_id, boss_id, tier)` 同 `enemy_killed = (transition_id, faction, tier)` payload 都唔帶 `workout_id`（per signal contract），但 Formula 2 ceremony_cap_check key 用 `workout_id`，#15 必須喺 trigger event handler 入面查 #9 攞 active workout context：
   - **API call**: `WorkoutStateTracker.get_active_workout_id() -> String | null`
   - **Non-null branch** (active workout): F2 ceremony_cap_check 用嗰個 workout_id 做 key，normal ceremony pipeline。
   - **Null branch** (no active workout — e.g. player 喺 gym 之外打 debug boss / cross-session edge case): drop **仍然 generate + persist**（P3 floor preserved，唔 silent loss），但 **route to non-ceremony path**（直入 inventory/mailbox，emit `loot_drop_unbound(transition_id, reason="no_active_workout")` audit telemetry，唔 emit `loot_dropped` ceremony signal）。**唔可以 silently suppress drop** — that 會違反 P3 ritual integrity。
   - **CI lint**: `tools/ci/check_loot_workout_id_resolution.gd` greps boss_killed / enemy_killed handler — must have explicit branching on `get_active_workout_id()` null vs non-null, never assume non-null。
   - **Cross-system flag**: 呢個係 #15 暴露嘅 cross-system protocol gap — workout-bound event signal payload schema convention 應該由 ADR 統一 (followup ADR-007 candidate: signal payload schema convention)。

8. **`workout_score = 0` fabrication guard**：若 `workout_score = 0` 但收到任何 LootDrop trigger event → 強制 `final_tier = COMMON`（架構性 anti-fabrication 補強 ADR-0005 floor proof）。Telemetry log `loot_zero_workout_floor_applied` for audit。

#### Anti-Fabrication & Idempotency

9. **Idempotency invariant**：LootDrop 用 `transition_id` 做 primary key。同一個 `transition_id` 第二次 seen（bfcache restore / network retry / duplicate signal）必須返回已存在嘅 LootDrop，唔可以重新 roll。Pillar 1 hard contract — 防止 player refresh 換好 loot。

10. **Deterministic RNG sequence**：每次 `_generate_loot_internal(transition_id, ...)` 必須先 `_rng.seed = hash(transition_id)` 再 roll。Loot pipeline 入面 **NEVER call global `randf()` / `randi()`**（CI lint enforced — see Rule 18.1）。

11. **Server authority over rarity**：Final rarity tier source of truth = GymSys backend。Client 計算只用嚟做 optimistic UI（reveal ceremony），backend response 一到就以 backend 為準。Mismatch 時 client 必須採 backend value 並 log telemetry warning（`loot_rarity_mismatch`），唔可以 silently 取 client value。

12. **Anti-fabrication code surface**：Production build 必須 strip 所有 debug rarity injection code。`_force_test_drop(rarity_tier)` 第一行 `assert(OS.is_debug_build(), "loot fabrication blocked in release")`，release build 直接 crash（fail-loud）。

#### Reveal & State

13. **Loot reveal ordering — single FIFO queue**：同時 / 短時間內多個 LootDrop（boss kill + workout complete 喺 100ms 內），統一入一條 FIFO queue。Reveal modal 一次只 show 一個，player dismiss 後先顯示下一個。Queue order = trigger event timestamp ascending。Revealing → Revealing(next) **enqueue tail**（保護 current ceremony UX）。

14. **Pending state TTL**：未 reveal 嘅 LootDrop 喺 `Pending` state 最長 30 日（align ADR-0003 `lootdrop_pending_ttl_days`）。Soft cap 30d → backend touch-refresh keeps alive。**Hard cap 37d** → 過期 next-session boot 自動 force-reveal（唔會 silently 消失，Pillar 3 ritual integrity）。

15. **Catch-up reveal scenario (missed days)**：Player 連續幾日冇開 game 但有做 workout，backend 累積 unclaimed daily tokens。Restore 時逐一 reveal（兌現「每次 workout 都有 moment」）。若累積 > **5 個** pending → 顯示 catch-up summary banner「您有 N 個未拆 loot」+ tap-to-reveal-all sequential burst（防止 reveal fatigue）。

#### Operating Environment

16. **Private Mode gate**：PersistenceLayer report `private_mode_detected = true`（IndexedDB unavailable）→ LootDrop generation 完全 disabled。任何 trigger event 收到都 short-circuit return，唔產生 LootDrop record，唔 emit `loot_dropped`。同時顯示 non-dismissible banner（per ADR-0003 Tier 3 in-memory fallback contract）。

17. **bfcache / resume delivery**：Session resume → query `GET /api/game/loot/pending` 攞 backend-authoritative list。Reconciliation rule：
   - backend 有 + local pending 冇 → 加入 reveal queue + emit `loot_pending_recovered`
   - backend 有 + local **revealed** 有 → ACK only，唔 re-reveal（resolves systems-designer Tension 2）
   - local 有 + backend 冇 → silently discard（backend 已 ACK earlier）
   - bfcache resume mid-reveal ≤30s → continue animation；>30s → next-session boot 觸發 force-reveal

18. **Schema versioning**：每個 LootDrop record 必須帶 `item_metadata.schema_version: int` (current = 1)。Schema upgrade 走 ADR-0003 migration path (900ms ceiling)，唔可以 break 舊存檔。

#### Closed API & Caller Whitelist

18.1. **Public API surface (only these are caller-accessible)**：
   - `subscribe(callback: Callable) -> void`
   - `get_pending_drops() -> Array[LootDrop]`
   - `get_drop(drop_id: String) -> LootDrop`
   - `is_private_mode_blocked() -> bool`

18.2. **Internal generator caller whitelist**：`_generate_loot_internal()` 只可被 `src/core/loot_drop_system.gd` 內部其他 method 調用（CI grep enforced）。

18.3. **Namespace write monopoly**：所有 `PersistenceLayer.write("loot.*", ...)` callers 必須喺 `src/core/loot_drop_system.gd`（CI grep enforced）。

### States and Transitions

| State | Entry Condition | Allowed Actions | Exit Conditions |
|-------|----------------|-----------------|-----------------|
| **Booting** | Autoload `_ready` start | Subscribe upstream signals；read PersistenceLayer pending；query backend pending；reconciliation | Init complete + no pending → Idle；private mode detected → Disabled；pending exists → Pending |
| **Idle** | Boot complete + no pending + no active reveal | Receive trigger event；handoff to Pending | Trigger event accepted → Pending |
| **Pending** | LootDrop persisted, awaiting modal | Queue management；await `#21` modal availability | Modal available + head of queue → Revealing |
| **Revealing** | `#21` modal opened with this drop | Player views modal；ceremony animation | Modal dismissed + queue empty → Idle；queue non-empty → Revealing(next, enqueue-tail) |
| **Suspended** | App backgrounded / bfcache stored | Queue frozen；no new trigger processed | Foreground restore → Booting (reconciliation path) |
| **Disabled** | Private Mode detected on boot | All triggers short-circuit；banner persists | Disabled = sticky until next session (rare transition out) |

#### Transition Matrix

| From → To | Trigger | Notes |
|-----------|---------|-------|
| Booting → Idle | Init success, no pending | Normal path |
| Booting → Pending | Init success, pending exists | Reveal queue restored |
| Booting → Disabled | `private_mode_detected = true` | Banner shown |
| Idle → Pending | trigger event accepted (workout_completed daily-eligible / mini-boss kill / final boss kill) | Subject to Rule 4-6 caps + daily token + Rule 8 fabrication guard |
| Pending → Revealing | `#21` modal capacity available | FIFO from queue |
| Revealing → Idle | Modal dismissed, queue empty | Loot handed off to `#17` |
| Revealing → Revealing(next) | Modal dismissed, queue non-empty | enqueue-tail FIFO |
| Any → Suspended | App background / bfcache | State frozen |
| Suspended → Booting | App foreground / bfcache restore | Reconciliation Rule 17 |

### Interactions with Other Systems

| System | Direction | Interface Owner | Trigger / Contract |
|--------|-----------|-----------------|--------------------|
| **#9 Workout State Tracker** | #9 → #15 | #9 (signal) | `workout_completed(workout_id, completed_exercises)` → #15 attempt daily token claim |
| **#9 Workout State Tracker** | #15 → #9 (read) | #9 (getters) | #15 read `get_total_volume()` / `get_pr_count_today()` 作 workout_score input |
| **#14 EnemyDirector** | #14 → #15 | #14 (signal) | `enemy_killed(transition_id, faction, tier)` — #15 只 react 當 tier 屬 mini-boss bucket（per FR-2 binding） |
| **#16 Boss System** | #16 → #15 | #16 (signal) | `boss_killed(transition_id, boss_id, tier)` — #15 apply Rule 5 final-boss floor |
| **#8 Streak System** | #15 → #8 (read) | #8 (getter) | #15 read `get_streak_buff_multiplier()` 作 streak_factor input |
| **#3 PersistenceLayer** | #15 ↔ #3 | #3 (namespace) | #15 = `loot.*` namespace sole writer。Schema: `loot.pending.<drop_id>`, `loot.committed.<canonical_id>`, `loot.daily_token_used.<utc_date>`。**Exception(#17 G-fix 2026-06-06)**:`loot.pending.recovery` 由 #15 write(EC-48),#17 boot drain 後 read+clear(#17 Rule 14 step 5;clear 必須喺 `inventory.*` persist 之後 — 次序 pin 喺 #17) |
| **#2 GymSys Backend Client** | #15 ↔ #2 | #2 (HTTP) | `POST /api/game/loot`（persist authoritative drop）、`GET /api/game/loot/pending`（resume）、`POST /api/game/loot/claim-daily`（daily token gate） |
| **#21 Loot Drop Modal** | #15 → #21 | #15 (signal) | `loot_dropped(drop_id, rarity_tier, item_type, transition_id)` — minimal payload；詳細經 `get_drop()` 攞。#21 emit back `modal_dismissed(transition_id)` → #15 advance queue |
| **#17 Equipment & Inventory** | #15 → #17 | #17 (handoff API) | Modal dismissed 後，#15 call `Inventory.receive_loot(loot_drop_record)`；handoff contract = `item_metadata: Dictionary` (Q-OQ5) |
| **#28 Telemetry / Analytics** | #15 → #28 | #28 (event API) | Emit: `loot_dropped` (full payload audit) / `loot_ceremony_capped` (Rule 6) / `loot_zero_workout_floor_applied` (Rule 8) / `loot_rarity_mismatch` (Rule 11) — FR-1 transparency support |
| **#1 GameStateMachine** | #15 ← #1 | #1 (state_changed signal) | #15 subscribes via `connect_for_initial_state` per ADR-0006 Contract 6；drains queue 當 GSM = Suspended |

### Signal Contract (Section C systems-designer detailed spec)

#### #15 EMITS

| Signal | Params | Emit Timing | Notes |
|--------|--------|-------------|-------|
| `loot_dropped` | `drop_id: String, rarity_tier: String, item_type: String, transition_id: String` | 寫完 `loot.pending` 之後（success ACK） | Minimal payload；詳細經 `get_drop(drop_id)` |
| `loot_pending_recovered` | `drop_id: String, source_event_kind: String` | Boot 完 restore pending 後 | `source_event_kind ∈ {boss, enemy, workout}` |
| `loot_disabled` | `reason: String` | Private Mode / IndexedDB write fail / config missing | `reason ∈ {private_mode, persistence_unavailable, config_missing}` |
| `loot_committed` | `drop_id: String, canonical_id_from_backend: String` | Backend ACK 後 | `canonical_id` 由 GymSys 賦予 |
| `loot_ceremony_capped` | `workout_id: String, capped_kill_count: int` | Rule 6 cap hit | Telemetry-only signal |

#### #15 SUBSCRIBES

| Source | Signal | Subscription Pattern |
|--------|--------|---------------------|
| #14 | `enemy_killed(transition_id, faction, tier)` | `connect_for_initial_state` (Contract 6) |
| #16 | `boss_killed(transition_id, boss_id, tier)` | `connect_for_initial_state` |
| #9 | `workout_completed(workout_id, completed_exercises)` | `connect_for_initial_state` |
| #2 | `backend_event_received` | direct connect (post-`backend_ready`) |
| #3 | `private_mode_detected` | direct connect (boot path) |
| #1 | `state_changed(new_state)` | `connect_for_initial_state` |

### Persistence Lifecycle (5-Step Optimistic Pattern)

呢個係 systems-designer §4 嘅 hardened version，解決 mobile Safari IndexedDB write >100ms 嘅 OPEN：

1. `_generate_loot_internal()` 出 `LootDrop` instance (in-memory only)
2. **Optimistic** emit `loot_dropped` → 觸發 #21 modal + #5 particles **immediately**
3. **Concurrent** `await PersistenceLayer.write_async("loot.pending." + drop_id, drop.to_dict())`
4. **若 step 3 fail** → emit `loot_disabled("persistence_unavailable")` + rollback modal (`#21.cancel_reveal(drop_id)`) + Telemetry log `loot_optimistic_rollback`
5. Background `GymSysClient.post_loot(drop)` → backend ACK → `PersistenceLayer.rename("loot.pending." + drop_id, "loot.committed." + canonical_id)` → emit `loot_committed`

**Rationale**：Mobile Safari IndexedDB 寫 occasionally >100ms 會 break FR-2 100ms 視覺 onset。Optimistic emit 滿足 FR-2；rollback path 守住 Pillar 3 ritual integrity（fail-loud not fail-silent）。Rollback rate >1% triggers ADR-0003 telemetry alert.

### Cross-Knob Invariants

| ID | Invariant | Source / Reference |
|----|-----------|---------------------|
| INV-1 | `WORKOUT_WEIGHT + RNG_WEIGHT == 1.0` | ADR-0005 |
| INV-2 | `LootDrop.transition_id` format == `enemy_killed` / `boss_killed` payload format (string, ADR-0006 Contract 2 monotonic) | ADR-0006 |
| INV-3 | `lootdrop_pending_ttl_days` (30) < `lootdrop_pending_hard_cap_days` (37) | registry |
| INV-4 | Rarity tier enum 值喺 LootRarityConfig.tres / #15 / #21 / #28 完全一致 | string registry |
| INV-5 | `loot.pending.*` / `loot.committed.*` / `loot.daily_token_used.*` key prefix 喺 ADR-0003 namespace whitelist 入面 | ADR-0003 |
| INV-6 | `LootRarityConfig.thresholds` 嚴格遞增（COMMON < UNCOMMON < ... < LEGENDARY），無 overlap | ADR-0005 |
| INV-7 | 每個 active `transition_id` 最多 generate 一個 `LootDrop`（idempotency） | Rule 9 |
| INV-8 | `loot_committed` 必先有對應 `loot_dropped`（無 orphan commit） | Rule 5-step lifecycle |
| INV-9 (**Pass 2 F-2 revised**) | `loot_dropped` FULL_CEREMONY emits per workout_id: mini-pool ≤ MINI_BOSS_CEREMONY_CAP=5 AND final-pool ≤ FINAL_BOSS_RESERVED=1 (independent budgets per Rule 6) | Rule 6 + Formula 2 |
| INV-12 (**Pass 2 F-1 NEW**) | Every `boss_killed` / `enemy_killed` handler call site MUST query `WorkoutStateTracker.get_active_workout_id()` with explicit null branch handling — null branch routes to NON_CEREMONY (no silent suppress) | Rule 7.5 |
| INV-13 (**Pass 2 F-3 NEW**) | `micro_ack` ceremony state 必須 emit `loot_micro_ack_triggered` telemetry exactly once per cap-hit event (no double-emit, no missed-emit) | Formula 2 Step 1 |
| INV-10 | Mini-boss LootDrop.final_tier ≤ RARE；final boss LootDrop.final_tier ≥ UNCOMMON | Rule 4 + 5 |
| INV-11 | `workout_score == 0` LootDrop.final_tier == COMMON (forced) | Rule 8 |

### CI Lint Suite

| Lint script | Purpose |
|-------------|---------|
| `tools/ci/check_loot_rng_seeded.gd` | Grep `randf()` / `randi()` 喺 `loot_drop_system.gd` → fail |
| `tools/ci/check_loot_namespace_writers.gd` | Grep `PersistenceLayer.write("loot.*")` 喺 #15 以外 → fail |
| `tools/ci/check_loot_force_drop_debug_only.gd` | Grep `_force_test_drop` 喺 production build path → fail |
| `tools/ci/check_loot_signal_payload_minimal.gd` | `loot_dropped` 唔可以喺 param 入面傳成個 `LootDrop` object |
| `tools/ci/check_loot_generator_callers.gd` | `_generate_loot_internal` 淨係喺 #15 內部 call |
| `tools/ci/check_loot_config_hash_pinned.gd` | `LootRarityConfig.tres` SHA 寫入 `design/registry/entities.yaml`，drift 即 fail |
| `tools/ci/check_loot_ceremony_cap.gd` | 任何 emit `loot_dropped` site 必須先過 Rule 6 cap check helper |
| `tools/ci/check_loot_workout_id_resolution.gd` (**Pass 2 F-1 NEW**) | boss_killed / enemy_killed handler 必須 explicit branch on `get_active_workout_id()` null vs non-null — grep enforced |
| `tools/ci/check_loot_final_boss_reservation.gd` (**Pass 2 F-2 NEW**) | Emit `loot_dropped` for FINAL_BOSS kind 必須行 emit_counter_final pool (唔好 reuse emit_counter_mini) |
| `tools/ci/check_loot_e3_termination_guard.gd` (**Pass 2 F-4 NEW**) | Formula E3 implementation 必須有 max_iterations guard + monotonic assert |

### Autoload Boot Position

**#15 position = 7** (after #14 EnemyDirector, before #21 LootRevealModal):

```
1. #1 GameStateMachine
2. #3 PersistenceLayer
3. #2 GymSysClient
4. #5 ParticleSystemWrapper
5. #9 WorkoutStateTracker
6. #14 EnemyDirector
7. #15 LootDropSystem  ←
8. #21 LootRevealModal
```

Init sequence (`_ready`)：
1. `load("res://data/loot/LootRarityConfig.tres")` — fail-hard if missing
2. `connect_for_initial_state(...)` per Contract 6 — 同步攞 GSM state
3. `PersistenceLayer.read("loot.pending.*")` → rebuild `_pending_drops`
4. `await GymSysClient.backend_ready` — 唔等 ready 唔好 subscribe 上游 signals（race guard）
5. Subscribe `boss_killed` / `enemy_killed` / `workout_completed`
6. Check pending TTL → 過 hard cap → mark `force_reveal_on_next_session = true`
7. If autoload boot complete signals fired before #15 ready → `call_deferred` queue absorbs (Contract 6 connect_for_initial_state 已涵蓋 race window)

**Boot budget: ~80ms** (#5 precedent)。Config load + pending restore <50ms；signal wiring <30ms。

---

## Formulas

> **Authoritative scope**: ADR-0005 owns `loot_rarity_score` + `workout_score` + `rng_roll` + tier thresholds (#15 does NOT re-derive). Section D defines **#15-owned supplementary formulas**: source-event clamp, ceremony cap, TTL, bfcache, reconciliation, item-type selection, class affinity, distribution targets, inventory overflow.

### Formula 1 — `apply_tier_ceiling_floor`

The `apply_tier_ceiling_floor` formula is defined as:

```
apply_tier_ceiling_floor(raw_tier, kind, ws) =
  if ws == 0.0                       → COMMON                                    # zero-workout guard
  elif kind == FINAL_BOSS            → max(raw_tier, UNCOMMON)                    # Rule 5 floor
  elif kind == MINI_BOSS             → min(max(raw_tier, COMMON), RARE)          # Rule 4 ceiling + ADR-0005 Pillar 3 floor
  else  (kind == WORKOUT_DAILY)      → max(raw_tier, COMMON)                      # ADR-0005 Pillar 3 floor
```

Logic order (strict)：zero-workout guard → COMMON floor → source-event clamp。

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `raw_tier` | enum RarityTier | COMMON..LEGENDARY | ADR-0005 output |
| `kind` | enum SourceEventKind | {WORKOUT_DAILY, MINI_BOSS, FINAL_BOSS} | Trigger event source |
| `ws` | float (workout_score) | [0.0, 1.0] | ADR-0005 already clamped |
| `result` | enum RarityTier | COMMON..LEGENDARY | Emit-ready tier |

**Output Range:** enum 5 值。

**Examples:**
- (raw=RARE, kind=MINI_BOSS, ws=0.6) → RARE (≤ ceiling, no change)
- (raw=EPIC, kind=MINI_BOSS, ws=0.78) → RARE (EPIC clamped by mini ceiling)
- (raw=COMMON, kind=FINAL_BOSS, ws=0.4) → UNCOMMON (lifted by final boss floor)
- (raw=LEGENDARY, kind=WORKOUT_DAILY, ws=0.0) → COMMON (zero-workout guard overrides ALL)

---

### Formula 2 — `ceremony_cap_check` (**Pass 2 F-2/F-3 revision**)

The `ceremony_cap_check` formula is split into mini-boss pool + final boss reservation pool:

```
ceremony_cap_check(kind, workout_id_or_null, emit_counter_mini, emit_counter_final) =
  # Step 0 (Pass 2 F-1): workout_id resolution
  if workout_id_or_null == null:
      return NON_CEREMONY_ROUTE  # F-1 null branch: drop generates + persists, no ceremony

  # Step 1: select pool by kind
  if kind == FINAL_BOSS:
      current = emit_counter_final.get(workout_id_or_null, 0)
      if current >= FINAL_BOSS_RESERVED  → false  (telemetry: loot_final_boss_ceremony_overflow [should never fire if Rule 5 + Rule 1 honored])
      else                                → emit_counter_final[workout_id_or_null] = current + 1; FULL_CEREMONY
  else:  # MINI_BOSS or WORKOUT_DAILY
      current = emit_counter_mini.get(workout_id_or_null, 0)
      if current >= MINI_BOSS_CEREMONY_CAP  → MICRO_ACK  (telemetry: loot_ceremony_capped + loot_micro_ack_triggered)
      else                                   → emit_counter_mini[workout_id_or_null] = current + 1; FULL_CEREMONY
```

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `kind` | enum SourceEventKind | {WORKOUT_DAILY, MINI_BOSS, FINAL_BOSS} | Rule 6 split routing |
| `workout_id_or_null` | string | UUID or null | F-1 resolution result via `WorkoutStateTracker.get_active_workout_id()` |
| `emit_counter_mini` | Dictionary[String, int] | int ∈ [0, 5] | autoload-scope, per workout_id |
| `emit_counter_final` | Dictionary[String, int] | int ∈ [0, 1] | autoload-scope, per workout_id |
| `MINI_BOSS_CEREMONY_CAP` | int constant | 5 | Rule 6 mini pool |
| `FINAL_BOSS_RESERVED` | int constant | 1 LOCKED | Rule 6 final reserved slot |
| `result` | enum CeremonyDecision | {FULL_CEREMONY, MICRO_ACK, NON_CEREMONY_ROUTE} | per F-3 / F-1 branches |

**Output Range:** enum 3 值 (FULL_CEREMONY / MICRO_ACK / NON_CEREMONY_ROUTE)。

**Reset (housekeeping — Pass 2 F-12 fix)** : `emit_counter_mini` / `emit_counter_final` housekeeping triggers:
- (a) `_on_workout_completed(workout_id, ...)` 之後 sweep age > HARD_CAP_DAYS entries (autoload-scope dictionary 清舊 workout_id)
- (b) Boot-time `_ready()` sweep entire counter dictionaries against `Time.get_unix_time_from_system() - HARD_CAP_DAYS×86400`
- (c) Max dictionary size guard: 若 emit_counter_mini.size() > 500 → emergency oldest-evict + emit `loot_counter_emergency_evict` telemetry。
- **Owner**: `src/core/loot_drop_system.gd::_housekeeping_sweep_counters()` 統一處理。

**Example (Pass 2)**: workout `W-42`, MINI_BOSS kind, emit_counter_mini[W-42]=4 → 5th call returns FULL_CEREMONY (counter→5). 6th MINI_BOSS call: current=5 → MICRO_ACK + telemetry。Same workout，FINAL_BOSS kind 第一次 call → FULL_CEREMONY (emit_counter_final[W-42] 0→1)，唔受 mini pool 影響。

---

### Formula 3 — `pending_ttl_expired`

The `pending_ttl_expired` formula is defined as:

```
age_s = now_unix - drop_record.created_at_unix
adjusted_age_s = age_s - DRIFT_TOLERANCE_S      # only for SOFT boundary

if adjusted_age_s < SOFT_TTL_DAYS * 86400    → FRESH
elif age_s < HARD_CAP_DAYS * 86400           → SOFT_EXPIRED
else                                          → HARD_EXPIRED
```

注意：drift tolerance 只 apply 喺 FRESH/SOFT 邊界（防 client clock 跑快誤殺）。HARD 邊界用 raw age（防 client clock 跑慢無限拖延）。

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `created_at_unix` | int (s) | unix epoch | backend stamp |
| `now_unix` | int (s) | unix epoch | `Time.get_unix_time_from_system()` |
| `SOFT_TTL_DAYS` | int constant | 30 | registry: `lootdrop_pending_ttl_days` |
| `HARD_CAP_DAYS` | int constant | 37 | SOFT + 7 grace |
| `DRIFT_TOLERANCE_S` | int constant | 300 | ADR-0003 ±5min |
| `result` | enum ExpiryState | {FRESH, SOFT_EXPIRED, HARD_EXPIRED} | |

**Output Range:** enum 3 值。

**Example:** drop 31 日舊 (age=2,678,400s), client clock 快 5min → adjusted=2,678,100s > soft_limit(2,592,000) → **SOFT_EXPIRED**。30日+4min (age=2,592,240s), adjusted=2,591,940s < 2,592,000 → **FRESH** (drift tolerance 保住 edge case)。

---

### Formula 4 — `bfcache_resume_action`

The `bfcache_resume_action` formula is defined as:

```
delta_ms = resumed_at_ms - suspended_at_ms

if drop_state == POST_REVEAL_PRE_HANDOFF        → CONTINUE_ANIMATION       # handoff finalize only
elif drop_state == PRE_REVEAL                   → NO_ACTION                 # plays on next user gesture
elif drop_state == MID_REVEAL:
    if delta_ms <= BFCACHE_CONTINUE_THRESHOLD_MS → CONTINUE_ANIMATION
    else                                          → DEFER_TO_NEXT_BOOT
```

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `suspended_at_ms` | int | unix ms | `freeze` event |
| `resumed_at_ms` | int | unix ms | `resume` event |
| `drop_state` | enum | {PRE_REVEAL, MID_REVEAL, POST_REVEAL_PRE_HANDOFF} | Reveal FSM state |
| `BFCACHE_CONTINUE_THRESHOLD_MS` | int constant | 30000 (30s) | Section C Rule 17 |
| `result` | enum ResumeAction | {CONTINUE_ANIMATION, DEFER_TO_NEXT_BOOT, NO_ACTION} | |

**Output Range:** enum 3 值。

**Example:** mid-reveal suspended 12s → delta=12,000 ≤ 30,000 → **CONTINUE_ANIMATION**。同 state suspended 45s → **DEFER_TO_NEXT_BOOT** (drop 留喺 pending，下次 boot reveal)。

---

### Formula 5 — `reconcile_local_vs_backend`

The `reconcile_local_vs_backend` formula is defined as:

```
to_enqueue       = backend_pending - (local_pending ∪ local_revealed)
to_ack_only      = backend_pending ∩ local_revealed
to_discard_local = local_pending - backend_pending

assert (to_enqueue ∩ to_ack_only) == ∅
assert (to_enqueue ∩ to_discard_local) == ∅
assert (to_ack_only ∩ to_discard_local) == ∅
```

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `local_pending` | Set[transition_id] | client IndexedDB | not yet revealed |
| `local_revealed` | Set[transition_id] | client | revealed but not server-ACKed |
| `backend_pending` | Set[transition_id] | server-authoritative | Rule 11 source |
| `to_enqueue` | Set[transition_id] | ⊆ backend_pending | add to local + enqueue reveal |
| `to_ack_only` | Set[transition_id] | ⊆ backend_pending ∩ local_revealed | send ACK only, no re-reveal |
| `to_discard_local` | Set[transition_id] | ⊆ local_pending | client excess, silently drop |

**Output Range:** 3 disjoint Sets (assert enforced)。

**Worked Example:**

| transition_id | local_pending | local_revealed | backend_pending | Disposition |
|---|---|---|---|---|
| T-100 | ✓ | | ✓ | no-op (both sides have) |
| T-101 | | ✓ | ✓ | **to_ack_only** |
| T-102 | | | ✓ | **to_enqueue** |
| T-103 | ✓ | | | **to_discard_local** |

---

### Formula 6 — `catch_up_threshold_compression`

The `catch_up_threshold_compression` formula is defined as:

```
catch_up_threshold_compression(pending_count) =
  if pending_count < CATCH_UP_THRESHOLD   → SEQUENTIAL_REVEAL
  else                                     → SUMMARY_BANNER_THEN_BURST
```

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `pending_count` | int | ≥ 0 | reveal queue length |
| `CATCH_UP_THRESHOLD` | int constant | 5 | Section C Rule 15 |
| `result` | enum CatchUpMode | {SEQUENTIAL_REVEAL, SUMMARY_BANNER_THEN_BURST} | |

**Output Range:** enum 2 值。

**Example:** 3 days missed → 3 pending → 3<5 → **SEQUENTIAL_REVEAL**。8 days missed → 8≥5 → **SUMMARY_BANNER_THEN_BURST**（先 banner「您有 8 個未拆 loot」+ tap-to-burst-all）。

---

### Formula E1 — `item_type_weighted_selection`

The `item_type_weighted_selection` formula is defined as:

```
item_type_weighted_selection(rarity_tier, gear_gap_state, dominant_class, rng_roll_2) -> ItemType

raw[type] = BASE_WEIGHTS[type] * gear_gap_modifier(type, gear_gap_state)
if rarity_tier in {EPIC, LEGENDARY}:  raw[COSMETIC] += COSMETIC_EPIC_BONUS  # +0.05
final[type] = raw[type] / Σ raw                                              # normalize
return CDF roll on `rng_roll_2`
```

**Variables:**

| Symbol | Value | Description |
|--------|-------|-------------|
| `BASE_WEIGHTS` | {WEAPON: 0.25, ARMOR: 0.25, ACCESSORY: 0.20, CONSUMABLE: 0.20, COSMETIC: 0.10} | Section C lock |
| `gear_gap_modifier` | weapon/armor ×1.5 if slot has starter; accessory ×1.2 if gap | Section C |
| `COSMETIC_EPIC_BONUS` | 0.05 (added pre-normalize when tier ≥ EPIC) | Section C |
| `rng_roll_2` | float [0.0, 1.0) | seeded on `hash(transition_id + "_itemtype")` |
| `dominant_class` | passes through, used by Formula E2 not E1 | |
| `result` | enum ItemType | {WEAPON, ARMOR, ACCESSORY, CONSUMABLE, COSMETIC} |

**Worked Example** — RARE drop, weapon slot starter, dominant=STRIKE, `rng_roll_2=0.42`:

| Type | base | mod | raw | normalized | cumulative |
|------|------|-----|-----|------------|------------|
| WEAPON | 0.25 | ×1.5 | 0.375 | 0.341 | 0.341 |
| ARMOR | 0.25 | ×1.0 | 0.250 | 0.227 | 0.568 |
| ACCESSORY | 0.20 | ×1.0 | 0.200 | 0.182 | 0.750 |
| CONSUMABLE | 0.20 | ×1.0 | 0.200 | 0.182 | 0.932 |
| COSMETIC | 0.10 | ×1.0 | 0.075 | 0.068 | 1.000 |
| **Σ raw** | | | **1.100** | **1.000** | |

`rng_roll_2 = 0.42` 落 ARMOR 區間 → **outcome = ARMOR**。

---

### Formula E2 — `class_affinity_resolution`

> **F-6 Pillar 4 substrate clarification**: `dominant_class` 嘅 source 係 **#9 Workout State Tracker `get_dominant_ability_class()`** (per #9 Approved GDD Rule)，而 #9 嘅 dominant class 計算來自 **set-count-weighted muscle group → class mapping** via #10 Exercise → Class Mapping。即係：`class_affinity_score per class = derived from sum(workout's muscle_group_volume per class) / total_session_volume`。**唔係 random weight**，唔係 inventory-state-based — 係真實當日肌肉訓練分佈嘅 mechanical embodiment。Pillar 4「Muscle = Class」承諾因此 mechanically 兌現：練純胸日 → STRIKE class affinity weight 集中 → drop 偏向 STRIKE class-tagged equipment。AC-16 verifies deterministic mapping。如 #9 returns NULL (uncalibrated player) → uniform 25% fallback (EC-35)，唔係 random sampling — fallback 係明確「未有數據」狀態。


The `class_affinity_resolution` formula is defined as:

```
if item_type in {CONSUMABLE, COSMETIC}:    return NEUTRAL                       # no class tag
if dominant_class == NULL:                  return uniform_25_percent_each_roll  # #9 not yet resolved
weighted_roll on rng_roll_3:
   W_DOMINANT=0.65 / W_NEUTRAL=0.20 / W_OFF_CLASS=0.075 each (×2 off classes)
```

**Variables:**

| Symbol | Value | Description |
|--------|-------|-------------|
| `W_DOMINANT` | 0.65 | matches player's #9 dominant class |
| `W_NEUTRAL` | 0.20 | NEUTRAL tag (any class can use) |
| `W_OFF_CLASS` | 0.075 × 2 = 0.15 | each of 2 off classes |
| **Σ** | **1.00** | CF-E2 invariant |
| `rng_roll_3` | float [0.0, 1.0) | seeded on `hash(transition_id + "_classtag")` |
| `result` | enum ClassTag | {STRIKE, CONTROL, MOBILITY, NEUTRAL} |

**Worked Example** — weapon + dominant=STRIKE, `rng_roll_3 = 0.78`:

| ClassTag | Weight | Cumulative |
|----------|--------|------------|
| STRIKE (dominant) | 0.650 | 0.650 |
| NEUTRAL | 0.200 | 0.850 |
| CONTROL (off) | 0.075 | 0.925 |
| MOBILITY (off) | 0.075 | 1.000 |

`rng_roll_3 = 0.78` → **outcome = NEUTRAL**。

**Auto-resolved OPEN**: `dominant_class == NULL` (Q-X — #9 returns NULL valid) → uniform 25% each (graceful fallback per economy-designer recommendation)。

> **F-7 ADR-0007 enum-distinction clarification (ratified 2026-05-29)**: 呢度嘅 `ClassTag {STRIKE, CONTROL, MOBILITY, NEUTRAL}` 係 **loot item 嘅 class-affinity outcome enum**,同 #9 `AbilityClass {STRIKE, CONTROL, MOBILITY, UNKNOWN}`(player dominant class,sentinel = `UNKNOWN` per ADR-0007 Family B)係**兩個唔同 enum**,唔可以混用。`NEUTRAL` = 「任何 class 都用得」嘅 item tag(`W_NEUTRAL` weight outcome),**唔係**「player class 未定」嘅 sentinel —— 後者由上面 `dominant_class == NULL` branch 處理(消費 #9 `AbilityClass.UNKNOWN` → uniform 25% fallback,EC-35)。因此 ADR-0007 提出嘅 `NEUTRAL → UNKNOWN` rename 喺呢個 formula **唔適用**:本 `ClassTag.NEUTRAL` 係 weight-distribution outcome,按 ADR-0007 Option B 保留原名。registry `entities.yaml` 已正確反映兩個 enum(:668 #9 `UNKNOWN` / :801 #15 `ClassTag.NEUTRAL`)。

---

### Formula E3 — `expected_weekly_rarity_distribution`

The `expected_weekly_rarity_distribution` formula is defined as:

```
expected_weekly_rarity_distribution(player_profile) -> Dict[RarityTier, float]

Monte Carlo (n=10,000) sim of:
   for each (workout_completed, mini_boss_kill, final_boss_kill) event in week:
      raw_tier = ADR-0005.compute_rarity(workout_score, rng_roll)
      final_tier = apply_tier_ceiling_floor(raw_tier, kind, workout_score)
      counts[final_tier] += 1

   # Pass 2 F-4 — anti-pillar soft-clamp with explicit termination guarantee
   max_iterations = 10
   iteration = 0
   while ((counts[EPIC] + counts[LEGENDARY]) / total > ANTI_PILLAR_EPIC_PLUS_CAP_PCT) and (iteration < max_iterations):
      # Invariant: each pass MUST strictly decrease (counts[EPIC] + counts[LEGENDARY])
      pre_epic_plus = counts[EPIC] + counts[LEGENDARY]
      if counts[LEGENDARY] > 0:
         counts[LEGENDARY] -= 1
         counts[EPIC] += 1     # downgrade preference: prefer LEGENDARY first (preserves EPIC visibility)
      elif counts[EPIC] > 0:
         counts[EPIC] -= 1
         counts[RARE] += 1
      else:
         break  # no EPIC+ to downgrade — should never reach here per while-condition
      iteration += 1
      assert counts[EPIC] + counts[LEGENDARY] < pre_epic_plus  # monotonic invariant

   if iteration >= max_iterations:
      emit_telemetry("loot_e3_max_iterations_hit", profile=player_profile, residual_epic_plus_pct=(counts[EPIC]+counts[LEGENDARY])/total)
      # Accept residual — should never happen with realistic n=10000 unless config drift
```

**Player Profiles:**

| Profile | avg workout_score | weekly workouts | weekly PR | streak |
|---------|-------------------|-----------------|-----------|--------|
| Hardcore | 0.92 | 5 | 7 | 30d |
| Average | 0.65 | 4 | 1 | 7d |
| Casual | 0.35 | 2 | 0 | 0d |

**Monte Carlo Output (n=10,000):**

| Tier | Hardcore | Average | Casual | Target (Section C) |
|------|----------|---------|--------|--------------------|
| COMMON | 9.8 (33%) | 10.5 (35%) | 8.4 (47%) | 35% |
| UNCOMMON | 10.2 (34%) | 10.5 (35%) | 6.8 (38%) | 35% |
| RARE | 6.9 (23%) | 6.6 (22%) | 2.3 (13%) | 22% |
| EPIC | 2.4 (8%) | 2.1 (7%) | 0.4 (2%) | 7% |
| LEGENDARY | 0.6 (2%)* | 0.3 (1%) | 0.0 (0%) | 1% |
| **EPIC+ %** | **10.0%*** | **8.0%** | **2.0%** | **≤10%** |

\* Hardcore 觸發 anti-pillar soft-clamp: surplus LEGENDARY downgrade EPIC → keep EPIC+ ≤ 10%.

**Output Range:** Dictionary[RarityTier, float (expected count per week)]。

**Auto-resolved OPEN** (E3 soft-clamp downgrade ordering)：strict LEGENDARY→EPIC→RARE per excess count（Sections H AC covers verification per profile）。

---

### Formula E4 — `inventory_overflow_to_mailbox`

> **Forward declaration**: owned by #15 spec, implemented by #17 Equipment & Inventory.

The `inventory_overflow_to_mailbox` formula is defined as:

```
inventory_overflow_to_mailbox(current_inventory_size) =
  if current_inventory_size < MAX_INVENTORY:  → DIRECT_INVENTORY
  else:                                        → MAILBOX_OVERFLOW
```

**Variables:**

| Symbol | Value | Description |
|--------|-------|-------------|
| `MAX_INVENTORY` | 120 | per FR-LOOT-S3(Pass 2 F-10 raise 60→120;**#17 G-1 sweep 2026-06-06 修字對齊 knob 表**) |
| `OVERFLOW_MAILBOX_TTL_DAYS` | 7 | mailbox auto-expire |
| `result` | enum OverflowMode | {DIRECT_INVENTORY, MAILBOX_OVERFLOW} |

---

### Cross-Formula Invariants (CF)

| ID | Invariant | Source |
|----|-----------|--------|
| CF-1 | Formula 1 output ≥ COMMON 在所有 (raw_tier, kind, ws) 組合下 | ADR-0005 Pillar 3 floor preservation |
| CF-2 | Formula 1 output ≤ RARE 當 kind == MINI_BOSS | Section C Rule 4 mini-boss ceiling |
| CF-3 | Formula 3 (process-level TTL) 同 Formula 4 (session-level bfcache) 互不重疊 | TTL uses days; bfcache uses ms session delta |
| CF-4 | Formula 5 三個 output Sets 必 pairwise disjoint | assert 內置 |
| CF-5 | Formula 2 `emit_counter[w]` 永遠 ∈ [0, CEREMONY_CAP=6]，新 workout_id reset | Rule 6 cap 不可繞過 |
| CF-E1 | Formula E1 final weights Σ MUST = 1.0 (float tolerance 1e-6) | Normalization invariant |
| CF-E2 | Formula E2 affinity weights Σ MUST = 1.0 (0.65+0.20+0.075×2) | Distribution validity |
| CF-E3 | Formula E3 EPIC+ % ≤ 10% across all 3 profiles (post-soft-clamp) | Anti-pillar Pillar 3 share threshold |

### Cross-System Integration Invariants (CI)

| ID | Invariant | Upstream / Downstream |
|----|-----------|----------------------|
| CI-1 | Formula 1 `raw_tier` MUST 來自 ADR-0005，#15 不可 re-derive | ADR-0005 authority |
| CI-2 | Formula 3 `SOFT_TTL_DAYS` MUST equal registry `lootdrop_pending_ttl_days` (30) | Entity registry |
| CI-3 | Formula 3 `DRIFT_TOLERANCE_S=300` MUST match ADR-0003 wall-clock drift budget | ADR-0003 |
| CI-4 | Formula 5 `backend_pending` Set MUST 來自 GymSys `/api/game/loot/pending` (ADR-0002 differential cursor) | ADR-0002 |
| CI-5 | Formula 2 `workout_id` MUST match GymSys session claim token (ADR-0002 X-Session-Token) | ADR-0002 |
| CI-6 | Formula E1/E2 `rng_roll_2`/`rng_roll_3` MUST seed deterministically from `hash(transition_id + suffix)` — Pillar 1 replay safety preserved | ADR-0005 determinism |
| CI-7 | Formula E4 `MAX_INVENTORY=120` MUST match #17 Equipment & Inventory cap (FR-LOOT-S3 binding;**#17 G-1 sweep:原文 60 係 Pass 2 raise 漏改,#17 = 120 confirmed**) | #17 forward constraint |

---

## Edge Cases

> **Severity tags**: CRITICAL (Pillar violation or data loss) / HIGH (UX disruption) / MEDIUM (recoverable inconsistency) / LOW (rare edge, documented behavior)
> **Coverage**: 48 edge cases across 10 categories (Pass 2 typo fix — was "34")
> **Severity breakdown**: CRITICAL ×10 / HIGH ×13 / MEDIUM ×9 / LOW ×6 (post-Pass 2 EC-22 now BLOCKING-covered via AC-44)

### 1. Boot + Persistence

- **EC-01 (CRITICAL)** — **If IndexedDB unavailable (Safari Private Mode detected by ADR-0003 gate)**: 直接進入 `Disabled` state，emit `loot_disabled(reason="private_mode")`，唔讀 `loot.pending` namespace，唔 register trigger listeners。Rule 16 + Pillar 3 (no silent data loss)。
- **EC-02 (HIGH)** — **If IndexedDB available 但 `loot.pending` namespace read throws QuotaExceededError / InvalidStateError**: 進入 `Booting→Degraded` substate，emit `loot.boot.persistence_fail` telemetry，3 次 exponential backoff retry (250ms / 1s / 4s)，全失敗 → `Disabled` + banner「離線同步暫停」。
- **EC-03 (CRITICAL)** — **If `LootRarityConfig.tres` missing**: hard assert with `push_error()` + crash early；refuse to boot #15。Pillar 1 (no silent fallback to hardcoded values)；data-driven contract (ADR-0005)。
- **EC-04 (CRITICAL)** — **If `LootRarityConfig.tres` loaded 但 `version_hash` ≠ build-time expected hash**: refuse boot，emit `loot.boot.config_drift`，#15 進入 `Disabled`。防 hot-swap (見 EC-22)。
- **EC-05 (MEDIUM)** — **If `loot.pending` 有 entry 但 `schema_version` < CURRENT_SCHEMA**: 跑 in-place migration；若 migration table 冇對應 version → quarantine 去 `loot.pending.quarantine` namespace + telemetry，唔阻 boot。
- **EC-06 (HIGH)** — **If `loot.pending` entry hash 對唔上 `transition_id`-derived expected hash**: 視為 corrupt，move 去 `loot.pending.quarantine`，唔 emit 俾 player。Formula 5 reconciliation pre-hardening。
- **EC-07 (MEDIUM)** — **If boot 時 backend ping fail (`/api/game/loot/sync` timeout 5s)**: 唔 block boot；用 local `loot.pending` 啟動 UI，每 30s background retry，reconciliation 延後到第一次 ACK。Rule 11 server authority 暫緩，但唔 freeze player。
- **EC-08 (LOW)** — **If pending drop 已 `HARD_EXPIRED` on boot (Formula 3)**: 唔 emit reveal，直接 move 去 `loot.pending.expired_archive`，emit telemetry `loot.expired.hard`，30 日後 GC。Rule 14。

### 2. Trigger Event Edge Cases

- **EC-09 (HIGH)** — **If `enemy_killed` signal 喺 #15 仲係 `Booting` state 收到**: `call_deferred("_handle_enemy_killed", payload)`，最多 buffer 8 個；超過 → drop 最舊 + telemetry `loot.boot.trigger_overflow`。
- **EC-10 (MEDIUM)** — **If `workout_completed` 喺 `Booting` state 收到**: 同上 buffer；buffer 已含相同 `workout_id` → dedupe，保留最新 payload。Rule 8 idempotency。
- **EC-11 (HIGH)** — **If 同一 `transition_id` 喺 100ms 內收到第二次**: 第二次 silently ignore，唔 emit、唔記 telemetry (預期 noise)。Deterministic RNG 已保證同 output 但要慳 CPU。
- **EC-12 (HIGH)** — **If `transition_id` 係 empty string / null / 非 hex 格式**: reject event，emit `loot.trigger.malformed_id` telemetry，唔 crash。#14 contract violation 但 #15 必須 fail-safe。
- **EC-13 (MEDIUM)** — **If `workout_completed` payload `completed_exercises = 0`**: 跑 Formula 1 → forced COMMON tier，但 token gate **仍然消耗**（player 已 claim daily attempt）。Rule 8 + 防 farming。
- **EC-14 (MEDIUM)** — **If `workout_completed` 但 daily token 今日已 claim**: reject daily drop emit (telemetry `loot.daily.duplicate_claim`)，但同一 session 後續 `boss_killed` / `enemy_killed` 照常 emit (兩條 budget 獨立)。Rule 1 拆分 budget。
- **EC-15 (LOW)** — **If `enemy_killed` payload `enemy_tier ∉ {mini_boss, final_boss}`**: silently drop，**唔 emit telemetry** (預期 99% normal mob kill noise)。Telemetry hygiene。
- **EC-16 (LOW)** — **If `boss_killed` 但 `workout_score = 0` (player 冇做 workout 直接打 boss — debug-only path)**: 套用 Formula 1 forced COMMON + boss floor → 結果 = UNCOMMON。Rule 11 server 會 reject in production build。

### 3. Persistence + Backend Coordination

- **EC-17 (CRITICAL)** — **If 5-step optimistic emit Step 3 (IndexedDB write) > 100ms timeout**: 觸發 rollback — revoke optimistic `loot_dropped` via `loot_rollback(drop_id)`，UI 收銀幕；retry 1 次；再失敗 → `Disabled`。Safari IndexedDB 已知 issue。
- **EC-18 (HIGH)** — **If backend ACK timeout 60s after submit**: `pending` 狀態保留，client polling cursor 每 30s recheck；72 小時後仍未 ACK → mark `orphan` + alert，唔自動 reconcile (避免 double-grant)。Rule 14。
- **EC-19 (HIGH)** — **If backend `committed.tier` ≠ client optimistic `tier`**: 跟 backend，emit `loot_tier_corrected(drop_id, old, new)`，UI 播 quick「重新評估」animation，**唔退 player loot** (升或降都接受)。Telemetry `loot.reconcile.tier_mismatch`。Rule 11。
- **EC-20 (HIGH)** — **If backend `loot.committed` 有 entry 但 client `loot.pending` 對應 entry 不見** (commit ACK 之前 client crash): backend 為真 → client insert 落 `loot.committed`，skip reveal ceremony，直接入 inventory + mailbox notification「離線時獲得」。Formula 5。
- **EC-21 (HIGH)** — **If GymSys returns 401 mid-loot-flow**: pause #15 emit pipeline，emit `loot_paused(reason="auth")`；交俾 #2 auth refresh；refresh 成功 → resume，pending queue intact。
- **EC-22 (CRITICAL)** — **If backend returns rarity tier 唔喺 enum (e.g., "MYTHIC")**: reject ACK，當 timeout 處理 (EC-18)，alert `loot.backend.unknown_tier`。Server contract violation。

### 4. State Transition Edge Cases

- **EC-23 (MEDIUM)** — **If `Revealing → Suspended` (tab background) mid-animation at frame 30/60**: 凍結 animation timeline，記 `resume_frame=30` + `suspend_timestamp`；resume 時跑 Formula 4 決定 CONTINUE / DEFER。Rule 17。
- **EC-24 (HIGH)** — **If `Disabled` (Private Mode) state 喺同一 session 內 Private Mode 解除**: 仍然 sticky `Disabled` 到 next boot — 唔 mid-session re-enable (避免 partial state corruption)。Banner 文案改為「下次開啟 app 將自動恢復」。Rule 16。
- **EC-25 (HIGH)** — **If `Idle → Disabled` mid-session (Private Mode 喺 session 中段突然 detected)**: 已 reveal 嘅 drop 保留喺記憶體 (volatile)，**唔寫 IndexedDB**；新 trigger 全部 drop + telemetry。Player session 結束 → memory 清空 (acceptable loss per Rule 16)。
- **EC-26 (MEDIUM)** — **If `Booting → Disabled` 即時 detected**: skip 所有 startup ceremony；banner 即出，唔 register trigger listeners (慳 CPU)。

### 5. Ceremony Cap + Queue Behavior

- **EC-27 (MEDIUM)** — **If 第 7 個 boss kill 同一 workout (ceremony_cap = 6 per Rule 6)**: silently 唔 emit reveal，但 **drop 仍然 grant 入 inventory** (skip ceremony only)，telemetry `loot.ceremony.cap_hit`。Formula 2。
- **EC-28 (HIGH)** — **If queue length > 30 (heavy combat burst)**: trigger Formula 6 catch_up compression → summary banner「擊敗 {n} 個敵人，獲得 {tier_breakdown}」+ 單一 burst animation；individual reveals skip。
- **EC-29 (MEDIUM)** — **If `modal_dismissed` signal 收到兩次 (double-tap race)**: 第二次 ignore via `last_dismissed_drop_id` guard；queue advance 一次。Idempotency。
- **EC-30 (MEDIUM)** — **If bfcache suspend queue=3，resume 後冇新 trigger**: resume 時跑 Formula 4 → CONTINUE (≤30s) 就 drain queue 由 index 0 起；DEFER (>30s) 將 queue 整批 move 去 `loot.pending` 等下次 boot。Rule 17。

### 6. RNG + Determinism

- **EC-31 (CRITICAL)** — **If 同一 `transition_id` 第二次計算產出不同 rarity**: hard assert `assert(prev_result == new_result, "RNG determinism violated")`，crash dev build；release build emit `loot.rng.determinism_break` CRITICAL alert + 用 cached `prev_result`。Pillar 1。
- **EC-32 (LOW)** — **If player 嘗試手動構造 `transition_id` (e.g., devtools inject)**: hash 仍然 deterministic → 計出 tier，但 backend Rule 11 reject (server source-of-truth `transition_id` 唔 match)，client revert。Attack mitigated by server。
- **EC-33 (HIGH)** — **If `LootRarityConfig.tres` runtime hot-reload detected (file mtime 變)**: hard assert，refuse to apply；config 必須 build-time bake。防 cheating + replay corruption。
- **EC-34 (CRITICAL)** — **If `_force_test_drop()` 喺 release build 被 call**: `assert(OS.is_debug_build(), "Debug API in production")` → crash dev，release build emit CRITICAL `loot.debug.production_leak` + ignore call。Rule 12。

### 7. Item Type / Class Affinity

- **EC-35 (MEDIUM)** — **If `dominant_class` returns NULL (player class data 未 sync)**: Formula E2 fallback → uniform 1/N weighting across 所有 class affinity buckets。
- **EC-36 (LOW)** — **If `gear_gap_state` empty (全 starter gear)**: 所有 weapon/armor slot ×1.5 boost，cosmetic ×1.0 (Formula E1 weighted selection 偏 functional)。
- **EC-37 (MEDIUM)** — **If player inventory 全 cosmetic (0 functional gear)**: 強制 next 3 drops `item_type ∈ {weapon, armor, accessory}`，bypass weighted RNG，telemetry `loot.bootstrap.functional_pity`。
- **EC-38 (MEDIUM)** — **If LEGENDARY drop rolled item_type = cosmetic 但 player 已 unlock 全部 cosmetic slots**: re-roll item_type **一次** (保留 tier)；仍然 cosmetic → grant duplicate + auto-convert to **`salvage_yield(rarity)` shards(LEGENDARY → 800;#17 G-3 RESOLVED 2026-06-06 — 統一單一 salvage 價值軌,原 100 同 manual salvage 800 有 8× player-visible 矛盾)**(per #17 Rule 11)。

### 8. Anti-Fabrication / Server Authority

- **EC-39 (CRITICAL)** — **If telemetry `loot.reconcile.tier_mismatch` rate > 0.5% over 1h rolling window**: PagerDuty alert，dashboard 自動截圖，suspect RNG drift 或 config desync。Pillar 1 monitoring。
- **EC-40 (CRITICAL)** — **If `transition_id` 喺 backend 出現於兩個唔同 `workout_id` (collision attack)**: backend reject 第二個 + ban submission for 60s + telemetry `loot.security.id_collision`。
- **EC-41 (HIGH)** — **If #9 `workout_score < 0` (上游 bug)**: clamp to 0 → Formula 1 forced COMMON，telemetry `loot.input.negative_score`。
- **EC-42 (LOW)** — **If `pr_breakthrough_count > MAX_PR_FACTOR` (ADR-0005 = 10)**: clamp to 10，silently，唔 alert (PR session 自然上限保護)。

### 9. UTC / Timezone

- **EC-43 (HIGH)** — **If daily token claim arrive 喺 UTC 00:00:00.xxx ±200ms boundary**: 用 backend `server_epoch_id` 為準 (Rule 1)，client local clock ignored — backend 決定 today vs yesterday。
- **EC-44 (MEDIUM)** — **If client clock drift > DRIFT_TOLERANCE (300s per Formula 3)**: TTL 計算改用 backend `server_time` from last poll；若 > 24h 冇 poll → 視所有 pending 為 `UNKNOWN_TTL`，conservative 當 FRESH 處理直到 reconcile。
- **EC-45 (LOW)** — **If DST shift in player local timezone**: 完全唔影響 — 所有 #15 logic 用 UTC，local time 只用於 UI 顯示。文檔 reminder。

### 10. Inventory / Mailbox

- **EC-46 (MEDIUM)** — **If inventory 剛好 120 (Formula E4 boundary;#17 G-1 sweep 60→120)**: 第 120 個 drop 直入 inventory (slot 120)；第 121 個去 mailbox 7d hold(#17 A3:expire = auto-salvage,唔係刪除)。
- **EC-47 (HIGH)** — **If mailbox 已達 `MAILBOX_HARD_CAP`=180 (overflow of overflow;#17 G-1b fix 2026-06-06:stale 100→180 + policy defer)**: **主路徑 defer to #17 Rule 4/EC-9** — 最舊非-receipt mailbox item auto-salvage 騰位(價值永不蒸發,#17 A3 binding),insert 照成功;UI banner「{n} 個獎勵待處理 — 整理背包」+ telemetry `loot.mailbox.full` 保留。**Fallback only**(#17 EC-9 極端 case:全 mailbox receipt-bearing 無 evictable):reject insert → `loot.orphan_queue` (max 50),oldest evict + telemetry `loot.orphan.evicted`。原 reject-first path 同 #17 auto-salvage policy 衝突,已 superseded。
- **EC-48 (CRITICAL)** — **If `Inventory.receive_loot()` throws** (e.g., #17 inventory system bug): rollback drop 去 `loot.pending.recovery` namespace，emit `loot.inventory.grant_fail` CRITICAL，UI 顯示「獎勵已保留，下次開啟自動補發」。Pillar 3 no loss。

---

## Dependencies

### Upstream Hard Dependencies

| Dep | Type | Interface | Bidirectional Sync Status |
|-----|------|-----------|--------------------------|
| **#8 Streak System** (Approved) | API call | `Streak.get_streak_buff_multiplier() -> float` (1.0 baseline, scales with consecutive workout days) | ✅ #8 GDD Section F lists "#15 Loot Drop" as referrer |
| **#9 Workout State Tracker** (Approved) | Signal subscription + read | Subscribes `workout_completed(workout_id, completed_exercises)`; reads `get_total_volume()`, `get_pr_count_today()` for `workout_score` formula | ⚠️ FORWARD: #9 lists #15 as downstream consumer (set_completed for in-session drops + workout_completed for guaranteed drop). #9 GDD pre-flagged FR-9 binding |
| **#14 EnemyDirector** (Approved) | Signal subscription | Subscribes `enemy_killed(transition_id, faction, tier)` — `transition_id` 係 deterministic RNG seed per ADR-0005 | ✅ #14 FR-2 binding `enemy_killed.transition_id → #15 chain seed` 已建立 |
| **#16 Boss System** (Pass 5 APPROVED) | Signal subscription | Subscribes `boss_killed(transition_id, boss_id, tier)`; mini-boss ceiling = RARE; final boss floor = UNCOMMON | ✅ #16 OQ Q-X6 (loot sink cross-doc) tracked Followup #12 |

### Upstream ADR Dependencies

| ADR | Status | Binding |
|-----|--------|---------|
| **ADR-0005 Loot Rarity Formula** | Proposed | Formula `loot_rarity_score = workout_score × 0.75 + rng_roll × 0.25` + Pillar 1 floor proof + LootRarityConfig.tres data-driven thresholds + deterministic RNG seeding |
| **ADR-0003 Save State Strategy** | Proposed | `loot.*` namespace ownership + `loot_pending` persistence (Tier 2 IndexedDB cache) + Private Mode loot-disable gate |
| **ADR-0006 State Machine Contract** | Proposed | Contract 2 (transition_id atomicity guarantees deterministic chain) + Contract 6 (`connect_for_initial_state` for boss signal subscription) |
| **ADR-0001 Web Export Budget Caps** | Proposed | LOOT_BURST / LOOT_RARE_BURST particle preset budget allocation (3× combat baseline, mobile 0.5×) |

### Downstream Dependents (Not Started)

| System | Reverse Dependency Statement (to add when GDD authored) |
|--------|--------------------------------------------------------|
| **#17 Equipment & Inventory** | Will receive `LootDrop` instances and produce Equipment items. Schema contract pending #17 GDD authoring. Q-OQ5 blocker. |
| **#21 Loot Drop Modal** (Presentation, Pre-MVP) | Subscribes `loot_dropped` signal; renders P-05 loot-drop-modal pattern. Will list #15 as upstream when authored. |
| **#22 Character Screen** (Presentation, MVP) | Reads loot history from PersistenceLayer (`loot.*`) for stat/equipment review. |
| **#28 Telemetry / Analytics** (Polish, Pre-MVP) | Subscribes `loot_dropped` for rarity distribution metrics; subscribes `loot_pending_recovered` for ADR-0003 durability validation. |

### Failure Mode Matrix

| If upstream fails | LootDrop behavior |
|-------------------|-------------------|
| #14/#16 boss kill signal lost | NO drop generated. NO ghost loot. Signal-or-nothing contract. |
| #9 workout_completed lost (GymSys polling fail) | NO daily guaranteed drop until polling recovers + cursor catches up. Tombstone forward-recovery via ADR-0003. |
| ADR-0003 PersistenceLayer Private Mode detected | **DISABLE all loot generation**. Show non-dismissible banner ("Private Mode — loot disabled"). Pillar 3 hard guarantee: never lose loot due to silent failure. |
| ADR-0005 formula constants tampered | CI lint enforcement (LootRarityConfig.tres immutable post-load) + runtime assertion. |

### Forward Constraints to Downstream

| Constraint | Receiving System | Binding |
|-----------|-----------------|---------|
| FR-LOOT-1: Equipment schema must accept `LootDrop.item_metadata` dict | #17 Equipment & Inventory | Required before #17 GDD authoring |
| FR-LOOT-2: Modal must subscribe `loot_dropped` within 100ms of emit | #21 Loot Drop Modal | Pillar 3 ritual timing |
| FR-LOOT-3: Telemetry event payload contract `loot_dropped_v1` schema | #28 Telemetry | Frozen schema, version on schema change |

---

## Tuning Knobs

> **Stability classification**:
> - **LOCKED** — Cannot change without ADR amendment or pillar re-validation
> - **DESIGN-FROZEN** — Section C/D contract binding; change requires GDD revision
> - **TUNABLE** — Designer-adjustable in `LootRarityConfig.tres` / `LootSystemConfig.tres`
> - **PROVISIONAL** — Baseline value pending playtest data (Pre-MVP iteration)

### Owned Knobs (#15 sole authority)

| Knob | Default | Safe Range | Stability | Effect / Failure Mode |
|------|---------|------------|-----------|----------------------|
| `CEREMONY_CAP` | **6** (total) | [3, 12] | DESIGN-FROZEN | Per-workout total ceremony budget (Pass 2 F-2: split into MINI_BOSS_CEREMONY_CAP + FINAL_BOSS_RESERVED below). Effective budget unchanged from Pass 1 |
| `MINI_BOSS_CEREMONY_CAP` (**Pass 2 F-2 NEW**) | **5** | [2, 11] | DESIGN-FROZEN | Mini-boss + workout-locked daily shared pool。第 6+ mini-boss kill → MICRO_ACK tier (Rule 6 + Formula 2). <2 → P3「每次 boss 死都有 moment」全 dies；>11 → ceremony fatigue + final reservation pressure |
| `FINAL_BOSS_RESERVED` (**Pass 2 F-2 NEW**) | **1** | LOCKED | LOCKED | Final boss ceremony guaranteed slot (independent of mini pool). P3 PRIMARY substrate hard guarantee — never preemptable |
| `SOFT_TTL_DAYS` | **30** | [7, 60] | LOCKED | Aligns `lootdrop_pending_ttl_days` registry (#2 backend retention contract). Change → ADR-0003 cascade |
| `HARD_CAP_DAYS` | **37** | SOFT+5 to SOFT+14 | LOCKED | SOFT+7 grace per ADR-0003 + #2 backend `lootdrop_cache` row retention contract |
| `DRIFT_TOLERANCE_S` | **300** | [60, 900] | LOCKED | ADR-0003 wall-clock drift budget binding (CI-3) |
| `BFCACHE_CONTINUE_THRESHOLD_MS` | **30000** | [10000, 60000] | TUNABLE | Formula 4 mid-reveal continue vs defer threshold。<10s → 細微 suspend 都重啟 ceremony；>60s → 老土動畫 resume 觀感差 |
| `CATCH_UP_THRESHOLD` | **5** | [3, 10] | TUNABLE | Formula 6 sequential vs summary banner switch。<3 → 細數都 summary 失去逐個 ceremony；>10 → 連續 reveal fatigue |
| `COSMETIC_EPIC_BONUS` | **0.05** | [0.0, 0.10] | TUNABLE | Formula E1 cosmetic weight bonus at tier ≥ EPIC。>0.10 → cosmetic 喺 high tier 主導，functional gear drought |
| `W_DOMINANT` | **0.65** | [0.50, 0.75] | TUNABLE | Formula E2 dominant class affinity weight。<0.50 → Pillar 4 「muscle=class」signal 失真；>0.75 → off-class drops 太罕有，build diversity 受限 |
| `W_NEUTRAL` | **0.20** | [0.10, 0.30] | TUNABLE | Formula E2 NEUTRAL tag weight。配合 W_DOMINANT 維持 INV CF-E2 sum=1.0 |
| `W_OFF_CLASS` | **0.075** | [0.05, 0.15] | TUNABLE | Formula E2 each off-class weight。CF-E2: W_DOMINANT + W_NEUTRAL + 2×W_OFF_CLASS = 1.0 |
| `MAX_INVENTORY` (**Pass 2 F-10 interim raise**) | **120** | [60, 200] | DESIGN-FROZEN | Formula E4 boundary。Pass 2 raised 60→120 per economy-designer C1 (Hardcore 30 drops/week × 60 = 14-day fill with MVP 5 items = duplicate flood). Long-term: #17 Equipment & Inventory cross-system fix (auto-convert duplicates / stash tier). Aligns #17 FR-LOOT-S3 forward constraint (revise #17 to 120 when authored) |
| `OVERFLOW_MAILBOX_TTL_DAYS` | **7** | [3, 14] | TUNABLE | Mailbox auto-expire window。<3 → player 冇足夠時間整理 inventory；>14 → mailbox 變第二 inventory |
| `MAILBOX_HARD_CAP` | **180** | [150, 250] | TUNABLE | Mailbox max entries before orphan_queue overflow (EC-47)。**#17 G-1 fix 2026-06-06:100 → 180** — Pass 2 raise MAX_INVENTORY 60→120 後 100 < 120 違反 INV-G3(config-load assertion 會 boot fail);180 = 1.5× MAX_INVENTORY(本 GDD cross-knob 建議 §4)。Range 下界須 > MAX_INVENTORY |
| `ORPHAN_QUEUE_CAP` | **50** | [25, 100] | TUNABLE | EC-47 last-resort queue cap，oldest-evict pattern |
| `BACKEND_ACK_TIMEOUT_S` | **60** | [30, 180] | TUNABLE | EC-18 ACK wait window before pending stays + polling retry |
| `BACKEND_ORPHAN_ALERT_HOURS` | **72** | [24, 168] | TUNABLE | EC-18 orphan classification threshold |
| `BASE_WEIGHTS.WEAPON` | **0.25** | [0.15, 0.40] | TUNABLE | Formula E1 base; ×1.5 if slot has starter gear |
| `BASE_WEIGHTS.ARMOR` | **0.25** | [0.15, 0.40] | TUNABLE | Formula E1 base; ×1.5 if slot has starter gear |
| `BASE_WEIGHTS.ACCESSORY` | **0.20** | [0.10, 0.30] | TUNABLE | Formula E1 base; ×1.2 if gap |
| `BASE_WEIGHTS.CONSUMABLE` | **0.20** | [0.10, 0.30] | TUNABLE | Formula E1 base; no gear gap modifier |
| `BASE_WEIGHTS.COSMETIC` | **0.10** | [0.05, 0.25] | TUNABLE | Formula E1 base; tier ≥ EPIC → +COSMETIC_EPIC_BONUS |
| `GEAR_GAP_WEAPON_MULT` | **1.5** | [1.0, 2.5] | TUNABLE | Formula E1 weapon-slot starter boost |
| `GEAR_GAP_ARMOR_MULT` | **1.5** | [1.0, 2.5] | TUNABLE | Formula E1 armor-slot starter boost |
| `GEAR_GAP_ACCESSORY_MULT` | **1.2** | [1.0, 1.8] | TUNABLE | Formula E1 accessory-slot gap boost |
| `ANTI_PILLAR_EPIC_PLUS_CAP_PCT` | **0.10** | [0.05, 0.15] | LOCKED | Formula E3 soft-clamp anti-pillar threshold。Locked = Pillar 3 share-worthiness preservation |

### Referenced Knobs (owned by ADR-0005 / other systems — #15 reads only)

| Knob | Owner | Value | Why #15 cares |
|------|-------|-------|---------------|
| `WORKOUT_WEIGHT` | ADR-0005 | 0.75 (LOCKED ≥ 0.70) | Rarity formula input (INV-1) |
| `RNG_WEIGHT` | ADR-0005 | 0.25 (LOCKED ≤ 0.30) | INV-1: WORKOUT + RNG = 1.0 |
| `TARGET_EXERCISES` | ADR-0005 | 5 | volume_factor denominator |
| `PR_BONUS_PER_PR` | ADR-0005 | 0.12 | pr_factor incremental |
| `MAX_PR_FACTOR` | ADR-0005 | 1.25 | pr_factor cap (EC-42 floor) |
| `STREAK_SCALE` | ADR-0005 | 28 | streak_factor scale |
| `MAX_STREAK_BONUS` | ADR-0005 | 0.20 | streak_factor cap |
| `tier_thresholds` | ADR-0005 | [0.0, 0.35, 0.55, 0.72, 0.88] | INV-6 ascending order |
| `lootdrop_pending_ttl_days` | #2 GymSys | 30 | INV-3 + CI-2 alignment |
| `lootdrop_pending_hard_cap_days` | #2 GymSys | 37 | INV-3 alignment |
| `wall_clock_drift_tolerance_seconds` | ADR-0003 | 300 | DRIFT_TOLERANCE_S binding |
| `max_active_particles` | #5 / ADR-0001 | 200 | LOOT_BURST / LOOT_RARE_BURST budget consumer |
| `loot_burst_multiplier` | #5 | 3.0 | particle preset multiplier (LOOT_BURST scope) |
| `mobile_fallback_multiplier` | #5 | 0.5 | mobile particle downscale |

### Cross-Knob Invariants (reference Section C INV table)

呢度只列出 Section G 額外 cross-knob constraint（INV-1..INV-11 已在 Section C）：

| ID | Constraint | Verification |
|----|-----------|--------------|
| INV-G1 | `BASE_WEIGHTS.* sum ≤ 1.5` before normalization (Formula E1 sanity) | Unit test on config load |
| INV-G2 | `CEREMONY_CAP ≥ 3` (else Pillar 3 「each workout has a moment」undermined) | Config load assertion |
| INV-G3 | `MAILBOX_HARD_CAP > MAX_INVENTORY` (must absorb at least 1 inventory overflow) | Config load assertion |
| INV-G4 | `BACKEND_ACK_TIMEOUT_S < BACKEND_ORPHAN_ALERT_HOURS × 3600` | Config load assertion |
| INV-G5 | `OVERFLOW_MAILBOX_TTL_DAYS < SOFT_TTL_DAYS` (mailbox expires faster than IndexedDB cache) | Config load assertion |

### Knob Interaction Warnings

1. **CEREMONY_CAP × CATCH_UP_THRESHOLD**：若 CEREMONY_CAP=12 但 CATCH_UP_THRESHOLD=3，sequential reveal 跑 12 個 ceremony 但 catch-up 3 個就 summary — 不一致 UX。建議 CATCH_UP_THRESHOLD ≥ CEREMONY_CAP / 2。
2. **W_DOMINANT × #9 dominant_class lag**：W_DOMINANT=0.65 假設 #9 `dominant_class` accurate；若 #9 stale → drops feel mis-targeted。Telemetry monitor `loot_class_affinity_match_rate` ≥ 0.60。
3. **COSMETIC_EPIC_BONUS × #17 cosmetic slot saturation**：若 player unlocks 全部 cosmetic，bonus 變浪費 (EC-38 re-roll)。Tune down 至 0.0 為 endgame opt-in。
4. **MAX_INVENTORY × MAILBOX_HARD_CAP**：兩者太接近 → 短時間 burst 即時 overflow。建議 mailbox 至少 inventory 1.5×。
5. **ANTI_PILLAR_EPIC_PLUS_CAP_PCT × hardcore player retention**：太嚴 → hardcore players 唔開心；太鬆 → ceremonial dilution。Locked at 0.10 per Pillar 3 anti-drift。

### Stability Summary

| Tier | Count | Notes |
|------|-------|-------|
| LOCKED | 5 | `SOFT_TTL_DAYS`, `HARD_CAP_DAYS`, `DRIFT_TOLERANCE_S`, `ANTI_PILLAR_EPIC_PLUS_CAP_PCT`, ADR-0005 weights |
| DESIGN-FROZEN | 3 | `CEREMONY_CAP`, `MAX_INVENTORY`, related FR contracts |
| TUNABLE | 17 | Most weights, multipliers, timeouts |
| PROVISIONAL | 0 | All values have basis (no playtest data deferred — economy E3 Monte Carlo provides initial calibration) |

---

## Visual/Audio Requirements

> Initial cross-reference: P-05 loot-drop-modal (UX patterns) + Art Bible Section 4.E (Loot Drop saturation timeline) + Section 2.1 (ceremonial mood)

### A. Per-Rarity Visual Spec Table

| Tier | Hold | Time-stop | Camera | Screen Shake | Saturation (World) | Particle Preset | Color | Audio Duck |
|------|------|-----------|--------|--------------|--------------------|-----------------|-------|------------|
| COMMON | 0.20s | 0s | — | — | −60% (recover 2.0s) | LOOT_BURST (1×) | #FFFFFF White | −3dB / 0.3s |
| UNCOMMON | 0.35s | 0s | — | — | −60% (recover 2.0s) | LOOT_BURST (1×) | #4CAF50 Green | −5dB / 0.4s |
| RARE | 0.50s | 0.15s | 1.02× pulse, 0.3s ease-in-out | 2px / 0.2s | −60% (recover 2.0s) | LOOT_BURST (1.5×) | #2196F3 Blue | −8dB / 0.5s |
| EPIC | 0.65s | 0.30s | 1.05× + 0.65s focal lock | 4px / 0.35s | −60% (recover 2.0s) | LOOT_RARE_BURST (2×) | #9C27B0 Purple | −12dB / 0.6s |
| LEGENDARY | 0.80s | 0.40s | 1.08× + 0.8s focal lock + 輕微 orbit drift | 6px / 0.5s + 0.1s pre-shake anticipation | −60% (recover 2.0s) | LOOT_RARE_BURST (3×) | #FF9800 Orange | −16dB / 0.8s |

All particle counts 受 ADR-0001 Web Export budget cap 200 active particles 限制；mobile profile 自動 ×0.5 multiplier。Saturation 統一 −60%，唔隨 tier 升級——tier 用 hold 時長同 particle 密度區分，避免世界顏色過度漂移。

### B. Audio Direction Contract

**Forward constraint to #4 Audio Manager** (尚未設計)：

每個 rarity_tier 必須對應一個 reveal sting audio bank entry。Sting escalation 由 sound-designer 製作，ladder 結構：

| Tier | Reveal Sting Character |
|------|------------------------|
| COMMON | Soft chime (single tone, < 0.4s) |
| UNCOMMON | Warm chime (two-tone, < 0.6s) |
| RARE | Crystal hit (resonant, ~0.8s sustain) |
| EPIC | Orchestral swell (strings + bell, ~1.2s) |
| LEGENDARY | Full orchestral hit + brass stab (~1.6s, anticipation pre-roll matches 0.1s pre-shake) |

**Workout music semantics**: 永遠 duck-not-stop（Pillar 2「肌肉先於屏幕」）。Workout track 由 −dB 衰減進入 ceremony，ceremony 結束後 1.5s ease-back 還原到 0dB。**禁止 stop() / pause() / fade-out-to-zero**——音樂必須維持 audible bed，避免破壞健身節奏感。

**CI lint rule (forward to #4)**: `tools/ci/check_loot_audio_bank.gd` 應 enumerate `LootRarityTier` 並 assert audio bank 每個 tier 都有對應 sting entry。任何 tier 缺 sting → CI fail。同理 verify duck dB / duration 對應 spec table。

### C. Anti-Pillar Visual Guards

- **Pillar 1（避免「lucky」框架）**：RARE+ reveal modal 必須顯示 workout_score 同 rng_roll 嘅貢獻 breakdown（ADR-0005 公式可視化）。視覺設計 forward 去 #21 modal — breakdown bar 必須 workout_score 段大於 rng_roll 段（75/25），令玩家視覺上理解「身體先於骰仔」。
- **Pillar 2（attention budget ceiling）**：每 ceremony perceived time ≤ 1.2s（LEGENDARY = 0.8s hold + 0.4s time-stop = 1.2s）。Saturation 2.0s recovery 屬 background ambient，唔計入 attention budget。
- **Pillar 3（distinguishability — FR-2 mitigation）**：五個 tier 視覺上必須瞬間可辨。色相 + hold 時長 + particle 密度 + 音效 sting 四重編碼。100ms emit-to-visual-onset window 內 tier identity 必須已經 communicated（particle burst 起手即攜帶 tier color）。
- **Pillar 5（Mirror Moment — LEGENDARY 截圖時刻）**：LEGENDARY ceremony 嘅 orbit drift + focal lock 設計為適合截圖嘅 composition — camera 輕微 orbit 令物品 silhouette 有 parallax depth，玩家用 PWA share button 截圖時自動得到「明信片級」frame。

### D. Performance / Web Export Budget

- 每 tier 嘅 particle preset 必須 fit within ADR-0001 200 active particle cap。LOOT_RARE_BURST 3× 為 LEGENDARY 嘅 peak load，technical-artist 需 verify 唔超 cap（spike test required）。
- Mobile profile 自動 ×0.5 particle multiplier；hold 時長同 camera / shake 不變（mobile 唔降 ceremony 質感，只降 particle 密度）。
- World saturation effect 必須用 fullscreen shader post-process（CanvasLayer）實現，**禁止** per-pixel CPU 處理。Shader uniform `saturation_factor` 由 #6 Screen Effects 控制 tween。
- Camera focal lock + orbit drift 必須 route through `src/autoload/camera_controller.gd`（ADR-0001 enforcement）。
- Pre-shake anticipation（LEGENDARY 0.1s）必須 route through `src/autoload/screen_effects.gd` shader uniform path，**禁止** 直接 mutate `Camera2D.offset`。

📌 **Asset Spec Flag**: 5× particle texture atlases (per-tier), 5× reveal sting audio files, 1× saturation post-process shader (`loot_saturation.gdshader`), 5× rarity badge sprites (matches P-06 pattern)。All assets follow naming: `vfx_loot_[tier]_burst_[size].png`, `sfx_loot_[tier]_reveal.ogg`, `ui_badge_rarity_[tier].png`。Mobile variants suffix `_mobile`。**Owner: art-director (specs) + technical-artist (shader) + sound-designer (audio)**。Art Bible 一旦 approved，run `/asset-spec system:loot-drop-system` 產生 per-asset 嘅 visual descriptions + dimensions + generation prompts。

---

## UI Requirements

> Initial cross-reference: P-06 rarity-color-tier (UX patterns) + accessibility-requirements.md tier commitments

### A. Trigger UI Surfaces

- **In-game HUD during workout**: **NONE**。Workout 進行中 loot drop 唔顯示任何 HUD overlay / toast / counter（Pillar 2「肌肉先於屏幕」）。Loot accumulation 靜默發生，靠 ceremony 模式集中 reveal。
- **#21 Loot Drop Modal**: primary reveal surface。Subscribes `loot_dropped` signal，必須喺 emit 後 100ms 內 visual onset（FR-2 mitigation）。
- **Disabled banner**: 由 shared UI library 提供 banner component（#21 實現），#15 只擁有 content string：「**Private Mode：Loot 暫停掉落，因為 IndexedDB 不可用**」。Forward constraint：PersistenceLayer 偵測 Private Mode 時觸發 banner display，#15 提供 banner copy ownership。

### B. Reveal Modal Content Contract (forward constraint to #21)

#21 modal 必須包含以下 content slots：

1. **Rarity badge** — 跟 P-06 pattern（色 + 形 + label 三重編碼）
2. **Item name + icon** — 由 #17 Item Catalog 提供
3. **Source attribution string** — 三種 variant：
   - 「來自 boss 擊殺」(boss kill source)
   - 「來自健身完成」(workout completion source)
   - 「來自 mini-boss 擊殺」(mini-boss source)
4. **FR-1 mitigation — RARE+ contribution breakdown**：顯示 workout_score 同 rng_roll 嘅 weighted bar（75/25 split），讓玩家睇到「身體貢獻 vs 運氣貢獻」嘅實際比例。COMMON/UNCOMMON tier 唔顯示 breakdown（避免 modal 過度膨脹）。
5. **Dismiss CTA**：tap target ≥ 48dp（touch-first input per technical-preferences）。
6. **ScreenReader announcement**：`"[Rarity] loot: [Item Name]，來自 [source]. [Workout contribution X%, RNG contribution Y%]"` — RARE+ 才讀 breakdown segment。

### C. Ceremony Cap + Catch-up UI

- **Rule 6 cap behaviour**: 當 ceremony budget 觸 cap 時，**唔顯示任何 visual cue**，只 emit telemetry event（`loot_ceremony_capped`）。玩家無感知 cap 存在，避免 Pillar 2 attention budget 被破壞。
- **Formula 6 catch-up banner**: workout session 結束後，若有未拆 loot，顯示 banner：「**您有 N 個未拆 loot**」+ 主 CTA「tap to reveal all」。Tap 後 batch burst 用 LOOT_BURST preset rapid-fire（每 0.15s 一個），所有 RARE+ 仍各自獨立 ceremony（保留 hold + time-stop ladder）。

### D. Accessibility

- **`motion_reduction` setting respect**: 開啟後 saturation drop disabled（世界保持正常飽和度）、time-stop disabled（0s across all tiers）、screen shake disabled（0px across all tiers）。Hold 時長保留（屬視覺停頓非 motion）、particle burst 保留但密度 ×0.5、camera zoom 改為 fade-in vignette 取代。
- **Color NOT sole rarity indicator**（per P-06）：每 tier 必須有 shape badge + animation timing + audio sting 三重 backup channel。色盲玩家依靠 hold 時長同 sting character 仍可辨識 tier。
- **ScreenReader contract**: 每次 `loot_dropped` emit 必須有對應 ARIA live region announcement，timing 唔受 motion_reduction 影響。FR-3 mitigation：daily guaranteed drop 嘅 NO pity bonus visual / audio cue — ScreenReader 亦 NOT 提及「pity / guaranteed」字眼（避免破壞 Pillar 1）。

📌 **UX Flag**: #21 Loot Drop Modal（Pre-MVP, not yet designed）為呢個 GDD 嘅 primary forward dependency。Modal content contract、disabled banner integration、catch-up banner、motion_reduction switch 必須由 ux-designer 同 ui-programmer 喺 #21 設計階段對齊本節 spec。Shared banner component ownership 屬 #21 UI library；#15 只擁有 content strings。Accessibility audit gate 必須 verify motion_reduction full ladder disable 行為（accessibility-specialist sign-off required before #21 ships）。喺 Phase 4 (Pre-Production)，run `/ux-design` to create UX spec for #21 modal before writing epics。

---

## Acceptance Criteria

> **Scope**: 44 Given-When-Then ACs covering 18 Core Rules + 10 Formulas + 11 INVs + 48 ECs (Pass 2 post-fresh-session CD revision)
> **Test Distribution**: 24 unit / 12 integration / 5 static-analysis / 3 manual (ADVISORY) / 1 composite (Pass 2: +AC-43 daily token gate unit + AC-44 EC-22 unknown tier unit; AC-38/40/41 downgraded to ADVISORY per CD F-9 Testing Standards compliance)
> **Gate Levels (Pass 2)**: 34 BLOCKING (post-Pass 2: -3 playtest BLOCKING→ADVISORY + 2 new BLOCKING + 0 ADR-RATIFICATION reclassify-pending) / 4 ADR-RATIFICATION-GATED (status: ADR-0006 Accepted so AC-37 actionable now; ADR-0003 Accepted so AC-23/24/35 actionable now — reclassify in Pass 3) / 4 ADVISORY (AC-38 attribution + AC-39 skip + AC-40 screenshot + AC-41 interview — Visual/Feel per coding-standards.md Testing Standards)

### AC Table

| AC# | GIVEN / WHEN / THEN | Source | Test Type | Gate | File Path |
|---|---|---|---|---|---|
| **AC-01** | **GIVEN** `_rng.seed = hash("T-deadbeef")` and `workout_score = 0.0` **WHEN** `_generate_loot_internal("T-deadbeef", WORKOUT_DAILY, 0.0)` run 1,000 times across max RNG seeds **THEN** every output `final_tier == COMMON`; no run produces UNCOMMON+ | Pillar 1 anti-fabrication proof (ADR-0005 + Rule 8) | unit | BLOCKING | `tests/unit/loot/test_pillar1_rng_alone_never_exceeds_common.gd` |
| **AC-02** | **GIVEN** ADR-0005 max RNG contribution = 0.25 and EPIC threshold = 0.72 **WHEN** Monte Carlo 10,000 rolls with `workout_score = 0.001` (epsilon) **THEN** zero rolls produce `raw_tier >= EPIC` (architectural proof) | Pillar 1 ADR-0005 floor proof + FR-1 | unit | BLOCKING | `tests/unit/loot/test_rng_ceiling_below_epic.gd` |
| **AC-03** | **GIVEN** raw_tier=EPIC + kind=MINI_BOSS + ws=0.78 **WHEN** `apply_tier_ceiling_floor()` evaluated **THEN** result == RARE (clamped); telemetry log `loot.tier.clamp_mini` emitted | Formula 1 mini ceiling + INV-10 + Rule 4 | unit | BLOCKING | `tests/unit/loot/test_apply_tier_ceiling_floor.gd` |
| **AC-04** | **GIVEN** raw_tier=COMMON + kind=FINAL_BOSS + ws=0.4 **WHEN** `apply_tier_ceiling_floor()` evaluated **THEN** result == UNCOMMON (lifted by final boss floor); INV-10 satisfied | Formula 1 final boss floor + INV-10 + Rule 5 | unit | BLOCKING | `tests/unit/loot/test_apply_tier_ceiling_floor.gd` |
| **AC-05** | **GIVEN** raw_tier=LEGENDARY + kind=WORKOUT_DAILY + ws=0.0 **WHEN** `apply_tier_ceiling_floor()` evaluated **THEN** result == COMMON (zero-workout guard overrides ALL) | Formula 1 zero-workout guard + Rule 8 + INV-11 + EC-13 | unit | BLOCKING | `tests/unit/loot/test_zero_workout_forced_common.gd` |
| **AC-06** | **(Pass 2 F-1 reword)** **GIVEN** workout W-42 active (`WorkoutStateTracker.get_active_workout_id()` returns "W-42") + 5 prior mini-boss `loot_dropped` ceremony emits (MINI_BOSS_CEREMONY_CAP=5 hit) **WHEN** 6th `enemy_killed` (mini-boss) event arrives **THEN** Formula 2 ceremony_cap_check returns MICRO_ACK; `loot_dropped` NOT emitted (no full ceremony); loot record persisted; `loot_ceremony_capped` + `loot_micro_ack_triggered(workout_id="W-42", mini_boss_seq_num=6)` telemetry fires exactly once; mailbox badge +1 increments; subsequent `boss_killed` (final boss) same workout returns FULL_CEREMONY (FINAL_BOSS_RESERVED slot independent) | Rule 6 + Formula 2 + Rule 7.5 + INV-9 + EC-27 | integration | BLOCKING | `tests/integration/loot/test_ceremony_cap_micro_ack_and_final_reservation.gd` |
| **AC-07** | **GIVEN** new workout_id `W-99` **WHEN** `ceremony_cap_check()` called 6 times then 7th **THEN** first 6 return true, 7th returns false; counter for W-42 unaffected (per-workout isolation) | Formula 2 + CF-5 + Rule 6 | unit | BLOCKING | `tests/unit/loot/test_ceremony_cap_per_workout_isolation.gd` |
| **AC-08** | **GIVEN** local `LootDrop` with optimistic `tier=EPIC` + drop_id D-100 **WHEN** backend ACK returns `tier=RARE` for D-100 **THEN** client adopts RARE; `loot_tier_corrected(D-100, "EPIC", "RARE")` emitted; UI plays「重新評估」animation; player NOT refunded | Rule 11 + EC-19 | integration | BLOCKING | `tests/integration/loot/test_server_authority_tier_correction.gd` |
| **AC-09** | **GIVEN** `local_pending = {T-103}`, `local_revealed = {T-101}`, `backend_pending = {T-100, T-101, T-102}` (4-entry worked example) **WHEN** `reconcile_local_vs_backend()` run **THEN** `to_enqueue == {T-100, T-102}`, `to_ack_only == {T-101}`, `to_discard_local == {T-103}`; 3 sets pairwise disjoint (assert holds) | Formula 5 + CF-4 + Rule 17 + EC-20 | unit | BLOCKING | `tests/unit/loot/test_reconcile_local_vs_backend.gd` |
| **AC-10** | **GIVEN** drop age = 30 days + 4 minutes (2,592,240s) + client clock skew = +5 min (DRIFT_TOLERANCE_S = 300) **WHEN** `pending_ttl_expired()` evaluated **THEN** result == FRESH (drift tolerance saves edge case at SOFT boundary); adjusted_age (2,591,940) < SOFT_TTL (2,592,000) | Formula 3 drift edge + EC-44 + CI-3 | unit | BLOCKING | `tests/unit/loot/test_pending_ttl_drift_tolerance.gd` |
| **AC-11** | **GIVEN** drop age = 38 days + client clock skew = -10 min **WHEN** `pending_ttl_expired()` evaluated **THEN** result == HARD_EXPIRED (raw age used at HARD boundary, drift ignored); next-session boot triggers force-reveal | Formula 3 HARD boundary + Rule 14 + EC-08 | unit | BLOCKING | `tests/unit/loot/test_pending_ttl_hard_cap.gd` |
| **AC-12** | **GIVEN** mid-reveal LootDrop suspended at frame 30/60 **WHEN** bfcache resume with delta = 12,000ms (≤ 30s threshold) **THEN** `bfcache_resume_action` returns CONTINUE_ANIMATION; animation continues from frame 30 | Formula 4 + Rule 17 + EC-23 | unit | BLOCKING | `tests/unit/loot/test_bfcache_resume_continue.gd` |
| **AC-13** | **GIVEN** mid-reveal suspended **WHEN** resume delta = 45,000ms (> 30s) **THEN** `bfcache_resume_action` returns DEFER_TO_NEXT_BOOT; drop persists in `loot.pending`; next boot force-reveal | Formula 4 deferral + Rule 17 + EC-30 | unit | BLOCKING | `tests/unit/loot/test_bfcache_resume_defer.gd` |
| **AC-14** | **GIVEN** Hardcore profile (avg ws=0.92, 5 workouts, 7 PR, 30d streak) **WHEN** `expected_weekly_rarity_distribution` Monte Carlo n=10,000 run **THEN** post-clamp EPIC+ percentage ≤ 10.0% (CF-E3 invariant); soft-clamp downgrade order verified LEGENDARY→EPIC→RARE strict | Formula E3 + CF-E3 + FR-1 anti-pillar | unit | BLOCKING | `tests/unit/loot/test_e3_anti_pillar_soft_clamp.gd` |
| **AC-15** | **GIVEN** RARE drop, weapon slot starter, dominant=STRIKE, rng_roll_2=0.42 **WHEN** `item_type_weighted_selection` evaluated **THEN** Σ weights == 1.0 (within 1e-6); cumulative distribution lands rng_roll_2 in ARMOR band (0.341..0.568) → outcome == ARMOR | Formula E1 worked example + CF-E1 + CI-6 | unit | BLOCKING | `tests/unit/loot/test_item_type_weighted_selection.gd` |
| **AC-16** | **GIVEN** weapon + dominant=STRIKE + rng_roll_3=0.78 **WHEN** `class_affinity_resolution` evaluated **THEN** Σ weights == 1.0 (0.65+0.20+0.075+0.075); outcome == NEUTRAL (rng_roll_3 in 0.650..0.850 band); deterministic for same seed | Formula E2 worked example + CF-E2 + CI-6 | unit | BLOCKING | `tests/unit/loot/test_class_affinity_resolution.gd` |
| **AC-17** | **GIVEN** inventory size = 120 (Formula E4 boundary;#17 G-1 sweep 60→120) **WHEN** new drop arrives **THEN** drop occupies slot 120 (DIRECT_INVENTORY); subsequent 121st drop routes to MAILBOX_OVERFLOW with 7-day TTL | Formula E4 + EC-46 + CI-7 | unit | BLOCKING | `tests/unit/loot/test_inventory_overflow_boundary.gd` |
| **AC-18** | **GIVEN** 8 pending unrevealed drops (catch-up scenario) **WHEN** `catch_up_threshold_compression` evaluated **THEN** result == SUMMARY_BANNER_THEN_BURST; banner copy「您有 8 個未拆 loot」rendered; individual reveals skip in favor of single tap-to-burst sequence | Formula 6 + Rule 15 + EC-28 | integration | BLOCKING | `tests/integration/loot/test_catchup_summary_banner.gd` |
| **AC-19** | **GIVEN** 3 pending drops missed across 3 days **WHEN** session boot reconcile complete **THEN** result == SEQUENTIAL_REVEAL; 3 modals shown in trigger-timestamp ASC order; no summary banner | Formula 6 sequential path + Rule 15 | integration | BLOCKING | `tests/integration/loot/test_catchup_sequential.gd` |
| **AC-20** | **GIVEN** same `transition_id = "T-feedface"` **WHEN** `_generate_loot_internal` called twice with identical inputs **THEN** both calls return byte-identical `LootDrop.rarity_tier` + `item_type` + `class_tag` (replay safety) | Rule 10 + EC-31 + CI-6 | unit | BLOCKING | `tests/unit/loot/test_deterministic_rng_replay.gd` |
| **AC-21** | **GIVEN** same `transition_id` already in `_drops_by_transition` cache **WHEN** duplicate `enemy_killed` signal arrives within 100ms **THEN** cached LootDrop returned; no new RNG roll executed; no telemetry noise emitted | Rule 9 idempotency + INV-7 + EC-11 | unit | BLOCKING | `tests/unit/loot/test_transition_id_idempotency.gd` |
| **AC-22** | **GIVEN** `transition_id = ""` (empty string) or non-hex format **WHEN** trigger event handler reached **THEN** event rejected; `loot.trigger.malformed_id` telemetry emitted; no crash; no LootDrop created | EC-12 + Rule 9 fail-safe | unit | BLOCKING | `tests/unit/loot/test_malformed_transition_id.gd` |
| **AC-23** | **GIVEN** ADR-0003 `PersistenceLayer.private_mode_detected = true` on boot **WHEN** #15 `_ready()` executes **THEN** state == Disabled; `loot_disabled("private_mode")` emitted; non-dismissible banner shown; subsequent `boss_killed`/`workout_completed` triggers all short-circuit with no LootDrop generation | Rule 16 + EC-01 + Q-OQ3 resolved | integration | ADR-RATIFICATION-GATED (BLOCKED-ON: ADR-0003) | `tests/integration/loot/test_private_mode_disabled_state.gd` |
| **AC-24** | **GIVEN** Private Mode detected mid-session **WHEN** state transitions Idle → Disabled **THEN** already-revealed drops retained in memory (volatile); new triggers dropped + telemetry; banner copy changes to「下次開啟 app 將自動恢復」 | EC-24 + EC-25 + Rule 16 | integration | ADR-RATIFICATION-GATED (BLOCKED-ON: ADR-0003) | `tests/integration/loot/test_private_mode_mid_session.gd` |
| **AC-25** | **GIVEN** release build (`OS.is_debug_build() == false`) **WHEN** `_force_test_drop(RARITY_LEGENDARY)` invoked from any code path **THEN** assertion fires + crashes process with message "loot fabrication blocked in release"; telemetry `loot.debug.production_leak` emitted before crash | Rule 12 + EC-34 + FR-1 | unit | BLOCKING | `tests/unit/loot/test_force_test_drop_release_guard.gd` |
| **AC-26** | **GIVEN** GDScript codebase at HEAD **WHEN** `tools/ci/check_loot_rng_seeded.gd` runs **THEN** any occurrence of bare `randf()` / `randi()` inside `src/core/loot_drop_system.gd` causes CI exit code != 0 | Rule 10 + CI lint suite | static-analysis | BLOCKING | `tools/ci/check_loot_rng_seeded.gd` |
| **AC-27** | **GIVEN** any file under `src/` **WHEN** `tools/ci/check_loot_namespace_writers.gd` runs **THEN** any `PersistenceLayer.write("loot.*", ...)` call outside `src/core/loot_drop_system.gd` causes CI fail | Rule 18.3 namespace monopoly + INV-5 | static-analysis | BLOCKING | `tools/ci/check_loot_namespace_writers.gd` |
| **AC-28** | **GIVEN** any file under `src/` **WHEN** `tools/ci/check_loot_generator_callers.gd` runs **THEN** any call to `_generate_loot_internal()` outside `src/core/loot_drop_system.gd` causes CI fail | Rule 18.2 caller whitelist | static-analysis | BLOCKING | `tools/ci/check_loot_generator_callers.gd` |
| **AC-29** | **GIVEN** `design/registry/entities.yaml` pins `LootRarityConfig.tres` SHA = X **WHEN** `tools/ci/check_loot_config_hash_pinned.gd` runs **THEN** any drift between file SHA and pinned SHA causes CI fail (defends EC-04 boot drift) | EC-04 + EC-22 config integrity | static-analysis | BLOCKING | `tools/ci/check_loot_config_hash_pinned.gd` |
| **AC-30** | **GIVEN** any `emit_signal("loot_dropped", ...)` site in `loot_drop_system.gd` **WHEN** `tools/ci/check_loot_signal_payload_minimal.gd` runs **THEN** any payload containing a full `LootDrop` object (not just `drop_id: String + rarity_tier: String + item_type: String + transition_id: String`) causes CI fail | Signal contract minimality + FR-2 100ms binding | static-analysis | BLOCKING | `tools/ci/check_loot_signal_payload_minimal.gd` |
| **AC-31** | **GIVEN** session with `local_pending={T-103}` + `local_revealed={T-101}` + `backend_pending={T-100, T-101, T-102}` + Private Mode false **WHEN** full bfcache→resume→`GET /api/game/loot/pending`→reconcile→reveal_queue_drain flow executes **THEN** modals shown in order [T-100, T-102]; ACK sent for T-101 (no re-reveal); T-103 silently discarded; no orphan drops in any namespace post-flow | Rule 17 + Formula 5 + Q-OQ4 + EC-20 + EC-30 cross-system end-to-end | composite | BLOCKING | `tests/integration/loot/test_bfcache_reconcile_full_flow.gd` |
| **AC-32** | **GIVEN** clean autoload boot order **WHEN** Godot project launches **THEN** `#15 LootDropSystem` `_ready()` fires at position 7 (after `#14 EnemyDirector` ready, before `#21 LootRevealModal` ready); upstream signal subscriptions occur AFTER `GymSysClient.backend_ready` resolved | Autoload boot position + Rule 18 step 4 race guard | integration | BLOCKING | `tests/integration/loot/test_autoload_boot_position_7.gd` |
| **AC-33** | **GIVEN** Step 3 `PersistenceLayer.write_async("loot.pending." + drop_id, ...)` throws/timeouts >100ms **WHEN** 5-step optimistic pipeline executes **THEN** `loot_disabled("persistence_unavailable")` emitted; `#21.cancel_reveal(drop_id)` invoked; modal UI revoked; `loot_optimistic_rollback` telemetry fired; no leaked in-memory LootDrop | 5-step lifecycle Step 4 + EC-17 | integration | BLOCKING | `tests/integration/loot/test_optimistic_rollback_path.gd` |
| **AC-34** | **GIVEN** backend ACK arrives with `canonical_id = "C-7777"` for `drop_id = "D-100"` (Step 5) **WHEN** rename succeeds **THEN** `loot.pending.D-100` removed; `loot.committed.C-7777` written; `loot_committed("D-100", "C-7777")` emitted; INV-8 holds (every commit has prior `loot_dropped`) | 5-step lifecycle Step 5 + INV-8 | integration | BLOCKING | `tests/integration/loot/test_loot_commit_rename.gd` |
| **AC-35** | **GIVEN** `loot.pending` entry with `schema_version = 1` and CURRENT_SCHEMA = 2 (future migration) **WHEN** boot migration path runs **THEN** in-place migration < 900ms (ADR-0003 ceiling); unmigratable entry routed to `loot.pending.quarantine` namespace + telemetry; boot NOT blocked | Rule 18 schema versioning + EC-05 + ADR-0003 | integration | ADR-RATIFICATION-GATED (BLOCKED-ON: ADR-0003) | `tests/integration/loot/test_schema_migration_under_900ms.gd` |
| **AC-36** | **GIVEN** INV-1 (`WORKOUT_WEIGHT + RNG_WEIGHT == 1.0`) + INV-6 (`LootRarityConfig.thresholds` strictly increasing) **WHEN** `LootRarityConfig.tres` loaded at boot **THEN** both invariants asserted; either fails → EC-03 hard-assert crash with `push_error()` (refuse boot) | INV-1 + INV-6 + EC-03 + EC-04 | unit | BLOCKING | `tests/unit/loot/test_config_invariants_boot.gd` |
| **AC-37** | **GIVEN** INV-2 (`transition_id` format = ADR-0006 Contract 2 monotonic string) **WHEN** any LootDrop persisted to `loot.pending` or `loot.committed` **THEN** `transition_id` field passes regex `^[0-9a-f]{16,}$` (hex monotonic per ADR-0006) | INV-2 + ADR-0006 Contract 2 | unit | ADR-RATIFICATION-GATED (BLOCKED-ON: ADR-0006) | `tests/unit/loot/test_transition_id_format_invariant.gd` |
| **AC-38** | **(Pass 2 F-9 downgrade ADVISORY)** **GIVEN** FR-1「RNG-fabrication leak」risk **WHEN** RARE+ drop shown in #21 Loot Drop Modal **THEN** UI tooltip displays「workout contribution: X% / chance: Y%」breakdown (X derived from `workout_score × 0.75`, Y from `rng_roll × 0.25`); FT-2 attribution test player survey week 1 shows ≥60% players use「earned/值得」language over「lucky/好彩」; **extended (per CD F-5)**: ≥40% players 喺 post-session 5-min interview 主動引用具體 workout 數字 (e.g.「打到 180kg 嗰陣攞到」) when describing RARE+ drops (verbal attribution) | FR-1 + FT-2 falsifiable test + CD F-5 emotional reinforcement | manual/playtest | **ADVISORY** (per coding-standards.md Testing Standards: Visual/Feel evidence is ADVISORY not BLOCKING — catch-22 with pre-merge gate; telemetry hook + interview protocol owner tracked LOOT-AC-followup-07) | `production/qa/evidence/loot-ft2-attribution-test.md` |
| **AC-39** | **GIVEN** FR-2 ceremony length risk **WHEN** week-1 playtest cohort observed during LEGENDARY drop **THEN** <30% tab away / press skip during full ceremony window (0.8s hold + 0.4s time-stop + 2.0s recovery ≈ 3.2s)；FT-3 skip test threshold respected | FR-2 + FT-3 + Rule 13 reveal ordering | manual/playtest | ADVISORY (quantitative threshold added: <30% skip rate) | `production/qa/evidence/loot-ft3-skip-test.md` |
| **AC-40** | **(Pass 2 F-9 downgrade ADVISORY)** **GIVEN** FT-1 screenshot test cohort week 1 **WHEN** player receives first RARE+ drop **THEN** ≥50% capture screenshot within 60s of reveal (telemetry hook on share button OR manual cohort survey); **extended (per CD F-9 original)**: ≥80% playtester 喺 post-session interview 主動提及至少 1 件 loot drop by tier name; Pillar 3 share-worthiness validated | FT-1 + Pillar 3 fantasy validation | manual/playtest | **ADVISORY** (per coding-standards.md Testing Standards: catch-22 with pre-merge gate; telemetry share-button hook + 60s window definition tracked LOOT-AC-followup-08) | `production/qa/evidence/loot-ft1-screenshot-test.md` |
| **AC-41** | **(Pass 2 reorder: was after AC-42)** **GIVEN** telemetry `loot.reconcile.tier_mismatch` rate **WHEN** 1-hour rolling window evaluated post-launch **THEN** rate > 0.5% triggers PagerDuty alert + dashboard auto-screenshot; suspected RNG drift / config desync investigation begins | EC-39 + Rule 11 monitoring + FR-1 | integration | BLOCKING | `tests/integration/loot/test_tier_mismatch_alert_threshold.gd` |
| **AC-42** | **GIVEN** workout session 純練胸 (chest_volume = 100% of total_volume) **WHEN** workout_completed → daily LootDrop generates weapon/armor with class_affinity_score **THEN** STRIKE class affinity weight 集中於 STRIKE bucket (`class_affinity[STRIKE] >= 0.65` post-Formula E2 weighted roll); 非 random — deterministically derived from #9.get_dominant_ability_class() | Formula E2 + CD F-6 Pillar 4 substrate + Rule (class_affinity derived from #9) | integration | BLOCKING | `tests/integration/loot/test_class_affinity_derived_from_workout.gd` |
| **AC-43** | **(Pass 2 F-7 NEW BLOCKING)** **GIVEN** `loot.daily_token_used.<utc_date>` namespace already contains key for `today_utc()` (daily token consumed earlier same UTC day) **WHEN** second `workout_completed(workout_id_B, ...)` signal fires same UTC day **THEN** NO `loot_dropped` event emitted for daily-source; `loot_daily_token_skipped(workout_id=workout_id_B, reason="already_consumed_today")` telemetry fires; mini-boss / final boss triggers still active (independent budget per Rule 1 + Rule 2) | Rule 2 daily token gate + EC-14 | unit | BLOCKING | `tests/unit/loot/test_daily_token_gate_second_workout_same_day.gd` |
| **AC-44** | **(Pass 2 F-8 NEW BLOCKING — EC-22 CRITICAL coverage)** **GIVEN** backend ACK response contains `rarity_tier = "MYTHIC"` (not in client RarityTier enum) **WHEN** `LootDropParser.parse_backend_ack()` processes response **THEN** parse rejects with controlled fallback (treat as timeout per EC-18 retry path); `loot.backend.unknown_tier` CRITICAL alert telemetry emitted; client does NOT crash; client does NOT accept unknown tier value; client does NOT silently default to COMMON (must alert humans for backend contract violation) | EC-22 + Rule 11 server authority + INV-4 enum consistency | unit | BLOCKING | `tests/unit/loot/test_backend_unknown_rarity_tier_fallback.gd` |

### Coverage Map

**Core Rules (18/18 covered)**:
- Rule 1 trigger sources: AC-22, AC-32
- Rule 2 daily token gate: AC-23, AC-32
- Rule 3 daily drop timing: AC-31
- Rule 4 mini ceiling: AC-03
- Rule 5 final floor: AC-04
- Rule 6 ceremony cap: AC-06, AC-07
- Rule 7 idempotency: AC-21
- Rule 8 zero-workout COMMON: AC-05
- Rule 9 idempotency invariant: AC-21, AC-22
- Rule 10 deterministic RNG: AC-20, AC-26
- Rule 11 server authority: AC-08, AC-41
- Rule 12 debug surface: AC-25
- Rule 13 FIFO reveal queue: AC-19, AC-39
- Rule 14 pending TTL: AC-10, AC-11
- Rule 15 catch-up reveal: AC-18, AC-19
- Rule 16 Private Mode gate: AC-23, AC-24
- Rule 17 bfcache reconcile: AC-12, AC-13, AC-31
- Rule 18 schema versioning + caller whitelist: AC-27, AC-28, AC-30, AC-35, AC-37

**Formulas (10/10 covered)**:
- F1 → AC-03, AC-04, AC-05
- F2 → AC-06, AC-07
- F3 → AC-10, AC-11
- F4 → AC-12, AC-13
- F5 → AC-09, AC-31
- F6 → AC-18, AC-19
- E1 → AC-15
- E2 → AC-16
- E3 → AC-14
- E4 → AC-17

**INVs (11/11 covered)**: INV-1 → AC-36; INV-2 → AC-37; INV-3 → AC-11; INV-4 → AC-30; INV-5 → AC-27; INV-6 → AC-36; INV-7 → AC-21; INV-8 → AC-34; INV-9 → AC-06, AC-07; INV-10 → AC-03, AC-04; INV-11 → AC-05.

**Critical ECs covered** (8 of 10 CRITICAL): EC-01 (AC-23), EC-03/04 (AC-29, AC-36), EC-17 (AC-33), EC-31 (AC-20), EC-34 (AC-25), EC-39 (AC-41), EC-40 (AC-37), EC-48 (AC-33 rollback)。

**Fantasy Risks (3 FRs + 3 FTs)**: FR-1 → AC-02, AC-38, AC-41; FR-2 → AC-39; FR-3 → AC-32, AC-31; FT-1 → AC-40; FT-2 → AC-38; FT-3 → AC-39。

### Test Distribution Summary (Pass 2 revised)

| Type | Count | Notes |
|------|-------|-------|
| unit | 24 | F1-F6 + E1-E4 + INV asserts + Pillar 1 proofs + **AC-43 daily token gate** (F-7) + **AC-44 unknown rarity tier fallback** (F-8) |
| integration | 12 | Multi-system + boot + 5-step lifecycle + reconcile + telemetry alert + AC-42 class_affinity Pillar 4 derivation |
| static-analysis | 5 | CI lint suite (AC-26..30 covers all 7 lint scripts; force_drop runtime via AC-25, ceremony_cap via AC-06) |
| manual/playtest | 0 BLOCKING + 4 ADVISORY | **AC-38 / AC-39 / AC-40 / AC-41 all ADVISORY** per Pass 2 F-9 (Testing Standards compliance: catch-22 with pre-merge gate; playtest evidence not pre-mergeable) — interview/screenshot infrastructure tracked LOOT-AC-followup-07/08 |
| composite | 1 | AC-31 bfcache → reconcile → reveal end-to-end |
| **Total** | **44** | Pass 2 (+AC-43 daily gate, +AC-44 EC-22 coverage) |

### Followup-Tracked Items (DESIGN-OPEN deferred)

| ID | Item | Resolution Path |
|----|------|----------------|
| LOOT-AC-followup-01 | AC-38 tooltip exact copy | Defer to #21 Loot Drop Modal ux-designer pass |
| LOOT-AC-followup-02 | AC-41 PagerDuty integration | Defer to #28 Telemetry GDD + DevOps on-call schedule |
| LOOT-AC-followup-03 | AC-37 transition_id regex final form | Defer to ADR-0006 Contract 2 ratification |
| LOOT-AC-followup-04 | AC-40 screenshot-share telemetry hook vs survey | Defer to playtest protocol design (#28 telemetry) |
| LOOT-AC-followup-05 | **CD F-8** LEGENDARY re-roll economy (EC-38 100 shards throughput) | Defer to #17 Equipment & Inventory GDD authoring — evaluate shards-to-LEGENDARY craft ratio; if <5 crafts, raise to 200-300 shards or restrict to cosmetic-only currency |
| LOOT-AC-followup-06 | **CD F-12** Fantasy literal-ization (loot metadata = body's receipt) | Cross-system contract with #17 Equipment: evaluate per-LootDrop metadata schema carrying source workout signature (date + PR snapshot + volume snapshot)。If adopted, LEGENDARY drops MUST carry source receipt; inventory UI surfaces on hover/inspect。Aligns 「Stamped by 180kg × 5」microcopy (F-5) into structural data |
| LOOT-AC-followup-07 | **Pass 2 F-9** AC-38 attribution telemetry infrastructure | Spec needed for: (a) interview protocol owner (proposed: qa-lead protocol, qa-tester execution); (b) verbal-attribution coding scheme (「earned/值得」vs「lucky/好彩」classifier rubric); (c) ≥40% extended threshold operational definition |
| LOOT-AC-followup-08 | **Pass 2 F-9** AC-40 screenshot test infrastructure | Spec needed for: (a) share-button telemetry hook event name + payload schema (proposed: `loot_share_button_pressed(drop_id, time_since_reveal_ms)`); (b) 60s observation window scoring rule; (c) cohort sampling methodology (#28 Telemetry GDD ownership) |
| LOOT-AC-followup-09 | **Pass 2 F-10** Hardcore inventory pressure (MAX_INVENTORY=60 vs 30 drops/week) | Interim Pass 2 fix: raise MAX_INVENTORY = 120 (config-driven, no GDD change needed). Long-term: #17 Equipment & Inventory GDD authoring time — auto-convert duplicates to shards at source OR introduce stash tier. With MVP 5 items, duplicate flood is structural certainty within 14 days at Hardcore profile |
| LOOT-AC-followup-10 | **Pass 2 F-11** Ceremony Choreography Sub-Document | Single followup spec covering: (a) mid-set deferral queue behavior (defer ceremony to rest period?); (b) post-set burst pacing for catch-up reveal (currently 0.15s fixed — needs game-designer tuning); (c) micro_ack tier audio/visual finalization (F-3); (d) low-score-day emotional framing (game-designer A1). Owner: game-designer + audio-director joint |
| LOOT-AC-followup-11 | **Pass 2** Followup ADR-007 candidate (signal payload schema convention) | F-1 揭示 cross-system gap — boss_killed/enemy_killed/workout_completed signal payload conventions 應該由 ADR 統一。Proposed scope: workout-bound event signals MUST declare workout_id resolution path (direct payload OR upstream-system query helper). Owner: technical-director |
| LOOT-AC-followup-12 | **Pass 2** ADR-RATIFICATION-GATED AC reclassification | AC-23/24/35 (gated on ADR-0003) + AC-37 (gated on ADR-0006) currently classified ADR-RATIFICATION-GATED。Per `.claude/docs/technical-preferences.md` ADR log, ADR-0003 AND ADR-0006 both Accepted。Reclassify all 4 to plain BLOCKING in Pass 3 (defer to Pass 3 fresh-session reviewer to confirm ADR status independently) |

### CD-GDD-ALIGN Verdict — Pass 1 (2026-05-28 inline same-session, APPROVED retrospectively rescinded)

> **Verdict: CONCERNS (acceptable with deferral path)** — creative-director Opus tier
> 12 findings (4 ALIGN + 1 ADVISORY + 6 CONCERN + 1 promotion-recommended)。
> **Inline-resolved same-session**: F-3 (cap=6 rationale → Rule 6) + F-4 (daily NO pity boundary → Rule 2) + F-5 (FR-1 emotional microcopy → Section B FR-1) + F-6 (class_affinity Pillar 4 substrate → Formula E2 clarification + AC-42 new BLOCKING) + F-9 (AC-38 + AC-40 promoted ADVISORY → BLOCKING) + F-10 (anti-pillar drift guard → Overview header)
> **Deferred to followup-tracked items**: F-8 (LEGENDARY re-roll economy → #17 cross-system) + F-12 (loot metadata receipt schema → #17 cross-system)
> **No-action ALIGN findings**: F-1 (anti-fabrication chain integrity) + F-2 (ADR-0005 formula faithfully implemented) + F-7 (mini/final boss rules already explicit in Rule 4/5) + F-11 (Q-OQ resolution paths)
> **Pass 1 status**: APPROVED inline same-session — **rescinded by Pass 2 fresh-session re-review** (inline same-session approvals miss convergent structural defects only visible across independent specialists)

### CD-GDD-ALIGN Verdict — Pass 2 (2026-05-28 fresh-session re-review)

> **Verdict: MAJOR REVISION NEEDED** — creative-director Opus tier senior synthesis
> 4 independent specialists in fresh session: game-designer + systems-designer + economy-designer + qa-lead
> **12 Pass 2 findings**: F-1..F-8 BLOCKING (inline-fix this session) + F-9 ADVISORY (catch-22 downgrade) + F-10..F-12 DEFER-FOLLOWUP
> **Convergent patterns surfaced**:
> 1. **Signal payload schema gap** (F-1) — UNANIMOUS structural defect (systems B1 + qa-lead AC-06)。boss_killed/enemy_killed 唔帶 workout_id，F2 ceremony_cap_check key 不可實現。Fix: #15 calls `WorkoutStateTracker.get_active_workout_id()` with explicit null branch (Rule 7.5 NEW)
> 2. **Final boss ceremony reservation** (F-2) — UNANIMOUS pillar inversion (economy B2 + game-designer B2)。6 mini + 1 final = 7 > cap=6 silent route final boss to mailbox = P3 PRIMARY substrate 倒轉。Fix: MINI_BOSS_CEREMONY_CAP=5 + FINAL_BOSS_RESERVED=1 split pools (Rule 6 + Formula 2 rewrite)
> 3. **micro_ack tier** (F-3) — game-designer B2。Mini-boss #6 silent = P1 violation (multi-effort 應被 acknowledged)。Fix: NEW ceremony state `micro_ack` between FULL_CEREMONY and silent (Rule 6 NEW spec + Formula 2 NEW enum)
> 4. **E3 termination guarantee** (F-4) — CONVERGENT correctness (systems C3 + economy B1)。Single-pass soft-clamp 可能 violate invariant。Fix: while-loop with max_iterations=10 + monotonic assert (Formula E3 rewrite)
> 5. **Mini-boss tier-ceiling gate** (F-5) — game-designer B1 fantasy contradiction。100% drop without workout-score gate 令 loot 變 exercise-completion token。Fix: dual-gate Rule 4 — source-event ceiling (RARE) + workout-score ceiling `floor(workout_score × 5)`
> 6. **Entitlement framing rename** (F-6) — game-designer B3。「daily guaranteed」拎走 entitlement 違反 game-concept「缺日只係 delay」spirit。Fix: rename「workout-locked daily」throughout
> 7. **AC-43 NEW** (F-7) — qa-lead B2 Rule 2 daily token uncovered。Fix: NEW BLOCKING unit AC
> 8. **AC-44 NEW** (F-8) — qa-lead B3 EC-22 CRITICAL uncovered。Fix: NEW BLOCKING unit AC
> 9. **AC-38/40/41 BLOCKING→ADVISORY downgrade** (F-9) — qa-lead Testing Standards catch-22。Fix: downgrade all three (followup-07/08 track infrastructure)
> 10. **Hardcore inventory pressure** (F-10) — economy C1。Fix interim: MAX_INVENTORY 60→120 (config-driven, no GDD change). Long-term: #17 cross-system
> 11. **Ceremony Choreography Sub-Document** (F-11) — multi-specialist deferred-ceremony cluster。Followup-10 single-spec
> 12. **Cross-system protocol gaps** (F-12) — F-1 揭示 ADR-007 candidate (signal payload schema) + ADR-RATIFICATION reclassify pending
> **Anti-pattern guards established (Pass 2)**:
> (1) Signal payload contracts MUST be declared in Dependencies section (F-1 generalized)
> (2) Floor + ceiling pattern for pillar tension (F-5 method)
> (3) Ceremony budget is finite resource requiring reservation logic (F-2/F-3 method)
> (4) Every Testing-Standards-downgraded AC needs paired followup spec (F-9 method)
> **Pillar substrate post-fix**: P1 anti-fabrication chain 第六件套 restored (workout_id resolution closes ceremony-binding gap) / P3 PRIMARY substrate 修復 (final boss ceremony guaranteed) / P4 dominant-class derivation unchanged (Pass 1 F-6 still standing) / P5 decoupled (acceptable for #15, flag for downstream)
> **Status post-Pass 2 inline**: Pass 2 Revised — **awaiting Pass 3 fresh-session re-review** for independent verification per Pass 2 + Pass 1 precedent (inline same-session approvals proven insufficient for convergent structural defects)

---

## Open Questions

### Q-OQ1 — Mini-boss kill drop probability
**Question**: 每個 mini-boss kill loot drop 係 always (100%) 定 probabilistic (e.g. 70%)？
**Impact**: Pillar 3 ritual cadence balance — too frequent = devalues ceremony，too rare = breaks expected reward loop
**Resolution path**: economy-designer + game-designer 喺 Section C/D drafting 時決定（fresh session）。建議 always-drop 但 rarity 偏向 COMMON-UNCOMMON （Q-OQ1 → mini ceiling already locked UNCOMMON-RARE band per #16 Pass 3 economy E3 fix）
**Resolution owner**: game-designer
**Priority**: HIGH (gates Section C Core Rules)

### Q-OQ2 — Daily guaranteed drop scope
**Question**: "每日必爆 1 件" 嘅 "daily" 點定義？UTC midnight rollover / first-workout-of-day / 24-hour-since-last-drop？
**Impact**: 用戶喺 timezone 邊界 + cross-device 嘅體驗一致性
**Resolution path**: 參考 ADR-0003 wall-clock drift tolerance ±300s + ADR-0002 server_epoch_id 同步 mechanism。建議 server-authoritative：GymSys backend 判斷「today's guaranteed drop already issued」
**Resolution owner**: economy-designer + server team
**Priority**: HIGH

### Q-OQ3 — Private Mode loot disable contract
**Question**: ADR-0003 Tier 3 in-memory fallback 期間，loot 應該 (a) NEVER generate, (b) generate but warn, (c) generate-and-queue-for-when-IDB-recovers？
**Impact**: Pillar 3 hard guarantee「冇 silent loss」vs UX disruption
**Resolution path**: ADR-0003 line 139 已明確 "LootDrop grants DISABLED — `is_private_mode() → bool` gate"。本 GDD adopt option (a) — NEVER generate + show non-dismissible banner
**Resolution status**: ✅ RESOLVED by ADR-0003 reference
**Priority**: LOW (already locked)

### Q-OQ4 — Loot pending state durability + bfcache resume
**Question**: 玩家 trigger loot drop → 但喺 modal 開出之前 browser tab 被 bfcache suspend → 30 分鐘後返嚟，loot 點處理？
**Impact**: Pillar 3 ritual integrity — drop ritual 必須 deliver
**Resolution path**: ADR-0003 Conflict Resolution Rules priority 0.5 「loot_pending > 30 days hard cap → force reveal on boot」+ priority 1 「Local has unsynced LootDrop → Client wins」
**Resolution status**: ✅ Mostly resolved by ADR-0003，本 GDD 需 spec 「30-second 內 resume → fade-in modal continue ritual」vs「>30s resume → next-session boot 觸發 force reveal」
**Priority**: MEDIUM

### Q-OQ5 — Equipment item schema contract
**Question**: LootDrop 生成 Equipment item，但 #17 GDD 未寫 — 點定 item schema？
**Impact**: 全 LootDrop generation pipeline 依賴 Equipment schema
**Resolution path**: 喺本 GDD 定義 minimal contract `LootDrop.item_metadata: Dictionary` (un-typed payload until #17 authored)。#17 GDD authoring 時 reverse-define typed Equipment 從 item_metadata schema。
**Resolution owner**: economy-designer (本 GDD 寫 minimal contract) → systems-designer (full Equipment schema in #17)
**Priority**: HIGH (gates Section C)

### Q-OQ6 — Rarity tier display in non-modal context
**Question**: Loot 喺 inventory list / character screen 顯示時，rarity color 應該 dim (per art bible Layer Discipline) 還是 full saturation (Event Layer)？
**Impact**: Art bible Layer Discipline rule
**Resolution path**: 參考 P-06 rarity-color-tier pattern。建議 inventory list = dim corner badge (Character Layer 飽和度)，loot reveal modal = full Event Layer 100% saturation
**Resolution owner**: ux-designer + art-director (during #23 Inventory UI GDD)
**Priority**: LOW (post-MVP)

### Q-OQ7 — Anti-fabrication chain depth verification
**Question**: 喺 PR Detection 系統 (#18) 落地之前，volume_score 嘅 `pr_factor` component 點計？
**Impact**: ADR-0005 Pillar 1 floor proof 依賴 real-PR signal
**Resolution path**: ADR-0005 已有 provisional answer — `pr_factor = pr_count_today / max(1, pr_count_baseline)`，clamp [0.5, 2.0]。本 GDD 引用 ADR-0005 + flag for revisit when #18 GDD authored
**Resolution owner**: economy-designer (formula tuning) + systems-designer (caller schema)
**Priority**: MEDIUM

---

## Errata(2026-06-07 — #21 G-LM-4a 執行;source = loot-drop-modal.md Bidirectional sync flags)

> 以下條款已被 #21 APPROVED GDD + shipped code supersede。本節係 binding 修正記錄 — 原文唔改動,以本節為準。

1. **`#21.cancel_reveal()` call 方向** → 已被 shipped `loot_rollback` signal 取代(#21 subscribe,#15 emit)。
2. **Visual Spec Table hex(L1031-1034 Material 套)** → canonical = art bible §4.B / P-06(`#FFFFFF`/`#6FB87A`/`#4D8FD6`/`#9B5FCC`/`#FF8C42`);本表 hex 係樣板色孤例,doc-only error。
3. **micro_ack「0.15s toast」** → 0.15s = entrance beat(#21 F4);total visible ~1.5s(entry+plateau+fade)— 0.15s total 係 subliminal,違 Pillar 1 acknowledge。
4. **L204「micro_ack 維持 audio sting(降一 tier)」→ 撤** — toast 一律配 toast tick(low/mono);fanfare 音色家族獨家保留俾 modal(mid-set 無畫面 fanfare 違 Pillar 2;aggregated 跨 tier sting 無解)。
5. **Visual Spec Table「Audio Duck」列 stale** — per-tier −3..−16dB 同 shipped #4 衝突(flat −8dB、safe range −12–0、−16 出界);L1052「還原到 0dB」錯(Music base = −6dB);duck 深度/release 係 #4 own;L1054 CI duck-verify 指示一併撤。
6. **L1082 FR-2 anchor** —「emit 後 100ms 內 visual onset」喺 deferred reveal 下不可滿足 → re-anchor 做「reveal-trigger 後 ≤100ms」(#21 stage table;AC-8 structural + AC-9 wall-clock)。
7. **L1102「所有 RARE+ 仍各自獨立 ceremony」** → 被 #21 `K_CEREMONY_MAX=5` supersede(CD C-1:overflow RARE+ 喺 grid 有獨立 cell + rarity label 保 identity)。
8. **AC-18 + EC-28 catch-up 語意 stale** —「individual reveals skip in favor of single tap-to-burst」→ #21 contact-sheet model(stream + top-K ceremonies + grid)。
9. **LEGENDARY orbit drift cut from MVP**(#21 D2)— #7 冇 hold phase;freeze-as-hold 已兌現「定格喺 peak」;v0.2 重訪。

**Code-side 同步(2026-06-07,#21 story-017)**:`LootDrop` 加 `ceremony_kind` + `revealed` fields;`_reveal_pending` reveal queue 同 `_pending_drops` sync ledger 分離(backend ACK 永不蒸發未 reveal 件;dequeue 永不 skip commit rename);grant 時 `workout_score`/`rng_roll`/`rarity_score` 持久化落 `item_metadata`(#21 F2 breakdown 載體)。

**#4 catalog source 同步(G-LM-4 ⑦)**:`loot_fanfare_*` 觸發 caller = **#21 coordinator @ S0**(EG-1 precedent — data layer 唔 call play_sfx),唔係 #15;#4 GDD catalog source 列以此為準(#4-side erratum 隨 story-023)。
