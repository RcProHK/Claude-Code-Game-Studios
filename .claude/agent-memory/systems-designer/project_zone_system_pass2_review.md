---
name: zone-system-pass2-review
description: "#19 Zone System Pass 2 re-review 2026-06-06: Pass 1 全 FIXED (12/12 exit bar + B1-B4), CD P1-P6 faithful; 3 NEW BLOCKING (cite 錯 rule no. / epoch-reset full-resync 破單slot dedup / EC-7 rollback 漏 ceremony_pending)"
metadata:
  type: project
---

# #19 Zone System — Pass 2 fresh verification re-review (2026-06-06)

**Verdict: 仍有 BLOCKING — 但係 targeted NEEDS REVISION(3 項 localized),唔係 MAJOR。**

Pass 1 戰果:exit bar 12/12 grep PASS;B1-B4(phantom signal/field、G-Z-3 namespace、EC-1 backend phantom、#8/#18 dep 刪除)全 FIXED;CD P1-P6 全部忠實執行;#18 pr-detection.md 三處 sync 乾淨(L21/L99/L129/L131/L286/L352 一致「MVP 無 consumer」,零殘留「已接」);EG-4 file 存在;enemy_director.gd 零 zone 觸點。

**3 NEW BLOCKING(全部 revision 自引)**:
1. **B-NEW-1**:Rule 5 cite「#8 Rule 7 樣板」錯 — #8 Rule 7 = milestone emit-once(streak-system.md L280);write-success-then-emit 真身係 **#8 Rule 3**(L155 atomic skeleton,L188-193)+ Rule 9。
2. **B-NEW-2**:Formula variance note claim「out-of-order redelivery 由 #2 cursor ordering 保證唔出現」— **ADR-0002 L60 明文反例**:server_epoch_id mismatch → ignores last_event_id → **full resync(event replay)**。歷史 event 重派時單 slot {txn, date} dedup 全穿(txn 係 GSM acquire 嘅 fresh id,WST L476;date ≠ last_counted_date)→ count 全史 double = unlock-currency inflation(anti-Pillar 1)。Fix 一個 operator:`day == last_counted_date` → **`day <= last_counted_date`**(monotone date guard,full resync 下全 no-op,under-count 方向安全)。
3. **B-NEW-3**:Rule 5/EC-7/AC-10 rollback 只還原 `unlocked_zone_ids`,**漏 `ceremony_pending`**(Rule 3 兩個都 append 咗)→ ceremony-without-territory + boot sweep 自愈後 duplicate queue entry(違 EC-2「唔重複 queue」+ AC-11 aggregate)。Fix:rollback 範圍 = Rule 3 兩個 append;count/cursors 明文 keep in-memory(下次成功 persist 帶埋)。

**Why**: 再一次實證 project 嘅 fix-pass-自引-新問題 regression class — 今次唔係 phantom dep,係 (a) cite 加錯編號 (b) 新加 variance claim 同 shipped ADR 對撞 (c) 新機制(P6 queue)同舊 edge case(EC-7)嘅 interaction 冇 re-derive。
**How to apply**: review 任何 revision 時,新增嘅 upstream claim 要 grep ADR 原文(唔只 GDD);新 state field 加入 envelope 後,所有 rollback/recovery path 要逐個 re-enumerate 佢嘅去向。
相關:[[pr-detection-pass2-review]](#18 同日 Pass 2,同款 pattern)。
