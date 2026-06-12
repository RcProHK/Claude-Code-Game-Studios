# Story 002: Telemetry autoload scaffold + 5-state FSM + connect_for_initial_state bootstrap

> **Epic**: Telemetry / Analytics(#28)
> **Status**: ✅ Complete(2026-06-12 — 5-state FSM + cfis GSM bootstrap; integration GUT 8/8, 35 asserts; illegal-transition reject + FLUSHING-fail→ACTIVE + cfis COMBAT_ACTIVE back-fill + zero-custom-signal all green)
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — §States and Transitions(5-state FSM)+ Rule 13(order-resilient late boot)。
**ADR Governing Implementation**: ADR-0006 State Machine Contract(primary)+ ADR-0008
**ADR Decision Summary**: Contract 6 `connect_for_initial_state` 令 late-join subscriber boot 即收 #1 GSM current_state back-fill;Contract 4 autoload `_ready()` 內唔 emit。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 5-state FSM 純內部,唔 expose gameplay signal。

**Control Manifest Rules (Polish layer)**:
- Required: GSM subscription 用 `connect_for_initial_state`(Contract 6)
- Forbidden: `_ready()` 內 emit signal;telemetry emit 任何 gameplay signal(G-TEL-2)
- Guardrail: handler O(1) non-blocking(Rule 2)

---

## Acceptance Criteria

- [ ] `src/autoload/telemetry.gd` 建立,thin observer Node,5-state FSM:`BOOTING / ACTIVE / FLUSHING / SUSPENDED / DEGRADED`
- [ ] `_ready()` subscribe upstream(stub 連接點)+ `connect_for_initial_state` 訂 #1 GSM `state_changed`,back-fill `current_state`
- [ ] BOOTING → ACTIVE transition(subscribe 完成後)
- [ ] FLUSHING 失敗唔轉 error state —— 留 ACTIVE(buffer 保留 + backoff stub)
- [ ] FSM transition 表 6 條 path 全部可達 + 非法 transition reject
- [ ] 內部 state 唔 expose 俾 gameplay(無 public gameplay signal)

---

## Implementation Notes

*Derived from ADR-0006 Contract 6 + GDD States:*

- 用 `connect_for_initial_state`(GSM helper)而非裸 `state_changed.connect` —— boot 即收當前 state，`game_state` envelope stamp 由第一個 event 起準確（Rule 13）。
- FSM 用 enum + match;transition 入口集中(single `_transition_to(next)` method 帶非法 reject)。
- DEGRADED 入場條件留 stub(Story 016 接 private-mode/opt-out);FLUSHING 留 stub（Story 011 接真 flush）。
- 本 story 唔接真 upstream signal handler（Story 008/009/010）—— 只建 scaffold + GSM cfis + FSM。

---

## Out of Scope

- Story 003:event envelope schema / de-id
- Story 008/009/010:真 upstream subscription handler
- Story 011:真 flush;Story 016:DEGRADED 入場

---

## QA Test Cases

- **AC-1 (FSM states + transitions)**:
  - Given: telemetry instance（mock GSM injected）
  - When: 觸發各 transition trigger
  - Then: BOOTING→ACTIVE / ACTIVE→FLUSHING→ACTIVE(ack)/ FLUSHING-fail→ACTIVE(buffer 留)/ ACTIVE→SUSPENDED→ACTIVE / ACTIVE→DEGRADED;非法 transition reject
  - Edge cases: 重複 transition 同一 state = no-op
- **AC-2 (connect_for_initial_state back-fill)**:
  - Given: mock GSM current_state = `COMBAT_ACTIVE`，telemetry late-boot subscribe
  - When: `_ready()` 完成
  - Then: telemetry 內部 `_current_game_state == COMBAT_ACTIVE`(back-filled,非等下一個 state_changed)
  - Edge cases: GSM 未就緒回 sentinel → `&"UNKNOWN"`（EC-10，Story 016 詳測）
- **AC-3 (no gameplay emit)**:
  - Given: telemetry source
  - When: `get_signal_list()` 列舉
  - Then: 零 gameplay signal（G-TEL-2 lint 另 Story 013 守，此處 runtime 斷言）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/telemetry/test_autoload_scaffold_fsm.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001(autoload registered Last)
- Unlocks: Story 003 / 004 / 008 / 009 / 010
