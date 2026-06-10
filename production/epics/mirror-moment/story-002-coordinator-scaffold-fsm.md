# Story 002: Coordinator scaffold + 4-state FSM + cfis 3-subscription + bootstrap latch rebuild

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` CR-M11 / States table(Booting/DORMANT/ARMED/PRESENTING/PAUSED)/ #26 contract block
**Requirement**: AC-17(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0006 State Machine Contract(primary — Contract 6 cfis)· ADR-0008(autoload)
**ADR Decision Summary**: Contract 6 `connect_for_initial_state` 接 boot 時已發生 signal(replay-safe);#29 orchestration FSM ≠ GSM state。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 訂 `#26.avatar_evolution_milestone(tier:int, source_metrics:Dictionary)` + `#26.avatar_micro_evolution(delta_kind:StringName, source_metrics:Dictionary)` + GSM `state_changed`。#26 早 boot(#29 tail)→ cfis 接 replay。

**Control Manifest Rules (Polish layer)**:
- Required: cfis 3 subscription(ADR-0006 C6);4-state FSM(DORMANT/ARMED/PRESENTING/PAUSED)+ Booting
- Forbidden: #29 改 GSM transition(慶典係 overlay);foreign subscription
- Guardrail: idempotent latch rebuild(replay 唔開兩次)

---

## Acceptance Criteria

- [ ] **AC-17**(CR-M11): boot 時 #26 已發出過 milestone(replay)→ `connect_for_initial_state` 接 INITIAL_STATE → latch 正確 rebuild,**唔**因 replay 開兩次慶典(idempotent boolean latch)
- [ ] `MirrorMomentCoordinator` thin autoload Node;4-state FSM(DORMANT/ARMED/PRESENTING/PAUSED)+ Booting bootstrap;**唔擁有 GSM transition**
- [ ] cfis 3 subscription:`#26.avatar_evolution_milestone`、`#26.avatar_micro_evolution`、GSM `state_changed`
- [ ] Booting:connect 3 sub + `PersistenceLayer.read("mirror_moment")` rebuild latch(`pending_evolution_ceremony` / `week_had_change` / `last_ceremony_unix`)+ receive INITIAL_STATE sentinel → DORMANT(若 persisted pending + safe context → 直接評估去 ARMED)
- [ ] DORMANT listen:milestone → latch(CR-M4,story 006);micro → `week_had_change=true`;GSM state_changed → 每次評估 Formula 1(story 003)

---

## Implementation Notes

*Derived from CR-M11 + States table:*

- `src/autoload/mirror_moment_coordinator.gd`:thin autoload;持 ceremony overlay CanvasLayer ref(復用 110/120,story 010/011 wire)。
- 4-state FSM:DORMANT(default)/ ARMED(Formula 1 pass)/ PRESENTING(safe context)/ PAUSED(SUSPENDED)。
- cfis sentinel idempotent:重收同一 milestone(replay)→ `pending` boolean 重 set true = no-op;window marker 防重呈現(AC-17)。
- bootstrap rebuild latch from persistence(story 008 schema);本 story 搭 FSM + subscription pipeline。

---

## Out of Scope

- Story 003/004:Formula 1/2 評估細節(本 story 只搭 FSM skeleton + subscription)
- Story 006:CR-M4 latch persist 細節
- Story 008:persistence schema 細節

---

## QA Test Cases

- **AC-17**: replay idempotent
  - Given: #26 已 emit milestone before #29 boot
  - When: cfis INITIAL_STATE
  - Then: latch rebuild 正確;唔開兩次慶典(boolean latch no-op on re-set)
  - Edge cases: persisted pending + safe context → Booting 直去 ARMED
- **FSM**: state skeleton
  - Given: boot
  - When: subscription + read latch
  - Then: 4-state FSM ready;3 subscription connected;DORMANT entry

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/mirror_moment/coordinator_scaffold_test.gd` — MockPersistenceLayer + mock #26 signal seam(add_child 前注入);replay idempotent case
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001(autoload registered)/ #26 epic(signal contract — mock-scoped 先行)
- Unlocks: Story 003/004/006/008(build on FSM + subscription)
