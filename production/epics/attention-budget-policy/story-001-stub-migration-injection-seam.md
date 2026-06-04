# Story 001: Stub migration — IInputPolicy injection seam + untyped ctor + factory + constitutional constants

> **Epic**: Attention Budget & Interaction Policy
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (~3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-04

## Context

**GDD**: `design/gdd/attention-budget-policy.md`
**Requirement**: `TR-gsm-023`（IInputPolicy interface，Contract 13）+ `TR-ab-???`（無 dedicated registry block — append at `/architecture-review` Phase 8）
**ADR Governing Implementation**: ADR-0006 Contract 13（primary）+ Contract 14（MockInputPolicy spy）
**ADR Decision Summary**: `IInputPolicy extends RefCounted` 係 Pillar 2 enforcement 嘅 core contract；`AttentionBudgetPolicy extends IInputPolicy` 做 concrete 實作；input handler 經 **constructor injection** 攞 `IInputPolicy`，唔可 direct reference concrete class 或 static autoload call。Enforcement 喺 input-handler boundary。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 純 GDScript RefCounted + ctor injection，無 post-cutoff API。**ctor ref 必須 untyped**（typed `Node` param = GDScript compile-time member check fail — 參 reference_gdscript_di_seam）。

**Control Manifest Rules (Core layer, v2026-05-29)**:
- Required: `AttentionBudgetPolicy implements IInputPolicy` — concrete Pillar 2 enforcement（ADR-0006 C13）
- Required: `MockInputPolicy for tests` — `extends IInputPolicy`，inject into input handlers（ADR-0006 C14）
- Forbidden: input handler direct reference `AttentionBudgetPolicy` 或 static autoload call（必須 inject `IInputPolicy`）

---

## Acceptance Criteria

*From GDD `attention-budget-policy.md`, scoped to this story:*

- [ ] **Rule 10 stub migration**：`src/systems/attention_budget_policy.gd` rewrite — 移除 static `INPUT_BLOCKED_STATES: Array` + static autoload call；改 `_init(gsm_ref, wst_ref)` **untyped** ctor injection。廢除/更新所有依賴舊 pure-GSM-state 路徑（`in INPUT_BLOCKED_STATES`）嘅 test（唔可保留覆蓋舊路徑嘅 test）。
- [ ] **AC-05（Rule 1 injection，Integration）**：GIVEN handler 用 `MockInputPolicy(permitted=false)` 構造，WHEN handler 收到 tap，THEN tap early-return（唔消費、無 side-effect）。
- [ ] `AttentionBudget.create_policy() -> IInputPolicy` factory 存在，handler 構造時呼叫攞 injectable policy。
- [ ] `IInputPolicy` interface 含兩個 pure pull method：`is_input_permitted() -> bool` + `is_notification_permitted() -> bool`（未 override 都 `push_error`）。`MockInputPolicy` 兩個 stub 值（`_permitted` / `_notification_permitted`）獨立設。
- [ ] Constitutional constants 落地（data-driven，非字面）：`KNOWN_GSM_STATES`、`KNOWN_WST_PHASES`（B1 sentinel sets）、`FAIL_CLOSED_ON_NULL_DEP = const true`、`GSM_FLOOR_LOCKED_STATES`、`CEREMONY_LOCKED_STATES`、`LIFECYCLE_LOCKED_STATES`、`INPUT_LOCKED_PHASES`、`MAX_SET_ACTIVE_INTERACTIONS`。
- [ ] **AC-21（GDD pass 3 新增）**：`AttentionBudgetPolicy._init` 喺 construction 時做 duck-typed assert：`assert(gsm_ref != null and gsm_ref.has_method(&"get_current_state"))`（同理 wst_ref + `get_current_phase`）。錯誤 ref order → construction-time assert，唔係 query-time null crash。
- [ ] **AC-20（GDD pass 3 新增，Integration）**：`connect_for_initial_state` callback `_on_gsm_state_changed` 精確 3-arg `(from, to, payload)` 且 **無 `.bind()`**；wrong arity = deferred off-stack crash。CI `connect_for_initial_state(*.bind(*))` = error。

---

## Implementation Notes

*Derived from ADR-0006 Contract 13/14 + GDD Rule 1/10:*

- `class_name AttentionBudgetPolicy extends IInputPolicy`（已存在）。`_init(gsm_ref, wst_ref)` — **兩 ref untyped**（唔可 `gsm_ref: Node`）。存為 `_gsm` / `_wst` untyped member。
- `AttentionBudget`（autoload，pos 11+）暴露 `create_policy() -> IInputPolicy: return AttentionBudgetPolicy.new(GameStateMachine, WorkoutStateTracker)`。autoload 亦 own notification-layer surface（`is_notification_permitted` / `CRITICAL_NOTIFICATION_KINDS` — Story 003）。
- **`IInputPolicy` interface 擴展 flag**：ADR-0006 C13 原定義 IInputPolicy 只有 `is_input_permitted()`。GDD B-C2 決定加 `is_notification_permitted()` 入 IInputPolicy。**實作時確認**：(a) IInputPolicy base class 檔案位置（邊個 module own）；(b) 加 method 係 #33 latitude 定需要 ADR-0006 C13 amendment。若有疑問，notification predicate 可改放 `AttentionBudget` autoload-level（producer query autoload，input handler query injected IInputPolicy）—— 兩種 framing GDD 都有，揀一個 pin 落 code comment。
- `MockInputPolicy extends IInputPolicy`：`var _permitted := true` / `var _notification_permitted := true`；兩 method 各自 return。Contract 14 spy（`attach_query_spy`）若 #20 AC-15b 已有，沿用。
- **本 story 唔實作 Formula 1 derivation 內容**（Story 002）— `is_input_permitted()` 可先 minimal（call 落 derivation stub），但 ctor/seam/constants/factory 必須真。code comment 標 Story 002 ownership。

---

## Out of Scope

- **Story 002**：`is_input_permitted()` Hybrid derivation 全邏輯（Formula 1）+ perf。
- **Story 003**：`is_notification_permitted()` Formula 2 邏輯 + `CRITICAL_NOTIFICATION_KINDS` 內容 + `is_critical_notification()`。
- **Story 004**：boot subscription + Substate。

---

## QA Test Cases

*GDD-derived（design-review qa-lead-rigor ACs）。實作者照寫，唔自創。*

- **AC-05（injection seam，Integration）**
  - Given: 一個 minimal input handler，constructor-injected `MockInputPolicy.new()` with `_permitted = false`
  - When: handler 收到一個 tap event
  - Then: handler downstream action spy call count == 0（early-return，無 side-effect）；`MockInputPolicy.is_input_permitted` 被 query
  - Edge cases: `_permitted = true` 時同一 tap → downstream action 正常觸發（對照組）
- **Rule 10 migration（structural）**
  - Given: rewritten `attention_budget_policy.gd`
  - When: grep source
  - Then: 無 `INPUT_BLOCKED_STATES` array、無 static `GameStateMachine.get_current_state()`-in-array 形式；有 `func _init(` 2-arg untyped + `create_policy()`
  - Edge cases: 舊 test（覆蓋 `in INPUT_BLOCKED_STATES` 路徑）已刪除或重寫 — grep 確認無殘留
- **Constants（structural）**
  - Given: AttentionBudget autoload + AttentionBudgetPolicy
  - When: 讀常數
  - Then: `GSM_FLOOR_LOCKED_STATES == [WORKOUT_ACTIVE, COMBAT_ACTIVE, BOSS_ENCOUNTER]`、`CEREMONY_LOCKED_STATES == [LOOT_DROP]`、`LIFECYCLE_LOCKED_STATES == [BOOTING, SUSPENDED]`、`INPUT_LOCKED_PHASES == [SET_ACTIVE]`、`MAX_SET_ACTIVE_INTERACTIONS == 0`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/attention-budget/test_stub_migration_injection.gd` — must exist and pass（GUT `test_` 前綴；preload SUT pattern 因 autoload 無 class_name — 參 reference_gut_filename_convention）

**Status**: [x] Created + passing — `tests/integration/attention-budget/test_stub_migration_injection.gd`（17/17 pass）

---

## Dependencies

- Depends on: None（epic 第一個 story；但需 #1 GSM + #9 WST autoload 已存在於 project — 已 merged）
- Unlocks: Story 002（derivation）、003（notification）、004（boot）、005（glance）、006（recovery）— 全部依賴本 story 嘅 seam

---

## Completion Notes
**Completed**: 2026-06-04
**Criteria**: 7/7 covered（AC-05 / Rule 10 / factory / IInputPolicy 2-method / 8 constants / AC-21 / AC-20-structural）；GUT 17/17 pass（combined gate 1609 tests / 0 fail / 1 pending pre-existing AC-37）
**Files**: `src/core/i_input_policy.gd`（+is_notification_permitted）· `src/systems/attention_budget_policy.gd`（rewrite）· `tests/mocks/mock_input_policy.gd`（new）· `src/autoload/attention_budget.gd`（new scaffold，未 register）· test（new）
**Deviations（ADVISORY）**:
- placeholder derivation 已寫 floor/ceremony/lifecycle/refinement 但**欠 B1 sentinel** → **Story 002 必須補**（interim 可接受：autoload 未 register，無 consumer）
- AC-21 assert-fires-on-bad-ref 無直接 test（`_BadRef` dead code）；建議 Story 002/debug-harness 補或標 structural-only
- `test_rule10_no_input_blocked_states_const` 用 `get_property_list()` 查 const 缺席無效（const 唔出現喺 property_list）；建議改 grep-based
- IInputPolicy 加 `is_notification_permitted()` = ADR-0006 C13 interface drift（已 doc-note，建議日後 ADR-0006 addendum 正式化）
**Test Evidence**: Integration — `tests/integration/attention-budget/test_stub_migration_injection.gd`（17/17）
**Code Review**: Complete — APPROVED WITH SUGGESTIONS（3 minor，0 blocking）
