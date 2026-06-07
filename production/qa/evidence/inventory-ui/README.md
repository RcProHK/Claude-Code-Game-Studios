# #23 Inventory UI — Manual Evidence Protocol(story 018;收集 EXTERNAL)

> GDD: design/gdd/inventory-ui.md(APPROVED 2026-06-07)— Group H ADVISORY ACs。
> #22 story-020 / #21 story-027 先例:protocol 交付 = story 完成;收集需真 browser / 真 device / 真 SR / 人手。
> **前提**:UI visual skin(scene 實作)隨 `/asset-spec system:inventory-ui` → UI build 後先有得截圖。
> AC-33(open-path + re-read CPU ≤2ms mobile)= ADR-0001 **RATIFICATION-GATED** — CPU budget 數字 ratify 後行 `tests/performance/inventory_ui/`,唔屬本 protocol。

## AC-30 — CJK copy walkthrough(UI / ADVISORY)

- **Setup**:web build;fixture 含長 provenance(≥40 字 CJK 混排)+ receipt 件 + 過期件;360×560 viewport
- **Verify**:截圖 — list row(provenance 單行 ellipsis)/ ITEM_INSPECT(全文 wrap)/ MAKE_ROOM copy「倉滿 — 要騰 1 個位」/ BULK_CONFIRM 警告行「呢 [R] 件帶收據,分解後簽名永久消失」(~16 字 wrap 安全)/ mailbox lock honest copy(~18 字)/ first-run empty copy(~24 字)
- **Pass condition**:wrap 優先;空間死限先 ellipsis;肉眼 confirm 冇 CJK 字細過 12px(Zpix floor)

## AC-31 — 真 SR + touch walkthrough(UI / ADVISORY)

- **Setup**:web build + NVDA(Windows)或 VoiceOver(macOS/iOS)+ 真 touch device
- **Verify**:(a)section 切換 announce「[section 名],收藏 N 件」(coalesced — 連續切只讀最後);(b)claim →「已領取」/「已領取並裝上」;equip / unequip / salvage / error toast 全 announce;(c)**disabled 入口 focus → announce 原因**(「裝備 — 先領取先用得」/「分解 — 上鎖中」)— SR 玩家唔可以得個謎;(d)**focus 行到超過首屏件數嘅 row** → 視窗跟 focus 推進(focus-driven virtualization);(e)row hit-zone:「領取」button ≥64px、同主體 zone ≥8px dead gap(tap 落 gap = no-op);(f)全部 touch targets ≥48px
- **Pass condition**:全部可聽、語意正確、無 double-announcement;dead-gap 誤觸防線有效

## AC-32 — Visual 名單 walkthrough(Visual / ADVISORY)

- **Setup**:web build;120 件 + mailbox 混合 fixture
- **Verify 名單**:(a)**bulk execute 零逐件 fade-out cascade**(list rebuild 一次過 final — 12 件連環動畫 = 慶祝化毀滅,禁);(b)**retention 行零 ticking countdown**(static date-only);(c)MAILBOX tab badge 文法 —「(3)」dim 純文字,**禁色 pill / 紅 / dot / pulse**;0 件唔 render;(d)greyscale mode 下 rarity badge 仍可辨(corner accent + 文字 label 永配);(e)**claim 成功 silent 體感記錄**(provisional — inversion 認知在案:claim 失敗有聲成功零聲,注意力引去要處理嘅嘢;如體感唔妥 → v0.2 新 cue 提案跟 #4 catalog 規則);(f)section / filter snap-switch 80-120ms 無 elastic;(g)empty states L0 static(dotted outline + dim label)
- **Pass condition**:全名單肉眼 confirm + 截圖存檔本 dir

## AC-33 — RATIFICATION-GATED 記錄行

- **Status**:GATED(ADR-0001 CPU budget 數字 Provisional — VS-tier mobile profiling 後 ratify)
- **Ratify 後**:`tests/performance/inventory_ui/` 行 open-path 五 read + view build ≤2ms(mobile tier)+ 單件 mutation re-read ≤2ms;到時更新呢行 + AC-33 狀態

## Sign-off

| AC | Collector | Date | Evidence file(s) | Approved |
|----|-----------|------|------------------|----------|
| AC-30 | — | — | — | [ ] Approved |
| AC-31 | — | — | — | [ ] Approved |
| AC-32 | — | — | — | [ ] Approved |

> Solo dev:全部 role 可同一人 sign-off(test-evidence 標準註)。
