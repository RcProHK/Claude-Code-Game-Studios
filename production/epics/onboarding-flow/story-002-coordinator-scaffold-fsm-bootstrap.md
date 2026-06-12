# Story 002: Coordinator scaffold + 5-state FSM + cfis subscription bootstrap

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Rule 1 / Rule 8 / States §FSM / AC-01)
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR-0006: State Machine Contract(primary)+ ADR-0008(secondary)
**ADR Decision Summary**: Contract 6 `connect_for_initial_state`(boot 即收 initial state,replay-safe,`source_event == INITIAL_STATE_PAYLOAD_SOURCE_EVENT` sentinel 分辨);autoload sequential boot。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: DI seam 用 **untyped** node ref(`var _gsm = ...` 唔 typed Node — [[reference_gdscript_di_seam]]);`var x := untyped_node.method()` parse-fail → untyped `=`。

**Control Manifest Rules(this layer)**:
- Required: GSM 訂閱經 `connect_for_initial_state`(ADR-0006 C6);DI injection seam untyped
- Forbidden: 第二個 autoload(established pattern:一 autoload + 多 helper file);request GSM transition(Rule 8 observe-only)
- Guardrail: idle 零 draw-call(`OnboardingOverlayLayer` pre-warmed `visible=false`)

---

## Acceptance Criteria

- [x] **AC-01** — GIVEN `onboarding.completed==false` 且四 step latch 全 false,WHEN coordinator boot,THEN FSM 入 `WELCOME`(Formula 3)且 `OnboardingOverlayLayer` pre-warmed `visible==false`。✅ `test_fresh_boot_enters_welcome_with_overlay_prewarmed_hidden`。
- [x] REPLACE stub `onboarding_coordinator.gd` → 真 coordinator:5-state FSM enum(DORMANT/WELCOME/PREVIEW/COACHING/COMPLETE)。✅ + `src/core/onboarding_formulas.gd`(F1/2/3 pure)+ `src/data/onboarding_config.gd` + `assets/data/onboarding_config.tres`。
- [x] cfis subscription set:#1 GSM `state_changed`(connect_for_initial_state)+ #9 `workout_started_forwarded`/`dominant_class_changed`/`workout_completed_forwarded` + #21 `modal_dismissed`(訂閱 set 可驗)。✅ `test_boot_wires_observe_only_subscription_set`。
- [x] DI seam:GSM/#9/#21/#3 注入點 untyped,test 可注 fake。✅ 全 untyped seam([[reference_gdscript_di_seam]])。
- [x] **觀察 only**:零 GSM transition request、零 gameplay mutate(Rule 8;G-OB-2 story 012 lint 守)。✅ `test_observe_only_never_requests_gsm_transition`(spy GSM.transition_calls==0)+ idempotent guard(GSM cfis + #9/#21 has_signal-guarded)。

---

## Implementation Notes

*Derived from ADR-0006 / ADR-0008:*

- `src/autoload/onboarding_coordinator.gd`:`extends Node`;5-state FSM;`_ready()` 做 cfis bootstrap + `OnboardingOverlayLayer` instantiate(pre-warmed hidden)。
- **cfis 對每個 #1 GSM 訂閱**用 `GameStateMachine.connect_for_initial_state(_on_state_changed)`;#9/#21 係 event broadcast → 用 has_signal-guarded `.connect()`(loot_drop / #25 raw-connect 先例,非 cfis — #9/#21 唔係 GSM-style initial-state delivery)。
- **驗 grep**:#9 signals(workout_state_tracker.gd:65/69/104)、#21 `modal_dismissed`(loot_reveal_coordinator.gd:27)、GSM `connect_for_initial_state`(game_state_machine.gd:271)— 全 design-review grep-confirmed EXACT。
- subscription bootstrap idempotent(EC-double-subscribe guard,#26 AC-22 先例)。

---

## Out of Scope

- Story 003/004: F3 resume logic + persistence latch（呢個 story scaffold + AC-01 fresh-boot WELCOME）。
- Story 005/006: may_show / auto-dismiss formula。
- Story 013: OnboardingOverlayLayer CanvasLayer 數值（呢度只 instantiate pre-warmed hidden,layer int 留 G-OB-3）。

---

## QA Test Cases

**AC-01(fresh-boot WELCOME)**:
- Given: MockPersistence 注入,`onboarding.*` 全 false / 缺
- When: coordinator `_ready()` boot(fresh AvatarRenderer-style instance + real Stat/GSM + MockPersistence,add_child_autofree)
- Then: FSM == WELCOME;`OnboardingOverlayLayer.visible == false`
- Edge cases: 注入 fake-before-add_child([[reference_test_persistence_isolation]]);subscription set 含 GSM state_changed + #9 3-signal + #21 modal_dismissed

**Observe-only(Rule 8)**:
- Given: coordinator active
- When: 任何 state edge
- Then: 零 GSM transition request call(spy GSM enqueue_event 未被 call)
- Edge cases: subscription idempotent — 二次 boot 唔 double-connect

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/onboarding_flow/test_coordinator_bootstrap.gd`(AC-01 + subscription set + observe-only spy)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（autoload registered）
- Unlocks: Story 003/004/005/006（formula + latch 基於 scaffold）
