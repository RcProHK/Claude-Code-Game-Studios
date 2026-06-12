# Story 014: a11y screen-reader announce + reduced-motion + escape hatch

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(UI §a11y / Visual §Transitions)
**UX**: `design/ux/onboarding-flow.md`（Accessibility;UX-09/10/11）
**Accessibility**: `design/accessibility-requirements.md`（Tier:WCAG AA Core + Motion Safety）
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR: N/A — a11y seam（platform_detect announce_aria 既有 surface;無新架構 pattern）
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `announce_aria(text, polite)` = platform_detect 既有 2-arg + polite region（#24/#19 先例,back-compat）;reduced-motion → `coach_fade_sec → 0` 硬切;contrast palette warm-white `#F5EFE0` / amber `#F2A93B` on ink `#1A1D24`（~11:1 / ~8.5:1 AAA）。

**Control Manifest Rules(this layer)**:
- Required: WCAG AA contrast;announce_aria polite;reduced-motion alternative
- Forbidden: color-only 傳 class（copy 須明寫 class 名）;keyboard-trap / forced-focus
- Guardrail: `coach_marks_enabled=false` escape hatch 全關

---

## Acceptance Criteria

- [ ] **UX-09** — 全部 coach-mark text 達 WCAG AA contrast（warm-white/amber on ink-bg）;class coach-mark 唔單靠顏色傳 class（copy 明寫 class 名）。
- [ ] **UX-10** — reduced-motion 開啟時 coach-mark 硬切（無 fade）、全程零 motion/parallax/zoom（Motion Safety）。
- [ ] **UX-11** — coach-mark 顯示時 `announce_aria(text, polite)` fire,SR 讀到 copy 而唔搶斷其他 announce。
- [ ] `coach_marks_enabled=false` escape hatch:全部 step silent latch、純靠既有系統教學（onboarding 退化成 latch tracker）。
- [ ] 「試演」watermark 亦 announce「試演 / Preview, 非真實 progress」。

---

## Implementation Notes

*a11y seam:*

- coach-mark show → `PlatformDetect.announce_aria(copy, true)`（polite;back-compat 2-arg,#24 story 019 先例）。
- reduced-motion:`coach_fade_sec → 0`（硬切;全 transition 純 opacity 零 motion → Motion Safety tier 達標）。
- contrast:用既有 HUD palette（warm-white/amber on ink）— 全 text AA+。
- color-independent:class copy 明寫 class 名（顏色 enhancement 非 load-bearing,art-bible 雙-channel 規則）。
- `coach_marks_enabled=false`:全 step silent latch（knob,a11y/重玩 escape）。
- **無 keyboard-trap / forced-focus / timeout-pressure**（coach-mark 非 blocking;auto-dismiss 6s 寬鬆 + tap 即走 + dismiss 唔丟 progress → non-AAA-timeout-concern）。

---

## Out of Scope

- Story 013: overlay layer / coach-mark 視覺 layout（呢度 a11y 屬性疊上去）。
- Story 015: knob registry（`coach_marks_enabled` 定義喺 registry story;呢度用 it）。

---

## QA Test Cases

**UX-09(contrast + color-independent)**:
- Setup: 顯示 class coach-mark
- Verify: text contrast ≥ AA（warm-white/amber on ink）;copy 明寫「STRIKE」（非單顏色）
- Pass condition: greyscale 下 class 仍可讀

**UX-10(reduced-motion)**:
- Given: reduced-motion 開
- When: coach-mark 顯示/消失
- Then: 硬切（`coach_fade_sec→0`）;零 motion/parallax/zoom
- Edge cases: preview combat motion 受 #25/#14 motion_intensity 管

**UX-11(announce_aria)**:
- Given: coach-mark 顯示
- When: show
- Then: `announce_aria(copy, polite)` fire（spy）;polite region 唔搶斷
- Edge cases: watermark announce「試演」

**Escape hatch**:
- Given: `coach_marks_enabled=false`
- When: 全 step trigger
- Then: 全 silent latch;零 coach-mark;onboarding 仍 completed

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `tests/integration/onboarding_flow/test_a11y_announce.gd`（announce spy + reduced-motion + escape hatch）+ `production/qa/evidence/onboarding-a11y-evidence.md`（contrast + greyscale 人手）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 013（overlay UI）
- Unlocks: None
