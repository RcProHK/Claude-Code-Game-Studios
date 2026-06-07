# Story 027: Visual/UI ADVISORY evidence pack

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Protocol delivered(2026-06-07 — per-AC evidence protocol @ production/qa/evidence/loot-drop-modal/README.md;**evidence 收集 EXTERNAL**(真 browser + 人手;ADVISORY 軌唔 block — #20 先例);AC-9/87/88+SR = VS-tier)
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(AC §F 全組 + AC-9)+ UX spec + art bible §4/§7
**ADR**: ADR-0001(layer immune 視覺驗證)
**Engine**: Godot 4.6 | **Risk**: LOW(ADVISORY — 唔 pre-mergeable,唔做 merge gate;#20 先例)

## Acceptance Criteria(全部 ADVISORY — manual evidence + lead sign-off)

- [ ] **AC-9**(FR-2 wall-clock):真 web build frame capture,trigger→burst onset ≤100ms(6 frames@60fps)
- [ ] **AC-80**:LEGENDARY terminal frame 截圖 — 明信片 composition、「值唔值得 cap 圖」lead sign-off(Pillar 3 design test / FT-1)
- [ ] **AC-81**:micro-copy walkthrough — present tense、零正向運氣歸因(否定式准 — N-1)、數字行先;EPIC/LEG 證人聲線;CTA ==「影低佢」
- [ ] **AC-82**:catch-up grid 截圖 — rarity-sorted 一屏、hero cell、screenshot-worthy
- [ ] **AC-83**:S1 entry 錄影 — elastic-light 唔似 pop、肉眼無 staggered pop-in
- [ ] **AC-84**:breakdown bar 截圖(標準 + 窄屏 stacked + CJK 雙 font 混排 variant)
- [ ] **AC-85**:LEGENDARY freeze-hold 窗錄影 — 角落零 toast(defer 兌現)
- [ ] **AC-86**:stash anim 錄影 — 讀成「袋低咗」唔似 crash
- [ ] **AC-87**:world saturation 期間 burst 截圖 — burst 全飽和(>100 layer immune)[G-LM-1/2/3 落地後]
- [ ] **AC-88**:catch-up stream 錄影 — beats luminance-stable(零 per-beat flash),flash 只喺頭尾;LEGENDARY freeze 期間 fanfare 連續無 stutter(AC-76b perceptual 半邊)[G-LM-9 後]

## Implementation Notes

- Evidence 全部落 `production/qa/evidence/loot-drop-modal/`(每 AC 一節:setup / verify / pass condition / 截圖或錄影連結 / sign-off)。
- 真 browser build 需求:AC-9/87/88(+SR 聽感);headless 可先行嘅:AC-81 copy walkthrough(fixture 對照)。
- Desaturated screenshot QA protocol(art bible §4.C)— loot modal 係 critical scene。
- ADVISORY ≠ 可有可無:epic DoD 要 evidence docs 存在 + sign-off;但唔 block merge(#20 先例)。

## Out of Scope

- Structural 半邊(AC-10 → 006;AC-25 logic → 013 已 BLOCKING 收);asset 產生(`/asset-spec system:loot-drop-modal` 另行)。

## QA Test Cases

GDD §F manual verification steps(Setup / Verify / Pass condition 已喺 AC 文字內 — qa-plan-import-equivalent)。

## Test Evidence

**Required**: `production/qa/evidence/loot-drop-modal/`(per-AC 小節 + lead sign-off)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 026(全系統落地)
- Unlocks: epic 收線(ADVISORY 軌)
