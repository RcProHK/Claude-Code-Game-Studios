# #22 Character Screen — Manual Evidence Protocol(story 020;收集 EXTERNAL)

> GDD: design/gdd/character-screen.md(APPROVED 2026-06-07)— Group G ADVISORY ACs。
> #21 story-027 先例:protocol 交付 = story 完成;收集需真 browser / 真 device / 真 SR / 人手。
> **前提**:UI visual skin(scene 實作)隨 `/asset-spec system:character-screen` → UI build 後先有得截圖。
> AC-49(mobile CPU ≤2ms)= ADR-0001 RATIFICATION-GATED — ratify 後行 `tests/performance/character_screen/`,唔屬本 protocol。

## AC-43b — CJK wrap / 混排 walkthrough(UI / ADVISORY)

- **Setup**:web build;fixture item 帶長 CJK `signature_text`(≥40 字)+ 混排 provenance;360×560 viewport
- **Verify**:截圖 loadout card + ITEM_INSPECT;對照 font 指派表(UX spec UXQ-3)
- **Pass condition**:wrap 優先(多行);空間死限先 ellipsis;inspect 顯示全文;肉眼 confirm 冇任何 CJK 字細過 12px(AC-43a 自動半邊已 CI)

## AC-44 — 真 screen reader walkthrough(UI / ADVISORY;#26 L994 audit gate 驗收位)

- **Setup**:web build + NVDA(Windows)或 VoiceOver(macOS/iOS);開 #22
- **Verify**:(a)avatar 變化 announce「Avatar 變為 [class] T[n]」;(b)slider 操作 announce「[pct]%」(hold 唔 spam);(c)equip →「已裝備 […]」/ salvage →「已分解 […] — +[n] 碎片」/ error toast 文字;(d)P-08 ON 時 avatar breathing freeze 肉眼 confirm
- **Pass condition**:全部可聽、語意正確、無 double-announcement(#21 G-LM-6 同款 check)

## AC-45b — 實機 tap target 量度(UI / ADVISORY)

- **Setup**:真 touch device(手機/平板)web build
- **Verify**:量 close X / tab / card 3 zones(主體/更換/lock)/ picker rows / slider / toggle / modal buttons
- **Pass condition**:全部 ≥48px 物理可達;card 3-zone 互不誤觸(AC-45a 自動半邊已 CI)

## AC-46 — browser back button(UI / ADVISORY)

- **Evidence 標準(qa R14)**:(a)cite `tools/ci/check_platform_detect_callers.gd` lint pass(history intercept 必經 JavaScriptBridge — automated absence proof);(b)web build 撳 back 一張截圖(行為 = browser default,#22 唔 intercept)

## AC-47 — Visual 名單 walkthrough(Visual / ADVISORY)

- **Setup**:完整 screen walkthrough 截圖 set(STATS/LOADOUT/SETTINGS + 3 modals + offline banner + empty states + watermark 行 + nudge)
- **Verify**:對照 GDD「完全無 VFX」名單 + L0-L3 tier 表;greyscale check(art bible §4.C)
- **Pass condition**:零 particle / flash / pulse / elastic;rarity badge 永配文字 label;greyscale 下資訊無損

## AC-48 — Playtest(Playtest / ADVISORY)

- **Setup**:≥3 名 playtester 各 ≥5 分鐘 #22 session(soak);觀察 + 事後問卷
- **Pass condition**:(a)零 confusion-blocking event(玩家口頭問「呢個數字係乜」而 screen 冇答案);(b)每人可唔靠提示講出最少一件 item 嘅 provenance 來源;(c)零人形容 screen 為「嘈/催促」(prompted scale ≤2/5)
- **Watch-items**(記錄,唔係 pass/fail):lock nudge noticed rate;玩家被問「你進步咗幾多」時引用邊個 screen 元素(watermark 兌現度實證)

## 收集記錄

| AC | 日期 | 收集人 | 結果 | Evidence file |
|----|------|--------|------|---------------|
| 43b | — | — | PENDING | — |
| 44 | — | — | PENDING | — |
| 45b | — | — | PENDING | — |
| 46 | — | — | PENDING(lint 半邊:CI green 2026-06-07)| — |
| 47 | — | — | PENDING | — |
| 48 | — | — | PENDING | — |
