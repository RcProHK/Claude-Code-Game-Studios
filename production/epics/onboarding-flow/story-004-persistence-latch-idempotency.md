# Story 004: Persistence onboarding.* latch schema + per-step latch + idempotency

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Rule 2 / Rule 7 / AC-03 / AC-04 / AC-22 / EC-05 / EC-06 / EC-07）
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR-0003: Save State Strategy(primary)
**ADR Decision Summary**: backend-primary + IndexedDB secondary;`onboarding.*` namespace;detect-and-gate Private Mode;IPersistence interface。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: persistence-consumer test 喺 `add_child` **前**注入 MockPersistenceLayer([[reference_test_persistence_isolation]] — 真 autoload cache 跨 file 污染)。

**Control Manifest Rules(this layer)**:
- Required: 寫入經 #3 PersistenceLayer IPersistence;backend-primary
- Forbidden: 掂其他 namespace(只 `onboarding.*`);`window.localStorage`(ADR-0003)
- Guardrail: read fail conservative default(全 false,永不 fabricate completed)

---

## Acceptance Criteria

- [ ] **AC-03** — GIVEN 某 step latch 已 true,WHEN 該 step trigger 再 fire,THEN coach-mark 唔重顯示、latch 維持 true(恰好一次,永不重播)。
- [ ] **AC-04** — GIVEN 四 step latch 全 set,WHEN coordinator tick,THEN 寫 `onboarding.completed=true`、disconnect 全部 signal、入 `DORMANT`(terminal)。
- [ ] **AC-22** — GIVEN `onboarding.*` read 失敗,WHEN boot,THEN default 全 false(顯示 onboarding)、**永不** fabricate `completed=true`(EC-07)。
- [ ] `onboarding.*` 5 key(`completed`/`step_connect`/`step_preview`/`step_class`/`step_first_drop`,全 bool,backend-primary)read/write wire 入 coordinator;boot 用 F3(story 003)揀 resume state。
- [ ] EC-05:`step_preview` 只喺 preview 完成/skip/abort 先 latch（唔喺開始就 latch — crash 即走仍重播）。

---

## Implementation Notes

*Derived from ADR-0003:*

- coordinator `_read_persistence()` boot 讀 5 latch → F3 resume state;`_write_latch(key, true)` 經 IPersistence。
- **AC-04 DORMANT 收口**:四 latch set → 寫 completed → `disconnect` 全部 signal → FSM DORMANT(terminal,零 subscription)。
- **AC-22 conservative default**:read error → 全 false（誤顯示成本低,coach-mark dismissible）;**永不** fabricate completed=true（會令真新玩家錯過 onboarding）。backend sync 返 true 後 step 唔重 fire（latch resolve 為準）。
- inject seam:`_persistence` untyped,test 注 MockPersistenceLayer（add_child 前）。

---

## Out of Scope

- Story 003: F3 decision logic（呢個 story wire latch read/write + persist completed）。
- Story 007-010: 各 step 嘅 trigger / coach-mark（呢度只 latch persist 機制 + AC-03 idempotency 通則）。

---

## QA Test Cases

**AC-03(idempotent latch)**:
- Given: step_class==true(已 latch)
- When: `dominant_class_changed` 再 fire
- Then: coach-mark 唔重顯示;latch 維持 true
- Edge cases: 全 4 step 重複 trigger 皆 no-op

**AC-04(DORMANT 收口)**:
- Given: 四 latch 全 set
- When: coordinator tick
- Then: completed=true persisted;全 signal disconnect;FSM==DORMANT
- Edge cases: DORMANT 後再 boot → 直入 DORMANT 零 surface

**AC-22(read-fail default)**:
- Given: MockPersistence read 拋 error / 回 null
- When: boot
- Then: 全 latch default false(顯示 onboarding);completed **唔** fabricate
- Edge cases: backend 後 sync true → step 唔重 fire

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/onboarding_flow/test_persistence_latch.gd`(AC-03/04/22 + EC-05/07,MockPersistence inject-before-add_child)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（scaffold）+ Story 003（F3 resume）
- Unlocks: Story 007-010（step latch 各步）
