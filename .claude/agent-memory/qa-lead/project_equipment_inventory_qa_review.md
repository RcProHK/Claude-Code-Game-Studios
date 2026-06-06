---
name: equipment-inventory-qa-review
description: "#17 Equipment & Inventory GDD QA testability review history — Pass 1 (13 BLOCKING) + Pass 2 re-review (2026-06-06) outcome; residual items to re-check at epic authoring"
metadata:
  type: project
---

#17 equipment-inventory.md QA review history (qa-lead verifier both passes).

**Pass 1 (2026-06-06)**: 13 BLOCKING — time seam / AC-15 atomic / AC-21 Private-Mode unsatisfiable / API shape / #11 EC-21 rejection / 7 zero-AC rules / craft RNG seed.

**Pass 2 re-review (2026-06-06, fresh verify)**: 11/13 FIXED (2 by-deferral via A1), 1 PARTIAL. Verdict = TARGETED REVISION (focused), NOT structural MAJOR.
- **BLOCKING F1**: AC-20(b) call-order assert(re-push 喺 SALVAGED commit 之前)直接同 Rule 6 mutation discipline(push #11 永遠最後一步)矛盾;Rule 9 / EC-13 / state diagram 三處都寫 re-push mid-sequence;backfill 觸發時「恰好一次 push」不可能成立。正解 = batch 晒 mutations → 單一 final-aggregate push → 單一 persist。
- **BLOCKING F2**: AC-02/AC-03 THEN assert `loot.pending.recovery` write,但 Rule 14 step 5 + Interactions table 兩處 pin「#15 write,#17 boot drain」→ #17 unit test 永遠 fail by construction;receive_loot failure-signal contract(return/signal)未 spec。
- MAJOR: seam list 漏 GSM seam(AC-21/29/30)+ server-time injection(AC-09)+ primary/secondary persistence split(AC-32a);AC-27 round-trip 漏 receipt/provenance(A3 immunity 會 silent break);EC-15 re-entrancy guard 零 AC;manual equip/unequip 零 AC + manual-weaker-then-auto-revert interplay 未寫;Rule 11 cosmetic dupe auto-convert #17 side 零 EC/AC(mechanism 未 spec — dupe 唔係 idempotency dup);unknown item_type rollback + boot schema-shape guard 零 AC。
- **Upstream gates 已執行(grep-verified)**: G-1 #15 MAILBOX_HARD_CAP=180 + stale-60 sweep DONE;G-3 #15 EC-38 RESOLVED;G-4 ADR-0008 L96 added;G-2 partial — #11 已加 `is_boot_completed()`(L228)+ EC-21 wording fix(L526),**residual = `get_attack_power_excluding_equipment()` 未加 + #11 EC-17「apply-without-remove = caller bug」wording 未 bless #17 same-id replace pattern**(唔修 → implementer 會用 remove+apply pair 重開 stat-dip window)。#17 gate table 文面 stale(仍話 100 violates)。
- 正面:golden vectors 全部 recompute 正確(163/84/salvage table/5795);AC numbering 01..31+32a/b 無 dup;craft orphan sweep 乾淨;registry per-key ranges 實證(ATK+300/HP+500/MOVE+100/CRIT 0.20);Formula 1 stale「(AC-22)」應為 AC-18。

**Why:** BLOCKING-gate Logic AC 寫到 by-construction unsatisfiable 比無 AC 更壞([[binding-gate-satisfiability]]);Pass 2 rewrite 引入 2 個 internal contradiction — exit bar for Pass 3 = 0 new contradiction(cross-GDD citation 今次反而全 clean,唔觸發 structural freeze)。
**How to apply:** Pass 3 targeted revision 後用 grep spot-check(AC-20 ordering 字眼 / AC-02-03 ownership / seam list 5→8 項 / AC-27 round-trip set)即可,唔使 full re-review;epic /qa-plan 時重跑 coverage audit + confirm G-2 residual 兩項已落 #11。
