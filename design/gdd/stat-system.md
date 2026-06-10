# Stat System

> **Status**: In Design
> **Author**: Frank + systems-designer (Section D) + qa-lead (Section H)
> **Last Updated**: 2026-05-27
> **Implements Pillar**: Pillar 1 (Real Body, Real Power — anti-fabrication data layer) + Pillar 4 (Muscle = Class — class-tagged stat surface)
> **System #**: 11 (Core / VS tier, design order 7)
> **Depends On**: #3 PersistenceLayer (Approved)
> **Depended On By**: #12 Ability System, #13 CombatResolver, #17 Equipment & Inventory, #20 Gym-Mode HUD, #22 Character Screen, #26 Avatar Renderer (6 downstream — highest cascade risk per systems-index High-Risk table)
> **Governing ADRs**: ADR-006 State Machine Contract (Proposed) — Contract 3 (SerializableResource envelope), Contract 4 (autoload sequential boot); ADR-003 Save State Strategy (Proposed) — IPersistence interface, `user://state.json` namespace `stat.*`

## Overview

Stat System 係 Mirror Hero 嘅 **character data layer** — Core 層 autoload，boot 喺 #3 PersistenceLayer (autoload position 1) 之後，向 6 個 downstream consumer (#12 Ability / #13 CombatResolver / #17 Equipment / #20 HUD / #22 Character Screen / #26 Avatar Renderer — Core tier cascade risk highest per systems-index) 提供 canonical stat values + observer-pattern mutation broadcast。系統有雙重 framing：**data 層面**係 sync read API (`get_stat(stat_id) -> StatValue`) + permanent stat 經 ADR-003 `stat.*` namespace + ADR-006 Contract 3 SerializableResource envelope 持久化 + `stat_changed(stat_id, old, new, source)` signal 喺每次 mutation 後即 fire，下游 consumer 通過 `connect_for_initial_state(callable)` helper (ADR-006 Contract 6) 訂閱，禁止 poll；**player-facing 層面**係玩家做完一組 deadlift 嘅第 47 rep 觸發 PR breakthrough → 同一 frame fire `stat_changed(STR, 12.0, 13.0, PR_BREAKTHROUGH)` → #20 HUD 即時 update + 短暫 glow + #26 Avatar 下 frame 用新 attack_power 計傷害 — 即「真實 PR → in-game stat → visible power」嘅 Pillar 1 物質 substrate。MVP scope locked：**3 個 base stat** (STR / DEX / VIT — 對應 Pillar 4 push / pull / leg 三大肌群) + **4 個 derived stat** (max_hp / attack_power / move_speed / crit_chance)；mutation only via `StatSource` enum (`PR_BREAKTHROUGH` / `VOLUME_TICK` / `EQUIPMENT` / `DEBUG_OVERRIDE`)，任何其他 path 觸發 `push_error` + reject — Pillar 1 anti-fabrication hard guarantee，對應 PersistenceLayer 「存咗就係存咗」+ GymSys Client「Backend 唔識講大話」嘅 Foundation tier 「呢個系統唔會講大話畀你聽」voice 喺 Core tier 嘅延伸。系統屬 systems-index High-Risk row #11 mitigation 嘅「data-only with observer pattern」architecture — 唔 own combat math (#13)、equipment merge logic (#17)、UI display (#20/22)、avatar render (#26)，只 own canonical stat values + mutation contracts。Governing ADRs: ADR-003 (Save State Strategy — `stat.*` namespace + `user://state.json` Tier 2 persistence) + ADR-006 Contracts 3 / 4 / 6 (SerializableResource envelope + autoload sequential boot + `connect_for_initial_state` sentinel subscription)；ADR-005 (Loot Rarity Formula — Proposed) 屬 downstream consumer (loot may carry `StatSource.EQUIPMENT` modifier)，本 GDD 為 ADR-005 嘅 input scope。

## Player Fantasy

**Direct fantasy — 「真實 PR → 數字升 → 角色變強」嘅瞬間連繫**:
玩家做完 deadlift 第 47 rep、咬牙頂住 30 秒之後 PR breakthrough → 同一 frame，眼角瞄到 #20 HUD 入面 STR 由 12 變 13，數字短暫 glow 一下；下次抽空打開 #22 Character Screen 對比上週數據 — 「上週 STR 10，今週 13，月底見到 16」嗰個「我喺 gym 真做嘅嘢，喺 game 留低咗刻度」嘅 dopamine。**Stat System 本身唔 fire VFX / 音效** — visible glow + 數字 update 由下游 #20 HUD / #22 Character Screen 通過 `stat_changed` signal 訂閱後 own，但 source-of-truth 嘅數字 升 = 全 game 跟住升。

**Indirect fantasy — 「stat 升咗，攻擊變更大力」嘅戰鬥節奏轉變** (透過 #13 CombatResolver / #26 Avatar Renderer):
同一個 enemy 上週要 3 槳擊倒，今週 2 槳擊倒；particle burst 多咗一層；boss HP bar 倒退速度肉眼可見快咗。Stat 嘅 sync `get_stat(ATTACK_POWER)` 喺 #13 combat tick 期間 read，下 frame combat math 用新 value → 玩家「冇做特別嘢」但 game 整體節奏跟住升 — 呢個係 Pillar 1「真實能力 → in-game 能力」最 visceral 嘅 transduction 路徑。

**Anti-lie architectural posture (cross-system fantasy thread)**:
玩家心入面 implicit 嘅 promise — 「Mirror Hero 入面冇 cheat code、冇 RNG 突然升 STR、冇 click 30 分鐘解鎖 'I am Strong' 嘅 button。每一點 stat 升都對應一次真實 set；每一次 PR 突破都喺 disk 留底；任何試圖繞過呢個 contract 嘅 path 直接 `push_error` reject。」

呢條 posture 同 PersistenceLayer「存咗就係存咗」+ GymSys Client「Backend 唔識講大話」組成 **Pillar 1 anti-fabrication trio** — 三條 architectural posture 各 own 一條 Pillar 1 防線：

| # | System | Anti-lie surface |
|---|--------|-------------------|
| #2 | GymSys Backend Client | **Backend signal 唔講大話** — workout signal source-of-truth 嚟自 server-authoritative GymSys，client 唔可以 fabricate `workout_completed` |
| #3 | PersistenceLayer | **Storage 唔講大話** — `write()` 返 `true` 必對應 cache mutation + 即將 disk persist；失敗即 `critical_save_failed` 大聲講 |
| **#11** | **Stat System (本 GDD)** | **Stat 唔講大話** — 只有 `StatSource` enum 認可嘅 mutation path 可改變 stat；任何其他 code path 觸發 `push_error` reject |

三者組成 Pillar 1「Real Body, Real Power」嘅完整 vertical anti-fabrication architecture — Foundation tier 兩條 (signal + storage) + Core tier 一條 (data layer，本 GDD)。

**Falsifiable design tests** — 任何 client-side path 引致以下情境 = bug，唔係 acceptable behavior：

1. **Pillar 1 cardio gate**: 玩家做一小時 cardio (跑步機 / 單車) → `Time.get_unix_time_from_system()` 過咗一小時但 STR / DEX / VIT 任何一個 升 = ❌ (Pillar 1 violation — non-resistance training 不可餵 stat；#18 PR Detection 只 emit resistance-training PR event)
2. **Anti-fabrication gate**: 玩家用 DevTools 喺 console 寫 `StatSystem.set("str", 999)` 或 `StatSystem._base["str"] = 999` → ❌ (push_error reject — 唯一允許 path 係 `apply_stat_delta(stat_id, source: StatSource, delta: float)` + 認可 `StatSource`；private field 直接 mutation 喺 release build 經 CI lint catch)
3. **Pillar 4 class gate**: 玩家 push-day workout 完成 (只練臥推) → DEX 或 VIT 升 = ❌ (Pillar 4 class-aware — push 只影響 STR；class routing logic 喺 #10 Exercise→Class Mapping own，本 GDD 只 enforce StatSource 對應 stat_id 嘅 allowed_targets)
4. **Persistence round-trip gate**: 玩家做 PR set 之後 reload page → reload 後嘅 STR ≠ reload 前 = ❌ (ADR-006 Contract 3 SerializableResource envelope round-trip 失敗 — `to_dict()` / `from_dict()` 必須對稱)
5. **DEBUG_OVERRIDE release gate**: Release build 入面 `apply_stat_delta(STR, StatSource.DEBUG_OVERRIDE, 100)` call 仍可成功 = ❌ (compile-time export-template strip 失敗 — 違反 FR-3)

呢個 fantasy 直接 enables：
- **Pillar 1 (Real Body, Real Power) primary** — stat 嘅 mutation contract 係 anti-fabrication 嘅最後一塊；缺呢層，Foundation 兩條 trio member (#2 + #3) 守住 signal + storage 但 stat 仍可 in-process fabricate → Pillar 1 leak
- **Pillar 4 (Muscle = Class) supporting** — base stat 分 STR / DEX / VIT 三類，對應 push / pull / leg；唔同肌群訓練透過 #10 Exercise→Class Mapping routing 至 stat-tagged delta，唔可以 cross-class fertilize
- **Pillar 5 (Mirror Moment) precondition only** — Mirror Moment 每週可見 evolution 依賴 stat 跨週 unbroken；本 GDD 提供呢個 unbroken-ness 嘅 substrate，唔 own Mirror Moment fantasy 本身

### Fantasy Risk Register

呢個 anti-lie architectural posture framing 係 contingent on 以下 invariants 喺 **ADR-003 + ADR-005** ratification 真正 enforced；否則 Player Fantasy paragraph 變 retroactive lie。

| # | Contingent Invariant | Owner | Fallback if Dropped |
|---|---------------------|-------|---------------------|
| FR-1 | `StatSource` enum 係 exhaustive — `PR_BREAKTHROUGH` / `VOLUME_TICK` / `EQUIPMENT` / `DEBUG_OVERRIDE` 四個，唔可以增加 `LOOT_RANDOM` / `LEVEL_UP_BONUS` / `STREAK_BONUS` 等 RNG-based or time-based source | 本 GDD Rule 4 + ADR-005 ratification | 若 ADR-005 引入 RNG-based stat boost 而 stat 唔走 `EQUIPMENT` source → Pillar 1 anti-fabrication framing 破 — fallback = ADR-005 必須走 `EQUIPMENT` modifier path，由 #17 Equipment own，唔可以直接 fire `apply_stat_delta` 入 Stat System |
| FR-2 | `EQUIPMENT` source 嘅 stat delta 必須 derived from 真實 PR-anchored loot rarity (per ADR-005 Pillar 1 hard guarantee — real-PR-signal weight ≥ 0.7) | ADR-005 ratification | 若 loot rarity 走純 RNG path 而 equipment 之後加 stat → 變相 RNG 餵 stat → Pillar 1 violation；fallback = revisit Section B framing 為「stat 加 source-trace 但唔 enforce Pillar 1」 |
| FR-3 | `DEBUG_OVERRIDE` 喺 release build 完全 disabled — `OS.is_debug_build()` runtime guard + export-template strip + CI lint `tools/ci/check_debug_override_calls.gd` 三層防 | 本 GDD Rule 10 + CI lint | 若 release build 仍可調 `DEBUG_OVERRIDE` → cheat 可能 → Pillar 1 hard violation；fallback = blocking story to remove `DEBUG_OVERRIDE` enum value 之前 ship 任何 release |

**Ratification gate binding**: 本 GDD 嘅 Section C / H 必須 include FR-1 / FR-2 / FR-3 對應嘅 rules + ACs (gated on ADR-003 Accepted + ADR-005 Accepted)。若 ADR-005 ratification 後 FR-1 / FR-2 任一 invariant 改變 → revisit Player Fantasy paragraph + Risk Register with corresponding fallback framing。

## Detailed Design

### Core Rules

1. **Rule 1 — LOCKED Stat surface (MVP scope)** — Stat System 暴露 **3 個 base stat + 4 個 derived stat**：
   - **Base stats (persisted)**: `STR` (push 力量) / `DEX` (pull 敏捷) / `VIT` (leg 體質)
   - **Derived stats (computed on-read, NOT persisted)**: `MAX_HP` / `ATTACK_POWER` / `MOVE_SPEED` / `CRIT_CHANCE`
   - Stat IDs 係 `StringName` constants 喺 `class StatId`，禁止 magic string；caller 必須用 `StatId.STR`，唔可以用 `"str"` literal — CI lint `tools/ci/check_stat_id_magic_string.gd` 喺 release build fail
   - Stat surface **LOCKED** for MVP — 加新 stat = schema version bump (Rule 8 migration chain)，唔係 tuning
   - Derived stat formula owned by Section D；本 Rule 只 lock 列表

2. **Rule 2 — Closed mutation API (anti-lie hard guarantee, Pillar 1)** — Stat mutation 只有一個 entry point：
   ```gdscript
   func apply_stat_delta(stat_id: StringName, source: StatSource, delta: float) -> bool
   ```
   任何其他 mutation path (直接 field write `_base["str"] = 99`、reflection-style `set()` invoke、外部 inject via `JavaScriptBridge.eval`、Resource swap-in) 均違反 Pillar 1 anti-fabrication。Enforcement 三層防：
   - **Runtime guard**: `_base: Dictionary[StringName, float]` 標 `var _base` (private convention) — Godot 4.6 唔強制 access modifier，但 CI lint `tools/ci/check_stat_internal_field_access.gd` 喺 `src/` 內任何 `StatSystem._base[` 或 `StatSystem._equipment_modifiers[` 出現 (除 `src/autoload/stat_system.gd` 自身) 即 fail build
   - **Closed API**: 全部 mutation 經 `apply_stat_delta` 一個 chokepoint，方便 audit + telemetry
   - **CI caller whitelist** (paired with Rule 4): only specific 系統 (#9 / #17 / #18) 可 call mutation API；CI lint `tools/ci/check_stat_mutation_callers.gd` enforce caller file path whitelist

3. **Rule 3 — `StatSource` enum (5 values, 4 mutation + 1 sentinel)** — 完整列表：
   - `PR_BREAKTHROUGH` — 真實 PR (1RM) breakthrough，由 #18 PR Detection emit；delta 由 ADR-005 Pillar 1 公式計算；critical persistence (Rule 7 `flush=true`)
   - `VOLUME_TICK` — 每組 (set) 完成 嘅 micro-delta，由 #9 Workout State Tracker (routed via #10 Exercise→Class Mapping) emit；delta 小 (≤ 0.05 / set typical)；debounced persistence (Rule 7 `flush=false`)
   - `EQUIPMENT` — 裝備穿脫嘅 modifier (transient，唔 persist 入 stat.*)；由 #17 Equipment & Inventory call；走 modifier dictionary (Rule 5) 而非直接改 `_base`
   - `DEBUG_OVERRIDE` — Editor / debug build only；release build 經 Rule 10 三層防 strip
   - `INITIAL_STATE` (**internal sentinel only**) — ADR-006 Contract 6 `connect_for_initial_state` callv 路徑專用；mutation API 收到呢個 source 即 push_error reject (sentinel 唔係 mutation path，由 subscriber callable 路徑 internal use)

   **FR-1 binding (Section B)**: 4 個 mutation source LOCKED — 唔可以加 `LOOT_RANDOM` / `LEVEL_UP_BONUS` / `STREAK_BONUS` 等 RNG-based 或 time-based source。Loot 或 Streak 影響 stat 必須走 `EQUIPMENT` (transient modifier，由 #17 own) 路徑，唔可以直接 fire `apply_stat_delta`。

4. **Rule 4 — Source → stat_id allow-list (Pillar 1 + Pillar 4 cross-enforcement)** — 每個 `StatSource` 有 explicit allowed-target set；mismatch 即 push_error reject：

   | StatSource | Allowed stat_ids | Why |
   |------------|------------------|-----|
   | `PR_BREAKTHROUGH` | `STR`, `DEX`, `VIT` (base only) | Pillar 1 — PR 只影響 base；derived auto-recompute |
   | `VOLUME_TICK` | `STR`, `DEX`, `VIT` (base only) | Pillar 4 — class routing via #10 已 enforce push→STR / pull→DEX / leg→VIT |
   | `EQUIPMENT` | All 7 (3 base + 4 derived) | Equipment 可 buff base 或直接 buff derived |
   | `DEBUG_OVERRIDE` | All 7 | Debug 需要無限制 |
   | `INITIAL_STATE` | **None — mutation reject** | Sentinel only |

   **Caller whitelist** (paired with allow-list):
   - `PR_BREAKTHROUGH`: caller MUST 喺 `src/feature/pr_detection.gd` (係 #18 嘅 GDD-locked path)
   - `VOLUME_TICK`: caller MUST 喺 `src/core/workout_state_tracker.gd` (#9)
   - `EQUIPMENT`: caller MUST 喺 `src/feature/equipment_inventory.gd` (#17) — 經 `apply_equipment_modifier` (Rule 5)，唔直接 call `apply_stat_delta`
   - `DEBUG_OVERRIDE`: caller MUST 喺 `tests/` 或 editor-only paths
   - CI lint `tools/ci/check_stat_mutation_callers.gd` enforce

5. **Rule 5 — Equipment modifier layer (transient, NOT persisted)** — Equipment-induced stat change 唔走 `_base` 直接改寫，走 modifier table。API：
   ```gdscript
   func apply_equipment_modifier(equipment_id: StringName, modifier: StatModifier) -> void
   func remove_equipment_modifier(equipment_id: StringName) -> void
   class StatModifier extends RefCounted:
       var deltas: Dictionary  # { stat_id: StringName -> delta: float }
   ```
   行為：
   - `_equipment_modifiers: Dictionary[StringName, StatModifier]` 內部 storage；key = equipment_id (per #17 spec)
   - **NOT persisted by Stat System** — Stat System boot 時 modifier table 為 empty；#17 Equipment Inventory 喺自己 boot 完成後 replay 所有穿著裝備嘅 `apply_equipment_modifier` call (sequential，per Contract 4)
   - Modifier 影響 derived-stat 計算 (Section D Formula)；唔影響 `_base` value
   - `apply_equipment_modifier` / `remove_equipment_modifier` 各 emit `stat_changed` for affected stat_ids (source = `EQUIPMENT`, `is_equipment_change: true` 透過 signal 第 5 個 param)
   - 同一個 `equipment_id` 重複 apply → overwrite (idempotent)；remove unknown id → no-op (silent OK)

6. **Rule 6 — Observer pattern broadcast (ADR-006 Contract 6 inheritance)** — Stat System 嘅 sole broadcast signal：
   ```gdscript
   signal stat_changed(
       stat_id: StringName,
       old_value: float,
       new_value: float,
       source: StatSource,
       is_initial: bool   # true only via connect_for_initial_state callv path
   )
   ```
   Emit timing (Rule 13 atomic write sequence)：
   - **After** successful persistence flush (Rule 7) — 防 phantom-state defense (per GSM /design-review lesson — emit 前必有 disk persist confirm)
   - **Before** consumer 嘅 next-frame read — sync emit AFTER `_base[stat_id] = new_value` mutation
   - Derived stat change → emit `stat_changed` for EACH affected derived stat 由 `_recompute_derived_for(base_stat_id)` 觸發

   **Subscriber pattern** (ADR-006 Contract 6 binding)：
   - Subscribers MUST 用 `connect_for_initial_state(callable)` helper — 唔可以 plain `.connect()`
   - Helper 內部：(a) 立即 callv subscriber callable，逐個 stat_id deliver current value (using `INITIAL_STATE` sentinel + `is_initial=true`)；(b) 之後 `.connect()` to signal for 後續 mutation
   - Callable signature MUST 對應 signal 5-param shape；禁止 `.bind()` extras (per Contract 6)

   **Sentinel detection** (analogous to GSM `payload.source_event == 'initial_state'`)：subscriber 可用 `if source == StatSource.INITIAL_STATE` 區分 boot delivery vs fresh mutation。Both 路徑 deliver 同一 stat_id + new_value，subscriber 通常一致處理 (e.g. HUD 一律 redraw)。

7. **Rule 7 — Persistence contract (ADR-003 `stat.*` namespace + ADR-006 Contract 3)** — Base stat 經 PersistenceLayer 持久化：
   - **Storage keys**: `stat.str` / `stat.dex` / `stat.vit` (3 keys total)
   - **Write path**: `apply_stat_delta` 內部 call `PersistenceLayer.write(key, new_value, flush)`，**flush 決策**：
     - `PR_BREAKTHROUGH` → `flush = true` (critical — anti-fabrication anchor moment 必 disk persist 即時)
     - `VOLUME_TICK` → `flush = false` (debounced 100ms — 一組做完即更新 cache + signal，disk flush 跟 PersistenceLayer 嘅 debounce timer)
     - `EQUIPMENT` → **NO persistence call** (Rule 5 modifier 唔 persist)
     - `DEBUG_OVERRIDE` → `flush = true` (debug 期望即時 visible)
   - **Read path**: 只喺 `_ready()` 內一次 sync read，後續所有 `get_stat` 從 in-memory `_base` O(1) read
   - **Envelope**: Base stat value 係 primitive `float`，唔需要 SerializableResource envelope；直接 `Variant` round-trip 經 JSON
   - **Schema version**: PersistenceLayer-owned `_internal.schema_version` 之外，Stat System NOT own schema version 自己 — schema bump 經 PersistenceLayer migration chain (Contract 10)

8. **Rule 8 — Boot reconciliation (autoload sequential boot, ADR-006 Contract 4)** — Stat System autoload position 5 (after Persistence pos 1 + GSM pos 2 + PlatformDetect pos 3 + GymSys pos 4; F-SETUP-1 sync 2026-05-28 — PlatformDetect inserted at pos 3 per ADR-001 shifts downstream by 1)：
   - `_ready()` sync sequence (NO `await`):
     1. Sync read `PersistenceLayer.read("stat.str")` / `stat.dex` / `stat.vit`
     2. 每個 key absent → 用 default (Rule 11)
     3. 全部 valid float → populate `_base`
     4. 任何 read 返回非 float (e.g. corrupt path 後 PersistenceLayer 返 `{}` empty) → fallback to defaults + `push_warning("Stat boot fallback to defaults")`
     5. Subscribe GSM `state_changed` via `connect_for_initial_state` helper (Rule 14 Suspended gate)
   - `_ready()` 完成後 substate = `Ready`
   - **No `stat_changed` emit during `_ready()`** — subscribers 仲未 connect；emit 喺 subscriber 之後通過 `connect_for_initial_state` 嘅 callv 一次性 deliver

9. **Rule 9 — VOLUME_TICK batching (Pillar 2 protection — disk write reduction)** — 每組 lift 完成 fire 一個 VOLUME_TICK (e.g. +0.03 STR / push set)；若每組都 `flush=true` 會做 1 IDB write / set。Pillar 2 (Frictionless Companion) 反對 mid-set 任何可能 perceptible 嘅 lag/freeze (per Section B EC-12 PersistenceLayer Lessons)：
   - VOLUME_TICK 走 `flush=false` (PersistenceLayer 100ms debounce timer)
   - In-memory `_base[stat_id]` 即時 mutate + emit `stat_changed`
   - `_pending_volume_deltas: Dictionary[StringName, float]` NOT needed — PersistenceLayer's own cache + dirty-flag 已 batch；Stat System 唔需要 double-batch
   - 結果：玩家做 5 組 push → 5 個 stat_changed signal (即時 HUD update) → 100ms 內 1 個 disk flush (即時 anti-lie 守住，performance 守住)

10. **Rule 10 — `DEBUG_OVERRIDE` release-strip (FR-3 Pillar 1 hard guarantee)** — Triple defense：
    - **Runtime guard** in `apply_stat_delta` body：
      ```gdscript
      if source == StatSource.DEBUG_OVERRIDE and not OS.is_debug_build():
          push_error("DEBUG_OVERRIDE blocked in release build")
          return false
      ```
    - **CI lint** `tools/ci/check_debug_override_calls.gd`：grep `StatSource.DEBUG_OVERRIDE` literal 喺 `src/` (排除 `tests/` + editor-only paths) 任何出現 → fail build for release branch (`main` + `release/*`)
    - **Export config**: Godot 4.6 export preset 用 `OS.has_feature("editor")` runtime guard；release export 自動 strip editor-only code blocks (per technical-preferences.md)
    - **Test coverage**: AC-? (Section H) verify release build call `apply_stat_delta(STR, DEBUG_OVERRIDE, 100)` 返 `false` + push_error fires + stat 不變

11. **Rule 11 — Stat ranges + clamping + default values** — 所有 stat 有 hard range：
    - **Base stat range**: `[0, MAX_STAT_VALUE]` where `MAX_STAT_VALUE = 999` (knob — Section G)
    - **Derived stat range**: 由 Section D formula 決定；通常 `[0, derived_cap]`
    - **Default base stat value at first-boot**: STR = 10.0, DEX = 10.0, VIT = 10.0 (匹配 "starting from zero baseline" 嘅 Pillar 1 grind 感)
    - **Clamping behavior**: `apply_stat_delta` 計出 `target = _base[stat_id] + delta`，clamp 到 `[0, MAX_STAT_VALUE]`，若 clamp 觸發 → emit `stat_clamped(stat_id, attempted_value, clamped_value)` telemetry signal (Rule 16) — 但 `apply_stat_delta` 仍 return `true` (clamp 唔係 error)
    - **Underflow handling**: target < 0 → clamp 到 0；唔可以 negative (Pillar 1 anti-decay — 見 Rule 12)

12. **Rule 12 — No stat decay (Anti-pillar enforcement)** — Game-concept Anti-Pillar 第 3 條：「NOT Permadeath / weekly reset / progress 懲罰；缺日只係 delay bonus，唔可以拎走玩家已得嘅嘢」。本 GDD enforcement：
    - `apply_stat_delta(stat_id, source, delta)` where:
      - `delta < 0` AND
      - `stat_id in [STR, DEX, VIT]` (base only) AND
      - `source != DEBUG_OVERRIDE`
    - → push_error + reject + return false
    - **唯一 exception**: `EQUIPMENT` source removing equipment 可導致 derived stat 下跌 (e.g. 脫劍 → ATTACK_POWER 跌)，但 base stat 不變；Rule 5 modifier 路徑 enforce
    - **唯一其他 base 下跌路徑**: `DEBUG_OVERRIDE` (debug only, Rule 10 release strip)
    - CI lint `tools/ci/check_stat_decay_callers.gd` 喺 `src/` (排除 `tests/`) 任何 `apply_stat_delta(... , source, delta)` where source 唔係 `DEBUG_OVERRIDE` 且 caller side 可 statically prove `delta < 0` literal → fail build (best-effort，handles literal-negative case)

13. **Rule 13 — Atomic stat write sequence (persistence-first ordering)** — `apply_stat_delta` body steps：
    1. **Validate** — Rule 3 source enum valid，Rule 4 source-stat allow-list pass，Rule 10 DEBUG_OVERRIDE release gate，Rule 12 no-decay gate；fail any → push_error + return false
    2. **Compute target** — `target = clamp(_base[stat_id] + delta, 0, MAX_STAT_VALUE)`
    3. **Snapshot old** — `old_value = _base[stat_id]`
    4. **Persist FIRST (if base stat)** — `var persist_ok = PersistenceLayer.write("stat." + str(stat_id).to_lower(), target, flush_for_source(source))`; if not `persist_ok` → emit `stat_critical_save_failed(stat_id)` + push_error + return false (in-memory unchanged)
    5. **Mutate in-memory** — `_base[stat_id] = target` (AFTER persist confirm)
    6. **Emit base signal** — `emit_signal("stat_changed", stat_id, old_value, target, source, false)`
    7. **Recompute derived** — for each derived stat depending on this base, recompute + emit secondary `stat_changed` (source 一律 `EQUIPMENT` 抑或 inherit caller source？選 **inherit** — i.e., PR_BREAKTHROUGH 嘅 derived update signal source 仍係 PR_BREAKTHROUGH，方便 telemetry / UI distinguish)
    8. **Telemetry** — if clamp 觸發 step 2 → emit `stat_clamped`
    
    **Ordering rationale** (per /design-review lessons from #1 GSM Pass 2 + #3 PersistenceLayer Pass 2):
    - Persist BEFORE in-memory mutate → 如果 disk write 失敗，cache 唔會出現「new value 但 disk 仲係 old」phantom state
    - Emit AFTER in-memory mutate → subscriber 訪問 `get_stat(stat_id)` 喺 handler 內必 read 到 new value
    - 整個 sequence 屬 sync flow (no `await`) — single-frame execution per Pillar 2 protection

14. **Rule 14 — GSM Suspended gate (Pillar 2 + ADR-006 Contract 6)** — Stat System 訂閱 GSM `state_changed` 經 `connect_for_initial_state`：
    - GSM state = `Suspended` (per #1 Decision #4 — multi-device session lock force-boot 期間) → Stat System 進入 `Suspended` substate (見 States table)
    - Suspended substate 內 `apply_stat_delta` 嘅所有 mutation 路徑 reject (push_warning + return false)
    - Reason: Suspended 代表 stale device 已被 backend 拒絕；任何 stat mutation 都係 stale state，唔可以 commit
    - `get_stat` 喺 Suspended 仍正常 — 讀 cache OK (read 唔修改 state)
    - GSM transitions out of Suspended (resume) → Stat System Suspended → Ready transition：重新 read PersistenceLayer (因 Suspended 期間 backend reconciliation 可能改變 stored value) + emit `stat_changed` for any delta vs pre-Suspended snapshot

15. **Rule 15 — Single-character scope (MVP)** — Stat System 係 single-instance autoload, single-character。Per game-concept MVP scope — no party / multi-character / class spec 變體。v0.2+ 可能擴展到 multi-character (skill tree variants per #30) — 屆時本 GDD revise + schema bump (新增 `stat.<character_id>.<stat_id>` namespace structure)。MVP scope assumption：**冇 character switching mid-session**；玩家識嘅「角色」就係佢嘅 stat block，1-to-1。

16. **Rule 16 — Telemetry signal surface (anti-lie posture)** — Stat System emit 4 個 telemetry/diagnostic signal (separate from `stat_changed` core broadcast):
    - `stat_clamped(stat_id, attempted_value, clamped_value)` — Rule 11 clamp 觸發
    - `stat_critical_save_failed(stat_id)` — Rule 13 step 4 persistence write 返 false
    - `stat_mutation_rejected(stat_id, source, delta, reason)` — Rule 2/3/4/12 任何 reject 路徑；`reason` ∈ {`"invalid_stat_id"` (EC-07 unknown stat), `"invalid_source"` (EC-08 invalid enum value), `"source_stat_mismatch"` (EC-09 allow-list), `"debug_override_release_blocked"` (Rule 10), `"base_stat_decay_blocked"` (Rule 12), `"suspended_substate"` (Rule 14)}
    - `boot_completed()` — Rule 8 `_ready()` 完成 (subscriber 用嚟知 stat 已 ready for `connect_for_initial_state`)
    - **`is_boot_completed() -> bool`(#17 G-2 additive 2026-06-06)** — sync getter,同 signal 等價嘅 pull 形式。**Rationale**:Contract 4 sequential boot 下,position 較後嘅 autoload(如 #17 InventorySystem)`_ready()` 時 `boot_completed` 已 fire — `await` signal = permanent hang;後 boot 嘅 system 一律用此 getter assert,唔 await signal

    **Owner split with PersistenceLayer Rule 11** (Foundation `write_completed` / `critical_save_failed` 等)：Stat System NEVER emit raw `critical_save_failed` — 收到 PersistenceLayer signal filter `key startswith "stat."` 然後 emit 自己嘅 `stat_critical_save_failed(stat_id)`。Reason: domain layer 加 stat_id semantic，consumer 收到 telemetry 即可定位 affected stat 而唔需要 reverse-parse key string。

### States and Transitions

Stat System 唔係 gameplay-stateful system，但 boot + GSM-coupled lifecycle 有 4 個 internal substates：

| Substate | Entry | API behaviour | Exit |
|----------|-------|---------------|------|
| **Initialising** | `_enter_tree()` start | All API rejects — autoload position 5 invariant means 應該冇 caller hit API (PersistenceLayer / GSM / PlatformDetect / GymSys 必須先 ready) | `_ready()` 完成 sync read + GSM subscription → Ready |
| **Ready** | Normal operation | All API functional per Rules 2-16 | Receive GSM `state_changed(_, "suspended", _)` → Suspended |
| **Suspended** | GSM Suspended state (per Rule 14) | `get_stat` OK；mutation API reject with `stat_mutation_rejected` reason `"suspended_substate"`；equipment modifier add/remove 同樣 reject (因 mutation can't persist while session可能 stale) | GSM `state_changed(_, "<any-non-suspended>", _)` → Reconciling |
| **Reconciling** | Suspended exit | Brief substate (single frame) — sync re-read PersistenceLayer for 3 base keys + emit `stat_changed` for any delta vs pre-Suspended snapshot；mutation API still reject during this micro-window | Read complete → Ready |

**Why Suspended explicit**: GSM Suspended 代表 backend reconciliation 期間，client state 可能 stale (per #1 Decision #4 single-device session lock — backend may have overwritten state via other device)。Stat System 喺呢個 window 接受 mutation 等於同意 commit stale data → Pillar 1 anti-fabrication violation。Reject + log telemetry 係正確 anti-lie response。

**Why Reconciling 1-frame buffer**: GSM 轉 Suspended → Ready 嘅 frame，PersistenceLayer 可能已 update 但 Stat System 嘅 `_base` cache 仲係 pre-Suspended snapshot；Reconciling 強制 re-read + emit delta，避免下個 `get_stat` 返 stale。

### Interactions with Other Systems

| Consumer | Direction | API used | Key ownership | Notes |
|----------|-----------|----------|---------------|-------|
| **#3 PersistenceLayer** | reads + writes | `read("stat.*")` at boot；`write("stat.<base>", value, flush)` per Rule 7 flush policy；listens `critical_save_failed` filter `key startswith "stat."` | 3 base keys (`stat.str` / `stat.dex` / `stat.vit`) | Stat System owns `stat.*` namespace (per Rule 12 convention in PersistenceLayer) |
| **#1 GameStateMachine** | listens | Subscribe `state_changed` via `connect_for_initial_state` (Contract 6) for Suspended gate (Rule 14) | None | Stat System NEVER writes to GSM state — read-only consumer |
| **#9 Workout State Tracker** | calls mutation API | `apply_stat_delta(stat_id, StatSource.VOLUME_TICK, +0.03)` per set completion；stat_id 由 #10 routing 提供 | None | #9 caller whitelist enforced via Rule 4 CI lint |
| **#10 Exercise → Class Mapping** | (none direct) | Returns class enum / stat_id for #9 + #18 to route | None | #10 functions purely as router — never call mutation API itself |
| **#18 PR Detection & Avatar Progression** | calls mutation API | `apply_stat_delta(stat_id, StatSource.PR_BREAKTHROUGH, delta)` on PR detection；delta 由 ADR-005 公式計算 (gated) | None | Pre-MVP system — VS-tier 提供 mock/provisional path；ADR-005 ratification gate 解鎖真實 delta logic |
| **#17 Equipment & Inventory** | calls modifier API | `apply_equipment_modifier(equipment_id, StatModifier)` / `remove_equipment_modifier(equipment_id)` per equip/unequip | None — modifier dict 屬 #17 lifecycle (Stat System rebuilds each boot from #17's replay) | NEVER call `apply_stat_delta` 直接；must go through modifier API (Rule 5) |
| **#12 Ability System** | listens + reads | `connect_for_initial_state` to `stat_changed`；reads via `get_stat(stat_id)` on ability slot recomputation | None | Hot read path during ability resolve |
| **#13 CombatResolver** | reads | `get_stat(ATTACK_POWER)` / `get_stat(CRIT_CHANCE)` 等 per combat tick；NO signal subscription (read-on-demand) | None | Pure-function combat math 唔需要 cache stat — read each tick；O(1) get_stat 保證 hot path 唔 bottleneck |
| **#20 Gym-Mode HUD** | listens | `connect_for_initial_state` to `stat_changed`；HUD redraw per signal payload | None | Pillar 2 Frictionless — HUD update 必 ≤1 frame 內 reflect mutation |
| **#22 Character Screen** | listens + reads on open | `connect_for_initial_state` for live update；`get_stat` on screen open for static initial render | None | Player-facing comparison view (上週 vs 今週 stat) — screen 自身 own historical snapshot via #28 Telemetry data |
| **#26 Avatar Renderer** | listens | Subscribe `stat_changed` to derive render-only class posture (Formula 1) + evolution tier (Formula 2) from STR/DEX/VIT — render-only per ADR-0010 (weekly ceremony belongs to #29 Mirror Moment) | None | v0.2 layered character system 會深化呢個 dependency；MVP placeholder SpriteFrames |
| **#28 Telemetry / Analytics** | listens | Subscribe all 4 telemetry signals (`stat_clamped` / `stat_critical_save_failed` / `stat_mutation_rejected` / `boot_completed`)；forward to GymSys backend | None | `stat_mutation_rejected` 係 anti-fabrication telemetry — release build 內 fires = 可能有 cheat 嘗試或 implementation bug |

**Interaction invariants**:
- **Single mutation API chokepoint**: 所有 `_base` mutation 經 `apply_stat_delta`；所有 modifier mutation 經 `apply_equipment_modifier` / `remove_equipment_modifier`。No exceptions (Rule 2 closed API)
- **Read API is O(1) + side-effect-free**: `get_stat(stat_id)` 純 read，唔 fire signal，唔 mutate state；hot path (#13 combat tick) 可安全頻繁 call
- **`get_attack_power_excluding_equipment() -> float`(#17 G-2 additive API 2026-06-06)**: 回傳 `ATK_BASE + STR×ATK_PER_STR + DEX×ATK_PER_DEX`,**內部用 `_base` dict 計,唔經 modifier table** — #17 AntiSnowball clamp(FR-Equipment-AntiSnowball)需要「去裝備 ATK」做 cap 基準。O(1) + side-effect-free,同 `get_stat` 同級 read API。**Single source of truth**:#17 唔准 inline 重抄 formula(knob drift 溫床)— 必須經此 API。注:#17 D8 derived-keys-only 下 STR/DEX 永無 equipment 污染,`_base` 直計即可,無 decomposition 需要
- **Subscribers MUST use Contract 6 helper**: 任何 plain `.connect("stat_changed", cb)` (without `connect_for_initial_state`) 會 miss boot-time initial value，subscriber 第一個 stat_changed 收到 only 第一次 mutation 之後 — bug-prone。CI lint `tools/ci/check_stat_changed_connect.gd` enforce
- **No fan-out logic in Stat System**: Stat System emit generic `stat_changed`；唔知 consumer 係邊個；consumer 自行 connect + filter by stat_id
- **Equipment modifier table rebuilt each boot**: Stat System boot 完 modifier table empty；#17 boot 完成後 replay 所有 equipped items — 即係 boot 期間有 single-frame window 內 derived stat 未計 equipment buff，但 subscriber 通過 `connect_for_initial_state` 喺 #17 replay 完成後先收到 initial value，所以 visible inconsistency 唔會出現 (per ADR-006 Contract 4 sequential boot 保證)

## Formulas

本 section 6 條 formula 全部 **pure function**、O(1) compute、無 allocation，符合 Rule 14 (derived stat compute on-read) 同 Pillar 2 (frictionless < 0.01ms per call budget for CombatResolver hot path)。設計核心：**base stat 線性貢獻 + equipment additive modifier**，避免 multiplicative stacking 引致 snowball；diminishing returns 只喺 PR delta 同 CRIT cap 度出現。

### Formula 1: VOLUME_TICK delta (每組訓練微量加成)

**Rationale**: 對應 Pillar 1 (Real Body, Real Power) + Pillar 4 (Muscle = Class)。每完成一組真實 set，喺對應 stat 度加細小但穩定 delta，俾玩家「持續訓練 = 持續成長」嘅 feedback loop。Delta 故意細 — 大 jump 留俾 PR_BREAKTHROUGH，避免 volume farming exploit。Class routing 由 `class_id` 決定流向邊個 stat，符合 Pillar 4 push/pull/leg → STR/DEX/VIT hard mapping。

`volume_tick_delta = VOLUME_TICK_BASE × class_weight(class_id, target_stat)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `VOLUME_TICK_BASE` | b_v | float | [0.01, 0.5] | 每組基礎 delta 值 (tuning knob) |
| `class_id` | c | enum | {PUSH, PULL, LEG} | 完成嗰組所屬類別 (來自 #10) |
| `target_stat` | s | enum | {STR, DEX, VIT} | 接收 delta 嘅 base stat |
| `class_weight(c, s)` | w | float | {0.0, 1.0} | Class routing matrix lookup (pure 1.0 / 0.0，無 cross-routing) |
| `volume_tick_delta` | δ_v | float | [0.0, VOLUME_TICK_BASE] | 加落 base stat 嘅最終 delta |

**Class Routing Matrix (hard mapping)**:

| class_id \\ target_stat | STR | DEX | VIT |
|------------------------|-----|-----|-----|
| PUSH | 1.0 | 0.0 | 0.0 |
| PULL | 0.0 | 1.0 | 0.0 |
| LEG  | 0.0 | 0.0 | 1.0 |

**Output Range**: `[0.0, 0.05]` per call (at default VOLUME_TICK_BASE=0.05；knob safe range 上限 0.20 對應最大 delta 0.20 per call)；typical session (30 sets 等量分佈) VOLUME_TICK 累積 `~0.5` per stat (10 sets × 0.05 = 0.5)。配合 PR_BREAKTHROUGH 合計約 `~1.5–2.0` per stat per session (early game 假設 2–3 PRs per session，每次 delta ≈ 0.3–0.5)；持續訓練下大約 1–2 年 hardcore 玩家可撞 MAX_STAT_VALUE=999（Pillar 1 grind 長度設計合理）。

**Cross-knob invariants**: 無 cross-routing — 唔可以將 push set delta 加落 DEX。將來想加 hybrid class (e.g. deadlift = STR+VIT) 要喺 routing matrix 改值同時更新呢條 invariant。

**Worked Example**:
玩家完成一組 bench press (PUSH)：
- STR: `δ_v = 0.05 × 1.0 = 0.05` → STR 10.0 → 10.05
- DEX: `δ_v = 0.05 × 0.0 = 0.0` → DEX 不變
- VIT: `δ_v = 0.05 × 0.0 = 0.0` → VIT 不變

### Formula 2: PR_BREAKTHROUGH delta (VS provisional — gated on ADR-005)

**Rationale**: 對應 Pillar 1 核心 — 真實 1RM 突破必須俾玩家「我變強咗」嘅 meaningful jump。同時為咗反 snowball，當 stat 已經高 (接近 MAX_STAT_VALUE) 時 delta 要 diminishing return — stat 30 玩家破 PR 加 6 點，stat 800 玩家破同樣 PR 可能只加 1.5 點。**呢條 formula 明確標記為 VS-tier mock**，ADR-005 落實 Loot Rarity Formula 後反向錨定真實 PR magnitude。**Section B FR-2 binding** — 任何 RNG-based stat boost path 都唔可以走呢個 source；本 formula 只接受 #18 PR Detection 提供嘅 server-validated `pr_magnitude` 作 input。

`pr_delta = PR_BASE × pr_magnitude × diminishing_factor(current_stat)`

`diminishing_factor(s) = 1.0 - (s / MAX_STAT_VALUE) ^ PR_DIMINISH_EXP`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `PR_BASE` | b_p | float | [1.0, 20.0] | PR delta scale factor (tuning knob) |
| `pr_magnitude` | m | float | [0.0, 2.0] | 突破幅度 `(new_1RM - old_1RM) / old_1RM`，clamped at 2.0 (200% jump 視為 anomaly) |
| `current_stat` | s | float | [0.0, 999.0] | 當前 base stat (未加 equipment) |
| `MAX_STAT_VALUE` | M | int | 999 (const) | Rule 11 stat cap |
| `PR_DIMINISH_EXP` | k_p | float | [1.0, 4.0] | Diminishing curve 指數 (tuning knob) |
| `diminishing_factor` | f | float | [0.0, 1.0] | 高 stat 時 PR delta scale down 倍率 |
| `pr_delta` | δ_p | float | [0.0, PR_BASE × 2.0] | 最終加落 stat 嘅值 |

**Output Range**: typical PR (`m=0.05`，即 5% 1RM breakthrough at stat=10)：`δ_p ≈ 6.0 × 0.05 × 0.999 ≈ 0.30`。新手快速進步 (`m=0.20`)：`δ_p ≈ 6.0 × 0.20 × 0.999 ≈ 1.20`。理論最大：`PR_BASE × 2.0 × 1.0 = 12.0`。

**Cross-knob invariants**:
- `PR_BASE × 2.0 < 50.0` — 單次 PR 唔可以將 base stat 推上 5% MAX_STAT_VALUE 以上 (避免單次破紀錄就直接封頂)
- 當 `current_stat = MAX_STAT_VALUE` 時 `diminishing_factor = 0` → `δ_p = 0` — hard cap mathematical guarantee
- **ADR-005 ratification gate**: `PR_BASE` 同 loot rarity weight 要 cross-validate — 大 PR 既要俾 stat boost 又要 trigger 高 rarity drop；ADR-005 ratification 後 retune

**Worked Example**:
新手 bench press 1RM 60kg → 65kg (`m = 5/60 ≈ 0.0833`)，STR=12.0：
- `diminishing_factor = 1.0 - (12.0/999.0)^2.0 ≈ 0.9999`
- `pr_delta = 6.0 × 0.0833 × 0.9999 ≈ 0.500` → STR 12.0 → 12.5

對比後期 STR=800 玩家做同等 5kg PR (但 1RM 已 200kg → `m = 0.025`)：
- `diminishing_factor = 1.0 - (800/999)^2.0 ≈ 0.359`
- `pr_delta = 6.0 × 0.025 × 0.359 ≈ 0.054` → STR 800.0 → 800.05 (明顯收緊)

### Formula 3: MAX_HP (生存基線)

**Rationale**: MAX_HP 由 VIT 線性驅動，俾 leg-day 玩家清晰戰鬥意義 — 練腿 = 更耐打。Equipment modifier 用 additive 而非 multiplicative，避免 +HP% 裝堆疊滾雪球。Compute cheap (純加法乘法)，符合 Pillar 2 frictionless 要求。

`MAX_HP = HP_BASE + (VIT × HP_PER_VIT) + equipment_hp_mod`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `HP_BASE` | b_h | int | [50, 200] | 零 VIT 時最低 HP (防 1HP 死亡) (knob) |
| `VIT` | v | float | [0.0, 999.0] | 當前 VIT base stat |
| `HP_PER_VIT` | k_h | float | [3.0, 15.0] | 每 1 VIT 換幾多 HP (knob) |
| `equipment_hp_mod` | e_h | int | [-200, +500] | Equipment 加總 HP modifier (additive) |
| `MAX_HP` | H | int | [1, ~10000] | 最終 HP cap (`max(1, H)` clamping) |

**Output Range**: 預設下 `[80, ~8072]`，clamped at minimum 1 (防 negative HP from negative equipment mod)。

**Cross-knob invariants**:
- `HP_BASE + 10 × HP_PER_VIT ≥ 150` — 默認 stat=10 時新手起碼有 150 HP 抵幾下小怪
- `MAX_HP` 計完之後 `max(1, MAX_HP)` 防 negative

**Worked Example**:
- 新手 (VIT=10，無裝): `MAX_HP = 80 + (10 × 8.0) + 0 = 160`
- 中期 (VIT=150，+50 HP 護甲): `MAX_HP = 80 + (150 × 8.0) + 50 = 1330`
- 後期 (VIT=800，+200 HP 神裝): `MAX_HP = 80 + (800 × 8.0) + 200 = 6680`

### Formula 4: ATTACK_POWER (主傷害輸出)

**Rationale**: STR 主導，DEX 細幅貢獻，符合 Section C Rule 1 「STR dominates, DEX minor」spec。Design 上 push-day 玩家係主 DPS，但 pull-day 玩家都有貢獻 (DEX scaling)，避免 single-stat 暴政。Equipment modifier additive，同 MAX_HP 一致。

`ATTACK_POWER = ATK_BASE + (STR × ATK_PER_STR) + (DEX × ATK_PER_DEX) + equipment_atk_mod`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `ATK_BASE` | b_a | int | [5, 30] | 零 stat 時最低攻擊 (knob) |
| `STR` | r | float | [0.0, 999.0] | 當前 STR |
| `ATK_PER_STR` | k_s | float | [0.5, 3.0] | STR scaling (knob) |
| `DEX` | d | float | [0.0, 999.0] | 當前 DEX |
| `ATK_PER_DEX` | k_d | float | [0.1, 0.8] | DEX scaling (knob; 必須 < ATK_PER_STR × 0.5) |
| `equipment_atk_mod` | e_a | int | [-50, +300] | Equipment 加總攻擊 modifier |
| `ATTACK_POWER` | A | int | [1, ~4500] | 最終攻擊力 (`max(1, A)` clamping) |

**Output Range**: 預設下 `[10, ~4500]`，clamped at 1。

**Cross-knob invariants**:
- `ATK_PER_DEX < ATK_PER_STR × 0.5` — 強制 DEX 對攻擊嘅貢獻細過 STR 一半，鎖住 design intent (Rule 1 「STR dominates」)
- `ATK_BASE + 10 × ATK_PER_STR + 10 × ATK_PER_DEX ≥ 25` — 新手默認攻擊力起碼夠打 3-4 下殺一個 starter mob

**Worked Example**:
- 新手 (STR=10, DEX=10，無裝): `ATK = 10 + 15 + 3 + 0 = 28`
- Push specialist (STR=200, DEX=50，+30 武器): `ATK = 10 + 300 + 15 + 30 = 355`
- Hybrid (STR=300, DEX=200，+50 武器): `ATK = 10 + 450 + 60 + 50 = 570`

### Formula 5: MOVE_SPEED (移動速度)

**Rationale**: DEX 驅動，pull-day 玩家獎勵就係靈活性。用 hard `min` soft cap 防止 DEX 堆到 outrun camera follow → 崩 game feel。Soft cap 用 `min` 而非 exp/log (compute 平 + deterministic)。MOVE_CAP 需要 cross-system align with #7 Camera System follow rate (Cross-knob CF-3 below)。

`MOVE_SPEED = min(MOVE_BASE + (DEX × MOVE_PER_DEX) + equipment_move_mod, MOVE_CAP)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `MOVE_BASE` | b_m | float | [100.0, 250.0] | 零 DEX 基礎速度 (px/s) (knob) |
| `DEX` | d | float | [0.0, 999.0] | 當前 DEX |
| `MOVE_PER_DEX` | k_m | float | [0.1, 1.0] | DEX scaling (knob) |
| `equipment_move_mod` | e_m | float | [-50.0, +100.0] | Equipment additive modifier |
| `MOVE_CAP` | C_m | float | [300.0, 600.0] | 速度硬上限，防 camera 跟唔到 (knob) |
| `MOVE_SPEED` | V | float | [MOVE_BASE × 0.5, MOVE_CAP] | 最終移動速度 (px/s) |

**Output Range**: 預設下 `[90.0, 420.0]` px/s。

**Cross-knob invariants**:
- `MOVE_BASE + (999 × MOVE_PER_DEX) > MOVE_CAP` — 確保 cap reachable (default: 180 + 399.6 = 579.6 > 420 ✓)
- `MOVE_CAP ≤ camera_max_follow_speed` (#7 Camera System) — **cross-system invariant**，需同 #7 Camera GDD POSITION_SMOOTHING_SPEED 對齊；MOVE_CAP/zoom × POSITION_SMOOTHING_SPEED ≥ MOVE_CAP for 1-frame settle guarantee

**Worked Example**:
- 新手 (DEX=10, 無裝): `V = min(184, 420) = 184` px/s
- 中期 (DEX=100, +10 鞋): `V = min(230, 420) = 230` px/s
- 高 DEX (DEX=600, +20 鞋): `V = min(440, 420) = 420` px/s ← cap kicks in

### Formula 6: CRIT_CHANCE (暴擊率，硬 cap)

**Rationale**: DEX 驅動，但暴擊率必須 hard cap 否則戰鬥變 100% crit dice game。線性 + `min` cap 而非 asymptotic curve — (1) compute 更平，(2) 玩家容易理解「我去到 X DEX 就 crit cap」。CRIT cap 係 design lever — 設低 = 暴擊永遠係驚喜，設高 = 暴擊變主流。

`CRIT_CHANCE = min((DEX × CRIT_PER_DEX) + equipment_crit_mod, MAX_CRIT_CHANCE)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `DEX` | d | float | [0.0, 999.0] | 當前 DEX |
| `CRIT_PER_DEX` | k_c | float | [0.0005, 0.005] | 每點 DEX 換幾多 % crit (knob) |
| `equipment_crit_mod` | e_c | float | [0.0, 0.20] | Equipment 加 crit % (additive) |
| `MAX_CRIT_CHANCE` | C_c | float | [0.30, 0.75] | 硬 cap (knob) |
| `DEX_FOR_MAX_CRIT` | d_max | float | derived | `MAX_CRIT_CHANCE / CRIT_PER_DEX = 0.50 / 0.0015 ≈ 333` |
| `CRIT_CHANCE` | P | float | [0.0, MAX_CRIT_CHANCE] | 最終 crit 概率 |

**Output Range**: 預設下 `[0.0, 0.50]` (50% cap)。

**Cross-knob invariants**:
- `DEX_FOR_MAX_CRIT ≤ MAX_STAT_VALUE` — cap 必須 reachable (333 ≤ 999 ✓)
- `DEX_FOR_MAX_CRIT ≥ 100` — 唔可以新手 stat=10 就接近封頂 (333 ≥ 100 ✓)
- Equipment crit 最多總和 0.20 — 防 equipment-only 玩家無練 DEX 都封 crit

**Worked Example**:
- 新手 (DEX=10, 無裝): `P = min(0.015, 0.50) = 0.015` (1.5%)
- 中期 (DEX=150, +5% crit 武器): `P = min(0.275, 0.50) = 0.275` (27.5%)
- DEX-stacked (DEX=400, +10% crit): `P = min(0.70, 0.50) = 0.50` (cap)

### Cross-Formula Invariants

呢 4 條 cross-formula invariants 違反任何一條都應該喺 CI test fail (per Section H tests)：

**CF-1: Default Baseline Symmetry** — STR=DEX=VIT=10、無裝備、所有 default knob：
- `MAX_HP = 160` / `ATTACK_POWER = 28` / `MOVE_SPEED = 184` px/s / `CRIT_CHANCE = 0.015` (1.5%)
- Hard-coded 喺 `tests/unit/stat_system/test_default_baseline.gd`；任何 knob 改動 break baseline 必喺 PR description explicitly call out

**CF-2: Push vs Pull Specialization Parity** — STR=200, DEX=10, VIT=10 (pure push spec) 對 STR=10, DEX=200, VIT=10 (pure pull spec)：兩種專業化都應有 viable build；具體量化交俾 #13 CombatResolver GDD 跟進 (design intent only here)

**CF-3: Stat-only Caps Reachable** — 無 equipment 純練 stat 都可達 derived cap：MOVE_SPEED cap @ DEX≈600 (`(420-180)/0.4 = 600`)，CRIT_CHANCE cap @ DEX≈333。防「必須食裝先封頂」design failure (違反 Pillar 1 — loot 有 RNG)

**CF-4: Equipment Floor** — 所有 derived stat 喺移除所有 equipment (`equipment_mod = 0`) 後值必須 `≥ 1` (HP / ATK) 或 `≥ 0` (CRIT / MOVE)。玩家被脫光裝都唔會數值 broken

### MVP Balance Target Table (First 5-Minute Feel)

| Derived Stat | Default Value (STR=DEX=VIT=10, 無裝) | 設計理由 |
|--------------|---------------------------------------|---------|
| **MAX_HP** | **160** | 新手抵 4-5 下小怪攻擊 (小怪 ATK ≈ 30-40)。<100 = 戰鬥太緊張；>250 = 早期無威脅感、Pillar 1 「real body matters」feedback 出唔到 |
| **ATTACK_POWER** | **28** | 對應小怪 HP ≈ 80-100，3-4 hit kill；action RPG 入門 pacing。<20 = 殺怪慢悶；>50 = 新手太強無進步空間 |
| **MOVE_SPEED** | **184 px/s** | ≈1 tile (32px) / 0.17s；可從容走過 platforming gap 但唔 outrun camera。對比 Hollow Knight ~200 / Celeste ~190，係 2D platformer comfort zone |
| **CRIT_CHANCE** | **1.5%** | 新手主要靠 base damage 殺怪，crit 應該稀有驚喜 (每 60-70 hit 一次)。<0.5% = 5 分鐘可能完全見唔到 crit 機制 invisible；>5% = crit 變預期失驚喜 |

**設計取向**: 新手 5 分鐘體驗應感「我可以打贏，但唔係碾壓」；數值要細到玩家一眼睇晒 (HP 三位數比四位易讀)，後期 progression 留 headroom (160 HP → 6680 HP ≈ 40 倍 growth = RPG genre 合理 ratio)。

### Formulas Owned Elsewhere (Referenced, Not Duplicated)

| Formula | Owner GDD / ADR | Used in this layer |
|---------|-----------------|---------------------|
| `is_expired(anchor_unix, ttl_seconds, anchor_monotonic_ms)` | GDD #3 PersistenceLayer (Formula 1) | Not used directly — Stat System 唔做 time-based stat decay (Rule 12) |
| Loot rarity formula | ADR-005 (Proposed) | Provides input to `EQUIPMENT` source 嘅 `equipment_*_mod` value；Stat System 唔知 rarity，只接收 modifier |
| PR magnitude derivation | #18 PR Detection (not yet authored) + ADR-005 | Provides `pr_magnitude` input to Formula 2；server-validated

## Edge Cases

### Boot / Persistence Edge Cases

- **EC-01 First boot (all `stat.*` keys absent)**: `PersistenceLayer.read("stat.str")` 返 default 值 (`{}` empty) → Rule 8 step 2 fallback → `_base = { STR: 10.0, DEX: 10.0, VIT: 10.0 }` (Rule 11 defaults) → 入 Ready substate → `boot_completed` emit。**唔 emit `stat_changed` during boot** (subscriber 仲未 connect)；subscriber 之後通過 `connect_for_initial_state` 收 initial value。
- **EC-02 PersistenceLayer 返 Corrupt substate (read all returns `{}`)**: Stat System Rule 8 step 4 fallback to defaults + `push_warning("Stat boot fallback to defaults — PersistenceLayer corrupt")`，Ready substate 正常進入。Consumer 收 initial value 等同 first boot — **冇 attempt restore from backend**，呢個係 Stat System scope-out (backend reconciliation 屬 #2 GymSys Client + ADR-003)。Stat System 假設「local stat 損壞 = treat as fresh character」係 ADR-003 acceptable risk tier (per ADR-003 「Tier 1 GymSys = source of truth for non-LootDrop reconciliation」)。
- **EC-03 Partial `stat.*` keys (e.g., `stat.str` 存在但 `stat.dex` 缺失)**: 每個 key 獨立 fallback — present keys 用 persisted value，absent keys 用 default 10.0。`push_warning("stat.<key> absent — defaulting to 10.0")` for each absent key。**唔 corrupt-path** (partial state 唔代表 cache 損壞)。
- **EC-04 Persisted stat value 異常 (NaN / Infinity / 負數 / 超 MAX_STAT_VALUE)**: Rule 8 step 4 防禦：
  - `is_nan(value) or is_inf(value)` → fallback to default 10.0 + `push_error("stat.<key> NaN/Inf — defaulting")` + emit `stat_critical_save_failed(stat_id)`
  - `value < 0` → clamp to 0 + `push_warning("stat.<key> negative — clamped to 0")`
  - `value > MAX_STAT_VALUE` → clamp to MAX_STAT_VALUE + `push_warning("stat.<key> exceeds cap — clamped to %d" % MAX_STAT_VALUE)`
  - Boot continues — 唔阻 game launch
- **EC-05 Schema migration: stat surface 變化 (e.g., v2 加入 LUK)**: 由 PersistenceLayer Contract 10 migration chain own — Stat System 只見 post-migration `_base` Dictionary。本 GDD scope 唔涵蓋 LUK；future schema bump (v2+) revise 本 GDD。
- **EC-06 PersistenceLayer 寫失敗 (Rule 13 step 4 returns false)**: Stat System emit `stat_critical_save_failed(stat_id)` + push_error + return false from `apply_stat_delta` + **in-memory `_base` unchanged**。Caller 必須 handle return false (e.g. #18 PR Detection 已收到 server `pr_magnitude` 但 client persist 失敗 → 下次 boot reconcile 從 backend retry — 走 ADR-003 backend-primary path)。**唔 retry within Stat System**。

### Mutation API Edge Cases

- **EC-07 Unknown stat_id (e.g., `apply_stat_delta("luk", PR_BREAKTHROUGH, 1.0)`)**: Rule 1 stat surface LOCKED — unknown stat_id → push_error + emit `stat_mutation_rejected(stat_id, source, delta, "invalid_stat_id")` + return false。`_base` 不變。注意：reason code 用 `"invalid_stat_id"` 而唔係 `"invalid_source"` (後者保留給 EC-08 invalid enum source)，方便 #28 Telemetry 區分「caller 傳錯 stat ID」vs「caller 傳錯 source enum」。
- **EC-08 Source 唔喺 enum (e.g., int cast to invalid StatSource)**: GDScript runtime check — `if not StatSource.values().has(source): push_error + return false`。Typed enum API 喺 GDScript 4.6 一般 prevent compile-time，但 reflection-style invoke (eg. `Callable` with int arg) 可能繞過 → defensive check needed。
- **EC-09 Source/stat_id mismatch (e.g., `apply_stat_delta(MAX_HP, PR_BREAKTHROUGH, 50.0)`)**: Rule 4 allow-list — `PR_BREAKTHROUGH` only allows {STR, DEX, VIT}，MAX_HP 唔喺 allow-list → push_error + emit `stat_mutation_rejected(MAX_HP, PR_BREAKTHROUGH, 50.0, "source_stat_mismatch")` + return false。
- **EC-10 Delta = 0**: 合法 — 喺 mutation API 內 sequence run 但 `new_value == old_value`，emit `stat_changed` 同樣 fire (consistent contract — subscriber 知道有 "mutation event" 即使 value 不變)。VOLUME_TICK with `class_weight = 0` (e.g., push set on DEX) 走呢個 path — 每組總共 3 個 mutation event (each stat) 但 only 1 real value change。
- **EC-11 Delta = NaN / Infinity**: `is_nan(delta) or is_inf(delta)` → push_error + return false 即係 EC-07 路徑。Defensive — caller 不應該 pass，但 #18 server response parse 出 error 可能產生 NaN。
- **EC-12 Negative delta from VOLUME_TICK or PR_BREAKTHROUGH (anti-decay)**: Rule 12 — VOLUME_TICK / PR_BREAKTHROUGH source + delta < 0 + base stat target → push_error + emit `stat_mutation_rejected(..., "base_stat_decay_blocked")` + return false。**唔 emit `stat_changed`**。Loot 加 negative stat 必須走 `EQUIPMENT` source (via Rule 5 modifier)，唔可以直接 `apply_stat_delta(..., PR_BREAKTHROUGH, -1.0)`。
- **EC-13 PR_BREAKTHROUGH at current_stat = MAX_STAT_VALUE (diminishing_factor = 0)**: Formula 2 — `pr_delta = 0`。`apply_stat_delta` accepts (delta=0 合法 per EC-10)，emit `stat_changed` (value unchanged)。**唔 push_error** — 呢個係 design intent (停止 progression at cap，唔係 error)。
- **EC-14 PR_BREAKTHROUGH at current_stat = 0**: 罕見 (default 10.0；只有 EC-04 clamp 後可能 = 0)。Formula 2 — `diminishing_factor = 1.0 - (0/999)^k = 1.0`，full delta apply → Rule 11 clamp [0, MAX_STAT_VALUE] → `apply_stat_delta` 成功。
- **EC-15 Concurrent PR_BREAKTHROUGH same frame (different stat_ids)**: Sync API — 第二個 call 喺第一個 return 之後 execute。Order = call order。兩個 `stat_changed` emit (sync sequence)。Subscriber handler 喺第一個 emit 內 attempt second `apply_stat_delta` → 進入 EC-22 re-entrance path。
- **EC-16 Same-frame Equipment apply + remove on same equipment_id (e.g., quick swap)**: Order = call order。`apply_equipment_modifier(eq1, modA)` → modifier table 有 eq1；`remove_equipment_modifier(eq1)` → modifier table 唔 eq1。兩個 `stat_changed` (each derived stat affected by modA) emit sync sequence。NO race condition — sync I/O。

### Modifier Layer Edge Cases (Rule 5)

- **EC-17 Same equipment_id apply twice (overwrite)**: Idempotent per Rule 5 — 第二個 apply 覆蓋第一個 StatModifier。`_equipment_modifiers[eq1] = modB` (was modA)。Derived stat recompute + emit(每 affected stat **單次** emit post-replace 值 — 無 remove+apply 兩步嘅 dip window)。**(#17 G-2 pin 2026-06-06)** Same-id re-apply without remove = **supported atomic-replace path** — #17 Rule 8 嘅 aggregate 主更新路徑 by design 重複 re-apply `&"equipment_aggregate"`(loadout 每次變化 re-push 同 id);#11 實作唔可以加 duplicate-apply assert。原「caller bug」警告只適用於 per-item-id 模式下 distinct equipment 嘅意外 double-apply,唔適用 aggregate 模式。
- **EC-18 Remove unknown equipment_id (silent OK)**: `remove_equipment_modifier("unknown_id")` → `_equipment_modifiers.has("unknown_id") == false` → no-op，no emit，return void。Caller (#17) 可能因為 race condition 試 remove 已 removed item — 唔 fail loud (silent OK is safer)。
- **EC-19 Modifier StatModifier `deltas` Dictionary 含 unknown stat_id**: `apply_equipment_modifier(eq1, mod_with_LUK)` → modifier table 接受 (Stat System 唔 validate modifier deltas)，但 derived stat recompute 只 walk known stat_ids → LUK silently ignored。**唔 push_error** (modifier flexibility 允許 future schema extension w/o Stat System change)，但 telemetry 計唔到。**Recommendation**: #17 Equipment GDD CI lint 驗證 StatModifier 內 deltas keys ⊆ known stat_id set。
- **EC-20 Modifier sum exceeds derived stat physical range**: Formula 3/4/5/6 已 clamp at min 1 (HP/ATK) / cap (MOVE/CRIT)。Modifier sum 推 derived 到極端 → clamp 後 `stat_clamped` telemetry fire。**唔 reject modifier** (modifier 自身合法；clamp 屬 derived compute responsibility)。
- **EC-21 Equipment modifier add during Reconciling substate**: Rule 14 Reconciling 內 mutation API reject — `apply_equipment_modifier` 同樣 reject (`stat_mutation_rejected(..., "suspended_substate")` — share reason code for simplicity)。**(#17 G-2 wording fix 2026-06-06 — 原文「wait `boot_completed` signal」喺 Contract 4 下係 trap:#17 `_ready()` 時 signal 已 fire,await = permanent hang)** #17 replay 條件 = `is_boot_completed() == true`(sync getter assert;Contract 4 ordering 本身已保證)**AND** GSM gameplay-ready state(經 `connect_for_initial_state`;Suspended-at-boot → #17 pending-replay flag,Ready 後 deferred 一 frame push + subscribe `stat_mutation_rejected` retry)— 屬 #17 lifecycle responsibility(#17 Rule 14 step 6-7 / EC-14)。

### Substate / Lifecycle Edge Cases

- **EC-22 Subscriber handler re-enter `apply_stat_delta` (same stat_id)**: GDScript signal emit 係 sync — handler runs to completion before emit 返回。Handler 內第二個 `apply_stat_delta(SAME_STAT_ID, ...)` 將 execute fully → 第二個 emit fires → 若 handler 再 fire → unbounded recursion。**Mitigation**: Static analyzer scope — `tools/ci/check_stat_signal_reentrance.gd` flag handlers connected to `stat_changed` 內 call back into `apply_stat_delta` 同一 stat_id (best-effort literal detection)。Runtime: 加 `_emit_depth` counter (similar to ScreenEffects Rule 12)，depth > 0 → push_error + reject。
- **EC-23 GSM rapid Suspended → Ready transitions (e.g., debug)**: Stat System Suspended → Reconciling → Ready 多次。Reconciling substate 每次都 re-read PersistenceLayer — overhead small (3 keys × O(1) read = trivial)。**No degradation**。
- **EC-24 GSM state == Suspended at boot (e.g., crash recovery)**: Rule 8 boot completes (Ready substate)，然後 `connect_for_initial_state` 收 GSM `state_changed(_, "suspended", _)` initial delivery → 立即 Ready → Suspended transition (no Reconciling — Reconciling 只喺 Suspended exit)。Subscriber 收 `boot_completed` 然後立刻知 mutation rejected。
- **EC-25 `_ready()` exception during read**: 極罕 (sync read shouldn't throw)，但 defensive — autoload chain 唔可以 abort game。Rule 8 fallback: any exception → emit `stat_critical_save_failed("BOOT_FAILED")` + populate defaults + enter Ready substate (degraded mode)。

### Boundary / Clamping Edge Cases (Rule 11)

- **EC-26 Stat hits exactly 0**: Equipment removal pushes derived (e.g., MAX_HP) to 0 → Rule 11 clamp `max(1, MAX_HP) = 1`。Combat layer (#13) handles HP=1 vs HP=0 distinction — 唔關 Stat System 事。
- **EC-27 Stat hits exactly MAX_STAT_VALUE**: `_base[stat_id] = 999.0`。後續 `apply_stat_delta(..., +1.0)` → target = 1000 → clamp 999 → emit `stat_clamped(stat_id, 1000, 999)` + `stat_changed` (value unchanged from previous 999)。Pillar 1 sentinel — Mirror Hero MVP scope 假設 1 年內 hardcore 玩家先撞頂；real-life PR plateau 與 game cap 同步 (design intent)。
- **EC-28 Derived stat overflow (e.g., MAX_HP > int32 max)**: 預設 cap 範圍下不可達 (VIT=999, HP_PER_VIT=12 max → MAX_HP ≈ 11990，遠細過 int32)。Defensive — Formula 3 worked example 用 int type；GDScript 4.6 int 係 int64 → 唔 overflow within reasonable knob ranges。

### Subscriber Edge Cases (ADR-006 Contract 6)

- **EC-29 Subscriber uses plain `.connect("stat_changed", cb)` (skips Contract 6 helper)**: Subscriber miss initial-state delivery — 第一個 stat_changed handler 收到 only 第一次 mutation 之後嘅 event (boot 期間 7 stat 唔會 deliver)。**Mitigation**: CI lint `tools/ci/check_stat_changed_connect.gd` grep `\.connect\(.*"stat_changed"` 喺 `src/` (排除 `src/autoload/stat_system.gd` 同 `tests/`) — 任何出現非 `connect_for_initial_state` path → fail build。
- **EC-30 Subscriber callable uses `.bind()` extras**: ADR-006 Contract 6 prohibits — `connect_for_initial_state` callv path 喺 boot 階段 unable to construct callable with bind extras。Helper raise assertion at connect time (debug build) / silent drop with push_error (release)。
- **EC-31 Subscriber callable signature mismatch (e.g., 4 args instead of 5)**: GDScript signal emit 跑時 — callable invocation 引發 runtime error。**Mitigation**: callable signature 強制喺 connect_for_initial_state helper 用 typed Callable + signature validation (best-effort，GDScript reflection limitation acknowledged)。
- **EC-32 Subscriber connected then `Node.queue_free()` (callable invalidated)**: Godot 4.6 自動斷開 dead signal connection。Stat System 唔需要 explicit cleanup。但 `_equipment_modifiers` 入面唔可以存 Node references (Rule 5 spec — modifier deltas only)。

### Cross-System Edge Cases

- **EC-33 MAX_HP change while current HP exists (#13 CombatResolver concern)**: 玩家戴 +50 HP 護甲 → MAX_HP 由 160 → 210。Current HP 由 #13 own — Stat System 唔 dictate「current HP scales with MAX_HP delta」抑或「current HP unchanged」。**Cross-system Open Question** (Q-X1) — defer to #13 CombatResolver GDD (likely answer: current HP 不變，玩家可繼續療傷至新 MAX_HP)。**Stat System spec scope**: 只負 emit `stat_changed(MAX_HP, 160, 210, EQUIPMENT)`；下游 #13 handle。
- **EC-34 ADR-005 ratification after Stat System ships (PR_BREAKTHROUGH retune)**: VS-tier Formula 2 `PR_BASE=6.0` 屬 provisional；ADR-005 ratified 後 `PR_BASE` 可能 retune (e.g., 改 4.0)。**Migration path**: Tuning Knob update 唔需要 schema bump (knob 唔 persist — boot 從 const read)。`stat.str/dex/vit` 值仲係 persisted；只係將來 PR 觸發嘅 delta 改變。**No story blocker** — knob retune 屬 sprint task。
- **EC-35 #17 Equipment boot ordering — modifier replay delay**: Stat System Rule 8 完成後 modifier table empty；#17 Equipment Rule [TBD] replay 所有穿著裝備。Replay 期間 1 frame window 內 derived stat 未計 equipment buff。**Mitigation per Rule 8**: subscriber 通過 `connect_for_initial_state` 喺 #17 replay 完成後 (i.e. 通過 GSM `boot_completed`-like signal aggregation) 先收 initial value，所以 visible inconsistency 唔出現 (per ADR-006 Contract 4 sequential boot)。**Caveat**: subscriber 連接早於 #17 replay 完成 → 收 initial value 不含 equipment → 之後 #17 replay 觸發 `stat_changed(.., EQUIPMENT)` deliver corrected value。Subscriber must idempotently handle re-receive same stat_id (already required by `connect_for_initial_state` contract)。
- **EC-36 #18 PR Detection 送 anomalous large `pr_magnitude` (e.g., 5.0 — 500% jump)**: Formula 2 clamps `pr_magnitude` to [0.0, 2.0]。But Stat System 唔自行 clamp — 假設 #18 server-validated (ADR-002 binding)。**Cross-system contract** — #18 GDD 必須 spec server-side validation rejecting `pr_magnitude > 2.0`；client-side 收 anomaly = #18 bug or compromised backend → Pillar 1 violation outside Stat System scope。
- **EC-37 PersistenceLayer migration 改 `stat.str` 格式 (e.g., float → struct)**: Migration step (Contract 10) 必須 rewrite `stat.*` keys to new format。Stat System Rule 1 LOCKED stat surface — 但 Rule 7 storage format 可隨 schema bump 改變。Future schema bump 必 update 本 GDD Rule 7 + Section H AC。

## Dependencies

### Upstream (Hard — Stat System cannot function without)

| GDD / ADR | Status | Interface | Why hard |
|-----------|--------|-----------|----------|
| **#3 PersistenceLayer** | Approved 2026-05-26 | `read("stat.str/dex/vit")` at boot；`write("stat.<base>", float, flush: bool)` per Rule 7；listens `critical_save_failed` filter `key startswith "stat."` | Boot reconciliation 完全依賴 PersistenceLayer sync read；Rule 13 persistence-first ordering 要求每次 base stat mutation 必 write 落 disk 先 mutate cache |
| **#1 GameStateMachine** | Approved 2026-05-25 | Subscribes `state_changed` signal via `connect_for_initial_state` helper for Suspended substate gate (Rule 14) | Pillar 1 anti-fabrication requires session-validity gate — Suspended substate 期間 mutation reject |
| **ADR-006 State Machine Contract** | Accepted 2026-05-28 | Contract 4 (autoload sequential boot — pos 5 after Persistence/GSM/PlatformDetect/GymSys; F-SETUP-1 sync 2026-05-28)；Contract 6 (`connect_for_initial_state` sentinel — both as subscriber to GSM AND as broadcaster to 6 consumers) | Boot ordering invariant + observer pattern contract |
| **ADR-003 Save State Strategy** | Proposed | `stat.*` namespace allocation under `user://state.json` Tier 2 persistence; defines IndexedDB quota share for stat keys (small — 3 floats < 100 bytes) | `stat.*` namespace ratification — without it, namespace collision risk with other systems |

### Upstream (Soft — Co-evolving)

| GDD / ADR | Status | Interface | Why soft |
|-----------|--------|-----------|----------|
| **ADR-005 Loot Rarity Formula** | Proposed | Formula 2 `PR_BASE` retune gate; defines real-PR-anchor → loot rarity → `EQUIPMENT` modifier strength bridge | Stat System Formula 2 係 VS-tier provisional；ADR-005 ratification 後 retune；Stat System 唔 block on ADR-005，但 quantitative balance 取決於 ADR-005 lock |
| **#10 Exercise → Class Mapping** | Not Started (Pre-MVP) | Provides `class_id` enum (PUSH/PULL/LEG) for VOLUME_TICK routing | #9 / #18 caller responsibility to obtain class_id and route — Stat System 唔直接 import #10 |
| **#18 PR Detection & Avatar Progression** | Not Started (Pre-MVP) | Provides `pr_magnitude` server-validated value for Formula 2 input | VS-tier 可用 mock provided by debug autoload；MVP gate requires real #18 |

### Downstream (Depended On By — consumers in dependency order)

| Consumer | Tier | Interaction | Bidirectional sync status |
|----------|------|-------------|----------------------------|
| **#9 Workout State Tracker** | VS (Not Started) | Calls `apply_stat_delta(stat_id, VOLUME_TICK, +0.05)` per set completion；caller whitelist enforced via Rule 4 CI lint | ⚠️ Must add Stat System to #9 Section F when #9 authored — VOLUME_TICK class routing contract |
| **#10 Exercise → Class Mapping** | Pre-MVP (Not Started) | Returns class enum；no direct Stat System call | ⚠️ Must add Stat System to #10 Section F as downstream consumer (via #9/#18 routing) |
| **#11 (本 GDD) → #12 Ability** | VS (Not Started) | Subscribes `stat_changed` via `connect_for_initial_state`；reads `get_stat` on ability slot recompute | ⚠️ Must add Stat System to #12 Section F as upstream when #12 authored |
| **#11 → #13 CombatResolver** | VS (Not Started) | Hot read path — `get_stat(ATTACK_POWER)` 等 per combat tick；NO signal subscription (read-on-demand for stateless combat math) | ⚠️ #13 must add Stat System to Section F as upstream；EC-33 MAX_HP rescaling Open Question gates here |
| **#11 → #17 Equipment & Inventory** | MVP (Not Started) | Calls `apply_equipment_modifier(equipment_id, StatModifier)` / `remove_equipment_modifier(equipment_id)`；NEVER call `apply_stat_delta` directly (Rule 4 caller whitelist enforcement) | ⚠️ #17 must add Stat System to Section F as upstream；EQUIPMENT source path |
| **#11 → #18 PR Detection** | Pre-MVP (Not Started) | Calls `apply_stat_delta(stat_id, PR_BREAKTHROUGH, delta)`；caller whitelist `src/feature/pr_detection.gd` | ⚠️ #18 must add Stat System to Section F as upstream；FR-2 ratification cascade |
| **#11 → #20 Gym-Mode HUD** | MVP (Not Started) | Subscribes `stat_changed`；HUD redraws stat numbers + glow effect per signal payload | ⚠️ #20 must use `connect_for_initial_state` helper |
| **#11 → #22 Character Screen** | MVP (Not Started) | Subscribes `stat_changed` + reads `get_stat` on screen open；historical comparison via #28 Telemetry | ⚠️ #22 must use `connect_for_initial_state` helper |
| **#11 → #26 Avatar Renderer** | VS (Not Started) | Subscribes `stat_changed` to derive render-only class posture + evolution tier (Formula 1/2 from STR/DEX/VIT)；render-only per ADR-0010 | ⚠️ #26 must use `connect_for_initial_state` helper；v0.2 layered character system deepens this |
| **#11 → #28 Telemetry / Analytics** | Pre-MVP (Not Started) | Subscribes 4 telemetry signals: `stat_clamped` / `stat_critical_save_failed` / `stat_mutation_rejected` / `boot_completed` | ⚠️ `stat_mutation_rejected` release-build fires = cheat attempt or implementation bug — alert routing per #28 |

### ADR Dependencies (Detailed)

| ADR | Status | Bound contracts | This GDD's relationship |
|-----|--------|-----------------|--------------------------|
| **ADR-006 State Machine Contract** | Proposed (ratified 2026-05-25) | Contract 3 (SerializableResource envelope — Stat System NOT using, plain float persists)；Contract 4 (autoload sequential boot)；Contract 6 (`connect_for_initial_state` sentinel) | Inheritor only — Stat System NOT amending ADR-006 |
| **ADR-003 Save State Strategy** | Proposed | `stat.*` namespace allocation；`user://state.json` Tier 2 path | Inheritor — `stat.*` namespace registered with ADR-003 |
| **ADR-005 Loot Rarity Formula** | ⚠️ Registry discrepancy — systems-index 標 "Accepted 2026-05-27" 但 technical-preferences.md 仍寫 "Proposed"；待 technical-preferences.md 同步確認 | Section B FR-2 + Formula 2 `PR_BASE` retune | Input scope — Stat System provides `PR_BREAKTHROUGH` source contract that ADR-005 must respect (EQUIPMENT modifier path for RNG-influenced stat boost)；若 ADR-005 已 Accepted，Formula 2 provisional 標記 + Q-A1 retune path 可啟動 |
| **ADR-001 Web Export Budget Caps** | Proposed | No direct binding (Stat System hot read path < 0.01ms per call — well below CPU budget) | Stat System Pillar 2 budget enforcement happens through `get_stat` O(1) guarantee (Rule 14 no-cache rationale defers caching until profile-proven need) |
| **ADR-002 GymSys Integration Protocol** | Proposed | No direct binding (Stat System 唔 talk to GymSys backend；ADR-002 path via #2 → ADR-003 → PersistenceLayer → Stat System) | Indirect — `PR_BREAKTHROUGH` source originates from #18 PR Detection consuming GymSys events per ADR-002 |
| **ADR-004 CORS / Cross-Origin Auth Topology** | Proposed | No direct binding | Indirect — same chain as ADR-002 |

### Bidirectional Sync Status

⚠️ **Sync gap notice**: 本 GDD lists 10 downstream consumers + 3 hard upstream + 3 soft upstream，但所有 downstream consumer 嘅 GDD 仲未 authored (10 ⨉ "Not Started")。當 #9 / #10 / #12 / #13 / #17 / #18 / #20 / #22 / #26 / #28 GDD authored 時，必須喺 each 嘅 Section F 加 Stat System 為 upstream dependency — 呢個係 future bidirectional sync 嘅 propagation list。

⚠️ **Already-Approved GDD propagation required**: #1 GSM 同 #3 PersistenceLayer GDDs (both Approved) 仲未 reference #11 Stat System 為 downstream consumer。需 next-revision batch 加入：run `/propagate-design-change stat-system.md` targeting `game-state-machine.md` + `persistence-layer.md` Section F。

**Recommendation for future author**: 當 author 上述任何 GDD 時，run `Grep pattern="stat-system|StatSystem|apply_stat_delta|stat_changed" path="design/gdd/<your-gdd>.md"` 確認 cross-reference 已加入。

### Failure Mode Matrix

| Failure Source | Detection Mechanism | Stat System Response | Downstream Impact |
|----------------|---------------------|----------------------|-------------------|
| PersistenceLayer Corrupt substate at boot | `read()` returns `{}` empty | Fallback to defaults (Rule 8 step 4 + EC-02) | Subscriber 收 default 10.0 initial value — equivalent to fresh character |
| PersistenceLayer write fails mid-session | `write()` returns false | EC-06: emit `stat_critical_save_failed` + in-memory unchanged + caller `apply_stat_delta` return false | Caller (#9/#18) 必須 handle return false；下次 boot reconcile via ADR-003 backend-primary path |
| GSM Suspended state | `state_changed(_, "suspended", _)` received | Rule 14: enter Suspended substate；reject mutation API | All 6 consumers see frozen stats until resume；hot read (`get_stat`) still functional |
| #18 anomalous pr_magnitude (cheat / bug) | EC-36: Stat System assumes server-validated；no client-side range check beyond Formula 2 `clamp(m, 0, 2)` | Pillar 1 violation OUTSIDE Stat System scope — #18 must server-validate (ADR-002 binding) | If #18 sends `m > 2.0` it gets clamped to 2.0 in Formula 2 — fail-soft |
| Subscriber misconnects (plain `.connect`) | EC-29 + CI lint `check_stat_changed_connect.gd` | Build fails on release branch | Pre-merge gate — 唔到 production |
| DEBUG_OVERRIDE in release build | Rule 10 triple defense (runtime + CI + export strip) | Push_error + reject | Pillar 1 hard guarantee maintained |
| Schema migration adds stat (e.g., LUK) | PersistenceLayer Contract 10 chain runs at boot | Stat System Rule 1 LOCKED — current GDD does not handle LUK；schema bump requires GDD revision | All consumers must revise to handle new stat ID |

## Tuning Knobs

### Owned Knobs (15 total)

| Knob | Default | Safe Range | Source Rule / Formula | What changes if pushed |
|------|---------|-----------|------------------------|------------------------|
| `MAX_STAT_VALUE` | 999 | [100, 9999] | Rule 11 | ↑ Late-game ceiling 拉高，progression 延長；↓ 玩家更易撞頂、Pillar 1 grind 縮短 |
| `DEFAULT_BASE_STAT` | 10.0 | [1.0, 50.0] | Rule 11 | ↑ New player feel 更強 (HP/ATK 起點高)；↓ MVP balance target (CF-1) 失準 — 必同步 retune `*_BASE` knobs |
| `VOLUME_TICK_BASE` | 0.05 | [0.02, 0.20] | F1 | ↑ 玩家成長過快、PR_BREAKTHROUGH 失去 meaningful jump 角色；↓ 唔做 PR 嘅玩家感覺停滯，違反 Pillar 1 |
| `PR_BASE` ⚠️ | 6.0 | [3.0, 12.0] | F2 | **PROVISIONAL — ADR-005 ratification 後 retune**。↑ PR 變主要 progression source、VOLUME_TICK 變裝飾；↓ PR 唔再 meaningful，違反 Pillar 1 |
| `PR_DIMINISH_EXP` | 2.0 | [1.5, 3.0] | F2 | ↑ High-stat 玩家 PR 收益急跌、progression 變平；↓ snowball 風險、hardcore 玩家可能撞頂太快 |
| `HP_BASE` | 80 | [50, 150] | F3 | ↑ 新手生存太易、戰鬥 tension 流失；↓ 新手早期太脆，違反 first-5-min feel |
| `HP_PER_VIT` | 8.0 | [5.0, 12.0] | F3 | ↑ VIT scaling 太陡、leg day 過強；↓ VIT 投資感唔到回報 |
| `ATK_BASE` | 10 | [5, 20] | F4 | ↑ 新手攻擊太強無進步空間；↓ 殺怪慢悶 |
| `ATK_PER_STR` | 1.5 | [1.0, 2.5] | F4 | ↑ push-day 玩家過強；↓ STR 投資感唔到回報 |
| `ATK_PER_DEX` | 0.3 | [0.2, 0.5] | F4 | ↑ DEX 對攻擊嘅貢獻過大 (違反 Rule 1 「STR dominates」)；↓ pure pull 玩家戰鬥輸出薄弱 |
| `MOVE_BASE` | 180.0 | [150.0, 220.0] | F5 | ↑ 新手感覺敏捷但失 DEX progression feel；↓ 新手感覺笨拙 |
| `MOVE_PER_DEX` | 0.4 | [0.2, 0.7] | F5 | ↑ MOVE_CAP 早被擊穿；↓ DEX 對移動嘅貢獻不明顯 |
| `MOVE_CAP` | 420.0 | [350.0, 500.0] | F5 | ↑ Camera 可能跟唔到 (#7 Camera POSITION_SMOOTHING_SPEED cross-invariant)；↓ 高 DEX 玩家無 reward |
| `CRIT_PER_DEX` | 0.0015 | [0.001, 0.003] | F6 | ↑ DEX_FOR_MAX_CRIT 變細、太易封 crit；↓ DEX 對 crit 嘅貢獻不明顯 |
| `MAX_CRIT_CHANCE` | 0.50 | [0.30, 0.65] | F6 | ↑ 戰鬥變 crit dice game；↓ crit 永遠係驚喜但難以 lean-in |

### Cross-Knob Invariants (CI-Verified)

呢啲 invariant 必須喺 `tests/unit/stat_system/test_knob_invariants.gd` (Section H AC) 驗證；任何 knob 改動觸發 violation 必喺 PR description 度 explicit call out。

| ID | Invariant | Rationale |
|----|-----------|-----------|
| INV-1 | `PR_BASE × 2.0 < 50.0` | 單次 PR 唔可以將 base stat 推上 5% MAX_STAT_VALUE — Pillar 1 anti-snowball |
| INV-2 | `(s = MAX_STAT_VALUE) ⇒ diminishing_factor(s) = 0` | Formula 2 mathematical hard cap (independent of `PR_DIMINISH_EXP` value) |
| INV-3 | `HP_BASE + 10 × HP_PER_VIT ≥ 150` | Default stat 新手 MAX_HP ≥ 150；first-5-min feel baseline (CF-1) |
| INV-4 | `ATK_PER_DEX < ATK_PER_STR × 0.5` | Rule 1 「STR dominates」design intent — DEX 對 ATK 貢獻細過 STR 一半 |
| INV-5 | `ATK_BASE + 10 × ATK_PER_STR + 10 × ATK_PER_DEX ≥ 25` | Default stat 新手 ATTACK_POWER ≥ 25；3-4 hit kill starter mob |
| INV-6 | `MOVE_BASE + (999 × MOVE_PER_DEX) > MOVE_CAP` | MOVE_CAP reachable by stat-only (no equipment) — Pillar 1 CF-3 |
| INV-7 | `MOVE_CAP ≤ camera_max_follow_speed` (#7 Camera) | **Cross-system invariant** — 防止 avatar outrun camera follow lerp。⚠️ **PENDING** — 精確 math defer to Q-X4：#7 Camera GDD `POSITION_SMOOTHING_SPEED` 係指數衰減率唔係 max speed，需 #7 GDD next-revision export explicit `MAX_AVATAR_FOLLOW_SPEED` derived knob 再 update 本 invariant |
| INV-8 | `DEX_FOR_MAX_CRIT ∈ [100, MAX_STAT_VALUE]` where `DEX_FOR_MAX_CRIT = MAX_CRIT_CHANCE / CRIT_PER_DEX` | Cap reachable by stat-only AND not trivially close to default |
| INV-9 | All knobs in their safe range | Guard against out-of-range typo (e.g., `MAX_CRIT_CHANCE = 5.0`) |

### Knob Interaction Warnings

⚠️ **DEX triple-scale (intentional design)**: `ATK_PER_DEX` + `MOVE_PER_DEX` + `CRIT_PER_DEX` 三 knob 都 scale DEX。Pure pull-day specialist (high DEX) 同時得 ATTACK 細貢獻 + MOVE 大貢獻 + CRIT 大貢獻 = 「靈活刺客」build。**唔係 bug，係 Pillar 4 design intent** — 三大 stat 各有 archetypal payoff (STR=重擊，DEX=機動 crit，VIT=耐打)。

⚠️ **MAX_STAT_VALUE change ripples through 3 invariants**: `MAX_STAT_VALUE` 改動同時 invalidate INV-2 (diminishing factor math) + INV-6 (MOVE_CAP reachability — MOVE_BASE + MAX_STAT_VALUE × MOVE_PER_DEX 必 > MOVE_CAP) + INV-8 (DEX_FOR_MAX_CRIT ≤ MAX_STAT_VALUE)。Rule 1 LOCKED stat surface — 改 MAX_STAT_VALUE 屬 schema bump scope，唔屬普通 tuning。

⚠️ **DEFAULT_BASE_STAT change ripples through CF-1 baseline**: `DEFAULT_BASE_STAT` 改動必同步 retune `HP_BASE` / `ATK_BASE` 等以維持 MVP Balance Target Table (Section D)。建議 CF-1 baseline 一同 hard-pinned 入 unit test — 任何 knob 改動 break baseline 必 explicit call out。

### Referenced Knobs from Other Systems (NOT owned here)

| Knob | Owner GDD | Read access | Note |
|------|-----------|-------------|------|
| `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` | #3 PersistenceLayer | Not used | Stat System does not perform time-based logic per Rule 12 (no decay) |
| `POSITION_SMOOTHING_SPEED` / camera follow rate | #7 Camera System | Read-only (cross-knob invariant INV-7) | `MOVE_CAP ≤ camera_max_follow_speed` cross-system check |
| `MAX_FRAME_DELTA` | #5 / #6 / #7 | Not used | Stat System has no `_process(delta)` — pure event-driven |
| ADR-005 loot rarity weights | ADR-005 (Proposed) | Indirect — affects `equipment_*_mod` value range produced by #17 (loot drops) | EQUIPMENT modifier strength reflects ADR-005 PR-anchored rarity formula |
| `PR_BREAKTHROUGH` threshold (1RM detection) | #18 PR Detection (Not Started) | Read-only (`pr_magnitude` is a Formula 2 input) | Stat System assumes server-validated input per EC-36 |

### Tuning Knob Stability Tier (per concept doc governance)

| Tier | Knobs | Change governance |
|------|-------|--------------------|
| **LOCKED (schema bump)** | `MAX_STAT_VALUE`, `DEFAULT_BASE_STAT`, stat surface (3 base + 4 derived) | Requires PersistenceLayer schema migration; revise this GDD's Rule 1 + Rule 11 |
| **DESIGN-FROZEN (post-Pre-MVP)** | `VOLUME_TICK_BASE`, `PR_DIMINISH_EXP`, all derived stat `*_BASE` defaults | Change requires #28 Telemetry data showing pacing problem |
| **TUNABLE (sprint task)** | `HP_PER_VIT`, `ATK_PER_STR`, `ATK_PER_DEX`, `MOVE_PER_DEX`, `MOVE_CAP`, `CRIT_PER_DEX`, `MAX_CRIT_CHANCE` | Routine balance tuning; CI verifies invariants |
| **PROVISIONAL ⚠️** | `PR_BASE` | Locked at VS-tier mock; ADR-005 ratification triggers re-tune |

## Visual/Audio Requirements

**Stat System owns NO direct visual / audio surface** — per Section B / C committed posture「Stat System NEVER fires VFX / 音效，visible glow + 數字 update 由下游 consumer own」。本 section 列明 signal trigger contract，downstream visual / audio responsibility 屬下游 GDD scope (#5 / #20 / #22 / #26 / #4 Audio Manager)。

### Signal-Driven Visual Contract (downstream ownership)

| Stat System Signal | Visual Owner | Expected Visual Treatment | Audio Owner |
|--------------------|--------------|---------------------------|-------------|
| `stat_changed(stat_id, old, new, PR_BREAKTHROUGH, _)` | **#20 Gym-Mode HUD** | 「真實 PR → 數字升 → 角色變強」moment — HUD 對應 stat 數字 short flash + glow (per Pillar 3「值得 cap 圖」精神嘅 micro-version)；duration ≤ 300ms (Pillar 2 frictionless — mid-set glance 唔可拖長)；particles via #5 Particle System Wrapper preset (recommend `STATUS_BUFF` or new `PR_BURST` preset future addition) | **#4 Audio Manager** (Pre-MVP) — short PR confirmation chime (350-500ms tail), distinct from loot fanfare; **MAY duck** to background music briefly for emphasis (audio direction defer to #4 GDD) |
| `stat_changed(stat_id, old, new, VOLUME_TICK, _)` | **#20 HUD** | Subtle increment — 數字 tick up without glow (volume 累積唔應 over-emphasize per Pillar 2)；optional micro-particle from #5 `STATUS_*` preset family；OR pure-numerical update (no VFX) — art-director final call at #20 GDD authoring | **#4** — silent or very subtle "tick" SFX (~50ms tail)；caller may pass `multiplier=0.3` 等 to #5 if particle used |
| `stat_changed(stat_id, old, new, EQUIPMENT, _)` | **#22 Character Screen** + **#23 Inventory UI** (equip context) + **#20 HUD** (passive update) | Equip / unequip 觸發 stat number animation — typically 200-400ms ease；#22 may show「↑」/「↓」arrow indicator next to value | **#4** — equip / unequip SFX owned by #17 Equipment, not driven by Stat System signal |
| `stat_critical_save_failed(stat_id)` | **#24 Login / GymSys Connection UI** (banner) + **#28 Telemetry** | Persistent warning banner「Storage error — your progress 可能未儲存」(per Pillar 1 anti-lie posture — never silently degrade)；UX defer to #24 GDD | **#4** — soft error tone OR silent (UX call) |
| `stat_clamped(stat_id, attempted, clamped)` | NONE direct — debug telemetry only | No visual surface — `stat_clamped` 係 telemetry signal，唔 fire UI；#28 Telemetry forwards to backend for balance retune analysis | NONE |
| `boot_completed()` | NONE direct | Subscriber lifecycle hook only — no visual effect | NONE |

### Cross-System Visual Coordination

- **#5 Particle System Wrapper**: 若 PR_BREAKTHROUGH 要 particle burst，#20 HUD caller 用 `ParticleSystemWrapper.play(PresetId.PR_BURST, position, multiplier=1.2)`；preset definition 由 art-director 喺 #5 GDD 加入 (currently preset surface 9 個，PR_BURST 為 v0.2 candidate — MVP 用現有 STATUS_BUFF preset fallback)
- **#6 Screen Effects System**: Stat-related events **唔 trigger** screen shake / hit pause — Stat System mutation 屬 menu / passive layer，唔合 #6 嘅 peripheral kinaesthetic 用途
- **#7 Camera System**: Stat mutation **唔 trigger** Focal state — Focal 係 combat / loot ritual scope，stat 升 (especially VOLUME_TICK micro-tick) 應該 frictionless 唔搶 camera attention

### Asset Spec Status

**Stat System 自身 owns no assets** — 純 data layer。Downstream consumer (#20 HUD / #22 Character Screen / #26 Avatar Renderer) 各自 author Visual/Audio section + run `/asset-spec` for own assets。本 GDD 唔需要 trigger Asset Spec workflow。

## UI Requirements

**Stat System owns NO direct UI** — 純 autoload data layer，玩家從未直接「打開」Stat System。所有 player-facing display 由下游 own：

| UI Concern | Owner GDD | Pattern |
|------------|-----------|---------|
| Real-time stat numeric display | #20 Gym-Mode HUD | `connect_for_initial_state` to `stat_changed`；HUD redraw per signal |
| Detailed stat breakdown (base + equipment + total) | #22 Character Screen | Read-on-open via `get_stat(stat_id)` + subscribe for live update |
| Render-only class posture + evolution tier | #26 Avatar Renderer | Subscribe `stat_changed` → derive posture/tier (Formula 1/2); render-only per ADR-0010 |
| Equipment effect preview ("equip this for +5 STR") | #23 Inventory UI | Reads `get_stat(stat_id)` + simulates `apply_equipment_modifier` projection (without committing) — design TBD at #23 GDD |
| Storage error banner | #24 Login / Connection UI | Subscribe `stat_critical_save_failed` |

**API contract for UI consumers** (binding on downstream GDDs):
1. **MUST use `connect_for_initial_state` helper** for `stat_changed` subscription (per ADR-006 Contract 6 + AC-08 + AC-34)
2. **MUST call `get_stat` for read-on-open scenarios** (e.g., Character Screen first-open) — NEVER access internal `_base` Dictionary
3. **MUST handle `stat_changed` with `is_initial=true` idempotently** — subscriber may receive initial-state delivery AND subsequent mutation for same stat_id in quick succession (especially during #17 Equipment boot-time replay window per EC-35)
4. **MUST NOT call mutation API** from UI layer — UI is read-only consumer of Stat System

## Open Questions

> 7 條 open questions — split into resolved-by-future-GDD (Q-X*) + ADR-ratification-blocked (Q-A*)。Q-X* 由 downstream GDD authoring 自然 close；Q-A* 喺對應 ADR Accepted 後 revisit。

### Cross-System Open Questions (resolve via downstream GDD)

- **Q-X1 — MAX_HP change while current HP exists (EC-33)**
  - **Question**: 玩家戴 +50 HP 護甲 → MAX_HP 由 160 → 210。Current HP 由 #13 own — Stat System 唔 dictate「current HP scales」抑或「current HP unchanged」。
  - **Likely resolution**: #13 CombatResolver GDD 預期 ruling = "current HP 不變，玩家可繼續療傷至新 MAX_HP" (standard ARPG convention)
  - **Owner**: #13 CombatResolver GDD authoring (VS tier order 9)
  - **Stat System impact**: NONE — Stat System spec scope 只 emit `stat_changed(MAX_HP, 160, 210, EQUIPMENT)`；下游 #13 handle current-HP logic

- **Q-X2 — #17 Equipment boot ordering — modifier replay timing (EC-35)**
  - **Question**: Stat System Rule 8 boot 完 modifier table empty；#17 Equipment 喺 own boot 後 replay 穿著裝備。Subscriber 中間 1-frame window 可能收到 unbuffered initial value。
  - **Likely resolution**: #17 GDD spec 要求 #17 喺 own `boot_completed` 之後再 replay modifier；subscriber 通過 GSM `state_changed == "ready"` aggregation signal 等到 all autoloads ready 先 connect_for_initial_state (per ADR-006 Contract 6 pattern)
  - **Owner**: #17 Equipment & Inventory GDD authoring (MVP tier order 23)

- **Q-X3 — `boot_completed` signal vs `connect_for_initial_state` integration timing**
  - **Question**: Subscriber 應該 wait `boot_completed` 先 call `connect_for_initial_state`，定係立即 connect (helper 內部 handle queuing if not Ready)?
  - **Likely resolution**: Helper 應該 idempotent — call before Ready → queue connection；call after Ready → immediate callv. Consumer 唔需要 wait `boot_completed`。
  - **Owner**: Future Stat System implementation story；可能 ADR-006 Contract 6 helper API spec amendment
  - **Stat System impact**: Internal helper implementation detail，唔影響 public API contract

- **Q-X4 — Cross-system invariant INV-7 (MOVE_CAP ≤ camera_max_follow_speed)**
  - **Question**: Stat System MOVE_CAP = 420 px/s；#7 Camera System POSITION_SMOOTHING_SPEED = 5.0 (exp decay rate, 唔係 max speed)。實際 max follow speed = MOVE_CAP × (1 - exp(-5×0.0167)) ≈ 32 px/frame @ 60fps → 1920 px/s effective camera max。INV-7 spec hand-wave；needs precise math validation。
  - **Likely resolution**: 至 #7 Camera GDD next-revision 加 explicit `MAX_AVATAR_FOLLOW_SPEED` derived knob，本 GDD revise INV-7 公式 reference 嗰個 knob
  - **Owner**: #7 Camera System GDD revision + cross-system review

### ADR-Ratification Open Questions (blocked on ADR Accepted)

- **Q-A1 — `PR_BASE` retune post-ADR-005 ratification (FR-2 binding)**
  - **Question**: Formula 2 `PR_BASE = 6.0` 屬 VS-tier mock；ADR-005 Loot Rarity Formula ratification 之後 `pr_magnitude` 嘅 normalization 同 loot drop weight 需 cross-validate。
  - **Blocked on**: ADR-005 Accepted
  - **Resolution path**: ADR-005 Accepted → Stat System sprint task retune `PR_BASE` per balance data → CI knob safe-range invariant (AC-32) ensure within safe range
  - **Impact if PR_BASE changes by > 50%**: Section D Formula 2 worked example + MVP Balance Target Table 數字需 updated；Section H AC-24 STR ≈ 12.5 ±0.001 tolerance 可能需 adjust

- **Q-A2 — Schema migration policy when stat surface bumps (e.g., adding LUK in v0.2)**
  - **Question**: Rule 1 LOCKED 3 base + 4 derived stat surface。v0.2 可能加 LUK (luck — affects crit / loot rarity)；migration step (PersistenceLayer Contract 10) 如何 handle?
  - **Blocked on**: v0.2 scope decision + ADR-006 Contract 10 chain length budget (MAX_MIGRATION_CHAIN_LENGTH=6) 仲有 5 個 slot
  - **Resolution path**: v0.2 GDD revision → 加 LUK stat → migration step `_migrate_stat_v1_to_v2` populate `stat.luk = 10.0` default → ADR-006 binding check
  - **Impact**: 本 GDD Rule 1 + Section D 全部需 update；6 個 downstream consumer 同樣需 update

- **Q-A3 — Multi-character schema namespace migration (v0.2+ multi-character scope)**
  - **Question**: Rule 15 single-character MVP scope；v0.2+ skill tree variants (#30) 可能需 multi-character。Schema 由 `stat.<stat_id>` → `stat.<character_id>.<stat_id>` migration?
  - **Blocked on**: v0.2 multi-character feature scope decision (#30 Skill Tree GDD authoring + scope clarification)
  - **Resolution path**: v0.2 GDD revision → schema bump → migration step convert legacy `stat.*` → `stat.default.*` (preserve MVP player progress)

- **Q-A4 — AC-36 Pearson correlation threshold (r ≥ 0.7) — ADR-005 derived**
  - **Question**: AC-36 specs Pearson r ≥ 0.7 between `pr_magnitude` 同 EQUIPMENT modifier delta。0.7 來源於 ADR-005 Pillar 1 binding「real-PR-signal weight ≥ 0.7」— 但實際 statistical threshold 可能需要 ratchet (ADR-005 ratification 後 may settle on 0.65 or 0.75 based on simulation)。
  - **Blocked on**: ADR-005 Accepted + balance simulation 1000-sample run
  - **Resolution path**: ADR-005 ratification → simulation → AC-36 threshold confirmation OR adjustment

### Open Questions Summary Table

| Q-ID | Domain | Owner | Status |
|------|--------|-------|--------|
| Q-X1 | MAX_HP scaling | #13 CombatResolver GDD | Pending #13 authoring (VS tier order 9) |
| Q-X2 | Equipment boot ordering | #17 Equipment GDD | Pending #17 authoring (MVP tier order 23) |
| Q-X3 | `connect_for_initial_state` timing | Implementation story | Defer to implementation sprint |
| Q-X4 | INV-7 camera cross-invariant | #7 Camera GDD revision | Pending #7 GDD next-revision |
| Q-A1 | `PR_BASE` retune | ADR-005 | Pending ADR-005 Accepted |
| Q-A2 | Schema bump for LUK / new stat | v0.2 GDD revision | Pending v0.2 scope |
| Q-A3 | Multi-character namespace | v0.2 GDD revision | Pending v0.2 multi-character scope |
| Q-A4 | AC-36 Pearson threshold | ADR-005 + simulation | Pending ADR-005 Accepted + balance data |

## Acceptance Criteria

> **Format**: GIVEN-WHEN-THEN，獨立可測。Test Type ∈ {`unit`, `integration`, `static-analysis`, `manual`, `playtest`}。Gate Level ∈ {`BLOCKING`, `ADVISORY`, `ADR-RATIFICATION-GATED`}。
>
> **總 AC 數**: 37 (24 BLOCKING + 10 ADVISORY + 3 ADR-RATIFICATION-GATED)。
> **Test type 分布**: 24 unit + 6 integration + 6 static-analysis + 1 composite (binary inspection)。**冇 manual / playtest** — Stat System data layer 無 visual / feel surface，全部 evidence automatable。

### Core Rules ACs (Section C coverage)

- **AC-01 — Stat surface LOCKED (Rule 1)**
  - **GIVEN** Stat System Ready substate
  - **WHEN** 呼叫 `get_stat(StatId.STR)` / `DEX` / `VIT` / `MAX_HP` / `ATTACK_POWER` / `MOVE_SPEED` / `CRIT_CHANCE`
  - **THEN** 7 個 call 全部返 float；對 unknown id (`"luk"`) 返 `NAN` 或 push_error reject (test asserts no crash + telemetry fires)
  - Source: Rule 1 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_stat_surface_locked.gd`

- **AC-02 — Closed mutation API: direct `_base` write rejected by CI lint (Rule 2)**
  - **GIVEN** 任何 `src/` (排除 `src/autoload/stat_system.gd`) 文件包含 literal `StatSystem._base[` 或 `StatSystem._equipment_modifiers[`
  - **WHEN** CI lint `tools/ci/check_stat_internal_field_access.gd` 跑
  - **THEN** Build fail，exit code ≠ 0，error message identifies offending file + line
  - Source: Rule 2 | Test Type: static-analysis | Gate: BLOCKING | Path: `tools/ci/check_stat_internal_field_access.gd`

- **AC-03 — Caller whitelist enforce (Rule 2 + Rule 4)**
  - **GIVEN** 任何 `src/` 文件 (排除 #9 / #17 / #18 / `tests/`) 包含 `StatSystem.apply_stat_delta(`
  - **WHEN** CI lint `tools/ci/check_stat_mutation_callers.gd` 跑
  - **THEN** Build fail，identify unauthorized caller file path
  - Source: Rule 2, Rule 4 | Test Type: static-analysis | Gate: BLOCKING | Path: `tools/ci/check_stat_mutation_callers.gd`

- **AC-04 — `StatSource` enum 5-value completeness (Rule 3)**
  - **GIVEN** Stat System runtime
  - **WHEN** Inspect `StatSource.values()`
  - **THEN** 回返 array 5 elements: `PR_BREAKTHROUGH`, `VOLUME_TICK`, `EQUIPMENT`, `DEBUG_OVERRIDE`, `INITIAL_STATE`；**且** `apply_stat_delta(STR, StatSource.INITIAL_STATE, 1.0)` 返 false + push_error
  - Source: Rule 3 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_stat_source_enum.gd`

- **AC-05 — Source/stat allow-list: PR_BREAKTHROUGH base-only (Rule 4)**
  - **GIVEN** Stat System Ready，STR=10
  - **WHEN** `apply_stat_delta(StatId.STR, StatSource.PR_BREAKTHROUGH, 1.0)` (allowed) AND `apply_stat_delta(StatId.MAX_HP, StatSource.PR_BREAKTHROUGH, 50.0)` (disallowed)
  - **THEN** 第一 call 返 `true` + STR 升至 11.0；第二 call 返 `false` + `stat_mutation_rejected(MAX_HP, PR_BREAKTHROUGH, 50.0, "source_stat_mismatch")` fires + MAX_HP 不變
  - Source: Rule 4 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_source_stat_allow_list.gd`

- **AC-06 — Source/stat allow-list: EQUIPMENT all-7 (Rule 4, Rule 5)**
  - **GIVEN** Stat System Ready
  - **WHEN** `apply_equipment_modifier("eq_test", StatModifier.new({MAX_HP: 50, CRIT_CHANCE: 0.05}))` 被 #17 path 呼叫
  - **THEN** Modifier 接受，derived stat recompute，emit `stat_changed(MAX_HP, ..., EQUIPMENT)` + `stat_changed(CRIT_CHANCE, ..., EQUIPMENT)`
  - Source: Rule 4, Rule 5 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_equipment_modifier_allow_list.gd`

- **AC-07 — Equipment modifier NOT persisted (Rule 5)**
  - **GIVEN** Apply equipment modifier 加 STR +10 → derived recompute；無 base mutation
  - **WHEN** Reload Stat System (`_ready()` 再跑)
  - **THEN** `_base[STR]` 仍係 10 (default 或 pre-equip persisted value)；`_equipment_modifiers` 係 empty Dictionary；**且** PersistenceLayer 從未收 `stat.str = 20` write call
  - Source: Rule 5 | Test Type: integration | Gate: BLOCKING | Path: `tests/integration/stat_system/test_equipment_not_persisted.gd`

- **AC-08 — `connect_for_initial_state` delivers 7 initial stats (Rule 6, ADR-006 Contract 6)**
  - **GIVEN** Stat System boot 完成 (Ready)，STR=12, DEX=15, VIT=10
  - **WHEN** Subscriber `connect_for_initial_state(my_callable)`
  - **THEN** my_callable 即時收 7 次 invocation (各 stat_id 一次)，`source = StatSource.INITIAL_STATE`, `is_initial = true`，values match current `_base` + computed derived
  - Source: Rule 6 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_connect_for_initial_state.gd`

- **AC-09 — Persistence flush policy: PR_BREAKTHROUGH `flush=true` / VOLUME_TICK `flush=false` (Rule 7)**
  - **GIVEN** Stat System Ready，PersistenceLayer spy 記錄每次 `write(key, value, flush)` call
  - **WHEN** `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` 然後 `apply_stat_delta(STR, VOLUME_TICK, 0.05)`
  - **THEN** 第一 write call `flush == true`，第二 write call `flush == false`
  - Source: Rule 7, Rule 9 | Test Type: integration | Gate: BLOCKING | Path: `tests/integration/stat_system/test_persistence_flush_policy.gd`

- **AC-10 — Boot reconciliation: first-boot defaults (Rule 8, EC-01)**
  - **GIVEN** PersistenceLayer `read("stat.str/dex/vit")` 全部返 `{}` (key absent)
  - **WHEN** Stat System `_ready()`
  - **THEN** `_base = {STR: 10.0, DEX: 10.0, VIT: 10.0}`，substate = Ready，`boot_completed` emit，**唔 emit** `stat_changed` during boot
  - Source: Rule 8, EC-01 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_boot_first_time.gd`

- **AC-11 — Boot reconciliation: partial keys (Rule 8, EC-03)**
  - **GIVEN** `read("stat.str")` 返 25.0，但 `read("stat.dex")` 返 `{}` empty
  - **WHEN** `_ready()`
  - **THEN** `_base = {STR: 25.0, DEX: 10.0, VIT: 10.0}`，per-absent-key push_warning fires
  - Source: Rule 8, EC-03 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_boot_partial_keys.gd`

- **AC-12 — Boot reconciliation: corrupt fallback (Rule 8 step 4, EC-04)**
  - **GIVEN** `read("stat.str")` 返 `NAN`
  - **WHEN** `_ready()`
  - **THEN** `_base[STR] = 10.0` (default fallback)，`stat_critical_save_failed(STR)` emit，push_error fires，substate = Ready (degraded mode)，**唔阻** game launch
  - Source: Rule 8 step 4, EC-04 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_boot_corrupt_fallback.gd`

- **AC-13 — DEBUG_OVERRIDE release-build runtime guard (Rule 10, FR-3)**
  - **GIVEN** Release build (`OS.is_debug_build() == false`)，STR=10
  - **WHEN** `apply_stat_delta(STR, StatSource.DEBUG_OVERRIDE, 100.0)`
  - **THEN** 返 `false`，`push_error("DEBUG_OVERRIDE blocked in release build")` fires，`stat_mutation_rejected(STR, DEBUG_OVERRIDE, 100.0, "debug_override_release_blocked")` emit，STR 不變
  - Source: Rule 10 (runtime guard), FR-3 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_debug_override_release_runtime_guard.gd`

- **AC-14 — DEBUG_OVERRIDE CI lint catches `src/` usage (Rule 10)**
  - **GIVEN** 任何 `src/` (排除 `tests/` 同 editor-only marker) 文件包含 literal `StatSource.DEBUG_OVERRIDE`
  - **WHEN** CI lint `tools/ci/check_debug_override_calls.gd` 跑 on release branch (`main` / `release/*`)
  - **THEN** Build fail
  - Source: Rule 10 (CI lint layer) | Test Type: static-analysis | Gate: BLOCKING | Path: `tools/ci/check_debug_override_calls.gd`

- **AC-15 — Clamping at 0 boundary (Rule 11, EC-26)**
  - **GIVEN** STR=5 (debug-set), source = DEBUG_OVERRIDE (debug build only)
  - **WHEN** `apply_stat_delta(STR, DEBUG_OVERRIDE, -10.0)`
  - **THEN** STR clamped 至 0；`stat_clamped(STR, -5.0, 0.0)` emit；`stat_changed(STR, 5.0, 0.0, DEBUG_OVERRIDE, false)` emit；`apply_stat_delta` 返 `true`
  - Source: Rule 11, EC-26 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_clamp_at_zero.gd`

- **AC-16 — Clamping at MAX_STAT_VALUE (Rule 11, EC-27)**
  - **GIVEN** STR=999
  - **WHEN** `apply_stat_delta(STR, PR_BREAKTHROUGH, 5.0)` (caller-computed raw delta — direct clamp test, bypassing Formula 2 diminishing_factor)
  - **THEN** target=1004 → clamp 999 → `stat_clamped(STR, 1004.0, 999.0)` emit；**且** `stat_changed(STR, 999.0, 999.0, PR_BREAKTHROUGH, false)` emit exactly once (old==new after clamp — subscriber 必須 idempotently handle per EC-10)；STR 不變
  - Source: Rule 11, EC-27 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_clamp_at_max.gd`

- **AC-17 — Anti-decay: negative delta from VOLUME_TICK rejected (Rule 12, EC-12)**
  - **GIVEN** STR=20
  - **WHEN** `apply_stat_delta(STR, VOLUME_TICK, -1.0)`
  - **THEN** 返 `false`，`stat_mutation_rejected(STR, VOLUME_TICK, -1.0, "base_stat_decay_blocked")` emit，**唔 emit** `stat_changed`，STR 不變
  - Source: Rule 12, EC-12 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_anti_decay_volume_tick.gd`

- **AC-18 — Atomic write: persist BEFORE in-memory mutate (Rule 13)**
  - **GIVEN** PersistenceLayer spy 攔截 `write()` 強制返 `false`
  - **WHEN** `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` (STR was 12)
  - **THEN** 返 `false`，`_base[STR]` 仍係 12 (in-memory unchanged)，`stat_critical_save_failed(STR)` emit，**冇** `stat_changed` emit
  - Source: Rule 13 step 4-5 | Test Type: integration | Gate: BLOCKING | Path: `tests/integration/stat_system/test_atomic_write_persist_first.gd`

- **AC-19 — Atomic write: emit AFTER in-memory mutate (Rule 13)**
  - **GIVEN** STR=10，subscriber callable 喺 handler 內 call `StatSystem.get_stat(STR)`
  - **WHEN** `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)`
  - **THEN** Subscriber `get_stat(STR)` 喺 handler 內讀到 11.0 (new value)，**唔係** 10.0 (old value)
  - Source: Rule 13 step 5-6 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_atomic_write_emit_after.gd`

- **AC-20 — GSM Suspended gate rejects mutation (Rule 14)**
  - **GIVEN** GSM `state_changed` deliver `"suspended"`，Stat System substate = Suspended
  - **WHEN** `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)`
  - **THEN** 返 `false`，`stat_mutation_rejected(STR, PR_BREAKTHROUGH, 1.0, "suspended_substate")` emit，push_warning fires，STR 不變
  - Source: Rule 14 | Test Type: integration | Gate: BLOCKING | Path: `tests/integration/stat_system/test_suspended_gate.gd`

- **AC-21 — Telemetry signal: `stat_clamped` fires on Rule 11 boundary (Rule 16)**
  - **GIVEN** STR=998
  - **WHEN** `apply_stat_delta(STR, PR_BREAKTHROUGH, 5.0)` (caller-computed raw — target 1003 clamps to 999)
  - **THEN** `stat_clamped(STR, 1003.0, 999.0)` emit exactly once
  - Source: Rule 16 | Test Type: unit | Gate: ADVISORY | Path: `tests/unit/stat_system/test_telemetry_stat_clamped.gd`

- **AC-22 — Telemetry signal: `boot_completed` fires after `_ready()` (Rule 16)**
  - **GIVEN** Stat System autoload 開始 init
  - **WHEN** `_ready()` 完成 sync read + GSM subscription
  - **THEN** `boot_completed()` emit exactly once，subscriber 可用呢個 signal 觸發 `connect_for_initial_state`
  - Source: Rule 16 | Test Type: unit | Gate: ADVISORY | Path: `tests/unit/stat_system/test_telemetry_boot_completed.gd`

### Formula ACs (Section D coverage)

- **AC-23 — Formula 1 VOLUME_TICK class routing (F1)**
  - **GIVEN** Stat System Ready，STR=DEX=VIT=10，VOLUME_TICK_BASE=0.05
  - **WHEN** #9 path call `apply_stat_delta(STR, VOLUME_TICK, 0.05)` (class_id=PUSH already routed by #10)
  - **THEN** STR=10.05，DEX=10.0, VIT=10.0 不變，emit `stat_changed(STR, 10.0, 10.05, VOLUME_TICK, false)`
  - Source: Formula 1 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_formula1_volume_tick.gd`

- **AC-24 — Formula 2 PR_BREAKTHROUGH default-stat (F2)**
  - **GIVEN** STR=12，PR_BASE=6.0，PR_DIMINISH_EXP=2.0，MAX_STAT_VALUE=999
  - **WHEN** `apply_stat_delta(STR, PR_BREAKTHROUGH, 0.500)` (caller-computed delta from `pr_magnitude=0.0833`)
  - **THEN** STR ≈ 12.5 (±0.001 tolerance)
  - Source: Formula 2 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_formula2_pr_default.gd`

- **AC-25 — Formula 2 PR_BREAKTHROUGH at MAX_STAT_VALUE (F2, INV-2, EC-13)**
  - **GIVEN** STR=999 (MAX_STAT_VALUE)
  - **WHEN** Caller computes `pr_delta = PR_BASE × pr_magnitude × diminishing_factor(999)` (= 0 exactly per INV-2)，然後 `apply_stat_delta(STR, PR_BREAKTHROUGH, 0.0)`
  - **THEN** `apply_stat_delta` 返 `true` (delta=0 合法 per EC-10)，STR 不變，**冇** push_error
  - Source: Formula 2, INV-2, EC-13 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_formula2_pr_at_max.gd`

- **AC-26 — Formula 3 MAX_HP default + equipment (F3, CF-1)**
  - **GIVEN** VIT=10，無 equipment：`get_stat(MAX_HP) == 160` (`80 + 10×8.0 + 0`)
  - **WHEN** Apply equipment modifier `{MAX_HP: +50}`
  - **THEN** `get_stat(MAX_HP) == 210`
  - Source: Formula 3, CF-1 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_formula3_max_hp.gd`

- **AC-27 — Formula 4 ATTACK_POWER baseline CF-1 (F4)**
  - **GIVEN** STR=DEX=VIT=10，無 equipment，default knobs (ATK_BASE=10, ATK_PER_STR=1.5, ATK_PER_DEX=0.3)
  - **WHEN** `get_stat(ATTACK_POWER)`
  - **THEN** 返 28 (`10 + 10×1.5 + 10×0.3 + 0 = 28`)
  - Source: Formula 4, CF-1 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_default_baseline.gd`

- **AC-28 — Formula 5 MOVE_SPEED cap boundary (F5, INV-6)**
  - **GIVEN** DEX=600, equipment_move_mod=+20, MOVE_BASE=180.0, MOVE_PER_DEX=0.4, MOVE_CAP=420.0
  - **WHEN** `get_stat(MOVE_SPEED)`
  - **THEN** 返 420.0 exactly (`min(180 + 600×0.4 + 20, 420) = min(440, 420) = 420`)
  - Source: Formula 5, INV-6 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_formula5_move_cap.gd`

- **AC-29 — Formula 6 CRIT_CHANCE cap (F6, INV-8)**
  - **GIVEN** DEX=400, equipment_crit_mod=+0.10, CRIT_PER_DEX=0.0015, MAX_CRIT_CHANCE=0.50
  - **WHEN** `get_stat(CRIT_CHANCE)`
  - **THEN** 返 0.50 exactly (`min(0.60 + 0.10, 0.50) = 0.50`)
  - Source: Formula 6, INV-8 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_formula6_crit_cap.gd`

### Cross-Knob Invariant ACs (Section G coverage)

- **AC-30 — INV-1 + INV-3 + INV-4 + INV-5 hard-pinned baseline (INV-1/3/4/5)**
  - **GIVEN** Default knob values loaded from const
  - **WHEN** Test computes all 4 invariant expressions
  - **THEN**:
    - `PR_BASE × 2.0 = 12.0 < 50.0` ✓ (INV-1)
    - `HP_BASE + 10 × HP_PER_VIT = 80 + 80 = 160 ≥ 150` ✓ (INV-3)
    - `ATK_PER_DEX × 2 = 0.6 < ATK_PER_STR = 1.5` ✓ (INV-4)
    - `ATK_BASE + 10 × ATK_PER_STR + 10 × ATK_PER_DEX = 10 + 15 + 3 = 28 ≥ 25` ✓ (INV-5)
  - **AND** 假如改 knob 違反任一 invariant → test fail with diagnostic message
  - Source: INV-1, INV-3, INV-4, INV-5 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_knob_invariants.gd`

- **AC-31 — INV-6 + INV-8 stat-only cap reachable (INV-6, INV-8, CF-3)**
  - **GIVEN** Default knobs，equipment mod = 0
  - **WHEN** Test computes max stat-only derived
  - **THEN**:
    - `MOVE_BASE + 999 × MOVE_PER_DEX = 180 + 399.6 = 579.6 > MOVE_CAP = 420` ✓ (INV-6 — cap reachable by stat-only)
    - `DEX_FOR_MAX_CRIT = 0.50 / 0.0015 ≈ 333.3 ∈ [100, 999]` ✓ (INV-8)
  - Source: INV-6, INV-8, CF-3 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_knob_invariants.gd`

- **AC-32 — INV-9 all knobs in safe range (INV-9)**
  - **GIVEN** Default knob const file
  - **WHEN** Test iterates 15 knobs，check each against safe range from Section G table
  - **THEN** All 15 in range；任一 knob 改到 out-of-range (e.g. `MAX_CRIT_CHANCE = 5.0`) → test fail with knob name + actual + safe range
  - Source: INV-9 | Test Type: unit | Gate: ADVISORY | Path: `tests/unit/stat_system/test_knob_safe_ranges.gd`

### Edge Case ACs (Section E coverage)

- **AC-33 — EC-22 Re-entrance guard rejects nested mutation (EC-22)**
  - **GIVEN** Subscriber connected to `stat_changed`，handler body 嘗試 call `StatSystem.apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` 同一 stat
  - **WHEN** Outer `apply_stat_delta(STR, PR_BREAKTHROUGH, 1.0)` triggers signal → handler 跑 → nested call attempts
  - **THEN** Nested call detect `_emit_depth > 0`，返 `false`，push_error fires，無 unbounded recursion
  - Source: EC-22 | Test Type: unit | Gate: BLOCKING | Path: `tests/unit/stat_system/test_reentrance_guard.gd`

- **AC-34 — EC-29 Plain `.connect` lint catches Contract 6 violation (EC-29)**
  - **GIVEN** 任何 `src/` (排除 `src/autoload/stat_system.gd` + `tests/`) 文件包含 `.connect(.*"stat_changed"`
  - **WHEN** CI lint `tools/ci/check_stat_changed_connect.gd` 跑
  - **THEN** Build fail，message: "Use `connect_for_initial_state(callable)` instead of plain `.connect` for stat_changed signal — see ADR-006 Contract 6"
  - Source: EC-29, ADR-006 Contract 6 | Test Type: static-analysis | Gate: BLOCKING | Path: `tools/ci/check_stat_changed_connect.gd`

### ADR-RATIFICATION-GATED ACs (Section B Fantasy Risk Register)

> **重要**: 以下 3 條 AC **gated on ADR-005 (Loot Rarity) + ADR-003 (Save State) 雙雙 Accepted**。VS-tier ship 之前可用 mock test scaffolding；MVP gate 要求 real ADR 落實 + AC 全部 pass。Section B Fantasy Risk Register 列明若 invariant 變動 → 整個 fantasy framing 需要 revisit。

- **AC-35 — FR-1: `StatSource` enum exhaustiveness post-ADR-005 ratification**
  - **GIVEN** ADR-005 (Loot Rarity Formula) Accepted，loot 系統 (#17) shipped
  - **WHEN** Search codebase for any new `StatSource.*` enum value beyond `PR_BREAKTHROUGH` / `VOLUME_TICK` / `EQUIPMENT` / `DEBUG_OVERRIDE` / `INITIAL_STATE` (e.g. `LOOT_RANDOM`, `LEVEL_UP_BONUS`, `STREAK_BONUS`)
  - **THEN** **None found** — any RNG-influenced stat boost MUST 走 `EQUIPMENT` modifier path per Rule 5；any time-based bonus 走 transient modifier，唔可以直接 fire `apply_stat_delta`
  - **AND** CI lint enforces enum closed-set check
  - Source: FR-1, Rule 3 | Test Type: static-analysis | Gate: ADR-RATIFICATION-GATED (ADR-005 Accepted) | Path: `tools/ci/check_stat_source_enum_closed.gd`

- **AC-36 — FR-2: EQUIPMENT modifier delta derived from real-PR-anchored loot rarity (ADR-005 hard guarantee)**
  - **GIVEN** ADR-005 Accepted，loot system generates EQUIPMENT modifier deltas based on PR-anchored rarity formula (real-PR-signal weight ≥ 0.7)
  - **WHEN** Loot drop occurs (#17 ship-time integration test)，capture `equipment_*_mod` value distribution over 1000 simulated PR sessions
  - **THEN** Distribution of equipment delta **correlated** with `pr_magnitude` input (Pearson r ≥ 0.7 per ADR-005 Pillar 1 binding) — 即係冇做 PR 嘅玩家唔可能拎大 EQUIPMENT buff
  - **AND** Pure-RNG loot path (random equipment with no PR anchor) 唔存在於 codebase
  - Source: FR-2, ADR-005 Pillar 1 binding | Test Type: integration | Gate: ADR-RATIFICATION-GATED (ADR-005 Accepted) | Path: `tests/integration/stat_system/test_fr2_loot_pr_anchor_correlation.gd`

- **AC-37 — FR-3: DEBUG_OVERRIDE triple-defense full coverage**
  - **GIVEN** Release build pipeline (export template + CI gate + runtime guard 三層都 active)
  - **WHEN** (a) Runtime: AC-13 covers ✓ AND (b) CI lint: AC-14 covers ✓ AND (c) Export-template strip: editor-only code blocks (marked with `OS.has_feature("editor")`) confirmed stripped from release `.pck` binary (binary diff vs debug build shows DEBUG_OVERRIDE block absent)
  - **THEN** All three defenses pass independently — failure of any one layer 即係 FR-3 violation；blocking story to remove `StatSource.DEBUG_OVERRIDE` enum value altogether 之前 ship release
  - Source: FR-3, Rule 10 (all three layers) | Test Type: integration (binary inspection + AC-13 + AC-14 composite) | Gate: ADR-RATIFICATION-GATED (ADR-003 Accepted + export pipeline tooling complete) | Path: `tests/integration/stat_system/test_fr3_debug_override_triple_defense.gd` + `tools/ci/check_release_binary_strips_debug_override.sh`

### Coverage Map

| Source | AC IDs |
|--------|--------|
| Rule 1 (LOCKED stat surface) | AC-01 |
| Rule 2 (Closed mutation API) | AC-02, AC-03 |
| Rule 3 (StatSource enum) | AC-04 |
| Rule 4 (Source/stat allow-list + caller whitelist) | AC-03, AC-05, AC-06 |
| Rule 5 (Equipment modifier transient) | AC-06, AC-07 |
| Rule 6 (Observer pattern broadcast) | AC-08 |
| Rule 7 (Persistence contract + flush policy) | AC-09 |
| Rule 8 (Boot reconciliation) | AC-10, AC-11, AC-12 |
| Rule 9 (VOLUME_TICK batching) | AC-09 (debounce side), AC-23 |
| Rule 10 (DEBUG_OVERRIDE triple defense) | AC-13, AC-14, AC-37 |
| Rule 11 (Clamping) | AC-15, AC-16 |
| Rule 12 (Anti-decay) | AC-17 |
| Rule 13 (Atomic write sequence) | AC-18, AC-19 |
| Rule 14 (Suspended gate) | AC-20 |
| Rule 15 (Single-character scope) | — (no testable runtime invariant; covered by Rule 1 LOCKED schema) |
| Rule 16 (Telemetry signals) | AC-21, AC-22 (+ telemetry side-effects in AC-12/13/15/16/17/20) |
| Formula 1 (VOLUME_TICK) | AC-23 |
| Formula 2 (PR_BREAKTHROUGH) | AC-24, AC-25 |
| Formula 3 (MAX_HP) | AC-26 |
| Formula 4 (ATTACK_POWER) | AC-27 |
| Formula 5 (MOVE_SPEED) | AC-28 |
| Formula 6 (CRIT_CHANCE) | AC-29 |
| CF-1 Default Baseline | AC-26, AC-27, AC-30 |
| CF-3 Stat-only Caps Reachable | AC-31 |
| INV-1 (PR_BASE × 2 < 50) | AC-30 |
| INV-2 (diminishing at MAX) | AC-25 |
| INV-3 (HP baseline) | AC-30 |
| INV-4 (ATK_PER_DEX < ATK_PER_STR/2) | AC-30 |
| INV-5 (ATK baseline) | AC-30 |
| INV-6 (MOVE_CAP reachable) | AC-31 |
| INV-7 (MOVE_CAP ≤ camera) | — (cross-system; defer to #7 Camera GDD AC) |
| INV-8 (DEX_FOR_MAX_CRIT range) | AC-31 |
| INV-9 (knobs in safe range) | AC-32 |
| EC-01 First boot | AC-10 |
| EC-03 Partial keys | AC-11 |
| EC-04 NaN/Inf | AC-12 |
| EC-09 Source/stat mismatch | AC-05 |
| EC-12 VOLUME_TICK negative | AC-17 |
| EC-13 PR at MAX | AC-25 |
| EC-22 Re-entrance | AC-33 |
| EC-26 Stat hits 0 | AC-15 |
| EC-27 Stat hits MAX | AC-16 |
| EC-29 Plain `.connect` lint | AC-34 |
| FR-1 StatSource exhaustive | AC-35 |
| FR-2 EQUIPMENT real-PR anchor | AC-36 |
| FR-3 DEBUG_OVERRIDE strip | AC-37 (composite of AC-13 + AC-14 + binary check) |

> **Section order note**: Open Questions section appears above (line 725) per drafting workflow; standard skill skeleton positions it after Acceptance Criteria. Content authoritative; positioning idiosyncratic but acceptable per Foundation/Core tier precedent.
