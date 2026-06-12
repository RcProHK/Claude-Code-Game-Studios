# Story 012: G-OB-2 CI lint no-gameplay-mutator(Pillar 1 命脈)

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Logic（Static-CI）
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Rule 5 / Rule 6 / Rule 8 / AC-15 / G-OB-2 — **Pillar 1 命脈,must-not-regress**)
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR: N/A — CI tooling（gateway-lint;ADR-0003 namespace 為對象但 lint 本身無架構 pattern）
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: lint = `tools/ci/*.gd` headless script（particle/cvf lint 先例,sweep 全 dir 自動 pick up）;**gateway-lint 須 exempt owner**（[[project_main_ci_red_debug_override]] 教訓 — 但 onboarding 係純 consumer 唔 own seam,無 self-match 風險);fixture + static test inline 重現 detection（test_particle_ci_lint pattern）。

**Control Manifest Rules(this layer)**:
- Required: lint scope = `src/autoload/onboarding_coordinator.gd` + `src/ui/onboarding/*`
- Forbidden: false-positive 誤捉 signal name（如 `onboarding.*` read vs gameplay write）
- Guardrail: lint exit code check（唔 grep FAIL — [[feedback_lint_allowlist_adr_sync]]）

---

## Acceptance Criteria

- [ ] **AC-15**（must-not-regress,CI lint）— `tools/ci/check_onboarding_no_gameplay_mutator.gd`:grep onboarding source(`src/autoload/onboarding_coordinator.gd` + `src/ui/onboarding/*`)**零** write 去 `loot.*`/`stat.*`/`ability.*`/`streak.*` namespace、**零** call #15 drop-gen / daily-claim、**零** call #11/#12 mutator。違反 = fail。
- [ ] fixture `tests/fixtures/onboarding_gameplay_mutator_violation.gd`（含一個 violation,驗 lint 捉到）。
- [ ] static test `tests/static/test_onboarding_ci_lint.gd`（inline 重現 scope-aware detection,clean source pass + fixture fail）。
- [ ] lint 加入 `tools/ci/*.gd` sweep（確認 auto pick-up;particle lint 先例）。

---

## Implementation Notes

*Pillar 1 命脈 lint:*

- `check_onboarding_no_gameplay_mutator.gd`:scope-aware scan onboarding source。Forbidden pattern：
  - persistence write 去 `"loot\.`/`"stat\.`/`"ability\.`/`"streak\.` namespace（注意:`onboarding.*` read/write 合法,唔誤判;#29 CI-MM-4 `"avatar\.` forbid 但 signal `avatar_` 唔誤判 先例）
  - call `#15` drop-gen / `claim-daily` / client-trigger
  - call `#11`/`#12` mutator（`set_stat`/`unlock_ability` 等）
- **owner-exempt 唔需要**（onboarding 純 consumer,唔 define/guard 呢啲 seam — 無 self-match;對比 stat_system DEBUG_OVERRIDE）。
- fixture + static test 跟 #25 `check_cvf_no_runtime_alloc` / #29 CI-MM 先例（CI-gated + clean-pass + fixture-fail）。
- **lint sweep 驗 exit 0**（唔 grep FAIL — [[feedback_lint_allowlist_adr_sync]] 教訓）。

---

## Out of Scope

- Story 008/010: preview/first-drop impl 非綁定（呢度 lint 驗;impl 喺各 step story）。
- Story 001: autoload position lint（唔同 lint）。

---

## QA Test Cases

**AC-15(no-gameplay-mutator lint)**:
- Given: clean onboarding source（只 `onboarding.*` write + observe-only）
- When: 跑 `check_onboarding_no_gameplay_mutator.gd`
- Then: exit 0（pass）
- Edge cases: `onboarding.step_class` write 唔誤判做 gameplay mutator

**Fixture detection**:
- Given: `onboarding_gameplay_mutator_violation.gd`（含 `loot.*` write 或 #15 claim call）
- When: 跑 lint against fixture
- Then: exit 非 0（捉到 violation）
- Edge cases: static test inline 重現 detection logic（clean pass + fixture fail）

---

## Test Evidence

**Story Type**: Logic（Static-CI）
**Required evidence**: `tests/static/test_onboarding_ci_lint.gd`（lint detection + clean/fixture）+ lint exit 0 against real source
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（scaffold source 存在）+ Story 008/010（非綁定 impl 落地先驗 clean）
- Unlocks: None（命脈 guard,must-not-regress）
