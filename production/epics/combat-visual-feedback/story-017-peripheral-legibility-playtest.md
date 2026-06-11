# Story 017: Peripheral legibility + tone playtest evidence

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(AC-26/27 + Player Fantasy design principle)+ UX spec(UX-02/03)
**Requirement**: `TR-cvf-017`

**ADR Governing Implementation**: ADR: N/A — visual/feel playtest evidence,no architectural pattern required
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: ADVISORY(screenshot + art-director sign-off,per Testing Standards Visual/Feel gate);無法 headless CI 驗。

**Control Manifest Rules (Presentation)**:
- Required: tier 走 peripheral channel(pause/flash),非 number size/color
- Forbidden: tier 主要靠 foveal channel
- Guardrail: art-director sign-off

---

## Acceptance Criteria

*From GDD AC-26/27 + UX-02/03(全 ADVISORY):*

- [x] **AC-26 / UX-02**(ADVISORY external):`cvf-peripheral-legibility-evidence.md` protocol authored(1s peripheral-glance,tier 靠 pause+flash 非 number;art-director sign-off table)。structural(R-12 tier→peripheral)CI-green
- [x] **AC-27 / UX-03**(ADVISORY external):evidence protocol HEAVY-vs-CRITICAL side-by-side + degrade 65/100ms +「乾淨定格 + 骯髒爆發」tone sign-off
- [x] **AC-28(perf — CI-testable 部分)**:`test_cvf_perf.gd` — pool cap ≤16(40 hit 不過 12)+ overlay ≤1 ColorRect(8 CRITICAL)+ IDLE zero-cost(sentinel 不變);**P95 `pending("VS-tier: real mobile Safari …")`** honest skip

---

## Implementation Notes

*Visual/Feel evidence(ADVISORY):*

- 固定 viewport + 固定 glance 時長 screenshot/video:普通 hit vs CRITICAL climax;tester 唔對準 focal point,驗能否分辨 tier(主要靠 flash+pause)。
- desaturated screenshot(colorblind,與 story 013 UX-05 共用 protocol)。
- art-director sign-off 記錄喺 evidence doc。
- AC-28 CI-testable 部分(draw-call / blend-pass / IDLE short-circuit)可由 story 009/010 integration spy 驗;P95 hardware-gated。

---

## Out of Scope

- 實際 number/overlay 渲染（story 009/010）
- VS-tier mobile profiling(external hardware gate)

---

## QA Test Cases

- **Manual check: AC-26 peripheral legibility**
  - Setup: combat 進行中,固定 viewport,fovea 對準角落(非 focal point),1 秒 glance
  - Verify: 能分辨「普通 hit」vs「climax」主要靠 flash + pause(非 number)
  - Pass: art-director sign-off「tier 走 peripheral channel 成立」
- **Manual check: AC-27 tier 區分 + tone**
  - Setup: HEAVY(無 flash)vs CRITICAL(flash)並排;再睇 degrade mode(無 flash,65 vs 100ms)
  - Verify: peripheral 明顯有別;「乾淨定格 + 骯髒爆發」tone
  - Pass: art-director sign-off

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/cvf-peripheral-legibility-evidence.md`(screenshot/video + art-director sign-off)+ AC-28 CI-testable 部分 integration test
**Status**: [x] Created 2026-06-11 — evidence protocol doc authored(ADVISORY external human gate)+ `test_cvf_perf.gd` 3 pass + 1 pending(P95 VS-tier honest)。EPIC 收尾

---

## Dependencies

- Depends on: Story 009(number)、Story 010(overlay)、Story 013(a11y)
- Unlocks: None(epic 收尾)
