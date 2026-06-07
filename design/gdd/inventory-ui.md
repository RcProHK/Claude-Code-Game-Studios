# Inventory UI (#23)

> **Status**: Designed(pending fresh-session `/design-review`)— degraded inline authoring(agent spawn 1M-credit block;#18/#19 先例;CD-GDD-ALIGN skipped — fresh full review 把關)
> **Author**: frank + design-system pipeline(degraded inline 2026-06-07)
> **Last Updated**: 2026-06-07
> **Implements Pillar**: Pillar 1(provenance 收據庫)· 支援 Pillar 3(loot 整理 — 唔搶 #21 ceremony)
> **核心裁決**:獨立 full-screen surface(#22 pattern 全套 cite,divergence-only 寫法)/ CanvasLayer 61(G-IU-2)/ bulk per-rarity + shipped `bulk_salvage_preview` + receipt itemised / mailbox static「保留至 [date]」**禁倒數** / claim shortfall → MAKE_ROOM 零代理分解 / sort 固定 #22 F3 同一 code / **零新 SFX cue** / #23 零 persist 零 #11/#26 訂閱

<!-- DESIGN CONTEXT(2026-06-07 pre-load — #22 authoring session 已 grep-verify 晒,fresh session 唔使重 grep)

## 上游 contracts(BINDING — 全部 shipped/approved)

### #17 InventorySystem(shipped — src/autoload/inventory_system.gd)
- Commands(synchronous Dictionary return {"ok": bool, "error": String}):`salvage(item_id)` L548(locked → {"error":"locked"} — lock 免疫所有 salvage path)/ `bulk_salvage(rarity)` L581(every UNLOCKED item of rarity;mailbox+inventory+equipped 全 in range,equipped unlock-state 件 batch 內 auto-unequip)/ `claim(item_id)` L704(mailbox → inventory;**inventory full 時 blocked** — claim-when-full flow 係 #23 嘅 UX 命題,#17 L359 UX flag 指明)/ `equip`/`unequip`/`set_lock`(同 #22)
- Error codes ground truth:not_found / in_mailbox_claim_first / slot_type_mismatch / slot_empty / locked / **deferred_reentrancy(下 frame 自動重放 — 唔好 toast,#22 Rule 15 先例)**
- Reads:`get_item(item_id) -> EquipmentItem` / `get_inventory_count()` / `get_forge_shards()` / static `salvage_yield(rarity)`(COMMON 100 → LEGENDARY 800)
- **G-CS-1(#22 GDD 開咗,#23 係主受惠者)**:`get_loadout()` copy + enumeration getters — #23 嘅 full list 係主糧,gate 先行
- 冇 loadout/mutation signal — UI 用 command-then-re-read 模式(#22 Rule 14 先例)+ panel visibility re-read(#22 Rule 23)
- MAX_INVENTORY=120 / MAILBOX_HARD_CAP=180;mailbox TTL auto-salvage + receipt-never-silent-expire(#17 A3)
- acquired_at_unix 係 unix **seconds** — 同秒 tie 常態,sort 必須有 final tie-break(#22 F3 comparator 先例:rarity desc → acquired desc → item_id asc = strict total order;#23 如加 sort axes 都要保 total order)

### #22 Character Screen(Designed 2026-06-07 — 邊界 contract)
- #22 Rule 17 邊界:**full browse / sort / search / bulk operations = #23 地盤**;#22 picker 只做 slot-filtered 揀件
- 共用 patterns:ITEM_INSPECT(provenance/signature 顯示)/ salvage 兩步 confirm + yield preview / locked 灰掉 / P-06 badge / formatter-as-epsilon / GSM 入口 whitelist {IDLE, DISCONNECTED}(#23 大概率同款 — authoring 時裁)/ force-close 紀律(零 SFX — CD C1 先例)
- #22 嘅 49 ACs + lifecycle state machine 係直接 template

### #21 / GSM
- OQ-6:「未開封」mailbox item tap entry(ritual recovery)→ **v0.2**(需 #23 surface + GSM erratum + 獨立 content-source 分支;30-日 hard-cap auto-commit 件唔喺 reveal queue)— #23 MVP 唔做 reveal,首次見面永遠喺 #21
- P-06 inventory list display 規定:rarity badge = colored corner accent + **text label adjacent**(永不 color-alone)

### 其他
- CJK body Zpix 12px floor;touch ≥48px;無 hover-only/long-press(#22 Rule 22 先例)
- Art bible:#22 嘅 quiet ledger 文法(L0-L3 tier 表、particle=0、賬簿線 framing)大概率延伸 #23 — art-director consult 時確認
- ADR-0001 UI budget;ADR-0006 C6 connect_for_initial_state(如 subscribe)

## 設計裁決待做(authoring 時)
1. Shell 關係:#23 係 #22 嘅第四個 tab 定獨立 screen?(#22 Rule 23 cross-tab re-read 已預咗 tabs 可能性;#17 L359 將兩個 UX flag 分開寫)
2. Bulk-salvage flow:rarity 揀選 UI + receipt warning(LEGENDARY/receipt 件喺 bulk 內點 surface?lock 係唯一保護?)+ 後果 preview(N 件 → M shards)
3. Mailbox surface:claim 入口 / claim-when-full flow(騰位 vs 直接 salvage)/ TTL 倒數顯示?(收據聲線 vs 倒數壓力 — Pillar 3 anti-pillar 張力)
4. Sort / filter axes(rarity / slot / acquired / locked-first?)+ F3 擴展
5. 入口 rule(跟 #22 GSM whitelist?)+ 同 #22 嘅 navigation
-->

## Overview

Inventory UI(#23)係玩家嘅 **full inventory browse + 整理 surface** — #22 Character Screen 嘅「倉房」姊妹篇。玩家喺 GSM `IDLE` / `DISCONNECTED` 打開,瀏覽全部 IN_INVENTORY items(最多 120)+ MAILBOX overflow(最多 180)、用 slot filter chips 收窄、tap 入 ITEM_INSPECT 做單件操作(equip / lock / salvage — #22 同款 flow)、claim mailbox 件(full 時行 shortfall 騰位 flow)、同埋做 **per-rarity bulk-salvage**(#17 `bulk_salvage_preview` → 兩步 confirm + receipt itemised warning)。

#23 **唔 own 任何 game data**(#22 Rule 2 同款 pure overlay):全部經 #17 commands + getters;唯一新接口 = **G-IU-1 enumeration getters**(`get_mailbox_items` / `get_all_inventory_items` — additive,G-CS-1 先例)。Lifecycle / 訂閱 / force-close / injected clock 紀律**全套 cite #22**(Rules 1-8 pattern reuse — 唔重抄,divergence 先寫)。實作受 ADR-0001(CanvasLayer 61 — G-IU-2 revision)、ADR-0008(insertion — G-IU-2)、ADR-0003 約束。

玩家影響:#22 答「我而家係邊個」,#23 答「**我儲低咗啲乜**」— Pillar 1 嘅收據庫。冇 #23,mailbox 係黑箱(claim-when-full 冇 UX)、bulk 整理冇入口、120 件上限變成無形牆。

## Player Fantasy

> **Framing**:「**執倉**」— 收據庫嘅管理員時刻。#22 係門框(回望刻度),#23 係**儲物房**:你打開個櫃,一格格全部係有日期嘅收據。執倉嘅滿足感係 Maintenance 型(唔係 Achievement 型)— 分解一批 COMMON、鎖好件有故事嘅 LEGENDARY、領埋 mailbox 嗰幾件 — 操作完,間倉「整齊咗」。

- **聲線**:quiet ledger 延伸(#22 同款:數字+日期做主語、零 hype、禁 progress-bar 語言)。倉房比門框**操作性重** — 但操作嘅語言係 bookkeeping(「已分解 12 件 — +1,400 碎片」),唔係戰利品慶祝(dopamine 全部留 #21)。
- **Mailbox 張力裁決**:TTL 7 日 auto-salvage 係事實,但**唔做倒數計時器**(ticking countdown = 壓力 UI,違 Pillar 2 anti-pillar「製造焦慮嘅 mechanic」)— 顯示 static「**保留至 [date]**」(device local,#22 EC-15 同款)。事實照講,情緒唔加。
- **Bulk-salvage 嘅誠實度**:批量毀滅要兩步 + 後果 itemised(N 件 → M 碎片;內含 R 件 receipt 件逐件列名)— 收據件「永不 silent expire」(#17 A3)嘅 UI 兌現。Lock 係唯一硬保護,warning 係誠實防線。
- **Design test**(#22 同款延伸):任何 #23 micro-copy 問「呢句係咪倉房管理員嘅記帳語言?」— 係催促、係倒數、係慶祝,就唔屬於呢度。

**Pillar 對齊**:Pillar 1 primary(provenance 收據庫 — 每件嘅日期同來歷喺度先睇得晒)· 支援 Pillar 3(loot 整理後勤 — 唔搶 #21 ceremony,首次見面永遠喺 #21)。

## Detailed Design

> **Pattern reuse 宣言(本 GDD 嘅 ground rule)**:#23 嘅 lifecycle / 訂閱 / 命令 / 誠實度紀律**全套繼承 #22**(character-screen.md,APPROVED 2026-06-07)。下面用「**= #22 Rule N**」標明 cite;只有 **divergence** 先至全文寫。Implementer 讀本 section 要同 #22 GDD 並讀。

### Core Rules

**A. 入口 / lifecycle(= #22 Rules 1-6,divergence 如下)**

1. **入口條件 = #22 Rule 1 同款**:GSM ∈ {IDLE, DISCONNECTED} whitelist;入口 affordance 由 host shell own(provisional — Q-IU1);`can_open()` + `open()` double guard;**明文拒用 #33 `is_input_permitted()`**(同款語意分離)。**新增:#22 LOADOUT tab 嘅「查看全部 →」link 係第二入口**(#22 Rule 17 邊界嘅另一面)— tap → close #22(normal close path)→ open #23(sequential,唔並存)。
2. **同 #22 互斥**:#22 同 #23 永不同時 OPEN(都係 full-screen 全 attention surface)— shell/link 入口負責 sequential 切換;#23 `open()` 內 re-check 對方 state 唔係 #23 責任(coordinator 唔互相依賴 — shell own,Q-IU1)。
3. **Force-close / SUSPENDED / IDLE↔DISCONNECTED / close 手勢 / clean-slate reset = #22 Rules 3-5 全套**(FORCE_CLOSING ≤150ms 零 SFX CD C1 / snap 零 SFX / banner toggle 唔 close / 每次 open reset `active_section=INVENTORY`、`modal=NONE`、filter reset ALL)。Destructive modal(SALVAGE_CONFIRM / BULK_CONFIRM)force-close 一律 cancel(= #22 EC-01)。
4. **Close 唔 cancel #17 writes = #22 Rule 6**。

**B. Browse(enumeration + filter + sort)**

5. **Open 第一 frame sync read 齊(= #22 Rule 7)**:G-IU-1 `get_all_inventory_items()` + `get_mailbox_items()` + `get_inventory_count()` + `get_forge_shards()` + `get_loadout()`(G-CS-1 — 標 EQUIPPED 件)。冇 loading state。
6. **訂閱(= #22 Rule 8 pattern)**:GSM `state_changed` 經 cfis;**#11/#26 唔訂**(#23 冇 stat/avatar 面 — 比 #22 少兩條);CLOSED 零-subscription invariant 同款;command-then-re-read + section visibility re-read(= #22 Rules 14/23)。
7. **Sort = #22 F3 comparator 固定**(rarity desc → acquired desc → item_id asc — strict total order,byte-identical;referenced formula,唔 duplicate)。MVP **冇** user-selectable sort axes(收據庫唔係 spreadsheet;v0.2 Q-IU3)。
8. **Filter:slot chips**(ALL / WEAPON / ARMOR / ACCESSORY / COSMETIC)— 單選;filter 只係 view predicate(`item.slot_affinity == chip`),唔改 sort;切 chip = 即時 re-filter(本地,唔 re-read)。EQUIPPED 件**照列**(badge「現役」)— 倉房口徑 = 你擁有嘅全部。
9. **List 係 virtualized**(= #22 Rule 17 picker 同款理由:120+180 worst case;AC-49 class budget);row = P-06 item card pattern(name + rarity badge + provenance + locked / 現役 / mailbox 標記)。

**C. Mailbox + claim**

10. **MAILBOX section**(`active_section` 軸第二格):列 IN_MAILBOX 件(F3 同款 sort);每 row 加 static「**保留至 [date]**」(F2 retention date;device local;**禁倒數 ticking** — Player Fantasy 裁決)。Receipt 件(`has_receipt()`)加 receipt glyph(#17 A3:TTL 過都唔會 silent expire — 文案註明「收據件唔會自動分解」)。
11. **Claim flow**:row「領取」button → `claim(item_id)`(= #17 L709)→ ok → re-read(claim 會觸發 #17 auto-equip 評估 — 件如果上咗身,toast「已領取並裝上」;否則「已領取」);**`shortfall > 0`(inventory full)→ 開 `MAKE_ROOM` 流程**:non-blocking sheet「倉滿 — 要騰 [shortfall] 個位」+ 直接俾 INVENTORY section 入口(預設 COMMON filter?唔 — 保持 ALL,唔好自作聰明);玩家自行 salvage 騰位後再 claim。**唔提供「自動幫你分解最平嗰件」**(毀滅永不代理 — 兩步 friction 價值觀延伸)。
12. **Mailbox 件嘅單件操作限制**:IN_MAILBOX 件 tap → ITEM_INSPECT 照開(provenance 睇得),但 equip / salvage 入口 **disabled +「先領取」hint**(#17 ground truth:`in_mailbox_claim_first`)— UI 唔俾你撞 error,error code 留做 stale-race 防線。

**D. 單件操作(= #22 Rules 19-22 全套 cite)**

13. **ITEM_INSPECT** = #22 Rule 22 同款 view(provenance 全文 + LEGENDARY signature + stat_modifiers 原始數據 — 禁 predicted final);**新增 equip 入口**(slot_affinity 已知 ⇒「裝備」button → `equip(item_id, item.slot_affinity)`;cosmetic 同款;成功 → toast + 現役 badge 更新;**lock nudge = #22 Rule 18 同款 unconditional**);salvage 入口 = #22 Rule 19 兩步 + locked 灰掉(Rule 20);lock toggle 同款。
14. **Command error handling = #22 Rule 15 全套**(5 error codes → re-read + toast;`deferred_reentrancy` 唔 toast 下 frame 收割;toast = ARIA live region)。

**E. Bulk-salvage(per-rarity)**

15. **入口**:INVENTORY section header「批量分解」button → `BULK_SELECT` sheet:5 個 rarity row,每 row 顯示 `bulk_salvage_preview(rarity)` 結果(「COMMON — 12 件 → 1,200 碎片」;0 件 row 灰掉唔 disable tap — tap 顯示「呢個 tier 冇可分解嘅件」,= #22 EC-20 mystery-meat 原則)。
16. **確認(兩步 friction 加重版)**:rarity row tap → `BULK_CONFIRM` modal:count + yield + **receipt 件 itemised**(`receipt_count > 0` ⇒ modal 內逐件列 name + provenance —「呢 [R] 件帶收據,分解後簽名永久消失」;receipt 件冇 lock 嘅話 bulk 會食埋佢哋 — #17 ground truth lock 係唯一 immunity);cancel button + scrim=cancel + default focus=cancel(= #22 Rule 19 modal affordances);confirm → `bulk_salvage(rarity)` → re-read + toast「已分解 [count] 件 — +[shards] 碎片」+ `ui_salvage_execute` **一響**(唔 per 件)。
17. **Preview→execute 之間嘅 drift**:confirm modal 顯示嘅數字係 preview 時點;execute 用 #17 當下真值(return {count, shards})— toast 報 **execute 結果**,唔報 preview 數(兩者可以唔同 — EC 處理,唔係 bug)。
18. **Bulk 唔掂 mailbox 顯示口徑註記**:#17 `bulk_salvage` range 係**全部 unlocked 同 rarity 件(mailbox + inventory + equipped)**(L591-597 ground truth)— BULK_CONFIRM modal 文案必須講明「包括信箱 + 現役」;equipped 件被食 → #17 內部 auto-unequip + backfill(= #22 EC-13 同款兩 outcome,#23 re-read 自然反映)。

### States and Transitions

**FSM = #22 五態全套**(CLOSED / OPENING / OPEN / CLOSING / FORCE_CLOSING — 行為、timing knob、GSM 監聽、CLOSING 照聽 GSM、ghost-callv guard 全部 = #22 States 表;#23 唔重抄)。

**OPEN 內 orthogonal 軸(#23 自己)**:

| 軸 | 值 | 備註 |
|----|----|------|
| `active_section` | `INVENTORY`(default)/ `MAILBOX` | section 切換 = visibility re-read(= #22 Rule 23)|
| `slot_filter` | `ALL`(default)/ WEAPON / ARMOR / ACCESSORY / COSMETIC | view predicate only;open reset ALL |
| `modal` | `NONE` / `ITEM_INSPECT` / `SALVAGE_CONFIRM` / `BULK_SELECT` / `BULK_CONFIRM` / `MAKE_ROOM` | force-close 一律 cancel;ESC routing = #22 EC-07(modal 先 screen 後;BULK_CONFIRM ESC 退返 BULK_SELECT — 兩層 sheet 逐層退)|

### Interactions with Other Systems

| System | 方向 | 性質 | Interface |
|--------|------|------|-----------|
| **#17 Equipment & Inventory** | IN(read)+ OUT(command)| Hard | commands:`claim` / `equip` / `unequip` / `set_lock` / `salvage` / `bulk_salvage`;reads:`get_item` / `get_inventory_count` / `get_forge_shards` / `get_loadout`(G-CS-1)/ static `salvage_yield` / **`bulk_salvage_preview`(shipped — Pass 3 已預)** + **G-IU-1 additive getters**(`get_all_inventory_items()` + `get_mailbox_items()` — code 未有)|
| **#1 GSM** | IN(read + subscribe)| Hard | = #22 同款(cfis + force-close + call_deferred)|
| **#22 Character Screen** | 邊界 + 入口 | Soft | #22 LOADOUT「查看全部 →」→ sequential 切換(Rule 1);pattern 共用(inspect / salvage / lock / P-06 / formatter-epsilon / FSM);**互斥並存**(Rule 2)|
| **#21 Loot Modal** | 邊界 | Soft | 首次見面永遠喺 #21;mailbox「未開封」reveal = v0.2 OQ-6(Q-IU2)|
| **#4 AudioManager** | OUT(`play_sfx`)| Hard | **零新 cue** — 全 reuse #22 嘅 catalog 行(`ui_sheet_open/close` / `ui_salvage_execute` / `ui_lock_on/off` / `ui_equip_settle` 唔用[冇 stat 面]/ `ui_back` / `ui_error`)+ #22 open/close cue **唔 reuse**(screen 識別)→ 加 2 cue?**裁:reuse `ui_charscreen_open/close`**(同一 ledger 聲線家族;cue 係質感唔係 screen ID)— 零 catalog 改動,零 G gate |
| **#3 PersistenceLayer** | (none MVP)| — | #23 零 persist(filter/section 唔 sticky — clean-slate reset;**冇 #23-owned keys**)|
| **#26 / #11** | (none)| — | #23 冇 avatar/stat 面 — 明文唔訂 |

## Formulas

> #23 係 thin browse surface —「**唔需要 formula**」清單先行(#22 同款誠實地薄原則):

| 候選 | 裁決 | 理由 |
|------|------|------|
| Bulk yield preview | **Rule(Rule 15)** | 直接 render #17 `bulk_salvage_preview(rarity)` return({count, yield, receipt_count} — shipped L622)— #23 自己計 = duplicate ban 違規 |
| Claim shortfall | Rule(Rule 11)| `claim()` return `shortfall` verbatim(#17 L716)|
| Sort comparator | Referenced | = #22 F3(char_screen_formulas.gd `picker_before` — 同一 code,唔 fork)|
| Slot filter | Rule(Rule 8)| 單一 equality predicate,冇數學 |
| Shards 顯示 | Rule | verbatim int(#22 同款禁 K/M)|

### F1 — Mailbox retention date(唯一 #23-owned formula)

The `retention_date` formula is defined as:

`retention_date = date_local(acquired_at_unix + OVERFLOW_MAILBOX_TTL_DAYS × 86400)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| 入箱時間 | `acquired_at_unix` | int | unix seconds > 0 | #17 item field(mailbox 件 = 入箱時刻;TTL sweep 同一基準 — ground truth `_ttl_sweep` 用 acquired_at)|
| TTL | `OVERFLOW_MAILBOX_TTL_DAYS` | int | 7(#17 const L32 — **#17 own,#23 referenced**)| auto-salvage 期限 |
| 顯示 | `date_local` | func | — | device-local 日期 format(= #22 EC-15 timezone 規則)|

**Output Range:** 永遠係未來或過去嘅有效日期;過期件喺 #17 boot sweep 已被 auto-salvage(receipt 件除外 — A3),#23 list 唔會見到過期 non-receipt 件。**Receipt 件可以顯示過去日期** — render 規則:receipt 件唔顯示 retention 行(佢哋唔會被 sweep — 顯示限期 = 講大話)。
**禁 ticking countdown**(pinned design constant — Player Fantasy 裁決,唔係 knob)。
**Example:** acquired 6月1日 09:00 → retention「保留至 6月8日」;receipt 件 → 無 retention 行 +「收據件唔會自動分解」note。

## Edge Cases

> 格式 = #22 同款:**If [condition]**: [exact outcome]。Lifecycle/GSM race 類(force-close × modal / suspend snap / IDLE↔DISCONNECTED / signal 喺非 active states / re-tap open)**= #22 EC-01..07 全套 cite**,#23 唔重抄;以下只列 #23-specific。

- **EC-01(bulk preview 同 execute 之間 drift)**:If BULK_CONFIRM 開咗之後、confirm 之前,另一路徑(claim 觸發 auto-equip / TTL sweep)改咗 item 池:confirm 照行,`bulk_salvage` 用 #17 當下真值;toast 報 **execute return**({count, shards}),唔報 preview 數。Modal 唔 live-update(preview 係快照,execute 係事實)。
- **EC-02(bulk 0 件 rarity)**:If `bulk_salvage_preview(rarity).count == 0`:row 灰掉但 tap 照應(「呢個 tier 冇可分解嘅件」inline note)— 唔 disable(mystery meat,= #22 EC-20 原則)。
- **EC-03(bulk 全 locked)**:If 該 rarity 全部 locked:preview count==0(#17 preview 已濾 locked)→ EC-02 同款;modal 文案唔使特別講 locked(lock 係玩家自己嘅保護,唔使解釋)。
- **EC-04(claim shortfall)**:If `claim` 回 `{ok: false, shortfall: N}`:開 `MAKE_ROOM` sheet(「倉滿 — 要騰 N 個位」)+ INVENTORY section 直達;**零自動代理分解**。Claim button 唔 disable(每次 tap 重新檢查 — inventory 隨時變)。
- **EC-05(claim 後 auto-equip)**:If claim ok 且 #17 `_evaluate_auto_equip` 將件裝上:re-read 見 EQUIPPED → toast「已領取並裝上」;否則「已領取」。**#23 唔出 lock nudge**(nudge 係 manual equip 嘅誠實兌現 — auto-equip 上身係 #17 機器,#22 Rule 24 silent-accept 口徑)。
- **EC-06(mailbox 件 inspect 操作限制)**:If IN_MAILBOX 件 inspect:equip / salvage 入口 disabled +「先領取」hint(Rule 12)— stale race 下 command 照有 `in_mailbox_claim_first` 防線(= #22 Rule 15)。
- **EC-07(TTL 過期 race)**:If MAILBOX section 顯示緊某件,佢喺另一 session/boot 被 TTL sweep 食咗:任何操作 → `not_found` → toast + section re-read(= #22 EC-17 stale 口徑)。
- **EC-08(receipt 件 retention 行)**:If `has_receipt()`:**唔 render** retention 行(F1 規則)+ note「收據件唔會自動分解」— 顯示假限期 = 講大話。
- **EC-09(filter 下 empty)**:If slot_filter 收窄到 0 件:section 照 render empty-state(「呢類暫時冇收藏」)— 唔 auto-reset filter。
- **EC-10(120 滿 + mailbox 180 滿)**:If 兩個 cap 都頂:claim 永遠 shortfall;#17 hard-cap FIFO evict 係 #17 機器(#23 唔 render evict 預警 — v0.2 Q-IU4);MAKE_ROOM copy 照用。
- **EC-11(#22↔#23 sequential 切換 race)**:If「查看全部 →」tap 時 GSM 啱啱轉 state:#22 close 照行,#23 `open()` double guard 拒絕 → 玩家落返 shell(唔 crash 唔 limbo)— 兩個 coordinator 各自 guard,夾埋 safe。
- **EC-12(bulk 期間 force-close)**:If BULK_CONFIRM confirm 嗰下同 frame GSM force-close:= #22 EC-04 (i) 口徑 — `bulk_salvage` synchronous 已執行就成立(#17 single transaction),re-read/toast skip,下次 open 收割;modal 喺 force-close cancel(永不 confirm)= 未撳 confirm 就乜都冇發生。
- **EC-13(DISCONNECTED 全功能)**:= #22 EC-30 positive assertion 同款 — claim / bulk / equip / lock / salvage 全 local,照行,唯一 delta = offline banner。
- **EC-14(virtualized list + 同 frame mutation)**:If bulk execute 令 list 由 120 件變 8 件:re-read 後 virtualized container rebuild,scroll 位置 reset 去頂(唔保留 — 內容已根本唔同;保留 scroll 對住新 list 係假連續性)。

## Dependencies

### Upstream(#23 depends on)

| System | Hard/Soft | Interface | Bidirectional 狀態 |
|--------|-----------|-----------|---------------------|
| **#17 Equipment & Inventory** | Hard | commands(claim/equip/unequip/set_lock/salvage/bulk_salvage)+ reads(get_item/get_inventory_count/get_forge_shards/get_loadout/salvage_yield/**bulk_salvage_preview** shipped)+ **G-IU-1 additive getters** | ✅ #17 L359 UX flag 指明 claim-when-full 係 #23 命題;bulk_salvage_preview doc comment 直接點名 #23 |
| **#1 GSM** | Hard | = #22 同款(whitelist + cfis + force-close)| generic UI consumer |
| **#4 AudioManager** | Hard | `play_sfx` — **零新 cue,全 reuse #22 catalog 行**(含 ui_charscreen_open/close — 同一 ledger 聲線家族)| reuse 唔使 catalog gate;catalog 來源 column 加 #23 隨 G-IU-3 errata |
| **#22 Character Screen** | Soft(入口 + pattern)| LOADOUT「查看全部 →」sequential 切換;FSM/inspect/salvage/lock/F3/formatter-epsilon 全 pattern cite | ✅ #22 Rule 17 邊界 +「#23 係 full inventory surface」row 已 forward |

### Downstream(depends on #23)

| System | 性質 | 內容 |
|--------|------|------|
| **#21 Loot Modal** | v0.2 | OQ-6 mailbox「未開封」reveal 需要 #23 surface(Q-IU2)|
| **#24 Shell** | 入口 | #23 入口 affordance(Q-IU1,#22 Q-CS1 同款 provisional)|

### 非依賴(明文)

- **#11 / #26**:#23 冇 stat / avatar 面 — 零訂閱零讀(Rule 6)。
- **#3 PersistenceLayer**:#23 零 persist(filter/section clean-slate reset;冇 owned keys — 連 namespace 都唔使開)。

### Cross-system gates(G-IU-* — epic 內 stories;G-CS 先例)

| Gate | 內容 | 性質 |
|------|------|------|
| **G-IU-1** | #17 additive enumeration getters:`get_all_inventory_items() -> Array[StringName]`(IN_INVENTORY 全 slot)+ `get_mailbox_items() -> Array[StringName]`(IN_MAILBOX)— 排序由 #23 做(F3);copy 語意(G-CS-1 同款)| additive story(**browse 主糧 — 先行**)|
| **G-IU-2** | ADR-0001 revision:**InventoryUILayer 61**(PAUSABLE;>60 #22 / <100 capture — mood identity 同 #22 Rule 34 注記同款)+ ADR-0008 insertion(InventoryUICoordinator tail append 喺 CharacterScreenCoordinator 後;#28 keep last)| ADR revisions(scaffold 前提)|
| **G-IU-3** | #4 catalog 來源 column errata:reuse 行加 #23(ui_sheet_* / ui_salvage_execute / ui_lock_* / ui_back / ui_error / ui_charscreen_open/close)| doc erratum |
| **G-IU-4** | #22 GDD「查看全部 →」link 落地 row(LOADOUT panel header;#22-side 一行 + #23 接線)| #22 additive 一行 + wiring |

## Tuning Knobs

| Knob | Default | Safe range | Too high | Too low | Source |
|------|---------|-----------|----------|---------|--------|
| `BULK_CONFIRM_RECEIPT_LIST_MAX` | 8 | 4-20 | modal 超高(細屏 scroll)| receipt 件列唔晒 →「+N more」行(誠實度:總數照報)| Rule 16 |

### Referenced knobs(source of truth 喺上游/姊妹 — #23 唔 duplicate)

| Knob | Owner | #23 關係 |
|------|-------|----------|
| `OVERFLOW_MAILBOX_TTL_DAYS`(7)| #17 L32 | F1 retention date 嘅 TTL 來源 |
| `MAX_INVENTORY`(120)/ `MAILBOX_HARD_CAP`(180)| #17(DESIGN-FROZEN)| virtualized worst case + MAKE_ROOM copy |
| `FORCE_CLOSE_MAX_MS` / `ERROR_TOAST_DURATION_MS` / `ARIA_COALESCE_WINDOW_MS` / `OPEN/CLOSE_ANIM_MS` | #22 timing config | FSM/toast/ARIA 全 reuse(#23 自己零 timing knob — injected clock 同款紀律)|
| salvage_yield 曲線 | #17(monotonic assert)| bulk preview 數字來源 |

### Pinned constants(非 knob)

- **禁 ticking countdown**(F1 — Player Fantasy 裁決)
- **F3 comparator 鏈**(= #22 pinned — 同一 code)
- **毀滅永不代理**(EC-04 — MAKE_ROOM 零自動分解)

## Visual/Audio Requirements

> **= #22 Visual/Audio 全套文法延伸**(quiet ledger:particle = 0 pinned / L0-L3 tier 表 / 賬簿線 framing / amber+ink 雙色 / pure white 禁 / 禁 elastic·pulse·staggered pop-in / opaque ink base)— #23 唔重抄,divergence 如下:

| Event | 處理 | Tier |
|-------|------|------|
| Section / filter 切換 | snap-switch 80-120ms(= #22 tab)| L0-L1 |
| Bulk execute | list rebuild 一次過 final(**禁逐件 fade-out cascade** — 12 件連環動畫 = 慶祝化毀滅);shards snap;`ui_salvage_execute` **一響** | L1 |
| Claim 成功 | row 移去 INVENTORY(rebuild,唔做 fly-over 動畫);toast | L1 |
| Mailbox retention 行 / receipt glyph | `ui_text_dim` static;receipt glyph = 細印章形(squint test 同 lock 分得開)| L0 |
| MAKE_ROOM sheet | = picker bottom sheet 文法(slide-up + scrim)| L2 |
| Empty states(filter 0 件 / mailbox 空)| L0 static(= #22:dotted outline + dim label;「信箱空嘅」係好消息但唔慶祝)| L0 |

**Audio:零新 cue**(Dependencies 表裁決)— silent 名單延伸:filter chip 切換 / retention 行 render / MAKE_ROOM 開(用 ui_sheet_open)/ claim 成功(toast 承擔,唔加 settle 聲 — #23 冇 stat 面)。BGM 零 call(= #22)。

📌 **Asset Spec** — 隨 `/asset-spec system:inventory-ui`:receipt glyph sprite +「現役」badge chip;其餘全 reuse #22 assets(card 9-slice / badge accent / sheet bg / icons)。

## UI Requirements

### Layout 結構(360×560 min viewport,= #22)

- **Persistent**:header(title + shards counter verbatim + close X ≥48px)+ offline banner 位 + section tabs(INVENTORY / MAILBOX — MAILBOX tab 帶 count badge「(3)」)
- **Sub-header**(INVENTORY only):slot filter chips 一行(橫 scroll 如唔夠闊)+「批量分解」button
- **Content**:virtualized item card list(scroll container = #22 ux R4 同款)
- **Modal 軸**:ITEM_INSPECT / SALVAGE_CONFIRM / BULK_SELECT / BULK_CONFIRM / MAKE_ROOM(bottom sheets + center modal — 文法 = #22)
- 並發 messaging priority = #22 表同款(offline > toast > inline notes)

### Pattern 引用

P-06(rarity badge)/ P-13 three-zone-item-card 嘅 list 變體(#23 row = 主體 tap→inspect + 「領取」button[mailbox only];**冇** per-row lock toggle — lock 喺 inspect 內,list row 保持單一主操作)/ P-15 destructive-confirm-modal(SALVAGE_CONFIRM + BULK_CONFIRM)/ P-16 bottom-sheet(BULK_SELECT / MAKE_ROOM)。

### 實作要求

= #22 全套(touch ≥48px / 無 hover-only / 無 long-press / Zpix 12px floor + m6x11 數字 / ARIA via `platform_detect.announce_aria` / ESC routing modal-first / ADR-0001 budget + virtualized)。**ARIA 加項**:bulk execute → announce「已分解 [count] 件,+[shards] 碎片」;claim → announce toast 文字;section 切換 → announce section 名(coalesced)。

> **📌 UX Flag — Inventory UI**:Phase 4 入 epic 前必行 `/ux-design inventory-ui` 產 `design/ux/inventory-ui.md`;stories cite UX spec。Bulk flow 嘅兩層 sheet(SELECT → CONFIRM)係 wireframe 重點。

## Acceptance Criteria

> **33 ACs**:**29 BLOCKING**(3 Logic unit + 26 Integration)+ **3 ADVISORY**(manual)+ **1 RATIFICATION-GATED**。
> **Test seam = #22 AC header 全套 binding**(injected clock screen-wide / process_frame 禁 wait_frames / cfis 禁 .bind() / 真 #17 誘發禁 stub / negative assertion positive-control-先行 / golden vector binary-exact)。
> **G-IU-1 gated 標記**:AC-10/11/12/13/15 嘅 enumeration source 喺 getters 落地前跑唔到 — story 排序 G-IU-1 先行。
> **G-IU gates evidence**:各自喺 epic story 收口(G-IU-1 = #17-side unit tests;G-IU-2 = ADR diffs;G-IU-3/4 = doc diffs)。

### Group A — Logic(unit)

- **AC-01**:GIVEN mailbox 件 acquired 6月1日,WHEN F1,THEN「保留至 6月8日」(device local);GIVEN `has_receipt()`,THEN **無** retention 行 +「收據件唔會自動分解」note。Source: F1/EC-08 | Gate: BLOCKING | File: `tests/unit/inventory_ui/test_retention_date.gd`
- **AC-02**:GIVEN 混合 slot 件,WHEN filter chip 逐個,THEN 只列 `slot_affinity` match;0 件 → empty-state 照 render 唔 reset filter。Source: Rule 8/EC-09 | Gate: BLOCKING | File: `tests/unit/inventory_ui/test_inventory_filter.gd`
- **AC-03**:GIVEN #23 sort 路徑,WHEN introspect,THEN 用 `char_screen_formulas.picker_before` **同一 code**(唔 fork — grep/identity assert);真 fixture byte-identical。Source: Rule 7 | Gate: BLOCKING | File: 同上

### Group B — Lifecycle(Integration;FSM = #22 pattern,重驗 #23-specific)

- **AC-04**:GIVEN 全部 GSM states 逐個,WHEN `open()`/`can_open()`,THEN 只 IDLE/DISCONNECTED 准(double guard;唔 hardcode 數)。Source: Rule 1 | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_lifecycle.gd`
- **AC-05**:GIVEN BULK_CONFIRM 開緊,WHEN GSM→WORKOUT_ACTIVE,THEN modal cancel(bulk 永不執行)+ advance(FORCE_CLOSE_MAX_MS) 內 CLOSED + **零 play_sfx**。Source: Rule 3 | Gate: BLOCKING | File: 同上
- **AC-06**:GIVEN OPEN,WHEN SUSPENDED,THEN instant snap;resume 唔 auto-reopen。Source: Rule 3 | Gate: BLOCKING | File: 同上
- **AC-07**:GIVEN section=MAILBOX + filter=WEAPON + modal open,WHEN close→re-open,THEN 全 reset(INVENTORY/ALL/NONE)。Source: Rule 3 clean-slate | Gate: BLOCKING | File: 同上
- **AC-08**:GIVEN open,WHEN introspect subscriptions,THEN **只 GSM 一條**(cfis);#11/#26 零 connect(negative — 明文非依賴);3 close paths 後零 active。Source: Rule 6 | Gate: BLOCKING | File: 同上
- **AC-09**:GIVEN #22 OPEN,WHEN「查看全部 →」,THEN #22 normal close → #23 open sequential;GSM race 時 #23 double guard 拒 → 兩邊 CLOSED 無 limbo。Source: Rules 1-2/EC-11 | Gate: BLOCKING | File: 同上

### Group C — Browse(Integration;真 #17 + G-IU-1)

- **AC-10** *(G-IU-1 gated)*:GIVEN open 第一 frame,WHEN read,THEN all-inventory + mailbox + count + shards + loadout 齊(無 loading)。Source: Rule 5 | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_browse.gd`
- **AC-11** *(gated)*:GIVEN 真 #17 混合 fixture,WHEN render,THEN F3 排序 byte-identical;EQUIPPED 件照列 +「現役」badge。Source: Rules 7-8 | Gate: BLOCKING | File: 同上
- **AC-12** *(gated)*:GIVEN filter 切換,WHEN re-filter,THEN 本地 predicate(零 #17 re-read call);section 切返 → re-read(= #22 Rule 23)。Source: Rules 8/6 | Gate: BLOCKING | File: 同上
- **AC-13** *(gated)*:GIVEN 120 件 fixture,WHEN list render,THEN instantiated nodes < N(virtualized);bulk 後 rebuild scroll reset 頂。Source: Rule 9/EC-14 | Gate: BLOCKING | File: 同上

### Group D — Mailbox / claim(Integration;真 #17)

- **AC-15** *(gated)*:GIVEN mailbox 混合(普通 + receipt),WHEN render,THEN F3 sort + retention 行(普通)/ receipt note(receipt 件)+ MAILBOX tab count badge。Source: Rule 10/F1 | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_mailbox.gd`
- **AC-16**:GIVEN claim ok,WHEN #17 auto-equip 上身/唔上身,THEN toast「已領取並裝上」/「已領取」分支 + re-read;**零 lock nudge**(EC-05)。Source: Rule 11 | Gate: BLOCKING | File: 同上
- **AC-17**:GIVEN inventory full,WHEN claim,THEN `shortfall` → MAKE_ROOM sheet(「要騰 N 個位」)+ **零自動分解 call**;騰位後 re-claim ok。Source: Rule 11/EC-04 | Gate: BLOCKING | File: 同上
- **AC-18**:GIVEN mailbox 件 inspect,WHEN render,THEN equip/salvage disabled +「先領取」;stale race → `in_mailbox_claim_first`/`not_found` → toast + re-read。Source: Rule 12/EC-06/07 | Gate: BLOCKING | File: 同上

### Group E — Bulk(Integration;真 #17)

- **AC-19**:GIVEN 5 rarity 混合 fixture,WHEN BULK_SELECT 開,THEN 每 row = `bulk_salvage_preview` 真值;0 件 row 照 tap → inline note(唔 disable)。Source: Rule 15/EC-02 | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_bulk.gd`
- **AC-20**:GIVEN receipt_count>0(unlocked receipt 件),WHEN BULK_CONFIRM,THEN itemised 列名(cap `BULK_CONFIRM_RECEIPT_LIST_MAX` +「+N more」總數照報)+「包括信箱 + 現役」文案 + cancel button + scrim=cancel + focus=cancel。Source: Rules 16/18 | Gate: BLOCKING | File: 同上
- **AC-21**:GIVEN confirm,WHEN `bulk_salvage`,THEN toast 報 **execute return**(count/shards)+ `ui_salvage_execute` 恰好 **1** 響 + re-read;locked 件全存活。Source: Rules 16-17 | Gate: BLOCKING | File: 同上
- **AC-22**:GIVEN preview 後 execute 前外部 mutation(claim/salvage 一件),WHEN confirm,THEN execute 用當下真值,toast ≠ preview 數 — 無 crash 無 assert。Source: EC-01 | Gate: BLOCKING | File: 同上
- **AC-23**:GIVEN equipped unlocked 件喺 bulk range,WHEN execute,THEN #17 auto-unequip + backfill → re-read 反映(slot 變化 = #22 EC-13 兩 outcome 口徑)。Source: Rule 18 | Gate: BLOCKING | File: 同上
- **AC-24**:GIVEN BULK_CONFIRM 開,WHEN ESC,THEN 退返 BULK_SELECT(逐層);再 ESC → NONE;再 ESC → close screen。Source: States 表 | Gate: BLOCKING | File: 同上

### Group F — 單件 ops(Integration;真 #17;= #22 pattern 重驗)

- **AC-25**:GIVEN inventory 件 inspect,WHEN「裝備」,THEN `equip(id, slot_affinity)` + lock nudge unconditional(= #22 Rule 18 全套:inline [鎖定] tap → set_lock + 確認態);cosmetic 同款零 stat 面。Source: Rule 13 | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_commands.gd`
- **AC-26**:GIVEN 5 error codes + deferred_reentrancy(真 #17 誘發),WHEN 處理,THEN = #22 Rule 15 行為(toast / 唔 toast 下 frame 收割)。Source: Rule 14 | Gate: BLOCKING | File: 同上
- **AC-27**:GIVEN DISCONNECTED + OPEN,WHEN claim/bulk/equip/lock/salvage 逐個,THEN 同 IDLE 一致,唯一 delta = banner。Source: EC-13 | Gate: BLOCKING | File: 同上

### Group G — ARIA + audio(Integration)

- **AC-28**:GIVEN bulk execute / claim / section 切換,WHEN 處理,THEN announce「已分解 [N] 件,+[M] 碎片」/ toast 文字 / section 名(coalesced);positive control 先行。Source: UI Requirements | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_aria.gd`
- **AC-29**:GIVEN 完整操作 walkthrough,WHEN 收集 play_sfx calls,THEN 全部 ∈ reuse 名單(零新 cue;silent 名單延伸零 call)。Source: Dependencies #4 row | Gate: BLOCKING | File: 同上

### Group H — Manual(ADVISORY)+ GATED

- **AC-30**:長 CJK provenance + receipt 名單 walkthrough 截圖(wrap/ellipsis/12px floor)。Gate: ADVISORY | File: `production/qa/evidence/inventory-ui/`
- **AC-31**:真 SR walkthrough(claim/bulk/section announces 可聽)+ 真機 touch ≥48px。Gate: ADVISORY | File: 同上
- **AC-32**:Visual 名單 walkthrough(零 cascade 動畫/零 countdown/greyscale pass)。Gate: ADVISORY | File: 同上
- **AC-33** *[ADR-0001 RATIFICATION-GATED]*:mobile 真機 120 件 list scroll + bulk rebuild ≤ UI CPU 2ms。File: `tests/performance/inventory_ui/`

## Open Questions

| ID | Question | Owner | Target |
|----|----------|-------|--------|
| **Q-IU1** | 入口 affordance + #22↔#23 互斥嘅 shell 接線(= #22 Q-CS1 同一命題;「查看全部 →」link 係 #23 自己嘅,shell 入口係 #24 嘅)| #24 GDD | #24 authoring |
| **Q-IU2** | Mailbox「未開封」ritual recovery(#21 OQ-6)— 需 GSM erratum + content-source 分支;MVP 首次見面永遠喺 #21 | #21/#23 v0.2 | v0.2 |
| **Q-IU3** | User-selectable sort axes + search(MVP 固定 F3;120 件實測唔夠用先加)| #23 v0.2 | v0.2(soak 後)|
| **Q-IU4** | Mailbox hard-cap(180)FIFO evict 預警 UI(#17 機器;quiet ledger 點講「就嚟逼爆」而唔加壓力?)| #23 v0.2 | v0.2 |
| **Q-IU5** | `SfxCatalog` reuse 行 #23 來源 column(G-IU-3 隨 epic 執行)| epic | epic 期間 |
