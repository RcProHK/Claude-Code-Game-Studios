---
name: equipment-inventory-pass2-review
description: "#17 Equipment GDD Pass 2 re-review 2026-06-06: verdict NEEDS REVISION (targeted) — 2 NEW BLOCKING (D9-vs-EC4/5/AC05/06 pre-D9 leftover cluster; tombstone prune horizon 30d < 37d replay window), all 5 Pass 1 blockers FIXED"
metadata:
  type: project
---

#17 Equipment & Inventory GDD Pass 2 fresh re-review (2026-06-06).

**Verdict: NEEDS REVISION (targeted, 唔係 MAJOR)** — Pass 1 全部 5 個 blocker 真實 FIXED(grep+數學驗證),但揾到 2 個 NEW BLOCKING:

- **B1**: EC-4/EC-5/AC-05/AC-06/Rule 11 scrub 仍然假設「stat 由 #15 metadata 帶入」(pre-D9 model)— D9 下 #17 table-assign、metadata 冇 stat_modifiers,呢啲 AC GIVEN 不可滿足(untestable)或暗示 metadata-merge(打破 D9 determinism)。Fix = guard re-scope 去 post-assign dict + boot path。
- **B2**: Rule 2 tombstone prune 用 `LOOTDROP_PENDING_HARD_CAP_DAYS`(=30,係 #1 GSM constant,唔係 #15)— 真實 replay horizon = 37d(#15 HARD_CAP_DAYS=37 LOCKED + ADR-0006 L688 backend retention 30+7)→ 30d prune 開 7 日 resurrect/double-shard window。「replay 唔可能嚟自更舊 source」claim 係 false。Fix = prune ≥37d + 改 attribution。

**Why**: exit bar = 0 new phantom / 0 degenerate boundary;B2 係 mis-attributed citation + 錯 boundary,B1 係 revision leftover(改 D9 冇 sweep 晒 EC/AC)— 再一次印證 [[orphan-cleanup-fresh-context]] 嘅「每改一處要 grep 晒下游」lesson。

**Key state(防 stale 重複執行)**:
- G-1 已套用喺 #15(MAILBOX_HARD_CAP 100→180 + 60-sweep done;但 #15 EC-47 仍有 stale「100」+ EC-47 reject→orphan_queue 同 #17 Rule 4 evict-oldest 行為衝突,未 reconcile → 建議 G-6)
- G-3 已套用(#15 EC-38 = salvage_yield, RESOLVED 2026-06-06)
- G-2 2/3 已套用喺 #11(is_boot_completed L228 + get_attack_power_excluding_equipment L267 都真存在,語意啱);第 3 項 same-id atomic-replace 未——#11 EC-17 仍叫 same-id double-apply 做「caller bug」,同 #17 re-push 主路徑直接衝突
- #15 L297「loot.* sole writer」vs #17 boot drain 清空 loot.pending.recovery = write-ownership 衝突未 flag
- #3 persistence-layer L346 寫「gsm.inventory.* (TBD)」vs #17 直寫 inventory.* — sync flag 漏

**驗證過嘅數**: golden 163 ✓ / Formula 4 84-90 ✓ / sink 5,795 ✓ / AC-16/17/18/24/25 ✓ / table ≤ contract ranges ✓ / item_id collision-free proof ✓。錯數:Formula 1 range「[0,~700]」(table max ≈169, contract max 565)、Formula 4 raw「[0,270] @ MVP table」(slot model max 90)、Formula 1 golden 標「AC-22」應為 AC-18。

**How to apply**: Pass 3 re-review 時先 check 上面 gate state(G-1/G-3 done,唔好再要求);驗 B1/B2 fix 係咪 sweep 晒(B1 要 grep EC-4/EC-5/AC-05/AC-06/Rule 1/Rule 11 全部);R6 = RARITY_SHARD_MULT ±50% 可造 tier inversion(U<C),建議 monotonicity config assertion。
