# Story 001: Doc gates bundle(G-LM-1 + G-LM-5 doc + G-LM-7)

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Dependencies §Cross-system gates — G-LM-1 / G-LM-5 / G-LM-7 rows)
**ADR**: ADR-0001(revision 對象)+ ADR-0008(amendment 對象);doc-only — 唔產生 code
**Engine**: Godot 4.6 | **Risk**: LOW(doc);所記內容屬 HIGH domain(rendering)

## Acceptance Criteria(deliverable 存在性 — 無 GDD AC,gate 前提)

- [ ] **G-LM-1**:`docs/architecture/adr-0001-web-export-budget-caps.md` revision — topology 加 `CelebrationVFXLayer`(110, ALWAYS, follow_viewport)+ `ModalLayer`(120, ALWAYS);註明 >100 = BackBufferCopy capture 外(saturation/shake immune);cite L109 HUD knob 先例;① viewport residence 釘實(`follow_viewport` 只喺同 Camera2D 同一 viewport 先有意義 — world content 如最終入 SubViewport,autoload layer 掛 root viewport 嘅 anchor 映射要明文)② modal 8% local blur = 第二次 framebuffer copy(Compatibility/WebGL2)— priced 入 budget 或 opacity-only fallback 二揀一寫死
- [ ] **G-LM-5(doc 半)**:`docs/architecture/adr-0008-autoload-position-map.md` amendment — `LootRevealCoordinator` tail append 喺 ZoneSystem 後(#28 keep last);predecessor constraints `{#15, #1(C6), #33, Camera, ScreenEffects, Particle, Audio, PlatformDetect} ≺ #21`(`project.godot` 登記行 story 002)
- [ ] **G-LM-7**:`design/ux/interaction-patterns.md` — P-05 撤 5s auto-dismiss(改 tap-only + two-stage,sync GDD Rule 5)+ ladder 數值 sync #15(P-05 hold/slowmo drift — #15 wins)+ OQ-P3 close;P-06 hex 確認(art bible §4.B canonical 套)

## Implementation Notes

- ADR revision 跟既有 ADR 格式(Status 行加 revision 日期 note);唔郁 ADR 已 Accepted 結論,只 append #21 topology section。
- G-LM-7 P-05:UX advisory ×2(numeric char limits + resolution list)可順手補(ux-review 留低)。

## Out of Scope

- `project.godot` autoload 登記 + layer instantiate(story 002);#5 reparent(story 022)。

## QA Test Cases

Doc 存在性 + 內容對照 GDD gate row(G-LM-1 ② 嘅 priced/fallback 二揀一必須有結論,唔可以留開放)。Smoke check 級。

## Test Evidence

**Required**: smoke check 記錄(`production/qa/smoke-[date].md` 或 commit message 列 3 個 doc delta)。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None
- Unlocks: 002(AC-4 layer 數值)、022(G-LM-2 排 G-LM-1 後)
