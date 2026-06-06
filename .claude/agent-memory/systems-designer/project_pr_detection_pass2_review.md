---
name: pr-detection-pass2-review
description: "#18 PR Detection Pass 2 fresh verification 2026-06-06: B1-B8 7 FIXED + B7 PARTIAL; 4 NEW BLOCKING (AC-30 buffer 矛盾 / D-2.3 ratchet 缺 D8 語意 / D-2.2 下界 0.5 hole / D8 stale-magnitude 破 INV-PR-2); 0 new phantom"
metadata:
  type: project
---

#18 pr-detection.md + ADR-0011 Pass 2 re-review 結果(2026-06-06,我做 fresh verifier):

- **B-1..B-8**: 7 FIXED + B-7 PARTIAL。Revision 質素高,Position A-F 全落實,exit bar 新 AC 六項齊。
- **Citation 鏈 0 phantom**(~20 條全 grep 上游 line 核實:#11 L553/L616/L39/L254-255/L323/L338-340;#12 L57/L223/L498/L532;ability_system.gd:884-899(L890 comment 真係錯寫「delta」✓);wst L863;#2 L87/L479/L668;#15 L293;zone L22/L39-64;persistence_layer.gd 249-377 無 enumeration ✓ / 291-294 ✓;GSM enum 無 READY state)。
- **4 NEW BLOCKING(全部 targeted small fix,非結構)**:
  1. AC-30「buffer 一格 flush」vs Rule 10「無 SUSPENDED queue」vs Rule 6.7「belt-and-braces assert」三向矛盾;且 pr_delta==0 short-circuit skip 6.3 → 「結構上唔可達」claim 喺 cap path 不成立,gate 係 load-bearing。
  2. ADR-0011 D-2.3 server ratchet「判定規則 = client」只括注 noise floor,冇講 D8 corroboration → typo set 入 server ratchet → 下一 boot baseline poisoned high = B-4 同類壓制經 server 軸重現。
  3. D-2.2 下界 `v > 0.0` 收 0.5 級 entry(client 可產生最細 e1rm = WEIGHT_SANITY_MIN×31/30≈1.033)→ tiny baseline → clamp-2.0 假 max PR + 正常 set trivially corroborate = B-3 ÷0 嘅 sibling。Fix:`v >= WEIGHT_SANITY_MIN`。
  4. D8 pipeline integration 未 pin + **commit 用 open 時 stored magnitude 會破 INV-PR-2 upper bound**(worked:baseline 70,pending raw 94.5 m=0.35;期間正常 PR 70→76 m=0.0857;corroborate commit stored 0.35 → Σ0.4357 > honest bound 0.35)。Fix:commit 時對 current baseline 重計 magnitude。
- MEDIUM:Rule 10「發 async baseline sync 請求」vs D-2.4「隨 polling response」措辭(load-bearing for B-5 seal);INV-PR-2 lower bound 喺 clamped step 不成立(ln(10)=2.303>2.0,要 qualify);`candidates_workout_unix` orphan field(語意未 spec + 撞「無 clock 依賴」claim);Formula 4 mid-window candidate 棄用可 lose 真突破(撞 D5 under-count 原則)。
- **Lesson 實證**:Pass 1 BLOCKING 嘅 degenerate CLASS(server 值 degenerate / typo 壓制)named-instance fix 咗但 sibling 未掃齊 — 同 [[#16 Boss lesson]] 一致:fix 後要 class-sweep,唔係淨驗 named instance。
