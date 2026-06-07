# Equipment & Inventory

> **Status**: ✅ **APPROVED 2026-06-06(Pass 3)** — Pass 1 MAJOR REVISION → Pass 2 fresh 4-verifier re-review(全 blocker FIXED)→ Pass 3 targeted fixes + CD grep spot-check APPROVED(零 phantom、零 new orphan)
> **Author**: frank + agents (design-system / design-review Pass 1 revision)
> **Last Updated**: 2026-06-06
> **Implements Pillar**: Pillar 3 (Drop Euphoria — 主) · Pillar 1 (Real Body, Real Power — 約束) · Pillar 2 (Frictionless Companion — equip 機制)
> **Layer / Tier**: Feature / MVP
> **Depends On**: #3 PersistenceLayer · #11 Stat System · #15 Loot Drop System · #4 Audio Manager (Soft) · #33 Attention Budget (Soft)
> **Review history**: CD-GDD-ALIGN APPROVED 2026-06-06(authoring gate;scope = pillar alignment + 4 citation 抽驗,唔取代 /design-review)→ **/design-review Pass 1 MAJOR REVISION NEEDED 2026-06-06**(5 specialists + CD;review log: `design/gdd/reviews/equipment-inventory-review-log.md`)→ 本版 = Pass 1 revision(A1/A2/A3 user 拍板 + B1-B15 全數落實)
> **Structural decisions (Pass 1, user-ratified)**: **A1** salvage-only MVP(craft/upgrade → v0.2 Forge)· **A2** derived-keys-only(item 永不帶 STR/DEX/VIT key)· **A3** mailbox expire = auto-salvage + receipt 件永不 silent expire

## Overview

Equipment & Inventory 係 Mirror Hero 嘅**「戰利品歸宿」系統** —— 將 #15 Loot Drop 爆出嚟嘅 raw `loot_drop_record` 轉化成 typed、可裝備、可 salvage 嘅 **Equipment item**,管理玩家成個 inventory(`MAX_INVENTORY = 120` + mailbox overflow 7日 TTL → **auto-salvage**),並**透過 #11 Stat System** 將裝備數值餵入戰鬥(aggregated derived-stat modifier → `apply_equipment_modifier`)。

系統 owns 整個 equipment data + lifecycle:**接收(`receive_loot`,由 #21 reveal handoff 觸發)→ 入庫 → auto-equip-if-better → salvage 成 `forge_shard`**。MVP sink = **salvage-only**(A1;craft/upgrade 推 v0.2「Forge」,shards 係 banked currency + visible Forge hook)。所有裝備加成受 **FR-Equipment-AntiSnowball**(`equipment-derived ATK ≤ 3× stat-derived ATK`)硬約束,確保「真身真力」(Pillar 1)永遠係力量主體 —— **裝備係 amplifier,唔係 substitute**。A2 將呢條約束做到結構級:**item 只准帶 derived-stat key(ATTACK_POWER / MAX_HP / MOVE_SPEED / CRIT_CHANCE),永不帶 base-stat key(STR/DEX/VIT)** —— 「真身」stat 喺成個遊戲入面只有真實訓練寫得入。

玩家層面:每完成 workout 爆裝係 Pillar 3 dopamine peak 嘅**實體歸宿**,而 background auto-equip-if-better 守住 Pillar 2 嘅無壓力(玩家 mid-set 唔使理 equip)。Persistence 跟 ADR-0003(backend-primary + `user://` `inventory.*` namespace,localStorage FORBIDDEN)。

## Player Fantasy

**核心情緒**:「**我嘅汗水有實體回報,而且收埋落一本變強嘅帳簿**」—— Achiever fantasy(game-concept.md:Achievers ⭐⭐⭐⭐⭐ loot collection + build identity)。

**錨定時刻**:Workout 做到最後一組,final boss 爆一件 **LEGENDARY**,item 上面 stamped「**鍛造自 180kg × 5**」(F-12 source receipt)。玩家一眼認得 —— 呢件嘢唔係隨機掉落,係**自己嗰日真實 PR 變成嘅實體**。截圖 → 入庫 → avatar 變強。

**帳簿隱喻(承接 #26 Avatar Renderer 嘅 ledger voice,F-1)**:Inventory 唔係一個倉,係**「我變強嘅帳簿」**。LEGENDARY 帶 full `signature_text` receipt(稀缺、儀式級);**所有 tier 帶 lightweight provenance**(Pass 1 新增:由已有 data derive —「拾於 6月3日・腿日」,零上游成本)—— 玩家翻 inventory,每件嘢都認得返自己嗰次訓練。

**時序註記(Pass 1 措辭修正)**:入庫發生喺 **#21 reveal handoff 時**,唔係 set 完成嘅一瞬 —— 玩家 mid-set 唔望 mon 嘅 drop 由 #15 Pending pool 兜住(30日 soft TTL + boot force-reveal),**永不 loss**;下次望 mon 嘅 catch-up reveal 先批量入庫 + auto-equip。「Background 默默變強」嘅準確語意 = 玩家**唔使做任何 equip 決定**,唔係「秒級即時」。

**無壓力面向(Pillar 2)**:玩家**永遠唔使** mid-set 停低理 equip;auto-equip-if-better 喺 reveal handoff 後 background 完成。Equip 嘅「控制權」係事後(#22 Character Screen)先至需要。

**反面界定**:呢個唔係 build-theorycrafting min-max 系統(果個係 v0.2+ skill tree #30 嘅地盤);MVP equipment fantasy = **「睇住自己嘅戰利品累積、認得每件嘢嚟自邊次訓練」**,唔係 spreadsheet 優化。

## Detailed Design

### Core Rules

> **Resolved cross-system decisions(D1–D9;Pass 1 重訂 — authoring 時 D-locks 一律 provisional until /design-review,本版已經 Pass 1 review + user 拍板):**
> - **D1** — #15 registry `ItemType` = 5 個 `{WEAPON, ARMOR, ACCESSORY, CONSUMABLE, COSMETIC}`。#17 **收但 inert**:CONSUMABLE 入庫、可 salvage、唔佔 equip slot、MVP 無主動用途(唔郁 #15 已 shipped weight 表;Q-2 留問 0-weight)。
> - **D2** — 每件 functional 裝備帶 `class_tag {STRIKE, CONTROL, MOBILITY, NEUTRAL}`(#15 `class_affinity_resolution`);cosmetic 強制 NEUTRAL。**MVP display-only**(provenance 顯示 + 將來 #12 synergy hook);唔入 Formula 1、唔影響 equip。
> - **D3**(Pass 1 改)— AntiSnowball cap 對象 = **裝備 `ATTACK_POWER` delta 總和**。A2 derived-keys-only 下無「經 ATK_PER_* 放大」分支 —— 裝備永不加 STR/DEX,所以 raw_atk_contribution = Σ ATTACK_POWER deltas,clamp 喺 #17 完整攔截,零 collateral。
> - **D4** — cap floor:`cap = max(ANTISNOWBALL_FLOOR, 3 × stat_derived_atk)`。**Re-grounded(Pass 1)**:#11 真實新號 default STR=DEX=VIT=10 → `stat_derived_atk = 10 + 10×1.5 + 10×0.3 = 28` → min cap = 84;`FLOOR = 30` 係 **defense-in-depth**(防 #11 future default 改動 / EC corruption-clamp path 令 stat 歸 0),唔係 reachable-state fix。
> - **D5**(Pass 1 改)— salvage / bulk-salvage logic 住喺 #17;#22 / #23 只係 UI surface。**Craft / upgrade 全部推 v0.2「Forge」**(A1)— 見 § v0.2 Deferred Design。
> - **D6**(Pass 1 改)— Mailbox 7日 TTL;**expire = auto-salvage 成 `forge_shard`(價值永不蒸發)**;帶 `source_receipt` 嘅 item **永不 silent expire**(A3,anti-pillar #3 binding)。
> - **D7**(Pass 1 改)— Currency = `forge_shard`。**MVP sink = salvage-only**(滿足 MVP loot-sink MANDATE — MANDATE 對象係 item sink,唔係 shard sink)。Shards 喺 MVP 係 **banked currency**:#23 顯示 balance + locked「Forge — coming soon」hook(Hades 式 locked-sink anticipation);v0.2 用 MVP 真實 accumulation telemetry 定價(Q-5)。Bulk-salvage-by-rarity + item-level lock 入 MVP。
> - **D8**(Pass 1 新增,A2)— **Derived-keys-only**:functional item 嘅 `stat_modifiers` 只准 4 個 key:`ATTACK_POWER` / `MAX_HP` / `MOVE_SPEED` / `CRIT_CHANCE`(#11 真實 derived stat 名,grep-verified)。base-stat key(STR/DEX/VIT)同任何 unknown key 喺 hydration 一律 drop + telemetry(Rule 1)。
> - **D9**(Pass 1 新增)— **MVP item stat = fixed lookup table**(per `item_type × rarity`,見 § Formulas Stat Assignment Table)。**零 runtime RNG**:deterministic、golden-vector testable、無 seed seam 需求。Trade-off 明示:同 type 同 rarity item 完全相同 → dup 更明顯,但 MVP 5-item pool 下 dup flood 本來就係 reality,salvage 就係答案。Per-tier budget roll framework(Formula 7)推 v0.2 連 Forge 一齊設計。

1. **Hydration & Validation** — `receive_loot(loot_drop_record)` 將 `item_metadata: Dictionary`(#15 Q-OQ5 un-typed handoff)reverse-hydrate 成 typed `EquipmentItem`。Hydration 失敗 → **EC-1 rollback**(寫 `loot.pending.recovery` namespace + emit CRITICAL,Pillar 3 no-loss)。Validation 規則(**只適用於 drop-hydration path;boot re-hydration 唔重跑 — 見 Rule 15 + EC-2 scope**):
   - `source_transition_id` missing → rollback(CRITICAL)。
   - `item_type` unknown string → rollback。
   - LEGENDARY 但 `source_receipt` missing → rollback(F-12 binding);其他 tier missing → null OK。
   - `rarity` missing → 強制 COMMON(Pillar 3 floor,唔 rollback)。
   - `class_tag` missing/null → NEUTRAL。
   - **stat assignment(D9)**:`stat_modifiers` 由 #17 用 Stat Assignment Table lookup 賦值(#15 唔 roll stat — Q-OQ5 metadata 只帶 item_type/rarity/class_tag/receipt)。
   - **Key guard(D8;Pass 3 scope 修正)**:guard 對象 = `EquipmentItem.stat_modifiers` **final dict**(post-table-assign / boot re-hydration 嘅 persisted dict / `.tres` table misconfig / test fixture)帶非 4-derived-key(含 STR/DEX/VIT)→ drop 嗰 key + emit `inventory.stat_key.dropped` telemetry(**唔再「靜默」**— counter > 0 即 alert,防 key-space drift 令 auto-equip 整個 feature 無聲死亡)。**Drop path 嘅 `item_metadata` 唔讀 stat keys**(D9 table authoritative)— metadata 如帶 stat keys,detection-only telemetry,永不 merge(守 D9 deterministic / golden-vector testable)。
   - **非負 guard**:final dict 內 functional delta < 0 → clamp 0 + 同一 telemetry(MVP 無 cursed item design;一刀封死 negative-score auto-equip 鏈)。
2. **Idempotency** — 以 `item_id`(Formula 6,**composite StringName,無 hash**)為 idempotency key。同一 `(source_transition_id, drop_index)` 重入(#15 retry / bfcache replay)→ no-op。同一 transition 多件 → 唔同 `drop_index` → 各自正常入庫。`SALVAGED` tombstone(**只存 `{item_id: salvaged_at_unix}` Dictionary**,唔存 full item — Pass 3 fix:id-only set 無 timestamp 判唔到 prune age,而 `transition_id` 係 opaque 禁 parse,ADR-0006 Contract 2)同樣參與 dedup —— replay 唔可以復活已 salvage 嘅 item。Tombstone prune:`salvaged_at_unix` 早過 #15 replay horizon(**`HARD_CAP_DAYS` = 37 日**,#15 LOCKED;backend `lootdrop_cache` retention 同為 37 日 per ADR-0006 Contract 15)嘅條目可刪(replay 唔可能嚟自更舊 source;封 unbounded growth)。
3. **Inventory Cap + Overflow** — `MAX_INVENTORY = 120`(**DESIGN-FROZEN per #15 Pass 2 F-10**;此 count 唔包 mailbox)。receive 時 inventory 有位 → `IN_INVENTORY`;滿(≥120)→ `IN_MAILBOX`。
4. **Mailbox TTL + Hard Cap(A3 重寫)** — mailbox item 7日 TTL(`OVERFLOW_MAILBOX_TTL_DAYS = 7`)。**Expire = auto-salvage**:item 轉成 `salvage_yield(rarity)` shards + emit `inventory.mailbox.auto_salvaged` telemetry + 帳簿一句(「過期轉化 +N shards」,#23 surface)—— **價值永不蒸發**(anti-pillar #3:「唔可以拎走玩家已得嘅嘢」)。**帶 `source_receipt` 嘅 item 免疫 TTL 同 hard-cap evict,永不 silent expire**(LEGENDARY 0.6 件/週,免疫量唔會迫爆 cap)。Hard cap 跟 #15 `MAILBOX_HARD_CAP` = **180**(G-1 RESOLVED 2026-06-06 — #15 已修,INV-G3 成立);觸及時**最舊者(min `acquired_at_unix`,FIFO — 唔係 LRU)先 auto-salvage** 騰位。**時基(cross-session;Pass 3 措辭修正)**:ADR-0006 Contract 9 verbatim reuse 唔得 —— persisted monotonic anchor 跨 WASM reload 歸零會 poison drift-detection branch(reload 後 mono_diff 負/極細 → trust-monotonic path → **永不 expire**);Contract 15 嘅 server-clock-authoritative 先例支持本做法。Mailbox sweep 用 wall-clock(`TimeProvider.now_unix()`)+ server-time sanity check(經 **#2 GymSysBackendClient 暴露 last-known server time + freshness — gate G-7**;offline / 偏差超 `CLOCK_SANITY_TOLERANCE_SEC` → **寧可唔 expire(grace),下次 boot 再試**)。A3 落地後誤判後果 = 「提早 salvage」唔係「刪除」,風險已降級。
5. **Slot Model** — 3 個 functional equip slot:`WEAPON × 1`、`ARMOR × 1`、`ACCESSORY × 1`(1:1 對應 #15 3 個 functional item_type)。另加 `COSMETIC × 1`(MVP),**完全平行 pipeline,永不餵 #11**,**manual-only — auto-equip 唔適用**(avatar 外觀係玩家揀嘅,唔係 algorithm 揀;封 rarity tie-break 覆寫外觀 trap)。CONSUMABLE 唔佔 slot、`slot_affinity = null`、永不觸發 auto-equip(D1)。
6. **Auto-Equip-If-Better(Pass 1 重寫)** — **觸發集合**:{`receive_loot` 入庫後、mailbox claim 後、salvage-induced-unequip 後(empty-slot backfill:由 inventory 揀最高分 unlocked 同 type item 補位)}。**比較鍵 = loadout-level marginal(clamp-aware)**:計「swap 後 loadout aggregate → Formula 4 clamp → Formula 1 weighted sum」vs「現 loadout 同算」,swap 後分數**嚴格大於**現分數先 swap —— 唔係 item-vs-item raw 比(封「ATK 已 cap 時 swap 走 VIT 裝令 avatar 實際變弱」trap)。**Empty slot baseline = 0**;score ≤ 0 嘅 candidate 永不 auto-equip(Rule 1 非負 guard 下 MVP 唔會出現,defense-in-depth)。Deterministic tie-break(分數相等):`rarity` ↓ → `acquired_at_unix` ↑(舊者保留,減 churn)→ `item_id` 字典序 ↑。**永遠 skip 帶 `is_locked == true` item 嘅 slot**(Rule 7)。**Mutation discipline(re-entrancy,binding)**:#17 所有 internal state mutation(slot assignment、item state、dirty mark)必須喺**第一個 #11 call 之前**全部完成 —— push #11 永遠係成個 operation 嘅最後一步,令 #11 synchronous `stat_changed` emission 期間任何 handler 觀察到嘅 #17 state 都係 post-swap consistent。`_mutating` re-entrancy guard:mutation API 入口見 `_mutating == true` → `push_error` + `process_frame` ONE_SHOT defer(ADR-0006 Contract 5 idiom)。**Guard window(Pass 3 pin)**:`_mutating` 持續到 #11 push **return 之後**先清 —— guard 存在嘅唯一目的窗口就係 #11 synchronous `stat_changed` emission 期間,push 前清 flag = guard 喺自己嘅用途上失效。**Binding + CI lint**:`stat_changed` handler FORBIDDEN synchronous call #17 mutation API(`tools/ci/check_inventory_reentrancy.gd`,owner-exempt #17 自身)。
7. **Manual Override(#22 Character Screen)** — 玩家事後可手動 equip / unequip / lock / salvage。**Manual equip 唔受 score 限制**(玩家可以裝較弱嘅件 — 佢嘅 avatar 佢話事);**但唔 lock 嘅 manual choice 喺下一次 auto-equip trigger 會被換返最強件**(Pass 3 明寫 — by design:lock 就係「尊重我嘅選擇」嘅機制;**forward flag → #22 UX spec:manual equip 較弱 item 時必須露 lock affordance**,否則玩家會覺得 choice 被無視)。**`is_locked` 係 item-level flag**(Pass 1 統一 — 唔係 slot-level):locked item 若 EQUIPPED → auto-equip 唔郁佢個 slot;任何時候免疫 salvage / bulk-salvage / mailbox auto-salvage。#22 API = `set_lock(item_id, bool)`。寫入 `inventory.*` persist。
8. **#11 Aggregation + AntiSnowball Clamp(Pass 1 重寫)** — 3 個 functional slot 嘅 `stat_modifiers`(4 derived key)逐 key sum 成 aggregate。**COSMETIC slot 結構性排除**(aggregation 只迭代 3 functional slot —— 就算 scrub 漏咗都餵唔入,最後防線)。Clamp(Formula 4)後,**用單一 synthetic id `&"equipment_aggregate"` 經 `apply_equipment_modifier(&"equipment_aggregate", StatModifier)` push 一個 modifier**;loadout 任何變化 → 重算 + re-push 同 id(**same-id = atomic replace 語意 —— #11 EC-17 已 pin,G-2 RESOLVED 2026-06-06**,封 remove+apply 兩步嘅 stat-dip emission window)。**Per-key range clamp**:push 前每個 key clamp 落 #11/registry contract range(`ATTACK_POWER ≤ +300` / `MAX_HP ≤ +500` / `MOVE_SPEED ≤ +100` / `CRIT_CHANCE ≤ 0.20`)—— 直接解 cap>+300 撞 range 問題(原 CD ADVISORY-3,Pass 1 收編)。Clamp 係 **soft / non-blocking**:照著裝備,只係超出部分無效;#22 顯示「裝備加成 +84 / +90(受真身上限約束)」badge + ledger-voice reframe「練多啲,解放佢嘅全力」;emit `equipment.antisnowball.clamp` telemetry(#28)。**Rejection handling**:`apply_equipment_modifier` 被 #11 reject(Suspended/Reconciling,#11 EC-21)→ #17 訂閱 `stat_mutation_rejected`(handler **filter `source == EQUIPMENT`**;#17 係唯一 equipment caller — #11 該 signal 對 multi-key modifier 嘅 `stat_id` 取值 epic 時同 #11 對一句,minor),set `_pending_stat_push` flag,GSM Ready 後 deferred 一 frame re-push(唔係 fire-and-forget;loadout 同 #11 永不 desync)。Same-id re-push = atomic replace(**#11 EC-17 已 pin,G-2 RESOLVED**)。
9. **Salvage → Shards** — `salvage_yield(rarity)`(Formula 2)轉成 `forge_shard`。**EQUIPPED 唔可直接 salvage** — **單一 batch(Pass 3 ordering 修正)**:auto-unequip + `SALVAGED` 標記 + shard increment + empty-slot backfill(Rule 6)**全部 in-memory 完成** → **一次** final-aggregate push #11(Rule 6 mutation discipline:push 永遠最後一步,唔係夾喺中間)→ 一次 persist write。**Transaction atomicity(Pass 1 新增)**:item state change 同 shard mutation 必須同一個 in-memory commit + 同一次 persist write —— 唔可以「item 冇咗、shard 又冇到」(currency 版 silent loss;EC-19)。**Bulk-salvage-by-rarity**:一 tap 拆晒指定 rarity 嘅所有 unlocked item(Pillar 2 throughput);locked item 絕對排除(API 無 bypass param —— Pass 1 刪走 `exclude_locked` 參數,行為唔可配置)。Bulk 係單一 transaction + 單一 persist write(Rule 14)。
10. **Source Receipt(F-12)** — LEGENDARY drop **必帶** `SourceReceipt`(`workout_date_unix` + `pr_snapshot` + `volume_snapshot` + 預渲染 `signature_text`「鍛造自 180kg × 5」,#26 ledger voice)。供 #29 Mirror Moment ceremony narrative payload + #22 hover/inspect 顯示。其他 tier `source_receipt` nullable。**Lightweight provenance(Pass 1 新增,全 tier)**:每件 item 由已有 data derive 一行 `provenance_text`(`acquired_at_unix` + `class_tag` →「拾於 6月3日・腿日」)—— 零上游成本,帳簿 fantasy 全 tier 兌現。**Determinism pin(Pass 3)**:date 用 **UTC 日期** derive(CI 跨機 deterministic;display timezone 係 #22/#23 presentation 層 forward flag);`class_tag == NEUTRAL` → label「自由日」。
11. **Cosmetic Parallel Pipeline** — cosmetic item 嘅 `stat_modifiers` 強制 `{}`(empty),`class_tag = NEUTRAL`,**永不餵戰鬥**(final-dict scrub + Rule 8 aggregation 結構排除,雙防線),只餵 #26 AvatarRenderer 視覺。Cosmetic final dict 帶非空 stat(boot persisted corruption / table misconfig — EC-5 scope)→ 強制清空 + emit `inventory.stat_key.dropped`,唔 rollback(Pillar 3 no-loss)。**Cosmetic dupe auto-convert(Pass 1 新增,正面答 #15 EC-38 [OPEN];G-3 已回填)**:auto-convert rate = **`salvage_yield(rarity)`**(LEGENDARY → 800)—— 消除「同一件嘢 manual salvage 800 / auto-convert 100」嘅 8× player-visible 矛盾。**Mechanism(Pass 3 pin,#17 own)**:detection 喺 `receive_loot` —— cosmetic item 嘅 visual id 已 owned(任何 state)→ 唔入庫,直接 `forge_shard += salvage_yield(rarity)` + return `CONVERTED_DUPE` + emit `inventory.cosmetic.dupe_converted` telemetry + tombstone 登記 `{item_id: TimeProvider.now_unix()}`(convert 當刻;replay-safe)。#15 EC-38 嘅 re-roll-once 係 #15 內部 step;convert path 由 #17 執行(#17 own inventory/unlock state,#15 唔使 query)。
12. **Persistence** — ADR-0003 backend-primary + `user://` IndexedDB secondary,`inventory.*` namespace(localStorage **FORBIDDEN**)。`EquipmentItem` / `SourceReceipt` = **`SerializableResource` dict envelope**(`to_dict()` / `from_dict()`,ADR-0006 Contract 3 + ADR-0009);**`.tres` 寫落 `user://` FORBIDDEN**(script-embedding 風險 + devtools 不可讀)。Schema migration ≤900ms ceiling(ADR-0003;migration step 內禁 per-item heavy work)。
13. **Save 粒度(Pass 1 修正)** — ADR-0003 嘅 `IPersistence.write` 係 full-file rewrite + `IDBFS.syncfs`,key-level「incremental」唔減 I/O。**Flush 粒度 = per user action 一次 write**:所有 mutation 改 in-memory,operation 結尾(或 `process_frame` ONE_SHOT debounce)single write —— bulk-salvage 50 件 = **1 次** write,唔係 50 次(ADR-0001 frame budget 保護)。建議 #3 加 `write_batch(Dictionary)` API(gate G-5,optional)。
14. **Boot(`INITIALISING`,Pass 1 重寫)** — 順序:
    1. load `inventory.*` via `IPersistence`;
    2. hydrate items(**persisted-trust:唔重跑 Rule 1 drop-provenance validation** —— 自己 persist 嘅嘢唔重驗,EC-2 scope。Schema-shape guard 照跑:壞 dict → 該 item 棄 + CRITICAL telemetry);
    3. shard balance guard:非法值(負數 / 非 int)→ clamp 0 + emit `inventory.shard.balance_corrupted` CRITICAL;
    4. mailbox TTL sweep(Rule 4 cross-session 時基;expire = auto-salvage;receipt 件 skip);
    5. **drain `loot.pending.recovery`**:逐 record re-attempt `receive_loot`(idempotent — `item_id` dedup 令 double-drain 無害)。Ownership pin:**#15 catch + write(EC-48 + L297 sole-writer exception),#17 boot drain + clear**。**No-loss 次序 pin(Pass 3)**:drain 入庫嘅 items 必須隨 `inventory.*` persist(step 8 boot flush)**成功之後**先 clear `loot.pending.recovery` —— 反次序 crash = loss window;正次序 crash 只係 double-drain,dedup 無害;
    6. replay equipped loadout → **compute** aggregate + clamp(**唔 push — push 由 step 7 單一 own**,Pass 3 ownership 修正,封 Suspended-at-boot 場景嘅 double-push/duplicate-emission);**Boot ordering 靠 ADR-0008 position(`StatSystem ≺ InventorySystem`),唔係 await signal** —— per Contract 4,`StatSystem.boot_completed` 喺 #17 入 tree 前已 fire,await = permanent hang;用 `is_boot_completed()` sync getter assert(G-2 已落地 #11);
    7. GSM state 經 `connect_for_initial_state`(ADR-0006 Contract 6,3-arg callable、no `.bind()`):GSM 喺 gameplay-ready state → push(**恰好一次** — `_pending_boot_replay` 同 `_pending_stat_push` 合一做單一 dedup flag);**GSM Suspended-at-boot(crash recovery,#11 EC-24 同款)→ set flag,Ready transition handler 先 push**(#11 Rule 14 Suspended 期間 reject)。所有 resume-path push 一律 `process_frame` ONE_SHOT 延一 frame(避開 #11 Reconciling single-frame reject window)+ `stat_mutation_rejected` retry(Rule 8);
    8. **boot flush(Pass 3 新增)**:INITIALISING 期間所有 mutation(step 3 shard clamp / step 4 sweep auto-salvage / step 5 drain 入庫)聚合做**一次** batched `inventory.*` write(Rule 13 粒度;ADR-0003 900ms ceiling + ADR-0001 frame budget 保護),完成後先執行 step 5 嘅 recovery-clear。
15. **`SUSPENDED`(GSM non-gameplay / bfcache suspend)** — queue `receive_loot`(**FIFO**;return `QUEUED_SUSPENDED`)。**Queue durability(Pass 3 no-loss pin)**:queue 唔係純 in-memory — SUSPENDED 期間收到嘅 record 同步寫入 **`inventory.pending_queue`**(#17 own namespace,唔掂 #15 `loot.*` sole-writer;browser discard suspended tab 唔會 loss);resume drain 成功 + persist 後 clear。Resume 時 deferred drain(一 frame 延遲 + rejected retry,Rule 14 step 7 同款)。**Catch-up burst batching(Pass 1 新增)**:#15 boot force-reveal / catch-up 可以連發 N 個 `receive_loot`(**SUSPENDED drain 同 READY-state burst 兩個 path 都適用**)—— 入庫逐件處理,但 **aggregate + push #11 + persist write 各只做一次**(debounce 至 batch 尾;封 N 次重算 + N 次 syncfs)。

### States and Transitions

#### Item Lifecycle States

| State | 意義 | 入 | 出 |
|-------|------|----|----|
| `IN_MAILBOX` | inventory 滿(≥120),暫存,7日 TTL | `receive_loot` 時 slot 滿 | claim → `IN_INVENTORY`(需有位,EC-10)/ TTL 到或 hard-cap evict → **auto-salvage** → `SALVAGED`(receipt 件免疫) |
| `IN_INVENTORY` | 已入庫,未裝備 | mailbox claim / unequip / auto-equip skip | equip → `EQUIPPED` / salvage → `SALVAGED` |
| `EQUIPPED` | 現役,正餵 #11 | auto-equip-if-better / #22 手動裝備 | 被換或 unequip → `IN_INVENTORY` / salvage(先 auto-unequip)→ `SALVAGED` |
| `SALVAGED` | 已分解成 `forge_shard` | salvage / bulk-salvage / mailbox auto-salvage | **terminal**(tombstone = `{item_id: salvaged_at_unix}`,prune 過 #15 `HARD_CAP_DAYS` 37日) |

```
            receive_loot (reveal handoff)
                 │
        ┌────────┴─────────┐
   slot available?    slot full (≥120)
        │                  │
        ▼                  ▼
   IN_INVENTORY ◄──   IN_MAILBOX ──(7d TTL / hard-cap,FIFO oldest;
        │  ▲              │ claim     receipt 件免疫)──► SALVAGED (auto-salvage)
        │  │ unequip      └─(需 inventory 有位,否則 block)─► IN_INVENTORY
   equip│  │
        ▼  │
    EQUIPPED
        │
   salvage (batch: unequip+SALVAGED+backfill in-memory → 單一 final push #11 → 單一 persist)
        ▼
    SALVAGED (terminal + timestamped tombstone)
```

#### System Autoload Substates

| Substate | 意義 | 對齊 |
|----------|------|------|
| `INITIALISING` | boot 中:Rule 14 七步 | ADR-0006 Contract 4;**ADR-0008 position 約束:`StatSystem ≺ InventorySystem ≺ LootDropSystem`**(gate G-4 登記) |
| `READY` | 正常運作,接 `receive_loot` | — |
| `SUSPENDED` | GSM non-gameplay / bfcache suspend;FIFO queue,resume deferred drain | 對齊 #14/#9 pattern via `connect_for_initial_state`(Contract 6) |

### Interactions with Other Systems

| 系統 | 誰 own interface | 流入 #17 | 流出 #17 | 備註 |
|------|------------------|----------|----------|------|
| **#3 PersistenceLayer** | #3 own `IPersistence` | boot load `inventory.*` | per-action batched write(Rule 13) | ADR-0003;localStorage FORBIDDEN;gate G-5 `write_batch` 建議 |
| **#11 Stat System** | #11 own `apply_equipment_modifier(equipment_id, StatModifier)` + `stat_mutation_rejected` signal + **G-2 additive(已落地 2026-06-06)**:`get_attack_power_excluding_equipment()`(L267)/ `is_boot_completed()`(L228)/ EC-17 same-id atomic-replace pin | `stat_derived_atk` 經 `get_attack_power_excluding_equipment()` 讀(Pass 1 修正咗 phantom citation;Pass 2 verify API 已真實存在) | #17 push 單一 `&"equipment_aggregate"` modifier(clamp 後,4 derived key) | #17 **唔**直接寫 #11 stat;derived-keys-only(D8)下 STR/DEX 永無裝備污染 |
| **#15 Loot Drop** | #17 own `receive_loot(loot_drop_record) -> ReceiveResult` | `item_metadata: Dictionary`(Q-OQ5;只帶 item_type/rarity/class_tag/receipt — stat 由 #17 assign,D9) | EC-1 失敗 → return `FAILED_ROLLBACK` + CRITICAL;**#15 catch + write `loot.pending.recovery`**(EC-48 + L297 sole-writer exception 已 amend),#17 boot drain + clear(次序:`inventory.*` persist 先) | idempotent on `item_id`;gates G-1/G-1b/G-3 全部 RESOLVED 2026-06-06 |
| **#21 Loot Drop Modal** | #21 own reveal UI | reveal-ack 觸發入庫 handoff(#15 Pending pool 30日 TTL + boot force-reveal 兜底,永不 loss) | typed preview(rarity / receipt / provenance) | 入庫時序 = reveal handoff(Player Fantasy 時序註記) |
| **#22 Character Screen** | #22 own loadout UI | 手動 equip/unequip/`set_lock(item_id, bool)`/salvage | loadout state + per-item detail + AntiSnowball badge(`get_aggregate_raw_and_effective()`) | craft/upgrade command → v0.2 |
| **#23 Inventory UI** | #23 own list UI | list/filter/bulk-salvage command | inventory state + `forge_shard` balance(int64,千位分隔 display contract)+ mailbox indicator + Forge locked-hook | salvage logic 住喺 #17(D5) |
| **#29 Mirror Moment** | #29 own ceremony | LEGENDARY + `source_receipt` 觸發 | `source_receipt.signature_text` | F-12 receipt = ceremony payload |
| **#26 Avatar Renderer** | #26 own 視覺 | EQUIPPED functional / cosmetic 變化 | equipped item visual id | cosmetic pipeline 終點 |
| **#4 Audio Manager** | #4 own SFX catalog | — | audio co-trigger intents(§ Visual/Audio) | Soft dep(Pass 1 補列) |
| **#33 Attention Budget** | #33 own `is_input_permitted` / notification 通道 | — | **mid-workout auto-equip chime 必須 route 經 #33**(唔可以 parallel-channel 繞過) | Soft dep(Pass 1 補列) |

> **Bidirectional sync flags — 狀態(Pass 3 更新):**
> - ✅ #11 Stat:G-2 三項 additive 全落地(L228/L267/EC-17 pin)。Registry derived formula `referenced_by` actualization → /consistency-check batch。
> - ✅ #15 Loot:G-1(MAILBOX_HARD_CAP 180 + 4 處 stale 60)+ G-1b(EC-47 reconcile)+ G-3(EC-38 回填)+ L297 sole-writer exception 全落地。
> - ✅ ADR-0008:G-4 constraint 8 + insertion rule 落地。
> - ⬜ G-7(#2 server time,soft)+ G-8(#3 namespace 表一行)— epic 時做。

## Formulas

> **新號數學(Pass 1 re-grounded,單一模型)**:#11 default STR=DEX=VIT=10 → `stat_derived_atk = ATK_BASE(10) + 10×ATK_PER_STR(1.5) + 10×ATK_PER_DEX(0.3) = 28` → min cap = `max(30, 3×28) = 84`。全文 example / AC 一律用呢個 baseline。`STR=DEX=0` 喺正常 boot 下 unreachable(只可能經 #11 corruption-clamp path),`ANTISNOWBALL_FLOOR=30` 係該 path 嘅 defense-in-depth。

### Stat Assignment Table(MVP,D9 — data-driven `.tres`)

| item_type \ rarity | COMMON | UNCOMMON | RARE | EPIC | LEGENDARY |
|--------------------|--------|----------|------|------|-----------|
| **WEAPON**(ATTACK_POWER) | +6 | +12 | +22 | +45 | **+90** |
| **ARMOR**(MAX_HP) | +20 | +35 | +60 | +100 | +160 |
| **ACCESSORY**(MOVE_SPEED / CRIT_CHANCE) | +5 / — | +8 / +0.01 | +12 / +0.02 | +18 / +0.04 | +25 / +0.06 |

- 全部值 ≤ #11/registry per-key contract range(ATK ≤ +300 / HP ≤ +500 / MOVE ≤ +100 / CRIT ≤ 0.20)✓
- **LEGENDARY WEAPON +90 刻意 > 新號 cap 84** → 新號爆 L weapon 會真實觸發 AntiSnowball badge(「+84 / +90」),Pillar 1 narrative 喺真實玩法出現。
- CONSUMABLE / COSMETIC:`stat_modifiers = {}`。
- 全 doc 數字例子由此表 + formula 重現(re-review validation criterion (a))。

### Formula 1 — `loadout_score`(auto-equip-if-better 比較鍵,Pass 1 重寫)

```
effective_aggregate = Formula 4 clamp(Σ over 3 functional slots: stat_modifiers)
loadout_score       = Σ over (key, delta) in effective_aggregate: STAT_WEIGHT[key] × delta
swap 條件            = loadout_score(swap 後) > loadout_score(現役)        # 嚴格大於
```

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| delta(per key) | float | per-key:ATK [0,300] / HP [0,500] / MOVE [0,100] / CRIT [0,0.20](Rule 1 非負 guard + per-key clamp 後) | aggregate 該 derived stat 嘅加成 |
| `STAT_WEIGHT[key]` | float | per-key safe range(見 Tuning Knobs) | 該 stat 嘅「ATK 當量」normalization(**Pass 1:per-key scale,唔係統一 [0,2]** — CRIT scale 係 0.01 級,weight 要 ~10²) |
| `loadout_score` | float | [0, ~170] @ MVP table(max 169);[0, ~565] @ per-key contract ceilings | loadout-level 戰力標量 |

**STAT_WEIGHT(初值,knob)**:`ATTACK_POWER = 1.0`、`MAX_HP = 0.25`、`MOVE_SPEED = 0.6`、`CRIT_CHANCE = 400`。

**Golden vector(AC-18)**:loadout {WEAPON L, ARMOR L, ACCESSORY L} 新號(cap=84):effective = {ATK: min(90,84)=84, HP: 160, MOVE: 25, CRIT: 0.06} → score = 84×1.0 + 160×0.25 + 25×0.6 + 0.06×400 = 84 + 40 + 15 + 24 = **163**。

*Loadout-level + clamp-aware → ATK 已 cap 時唔會 swap 走 HP/MOVE 裝令 avatar 實際變弱;empty slot 對 score 貢獻 0,任何正分 item 都會 backfill。*

### Formula 2 — `salvage_yield`

`salvage_yield(rarity) = SHARD_BASE × RARITY_SHARD_MULT[rarity]`

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `SHARD_BASE` | int | [50, 200] | COMMON salvage baseline = **100**。**Rationale(Pass 1 自立 — 原「EC-38 anchor」係 mis-citation,#15 EC-38 嘅 100 係 LEGENDARY cosmetic dupe rate)**:COMMON = 雙位數無感 / 三位數有感嘅心理 floor;同 v0.2 craft cost 表(craft UNCOMMON 200 = 2 件 COMMON)保持 2:1 整數關係 |
| `RARITY_SHARD_MULT[rarity]` | float | per-tier ±50% | COMMON 1.0 / UNCOMMON 1.5 / RARE 2.5 / EPIC 4.5 / LEGENDARY 8.0 |
| `salvage_yield` | int(`floori`) | [100, 800] @ defaults | 該件 salvage 出嘅 `forge_shard` |

**Yield table:** COMMON **100** · UNCOMMON **150** · RARE **250** · EPIC **450** · LEGENDARY **800**。**Example:** salvage 一件 RARE → 100 × 2.5 = **250 shards**。
**Int 規則(全 economy formula 通用)**:中間值出小數一律 `floori()`。
*Super-linear:低 tier 量多低 yield = 穩定 faucet;高 tier super-linear 保 keep 價值。Mailbox auto-salvage(Rule 4)同 cosmetic dupe auto-convert(Rule 11 / #15 EC-38)用同一條 formula —— 全系統單一 salvage 價值軌。*

### Formula 4 — `equipment_atk_effective`(AntiSnowball clamp,Pass 1 重寫)

```
stat_derived_atk        = StatSystem.get_attack_power_excluding_equipment()   # G-2 additive API(已落地 #11 L267)
raw_atk_contribution    = Σ ATTACK_POWER deltas over 3 functional slots       # D8:無放大項,無 STR/DEX 分支
cap                     = max(ANTISNOWBALL_FLOOR, ANTISNOWBALL_MULT × stat_derived_atk)
equipment_atk_effective = clamp(raw_atk_contribution, 0, min(cap, EQUIPMENT_ATK_MOD_MAX))
```

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `stat_derived_atk` | float | [28, ~1800] @ #11 contract range(新號 28;display range「[10,200]」係 default-knob 典型值,唔係 contract bound) | 真身 ATK(去裝備;D8 下 STR/DEX 無污染,#11 用 `_base` 計) |
| `raw_atk_contribution` | float | **[0, 90] @ MVP table**(ATK 只來自 WEAPON slot;Pass 3 修正);[0, 300] @ per-key contract | 裝備 ATK 總貢獻(clamp 前;Rule 1 非負 guard 保證 ≥0) |
| `ANTISNOWBALL_MULT` | float | **LOCKED 3.0** | FR-Equipment-AntiSnowball binding(#13 繼承,**非 knob**) |
| `ANTISNOWBALL_FLOOR` | int | [20, 50] | **30**;defense-in-depth(D4) |
| `EQUIPMENT_ATK_MOD_MAX` | int | **300(#11 contract,非 knob)** | #11 `equipment_atk_mod` range 上限;push 前 per-key clamp(Rule 8)—— 高 stat 玩家 cap 可超 300,但 effective 永不超 #11 range |
| `equipment_atk_effective` | float | [0, min(cap, 300)] | clamp 後實際生效裝備 ATK |

**Example(新號 + LEGENDARY weapon)**:stat_derived_atk = 28 → cap = max(30, 84) = 84;raw = 90 → effective = clamp(90, 0, min(84, 300)) = **84** → #22 badge「+84 / +90(受真身上限約束)」。
*Clamp 喺 aggregate 之後、push `&"equipment_aggregate"` 之前;雙下界(clamp 0)+ 雙上界(cap + #11 range)封晒負值 passthrough 同 range 衝突。Soft/non-blocking,reframe 成成長目標(Pillar 1 正向敘事)。*

### Formula 6 — `item_id`(idempotency,Pass 1 重寫 — 無 hash)

`item_id = StringName(source_transition_id + "_" + str(drop_index))`

**Variables:**
| Variable | Type | Description |
|----------|------|-------------|
| `source_transition_id` | String | #15 drop 嘅 transition_id(ADR-0006 Contract 2 保證全域 unique) |
| `drop_index` | int | 同一 transition 內第幾件 |
| `item_id` | StringName | **construction 上 collision-free**、跨 engine version 穩定、devtools 人類可讀 |

*Pass 1 刪走 `hash()`:32-bit collision(~0.26%/player/3yr)= silent loot loss;composite string 本身已全域唯一,hash 零增值純引入風險。*

### Sink Throughput Sanity Check(Pass 1 重寫 — 自洽模型)

> 全表 trace **#15 Formula E3 Hardcore post-clamp 分佈**(COMMON 9.8 / UNCOMMON 10.2 / RARE 6.9 / EPIC 2.4 / LEGENDARY 0.6 ≈ 29.9 drops/週)。

- **Item sink(loot-rot gate)**:keep 假設兩 scenario —— week-1 ~15%(BiS 未飽和)/ steady-state ~5%(5-item pool 第 2 週起 per-slot BiS 飽和,只剩 strict upgrade + receipt 紀念品)。Steady-state net keep ≈ +1.5 件/週 → fill horizon ≈ 80 週;week-1 profile net +4.5 件/週 → 27 週。**14日 MVP loot-rot gate 滿足**(bulk-salvage 一 tap 清 dup);長線靠玩家 salvage 習慣,#28 telemetry 監察。
- **Shard faucet(full-salvage upper bound)**:9.8×100 + 10.2×150 + 6.9×250 + 2.4×450 + 0.6×800 = **5,795 shards/週**;keep-adjusted ≈ 3,900(week-1,**value-weighted** keep — 高 tier 全留:withheld ≈ 0.6L+2.4E+1.5R = 1,935)– 5,500(steady,**count-weighted** 5% keep:5,795×0.95)。兩個 bound 用唔同 keep-skew 模型,band 涵蓋真實行為。
- **Shard sink(MVP)= 0(A1 salvage-only)**:shards 係 banked currency。**Stockpile projection(v0.2 定價 binding input,Q-5)**:Hardcore ≈ 3.9k–5.5k/週 × v0.2 距離週數(8 週 ≈ **32k–44k**;12 週 ≈ **47k–66k**,Pass 3 修數)。v0.2 Forge 定價必須對住呢個 stockpile 設計(用 MVP 真實 telemetry 取代本估算)。
- **forge_shard type**:int64,無 cap by design(一年 Hardcore ~30 萬,離 2^53 極遠);#23 display contract = 千位分隔,預期 5–6 位數。

## Edge Cases

### Hydration / Validation
- **EC-1 (CRITICAL)** — **If `receive_loot()` hydration fail 或 `source_transition_id` missing**(Pass 3 contract pin):`receive_loot` return **`ReceiveResult.FAILED_ROLLBACK`** + emit `loot.inventory.grant_fail` CRITICAL,inventory state 不變;**`loot.pending.recovery` namespace write 係 #15 responsibility**(#15 EC-48 owner — catch failure return / throw 後 rollback;#15 L297 sole-writer)。#17 boot step 5 drain 兌現「下次開啟自動補發」。**唔可 silent loss**(Pillar 3 no-loss)。`receive_loot` return contract:`{OK, QUEUED_SUSPENDED, DUPLICATE_NOOP, CONVERTED_DUPE, FAILED_ROLLBACK}`。
- **EC-2 (HIGH)** — **If LEGENDARY drop 缺 `source_receipt`**:rollback(F-12 binding)。其他 tier → `source_receipt = null` 正常入庫。**Scope(Pass 1 收窄)**:F-12/provenance validation **只跑 drop-hydration path(`receive_loot`)**;boot re-hydration 對自己 persist 嘅 item 唔重跑(否則任何 schema 演變都會誤殺玩家舊裝)。
- **EC-3 (MEDIUM)** — **If `rarity` missing**:強制 `COMMON`(Pillar 3 floor,唔 rollback)。
- **EC-4 (MEDIUM,Pass 3 scope 修正)** — **If `EquipmentItem.stat_modifiers` final dict(boot re-hydration persisted dict / `.tres` table misconfig / test fixture)帶非 4-derived-key(含 STR/DEX/VIT)或負 delta**:drop 該 key / clamp 0,emit `inventory.stat_key.dropped` telemetry(**有聲 — counter 異常即 alert**,封 key-space drift 令 auto-equip 無聲死亡)。Drop path 嘅 `item_metadata` stat keys 一律唔讀(D9;detection-only telemetry)。
- **EC-5 (MEDIUM,Pass 3 scope 修正)** — **If cosmetic item 嘅 final dict 帶非空 `stat_modifiers`**(boot persisted-dict corruption / table misconfig — D9 下 #15 唔送 stat,「#15 bug」path 唔存在):強制 `{}` + `class_tag = NEUTRAL`,emit EC-4 telemetry,唔 rollback。

### Idempotency
- **EC-6 (HIGH)** — **If 同一 `(source_transition_id, drop_index)` 重入**:`item_id` 已存在(active 或 tombstone)→ no-op。**Tombstone replay**:已 SALVAGED 嘅 item replay 唔復活、唔重派 shards。同一 transition 唔同 `drop_index` → 各自正常入庫。

### Cap / Mailbox
- **EC-7 (MEDIUM)** — **If inventory 剛好 120**:第 120 件入 slot 120(`IN_INVENTORY`);第 121 件入 `IN_MAILBOX`。`MAX_INVENTORY` count 唔包 mailbox。
- **EC-8 (HIGH)** — **If boot 時 mailbox item 已過 7日 TTL**:`INITIALISING` sweep → **auto-salvage**(+`salvage_yield` shards)+ emit `inventory.mailbox.auto_salvaged`。**帶 receipt 件 skip(永不 silent expire,A3)**。時基 = `TimeProvider.now_unix()` + server-time sanity(偏差超 tolerance → grace 唔 expire,下次再試;Rule 4 — Contract 9 same-session 機制唔 reuse)。
- **EC-9 (MEDIUM)** — **If mailbox 觸及 `MAILBOX_HARD_CAP`**:最舊者(min `acquired_at_unix`,**FIFO**)先 auto-salvage 騰位;receipt 件 skip(跳去次舊)。**Defense-in-depth fallback(Pass 3)**:極端 case 全 mailbox receipt-bearing 無 evictable(MVP ~300 週 unreachable @ 0.6 L/週)→ soft-admit 超 cap + telemetry alert(#15 EC-47 fallback orphan_queue 做最後防線)。
- **EC-10 (MEDIUM,Pass 1 新增)** — **If 玩家 claim mailbox item 但 inventory 仍 ≥120**:block + 顯示「先騰 N 個位」+ 一鍵跳 bulk-salvage flow(#23)。Claim 唔可以臨時超額。

### Equip
- **EC-11 (HIGH)** — **If manual lock(#22)同 auto-equip 同 frame**:單線程 main thread + Rule 6 mutation discipline(mutation 全部完成先 push #11)+ `_mutating` guard。**Lock 永遠贏** — auto-equip skip locked item 嘅 slot。
- **EC-12 (MEDIUM)** — **If auto-equip 兩個 candidate `loadout_score` 相等**:tie-break(rarity ↓ → `acquired_at_unix` ↑ → `item_id` ↑),deterministic,舊者保留。
- **EC-13 (HIGH)** — **If salvage 一件 EQUIPPED 裝備**:禁止直接 salvage;batch(unequip + `SALVAGED` + shard + backfill)in-memory 完成 → 單一 final-aggregate push #11 → 單一 persist(Rule 9 Pass 3 ordering;Rule 6 discipline:push 最後),全程一個 transaction(EC-19)。
- **EC-14 (HIGH,Pass 1 新增)** — **If #11 reject `apply_equipment_modifier`**(Suspended/Reconciling,#11 EC-21):set `_pending_stat_push`,GSM Ready 後 deferred 一 frame re-push;**唔 fire-and-forget**,loadout 同 #11 永不 desync。
- **EC-15 (MEDIUM,Pass 1 新增)** — **If `stat_changed` handler synchronous call 返 #17 mutation API**:`_mutating` guard → `push_error` + deferred(Contract 5 idiom)。CI lint enforce handler 一律 deferred。

### AntiSnowball
- **EC-16 (CRITICAL)** — **If `stat_derived_atk` 低令 cap clamp 新爆嘅高 tier weapon**(新號 28 → cap 84 < LEGENDARY 90):clamp **透明顯示**「+84 / +90 受真身上限約束」+ reframe「練多啲解放佢嘅全力」。**唔可 silent clamp**。`equipment.antisnowball.clamp` telemetry。

### Economy / Persistence
- **EC-17 (MEDIUM)** — **If bulk-salvage 範圍含 `is_locked` item**:絕對排除(item-level lock,Rule 7;API 無 bypass)。Receipt 但 unlocked 嘅 item 會被拆 —— #23 UX spec 須喺 bulk-salvage confirm 顯示「含 N 件帶 receipt」warning(forward flag 畀 #23)。
- **EC-18 (LOW)** — **If #15 drop `CONSUMABLE`**(D1):入庫、可 salvage、唔佔 slot、唔觸發 auto-equip、MVP inert。
- **EC-19 (HIGH,Pass 1 新增)** — **If salvage 嘅 item state change 同 shard increment 之間 persist 失敗**:兩者必須同一 in-memory commit + 同一次 write;write 失敗 → 全 rollback + telemetry,**唔可以「item 冇咗 shard 又冇到」**(currency 版 silent loss)。
- **EC-20 (HIGH,Pass 1 新增)** — **If boot load 嘅 shard balance 非法**(負數/非 int):clamp 0 + emit `inventory.shard.balance_corrupted` CRITICAL。
- **EC-21 (HIGH)** — **If IndexedDB / `user://` 不可用(Private Mode,ADR-0003)**:backend-primary 照運作;secondary write 失敗只 logged warning 唔 throw;banner 由 #3 own。
- **EC-22 (MEDIUM,Pass 1 新增)** — **If #15 catch-up / force-reveal 連發 N 個 `receive_loot`**:逐件入庫,aggregate/push/persist 各一次(batch 尾 debounce,Rule 15)。

## Dependencies

### Upstream(#17 依賴佢哋)
| 系統 | Hard/Soft | Interface | 缺佢會點 |
|------|-----------|-----------|----------|
| **#3 PersistenceLayer** | Hard | `IPersistence` load/save `inventory.*`(gate G-5 `write_batch` 建議) | 無法 persist → 每 session 清零 |
| **#11 Stat System** | Hard | `apply_equipment_modifier` / `stat_mutation_rejected` + G-2 additive APIs(**已落地**:`get_attack_power_excluding_equipment()` / `is_boot_completed()` / EC-17 atomic-replace pin) | 裝備無法影響戰鬥 → 系統失去 Pillar 3 意義 |
| **#15 Loot Drop** | Hard | `receive_loot(loot_drop_record)`,`item_metadata: Dictionary` | 無 loot 來源 → inventory 永遠空 |
| **#4 Audio Manager** | Soft(Pass 1 補列) | SFX catalog co-trigger | equip/salvage 無聲(可接受 degrade) |
| **#33 Attention Budget** | Soft(Pass 1 補列) | mid-workout cue 須經 #33 通道 | 缺 → mid-set chime 變 attention 漏洞(唔可以 parallel-channel 繞過) |

### Downstream(佢哋依賴 #17)
| 系統 | Hard/Soft | #17 提供 |
|------|-----------|----------|
| **#21 Loot Drop Modal** | Soft | typed item preview(rarity / receipt / provenance) |
| **#22 Character Screen** | Hard | loadout state + per-item detail + AntiSnowball badge getter + equip/unequip/lock/salvage command sink |
| **#23 Inventory UI** | Hard | inventory list + `forge_shard` balance + bulk-salvage command sink + mailbox indicator + Forge locked-hook |
| **#26 Avatar Renderer** | Soft | equipped functional/cosmetic visual id |
| **#29 Mirror Moment** | Soft | LEGENDARY `source_receipt` signature |

### ADR / 架構約束
- **ADR-0003** Save State:backend-primary + `user://` `inventory.*`;localStorage FORBIDDEN;migration ≤900ms;**flush 粒度 per-action(Rule 13)**。
- **ADR-0006** Contract 3(SerializableResource dict envelope;`.tres`→`user://` FORBIDDEN)+ Contract 4(sequential boot)+ Contract 5(deferred idiom)+ Contract 6(`connect_for_initial_state`)。**Contract 9 唔直接 reuse**(same-session 設計;Rule 4 cross-session 時基取代)。
- **ADR-0008** Autoload Position Map:binding constraint 8(**G-4 已落地 2026-06-06**)— `StatSystem ≺ InventorySystem ≺ LootDropSystem`(後者係 binding:#15 runtime call `Inventory.receive_loot`,唔可以靠 position 巧合)。
- **FR-Equipment-AntiSnowball**(#13 繼承,binding):`equipment-derived ATK ≤ 3× stat-derived ATK`。
- **無新 ADR 需要**(G-2/G-4 係 focused amendment / additive API,唔係新 ADR)。

## Tuning Knobs

| Knob | 預設值 | Safe Range | 影響 / 太高 / 太低 |
|------|--------|-----------|---------------------|
| `SHARD_BASE` | 100 | [50, 200] | COMMON salvage baseline(rationale 自立,見 Formula 2)。太高 → v0.2 定價壓力;太低 → salvage 無感。**Joint-validation 注記:任何 economy knob 改動須跑 INV-E assertions(v0.2;MVP salvage-only 下無 pump 風險 — shards 只入不出)** |
| `RARITY_SHARD_MULT[5]` | [1.0,1.5,2.5,4.5,8.0] | 各 ±50%,**附 config-load assertion `salvage_yield(t+1) > salvage_yield(t)`**(Pass 3 — 封 per-tier ±50% 造 tier inversion:COMMON+50%=150 > UNCOMMON−50%=75 嘅荒謬;knob safe range 必須 joint-validate) | salvage yield curve(monotonic binding) |
| `STAT_WEIGHT{ATK,HP,MOVE,CRIT}` | {1.0, 0.25, 0.6, 400} | ATK [0.5,2] / HP [0.1,0.5] / MOVE [0.2,1.2] / CRIT [100,800](**per-key scale**) | auto-equip「better」判定。失衡 → 某 slot 裝備永不 swap |
| Stat Assignment Table | 見 § Formulas | 每格 ±40%,但**唔可超 #11 per-key contract range** | item power curve;data-driven `.tres` |
| `ANTISNOWBALL_FLOOR` | 30 | [20, 50] | defense-in-depth(D4)。太高 → 侵蝕 Pillar 1;太低 → corruption path 失守 |
| `MAX_INVENTORY` | 120 | **DESIGN-FROZEN per #15**(range [60,200] 僅供 #15 解凍後參考) | inventory cap |
| `OVERFLOW_MAILBOX_TTL_DAYS` | 7 | [3, 14] | auto-salvage 窗(A3 後情感成本低 — 價值唔蒸發) |
| `MAILBOX_HARD_CAP` | 180(跟 #15;**G-1 RESOLVED — #15 已修 180**) | `> MAX_INVENTORY`(INV-G3) | mailbox 容量;INV-G3 現已成立(180 > 120) |
| `CLOCK_SANITY_TOLERANCE_SEC` | 3600 | [600, 86400] | mailbox sweep server-time sanity 閾。太細 → 正常 drift 都 grace(永不 expire);太大 → 錯 clock 誤 salvage |
| `KEEP_RATIO`(模型輸入,非 runtime knob) | week-1 ~0.15 / steady ~0.05 | — | sink 模型;VS-tier 用真 telemetry 校準 |
| `ANTISNOWBALL_MULT` | 3.0 | **LOCKED** | FR binding,非 knob |
| `EQUIPMENT_ATK_MOD_MAX` | 300 | **#11 contract,非 knob** | per-key push clamp 上限 |

## Visual/Audio Requirements

> #17 係 data/logic 層,大部分 visual 由 presentation 系統 own。本節只列 #17 own 嘅 audio co-trigger contract 同 cross-system 視覺約束。

### Audio Co-Trigger Contract(via #4 SFX catalog;mid-workout cue 一律 route 經 #33)
| 事件 | SFX intent | 約束 |
|------|-----------|------|
| auto-equip swap | 輕微 equip chime | **必須經 #33 attention 通道**;低音量/可 mute;唔可 mid-set 搶 attention |
| manual equip(#22) | equip confirm | 事後場景,正常音量 |
| salvage / bulk-salvage | salvage crunch(bulk = 一個 aggregated cue) | bulk 唔可 N 件 N 聲 |
| mailbox auto-salvage(boot) | 無 SFX(boot 靜默;#23 帳簿一句顯示) | 唔可以 boot 連環響 |
| AntiSnowball clamp 首次觸發 | subtle UI tick(配合 badge) | 唔可 alarm-like |

> (craft/forge fanfare → v0.2 Forge)

### Cross-System 視覺約束
- **Rarity color** 跟 art bible Layer Discipline:inventory list = dim corner badge;loot reveal modal = full Event Layer saturation(#23 GDD 落實)。
- **Source receipt / provenance**:`signature_text`(LEGENDARY)+ `provenance_text`(全 tier)— #22 hover/inspect + #29 ceremony;ledger voice 對齊 #26。
- **AntiSnowball badge**:#22 顯示「+84 / +90」+ tooltip;非紅色 alarm,「未解鎖潛能」視覺語言。

> 📌 **Asset Spec** — art bible approve 後跑 `/asset-spec system:equipment-inventory`(equip chime / salvage crunch / AntiSnowball badge)。

## UI Requirements

> #17 唔 own 任何 UI;只暴露 data + command API。

| UI Surface | Owner | #17 提供嘅 data / command |
|------------|-------|---------------------------|
| Loadout(3 functional + cosmetic slot) | **#22** | 每 slot equipped item + detail + AntiSnowball badge(`get_aggregate_raw_and_effective() -> {raw, effective}`) |
| Equip / unequip / lock | #22 | `equip(item_id, slot)` / `unequip(slot)` / `set_lock(item_id, bool)`(**item-level**) |
| Salvage | #22 / #23 | `salvage(item_id)` + yield preview |
| Inventory list(120 cap + rarity badge + filter + provenance) | **#23** | typed items + `forge_shard` balance(int64 千位分隔)+ mailbox indicator |
| Bulk-salvage-by-rarity | #23 | `bulk_salvage(rarity)`(locked 絕對排除,無 bypass param)+ yield preview + **receipt-warning count**(EC-17 flag) |
| Mailbox claim | #23 | `claim(item_id)`;inventory 滿 → block + 「先騰 N 個位」+ bulk-salvage shortcut(EC-10) |
| Forge(locked hook) | #23 | `forge_shard` balance +「coming soon」hook(D7) |
| Source receipt / provenance hover | #22 / #29 | `signature_text` / `provenance_text` |

### UX 約束
- **Pillar 2**:workout 期間玩家唔需要任何 inventory UI 操作;所有 manual UI 係事後場景。
- **Bulk-salvage** 一 tap 拆批,唔可逐件 confirm;confirm dialog 須顯示 receipt-warning count(EC-17)。
- **AntiSnowball badge** informative 非 punitive。

> 📌 **UX Flag** — UI 由 **#22 + #23** 承載。Pre-Production 寫 epic 之前先跑 `/ux-design`(#22 / #23),特別係 bulk-salvage flow(含 receipt warning)+ AntiSnowball badge + mailbox claim-when-full flow。Stories cite `design/ux/character-screen.md` / `design/ux/inventory-ui.md`。

## Acceptance Criteria

> Given-When-Then;Story type 標尾。**Test seams(binding;Pass 3 擴至 8 項)**:(1) 所有 TTL/timestamp 邏輯經 injectable `TimeProvider`(`now_unix()`;production 真 clock,test 注 fixed value;**`acquired_at_unix` / `salvaged_at_unix` stamping 一律經此**;`TimeProvider` 係 **#17-introduced seam** — repo 現有先例係 injectable Callable / now-param,跟同款 pattern);(2) #11 經 untyped DI seam mock(project 慣例 — typed Node seam compile-time fail);(3) persistence 經 `IPersistence` mock;(4) MVP 無 runtime RNG(D9)— 無 seed seam 需求;(5) logger assert 一律改用 telemetry signal(可 spy);(6) **GSM state 經 untyped DI mock + `connect_for_initial_state` 注入**(AC-21/29/30);(7) **`TimeProvider.server_unix() -> Variant`**(nullable;null = offline → grace path;AC-09 sanity clause);(8) **persistence primary(backend)/ secondary(`user://`)兩層可獨立 mock**(AC-32a)。

### Hydration / Validation
- **AC-01 (Logic)** — **GIVEN** valid `loot_drop_record`(metadata 齊)+ inventory 有位,**WHEN** `receive_loot()`,**THEN** typed `EquipmentItem` 產生,`stat_modifiers` == Stat Assignment Table 該格,state = `IN_INVENTORY`。
- **AC-02 (Logic,Pass 3 contract 修正)** — **GIVEN** metadata 缺 `source_transition_id`,**WHEN** `receive_loot()`,**THEN** return `ReceiveResult.FAILED_ROLLBACK` + emit `loot.inventory.grant_fail` CRITICAL,inventory size 不變(`loot.pending.recovery` write 係 #15 EC-48 responsibility — drain side 由 AC-28 cover)。
- **AC-03 (Logic,Pass 3 contract 修正)** — **GIVEN** LEGENDARY 缺 `source_receipt`,**WHEN** `receive_loot()`,**THEN** return `FAILED_ROLLBACK` + CRITICAL emit(同 AC-02 斷言);**AND** COMMON 缺 receipt **THEN** return `OK` 正常入庫(receipt=null,`provenance_text` 仍生成)。
- **AC-04 (Logic)** — **GIVEN** `rarity` missing,**WHEN** hydrate,**THEN** rarity = COMMON,無 rollback。
- **AC-05 (Logic,Pass 3 GIVEN 修正)** — **GIVEN** persisted cosmetic item dict(boot path)帶非空 `stat_modifiers`,**WHEN** boot re-hydrate,**THEN** `stat_modifiers == {}` + emit `inventory.stat_key.dropped`,item 照 load(EC-5)。
- **AC-06 (Logic,Pass 3 GIVEN 修正)** — **GIVEN** persisted functional item dict(boot path)被注入 `{STR: 20, ATTACK_POWER: -5}`,**WHEN** boot re-hydrate + guard,**THEN** STR key dropped、負 delta clamp 0,各 emit `inventory.stat_key.dropped`(EC-4;drop path metadata 唔讀 stat keys — D9)。

### Idempotency / Cap / Mailbox
- **AC-07 (Logic)** — **GIVEN** 已入庫 `(transition_id, drop_index)`,**WHEN** 重入,**THEN** no-op;**AND** 同 transition 唔同 `drop_index` ×2 **THEN** 兩件都入庫;**AND** 已 SALVAGED 嘅 item_id replay **THEN** 唔復活、shard 不變(tombstone,EC-6)。
- **AC-08 (Logic)** — **GIVEN** inventory = 119,**WHEN** 連收 2 件,**THEN** 第 120 件 `IN_INVENTORY`、第 121 件 `IN_MAILBOX`(EC-7 boundary 雙邊)。
- **AC-09 (Logic)** — **GIVEN** injected `now_unix = T`,mailbox 有 item A(`acquired_at = T - 8d`,無 receipt)、item B(`acquired_at = T - 8d`,**有 receipt**),**WHEN** boot sweep,**THEN** A auto-salvage(shard += `salvage_yield`,emit `inventory.mailbox.auto_salvaged`),B 保留(A3);**AND** server-time sanity 偏差超 tolerance **THEN** 兩件都保留(grace,EC-8)。
- **AC-10 (Logic)** — **GIVEN** mailbox 達 `MAILBOX_HARD_CAP`(最舊 = 無 receipt 件),**WHEN** 新 overflow 到,**THEN** 最舊者 auto-salvage + telemetry emit;**AND** 最舊係 receipt 件 **THEN** skip 佢拆次舊(EC-9)。
- **AC-11 (Logic)** — **GIVEN** mailbox item + inventory = 120,**WHEN** `claim(item_id)`,**THEN** block + 回傳 shortfall(EC-10),state 不變;**AND** inventory = 119 **THEN** claim 成功 → `IN_INVENTORY`。

### Equip / AntiSnowball
- **AC-12 (Logic)** — **GIVEN** WEAPON slot 現裝 RARE(+22),**WHEN** 收 EPIC weapon(+45,unlocked slot),**THEN** auto-equip swap,舊件 → `IN_INVENTORY`(loadout_score 升)。
- **AC-13 (Logic)** — **GIVEN** EQUIPPED weapon `is_locked = true`,**WHEN** 更強 weapon 到,**THEN** auto-equip skip,新件 `IN_INVENTORY`,loadout 不變。
- **AC-14 (Logic)** — **GIVEN** 兩 candidate `loadout_score` 相等,**WHEN** tie-break,**THEN** rarity↓ → acquired_at↑ → item_id↑ deterministic,重跑同結果。
- **AC-15 (Logic)** — **GIVEN** WEAPON slot 空 + inventory 有 COMMON weapon,**WHEN** salvage 觸發 backfill 評估(或 receive),**THEN** 正分 candidate equip 入空 slot(baseline 0);**AND** COSMETIC slot 空 + 收 cosmetic **THEN** 唔 auto-equip(manual-only,Rule 5)。
- **AC-16 (Logic)** — **GIVEN** 新號(mock `get_attack_power_excluding_equipment() = 28`)+ 三 functional slot 裝齊 LEGENDARY(table 值),**WHEN** aggregate + clamp,**THEN** push 畀 #11 mock 嘅 modifier == 單一 `&"equipment_aggregate"` id、`ATTACK_POWER = 84`(= min(90, max(30,84)))、HP/MOVE/CRIT 原值,`equipment.antisnowball.clamp` telemetry emit(Formula 4 example + AC golden 一致)。
- **AC-17 (Logic,Pass 3 擴 per-key)** — **GIVEN** 注入 test fixture aggregate `{ATTACK_POWER: 350, MAX_HP: 600, MOVE_SPEED: 150, CRIT_CHANCE: 0.30}`(全部超 #11 contract range)+ mock SDA = 200(cap = 600),**WHEN** clamp + per-key range clamp,**THEN** push 值 = `{ATK: 300, HP: 500, MOVE: 100, CRIT: 0.20}`(ATK = min(350, 600, 300);其餘各 clamp 至 #11 contract 上限)。
- **AC-18 (Logic)** — **GIVEN** Formula 1 golden vector(3×LEGENDARY,新號),**WHEN** 計 `loadout_score`,**THEN** == **163**(84×1.0 + 160×0.25 + 25×0.6 + 0.06×400)。
- **AC-19 (Logic)** — **GIVEN** ATK 已 at cap(SDA=28,WEAPON L equipped,effective 84)+ ARMOR slot 裝 RARE(+60 HP),**WHEN** 收一件假想「ATK-heavy」候選(test fixture)競爭 ARMOR slot,**THEN** loadout-marginal 比較唔 swap(swap 後 score 跌)— clamp-aware 防變弱(Rule 6)。
- **AC-20 (Logic,Pass 3 ordering 反轉)** — **GIVEN** EQUIPPED item + inventory 有 backfill candidate,**WHEN** `salvage(item_id)` 單一 synchronous call return,**THEN** (a) state == `SALVAGED` + backfill candidate 已 `EQUIPPED`;(b) #11 mock 收到**恰好一次** final-aggregate push(call-order spy:push 喺**所有** state mutation — SALVAGED + shard + backfill — **之後**,Rule 6 discipline);(c) shard += yield 同 item state 同一 transaction commit;(d) `IPersistence` mock 收到恰好一次 write(EC-13/EC-19;「atomic」用 call-order + 單 commit + 單 write 三個 proxy assert)。
- **AC-21 (Logic)** — **GIVEN** #11 mock 對 push 回 `stat_mutation_rejected`,**WHEN** auto-equip swap,**THEN** `_pending_stat_push` set,mock 轉 Ready 後 deferred re-push 成功,loadout 同 #11 無 desync(EC-14)。
- **AC-22 (Logic)** — **GIVEN** COSMETIC slot 被注入帶 stat 嘅 item(繞過 scrub)+ 3 functional slot 有裝備,**WHEN** aggregate,**THEN** push modifier 唔含 cosmetic 任何 delta(Rule 8 結構排除,最後防線)。
- **AC-23 (Logic)** — **GIVEN** 各 item_type 一件,**WHEN** receive,**THEN** WEAPON/ARMOR/ACCESSORY 各自落正確 slot affinity;CONSUMABLE 入庫、`slot_affinity == null`、唔觸發 auto-equip;COSMETIC 入 cosmetic pipeline(Rule 5 / EC-18)。

### Economy
- **AC-24 (Logic)** — **GIVEN** RARE item,**WHEN** salvage,**THEN** `forge_shard` += 250(Formula 2)。
- **AC-25 (Logic)** — **GIVEN** 5 件 unlocked COMMON + 1 件 locked COMMON + 1 件 unlocked-with-receipt COMMON,**WHEN** `bulk_salvage(COMMON)`,**THEN** 拆 6 件 unlocked(locked 保留),shard += 600,persist write **恰好一次**(Rule 9/13);**AND** `bulk_salvage_preview(COMMON)` return `{count: 6, yield: 600, receipt_count: 1}`(receipt-warning count 由 **#17 提供**,#23 confirm UI 顯示 — Pass 3 ownership 統一)。
- **AC-26 (Logic)** — **GIVEN** boot load shard balance = -500,**WHEN** `INITIALISING` step 3,**THEN** balance = 0 + `inventory.shard.balance_corrupted` CRITICAL emit(EC-20)。

### Persistence / Boot / Suspended
- **AC-27 (Integration,Pass 3 round-trip set 擴)** — **GIVEN** inventory + loadout + locks + shards 已 persist,**WHEN** boot `INITIALISING`,**THEN** round-trip equality:item(id + state + is_locked + **source_receipt + provenance_text + acquired_at_unix**)集合、shard balance、per-slot loadout 完全還原,#11 mock 收到等價 aggregate(在 StatSystem 之後,ADR-0008 ordering)。Receipt round-trip 係 A3 immunity / FIFO / F-12 ceremony 嘅 load-bearing fields。
- **AC-28 (Logic)** — **GIVEN** `loot.pending.recovery` 有 2 records(1 件已 tombstone),**WHEN** boot step 5 drain,**THEN** 新 record 入庫、tombstoned record no-op,namespace 清空(Rule 14)。
- **AC-29 (Logic,Pass 3 擴 READY burst)** — **GIVEN** system `SUSPENDED`,**WHEN** `receive_loot` ×3(含 1 duplicate;各 return `QUEUED_SUSPENDED`/dup 照 queue),**WHEN** resume drain,**THEN** FIFO 順序入庫、duplicate no-op、aggregate/push/persist 各恰好一次(batch,Rule 15 / EC-22);**AND GIVEN** `READY` state 連發 ×3(boot force-reveal burst),**THEN** 同樣 batch(aggregate/push/persist 各一次,debounce 至 batch 尾)。
- **AC-30 (Logic)** — **GIVEN** GSM Suspended-at-boot(mock initial state),**WHEN** boot 完成,**THEN** loadout push 未發生(`_pending_boot_replay` set);**WHEN** GSM 轉 Ready,**THEN** deferred push 發生一次(Rule 14 step 7)。
- **AC-31 (Logic)** — **GIVEN** 120 items 其中 1 件 mutate,**WHEN** action 結尾 flush,**THEN** `IPersistence` mock 收到**恰好一次** write(per-action 粒度,Rule 13)。
- **AC-32a (Integration,CI)** — **GIVEN** mock secondary persistence 所有 write 回 failure(seam 8 分層 mock),**WHEN** receive + salvage + boot replay,**THEN** 全部經 backend path 成功,state 經 backend reload 還原,secondary failure 只 logged warning(EC-21)。
- **AC-32b (VS-tier playtest,ADVISORY)** — 真 browser Private Mode 行為 documented playtest,跟 ADR-0003 VS-tier gate 一齊行。

### Pass 3 補完(zero-AC rules / 新 mechanism)
- **AC-33 (Logic)** — **GIVEN** test 注入一個 `stat_changed` handler 會 synchronous call 返 #17 mutation API,**WHEN** 任何 mutation operation push #11(emission 期間 handler 觸發),**THEN** `_mutating` guard 截住(`push_error` + deferred 至下一 frame 執行),state 無 corruption、無 nested mutation(EC-15)。
- **AC-34 (Logic)** — **GIVEN** #22 `equip(item_id, slot)` 一件**較弱** item(unlocked slot),**WHEN** call return,**THEN** equip 成功(manual 唔受 score 限制)+ 恰好一次 re-push;**AND WHEN** 下一次 auto-equip trigger,**THEN** 較強件換返上(Rule 7 interplay — 唔 lock 唔尊重,by design);**AND** `unequip(slot)` **THEN** item → `IN_INVENTORY` + re-push。
- **AC-35 (Logic)** — **GIVEN** metadata `item_type` = unknown string,**WHEN** `receive_loot()`,**THEN** return `FAILED_ROLLBACK` + CRITICAL emit(Rule 1)。
- **AC-36 (Logic)** — **GIVEN** persisted `inventory.*` 含 1 個 schema-shape 壞 dict + 2 個 valid item,**WHEN** boot step 2,**THEN** 壞 dict 棄 + CRITICAL telemetry,2 valid 照 load(Rule 14 step 2)。
- **AC-37 (Logic)** — **GIVEN** inventory 已 own cosmetic visual id X,**WHEN** `receive_loot()` 收同 visual id 嘅 cosmetic(rarity RARE),**THEN** 唔入庫、`forge_shard` += 250、return `CONVERTED_DUPE`、emit `inventory.cosmetic.dupe_converted`、tombstone 登記(Rule 11)。
- **AC-38 (Logic)** — **GIVEN** 新號(mock SDA=28)+ LEGENDARY weapon equipped,**WHEN** `get_aggregate_raw_and_effective()`,**THEN** return `{raw: 90, effective: 84}`(EC-16 badge data contract)。
- **AC-39 (Logic)** — **GIVEN** injected `now_unix = T` + tombstone `salvaged_at_unix = T - 38d`,**WHEN** boot prune,**THEN** 條目刪除;**AND** `T - 36d` **THEN** 保留(37日 boundary,Rule 2)。
- **AC-40 (Logic)** — **GIVEN** boot `INITIALISING` 觸發 shard clamp + mailbox auto-salvage + recovery drain(多個 mutation),**WHEN** boot 完成,**THEN** `IPersistence` mock 收到**恰好一次** `inventory.*` batched write,且 recovery-clear 發生喺該 write 之後(Rule 14 step 5/8 次序)。
- **AC-41 (Logic)** — **GIVEN** mailbox item claim 成功入庫(inventory 有位)且該 item 強過現役,**WHEN** claim return,**THEN** auto-equip 評估已跑、item `EQUIPPED`(Rule 6 trigger set:claim 後)。

## Open Questions / Cross-System Gates

| # | 問題 | Impact | Resolution path | Owner |
|---|------|--------|-----------------|-------|
| **G-1** ✅ **RESOLVED 2026-06-06** | #15 `MAILBOX_HARD_CAP` 100→**180**(INV-G3 修復)+ 4 處 stale「60」sweep(Formula E4 / CI-7 / EC-46 / AC-17)— 全部已落 #15 | — | done | — |
| **G-1b** ✅ **RESOLVED 2026-06-06** | #15 EC-47 stale「100」→ 180 + policy reconcile:主路徑 defer to #17 auto-salvage(A3),orphan_queue 降做 all-receipt fallback | — | done | — |
| **G-2** ✅ **RESOLVED 2026-06-06** | #11 三項全落:`get_attack_power_excluding_equipment()`(L267)· `is_boot_completed()`(L228)+ EC-21 reword · EC-17 same-id atomic-replace pin(supported path,#11 唔可以加 duplicate-apply assert) | — | done | — |
| **G-3** ✅ **RESOLVED 2026-06-06** | #15 EC-38 [OPEN] 回填:auto-convert = `salvage_yield(rarity)` | — | done | — |
| **G-4** ✅ **RESOLVED 2026-06-06** | ADR-0008 binding constraint 8(`StatSystem ≺ InventorySystem ≺ LootDropSystem`)+ InventorySystem reserved insertion rule | — | done | — |
| **G-5** | #3 `IPersistence.write_batch(Dictionary)`(optional — Rule 13 per-action flush 已可用單 write 實現) | bulk I/O 效率 | #3 視乎 epic 需要 | #3 |
| **G-7**(Pass 3 新增) | #2 GymSysBackendClient 暴露 last-known server time + freshness(Rule 4 mailbox sweep sanity check 依賴) | clock-sanity 數據源 | #2 GDD additive amendment;**soft gate** — offline fallback = grace(唔 expire),epic 時做唔 block design | #2 / epic |
| **G-8**(Pass 3 新增) | #3 namespace governance 表(persistence-layer.md L346「`gsm.inventory.*` TBD」)對齊 #17 `inventory.*` + `inventory.pending_queue` 直寫 | namespace lint scoping | #3 表一行修字 | #3 |
| **Q-2** | #15 應否將 CONSUMABLE 設 0-weight(MVP inert) | 20% reveal 開包見 inert(Pillar 3 稀釋);#15 config-driven 可改唔使郁 GDD | game-designer + economy-designer 確認;或 v0.2 reframe 做 forge material | game-designer |
| **Q-5**(重寫) | v0.2 Forge 定價:**MVP banked stockpile projection(Hardcore ≈ 3.9k–5.5k shards/週)係 binding input** — v0.2 落地時用真 telemetry 取代估算,定價須同時對 stockpile 玩家同新玩家公平。**時限假設(Pass 3)**:locked-sink anticipation 只喺 bounded wait 有效 — **Forge 須於 MVP launch 後 ~12 週內落地**,否則 banked framing 由 anticipation 退化成 broken promise(salvage reward signal 無兌換 backing 會 extinguish);#23 Forge hook 應顯示 preview 內容(anticipation 要有 information 先有力) | inflation-debt 防範 + anticipation 衰減 | #28 telemetry `forge_shard` accumulation 監察;v0.2 Forge GDD 必引本段 | economy-designer / v0.2 |
| **Q-7**(改寫) | v0.2 craft 設計 binding 約束:LEGENDARY craft **必須帶 workout-derived catalyst**(真身輸入,Pillar 1)+ **CraftReceipt type**(craft=你砌嘅 / drop=身體賜嘅;封 no-receipt LEGENDARY 撞 F-12)+ INV-E1/E2 invariants + per-tier UPGRADE_DISCOUNT(flat 0.6 數學上錯 — base salvage value 佔 craft cost 15–30% 且隨 tier 跌) | Pillar 3 drop 獨特性 + F-12 一致性 | v0.2 Forge GDD(見 § v0.2 Deferred Design) | economy-designer / v0.2 |

> **已 RESOLVED(Pass 1)**:Q-1(derived 4 key 名 grep-verified #11)· Q-3 → G-1 · Q-4 → A1 salvage-only · Q-6 → G-2 + D8(decomposition 問題結構性消失)· Q-8 → A3(Rule 4)。

## v0.2 Deferred Design — Forge(craft / upgrade)

> A1 決定:craft + upgrade 唔入 MVP。本節保留 Pass 1 review 驗證過嘅 forward 約束,v0.2 Forge GDD 必須繼承:

1. **Workout-derived catalyst**:craft/upgrade-to-LEGENDARY 消耗只有真實 workout drop 先出嘅 catalyst(Pillar 1:就算砌神裝,鎖匙都要身體賺;封 LEGENDARY 量產 — Pass 1 算術:無 catalyst 下 Hardcore 週 2 起 manufactured:dropped ≈ 4:1)。
2. **CraftReceipt type**:crafted/upgraded item 帶 craft 系 receipt(鑄造日期 + 消耗 + base lineage),**唔係** null —— 封 F-12「LEGENDARY 無 receipt = fabrication」矛盾;drop receipt 嘅稀缺性保住真實掉落情感獨特性。
3. **INV-E1**:`∀ tier: craft_cost(tier) > salvage_yield(tier)`(config-load assertion + CI;Pass 1 boundary:`SHARD_BASE=200` 喺 safe range 內已可造 infinite pump — knob safe range 必須 joint-validate)。
4. **INV-E2**:`craft_cost(t) + upgrade_cost(t) ≥ craft_cost(t+1)`(封 upgrade-path 套利)。
5. **Per-tier `UPGRADE_DISCOUNT`**(dominance-neutral ≈ `1 − salvage_yield(from)/craft_cost(to)`,mapping:**U→R 0.70 / R→E 0.82 / E→L 0.85**,再按傾斜度調;flat 0.6 令 craft 全 tier strictly dominated)。**COMMON 不可 upgrade**(純 salvage 飼料 — 無 C→U path);INV-E2 quantifier domain = `t ∈ {UNCOMMON, RARE, EPIC}`(COMMON 無 `craft_cost`)。
6. **Upgrade stat 處理明寫**(保留 roll 按 tier scale,守 endowment 敘事)+ **craft RNG seed seam**(injectable;#15 用 transition_id,craft 無 transition — seed 來源須 spec)。
7. **Formula 7 per-tier stat budget framework**(取代 MVP fixed table 或並存)。
8. 原 Formula 3 craft_cost 數值表(U 200 / R 500 / E 1,400 / L 3,000)做 v0.2 起點 anchor,連同 stockpile projection(Q-5)重定價。

---

> **Pass 2 re-review(2026-06-06,4 fresh verifiers:systems/economy/qa/godot)**:Pass 1 全部 blocker 一致確認 FIXED;新發現全部 line-level。**Pass 3 fixes(同日落地)**:B1 phantom constant → `HARD_CAP_DAYS` 37日 · B2 tombstone → `{item_id: salvaged_at_unix}` · qa-F1 salvage batch ordering(Rule 9/EC-13/diagram/AC-20 四處統一:mutations 先、push 最後)· qa-F2 `ReceiveResult` failure contract(AC-02/03/35 改 return assert;#15 sole-writer exception)· godot-F4 no-loss pins(recovery-clear 次序 / `inventory.pending_queue` durable queue / boot step 8 單 write)· godot-F5/F6(step 6 compute-only + `_mutating` window)· G-2 第三項(#11 EC-17 atomic-replace pin)+ G-1b(#15 EC-47 reconcile)落地 → **G-1/G-1b/G-2/G-3/G-4 全 RESOLVED**;G-7/G-8 新 soft gates · seams 5→8 · AC-27 round-trip set 擴 · 新 AC-33~41 · minor cluster(ranges/AC-18 pointer/UTC provenance/monotonic assertion/stockpile 修數/Q-5 時限)。
>
> **Pass 1 revision traceability**:A1/A2/A3 user-ratified 2026-06-06;B1(stat table + 新號 re-ground)→ D9 + § Stat Assignment Table + Formulas 注記;B2(Formula 4)→ Formula 4 + G-2;B3(Formula 1)→ Formula 1 + Rule 6;B4(item_id)→ Formula 6;B5(EC-2 scope)→ EC-2 + Rule 14 step 2;B6(EC-38)→ Formula 2 rationale + Rule 11 + G-3;B7(Q-3/INV-G3)→ G-1;B8(mailbox)→ Rule 4 + EC-8/9/10;B9(intake timing)→ Player Fantasy 時序註記 + EC-22;B10(boot/lifecycle)→ Rule 14/15 + EC-14 + G-2;B11(TTL 時基)→ Rule 4 + `CLOCK_SANITY_TOLERANCE_SEC`;B12(is_locked)→ Rule 7;B13(AC bundle)→ § AC 重寫(32 條 + seams);B14(deps)→ Dependencies + Interactions #4/#33;B15(INV-E)→ § v0.2 items 3/4。Recommended 已落:sanity check 重寫、dirty-save 粒度(Rule 13)、provenance 全 tier(Rule 10)、shard atomicity(EC-19/20)、ADR-0008(G-4)、tombstone prune(Rule 2)、re-entrancy(Rule 6/EC-15)、SerializableResource envelope(Rule 12)。Deferred:tombstone codex view → #23 UX spec(強烈推薦)、CONSUMABLE reframe → Q-2。

---

## Errata(2026-06-07 — #21 story-024 / G-LM-10 執行)

1. **`inventory_system.gd:145` doc comment「#15 calls this」** → caller = **#21 LootRevealCoordinator @ S3**(INV-M3 — banking 喺 S3 entry,唔係 modal dismissed 時;#15 從未係 runtime caller)。
2. **EC-1 recovery 鏈 locus**:caller 唔直接寫 `loot.pending.recovery`(#21 stateless presentation)— 經 #15 `report_receive_failure(drop_id)`(G-LM-4b,sole-writer 紀律保持)。
3. **EC-22/AC-29 batching 語意 = internal-context-only**(`_batch_depth` boot/suspended-drain 專用)— external caller coalescing 屬 **G-LM-10 public seam**:`begin_receive_batch()` / `end_receive_batch()`(nested 配對;outermost end 行 deferred aggregate-push + state-flush exactly-once;unbalanced end = warned no-op)。Shipped per-call persist 行為對非 seam caller 不變(opt-in)。
