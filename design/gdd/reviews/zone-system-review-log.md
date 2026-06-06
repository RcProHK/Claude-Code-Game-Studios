# Zone System (#19) — Review Log

## Review — 2026-06-06 — Pass 3 — Verdict: ✅ APPROVED
Scope signal: S-M(epic)
Specialists: creative-director(grep spot-check,照 #17/#18 Pass 3 先例)
Blocking items: 0 | Non-blocking notes: 2(AC-08 test 應行 fresh PersistenceLayer 真 load path 唔好自 call parse_string;`last_counted_date` 初始 `""` 自然滿足 guard — implementation comment 一行)
Summary: Pass 2 嘅 6 one-line BLOCKING 逐項 grep ground-truth 驗證 FIXED(#8 Rule 7 L285-293 cite 三中 / `<=` monotone guard + txn-E vector + ADR-0002 L60 確認 / rollback 兩 append + count keep / unix ms ÷1000 + UTC 邊界 fixture / AC-08 fresh-load + typed Array rebuild / drain-persist + over-deliver accepted)。Advisory 4/4 落齊;exit-bar token sweep 全 0;ISO 字典序 claim 數學正確;P1-P6 完好;#18 sync 實際 5 處全一致;EG-4 file 實存。**Epic creation UNBLOCKED → /create-epics zone-system。**
Epic 方向(CD):scope S-M;核心 = ZoneRegistry.tres(editor-saved)+ Rule 2/3/5 pipeline + boot sweep + 12 ACs(4 seams);G-Z-3 + G-Z-1(同 G-PR-3 一齊)跟第一批 story。
Prior verdict resolved: Yes(Pass 2 6 BLOCKING 全 FIXED)

## Review — 2026-06-06 — Pass 2 — Verdict: TARGETED(6 one-line BLOCKING)— fresh 3-verifier
Scope signal: M
Specialists: systems-designer + qa-lead + godot-specialist(fresh context)
Blocking: 6 | 結果: Pass 1 全 FIXED;12/12 exit bar;**0 phantom**;qa lane PASS(12 ACs:10 PASS / 2 WEAK / 0 FAIL)
Summary: 6 targeted — #8 cite 編號精確化(verifier disagreement,ground truth:Rule 7 code block 正係 write-then-emit+erase rollback,標題係 milestone — cite 改 L285-293 雙引)/ `==`→`<=` monotone date guard(ADR-0002 L60 epoch full-resync 重派 → count 全史 double 漏洞)/ rollback 漏 ceremony_pending(desync + duplicate queue)/ completed_at 係 unix **ms**(WST L68 — 唔 pin 會令 per-day cap 靜默失效)/ AC-08 同 instance cache read = JSON coercion 零 exercise phantom-pass(typed Array[StringName] rebuild 係 codebase 首例)/ drain 後 persist path 冇 cover。Advisory:Rule 4 assert 字眼 / AC-04 vectors / AC-12 functional / EC-5 unreachable note / zone.unlocked assert / straddle bound note。
Prior verdict resolved: Yes(Pass 1 12 BLOCKING 全 FIXED + exit bar 12/12)

## Review — 2026-06-06 — Pass 1 — Verdict: MAJOR REVISION NEEDED
Scope signal: M(P1+P2 軸重裁後;表面係 L)
Specialists: game-designer, systems-designer, economy-designer, qa-lead, godot-specialist + creative-director (senior)
Blocking items: 12 | Recommended: ~8
Prior verdict resolved: First review(degraded inline authored 2026-06-06)

### Summary
架構方向五員一致 sound(薄容器 / data-driven registry / retroactive sweep / 永久性 binding)— 零概念重做。問題集中:(1) **P1 大發現 [economy]**:#8 streak = 連續 calendar day 零 rest-day grace(grep streak_system.gd 實證)→ STREAK_MILESTONE 做 content gate 對 3x/week 默認玩家**數學上不可達**,且誘發 junk-workout farming,同 #8 Sick Day Test 精神對撞;(2) #18 同款 phantom bug class 大規模重現:#9 `workout_completed` signal + `workout_id` field 唔存在(shipped = `workout_completed_forwarded(completed_at, transition_id)`)/ #8 milestone 鏈 spec'd-not-shipped 零 gate / #18 lifetime count 零 getter / `zone.` namespace 未註冊 / EC-1 backend-reconcile phantom 機制 / G-Z-1 chain 數學上不可滿足(EnemyDirector pos 12 < PrDetection pinned pos 19);(3) qa:9 ACs 1 PASS / 3 WEAK / 5 FAIL + seam 章節整章缺失。

### CD 裁決(P1-P6,binding)
- **P1**:v0.2 zone gate primary = **WORKOUT_COUNT**;STREAK_MILESTONE 從 schema 刪走;composite any-of 否決(speculative)。**EG-4 開立**(#8 reachability erratum — 見 production/escalations/EG-4-streak-reachability.md;fresh-session CD adjudication;唔 block #19)。#19 留 Design History note 引 EG-4。
- **P2**:PR_MILESTONE enum 刪走(錯 capability 貴過缺 capability;Σmagnitude 軸要 float,int threshold 表達唔到;.tres 後加零 migration 成本)。最終 enum `{ALWAYS, WORKOUT_COUNT, UNKNOWN}`(ADR-0007:sentinel last)。
- **P3**:單 key `zone.state` envelope `{schema_version, workout_count, last_counted_transition_id, last_counted_date, unlocked_zone_ids[], ceremony_pending[]}`;ALWAYS zones derived-not-persisted;manifest 只加不減 assert。
- **P4**:訂 #9 `workout_completed_forwarded(completed_at, transition_id)`(shipped workout_state_tracker.gd:69;transition_id dedup — loot_drop_system.gd:582 先例;fabrication-guarded path,#20 教訓 count 永不行 raw)。
- **P5**:Zone loot **lateral** forward contract:「zone-specific loot pools 必須 power-budget-neutral;zone 差異只可以 thematic / cosmetic / variety」— 封 streak→zone→boss loot→equipment FR-3 power-laundering。
- **P6**:unlock persist 永遠即時;presentation ≤ 同 session post-workout summary;mid-workout → #33 排程;boot-sweep → persisted `ceremony_pending` queue,**drain 做單一 aggregated reveal**。

### Top-5 revision(R1-R5)
R1 軸重裁(enum + 全部 STREAK/PR 觸點刪 + EG-4 + Fantasy 錨定時刻改 count 軸)· R2 signal contract(forwarded + transition_id dedup + **per-calendar-day cap 1** — count 正名 training-day count,junk farming 物理免疫)· R3 persist(envelope + write-success-then-emit [#8 樣板] + EC-1 改 local sweep recovery + G-Z namespace gate 照 G-PR-6)· R4 boot chain(`Persistence ≺ WST ≺ ZoneSystem` tail append;刪 `ZoneSystem ≺ EnemyDirector` 投機 constraint + `PrDetection ≺ ZoneSystem`;wiring = plain consumer connect,G-PR-4 reverse-wire 唔適用)· R5 ceremony queue + lateral contract + seam 章節(4 類)+ 9 ACs 重寫(AC-07 validate form / AC-09 拆三件套 / AC-06 transition_id)。

### RECOMMENDED
bidirectional sync flags 段(#18 樣板)/ Array[ZoneDef] keep + editor-saved + load smoke AC(Dictionary 會令 duplicate assert 物理不可觸發)/ workout_count 唔 backfill veteran 歷史明文 / Q-Z-1 telemetry small-N honesty + #28 依賴寫明 / v0.2 time-to-unlock pacing 表 / ALWAYS derived note。

### Exit bar(12 項,全 grep-verifiable)
1. `workout_completed`(非 `_forwarded`)→ 0;2. `workout_id` → 0;3. `STREAK_MILESTONE|PR_MILESTONE|streak_milestone_reached|pr_milestone_reached|streak_milestones_unlocked|lifetime` → 0(EG-4 note 用「streak / PR 軸」字眼);4. `reconcile` → 0;5. G-Z-1 段零 EnemyDirector ordering constraint;6. `zone.state` ≥1 且 `zone.unlocked.` → 0;7. write-success-then-emit 明文;8. `ceremony_pending` ≥1 + aggregate 規則;9. lateral/power-budget-neutral ≥1;10. BLOCKED-ON 標記齊 + EG-4 ≥1;11. AC 全 GWT,零 raw assert,AC-09 拆三;12. `zone.` namespace gate 條目。**+ 0 new phantom**:每條上游 cite 附 file:line,re-review 逐條 grep。
