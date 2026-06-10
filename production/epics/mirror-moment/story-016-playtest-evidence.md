# Story 016: Playtest evidence FT-2 / FT-M1

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` FT-2 / FT-M1 / AC-23 / AC-24
**Requirement**: AC-23 / AC-24(GDD 直接 trace — 2 ADVISORY playtest)
**ADR Governing Implementation**: N/A — playtest evidence(no code pattern)
**ADR Decision Summary**: N/A。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: FT-2 share rate 由 telemetry `mirror.shared`(#28 Soft,emit-only);需慶典上線 ≥2 週數據。

**Control Manifest Rules (Polish layer)**:
- Required: ≥30% weekly self-initiated share(FT-2);≥80% noticeability(FT-M1)
- Forbidden: —
- Guardrail: FT-2 falsified(<30%)→ 重檢 share affordance

---

## Acceptance Criteria

- [ ] **AC-23**(FT-2,ADVISORY/playtest): 慶典上線 ≥2 週 telemetry → weekly self-initiated `mirror.shared` rate ≥ 30%(否則 FT-2 falsified → 重檢 share affordance)
- [ ] **AC-24**(FT-M1,ADVISORY/playtest): 5 playtester 做 ≥2 週訓練 → 週末 first-open → ≥80% 注意到慶典出現過(weekly pause noticeability)

---

## Implementation Notes

*Derived from FT-2 / FT-M1(ADVISORY playtest — gate level ADVISORY):*

- FT-2:`mirror.shared` telemetry(#28 Soft)rate ≥30% weekly self-initiated;需慶典上線 ≥2 週真實數據(VS-tier / 上線後）。
- FT-M1:5 playtester ≥2 週訓練,週末 first-open noticeability quiz ≥80%。
- 需慶典 UI + asset(依賴 `/asset-spec system:mirror-moment` celebration preset / tier badge / share-card chrome);provisional evidence 若 asset 未齊。
- evidence doc + lead sign-off → `production/qa/evidence/mirror-moment/`。

---

## Out of Scope

- code logic(002-015 已實現;本 story 純 perceptual/telemetry playtest)
- asset 生產(`/asset-spec` — 本 story consume)

---

## QA Test Cases (Manual / telemetry)

- **AC-23 FT-2 share rate**:
  - Setup: 慶典上線 ≥2 週,telemetry `mirror.shared`
  - Verify: weekly self-initiated share rate
  - Pass condition: ≥30%(否則 falsified → 重檢 affordance)
- **AC-24 FT-M1 noticeability**:
  - Setup: 5 playtester ≥2 週訓練,週末 first-open
  - Verify: 注意到慶典出現過
  - Pass condition: ≥80%

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/mirror-moment-playtest-evidence.md` + lead sign-off;telemetry export(FT-2)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 010/011/015(overlay+burst+a11y)/ `/asset-spec`(celebration asset)
- Unlocks: None(ADVISORY epic-close evidence)
