# Story 015: G-CV-4 pattern library sync (P-10) + add combat-climax-flash

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md` + UX spec `design/ux/combat-visual-feedback.md`(UXQ-P10-SYNC + UXQ-NEWPATTERN)
**Requirement**: `TR-cvf-015`

**ADR Governing Implementation**: ADR: N/A — pattern library doc sync,no architectural pattern required
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: doc-only(`design/ux/interaction-patterns.md`);G-CS-6 / G-LM-7 pattern-sync 先例。

**Control Manifest Rules (Presentation)**:
- Required: 新 pattern 入 library 先於 review;sync drift 標 authoritative source
- Forbidden: re-invent 已存在 pattern
- Guardrail: pattern reference by name,唔 re-spec

---

## Acceptance Criteria

*From UX UXQ-P10-SYNC + UXQ-NEWPATTERN:*

- [x] **P-10 sync note(G-CV-4)** 加入:4 drift correction(cap 6→12 / spawn→camera-focal / overshoot→Formula 1 no-Tween / 移除 family-color)+ authoritative = #25 GDD(跟 P-03 #22 sync-note 寫法)
- [x] **P-19 combat-climax-flash** full section:Feedback/Overlay;ColorRect+analytic shader 無 texture;layer 105 >100 immune;Formula 2 線性衰減;× motion_intensity;WCAG 2.3.1 結構保證;When-to-Use/NOT
- [x] catalog index P-19 row(Used In: Combat VFX #25,Defined)+ P-10 sync-note grep ×1

---

## Implementation Notes

*Pattern-sync (G-CS-6 / G-LM-7 先例):*

- P-10:加 `⚠️ #25 sync note(G-CV-4)`,列出 4 項 drift correction(cap / spawn / animation / color),authoritative = `design/gdd/combat-visual-feedback.md`。**唔重寫整個 P-10**,只加 sync-note + 修 spec bullet。
- P-19 combat-climax-flash:full pattern entry(Description / Specification / When-to-Use / When-NOT / Accessibility[motion_intensity gate + WCAG 2.3.1])。
- catalog table 加 P-19 row(Used In: Combat VFX #25)。

---

## Out of Scope

- Story 016: entities.yaml registry
- 實際 overlay/number 渲染（story 009/010）

---

## QA Test Cases

- **Manual check: P-10 sync**
  - Setup: 讀 `interaction-patterns.md` P-10
  - Verify: 4 項 drift 已 correct(cap 12 / camera-focal / Formula1 / 無 family-color)+ sync-note 指 #25 GDD authoritative
  - Pass: P-10 spec 同 #25 GDD 一致(無矛盾)
- **Manual check: P-19 新 pattern**
  - Setup: 讀 catalog index + P-19 entry
  - Verify: P-19 row 在 + full spec(含 a11y motion gate + WCAG 2.3.1)
  - Pass: combat-climax-flash 可 by-name reference

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check — `interaction-patterns.md` P-10 synced + P-19 added(grep P-19 + P-10 sync-note 存在)
**Status**: [x] Verified 2026-06-11 — grep `combat-climax-flash`×2(index row + section)+ `G-CV-4` P-10 sync-note ×1 + `WCAG 2.3.1`×2。doc-only

---

## Dependencies

- Depends on: None(doc-only,可 parallel)
- Unlocks: None
