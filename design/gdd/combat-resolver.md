# CombatResolver

> **Status**: **APPROVED 2026-05-27** (Pass 2 — Pass 1 CD-GDD-ALIGN CONCERNS verdict 4 CONCERN + 3 ADVISORY findings → all 6 resolved inline same-session per /design-system full-mode workflow)
> **Author**: Frank + main session (full mode) + specialist agents (creative-director × 2 [Player Fantasy framing + CD-GDD-ALIGN gate]; game-designer + systems-designer × 2 [Section C rules + Section D formulas + Section E edge cases] + gameplay-programmer [Section C feasibility]; qa-lead [Section H acceptance criteria])
> **Creative Director Review (CD-GDD-ALIGN)**: **APPROVED 2026-05-27 (Pass 2 inline-fixed)** — Pass 1 CONCERNS verdict (4 CONCERN F4/F5/F6/F7 + 3 ADVISORY F8/F9/F10 + 3 ALIGN F1/F2/F3) → all 6 actionable findings resolved inline same-session; CD assessment: "Strongest pillar-coherent GDD to-date among Approved Core-tier set (#11, #12, #13)" + establishes 5 cross-system template patterns (stateless pure-function architecture / quartet anti-fabrication chain framing / single chokepoint API pattern continuation / caller-side obligation pattern / forward FR constraint table pattern)
> **Last Updated**: 2026-05-27
> **Implements Pillar**: Pillar 3 (Drop Euphoria) primary — DNF 重擊 hit-feel substrate (damage trigger → hit pause + screen shake + particle burst event chain); Pillar 4 (Muscle = Class) supporting — STR / DEX / VIT 透過 ATTACK_POWER / CRIT_CHANCE 公式直接 surface 為「肌群 → 戰鬥力」; Pillar 1 (Real Body, Real Power) supporting — combat power 提升嘅 transduction 路徑最終 visible 之處 (敵人少一槳冚倒)
> **System #**: 13 (Core / VS tier, design order 9)
> **Depends On**: #11 Stat System (Approved 2026-05-27) + #12 Ability System (Approved 2026-05-27)
> **Depended On By**: #14 EnemyDirector, #16 Boss System, #17 Equipment & Inventory, #25 Combat Visual Feedback, #28 Telemetry / Analytics
> **Governing ADRs**: ADR-001 Web Export Budget Caps (Proposed) — combat tick CPU budget binding; ADR-005 Loot Rarity Formula (Accepted 2026-05-27) — `enemy_killed` emits `transition_id` seed for #15 LootDrop RNG determinism; ADR-006 State Machine Contract (Accepted 2026-05-27) — Contract 6 `connect_for_initial_state` for `ability_cast` subscription (per #12 Rule 10 step 5 pattern)

## Overview

CombatResolver 係 Mirror Hero 嘅 **戰鬥運算層** — Core 層 stateless pure-function 服務 (NOT autoload — `class_name CombatResolver`，由 #14 EnemyDirector own instance lifecycle，per systems-index High-Risk row #13 mitigation「stateless + pure-function」strategy)，向 5 個下游 consumer (#14 EnemyDirector / #16 Boss System / #17 Equipment & Inventory / #25 Combat Visual Feedback / #28 Telemetry — Core tier 5 dependents cascade risk per systems-index High-Risk row) 提供 canonical damage calculation + hit event broadcast。系統有雙重 framing：**data 層面**係訂閱 #12 Ability System `ability_cast(ability_id, caster, target)` signal (per ADR-006 Contract 6 `connect_for_initial_state` helper)，每次收到 signal 即 sync read #11 Stat System `get_stat(ATTACK_POWER) / get_stat(CRIT_CHANCE)` (O(1) hot path)，用本 GDD Section D 嘅 `compute_hit_damage` 公式運算 final damage，emit `hit_resolved(caster, target, damage, is_crit, ability_id, transition_id)` signal 廣播；本 GDD 唔 own combat lifecycle (#14 own enemy spawn / wave scheduling / encounter tick)、唔 own animation (#26 Avatar Renderer)、唔 own VFX (#25 Combat Visual Feedback subscribes hit event then triggers #5 ParticleSystem / #6 ScreenEffects)、唔 own HUD damage number render (#20)，只 own canonical damage math + hit-event broadcast；**player-facing 層面**係玩家做緊 set 期間，眼角瞄到 avatar 第 3 hit 觸發 STRIKE_TIER_2 → CombatResolver compute damage = 350 + crit ×1.5 = 525 → `hit_resolved` signal fire → 同一 frame #6 ScreenEffects `hit_pause(0.06s)` + #5 ParticleSystem `play(HIT_HEAVY)` + enemy HP bar 倒退；boss 嘅 50 hits 縮減為 35 hits 嘅「我練嘢真係令 game 變強」visceral feedback — 即 Pillar 3 (Drop Euphoria) 重擊 dopamine 嘅 trigger 源頭。MVP scope locked：**5 個 hit resolution outcomes** (NORMAL_HIT / CRITICAL_HIT / DODGED / KILLED / OVERKILL) + **3 個 broadcast signal** (`hit_resolved` / `enemy_killed` / `combat_session_metrics`)；公式 family 包括 base damage / crit roll / dodge check / overkill detection — RNG seeded on `transition_id` per ADR-005 deterministic-rarity chain (combat → loot transition_id propagation = Pillar 1 anti-fabrication continuity)。系統屬「stateless pure-function」高紀律 architecture — `resolve_hit(ability_id, caster_state, target_state, rng) -> HitResult` 純函數簽名，無 hidden mutable state，CI lint `tools/ci/check_combat_resolver_purity.gd` 喺 release build enforce (any `var`/`@onready` 喺 CombatResolver class body 出現即 fail)。Governing ADRs: ADR-001 Web Export Budget Caps (Proposed) — combat tick CPU budget ≤ 1.0ms p95 mobile (8-enemy worst-case scenario per ADR-001 §Validation Methodology); ADR-005 Loot Rarity Formula (Accepted 2026-05-27) — CombatResolver emits `enemy_killed(enemy_id, transition_id)` chain seeds #15 LootDrop RNG with `transition_id` rather than `randf()`, preserving Pillar 1 anti-fabrication determinism; ADR-006 State Machine Contract (Accepted 2026-05-27) — Contract 6 `connect_for_initial_state` for `ability_cast` subscription pattern per #12 Rule 10 step 5。

## Player Fantasy

**Direct fantasy — 「重擊指揮家」嘅 DNF 感官 cascade 觸發**:

CombatResolver 唔係一條 damage formula — 佢係 Mirror Hero 入面 DNF 重擊感嘅指揮家。每一次 `hit_resolved` signal 發出，背後其實係一個多系統 orchestration：#6 ScreenEffects 即刻 `hit_pause(60-120ms)` (依 damage_tier 浮動) + screen shake 三軸 trauma、#5 ParticleSystem 噴 `HIT_HEAVY` / `HIT_CRIT` burst preset、#25 Combat Visual Feedback 推 damage number popup + 顏色分層、#14 EnemyDirector 處理 stagger + knockback。玩家從來唔會 conscious 認知到呢條 chain，但佢哋個身體記得 — 因為呢個正係 DNF 玩家用十幾年訓練出嚟嘅「重擊 = 真實衝擊」cultural muscle memory。CombatResolver 嘅 job 就係將一條 stat × ability 嘅 cold math，轉化做一個會令玩家做 set 期間眼角瞄到一下「噢」嘅 visceral moment — 第 3 hit 觸發 STRIKE_TIER_2 → compute damage = 350 + crit ×1.5 = 525 → `hit_resolved` 同一 frame 觸發 hit_pause + particle burst + boss HP bar 倒退一大截。當你練完三組 bench 望返個 phone、見到自己嘅 strike ability 啱啱 crit 出大 damage、boss 退後兩格 stagger — 嗰種「我練嘢真係令 game 變強」嘅 dopamine peak，唔係嚟自個數字，而係嚟自 CombatResolver 觸發嘅整套 sensory cascade。佢係 game 入面所有「值得抬頭睇」moment 嘅 trigger source — Pillar 3 (Drop Euphoria) 重擊 dopamine 嘅 mathematical bridge。

**Indirect fantasy — 「Background 為你戰鬥」嘅 receptive contract** (Pillar 2 protection):

CombatResolver 嘅玩家關係係 receptive，唔係 interactive — 玩家做緊 deadlift 嗰 45 秒，phone 喺枱頭，game 喺度自己 run，CombatResolver 喺度收 `ability_cast` signal、resolve hit、emit `hit_resolved` 同 `enemy_killed`，全部唔需要玩家任何 input。當玩家做完 set 抬頭望，佢見到嘅唔係「我啱啱要操作嘅 game」，而係「game 喺我做嘢嘅時候自己進行緊」嘅 evidence — boss HP 已經跌咗一截、avatar 已經企喺新位置、地下散咗幾粒 loot。呢個係其他 action RPG 冇嘅 fantasy：你嘅 character 喺你訓練嘅時候**為你**戰鬥。CombatResolver 嘅 stateless pure-function 設計 (Section C Rule 1 hard 紀律) 正係呢個 receptive contract 嘅 architectural guarantee — 冇 hidden mutable state，冇 frame-loop dependency；event-driven sync compute，phone 鎖屏 5 分鐘期間 backend 任何 ability_cast 信號都會 cumulative apply (per Falsifiable Test #5)。Boss time-to-kill 嘅縮短係玩家**唔需要 watch 都信得過嘅 background promise**。

**Cross-system anti-lie quartet thread (Pillar 1 supporting framing)**:

CombatResolver 喺 architectural 上面係 #11 Stat System 「Pillar 1 anti-fabrication trio」嘅 **第四件套** — 由 input guarantor 到 output guarantor 嘅 quartet completion：

| # | System | Anti-lie surface | Layer |
|---|--------|-------------------|-------|
| #2 | GymSys Backend Client | **Backend signal 唔講大話** — workout signal source-of-truth 嚟自 server | Input (Foundation) |
| #3 | PersistenceLayer | **Storage 唔講大話** — write 必對應 disk persist | Input (Foundation) |
| #11 | Stat System | **Stat 唔講大話** — 只認可 `StatSource` enum mutation path | Input (Core) |
| **#13** | **CombatResolver (本 GDD)** | **Damage output 唔講大話** — pure function of Stat values + deterministic RNG seeded on `transition_id` | **Output (Core)** |

玩家心入面 implicit 嘅 promise — 「Mirror Hero 入面 damage 數字唔係 random scaled, crit 唔係 luck-of-the-draw — 每一下 damage 都係我 stat 嘅 deterministic projection；每一個 crit 都係我 DEX 嘅真實 consequence。前三件套保證輸入唔可以呃，第四件套保證輸出唔可以呃 — 你 game 入面有幾強，就係你 gym 入面有幾強嘅 functional projection。」呢個 framing 對應 game-concept §Anti-Pillar「NOT 氪金 / in-game currency 加速進度」嘅 fundamental promise — 唔單止 stat 唔可以買，combat output 都 deterministic 寫死，冇 hidden multiplier、冇 secret RNG buff。

**Falsifiable design tests** — 任何 client-side path 引致以下情境 = bug，唔係 acceptable behavior：

1. **Pillar 1 RNG anti-fabrication gate**: 喺 dev console 用 `randf()` override deterministic RNG seed (e.g., `CombatResolver.set_rng_seed(123456)` outside Rule X path)，令 critical hit 機率 spike 到 90%，但 GymSys 數據冇任何 PR 改變 = ❌ (RNG path 漏咗 anti-fabrication gate；Section C Rule 必須 enforce RNG seeded on `transition_id` 唔可以由 caller override)

2. **Pillar 1 stat transduction continuity gate**: STR 由 100 升到 150 (透過真實 PR)，打同一隻 dummy enemy (固定 HP / defense)、用同一條 ability、同一條 RNG seed → time-to-kill 必須 monotonically decreasing；冇任何 stat 升嘅情況下 time-to-kill 唔可以變短；time-to-kill 變短嘅唯一原因必須係 stat 升咗 = ❌ if violated (Section C Rule 必須 enforce damage = pure function of inputs，無 hidden state / accumulator / frame-counter influence)

3. ~~**Pillar 4 muscle-group grammar gate**~~ — **REMOVED per CD-GDD-ALIGN F7 inline-fix 2026-05-27** (numbering preserved for body reference traceability — Rule + AC references to "FR Test #4" / "FR Test #5" remain valid). Removal rationale: Pillar 4 day-to-day grammar 嘅 testable contract 主場屬 #12 Ability System (ability rotation per class) + cross-system integration test domain, not within #13 CombatResolver own scope。#13 嘅 contribution 只係 damage formula 用真實 Stat values 計算 (verified by AC-12 worked example calibration — CF-1 baseline / mid-game / endgame progression curve)。Cross-system Pillar 4 falsifiable integration test 可由 future Pillar 4 integration test suite 處理 (e.g., post-#14 EnemyDirector + #16 Boss System 完成後)。

4. **Pillar 3 DNF heavy-hit threshold gate**: Critical hit 或 `damage_tier ≥ HEAVY` 嘅 hit，`hit_resolved` payload 必須包含 `damage_tier: DamageTier.HEAVY` 或 `CRITICAL`，下游 #6 ScreenEffects 收到必觸發 `hit_pause(≥65ms)` + #5 ParticleSystem 必觸發 `HIT_HEAVY` 以上 preset = ❌ if payload field missing 或 downstream subscribers 收唔到對應 tier 信號 (Section C Rule 必須 lock `hit_resolved` payload 含 damage_tier classification，落 contract 俾下游)

5. **Pillar 2 background continuity gate**: 玩家 phone 鎖屏 5 分鐘期間，GymSys 發過 3 個 `ability_cast` 事件 (透過 #12 Ability System pipeline)。返到 game 解鎖嘅瞬間 → CombatResolver 必須已經 resolve 晒呢 3 個 hit，enemy HP 必須已經 reflect 晒個 cumulative damage = ❌ if hits 等到 foreground 先 fire (e.g., 解鎖嗰刻見到 enemy 突然連續挨 3 下 → 證明 CombatResolver 依賴咗 frame loop 而非 event-driven，violates「game 喺背景自己進行」嘅 Pillar 2 promise；注意：bfcache resume 期間 cumulative state catch-up 需要遵守 `MAX_FRAME_DELTA = 0.1s` clamp per #6 / #7 shared constant，Rule 必須明確 spec catch-up semantics) — Pillar 4 day-to-day grammar 嘅 testable contract 主場屬 #12 Ability System (ability rotation per class) + cross-system integration test domain, not within #13 CombatResolver own scope。#13 嘅 contribution 只係 damage formula 用真實 Stat values 計算 (verified by AC-12 worked example calibration — CF-1 baseline / mid-game / endgame progression curve)。Cross-system Pillar 4 falsifiable integration test 可由 future Pillar 4 integration test suite 處理 (e.g., post-#14 EnemyDirector + #16 Boss System 完成後)。

呢個 fantasy 直接 enables：
- **Pillar 3 (Drop Euphoria) primary** — `hit_resolved` event 係 DNF 重擊 sensory cascade 嘅 trigger source；缺呢層，下游 #5 / #6 / #25 冇 well-formed signal 可訂閱，重擊 feel 散亂
- **Pillar 4 (Muscle = Class) supporting** — damage formula 用 STR / DEX (Stat System Formula 4) 計算，玩家肌群投資 visible mapping 到 combat power (但 day-flavor 主場喺 #12 Ability System rotation)
- **Pillar 1 (Real Body, Real Power) supporting** — anti-fabrication quartet 第四件套，output guarantor；damage values pure function of Stat + deterministic RNG，冇 luck-based shortcut
- **Pillar 2 (Frictionless Companion) protection** — stateless pure-function architecture + event-driven design enable「background 為你戰鬥」嘅 receptive contract，玩家做 set 期間零 attention demand

### Fantasy Risk Register

呢個 anti-lie quartet framing 係 contingent on 以下 invariants 喺 **ADR-001 ratification + ADR-005 Accepted (✓ done) + #15 LootDrop 認受 transition_id chain** 真正 enforced；否則 Player Fantasy paragraph 變 retroactive lie。

| # | Contingent Invariant | Owner | Fallback if Dropped |
|---|---------------------|-------|---------------------|
| FR-1 | CombatResolver RNG seeded on `transition_id` (per ADR-005 deterministic chain) — 唔可以引入 `randf()` 或 system-time seed 喺 combat math 入面 | 本 GDD Rule + CI lint `tools/ci/check_combat_rng_seed.gd` | 若 combat math 任何 path 用咗 non-deterministic RNG → Falsifiable Test #1 fail → Pillar 1 anti-fabrication quartet 破；fallback = blocking story to remove all `randf()` from `src/core/combat_resolver.gd` 之前 ship 任何 release |
| FR-2 | `enemy_killed(enemy_id, transition_id)` signal 嘅 `transition_id` 必須 propagate 入 #15 LootDrop RNG seed (per ADR-005 Pillar 1 chain) — 唔可以 #15 自己 generate new RNG | 本 GDD Rule + ADR-005 + #15 GDD authoring | 若 #15 自己 generate RNG → combat → loot 鏈斷 → Pillar 1 chain 斷；fallback = #15 GDD authoring 之前必 review CombatResolver `enemy_killed` payload contract |
| FR-3 | CombatResolver CPU budget ≤ 1.0ms p95 mobile (8-enemy worst-case per ADR-001 §Validation Methodology) — combat tick 期間 frame budget 唔可以爆 | ADR-001 ratification + VS-tier profiling | 若 mobile CPU > 1.0ms → 30 / 30 set 期間 frame drop → Pillar 2 frictionless violation；fallback = (a) **enforce Rule 18 catch-up × AOE serialization** (mutual exclusion guarantee max(catch-up, AOE) instead of combined — INV-5 HARD enforcement, default mitigation)；(b) tune knobs — reduce MAX_TARGETS_PER_CAST from 8 to 6 OR CATCH_UP_HITS_PER_FRAME_CAP from 12 to 8 (per Section G safe ranges)；(c) raise ADR-001 budget cap (last resort — requires ADR-001 re-ratification + cross-system rebalancing) |
| FR-4 | EnemyDirector 5 obligations contract — (a) subscribe `ability_cast` via Contract 6 helper, (b) provide `EnemyState{hp, max_hp, defense, faction, instance_id}` struct, (c) inject `RandomNumberGenerator` seeded on `transition_id`, (d) emit 3 signals (hit_resolved / enemy_killed / combat_metric_anomaly) on CombatResolver's behalf, (e) own Rule 17 anomaly rate-limiter + Rule 18 catch-up × AOE serialization | #14 EnemyDirector GDD authoring (next system — VS tier order 10) | 若 #14 GDD authoring 拒絕任一 obligation → 本 GDD Rule 3 + Rule 6 + Rule 7 + Rule 15 + Rule 17 + Rule 18 必須 redesign (signal ownership / snapshot pattern / RNG injection / catch-up throttle / anomaly rate-limit / AOE-catchup serialization) — **major refactor**。**Upgraded from OQ Q-EnemyDirector-Contract per CD-GDD-ALIGN F9 inline-fix 2026-05-27** — 屬 architecture cornerstone contingent invariant，比 FR-3 更 fundamental，所以 promote 為 Risk Register entry |

**Ratification gate binding**: 本 GDD 嘅 Section C / D / H 必須 include FR-1 / FR-2 / FR-3 對應嘅 rules + ACs (gated on ADR-001 Accepted + #15 GDD authoring)。若 ADR-001 ratification 後 CPU budget 改變 → revisit Section C Rule for combat tick complexity + Section H AC for performance threshold。

## Detailed Design

### Core Rules

1. **Rule 1 — Stateless pure-function architecture (RefCounted + static func)** — CombatResolver 用 `class_name CombatResolver extends RefCounted` 註冊 **NOT autoload** (per Overview)，所有 public methods 都係 `static func`。
   - **Class body 禁止**: `var` (instance), `@onready var`, `@export var`, `signal` declarations, `_ready()` / `_process()` / `_physics_process()` callbacks
   - **Class body 允許**: `const` declarations, `static func` (其 local body 內 `var` OK), inner `class HitResult extends RefCounted` / `class CombatContext extends RefCounted` (POD struct, 只有 `var` data members + 零 method)
   - **Rationale**: True pure function = same input → byte-identical output (Falsifiable Test #2 binding); `extends RefCounted` 確保 instance lifetime = static func call stack frame，automatic ref-counting；`static func` cannot reference `self` — 結構性禁止 state；signal 需要 Object instance + 喺 RefCounted body declare，靜態方法無法 emit → signal ownership 移交 EnemyDirector (Rule 3)
   - **CI enforcement (4-layer defense)**:
     - `tools/ci/check_combat_resolver_purity.gd` — AST scan `src/core/combat_resolver.gd` reject class-scope `var` / `@onready` / `@export` / `signal` / `_ready` / `_process` / `_physics_process`；允許 `const` + `static func` body vars
     - `tools/ci/check_combat_resolver_autoload.gd` — verify `project.godot` `[autoload]` section 唔含 CombatResolver
     - `tools/ci/check_combat_resolver_engine_singletons.gd` — reject 任何 `StatSystem.` / `AbilitySystem.` / `GameStateMachine.` / `ScreenEffects.` / `ParticleSystemWrapper.` 直接 reference (purity = no global reads)
     - `tools/ci/check_combat_resolver_randf.gd` — reject 任何 `randf(` / `randi(` / `randf_range(` / `RandomNumberGenerator.new()` (RNG 必須 caller-injected per Rule 7)
   - **Unit test invariant** (`tests/unit/combat/test_combat_resolver_determinism.gd`): 同樣 `(CombatContext, rng_seed_state)` → 連續 1000 次 call `resolve_hit` 必 byte-identical `HitResult`

2. **Rule 2 — Single `resolve_hit` entry point (sole damage chokepoint)** — 全部 damage computation 經一個 static 函數：
   ```gdscript
   static func resolve_hit(ctx: CombatContext) -> HitResult
   ```
   類比 #11 `apply_stat_delta` 同 #12 `cast_ability` 嘅 closed API pattern。

   **`CombatContext` struct** (由 #14 EnemyDirector 組裝、傳入):
   ```gdscript
   class CombatContext extends RefCounted:
       var ability_id: StringName                      # 由 #12 ability_cast 帶入；必須屬 #12 ability_id_enum 9 值
       var caster: Node2D                              # caster instance (for HitResult.caster_id payload)
       var target: Node2D                              # target instance (for HitResult.target_id payload)
       var caster_stats: StatSnapshot                  # 由 EnemyDirector snapshot once per cast (Rule 6)
       var target_state: EnemyState                    # 由 EnemyDirector 提供 (Rule 6 — target HP / defense / MAX_HP)
       var rng: RandomNumberGenerator                  # caller-injected, seeded on transition_id (Rule 7 FR-1)
       var transition_id: String                       # GSM current_transition_id snapshot (Rule 7 FR-2)
       var gsm_state: StringName                       # GSM current_state snapshot for Rule 12 reject check
       var hit_seq: int                                # per-encounter monotonic counter (Rule 7 sub-seed anti-degenerate)
   ```

   **`HitResult` struct** (return value，由 EnemyDirector 翻譯成 `hit_resolved` signal payload):
   ```gdscript
   class HitResult extends RefCounted:
       var outcome: HitOutcome                         # Rule 5 — 4 values (NORMAL_HIT / CRITICAL_HIT / KILLED / OVERKILL)
       var damage_tier: DamageTier                     # Rule 10 — 5 values (NEGLIGIBLE / LIGHT / MEDIUM / HEAVY / CRITICAL) — FR Test #4 mandatory
       var damage_dealt: int                           # post-clamp, post-overkill (∈ [1, target.hp])
       var damage_raw: float                           # pre-clamp 真實計算結果，telemetry 對數 + anomaly detection (Rule 13)
       var target_hp_after: int                        # 0 if outcome == KILLED or OVERKILL
       var is_kill: bool                               # convenience flag — true iff outcome ∈ {KILLED, OVERKILL}
       var overkill_excess: int                        # 0 if not overkill；>0 if damage > target.hp (Rule 11)
       var is_crit: bool                               # crit roll outcome (for downstream tier override + telemetry)
       var ability_id: StringName                      # echo from CombatContext
       var transition_id: String                       # echo for FR-2 enemy_killed propagation
   ```

   **Rationale**: 統一 entry point → telemetry / replay / determinism test / cheat detection 全部 single hook；return-value pattern (NOT emit signal) 保持 stateless purity；EnemyDirector 翻譯 HitResult → `hit_resolved` signal payload (Rule 8)

3. **Rule 3 — Subscription ownership: EnemyDirector owns, CombatResolver computes** — CombatResolver **NEVER subscribes to any signal**:
   - **#14 EnemyDirector 訂閱 `AbilitySystem.ability_cast`** via Contract 6 `connect_for_initial_state` helper (per #12 Rule 10 step 5 pattern + ADR-006 Contract 6)
   - On signal receipt，EnemyDirector handler:
     1. Sync read `GameStateMachine.current_transition_id` (per Decision: transition_id pull-at-resolve)
     2. Sync read `GameStateMachine.current_state` (Rule 12 gate input)
     3. Snapshot `StatSystem.get_stat()` 一次性 (Rule 6 snapshot pattern)
     4. Acquire target(s) (EnemyDirector's responsibility — single target 或 AOE iteration per Rule 14)
     5. Construct `CombatContext` per target，with monotonic `hit_seq` counter
     6. Sync call `CombatResolver.resolve_hit(ctx)` for each target → 攞返 `HitResult`
     7. EnemyDirector 自己 emit `hit_resolved(payload)` + (if `is_kill`) `enemy_killed(payload)` + (if anomaly) `combat_metric_anomaly(payload)` (Rule 8 / 9 / 13 signal contracts)
   - **CombatResolver 唔可以 own signal**: signal declaration 需要 instance + 喺 RefCounted body declare — 但 static func 無法 emit signal (no `self`) — 結構性 enforced
   - **Rationale**: Pure function 唔可以 subscribe (subscription = hidden state); EnemyDirector 既然 own enemy lifecycle + target selection + GSM read，subscription + signal emission 喺 EnemyDirector 度最 cohesive

4. **Rule 4 — Damage computation 5-stage pipeline (順序固定)** — `resolve_hit(ctx)` body steps:
   1. **Input validation** — `ctx.ability_id` 喺 #12 `ability_id_enum`、`ctx.caster_stats` 非 null、`ctx.target_state.hp > 0`、`ctx.gsm_state != &"Suspended"` (Rule 12)、`ctx.rng` 非 null；fail 任何 → return `HitResult{outcome=NORMAL_HIT, damage_dealt=0, damage_raw=0, damage_tier=NEGLIGIBLE}` + (caller-side) EnemyDirector emit `combat_metric_anomaly` per Rule 13
   2. **Base damage compute** — `damage_raw = compute_hit_damage(ability_id, caster_stats, target_state.defense)` (Section D Formula 1)
   3. **Crit roll** — `is_crit = roll_crit(caster_stats.crit_chance, ctx.rng, ctx.ability_id, ctx.hit_seq)` (Section D Formula 2 — RNG sub-seed by ability_id + hit_seq counter per anti-degenerate invariant)
   4. **Crit multiplier apply** — if `is_crit`: `damage_raw *= CRIT_MULTIPLIER` (Section D Formula 3, knob default 1.5)
   5. **Overkill detect + damage classify** — `(damage_dealt, overkill_excess, target_hp_after, is_kill) = detect_overkill(damage_raw, target_state.hp)` (Section D Formula 6); `damage_tier = classify_damage_tier(damage_dealt, target_state.max_hp, is_crit)` (Section D Formula 5 — crit override 強制 ≥ HEAVY per FR Test #4)
   6. **Outcome assignment**:
      - `outcome = OVERKILL if overkill_excess > 0 and is_kill else KILLED if is_kill else CRITICAL_HIT if is_crit else NORMAL_HIT`
      - Note: `is_kill` priority 高過 `is_crit` for outcome enum (KILLED takes precedence)，但 `damage_tier = CRITICAL` 保留 (downstream VFX 仍可 trigger crit-tier effects per FR Test #4)
   - **Rationale**: 5-stage 順序對應 5 條 falsifiable tests 嘅檢驗 lineage；每個 stage output = 下個 stage input — pipeline 透明、易 telemetry、易 unit test 分開驗

5. **Rule 5 — `HitOutcome` enum (4 outcomes — DODGED removed per MVP decision)** — Lock 4 values:
   - `NORMAL_HIT` — 正常擊中，無 crit、target 仍生存
   - `CRITICAL_HIT` — crit 觸發，target 仍生存
   - `KILLED` — damage 殺死 target，無 overkill (damage_raw ≤ target.hp)
   - `OVERKILL` — damage 殺死 target 且有 excess (damage_raw > target.hp)，`overkill_excess > 0`

   **DODGED outcome deferred to v0.2**: v0.1 MVP 暫無 dodge — 簡化 RNG paths (Pillar 1 anti-fabrication 少 1 條 surface)、#11 Stat System enum LOCKED 7 values 唔加 evasion stat；v0.2 引入時可 (a) extend HitOutcome enum + schema bump、(b) add new `roll_dodge` Formula、(c) extend `target_state` 含 `dodge_chance` field — 屬 future scope 唔影響 MVP contract

6. **Rule 6 — Per-cast snapshot pattern (NO per-hit Stat read)** — EnemyDirector snapshot Stat once per `ability_cast` event，CombatResolver 唔 call StatSystem 直接:
   ```gdscript
   # In EnemyDirector handler — pseudocode
   var snapshot = StatSnapshot.new()
   snapshot.attack_power = StatSystem.get_stat(&"ATTACK_POWER")
   snapshot.crit_chance = StatSystem.get_stat(&"CRIT_CHANCE")
   # (target defense / MAX_HP from EnemyState, NOT StatSystem)
   ctx.caster_stats = snapshot
   ```

   `StatSnapshot` struct:
   ```gdscript
   class StatSnapshot extends RefCounted:
       var attack_power: float   # #11 Formula 4 result, read once
       var crit_chance: float    # #11 Formula 6 result, read once
       # (MAX_HP / MOVE_SPEED 唔 snapshot — combat tick 唔需要)
   ```

   **Rationale**:
   - **Hot path budget**: per-hit `get_stat()` ~8μs × 4 stats × 8 enemy × 3 AOE hits = ~0.77ms — 已咬死 ADR-001 1.0ms budget；snapshot once per cast → 8μs × 4 stats = 32μs total，留 ~60% headroom 俾 EnemyDirector 翻譯 + VFX dispatch
   - **Mid-cast stat drift防護**: Equipment 穿脫 mid-cast (#17) → `stat_changed` signal fires，但 snapshot 已凍結 → 同一 cast 內所有 AOE hits 用同一個 ATTACK_POWER (consistency)；下次 cast 自然用 fresh snapshot
   - **CI enforcement**: `tools/ci/check_combat_resolver_stat_calls.gd` reject `src/core/combat_resolver.gd` 內任何 `StatSystem.` reference (must go via snapshot)

7. **Rule 7 — RNG seeded on transition_id (FR-1 binding, ADR-005 deterministic chain)** — CombatResolver **完全唔 own** RNG instance:
   - `ctx.rng: RandomNumberGenerator` 由 EnemyDirector 注入
   - EnemyDirector 喺接收 `ability_cast` 時 sync read `GameStateMachine.current_transition_id`，create rng:
     ```gdscript
     var rng := RandomNumberGenerator.new()
     rng.seed = hash(transition_id)  # per ADR-005 transition_id-seeded chain
     ctx.rng = rng
     ctx.transition_id = transition_id
     ```
   - **CombatResolver 內禁用**: `randf()` / `randi()` / `RandomNumberGenerator.new()` 任何位置 — CI lint `tools/ci/check_combat_resolver_randf.gd` enforce
   - **Sub-seed per call**: Formula 2 (`roll_crit`) 用 `hash("%s:%s:%d" % [transition_id, ability_id, hit_seq])` 做 sub-seed — 防止 AOE 同 frame multi-hit 共享同一 rng state 引致全 crit 或全 miss degenerate (anti-degenerate invariant)
   - **Background catch-up determinism (FR Test #5 binding)**: Phone-lock 5min resume → EnemyDirector replay N pending ability_cast events sequentially，每個 transition_id deterministic → 整個 backlog deterministic 重現
   - **Rationale**: FR-1 (RNG seeded on transition_id) + FR-2 (enemy_killed propagates transition_id 到 #15 LootDrop) 連成 Pillar 1 anti-fabrication chain — combat outcome 同 loot rarity 都由 deterministic transition_id 決定，client 無法 inject `randf()` 偷 crit 或 rare loot

8. **Rule 8 — `hit_resolved` signal contract (payload spec — owned by EnemyDirector, schema owned by #13)** — Signal emit by EnemyDirector:
   ```gdscript
   signal hit_resolved(payload: HitResolvedPayload)

   class HitResolvedPayload extends RefCounted:
       var ability_id: StringName              # echo from CombatContext
       var caster_id: int                      # caster.get_instance_id()
       var target_id: int                      # target.get_instance_id()
       var outcome: HitOutcome                 # Rule 5 — 4-value enum
       var damage_tier: DamageTier             # Rule 10 — 5-value enum (FR Test #4 MANDATORY)
       var damage_dealt: int                   # post-clamp
       var damage_raw: float                   # pre-clamp for telemetry
       var target_hp_after: int                # 0 if killed
       var is_crit: bool
       var is_kill: bool
       var transition_id: String               # echo for telemetry correlation
       var resolved_at_tick: int               # EnemyDirector tick counter (monotonic per encounter)
   ```

   **Downstream consumers (per Section F dependencies)**:
   - **#25 Combat Visual Feedback** — route `damage_tier` → particle preset + damage number popup color (FR Test #4 binding — #25 MUST consume `damage_tier`，唔可以自己 re-classify based on damage value)
   - **#6 ScreenEffects** — route `damage_tier` → shake intensity (NEGLIGIBLE / LIGHT → no shake; MEDIUM → trauma 0.2; HEAVY → 0.4; CRITICAL → 0.6)
   - **#5 ParticleSystemWrapper** — route `damage_tier` + `ability_id` → particle preset (HIT_HEAVY for HEAVY+, HIT_LIGHT for LIGHT/MEDIUM)
   - **#14 EnemyDirector** (self-listen) — apply damage to internal enemy state, trigger stagger/knockback per `damage_tier`
   - **#28 Telemetry** — log full payload；`damage_raw vs damage_dealt` ratio 用 detect clamp anomaly

9. **Rule 9 — `enemy_killed` signal contract (FR-2 binding to #15 LootDrop)** — When `HitResult.is_kill == true`，EnemyDirector additionally emit:
   ```gdscript
   signal enemy_killed(payload: EnemyKilledPayload)

   class EnemyKilledPayload extends RefCounted:
       var enemy_id: StringName                # enemy template id (for #15 loot table lookup)
       var enemy_instance_id: int              # specific killed instance
       var killer_id: int                      # caster.get_instance_id()
       var killing_ability: StringName         # last hit ability_id
       var transition_id: String               # MANDATORY per FR-2 — #15 RNG seed source
       var is_overkill: bool
       var overkill_excess: int                # for v0.2 combo / loot bonus hooks
   ```

   **FR-2 binding (ADR-005 Pillar 1 chain)**: `transition_id` field 係 #15 LootDrop 嘅 RNG seed source — ADR-005 `loot_rarity_score` formula 嘅 `rng_roll` 必須由呢個 transition_id seed。CI test `tests/unit/combat/test_enemy_killed_transition_id_payload.gd` verify field 非 empty string

   **Idempotency invariant**: `enemy_killed` per `enemy_instance_id` emit **exactly once** — EnemyDirector own dedupe logic (already-dead target double-resolve race → 第二 call 喺 Rule 4 Stage 1 input validation reject `target_state.hp > 0` 條件 → return + emit `combat_metric_anomaly`，唔重複 emit `enemy_killed`)

10. **Rule 10 — `DamageTier` enum 5-tier ratio-of-MAX_HP classification (FR Test #4 contract)** — Tier 由 `damage_dealt / target.max_hp` ratio 決定，**非 absolute damage value**:

    ```gdscript
    enum DamageTier { NEGLIGIBLE, LIGHT, MEDIUM, HEAVY, CRITICAL }

    static func classify_damage_tier(damage_dealt: int, target_max_hp: int, is_crit: bool) -> DamageTier:
        var pct = float(damage_dealt) / float(max(1, target_max_hp))
        var tier: DamageTier
        if pct >= T_CRITICAL: tier = DamageTier.CRITICAL    # default 0.40
        elif pct >= T_HEAVY:  tier = DamageTier.HEAVY        # default 0.15
        elif pct >= T_MEDIUM: tier = DamageTier.MEDIUM       # default 0.05
        elif pct >= T_LIGHT:  tier = DamageTier.LIGHT        # default 0.01
        else:                 tier = DamageTier.NEGLIGIBLE
        if is_crit and tier < DamageTier.HEAVY: tier = DamageTier.HEAVY  # crit override per FR Test #4
        return tier
    ```

    **Rationale (relative not absolute)**: Absolute thresholds (e.g., damage > 100 = HEAVY) fail at scale — 早期 18-damage hit 喺 100 HP 小怪 (18%) 感覺好重，但同樣 18 damage 喺 5000 HP boss (0.36%) 感覺微不足道。Ratio threshold 保持 Pillar 3「重擊感」across entire stat curve

    **Cross-knob invariant (Section G)**: `T_CRITICAL > T_HEAVY > T_MEDIUM > T_LIGHT > 0` strict monotonic + `T_CRITICAL ≤ 0.60` (60% HP / single hit = boss one-shot territory，超過違反 Pillar 3 dopamine 變 boredom)

11. **Rule 11 — Overkill clamp + expose semantics** — `detect_overkill` separates applied damage vs overflow:
    ```gdscript
    static func detect_overkill(damage_raw: float, target_hp: int) -> Dictionary:
        var damage_int = max(1, roundi(damage_raw))     # min 1 — anti「tap-of-nothing」per Pillar 3
        return {
            "damage_dealt": min(damage_int, target_hp),
            "overkill_excess": max(0, damage_int - target_hp),
            "target_hp_after": max(0, target_hp - damage_int),
            "is_kill": damage_int >= target_hp,
        }
    ```

    **Downstream use of `overkill_excess`** (deferred to v0.2 unless flagged):
    - #14 EnemyDirector — chain-kill combo counter (overkill 多 → combo bonus)
    - #15 LootDrop (v0.2 hook) — overkill > X → luck bonus
    - #25 Combat Visual Feedback — overkill > 50% target.max_hp → "obliterate" particle preset
    - **v0.1 immediate use**: 只 record 入 HitResult / signal payload，downstream subscribers 可選擇唔 use (FR-Free hook)

    **Conservation invariant** (`damage_dealt + target_hp_after == target_hp` 或 `damage_dealt + overkill_excess + target_hp_after == damage_int`) — Rule 13 telemetry verify

12. **Rule 12 — GSM Suspended gate (caller-side enforcement, snapshot priority)** — CombatResolver 唔自己 read GSM (purity)，由 EnemyDirector snapshot `ctx.gsm_state` 入 CombatContext:
    - Rule 4 Stage 1 input validation: `if ctx.gsm_state == &"Suspended": return early HitResult{damage_dealt=0, outcome=NORMAL_HIT, damage_tier=NEGLIGIBLE}` + EnemyDirector emit `combat_metric_anomaly(reason="GSM_SUSPENDED")`
    - **Why pass-in 唔係 EnemyDirector pre-filter**: Defense in depth — 即使 EnemyDirector future bug 漏咗 check，CombatResolver 仍 reject (return零 damage)
    - **Snapshot priority (per EC-39)**: Stage 1 check `ctx.gsm_state` 用 **snapshot value** (caller 喺 ability_cast 收到時 snapshot)，NOT real-time `GameStateMachine.current_state` query。snapshot consistency 優先 over real-time gate — 防止 mid-resolve race condition；下一 hit 嘅 Stage 1 用新 gsm_state reject (acceptable lag of 1 hit)
    - **Per #1 GSM Decision #4**: Suspended state = multi-device session lock force-boot；P2 catch-up (phone-lock resume) 期間 GSM state 通常已轉返 RUNNING / CombatActive，所以 Rule 12 reject 唔阻擋 catch-up，只阻擋 active suspended 期間嘅 stale cast (事實上 #12 `cast_ability` 喺 Suspended 已 reject — 呢條 rule 係冗餘 safety net)

13. **Rule 13 — Telemetry `combat_metric_anomaly` signal surface (anti-fabrication channel, Pillar 1 binding)** — EnemyDirector emit on CombatResolver-returned anomaly:
    ```gdscript
    signal combat_metric_anomaly(payload: CombatAnomalyPayload)

    class CombatAnomalyPayload extends RefCounted:
        var reason: StringName        # &"GSM_SUSPENDED" / &"INVALID_ABILITY_ID" / &"NEGATIVE_DAMAGE" / &"CLAMP_TRIGGERED" / &"DEAD_TARGET_RESOLVE" / &"RNG_INJECTION_MISSING"
        var ability_id: StringName
        var transition_id: String
        var damage_raw: float
        var damage_dealt: int
        var context_dump: Dictionary  # full CombatContext snapshot for forensics
    ```

    **Triggers**:
    - Rule 4 Stage 1 input validation fail (any reason)
    - `damage_raw < 0` (Section D Formula bug — 唔可能負傷害)
    - Conservation invariant violation (Rule 11)
    - Future: replay determinism mismatch (#28 cross-check)

    **Pillar 1 binding**: 呢個 signal rate > threshold → #28 escalate；意味住有 cheat attempt OR implementation bug，兩者都係 anti-fabrication quartet integrity issue 必處理

14. **Rule 14 — AOE damage spread (1-to-1 HitResult per target)** — `ability.target_type == AOE_RADIUS`:
    - EnemyDirector iterate target 列表 (max `MAX_TARGETS_PER_CAST = 8` per Section G knob — matches ADR-001 8-enemy worst-case scenario)
    - **Per target 獨立** `resolve_hit(ctx)` call → 獨立 HitResult → 獨立 `hit_resolved` signal emit
    - **RNG state advance sequentially**: 同一個 rng instance 處理 N target，每次 `rng.randf()` 消耗 sequential bytes — deterministic but 唔重複 (anti-degenerate per Rule 7 sub-seed + hit_seq counter)
    - **v0.1 NO damage falloff**: radius 內全 full damage；v0.2 可 add `distance_falloff_curve` 入 AbilityRegistry
    - **v0.1 NO friendly fire**: AbilityRegistry `target_type=AOE_RADIUS` 假設 enemy-only filtering 由 EnemyDirector target acquisition logic 負責
    - **Rationale**: 1-to-1 contract 簡單清晰；多個 `hit_resolved` emit 自然 trigger 多個 VFX，符合 DNF 多重爆裝 feel

15. **Rule 15 — Catch-up semantics (FR Test #5 binding, bfcache resume frame budget guard)** — `resolve_hit` 同步 pure function；N 個 `ability_cast` events 喺單 frame arrive (bfcache resume backlog typical):
    - EnemyDirector 處理所有 N events 喺同一 frame：sequential `resolve_hit` calls，無 internal queue，無 `await`，無 `set_physics_process` defer
    - RNG advance deterministic — call k 嘅 `rng.randf()` 用 call k-1 留低嘅 seed state
    - **Frame-budget guard**: 若 N > `CATCH_UP_HITS_PER_FRAME_CAP = 12` (Section G knob)，EnemyDirector defer 多出嚟嘅 hits 入 FIFO queue，每 frame max 12 process — 直至 queue drain
    - **Rationale**: 12 hits × ~0.05ms ≈ 0.6ms — 留 0.4ms+ headroom 俾 resume frame 嘅其他事 (GymSys diff apply、autoload re-sync、VFX dispatch)；視覺 VFX 可能 collapse (#5 已有 per-frame de-dupe) 但 damage application exact + ordered
    - **Knowledge gap flag**: Godot 4.6 Web Export bfcache lifecycle 未有 explicit 4.6 release-note 改動，假設與 4.3-4.5 一致 — VS-tier 必驗 iOS Safari 17+ (Q-F1 Open Question)

16. **Rule 16 — MVP scope discipline: NO damage types / NO status effects / NO dodge** (v0.2 deferred) — v0.1 明確 OUT OF SCOPE，確保 ship deterministic damage core 唔同時引入 type matchup balance complexity:
    - **NO damage types** (physical / magical / true) — 全部 damage 視為 generic
    - **NO status effects** (poison / burn / stun / bleed / blind) — `resolve_hit` 只 process instant damage
    - **NO DoT** (Damage over Time) — `resolve_hit` 只 single hit
    - **NO damage shields / barriers** — target HP 係 sole defense layer (alongside `target.defense` in Formula 1)
    - **NO dodge** — per MVP decision (4-outcome HitOutcome enum, DODGED removed; v0.2 add)
    - **v0.2 hook points reserved**:
      - `CombatContext` 可加 `damage_type: DamageType` field 而唔 break contract
      - `HitResult` 可加 `status_applied: Array[StringName]` field
      - 新 signals `status_applied` / `dodge_attempted` 可加去 EnemyDirector signal surface
    - **Rationale**: MVP discipline — combat math 1 條 axis (raw damage scaling)，唔同步引入 5 條 axes (types × statuses × DoT × shields × dodge)，避免 balance complexity 爆炸 + 確保 VS-tier 6-8 週 scope realistic

17. **Rule 17 — Telemetry rate-limit obligation (EnemyDirector caller-side, EC-47 binding)** — 為防 `combat_metric_anomaly` recursion / runaway emit blocking frame，**EnemyDirector caller-side MUST 限 anomaly emit rate**:
    - **Rate limit**: 同一 `reason` enum value 喺 1 秒內最多 emit **10 個** anomaly signal — 超出 silently drop
    - **Aggregate emit**: 1 秒 window 結束時，若有 drop 過任何 anomaly → emit 1 個 aggregate anomaly `{reason: <original>, dropped_count: <N>, aggregate: true}` 通知 #28 Telemetry 累積值
    - **Context dump size cap**: 每個 anomaly payload `context_dump: Dictionary` 序列化 size > 10KB → EnemyDirector caller-side truncate + 加 `{truncated: true}` field (per EC-48)
    - **Why caller-side**: CombatResolver pure-function 唔可以 own counter state；EnemyDirector instance 持有 `_anomaly_rate_tracker: Dictionary[StringName, RateWindow]` (簡單 sliding-window counter per reason)
    - **CI test**: `tests/unit/combat/test_anomaly_rate_limit.gd` verify 100 同-reason anomaly 喺 1 秒內，#28 收到 ≤ 11 個 (10 emit + 1 aggregate)

18. **Rule 18 — Catch-up × AOE mutual exclusion (FR-3 budget protection, CD F6 binding)** — 為 prevent Rule 14 AOE worst-case (8 targets × 0.05ms = 0.4ms) × Rule 15 catch-up worst-case (12 hits × 0.05ms = 0.6ms) 同 frame combined CPU = 1.0ms+ → ADR-001 budget breach + Pillar 2 frictionless violation。EnemyDirector caller-side MUST enforce mutual exclusion serialization:
    - **Detection**: EnemyDirector instance 持有 `_catch_up_queue: Array[CombatContext]`。若 `_catch_up_queue.size() > 0` (catch-up draining) AND new ability_cast 收到 AOE-type (target_type=AOE_RADIUS)：
      - **Path (a) recommended**: AOE cast defer 入 `_catch_up_queue` tail，等 catch-up drain 完成先 process — 保證 catch-up frame 唔同時 process AOE expansion (frame budget protect)
      - **Path (b) alternative**: catch-up frame 期間 AOE cast 收縮成 1 個「logical hit」(只 process primary target，skip 其他 7 個 target target acquisition) — preserve player perceived input responsiveness 但 sacrifice AOE spectacle during catch-up window
    - **Default**: Path (a) (defer AOE 入 queue) — 因為 bfcache resume 期間 AOE spectacle 失效 唔係玩家 attention focus point (player 剛 unlock phone)，preserve frame budget 優先
    - **Implementation**: EnemyDirector `_on_ability_cast(...)` 邏輯：
      ```gdscript
      if _catch_up_queue.size() > 0 and ability_registry[ability_id].target_type == AOE_RADIUS:
          _catch_up_queue.append(_build_ctx(ability_id, caster, target, ...))
          return  # defer — Rule 18 catch-up/AOE serialization
      # ... normal processing
      ```
    - **Why caller-side**: CombatResolver pure-function 唔可以 own queue state；EnemyDirector instance 持有 `_catch_up_queue` (per Rule 15 already)
    - **CI test**: `tests/integration/combat/test_catch_up_aoe_mutex.gd` verify catch-up 期間 8-target AOE cast → AOE 喺 catch-up drain 完成後先 process (queue position + frame deferral)
    - **Rationale**: Finding 6 CD-GDD-ALIGN — combined catch-up × AOE worst-case 4.8ms 違反 INV-5 + FR-3 1.0ms budget。Rule 18 mutual exclusion guarantee combined CPU 任何 frame ≤ max(catch-up, AOE) 0.6ms — 留 0.4ms+ headroom 俾 frame overhead + VFX dispatch

### States and Transitions

CombatResolver 本身 **冇 internal states** (Rule 1 stateless purity)。呢個 section 重構為 **「Input-Driven Behavior Variation」** — 同一個 `resolve_hit(ctx)` call 根據 input 不同會行唔同 path，但 **無 hidden state transition**:

| Input Variation | Pipeline Path | Output |
|---|---|---|
| `ctx.gsm_state == &"Suspended"` | Rule 4 Stage 1 reject (per Rule 12) | `HitResult{outcome=NORMAL_HIT, damage_dealt=0, damage_tier=NEGLIGIBLE}` + anomaly `GSM_SUSPENDED` |
| `ctx.target_state.hp <= 0` | Rule 4 Stage 1 reject | `HitResult{outcome=NORMAL_HIT, damage_dealt=0}` + anomaly `DEAD_TARGET_RESOLVE` (caller bug — 對死敵 cast) |
| `ctx.ability_id` 唔屬 #12 enum | Rule 4 Stage 1 reject | `HitResult{outcome=NORMAL_HIT, damage_dealt=0}` + anomaly `INVALID_ABILITY_ID` |
| `ctx.rng == null` | Rule 4 Stage 1 reject | `HitResult{outcome=NORMAL_HIT, damage_dealt=0}` + anomaly `RNG_INJECTION_MISSING` |
| Normal `ctx`, `is_crit == false`, `damage_dealt < target.hp` | Rule 4 Stage 1-6 normal path | `HitResult{outcome=NORMAL_HIT, damage_tier=<computed>}` |
| Normal `ctx`, `is_crit == true`, `damage_dealt < target.hp` | Rule 4 Stage 4 crit branch + tier override | `HitResult{outcome=CRITICAL_HIT, damage_tier ≥ HEAVY}` (FR Test #4 guarantee) |
| Normal `ctx`, `damage_raw >= target.hp` 且 `damage_raw - target.hp <= 0` | Rule 4 Stage 5 kill branch | `HitResult{outcome=KILLED, target_hp_after=0, is_kill=true, overkill_excess=0}` |
| Normal `ctx`, `damage_raw > target.hp` 且 `damage_raw - target.hp > 0` | Rule 4 Stage 5 overkill branch | `HitResult{outcome=OVERKILL, target_hp_after=0, is_kill=true, overkill_excess=<computed>}` |

**Behavioural Invariant** (Rule 1 CI determinism test binding): 同樣 `(ctx.ability_id, ctx.caster_stats snapshot, ctx.target_state snapshot, ctx.rng seed state, ctx.transition_id, ctx.gsm_state, ctx.hit_seq)` 必產生 byte-identical `HitResult`。呢個係 Pillar 1 anti-fabrication quartet + ADR-005 deterministic chain 嘅 cornerstone

**No state machine diagram needed** — single-call decision tree，無持續狀態，無 transition

### Interactions with Other Systems

| # | System | Direction | API / Signal Used | Key Ownership | Notes |
|---|--------|-----------|-------------------|---------------|-------|
| #1 | GameStateMachine | EnemyDirector reads (NOT CombatResolver — purity) | `GameStateMachine.current_state` + `current_transition_id` (sync reads by EnemyDirector at ability_cast receipt) | #1 owns state lifecycle + transition_id source | Rule 12 Suspended gate input + Rule 7 transition_id FR-1 seed source |
| #11 | Stat System | EnemyDirector snapshots (Rule 6 — CombatResolver never reads StatSystem direct) | `StatSystem.get_stat(&"ATTACK_POWER")` + `get_stat(&"CRIT_CHANCE")` (sync O(1) by EnemyDirector once per ability_cast event) | #11 owns formulas Formula 4 + 6; #13 consumes snapshot only | EnemyDirector wraps reads into `StatSnapshot` BEFORE `resolve_hit` call; CI lint enforces no direct StatSystem reads in CombatResolver |
| #12 | Ability System | EnemyDirector subscribes (NOT CombatResolver — purity) | `ability_cast(ability_id, caster, target)` signal via Contract 6 `connect_for_initial_state`; `AbilityRegistry.tres` (data-driven Resource) for `{class, tier, target_type, base_cooldown_sec, base_damage_multiplier}` | #12 owns ability metadata + cast lifecycle; #13 owns damage interpretation | EnemyDirector subscribes; ability_id 係 primary routing key 入 Section D Formula 1。**Note**: `base_damage_multiplier` field 需要 #12 `AbilityRegistry.tres` schema extension — Q-F2 Open Question |
| #14 | EnemyDirector | **calls** `CombatResolver.resolve_hit()` (instantiated by #14); **emits** `hit_resolved` + `enemy_killed` + `combat_metric_anomaly` signals on CombatResolver's behalf | `CombatResolver.resolve_hit(ctx: CombatContext) -> HitResult` (static); #14 owns 3 signal emissions per Rule 3 | #14 owns enemy lifecycle / target selection / rng injection / GSM read / snapshot; #13 owns the math | **PROVISIONAL** — #14 not yet designed (VS tier order 10). This GDD assumes #14 provides `EnemyState{hp, max_hp, defense, faction, instance_id}` struct. Verify on #14 GDD authoring (cross-system FR flagged in Section F) |
| #15 | LootDrop System | Indirect via `enemy_killed` payload `transition_id` field (FR-2 binding) | `enemy_killed(payload)` — payload.`transition_id` 用作 #15 RNG seed source per ADR-005 `loot_rarity_score` | #15 owns loot table; #13 guarantees `transition_id` propagation only | Per ADR-005 Pillar 1 chain — same kill replay 一定 roll same rarity; **PROVISIONAL** — #15 not yet designed (Pre-MVP tier order 17) |
| #16 | Boss System | Same as #14 (boss = special enemy) | Same `resolve_hit()` API; boss `EnemyState` 可能有更高 `defense` + special metadata | #16 owns boss-specific phase logic; #13 stays generic | Boss phases handled by EnemyDirector swapping in different `EnemyState` per phase — #13 唔知「呢個係 boss」 |
| #17 | Equipment & Inventory | Indirect — #17 applies equipment modifiers to #11 stats BEFORE CombatResolver reads | `StatSystem.apply_equipment_modifier(equipment_id, StatModifier)` per #11 Rule 5 | #17 owns equipment data + lifecycle; #13 sees post-equipment stats only (via #11) | Equipment damage bonuses baked into `caster_stats.attack_power` before `resolve_hit` — #13 has ZERO direct coupling to equipment; **anti-snowball forward constraint**: equipment-derived ATK ≤ 3× stat-derived ATK (flag for #17 GDD authoring per Section F) |
| #25 | Combat Visual Feedback | **Listens to** `hit_resolved` | `EnemyDirector.hit_resolved(payload)` — `damage_tier` as routing key | #25 owns VFX library + damage number popups + hit_pause durations per tier | FR Test #4 binding — #25 must use `damage_tier`，唔可以 re-derive based on damage value |
| #6 | ScreenEffects | **Listens to** `hit_resolved` | Same signal; uses `damage_tier` → shake intensity mapping (NEGLIGIBLE / LIGHT → no shake; MEDIUM → trauma 0.2; HEAVY → 0.4; CRITICAL → 0.6) | #6 owns shake curve + hit_pause API; #13 owns tier trigger | Per ADR-001 shake routed via shader uniform path (#6 Rule 14) |
| #5 | ParticleSystemWrapper | **Listens to** `hit_resolved` | Same signal; #25 may call `ParticleSystem.play(preset_id, position, caller_mult)` directly OR #5 auto-dispatch per #5 Rule 9 | #5 owns particle budget per tier; #13 owns tier trigger only | Per ADR-001 GPU particle cap 200 mobile / 400 desktop — high-tier emits gated by budget |
| #28 | Telemetry / Analytics | **Listens to** all 3 signals (`hit_resolved` + `enemy_killed` + `combat_metric_anomaly`) | 3 signals total | #28 owns event aggregation + anomaly threshold tuning | `combat_metric_anomaly` 係 anti-fabrication channel (Pillar 1 binding); #28 escalate 若 rate > threshold |

**Interaction invariants**:
- **No direct global reads**: CombatResolver NEVER calls `StatSystem.` / `AbilitySystem.` / `GameStateMachine.` / `ScreenEffects.` / `ParticleSystemWrapper.` directly (Rule 1 CI lint enforced) — 全部 input via `CombatContext` parameter
- **Return-value only**: CombatResolver NEVER emit signal — `HitResult` return value，EnemyDirector 翻譯成 signal payload
- **EnemyDirector contract assumption**: This GDD assumes #14 provides `EnemyState` struct + handles signal emission per Rule 3。若 #14 GDD authoring (VS tier order 10, next system) 重新 design，呢個 GDD 嘅 Rule 3 / Rule 6 / Rule 7 / Interactions table 必 re-review

## Formulas

CombatResolver 嘅 formula family — 5 條 pure-function math layer，全部 `static func`、O(1) compute、無 allocation (output struct ref-counted only)、符合 Rule 1 stateless purity + Pillar 2 frictionless < 1.0ms total budget per resolve_hit call (per ADR-001 FR-3 binding)。設計核心：**ATTACK_POWER × ability_multiplier × 線性 defense subtract** (Q-D1 [A] MVP simplicity)，crit 用 fixed 1.5× multiplier (Q-D2 [A] anti-snowball)，damage_tier 用 ratio-of-MAX_HP classification (Q-D4 [B] scales across boss / mob)，overkill expose excess 唔 clamp raw (Q-D7 [A] downstream hook 留空間)。

**Calibration target** (per Q-D8 [B]): **Mid-game stat (STR=100, ATTACK_POWER ~160) + TIER_3 ability (×3.0 multiplier) vs mid-boss (5000 HP, defense=20)** → ~10 hits to kill → 對應 game-concept「boss 10-20 hit kill」standard。Starter-stat / starter-boss 配對 = 30-50 hits (early grind feel)；endgame stat / starter-boss = 3-5 hits (power fantasy moment)；endgame stat / endgame boss = 8-15 hits (sweet spot — Pillar 3 dopamine 唔被 trivial hit count 稀釋)。

### Formula 1: `compute_hit_damage` — Base pre-crit, pre-mitigation damage

**Rationale**: Q-D1 [A] flat subtraction — MVP simplicity，`max(1, ...)` floor 防「tap-of-nothing」per Pillar 3。Q-D-NEW [A] 用 ATTACK_POWER (#11 已 aggregate STR / DEX / equipment) — CombatResolver pure consumer，唔重複 aggregate。`ability_damage_multiplier` 由 #12 `AbilityRegistry.tres` 提供 (Q-D3 [A] data-driven per coding-standards)。

`base_damage = max(1, round(ATTACK_POWER × ability_damage_multiplier − target_defense))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `ATTACK_POWER` | A | float | [1, 4500] | From #11 Formula 4 — read fresh每 ability_cast via Rule 6 StatSnapshot |
| `ability_damage_multiplier` | μ_a | float | [0.5, 3.0] | From #12 `AbilityRegistry.tres` per ability_id (Q-F2 schema extension — see Section F) |
| `target_defense` | D | int | [0, 500] | From #14 EnemyDirector `EnemyState.defense` (provisional contract per Section F) |
| `base_damage` | δ_b | int | [1, ~13500] | Pre-crit, pre-tier-classification 整數 damage |

**Output Range**: `[1, ~13500]`。Hard floor 1 (Pillar 3 每 hit lands ≥1 anti「tap-of-nothing」)。Upper bound = (max ATTACK_POWER 4500 × max multiplier 3.0) − 0 defense ≈ 13500。

**Default knob values** (per AbilityRegistry.tres):

| Ability tier | `ability_damage_multiplier` default | Rationale |
|---|---|---|
| TIER_1 (bread-and-butter, ~3s cd, ~20 casts/60s) | 1.0 | Baseline cadence |
| TIER_2 (combo piece, ~6s cd, ~10 casts) | 1.8 | 1.8× single hit ≈ 0.9× per-second DPS vs TIER_1 — encourage weaving |
| TIER_3 (signature, ~10s cd, ~6 casts) | 3.0 | 3.0× single hit ≈ 0.9× per-second DPS vs TIER_1 — power burst feel |

**Cross-knob invariants**:
- `ability_damage_multiplier ≤ 3.0` (anti-snowball; combined with crit cap below)
- `TIER_3 mult / TIER_1 mult ≤ 4.0` (mirrors #12 Formula 2 INV-7 cooldown ratio cap — proportional tier scaling)
- Per-second DPS of TIER_1 / 2 / 3 within ±20% of each other (encourages weaving instead of single-tier spam — Pillar 4 day-rotation 嘅 design intent)

**Worked Examples**:
- **CF-1 baseline (starter player STR=10, DEX=10, no equipment, starter mob defense=10)**:
  - ATTACK_POWER = 28 (per #11 Formula 4 CF-1 baseline + AC-27)
  - Cast STRIKE_TIER_1_JAB (μ_a=1.0): `δ_b = max(1, round(28 × 1.0 − 10)) = 18`
  - Starter mob MAX_HP = 80–100 → 80 / 18 ≈ **4-5 hits to kill** → satisfies game-concept「starter mob 3-4 hit kill」target ✓ (Pillar 1 baseline survivable encounter)
- **Mid-game calibration (STR=100, DEX=50, +20 wpn vs mid-boss 5000 HP, defense=20)**:
  - ATTACK_POWER ≈ 10 + 100×1.5 + 50×0.3 + 20 = 195
  - TIER_3 cast (μ_a=3.0): `δ_b = max(1, round(195 × 3.0 − 20)) = 565` per hit
  - 5000 / 565 ≈ **9 hits to kill** → satisfies Q-D8 [B]「mid-game vs mid-boss = ~10 hits」target ✓
- **Endgame (STR=400, DEX=200, +50 wpn vs endgame boss 8000 HP, defense=100)**:
  - ATTACK_POWER ≈ 10 + 400×1.5 + 200×0.3 + 50 = 720
  - TIER_3 cast (μ_a=3.0): `δ_b = max(1, round(720 × 3.0 − 100)) = 2060` per hit
  - 8000 / 2060 ≈ **4 hits to kill** → Pillar 3 power fantasy moment ✓

### Formula 2: `roll_crit` — Deterministic crit decision (FR-1 binding)

**Rationale**: Pillar 1 anti-fabrication — RNG seeded by `transition_id + ability_id + hit_seq` sub-seed key，防 AOE 多 hit 共享同 seed 引致全 crit / 全 miss degenerate。Caller-injected rng instance (Rule 7) — CombatResolver 唔 own RNG。CRIT_CHANCE 由 #11 Formula 6 提供 (上限 MAX_CRIT_CHANCE=0.50 per #11 lock)。

`is_crit = (rng.randf() < CRIT_CHANCE) where rng_subseed = hash("%s:%s:%d" % [transition_id, ability_id, hit_seq])`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `CRIT_CHANCE` | p_c | float | [0.0, MAX_CRIT_CHANCE=0.50] | From #11 Formula 6, snapshot via Rule 6 |
| `transition_id` | t_id | String | UUID-like | From GSM `StateTransitionPayload` |
| `ability_id` | a_id | StringName | #12 enum | For sub-seed disambiguation |
| `hit_seq` | k | int | [0, ∞) | EnemyDirector monotonic counter per encounter — anti-degenerate per AOE |
| `is_crit` | b_c | bool | {true, false} | Single Bernoulli outcome |

**Output Range**: boolean (single bit outcome)。

**Default knob**: none — `CRIT_CHANCE` fully derived from #11 stat formula。

**Cross-knob invariants**:
- RNG seed MUST include `transition_id` (FR-1 binding) AND per-call discriminator (`ability_id` + `hit_seq`)，否則同 frame multi-hit 共享 seed → 全 crit / 全 miss degenerate
- 同樣 `(transition_id, ability_id, hit_seq, p_c)` 必 produce 同樣 `is_crit` (Rule 1 determinism invariant binding)

**Worked Examples**:
- CF-1 baseline (DEX=10 → CRIT_CHANCE = 0.015 per #11 AC-29 sub-test) — `rng.randf()` deterministic returns 0.872 → 0.872 ≥ 0.015 → `is_crit = false` (expected — crits rare delight at baseline, ~1 per 67 hits)
- Mid-game (DEX=200 → CRIT_CHANCE = 200×0.0015 + 0 = 0.30) — `rng.randf()` returns 0.18 → 0.18 < 0.30 → `is_crit = true`
- Endgame (DEX=333 → CRIT_CHANCE = MAX_CRIT_CHANCE = 0.50 capped per #11) — `rng.randf()` returns 0.47 → `is_crit = true`

### Formula 3: `apply_crit_multiplier` — Scale damage on crit (Q-D2 [A] fixed 1.5×)

**Rationale**: Q-D2 [A] fixed `CRIT_MULTIPLIER = 1.5` — DEX 已 increases crit chance (#11 Formula 6)，doubling up with crit *magnitude* scaling 會破 anti-snowball invariant `CRIT_MULTIPLIER × MAX_CRIT_CHANCE ≤ 0.75` expected bonus。Stat-scaled crit multiplier defer v0.2。

`post_crit_damage = round(base_damage × (CRIT_MULTIPLIER if is_crit else 1.0))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `base_damage` | δ_b | int | [1, ~13500] | From Formula 1 |
| `is_crit` | b_c | bool | {true, false} | From Formula 2 |
| `CRIT_MULTIPLIER` | M_c | float | [1.5, 2.5] | Tuning knob (Section G), default 1.5 fixed per Q-D2 [A] |
| `post_crit_damage` | δ_p | int | [1, ~33750] | Output |

**Output Range**: `[1, ~33750]` (max base 13500 × max crit_mult 2.5 ceiling at safe-range upper bound)。

**Default knob**: `CRIT_MULTIPLIER = 1.5` (Pillar 3 noticeable but not degenerate)。

**Cross-knob invariants (anti-snowball, critical)**:
- **HARD**: `CRIT_MULTIPLIER × MAX_CRIT_CHANCE ≤ 0.75` expected-value bonus per hit (current 1.5 × 0.50 = 0.75 ✓) → 防「100% crit chance + 3x mult = 3x DPS dice-game」degeneracy
- **HARD**: `CRIT_MULTIPLIER × max(ability_damage_multiplier) ≤ 5.0` per single-hit ceiling (current 1.5 × 3.0 = 4.5 ✓) — bounds max single-hit multiplicative stack
- **SOFT (Section H AC binding)**: ship unit test `tests/unit/combat/test_max_single_hit_bound.gd` 確保 `max_possible_single_hit(stats, ability) ≤ target_MAX_HP × 0.60` for all (stat-tier × ability-tier × enemy-tier) combinations。Forces designer review of any tuning that produces single-hit > 60% boss HP

**Worked Examples**:
- New player STR=10 JAB on starter mob: base_damage=18, is_crit=true → `δ_p = round(18 × 1.5) = 27` → starter mob 80 HP → ~3 hits to kill on crit chain (vs 5 hits non-crit) — Pillar 3 crit visible meaningful moment ✓
- Mid-game STR=100 OVERHAND on mid-boss: base_damage=565, is_crit=true → `δ_p = round(565 × 1.5) = 848` → 5000 / 848 ≈ ~6 hits to kill (vs ~9 hits non-crit) — crit moment 加速 boss fight 但唔 trivialize

### Formula 4: `classify_damage_tier` — Map final damage → DamageTier enum (Q-D4 [B] ratio-of-MAX_HP)

**Rationale**: Q-D4 [B] relative threshold — absolute thresholds (e.g., damage > 100 = HEAVY) fail at scale；early 18-damage hit on 100 HP mob (18%) 感覺重，同樣 18 damage on 5000 HP boss (0.36%) 感覺微不足道。Ratio preserves Pillar 3「重擊感」across entire stat curve。Crit override (`is_crit → tier ≥ HEAVY`) per FR Test #4 — even on bullet-sponge target，crit moment 仍 trigger hit_pause + heavy preset。

```gdscript
damage_pct = float(damage_dealt) / float(max(1, target_max_hp))

if damage_pct >= T_CRITICAL: tier = CRITICAL     # default 0.40
elif damage_pct >= T_HEAVY:  tier = HEAVY        # default 0.15
elif damage_pct >= T_MEDIUM: tier = MEDIUM       # default 0.05
elif damage_pct >= T_LIGHT:  tier = LIGHT        # default 0.01
else:                        tier = NEGLIGIBLE

if is_crit and tier < HEAVY: tier = HEAVY        # crit override per FR Test #4
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `damage_dealt` | δ_d | int | [1, target_hp] | Post-clamp from Formula 5 |
| `target_max_hp` | H_m | int | [1, ~10000] | From #14 `EnemyState.max_hp` |
| `damage_pct` | r | float | [0.0, 1.0] | Ratio (clamped — overkill 計算 separately in Formula 5) |
| `is_crit` | b_c | bool | {true, false} | From Formula 2 |
| `T_CRITICAL` | T_4 | float | [0.30, 0.60] | Knob (Section G), default 0.40 |
| `T_HEAVY` | T_3 | float | [0.10, 0.25] | Knob, default 0.15 |
| `T_MEDIUM` | T_2 | float | [0.03, 0.08] | Knob, default 0.05 |
| `T_LIGHT` | T_1 | float | [0.005, 0.02] | Knob, default 0.01 |
| `tier` | T | enum | DamageTier | Output for FR Test #4 |

**Output Range**: enum `{NEGLIGIBLE, LIGHT, MEDIUM, HEAVY, CRITICAL}` — 5-value finite set。

**Cross-knob invariants**:
- `T_CRITICAL > T_HEAVY > T_MEDIUM > T_LIGHT > 0` strict monotonic
- `T_CRITICAL ≤ 0.60` (>60% HP / single hit = boss one-shot territory，超過違反 Pillar 3 dopamine — 變 Pillar 3 boredom，無 fight 只有 first hit)
- **FR Test #4 binding**: `is_crit == true` OR `damage_pct ≥ T_HEAVY` MUST yield `tier ≥ HEAVY` so #6 ScreenEffects auto-dispatch fires `hit_pause(≥65ms)` + #5 fires HIT_HEAVY+ preset

**Worked Examples**:
- New player JAB on starter mob: damage_dealt=18, max_hp=80 → `r = 0.225` → **HEAVY** ✓ (early game every hit feels meaningful — Pillar 3 visceral)
- Same JAB on mid-boss: damage_dealt=18, max_hp=5000 → `r = 0.0036` → **NEGLIGIBLE** (correctly downgrades VFX — boss takes hundreds of jabs，no need for hit_pause per jab，frame budget protect)
- Crit JAB on mid-boss: damage_dealt=27, max_hp=5000 → `r = 0.0054` would be NEGLIGIBLE，but `is_crit=true` override → **HEAVY** (preserves crit excitement on bullet-sponge targets per FR Test #4)
- Mid-game OVERHAND on mid-boss: damage_dealt=565, max_hp=5000 → `r = 0.113` → **MEDIUM** (TIER_3 signature feels weighty but not finishing)
- Mid-game OVERHAND crit on mid-boss: damage_dealt=848, max_hp=5000 → `r = 0.170` → **HEAVY** (crit + TIER_3 = full DNF重擊 moment) ✓

### Formula 5: `detect_overkill` — Clamp damage_dealt + expose overflow (Q-D7 [A])

**Rationale**: Q-D7 [A] clamp `damage_dealt` at `target.hp` but expose `overkill_excess` field — Telemetry sees both `applied=20` (HP integrity) 同 `overkill=30` (future combo / loot bonus hook)。Caller-visible distinction is cheap and enables OVERKILL outcome + achievement hooks without #28 re-deriving。

```gdscript
static func detect_overkill(damage_raw: float, target_hp: int) -> Dictionary:
    var damage_int = max(1, roundi(damage_raw))         # min 1 per Pillar 3 anti「tap-of-nothing」
    return {
        "damage_dealt": min(damage_int, target_hp),
        "overkill_excess": max(0, damage_int - target_hp),
        "target_hp_after": max(0, target_hp - damage_int),
        "is_kill": damage_int >= target_hp,
    }
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `damage_raw` | δ_r | float | [0, ~33750] | Pre-clamp from Formula 3 |
| `target_hp` | H_c | int | [0, target_max_hp] | Enemy current HP (owned by #14 EnemyDirector) |
| `damage_int` | δ_i | int | [1, ~33750] | Rounded + floored (min 1) |
| `damage_dealt` | δ_d | int | [1, target_hp] | Output — recorded HP loss |
| `overkill_excess` | E | int | [0, ~33750] | Output — excess for OVERKILL outcome |
| `target_hp_after` | H_a | int | [0, target_hp] | Output — updated HP |
| `is_kill` | b_k | bool | {true, false} | Output — triggers `enemy_killed` |

**Output Range**: integers, bounded as shown。

**Cross-knob invariants**:
- **Conservation**: `damage_dealt + target_hp_after == target_hp` (no double-counting in telemetry)
- **Overkill / kill consistency**: `is_kill == true` iff `damage_int >= target_hp` iff `target_hp_after == 0`
- **Idempotency**: `is_kill == true` ↔ `enemy_killed(enemy_id, transition_id)` emitted exactly once by EnemyDirector — race protection per Rule 9

**Worked Examples**:
- Mob current_hp=20, incoming damage=18 → applied=18, overkill=0, new_hp=2, killed=false → `HitResult{outcome=NORMAL_HIT, damage_dealt=18, overkill_excess=0}`
- Mob current_hp=20, incoming damage=50 → applied=20, overkill=30, new_hp=0, killed=true → `HitResult{outcome=OVERKILL, damage_dealt=20, overkill_excess=30, is_kill=true}` + EnemyDirector emit `enemy_killed(mob_id, transition_id)` same frame
- Mob current_hp=20, incoming damage=20 → applied=20, overkill=0, new_hp=0, killed=true → `HitResult{outcome=KILLED, damage_dealt=20, overkill_excess=0, is_kill=true}` (exact kill — KILLED not OVERKILL)
- Boss current_hp=5000, incoming damage=848 (crit OVERHAND) → applied=848, overkill=0, new_hp=4152, killed=false → `HitResult{outcome=CRITICAL_HIT, damage_dealt=848, damage_tier=HEAVY}` (mid-fight crit, no kill)

### Formula Family Integration: `resolve_hit` pipeline (Rule 4 reference)

完整 5-stage pipeline 引用 Formulas 1-5 順序：

```
Input ctx → 
  Stage 2: damage_raw = compute_hit_damage(ctx.ability_id, ctx.caster_stats.attack_power, ctx.target_state.defense)   # Formula 1
  Stage 3: is_crit = roll_crit(ctx.caster_stats.crit_chance, ctx.rng, ctx.ability_id, ctx.hit_seq)                     # Formula 2
  Stage 4: if is_crit: damage_raw = apply_crit_multiplier(damage_raw, CRIT_MULTIPLIER)                                  # Formula 3
  Stage 5a: (damage_dealt, overkill_excess, target_hp_after, is_kill) = detect_overkill(damage_raw, ctx.target_state.hp)  # Formula 5
  Stage 5b: damage_tier = classify_damage_tier(damage_dealt, ctx.target_state.max_hp, is_crit)                          # Formula 4
  Stage 6: outcome = OVERKILL if overkill_excess > 0 and is_kill else KILLED if is_kill else CRITICAL_HIT if is_crit else NORMAL_HIT
→ Output HitResult{outcome, damage_tier, damage_dealt, damage_raw, target_hp_after, is_kill, overkill_excess, is_crit, ability_id, transition_id}
```

**Total compute cost per hit** (analytic estimate):
- Formula 1: 2 mul + 1 sub + 1 round + 1 max + 1 Dictionary lookup (AbilityRegistry) = ~6 GDScript ops ≈ 0.005ms
- Formula 2: 1 hash + 1 randf + 1 compare = ~3 ops ≈ 0.002ms
- Formula 3: 1 mul + 1 round (branch) = ~2 ops ≈ 0.001ms
- Formula 4: 1 div + 5 compares + 1 branch override = ~7 ops ≈ 0.003ms
- Formula 5: 3 max + 2 min + 1 round + 1 sub = ~7 ops ≈ 0.003ms
- HitResult allocation: ~0.005ms (RefCounted struct, 10 fields)

**Per-hit total ≈ 0.02ms**。8 enemy × 3 AOE hits = 24 hits = **0.48ms** — 喺 ADR-001 1.0ms p95 mobile budget 內留 ~52% headroom 俾 EnemyDirector orchestration + signal emission + downstream VFX dispatch ✓ (FR-3 binding satisfied analytically；VS-tier benchmark per Section H AC 確認)

### Anti-Snowball Risk Matrix (Cross-Formula Invariants)

| # | Risk Pattern | Invariant | Default Status |
|---|---|---|---|
| 1 | Multiplicative DPS stacking — late-game one-shots | `CRIT_MULTIPLIER × max(ability_damage_multiplier) ≤ 5.0` | 1.5 × 3.0 = 4.5 ✓ |
| 2 | Crit expected value runaway | `CRIT_MULTIPLIER × MAX_CRIT_CHANCE ≤ 0.75` | 1.5 × 0.50 = 0.75 ✓ |
| 3 | DEX double-dip (chance + multiplier) | CRIT_MULTIPLIER fixed (not DEX-scaled) per Q-D2 [A] | ✓ enforced |
| 4 | Equipment ATK overpowering stat ATK | `equipment_atk / stat_atk ≤ 3.0` (forward constraint for #17 GDD authoring) | flag in Section F |
| 5 | bfcache resume batch sharing single crit roll | RNG sub-seed includes `hit_seq` counter per Rule 7 | enforced in Formula 2 |
| 6 | Defense formula flat-zero negation | `max(1, ...)` floor in Formula 1 prevents 0 damage | ✓ enforced |
| 7 | Damage_tier absolute-threshold scale failure | Q-D4 [B] ratio-of-MAX_HP design | ✓ enforced in Formula 4 |
| 8 | Boss one-shot single-hit | `T_CRITICAL ≤ 0.60` Section G invariant | ✓ knob constraint |
| 9 | Negative defense debuff stacking — EC-16 allow `target_defense < 0` ("shred armor" buff)，若 future debuff system 加 -100 defense → Formula 1 變 `max(1, round(ATTACK × mult + 100))` → 對細-stat hit 效應顯著放大 (3× boost typical mid-stat encounter) | `target_defense ≥ −ATTACK_POWER × 0.5` invariant — debuff 唔可以加超過 50% effective ATK；OR alternative: MVP ban negative defense (EC-16 改為 reject at Stage 1 + emit `NEGATIVE_DEFENSE` anomaly)，defer debuff system to v0.2 | **flag for #14 EnemyDirector + #16 Boss System (boss debuff abilities) GDD authoring constraint** — per CD-GDD-ALIGN F10 inline-fix 2026-05-27 |

## Edge Cases

50 concrete edge cases，按 10 category 分組。每個 case 用「If [condition]: [exact resolution]」格式，明確指定 HitResult 結構 + signal emit，唔用含糊「handle gracefully」字眼。Cross-references 用 [[autoload-boot-order]] / [[N-recursion-guard]] / EC-NN format。

### E.1 Input Validation Edge Cases (Rule 4 Stage 1)

- **EC-01 [Validation]**: If `ctx` itself is null → `resolve_hit` 一進入立即 `assert(ctx != null)` fail；release build fallback return `HitResult{outcome=NORMAL_HIT, damage_dealt=0, damage_tier=NEGLIGIBLE, is_crit=false, overkill_excess=0}`。冇 EnemyDirector caller context 可以 emit anomaly，所以 CombatResolver 自己 `push_error("CombatResolver: null ctx")` 入 Godot log，由 #28 telemetry log scraper 拎走。Rationale: caller bug 唔應該 crash combat loop。

- **EC-02 [Validation]**: If `ctx.ability_id` is empty StringName (`&""`) → Stage 1 reject, return `HitResult{outcome=NORMAL_HIT, damage_dealt=0, damage_tier=NEGLIGIBLE}` + EnemyDirector emit `combat_metric_anomaly(reason=INVALID_ABILITY_ID, context_dump={ability_id: "", caster_id: ctx.caster_id})`。唔做 damage compute。

- **EC-03 [Validation]**: If `ctx.ability_id` 唔存在 #12 AbilityRegistry → Stage 1 reject (registry lookup 拎唔到 multiplier)，return zero-damage HitResult + emit `combat_metric_anomaly(reason=INVALID_ABILITY_ID, context_dump={ability_id: ctx.ability_id})`。Rationale: 防止 ability_damage_multiplier=null 喺 Formula 1 引發 NaN propagation。

- **EC-04 [Validation]**: If `ctx.caster_stats.attack_power == 0` → Stage 1 **PASS** (0 ATK 係 valid stat，唔係 invalid input)，繼續到 Formula 1。最終 `max(1, round(0 × mult − defense))` = 1 (被 max(1, ...) floor 救返)，return `HitResult{outcome=NORMAL_HIT, damage_dealt=1, damage_tier=NEGLIGIBLE}`。Rationale: 0 ATK 係 design-valid edge case (debuffed caster)，唔應該 anomaly。

- **EC-05 [Validation]**: If `ctx.caster_stats.attack_power < 0` → Stage 1 reject (negative stat indicates upstream #11 bug)，return zero-damage HitResult + emit `combat_metric_anomaly(reason=NEGATIVE_DAMAGE, context_dump={attack_power: ctx.caster_stats.attack_power, source: "caster_stats"})`。

- **EC-06 [Validation]**: If `ctx.target_state.hp == 0` 進入 resolve_hit → Stage 1 reject (dead target)，return `HitResult{outcome=NORMAL_HIT, damage_dealt=0, damage_tier=NEGLIGIBLE}` + emit `combat_metric_anomaly(reason=DEAD_TARGET_RESOLVE, context_dump={target_id, hp: 0})`。Rationale: 防止 negative HP arithmetic + 防止 enemy_killed signal 重複 fire 觸發 #15 double loot drop。

- **EC-07 [Validation]**: If `ctx.target_state.hp < 0` 進入 resolve_hit → 同 EC-06 處理，但 anomaly `reason=DEAD_TARGET_RESOLVE` 帶 `context_dump={hp: <negative>}` 標記 upstream HP integrity bug。

- **EC-08 [Validation]**: If `ctx.target_state.max_hp == 0` (uninitialized enemy) → Stage 1 reject，return zero-damage HitResult + emit `combat_metric_anomaly(reason=NEGATIVE_DAMAGE, context_dump={max_hp: 0, note: "tier classification undefined for max_hp=0"})`。Rationale: Formula 4 `damage_dealt / max_hp` 會 div-by-zero。

- **EC-09 [Validation]**: If `ctx.rng` is null → Stage 1 reject，return zero-damage HitResult + emit `combat_metric_anomaly(reason=RNG_INJECTION_MISSING, context_dump={ability_id, hit_seq})`。Rationale: 冇 RNG 無辦法 deterministic seed Formula 2。

- **EC-10 [Validation]**: If `ctx.hit_seq < 0` or `ctx.transition_id == ""` → Stage 1 reject + emit `combat_metric_anomaly(reason=RNG_INJECTION_MISSING, context_dump={hit_seq, transition_id})`。Rationale: hash seed 需要兩者都 valid 先可以 deterministic reproduce。

### E.2 Damage Computation Edge Cases (Formulas 1-3)

- **EC-11 [Damage Compute]**: If `ATTACK_POWER × ability_damage_multiplier < target_defense` (e.g., 10×1.0 − 50 = −40) → Formula 1 `max(1, round(−40))` = 1, return `HitResult{outcome=NORMAL_HIT, damage_dealt=1, damage_tier=NEGLIGIBLE}`。冇 anomaly emit (依設計, "tank wall" 永遠最少 1 damage 防止 0-damage feedback)。

- **EC-12 [Damage Compute]**: If `ability_damage_multiplier` is NaN (malformed `AbilityRegistry.tres`) → Stage 1 偵測 `is_nan(mult)` 拒 reject，return zero-damage HitResult + emit `combat_metric_anomaly(reason=INVALID_ABILITY_ID, context_dump={ability_id, ability_damage_multiplier: "NaN"})`。Rationale: NaN propagation 會污染後續 tier classification。

- **EC-13 [Damage Compute]**: If `ability_damage_multiplier == INF` → 同 EC-12 處理 (Stage 1 `is_inf(mult)` reject)，emit anomaly with `multiplier: "Inf"`。

- **EC-14 [Damage Compute]**: If `base_damage` after Formula 1 > `BASE_DAMAGE_OVERFLOW_CAP = 1_000_000` (Section G knob, theoretical overflow 風險, 1.43e9 base) → Formula 3 之前 clamp `base_damage = min(base_damage, BASE_DAMAGE_OVERFLOW_CAP)`，emit `combat_metric_anomaly(reason=CLAMP_TRIGGERED, context_dump={original: base_damage, clamped: BASE_DAMAGE_OVERFLOW_CAP})`。Rationale: MVP 階段 enemy max_hp ≤ 10k，1M damage 必然 indicates stat scaling bug。

- **EC-15 [Damage Compute]**: If `is_crit == true` AND `base_damage == 1` → Formula 3 `round(1 × 1.5)` = 2 (Godot `round(1.5)` = 2 via banker's rounding 4.6 行為要 verify, but worst case = 1 or 2)。Return `HitResult{damage_dealt=2, is_crit=true, damage_tier=HEAVY (crit override per Rule 10)}`。Rationale: 確認 crit override forces ≥HEAVY 即使 base 細，玩家見到 yellow crit number。

- **EC-16 [Damage Compute]**: If `target_defense < 0` (negative defense — buff scenario) → Formula 1 變 `ATTACK − (negative)` = ATTACK + |def|，allowed pass through。Rationale: 設計上 "shred armor" debuff 用 negative defense 表達合理，唔係 bug。

### E.3 Tier Classification Edge Cases (Formula 4)

- **EC-17 [Tier Classify]**: If `damage_dealt > target_max_hp` (overkill scenario) → Formula 4 `damage_pct = damage_dealt / max_hp` 可能 > 1.0，無 clamp (e.g., 1.5)，1.5 > T_CRITICAL(0.40) 所以 tier=CRITICAL 正常 assign。Rationale: ratio > 1.0 唔需 cap，分類邏輯純粹 threshold 比較。

- **EC-18 [Tier Classify]**: If `target_max_hp == 1` → 任何 damage_dealt ≥ 1 → damage_pct ≥ 1.0 → tier=CRITICAL。配合 overkill detection (Rule 11)，呢類 1-HP minion 永遠 KILLED + OVERKILL outcome。

- **EC-19 [Tier Classify]**: If `damage_pct < T_LIGHT (0.01)` → tier=NEGLIGIBLE (5th tier 對應 < 1% max HP)，e.g., 1 damage on 200-HP enemy = 0.005 → NEGLIGIBLE。

- **EC-20 [Tier Classify]**: If `is_crit == true` AND raw `damage_pct < T_HEAVY (0.15)` → Rule 10 crit override forces tier = HEAVY (即使 raw 應該係 LIGHT/MEDIUM/NEGLIGIBLE)。Return `HitResult{is_crit=true, damage_tier=HEAVY}`。Rationale: 玩家 visual feedback (crit number colour) 必須匹配 tier ≥HEAVY 嘅 screen shake intensity。

- **EC-21 [Tier Classify]**: If `is_crit == true` AND raw `damage_pct ≥ T_CRITICAL (0.40)` → crit override **唔會** downgrade tier，最終 tier=CRITICAL (取 max(raw_tier, HEAVY))。

### E.4 Overkill Edge Cases (Formula 5)

- **EC-22 [Overkill]**: If `damage_raw == target_hp` exactly (e.g., raw=100, hp=100) → outcome=KILLED (NOT OVERKILL)，`damage_dealt=100, overkill_excess=0`。Rationale: 「剛好 0 HP」係乾淨 kill，唔算 overkill (OVERKILL 定義為 excess > 0)。

- **EC-23 [Overkill]**: If `damage_raw == target_hp + 1` → outcome=OVERKILL, `damage_dealt=target_hp` (clamped), `overkill_excess=1`。EnemyDirector emit `enemy_killed(transition_id, overkill_excess=1)` feed #15 LootDrop 可選 bonus drop。

- **EC-24 [Overkill]**: If `damage_raw > target_hp × 10` (大幅 overkill, e.g., 5000 damage on 100-HP enemy) → outcome=OVERKILL, `damage_dealt=100, overkill_excess=4900`。冇 anomaly (合法 high-stat scenario)，但 #15 LootDrop 可用 overkill_excess 做 rarity bonus modifier (out-of-scope #13)。

- **EC-25 [Overkill]**: If Formula 1 somehow returns negative `damage_raw` (bug) → Stage 5 detect 加 anomaly emit `combat_metric_anomaly(reason=NEGATIVE_DAMAGE, context_dump={damage_raw, base_damage, defense})`, force `damage_dealt = max(0, damage_raw)` clamp 為 0，outcome=NORMAL_HIT (NOT KILLED 即使 hp 不變)。Rationale: defense-in-depth catch Formula bug 避免 negative HP。

### E.5 RNG Edge Cases (Formula 2 + Rule 7)

- **EC-26 [RNG]**: If 2 AOE targets 同一 frame call resolve_hit with 相同 `transition_id` + `ability_id` 但 `hit_seq` 不同 (0, 1, ..., 7) → sub-seed `hash(transition_id + ability_id + hit_seq)` 對每個 hit_seq 產生不同 hash，8 個 target 各有獨立 crit roll outcome。Verified determinism: 相同 input 永遠相同 output。

- **EC-27 [RNG]**: If `hit_seq` reaches `MAX_HIT_SEQ = 1_000_000` (Section G knob, theoretical overflow) → Stage 1 額外 check `hit_seq < MAX_HIT_SEQ` reject + emit `combat_metric_anomaly(reason=RNG_INJECTION_MISSING, context_dump={hit_seq, note: "hit_seq overflow"})`。MVP 階段每 session 唔可能 > 1M hits。

- **EC-28 [RNG]**: If `transition_id` 含 unicode / special chars (e.g., emoji) → Godot `hash()` 接受任何 String → 64-bit int，唔會 collide on reasonable inputs。冇特殊處理需要。

- **EC-29 [RNG]**: If caller injects same `RandomNumberGenerator` instance 跨多個 resolve_hit call → Formula 2 用 caller-provided rng (rng.randf() advances state)，但因為 `hash(transition_id + ability_id + hit_seq)` 作為 sub-seed 喺 randf 前 set，每個 hit 重新 seed → deterministic per-hit roll，唔受 rng instance 之前 state 影響。

### E.6 AOE Edge Cases (Rule 14)

- **EC-30 [AOE]**: If AOE target list is empty (`targets.size() == 0`) → EnemyDirector 唔 call resolve_hit (0 iteration)，唔 emit hit_resolved signal。冇 anomaly (合法 — AOE 揮空)。Rationale: empty AOE 係常見 gameplay (玩家 mistimed)，唔係 error。

- **EC-31 [AOE]**: If AOE target list > `MAX_TARGETS_PER_CAST (8)` → EnemyDirector caller-side clip `targets = targets.slice(0, 8)` (按 #14 距離 sort 取最近 8 個)，emit `combat_metric_anomaly(reason=CLAMP_TRIGGERED, context_dump={ability_id, requested: targets.size(), capped: 8})`。CombatResolver 本身只見到 ≤8 個 resolve_hit call。

- **EC-32 [AOE]**: If AOE 第 1 hit kills target，第 2 hit 同一 target (重複入 list) → 第 2 hit Stage 1 reject (target.hp == 0 from EC-06)，emit `combat_metric_anomaly(reason=DEAD_TARGET_RESOLVE)`。Rationale: 防止 duplicate kill signal 觸發 #15 double loot。

- **EC-33 [AOE]**: If 2 AOE targets have same world position (overlapping enemies) → EnemyDirector 按 enemy `id` (numeric) ascending sort 保證 deterministic ordering — hit_seq 0 assigned to lower id, hit_seq 1 to higher id。確保 replay 一致。

- **EC-34 [AOE]**: If AOE 8-target batch 喺第 4 個 hit 時 GSM 轉 Suspended → 剩低 4 個 hit Stage 1 reject (GSM_SUSPENDED)，前 4 個 hit_resolved signal 已 fire。EnemyDirector 為剩餘 4 個 emit `combat_metric_anomaly(reason=GSM_SUSPENDED, context_dump={partial_aoe: true, completed: 4, remaining: 4})`。

### E.7 Catch-up / bfcache Edge Cases (Rule 15)

- **EC-35 [Catch-up]**: If bfcache resume queues 100 ability_cast events → EnemyDirector FIFO queue 拎前 12 個 (CATCH_UP_HITS_PER_FRAME_CAP) 喺 next frame call resolve_hit，剩 88 個下一 frame 再 12 個，~9 frames 完成 catch-up。RNG ordering preserved by hit_seq monotonic increment。

- **EC-36 [Catch-up]**: If catch-up queue size > `CATCH_UP_QUEUE_HARD_CAP = 1_000` (Section G knob, extreme bfcache) → EnemyDirector caller-side hard cap → drop oldest events 至 1000 + emit `combat_metric_anomaly(reason=CLAMP_TRIGGERED, context_dump={queue_overflow: true, dropped: <count>})`。Rationale: 超過 1000 events 表示 GymSys polling 累積異常，唔應該 spam combat。

- **EC-37 [Catch-up]**: If user closes tab 喺 catch-up 中途 → Godot Web Export `Node._notification(NOTIFICATION_WM_CLOSE_REQUEST)` 唔需要 CombatResolver 特殊處理 — queue lost is acceptable，#14 EnemyDirector 持有 queue，page unload 時 queue 隨 process 死。下次 boot 由 #11 stat replay + GymSys differential cursor 重建 state。

- **EC-38 [Catch-up]**: If catch-up RNG ordering differs from pre-suspend (e.g., events arrived out-of-order from GymSys polling) → hit_seq 應該由 GymSys event cursor 順序 assign，唔係 receive time。如果 EnemyDirector 偵測 `hit_seq` 唔 monotonic → sort by hit_seq before resolve，emit `combat_metric_anomaly(reason=CLAMP_TRIGGERED, context_dump={resort_required: true})`。

### E.8 Cross-System Interaction Edge Cases

- **EC-39 [Cross-System]**: If #14 EnemyDirector 喺 GSM transition 邊界 read stale `gsm_state` (read 喺 transition 前但 resolve 喺 transition 後) → CombatResolver Rule 4 Stage 1 second-check `ctx.gsm_state` 仍係 CombatActive (caller snapshot 時) → 過 validation，但 actual current GSM 已 Suspended → resolve 完成。Rationale: Rule 12 snapshot priority — 用 snapshot 一致性勝過 real-time gate 防止 mid-resolve race。下一 hit Stage 1 用新 gsm_state reject。

- **EC-40 [Cross-System]**: If #11 Stat System emit `stat_changed` 喺 resolve_hit 中途 (e.g., player ATK +10 mid-hit) → Rule 6 per-cast StatSnapshot 已 frozen，本 hit 用 snapshot value，stat change 影響下一 ability_cast。Rationale: 防止「hit half-resolved with old ATK, other half new ATK」inconsistency。

- **EC-41 [Cross-System]**: If #12 ability_cast signal payload 含 invalid `ability_id` post-#12 schema migration (old save with deprecated ID) → EnemyDirector caller-side check #12 AbilityRegistry.has(ability_id)，唔 build CombatContext，emit `combat_metric_anomaly(reason=INVALID_ABILITY_ID, context_dump={ability_id, source: "deprecated_id_post_migration"})`，唔 call resolve_hit。

- **EC-42 [Cross-System]**: If #6 ScreenEffects 同時收到 #5 `burst_started` (auto-dispatch hit_pause 50ms) AND #13 `hit_resolved(tier=HEAVY)` (auto-dispatch hit_pause 80ms) → #6 內部 coalesce — 後到嘅 hit_pause 如果 duration > 進行中的 → extend，否則 ignore。CombatResolver 唔負責 coalesce，#6 自己 handle。Rationale: combat 系統職責邊界清晰，effect coalesce 屬 #6 domain。

- **EC-43 [Cross-System]**: If #15 LootDrop 未 ready (e.g., scene 未 load) 但 `enemy_killed` signal fires → EnemyDirector emit signal 後 fire-and-forget，#15 listener 未 connect → signal 丟失。Rationale: Godot signal 預設行為 — 冇 listener 等於 noop。#15 boot 順序 要喺 #14 之前 (autoload order)，否則丟失嘅 kill events 永久 lost。標記為 [[autoload-boot-order]] 已喺 ADR-0006 Contract 4 sequential boot 解決 — Section F dependencies 明確列出 #15 + #28 boot 必須喺 #14 之前。

### E.9 GSM / Lifecycle Edge Cases (Rule 12)

- **EC-44 [GSM]**: If GSM 喺 single frame 內 transition CombatActive → Suspended → CombatActive (rapid toggle, e.g., bfcache flicker) → EnemyDirector 用 final GSM state (frame end) build CombatContext，所以呢 frame 任何 ability_cast 都按 final state 處理。Rationale: GSM transition_id 每次轉換新 id，hit_seq RNG seed 隨 transition_id 變 → 同一 input 不同 transition 產生不同 rng outcome (intended)。

- **EC-45 [GSM]**: If encounter 結束 (所有 enemy dead) 但 ability_cast 仍 queue 中 → EnemyDirector caller-side 偵測 target list empty → 唔 call resolve_hit，emit `combat_metric_anomaly(reason=DEAD_TARGET_RESOLVE, context_dump={encounter_ended: true})`。Rationale: 防止 stale ability_cast 對 null target 觸發 crash。

- **EC-46 [GSM]**: If GSM 永遠停留 Suspended (user 離開 tab 永久不返) → CombatResolver 無 timer 自動清空 queue，由 #28 telemetry session timeout (out-of-scope #13) 處理。CombatResolver 本身 stateless 冇 memory leak risk。

### E.10 Telemetry Edge Cases (Rule 13 + Rule 17)

- **EC-47 [Telemetry]**: If `combat_metric_anomaly` signal fires faster than #28 consume (e.g., 1000 anomaly/sec from infinite loop) → Rule 17 rate limit per-reason 10/sec hard cap silent drop + aggregate emit `{reason: original, dropped_count: N, aggregate: true}` window-end。

- **EC-48 [Telemetry]**: If `context_dump` payload size > 10KB (e.g., 含大 array) → Rule 17 EnemyDirector caller-side truncate to 10KB + 加 `{truncated: true}` field。Rationale: 防止 memory bloat + #28 storage overflow。

- **EC-49 [Telemetry]**: If anomaly handler 喺 #28 內部 trigger 另一 anomaly (recursion) → Godot signal 同步 dispatch 會 stack overflow。#28 (out-of-scope) 內部需有 recursion guard，CombatResolver 唔負責。標記為 [[28-recursion-guard]] 屬 #28 系統 responsibility (Section F flag 標記)。

- **EC-50 [Telemetry]**: If anomaly emit 喺 `_ready()` 時 (boot 階段 #28 未 ready) → 同 EC-43 處理 — signal 冇 listener 丟失。Autoload boot order 由 ADR-0006 Contract 4 保證 #28 喺 #14 EnemyDirector 之前 ready。Section F dependencies 明確列出 boot order requirement。

## Dependencies

CombatResolver 嘅 dependency surface — hard (system 唔可能 function without it) vs soft (enhanced by, 但 fallback graceful)，包含 upstream provider + downstream consumer，明確 ownership 同 contract source。Cross-system invariant 同 forward constraint 標記為 future GDD authoring guard。

### Upstream Dependencies (CombatResolver consumes)

| # | System | Hard/Soft | Interface | Source-of-truth | Notes |
|---|--------|-----------|-----------|-----------------|-------|
| **#11 Stat System** (Approved 2026-05-27) | Hard | `StatSystem.get_stat(&"ATTACK_POWER")` + `get_stat(&"CRIT_CHANCE")` (sync O(1) read by EnemyDirector caller, snapshot per Rule 6) | #11 Formula 4 + 6 (ATTACK_POWER 同 CRIT_CHANCE 公式定義) | Stat values 變化 mid-resolve_hit 由 snapshot 凍結 (EC-40) — 唔影響當前 hit |
| **#12 Ability System** (Approved 2026-05-27) | Hard | `ability_cast(ability_id, caster, target)` signal subscription by EnemyDirector via Contract 6 + `AbilityRegistry.tres` lookup for `{class, tier, target_type, base_cooldown_sec, base_damage_multiplier}` | #12 Rule 8 step 6 (signal emit) + #12 AbilityRegistry.tres (data-driven Resource per coding-standards) | **CROSS-SYSTEM FR-Q-F2**: `base_damage_multiplier: float` 字段需要 #12 AbilityRegistry.tres schema extension — 屬 minor schema bump 由本 GDD 觸發 propagate-design-change to #12 (Approved)；TIER_1=1.0 / TIER_2=1.8 / TIER_3=3.0 默認值 lock 喺 Section D Formula 1 |
| **#1 GameStateMachine** (Approved 2026-05-25) | Hard (indirect via EnemyDirector) | `GameStateMachine.current_state` + `current_transition_id` (sync read by EnemyDirector at ability_cast receipt) | #1 GSM Decision #4 (Suspended state) + ADR-006 Contract 2 (transition_id atomicity) | Suspended gate (Rule 12) + FR-1 RNG seeding (Rule 7) source；EnemyDirector caller-side snapshot priority over real-time query (Rule 12 amendment per EC-39) |
| **#14 EnemyDirector** (VS tier order 10, **NOT YET DESIGNED — provisional contract**) | Hard | CombatResolver 由 #14 instantiate；EnemyDirector 提供 `EnemyState{hp, max_hp, defense, faction, instance_id}` struct per ability_cast；EnemyDirector own `ability_cast` subscription + 3 signal emissions (hit_resolved / enemy_killed / combat_metric_anomaly) per Rule 3 + Rule 17 anomaly rate limiter | #14 GDD authoring (next system — VS tier order 10) | **PROVISIONAL CONTRACT** — 本 GDD lock 5 個 #14 obligations: (a) EnemyDirector subscribes to ability_cast via Contract 6 helper, (b) provides `EnemyState{hp, max_hp, defense, faction, instance_id}` per Rule 3, (c) injects RNG seeded on transition_id (Rule 7), (d) emits 3 signals on CombatResolver's behalf (Rule 3 + 13), (e) owns Rule 17 anomaly rate limiter + Rule 15 catch-up queue throttle (CATCH_UP_HITS_PER_FRAME_CAP = 12)。**#14 GDD authoring 必 re-review 呢 5 obligations** — bidirectional consistency check 必要 |

### Downstream Consumers (CombatResolver outputs)

| # | System | Hard/Soft | Consumes | Notes |
|---|--------|-----------|----------|-------|
| **#5 ParticleSystemWrapper** (Approved 2026-05-26) | Soft (auto-dispatch fallback per #5 Rule 9) | `hit_resolved.damage_tier` 路由 particle preset (HIT_HEAVY for HEAVY+ tier, HIT_LIGHT for LIGHT/MEDIUM, no particle for NEGLIGIBLE) | FR Test #4 binding — #25 Combat Visual Feedback 主要 caller，可 direct call `ParticleSystem.play(preset, position, caller_mult)` OR rely on #5 auto-dispatch；CombatResolver 唔直接 call #5 |
| **#6 ScreenEffects** (Approved 2026-05-26) | Soft (auto-dispatch fallback per #6 Rule 9) | `hit_resolved.damage_tier` 路由 shake + hit_pause intensity (NEGLIGIBLE / LIGHT → no shake; MEDIUM → trauma 0.2; HEAVY → trauma 0.4 + hit_pause 65ms; CRITICAL → trauma 0.6 + hit_pause 80ms) | FR Test #4 binding — #25 主要 caller；CombatResolver 唔直接 call #6；#6 own coalesce logic per EC-42 |
| **#14 EnemyDirector** (NOT YET DESIGNED) | Hard (self-listen) | `hit_resolved` apply damage to internal EnemyState + trigger stagger / knockback per `damage_tier`; `enemy_killed` clean up entity + transition_id propagation; `combat_metric_anomaly` rate-limit + forward to #28 | EnemyDirector instantiates CombatResolver + emits 3 signals 自身 — 同時亦 subscribe (own emissions self-listen for state update) |
| **#15 LootDrop System** (Pre-MVP tier order 17, **NOT YET DESIGNED — provisional contract**) | Hard (indirect via `enemy_killed.transition_id`) | `enemy_killed(payload).transition_id` 用作 #15 RNG seed source per ADR-005 `loot_rarity_score` formula | **PROVISIONAL CONTRACT** — `transition_id` field MUST 維持 String non-null；#15 GDD authoring 必 verify field usage 一致 with ADR-005 transition_id chain；**[[autoload-boot-order]] requirement**: #15 must boot BEFORE #14 (per EC-43, ADR-006 Contract 4 sequential boot) — `_ready()` 完成順序 #1 → #2 → #3 → #5 → #6 → #7 → #11 → #12 → #15 → #14 (EnemyDirector 最後)，否則 enemy_killed signal listener 未 connect → loot 丟失 |
| **#16 Boss System** (VS tier order 12, NOT YET DESIGNED) | Hard | Same `hit_resolved` + `enemy_killed` (boss = special enemy); boss `EnemyState` 可能含更高 defense + special phase metadata | Boss-specific phase logic 屬 #16 scope — CombatResolver stays generic, doesn't know「呢個係 boss」 |
| **#17 Equipment & Inventory** (MVP tier order 23, NOT YET DESIGNED) | Hard (indirect via #11 stat aggregation) | #17 applies `StatModifier` to #11 stats BEFORE CombatResolver reads — `caster_stats.attack_power` 已 reflect equipment | **CROSS-SYSTEM FORWARD CONSTRAINT (FR-Equipment-AntiSnowball)**: 為 honor Pillar 1 transduction (gym work = power, NOT gear = power) — equipment-derived ATK ≤ 3× stat-derived ATK 嘅 invariant 應喺 #17 GDD authoring 明確 enforce；本 GDD Section D anti-snowball matrix #4 flag |
| **#25 Combat Visual Feedback** (MVP tier order 29, NOT YET DESIGNED) | Hard | `hit_resolved.damage_tier` 路由 VFX library: particle preset (#5 caller) + damage number popup color + screen shake (#6 caller) + hit_pause request | FR Test #4 binding — #25 MUST 用 `damage_tier`，唔可以 re-derive from damage value；#25 主要 #5 + #6 caller，CombatResolver 只 trigger source |
| **#28 Telemetry / Analytics** (Pre-MVP tier order 21, NOT YET DESIGNED) | Hard | All 3 signals (`hit_resolved` + `enemy_killed` + `combat_metric_anomaly`) — `combat_metric_anomaly` 係 anti-fabrication channel (Pillar 1 binding)，#28 escalate 若 rate > threshold | **[[28-recursion-guard]]**: per EC-49 — #28 內部 anomaly handler MUST 有 recursion guard 防止 infinite loop；屬 #28 GDD authoring responsibility，CombatResolver 唔負責。**[[autoload-boot-order]]**: #28 boots **Last** per ADR-0008 (G-TEL-1, canonical map) — **NOT** before #14 (Q-T1 erratum 2026-06-12). The 3 signals are runtime emits (CombatActive / boss-kill), far after every `_ready()`, so #28's `connect_for_initial_state` late-boot catches all with zero silent drop; the pre-ADR-0008 EC-50「before #14」fear is superseded |

### Autoload Boot Order Requirement (cross-system invariant)

Per ADR-006 Contract 4 sequential autoload boot + EC-43 / EC-50 boot order requirement，autoload `_ready()` 順序 MUST 為:

```
position 1: #3 PersistenceLayer  (Approved Foundation — already locked)
position 2: #1 GameStateMachine  (Approved Foundation — already locked)
position 3: #2 GymSys Backend Client + #4 Audio Manager + others (Approved Foundation)
position 4: #11 Stat System      (Approved Core — already locked)
position 5: #12 Ability System   (Approved Core — already locked)
...
position N-1: #15 LootDrop System (boot BEFORE #14 — EC-43 HARD constraint, still valid)
position N:   #14 EnemyDirector  (boots after its #15 loot consumer; NOT the absolute
                                  last — presentation/coordinator autoloads + #28 boot
                                  after it per ADR-0008)
position Last: #28 Telemetry     (boots LAST per ADR-0008 G-TEL-1 — Q-T1 erratum 2026-06-12:
                                  NOT before #14; the 3 combat signals are runtime emits so
                                  late-boot via connect_for_initial_state catches all)
```

Rationale: CombatResolver 唔係 autoload，但由 #14 EnemyDirector instantiate；#14 boot 期間立即 instantiate CombatResolver context + emit 3 signals — 如果 #15 / #28 未 boot → `enemy_killed` + `combat_metric_anomaly` signals 冇 listener → silently 丟失 (Godot signal default behavior，唔 buffer)。本 GDD lock 呢個 boot order requirement 為 #14 + #15 + #28 GDD authoring 嘅 cross-system invariant。

### Cross-System Forward Constraints (FR-Author flags for future GDDs)

| FR ID | Scope | Constraint | Owner GDD (future) | Verification |
|-------|-------|------------|---------------------|--------------|
| FR-Q-F2 | #12 Ability System | `AbilityRegistry.tres` schema 加 `base_damage_multiplier: float` field — default TIER_1=1.0 / TIER_2=1.8 / TIER_3=3.0 per Section D Formula 1 | #12 next /design-system revision OR /propagate-design-change run | Section D Formula 1 worked example calibration assumes 呢 3 個 default values |
| FR-Equipment-AntiSnowball | #17 Equipment & Inventory | equipment-derived ATK ≤ 3× stat-derived ATK invariant — 防 gear power dominance over gym work transduction | #17 GDD authoring | Section D anti-snowball matrix #4 flag |
| FR-EnemyDirector-Contract | #14 EnemyDirector | 5 obligations per upstream table — subscription / EnemyState struct / RNG injection / 3 signal emit / rate limiter | #14 GDD authoring (VS tier order 10, next system) | Re-review 5 obligations bidirectional consistency |
| FR-LootDrop-TransitionId | #15 LootDrop System | `enemy_killed.transition_id` 用作 `loot_rarity_score.rng_roll` seed source per ADR-005 chain — 唔可以 #15 generate new RNG | #15 GDD authoring | ADR-005 Pillar 1 chain integrity |
| FR-Telemetry-RecursionGuard | #28 Telemetry | anomaly handler 內 recursion guard 防 infinite signal loop | #28 GDD authoring | EC-49 [[28-recursion-guard]] flag |
| FR-Autoload-BootOrder | Project-wide | #15 + #28 boot before #14 — per EC-43 + EC-50 + ADR-006 Contract 4 | #14 + #15 + #28 GDD authoring + `project.godot` autoload section | EC-43 / EC-50 cross-reference |

### Bidirectional Consistency Check

呢個 GDD declares dependencies；對應 systems 嘅 GDDs (if existing) 應 list CombatResolver as 「Depended on by」:

| Cross-system | Bidirectional listing status |
|--------------|------------------------------|
| #11 Stat System (Approved) | ✓ #11 Interactions table line 257 lists `#13 CombatResolver — reads, NO signal subscription (read-on-demand)`。**ALIGN with 本 GDD Rule 6 snapshot pattern** — #11 描述「read-on-demand」 actually means「snapshot read by caller, not subscription」per本 GDD 詳細 spec；屬 minor #11 row update for clarity (flag for #11 next-revision batch — non-blocking) |
| #12 Ability System (Approved) | ✓ #12 Interactions table 各 row lists `#13 CombatResolver — subscribes ability_cast, computes damage post-signal`。Aligned with 本 GDD Rule 3。但 #12 Rule 8 step 6 `ability_cast` signal payload **未含 `transition_id` field** — 本 GDD 採 [B] EnemyDirector pulls from GSM at resolve time，唔 require #12 schema revision (decoupled solution) ✓ |
| #1 GameStateMachine (Approved) | ⚠ #1 GDD 唔具體 list 每個 downstream consumer — universal Suspended gate convention (per ADR-006 Contract 4 + #1 Decision #4)；本 GDD 通過 EnemyDirector intermediary read，唔需 #1 GDD revision |
| #5 / #6 (Approved) | ✓ #5 + #6 Auto-dispatch rules (Rule 9 各自) 預期接收 hit / burst event；本 GDD `hit_resolved.damage_tier` payload contract 跟 #5 + #6 expected enum routing ALIGN |
| #14 / #15 / #16 / #17 / #25 / #28 (NOT YET DESIGNED) | Forward constraints flagged per FR-Author table above — bidirectional consistency 將喺 future GDD authoring 確認 |

## Tuning Knobs

CombatResolver 嘅 11 個 owned knobs — 5 個 formula knobs (Section D) + 3 個 EC NEW RULE knobs (Section E flags) + 3 個 rule-level knobs (Section C limits)。所有 knobs 用 `const` 喺 `src/core/combat_resolver.gd` declared (per Rule 1 const allowed)，或者 `AbilityRegistry.tres` data-driven entries。冇 designer-runtime tuning UI (敏感於 deterministic replay — runtime mutation 違反 Pillar 1)。

### Owned Knobs (本 GDD ownership)

| # | Knob name | Type | Default | Safe range | What breaks if too high | What breaks if too low | Source |
|---|-----------|------|---------|------------|--------------------------|--------------------------|--------|
| 1 | `CRIT_MULTIPLIER` | float | **1.5** | [1.2, 2.5] | > 2.5: anti-snowball invariant `CRIT_MULTIPLIER × MAX_CRIT_CHANCE ≤ 0.75` 失守，期望值滑出 → crit one-shot degenerate | < 1.2: crit 變不明顯，玩家認知唔到「crit moment」→ Pillar 3 dopamine signal 不到 | Section D Formula 3, Q-D2 [A] decision |
| 2 | `T_CRITICAL` | float | **0.40** (ratio of MAX_HP) | [0.30, 0.60] | > 0.60: 單 hit > 60% boss HP = one-shot territory，違反 Pillar 3「boss fight」design intent → Pillar 3 dopamine 變 boredom | < 0.30: CRITICAL tier 太易達到 → tier 通脹，所有 hit 都 critical → FR Test #4 信號失意義 | Section D Formula 4, Q-D4 [B] decision |
| 3 | `T_HEAVY` | float | **0.15** | [0.10, 0.25] | > 0.25: HEAVY tier 太難達到 → DNF 重擊 feel 稀有 → Pillar 3 信號 dilution | < 0.10: HEAVY tier 太普通 → hit_pause 65ms 每幾 hit 觸發 → 玩家 attention 被搶 → Pillar 2 violation | Section D Formula 4 |
| 4 | `T_MEDIUM` | float | **0.05** | [0.03, 0.08] | > 0.08: MEDIUM 跟 HEAVY 太近 → tier band 過窄 | < 0.03: 跟 LIGHT 太近 → 同樣 band 過窄問題 | Section D Formula 4 |
| 5 | `T_LIGHT` | float | **0.01** | [0.005, 0.02] | > 0.02: NEGLIGIBLE band 收窄 → 玩家覺得每 hit 都有 visual feedback → 視覺 noise floor 不到 | < 0.005: LIGHT 太易達到 → 同樣 noise floor 問題 | Section D Formula 4 |
| 6 | `MAX_TARGETS_PER_CAST` | int | **8** | [4, 12] | > 12: AOE 8+ hits / frame × 0.05ms = 0.6ms+ CPU → 接近 ADR-001 1.0ms p95 budget ceiling | < 4: AOE 力量 dilute → MOBILITY class TIER_3 GROUND_POUND 失去戰術價值 | Section C Rule 14 |
| 7 | `CATCH_UP_HITS_PER_FRAME_CAP` | int | **12** | [6, 20] | > 20: 20 × 0.05ms = 1.0ms 已等於 ADR-001 budget，bfcache resume 個 frame 必 spike → Pillar 2 frictionless 失守 | < 6: catch-up 太慢，5min bfcache backlog 需 > 17 frames → 玩家 resume 後見到 progress bar slow tick | Section C Rule 15 |
| 8 | `BASE_DAMAGE_OVERFLOW_CAP` | int | **1_000_000** | [500_000, 10_000_000] | > 10M: cap too lax，stat scaling bug 唔被即時 catch | < 500k: 合法 endgame stat scaling 可能 false-positive trigger → CLAMP_TRIGGERED anomaly spam | Section E EC-14 NEW RULE |
| 9 | `MAX_HIT_SEQ` | int | **1_000_000** | [100_000, 10_000_000] | > 10M: hit_seq int overflow protection 失效 | < 100k: 長時間 session 可能 false-positive (一場 boss fight 可能 ~500 hits，1 hour session 估計 ~30k hits，10萬 應該夠) | Section E EC-27 NEW RULE |
| 10 | `CATCH_UP_QUEUE_HARD_CAP` | int | **1_000** | [500, 5_000] | > 5000: memory 累積 + drop point 太遲 — bfcache backlog 異常情況 swallow 過多 | < 500: 合法 5min bfcache backlog (~50-100 events typical) 可能 false-positive truncate | Section E EC-36 NEW RULE |
| 11 | `ANOMALY_RATE_LIMIT_PER_REASON_PER_SEC` | int | **10** | [3, 50] | > 50: anomaly spam 唔被 rate-limit，#28 telemetry queue overflow | < 3: 合法 burst anomaly (e.g., 5 個 AOE hit 全部 INVALID_TARGET) 被過早 silent drop → debugging 困難 | Section C Rule 17 (Section E EC-47 NEW RULE) |

### Data-Driven Knobs (via `#12 AbilityRegistry.tres` schema)

| # | Knob name | Type | Default | Safe range | Notes |
|---|-----------|------|---------|------------|-------|
| 12 | `base_damage_multiplier` (per ability_id) | float | TIER_1=**1.0** / TIER_2=**1.8** / TIER_3=**3.0** | [0.5, 3.0] per entry | Owned by #12 AbilityRegistry.tres post-schema-extension (FR-Q-F2 forward constraint); cross-knob invariant: `TIER_3 / TIER_1 ≤ 4.0` ratio cap |

### Knobs Referenced from Upstream (read-only — owned by other GDDs)

| Knob | Source GDD | Value | Why CombatResolver reads |
|------|------------|-------|--------------------------|
| `MAX_CRIT_CHANCE` | #11 Stat System | 0.50 | Formula 2 (`CRIT_CHANCE` 上限) + anti-snowball invariant `CRIT_MULTIPLIER × MAX_CRIT_CHANCE ≤ 0.75` |
| `ATK_BASE` / `ATK_PER_STR` / `ATK_PER_DEX` | #11 Stat System | 10 / 1.5 / 0.3 | Formula 1 (#11 computes ATTACK_POWER, #13 consume aggregated value) |
| `CRIT_PER_DEX` | #11 Stat System | 0.0015 | Formula 2 (DEX → CRIT_CHANCE conversion, read-only) |
| `MAX_OFFSET_PX` | #6 ScreenEffects | 4.0 | Reference — `hit_resolved.damage_tier` 觸發 #6 shake，最大 amplitude 由 #6 own |
| `MAX_PAUSE_SEC` | #6 ScreenEffects | 0.12 | Reference — hit_pause cap |
| `MAX_ACTIVE_PARTICLES` | #5 ParticleSystemWrapper | 200 (mobile) / 400 (desktop) | Reference — `hit_resolved.damage_tier` 觸發 #5 particle，pool budget 由 #5 own (per ADR-001) |
| `gymsys_poll_interval_seconds` | game-concept | 5.0 | Reference — catch-up backlog 來源 cadence；CATCH_UP_QUEUE_HARD_CAP 設計考慮呢個 |

### Cross-Knob Invariants (Hard + Soft)

| # | Invariant | Type | Default Status |
|---|-----------|------|----------------|
| INV-1 | `CRIT_MULTIPLIER × MAX_CRIT_CHANCE ≤ 0.75` (anti expected-value snowball) | HARD | 1.5 × 0.50 = 0.75 ✓ |
| INV-2 | `CRIT_MULTIPLIER × max(base_damage_multiplier) ≤ 5.0` (anti single-hit one-shot cap) | HARD | 1.5 × 3.0 = 4.5 ✓ |
| INV-3 | `T_CRITICAL > T_HEAVY > T_MEDIUM > T_LIGHT > 0` (strict monotonic tier ordering) | HARD | 0.40 > 0.15 > 0.05 > 0.01 ✓ |
| INV-4 | `T_CRITICAL ≤ 0.60` (anti boss one-shot tier inflation) | HARD | 0.40 ≤ 0.60 ✓ |
| INV-5 | `max(MAX_TARGETS_PER_CAST, CATCH_UP_HITS_PER_FRAME_CAP) × 0.05ms ≤ ADR-001 budget 1.0ms` (catch-up OR AOE worst-case — Rule 18 mutual exclusion enforces serialization) | **HARD** (per CD F6 inline-fix 2026-05-27) | max(8, 12) × 0.05ms = 0.6ms ≤ 1.0ms ✓ (post-Rule 18 mitigation; pre-Rule 18 combined 4.8ms would have violated) |
| INV-6 | `TIER_3 base_damage_multiplier / TIER_1 base_damage_multiplier ≤ 4.0` (proportional tier scaling, mirrors #12 Formula 2 INV-7) | HARD | 3.0 / 1.0 = 3.0 ✓ |
| INV-7 | `BASE_DAMAGE_OVERFLOW_CAP > max_realistic_endgame_damage × 2` (defensive margin) | SOFT | 1M > expected ~50k endgame damage × 2 = 100k ✓ (10× margin) |
| INV-8 | `CATCH_UP_QUEUE_HARD_CAP ≥ 5 × MAX_TARGETS_PER_CAST × MAX_BACKLOG_MINUTES` (legitimate 5-min bfcache survivability) | SOFT | 1000 ≥ 5 × 8 × 5 = 200 ✓ (5× margin) |

### Knob Hierarchy (per game-concept Producer Hard Governance)

| Tier | Can change at... | Examples |
|------|------------------|----------|
| **LOCKED** (schema bump required) | Cross-GDD revision via /propagate-design-change | HitOutcome 4 values (Rule 5 LOCKED — adding DODGED = schema bump per Q-C v0.2 deferred) + DamageTier 5 values |
| **HARD** (changing affects multiple ACs) | Major design revision | INV-1 / INV-2 / INV-3 / INV-4 / INV-6 (anti-snowball + monotonic) |
| **SOFT** (designer can adjust) | Section H AC verifies safe range | knobs 1-11 within safe ranges |
| **DATA-DRIVEN** (per ability via .tres) | AbilityRegistry.tres edit (no code change) | knob 12 base_damage_multiplier |
| **REFERENCE** (read-only) | Owner GDD revision | upstream knobs from #5 / #6 / #11 / #12 |

## Visual/Audio Requirements

**Scope clarification**: CombatResolver 係 **pure math + signal source**，本 GDD 唔 own 任何 VFX preset / particle sprite / shader / animation / audio cue / sound effect file。VFX library 由 #25 Combat Visual Feedback own (MVP tier order 29 — NOT YET DESIGNED)；particle preset 同 GPU budget 由 #5 ParticleSystemWrapper own (Approved)；screen shake + hit pause shader 由 #6 ScreenEffects own (Approved)；audio cue 由 #4 Audio Manager own (MVP tier order 22 — NOT YET DESIGNED)；avatar attack animation 由 #26 Avatar Renderer own (VS tier order 13 — NOT YET DESIGNED)。

**Visual/Audio contract** (signal payload spec — `hit_resolved` 作為 trigger source):

| Downstream | Field consumed | Visual / Audio mapping (recommended default — actual spec owned by consumer) |
|------------|----------------|------------------------------------------------------------------------------|
| **#5 ParticleSystemWrapper** | `damage_tier` | NEGLIGIBLE → no particle；LIGHT → `HIT_LIGHT` preset (small spark)；MEDIUM → `HIT_LIGHT` preset (extended duration)；HEAVY → `HIT_HEAVY` preset (DNF 重擊 burst)；CRITICAL → `HIT_HEAVY` preset + crit-color overlay |
| **#5 ParticleSystemWrapper** | `enemy_killed` event | `DEATH` preset — death burst overrides any active hit particle |
| **#6 ScreenEffects** | `damage_tier` (via #25 caller OR auto-dispatch) | NEGLIGIBLE / LIGHT → no shake；MEDIUM → `shake(intensity=0.2, duration=0.05s)`；HEAVY → `shake(0.4, 0.08) + hit_pause(0.065)`；CRITICAL → `shake(0.6, 0.10) + hit_pause(0.08)` |
| **#4 Audio Manager** | `damage_tier` | NEGLIGIBLE → no sound (anti-noise floor)；LIGHT → `hit_light.wav` (短促 thud)；MEDIUM → `hit_medium.wav`；HEAVY → `hit_heavy.wav` (DNF impact + low-pass duck)；CRITICAL → `hit_crit.wav` (crit fanfare + screen sweep) |
| **#4 Audio Manager** | `enemy_killed` event | `enemy_death.wav` per `enemy_id` enemy template (sound bank lookup) — overrides any in-flight hit sound |
| **#25 Combat Visual Feedback** | `damage_dealt, damage_tier, is_crit` | Damage number popup color: NEGLIGIBLE → no popup; LIGHT/MEDIUM → white; HEAVY → orange; CRITICAL → yellow + larger font + animation (per DNF cultural convention) |
| **#26 Avatar Renderer** | `ability_id` (from upstream `ability_cast`, not `hit_resolved`) | Avatar attack animation per ability_id — `STRIKE_TIER_1_JAB` → quick punch；`STRIKE_TIER_3_OVERHAND` → wind-up + overhead swing；etc. |

**Visual identity alignment** (per game-concept Visual Identity Anchor):
- DNF 重擊 cultural reference — `damage_tier ≥ HEAVY` 觸發完整 cascade (hit_pause + screen shake + particle burst + sound) 應該感覺「乾淨剪影 + 骯髒粒子」一致 (per Visual Identity Anchor Principle 1 "Silhouette First" + Principle 2 "Particle Budget Rule")
- Crit yellow color (per `damage_tier=CRITICAL` mapping) 用 **DNF cultural convention** (獨立於 game-concept Color Philosophy loot rarity ladder white → green → blue → purple → orange — yellow 唔在 ladder 入面)。Combat crit moment 同 loot drop 屬唔同 visual semantic layer — combat hit cascade vs loot reward fanfare，唔共享同一 color identity。Layer separation 防止「眼角瞄到」時 confuse crit moment 同 LOOT_RARE_BURST drop event。Crit color final selection 待 art-bible authoring 時 ratify (cf. Q-Visual-CritColor open question)
- Mobile fallback per ADR-001 `MOBILE_FALLBACK_MULTIPLIER = 0.5` 自動 reduce particle count — 此調整由 #5 內部處理，CombatResolver `hit_resolved.damage_tier` 信號 contract 唔變

📌 **Asset Spec**: CombatResolver 本身 **冇 owned asset** — 唔需要 `/asset-spec system:combat-resolver`。下游 systems (#5 / #6 / #25 / #4 / #26) 各自喺 art bible approved 後 run `/asset-spec system:[downstream-system]` 為自己 owned asset 產出 visual specs + AI generation prompts。本 GDD V/A section 提供咗 signal-contract trigger source spec，方便下游 GDD authoring 引用一致 mapping。

## UI Requirements

**Scope clarification**: CombatResolver 純 **non-UI data layer** — 唔 own HUD render / menu / damage number popup 任何 player-visible UI element。

**UI binding source contract**: 下游 UI consumer subscribe `hit_resolved` + `enemy_killed` signal，binding 以下 UI updates：

| Downstream UI | Signal binding | UI behavior (recommended — actual spec owned by consumer) |
|---------------|----------------|-----------------------------------------------------------|
| **#20 Gym-Mode HUD** (MVP tier order 25, NOT YET DESIGNED) | `hit_resolved.damage_dealt + damage_tier + is_crit` | Damage number popup over target；color per damage_tier；crit 大字 + animation；HP bar realtime update per `target_hp_after` |
| **#22 Character Screen** (MVP tier order 26, NOT YET DESIGNED) | `enemy_killed.enemy_id + transition_id` (historical aggregation via #28 Telemetry) | Stat-page combat history pane — total hits / crits / kills count + time-to-kill statistics per enemy archetype |
| **#25 Combat Visual Feedback** (MVP tier order 29, NOT YET DESIGNED) | `hit_resolved.damage_tier, is_crit` | Damage number rendering style (color / size / animation) + screen sweep on CRITICAL + obliterate overlay on OVERKILL |

📌 **UX Flag — CombatResolver**: 本 GDD 唔 own 任何 UI screen，所以**唔需要** 直接 run `/ux-design` for CombatResolver。但下游 #20 / #22 / #25 喺 Pre-Production phase 認 `/ux-design` 時，必 reference 本 GDD signal-contract 表 + Visual/Audio section 為 UI binding spec source。Stories 認 UI 時 cite `design/ux/[downstream-screen].md`，唔可以 cite 本 GDD 直接 (per /design-system UI Flag convention)。

## Acceptance Criteria

**Total**: 37 ACs (30 BLOCKING + 6 ADVISORY + 1 ADR-RATIFICATION-GATED)

**Test category tag legend**:
- Type: `[Logic | Integration | Visual | UI | Config]`
- Gate: `[BLOCKING | ADVISORY | ADR-RATIFICATION-GATED]`
- Test mode: `unit | integration | static | CI | benchmark | playtest`

### H.1 Architecture & Purity (Rules 1, 2, 6)

- **AC-01 [Logic | BLOCKING | static]**: GIVEN `CombatResolver.gd` source file, WHEN static analyzer (`tools/ci/check_combat_resolver_purity.gd`) scan 個 class body, THEN 唔可以見到任何 `var` instance member、`@onready`、`signal` declaration，剩低 `class_name CombatResolver extends RefCounted` + `static func` only。違反即 CI fail。
  - File: `tools/ci/check_combat_resolver_purity.gd`

- **AC-02 [Logic | BLOCKING | unit]**: GIVEN 兩個 identical `CombatContext` input (deep-equal fields), WHEN `CombatResolver.resolve_hit(ctx_a)` 同 `resolve_hit(ctx_b)` 順序執行 1000 次, THEN 兩邊 returned `HitResult` 全部 field-for-field 相等 (damage_dealt / outcome / damage_tier / is_crit / overkill_excess / rng_roll_value)。證明 stateless。
  - File: `tests/unit/combat/test_combat_resolver_purity.gd`

- **AC-03 [Logic | BLOCKING | unit]**: GIVEN `CombatResolver` static functions only, WHEN test 嘗試 `CombatResolver.new()`, THEN instantiation 應該成功 (RefCounted 容許) 但 instance 唔可以 hold state — repeated `resolve_hit` call on same instance 同 fresh instance produce 相同 result。Sanity guard against accidental instance-state introduction。
  - File: `tests/unit/combat/test_combat_resolver_purity.gd`

- **AC-04 [Logic | BLOCKING | unit]**: GIVEN single `resolve_hit` call with `CombatContext.caster_stats.attack_power=100`, WHEN test mid-call 改動原 source StatSystem 嘅 attack_power 去 999 (透過 mock), THEN returned `HitResult.damage_dealt` 計算仍用 snapshot 嘅 100，唔受 source mutation 影響。證明 per-cast StatSnapshot pattern (Rule 6)。
  - File: `tests/unit/combat/test_combat_resolver_snapshot.gd`

- **AC-05 [Logic | BLOCKING | static]**: GIVEN `CombatResolver.resolve_hit` signature, WHEN static type checker run, THEN entry point 必須係 `static func resolve_hit(ctx: CombatContext) -> HitResult`，所有 typed parameters，無 `Variant` return。Single-entry-point invariant (Rule 2)。
  - File: `tools/ci/check_combat_resolver_purity.gd`

### H.2 Signal & Subscription (Rules 3, 8, 9, 13, 17)

- **AC-06 [Integration | BLOCKING | integration]**: GIVEN fresh `EnemyDirector` autoload boot, WHEN `_ready()` 完成, THEN `EnemyDirector` 必須已經 subscribe `AbilitySystem.ability_cast` signal via Contract 6 `connect_for_initial_state` helper，AND own `hit_resolved` / `enemy_killed` / `combat_metric_anomaly` 三條 signal emitter wiring。CombatResolver 本身 emit nothing — 純 return HitResult。
  - File: `tests/integration/combat/test_enemy_director_signal_wiring.gd`

- **AC-07 [Logic | BLOCKING | unit]**: GIVEN `HitResolvedPayload` struct, WHEN test inspect schema, THEN 必須包含全部 field: `ability_id: StringName, caster_id: int, target_id: int, outcome: HitOutcome, damage_tier: DamageTier, damage_dealt: int, damage_raw: float, target_hp_after: int, is_crit: bool, is_kill: bool, transition_id: String, resolved_at_tick: int`。`damage_tier` 唔可以係 null / missing (FR Test #4 mandatory)。
  - File: `tests/unit/combat/test_hit_resolved_payload_schema.gd`

- **AC-08 [Integration | BLOCKING | integration]**: GIVEN `resolve_hit` returned `HitResult.is_kill == true`, WHEN EnemyDirector emit `enemy_killed` signal, THEN payload 必須 propagate 原 `ctx.transition_id` (string identity check)，俾下游 #15 LootDrop 用嚟做 RNG sub-seed。FR-2 binding。
  - File: `tests/integration/combat/test_enemy_killed_transition_id_propagation.gd`

- **AC-09 [Logic | BLOCKING | unit]**: GIVEN `combat_metric_anomaly` signal emission, WHEN test trigger 6 種 anomaly 情況 (GSM_SUSPENDED / INVALID_ABILITY_ID / NEGATIVE_DAMAGE / CLAMP_TRIGGERED / DEAD_TARGET_RESOLVE / RNG_INJECTION_MISSING), THEN 每次 emit 嘅 payload `reason` field 必須係 enum 6 值之一，唔可以係 free-form string。
  - File: `tests/unit/combat/test_anomaly_reason_enum.gd`

- **AC-10 [Integration | ADVISORY | integration]**: GIVEN EnemyDirector caller emit `combat_metric_anomaly` at >10/sec rate per reason, WHEN rate limiter engage, THEN excess emissions get coalesced 成 single summary event with `dropped_count`。CombatResolver 本身唔做 rate limiting (Rule 17 — caller-side obligation)。
  - File: `tests/integration/combat/test_anomaly_rate_limit.gd`

- **AC-11 [Logic | BLOCKING | unit]**: GIVEN AOE cast with `targets.size() == 5`, WHEN EnemyDirector iterate calls `CombatResolver.resolve_hit(ctx_i)` for each target, THEN 返回 5 個獨立 `HitResult` instances，order 同 input targets 一致；每個 ctx 嘅 `hit_seq` 各自 0/1/2/3/4。1-to-1 mapping (Rule 14)。
  - File: `tests/unit/combat/test_combat_resolver_aoe.gd`

### H.3 Pipeline & Computation (Rule 4, Formulas 1-5)

- **AC-12 [Logic | BLOCKING | unit]**: GIVEN `ctx.caster_stats.attack_power=100, ability_damage_multiplier=2.0, target.defense=50`, WHEN `compute_hit_damage` run, THEN `base_damage == max(1, round(100 × 2.0 − 50)) == 150`。Formula 1 binding。
  - File: `tests/unit/combat/test_compute_hit_damage.gd`

- **AC-13 [Logic | BLOCKING | unit]**: GIVEN `attack_power × multiplier − defense < 1` (e.g., attack=10, mult=1.0, defense=100), WHEN `compute_hit_damage` run, THEN result == 1 (min floor)，NOT 0 or negative。Boundary of Formula 1 max(1, ...) clamp。
  - File: `tests/unit/combat/test_compute_hit_damage.gd`

- **AC-14 [Logic | BLOCKING | unit]**: GIVEN fixed `transition_id="TX-001"`, `ability_id="STRIKE_TIER_1_JAB"`, `hit_seq=3`, WHEN `roll_crit` called 1000 次 with identical sub-seed `hash(transition_id + ability_id + hit_seq)`, THEN 1000 次 return 完全相同 boolean 值。Determinism of Formula 2。
  - File: `tests/unit/combat/test_roll_crit_determinism.gd`

- **AC-15 [Logic | BLOCKING | unit]**: GIVEN `is_crit=true, base_damage=100`, WHEN `apply_crit_multiplier` run, THEN `crit_damage == round(100 × 1.5) == 150`。Formula 3 binding。Edge case: base=1 → round(1.5) == 2。
  - File: `tests/unit/combat/test_apply_crit_multiplier.gd`

- **AC-16 [Logic | BLOCKING | unit]**: GIVEN `target.max_hp=1000` 同 `damage_dealt` 分別係 [9, 50, 149, 400, 401], WHEN `classify_damage_tier` run, THEN tier 分別係 [LIGHT, MEDIUM, MEDIUM, HEAVY, CRITICAL]。Verify 5-tier ratio boundaries (0.01 / 0.05 / 0.15 / 0.40) of Formula 4。
  - File: `tests/unit/combat/test_classify_damage_tier.gd`

- **AC-17 [Logic | BLOCKING | unit]**: GIVEN `is_crit=true, damage_dealt=20, target.max_hp=1000` (ratio=0.02 normally LIGHT), WHEN `classify_damage_tier` run, THEN tier == HEAVY (crit override 強制 ≥HEAVY per Rule 10)。
  - File: `tests/unit/combat/test_classify_damage_tier.gd`

- **AC-18 [Logic | BLOCKING | unit]**: GIVEN `target.hp=50, damage_raw=200`, WHEN `detect_overkill` run, THEN `HitResult.damage_dealt == 50` (clamped) AND `outcome == OVERKILL` AND `overkill_excess == 150`。Formula 5 binding。
  - File: `tests/unit/combat/test_detect_overkill.gd`

- **AC-19 [Logic | BLOCKING | unit]**: GIVEN `target.hp=50, damage_raw=50` (exact kill), WHEN `detect_overkill` run, THEN `outcome == KILLED` (NOT OVERKILL) AND `overkill_excess == 0`。Boundary EC-22 binding。
  - File: `tests/unit/combat/test_detect_overkill.gd`

- **AC-20 [Logic | BLOCKING | unit]**: GIVEN `resolve_hit` 5-stage pipeline, WHEN test trace single hit execution via instrumented hook, THEN stages 必須按順序執行: validate → compute_hit_damage → roll_crit → apply_crit_multiplier → detect_overkill + classify_damage_tier → outcome assignment。Stage skip / reorder 即 fail。
  - File: `tests/unit/combat/test_pipeline_order.gd`

- **AC-21 [Logic | BLOCKING | unit]**: GIVEN `HitOutcome` enum, WHEN test enumerate values, THEN 必須剛好係 4 個值: NORMAL_HIT / CRITICAL_HIT / KILLED / OVERKILL。DODGED 必須唔存在 (Rule 5 + Rule 16 — MVP scope discipline)。
  - File: `tests/unit/combat/test_hit_outcome_enum.gd`

### H.4 Determinism & RNG (Rule 7, Falsifiable Tests #1 + #2)

- **AC-22 [Logic | BLOCKING | unit]** (FR Test #1 — Pillar 1 RNG anti-fabrication): GIVEN `transition_id="TX-replay-001"`, ability cast with `ability_id="STRIKE_TIER_2_HOOK"`, target sequence A→B→C, WHEN test run sequence 兩次 (fresh process each time), THEN 兩 run 嘅 全部 HitResult 完全相同 (包括 rng_roll_value field)。FR-1 + Falsifiable Test #1 binding — replay determinism。
  - File: `tests/unit/combat/test_rng_replay_determinism.gd`

- **AC-23 [Logic | BLOCKING | unit]**: GIVEN 兩個 cast 用相同 `ability_id` 同 `hit_seq` 但唔同 `transition_id` ("TX-A" vs "TX-B"), WHEN `roll_crit` 各執行一次, THEN sub-seed `hash("TX-A" + ability_id + hit_seq) != hash("TX-B" + ability_id + hit_seq)` AND 兩個 RNG stream 獨立 (test 10000 sample 統計 chi-square 唔 reject independence)。
  - File: `tests/unit/combat/test_rng_subseed_independence.gd`

- **AC-24 [Logic | BLOCKING | unit]**: GIVEN `transition_id` 含 unicode characters ("TX-測試-🎲-001"), WHEN `hash(transition_id + ability_id + hit_seq)` 計算, THEN sub-seed function 唔可以 throw / return 0 / collide with ASCII transition_id。EC-28 binding。
  - File: `tests/unit/combat/test_rng_unicode_transition_id.gd`

- **AC-25 [Logic | BLOCKING | unit]**: GIVEN `hit_seq` approaching `MAX_HIT_SEQ = 1_000_000` (Section G knob), WHEN sub-seed hash 計算, THEN 唔可以 integer overflow throw exception；應該 wrap 安全 (test boundary hit_seq = MAX_HIT_SEQ-1, MAX_HIT_SEQ, MAX_HIT_SEQ+1 — 最後一個 reject + anomaly emit)。EC-27 binding。
  - File: `tests/unit/combat/test_rng_hit_seq_overflow.gd`

- **AC-36 [Logic | BLOCKING | unit]** (FR Test #2 — Pillar 1 stat transduction continuity): GIVEN 同一個 `ability_id` + 同一個 `target` (固定 HP/defense) + 同一個 `rng_seed`，但 `caster_stats.attack_power` 由 100 → 150, WHEN `resolve_hit` 跑 2 次 (前後 ATTACK_POWER 唔同), THEN `damage_dealt2 > damage_dealt1` 嚴格 strictly increasing (monotonically increasing in ATTACK_POWER)。冇任何 hidden state / accumulator / frame-counter 影響輸出 — damage = pure function of inputs per Falsifiable Test #2 binding。
  - File: `tests/unit/combat/test_stat_transduction_continuity.gd`

### H.5 Edge Cases & Validation (sample ECs from E.1-E.10)

- **AC-26 [Logic | BLOCKING | unit]**: GIVEN `ctx == null`, WHEN `resolve_hit(null)` called, THEN return safe `HitResult{outcome=NORMAL_HIT, damage_dealt=0, damage_tier=NEGLIGIBLE}` AND `push_error("CombatResolver: null ctx")` 入 Godot log AND 唔可以 crash。EC-01 binding。
  - File: `tests/unit/combat/test_validate_null_ctx.gd`

- **AC-27 [Logic | BLOCKING | unit]**: GIVEN `ctx.target_state.hp == 0` (already dead), WHEN `resolve_hit` called, THEN `HitResult.damage_dealt == 0` AND `outcome == NORMAL_HIT` (NOT KILLED — already dead) AND EnemyDirector emit `combat_metric_anomaly` with `reason=DEAD_TARGET_RESOLVE`。EC-06 binding。
  - File: `tests/unit/combat/test_validate_dead_target.gd`

- **AC-28 [Logic | BLOCKING | unit]**: GIVEN `ctx.ability_damage_multiplier == NaN`, WHEN `compute_hit_damage` run, THEN Stage 1 detect `is_nan(mult)` reject AND base_damage 唔 compute AND EnemyDirector emit `combat_metric_anomaly` with `reason=INVALID_ABILITY_ID, context_dump={multiplier: "NaN"}`。EC-12 binding — no NaN propagation。
  - File: `tests/unit/combat/test_validate_nan_multiplier.gd`

- **AC-29 [Logic | BLOCKING | unit]**: GIVEN AOE cast with `targets.size() == 12` (> MAX_TARGETS_PER_CAST=8), WHEN EnemyDirector caller-side clip, THEN 只 process 頭 8 targets (距離 sort 取最近 8 個)，返回 Array size==8，剩低 4 個 dropped AND emit `combat_metric_anomaly` with `reason=CLAMP_TRIGGERED, context_dump={requested: 12, capped: 8}`。EC-31 binding。
  - File: `tests/unit/combat/test_aoe_target_cap.gd`

- **AC-30 [Logic | BLOCKING | unit]**: GIVEN `target.max_hp == 1`, WHEN `classify_damage_tier` run with `damage_dealt=1`, THEN tier == CRITICAL (ratio=1.0)，唔可以 div-by-zero / NaN。EC-18 binding — max_hp boundary。
  - File: `tests/unit/combat/test_classify_max_hp_one.gd`

- **AC-31 [Integration | BLOCKING | integration]**: GIVEN GSM state == &"Suspended", WHEN caller (EnemyDirector) snapshot gsm_state 入 ctx 然後 call `CombatResolver.resolve_hit`, THEN Rule 4 Stage 1 reject + return `HitResult{outcome=NORMAL_HIT, damage_dealt=0}` AND EnemyDirector emit `combat_metric_anomaly(reason=GSM_SUSPENDED)`。EC-39 binding。
  - File: `tests/integration/combat/test_gsm_suspended_gate.gd`

### H.6 Cross-system Integration (#5 / #6 / #14 / #15 / #28 contracts)

- **AC-32 [Integration | BLOCKING | integration]**: GIVEN `enemy_killed` signal emit with payload `EnemyKilledPayload{enemy_id, enemy_instance_id, killer_id, killing_ability, transition_id, is_overkill, overkill_excess}`, WHEN downstream #15 LootDrop subscribe, THEN payload schema 必須 match LootDrop 嘅 expected input contract (verified via shared `EnemyKilledPayload` resource schema)。FR-2 end-to-end binding。
  - File: `tests/integration/combat/test_enemy_killed_loot_contract.gd`

- **AC-33 [Integration | BLOCKING | integration]**: GIVEN `hit_resolved` signal emit, WHEN downstream consumers (#5 ParticleSystemWrapper, #6 ScreenEffects, #25 Combat Visual Feedback, #28 Telemetry) 各自 subscribe, THEN 4 consumer 全部收到相同 `HitResolvedPayload` 同一 frame，AND 每個 consumer 對 `damage_tier` field 嘅 read 都 non-null。Multi-subscriber broadcast integrity (FR Test #4 binding)。
  - File: `tests/integration/combat/test_hit_resolved_multi_subscriber.gd`

- **AC-34 [Integration | ADVISORY | integration]**: GIVEN catch-up scenario (tab reactivate after 5s pause), WHEN EnemyDirector replay 100 queued combat events, THEN sync rate ≤ CATCH_UP_HITS_PER_FRAME_CAP=12 hits/frame，超出部分 deferred 到下個 frame，UI / audio 唔會 spike。Rule 15 binding。
  - File: `tests/integration/combat/test_catch_up_throttle.gd`

- **AC-37 [Integration | ADVISORY | integration]** (FR Test #5 — Pillar 2 background continuity): GIVEN simulated 5-min bfcache pause with 60 queued ability_cast events backlog, WHEN tab resume frame fires, THEN catch-up complete in ≤ 60/12 = 5 frames (per CATCH_UP_HITS_PER_FRAME_CAP=12)；cumulative damage applied to enemies match deterministic non-pause baseline (replay determinism — same final HP); 無 enemy HP 嘅 visible「突然連續挨 3 下」(no batch-fire — sequential per-frame application per Rule 15)。FR Test #5 binding。
  - File: `tests/integration/combat/test_bfcache_resume_continuity.gd`

- **AC-38 [Integration | ADVISORY | integration]** (FR Test #4 — Pillar 3 DNF重擊 audio sensory cascade): GIVEN `hit_resolved.damage_tier ≥ HEAVY` signal emit, WHEN #4 Audio Manager subscribe via Contract 6, THEN audio cue 必須觸發對應 tier-level sound (HEAVY → `hit_heavy.wav` impact thud + low-pass duck；CRITICAL → `hit_crit.wav` crit fanfare + screen sweep)。完整 Pillar 3 sensory cascade 4-axis (visual particle / screen shake / temporal hit_pause / audio impact) 任何一 axis 缺 trigger = ❌。ADVISORY 因 **#4 Audio Manager NOT YET DESIGNED** (MVP tier order 22) — promote 為 BLOCKING 當 #4 GDD authoring 完成 + cross-system integration test infra 就緒；當前作為 forward contract spec。
  - File: `tests/integration/combat/test_hit_resolved_audio_binding.gd` (deferred until #4 ready)

### H.7 Performance & Determinism (FR-3 binding, ADR-001 gated)

- **AC-35 [Logic | ADR-001 RATIFICATION-GATED | benchmark]**: GIVEN AOE cast with 8 targets × 3 hits each (worst-case 24 hits per frame), WHEN benchmark run on mobile reference hardware (per ADR-001 §Validation Methodology — iPhone 12 / iOS 17+ Safari), THEN total `resolve_hit` CPU time p95 ≤ 1.0ms (FR-3 budget)，p99 ≤ 1.5ms。**ADR-001 RATIFICATION-GATED** — provisional pending VS-tier mobile profiling; if ADR-001 ratify 新 budget figure，更新本 AC threshold。
  - File: `tests/performance/combat/combat_resolver_hotpath_bench.gd`

### Coverage Matrix Summary

**Rule coverage** (17 rules):

| Rule | ACs | Coverage |
|---|---|---|
| Rule 1 (Stateless purity) | AC-01, AC-02, AC-03 | 3 ACs ✓ |
| Rule 2 (Single resolve_hit entry) | AC-05, AC-07 | 2 ACs ✓ |
| Rule 3 (EnemyDirector owns subscription) | AC-06 | 1 AC ✓ |
| Rule 4 (5-stage pipeline) | AC-20 | 1 AC ✓ |
| Rule 5 (HitOutcome 4 values) | AC-21 | 1 AC ✓ |
| Rule 6 (Per-cast StatSnapshot) | AC-04 | 1 AC ✓ |
| Rule 7 (RNG transition_id seed) | AC-14, AC-22, AC-23, AC-24, AC-25 | 5 ACs ✓ |
| Rule 8 (hit_resolved signal contract) | AC-07, AC-33 | 2 ACs ✓ |
| Rule 9 (enemy_killed signal contract) | AC-08, AC-32 | 2 ACs ✓ |
| Rule 10 (DamageTier 5-tier + crit override) | AC-16, AC-17, AC-30 | 3 ACs ✓ |
| Rule 11 (Overkill clamp + expose) | AC-18, AC-19 | 2 ACs ✓ |
| Rule 12 (GSM Suspended gate) | AC-31 | 1 AC ✓ |
| Rule 13 (combat_metric_anomaly signal) | AC-09 (broad) + AC-26/27/28/29/31 (per-reason) | 6 ACs total ✓ |
| Rule 14 (AOE 1-to-1) | AC-11, AC-29 | 2 ACs ✓ |
| Rule 15 (Catch-up CAP=12) | AC-34, AC-37 | 2 ACs ✓ |
| Rule 16 (MVP scope discipline) | AC-21 (DODGED absent) | 1 AC (partial — damage_types/statuses absence enforced via Rule 1 CI lint) |
| Rule 17 (Telemetry rate-limit) | AC-10 | 1 AC ✓ |

**Formula coverage** (5 formulas): ✓ 全部 covered (F1: AC-12/13; F2: AC-14/22/23; F3: AC-15; F4: AC-16/17/30; F5: AC-18/19)

**Falsifiable Test coverage** (5 tests):
- FR Test #1 (Pillar 1 RNG anti-fabrication) — AC-22 ✓
- FR Test #2 (Pillar 1 stat transduction continuity) — AC-36 ✓
- FR Test #3 (Pillar 4 muscle-group grammar) — Partial via AC-12 worked example calibration；day-flavor 主場 #12 GDD (acknowledged Section B note)
- FR Test #4 (Pillar 3 DNF heavy-hit threshold) — AC-07 + AC-17 + AC-33 ✓
- FR Test #5 (Pillar 2 background continuity) — AC-37 ✓

**Cross-system FR-Author constraint coverage** (6 FRs from Section F): forward constraints flagged for future GDD authoring — bidirectional consistency 將喺 #14 / #15 / #17 / #28 GDD authoring 確認。FR-Q-F2 (AbilityRegistry.tres schema extension) verified via AC-12 worked example assuming `base_damage_multiplier` field exists per ability_id。

### Test Infrastructure Additions (recommended sprint backlog stories)

1. **`tests/helpers/combat_context_factory.gd`** — factory for building valid / invalid CombatContext fixtures (null, dead target, NaN multiplier 等 edge case inputs)，避免每個 test 手寫 setup boilerplate
2. **`tests/helpers/mock_rng.gd`** — deterministic RandomNumberGenerator mock helper that can replay a fixed sequence of `randf()` values；AC-14/22/23/36 都要用
3. **`tests/helpers/enemy_director_test_double.gd`** — minimal EnemyDirector test double that captures emitted signals into a queue，俾 AC-06/08/10/31/32/33/37 用嚟做 signal assertion 唔需要 full autoload boot
4. **`tools/ci/check_combat_resolver_purity.gd`** — static analyzer (referenced by AC-01, AC-05) — 需要 implement，scan `src/core/combat_resolver.gd` for instance member / signal / @onready declarations。建議 model 跟 existing `tools/ci/check_camera_callers.gd` pattern
5. **`tests/helpers/payload_schema_validator.gd`** — schema validator for HitResolvedPayload / EnemyKilledPayload / CombatAnomalyPayload；AC-07/09/32/33 share 用嚟 enforce required fields + types
6. **`tests/performance/combat/combat_resolver_hotpath_bench.gd`** — benchmark harness (AC-35)。需要：mobile reference hardware spec (待 ADR-001 ratification) + p95 / p99 percentile reporting + headless run mode for CI
7. **Cross-GDD coordination**: EnemyDirector ownership-of-signals 嘅 architecture (per Rule 3) 需要 cross-GDD coordination with #14 (EnemyDirector GDD) — flag 畀 lead-programmer + #14 owner，確認 signal emission ownership boundary 文檔同步

## Open Questions

12 條 open questions — surface 喺 GDD 各 section 期間，按 owner + timeline + resolve gate 分類。Resolve 後 update GDD 對應 section + close OQ entry。

| OQ ID | Question | Owner | Timeline / Resolve Gate | Impact |
|-------|----------|-------|--------------------------|--------|
| **Q-D1** | target_defense formula shape — current MVP locked [A] flat subtraction `max(1, round(ATK × mult − defense))`；v0.2 應升級到 [B] proportional reduction `damage × (1 − def/(def+K))` 抑或 [C] log curve? | systems-designer + game-designer | VS-tier playtest feedback + v0.2 planning | Formula 1 revision + Section H AC adjustment |
| **Q-D8** | Boss TTK calibration — game-concept「boss 10-20 hit kill」對應 mid-game (STR=100, ATTACK_POWER ~160, TIER_3 multiplier 3.0) [B] 鎖定 ~10 hits to kill 5000 HP boss；but starter-stat vs starter-boss (~50 hits) 同 endgame stat vs starter-boss (~5 hits) 嘅 range 是否 acceptable design intent? | game-designer + economy-designer | VS-tier first playtest after #14 EnemyDirector + #16 Boss System 完成 | Section D Formula 1 worked example calibration + Section G knob tune |
| **Q-F1** | bfcache lifecycle behavior verification — Godot 4.6 Web Export 嘅 bfcache `_physics_process` pause behavior 同 4.3-4.5 假設一致？iOS Safari 17+ 上 catch-up frame budget guard (Rule 15) 是否 reliable? | gameplay-programmer + engine-programmer | VS-tier engine smoke test on actual iPhone 12 + iOS 17 Safari | Rule 15 amendment if behavior differs; AC-37 test threshold adjust |
| **Q-F2** | `#12 AbilityRegistry.tres` schema extension — `base_damage_multiplier: float` field 需要 #12 GDD revision via /propagate-design-change？OR本 GDD 主導 schema bump request? | #12 owner (game-designer) + lead-programmer | Before #12 first implementation story (likely Pre-MVP) | #12 GDD revision tracked via /propagate-design-change skill |
| ~~**Q-EnemyDirector-Contract**~~ | **UPGRADED 為 Risk Register FR-4 per CD-GDD-ALIGN F9 inline-fix 2026-05-27** — 屬 architecture cornerstone contingent invariant 而非單純 open question；resolution 路徑 + fallback 詳細 spec 喺 Section B Risk Register FR-4 row | (moved to Risk Register) | (moved to Risk Register) | (moved to Risk Register) |
| **Q-LootDrop-TransitionId** | `enemy_killed.transition_id` propagation — #15 GDD authoring 接受 ADR-005 chain (#13 → #15 transition_id seed) 而非 #15 generate own RNG? | #15 owner (economy-designer + systems-designer) | #15 GDD authoring (Pre-MVP tier order 17) | FR-2 + ADR-005 Pillar 1 chain integrity |
| **Q-Telemetry-RecursionGuard** | #28 anomaly handler internal recursion guard — 由 #28 own (per [[28-recursion-guard]] flag) confirm? | #28 owner (analytics-engineer) | #28 GDD authoring (Pre-MVP tier order 21) | EC-49 cross-system invariant |
| **Q-Equipment-AntiSnowball** | #17 equipment ATK ≤ 3× stat ATK invariant — #17 GDD authoring 接受 forward constraint? | #17 owner (systems-designer + economy-designer) | #17 GDD authoring (MVP tier order 23) | Section D anti-snowball matrix #4 + Pillar 1 transduction integrity |
| **Q-Boot-Order** | Autoload boot order `#15 + #28 boot before #14` — `project.godot` 配置 ratification + ADR-006 Contract 4 compliance verify? | technical-director + lead-programmer | VS-tier autoload integration story (likely after #14 design but before #14 implementation) | EC-43 + EC-50 cross-system invariant |
| **Q-Bench-Mobile** | ADR-001 mobile reference hardware spec (iPhone 12 + iOS 17 Safari) for AC-35 benchmark — 實際 device available? OR use cloud device farm (e.g., BrowserStack)? | performance-analyst + devops-engineer | VS-tier profiling phase (per ADR-001 §Validation Methodology) | AC-35 ADR-001 RATIFICATION-GATED resolve |
| **Q-Mock-RNG** | Test helper `tests/helpers/mock_rng.gd` deterministic replay implementation — sequence injection pattern (e.g., `[0.1, 0.5, 0.99, ...]`) vs PRNG seed override? | qa-tester + lead-programmer | Before AC-14/22/23/36 implementation | Test infra recommendation #2 from Section H |
| **Q-V02-Dodge** | v0.2 dodge re-introduction — `DODGED` outcome + `roll_dodge` Formula + per-enemy `dodge_chance` field — when to design? Pre-v0.2 planning OR post-MVP retrospective? | game-designer + systems-designer | v0.2 milestone planning (post-MVP gate) | Rule 5 schema bump + HitOutcome enum extension + new Formula |
