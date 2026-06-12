# Story 007: Step 1 Connect(WELCOME)+ welcome coach-mark + step_connect latch

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Rule 3.1 / AC-06 / AC-19 / EC-02 / EC-16;#24 host 關係)
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR-0006: State Machine Contract(primary)
**ADR Decision Summary**: GSM landing state 偵測經 `connect_for_initial_state`;connect proxy = GSM 離 BOOTING 落 non-auth landing。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: connect-success 確切 signal = Q-OB-6 epic-time grep #2 surface（`gym_sys_backend_client.gd` session-established signal）;MVP 用 GSM 離 BOOTING 落 landing 作 proxy。#24 owns login surface — onboarding **唔** reimplement login。

**Control Manifest Rules(this layer)**:
- Required: connect 偵測經 #1 GSM landing + #2 session（observe）
- Forbidden: reimplement login（#24 owns surface）;login error UX（#24 owns）
- Guardrail: login 反覆失敗 → onboarding 留 WELCOME 靜觀,零顯示

---

## Acceptance Criteria

- [ ] **AC-06** — GIVEN `WELCOME` 且 connect 成功（GSM 離 BOOTING + session established）,WHEN observe,THEN latch `step_connect`、顯示 welcome coach-mark（非 workout-critical 時）。
- [ ] **AC-19** — GIVEN connect 嗰刻真實 workout 已 active,WHEN `step_connect` latch,THEN **skip PREVIEW** 直入 `COACHING`（EC-02）。
- [ ] **EC-16** — 玩家連登入都未成功（GSM 永留 BOOTING/auth）→ onboarding 留 `WELCOME` 靜觀,零顯示;login error UX 由 #24 own。
- [ ] welcome coach-mark copy「連好喇 — 睇下你個角色」（data-driven localized）,dismissible;dismiss/auto → latch `step_connect`。

---

## Implementation Notes

*Derived from ADR-0006:*

- `_on_state_changed`:GSM BOOTING → landing(non-auth)edge = connect proxy → 若 `step_connect` 未 set + may_show → 顯示 welcome coach-mark。
- **AC-19 真實優先**:connect 嗰刻若 `#9 workout_started_forwarded` 已 fire / GSM workout-系 state → `step_preview` latch as done-by-workout,WELCOME → COACHING（skip PREVIEW,EC-02）。
- **EC-16**:GSM 留 BOOTING → 零顯示,靜觀;#24 處理 login error。
- welcome coach-mark 經 story 013 overlay render + story 006 dismiss timer。

---

## Out of Scope

- Story 008: PREVIEW（呢個 story latch step_connect → 正常去 PREVIEW;AC-19 異常去 COACHING）。
- Story 013/014: coach-mark 視覺 / a11y（呢度只 trigger + latch 邏輯）。
- Q-OB-6: connect-signal 確切 edge（MVP GSM proxy;epic-time grep #2 — 留 follow-up）。

---

## QA Test Cases

**AC-06(connect → welcome)**:
- Given: FSM=WELCOME, step_connect=false, GSM=BOOTING
- When: GSM transition BOOTING→IDLE(landing) + session established(FakeGSM/Fake#2)
- Then: step_connect latched;welcome coach-mark 顯示（非 critical 時）→ FSM PREVIEW
- Edge cases: connect 時 GSM=WORKOUT_ACTIVE → AC-19 skip PREVIEW → COACHING

**EC-16(login fail)**:
- Given: GSM 留 BOOTING（login 反覆失敗）
- When: observe
- Then: FSM 留 WELCOME;零 coach-mark 顯示
- Edge cases: 多次 BOOTING re-enter 唔 latch step_connect

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/onboarding_flow/test_step1_connect.gd`（AC-06/19 + EC-16,FakeGSM landing edge）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004（latch persist）+ Story 005（may_show）
- Unlocks: Story 008（PREVIEW）
