---
name: character-screen-ux-review
description: "#22 Character Screen GDD adversarial UX review (2026-06-07): 6 BLOCKING — P-07 preview vs shake-layer topology / #4 L275 volume UI 孤兒 / #26 motion_reduction 接線缺失 / Rule 17 vs 22 tap 衝突 / settings key 名分裂 / loadout-mutation ARIA 零覆蓋; verdict NEEDS REVISION → fix-pass re-verify PASS 同日 (0 new phantom, 4 minor errata)"
metadata:
  type: project
---

**#22 Character Screen GDD adversarial /ux-review 完成(2026-06-07)** — verdict **NEEDS REVISION**(6 BLOCKING,全部 enumerable 局部修,唔使重寫結構)。

6 BLOCKING(/ux-design 前必修 — 全部係 cross-system contract 或 GDD pin 衝突,ux-design 階段冇權改):

1. **P-07 slider preview 可見性 vs shake topology**:screen-effects-system.md L290-299 Rule 14 — shake 只 capture GameLayer(0)+ParticleLayer(10)+HUDLayer(50);#22 係全屏 opaque overlay,如跟 #21 modal「>100 layers immune」convention 放 menu 層 → preview shake 完全不可見(任何 intensity 都零 visual)。GDD Rule 30/EC-24/AC-37 從未 pin #22 layer 位。
2. **Volume UI 孤兒**:audio-manager.md L275 contract row「#20 HUD / Settings screen — host volume slider UI」;#20 GDD grep volume 零 hits(shipped 無),#22 Rule 25 MVP 只有 P-07+P-08。`set_bus_volume_db` API + `audio.*` persistence 全 shipped 但成個 game 無 UI 表面。同 #21 GSM L375 missed-contract-row 同款 class。
3. **#26 motion_reduction 接線缺失**:avatar-renderer.md L985(breathing freeze 應 respect motion_reduction)+ L994 audit gate(accessibility-specialist verify before #22 ships)— #22 零 mention;G-CS gates 冇 #26 boot self-read;live toggle flip 時 persistent avatar panel 喺同一 screen 繼續 breathing = 設定即場「睇落壞咗」。
4. **Rule 17 vs Rule 22 tap routing 衝突**:occupied functional slot card — Rule 17 pin「slot tap → picker」,Rule 22 pin「item tap → ITEM_INSPECT」,同一物理 surface;ITEM_INSPECT + salvage 嘅 entry point map 完全未定義。
5. **Settings key 名分裂**:#22 用 `settings.camera_motion_reduction`(Rule 28/AC-35/G-CS-2);P-08 pattern L272 + accessibility-requirements.md L63 用 `settings.reduce_camera_motion` — consumer self-read 讀錯 key = toggle 永不 persist 嘅 silent fail。G-CS-3 要 pin canonical + errata 另外兩 doc。
6. **Loadout-mutation ARIA 零覆蓋**:GDD 自己已 commit MVP ARIA(Rule 12 avatar + EC-28 settings)但 equip 成功/salvage 完成/error toast 全部唔 announce;EC-18「無 silent fail」對 SR user 唔成立;toast 未宣告 live region;AC-41/44 只測 avatar+settings。

RECOMMENDED 重點:lock nudge unconditional(AC-27 pin 死)要 pin stacking + reserved-space render(layout shift 推走 tap target);scrim-tap 行為 + SALVAGE_CONFIRM cancel button + default focus cancel 未 spec;picker worst-case N=120(MAX_INVENTORY frozen)無 scroll/virtualization spec;mobile vertical budget(avatar 96-128px persistent + chrome ~240-280px → tab content 必須 scroll,GDD 零 scroll mention);font 指派表未做(#21 Pass 1 先例 — H1 11px latin < CJK 12px inversion 要 position/weight 補);banner/toast stack priority table(offline + persist-fail + toast + nudge 並發)。

**How to apply**:/ux-design character-screen 時逐項核對 6 BLOCKING 有冇喺 GDD 修咗先開工;R 項屬 ux-design 份內要寫入 spec。Pattern 重申:upstream forward-contract row(#4 L275 / #26 L985+L994)係 review 必 grep 點 — 同 [[loot-modal-ux-positions]] GSM L375 教訓同源。

**Re-verify pass(同日 2026-06-07)— verdict PASS,0 new phantom**:6B + 7R 全部落地(Rule 31-34 / AC-50..55 / G-CS-9..11 新增)。全部新 cite grep-true(#26 L985/L987/L994/L170、#4 L43-44/L148/L197-213/L275、#17 L309/L258/L384、a11y-req L63、patterns L272、screen_effects.gd L367/L375)。4 個 minor errata 交 main session 一行修:(1)Rule 34 + G-CS-7 cite「screen_effects.gd L299」係 file-slip — L299 of shipped code = `hit_pause()`;正確 locus = screen-effects-system.md L294-299(doc 同一行號!)+ code comment L363-364;(2)AC-31 GIVEN 仍寫「slot tap → picker」舊措辭,同 Rule 22 entry map 唔對齊;(3)EC-20 同款「slot tap」殘留;(4)Rule 13 card 內容清單漏咗「更換」button + lock toggle 兩個 zone(Rule 17b/18/22 有 pin,Rule 13 冇 cross-ref)。Lesson:fix pass 嘅 cite 要連 file extension 都 grep — 行號啱 file 錯係新 error class。
