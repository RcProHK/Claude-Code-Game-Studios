---
name: inventory-ui-qa-review
description: "#23 Inventory UI GDD QA verification — Pass 2 verdict FAIL(1 BLOCKING): AC-18/EC-06/Rule 12 salvage→in_mailbox_claim_first phantom(code 只 equip 有 guard);其餘 9/10 items PASS"
metadata:
  type: project
---

# #23 Inventory UI — QA targeted re-verification(Pass 2,2026-06-07)

Verdict: **FAIL — 1 BLOCKING 殘留**(targeted fix 後可 PASS)。

**Why:** Pass 1 嘅「error-code class sweep」exit bar 做咗 claim(`not_in_mailbox` L711-712 / shortfall L715 無 error key)同 equip(L657/L659),但漏咗 salvage sibling — `salvage()` L548-556 **冇 IN_MAILBOX lifecycle guard**(全 file `in_mailbox_claim_first` 只有 L659 equip path),IN_MAILBOX 件直接 salvage 成功毀件。Rule 12 / EC-06 / AC-18 三個 locus 斷言「salvage 對仍-IN_MAILBOX 件 → in_mailbox_claim_first」= 對 shipped code 唔成立,AC-18 跑真 #17 必 fail。同 #16 lesson 重演:named-instance fix 漏 sibling class member。

**其餘 ground truth(下游 verify 可重用):**
- AC 數 37 ✓(3 Logic + 30 Integration BLOCKING;30-32 ADVISORY;33 GATED;1-37 連續無 dup)
- event→cue map 全部 cue 實證喺 audio-manager.md(L362 ui_back/ui_error;L500-504 ui_charscreen_*/ui_equip_settle/ui_lock_*/ui_salvage_execute/ui_sheet_*)— 零新 cue claim 成立
- picker_before = char_screen_formulas.gd L67 static ✓;ADR-0001 capture enumeration L112+L127「0/10/50/60」✓(G-IU-2 正確框 pending);#17 GDD UX flag 實際 L358 📌 段;#22 AC-42 L608 / AC-54 L609 ✓
- 13/13 Pass-1 BLOCKING 落地(#1 claim cluster 落地唔完整 = 上面 BLOCKING);D1-D8 全落地
- Advisory ×2:AC-16「AC-25 同 file」措辭歧義(AC-25 實喺 test_invui_commands.gd);AC-20 用 `preview.receipt_ids`(G-IU-1 subject)但冇 *(gated)* marker

**How to apply:** Pass 3 只需驗 salvage 半邊三 locus 嘅改寫(對齊 code:salvage-on-mailbox = 直接成功,防線只有 disabled 入口;或 #17-side guard story — 要 design call)。Claim dispatch ①②③ 已驗 sound(not_in_mailbox/deferred 都帶 shortfall:0)。
