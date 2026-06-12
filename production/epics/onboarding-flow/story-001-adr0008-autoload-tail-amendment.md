# Story 001: G-OB-1 ADR-0008 autoload tail amendment + project.godot register

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Rule 1 / AC-23 / G-OB-1)
**Requirement**: TR-onboarding-??? (no TR-ID — direct GDD trace,#21/#24/#25/#26/#29 先例)

**ADR Governing Implementation**: ADR-0008: Autoload Position Map(primary)
**ADR Decision Summary**: `project.godot` 係 autoload 絕對位置唯一 ground-truth;新 coordinator tail-append 喺 current tail 後,terminal,partial-order predecessor 滿足。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: autoload registration 喺 `project.godot [autoload]` section;`--import` 後 boot-smoke = 跑 GUT suite(本 project 冇 main scene,唔用 `--quit-after`)。

**Control Manifest Rules(this layer)**:
- Required: autoload 絕對位置只改 `project.godot`(ADR-0008 F-SETUP-4)
- Forbidden: 硬寫 stale predecessor 名(B-2 教訓 — `#29` 措辭已 stale)
- Guardrail: boot 乾淨,零 autoload init crash

---

## Acceptance Criteria

*From GDD `design/gdd/onboarding-flow.md`,scoped to this story:*

- [x] **AC-23**(部分)— `OnboardingCoordinator` 喺 `project.godot` autoload position **tail-append after current tail**(impl-time grep 確認 current tail = `CombatVisualFeedback` #25,project.godot L162);position > **所有現有 coordinator**。✅ project.godot 註冊 + `test_onboarding_autoload_position.gd::test_onboarding_coordinator_boots_after_every_existing_coordinator`。
- [x] ADR-0008 doc amendment:`OnboardingCoordinator` tail entry + predecessor 集 {#1 GSM C6,#2,#3,#9,#10,#21,#24,#25,...全現有 coordinator};terminal note。✅ amendment 2026-06-12 G-OB-1 + insertion-rule row + traceability row。
- [x] `--import` exit 0(全 script parse;stub `onboarding_coordinator.gd` 已 `extends Node` placeholder,story 002 REPLACE)。✅
- [x] boot-order static test 驗 OnboardingCoordinator index > current tail index 且 boot 乾淨。✅ 3 test(registered/tail/terminal)+ lint sync(check_loot_reveal_boot_order ALLOWED_SUCCESSORS + test_invui_lifecycle allowlist)。GUT 24 pass / 0 fail。

---

## Implementation Notes

*Derived from ADR-0008:*

- **Impl-time grep current tail**(勿照 GDD 早期「#29」措辭 — B-2 stale-fix):`grep -nE 'Coordinator|VisualFeedback' project.godot | tail` → current tail = `CombatVisualFeedback`(#25,L162)。OnboardingCoordinator line 加喺其後。
- ADR-0008 amendment row + constraint note(類似 G-MM-1 / G-LS-2 amendment 格式)。
- **Predecessor 安全性**:onboarding `_ready()` init 唔 sync-read 任何上游(只 runtime observe signal + read latch)→ tail-append 安全,零 boot dependency violation。
- **BBCopy/boot-order lint allowlist sync**(若 onboarding tail-append 觸發 any successor allowlist):grep 晒 `tools/ci/check_*_boot_order.gd` + `tests/integration/*/test_*_lifecycle.gd` allowlist,加 `OnboardingCoordinator`([[feedback_lint_allowlist_adr_sync]] — #29 G-MM-1 再現教訓)。

---

## Out of Scope

- Story 002: coordinator scaffold + FSM + subscription（呢個 story 只登記位置 + stub）。
- Story 013: G-OB-3 ADR-0001 OnboardingOverlayLayer CanvasLayer 數值（autoload position ≠ CanvasLayer layer）。

---

## QA Test Cases

**AC-23(autoload position)**:
- Given: `project.godot` 加 OnboardingCoordinator tail entry
- When: 讀 autoload order
- Then: OnboardingCoordinator index > CombatVisualFeedback(#25)index 且 > 所有其他 coordinator
- Edge cases: 確認冇其他 autoload 喺 OnboardingCoordinator 之後(terminal);`--import` exit 0

**Boot cleanliness**:
- Given: 全 autoload registered
- When: GUT harness boot(boot 晒 autoload)
- Then: 零 init crash,OnboardingCoordinator `_ready` 跑到
- Edge cases: stub `extends Node` placeholder 階段 boot 都要乾淨

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `tests/static/test_onboarding_autoload_position.gd`(position assert)+ smoke check(`--import` exit 0 + GUT boot green)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（scaffold 前提，最早做）
- Unlocks: Story 002（coordinator scaffold REPLACE stub）
