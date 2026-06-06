# Equipment & Inventory (#17) — Review Log

## Review — 2026-06-06 — Verdict: APPROVED (Pass 3)
Scope signal: M(salvage-only MVP 縮細咗 Pass 1 嘅 L;craft/upgrade → v0.2 Forge)
Specialists: Pass 2 = systems-designer + economy-designer + qa-lead + godot-specialist(4 fresh verifiers)→ Pass 3 fixes → creative-director grep spot-check(final verdict)
Blocking items: 0 remaining | Soft gates: G-5(#3 write_batch optional)/ G-7(#2 server time)/ G-8(#3 namespace 表)— epic 時做,唔 block
Summary: Pass 2 確認 Pass 1 全部 blocker 真實 FIXED(5 specialist 收斂);新發現全 line-level(phantom constant、tombstone timestamp、salvage ordering、ReceiveResult contract、no-loss pins),Pass 3 同日全數落地 + 上游 amendments grep 實證(#11 EC-17 atomic-replace pin / #15 EC-47 reconcile + L297 exception / G-1~G-4 全 RESOLVED)。三輪以嚟首次零 phantom、零 new orphan。**#17 可進入 epic decomposition。**
Prior verdict resolved: Yes — Pass 1 MAJOR REVISION NEEDED(同日)全數解決

### Pass 2 詳情(4 fresh verifiers,2026-06-06)
- Pass 1 blocker 驗證:systems 5/5 FIXED · economy 5/5 FIXED(F-D~F-H)· qa 11 FIXED + 1 PARTIAL · godot 5/5 FIXED
- 新 BLOCKING(全 line-level):`LOOTDROP_PENDING_HARD_CAP_DAYS` phantom(真名 #15 `HARD_CAP_DAYS`=37)· tombstone id-only 無 timestamp(prune unimplementable + Contract 2 opacity)· D9-vs-EC4/5/AC-05/06 leftover · AC-20 ordering 同 Rule 6 矛盾 · AC-02/03 assert #15-owned write(unsatisfiable)· #11 EC-17「caller bug」wording 衝突 · no-loss windows(volatile queue / recovery-clear 次序)
- 數字獨立重計全 PASS(163 golden / 84 clamp / 5,795 faucet / 37日 boundary / per-key ranges)
- Verdicts:NEEDS REVISION(targeted)×2 / APPROVED+1gate / MINOR REVISION — 收斂「唔使 full re-review」

### Pass 3 fixes(同日)
B1/B2 phantom+tombstone → `HARD_CAP_DAYS` 37 + `{item_id: salvaged_at_unix}` · guard re-scope final-dict · salvage batch ordering 四處統一 · `ReceiveResult` contract(`{OK, QUEUED_SUSPENDED, DUPLICATE_NOOP, CONVERTED_DUPE, FAILED_ROLLBACK}`)· `inventory.pending_queue` durable · boot step 8 + recovery-clear 次序 · `_mutating` window · seams 5→8 · AC-27 set 擴 · 新 AC-33~41(共 42 AC)· G-2 第三項(#11 EC-17)+ G-1b(#15 EC-47)落地 · minor cluster 全掃



## Review — 2026-06-06 — Verdict: MAJOR REVISION NEEDED
Scope signal: L(8 dependencies、6 formulas、需 ADR-0008 focused amendment + #11 additive API gate;A1 揀 salvage-only 會縮細)
Specialists: game-designer · systems-designer · economy-designer · qa-lead · godot-specialist · creative-director (senior synthesis)
Blocking items: 3 structural decisions (A1-A3) + 15 blocking edits (B1-B15) | Recommended: 7 | Nice-to-have: 5
Prior verdict resolved: First /design-review(CD-GDD-ALIGN authoring gate APPROVED 2026-06-06 — scope 唔同,唔取代本 review)

### 點解 MAJOR 而唔係 NEEDS [creative-director]
唔係 process-defect escalation(first adversarial review,specialists 冇錯誤級聯)— 係因為逐行修之前要先做 3 個 structural decision(A1-A3),冇咗呢啲決定,Formula 1/3/4/5 嘅 line-edit 全部白做。一個 well-sequenced revision pass 應該夠去 re-review,唔使 freeze。

### 先決策(A1-A3,user 拍板)
| | 決定 | CD 推薦 |
|---|------|---------|
| A1 | Q-4:craft+upgrade 留 MVP vs salvage-only | **Salvage-only MVP** — 消滅 F-E/F-G/F-H;shards 做 visible Forge v0.2 hook;v0.2 用真 telemetry 定價 |
| A2 | Item stat-key model | **Derived-keys-only**(只准 ATTACK_POWER/MAX_HP/MOVE_SPEED/CRIT_CHANCE;禁 STR/DEX/VIT)— 解 phantom API + clamp 攔唔到 + DEX collateral;Pillar 1 更純 |
| A3 | Mailbox 7日 TTL expire | **Auto-salvage 成 shards + receipt 件永不 silent expire** — anti-pillar #3 唔容議價;#17 data rule 唔准 defer #23 |

### Blocking edits 摘要(B1-B15,full detail 喺 CD verdict)
1. Item stat 來源:MVP 5-item fixed stat table(registry)+ 全 doc examples/AC 用 #11 真 default re-ground(消除 0/10/28 三模型)
2. Formula 4 重寫(per A2):真實 computation path、`clamp(raw, 0, cap)`、aggregate push shape(synthetic `&"equipment_aggregate"`)+ same-id overwrite 語意、cap>+300 處理
3. Formula 1 重寫:empty-slot baseline=0、score≤0 永不 auto-equip、clamp-aware 比較、weights 對齊 A2 key set、COSMETIC manual-only、trigger set 補全(empty-slot backfill)
4. item_id 去 hash():`StringName(source_transition_id + "_" + str(drop_index))`
5. EC-2 scope 收窄:provenance validation 只跑 drop-hydration,boot re-hydration 唔重驗
6. Citation 修正:EC-38 重 cite + 答 #15 [OPEN](cosmetic dupe rate = salvage_yield 統一)、SHARD_BASE 自立 rationale、LOOT-followup-05 正確 metric
7. Q-3 重寫 + cross-system gate:#15 MAILBOX_HARD_CAP 100→180 + #15 4 行 stale「60」sweep(上游 defect,#17 surface)
8. Mailbox expire → auto-salvage(per A3)+ claim-when-full spec
9. Intake timing 寫準(modal-dismiss handoff 現實)+ catch-up burst batch-recompute EC
10. Boot/lifecycle:#11 EC-21 reject-retry、SUSPENDED FIFO drain spec、「ADR-0008 ordering 非 signal wait」+ #11 EC-21 wording/sync-getter gate
11. TTL cross-session 時基(Contract 9 係 same-session 設計;server-time sanity + prefer-not-expire grace)
12. `is_locked` 統一 item-level 語意
13. AC bundle:AC-21 split 21a/21b、AC-13 shape、AC-15 call-order spy、time-injection seam、zero-AC rules 各補
14. Dependencies 補 #4 Audio + #33 AttentionBudget(mid-workout chime 行 #33)
15. INV-E1/E2 config assertions(∀tier craft_cost > salvage_yield)

### Recommended(唔 block)
Sanity check 三條數重寫(5,910 不可重現/「25.5≥30」反向/2.2:1 無 sink model)· dirty-save batch/debounce(ADR-0003 single-file 矛盾;bulk-salvage 50 件=50 次 full rewrite)· lightweight provenance 全 tier + SALVAGED tombstone → ledger/codex view(→#23)· CONSUMABLE 20% inert reframe · shard mutation atomicity EC · ADR-0008 amendment + InventorySystem ≺ LootDropSystem · tombstone prune horizon

### Specialist disagreements(CD 裁決)
- game-designer NEEDS REVISION vs CD-GDD-ALIGN 0-BLOCKING → **game-designer 啱**(ALIGN gate 抽驗 4 條 citation 全中,錯嘅正正係冇抽嗰啲)
- Receipt all-tier vs LEGENDARY-only → **GDD 啱**(#15 只承諾 LEGENDARY;補 lightweight provenance 用免費 data)
- Modal-ack gate 入庫 BLOCKING → **降級**(#15 Pending TTL 30日 force-reveal 兜底;改措辭修正 + catch-up batch EC)
- Mailbox expire defer #23 vs #17 rule → **#17 rule**(pillar 保證唔可以住喺下游 UX spec)

### Validation criteria(re-review exit bar)
(a) 全 doc 任何數字例子可由 stat table + formula 重現;(b) 所有 cross-GDD citation 經 exhaustive grep sweep 零 phantom 零 mis-cite;(c) 零個對 merged upstream 嘅行為 churn(additive gate 除外);(d) 每條 binding AC 喺 CI mock 環境可滿足。

### Process 改動(CD 已寫入 agent memory)
CD-GDD-ALIGN 日後必須 enumerate 全部 upstream citation 逐條 grep(含 API 存在性),驗唔晒明標 UNVERIFIED;gate verdict 附 scope disclaimer;authoring-time D-locks 一律 provisional until /design-review。
