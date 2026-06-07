---
name: inventory-ui-verification
description: "#23 Inventory UI fix-pass re-verification (2026-06-07): 11/12 PASS, 1 BLOCKING FAIL — salvage()×IN_MAILBOX phantom error code (Rule 12/EC-06/AC-18); error-code class sweep 做咗 claim 漏咗 salvage"
metadata:
  type: project
---

**#23 Inventory UI targeted re-verification(2026-06-07,Pass 1 fix-pass 後)** — verdict **FAIL(1 BLOCKING)**,其餘 11 項全 PASS。

**FAIL 項**:GDD Rule 12 / EC-06 / AC-18 claim `salvage` 對 IN_MAILBOX 件回 `in_mailbox_claim_first` — 但 shipped `inventory_system.gd` 全 file 該 code 只有 **equip path L658-659 一處**;`salvage()`(L548-578)**零 IN_MAILBOX lifecycle guard**,unlocked mailbox 件照執行 `{ok:true}`。AC-18 對真 #17 跑必 FAIL = unsatisfiable binding gate([[binding-gate-satisfiability]] class)。CD 嘅「error-code class sweep」exit bar 正正係要捉呢類 — sweep 修咗 claim(`not_in_mailbox` ✓)但漏咗 sibling command salvage(同 #16 Boss「named-instance fix 漏 sibling」class)。

**Why**: fix pass 對單一被點名 command 做 sweep,冇逐 command grep error-code 來源行 — claim 修啱咗造成「已 sweep」錯覺。
**How to apply**: 任何「error model 對齊 shipped code」verification,要逐 command grep error string 喺 source file 嘅**所有**出現位置,確認每個 GDD 斷言嘅 (command, code) pair 都有對應 code 行;只得一處 = 即刻懷疑其他 command 嘅同款斷言。

**Advisory(非 blocking,順手記)**:
- #17 `set_lock` comment L690-691「immune to every salvage path」係 stale over-claim(TTL sweep L946-947 / evict L994-995 只豁免 receipt,唔理 lock)— GDD D1 honest copy 啱 code;建議 G-IU-3 errata 加 #17 comment erratum 防 implementer 信錯 comment。
- `get_inventory_count` cite 行號分裂:L1125(doc comment 行,口徑語意)vs L1128(func 行)— 兩行都真,cosmetic。
- `make_room_pending` 清空條件:States 表/Rule 11 列五個;EC-04+AC-17 另 pin 第六個(MAKE_ROOM dismiss 清空)— outcome 由 AC pin 住,enumeration 唔齊 advisory 級。

**Pass 1 ux-designer 嘅 16 條 findings 原文冇持久化**(review log 只有 13-BLOCKING dedup synthesis)— 用 review-log clusters + CD D1-D8 做 ground truth 逐項核,全部已落地(除上述 sweep 漏網)。下次 review 完應該即時把自己 findings 摘要存 memory,免 re-verification 冇 ground truth。
