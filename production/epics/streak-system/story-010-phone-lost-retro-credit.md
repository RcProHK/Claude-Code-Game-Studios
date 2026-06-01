# Story 010: Phone-Lost Retro-Credit Integration Test (AC-37 / FR-1)

> **Epic**: StreakSystem
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/streak-system.md`
**Requirement**: `TR-streak-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save State Strategy, **Accepted 2026-05-30**) primary; ADR-0002 (GymSys Integration Protocol, **Accepted data-contract 2026-05-31**) secondary
**ADR Decision Summary**: ADR-0002 differential event cursor（`GET /api/game/state?last_event_id={N}&server_epoch_id={E}`）IS the retro-credit delivery mechanism — phone offline → reconnect → poll with stored `last_event_id` → backend returns missed `workout_completed` events in `event_id` order。ADR-0003 Accepted 解除 Q-O2/Q-R1 ADR gate。本 story 驗證 **Streak-side acceptance contract**：當 GymSys 按序 deliver retro event（過去 timestamp）再 current event，Rule 4 monotonicity gate 接受兩者（Day30 < Day32），Rule 6 consecutive-day classification 正確 credit。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: **Mock-scoped headless test**（跟 #9 WST story-012 mock-GymSys pattern）。inject mock `GymSysBackendClient` stub（emit `workout_completed(completed_at_utc)` signal 按序），驗證 Streak Rule 4 + Rule 6 行為。**Live-backend cursor replay 驗證（GymSys 真係按 `last_event_id` 補 emit missed events）係 ADR-0002 VS-tier scope，OUT OF SCOPE** — 本 story 只驗 Streak 收到按序 retro event 之後 credit 正確。`completed_at_utc` 過去 timestamp（< device_now）→ `future_skew` negative → drift gate pass（drift gate 只防 future-skew tamper，past 永遠 OK，per Rule 4 rationale）。

**Control Manifest Rules (Foundation layer)**:
- Required: retro event（past timestamp，按序 deliver）→ accept + credit per Rule 6
- Forbidden: 因 `completed_at_utc` 喺過去就 reject（會違反 Phone-Lost dignity）
- Guardrail: monotonic-but-past retro events 唔可以 double-credit 同一 calendar day

---

## Acceptance Criteria

*From GDD Section H, scoped to this story（AC-37 structure unblocked by ADR-0003 Accepted；assertions grounded in the SHIPPED surface — see Implementation Notes）:*

> **GDD-vs-impl reconciliation (2026-06-01)**: 實作 Stories 001-008 嘅 streak 只 track `_streak_count` + `_last_workout_date_local`，derive `get_streak_buff_multiplier()`；**冇** `streak_changed` / `streak_milestone_reached` signal，**冇** milestone-unlocked Array（GDD Rule 7 嗰啲未實作）。AC-37 因此 assert COUNT + buff MULTIPLIER + drift-gate acceptance，唔 assert 唔存在嘅 signal/Array。**Drift gate 修正**：原實作對稱 `abs≤300`（reject 過去），呢個 story revise 咗 Story 002 嘅 `_passes_drift_gate` 為 GDD Rule 4 directional（future-skew-only + monotonicity anchor `_last_accepted_completed_at_utc`），先令 retro past event 通過。

- [ ] **AC-37** [FR-1 / Rule 4 directional / Falsifiable Test #3] — GIVEN `_streak_count==29`, `_last_workout_date_local==20260429`, `_now_utc_override==Day32`，THEN：(a) retro `_on_workout_completed(Day30_utc)`（2 日前）→ drift gate ACCEPT（`streak_persistence_failed` NOT emitted）；Day29→Day30 consecutive → `_streak_count==30`，`get_streak_buff_multiplier()==1.6`；(b) `_on_workout_completed(Day32_utc)`（monotonic）→ Day30→Day32 gap → `_streak_count==1`，buff `==1.1`（forward-pull，current state）。
- [ ] **AC-37a** [directional gate] — `_passes_drift_gate(now - 5*86400)` → PASS（過去 5 日 retro 接受）；`_passes_drift_gate(now + 400)` → REJECT（future skew > tolerance，anti clock-forward tamper）。
- [ ] **AC-37b** [no double-credit] — 同一 local calendar day 收到兩個 monotonic `_on_workout_completed`（utc 遞增、同日）→ 第二個 `record_today_workout` idempotent no-op，`_streak_count` 不變。

---

## Implementation Notes

*Derived from ADR-0003 + ADR-0002 cursor + GDD Rule 4/6/12:*

- Mock `_GymSysStub extends RefCounted`（或 Node）暴露 `signal workout_completed(completed_at_utc: int)`；test inject 入 SUT 取代 autoload ref（DI seam）。SUT `_on_workout_completed` 已實作（Story 003），呢度只驗 integration 行為。
- timestamps：用固定 fixture（deterministic，no `Time.get_unix_time_from_system()` 直接斷言 — 但 drift gate 內部會 call，所以 retro timestamp 要設成相對 `device_now` 明確喺過去，e.g. `device_now - N*86400`）。**注意**：drift gate 用 device wall-clock 算 future_skew；test 要確保 fixture timestamp 喺過去（負 skew）令 gate pass。monotonicity guard（`_last_accepted_completed_at_utc`）要按序 feed。
- local-day conversion 用 fixed `_local_timezone_offset_minutes`（e.g. UTC+0 / +480 HK）令 calendar-day boundary deterministic。
- 驗證序列：seed `_streak_count=29` + `_last_workout_date_local` + `_last_accepted_completed_at_utc`（Day29）→ emit Day30 → assert 30 + milestone → emit Day32 → assert reset-to-1 + milestone Array 保留 30。

---

## Out of Scope

*Handled by neighbouring stories / other epics:*

- **ADR-0002 VS-tier**: live GymSys backend 真係按 `last_event_id` cursor 補 emit missed events（network-level retro delivery）— 屬 #2 GymSysBackendClient live-transport validation，唔喺 Streak 呢度
- Story 009: AC-39 caller whitelist CI
- AC-38（FR-2 drift FPR threshold）: 仍 DEFERRED — 需 VS-tier ≥100-session playtest telemetry + ADR 定義 acceptable rate；headless 測唔到 false-positive RATE

---

## QA Test Cases

> **Seams**: mock `GymSysBackendClient`（`workout_completed` signal，按序 emit）；`_streak_count`/`_last_workout_date_local`/`_last_accepted_completed_at_utc`/`_streak_milestones_unlocked` seedable；`_local_timezone_offset_minutes` fixed；`watch_signals(_sut)`。retro timestamp = `device_now - N*86400`（保證過去）。

- **AC-37**: phone-lost retro-credit sequence
  - Given: seed `_streak_count=29`, `_last_workout_date_local=<Day29 local>`, `_last_accepted_completed_at_utc=<Day29 utc>`, `_streak_milestones_unlocked=[7,14]`；fixed tz offset；`watch_signals`
  - When: mock emit `workout_completed(<Day30 utc>)` 然後 `workout_completed(<Day32 utc>)`（按序，皆過去）
  - Then: after Day30 → `_streak_count==30` + `streak_milestone_reached(30)` emit_count==1；after Day32 → `_streak_count==1`（gap reset）；`_streak_milestones_unlocked` 含 30（保留）；無 crash；無 push_error
  - Edge: 確認 Day30 event 唔被 drift gate reject（past timestamp）；monotonicity（Day30 < Day32）pass

- **AC-37a**: past-timestamp accept
  - Given: Ready，`_last_accepted_completed_at_utc=0`
  - When: emit `workout_completed(device_now - 5*86400)`（5 日前）
  - Then: drift gate PASS；`_drift_rejected_count==0`；streak credited
  - Edge: 對比 future-skew tamper（`device_now + 400`）→ 應 reject + counter++（驗反方向）

- **AC-37b**: same-day retro no double-credit
  - Given: seed streak credited to some Day-N
  - When: 兩個 retro `workout_completed` 同一 local calendar date（monotonic utc 但同日）
  - Then: 第一個 credit；第二個 Rule 6 same-day no-op → `_streak_count` 不變；`streak_changed` 第二次唔 emit
  - Edge: same-day 第二 event utc > 第一（monotonicity pass）但 local date 相同 → idempotent

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/streak/test_phone_lost_retro_credit.gd` — must exist and pass（AC-37, 37a, 37b；`test_` prefix for GUT discovery）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003（`_on_workout_completed` handler）、Story 002（drift gate — **revised by this story**）、**ADR-0003 Accepted (2026-05-30)**、**ADR-0002 Accepted data-contract (2026-05-31)**
- Unlocks: AC-37 Streak-side closed（FR-1 Phone-Lost dignity）；live-backend cursor replay 留畀 ADR-0002 VS-tier

---

## Completion Notes
**Completed**: 2026-06-01
**Criteria**: AC-37 / 37a / 37b passing（GUT 3 integration tests green）
**Deviations**:
- **Drift gate revised** (BLOCKING fix): Story 002 `_passes_drift_gate` 由對稱 `abs≤300` 改為 GDD Rule 4 directional（future-skew-only + `_last_accepted_completed_at_utc` monotonicity anchor）。原對稱實作 reject 過去 timestamp，直接違反 AC-37/FR-1/Falsifiable Test #3（Pillar 1）。Story 002 個 `past 600 must REJECT` 斷言 flipped → PASS；加 `test_drift_gate_rejects_non_monotonic_replay`。User 批准（Option A，`/propagate-design-change` 2026-06-01）。
- **Scope grounding** (ADVISORY): GDD Rule 7 milestone signal/Array（`streak_milestone_reached`、`streak_milestones_unlocked`）唔喺 shipped code，AC assert `_streak_count` + `get_streak_buff_multiplier()` 代替。GDD Rule 2 `GymSysBackendClient.workout_completed.connect` 亦未 wire — handler 直接 invoke（同 Story 002 test 一致）。
**Test Evidence**: `tests/integration/streak/test_phone_lost_retro_credit.gd`（3 tests，mock GSM + stub persistence + pinned now）
**Code Review**: Self-review — directional gate predicate pure (no mutation); anchor advanced in handler only
