---
name: loot-drop-modal-qa-review
description: "#21 loot-drop-modal GDD QA review — Pass 2 AC sweep (2026-06-07) verdict TARGETED REVISION: counts 94 ✓ 但 2 BLOCKING 殘留(AC-28/58/72 #17 batch 機制誤讀 + AC-37b outcome field phantom);Pass 1 5 BLOCKING 中 4 真 FIXED"
metadata:
  type: project
---

#21 loot-drop-modal.md QA review 歷史(qa-lead)。

**Pass 1(2026-06-06,fresh adversarial AC review,87 ACs full sweep + 全 citation grep-verify)**: **TARGETED REVISION**

**5 BLOCKING:**
- **B-1 GSM exit seam 衝突**:GSM locked 機制 = #15 emit `loot_confirmed` → GSM → IDLE(gsm GDD L214/234/363/AC-14 L705,direct-call spy==0);`loot_confirmed` src/ 零 match(#15 未實裝);`_check_pending_loot_reveal()` 零 caller(Rule 13 trigger 未 wire,#21 L53「已 shipped」過度聲稱)。AC-19/73「#21 call GSM 通知」assert 錯 seam。Fix:行 #15 chain + zero-direct-call negative spy;G-LM-4 擴 scope 包 loot_confirmed。
- **B-2 pre-S3 force-close = item 永久消失 hole**:MIN_REVEAL_WINDOW 喺 code 只係 const+invariant assert(gsm L114/671),GSM GDD L211 用法係 entry 條件 — Rule 7「結構上唔存在」無 code 支持;AC-1 自己 parametrize stash-exit@S2a;pre-S3 stash-exit → emit modal_dismissed(dequeue)+ 未 receive_loot = loss。Fix:新 EC-M21(bank-then-stash 或 cancel-leave-pending)+ G-flag-4。
- **B-3 AC-15 vs F5 debounce anchor 矛盾**:F5 example 850ms = S3 entry+0.25;AC-15 第三 tap t+0.3 = S3+0.2 → 兩條互 fail。Pin anchor(建議 S3 entry)。
- **B-4 AC-13 hardcode (0.6,1.4) 違 Rule 4 自己「唔另印數」+ 同 #15 ladder 衝突**(camera per-tier 1.02×0.3s/1.05×0.65s/1.08×0.8s;RARE 係 pulse 唔係 focal;EC-M9 自用 0.8s)。Fix:per-tier 由 #15 config 讀;RARE focal 裁決。
- **B-5 AC-21 lint day-one RED**:inventory_system.gd 內部 4 個 receive_loot( call site(162/313/319/457)。Fix:owner-exempt(debug-override PR #12 同 class)。

**13 RECOMMENDED(撮要)**:R-1 coverage counterexamples(Rule 5 scrim 零 AC / Rule 2 doorbell positive 零 AC / Rule 12 banner 幾何零 AC / AC-35② mapping 錯 cite AC-31);R-2 gated 自檢「12 條」實 13 +「全有先行斷言」對 AC-54/75 唔真;R-3 distribution「7 gated」實 6 + AC-56 跨類 + AC-77 manual 半邊冇入數;R-4 AC-78 漏 gate(#20 banner 係自己 node GymModeHud.tscn:97 → 要 G-LM-8);R-5 fake-clock seam 未 spec(AC-14/40/49/52/60)+ AC-40 equality flaky;R-6 AC-46/47 vs F3「唔使 runtime time-projection」矛盾 → spec pure build_catchup_plan();R-7 G-LM-6「現時 STUB」唔準(announce_aria 完全唔存在);R-8 FR-2 locus 重詮釋(#15 L1083 emit→onset vs reveal-start→onset)未入 erratum;R-9 negative spy 配 positive control(AC-16/30);R-10 test_*.gd prefix 未 pin;R-11 AC-26 CATCH_UP_THRESHOLD 係 function-local const(loot_reconcile_calc.gd:139)→ 改用 catch_up_threshold_compression() API;R-12 AC-37 assert/no-op 二擇 + AC-28「<<24」非 bound;R-13 AC-12 fanfare 序 vs AC-76 @S0 reconcile。

**6 NICE**:T_banner_beat 冇入 var table;F4 [1.2,3.0] vs 1.5s 定義;sign-off role 具名;AC-83/86 主觀字眼加 companion;FSM vs S-stage concurrency 對映(LEGENDARY freeze 全喺 ENTRY 內);GSM table L214 LOOT_DROP 冇 Suspended exit(EC-M1 premise 未 model)。

**驗證 PASS(credit)**:F1/F2/F3 arithmetic 全啱(87/73px、55/45、14.3s、10.0s、motion-reduction ladder);#15 ladder/hex/L1059/L1081 cite 全 verbatim 啱;ReceiveResult 5 值/inventory:180/screen_effects:55/344/362/camera counter/SAFE_STATES 三州 全證實;EC-M1–M20 全 mapped;87 條冇「feels good」class。

**Why:** B-1/B-2 顯示 G-flag 機制嘅盲點 — 將「grep 到答案」推遲去 epic,但答案而家已 grep 得出且推翻 baseline 設計;verification flag 唔係 deferral licence。
**How to apply:** Pass 2 exit bar = B-1..B-5 全清 + R-1(a)(b)(d) + R-2/R-3 數字修正;seam 方向要 CD/systems-designer 裁(建議全行 #15 chain)。同 [[zone-system-qa-review]] / [[pr-detection-qa-review]] 同 pipeline;B-5 同 main-CI-RED owner-exempt 教訓同 class。

---

**Pass 2(2026-06-07,fresh verifier AC sweep,94 ACs)**: **TARGETED REVISION — 殘留 2 BLOCKING + 6 RECOMMENDED**

Counts 核實:總數 94 ✓(A3/B39/C14/D19/E10/F9);71u/9i/3s/10m/1map ✓(AC-56「Logic+Integration」計 unit、AC-77 計 unit 嘅 convention);gated 19 條 per-AC tags 完全對應 ✓;唯一 count 錯 = distribution table integration row「(6 gated)」實 8(54/65/71/73/74/75/76/78,只有 72 ungated)。

**殘留 BLOCKING:**
- **P2-B1 AC-28/58/72 + Rule 7「#17 one-frame ONE_SHOT debounce」係機制誤讀**:shipped `_batch_depth` 只由 #17 內部 boot drain(inventory_system.gd:308)同 suspended drain(:454)開;`_mark_dirty_and_flush`(:389-393)depth==0 → 每 call 即 flush;`_push_aggregate`(:838-842)同款。External caller same-frame 24 連發 = 24 push + 24 full persist → 「persist spy == 1」不可滿足。`_defer_one_shot` ONE_SHOT idiom(:478)係 drain/boot-push 用,唔係 same-frame coalescer。Fix 方向:#17 amendment 開 public batch API(或 `receive_loot_batch`)→ 新 gate;AC-28(unit)嘅 persist 斷言移去 AC-72(integration)並 gate。citation-grep-verify 教訓重演:cite #17 EC-22/AC-29 存在但語意係 internal-context-only。
- **P2-B2 AC-37b fast-victory fixture 無 data path(新 phantom)**:`loot_drop.gd` 零 outcome field(只有 source_event_kind 三值 WORKOUT_DAILY/MINI_BOSS/FINAL_BOSS);`loot_drop_system.gd` grep INTERRUPTED/outcome/item_metadata 零 match(producer 唔寫);AC ungated 但 GIVEN 不可構造。Fix:G-LM-4 加 scope ⑧(#15 grant 時讀 BossPayload.outcome 持久化 marker)+ AC-37b 標 gated;或 13b(c) 跟 13b(b) defer v0.2。

**Pass 1 fix 驗證**:AC-15/F5 錨點 ✓、AC-21 owner-exempt ✓(4 sites 162/313/319/457 證實)、AC-22b pre-S3 ✓ 完整、fake-clock seam ✓(統一 timing model)、gated 19 ✓;F1/F2/F3 全數重算啱(15.8/10.3/87px/55-45/99-1 clamp)。但「AC-72 改成 shipped #17 可滿足形式」聲稱唔成立(P2-B1)。

**6 RECOMMENDED**:integration row「6 gated」→8;14.3s stale ×2(Rule 10 + MAX_STREAM_BEATS row)vs 15.8;`catchup_truncated`+`suspicious_dismiss`+`focal_watchdog` telemetry 零 AC;micro_ack-path FAILED_ROLLBACK report 鏈無 AC;AC-2/52/53 fake-#6-seam gate-tag 準則同 AC-1 唔一致;D4 positive half(aggregated stream cue/單 duck handle)無 AC。

**Why:** fix pass 喺 mechanism 層面引用 shipped code 行為時,verifier 必須 grep 到「邊個 context 先觸發」嗰層 — 「batch 機制存在」≠「external caller 用得到」。
**How to apply:** Pass 3 only需 verify 兩個 localized fix(#17 batch gate + 37b data path),唔使 full re-sweep;counts/formulas 已凍結可信。
