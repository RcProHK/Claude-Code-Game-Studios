# Story 002: `is_input_permitted()` Hybrid derivation + hot-path perf

> **Epic**: Attention Budget & Interaction Policy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-04

## Context

**GDD**: `design/gdd/attention-budget-policy.md`
**Requirement**: `TR-gsm-023`（IInputPolicy derivation from GSM）+ `TR-ab-???`
**ADR Governing Implementation**: ADR-0006 Contract 13
**ADR Decision Summary**: `is_input_permitted()` derives from `GameStateMachine` current state（read-only）；state machine = source of truth，policy = gate。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GSM 只有 `get_current_state()` method（**冇** `.current_state` property — design-review godot R-6 + main-RED 先例）；WST 只有 `get_current_phase()`。Enum `in Array[int]` membership 唔 allocate（lock set 預建 const）。

**Control Manifest Rules (Core layer, v2026-05-29)**:
- Required: `AttentionBudgetPolicy.is_input_permitted()` derives from GSM current state（ADR-0006 C13）
- Forbidden: cache gate state（pure-pull only — GDD Rule 2）

---

## Acceptance Criteria

*From GDD `attention-budget-policy.md`, Formula 1, scoped to this story:*

- [ ] **AC-01a（GSM floor）**：GSM ∈ {`WORKOUT_ACTIVE`,`COMBAT_ACTIVE`,`BOSS_ENCOUNTER`} → `false`，對所有 WST phase（floor 憲法鎖，phase 唔 override）。
- [ ] **AC-01b（WST refinement）**：GSM ∉ floor ∉ lifecycle（如 `IDLE`）AND phase == `SET_ACTIVE` → `false`。
- [ ] **AC-19（ceremony lock）**：GSM == `LOOT_DROP` AND phase ≠ `SET_ACTIVE` → `false`（對齊 locked GSM AC-11b；loot modal dismiss tap 屬 #21 exempt handler，唔經本 predicate）。
- [ ] **AC-02（lifecycle）**：GSM == `SUSPENDED` → `false`；GSM == `BOOTING` → `false`。
- [ ] **AC-03（default-open）**：GSM ∈ {`IDLE`,`REST_PERIOD`(GSM),`DISCONNECTED`} AND phase ∈ {`IDLE`,`WARM_UP`,`REST_PERIOD`,`WORKOUT_COMPLETE`} → `true`。
- [ ] **AC-09（EC-3 disagree）**：GSM == `IDLE` AND phase == `SET_ACTIVE` → `false`（WST refinement 收緊；AC-01b 之 IDLE instance）。
- [ ] **AC-04（pure-pull）**：兩次 query 之間直接 mutate mock GSM/WST 值（**唔送 signal**），第二次 query 反映新值（證明無 cache）。
- [ ] **AC-10（fail-closed）**：injected GSM ref == null AND `FAIL_CLOSED_ON_NULL_DEP == true` → `false`（null guard named expression 最高優先）。
- [ ] **AC-17a（perf structural，BLOCKING）**：`is_input_permitted()` body 無 allocating 構造（無 inline Array/Dict literal、無 `.new()`、無 string concat、無 closure capture）；O(1)。CI static grep 驗證。
- [ ] **AC-17b（perf runtime，ADVISORY）**：profiler heap-alloc baseline diff ≈ 0（noise-tolerant，非 deterministic gate）。

---

## Implementation Notes

*Derived from GDD Formula 1:*

```
is_input_permitted() =
    IF (gsm_ref == null OR wst_ref == null) AND FAIL_CLOSED_ON_NULL_DEP: RETURN false   # null guard 最高優先（fail-closed，防 fail-OPEN）
    NOT ( gsm_state ∈ GSM_FLOOR_LOCKED_STATES
          OR gsm_state ∈ CEREMONY_LOCKED_STATES        # {LOOT_DROP}
          OR gsm_state ∈ LIFECYCLE_LOCKED_STATES       # {BOOTING, SUSPENDED}
          OR wst_phase ∈ INPUT_LOCKED_PHASES )         # {SET_ACTIVE}
```

- `gsm_state = _gsm.get_current_state()`；`wst_phase = _wst.get_current_phase()` —— 每次 call 即時 pull，**唔存 member**（Rule 2）。
- Null guard **必須喺 named expression 內最高 precedence**（B-B3）：若寫成 `NOT(... null == SET_ACTIVE ...)` 會 fail-OPEN。先 explicit null check return false。
- 所有 lock set 用 Story 001 嘅 const（唔字面 hardcode enum）。
- AC-17a：`is_input_permitted()` 內**唔可**有 `[]` / `{}` / `.new()` / `"%s"` —— 全部係 enum read + `in` const-array + bool。CI grep ban 呢啲 token 喺此 method body。

---

## Out of Scope

- **Story 001**：seam / ctor / factory / constants 定義（本 story 假設已存在）。
- **Story 003**：`is_notification_permitted()`（Formula 2，多 LOOT_DROP 之外仲有不同 term）。
- **Story 006**：suspend→resume recovery 嘅 Integration 驗證（本 story 只驗 derivation 純邏輯）。

---

## QA Test Cases

*GDD-derived。實作者照寫。全部用 mock GSM/WST 注入 live enum 值，無 signal。*

- **AC-01a**: Given GSM=WORKOUT_ACTIVE / COMBAT_ACTIVE / BOSS_ENCOUNTER（各一）+ phase ∈ {IDLE,WARM_UP,REST_PERIOD,WORKOUT_COMPLETE}（cartesian）; When query; Then 全 `false`. Edge: floor × SET_ACTIVE 亦 false（double-lock）。
- **AC-01b / AC-09**: Given GSM=IDLE + phase=SET_ACTIVE; When query; Then `false`. Edge: GSM=DISCONNECTED + phase=SET_ACTIVE → false。
- **AC-19**: Given GSM=LOOT_DROP + phase ∈ {IDLE,WARM_UP,REST_PERIOD,WORKOUT_COMPLETE}; When query; Then `false`. Edge: LOOT_DROP + SET_ACTIVE → false（仍 lock）。
- **AC-02**: Given GSM=SUSPENDED（phase 任意非 SET_ACTIVE）; When query; Then `false`. And GSM=BOOTING → false。
- **AC-03**: Given GSM ∈ {IDLE,REST_PERIOD(GSM),DISCONNECTED} + phase ∈ default set; When query; Then `true`. Edge: REST_PERIOD GSM + REST_PERIOD phase → true（set 完一 tap window）。
- **AC-04**: Given query 一次（mutate mock GSM IDLE→WORKOUT_ACTIVE，唔 emit signal）; When 再 query; Then 第二次 false（反映新值，證無 cache）。
- **AC-10**: Given `_gsm = null` + FAIL_CLOSED_ON_NULL_DEP=true; When query; Then `false`. Edge: `_wst = null` 同樣 false。
- **AC-17a**: Given method source; When CI grep `is_input_permitted` body; Then 無 `\[\]` / `\{\}` / `\.new\(` / string-format token。
- **AC-17b（ADVISORY）**: Given 1000× query loop; When 量 `Performance.get_monitor(MEMORY_STATIC)` baseline diff; Then ≈ 0（noise-tolerant，非 hard assert）。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/attention-budget/test_input_permitted_derivation.gd` — must exist and pass

**Status**: [x] Created + passing — `tests/unit/attention-budget/test_input_permitted_derivation.gd`（29/29 pass）

---

## Dependencies

- Depends on: Story 001（seam + constants + factory）DONE
- Unlocks: Story 006（recovery 用本 derivation）

---

## Completion Notes
**Completed**: 2026-06-04
**Criteria**: 全 covered — AC-01a（cartesian incl SET_ACTIVE double-lock）/ AC-01b / AC-02 / AC-03（incl REST+REST one-tap）/ AC-04 pure-pull / AC-09 / AC-10 fail-closed / AC-19 ceremony / AC-17a structural（source grep zero-alloc）/ AC-17b ADVISORY（1000× mem diff noise-tolerant）。**B1 sentinel 已接入 + 6 regression tests**（invalid int 999/-1/超界 → fail-closed，關閉 Story 001 placeholder 嘅 fail-OPEN 漏洞）。
**GUT**: 29/29 pass（attention-budget dir 46/46 = 001:17 + 002:29）；combined gate 254 scripts / 1638 tests / 1637 pass / 0 fail / 1 pending（pre-existing AC-37）。
**Files**: `src/systems/attention_budget_policy.gd`（finalize is_input_permitted：null→sentinel→Hybrid；移走 TODO）· `tests/unit/attention-budget/test_input_permitted_derivation.gd`（new，29 tests）。
**Carry-over 處理**: Story 001 嘅 rule10 const-check（get_property_list 無效）→ 本 story 新 test 用 grep-based + 剔 comment 行修正（1 個 test fix iteration：原 grep 埋 doc comment 誤判，改剔 `#` 行後 green）。
**仍 ADVISORY（未做）**: Story 001 AC-21 assert-fires-on-bad-ref 直接 test（`_BadRef` dead code）—— 留作 test-debt，非 blocking（construction good-path + null-guard 已測）。
**Test Evidence**: Logic — `tests/unit/attention-budget/test_input_permitted_derivation.gd`（29/29）。
**Code Review**: Pending（lean — 與 Story 001 一致已過靜態 review pattern；建議 sprint close 前批量 /code-review 002-006）。
