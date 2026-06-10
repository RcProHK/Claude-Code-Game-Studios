# Story 019: Silhouette / glance playtest evidence

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` FT-1/FT-4/FT-5 / Visual A (silhouette) / AC-31/32/33
**Requirement**: AC-31 / AC-32 / AC-33(GDD 直接 trace — 3 ADVISORY playtest)
**ADR Governing Implementation**: N/A — playtest evidence(no code pattern)
**ADR Decision Summary**: N/A。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 需 final(或近 final)sprite asset(silhouette mass diff)— 依賴 `/asset-spec` 產出;palette-swap REJECTED(silhouette mass required for FT-4)。

**Control Manifest Rules (Presentation layer)**:
- Required: greyscale/desaturated screenshot QA(class info readable in greyscale — accessibility-requirements QA Protocol)
- Forbidden: 用 color 做 sole class differentiator(FT-4)
- Guardrail: ≥80% accuracy bar

---

## Acceptance Criteria

- [ ] **AC-31**(FT-1):10 playtester mid-set 1s glance → ≥80% identify class+state+tier
- [ ] **AC-32**(FT-4):16×16 黑剪影 → ≥80% classify class across 3(STRIKE bottom-heavy triangle / CONTROL tall pillar / MOBILITY asymmetric Y-pose)
- [ ] **AC-33**(FT-5):post-onboarding expectation vs delivered MVP → ≥80% match(honest framing — screenshot weekly + 3 anim,非 layered armor/cutscene)
- [ ] QA desaturated screenshot review pass(class info readable in greyscale,8×8 squint)

---

## Implementation Notes

*Derived from FT-1/FT-4/FT-5(ADVISORY playtest — gate level ADVISORY):*

- 需 sprite asset(或 near-final)— 依賴 `/asset-spec`(G-AR-5)產出;若 asset 未齊,用 best-available + 記錄為 provisional evidence。
- silhouette quiz:純黑 16×16 剪影降至 8×8 仍要分辨(Visual A verification)。
- desaturated screenshot QA(accessibility-requirements QA Protocol — combat/loot/boss greyscale readable;此處 avatar silhouette)。
- evidence doc + lead sign-off → `production/qa/evidence/avatar-renderer/`。

---

## Out of Scope

- code logic(003-016 已實現;本 story 純 perceptual playtest)
- asset 生產(`/asset-spec` — 本 story consume)

---

## QA Test Cases (Manual verification)

- **AC-31 glance**: 
  - Setup: 10 playtester,mid-set 1s glance(各 class/state/tier 組合)
  - Verify: 答 class+state+tier
  - Pass condition: ≥80% accuracy
- **AC-32 silhouette**:
  - Setup: 純黑 16×16 剪影 quiz,3 class
  - Verify: classify STRIKE/CONTROL/MOBILITY
  - Pass condition: ≥80% across 3;8×8 squint 仍分辨
- **AC-33 honest framing**:
  - Setup: post-onboarding survey
  - Verify: expectation vs delivered MVP
  - Pass condition: ≥80% match(無 ≥20% 期待 layered armor/cutscene)

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/avatar-renderer-silhouette-evidence.md` + lead sign-off;desaturated screenshot set
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 015(sprite resolution)/ `/asset-spec`(G-AR-5 asset)
- Unlocks: None(ADVISORY epic-close evidence)
