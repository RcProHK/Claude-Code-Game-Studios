# Story 011: [BLOCKED] ADR-001 Hardware Ratification — FR-1/2/3

> **Epic**: Screen Effects System
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/screen-effects-system.md`
**Requirement**: `TR-screen-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30** — 結構 Accepted；但 **CPU/perf budget 數字 Provisional**，pending VS-tier profiling)
**ADR Decision Summary**: ScreenEffects CPU budget（separate from #5 GPU budget）、peripheral 體感 distinguishability、autoload PROCESS_MODE_ALWAYS whitelist drift — 全部 hardware/playtest/CI-infra claim，唔可 headless 驗，必須 VS-tier iOS Safari WebGL2 hardware spike。

**Engine**: Godot 4.6 | **Risk**: HIGH（ADR-0001 RATIFICATION-GATED）
**Engine Notes**: ADR-0001 CPU budget 數字 fill-in-blank pending ratification。FR-3 EXPECTED_AUTOLOADS whitelist CI 必須喺 first VS-tier autoload 增加之前 in-place。

---

## BLOCKED

> **BLOCKED: ADR-0001 CPU/perf budget 數字仍 Provisional**（VS-tier iOS Safari WebGL2 hardware profiling 未做）。
>
> ADR-0001 **結構決策** 已 Accepted（2026-05-30），所以 Stories 001-010 嘅 structural + behavioral ACs 全部 unblocked。但呢個 story 嘅 3 個 FR/perf AC **只可** 喺真實 device 量度或 playtest panel 驗，唔可 headless。
>
> **Unblock 條件**：完成 VS-tier hardware spike（iOS Safari WebGL2），量度 frame-time P95 / peripheral distinguishability（n≥5 panel）/ autoload drift CI infra，然後將 ADR-0001 CPU 數字由 Provisional → Accepted。在此之前唔好實作呢個 story。

---

## Acceptance Criteria

*From GDD Section H（ADR-001 FR-1/2/3）— ALL ADR-RATIFICATION-GATED:*

- [ ] **AC-27 (FR-1)** — mobile Safari iOS 17+（iPhone 12 baseline）60s 持續 shake load（`shake(0.4,0.12)` @8Hz + `hit_pause(0.06)` @2Hz）→ ScreenEffects per-frame P95 CPU ≤ ADR-0001 allocated budget（separate from #5 GPU）。
- [ ] **AC-28 (FR-2)** — human playtest panel（n≥5）mobile Safari，random-order HIT_HEAVY/PARRY/DEATH/LOOT_RARE_BURST shakes，mid-set glance condition → ≥80% panelists correctly distinguish 全 4 peripheral 體感 signatures。LOOT_RARE_BURST 0.16px sub-pixel risk flagged if <80%。
- [ ] **AC-29 (FR-3)** — `check_screen_effects_callers.gd` + `EXPECTED_AUTOLOADS` whitelist：新 autoload 加入 project.godot 但缺 whitelist entry + `PROCESS_MODE_ALWAYS` declaration → CI build fail（exit 1）naming offending autoload。

---

## Implementation Notes

*Blocked — do not implement until ADR-0001 CPU numbers ratified.*

- AC-27：VS-tier spike harness 喺真 device 跑 sustained shake/pause load，量 frame-time P95，對 ADR-0001 budget。
- AC-28：peripheral glance playtest（art-director + qa-lead 主持，n≥5），4 preset random order，量 distinguishability ≥80%。Sub-pixel LOOT_RARE_BURST（0.16px）= FR-2 monitor。
- AC-29：擴展 `check_screen_effects_callers.gd` 加 `EXPECTED_AUTOLOADS` whitelist + PROCESS_MODE_ALWAYS drift detection（new autoload missing ALWAYS → fail）。
- 結果回寫 ADR-0001：CPU 數字 Provisional → Accepted（`/architecture-decision` 修訂）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 003: hierarchy gap **formula** invariant（AC-26 headless）— 呢度只驗真 device peripheral perception
- Story 008: caller-ban CI lint **base**（呢度只加 autoload-drift extension）
- Story 005: PROCESS_MODE_ALWAYS **runtime** behavior（呢度只加 CI drift detection）

---

## QA Test Cases

*Visual/Feel + hardware/CI-infra — device profiling / playtest / CI, NOT headless GUT.*

- **AC-27 (FR-1)**: frame-time P95
  - Setup: VS-tier iOS Safari WebGL2 device，60s sustained shake @8Hz + hit_pause @2Hz
  - Verify: ScreenEffects per-frame P95 CPU vs ADR-0001 budget
  - Pass: P95 ≤ ratified budget（數字待 spike）

- **AC-28 (FR-2)**: peripheral distinguishability
  - Setup: n≥5 panel，mobile Safari，4 preset random order，mid-set glance（10-30s rep window sim）
  - Verify: panelists 能否分辨 4 個 體感 signature
  - Pass: ≥80% correct；LOOT_RARE_BURST sub-pixel flagged if <80%

- **AC-29 (FR-3)**: autoload drift CI
  - Setup: `check_screen_effects_callers.gd` + EXPECTED_AUTOLOADS whitelist
  - Verify: 新 autoload 缺 whitelist + ALWAYS → exit 1 naming offender
  - Pass: CI fail with explicit message

> 全部 AC ADR-RATIFICATION-GATED — evidence 收喺 `production/qa/evidence/` + `/playtest-report`，唔可 headless 自動化。

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `production/qa/evidence/screen-effects-hardware-ratification-evidence.md` + lead sign-off（VS-tier spike 後）
- ADR-0001 CPU 數字 Provisional → Accepted 修訂記錄
- `tests/unit/ci/autoload_whitelist_drift_test.gd`（AC-29，CI infra）

**Status**: [ ] BLOCKED — not startable until ADR-0001 CPU numbers ratified

---

## Dependencies

- Depends on: Story 001-010（全部 Complete 後先有 device build 可 profile）+ **VS-tier hardware spike（external blocker）**
- Unlocks: ADR-0001 full ratification（CPU 數字 Accepted）；epic 100% close
