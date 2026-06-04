# Story 003: `is_notification_permitted()` + CRITICAL_NOTIFICATION_KINDS allowlist

> **Epic**: Attention Budget & Interaction Policy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (~2-3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-04

## Context

**GDD**: `design/gdd/attention-budget-policy.md`
**Requirement**: `TR-ab-???`（notification suppression — 無 dedicated registry block）
**ADR Governing Implementation**: N/A — pure GDD-defined predicate（Rule 7 / Formula 2），無 architectural pattern ADR；沿用 ADR-0006 C13 嘅 pull-method shape。
**ADR Decision Summary**: N/A（#33-internal notification policy）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 純 boolean predicate + `Array[StringName]` membership。無 post-cutoff API。

**Control Manifest Rules (Core layer, v2026-05-29)**:
- Required: pull-method shape 對齊 IInputPolicy（`is_notification_permitted() -> bool`）
- Forbidden: queue suppressed notification（GDD Rule 7 — DROP not queue；queued nag = The Nag Engine）

---

## Acceptance Criteria

*From GDD `attention-budget-policy.md`, Formula 2 + Rule 7:*

- [ ] **AC-07（Rule 7 suppress）**：phase == `SET_ACTIVE` → `is_notification_permitted()` == `false`。
- [ ] **AC-08（Rule 7 permit）**：phase == `REST_PERIOD` AND GSM ∉ suppressed set → `is_notification_permitted()` == `true`。
- [ ] **AC-18a（GDD pass 3 split，BLOCKING — Unit）**：`CRITICAL_NOTIFICATION_KINDS: Array[StringName]` closed allowlist 存在；`is_critical_notification(&"disconnect_warning")` → `true`；`is_critical_notification(&"unknown_kind")` → `false`；`is_critical_notification(&"")` → `false`。此條喺 #33 story-003 驗。
- [ ] **AC-18b（GDD pass 3 split，ADVISORY — BLOCKED-deferred #8/#28）**：producer-compliance grep —— deferred，唔喺本 story gate。
- [ ] **AC-15（drop-not-queue，ADVISORY — unit-scoped）**：mock producer callback，suppressed during `SET_ACTIVE` 時，驗證無 re-emission callback 被 schedule（producer-side mock）。完整 Integration 驗證 BLOCKED-deferred to #8/#28。
- [ ] Formula 2 多 `LOOT_DROP` suppression term（input 容許 dismiss 但 notification 唔好蓋 ceremony）。

---

## Implementation Notes

*Derived from GDD Formula 2 + Rule 7:*

```
is_notification_permitted() =
    NOT ( wst_phase == SET_ACTIVE
          OR gsm_state == BOOTING
          OR gsm_state == SUSPENDED
          OR gsm_state == LOOT_DROP )
```

- `NOTIFICATION_SUPPRESSED_STATES`（tuning knob，data-driven set `{SET_ACTIVE, BOOTING, SUSPENDED, LOOT_DROP}`）—— 注意混 phase（SET_ACTIVE）+ GSM state；實作清楚分開 query `_wst.get_current_phase()` vs `_gsm.get_current_state()`。
- `CRITICAL_NOTIFICATION_KINDS` default `[&"disconnect_warning", &"save_failed"]`（StringName）。**closed**：加非-critical kind = The Nag Engine 漏口。
- `is_notification_permitted()` 放喺邊（autoload-level vs IInputPolicy）跟 Story 001 pin 嘅決定一致。
- Rule 7：suppressed notification **DROP，唔 queue**。本 story 唔實作 producer（producer 喺 #8/#28）；只提供 predicate + allowlist + `is_critical_notification()`。

---

## Out of Scope

- **AC-18b（producer-compliance CI grep）**：BLOCKED-deferred to #8 Streak / #28 Telemetry producer epic（producer 實作後方可 grep）。
- **AC-15 完整 Integration**：deferred 同上（本 story 只 unit-scoped mock producer）。
- producer 自身 defer 邏輯（例如 #8 milestone 喺 WORKOUT_COMPLETE 重發）—— producer epic own。

---

## QA Test Cases

*GDD-derived。*

- **AC-07**: Given phase=SET_ACTIVE; When query is_notification_permitted; Then `false`. Edge: SET_ACTIVE + GSM=IDLE 仍 false（phase term 獨立）。
- **AC-08**: Given phase=REST_PERIOD + GSM=REST_PERIOD(GSM); When query; Then `true`. Edge: phase=REST_PERIOD 但 GSM=LOOT_DROP → false（LOOT_DROP term）。
- **AC-18a**: Given CRITICAL_NOTIFICATION_KINDS=[disconnect_warning, save_failed]; When is_critical_notification(&"disconnect_warning") / is_critical_notification(&"streak_nag"); Then `true` / `false`. Edge: 空 StringName &"" → false。
- **AC-15（ADVISORY unit）**: Given mock producer with re-emit spy; When suppressed during SET_ACTIVE; Then re-emit spy call count == 0（DROP，無 schedule）。
- **Formula 2 LOOT_DROP term**: Given GSM=LOOT_DROP + phase=WORKOUT_COMPLETE; When query is_input_permitted vs is_notification_permitted; Then `false`（input，ceremony lock — Story 002）vs `false`（notification）—— 本 story 只斷言 notification side。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/attention-budget/test_notification_permitted.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（seam + autoload surface）DONE
- Unlocks: None（#8/#28 producer epic 之後對接 AC-18b/AC-15 full）

---

## Completion Notes
**Completed**: 2026-06-04
**Criteria**: AC-07 / AC-08 / AC-18a 全 covered；Formula 2 full（含 WORKOUT_ACTIVE+WARM_UP→true 證 suppression 嚟自 phase term 非 GSM floor，+ contrast WORKOUT_ACTIVE+SET_ACTIVE→false）；H1 WORKOUT_COMPLETE permit；B1 sentinel 加埋落 is_notification_permitted（fail-closed 一致）。
**GUT**: 18 tests pass（attention-budget dir 63/63）；combined 255 scripts / 1655 / 1654 pass / 0 fail / 1 pending。
**Files**: `src/systems/attention_budget_policy.gd`（finalize is_notification_permitted + B1 sentinel）· `src/autoload/attention_budget.gd`（+CRITICAL_NOTIFICATION_KINDS const + is_critical_notification）· `tests/unit/attention-budget/test_notification_permitted.gd`（new，18 tests）。
**Test-fix iteration**: Story 002 AC-17a structural test 嘅 `.new(` check 原用 naive `.contains()` 冇剔 comment → Story 003 finalize doc comment 加「no .new()」字眼被 body-extraction sweep 誤判 → 修 test 用 `_method_body_has_token`（剔 comment 行，同其餘 3 check 一致）。
**Deferred（按 GDD 決定）**: AC-18b producer-compliance grep + AC-15 full drop-not-queue → #8 Streak / #28 Telemetry producer epic（#33 唔 own producer）。
**Test Evidence**: Logic — `tests/unit/attention-budget/test_notification_permitted.gd`（18/18）。
**Code Review**: Pending（lean — sprint close 前批量）。
