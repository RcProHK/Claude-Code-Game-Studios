# #21 Loot Drop Modal — Visual/UI Evidence Pack(story 027)

> **Status**: PROTOCOL DELIVERED — evidence 收集係 EXTERNAL(真 browser build + 人手;#20 先例:ADVISORY 軌唔 block merge/epic close)
> **Sign-off 規則**: 每項 AC 影低 screenshot/錄影 → 貼落本目錄(`ac-NN-*.png/mp4`)→ lead 喺下表簽名
> **Build**: Web Export(Compatibility renderer)— `godot --export-release "Web"`;AC-9/87/88 必須真 browser(headless 量唔到)

| AC | 項目 | Setup | Verify | Pass condition | Evidence | Sign-off |
|----|------|-------|--------|----------------|----------|----------|
| AC-9 | FR-2 wall-clock | 真 web build + 錄屏 60fps;觸發 mini-boss kill drop | trigger→burst onset frame 數 | ≤6 frames(100ms@60fps) | — | — |
| AC-80 | LEGENDARY terminal frame | `_force_test_drop(LEGENDARY)`(debug build)行到 S3 截圖 | 明信片 composition:icon hero、frame ornament、breakdown bar | lead 答「值得 cap 圖」(FT-1 design test) | — | — |
| AC-81 | micro-copy walkthrough | 行勻 5 tiers + fast-victory variant 嘅 caption/attribution | present tense;零正向運氣歸因(「好彩/lucky」禁;否定式「RNG 唔夠 0.25」准 — N-1);數字行先「180kg × 5 — Stamped」;CTA ==「影低佢」 | 全部 string 過 checklist | — | — |
| AC-82 | catch-up grid | 6+ 件 mixed-tier catch-up 行到 grid 截圖 | rarity-sorted 一屏、hero cell 2×2、film-edge header | screenshot-worthy(FT-1) | — | — |
| AC-83 | S1 entry 錄影 | LEGENDARY reveal 錄 60fps | elastic-light overshoot ~1.03×;肉眼無 staggered pop-in | 唔似 pop;content 一齊現(structural 半 AC-10 ✅ 已自動化) | — | — |
| AC-84 | breakdown bar | RARE+ 截圖 ×3:標準 160px / 窄屏 stacked(<120px)/ CJK 雙 font 混排 | 兩段對比、% label、legend 行 Zpix 12px、resize 唔破版 | 全部可讀 | — | — |
| AC-85 | freeze-hold 零 toast | LEGENDARY freeze 窗錄影,期間注入 micro_ack | 角落零 toast(defer 兌現;logic 半 AC-25 ✅) | freeze 期間畫面唯一主體係 modal | — | — |
| AC-86 | stash anim | post-S3 force-close(rest_ended)錄影 | scale-down 飛向 stash anchor、tier trail ≤0.3s、無 bounce | 讀成「袋低咗」唔似 crash | — | — |
| AC-87 | saturation immunity | world −60% 期間 burst 截圖(G-LM-1/2/3 ✅ 已落地) | burst 全飽和 vs 世界灰 | >100 layer immune 視覺證據 | — | — |
| AC-88 | stream + freeze audio | catch-up stream 錄影 + LEGENDARY freeze 期間聽 fanfare | beats luminance-stable(零 per-beat flash;頭尾各一 transient);fanfare 連續無 stutter(AC-76b ✅ property 半) | 聽感 + 視覺都過 | — | — |
| +SR | AC-77 manual 半 | 真 browser + VoiceOver/NVDA | S3 announcement 讀一次;檢查 AccessKit double-announcement(story 025 spike note) | 單一 announcement | — | — |

**注意**:AC-9/87/88 + SR 係 VS-tier 場景(真 browser);其餘可喺 desktop editor run 收。Desaturated screenshot QA protocol(art bible §4.C)適用於 AC-80/82。
