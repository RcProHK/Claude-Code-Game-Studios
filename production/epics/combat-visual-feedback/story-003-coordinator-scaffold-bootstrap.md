# Story 003: Coordinator scaffold + cfis subscription + bootstrap + lifecycle

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(R-1 subscription / States and Transitions / EC-08/15)
**Requirement**: `TR-cvf-003`

**ADR Governing Implementation**: ADR-0006: State Machine Contract(primary)、ADR-0008(secondary)
**ADR Decision Summary**: Contract 6 `connect_for_initial_state` boot 即收 current state;Contract 4 sequential boot;autoload `PROCESS_MODE_ALWAYS` 喺 tree-pause 仍 tick。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `connect_for_initial_state(signal, callable)` helper(GSM shipped);`process_mode = Node.PROCESS_MODE_ALWAYS`;untyped DI seam(test 注入 mock #5/#6/#26/clock)。

**Control Manifest Rules (Presentation)**:
- Required: signal connect 喺 `_ready()`,**唔喺 hot path**(`_process`/handler)connect/disconnect;cfis for initial-state
- Forbidden: 直接 `new GPUParticles2D()` / mutate Camera2D
- Guardrail: DI seam untyped(typed Node fail compile-time member check — [[reference_gdscript_di_seam]])

---

## Acceptance Criteria

*From GDD R-1 / States table / AC-01:*

- [x] **AC-01**:GIVEN fresh #25 instance(real/fake #14 + mock inject),WHEN `_ready()`,THEN connect 到 #14 `hit_resolved` + `enemy_killed` + #1 GSM `state_changed`。**用 fresh-instance wiring 驗**(test_cvf_bootstrap 各 1 connection)。⚠️ **erratum**:#14 hit_resolved/enemy_killed 係 event broadcast → **raw `.connect()` + has_signal guard**(loot_drop_system:193-197 ground-truth 先例),**唔係 cfis**;cfis 淨係 GSM state_changed(Contract 6)。AC 措辭「cfis 到 #14」grep-corrected。
- [x] coordinator `PROCESS_MODE_ALWAYS`(EC-15:hit_resolved 喺 #6 HitPaused/tree-pause 期間照收)— test_process_mode_is_always + lint forward-protected(check_autoload_process_modes REQUIRED_FILES +combat_visual_feedback.gd)
- [x] lifecycle Active(default)/ Suspended(GSM→Suspended)兩 sub-state scaffold(reject incoming + 細節留 story 012)— test_suspended_rejects_incoming(2 rejected)+ test_resume_returns_to_active
- [x] DI seam:`_enemy_director` / `_gsm` / `_particles` / `_screen_fx` / `_clock` / (optional)`_avatar` untyped injectable;real autoload fallback via `_node_or_null` + test fake inject-before-add_child;absent-pred null-safe(test_absent_predecessors_no_crash)

---

## Implementation Notes

*Derived from ADR-0006:*

- 替換 story 001 嘅 stub `src/autoload/combat_visual_feedback.gd`。`_ready()`:無條件 call `connect_for_initial_state`(real autoload + fake 皆有;移除 dead else-fallback,避 gateway-lint 觸發 — #26 教訓)。
- `_visual_state`-free:#25 near-stateless,只持 number pool / overlay handle / coalescing dict / dedup set。
- routing handler 本 story 只 scaffold(switch outcome→tier 框架),具體 routing 留 004-008。
- `var x = untyped_node.method()`(**唔用 `:=`** — untyped DI seam `:=` parse-fail phantom,[[reference_gut_filename_convention]] 家族)。

---

## Out of Scope

- Story 004-008: 具體 routing logic
- Story 012: Suspended force-reset 細節 + bfcache resume

---

## QA Test Cases

- **AC-01**: subscription wiring
  - Given: fresh `CombatVisualFeedback` instance + fake #14(emit-able)+ mock #5/#6/clock,inject-before-add_child
  - When: `_ready()` + add_child_autofree
  - Then: fake #14 `hit_resolved`/`enemy_killed` + GSM `state_changed` 各有 1 connection（fresh-instance 驗,唔靠 real autoload）
  - Edge cases: pred 缺席（fake null）→ 唔 crash(null-safe guard)
- **AC-process-mode**: ALWAYS tick
  - Given: instance ready
  - When: 讀 `process_mode`
  - Then: `== PROCESS_MODE_ALWAYS`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat_visual_feedback/test_cvf_bootstrap.gd`(fresh-instance wiring + process_mode)
**Status**: [x] Created + green 2026-06-11 — `test_cvf_bootstrap.gd` 5/5 pass(subscription set / process_mode ALWAYS / absent-pred null-safe / suspended-reject / resume-active);`--import` exit 0;全 .gd lint exit 0(connection-pattern clean:GSM cfis 唔觸 check_attention_subscription,#14 raw-connect 唔觸 enemy_director lint[單檔 scope])

---

## Dependencies

- Depends on: Story 001(autoload 位置)、Story 002(CanvasLayer topology amendment)
- Unlocks: Story 004(routing core)
