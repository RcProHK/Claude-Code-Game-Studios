# Story 009: [BLOCKED] ADR-0001 Hardware Ratification — FR-1/2/3 Perf ACs

> **Epic**: Particle System Wrapper
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/particle-system-wrapper.md`
**Requirement**: `TR-particle-020`, `TR-particle-021`, `TR-particle-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30** — 結構 Accepted，但 **CPU/perf budget 數字 Provisional**，pending VS-tier mobile profiling)
**ADR Decision Summary**: `MAX_ACTIVE_PARTICLES=200`(mobile §8 hard governance) / 400(desktop)、frame-time P95、iOS Safari UA 100% accuracy、LOOT_BURST vs LOOT_RARE_BURST peripheral 1-second glance distinguishability — 全部係 hardware/playtest claim，**唔可以喺 headless GUT 驗證**，必須 VS-tier iOS Safari WebGL2 hardware spike。

**Engine**: Godot 4.6 | **Risk**: HIGH（ADR-0001 RATIFICATION-GATED）
**Engine Notes**: GPUParticles2D + iOS Safari WebGL2 performance spike 未做。呢個 story 嘅全部 AC 係 ADR-RATIFICATION-GATED，blocked 直至 VS hardware spike 完成 + ADR-0001 CPU 數字由 Provisional → Accepted。

---

## BLOCKED

> **BLOCKED: ADR-0001 CPU/perf budget 數字仍 Provisional**（VS-tier iOS Safari WebGL2 hardware profiling 未做）。
>
> ADR-0001 **結構決策** 已 Accepted（2026-05-30，renderer/topology/CI/particle-cap），所以 Stories 001-008 嘅 structural + behavioral ACs 全部 unblocked 可實作。但呢個 story 嘅 3 個 perf/hardware AC（FR-1/2/3）**只可** 喺真實 device 量度，唔可以 headless 驗證。
>
> **Unblock 條件**：完成 VS-tier hardware spike（iOS Safari WebGL2 + Android Chrome），量度 frame-time P95 / particle budget headroom / UA accuracy / peripheral glance distinguishability，然後將 ADR-0001 CPU 數字由 Provisional → Accepted（透過 `/architecture-decision` 修訂）。在此之前唔好實作呢個 story。

---

## Acceptance Criteria

*From GDD Section H（ADR-001 FR-1/2/3）— ALL ADR-RATIFICATION-GATED:*

- [ ] **AC-24 (FR-1)** — frame-time P95：mobile ≤200 active particles 時 frame-time P95 喺 budget 內（VS-tier iOS Safari WebGL2 量度，`/playtest-report` 驗證）。
- [ ] **AC-25 (FR-3)** — iOS Safari UA detection 100% accuracy across variants（真實 device UA matrix，TR-particle-021）。
- [ ] **AC-26 (FR-2)** — LOOT_BURST vs LOOT_RARE_BURST peripheral 1-second glance distinguishability（art-director + #21 owner 主持 playtest，TR-particle-022）。

---

## Implementation Notes

*Blocked — do not implement until ADR-0001 CPU numbers ratified.*

- 呢個 story 唔產生 GDScript logic — 係 hardware profiling + playtest evidence collection。
- AC-24：VS-tier spike harness 喺真 device 跑 EnemyDirector 12-enemy 同時 fire + LOOT burst，量 frame-time P95。
- AC-25：iOS Safari UA variant matrix（iPhone/iPad/iPad-as-Mac across Safari versions）vs `classify_ua()` 輸出，要 100% match。
- AC-26：錄 1 秒 loot drop 片段（旁有打架），peripheral glance test 由 art-director 主持。
- 結果回寫 ADR-0001：CPU 數字 Provisional → Accepted（`/architecture-decision` 修訂）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 005: UA classification **邏輯** 正確性（headless，已 unblocked）— 呢個 story 只驗真 device accuracy
- Story 003: Formula 1 mobile_mult **計算**（headless）— 呢個 story 只驗真 device budget headroom
- Story 008: preset .tres 內容（config）— 呢個 story 只驗 peripheral distinguishability

---

## QA Test Cases

*Visual/Feel + hardware — manual / device profiling, NOT headless GUT.*

- **AC-24 (FR-1)**: frame-time P95
  - Setup: VS-tier iOS Safari WebGL2 device，跑 12-enemy combat + LOOT burst stress
  - Verify: frame-time P95 vs ADR-0001 budget
  - Pass condition: P95 喺 ratified budget 內（數字待 spike 確定）

- **AC-25 (FR-3)**: iOS Safari UA accuracy
  - Setup: 真 iPhone/iPad/iPad-as-Mac across Safari versions
  - Verify: `classify_ua()` 輸出 vs 實際 device class
  - Pass condition: 100% match across variant matrix

- **AC-26 (FR-2)**: LOOT peripheral distinguishability
  - Setup: 錄 1 秒 loot drop 片段，旁有打架
  - Verify: peripheral glance 下玩家能否 unambiguously 分辨 LOOT_BURST vs LOOT_RARE_BURST
  - Pass condition: art-director + #21 owner playtest sign-off

> 全部 AC 係 ADR-RATIFICATION-GATED — evidence 收喺 `production/qa/evidence/` + `/playtest-report`，唔可 headless 自動化。

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `production/qa/evidence/particle-hardware-ratification-evidence.md` + lead sign-off（VS-tier spike 後）
- ADR-0001 CPU 數字 Provisional → Accepted 修訂記錄

**Status**: [ ] BLOCKED — not startable until ADR-0001 CPU numbers ratified

---

## Dependencies

- Depends on: Story 003（Formula 1）、Story 005（UA logic）、Story 007（lifecycle）— 全部 Complete 後先有 device build 可 profile；**+ VS-tier hardware spike（external blocker）**
- Unlocks: ADR-0001 full ratification（CPU 數字 Accepted）；epic 100% close
