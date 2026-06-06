# Loot Drop Modal (#21) — Review Log

## Review — 2026-06-06 — Verdict: MAJOR REVISION NEEDED
Scope signal: XL(11 deps、6 formulas、9+ gates、ADR-0001 revision、3 upstream erratum)
Specialists: game-designer · systems-designer · ux-designer · qa-lead · godot-specialist · gameplay-programmer · audio-director + creative-director synthesis(opus)
Blocking items: ~25(去重後 8 clusters)| Recommended: ~20 | Nice-to-have: ~12
Prior verdict resolved: First review(authoring 時 7-specialist 諮詢屬 design-time,唔係 review)

### Summary
Fantasy 同 presentation craft(F1 satisfiability、F2 provable floor、INV-M1 single-exit、flashbulb framing)係 approve 級;問題集中喺 cross-system seam:① pull-model queue binding 建立喺對 shipped #15 `_pending_drops` 雙語意嘅誤讀(backend ACK erase → online reveal 蒸發 — silent phantom class);② GSM downstream contract 四項(L127/L128/L375 b/c/d)grep 已確認 negative,唔可以等 epic;③ camera choreography 用 shipped #7 寫唔出(focal_completed 時序誤讀 + 數值三源 + item_world_pos unsourced);④ #6 freeze ledger/saturation/audio-pause 三項 phantom 基建;⑤ FSM/F2/F5 內部矛盾;⑥ audio spec 斷裂(catalog gate 真空 + stream 機關槍 + sting 三源)。

### CD 裁決(D1-D5,binding)
- **D1**:推翻原 CD-GDD-ALIGN blend — **S3 = 唯一 commit point;pre-S3 force-close = cancel + 留 pending + re-reveal**(唔 emit modal_dismissed)。跟 GSM L127/L375(d) locked contract +「未撳快門 = 未影相」哲學。Post-S3 force-close 維持 stash-exit auto-collect(已 banked)。
- **D2**:**Accept frozen-focal 並升格做機制** — `ceremony_freeze` 錨喺 `focal_completed` → 凍 camera 喺 peak = de facto per-tier hold;#7 API 零 change;orbit drift cut from MVP。
- **D3**:Verdict = **MAJOR**(first-round,唔觸發 freeze;findings 屬 authoring-time pre-existing class)。
- **D4**:catch-up audio = **sustained 淺 duck + 單一 aggregated stream cue,禁 per-beat fanfare**。
- **D5**:**保留 two-stage tap,F5 math clamp 修**(`S3_entry = min(t_tap + SNAP, T_block)`,natural completion supersede)。

### BLOCKING clusters(fix pass 對象)
1. **#15 queue 雙語意**[gd B-1 / gp B1-B3]:`loot_drop_system.gd:766-779` backend ACK erase `_pending_drops` → reveal 蒸發;dequeue 反方向 → boot recovery re-reveal;micro_ack drops 入 queue 但 LootDrop 冇 ceremony field → #21 錯誤 full-ceremony cap-degrade 件;micro_ack 件冇人 bank(Rule 9「已 grant」phantom)。→ G-LM-4 scope 重寫:revealed/sync state 分離 + ceremony kind 持久化 + micro_ack banking。
2. **GSM contract ×4**[ux B1-B3 / gd B-2 / qa B-1]:L127 retry 語意(re-reveal)vs Rule 7/8;邊個 clear `loot_reveal_pending` 無定義 → ghost loop;L128 drain ONE vs drain-all;L375(b) 未開封 item entry 結構上不可能;L375(c) INTERRUPTED_WITH_CREDIT fast-victory variant 零提及;exit seam 方向(qa:locked 機制係 `loot_confirmed` #15 emit,唔係 #21 call GSM)。
3. **Pre-S3 force-close item 黑洞**[gd B-3 / qa B-2]:15s 係 entry gate 唔係 suppression;rest_ended event-driven;S0-S2 force-close → dequeue 但未 bank;AC-1 自己 parametrize pre-S3 stash-exit。→ D1 解。
4. **Camera**[gd B-5 / sd B7-B8 / godot B-2/B-3/B-4 / gp B4-B6]:(0.6,1.4) hardcode vs #15 per-tier(RARE 冇 focal)未裁決;focal_completed @ entry-tween 完成(`camera_controller.gd:364-376`),EC-M9 gate 修唔到 silent DROP;「focal 剩餘」無 API;#7 冇 hold phase;focal tween pause-bound;**item_world_pos unsourced**(LootDrop 冇 position field)。→ D2 重寫 choreography。
5. **#6 基建**[godot B-1/B-5/R-3 / gp B7]:`get_tree().paused` pause 埋 AudioManager(PAUSABLE)→ fanfare stutter @ peak,AC-16 spy 驗唔到;freeze「ledger」shipped 係 scalar,無早收 release API;**saturation API 唔存在**(grep 全 src/ 零實現)。→ G-LM-3 重寫 + G-LM-9(process-mode)。
6. **FSM/Formula 內部矛盾**[sd B1-B6/B10/B11 / gp B8/B9]:FSM 冇 catch-up states/edges(GRID tap-close 冇 GSM notify → deadlock);rollback-cancel → GSM stuck;F2 pct=100/0(ws=0.8/rr=0 legal)否證 AC-42;F5/AC-15 debounce 錨點矛盾;F5 race near T_block;S3 rollback = show-then-revoke;STASH_COLLAPSE range 0.25+0.1>0.3 違 F6;F4 merge-vs-cap 未定義;stage table vs F1 vs FSM 三種 timeline 讀法。
7. **Audio**[ad B-1..B-6]:4 新 cue 零 catalog gate(→ G-LM-8);fanfare caller 應 inline 釘死 = #21(EG-1 precedent);stream audio 零 spec(→ D4);micro_ack sting 三源矛盾(#15 L204 vs §G tick vs flush gate)→ 裁 toast 一律 low/mono tick + #15 L204 erratum;#15 duck 列 stale(−16 出界 / 0dB base 錯)→ Rule 4 剔走 duck + erratum;Rule 14 sting 承諾 scope note。
8. **其他**:receive_loot caller relocation 斬斷 #17 EC-1 recovery chain(冇人寫 `loot.pending.recovery`);AC-21 lint 冇 owner-exempt(inventory_system.gd 4 internal call sites)→ day-one RED;AC-72 對 shipped #17 不可滿足(debounce 一 frame vs 0.15s beats);stream 6.7 beats/s vs ≤3 flash/s;CJK font 斷裂(Zpix 12px 零引用;% label ≈130px > W_BAR_MIN 120);「稍後再拆」affordance 冇 input policy;catch-up 19s > 15s window(peak-end 被斬最高 tier)。

### Disposition
- **Inline 必修**:Cluster 2/3/4/6 + 7(b)(c)(f) + 8 全部。
- **Erratum ×3**:#15(sync/reveal 分離 + micro_ack banking + duck 列 + L204 + L1102 + FR-2 anchor + AC-18/EC-28 + hex 已有)/ #17(EC-1 recovery ownership + caller relocation)/ #4(catalog source #15→#21)。
- **Gates**:G-LM-3 重寫(ledger 新增 + 早收 release API + saturation 明寫新增)/ G-LM-4 重寫(state 分離 + ceremony kind + micro_ack banking)/ 新 G-LM-8(#4 catalog co-design:event_id/priority/channels)/ 新 G-LM-9(#4 AudioManager process-mode ALWAYS + coordinator ALWAYS)。

### Exit bar(fix pass 完成標準)
1. 0 new phantom — 全 citation enumerate + grep,唔准 sampling
2. GSM 四項 reconcile 各附 line number(兌現 / G-flag / erratum 三選一,唔准漏空)
3. 統一 timing model 表(stage table = F1 = FSM 單一讀法)
4. 全 AC shipped-code 可滿足(AC-13/15/16/21/42/72 重寫)
5. 三份 erratum draft 齊

---

## Fix Pass — 2026-06-06(same session)— 8 clusters 全部 inline 修正

**Exit bar 自檢**:
1. ✅ Stale-reference sweep ×5 輪 grep(`item_world_pos`→`reveal_anchor_pos` / `tap 收藏`→`影低佢` / `唔做 re-reveal` / `(0.6, 1.4)` / `modal_dismissed(transition_id)`→`(drop_id, terminal)` / orbit / focal lock / Stamped 語序 / STUB / 現有 API / 通知 GSM / 降一 tier — 殘留 match 全部係 Pass-1 修正注釋 intentional quote)
2. ✅ GSM 四項 reconcile @ Rule 13b(a 兌現 / b defer v0.2 + erratum + OQ-6 / c 兌現 UI §B slot 4 / d 兌現 Rule 8 pre-S3)+ L128 erratum @ Rule 6 + exit seam @ Rule 6(`loot_confirmed` chain,grep GSM L234/L363/AC-14 + `game_state_machine.gd:446` 確認)
3. ✅ 統一 timing model 表(FSM section)+ stage table 重寫 + F1 D2 order flip(S2a hold/focal → S2b freeze;T_block 數值不變,equality 保留)
4. ✅ AC 重寫:AC-1/2/10/12/13/15/16/18/19/21(owner-exempt)/22/27/28/29/30/34/37/42/43/46(15.8s)/47(10.3s)/49/50/51/52/54/58/60/65/71/72(batch frame)/73/76/78/84/85/87 + 新增 AC-22b/30b/34b/37b/37c/76b/88 → **94 ACs**(71 unit / 9 integration / 3 static / 10 manual / 1 mapping;gated 19 條)
5. ✅ Erratum drafts ×4(#15 ×9 項 / #17 ×2 / #4 ×2 / GSM ×2)@ Bidirectional sync flags

**D1-D5 落地**:D1 → INV-M3 + Rule 7/8 pre-post-S3 split + AC-22b/52;D2 → Rule 4 freeze-as-hold + F1 order + EC-M9 margin 機制 + AC-12/60;D3 → 本 entry;D4 → Rule 10 stream aggregated cue + sustained duck + AC-28 negative spy;D5 → F5 clamp + 錨點統一 + AC-15/50。

**Gates**:G-LM-3/4 重寫(scope 反映 shipped 真實差距)+ G-LM-8(audio catalog)/G-LM-9(process-mode)新增;G-flag-2/3 部分 resolve(grep 結果記錄入 doc),新 G-flag-4(#7 const)。

**Net 新增物**:INV-M3、CATCHUP_STREAM state、`FOCAL_EXIT_MARGIN_SEC` knob、font 指派表(CJK Zpix 12px)、silent-mode fallback chain、retry-suppression pin、`report_receive_failure` seam、micro_ack banking path、honest-endpoint pct clamp。

**NEXT**:fresh-session(/fresh-verifier-agents)Pass 2 re-review — verdict 前唔開 epic。
