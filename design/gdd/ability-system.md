# Ability System

> **Status**: In Design
> **Author**: Frank + main session (lean mode)
> **Last Updated**: 2026-05-27
> **Implements Pillar**: Pillar 4 (Muscle = Class) primary — push/pull/leg → strike/control/mobility class-tagged abilities; Pillar 1 (Real Body, Real Power) supporting — ability slot unlock anchored to real PR breakthrough; Pillar 3 (Drop Euphoria) indirect — ability unlocks reuse loot-grade ritual moment
> **System #**: 12 (Core / VS tier, design order 8)
> **Depends On**: #11 Stat System (Approved 2026-05-27) + #10 Exercise→Class Mapping (Pre-MVP, **Not Started** — provisional contract)
> **Depended On By**: #13 CombatResolver, #20 Gym-Mode HUD, #26 Avatar Renderer, #30 Skill Tree (v0.2)
> **Governing ADRs**: ADR-006 State Machine Contract (Proposed) — Contracts 4/6 (autoload sequential boot + `connect_for_initial_state`); ADR-003 Save State Strategy (Proposed) — `ability.*` namespace

## Overview

Ability System 係 Mirror Hero 嘅 **player-action data layer** — Core 層 autoload，boot 喺 #11 Stat System (autoload position 4) 之後 (position 5)，向 4 個下游 consumer (#13 CombatResolver / #20 Gym-Mode HUD / #26 Avatar Renderer / #30 Skill Tree v0.2) 提供 canonical ability slot state + 發起 ability cast event。系統有雙重 framing：**data 層面**係 `get_unlocked_abilities() -> Array[AbilityId]` + `get_ability_state(ability_id) -> AbilityState` sync read API、`cast_ability(ability_id, target) -> CastResult` 唯一 mutation entry point (被 #13 CombatResolver 自動 trigger，符合 game-concept「auto-combat side-scroller，玩家唔需要按制」)、`ability_cast(ability_id, caster, target, damage)` / `ability_unlocked(ability_id, source)` / `ability_cooldown_started(ability_id, duration)` 三個核心 broadcast signal，下游通過 ADR-006 Contract 6 `connect_for_initial_state` 訂閱；**player-facing 層面**係玩家連續做咗 3 個月推日 (chest dominant) → #18 PR Detection emit `pr_breakthrough(bench_press, magnitude)` → Ability System Rule 7 evaluate「呢個 PR 達到 STRIKE_TIER_3 unlock 條件」→ `ability_unlocked(STRIKE_TIER_3_OVERHAND, PR_BREAKTHROUGH)` fires → 同一 frame #20 HUD 加入第 4 個 strike ability icon (短暫 glow per #5 Particle System) + 下次 combat tick 期間 #13 CombatResolver 可以 schedule 呢個 ability → 玩家「我嘅 bench PR 變咗 game 入面新 combo」嘅 Pillar 4 visceral feedback。MVP scope locked：**9 個 ability slot** (3 class × 3 tier — STRIKE/CONTROL/MOBILITY each with TIER_1/2/3) + **6 個 cast trigger condition** (cooldown-ready + stat-threshold + class-active + GSM-permits + caster-alive + target-valid)；ability 嘅 stat scaling formula (damage = STR × ATK_PER_STR + ...) 屬 #13 CombatResolver scope，本 GDD 只 own slot-unlock contract + cast-event broadcast。系統屬 Pillar 4 (Muscle = Class) primary substrate — 唔 own combat math (#13)、唔 own animation (#26)、唔 own HUD render (#20)、唔 own ability slot tree (#30 v0.2)；只 own canonical ability state + slot-unlock event。Governing ADRs: ADR-003 (Save State — `ability.unlocked.*` namespace persist unlocked slot IDs + first-unlock timestamps) + ADR-006 Contracts 4 / 6 (autoload sequential boot + `connect_for_initial_state` sentinel)。

## Player Fantasy

**Direct fantasy — 「真實 PR → 新 ability icon 喺 HUD 出現」嘅 unlock moment**:
玩家連續 3 個月推日 push priority (bench / OHP / dips dominant) → 某朝做 bench 1RM 由 100kg → 105kg → #18 PR Detection emit `pr_breakthrough(bench_press, 0.05)` → 同一 frame Ability System 計算「STR 累積去到 STRIKE_TIER_3 threshold ✓」→ `ability_unlocked(STRIKE_TIER_3_OVERHAND, PR_BREAKTHROUGH)` fires → #20 HUD 入面 strike ability bar 多咗第 4 個 icon (短暫 glow per #5 Particle System `STATUS_BUFF` preset)；下次抽空打開 #22 Character Screen → 對比上週 ability list「上週 3 個 strike，今週 4 個」嘅「我嘅 PR 變咗 game 入面新 combo」visceral feedback。**Ability System 本身唔 fire VFX / 音效** — visible glow + icon update 由下游 #20 HUD / #22 Character Screen 通過 `ability_unlocked` signal 訂閱後 own，但 source-of-truth 嘅 unlock state = 全 game 跟住即時更新。

**Indirect fantasy — 「新 ability → 戰鬥節奏轉變」嘅 game-feel shift** (透過 #13 CombatResolver):
解鎖 STRIKE_TIER_3 之後一場 boss 戰 — #13 CombatResolver tick 期間 read `AbilitySystem.get_unlocked_abilities()` 揀最高 priority ability → cast STRIKE_TIER_3_OVERHAND → 第三 hit 觸發大傷害 + 額外 particle burst (per #5)；同一場 boss 上週要 5 段 combo 擊倒，今週 4 段 combo + 1 finisher 擊倒 — 玩家「冇做特別嘢」但 combat 節奏跟住升 — Pillar 4 「Muscle = Class」最 visceral 嘅 transduction 路徑。

**Class-segregated power fantasy thread (Pillar 4 hard contract)**:
玩家心入面 implicit 嘅 promise — 「Mirror Hero 入面唔可以 generic level-up 解鎖所有 ability。練 push → 只解鎖 strike ability；練 pull → 只解鎖 control ability；練 leg → 只解鎖 mobility ability。Hybrid build (push + pull + leg 均衡) 解鎖各 class 嘅 TIER_1 但未必去到 TIER_3。Specialist build (純練 push) 解鎖 STRIKE_TIER_3 但 control / mobility 永遠停喺 TIER_1 — 呢個 trade-off 喺 game 入面 visible，唔可以 cheat。」

呢條 promise 同 #11 Stat System 嘅 anti-fabrication trio 形成 **Pillar 4 唯一架構 enforcement** — Stat System 提供「practice → stat」嘅 raw input，Ability System 提供「class-segregated stat 累積 → tiered ability slot」嘅 player-meaningful translation：

| # | System | Pillar 4 contribution |
|---|--------|----------------------|
| #10 | Exercise→Class Mapping | **Class routing** — push set → STR; pull set → DEX; leg set → VIT (hard 1:1:1 mapping) |
| #11 | Stat System | **Stat accumulation** — STR/DEX/VIT 累積 (anti-fabrication via Pillar 1 trio) |
| **#12** | **Ability System (本 GDD)** | **Class-tiered unlock translation** — STR threshold → STRIKE_TIER_N; DEX → CONTROL_TIER_N; VIT → MOBILITY_TIER_N |

三者組成 Pillar 4 完整 architecture — input routing (#10) + raw accumulation (#11) + player-meaningful translation (#12)。

**Falsifiable design tests** — 任何 client-side path 引致以下情境 = bug，唔係 acceptable behavior：

1. **Pillar 4 cross-class gate**: 玩家 STR = 200 但 DEX = 10 → CONTROL_TIER_2 unlocked = ❌ (Pillar 4 violation — Strike-class accumulation 唔可以 unlock Control-class ability；Rule 6 source/class allow-list reject)
2. **Anti-fabrication gate**: 玩家用 DevTools 喺 console 寫 `AbilitySystem._unlocked_abilities.append("STRIKE_TIER_3")` → ❌ (push_error reject — 唯一允許 path 係 Rule 7 unlock path，private field 直接 mutation 喺 release build 經 CI lint catch)
3. **Permanent unlock contract**: Ability 一旦 unlock，stat 跌返 (理論上 #11 Rule 12 anti-decay 應該阻止) 或 equipment 脫掉 → ability 仍然 unlocked = ✅ (per Anti-Pillar「缺日只係 delay bonus，唔可以拎走玩家已得嘅嘢」)
4. **Persistence round-trip gate**: 玩家 PR breakthrough unlock 之後 reload → reload 後 `get_unlocked_abilities()` 必包含啱啱 unlocked 嘅 id = ✅ (ADR-006 Contract 3 + ADR-003 `ability.unlocked.*` namespace)
5. **Cast-without-unlock gate**: #13 CombatResolver call `cast_ability(STRIKE_TIER_3, ...)` 但 STRIKE_TIER_3 未 unlock = ❌ (push_error + return `CastResult.NOT_UNLOCKED`，combat tick 跌返低 tier ability)

呢個 fantasy 直接 enables：
- **Pillar 4 (Muscle = Class) primary** — class-tiered ability 係 Pillar 4 嘅 player-visible payoff；缺呢層，Stat System 累積咗 STR 200 但 game 入面冇 visible 「我練 push 換到新嘢」嘅 reward → Pillar 4 leak
- **Pillar 1 (Real Body, Real Power) supporting** — ability unlock 依賴 真實 PR signal (via #18)，唔可以 cheat
- **Pillar 3 (Drop Euphoria) indirect** — ability unlock moment reuse loot-grade ritual (short glow + #20 HUD icon flash)，但 magnitude 小過 loot drop (per Section B framing 「micro-version of Pillar 3」)

### Fantasy Risk Register

呢個 class-segregated unlock framing 係 contingent on 以下 invariants 喺 **#10 + ADR-003** ratification 真正 enforced；否則 Player Fantasy paragraph 變 retroactive lie。

| # | Contingent Invariant | Owner | Fallback if Dropped |
|---|---------------------|-------|---------------------|
| FR-1 | `class_id` enum 維持 `{STRIKE, CONTROL, MOBILITY}` 三類，1:1 對應 STR/DEX/VIT — 唔可以引入 hybrid class (e.g. PUSH_PULL_HYBRID) 而破壞 「3 class × 3 tier = 9 slots」MVP scope | 本 GDD Rule 1 + #10 Exercise→Class Mapping GDD authoring | 若 #10 引入 hybrid class → Section C Rule 1 / Section D Formula 1 全部需 revise；ability slot 數可能由 9 跳到 12+ |
| FR-2 | `pr_magnitude` 嘅 server-validated input (per #18 + ADR-002) 真實反映 1RM 突破，唔可以 client-side fabricate 喂 ability unlock | #18 PR Detection + ADR-002 ratification | 若 #18 client-side 可 fabricate `pr_breakthrough` → ability unlock 變相 cheat 可行；fallback = revisit Section B framing「ability unlock 加 server-side double-check」|
| FR-3 | `ability.unlocked.*` namespace 持久化保證 unlock contract permanent — 一旦 unlock 永遠 unlocked (per Anti-Pillar「缺日唔拎走嘢」) | ADR-003 ratification + Rule 9 persist-on-unlock | 若 ADR-003 提倡 weekly reset 之類 → Anti-Pillar 違反；fallback = blocking story to enforce `ability.unlocked.*` immutable-on-set |

**Ratification gate binding**: 本 GDD 嘅 Section C / H 必須 include FR-1 / FR-2 / FR-3 對應嘅 rules + ACs (gated on #10 + ADR-003 Accepted)。若 #10 ratification 後 class enum 改變 → revisit Player Fantasy paragraph + Risk Register。

## Detailed Design

### Core Rules

1. **Rule 1 — LOCKED ability slot surface (MVP scope)** — 9 個 ability slots，3 class × 3 tier：
   - **STRIKE class** (driven by STR / push training): `STRIKE_TIER_1_JAB`, `STRIKE_TIER_2_HOOK`, `STRIKE_TIER_3_OVERHAND`
   - **CONTROL class** (driven by DEX / pull training): `CONTROL_TIER_1_PARRY`, `CONTROL_TIER_2_HOOK_PULL`, `CONTROL_TIER_3_GRAPPLE`
   - **MOBILITY class** (driven by VIT / leg training): `MOBILITY_TIER_1_DASH`, `MOBILITY_TIER_2_LEAP`, `MOBILITY_TIER_3_GROUND_POUND`
   - Ability IDs 係 `StringName` constants 喺 `class AbilityId`，禁止 magic string；caller (#13) 必須用 `AbilityId.STRIKE_TIER_1_JAB`，唔可以用 `"strike_tier_1_jab"` literal — CI lint `tools/ci/check_ability_id_magic_string.gd` 喺 release build fail
   - Ability slot surface **LOCKED** for MVP — 加新 ability = schema version bump (Rule 9 migration chain)，唔係 tuning
   - **Per-ability metadata** owned by `AbilityRegistry.tres` (data-driven Resource，per coding-standards「Gameplay values must be data-driven」)：`{id, class, tier, display_name, base_cooldown_sec, target_type, unlock_stat_threshold}`

2. **Rule 2 — `AbilityClass` + `AbilityTier` enum (3 × 3 = 9 LOCKED combinations)** — 完整列表：
   - `AbilityClass`: `STRIKE`, `CONTROL`, `MOBILITY` (per Pillar 4 hard mapping, FR-1 binding)
   - `AbilityTier`: `TIER_1`, `TIER_2`, `TIER_3` (per MVP scope; v0.2 可能加 TIER_4 + 對應 schema bump per Q-A2)
   - **Hard 1:1:1 stat→class mapping**：STR→STRIKE, DEX→CONTROL, VIT→MOBILITY；唔可以 cross-class (e.g., STR threshold unlock CONTROL ability = Rule 6 reject)

3. **Rule 3 — Closed mutation API (anti-fabrication hard guarantee, Pillar 4)** — Ability System 暴露兩個 mutation entry points：
   ```gdscript
   func unlock_ability(ability_id: StringName, source: UnlockSource) -> bool
   func cast_ability(ability_id: StringName, caster: Node2D, target: Node2D) -> CastResult
   ```
   任何其他 mutation path (直接 `_unlocked_abilities.append(...)`、Resource swap、reflection-style invoke) 均違反 Pillar 4 anti-fabrication。Enforcement 三層防：
   - **Runtime guard**: `_unlocked_abilities: Dictionary[StringName, UnlockRecord]` 標 `_` private convention；CI lint `tools/ci/check_ability_internal_field_access.gd` 喺 `src/` 內任何 `AbilitySystem._unlocked_abilities[` 出現 (除 `src/autoload/ability_system.gd` 自身) 即 fail build
   - **Closed API**: 全部 unlock 經 `unlock_ability` 一個 chokepoint；全部 cast 經 `cast_ability` 一個 chokepoint，方便 audit + telemetry
   - **CI caller whitelist** (paired with Rule 6): `unlock_ability` 只被 `src/autoload/ability_system.gd` 自身 internal handlers 呼叫（Path A via subscription to #18's `pr_breakthrough` signal；Path B via subscription to #11's `stat_changed`）；#18 PR Detection emit `pr_breakthrough` signal，Ability System internal handler 訂閱並 call `_evaluate_unlock` → `unlock_ability` (signal subscription pattern per Rule 7，唔係 #18 直接 call `unlock_ability`)。Only `src/autoload/ability_system.gd` 係 `unlock_ability` caller whitelist；only `src/core/combat_resolver.gd` (#13) 係 `cast_ability` caller whitelist — CI lint `tools/ci/check_ability_unlock_callers.gd` + `check_ability_cast_callers.gd` enforce

4. **Rule 4 — `UnlockSource` enum (3 values, 2 mutation + 1 sentinel)** — 完整列表：
   - `PR_BREAKTHROUGH` — 真實 PR breakthrough 觸發，由 #18 PR Detection emit；critical persistence (Rule 9 `flush=true`)
   - `STAT_THRESHOLD` — Stat 累積到 threshold 觸發 (e.g., STR=50 → STRIKE_TIER_2 unlock)，由 #11 Stat System `stat_changed` subscription handler 觸發 (Ability System 內部 evaluation)；debounced persistence (Rule 9 `flush=false`)
   - `INITIAL_STATE` (**internal sentinel only**) — ADR-006 Contract 6 `connect_for_initial_state` callv 路徑專用；mutation API 收到呢個 source 即 push_error reject (sentinel 唔係 mutation path)

   **FR-1 binding (Section B)**: 2 個 mutation source LOCKED — 唔可以加 `RANDOM_DROP` / `LEVEL_UP_BONUS` 等 RNG-based source。Ability unlock 必須走 stat-anchored path。

5. **Rule 5 — `CastResult` enum (6 outcomes)** — `cast_ability` 唯一 return type：
   - `SUCCESS` — ability fired，damage dealt，cooldown started
   - `NOT_UNLOCKED` — ability_id 唔喺 `_unlocked_abilities` set；caller bug (#13 應該 check 先 cast)
   - `ON_COOLDOWN` — cooldown 未完，return time_remaining
   - `STAT_INSUFFICIENT` — caster current stat 跌返到 ability minimum threshold 之下 (極罕，per Rule 12)
   - `INVALID_TARGET` — target_type mismatch (e.g., ABILITY 要 enemy 但 caller pass null)
   - `GSM_REJECT` — GSM 唔喺 CombatActive / BossEncounter state，Ability System Suspended substate (Rule 11)

6. **Rule 6 — Source→class allow-list (Pillar 4 cross-enforcement)** — 每個 `UnlockSource` + `stat_id` 有 explicit allowed-class set；mismatch 即 push_error reject：

   | UnlockSource | stat_id (caller-passed) | Allowed AbilityClass | Why |
   |--------------|------------------------|---------------------|-----|
   | `PR_BREAKTHROUGH` | `STR` | `STRIKE` only | Pillar 4 — push PR 只解鎖 strike |
   | `PR_BREAKTHROUGH` | `DEX` | `CONTROL` only | Pillar 4 — pull PR 只解鎖 control |
   | `PR_BREAKTHROUGH` | `VIT` | `MOBILITY` only | Pillar 4 — leg PR 只解鎖 mobility |
   | `STAT_THRESHOLD` | `STR` | `STRIKE` only | (same) |
   | `STAT_THRESHOLD` | `DEX` | `CONTROL` only | (same) |
   | `STAT_THRESHOLD` | `VIT` | `MOBILITY` only | (same) |
   | `INITIAL_STATE` | — | **None — mutation reject** | Sentinel only |

   **Caller whitelist** (paired with allow-list):
   - `PR_BREAKTHROUGH` (Path A): caller MUST 喺 `src/autoload/ability_system.gd` 內部 (internal handler subscribed to #18's `pr_breakthrough` signal)；`pr_detection.gd` 唔入 whitelist，因為佢唔直接 call `unlock_ability` (per Rule 7 signal subscription pattern)
   - `STAT_THRESHOLD` (Path B): caller MUST 喺 `src/autoload/ability_system.gd` 內部 (internal handler subscribed to #11 `stat_changed`)
   - `cast_ability`: caller MUST 喺 `src/core/combat_resolver.gd` (#13)
   - CI lint `tools/ci/check_ability_unlock_callers.gd` + `check_ability_cast_callers.gd` enforce

   **Rule 6 enforcement level**: Source/class allow-list validation 發生喺 `_evaluate_unlock(stat_id, value, source)` 內部 — stat_id → class mapping 喺 internal function level enforced，唔係喺 public `unlock_ability(ability_id, source)` API level (因為 public API 冇 stat_id parameter)。`unlock_ability` 喺 API level 只驗證：ability_id's class (from AbilityRegistry) ∈ allowed-class-set for the source；能夠做到係因為所有 caller 都係 ability_system.gd 自身 internal code，唔需要在 public boundary 加 stat_id。

7. **Rule 7 — Unlock evaluation logic (PR_BREAKTHROUGH + STAT_THRESHOLD)** — Two paths converge on `_evaluate_unlock(stat_id, current_value, source)`:
   - **Path A (PR_BREAKTHROUGH)**: #18 emits `pr_breakthrough(stat_id, magnitude)` signal (NOT calling `unlock_ability` directly) → **AbilitySystem's internal signal handler** (subscribed to #18's `pr_breakthrough` signal) reads `StatSystem.get_stat(stat_id)` → calls internal `_evaluate_unlock(stat_id, current_stat_value, PR_BREAKTHROUGH)` → which internally calls `unlock_ability`。`pr_detection.gd` 永不直接 call `unlock_ability`；只有 ability_system.gd 自身 internal code 呼叫。
   - **Path B (STAT_THRESHOLD)**: AbilitySystem subscribed to `stat_changed(stat_id, old, new, source, _)` via `connect_for_initial_state` → on every stat update, if `source ∈ {VOLUME_TICK, PR_BREAKTHROUGH}` and `stat_id ∈ {STR, DEX, VIT}`, calls `_evaluate_unlock(stat_id, new, STAT_THRESHOLD)`
   - **Common evaluation** (Section D Formula 1):
     - Map stat_id → class (Rule 6 mapping)
     - For each tier 1→2→3, check `current_value ≥ TIER_THRESHOLDS[tier]` (Section G knob)
     - For each tier 滿足 threshold AND `ability_id not in _unlocked_abilities`: call `unlock_ability(ability_id_for(class, tier), source)`
   - **Idempotent**: 重複 evaluation 同一 ability_id (already unlocked) → no-op (no double emit, no double persist)

8. **Rule 8 — Cast evaluation (`cast_ability` body)** — `cast_ability(ability_id, caster, target)` body steps (per Rule 13 atomic ordering):
   1. **Validate** — `ability_id` 喺 `AbilityRegistry`，`ability_id` 喺 `_unlocked_abilities` (per Rule 5 NOT_UNLOCKED gate)；fail → push_error + return `CastResult.NOT_UNLOCKED`
   2. **Cooldown check** — `_cooldown_remaining[ability_id] > 0` → return `CastResult.ON_COOLDOWN` (含 time_remaining)
   3. **GSM check** — `GameStateMachine.current_state ∉ {CombatActive, BossEncounter}` → return `CastResult.GSM_REJECT`
   4. **Stat check** — read `StatSystem.get_stat(ability.class_stat_id)`; if < `ability.minimum_active_stat` (Section G knob, default 5.0) → return `CastResult.STAT_INSUFFICIENT`
   5. **Target check** — target type compatibility per `AbilityRegistry.target_type` (`ENEMY` / `SELF` / `AOE_RADIUS`)；mismatch → return `CastResult.INVALID_TARGET`
   6. **Cast** — emit `ability_cast(ability_id, caster, target)` (damage 係 #13 CombatResolver 自身職責 — #13 收 `ability_cast` signal 後用自己的 Stat formula 計算 damage，Ability System 唔 own combat math)；start cooldown `_cooldown_remaining[ability_id] = ability.base_cooldown_sec`；emit `ability_cooldown_started(ability_id, duration)`
   7. **Return** — `CastResult.SUCCESS`

9. **Rule 9 — Persistence contract (ADR-003 `ability.unlocked.*` namespace + ADR-006 Contract 3)** — Unlock 經 PersistenceLayer 持久化：
   - **Storage keys**: `ability.unlocked.<ability_id>` (key per unlocked ability_id)；value = `UnlockRecord` SerializableResource envelope `{first_unlocked_at_unix: int, source: UnlockSource, source_event_id: String}`
   - **Write path**: `unlock_ability` 內部 call `PersistenceLayer.write("ability.unlocked." + str(ability_id).to_lower(), envelope.to_dict(), flush)`，**flush 決策**：
     - `PR_BREAKTHROUGH` → `flush = true` (critical — Pillar 4 anchor moment 必 disk persist 即時)
     - `STAT_THRESHOLD` → `flush = false` (debounced — Stat System 已 batch write，呢度同步)
   - **Read path**: 只喺 `_ready()` 內一次 sync read：iterate all `ability.unlocked.*` keys → populate `_unlocked_abilities`
   - **Cooldown NOT persisted** — `_cooldown_remaining` transient；reload 後 cooldown reset，玩家被「免費」一次 reset，acceptable trade-off (per game-concept Anti-Pillar「缺日只係 delay bonus」)
   - **Schema version**: PersistenceLayer-owned；Ability System NOT own schema version 自己

10. **Rule 10 — Boot reconciliation (autoload sequential boot, ADR-006 Contract 4)** — Ability System autoload position 6 (after Persistence pos 1 + GSM pos 2 + PlatformDetect pos 3 + GymSys pos 4 + Stat pos 5; F-SETUP-1 sync 2026-05-28 — PlatformDetect inserted at pos 3 per ADR-001 shifts downstream by 1)：
    - `_ready()` sync sequence (NO `await`):
      1. Sync iterate `PersistenceLayer.list_keys_matching("ability.unlocked.*")`
      2. For each key: read SerializableResource envelope；validate (Rule 1 ability_id 喺 LOCKED list)；invalid → push_warning + skip
      3. Populate `_unlocked_abilities` Dictionary
      4. Initialize `_cooldown_remaining` to empty (transient)
      5. Subscribe `StatSystem.stat_changed` via `connect_for_initial_state` (for Rule 7 Path B)
      6. Subscribe `GameStateMachine.state_changed` via `connect_for_initial_state` (for Rule 11 Suspended gate)
    - `_ready()` 完成後 substate = `Ready`
    - **No `ability_unlocked` emit during `_ready()`** — subscribers 仲未 connect；emit 喺 subscriber 之後通過 `connect_for_initial_state` 嘅 callv 一次性 deliver

11. **Rule 11 — GSM Suspended gate (Pillar 2 + ADR-006 Contract 6)** — Ability System 訂閱 GSM `state_changed` 經 `connect_for_initial_state`：
    - GSM state = `Suspended` (per #1 Decision #4 — multi-device session lock force-boot 期間) → Ability System 進入 `Suspended` substate
    - Suspended 內：`cast_ability` 立即 return `CastResult.GSM_REJECT`；`unlock_ability` reject + push_warning + emit `ability_mutation_rejected(...)`
    - Read API (`get_unlocked_abilities` / `get_ability_state`) 仍 OK (read 唔修改 state)
    - GSM transitions out of Suspended → Ability System 進入 `Reconciling` substate (single frame，per #11 Stat System pattern)：re-read all `ability.unlocked.*` keys + emit `ability_unlocked` for any new entries (backend reconciliation 可能 unlock ability via other device)
    - Reconciling 完成 → Ready

12. **Rule 12 — No ability lock (Anti-pillar enforcement)** — Game-concept Anti-Pillar 第 3 條：「缺日只係 delay bonus，唔可以拎走玩家已得嘅嘢」。本 GDD enforcement：
    - 一旦 `ability_id in _unlocked_abilities` → permanent
    - `unlock_ability` 唔提供 `relock_ability` counterpart
    - Stat 跌返 (理論上 #11 Rule 12 anti-decay 阻止，但 EQUIPMENT mod 可能拉低 derived) → ability 仍 unlocked；`cast_ability` 經 Rule 8 step 4 stat check 阻 cast (return `STAT_INSUFFICIENT`)，但 unlock state 不變
    - **唯一 exception**: schema bump via PersistenceLayer Contract 10 migration 可能 remove deprecated ability_id (e.g., v0.2 削減某 tier)；屬 schema 改動，唔屬 runtime decay
    - CI lint `tools/ci/check_ability_relock.gd` 喺 `src/` 任何 `_unlocked_abilities.erase(` / `_unlocked_abilities.clear(` (除 schema migration paths) → fail build

13. **Rule 13 — Atomic unlock write sequence (persistence-first ordering)** — `unlock_ability` body steps：
    1. **Validate** — Rule 4 source enum valid，Rule 6 source-class allow-list pass，ability_id 喺 LOCKED list，ability_id NOT already in `_unlocked_abilities` (idempotent — repeated unlock = no-op return true)；fail → push_error + return false
    2. **Construct UnlockRecord** — `record = UnlockRecord.new()`；populate `first_unlocked_at_unix = Time.get_unix_time_from_system()`, `source`, `source_event_id`
    3. **Persist FIRST** — `var persist_ok = PersistenceLayer.write(key, record.to_dict(), flush_for_source(source))`; if not `persist_ok` → emit `ability_unlock_save_failed(ability_id)` + push_error + return false (in-memory unchanged)
    4. **Mutate in-memory** — `_unlocked_abilities[ability_id] = record` (AFTER persist confirm)
    5. **Emit unlock signal** — `emit_signal("ability_unlocked", ability_id, source, false)` (`is_initial = false`)
    6. **Return** `true`

    **Ordering rationale** (per /design-review lessons from #11 Stat System): Persist BEFORE in-memory mutate → 如果 disk write 失敗，cache 唔會出現「new ability 但 disk 仲未寫」phantom state；emit AFTER in-memory mutate → subscriber 訪問 `get_unlocked_abilities()` 喺 handler 內必 see new ability。整個 sequence 屬 sync flow (no `await`)。

14. **Rule 14 — Cooldown tick (`_process(delta)` event-driven decrement)** — Cooldowns 係 transient，需要 `_process(delta)` decrement：
    - `_process(delta)`: iterate `_cooldown_remaining`，每個 entry `time -= delta`；time ≤ 0 → erase entry + emit `ability_cooldown_ended(ability_id)`
    - `delta` clamped to `MAX_FRAME_DELTA = 0.1` (per #6 / #7 shared constant) — bfcache resume 30s 後唔可以一 frame decay 完所有 cooldown
    - **Optimization**: if `_cooldown_remaining.is_empty()`: `set_process(false)` → 0 CPU cost；`_start_cooldown` → `set_process(true)`；`_cooldown_remaining` last entry erased → `set_process(false)` (per Godot 4.6 best-practice)
    - Suspended substate → `set_process(false)` regardless (no cooldown tick during pause)

15. **Rule 15 — Single-character scope (MVP)** — Ability System single-instance autoload, single-character。Per game-concept MVP scope。v0.2+ multi-character 可能擴展到 per-character ability set — 屆時本 GDD revise + schema bump (新增 `ability.<character_id>.unlocked.*` namespace structure)。MVP 假設「冇 character switching mid-session」。

16. **Rule 16 — Telemetry signal surface (anti-fabrication posture)** — Ability System emit 4 個 telemetry/diagnostic signal (separate from `ability_unlocked` / `ability_cast` / `ability_cooldown_*` core broadcasts):
    - `ability_unlock_save_failed(ability_id)` — Rule 13 step 3 persistence write 返 false
    - `ability_mutation_rejected(ability_id, source, reason)` — Rule 3/4/6 任何 reject 路徑；`reason` ∈ {`"invalid_source"`, `"invalid_ability_id"`, `"source_class_mismatch"`, `"suspended_substate"`, `"caller_whitelist_violation"`, `"sentinel_misuse"` (INITIAL_STATE passed to mutation API)}
    - `ability_cast_rejected(ability_id, reason)` — Rule 8 任何 non-SUCCESS CastResult；`reason` ∈ {`"not_unlocked"`, `"on_cooldown"`, `"gsm_reject"`, `"stat_insufficient"`, `"invalid_target"`}
    - `boot_completed()` — Rule 10 `_ready()` 完成 (subscriber 用嚟知 ability state 已 ready for `connect_for_initial_state`)

### States and Transitions

Ability System 唔係 gameplay-stateful system，但 boot + GSM-coupled lifecycle 有 4 個 internal substates：

| Substate | Entry | API behaviour | Exit |
|----------|-------|---------------|------|
| **Initialising** | `_enter_tree()` start | All API rejects — autoload position 6 invariant means 應該冇 caller hit API (Persistence/GSM/PlatformDetect/GymSys/Stat 必須先 ready) | `_ready()` 完成 sync read + subscriptions → Ready |
| **Ready** | Normal operation | All API functional per Rules 3-16；`_process(delta)` active iff `_cooldown_remaining` non-empty | Receive GSM `state_changed(_, "suspended", _)` → Suspended |
| **Suspended** | GSM Suspended state (per Rule 11) | `get_unlocked_abilities` / `get_ability_state` OK；`cast_ability` returns `GSM_REJECT`；`unlock_ability` rejects with telemetry；`_process` disabled | GSM `state_changed(_, "<any-non-suspended>", _)` → Reconciling |
| **Reconciling** | Suspended exit | Brief substate (single frame) — sync re-read all `ability.unlocked.*` + emit `ability_unlocked` for any newly-discovered；mutation API still rejects during this micro-window | Read complete → Ready |

**Why Suspended explicit**: GSM Suspended 代表 backend reconciliation 期間，client state 可能 stale (per #1 Decision #4 single-device session lock — backend may have unlocked ability via other device)。Ability System 喺呢個 window 接受 unlock 或 cast 等於同意 commit stale state → Pillar 4 anti-fabrication violation。

**Why Reconciling 1-frame buffer**: GSM 轉 Suspended → Ready 嘅 frame，PersistenceLayer 可能已 update (backend reconciliation 寫入新 unlock keys) 但 Ability System 嘅 `_unlocked_abilities` cache 仲係 pre-Suspended snapshot；Reconciling 強制 re-read，避免下個 `get_unlocked_abilities` 返 stale。

### Interactions with Other Systems

| Consumer | Direction | API used | Key ownership | Notes |
|----------|-----------|----------|---------------|-------|
| **#3 PersistenceLayer** | reads + writes | `list_keys_matching("ability.unlocked.*")` at boot；`write("ability.unlocked.<id>", envelope, flush)` per Rule 9；listens `critical_save_failed` filter | All `ability.unlocked.*` keys (1 per unlocked ability，max 9 entries) | Ability System owns `ability.*` namespace |
| **#1 GameStateMachine** | listens | Subscribe `state_changed` via `connect_for_initial_state` for Suspended gate (Rule 11) + cast permit check (Rule 8 step 3) | None | Read-only consumer |
| **#11 Stat System** | listens + reads | Subscribe `stat_changed` via `connect_for_initial_state` for Rule 7 Path B (STAT_THRESHOLD unlock evaluation)；read `get_stat(stat_id)` on cast for stat-check (Rule 8 step 4) | None | Hot read path on cast |
| **#10 Exercise → Class Mapping** | (none direct) | Returns class enum；no direct Ability System call | None | Provisional — when #10 authored, class enum names must match Rule 2 (STRIKE/CONTROL/MOBILITY) or this GDD revises |
| **#18 PR Detection & Avatar Progression** | emits signal (consumed by Ability System) | Emits `pr_breakthrough(stat_id, magnitude)` signal；**G-PR-5 amendment (2026-06-06, #18 story 012)**：#18 喺自己 `_ready()` reverse-wire 落 `_on_pr_breakthrough`（G-PR-4 pinned entry point）；`_on_stat_changed` 已 skip `source == PR_BREAKTHROUGH`（Path A 係唯一 PR unlock route — 消 double-path + 保 provenance/immediate-flush）；另加 `is_boot_completed()` sync getter（mirror #11 G-2）。`magnitude` = relative ratio [0, 2.0]，唔係 delta；#18 NOT directly call `unlock_ability` | None | Pre-MVP system — VS-tier 提供 mock/provisional path；mock 需要 emit same `pr_breakthrough(stat_id, magnitude)` signal interface |
| **#13 CombatResolver** | calls mutation + reads | `cast_ability(...)` per combat tick；`get_unlocked_abilities()` / `get_ability_state(id)` per combat scheduler；NO signal subscription (read-on-demand for stateless combat math) | None | Pure-function combat math reads on each tick；O(1) reads 保證 hot path 唔 bottleneck |
| **#20 Gym-Mode HUD** | listens | `connect_for_initial_state` to `ability_unlocked` + `ability_cooldown_started` + `ability_cooldown_ended`；HUD redraw per signal | None | Pillar 2 Frictionless — HUD update ≤1 frame |
| **#22 Character Screen** | listens + reads on open | `connect_for_initial_state` for live update；`get_unlocked_abilities()` + `get_ability_state(id)` on screen open | None | Player-facing ability comparison view |
| **#26 Avatar Renderer** | listens | Subscribe `ability_cast` to trigger cast animation (e.g., STRIKE_TIER_3 punch anim) | None | v0.2 layered character system 會深化呢個 dependency；MVP 用 placeholder animation |
| **#30 Skill Tree (v0.2)** | listens + reads | `connect_for_initial_state` to `ability_unlocked`；reads `get_unlocked_abilities()` to render tree state | None | v0.2 only — MVP 唔 ship skill tree UI |
| **#28 Telemetry / Analytics** | listens | Subscribe 4 telemetry signals (`ability_unlock_save_failed` / `ability_mutation_rejected` / `ability_cast_rejected` / `boot_completed`)；forward to GymSys backend | None | `ability_mutation_rejected` release-build fires = 可能有 cheat 嘗試或 implementation bug |

**Interaction invariants**:
- **Single mutation API chokepoint**: 所有 unlock 經 `unlock_ability`；所有 cast 經 `cast_ability`。No exceptions (Rule 3 closed API)
- **Read API is O(1) + side-effect-free**: `get_unlocked_abilities()` 返 immutable Dictionary view (per Godot 4.6 `Dictionary.make_read_only()`)；`get_ability_state(id)` 返 `AbilityState` struct snapshot；hot path (#13 combat tick) 可安全頻繁 call
- **Subscribers MUST use Contract 6 helper**: 任何 plain `.connect("ability_unlocked", cb)` 會 miss boot-time initial values；CI lint `tools/ci/check_ability_signal_connect.gd` enforce
- **Equipment不直接改變ability state**: Equipment buff stat (#11 EQUIPMENT modifier path) → derived stat changes → if cross stat threshold → unlock_ability path runs (Rule 7 Path B)；equipment unequip → derived stat drops → Rule 8 step 4 stat check may reject cast (return STAT_INSUFFICIENT)，但 unlock state 不變 (Rule 12)
- **#13 must check `get_ability_state(id)` before cast**: per Rule 5 NOT_UNLOCKED gate — caller-side check 避免 wasted cast attempt + telemetry noise

## Formulas

本 section 3 條 formula 全部 **pure function**、O(1) compute、無 allocation。設計原則：data-driven const lookup（非 closed-form）— 玩家可預期、designer 易調，且 unlock event 順序 deterministic。

### Formula 1: TIER_THRESHOLDS — 每個 (class, tier) 對應嘅 stat threshold

**Rationale**: Rule 7 unlock evaluation 喺 `STAT_THRESHOLD` path 用呢個 lookup table 對比 `current_stat_value`，決定 ability 是否可以解鎖。採用 **data-driven const lookup table**（非 closed-form formula）嘅理由：

1. **可預測性**：玩家 in-UI 見到「下個 tier 仲差 X stat」嘅進度，必須係穩定可預期嘅整數值，唔可以因為 exp/log 計算飄移
2. **Designer tuning velocity**：early playtest 大機會調整其中一兩個 threshold，lookup table 改一個格唔影響其他 tier
3. **與 Pillar 4 specialist/hybrid 軸對齊**：threshold 之間嘅 gap (10 → 50 → 200) 需要 non-uniform spacing（首 tier 易、尾 tier 難），closed-form 多項式表達唔到呢種 designer-intent curve

數值用 `DEFAULT_BASE_STAT = 10.0` 作為 TIER_1 anchor（first-week reachable），用 `MAX_STAT_VALUE = 999` 嘅 ~20% 作為 TIER_3 anchor（multi-month commitment per class）。

`TIER_THRESHOLDS[class][tier] = lookup(class, tier)`

實際 values (3 class × 3 tier，全部 class 用同一組 threshold 確保跨 class 對稱)：

| Tier | Stat Threshold | Target Time-to-Unlock | Pillar 4 Build Implication |
|------|---------------|----------------------|---------------------------|
| TIER_1 | 10 | First week (first-boot 已達) | All builds 立即解鎖 base ability |
| TIER_2 | 50 | First month (~25-35 sessions) | Casual/hybrid builds 可達 |
| TIER_3 | 200 | 3-6 months specialist commitment | Specialist build only；hybrid 慢 2-3x |

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `class` | c | enum | {STRIKE, CONTROL, MOBILITY} | Ability class，由 driving stat 決定 (STR/DEX/VIT) |
| `tier` | t | enum | {TIER_1, TIER_2, TIER_3} | Ability tier，3 個 unlock gate |
| `threshold` | T | int | {10, 50, 200} | Required stat value to unlock |
| `current_stat_value` | s | float | [0, 999] | 來自 #11 Stat System，driving stat 嘅 current value |
| `unlocked` | result | bool | {true, false} | `unlocked = (s ≥ T)` |

**Output Range**: `T ∈ {10, 50, 200}`，bounded by stat hard cap `MAX_STAT_VALUE = 999`。三個 anchor value 全部 < 999，所以任何 tier 都係 reachable（無 dead content）。Extreme behaviour：

- `s = 0`（極新玩家，唔應該發生因為 `DEFAULT_BASE_STAT = 10.0`）：no unlocks
- `s = 999`（max cap）：3 tier 全部 unlocked，gate logic 退化為 idempotent (Rule 13 step 1 idempotent guard)

**Cross-knob invariants**:
1. `TIER_1 < TIER_2 < TIER_3`（strict monotonic — 否則 unlock event ordering 會壞）
2. `TIER_1 ≥ DEFAULT_BASE_STAT`（first-boot 唔可以已經 auto-unlock 全部，必須有少量 progression 觸發 unlock feedback）— 取 equal value 10，配合 first VOLUME_TICK (~0.05) 即達 unlock
3. `TIER_3 ≤ MAX_STAT_VALUE × 0.25`（TIER_3 唔可以接近 hard cap，避免 grind ceiling 變成 unlock gate）
4. Three classes 共用同一組 threshold — Pillar 4 fairness (STR-specialist 與 DEX-specialist 達 TIER_3 嘅 effort 對稱)

**Worked Example**:

- **New player (first-boot, STR=10.0, DEX=10.0, VIT=10.0)**:
  - STRIKE: `10 ≥ 10` → TIER_1_JAB unlocked
  - CONTROL: `10 ≥ 10` → TIER_1_PARRY unlocked
  - MOBILITY: `10 ≥ 10` → TIER_1_DASH unlocked
  - 結果：3 個 TIER_1 ability 即時 available，符合 onboarding 目標

- **Mid-game STRIKE specialist (1 個月純 push training, STR=55, DEX=12, VIT=14)**:
  - STRIKE: `55 ≥ 50` → TIER_2_HOOK unlocked；`55 < 200` → TIER_3 locked
  - CONTROL: `12 ≥ 10` only → 仍係 TIER_1
  - MOBILITY: `14 ≥ 10` only → 仍係 TIER_1
  - 結果：STRIKE 路線開始拉開，hybrid path 仍喺 base — Pillar 4 expression 顯現

- **Hardcore STRIKE specialist (6 個月純 push, STR=210, DEX=35, VIT=40)**:
  - STRIKE: `210 ≥ 200` → TIER_3_OVERHAND unlocked，全 STRIKE 樹完成
  - CONTROL: `35 < 50` → 仍係 TIER_1
  - MOBILITY: `40 < 50` → 仍係 TIER_1
  - 結果：Pillar 4 specialist build 完整表達

- **Hardcore hybrid player (6 個月均衡, STR=85, DEX=80, VIT=78)**:
  - 3 class 全部 TIER_2 unlocked，無一達 TIER_3
  - 結果：Hybrid 有 9 條 ability 中 6 條，specialist 有 3 條 mastery + 6 條 base — 對稱 trade-off 成立

**Tuning Knobs (Section G)**: `TIER_1_THRESHOLD`, `TIER_2_THRESHOLD`, `TIER_3_THRESHOLD`

---

### Formula 2: BASE_COOLDOWN_SEC — 每個 ability tier 對應嘅 base cooldown

**Rationale**: Rule 8 step 6 喺 cast 完之後 `_cooldown_remaining[ability_id] = ability.base_cooldown_sec`。Cooldown 設計係 combat pacing 嘅 primary lever：

- **Pillar 2 (Frictionless)**: cooldown 過長 → boss 戰玩家 idle 等 CD，frustrating；過短 → 退化為 spam，failure of design intent
- **Tier 設計意圖**: TIER_1 = bread-and-butter（高頻、低 impact），TIER_2 = setup/combo piece（中頻、中 impact），TIER_3 = signature move（低頻、高 impact）

採用 **fixed-per-tier const lookup**（非 stat-scaled）嘅理由：

1. **Stat-scaled cooldown 會引入逆 progression**：玩家練得多反而 ability spam 更快，violate「power 由 unlock 同 damage 表達，唔由 cooldown 表達」嘅 separation of concerns
2. **Combat readability**：玩家需要 mental model 知「呢個 ability 大概幾耐 ready 返」，跨 stat 飄移會破壞呢個 model
3. **與 #11 Stat System decoupling**：Stat 飄移唔應該影響 combat tempo，避免雙系統 coupling bug

`BASE_COOLDOWN_SEC[tier] = lookup(tier)`

實際 values：

| Tier | base_cooldown_sec | Casts per 60-sec Encounter | Design Role |
|------|-------------------|---------------------------|-------------|
| TIER_1 | 3.0 | ~20 | Bread-and-butter，rhythm establisher |
| TIER_2 | 6.0 | ~10 | Combo piece，setup ability |
| TIER_3 | 10.0 | ~6 | Signature move，commitment cast |

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `tier` | t | enum | {TIER_1, TIER_2, TIER_3} | Ability tier |
| `base_cooldown_sec` | cd | float | {3.0, 6.0, 10.0} | Seconds before ability can re-cast |
| `cooldown_remaining` | cd_r | float | [0.0, cd] | Runtime countdown，stored in `_cooldown_remaining` dict |
| `can_cast` | result | bool | {true, false} | `can_cast = (cd_r ≤ 0.0)` |

**Output Range**: `cd ∈ {3.0, 6.0, 10.0}` 秒。Bounded 由 design intent 而非 hard limit。Extreme behaviour：

- `cd → 0`（hypothetical buff override，非 base）：退化為 spam，必須由 cast logic 額外 rate-limit (out of scope for base formula)
- `cd → ∞`（hypothetical）：ability 永遠 unavailable，等於 unlearn — 用 unlock state 表達會更清晰，cooldown 唔應該做 unlock job

**Cross-knob invariants**:
1. `TIER_1_CD < TIER_2_CD < TIER_3_CD`（strict monotonic — higher tier 必須 rarer cast，否則 tier hierarchy 崩潰）
2. `TIER_1_CD ≥ 2.0`（floor — 防止 spam degeneration；典型 player input cadence ceiling ~2-3 cast/sec）
3. `TIER_3_CD ≤ 15.0`（ceiling — 防止 boss 戰 dead time；60-sec encounter 至少要可以 cast 4 次 TIER_3）
4. `TIER_3_CD / TIER_1_CD ≤ 4.0`（ratio cap — tier 之間 cadence gap 唔可以太大；current ratio = 10.0/3.0 = 3.33 ✓）

**Worked Example**:

- **New player 60-sec encounter (only TIER_1_JAB unlocked, cd=3.0)**:
  - Max casts: `60 / 3.0 = 20`
  - Player 感受：constant rhythm，jab 永遠 available

- **Mid-game STRIKE specialist 60-sec encounter (TIER_1 + TIER_2 unlocked)**:
  - TIER_1_JAB casts: `60 / 3.0 = 20`
  - TIER_2_HOOK casts: `60 / 6.0 = 10`
  - 玩家可以 weave: jab-jab-hook-jab-jab-hook combo pattern，cadence asymmetry 創造節奏感

- **Hardcore STRIKE specialist 60-sec boss fight (3 tier 全 unlocked)**:
  - TIER_1: 20, TIER_2: 10, TIER_3: 6 → total ~36 ability events / 60 sec = ~0.6 cast/sec ✓ readable

**Tuning Knobs (Section G)**: `TIER_1_BASE_COOLDOWN_SEC`, `TIER_2_BASE_COOLDOWN_SEC`, `TIER_3_BASE_COOLDOWN_SEC`

---

### Formula 3: UNLOCK_EVENT_PRIORITY — 同 frame 多個 unlock 觸發時嘅 emit order

**Rationale**: Edge case — 玩家做完一個大 PR，PR_BREAKTHROUGH delta 推 stat 一次跨越多個 threshold（罕見但 deterministic possible），或 PR_BREAKTHROUGH path 同 STAT_THRESHOLD path 同 frame triggered。如果 emit order 唔 deterministic：

1. **UX 災難**：unlock VFX/SFX 重疊播放，玩家睇唔清解鎖咗咩
2. **Test brittleness**：unit test 對 `ability_unlocked` signal sequence 嘅 assertion 會 flaky
3. **Replay/save 不一致**：兩次相同 input 產生唔同 event log

設計選擇 **tier-ascending order**（TIER_1 → TIER_2 → TIER_3 先後 emit）嘅理由：

- **Narrative coherence**：玩家心理上「先學基礎再學進階」，TIER_1 unlock notification 先出，escalation feel
- **與 Pillar 2 對齊**：玩家有 cognitive runway 逐個吸收
- **Class ordering secondary**：同 tier 之間用 enum declaration order (STRIKE → CONTROL → MOBILITY) 作為 deterministic tiebreaker

`emit_order = sort(pending_unlocks, key=(tier_ordinal, class_ordinal))`

| tier_ordinal | tier | class_ordinal | class | emit_priority (sort key) |
|-------------|------|---------------|-------|-------------------------|
| 0 | TIER_1 | 0 | STRIKE | (0, 0) — emits first |
| 0 | TIER_1 | 1 | CONTROL | (0, 1) |
| 0 | TIER_1 | 2 | MOBILITY | (0, 2) |
| 1 | TIER_2 | 0 | STRIKE | (1, 0) |
| 1 | TIER_2 | 1 | CONTROL | (1, 1) |
| 1 | TIER_2 | 2 | MOBILITY | (1, 2) |
| 2 | TIER_3 | 0 | STRIKE | (2, 0) |
| 2 | TIER_3 | 1 | CONTROL | (2, 1) |
| 2 | TIER_3 | 2 | MOBILITY | (2, 2) — emits last |

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `pending_unlocks` | U | Array[AbilityId] | size [0, 9] | 同 frame 內 evaluate 出嘅 to-be-emitted unlocks |
| `tier_ordinal` | t_ord | int | {0, 1, 2} | TIER_1=0, TIER_2=1, TIER_3=2 |
| `class_ordinal` | c_ord | int | {0, 1, 2} | STRIKE=0, CONTROL=1, MOBILITY=2 |
| `emit_priority` | (t_ord, c_ord) | tuple(int,int) | (0,0) to (2,2) | Lexicographic sort key |
| `emit_order` | result | Array[AbilityId] | size [0, 9] | Deterministic ordered queue |

**Output Range**: Sort 後 `emit_order` 係 `pending_unlocks` 嘅 permutation，size 一致。Max realistic size = 9（first-boot 同 frame 全 unlock，極罕見 corner case，已 verified test-tractable）。

**Cross-knob invariants**:
1. **Determinism**：相同 `pending_unlocks` set（無視 insertion order）必然產生相同 `emit_order`
2. **Tier monotonic emit**：對任意 `i < j`，`emit_order[i].tier_ordinal ≤ emit_order[j].tier_ordinal`
3. **No reordering across frames**：同 frame 內 sort；跨 frame unlocks 按 frame 順序 emit
4. **Idempotent guard 在 sort 之前**：Rule 13 step 1 嘅 duplicate unlock guard 必須喺 sort 之前 apply

**Worked Example**:

- **Common case (single unlock per frame)**:
  - `pending_unlocks = [TIER_2_HOOK]` → `emit_order = [TIER_2_HOOK]` — trivial

- **First-boot edge case (DEFAULT_BASE_STAT=10.0 = TIER_1_THRESHOLD，3 class 同時觸發)**:
  - `pending_unlocks = [TIER_1_DASH, TIER_1_JAB, TIER_1_PARRY]`（hash order 隨機）
  - Sort by (tier_ordinal, class_ordinal):
    - TIER_1_JAB → (0, 0)
    - TIER_1_PARRY → (0, 1)
    - TIER_1_DASH → (0, 2)
  - `emit_order = [TIER_1_JAB, TIER_1_PARRY, TIER_1_DASH]` — STRIKE → CONTROL → MOBILITY crescendo

- **Hypothetical multi-tier (一次 PR 跨 2 class TIER_2)**:
  - `pending_unlocks = [TIER_2_HOOK_PULL, TIER_2_HOOK]`
  - Sort: TIER_2_HOOK → (1, 0); TIER_2_HOOK_PULL → (1, 1)
  - `emit_order = [TIER_2_HOOK, TIER_2_HOOK_PULL]` — deterministic

**Tuning Knobs (Section G)**: **None** — 呢條 formula 係 determinism contract，唔係 balance lever。Enum ordering 係 architectural decision，唔應該作為 runtime knob。

---

### Cross-Formula Invariants

呢 3 條 cross-formula invariants 違反任何一條都應該喺 CI test fail：

**CF-1: Default Baseline Auto-Unlock** — first-boot DEFAULT_BASE_STAT=10 ≥ TIER_1_THRESHOLD=10 → 3 個 TIER_1 ability 自動 unlock；任何 knob 調整破壞呢個 default 即係 break onboarding moment。Hard-coded 喺 `tests/unit/ability_system/test_first_boot_unlock.gd`。

**CF-2: Tier Progression Time Anchors** — 三個 anchor 對應 design intent：
- TIER_1: first week reachable (10 stat ≈ first VOLUME_TICK；first-boot auto-unlock per CF-1)
- TIER_2: **specialist build** first month (50 stat ÷ ~2.0/session pure-class ≈ 25 sessions)；**hybrid build** ~2.5 months (50 stat ÷ ~0.67/session per-class at 3-way split ≈ 75 sessions) — Formula 1 table 話「Casual/hybrid builds 可達」係正確嘅，但 timeline 係 2-3 個月而非 1 個月 (R-2 fix)
- TIER_3: specialist commitment ~6 months (200 stat ÷ ~2.0/session ≈ 100 sessions per class)；hybrid build 可能需要 2+ 年達任意一個 TIER_3 (因為每 stat 只積 ~0.67/session)

**CF-3: Cooldown Cadence Diversity** — 3 tier cooldown 必須產生 3 種不同 cast rhythm；TIER_1 ratio TIER_3 cooldown ≤ 0.4（current: 3/10 = 0.3 ✓） — 保證高 tier 始終係 rare moment

---

### Formulas Owned Elsewhere (Referenced, Not Duplicated)

| Formula | Owner GDD / ADR | Used in this layer |
|---------|-----------------|---------------------|
| `volume_tick_delta` | GDD #11 Stat System (Formula 1) | Not used directly — Ability System 唔做 stat mutation |
| `pr_breakthrough_delta` | GDD #11 Stat System (Formula 2) | Indirect — affects rate at which stat crosses TIER thresholds |
| Damage formulas (ATTACK_POWER × ...) | GDD #13 CombatResolver (not yet authored) | Ability System emit `ability_cast` with damage param 由 #13 compute |
| Class routing (push→STR/pull→DEX/leg→VIT) | GDD #10 Exercise→Class Mapping (Pre-MVP, Not Started) | Provisional input — `class_id` enum mapping

## Edge Cases

### Boot / Persistence Edge Cases

- **EC-01 First boot (no `ability.unlocked.*` keys exist)**: Rule 10 step 1 iterate 返 empty list → `_unlocked_abilities` 空 → first `stat_changed` from #11 boot delivery (per Contract 6) 觸發 Rule 7 Path B → if DEFAULT_BASE_STAT=10 ≥ TIER_1_THRESHOLD=10 → 3 個 TIER_1 ability 同 frame unlock via Formula 3 emit order。**唔 emit `ability_unlocked` during `_ready()`** (subscriber 仲未 connect)；emit 喺 #11 initial-state delivery 觸發。
- **EC-02 PersistenceLayer Corrupt substate (all reads return `{}`)**: Rule 10 fallback - `list_keys_matching` 返 empty → treat as first boot (EC-01 path) + `push_warning("Ability boot fallback - PersistenceLayer corrupt")`。**冇 attempt restore from backend** - Ability System scope-out (backend reconciliation 屬 #2 GymSys + ADR-003 Tier 1)
- **EC-03 Partial `ability.unlocked.*` keys (e.g., STRIKE_TIER_2 存在但 STRIKE_TIER_1 缺失)**: 每個 key 獨立 read - present keys 加入 `_unlocked_abilities`。**No back-fill** - 即使 logical "should have TIER_1 to have TIER_2"，本 GDD 唔自行 reconstruct；屬 PersistenceLayer / migration concern。`push_warning("ability_id <STRIKE_TIER_1> absent but <STRIKE_TIER_2> present - non-causal unlock chain")` for telemetry。
- **EC-04 Persisted UnlockRecord 異常 (NaN timestamp / invalid source enum / corrupted SerializableResource)**: Rule 10 step 2 defensive：
  - `is_nan(first_unlocked_at_unix)` → fallback to `Time.get_unix_time_from_system()` (current time) + push_warning
  - `source not in UnlockSource.values()` → coerce to `INITIAL_STATE` + push_warning
  - `to_dict()` round-trip fail → skip key + `ability_unlock_save_failed` emit
  - Boot continues — 唔阻 game launch
- **EC-05 Schema migration: ability slot 變化 (e.g., v0.2 加 TIER_4)**: 由 PersistenceLayer Contract 10 migration chain own — Ability System 只見 post-migration ability_id list。本 GDD scope 唔涵蓋 TIER_4；future schema bump revise 本 GDD Rule 1。
- **EC-06 PersistenceLayer 寫失敗 (Rule 13 step 3 returns false)**: emit `ability_unlock_save_failed(ability_id)` + push_error + return false from `unlock_ability` + **in-memory `_unlocked_abilities` unchanged**。Caller (#18) handle return false (e.g., #18 已收到 server `pr_breakthrough` 但 client persist 失敗 → 下次 boot reconcile via ADR-003 backend-primary path)。**No retry within Ability System**。

### Mutation API Edge Cases (Rule 3 + Rule 13)

- **EC-07 Unknown ability_id (e.g., `unlock_ability("undefined_id", PR_BREAKTHROUGH)`)**: Rule 1 ability surface LOCKED → push_error + emit `ability_mutation_rejected(ability_id, source, "invalid_ability_id")` + return false。`_unlocked_abilities` 不變。
- **EC-08 Source 唔喺 enum (e.g., int cast to invalid UnlockSource)**: GDScript runtime check — `if source not in UnlockSource.values(): push_error + return false`。Typed enum API 一般 prevent compile-time，但 reflection-style invoke 可能繞過 → defensive check。
- **EC-09 Source/class mismatch (e.g., `unlock_ability(CONTROL_TIER_1_PARRY, PR_BREAKTHROUGH, stat_id=STR)`)**: Rule 6 allow-list — STR-source 唔可 unlock CONTROL ability → push_error + emit `ability_mutation_rejected(CONTROL_TIER_1_PARRY, PR_BREAKTHROUGH, "source_class_mismatch")` + return false。
- **EC-10 Caller whitelist violation (e.g., `src/feature/equipment_inventory.gd` call `unlock_ability(...)`)**: Rule 6 caller whitelist CI lint catches at build time。Runtime: 若 CI lint missed → push_error + emit `ability_mutation_rejected(..., "caller_whitelist_violation")` + return false。Defensive layer — release build expected 0 occurrences。
- **EC-11 Repeated unlock (idempotent guard)**: `unlock_ability(STRIKE_TIER_1_JAB, PR_BREAKTHROUGH)` 第二次 call (already in `_unlocked_abilities`) → Rule 13 step 1 idempotent guard catches → return **true** (no-op + no double emit + no double persist)。Rationale: caller (#18) 可能 re-emit `pr_breakthrough` 喺 retry path；idempotency 防 telemetry noise + double `ability_unlocked` emit。
- **EC-12 Concurrent unlock same-frame (different ability_ids)**: Sync API — 第二個 call 喺第一個 return 之後 execute。Order = call order，但 Formula 3 UNLOCK_EVENT_PRIORITY sort 喺 emit 之前 apply。兩個 `ability_unlocked` 按 sorted order emit (sync sequence)。
- **EC-13 Stat update triggers cross-tier unlock (e.g., STR jumps 49 → 52)**: Rule 7 Path B `_evaluate_unlock(STR, 52, STAT_THRESHOLD)` → iterate tier 1→2→3：
  - TIER_1 (10): 52 ≥ 10 ✓ 但 STRIKE_TIER_1_JAB 已 unlocked (idempotent) → skip emit
  - TIER_2 (50): 52 ≥ 50 ✓ STRIKE_TIER_2_HOOK NOT unlocked → enter pending_unlocks
  - TIER_3 (200): 52 < 200 ✗ → no action
  - Result: 1 unlock event emit (TIER_2)
- **EC-14 Stat update triggers double-tier jump (e.g., STR jumps 49 → 210 via massive equipment buff)**: Rule 7 Path B iterate tier 1→2→3：
  - TIER_2: 210 ≥ 50 ✓ unlocked → pending
  - TIER_3: 210 ≥ 200 ✓ unlocked → pending
  - Formula 3 sort emit order: TIER_2 first, then TIER_3
  - **但 equipment-driven stat boost 唔應該 unlock ability** — Pillar 1 violation (anti-fabrication)；treatment：Rule 7 Path B 收 `stat_changed` 時 check `source ∈ {VOLUME_TICK, PR_BREAKTHROUGH}` only (EQUIPMENT source excluded per Rule 7 spec)
- **EC-15 Stat update from EQUIPMENT source**: per EC-14 fix - `stat_changed(STR, ..., EQUIPMENT, _)` handler 直接 return early (no unlock evaluation)。Equipment buff stat → derived combat stronger，但 唔可以 unlock new ability。Pillar 1 anti-fabrication 守住。
- **EC-16 Unlock during Reconciling substate**: Rule 11 Reconciling 內 mutation API reject — `unlock_ability` 同樣 reject (`ability_mutation_rejected(..., "suspended_substate")`)。#18 PR Detection 必須 wait `boot_completed` signal + GSM `Ready` state 後先 emit pr_breakthrough — 屬 #18 lifecycle responsibility。

### Cast API Edge Cases (Rule 5 + Rule 8)

- **EC-17 Cast unknown ability_id**: per Rule 8 step 1 - `ability_id` 唔喺 `AbilityRegistry` → push_error + return `CastResult.NOT_UNLOCKED` (用 NOT_UNLOCKED reason 簡化 telemetry — caller bug 結果一樣係 ability 不可用)
- **EC-18 Cast unlocked-but-cooling-down ability**: Rule 8 step 2 - `_cooldown_remaining[id] = 1.5 > 0` → return `CastResult.ON_COOLDOWN` (含 time_remaining=1.5)。#13 CombatResolver scheduler 跌返低 tier ability。
- **EC-19 Cast during GSM Idle (not CombatActive/BossEncounter)**: Rule 8 step 3 - GSM check fail → return `CastResult.GSM_REJECT`。Telemetry `ability_cast_rejected(id, "gsm_reject")` fires。
- **EC-20 Cast with stat dropped below minimum_active_stat (極罕)**: Rule 8 step 4 - read STR=3 (debug override 觸發 anti-decay 例外) < minimum_active_stat=5 → return `CastResult.STAT_INSUFFICIENT`。Unlock state 不變 (Rule 12)，玩家 stat 升返夠就可以 cast。
- **EC-21 Cast with null target on non-SELF ability**: Rule 8 step 5 - target_type=ENEMY 但 target=null → return `CastResult.INVALID_TARGET`。Caller bug — #13 應該 pre-validate。
- **EC-22 Cast with destroyed target (Node has been queue_free()'d)**: Godot 4.6 `Node.is_queued_for_deletion()` check 喺 step 5。If true → return `CastResult.INVALID_TARGET` (treat as null)。Defensive — combat tick frequency 高，target 可能 mid-frame 死。
- **EC-23 Concurrent cast same-frame same ability**: Sync API — 第二個 call 喺第一個 return 之後 execute。第一 call SUCCESS → cooldown 啟動；第二 call 立即 ON_COOLDOWN。No race。
- **EC-24 Cast cooldown exactly 0.0 boundary (cooldown 剛剛 expire)**: Rule 14 `_process(delta)` 將 time -= delta；若 result ≤ 0 → erase entry。Subsequent cast 喺同 frame 後續 call → step 2 `_cooldown_remaining.has(id) == false` → cast proceeds (cooldown ended)。**OK** — no off-by-one。

### Cooldown / `_process` Edge Cases (Rule 14)

- **EC-25 `set_process(false)` race during `_process` body**: Godot 4.6 guarantees `_process` 完成 before next-frame `set_process` takes effect。Cooldown last entry erased inside `_process` body → set_process(false) called → 下一 frame `_process` 唔再 run。No race。
- **EC-26 `bfcache resume` 30s freeze causing large delta jump**: Rule 14 clamp `delta = min(delta, MAX_FRAME_DELTA = 0.1)` → 30s freeze 後 single-frame `delta=0.1` → cooldown decay 唔超出 100ms per frame → 後續 frames 繼續 decay。**No spike**。
- **EC-27 Cooldown for un-unlocked ability appears in `_cooldown_remaining` (impossible per Rule 13 + Rule 8)**: Defensive `if not _unlocked_abilities.has(id): _cooldown_remaining.erase(id) + push_warning`。Should never happen — Rule 8 step 1 NOT_UNLOCKED gate ensures cooldown never start for unlocked-only ability。
- **EC-28 Subscriber handler call `cast_ability` from `ability_cooldown_ended` (re-entrance)**: GDScript sync signal emit — handler runs before emit returns。Subscriber call `cast_ability` → cooldown re-start → emit `ability_cooldown_started` → handler returns → original `ability_cooldown_ended` emit completes。**OK if shallow**。Deep nesting (cast → ended → cast → ended → ...) → `_emit_depth` counter check (analogous to #6 ScreenEffects Rule 12 + #11 Stat Rule 22): `_emit_depth > 2` → push_error + return `CastResult.GSM_REJECT` (defensive)。

### Substate / Lifecycle Edge Cases

- **EC-29 GSM rapid Suspended ↔ Ready transitions (debug)**: Ability System Suspended → Reconciling → Ready 多次。Reconciling overhead small (max 9 ability key reads = trivial)。**No degradation**。
- **EC-30 GSM state == Suspended at boot (crash recovery)**: Rule 10 boot completes (Ready substate) → `connect_for_initial_state` 收 GSM `state_changed(_, "suspended", _)` initial delivery → 立即 Ready → Suspended transition (no Reconciling intermediate)。Subscriber 收 `boot_completed` 然後立刻知 mutation rejected。
- **EC-31 `_ready()` exception during read**: Defensive — autoload chain 唔可以 abort game。Any exception in Rule 10 → emit `ability_unlock_save_failed("BOOT_FAILED")` + populate empty `_unlocked_abilities` + enter Ready substate (degraded mode — player sees no abilities until first valid stat_changed trigger Rule 7 Path B)。

### Subscriber Edge Cases (ADR-006 Contract 6)

- **EC-32 Subscriber uses plain `.connect("ability_unlocked", cb)` (skips Contract 6 helper)**: Miss initial-state delivery — 第一個 handler 收到 only 第一次 NEW unlock 之後嘅 event (boot 期間已 unlocked abilities 唔 deliver)。**Mitigation**: CI lint `tools/ci/check_ability_signal_connect.gd` grep `\.connect\(.*"ability_(unlocked|cast|cooldown_)"` 喺 `src/` (排除 `src/autoload/ability_system.gd` + `tests/`) → 任何 non-`connect_for_initial_state` path → fail build。
- **EC-33 Subscriber callable signature mismatch**: GDScript signal emit runtime — callable invocation 引發 runtime error。**Mitigation**: callable signature 強制喺 helper 用 typed Callable + signature validation (best-effort)。
- **EC-34 Subscriber connected then `Node.queue_free()` (callable invalidated)**: Godot 4.6 自動斷開 dead signal connection。Ability System 唔需要 explicit cleanup。

### Cross-System Edge Cases

- **EC-35 #18 sends anomalous pr_breakthrough (negative magnitude, NaN, etc.)**: Ability System Rule 7 Path A 唔自行 clamp — 假設 #18 server-validated (ADR-002 binding)。**Cross-system contract** — #18 GDD 必須 spec server-side validation；client-side 收 anomaly = #18 bug or compromised backend → Pillar 1 violation outside Ability System scope。Defensive: `is_nan(magnitude) or magnitude < 0` → push_error + skip evaluation (no unlock attempt)。
- **EC-36 #11 Stat System Suspended during Ability boot**: Per autoload position 5 → 6 sequential boot — Stat System 必喺 Ability Sys boot 之前 ready。Rule 7 Path B subscription via `connect_for_initial_state` 喺 boot 完成後 fires，#11 已 Ready or Suspended：
  - #11 Ready → Path B 正常 evaluate
  - #11 Suspended → `stat_changed` 唔 fire (per #11 Rule 14 Suspended freeze)；no evaluation triggered；OK
- **EC-37 ADR-003 ratification after Ability System ships (`ability.unlocked.*` namespace migration)**: VS-tier 假設 namespace = `ability.unlocked.<lowercase_ability_id>`。ADR-003 ratified 後 namespace 可能 retune (e.g., 加 `ability.unlocked.<character_id>.<ability_id>` for multi-character)。**Migration path**: PersistenceLayer Contract 10 migration step rewrites keys。Stat System Rule 1 LOCKED ability surface — schema bump 屬 #11 + #12 同步 revise。
- **EC-38 #13 CombatResolver implementation skips `get_ability_state` check before cast**: Caller-side check missing → `cast_ability` returns `NOT_UNLOCKED` / `ON_COOLDOWN` / 其他 reject。`ability_cast_rejected` telemetry fire → #28 backend log → developer notice → fix。No game crash — defensive rejection。
- **EC-39 #10 Exercise→Class Mapping authored with different class enum (e.g., `{CHEST, BACK, LEGS}` instead of `{STRIKE, CONTROL, MOBILITY}`)**: 屬 cross-GDD naming inconsistency — should be caught by `/consistency-check` at #10 authoring time。Resolution: #10 GDD uses ability-class enum names (STRIKE/CONTROL/MOBILITY)，唔用 muscle-group names (CHEST/BACK/LEGS) — class_id 係 abstract ability-domain concept，唔係 anatomy。本 GDD Rule 2 + Section B FR-1 binding forecloses 呢個 risk。

## Dependencies

### Upstream (Hard — Ability System cannot function without)

| GDD / ADR | Status | Interface | Why hard |
|-----------|--------|-----------|----------|
| **#3 PersistenceLayer** | Approved 2026-05-26 | `list_keys_matching("ability.unlocked.*")` at boot；`write("ability.unlocked.<id>", envelope, flush: bool)` per Rule 9；listens `critical_save_failed` filter `key startswith "ability."` | Boot reconciliation 完全依賴 PersistenceLayer sync read；Rule 13 persistence-first ordering 要求每次 unlock 必 write 落 disk 先 mutate cache |
| **#1 GameStateMachine** | Approved 2026-05-25 | Subscribes `state_changed` via `connect_for_initial_state` for Suspended substate gate (Rule 11) + cast permit check (Rule 8 step 3) | Pillar 1 anti-fabrication requires session-validity gate；Suspended 期間 mutation reject |
| **#11 Stat System** | Approved 2026-05-27 | Subscribes `stat_changed` via `connect_for_initial_state` for Rule 7 Path B (STAT_THRESHOLD unlock evaluation)；reads `get_stat(stat_id)` on cast (Rule 8 step 4) | Ability System 全部 unlock 邏輯依賴 stat threshold；冇 #11 整個 Pillar 4 progression 路徑斷 |
| **ADR-006 State Machine Contract** | Accepted 2026-05-28 | Contract 4 (autoload sequential boot — pos 6 after Persistence/GSM/PlatformDetect/GymSys/Stat; F-SETUP-1 sync 2026-05-28)；Contract 6 (`connect_for_initial_state` sentinel — both as subscriber to #1+#11 AND as broadcaster to 4 consumers) | Boot ordering invariant + observer pattern contract |
| **ADR-003 Save State Strategy** | Proposed | `ability.unlocked.*` namespace allocation under `user://state.json` Tier 2 persistence；defines IndexedDB quota share for ability keys (small — max 9 envelope records < 2KB) | Namespace ratification — without it, namespace collision risk |

### Upstream (Soft — Co-evolving / Provisional)

| GDD / ADR | Status | Interface | Why soft |
|-----------|--------|-----------|----------|
| **#10 Exercise → Class Mapping** | **Not Started (Pre-MVP)** | Provides `class_id` enum (STRIKE/CONTROL/MOBILITY) for #18 PR Detection to route PR breakthrough to correct ability class | ⚠️ **PROVISIONAL** — #10 authored 時 class enum names MUST match Rule 2 (STRIKE/CONTROL/MOBILITY)，唔係 muscle-group names (CHEST/BACK/LEGS)。Section B FR-1 binding |
| **#18 PR Detection & Avatar Progression** | Not Started (Pre-MVP) | Calls `unlock_ability(ability_id, PR_BREAKTHROUGH)` on PR detection；caller whitelist `src/feature/pr_detection.gd` | VS-tier 可用 mock provided by debug autoload；MVP gate requires real #18 |
| **ADR-005 Loot Rarity Formula** | ⚠️ Registry discrepancy — systems-index 標 "Accepted 2026-05-27" 但 technical-preferences.md 仍寫 "Proposed" | No direct binding — Ability System 唔 produce loot 或 modify rarity；ability unlock event MAY influence ADR-005 future revisions (e.g., TIER_3 unlock 觸發 LEGENDARY loot drop) | Indirect — input scope only |

### Downstream (Depended On By — consumers in dependency order)

| Consumer | Tier | Interaction | Bidirectional sync status |
|----------|------|-------------|----------------------------|
| **#13 CombatResolver** | VS (Not Started) | Hot read path — `get_unlocked_abilities()` / `get_ability_state(id)` per combat tick；`cast_ability(...)` per scheduled action；caller whitelist enforced via Rule 6 CI lint | ⚠️ Must add Ability System to #13 Section F when #13 authored — combat tick scheduler 依賴 ability slot state |
| **#20 Gym-Mode HUD** | MVP (Not Started) | Subscribes `ability_unlocked` + `ability_cooldown_started` + `ability_cooldown_ended` via `connect_for_initial_state`；HUD redraw stat numbers + cooldown bar per signal payload | ⚠️ Must use `connect_for_initial_state` helper |
| **#22 Character Screen** | MVP (Not Started) | Subscribes `ability_unlocked` for live update；`get_unlocked_abilities()` on screen open；historical comparison via #28 Telemetry | ⚠️ Must use `connect_for_initial_state` helper |
| **#26 Avatar Renderer** | VS (Not Started) | Subscribe `ability_cast` for cast animation trigger (e.g., STRIKE_TIER_3 punch anim) | ⚠️ v0.2 layered character system 會深化呢個 dependency；MVP 用 placeholder animation |
| **#30 Skill Tree (v0.2)** | v0.2 (Not Started) | `connect_for_initial_state` to `ability_unlocked`；reads `get_unlocked_abilities()` to render tree state | ⚠️ v0.2 only — MVP 唔 ship skill tree UI |
| **#28 Telemetry / Analytics** | Pre-MVP (Not Started) | Subscribe 4 telemetry signals: `ability_unlock_save_failed` / `ability_mutation_rejected` / `ability_cast_rejected` / `boot_completed`；forward to GymSys backend | ⚠️ `ability_mutation_rejected` release-build fires = 可能有 cheat 嘗試或 implementation bug |

### ADR Dependencies (Detailed)

| ADR | Status | Bound contracts | This GDD's relationship |
|-----|--------|-----------------|--------------------------|
| **ADR-006 State Machine Contract** | Proposed (ratified 2026-05-25) | Contract 3 (SerializableResource envelope — `UnlockRecord`)；Contract 4 (autoload sequential boot)；Contract 6 (`connect_for_initial_state` sentinel) | Inheritor — Ability System NOT amending ADR-006 |
| **ADR-003 Save State Strategy** | Proposed | `ability.unlocked.*` namespace allocation；`user://state.json` Tier 2 path | Inheritor — `ability.unlocked.*` namespace registered with ADR-003 |
| **ADR-005 Loot Rarity Formula** | ⚠️ Registry discrepancy (systems-index Accepted vs technical-preferences Proposed) | No direct binding | Indirect — Ability System input scope only for v0.2 ability-tier-driven loot |
| **ADR-001 Web Export Budget Caps** | Proposed | No direct binding — Ability System hot read path < 0.01ms per call (well below CPU budget) | Pillar 2 budget enforcement via O(1) read API |
| **ADR-002 GymSys Integration Protocol** | Proposed | No direct binding — Ability System 唔 talk to GymSys backend；ADR-002 path via #2 → #18 → Ability System | Indirect — `PR_BREAKTHROUGH` source originates from #18 PR Detection consuming GymSys events per ADR-002 |

### Bidirectional Sync Status

⚠️ **Sync gap notice**: 本 GDD lists 6 downstream consumers + 3 hard upstream + 3 soft upstream，但所有 downstream consumer GDDs 仲未 authored (6 ⨉ "Not Started")。當 #13 / #20 / #22 / #26 / #28 / #30 GDD authored 時，必須喺 each 嘅 Section F 加 Ability System 為 upstream dependency。

⚠️ **Already-Approved GDD propagation required**: #1 GSM、#3 PersistenceLayer、#11 Stat System (all Approved) 仲未 reference #12 Ability System 為 downstream consumer。需 next-revision batch 加入：run `/propagate-design-change ability-system.md` targeting `game-state-machine.md` + `persistence-layer.md` + `stat-system.md` Section F。

**Recommendation for future author**: 當 author 上述任何 downstream GDD 時，run `Grep pattern="ability-system|AbilitySystem|unlock_ability|cast_ability|ability_unlocked" path="design/gdd/<your-gdd>.md"` 確認 cross-reference 已加入。

### Failure Mode Matrix

| Failure Source | Detection Mechanism | Ability System Response | Downstream Impact |
|----------------|---------------------|-------------------------|-------------------|
| PersistenceLayer Corrupt substate at boot | `list_keys_matching` returns empty (EC-02) | Fallback to empty unlock set (Rule 10) + push_warning | Subscriber 收 no initial unlocks — equivalent to fresh character |
| PersistenceLayer write fails mid-session | `write()` returns false | EC-06: emit `ability_unlock_save_failed` + in-memory unchanged + caller `unlock_ability` return false | Caller (#18) handle return false；下次 boot reconcile via ADR-003 backend-primary path |
| GSM Suspended state | `state_changed(_, "suspended", _)` received | Rule 11: enter Suspended substate；reject mutation API + cast | All 6 consumers see frozen ability state until resume |
| #18 anomalous pr_breakthrough magnitude | EC-35: defensive `is_nan(magnitude) or magnitude < 0` check | Skip evaluation — no unlock attempt | Pillar 1 violation OUTSIDE Ability System scope — #18 must server-validate |
| Subscriber misconnects (plain `.connect`) | EC-32 + CI lint `check_ability_signal_connect.gd` | Build fails on release branch | Pre-merge gate |
| Cross-class unlock attempt (Pillar 4 violation) | Rule 6 source/class allow-list | Push_error + `ability_mutation_rejected(..., "source_class_mismatch")` | Pillar 4 hard guarantee maintained |
| Schema migration adds new ability (e.g., TIER_4) | PersistenceLayer Contract 10 chain runs at boot | Ability System Rule 1 LOCKED — current GDD does not handle TIER_4；schema bump requires GDD revision | All consumers must revise to handle new ability ID |

## Tuning Knobs

### Owned Knobs (8 total)

| Knob | Default | Safe Range | Source Rule / Formula | What changes if pushed |
|------|---------|-----------|------------------------|------------------------|
| `TIER_1_THRESHOLD` | 10 | [5, 30] | F1 | ↑ first-boot unlock 唔即時，新玩家 onboarding moment 失；↓ trivial — auto-unlock 喺 boot 前已超 threshold (degenerate) |
| `TIER_2_THRESHOLD` | 50 | [30, 100] | F1 | ↑ mid-game progression 拖長；↓ TIER_2 太易達，TIER_3 commitment 失 meaning |
| `TIER_3_THRESHOLD` | 200 | [100, 400] | F1 | ↑ 6-month commitment 變 1-year，hardcore 玩家 grind ceiling 失；↓ specialist build 對 hybrid build 嘅 differentiation 收窄 |
| `TIER_1_BASE_COOLDOWN_SEC` | 3.0 | [2.0, 5.0] | F2 | ↑ TIER_1 rhythm dilute，combat feel 鬆散；↓ < 2.0 接近 spam degeneration |
| `TIER_2_BASE_COOLDOWN_SEC` | 6.0 | [4.0, 9.0] | F2 | ↑ combo piece 變 rare，weave rhythm 失；↓ TIER_2 overlap TIER_1 cadence, tier hierarchy 崩 |
| `TIER_3_BASE_COOLDOWN_SEC` | 10.0 | [7.0, 15.0] | F2 | ↑ signature move dead-time，60s encounter 可能撞唔到 4 次；↓ < 7.0 TIER_3 失「commitment cast」design intent |
| `MINIMUM_ACTIVE_STAT` | 5.0 | [3.0, 15.0] | Rule 8 step 4 | ↑ EQUIPMENT debuff 易觸發 STAT_INSUFFICIENT reject (玩家 frustrating)；↓ defensive 失效 — extreme stat decay edge case 通過 |
| `MAX_EMIT_DEPTH` | 2 | [0, 4] | EC-28 | ↑ 容許 deep re-entrance，cooldown_ended → cast → ended → cast 連鎖 stack overflow 風險；↓ legitimate cast-chain in handler reject |

### Cross-Knob Invariants (CI-Verified)

呢啲 invariant 必須喺 `tests/unit/ability_system/test_knob_invariants.gd` (Section H AC) 驗證；任何 knob 改動觸發 violation 必喺 PR description 度 explicit call out。

| ID | Invariant | Rationale |
|----|-----------|-----------|
| INV-1 | `TIER_1_THRESHOLD < TIER_2_THRESHOLD < TIER_3_THRESHOLD` | F1 strict monotonic — unlock event ordering correctness (Formula 3) |
| INV-2 | `TIER_1_THRESHOLD ≥ DEFAULT_BASE_STAT` (= 10 from #11 Stat System) | F1 anchor — first-boot 唔可以已經 auto-unlock TIER_2/3 |
| INV-3 | `TIER_3_THRESHOLD ≤ MAX_STAT_VALUE × 0.25` (= 249.75 from #11 = 999) | F1 ceiling — TIER_3 唔可以接近 hard cap (grind ceiling concern) |
| INV-4 | `TIER_1_BASE_COOLDOWN_SEC < TIER_2_BASE_COOLDOWN_SEC < TIER_3_BASE_COOLDOWN_SEC` | F2 strict monotonic — tier hierarchy preservation |
| INV-5 | `TIER_1_BASE_COOLDOWN_SEC ≥ 2.0` | F2 floor — anti-spam degeneration |
| INV-6 | `TIER_3_BASE_COOLDOWN_SEC ≤ 15.0` | F2 ceiling — anti-dead-time |
| INV-7 | `TIER_3_BASE_COOLDOWN_SEC / TIER_1_BASE_COOLDOWN_SEC ≤ 4.0` | F2 ratio cap — cadence gap not too extreme |
| INV-8 | All knobs in their safe range | Guard against out-of-range typo |

### Knob Interaction Warnings

⚠️ **Class symmetry preservation**: Three classes share **same** TIER_THRESHOLDS — 唔可以 designer 想「make STRIKE easier than CONTROL」就改 STR-only threshold；Pillar 4 fairness 要求對稱。任何想做 per-class threshold 差異化 = 屬 schema change (新增 `STRIKE_TIER_2_THRESHOLD` vs `CONTROL_TIER_2_THRESHOLD` knob)，唔屬普通 tuning。

⚠️ **Cooldown floor vs Pillar 2 boss-fight pacing**: TIER_3_BASE_COOLDOWN_SEC ceiling (15.0) 預設假設 60s typical boss encounter；若 boss 戰拉長到 120s+ (TBD #16 Boss System)，呢個 ceiling 可能 over-restrictive — defer to #16 GDD authoring 時 cross-validate。

⚠️ **TIER_1_THRESHOLD = DEFAULT_BASE_STAT 嘅 onboarding 設計**: TIER_1_THRESHOLD=10 = DEFAULT_BASE_STAT=10 (恰好相等)。First-boot 3 個 TIER_1 ability auto-unlock — 呢個係 intentional onboarding moment (per Formula 1 CF-1)。若改 DEFAULT_BASE_STAT (#11 Section G knob) → 同步改 TIER_1_THRESHOLD 維持 onboarding moment。

### Referenced Knobs from Other Systems (NOT owned here)

| Knob | Owner GDD | Read access | Note |
|------|-----------|-------------|------|
| `MAX_STAT_VALUE` (= 999) | #11 Stat System | Read-only (INV-3 cross-knob invariant) | TIER_3_THRESHOLD ≤ 25% of this value |
| `DEFAULT_BASE_STAT` (= 10.0) | #11 Stat System | Read-only (INV-2 cross-knob invariant) | TIER_1_THRESHOLD ≥ this value |
| `MAX_FRAME_DELTA` (= 0.1) | #5 / #6 / #7 | Read-only (Rule 14 cooldown tick clamp) | Shared bfcache resume safety value |
| ADR-005 loot rarity (post-v0.2) | ADR-005 | Indirect | v0.2 may have ability-tier-driven loot influence |

### Tuning Knob Stability Tier (per concept doc governance)

| Tier | Knobs | Change governance |
|------|-------|--------------------|
| **LOCKED (schema bump)** | Ability slot surface (9 LOCKED IDs), class enum, tier enum, UnlockSource enum, CastResult enum | Requires PersistenceLayer schema migration; revise Rule 1 + Rule 2 + Rule 4 + Rule 5 |
| **DESIGN-FROZEN (post-Pre-MVP)** | `TIER_*_THRESHOLD` (all 3), `MINIMUM_ACTIVE_STAT` | Change requires #28 Telemetry data showing unlock pacing problem |
| **TUNABLE (sprint task)** | `TIER_*_BASE_COOLDOWN_SEC` (all 3), `MAX_EMIT_DEPTH` | Routine balance tuning; CI verifies invariants |

## Visual/Audio Requirements

**Ability System owns NO direct visual / audio surface** — 純 data layer，per Section B / C committed posture「Ability System 本身唔 fire VFX / 音效，visible glow + icon update 由下游 consumer own」。本 section 列明 signal trigger contract，downstream visual / audio responsibility 屬下游 GDD scope。

### Signal-Driven Visual Contract (downstream ownership)

| Ability System Signal | Visual Owner | Expected Visual Treatment | Audio Owner |
|----------------------|--------------|---------------------------|-------------|
| `ability_unlocked(ability_id, PR_BREAKTHROUGH, _)` | **#20 Gym-Mode HUD** + **#22 Character Screen** | 「真實 PR → 新 ability icon 出現 HUD」moment — HUD 新 icon fade-in + short glow (~300ms per Pillar 2 frictionless 限制)；particles via #5 `STATUS_BUFF` preset (or new `ABILITY_UNLOCK_BURST` preset future addition) | **#4 Audio Manager** (Pre-MVP) — short ability unlock chime (350-500ms tail)，distinct from PR confirmation chime + loot fanfare |
| `ability_unlocked(ability_id, STAT_THRESHOLD, _)` | **#20 HUD** | Subtle icon fade-in — STAT_THRESHOLD 累積觸發唔應 over-emphasize per Pillar 2 (mid-set glance budget)；optional micro-particle via #5 `STATUS_*` preset family；OR pure-icon update (no VFX) — art-director final call at #20 GDD authoring | **#4** — silent or very subtle "tick" SFX (~50ms tail) |
| `ability_cast(ability_id, caster, target, damage)` | **#26 Avatar Renderer** | Per-ability cast animation (e.g., STRIKE_TIER_3_OVERHAND triggers heavy-punch anim)；ability-specific particle burst from #5 (e.g., `HIT_HEAVY` for TIER_3 STRIKE) | **#4** — per-ability SFX (cast sound vary by class + tier)；TIER_3 abilities **MAY duck** to background music briefly |
| `ability_cooldown_started(ability_id, duration)` | **#20 HUD** | Cooldown bar visual start — radial sweep / linear bar reaches 0 over `duration` seconds；ability icon dimmed during cooldown | NONE direct — visual only |
| `ability_cooldown_ended(ability_id)` | **#20 HUD** | Cooldown bar clears；ability icon brightens；optional subtle "ready" glint (per #20 design) | **#4** — optional very-subtle "ready" tick (~30ms)，可被 Pillar 2 settings disabled |
| `ability_mutation_rejected(ability_id, source, reason)` | NONE direct — telemetry only | No visual surface | NONE |
| `ability_cast_rejected(ability_id, reason)` | NONE direct — telemetry only | No visual surface (combat tick simply selects another ability per #13 scheduler) | NONE |
| `ability_unlock_save_failed(ability_id)` | **#24 Login / GymSys Connection UI** (banner) + **#28 Telemetry** | Persistent warning banner「Ability unlock 未儲存 — 嘗試 retry」(per Pillar 1 anti-lie posture — never silently degrade)；UX defer to #24 GDD | **#4** — soft error tone OR silent (UX call) |

### Cross-System Visual Coordination

- **#5 Particle System Wrapper**: 若 ability_unlocked 要 particle burst，#20 HUD caller 用 `ParticleSystemWrapper.play(PresetId.STATUS_BUFF, position, multiplier=1.2)`；future addition `ABILITY_UNLOCK_BURST` preset 可由 art-director 喺 #5 GDD 加入
- **#6 Screen Effects System**: Ability-related events **唔 trigger** screen shake / hit pause from Ability System layer；但 #13 CombatResolver 收 `ability_cast` 之後可能根據 damage magnitude trigger #6 — 屬 #13 scope
- **#7 Camera System**: Ability cast **唔 trigger** Focal state — Focal 係 combat / loot ritual scope；ability unlock (especially STAT_THRESHOLD micro-tick) 應該 frictionless 唔搶 camera attention。**Exception**: TIER_3 ability unlock 可能 future considered for Focal moment treatment (gated to #29 Mirror Moment整合，唔屬 MVP scope)

### Asset Spec Status

**Ability System 自身 owns no assets** — 純 data layer。Downstream consumer (#20 HUD / #22 Character Screen / #26 Avatar Renderer) 各自 author Visual/Audio section + run `/asset-spec` for own assets (ability icons / cast animations / class-tier color theme)。本 GDD 唔需要 trigger Asset Spec workflow。

## UI Requirements

**Ability System owns NO direct UI** — 純 autoload data layer，玩家從未直接「打開」Ability System。所有 player-facing display 由下游 own：

| UI Concern | Owner GDD | Pattern |
|------------|-----------|---------|
| Real-time ability slot display (icons + cooldown bars) | #20 Gym-Mode HUD | `connect_for_initial_state` to `ability_unlocked` + `ability_cooldown_started` + `ability_cooldown_ended`；HUD redraw per signal |
| Detailed ability list + lock state | #22 Character Screen | Read-on-open via `get_unlocked_abilities()` + subscribe `ability_unlocked` for live update |
| Ability tree visualization (v0.2) | #30 Skill Tree System | Subscribe `ability_unlocked` + reads `get_unlocked_abilities()` to render tree state |
| Storage error banner | #24 Login / Connection UI | Subscribe `ability_unlock_save_failed` |

**API contract for UI consumers** (binding on downstream GDDs):
1. **MUST use `connect_for_initial_state` helper** for `ability_unlocked` / `ability_cooldown_started` / `ability_cooldown_ended` subscriptions (per ADR-006 Contract 6 + AC-14)
2. **MUST call `get_unlocked_abilities()` / `get_ability_state(id)` for read-on-open scenarios** — NEVER access internal `_unlocked_abilities` Dictionary
3. **MUST handle `ability_unlocked` with `is_initial=true` idempotently** — subscriber 可能 receive initial-state delivery AND subsequent mutation for same ability_id in quick succession (Reconciling substate exit per Rule 11)
4. **MUST NOT call mutation API** from UI layer — UI is read-only consumer

## Open Questions

> 7 條 open questions — split into resolved-by-future-GDD (Q-X*) + ADR-ratification-blocked (Q-A*)。

### Cross-System Open Questions (resolve via downstream GDD)

- **Q-X1 — STAT_THRESHOLD evaluation cost on every `stat_changed`**
  - **Question**: Rule 7 Path B 喺 every `stat_changed` (including high-frequency VOLUME_TICK fire) trigger `_evaluate_unlock`。Iterate 3 tier × check threshold = O(3) per call = trivial，但 typical workout session 30 sets = 90 stat_changed × 9 ability_id check = 810 ops per session。對 Pillar 2 ≤ 0.01ms 應該無影響，但需要 #28 Telemetry instrument first sprint。
  - **Likely resolution**: Implementation story 加 telemetry counter；若 cost confirmed trivial → no action；若 cost issue → optimize via cache `_tier_already_unlocked[class]` short-circuit
  - **Owner**: Implementation sprint task

- **Q-X2 — Cast targeting logic (Ability System vs #13 CombatResolver split)**
  - **Question**: `cast_ability(ability_id, caster, target)` 嘅 `target` 由 #13 提供。但「ability 應該 cast 邊個 target」嘅決策 logic — keep at #13 (combat scheduler) 抑或 move to Ability System (per-ability target_type metadata)?
  - **Likely resolution**: target selection 屬 #13 combat scheduler scope；Ability System 只 own `target_type` metadata (`ENEMY` / `SELF` / `AOE_RADIUS`) + Rule 8 step 5 validation
  - **Owner**: #13 CombatResolver GDD authoring (VS tier order 9)
  - **Ability System impact**: Section C Rule 8 step 5 已 lock 呢個 split — final confirmation 喺 #13 authoring

- **Q-X3 — TIER_2 / TIER_3 ability animations ownership**
  - **Question**: 9 個 ability 各需要 cast animation。MVP scope 用 placeholder anim，v0.2 layered avatar 加 per-ability anim。Animation rig / blend logic 屬 #26 Avatar Renderer scope，但「邊個 ability 對應邊個 anim」mapping ownership 不清。
  - **Likely resolution**: AbilityRegistry.tres 加 `animation_clip_id: StringName` field；#26 Avatar Renderer 內部 own animation ID → animation clip 嘅 mapping
  - **Owner**: #26 Avatar Renderer GDD authoring

- **Q-X4 — `AbilityRegistry.tres` data ownership / authoring**
  - **Question**: Rule 1 spec data-driven `AbilityRegistry.tres`，但本 GDD 唔 spec 邊個 author + maintain。Designer 改 ability metadata 直接改 .tres？定 game-designer + systems-designer 共同 own?
  - **Likely resolution**: systems-designer own AbilityRegistry.tres + balance values；game-designer 提供 display_name + flavor metadata；CI verify .tres 結構 schema
  - **Owner**: Implementation sprint task

### ADR-Ratification Open Questions (blocked on ADR / GDD Accepted)

- **Q-A1 — TIER_THRESHOLDS retune post-#18 PR Detection authoring**
  - **Question**: Formula 1 TIER_THRESHOLDS `{10, 50, 200}` 屬 VS-tier estimation (基於 #11 Stat System 累積 rate)。#18 PR Detection authored 之後，實際 PR breakthrough rate (per ADR-005 cross-validation) 可能 require threshold retune。
  - **Blocked on**: #18 GDD authored (Pre-MVP) + ADR-005 ratified
  - **Resolution path**: #18 + ADR-005 落實 → balance simulation 1000 player sessions → CF-2 anchor verify → adjust TIER_THRESHOLDS if needed
  - **Impact**: Section D Formula 1 + Section G INV-2/INV-3 + worked examples 需 updated

- **Q-A2 — Schema migration for multi-character (v0.2+ scope)**
  - **Question**: Rule 15 single-character MVP scope。v0.2+ #30 Skill Tree 可能引入 multi-character ability sets — schema 由 `ability.unlocked.<id>` → `ability.unlocked.<character_id>.<id>` migration?
  - **Blocked on**: v0.2 multi-character feature scope decision + ADR-006 Contract 10 chain budget (MAX_MIGRATION_CHAIN_LENGTH=6 仲有 slot)
  - **Resolution path**: v0.2 GDD revision → 加 `character_id` parameter → migration step convert legacy `ability.unlocked.*` → `ability.unlocked.default.*` (preserve MVP player progress)

- **Q-A3 — TIER_4 ability addition (v0.2+ skill tree expansion)**
  - **Question**: Rule 2 LOCKED `TIER_1/TIER_2/TIER_3`。v0.2 Skill Tree (#30) 可能加 TIER_4 ("Mastery tier")。Schema bump + GDD Rule 1/2/Formula 1/2 全部需要 update。
  - **Blocked on**: v0.2 scope decision + #30 Skill Tree GDD authoring
  - **Resolution path**: v0.2 GDD revision → 加 TIER_4 enum + TIER_4_THRESHOLD (e.g., 500) + TIER_4_BASE_COOLDOWN_SEC (e.g., 15) → migration step backfill TIER_4 lock state

### Open Questions Summary Table

| Q-ID | Domain | Owner | Status |
|------|--------|-------|--------|
| Q-X1 | STAT_THRESHOLD evaluation cost | Implementation sprint | Defer to instrument |
| Q-X2 | Cast targeting split | #13 CombatResolver GDD | Pending #13 authoring (VS tier order 9) |
| Q-X3 | Ability animation mapping | #26 Avatar Renderer GDD | Pending #26 authoring |
| Q-X4 | AbilityRegistry.tres ownership | Implementation sprint | Defer to implementation |
| Q-A1 | TIER_THRESHOLDS retune | #18 + ADR-005 | Pending #18 authoring + ADR-005 simulation |
| Q-A2 | Multi-character namespace | v0.2 GDD revision | Pending v0.2 scope decision |
| Q-A3 | TIER_4 ability addition | v0.2 GDD revision + #30 authoring | Pending v0.2 scope decision |

## Acceptance Criteria

> **Format**: GIVEN-WHEN-THEN，獨立可測。Test Type ∈ {`unit`, `integration`, `static-analysis`}。Gate Level ∈ {`BLOCKING`, `ADVISORY`, `ADR-RATIFICATION-GATED`}。
>
> **總 AC 數**: 33 (30 BLOCKING + 3 ADR-RATIFICATION-GATED)。
> **Test type 分布**: 18 unit + 4 integration + 11 static-analysis — 全自動化 cover (Core autoload 無 Visual/Feel/UI surface)。

### Core Rules ACs (Section C coverage)

- **AC-01 — Ability ID surface LOCKED to 9 enum constants (Rule 1)**
  - **GIVEN** `class AbilityId` 喺 `src/autoload/ability_system.gd` declared
  - **WHEN** static analysis enumerates all `StringName` constants under `AbilityId`
  - **THEN** count equals exactly 9 AND set equals `{STRIKE_TIER_1_JAB, STRIKE_TIER_2_HOOK, STRIKE_TIER_3_OVERHAND, CONTROL_TIER_1_PARRY, CONTROL_TIER_2_HOOK_PULL, CONTROL_TIER_3_GRAPPLE, MOBILITY_TIER_1_DASH, MOBILITY_TIER_2_LEAP, MOBILITY_TIER_3_GROUND_POUND}`
  - Source: Rule 1 | Test Type: static-analysis | Gate: BLOCKING | Path: `tests/unit/ability_system/test_ability_id_surface.gd`

- **AC-02 — Magic-string ability_id literal banned in src/ (Rule 1)**
  - **GIVEN** `tools/ci/check_ability_id_magic_string.gd` configured
  - **WHEN** lint runs against `src/**/*.gd` excluding `src/autoload/ability_system.gd`
  - **THEN** any string literal matching pattern `(strike|control|mobility)_tier_[1-3]_[a-z_]+` fails build with exit code != 0
  - Source: Rule 1 | Test Type: static-analysis | Gate: BLOCKING | Path: `tests/unit/ci/test_check_ability_id_magic_string.gd`

- **AC-03 — AbilityClass + AbilityTier enum LOCKED (Rule 2)**
  - **GIVEN** `AbilityClass` 同 `AbilityTier` enums declared
  - **WHEN** reflection reads `AbilityClass.values()` 同 `AbilityTier.values()`
  - **THEN** `AbilityClass.values()` returns exactly `[STRIKE, CONTROL, MOBILITY]` AND `AbilityTier.values()` returns exactly `[TIER_1, TIER_2, TIER_3]`
  - Source: Rule 2 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_enums_locked.gd`

- **AC-04 — Closed mutation API rejects direct private field access (Rule 3)**
  - **GIVEN** `tools/ci/check_ability_internal_field_access.gd` configured
  - **WHEN** lint scans `src/**/*.gd` excluding `src/autoload/ability_system.gd` 同 `tests/`
  - **THEN** any pattern `AbilitySystem\._unlocked_abilities\s*[\[\.\=]` fails build
  - Source: Rule 3 | Test Type: static-analysis | Gate: BLOCKING | Path: `tests/unit/ci/test_check_ability_internal_field_access.gd`

- **AC-05 — UnlockSource enum exactly 3 values with INITIAL_STATE sentinel (Rule 4)**
  - **GIVEN** `UnlockSource` enum declared
  - **WHEN** `UnlockSource.values()` enumerated
  - **THEN** result equals exactly `[PR_BREAKTHROUGH, STAT_THRESHOLD, INITIAL_STATE]` AND `unlock_ability(STRIKE_TIER_1_JAB, UnlockSource.INITIAL_STATE)` returns `false` + emits `ability_mutation_rejected(STRIKE_TIER_1_JAB, INITIAL_STATE, "sentinel_misuse")` (reason code per Rule 16 enum — R-1 fix: "sentinel_misuse" added to Rule 16 reason list)
  - Source: Rule 4 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_unlock_source_enum.gd`

- **AC-06 — CastResult enum exactly 6 outcomes (Rule 5)**
  - **GIVEN** `CastResult` enum declared
  - **WHEN** `CastResult.values()` enumerated
  - **THEN** result equals exactly `[SUCCESS, NOT_UNLOCKED, ON_COOLDOWN, STAT_INSUFFICIENT, INVALID_TARGET, GSM_REJECT]` (6 entries) AND `cast_ability` return type annotation is `CastResult`
  - Source: Rule 5 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_cast_result_enum.gd`

- **AC-07 — Source-to-class allow-list rejects cross-class unlock (Rule 6 + EC-09)**
  - **GIVEN** AbilitySystem initialized, GSM Ready
  - **WHEN** `unlock_ability(CONTROL_TIER_1_PARRY, PR_BREAKTHROUGH)` invoked with stat_id=STR
  - **THEN** return `false`，`_unlocked_abilities` 不含 `CONTROL_TIER_1_PARRY`，`ability_mutation_rejected(CONTROL_TIER_1_PARRY, PR_BREAKTHROUGH, "source_class_mismatch")` emit exactly once
  - Source: Rule 6, EC-09 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_source_class_allowlist.gd`

- **AC-08 — Caller whitelist CI lint for unlock_ability (Rule 3 + Rule 6)**
  - **GIVEN** `tools/ci/check_ability_unlock_callers.gd` configured with whitelist `[src/autoload/ability_system.gd]` only (signal subscription pattern — #18 emits signal, not direct call; #11 stat_changed also subscribed internally)
  - **WHEN** lint scans `src/**/*.gd` for `AbilitySystem.unlock_ability(`
  - **THEN** any call site outside `src/autoload/ability_system.gd` fails build with caller path reported；if `src/feature/pr_detection.gd` calls `unlock_ability` directly — build fail (must use signal emission instead)
  - Source: Rule 3, Rule 6, Rule 7 | Test Type: static-analysis | Gate: BLOCKING | Path: `tests/unit/ci/test_check_ability_unlock_callers.gd`

- **AC-09 — Caller whitelist CI lint for cast_ability (Rule 3 + Rule 6)**
  - **GIVEN** `tools/ci/check_ability_cast_callers.gd` configured with whitelist `[src/autoload/combat_resolver.gd]`
  - **WHEN** lint scans `src/**/*.gd` for `AbilitySystem.cast_ability(`
  - **THEN** any call site outside whitelist fails build
  - Source: Rule 3, Rule 6 | Test Type: static-analysis | Gate: BLOCKING | Path: `tests/unit/ci/test_check_ability_cast_callers.gd`

- **AC-10 — Unlock evaluation Path A (PR_BREAKTHROUGH) — Rule 7 + Rule 13**
  - **GIVEN** STR=210，STRIKE_TIER_1 already unlocked，STRIKE_TIER_2 + STRIKE_TIER_3 locked
  - **WHEN** `unlock_ability(STRIKE_TIER_3_OVERHAND, PR_BREAKTHROUGH)` invoked
  - **THEN** return `true`，`_unlocked_abilities` 含 `STRIKE_TIER_3_OVERHAND`，`ability_unlocked(STRIKE_TIER_3_OVERHAND, PR_BREAKTHROUGH)` emit exactly once，PersistenceLayer key `ability.unlocked.strike_tier_3_overhand` write 喺 signal emit 之前 (Rule 13 ordering)
  - Source: Rule 7, Rule 13 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_unlock_path_a_pr_breakthrough.gd`

- **AC-11 — Unlock evaluation Path B (STAT_THRESHOLD multi-tier ascent) — Rule 7 + EC-13 + F3**
  - **GIVEN** AbilitySystem initialized，no abilities unlocked，STR=9
  - **WHEN** `stat_changed(STR, 9, 52, STAT_THRESHOLD)` delivered from #11
  - **THEN** Rule 7 Path B iterates TIER_1 → TIER_2 → TIER_3，`STRIKE_TIER_1_JAB` + `STRIKE_TIER_2_HOOK` unlocked，`STRIKE_TIER_3_OVERHAND` NOT unlocked (52 < 200)，signals emit per Formula 3 order (TIER_1 before TIER_2)
  - Source: Rule 7, EC-13, F3 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_unlock_path_b_multi_tier.gd`

- **AC-12 — Cast evaluation atomic sequence (Rule 8)**
  - **GIVEN** STRIKE_TIER_1_JAB unlocked，cooldown 0，STR=100，GSM `CombatActive`，valid live target
  - **WHEN** `cast_ability(STRIKE_TIER_1_JAB, caster, target)` invoked
  - **THEN** return `CastResult.SUCCESS`，`_cooldown_remaining[STRIKE_TIER_1_JAB] == BASE_COOLDOWN_SEC[TIER_1]`，`ability_cast` emit with `(STRIKE_TIER_1_JAB, caster, target)` exactly once (no `damage` param — damage owned by #13 CombatResolver)，`ability_cooldown_started` emit with duration
  - Source: Rule 8 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_cast_atomic_sequence.gd`

- **AC-13 — Persistence namespace per-source flush policy (Rule 9)**
  - **GIVEN** AbilitySystem 同 mocked PersistenceLayer recording `write(key, value, flush)` calls
  - **WHEN** `unlock_ability(STRIKE_TIER_1_JAB, PR_BREAKTHROUGH)` 同 `unlock_ability(STRIKE_TIER_2_HOOK, STAT_THRESHOLD)` invoked
  - **THEN** PR_BREAKTHROUGH write recorded with key `ability.unlocked.strike_tier_1_jab` + `flush=true`，STAT_THRESHOLD write recorded with `flush=false`
  - Source: Rule 9 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_persistence_flush_policy.gd`

- **AC-14 — Boot reconciliation rebuilds state from PersistenceLayer (Rule 10 + EC-01)**
  - **GIVEN** PersistenceLayer keys preloaded `{ability.unlocked.strike_tier_1_jab, ability.unlocked.control_tier_1_parry}` 同 autoload position 6
  - **WHEN** AbilitySystem `_ready()` completes
  - **THEN** `get_unlocked_abilities()` returns exactly `[STRIKE_TIER_1_JAB, CONTROL_TIER_1_PARRY]` (order per Formula 3)，no `ability_unlocked` signals emit during `_ready()`，substate is `Ready`
  - Source: Rule 10, EC-01 | Test Type: integration | Gate: BLOCKING | Path: `tests/integration/ability_system/test_boot_reconciliation.gd`

- **AC-15 — GSM Suspended gate rejects mutation API (Rule 11 + EC-16)**
  - **GIVEN** AbilitySystem `Ready`，GSM transitions to `Suspended`
  - **WHEN** `unlock_ability(STRIKE_TIER_1_JAB, PR_BREAKTHROUGH)` invoked during Suspended
  - **THEN** return `false`，`_unlocked_abilities` 不變，`ability_mutation_rejected(..., "suspended_substate")` emit，no PersistenceLayer.write call
  - Source: Rule 11, EC-16 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_suspended_gate.gd`

- **AC-16 — Permanent unlock contract (no relock under stat drop) — Rule 12 + Anti-Pillar**
  - **GIVEN** STRIKE_TIER_2_HOOK unlocked at STR=50
  - **WHEN** `stat_changed(STR, 50, 5, EQUIPMENT)` delivered
  - **THEN** `get_unlocked_abilities()` 仍含 `STRIKE_TIER_2_HOOK`，no `ability_relocked` signal exists，no PersistenceLayer.delete for `ability.unlocked.*` keys
  - Source: Rule 12, Anti-Pillar | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_no_relock_on_stat_drop.gd`

- **AC-17 — Atomic unlock write ordering: persist BEFORE mutate BEFORE emit (Rule 13)**
  - **GIVEN** mocked PersistenceLayer that records timestamps on `write` 同 mocked signal listener
  - **WHEN** `unlock_ability(STRIKE_TIER_1_JAB, PR_BREAKTHROUGH)` invoked
  - **THEN** PersistenceLayer.write timestamp T1 < `_unlocked_abilities` mutation T2 < `ability_unlocked` signal T3 (strict ordering)
  - Source: Rule 13 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_atomic_write_ordering.gd`

- **AC-18 — Cooldown tick uses set_process toggle + MAX_FRAME_DELTA clamp (Rule 14 + EC-26)**
  - **GIVEN** AbilitySystem with no abilities on cooldown，`is_processing() == false`
  - **WHEN** `cast_ability(...)` succeeds 同 sets `_cooldown_remaining[STRIKE_TIER_1_JAB] = 3.0`
  - **THEN** `is_processing() == true`，simulated `_process(0.5)` decrements to 2.5，simulated `_process(0.3)` resulting in cooldown ≤ 0 erases entry，`is_processing() == false` after last cooldown clears，`_process(30.0)` clamps delta to MAX_FRAME_DELTA=0.1
  - Source: Rule 14, EC-26 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_cooldown_tick.gd`

- **AC-19 — Single-character scope (Rule 15)**
  - **GIVEN** AbilitySystem public API
  - **WHEN** reflection inspects `unlock_ability` / `cast_ability` / `get_unlocked_abilities` / `get_ability_state` signatures
  - **THEN** no signature contains parameter named `character_id` or `char_id`
  - Source: Rule 15 | Test Type: static-analysis | Gate: BLOCKING | Path: `tests/unit/ability_system/test_single_character_scope.gd`

- **AC-20 — Seven core/telemetry signals declared with typed signatures (Rule 16)**
  - **GIVEN** AbilitySystem signal declarations
  - **WHEN** reflection enumerates signals
  - **THEN** declarations contain exactly 7 signals: `ability_unlocked(ability_id: StringName, source: int)`, `ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)` (no damage — B-1 fix), `ability_cooldown_started(ability_id: StringName, duration: float)`, `ability_cooldown_ended(ability_id: StringName)`, `ability_mutation_rejected(ability_id: StringName, source: int, reason: String)`, `ability_cast_rejected(ability_id: StringName, reason: String)`, `ability_unlock_save_failed(ability_id: StringName)` (R-4 fix: added `ability_cooldown_started` + `ability_cooldown_ended` to verification)
  - Source: Rule 16 | Test Type: static-analysis | Gate: BLOCKING | Path: `tests/unit/ability_system/test_telemetry_signals.gd`

### Formula ACs (Section D coverage)

- **AC-21 — Formula 1 (TIER_THRESHOLDS) boundary values**
  - **GIVEN** `const TIER_THRESHOLDS = {TIER_1: 10, TIER_2: 50, TIER_3: 200}`
  - **WHEN** `_evaluate_unlock(STR, value, STAT_THRESHOLD)` invoked with `value ∈ {9, 10, 49, 50, 199, 200}`
  - **THEN** value=9 unlocks 0 tiers；value=10 unlocks TIER_1 only；value=49 unlocks TIER_1 only；value=50 unlocks TIER_1+TIER_2；value=199 unlocks TIER_1+TIER_2；value=200 unlocks all 3 tiers (inclusive boundary `≥`)
  - Source: Formula 1 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_formula_tier_thresholds.gd`

- **AC-22 — Formula 2 (BASE_COOLDOWN_SEC) lookup correctness**
  - **GIVEN** `const BASE_COOLDOWN_SEC = {TIER_1: 3.0, TIER_2: 6.0, TIER_3: 10.0}`
  - **WHEN** ability cast for each tier succeeds (separate fixtures)
  - **THEN** `_cooldown_remaining[STRIKE_TIER_1_JAB] == 3.0`，`STRIKE_TIER_2_HOOK == 6.0`，`STRIKE_TIER_3_OVERHAND == 10.0` (exact match, no float fuzziness > 1e-6)
  - Source: Formula 2 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_formula_base_cooldown.gd`

- **AC-23 — Formula 3 (UNLOCK_EVENT_PRIORITY) deterministic emit order — EC-01 + EC-12**
  - **GIVEN** AbilitySystem first boot with DEFAULT_BASE_STAT=10 across STR=DEX=VIT=10 delivered same frame
  - **WHEN** all 3 TIER_1 abilities unlock during initial-state delivery
  - **THEN** `ability_unlocked` signals arrive in sorted order: `(TIER_1, STRIKE)` → `(TIER_1, CONTROL)` → `(TIER_1, MOBILITY)` AND repeating test 100 times produces identical order every run (determinism)
  - Source: Formula 3, EC-01, EC-12 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_formula_unlock_event_priority.gd`

### Cross-Knob Invariant ACs (Section G coverage)

- **AC-24 — INV-1 + INV-4 strict monotonic for thresholds 同 cooldowns**
  - **GIVEN** TuningKnobs loaded from `data/balance/ability_system.tres`
  - **WHEN** CI invariant check runs at build time
  - **THEN** `TIER_1_THRESHOLD < TIER_2_THRESHOLD < TIER_3_THRESHOLD` 同 `TIER_1_BASE_COOLDOWN_SEC < TIER_2_BASE_COOLDOWN_SEC < TIER_3_BASE_COOLDOWN_SEC` 同時 hold；violation fails build with offending values reported
  - Source: INV-1, INV-4 | Test Type: static-analysis | Gate: BLOCKING | Path: `tests/unit/balance/test_ability_invariants_monotonic.gd`

- **AC-25 — INV-2 + INV-3 threshold anchor + ceiling**
  - **GIVEN** TuningKnobs loaded，#11 Stat System exposes `DEFAULT_BASE_STAT=10` + `MAX_STAT_VALUE=999`
  - **WHEN** CI invariant check runs
  - **THEN** `TIER_1_THRESHOLD >= 10` (INV-2) AND `TIER_3_THRESHOLD <= floor(999 * 0.25) == 249` (INV-3) 同時 hold；violation fails build
  - Source: INV-2, INV-3 | Test Type: static-analysis | Gate: BLOCKING | Path: `tests/unit/balance/test_ability_invariants_anchor_ceiling.gd`

- **AC-26 — INV-5 + INV-6 + INV-7 cooldown floor + ceiling + ratio**
  - **GIVEN** TuningKnobs loaded
  - **WHEN** CI invariant check runs
  - **THEN** `TIER_1_BASE_COOLDOWN_SEC >= 2.0` (INV-5) AND `TIER_3_BASE_COOLDOWN_SEC <= 15.0` (INV-6) AND `(TIER_3_BASE_COOLDOWN_SEC / TIER_1_BASE_COOLDOWN_SEC) <= 4.0` (INV-7) 同時 hold；violation fails build
  - Source: INV-5, INV-6, INV-7 | Test Type: static-analysis | Gate: BLOCKING | Path: `tests/unit/balance/test_ability_invariants_cooldown_bounds.gd`

- **AC-27 — INV-8 all knobs within declared safe range**
  - **GIVEN** Section G knob table with safe ranges for all 8 owned knobs
  - **WHEN** CI invariant check iterates each knob
  - **THEN** every knob value satisfies `safe_range_min <= value <= safe_range_max`；out-of-range fails build with knob name + value + range reported
  - Source: INV-8 | Test Type: static-analysis | Gate: BLOCKING | Path: `tests/unit/balance/test_ability_invariants_safe_range.gd`

### Critical Edge Case ACs

- **AC-28 — EC-28 re-entrance depth limit (MAX_EMIT_DEPTH guard)**
  - **GIVEN** AbilitySystem `MAX_EMIT_DEPTH=2`，subscriber handler calls `cast_ability` synchronously from within `ability_cooldown_started` listener
  - **WHEN** initial `cast_ability` triggers chain exceeding depth 2
  - **THEN** 3rd-level re-entrant call returns `CastResult.GSM_REJECT` (or equivalent re-entrance reject code)，`ability_mutation_rejected(..., "reentrance_depth_exceeded")` emit，no stack overflow / no infinite recursion (test completes within 1 second)
  - Source: EC-28, Knob `MAX_EMIT_DEPTH` | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_reentrance_depth_limit.gd`

- **AC-29 — EC-06 persistence write failure leaves in-memory state unchanged**
  - **GIVEN** mocked PersistenceLayer.write returns `false`，AbilitySystem in `Ready`，`_unlocked_abilities` empty
  - **WHEN** `unlock_ability(STRIKE_TIER_1_JAB, PR_BREAKTHROUGH)` invoked
  - **THEN** return `false`，`_unlocked_abilities` remains empty (Rule 13 rollback)，`ability_unlock_save_failed(STRIKE_TIER_1_JAB)` emit exactly once，no `ability_unlocked` signal emit
  - Source: EC-06, Rule 13 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_persist_fail_rollback.gd`

- **AC-30 — EC-10 anti-fabrication runtime defense (caller whitelist runtime layer)**
  - **GIVEN** test fixture simulates non-whitelisted caller invoking `unlock_ability` (CI lint bypassed for this defensive test)
  - **WHEN** call executed
  - **THEN** return `false`，`_unlocked_abilities` unchanged，`ability_mutation_rejected(..., "caller_whitelist_violation")` emit，`push_error` logged
  - Source: EC-10, Rule 6 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/ability_system/test_caller_whitelist_runtime_defense.gd`

### ADR-RATIFICATION-GATED ACs (Section B Fantasy Risk Register)

> **重要**: 以下 3 條 AC **gated on #10 + ADR-002 + ADR-003 ratified**。VS-tier ship 之前可用 mock test scaffolding；MVP gate 要求 real ADR 落實 + AC 全部 pass。

- **AC-31 — FR-1 class_id enum LOCKED to {STRIKE, CONTROL, MOBILITY}**
  - **GIVEN** #10 Exercise→Class Mapping GDD ratified (Accepted status) with class enum frozen
  - **WHEN** static analysis compares `AbilityClass.values()` to #10's published `ClassId.values()`
  - **THEN** both equal exactly `[STRIKE, CONTROL, MOBILITY]` AND no `PUSH_PULL_HYBRID` 或其他 hybrid class；mismatch fails build with note "FR-1 binding violation — revisit Section B + Rule 1"
  - Source: FR-1, Rule 1 | Test Type: static-analysis | Gate: ADR-RATIFICATION-GATED (#10 Accepted) | Path: `tests/unit/ability_system/test_fr1_class_enum_locked.gd`

- **AC-32 — FR-2 pr_magnitude server-validated (no client-side fabrication path)**
  - **GIVEN** ADR-002 ratified with server-validated `pr_breakthrough` contract AND #18 PR Detection authored
  - **WHEN** integration test injects fabricated `pr_breakthrough(bench_press, magnitude=0.5)` via client-side path without server attestation token
  - **THEN** #18 rejects emit (signal never reaches AbilitySystem)，AbilitySystem `_unlocked_abilities` unchanged；defensive check at AbilitySystem boundary triggers `is_nan(magnitude) or magnitude < 0` rule (EC-35) AND no unlock attempt logged
  - Source: FR-2, EC-35 | Test Type: integration | Gate: ADR-RATIFICATION-GATED (ADR-002 Accepted + #18 authored) | Path: `tests/integration/ability_system/test_fr2_pr_server_validated.gd`

- **AC-33 — FR-3 ability.unlocked.* namespace permanent (no auto-decay)**
  - **GIVEN** ADR-003 ratified with `ability.unlocked.*` namespace as Tier 1 backend-primary + IndexedDB secondary，STRIKE_TIER_2_HOOK persisted at session start
  - **WHEN** simulated absence of 30 in-game days (no stat_changed, no pr_breakthrough, no playtime) 同 reboot
  - **THEN** Rule 10 boot reconciliation reads `ability.unlocked.strike_tier_2_hook` key，`get_unlocked_abilities()` after boot contains `STRIKE_TIER_2_HOOK`，no `ability_relocked` / `ability_decayed` signal exists in codebase (grep proof)，no scheduled task deletes `ability.unlocked.*` keys
  - Source: FR-3, Rule 12, Anti-Pillar | Test Type: integration | Gate: ADR-RATIFICATION-GATED (ADR-003 Accepted) | Path: `tests/integration/ability_system/test_fr3_namespace_permanent.gd`

### Coverage Map

| Source | AC IDs |
|--------|--------|
| Rule 1 (LOCKED slot surface) | AC-01, AC-02 |
| Rule 2 (AbilityClass + AbilityTier enums) | AC-03 |
| Rule 3 (Closed mutation API) | AC-04, AC-08, AC-09 |
| Rule 4 (UnlockSource enum + INITIAL_STATE sentinel) | AC-05 |
| Rule 5 (CastResult enum) | AC-06 |
| Rule 6 (Source→class allow-list + caller whitelist) | AC-07, AC-08, AC-09, AC-30 |
| Rule 7 (Unlock evaluation Path A + B) | AC-10, AC-11 |
| Rule 8 (Cast atomic sequence) | AC-12 |
| Rule 9 (Persistence + flush policy) | AC-13 |
| Rule 10 (Boot reconciliation) | AC-14 |
| Rule 11 (GSM Suspended gate) | AC-15 |
| Rule 12 (Permanent unlock / no relock) | AC-16, AC-33 |
| Rule 13 (Atomic write ordering) | AC-17, AC-29 |
| Rule 14 (Cooldown `_process` tick) | AC-18 |
| Rule 15 (Single-character scope) | AC-19 |
| Rule 16 (Telemetry signals) | AC-20 |
| Formula 1 (TIER_THRESHOLDS) | AC-21 |
| Formula 2 (BASE_COOLDOWN_SEC) | AC-22 |
| Formula 3 (UNLOCK_EVENT_PRIORITY) | AC-23, AC-11 |
| INV-1 + INV-4 (monotonic) | AC-24 |
| INV-2 + INV-3 (anchor + ceiling) | AC-25 |
| INV-5 + INV-6 + INV-7 (cooldown bounds + ratio) | AC-26 |
| INV-8 (safe range) | AC-27 |
| EC-01 (first boot) | AC-14, AC-23 |
| EC-06 (persist fail) | AC-29 |
| EC-09 (source/class mismatch) | AC-07 |
| EC-10 (caller whitelist violation) | AC-30 |
| EC-13 (multi-tier ascent) | AC-11 |
| EC-16 (Suspended substate) | AC-15 |
| EC-26 (bfcache delta clamp) | AC-18 |
| EC-28 (re-entrance depth) | AC-28 |
| EC-35 (anomalous pr_magnitude) | AC-32 |
| FR-1 (class enum lock) | AC-31 |
| FR-2 (pr server-validated) | AC-32 |
| FR-3 (namespace permanent) | AC-33 |

## Open Questions

[To be designed]
