---
name: loot-modal-21-review
description: "#21 Loot Modal review: Pass 1 11 BLOCKING (2026-06-06) → Pass 2 verify (2026-06-07) 7/8 clusters FIXED, 0 new phantom; 殘留 2 BLOCKING one-line 級 (F2 px sum 121≠120 @W=120 / F1 var-table S2a/S2b label 反 D2)"
metadata:
  type: project
---

#21 loot-drop-modal.md review 軌跡。佢係 [[loot-modal-21-consult]] 嘅 review pass — consult 嘅 flags(ceremony_freeze/FAILED_ROLLBACK/F1 equality)全部已落實 ✓。

**Why:** Pass 2(2026-06-07 fresh verify)已對齊 — 8 clusters 7 FIXED / cluster 6 PARTIAL;下一步只需 spot-verify 兩處 BLOCKING fix,唔使 full pass。

**How to apply:** Pass 3 / spot-verify 時只對:① F2 px clamp 後有冇加 `px_w := W_bar − px_r` 同步(AC-42 endpoint case ws=1.0/rr=0.01 @ W=120 係否證 vector:round(119.6)=120 → px_r clamp 1 → sum 121)② F1 variable table L198-199 S2a/S2b label 有冇調返(D2 = hold 先 freeze 後)。RECOMMENDED ×2:FSM rollback edge 冇 in_catchup branch(跳 grid/超 K cap,無 loss);FLUSH_DELAY default 0.1 < §G 建議 0.15。Pass 2 grep 證實 fix-pass 新 cite 全真:screen_effects.gd:55/111、gsm:446 零 caller、camera_controller.gd:355-356/364-376。

**Pass 2 cluster verdicts(2026-06-07)**:1 queue 雙語意 FIXED(G-LM-4 重寫+AC-71 ordering+AC-34b)/ 2 GSM ×4 FIXED(Rule 13b+loot_confirmed chain)/ 3 D1 FIXED(AC-22b/52+N-2 pin)/ 4 camera FIXED(1.4× hardcode 清除,args==#15 table)/ 5 #6 FIXED(G-LM-3 重寫+G-LM-9)/ 6 PARTIAL(上述 2 BLOCKING)/ 7 audio FIXED(G-LM-8+D4)/ 8 其他 FIXED(AC-72 batch-frame 即時可執行)。Formula 重驗全過:F1 table 200/350/650/950/1200 equality ✓、F3 15.8 bound(conservative — 首 gap 實為 0.3)+ example 10.3 逐步重算 ✓、F4 守恆 ✓、F5 clamp 850=600+250 ✓、F6 0.3 閉合 ✓。INV-M3 vs Rule 9 banking 無抵觸(population disjoint)。

11 BLOCKING ground truth:
1. F2 rr≈0 區域(rr < ~0.02×score)→ pct_w=round_half_up(≥99.5)=100、pct_r=0 — AC-42「pct∈[1,99] 恆成立」被 legal input 否證(例:ws=0.8,rr=0 → frac_w=1.0)
2. F5 debounce 錨點:AC-15(由 S2 tap 計,t+0.3 dismiss)vs F5 example(由 S3 entry 計,850=600+250)直接矛盾
3. F5 race:t_tap ∈ (T_block−SNAP, T_block) → T_block_fast > T_block,claimed range「< T_block」假;natural-completion 雙路入 S3 未定義
4. FSM 冇 ENTRY/STEADY rollback edge(AC-30 ×4 vs AC-37 table-driven 衝突);S3 rollback = item 已 banked + content 已見 → 撞 Rule 11「永不 show-then-revoke」;正解應係 post-grant 當 no-op
5. rollback-cancel → HIDDEN 但 GSM 留喺 LOOT_DROP、queue 冇 re-drain/terminal-dismiss → deadlock(EC-M6 有 advance,Rule 11 冇)
6. catch-up FSM 唔完整:EXITING 冇 →CATCHUP_GRID edge(queue空→HIDDEN+通知GSM 早咗);CATCHUP_GRID tap-close 冇 GSM notify(deadlock);CATCHUP_PROMPT 冇 force-close edge;stream phase 冇 state
7. EC-M9:focal_completed 喺 entry-complete fire(camera_controller.gd:364-367,exit tween 之前;#7 EC-08 明文 exit tween 期間 reject)→ gate 喺 focal_completed + 0.3s gap 照中 silent DROP;0.8+0.5=1.3 算術同 AC-13 嘅 0.6 entry 對唔上
8. AC-13/Rule 4 釘死 request_focal(pos, 0.6, 1.4) 全 RARE+ — 但 Rule 4 同時話 camera per-tier 數值 #15 own(#15 L1032-1034:1.02×/0.3s、1.05×/0.65s、1.08×/0.8s)— 同 hex 裁決同類 cross-doc conflict 漏咗裁
9. AC-72(即時可執行)斷言 catch-up N 件 persist 各一次 — #17 Rule 13 debounce = process_frame ONE_SHOT(一 frame),stream beats 隔 0.15s → N 次 persist,不可滿足
10. STASH_COLLAPSE_SEC safe range 上限 0.25 + jitter 0.1 = 0.35 > F6 budget 0.3 → AC-51 喺 safe range 內 fail(binding-gate satisfiability class)
11. F4 merge-vs-cap 邊界:ack 喺 remaining-to-cap < MERGE_MIN_REMAIN 時(t∈(2.4,3.0))merge 定 carryover 未定義 → AC-49「count 守恆」不可 deterministic 實現

Key RECOMMENDED: F2 guard order(EC-M15 check 要喺 frac_w 除法之前,防 score=0 div-by-zero);AC-43 hardcode W≥120 但 knob 去到 88;#15 L1102「所有 RARE+ 仍各自獨立 ceremony」vs K_CEREMONY_MAX 折 grid — erratum list 漏咗;FR-2「emit 後 100ms」(#15 L1082)→「reveal-trigger 後」re-anchor 漏 erratum;inventory_system.gd:145 doc comment 話「#15 calls after dismiss」vs #21@S3 唯一 caller 冇 #17-side gate;camera focal tween 喺 ceremony_freeze tree-pause 下會 stall(G-LM-2 只 cover particle)。

Citations 全 verified ✓(screen_effects 55/344-346/362、camera 99、inventory 161-163/180、equipment_enums 56-62、GSM 441 + MIN_REVEAL_WINDOW=15、#15 L1059/L1081/L1031-1034、BFCACHE 30s)。loot_micro_ack(drop_id) shipped code 存在(loot_drop_system.gd:100)— #15 GDD signal table 反而漏咗,#21 cite 啱。
