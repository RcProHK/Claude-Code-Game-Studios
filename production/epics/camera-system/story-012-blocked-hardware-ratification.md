# Story 012: [BLOCKED] ADR-001 Hardware Ratification — FR-1/2/3

> **Epic**: Camera System
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Performance
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-camera-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30** — 結構 Accepted；CPU/perf/smoothness 數字 Provisional，pending VS-tier profiling)
**ADR Decision Summary**: Camera CPU budget（separate from #5 GPU / #6 CPU）、Focal tween 60fps smoothness（Compatibility renderer）、Focal trigger caller-gating CI（`check_focal_caller_states.gd` + whitelist）— hardware/perf/CI-infra claim，唔可 headless 完整驗，需 VS-tier iOS Safari WebGL2 spike。

**Engine**: Godot 4.6 | **Risk**: HIGH（ADR-0001 RATIFICATION-GATED）
**Engine Notes**: `Camera2D.position_smoothing` + Tween cubic 喺 Compatibility renderer（WebGL2 mobile Safari）frame budget 未驗（Q-R2 knowledge gap）。ADR-0001 CPU 數字 fill-in-blank。

---

## BLOCKED

> **BLOCKED: ADR-0001 CPU/perf budget 數字仍 Provisional**（VS-tier iOS Safari WebGL2 profiling 未做）。
>
> ADR-0001 結構決策已 Accepted（2026-05-30），所以 Stories 001-010 嘅 structural + behavioral ACs 全部 unblocked。但呢個 story 嘅 3 個 FR/perf AC **只可** 喺真 device 量度或 CI-infra build。
>
> **Unblock 條件**：VS-tier hardware spike（iOS Safari WebGL2），量度 Camera CPU P95 / Focal tween 60fps smoothness / 建 `check_focal_caller_states.gd` whitelist CI，然後 ADR-0001 CPU 數字 Provisional → Accepted。

---

## Acceptance Criteria

*From GDD Section H（ADR-001 FR-1/2/3）— ALL ADR-RATIFICATION-GATED:*

- [ ] **AC-33 (FR-1)** — mobile Safari iOS 17+（iPhone 12）60s session（Following + Focal every 30s）→ Camera per-frame P95 CPU ≤ ADR-0001 budget（separate from #5/#6）；cross-platform consistent。
- [ ] **AC-34 (FR-2)** — 60fps target + Focal entry 0.6s + exit 0.5s，60s sample → zero frame drops（Compatibility 模式唔 < 30fps mid-tween）。fallback: Focal shrink 0.4/0.3s OR mobile snap zoom。
- [ ] **AC-35 (FR-3)** — `check_focal_caller_states.gd` + `focal_caller_whitelist.txt`：scan src/ `Camera.request_focal(...)` callers，唔喺 whitelist → CI fail naming offender。first authorized: enemy_director `_on_boss_spawn` + loot_drop_modal `_on_loot_drop_entry`。

---

## Implementation Notes

*Blocked — do not implement until ADR-0001 CPU numbers ratified.*

- AC-33：VS-tier spike 真 device 跑 Following + Focal sustained，量 P95 CPU vs ADR-0001 budget。
- AC-34：60s Focal tween `Engine.get_frames_per_second()` sample，zero drop < 30fps。
- AC-35：建 `tools/ci/check_focal_caller_states.gd` + `tools/ci/focal_caller_whitelist.txt`（explicit whitelist，每行 `path:function`，mirror Rule 13 WHITELIST_PATHS）；non-whitelist caller → exit 1。Q-R3 resolved（Pass 3）= explicit whitelist file。
- 結果回寫 ADR-0001：CPU 數字 Provisional → Accepted。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 003: Pillar 2 lock-on **formula** AC-09（headless）— 呢度只驗真 device CPU
- Story 005: PAUSABLE freeze **behavior**（headless）— 呢度只驗 60fps smoothness
- Story 006: focal gating **runtime** AC-19（headless）— 呢度加 static CI caller-whitelist

---

## QA Test Cases

*Performance + CI-infra — device profiling / CI, NOT headless GUT behavioral.*

- **AC-33 (FR-1)**: VS-tier iOS Safari，60s Following+Focal stress，P95 CPU ≤ ratified budget（數字待 spike）
- **AC-34 (FR-2)**: 60fps device，60s Focal tween sample，zero < 30fps drop；fallback documented
- **AC-35 (FR-3)**: `check_focal_caller_states.gd` + whitelist；non-whitelist caller → exit 1 naming offender；first authorized callers in whitelist

> 全部 ADR-RATIFICATION-GATED — evidence 收喺 `production/qa/evidence/` + `/playtest-report`。

---

## Test Evidence

**Story Type**: Performance / CI-infra
**Required evidence**:
- `production/qa/evidence/camera-hardware-ratification-evidence.md` + lead sign-off（VS-tier spike 後）
- ADR-0001 CPU 數字 Provisional → Accepted 修訂記錄
- `tools/ci/check_focal_caller_states.gd` + `tools/ci/focal_caller_whitelist.txt`（AC-35 CI infra）

**Status**: [ ] BLOCKED — not startable until ADR-0001 CPU numbers ratified

---

## Dependencies

- Depends on: Story 001-009（全 Complete 後先有 device build profile）+ **VS-tier hardware spike（external blocker）**
- Unlocks: ADR-0001 full ratification（CPU 數字 Accepted）；epic 100% close
