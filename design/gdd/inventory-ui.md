# Inventory UI (#23)

> **Status**: ✅ **Approved 2026-06-07**(同日全 pipeline:Pass 1 full 7-specialist + CD = NEEDS REVISION [13 BLOCKING + D1-D8] → consolidated fix pass → 3-verifier re-pass [godot PASS 0-phantom;qa-lead + ux-designer converge 1 FAIL = salvage×IN_MAILBOX phantom sibling → 同 session 修] → CD final sign-off APPROVED,0 phantom)
> **Author**: frank + design-system pipeline(degraded inline 2026-06-07;fix pass 2026-06-07)
> **Last Updated**: 2026-06-07
> **Implements Pillar**: Pillar 1(provenance 收據庫)· 支援 Pillar 3(loot 整理 — 唔搶 #21 ceremony)
> **核心裁決**:獨立 full-screen surface(#22 pattern 全套 cite,divergence-only 寫法)/ CanvasLayer 61(G-IU-2)/ bulk per-rarity + shipped `bulk_salvage_preview`(G-IU-1 擴 `receipt_ids`)+ 三層誠實度(D5)/ mailbox static「保留至 [date]」**禁倒數**(F1 −1 day 最後完整保證日,D3)/ claim shortfall → MAKE_ROOM 零代理分解(D4 雙入口 + transient claim-target)/ INVENTORY sort = #22 F3 同一 code;MAILBOX = **F2-M acquired asc**(D8)/ shards 顯示 = **thousands separators 全 game 統一**(D6,G-IU-5)/ **零新 SFX cue**(event→cue map 表)/ FSM **fork now**(extraction ADR 留 #24)/ #23 零 persist 零 #11/#26 訂閱

<!-- DESIGN CONTEXT(2026-06-07 pre-load — #22 authoring session 已 grep-verify 晒,fresh session 唔使重 grep)

## 上游 contracts(BINDING — 全部 shipped/approved)

### #17 InventorySystem(shipped — src/autoload/inventory_system.gd;line cites re-verified 2026-06-07 fix pass)
- Commands(synchronous Dictionary return {"ok": bool, "error": String}):`salvage(item_id)` L548(locked → {"error":"locked"})/ `bulk_salvage(rarity)` L585(every UNLOCKED item of rarity;mailbox+inventory+equipped 全 in range,equipped unlock-state 件 batch 內 auto-unequip;return `{ok, count, shards}` L617)/ `claim(item_id)` L709(mailbox → inventory;**inventory full 時 blocked** — claim-when-full flow 係 #23 嘅 UX 命題,#17 GDD L359 UX flag 指明)/ `equip`/`unequip`/`set_lock`(同 #22)
- Error codes ground truth(**7 個,唔係 #22 嘅 5+1**):not_found / in_mailbox_claim_first / slot_type_mismatch / slot_empty / locked / **`not_in_mailbox`(claim 專屬 — L711-712,item==null 或非 IN_MAILBOX 都係呢個,claim 永不回 not_found)** / deferred_reentrancy(下 frame 自動重放 — 唔好 toast,#22 Rule 15 先例)。**claim 嘅 shortfall return `{ok:false, shortfall:N}` 冇 error key**(L715)— dispatch 順序見 Rule 11
- **Lock × salvage path 真值表**:lock 免疫 manual salvage(L555)+ bulk_salvage(L593);**TTL sweep(L942-949)同 hard-cap FIFO evict(L988+)只豁免 `has_receipt()`,唔理 `is_locked`** — locked 非-receipt mailbox 件照被 sweep。`set_lock`(L692-698)冇 lifecycle check — IN_MAILBOX 件 lock 有效(Rule 12 honest copy 依此)
- **TTL sweep grace path(L939-940)**:offline 或 server-clock drift → 成個 sweep skip(`_server_clock_sane` false)— **過期 non-receipt 件喺 DISCONNECTED 下可見**(F1 / EC-15 處理);過期唔係毀滅 — `_auto_salvage`(L915-919)「value never evaporates (A3): shards credited」
- Reads:`get_item(item_id) -> EquipmentItem` / `get_inventory_count()`(L1128 — **IN_INVENTORY + EQUIPPED**,120 cap 包現役)/ `get_forge_shards()`(L1138 doc comment:「#23 display contract: thousands separators」)/ static `salvage_yield(rarity)`(COMMON 100 → LEGENDARY 800)
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

#23 **唔 own 任何 game data**(#22 Rule 2 同款 pure overlay):全部經 #17 commands + getters;唯一新接口 = **G-IU-1 additive 擴充**(`get_all_inventory_items`[IN_INVENTORY + EQUIPPED — 同 `get_inventory_count` L1128 cap 口徑一致] + `get_mailbox_items` + `bulk_salvage_preview` 加 `receipt_ids` key — G-CS-1 先例)。Lifecycle / 訂閱 / force-close / injected clock 紀律**全套 cite #22**(Rules 1-8 pattern reuse — 唔重抄,divergence 先寫;FSM code 層面 = fork,見 States)。實作受 ADR-0001(CanvasLayer 61 — G-IU-2 revision)、ADR-0008(insertion — G-IU-2)、ADR-0003 約束。

玩家影響:#22 答「我而家係邊個」,#23 答「**我儲低咗啲乜**」— Pillar 1 嘅收據庫。冇 #23,mailbox 係黑箱(claim-when-full 冇 UX)、bulk 整理冇入口、120 件上限變成無形牆 —「拆牆」由 **INVENTORY header「[count]/120」常駐 readout**(Rule 5)兌現,唔係等 claim 碰壁先見到。

## Player Fantasy

> **Framing**:「**執倉**」— 收據庫嘅管理員時刻。#22 係門框(回望刻度),#23 係**儲物房**:你打開個櫃,一格格全部係有日期嘅收據。執倉嘅滿足感係 Maintenance 型(唔係 Achievement 型)— 分解一批 COMMON、鎖好件有故事嘅 LEGENDARY、領埋 mailbox 嗰幾件 — 操作完,間倉「整齊咗」。

- **聲線**:quiet ledger 延伸(#22 同款:數字+日期做主語、零 hype、禁 progress-bar 語言)。倉房比門框**操作性重** — 但操作嘅語言係 bookkeeping(「已分解 12 件 — +1,400 碎片」),唔係戰利品慶祝(dopamine 全部留 #21)。
- **Mailbox 張力裁決**:TTL 7 日 auto-salvage 係事實,但**唔做倒數計時器**(ticking countdown = 壓力 UI — Pillar 2「無壓力陪伴」精神嘅 IDLE-surface 延伸:唔製造焦慮、唔催促;paraphrase,game-concept 無此 verbatim 句)— 顯示 static「**保留至 [date]**」(device local,#22 EC-15 同款;date = **最後完整保證日**,F1 D3)。事實照講,情緒唔加。**明文承認張力**:TTL auto-salvage 本身同「唔拎走玩家已得嘅嘢」精神有張力 — mitigation 係 A3 雙保險:(a) receipt 件(Pillar 1 真正在乎嘅)永不 silent expire;(b) 過期唔係蒸發 — `_auto_salvage` shards 照入賬(L915-919「value never evaporates」)。#23 嘅禁倒數係 mitigation,唔係 resolution(Q-IU4 v0.2 再議)。
- **Bulk-salvage 嘅誠實度(D5 三層)**:批量毀滅要兩步 + 後果分層 itemised — receipt 件逐件列名;equipped / mailbox 件 **conditional count breakdown**(有先出,零中招時唔出 — static copy 喺冇人中招時係 noise,warning fatigue 磨蝕真 warning);MAKE_ROOM context 下 claim-target named warning(EC-04)。Lock 係 bulk 唯一硬保護(**對 TTL sweep 唔係** — Rule 12 honest copy),warning 係誠實防線。
- **Mailbox 排序裁決(D8)**:MAILBOX section 用 **acquired asc**(F2-M)— TTL 食最舊,FIFO expiry queue 用 FIFO 順序先係誠實 information architecture;「唔催促」係語氣裁決,唔係資訊埋藏。
- **Design test**(#22 同款延伸):任何 #23 micro-copy 問「呢句係咪倉房管理員嘅記帳語言?」— 係催促、係倒數、係慶祝,就唔屬於呢度。

**Pillar 對齊**:Pillar 1 primary(provenance 收據庫 — 每件嘅日期同來歷喺度先睇得晒)· 支援 Pillar 3(loot 整理後勤 — 唔搶 #21 ceremony,首次見面永遠喺 #21)。

## Detailed Design

> **Pattern reuse 宣言(本 GDD 嘅 ground rule)**:#23 嘅 lifecycle / 訂閱 / 命令 / 誠實度紀律**全套繼承 #22**(character-screen.md,APPROVED 2026-06-07)。下面用「**= #22 Rule N**」標明 cite;只有 **divergence** 先至全文寫。Implementer 讀本 section 要同 #22 GDD 並讀。

### Core Rules

**A. 入口 / lifecycle(= #22 Rules 1-6,divergence 如下)**

1. **入口條件 = #22 Rule 1 同款**:GSM ∈ {IDLE, DISCONNECTED} whitelist;入口 affordance 由 host shell own(provisional — Q-IU1);`can_open()` + `open()` double guard;**明文拒用 #33 `is_input_permitted()`**(同款語意分離)。**新增:#22 LOADOUT tab 嘅「查看全部 →」link 係第二入口**(#22 Rule 17 邊界嘅另一面)— tap → close #22(normal close path)→ open #23(sequential)。**Link path 雙 cue 政策**:#22 close 響 `ui_charscreen_close` + #23 open 響 `ui_charscreen_open` back-to-back — **接受**(sequential 切換嘅誠實聲;chaining craft constraint 隨 G-IU-3 傳俾 sound-designer)。
2. **同 #22 互斥(語意收窄)**:#22 同 #23 永不同時 ∈ {OPENING, OPEN}(都係 full-screen 全 attention surface);**CLOSING × OPENING animation 並存容許**(≤CLOSE_ANIM_MS;layer 61 > 60 — incoming 蓋 outgoing,visual 收得住)。**MVP glue locus(G-IU-4)**:#22 link handler `close()` 後同 gesture 內 `call_deferred` call `/root/InventoryUICoordinator.open()`(untyped seam + `has_method` guard)—「唔互相依賴」收窄為「唔 subscribe、唔讀對方 state」,one-shot deferred call 容許;#24 shell 落地後遷移(Q-IU1)。#23 `open()` 唔 re-check #22 state — 各自 double guard,夾埋 safe(EC-11)。
3. **Force-close / SUSPENDED / IDLE↔DISCONNECTED / close 手勢 / clean-slate reset = #22 Rules 3-5 全套**(FORCE_CLOSING ≤150ms 零 SFX CD C1 / snap 零 SFX / banner toggle 唔 close / 每次 open reset `active_section=INVENTORY`、`modal=NONE`、filter reset ALL、**make-room pending state 清空**)。Destructive modal(SALVAGE_CONFIRM / BULK_CONFIRM)+ MAKE_ROOM force-close 一律 cancel(= #22 EC-01)。
4. **Close 唔 cancel #17 writes = #22 Rule 6**。

**B. Browse(enumeration + filter + sort)**

5. **Open 第一 frame sync read 齊(= #22 Rule 7)**:G-IU-1 `get_all_inventory_items()`(**IN_INVENTORY + EQUIPPED** — getter 口徑 = `get_inventory_count()` L1128 cap 口徑,Rule 8「倉房口徑」由 getter 直接兌現,#23 **唔做** loadout merge)+ `get_mailbox_items()`(IN_MAILBOX)+ `get_inventory_count()` + `get_forge_shards()` + `get_loadout()`(G-CS-1 — 只用嚟標「現役」badge:`loadout.values()` build set,row O(1) lookup)。冇 loading state。**Read 後即 build snapshot view models**(#22 `_loadout_view` 先例)— render 層唔持有 live `EquipmentItem` reference。**INVENTORY section header 常駐 render「[count]/120」**(verbatim,禁 progress bar 禁變色 — ledger 事實;count 含現役,#17 L1125 口徑,免「我得 116 件點解話滿」困惑)。
6. **訂閱(= #22 Rule 8 pattern)**:GSM `state_changed` 經 cfis;**#11/#26 唔訂**(#23 冇 stat/avatar 面 — 比 #22 少兩條);CLOSED 零-subscription invariant 同款;command-then-re-read + section visibility re-read(= #22 Rules 14/23)。**Re-read 範圍統一 = Rule 5 全套**(五個 read 全重讀 + view model rebuild — 唔做 targeted re-read;AC-33 2ms budget 負責驗可行性)。
7. **Sort 分 section**:INVENTORY = **#22 F3 comparator 同一 code**(`char_screen_formulas.picker_before`:rarity desc → acquired desc → item_id asc;referenced,唔 fork — AC-03 identity assert);MAILBOX = **F2-M**(#23-owned:acquired **asc** → item_id asc — FIFO expiry queue 用 FIFO 順序,D8;見 Formulas)。MVP **冇** user-selectable sort axes(收據庫唔係 spreadsheet;v0.2 Q-IU3)。
8. **Filter:slot chips**(ALL / WEAPON / ARMOR / ACCESSORY / COSMETIC)— 單選;**2 字 CJK labels(全部/武器/護甲/飾品/外觀),5 chips 一行排晒 360px,MVP 唔 scroll**(剷走 nested-scroll 手勢衝突類);filter 只係 view predicate(`item.slot_affinity == chip`),唔改 sort;切 chip = 即時 re-filter(本地,唔 re-read)。EQUIPPED 件**照列**(badge「現役」)— 倉房口徑 = 你擁有嘅全部(Rule 5 getter 直接兌現)。
9. **List 係 virtualized — spec**:component = **#23 自建 minimal virtualized controller**(`src/ui/inventory_ui/` 內;ScrollContainer + fixed-height row pool + scroll-offset→index 數學;設計成 #24 可 reuse — project 零先例 code,#22 Rule 17 係 requirement 唔係 component);**row 高度 uniform fixed**(retention 行 / receipt note 喺 fixed card 內預留位,唔改 card 高;**list row provenance 單行 ellipsis** — 全文只喺 ITEM_INSPECT);INVENTORY / MAILBOX 兩 section 共用 component class、各自 instance;instantiated row nodes ≤ `ceil(viewport_h / ROW_HEIGHT_PX) + 2 × POOL_BUFFER_ROWS`(knob)。Row = P-06 item card pattern(name + rarity badge + provenance + locked / 現役 / mailbox 標記)。**Rebuild scroll 規則(雙軌)**:單件 mutation(claim / 單件 salvage / equip / lock)rebuild **保留 scroll offset(clamped)** — 內容 99% 冇變,reset 先係假不連續;bulk execute rebuild **reset 去頂**(內容根本唔同,EC-14)。

**C. Mailbox + claim**

10. **MAILBOX section**(`active_section` 軸第二格):列 IN_MAILBOX 件(**F2-M sort:acquired asc** — D8,就嚟過期排最頂);每 row 加 static「**保留至 [date]**」(**F1** retention date;device local;date = 最後完整保證日 D3;**禁倒數 ticking** — Player Fantasy 裁決;**過期日期照 render 唔改寫** — D2,賬簿唔改寫事實,EC-15)。Receipt 件(`has_receipt()`)加 receipt glyph + **唔 render retention 行**(F1:佢哋唔會被 sweep,顯示限期 = 講大話)+ note「收據件唔會自動分解」(#17 A3)。**MAILBOX tab count badge 文法**:tab label 內 dim ink 純文字「(3)」(`ui_text_dim` 級)— 禁色 pill / 禁紅 / 禁 dot / 禁 pulse;0 件唔 render「(0)」;ARIA tab 名連 count 讀。
11. **Claim flow + return dispatch(pin)**:row「領取」button → `claim(item_id)`(#17 L709)。**Return 處理順序(binding)**:① `ok == true` → success 分支;② `shortfall > 0` → MAKE_ROOM(**呢個 return 冇 error key — L715,唔行 error path**);③ 其餘 → Rule 14 error path。Success 分支:re-read(Rule 6 全套)→ 判定 `get_item(claimed_id).lifecycle_state == EQUIPPED`(claim 觸發 #17 auto-equip 評估 L721)→ toast「已領取並裝上」/「已領取」。**MAKE_ROOM(D4)**:sheet「倉滿 — 要騰 1 個位」(shortfall verbatim render;#17 invariant 下 N≡1 — count ≤ 120 恆成立,L715 公式只產 1;中文無複數,copy 零問題)+ **兩個入口**:(a)「批量分解」→ `modal := BULK_SELECT`(兌現 #17 L706-707 doc comment 嘅 bulk-salvage shortcut 期望;BULK 自帶兩步 confirm — 「毀滅永不代理」禁嘅係 system 揀邊件死,唔禁路標);(b)「自行整理」→ `modal := NONE` + `active_section := INVENTORY`(= Rule 23 visibility re-read)。**Claim target 以 coordinator transient state 保留**(`make_room_pending: item_id`;零 persist;close / force-close / claim 成功 / `not_in_mailbox` 一律清空)— 騰夠位(re-read 後 count < 120)時 INVENTORY section 頂 render inline hint strip「已騰出空位 — [領取「name」]」(P-14 文法;one-tap claim;有 dismiss X)。**唔提供「自動幫你分解最平嗰件」**(毀滅永不代理)。
12. **Mailbox 件嘅單件操作 + lock(D1)**:IN_MAILBOX 件 tap → ITEM_INSPECT 照開(provenance 睇得);equip / salvage 入口 **disabled +「先領取」hint**。**兩個 command 嘅防線深度唔同(ground truth)**:`equip` 有 code-side guard(`in_mailbox_claim_first` L658-659 — stale race 兜底);**`salvage` 冇 IN_MAILBOX guard(L548-556 只查 null/SALVAGED/locked)— unlocked mailbox 件 dispatch 落去會照執行毀件**(同 bulk-includes-mailbox 語意一致),所以 **disabled 入口係 #23 唯一防線,「#23 對 IN_MAILBOX 件零 `salvage` dispatch」係 binding UI invariant**(AC-18 negative assert;唔開 #17-side guard story — 零 upstream churn,consumer forward contract);**lock toggle enabled**(`set_lock` L692-698 冇 lifecycle check — 有效)+ **honest copy**:「鎖定 — 批量分解唔會掂佢;保留期照計」(ground truth:TTL sweep L942-949 唔理 `is_locked` — lock 對 mailbox 件擋 bulk 唔擋 sweep,文案照直講;receipt 件 lock 後 = 真・全保護[sweep 免疫 receipt + bulk 免疫 lock + evict 免疫 receipt 三層齊])。**Rescue window(positive)**:過期但未被 sweep 嘅件(grace / mid-session 過界,EC-15)「領取」button **照 enabled** — `claim()` 零 TTL check(L709-724),claim 成功 = 救返件嘢;唔好「好心」disable。

**D. 單件操作(= #22 Rules 19-22 全套 cite)**

13. **ITEM_INSPECT** = #22 Rule 22 同款 view(provenance 全文 + LEGENDARY signature + stat_modifiers 原始數據 — 禁 predicted final);**affordance set 按 lifecycle 分**:(a)IN_INVENTORY 件 —「裝備」button → `equip(item_id, item.slot_affinity)`(cosmetic 同款;成功 → toast + 現役 badge 更新 + **lock nudge unconditional,render locus = ITEM_INSPECT sheet 內 inline 一行**[#22 Rule 18 嘅 one-tap rationale 同款兌現 — #23 冇 loadout card,nudge 唔跟去 list,inspect 閂咗即棄]);(b)**EQUIPPED 件 —「裝備」button 唔 render(self-equip 無意義),改 render「現役」標記 +「卸下」button → `unequip(item.slot_affinity)`**(倉房口徑包括「擺返件衫入櫃」;#17 L1125 cap 計 IN_INVENTORY+EQUIPPED — unequip 永不爆 cap,零新 edge;error 行 Rule 14,`slot_empty` 係 stale 防線);(c)IN_MAILBOX 件 — 見 Rule 12。Salvage 入口 = #22 Rule 19 兩步 + locked 灰掉(Rule 20);lock toggle 同款。**Salvage confirm 成功 → SALVAGE_CONFIRM + ITEM_INSPECT 一齊閂**(`modal := NONE`)→ 返 list + toast(件已毀,inspect 對住唔存在嘅嘢係 limbo)。
14. **Command error handling = #22 Rule 15 pattern,error 表擴至 #23 command set**:**6 error codes** → re-read + toast — `not_found` / `in_mailbox_claim_first` / `slot_type_mismatch` / `slot_empty` / `locked`(#22 5 個)+ **`not_in_mailbox`(claim 專屬 — L711-712;toast「件物品已唔喺信箱(可能已自動分解)」+ section re-read)**;`deferred_reentrancy` 例外唔 toast 下 frame 收割(= #22);toast = ARIA live region。**Dispatch order = Rule 11 ① ② ③**(claim 嘅 shortfall return 冇 error key — 必須 shortfall-first)。**#22 toast map 唔可以照搬** — 加 `not_in_mailbox` entry,免 raw error code leak。

**E. Bulk-salvage(per-rarity)**

15. **入口 + preview 時點(pin)**:INVENTORY section header「批量分解」button(或 MAKE_ROOM 入口 (a))→ `BULK_SELECT` sheet:5 個 rarity row,每 row 顯示 `bulk_salvage_preview(rarity)` 結果(「COMMON — 12 件 → 1,200 碎片」)。**Preview 時點規則**:sheet 每次 enter(開 / 由 CONFIRM 退返)重行全 5 row preview;**row tap 再 re-preview 一次**,用 tap-time 數開 CONFIRM(preview 係 free synchronous read,冇理由用舊快照);0 件 row 灰掉唔 disable tap — tap 同樣 re-check,仍 0 → inline note「呢個 tier 冇可分解嘅件」(>0 就照開 CONFIRM)= #22 EC-20 mystery-meat 原則。
16. **確認(兩步 friction 加重版 + D5 三層誠實度)**:rarity row tap → `BULK_CONFIRM` modal,**結構 pin(360×560 排得落嘅唯一解)**:fixed header(count + yield + receipt 總數行「內含 [R] 件收據件」— 決策資訊必須 above-the-fold)+ **scrollable 中段**(itemised 明細)+ fixed footer(cancel + confirm 永遠 on-screen)。中段三層:①**receipt 件逐件列 name + provenance**(data source = `bulk_salvage_preview().receipt_ids` → `get_item()` — G-IU-1 擴充,誠實名單同毀滅名單同源,#23 零 predicate duplicate;cap `BULK_CONFIRM_RECEIPT_LIST_MAX` +「+N more」總數照報)+「呢 [R] 件帶收據,分解後簽名永久消失」;②**conditional count breakdown**:「內含信箱 [M] 件、現役 [K] 件」(M/K 由 #23 view model 對 preview 範圍本地點算 — view 層 count,唔係 selection predicate;**有先 render,零中招唔出** — static copy 喺冇人中招時係 noise);③**MAKE_ROOM context warning**:`make_room_pending` 件 rarity match 且 unlocked ⇒ 第一行 named warning「⚠ 包括你想領取嗰件「[name]」」(claim-target destruction trap 封口)。Modal affordances:cancel button + scrim=cancel + default focus=cancel(= #22 Rule 19);**cancel / scrim / ESC 三者等效,一律退返 BULK_SELECT**。Confirm → `bulk_salvage(rarity)` → **`modal := NONE`**(= #22 confirm_salvage 先例;連環 bulk 由玩家重開,sheet re-enter 自然攞新 preview)→ re-read + toast「已分解 [count] 件 — +[shards] 碎片」+ `ui_salvage_execute` **一響**(唔 per 件 — transaction stamp,#17 single transaction)。
17. **Preview→execute 之間嘅 drift**:confirm modal 顯示嘅數字係 row-tap 時點;execute 用 #17 當下真值(return `{count, shards}` L617)— toast 報 **execute 結果**,唔報 preview 數(兩者可以唔同 — EC-01 處理,唔係 bug)。
18. **Bulk range 口徑**:#17 `bulk_salvage` range 係**全部 unlocked 同 rarity 件(mailbox + inventory + equipped)**(L591-597 ground truth)— Rule 16 ② 嘅 conditional breakdown 係呢個 range 嘅 UI 兌現;equipped 件被食 → #17 內部 auto-unequip + backfill(= #22 EC-13 同款兩 outcome,#23 re-read 自然反映)。

### States and Transitions

**FSM = #22 五態全套**(CLOSED / OPENING / OPEN / CLOSING / FORCE_CLOSING — 行為、timing knob、GSM 監聽、CLOSING 照聽 GSM、ghost-callv guard 全部 = #22 States 表;#23 唔重抄 spec)。**Code reuse 機制(CD 裁決,binding)**:**fork** — #23 coordinator 自己 inline FSM(~150-200 行),header comment cross-ref #22 + 兩邊 divergence 要同步;**唔 extract base/component**(rule of three — #24 Shell 係潛在第三 consumer,extraction ADR 喺 #24 authoring 時開,見 Dependencies 注記)。行為等價由兩邊 AC contract-pin(Group B 係 mechanism-agnostic 驗收)。

**OPEN 內 orthogonal 軸(#23 自己)**:

| 軸 | 值 | 備註 |
|----|----|------|
| `active_section` | `INVENTORY`(default)/ `MAILBOX` | section 切換 = visibility re-read(= #22 Rule 23)|
| `slot_filter` | `ALL`(default)/ WEAPON / ARMOR / ACCESSORY / COSMETIC | view predicate only;open reset ALL |
| `modal` | `NONE` / `ITEM_INSPECT` / `SALVAGE_CONFIRM` / `BULK_SELECT` / `BULK_CONFIRM` / `MAKE_ROOM` | 單值軸(唔係 stack);force-close 一律 cancel;**modal ≠ NONE ⇒ section tabs 被 scrim 封鎖**(MAKE_ROOM 嘅「自行整理」入口係唯一例外路徑 — 佢本身 set modal=NONE)|
| `make_room_pending` | `&""` / item_id | transient(Rule 11);open reset / close / force-close / claim 成功 / `not_in_mailbox` / **MAKE_ROOM dismiss(= 放棄)** 一律清空;零 persist |

**Per-modal dismiss return-target(pin — cancel button / scrim / ESC 三者等效)**:

| Modal | 開自 | Dismiss → | 備註 |
|-------|------|-----------|------|
| ITEM_INSPECT | list row 主體 tap | `NONE` | |
| SALVAGE_CONFIRM | ITEM_INSPECT salvage 入口 | **`ITEM_INSPECT`**(逐層退) | confirm 成功 → 兩層一齊閂 `NONE`(Rule 13)|
| BULK_SELECT | header「批量分解」/ MAKE_ROOM (a) | `NONE` | re-enter 重行 preview(Rule 15)|
| BULK_CONFIRM | BULK_SELECT row tap | **`BULK_SELECT`**(逐層退) | confirm 成功 → `NONE`(Rule 16)|
| MAKE_ROOM | claim shortfall | `NONE`(= 放棄,claim button 唔 disable 可重試) | 入口 (a) → BULK_SELECT;入口 (b) → `NONE` + section 切換 |

ESC routing 大原則 = #22 EC-07(modal 先 screen 後)— modal=NONE 時 ESC 先 close screen。

### Interactions with Other Systems

| System | 方向 | 性質 | Interface |
|--------|------|------|-----------|
| **#17 Equipment & Inventory** | IN(read)+ OUT(command)| Hard | commands:`claim`(dispatch order Rule 11)/ `equip` / `unequip`(Rule 13 (b)「卸下」)/ `set_lock`(含 IN_MAILBOX 件 — Rule 12)/ `salvage` / `bulk_salvage`;reads:`get_item` / `get_inventory_count` / `get_forge_shards` / `get_loadout`(G-CS-1 — badge set only)/ static `salvage_yield` / `bulk_salvage_preview`(shipped)+ **G-IU-1 additive 擴充**(`get_all_inventory_items()`[IN_INVENTORY+EQUIPPED] + `get_mailbox_items()` + preview `receipt_ids` key — code 未有)|
| **#1 GSM** | IN(read + subscribe)| Hard | = #22 同款(cfis + force-close + call_deferred)|
| **#22 Character Screen** | 邊界 + 入口 | Soft | #22 LOADOUT「查看全部 →」→ sequential 切換(Rule 1-2;glue locus = #22 link handler `call_deferred` one-shot — 唔 subscribe 唔讀 state);pattern 共用(inspect / salvage / lock / P-06 / formatter-epsilon)+ F3 同一 code(preload `char_screen_formulas.gd` — **唔搬家唔 rename**,cross-dir 依賴接受);FSM = spec cite + code fork(States)|
| **#21 Loot Modal** | 邊界 | Soft | 首次見面永遠喺 #21;mailbox「未開封」reveal = v0.2 OQ-6(Q-IU2)|
| **#4 AudioManager** | OUT(`play_sfx`)| Hard | **零新 cue** — event→cue map 表喺 Visual/Audio section(usage mapping 係 binding,唔係淨係 reuse 名單);#22 open/close cue **裁:reuse `ui_charscreen_open/close`**(同一 ledger 聲線家族;cue 係質感唔係 screen ID — 名係 historical,family 語意隨 G-IU-3 收口)— 零 catalog 新行,備註 errata 隨 G-IU-3 |
| **#3 PersistenceLayer** | (none MVP)| — | #23 零 persist(filter/section 唔 sticky — clean-slate reset;**冇 #23-owned keys,連 namespace 都唔開**;negative AC-37)|
| **#26 / #11** | (none)| — | #23 冇 avatar/stat 面 — 明文唔訂 |

## Formulas

> #23 係 thin browse surface —「**唔需要 formula**」清單先行(#22 同款誠實地薄原則):

| 候選 | 裁決 | 理由 |
|------|------|------|
| Bulk yield preview | **Rule(Rule 15)** | 直接 render #17 `bulk_salvage_preview(rarity)` return(`{count, yield, receipt_count}` — shipped L622-634;**G-IU-1 擴 `receipt_ids: Array[StringName]` additive key** — itemised 名單同毀滅名單同源)— #23 自己重砌 selection predicate = duplicate ban 違規 |
| Claim shortfall | Rule(Rule 11)| `claim()` return `shortfall` verbatim(#17 L715;invariant 下恆等 1)|
| INVENTORY sort | Referenced | = #22 F3(char_screen_formulas.gd `picker_before` — 同一 code,唔 fork;AC-03 identity assert)|
| MAILBOX sort | **F2-M(#23-owned)** | D8 裁決 — FIFO expiry 順序,見下 |
| Slot filter | Rule(Rule 8)| 單一 equality predicate,冇數學 |
| Shards 顯示 | **Rule(D6 裁決)** | **thousands separators**(「1,400」)— #17 L1138 shipped contract +「禁 K/M lossy abbreviation」嘅原意保留(千位逗號係 lossless,真賬簿文法);**全 game 統一 shared formatter — G-IU-5**(#22 header counter `str()` 係 sibling drift,#22-side 一行對齊 + #17 L1138 comment erratum 擴「#22/#23 shared contract」)|

### F1 — Mailbox retention date

The `retention_date` formula is defined as:

`retention_date = date_local(acquired_at_unix + OVERFLOW_MAILBOX_TTL_DAYS × 86400 − 86400)`

**最後完整保證日(D3)**:sweep 條件係 `now − acquired > ttl_sec`(L948)— 件喺「acquired 時刻 + 7 日」嗰一刻起可被食,唔係嗰日完。直接顯示第 8 日 = 該日大部分時間件可以已消失(over-promise)。**−86400(−1 day)= 顯示最後一個完整保證日** — 承諾必兌現,date-only(附時刻 = 半個 countdown,焦慮文法)。

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| 入箱時間 | `acquired_at_unix` | int | unix seconds > 0 | #17 item field(mailbox 件 = 入箱時刻;TTL sweep 同一基準 — ground truth `sweep_mailbox` L948 用 `acquired_at_unix`)|
| TTL | `OVERFLOW_MAILBOX_TTL_DAYS` | int | 7(#17 const L32 — **#17 own,#23 referenced**)| auto-salvage 期限 |
| 顯示 | `date_local` | func | — | device-local 日期 format(= #22 EC-15 timezone 規則;test 經 injected tz offset seam — AC-01)|

**Render guards:**
- **Receipt 件唔 render retention 行**(佢哋唔會被 sweep — 顯示限期 = 講大話)+ note「收據件唔會自動分解」。
- **`acquired_at_unix <= 0` 唔 render retention 行**(persist 壞數據 / migration default — ledger 寧願唔講,唔好講 1970)。
- **過期日期照 render 唔改寫(D2)**:賬簿唔改寫事實 —「保留至 [過去日期]」係最誠實嘅狀態陳述;interpretive copy(「即將分解」「離線期間保留」)係倒數恐嚇近親 / 違 quiet ledger 文法。

**Output Range(誠實版)**:boot 後首 frame、sane-clock 情況下唔會見到過期 non-receipt 件(#17 boot sweep 已收);**兩個例外過期件會出現**:(a)**grace path** — `sweep_mailbox` L939-940 offline / server-clock drift ⇒ 成個 sweep skip(DISCONNECTED 必觸發 — #23 whitelisted state);(b)**mid-session 過界** — sweep 只喺 boot 行。兩者 render 規則同上(照 render);操作規則見 Rule 12 rescue window(claim 照得)+ EC-15。
**A3 框架(価值不蒸發)**:TTL 過期唔係毀滅 — `_auto_salvage`(L915-919)shards 照入賬 +tombstone + loud telemetry(「value never evaporates」);玩家損失嘅只係件本身嘅 provenance,而 receipt 件(Pillar 1 真正在乎嘅)免疫。
**禁 ticking countdown**(pinned design constant — Player Fantasy 裁決,唔係 knob)。
**Example:** acquired 6月1日 09:00 → expiry instant = 6月8日 09:00 → retention「保留至 **6月7日**」(最後完整保證日);receipt 件 → 無 retention 行 +「收據件唔會自動分解」note。

### F2-M — Mailbox sort comparator(#23-owned;D8)

`mailbox_before(a, b) := a.acquired_at_unix < b.acquired_at_unix`(tie → `String(a.item_id) < String(b.item_id)`)

- **acquired asc** — TTL 食最舊,FIFO expiry queue 用 FIFO 順序先係誠實 information architecture(最需決策嘅件喺最頂);同秒 tie 常態(unix seconds),item_id asc 保 strict total order(store-wide unique — #22 F3 同款論證)。
- 住喺 #23 自己嘅 formulas file(`src/ui/inventory_ui/`)— 唔掂 `char_screen_formulas.gd`。
- **Output:** strict weak ordering,total order(unique tie-break)— golden vector binary-exact(AC-03)。

## Edge Cases

> 格式 = #22 同款:**If [condition]**: [exact outcome]。Lifecycle/GSM race 類(force-close × modal / suspend snap / IDLE↔DISCONNECTED / signal 喺非 active states / re-tap open)**= #22 EC-01..07 全套 cite**,#23 唔重抄;以下只列 #23-specific。

- **EC-01(bulk preview 同 execute 之間 drift)**:If BULK_CONFIRM 開咗之後(row-tap 時點 preview)、confirm 之前,另一路徑(claim 觸發 auto-equip / TTL sweep)改咗 item 池:confirm 照行,`bulk_salvage` 用 #17 當下真值;toast 報 **execute return**(`{count, shards}` L617),唔報 preview 數。**Modal 唔 live-update**(preview 係 row-tap 快照,execute 係事實);reverse drift(execute 多過 preview)同款口徑。
- **EC-02(bulk 0 件 rarity)**:If `bulk_salvage_preview(rarity).count == 0`:row 灰掉但 tap 照應 — **tap 時 re-preview(Rule 15)**,仍 0 →「呢個 tier 冇可分解嘅件」inline note;>0(reverse drift)→ 照開 CONFIRM。唔 disable(mystery meat,= #22 EC-20 原則)。
- **EC-03(bulk 全 locked)**:If 該 rarity owned > 0 但全部 locked:preview count==0(#17 preview 已濾 locked)→ inline note 用 variant「**0 件可分解([N] 件已鎖)**」(N = view model 對該 rarity 嘅 locked count — 玩家見到 30 件 COMMON 但 bulk 話 0,唔解釋就讀成 bug;quiet ledger 講事實);owned==0 先用 EC-02 copy。
- **EC-04(claim shortfall → MAKE_ROOM)**:If `claim` 回 `{ok: false, shortfall: 1}`(N≡1 — #17 invariant,L715):開 `MAKE_ROOM` sheet(Rule 11 D4 全套:雙入口 + `make_room_pending` transient + 騰夠位 inline hint)。**零自動代理分解**;claim button 唔 disable(每次 tap 重新檢查 — inventory 隨時變)。Dismiss = 放棄(pending 清空)— 重試 = 再 tap 領取。
- **EC-05(claim 後 auto-equip)**:If claim ok 且 #17 `_evaluate_auto_equip`(L721)將件裝上:判定 predicate = re-read 後 `get_item(claimed_id).lifecycle_state == EquipmentEnums.ItemLifecycle.EQUIPPED` → toast「已領取並裝上」;否則「已領取」。**#23 唔出 lock nudge**(nudge 係 manual equip 嘅誠實兌現 — auto-equip 上身係 #17 機器,#22 Rule 24 silent-accept 口徑)。
- **EC-06(mailbox 件 inspect stale race — per-command 真值)**:If IN_MAILBOX 件 inspect 內 stale race:`equip` 對仍-IN_MAILBOX 件 → `in_mailbox_claim_first`(L658-659);**`salvage` 對仍-IN_MAILBOX 件冇 code guard — #23 必須零 dispatch(Rule 12 invariant;disabled 入口係唯一防線)**;equip/salvage 對已消失件 → `not_found`(L553-554 / L656-657);**`claim` 對已消失/已領件 → `not_in_mailbox`(L711-712 — 兩種情況同一 code,claim 永不回 not_found)**;有 error code 嘅全部 → Rule 14 toast + re-read。
- **EC-07(TTL 過期 race)**:If MAILBOX section 顯示緊某件,佢喺另一 boot 被 TTL sweep 食咗:「領取」tap → **`not_in_mailbox`** → toast「件物品已唔喺信箱(可能已自動分解)」+ section re-read;inspect 內 equip/salvage(disabled 防線漏網嘅 stale tap)→ `not_found`(= #22 EC-17 stale 口徑;per-command code 見 EC-06)。
- **EC-08(receipt 件 retention 行)**:If `has_receipt()`:**唔 render** retention 行(F1 render guard)+ note「收據件唔會自動分解」— 顯示假限期 = 講大話。
- **EC-09(empty states ×2)**:If slot_filter 收窄到 0 件:section 照 render empty-state「呢類暫時冇收藏」— 唔 auto-reset filter。**If INVENTORY + filter==ALL + 0 件(first-run)**:first-collection copy「收據庫仲未有收藏 — 完成 workout 之後,loot 會喺度等你」(ledger 聲線,講事實順手教 loot 來源,唔催促);「批量分解」button 照 render(mystery-meat 自洽 → BULK_SELECT 五行全 0)。
- **EC-10(120 滿 + mailbox 180 滿)**:If 兩個 cap 都頂:claim 永遠 shortfall;#17 hard-cap FIFO evict 係 #17 機器(#23 唔 render evict 預警 — v0.2 Q-IU4);MAKE_ROOM copy 照用。**Soft-admit 注記**:all-receipt fallback(L970-974)下 mailbox 可 >180(~300 週 edge)— virtualized list 天然 cover,「最多 180」口徑唔 binding render。
- **EC-11(#22↔#23 sequential 切換 race)**:If「查看全部 →」tap 時 GSM 啱啱轉 state:#22 close 照行,#23 `open()` double guard 拒絕 → 玩家落返 shell(唔 crash 唔 limbo)— 兩個 coordinator 各自 guard,夾埋 safe(Rule 2 glue = one-shot deferred call,冇 retry)。
- **EC-12(bulk 期間 force-close)**:If BULK_CONFIRM confirm 嗰下同 frame GSM force-close:= #22 EC-04 (i) 口徑 — `bulk_salvage` synchronous 已執行就成立(#17 single transaction),re-read/toast/SFX skip,下次 open 收割(AC-36);modal 喺 force-close cancel(永不 confirm)= 未撳 confirm 就乜都冇發生。
- **EC-13(DISCONNECTED 全功能)**:= #22 EC-30 positive assertion 同款 — claim / bulk / equip / unequip / lock / salvage 全 local,照行,唯一 delta = offline banner(+ EC-15 嘅過期件可見)。
- **EC-14(virtualized rebuild scroll — 雙軌,Rule 9)**:If bulk execute 令 list 由 120 件變 8 件:rebuild + scroll **reset 去頂**(內容根本唔同,保留 = 假連續性)。If 單件 mutation(claim / 單件 salvage / equip / lock):rebuild + **保留 scroll offset(clamped)** — 內容 99% 冇變,reset 先係假不連續(180 件逐件 claim 嘅 loop 唔可以每下飛返頂)。
- **EC-15(過期件可見 — grace / mid-session)**:If retention date 已過但件仍在(`sweep_mailbox` grace skip L939-940 [DISCONNECTED 必觸發] 或 mid-session 過界):row 照列,**過去日期照 render 唔改寫**(D2)+ 零 urgency styling;「領取」**照 enabled**(rescue window — Rule 12);reconnect 後 boot sweep 收件 → 下次 re-read 自然消失,期間操作撞 race → EC-07。
- **EC-16(deferred claim replay 嘅 return 丟棄 — 設計接受)**:If claim 撞 `_mutating` → `deferred_reentrancy`(L716-718):#17 下 frame 自動重放,但 replay 係 `func() -> void` — **return 冇人收**;如果 replay 嗰下先至 full,`shortfall` 落咗 void ⇒ MAKE_ROOM 唔會開、toast 冇。**設計接受**:re-read 後件如仍 IN_MAILBOX,玩家 re-tap「領取」係 recovery path(claim button 唔 disable — EC-04)— implementer **唔好**試圖收割一個收割唔到嘅 return。

## Dependencies

### Upstream(#23 depends on)

| System | Hard/Soft | Interface | Bidirectional 狀態 |
|--------|-----------|-----------|---------------------|
| **#17 Equipment & Inventory** | Hard | commands(claim/equip/unequip/set_lock/salvage/bulk_salvage)+ reads(get_item/get_inventory_count/get_forge_shards/get_loadout/salvage_yield/bulk_salvage_preview shipped)+ **G-IU-1 additive 擴充**(getters + `receipt_ids`)| ✅ #17 GDD L359 UX flag 指明 claim-when-full 係 #23 命題;bulk_salvage_preview doc comment 直接點名 #23;**#17 code L706-707「bulk-salvage shortcut」期望已由 Rule 11 D4 入口 (a) 兌現** |
| **#1 GSM** | Hard | = #22 同款(whitelist + cfis + force-close)| generic UI consumer |
| **#4 AudioManager** | Hard | `play_sfx` — **零新 cue**;binding usage = Visual/Audio event→cue map 表 | catalog 來源 column + 備註 errata 隨 G-IU-3 |
| **#22 Character Screen** | Soft(入口 + pattern)| LOADOUT「查看全部 →」sequential 切換(glue locus Rule 2);inspect/salvage/lock/F3/formatter-epsilon pattern cite;FSM = spec cite + **code fork**(States);preload `char_screen_formulas.gd` + `char_screen_timing_config.gd`(唔搬家唔 rename)| ✅ #22 Rule 17 邊界 +「#23 係 full inventory surface」row 已 forward;G-IU-4 加 link row;G-IU-5 掂 #22 shards formatter 一行 |

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
| **G-IU-1** | #17 additive 擴充三件:`get_all_inventory_items() -> Array[StringName]`(**IN_INVENTORY + EQUIPPED** — 口徑 = `get_inventory_count` L1128;cap 數乜佢列乜,語意自洽)+ `get_mailbox_items() -> Array[StringName]`(IN_MAILBOX)+ **`bulk_salvage_preview` return 加 `receipt_ids: Array[StringName]` key**(additive Dictionary key — #22 唔 call 零影響;selection predicate 留 #17 single-source,#17-side unit test 加 predicate↔ids 一致性 assert)— 排序由 #23 做(F3 / F2-M);getters copy 語意(G-CS-1 同款)| additive story(**browse 主糧 — 先行;de facto blocks 全部 open-path integration ACs**)|
| **G-IU-2** | ADR-0001 revision:**InventoryUILayer 61**(PAUSABLE;>60 #22)+ **L112/L127 capture enumeration 明文更新「0/10/50/60」→「0/10/50/60/61」**(G-CS-7 先例同款 — 機制上 BackBufferCopy capture 係 positional <100[screen_effects.gd L372-373],61 本身會被 capture;但 ADR 明文 enumeration 唔同步 = phantom-citation 溫床)+ mood note(layer 61 過 saturation chain;IDLE/DISCONNECTED steady chain = identity — #22 Rule 34 同款;LOOT_DROP force-close #23;CLOSING×OPENING crossfade transient 兩面同 draw 接受 — 遠低 mobile 150 cap)。ADR-0008 insertion:InventoryUICoordinator tail append 喺 CharacterScreenCoordinator 後;**predecessor constraints {GameStateMachine (C6), InventorySystem, AudioManager, PlatformDetect} ≺ InventoryUICoordinator**;**明文「NO #22 constraint」**(tail 位置係慣例唔係 binding — 兩 coordinator 零 boot-order 依賴,preload 係 script resource;防 verifier 發明 phantom constraint;#19 G-Z-1「NO EnemyDirector」先例);明文唔列 StatSystem / AvatarRenderer / PersistenceLayer / ScreenEffects / CameraController(零接觸);#28 keep last | ADR revisions(scaffold 前提)|
| **G-IU-3** | #4 catalog doc errata cluster:(a)來源 column reuse 行加 #23(ui_sheet_* / ui_salvage_execute / ui_lock_* / ui_error / ui_charscreen_open/close — `ui_back` #23 唔用,唔加);(b)**備註更新**:`ui_salvage_execute` →「transaction stamp,count-invariant(1..120 件同一響)」[原單件語境 author 出嚟嘅紙撕聲,12 件一響會單薄似 bug — sound-designer 要知];`ui_charscreen_*` →「cue 語意 = ledger-surface 開合(#22+#23 共用);名係 historical,新 consumer 當 family cue」+ **chaining craft constraint**(#22 close + #23 open back-to-back ~300ms 內,兩 cue 要 chain 得起唔似 stutter);(c)#23 voice pool 包絡一行(IDLE/DISCONNECTED only / 全 low mono / 同時 ≤2-3 — G-CS-9 先例);(d)interaction-patterns.md P-13/P-15/P-16 **Used-by 加 #23 + 變體註記**(P-13 list 變體[主體+領取兩 zone,無 per-row lock] / P-15 BULK_CONFIRM[itemised 加重 + fixed-footer 結構] / P-16 BULK_SELECT/MAKE_ROOM)+ P-14 加 #23(make-room inline hint);(e)#17 code L706-707 doc comment「+ bulk-salvage shortcut」divergence note:已兌現(Rule 11 (a)),措辭 superseded by #23 GDD;(f)**#17 `set_lock` doc comment L690-691「immune to every salvage path」stale over-claim erratum**(ground truth:TTL sweep + FIFO evict 唔理 `is_locked` — comment 要收窄至 manual/bulk salvage,防 implementer 信 comment 推翻 D1 honest copy)| doc errata cluster |
| **G-IU-4** | #22 GDD「查看全部 →」link 落地 row(LOADOUT panel header;#22-side 一行)+ #23 接線(glue locus = Rule 2 pin:#22 link handler `close()` 後 `call_deferred` `/root/InventoryUICoordinator.open()` untyped seam + guard)| #22 additive 一行 + wiring |
| **G-IU-5** | **Shards 顯示統一(D6)**:shared thousands-separator formatter(locus:#23 epic 起 `src/ui/common/` 或 #17-side static — story 裁)+ **#22-side 一行 churn**(`get_forge_shards_display` `str()` → shared formatter;#22 AC literal 同步 + suite 重跑)+ #17 L1138 doc comment erratum 擴「#22/#23 shared contract」+ #22 GDD「int verbatim 禁 K/M」行 erratum(原意 = 禁 lossy abbreviation;千位逗號 lossless)| code 統一 + doc errata |

> **FSM extraction 注記(CD 裁決)**:#23 FSM = fork(States section);`ScreenLifecycleFsm` extraction ADR 喺 **#24 Shell authoring 時開**(rule of three — 第三 consumer 需求知道先 bake API)。唔係 #23 gate。

## Tuning Knobs

| Knob | Default | Safe range | Too high | Too low | Source |
|------|---------|-----------|----------|---------|--------|
| `BULK_CONFIRM_RECEIPT_LIST_MAX` | 8 | 4-20 | scrollable 中段過長(fixed footer 結構下唔致命 — Rule 16)| receipt 件列唔晒 →「+N more」行(誠實度:總數照報)| Rule 16 |
| `POOL_BUFFER_ROWS` | 2 | 1-4 | 多餘 node(memory)| scroll 邊緣 pop-in | Rule 9(AC-13 pool 公式;`ROW_HEIGHT_PX` 由 UX spec 定後 test 讀同一常數)|

### Referenced knobs(source of truth 喺上游/姊妹 — #23 唔 duplicate)

| Knob | Owner | #23 關係 |
|------|-------|----------|
| `OVERFLOW_MAILBOX_TTL_DAYS`(7)| #17 L32 | F1 retention date 嘅 TTL 來源 |
| `MAX_INVENTORY`(120)/ `MAILBOX_HARD_CAP`(180)| #17(DESIGN-FROZEN)| virtualized worst case + MAKE_ROOM copy |
| `FORCE_CLOSE_MAX_MS` / `ERROR_TOAST_DURATION_MS` / `ARIA_COALESCE_WINDOW_MS` / `OPEN/CLOSE_ANIM_MS` | #22 timing config | FSM/toast/ARIA 全 reuse(#23 自己零 timing knob — injected clock 同款紀律)|
| salvage_yield 曲線 | #17(monotonic assert)| bulk preview 數字來源 |

### Pinned constants(非 knob)

- **禁 ticking countdown**(F1 — Player Fantasy 裁決)
- **F1 −86400 最後完整保證日**(D3 — under-promise 安全邊)
- **F3 comparator 鏈**(= #22 pinned — 同一 code,INVENTORY only)+ **F2-M acquired asc**(D8 — MAILBOX)
- **毀滅永不代理**(EC-04 — MAKE_ROOM 零自動分解;入口 (a) 通去嘅 BULK 自帶兩步 confirm)
- **Shards thousands separators**(D6 — 全 game 統一,G-IU-5)
- **過期日期照 render 唔改寫**(D2)

## Visual/Audio Requirements

> **= #22 Visual/Audio 全套文法延伸**(quiet ledger:particle = 0 pinned / L0-L3 tier 表 / 賬簿線 framing / amber+ink 雙色 / pure white 禁 / 禁 elastic·pulse·staggered pop-in / opaque ink base)— #23 唔重抄,divergence 如下:

| Event | 處理 | Tier |
|-------|------|------|
| Section / filter 切換 | snap-switch 80-120ms(= #22 tab)| L0-L1 |
| Bulk execute | list rebuild 一次過 final(**禁逐件 fade-out cascade** — 12 件連環動畫 = 慶祝化毀滅);shards snap;scroll reset 頂(EC-14)| L1 |
| Claim 成功 | row 移去 INVENTORY(rebuild,唔做 fly-over 動畫;scroll 保留 clamped — EC-14);toast | L1 |
| Mailbox retention 行 / receipt glyph | `ui_text_dim` static;receipt glyph = 細印章形(squint test 同 lock 分得開)| L0 |
| MAILBOX tab count badge | dim ink 純文字「(N)」(Rule 10 文法 — 禁色 pill / 紅 / dot / pulse;0 唔 render)| L0 |
| MAKE_ROOM sheet / inline hint strip | = picker bottom sheet 文法(slide-up + scrim);hint strip = P-14 inline 文法 | L2 / L0 |
| Empty states(filter 0 件 / first-run / mailbox 空)| L0 static(= #22:dotted outline + dim label;「信箱空嘅」係好消息但唔慶祝;copy 分流 EC-09)| L0 |

### Event→cue map(binding — AC-29 驗 mapping,唔係淨 set-membership)

| Event | Cue | 備註 |
|-------|-----|------|
| Screen open / close(player-initiated)| `ui_charscreen_open` / `ui_charscreen_close` | family cue(G-IU-3 語意收口);force-close / SUSPENDED snap **零 SFX**(CD C1)|
| #22→#23 link path | 雙 cue(#22 close + #23 open)| **接受**(Rule 1;chaining constraint → G-IU-3)|
| 全部 modal 開 / 關(ITEM_INSPECT / SALVAGE_CONFIRM / BULK_SELECT / BULK_CONFIRM / MAKE_ROOM)| `ui_sheet_open` / `ui_sheet_close` | 逐層退 = 該層一響 close;兩層連開 = 兩響(#22「共用」備註同款)|
| Salvage execute(單件 + bulk)| `ui_salvage_execute` **恰好一響** | transaction stamp,count-invariant(G-IU-3 備註)|
| Lock on / off(inventory + mailbox 件)| `ui_lock_on` / `ui_lock_off` | |
| Error toast(Rule 14 全部 codes)| `ui_error` | `deferred_reentrancy` 唔 toast ⇒ 零 SFX |
| **Equip / unequip 成功** | **silent(明文)** | toast + badge 承擔;`ui_equip_settle` 綁 #22 stat-tween settle moment,#23 冇 stat 面 ⇒ 冇 referent(#22 cosmetic equip 無聲先例;audio grammar:#23 嘅聲只留俾 destructive[salvage]同 protective[lock],acquisition/assignment 類視覺承擔)|
| **Claim 成功** | **silent(provisional)** | 同上 grammar;**inversion 認知在案**:claim 失敗路徑(MAKE_ROOM sheet_open)有聲、成功零聲 — 注意力引去要處理嘅嘢,intended;AC-31/32 walkthrough 順手驗,如補聲 = v0.2 新 cue(歸檔質感)跟 #4 catalog 規則 co-design |
| Silent 名單(其餘全部)| — | filter chip / section tab 切換 / retention 行 render / count badge 更新 / 0-件 row tap inline note / disabled 入口 tap(hint 承擔)/ success toast 出現 / virtualized rebuild / scroll reset / inline hint strip 出現 |

**`ui_back` #23 唔用**(modal 退層 = `ui_sheet_close`)— 由 reuse 名單剔走。BGM 零 call(= #22)。**Web 首 gesture note(正確版 — 唔好由 #22 抄錯版)**:#23 open 必由 tap 觸發 ⇒ 首 SFX 時 audio 已 unlock(#4 `_input` unlock 先於 GUI);唯一 artifact = unlock chime 疊聲 / AudioContext resume 首 frame clip — 接受。

📌 **Asset Spec** — 隨 `/asset-spec system:inventory-ui`:receipt glyph sprite +「現役」badge chip;其餘全 reuse #22 assets(card 9-slice / badge accent / sheet bg / icons)。

## UI Requirements

### Layout 結構(360×560 min viewport,= #22)

- **Persistent**:header(title + shards counter[thousands separators — D6] + close X ≥48px)+ offline banner 位 + section tabs(INVENTORY / MAILBOX — MAILBOX tab 帶 dim-text count「(3)」,Rule 10 文法)
- **Sub-header**(INVENTORY only):slot filter chips 一行(**2 字 CJK labels,5 chips 排晒 360px,唔 scroll** — Rule 8)+「**[count]/120**」readout(Rule 5;verbatim,禁 progress bar)+「批量分解」button
- **Content**:virtualized item card list(scroll container = #22 ux R4 同款;rebuild scroll 雙軌 — EC-14)
- **Row hit-zone(P-13 list 變體 pin)**:「領取」button 右對齊、寬 ≥64px、同主體 zone 之間 **≥8px dead gap**(tap 落 gap = no-op)— claim 唔 confirm(可逆:unequip/re-equip 救得返;friction 預算全留 destructive),誤觸防線喺 hit-zone 切割
- **Modal 軸**:ITEM_INSPECT / SALVAGE_CONFIRM / BULK_SELECT / BULK_CONFIRM / MAKE_ROOM(bottom sheets + center modal — 文法 = #22;**BULK_CONFIRM 結構 = fixed header + scrollable 中段 + fixed footer** — Rule 16,confirm/cancel 永遠 on-screen)
- 並發 messaging priority = #22 表同款(offline > toast > inline notes)

### Pattern 引用

P-06(rarity badge)/ P-13 three-zone-item-card 嘅 list 變體(#23 row = 主體 tap→inspect +「領取」button[mailbox only];**冇** per-row lock toggle — lock 喺 inspect 內,list row 保持單一主操作)/ P-14 inline-nudge-strip(make-room hint — Rule 11)/ P-15 destructive-confirm-modal(SALVAGE_CONFIRM + BULK_CONFIRM)/ P-16 bottom-sheet(BULK_SELECT / MAKE_ROOM)。Registry Used-by 更新隨 G-IU-3 (d)。

### 實作要求

= #22 全套(touch ≥48px / 無 hover-only / 無 long-press / Zpix 12px floor + m6x11 數字 / ARIA via `platform_detect.announce_aria` / ESC routing modal-first / ADR-0001 budget + virtualized)。

**ARIA 加項(binding)**:
- bulk execute → announce「已分解 [count] 件,+[shards] 碎片」;claim → announce toast 文字;**equip / unequip / 單件 salvage 成功 + error toast → announce**(= #22 AC-54 command-result set,#23 command 集);section 切換 → announce section 名 + **list summary「收藏 N 件」**(coalesced — filter 切換同款報數)
- **Disabled 入口 focus → announce 原因**(「裝備 — 先領取先用得」/「分解 — 上鎖中」)— 視覺玩家有 hint 文字,SR 玩家唔可以得個謎
- **Virtualized list SR/keyboard policy**:focus-driven virtualization — keyboard/SR focus 行到 pool 視窗邊 → 視窗跟 focus 推進(唔淨係跟 scroll position);AC-31 walkthrough 包「focus 行到超過首屏件數嘅 row」

> **📌 UX Flag — Inventory UI**:Phase 4 入 epic 前必行 `/ux-design inventory-ui` 產 `design/ux/inventory-ui.md`;stories cite UX spec。Bulk flow 嘅兩層 sheet(SELECT → CONFIRM)係 wireframe 重點。

## Acceptance Criteria

> **37 ACs**:**33 BLOCKING**(3 Logic unit + 30 Integration)+ **3 ADVISORY**(manual)+ **1 RATIFICATION-GATED**。(Pass 1 fix:原「33」實數 32 + AC-14 跳號 — AC-14 已填 grace-path AC,另增 AC-34..37;header 數 = grep 實數。)
> **Test seams(binding)**:injected clock screen-wide / process_frame 禁 wait_frames / cfis 禁 .bind() / 真 #17 誘發禁 stub(**`_mutating=true` state 注入唔算 stub** — deferred 誘發用)/ golden vector binary-exact / **injected tz offset seam**(F1 `date_local` — AC-01 determinism,唔好裸用 device TZ)/ **negative assertion positive-control 紀律 = #22 AC-42 qa R4 機制**(同一 spy instance / 同一 test file 內先 assert positive 再 assert negative — locus 係 #22 AC-42 inline,唔係 AC header;各 negative AC 已逐條 inline pin)。
> **G-IU-1 gating**:run-level — Rule 5 第一 frame 就 call 新 getters,getter 未落地 coordinator parse 唔過 ⇒ **全部 integration ACs de facto blocked;story 排序 G-IU-1 = epic 第一個 story**。「*(gated)*」標記係 subject 層面(getter 係被測對象)。**AC-09 另 gated on G-IU-4**(link row)。
> **G-IU gates evidence**:各自喺 epic story 收口(G-IU-1 = #17-side unit tests 含 predicate↔receipt_ids 一致性;G-IU-2 = ADR diffs;G-IU-3/4 = doc diffs;G-IU-5 = formatter test + #22 suite 重跑 green)。

### Group A — Logic(unit)

- **AC-01**:GIVEN mailbox 件 acquired 6月1日 09:00(injected clock + injected tz),WHEN F1,THEN「保留至 **6月7日**」(−1 day 最後完整保證日 — D3;golden 用 formatter round-trip + fixed-tz golden 兩條腿);GIVEN `has_receipt()`,THEN **無** retention 行 +「收據件唔會自動分解」note;GIVEN `acquired_at_unix <= 0`,THEN 無 retention 行(degenerate guard — 唔講 1970)。Source: F1/EC-08 | Gate: BLOCKING | File: `tests/unit/inventory_ui/test_retention_date.gd`
- **AC-02**:GIVEN 混合 slot 件 view models,WHEN filter predicate 逐 chip,THEN 只剩 `slot_affinity` match + filter 值不變(unit 收窄到 predicate;empty-state render 歸 AC-12)。Source: Rule 8 | Gate: BLOCKING | File: `tests/unit/inventory_ui/test_inventory_filter.gd`
- **AC-03**:GIVEN #23 INVENTORY sorter,WHEN introspect,THEN `SORT_COMPARATOR == Callable(preload("res://src/ui/character_screen/char_screen_formulas.gd"), "picker_before")`(**Callable equality identity assert** — 同 script object + 同 method name,fork 必不等;#23 expose `SORT_COMPARATOR` const 做 seam)+ 真 fixture byte-identical(behavioral 防 binding 錯件);GIVEN F2-M(MAILBOX),THEN golden vectors:acquired asc + 同秒 tie → item_id asc(strict total order — 排列任意 shuffle 收斂同一序)。grep-lint 留 CI(隨 G-IU gates),唔混入 GUT assert。Source: Rule 7/F2-M | Gate: BLOCKING | File: `tests/unit/inventory_ui/test_invui_sort.gd`

### Group B — Lifecycle(Integration;FSM = #22 pattern,重驗 #23-specific)

- **AC-04**:GIVEN 全部 GSM states 逐個,WHEN `open()`/`can_open()`,THEN 只 IDLE/DISCONNECTED 准(double guard;唔 hardcode 數)。Source: Rule 1 | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_lifecycle.gd`
- **AC-05**:GIVEN BULK_CONFIRM 開緊,WHEN GSM→WORKOUT_ACTIVE,THEN modal cancel(bulk 永不執行 — #17 count/shards 不變)+ advance(FORCE_CLOSE_MAX_MS) 內 CLOSED + **零 play_sfx**(positive control 同 test:先 player-initiated open assert `ui_charscreen_open` 一響,再 force-close assert 零)。Source: Rule 3/EC-12 | Gate: BLOCKING | File: 同上
- **AC-06**:GIVEN OPEN,WHEN SUSPENDED,THEN instant snap;resume 唔 auto-reopen。Source: Rule 3 | Gate: BLOCKING | File: 同上
- **AC-07**:GIVEN section=MAILBOX + filter=WEAPON + modal open + `make_room_pending` set,WHEN close→re-open,THEN 全 reset(INVENTORY/ALL/NONE/`&""`)。Source: Rule 3 clean-slate | Gate: BLOCKING | File: 同上
- **AC-08**:GIVEN open,WHEN introspect subscriptions,THEN 先 assert GSM connect **存在**(positive control)再 assert **只此一條**(cfis);#11/#26 零 connect(明文非依賴);全 code path 零 `is_input_permitted` call(同一 introspect pass — Rule 1 拒用);3 close paths 後零 active。Source: Rules 1/6 | Gate: BLOCKING | File: 同上
- **AC-09** *(G-IU-4 gated)*:GIVEN #22 OPEN,WHEN「查看全部 →」,THEN #22 normal close → #23 open sequential(glue = `call_deferred` one-shot — Rule 2);GSM race 時 #23 double guard 拒 → 兩邊 CLOSED 無 limbo;雙 cue(close+open)各一響(Rule 1 政策)。Source: Rules 1-2/EC-11 | Gate: BLOCKING | File: 同上
- **AC-37**:GIVEN 完整操作 session(claim/bulk/equip/lock/filter/section),WHEN 3 close paths 逐個,THEN **#23 零 PersistenceLayer write**(spy IPersistence;positive control:#17 自己嘅 write 照行 — 先 assert #17 write 存在,再 assert 零 #23-origin key)。Source: Dependencies #3 row | Gate: BLOCKING | File: 同上

### Group C — Browse(Integration;真 #17 + G-IU-1)

- **AC-10** *(G-IU-1 gated)*:GIVEN open 第一 frame,WHEN read,THEN all-inventory(**IN_INVENTORY+EQUIPPED**)+ mailbox + count + shards + loadout 齊(無 loading)+ view models built(render 層零 live `EquipmentItem` reference — introspect)。Source: Rule 5 | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_browse.gd`
- **AC-11** *(gated)*:GIVEN 真 #17 混合 fixture(含 equipped),WHEN render,THEN F3 排序 byte-identical;EQUIPPED 件照列 +「現役」badge(loadout set lookup)。Source: Rules 7-8 | Gate: BLOCKING | File: 同上
- **AC-12** *(gated)*:GIVEN filter 切換,WHEN re-filter,THEN **state-based assert:view model array object identity 不變**(零 re-read 嘅可觀察等價 — 唔 wrap #17);filter 0 件 → empty-state 照 render 唔 reset filter;first-run(ALL+0 件)→ first-collection copy(EC-09);section 切返 → re-read(view model 新 object)。Source: Rules 6/8/EC-09 | Gate: BLOCKING | File: 同上
- **AC-13** *(gated)*:GIVEN 120 件 fixture,WHEN list render,THEN instantiated row nodes ≤ `ceil(viewport_h / ROW_HEIGHT_PX) + 2 × POOL_BUFFER_ROWS`(test 讀 implementation 同一常數;P-06 card node 計,chrome 唔計);WHEN bulk rebuild,THEN scroll reset 頂;WHEN 單件 mutation rebuild(claim/salvage 一件),THEN scroll offset 保留(clamped)— EC-14 雙軌。Source: Rule 9/EC-14 | Gate: BLOCKING | File: 同上
- **AC-35** *(gated)*:GIVEN open,WHEN INVENTORY section render,THEN header「[count]/120」readout(count = `get_inventory_count()` verbatim — 含現役);WHEN claim/salvage 改 count,THEN re-read 後 readout 更新;零 progress-bar 零變色(introspect node type)。Source: Rule 5 | Gate: BLOCKING | File: 同上

### Group D — Mailbox / claim(Integration;真 #17)

- **AC-14** *(gated)*:GIVEN DISCONNECTED(`_server_clock_sane` false ⇒ sweep grace)+ mailbox non-receipt 件 retention date 已過(injected clock),WHEN MAILBOX render,THEN row 照列 + **過去日期照 render 原文案**(D2 — 零 urgency styling 零 copy 改寫)+「領取」enabled;WHEN claim,THEN ok(rescue window — 救返件);GIVEN 件已被另一 boot sweep 收(fixture erase),WHEN「領取」,THEN `not_in_mailbox` → toast + re-read(EC-07)。Source: F1/EC-15/Rule 12 | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_mailbox.gd`
- **AC-15** *(gated)*:GIVEN mailbox 混合(普通 + receipt),WHEN render,THEN **F2-M sort(acquired asc)** + retention 行(普通件,−1 day)/ receipt note(receipt 件,無 retention 行)+ MAILBOX tab count「(N)」dim text(0 件唔 render「(0)」— badge 文法);**#23 唔 render evict 預警**(EC-10 negative — fold 喺度)。Source: Rule 10/F1/F2-M | Gate: BLOCKING | File: 同上
- **AC-16**:GIVEN claim ok,WHEN #17 auto-equip 上身/唔上身(predicate = `get_item(id).lifecycle_state == EQUIPPED`),THEN toast「已領取並裝上」/「已領取」分支 + re-read;**零 lock nudge**(EC-05;positive control = **同 file 內**先行一次 manual-equip-nudge positive[= AC-25 同款 assert,喺本 file 重做])。Source: Rule 11/EC-05 | Gate: BLOCKING | File: 同上
- **AC-17**:GIVEN inventory full,WHEN claim,THEN `{shortfall:1, 無 error key}` → MAKE_ROOM sheet(「要騰 1 個位」+ 雙入口)+ `make_room_pending` set;**零自動分解**(state-based:#17 shards + count 全程不變直到玩家自己 confirm);WHEN 玩家經入口 (b) salvage 騰位(re-read 後 count < 120),THEN INVENTORY 頂 inline hint「已騰出空位 — 領取『[name]』」+ one-tap claim ok + pending 清空;WHEN MAKE_ROOM dismiss,THEN pending 清空 + claim button 照 enabled(re-tap 重試)。Source: Rule 11/EC-04 | Gate: BLOCKING | File: 同上
- **AC-18**:GIVEN mailbox 件 inspect,WHEN render,THEN equip/salvage disabled +「先領取」hint + **lock toggle enabled**;stale race 逐 command assert:`equip` 對仍-IN_MAILBOX 件 → `in_mailbox_claim_first`;equip/salvage 對已消失件 → `not_found`;**`claim` 對已消失件 → `not_in_mailbox`** — 有 code 嘅全部 toast + re-read;**`salvage` 零 dispatch invariant**:walkthrough 全程(含 disabled 入口 stale tap 模擬)assert #23 對 IN_MAILBOX 件零 `salvage()` call(negative;positive control = 同 file 先行一次 IN_INVENTORY 件 salvage assert dispatch 存在 — code 冇 guard,dispatch 咗 = 件已毀)。Source: Rule 12/EC-06/07 | Gate: BLOCKING | File: 同上
- **AC-34**:GIVEN mailbox unlocked receipt 件,WHEN inspect 內 lock on,THEN `set_lock` ok + lock 標記 + receipt glyph 並存 render + honest copy「鎖定 — 批量分解唔會掂佢;保留期照計」;WHEN `bulk_salvage(該 rarity)`,THEN 件存活喺 mailbox(真 #17 — lock 係 bulk 唯一 immunity);GIVEN locked **non-receipt** mailbox 件,THEN retention 行**照 render**(lock 唔擋 sweep — 日期仍係事實,D1)。Source: Rule 12/D1 | Gate: BLOCKING | File: 同上

### Group E — Bulk(Integration;真 #17)

- **AC-19**:GIVEN 5 rarity 混合 fixture,WHEN BULK_SELECT 開,THEN 每 row = `bulk_salvage_preview` 真值;0 件 row 照 tap → **re-preview**,仍 0 → inline note(唔 disable);GIVEN owned>0 全 locked,THEN note variant「0 件可分解([N] 件已鎖)」(EC-03);GIVEN 0-件 row tap 時 reverse drift(re-preview >0),THEN 照開 CONFIRM。Source: Rule 15/EC-02/03 | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_bulk.gd`
- **AC-20** *(G-IU-1 gated — receipt_ids)*:GIVEN receipt_count>0(unlocked receipt 件,含 mailbox+equipped 中招),WHEN BULK_CONFIRM,THEN **D5 三層**:①itemised 列名 data source = `preview.receipt_ids` → `get_item()`(cap `BULK_CONFIRM_RECEIPT_LIST_MAX` +「+N more」總數照報)②conditional breakdown「內含信箱 [M] 件、現役 [K] 件」(M/K >0 先 render — 零中招 fixture assert **無**呢行)③`make_room_pending` rarity-match unlocked ⇒ 第一行「⚠ 包括你想領取嗰件『[name]』」(無 pending fixture assert 無);modal 結構 = fixed header(receipt 總數行)+ scrollable 中段 + fixed footer;cancel + scrim + ESC 三者一律退返 BULK_SELECT;default focus=cancel。Source: Rule 16/18/D5 | Gate: BLOCKING | File: 同上
- **AC-21**:GIVEN confirm,WHEN `bulk_salvage`,THEN toast 報 **execute return**(count/shards — thousands separators)+ `ui_salvage_execute` 恰好 **1** 響 + `modal := NONE` + re-read;locked 件全存活。Source: Rules 16-17 | Gate: BLOCKING | File: 同上
- **AC-22**:GIVEN row-tap preview 後 execute 前外部 mutation(test 直接 call `_inv.salvage(victim)`),WHEN confirm,THEN execute 用當下真值,toast ≠ preview 數 — 無 crash 無 assert。Source: EC-01 | Gate: BLOCKING | File: 同上
- **AC-23**:GIVEN equipped unlocked 件喺 bulk range,WHEN execute,THEN #17 auto-unequip + backfill → re-read 反映(slot 變化 = #22 EC-13 兩 outcome 口徑)。Source: Rule 18 | Gate: BLOCKING | File: 同上
- **AC-24**:GIVEN BULK_CONFIRM 開,WHEN ESC,THEN 退返 BULK_SELECT(逐層 + re-preview);再 ESC → NONE;再 ESC → close screen;GIVEN SALVAGE_CONFIRM(ITEM_INSPECT 內開),WHEN ESC/scrim/cancel,THEN 退返 **ITEM_INSPECT**(return-target 表);GIVEN MAKE_ROOM,WHEN ESC/scrim,THEN → NONE。Source: States return-target 表 | Gate: BLOCKING | File: 同上
- **AC-36**:GIVEN BULK_CONFIRM confirm 嗰下同 frame GSM force-close(EC-12 executed branch),THEN #17 state 已變(count/shards assert — synchronous single transaction)+ **零 toast 零 SFX 零 re-read**;下次 open render 新 state(收割)。Source: EC-12 | Gate: BLOCKING | File: 同上

### Group F — 單件 ops(Integration;真 #17;= #22 pattern 重驗)

- **AC-25**:GIVEN IN_INVENTORY 件 inspect,WHEN「裝備」,THEN `equip(id, slot_affinity)` + **lock nudge inline 喺 ITEM_INSPECT sheet 內**(unconditional;inline [鎖定] tap → set_lock + 確認態;inspect 閂咗 nudge 即棄);cosmetic 同款零 stat 面;GIVEN **EQUIPPED** 件 inspect,THEN「裝備」button **唔 render**,「現役」標記 +「卸下」render,WHEN「卸下」,THEN `unequip(slot)` ok + re-read(badge 消失);GIVEN 單件 salvage confirm 成功,THEN SALVAGE_CONFIRM + ITEM_INSPECT 一齊閂 → NONE + toast。Source: Rule 13 | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_commands.gd`
- **AC-26**:GIVEN **6 error codes**(not_found / in_mailbox_claim_first / slot_type_mismatch / slot_empty / locked / not_in_mailbox)+ deferred_reentrancy(真 #17 誘發 — `_mutating=true` 注入),WHEN 處理,THEN = Rule 14 行為(6 codes → toast + re-read,`not_in_mailbox` 有自己 toast entry 唔 leak raw code;deferred 唔 toast 下 frame 收割);GIVEN claim 回 `{ok:false, shortfall:1}`(**無 error key**),THEN 行 MAKE_ROOM 路徑 **唔行** toast 路徑(dispatch order ①②③)。Source: Rules 11/14 | Gate: BLOCKING | File: 同上
- **AC-27**:GIVEN DISCONNECTED + OPEN,WHEN claim/bulk/equip/**unequip**/lock/salvage 逐個,THEN 同 IDLE 一致,唯一 delta = banner(+ EC-15 過期件可見 — AC-14 cover)。Source: EC-13 | Gate: BLOCKING | File: 同上

### Group G — ARIA + audio(Integration)

- **AC-28**:GIVEN bulk execute / claim / equip / unequip / 單件 salvage / error toast / section 切換,WHEN 處理,THEN announce 對應文字(「已分解 [N] 件,+[M] 碎片」/ toast 文字 / section 名 + list summary「收藏 N 件」,coalesced — #22 AC-54 command-result set 擴 #23 command 集);disabled 入口 focus → announce 原因;positive control 先行(同 spy instance 先 assert 一條 announce 存在)。Source: UI Requirements ARIA | Gate: BLOCKING | File: `tests/integration/inventory_ui/test_invui_aria.gd`
- **AC-29**:GIVEN 完整操作 walkthrough(**op 名單枚舉**:open → filter → section 切換 → inspect → equip → unequip → lock on/off → salvage 兩步 → bulk 兩層開關 + confirm → claim shortfall → MAKE_ROOM 開 + dismiss → claim ok → error 誘發 → ESC 退層 → close),WHEN 收集 play_sfx calls,THEN **逐 event assert = event→cue map 指派 cue**(mapping 驗證,唔係淨 set-membership);silent 名單 events 零 call;`ui_back` 零 call(#23 唔用);positive control 先行(map 內任一 sounding event 響咗先)。Source: Visual/Audio event→cue map | Gate: BLOCKING | File: 同上

### Group H — Manual(ADVISORY)+ GATED

- **AC-30**:長 CJK provenance walkthrough 截圖 — **list row 單行 ellipsis**(Rule 9 fixed height 前提);wrap/12px floor 驗證限 ITEM_INSPECT + BULK_CONFIRM 內(receipt 名單)。Gate: ADVISORY | File: `production/qa/evidence/inventory-ui/`
- **AC-31**:真 SR walkthrough(claim/bulk/section/equip announces 可聽 + disabled 原因可聽 + **focus 行到超過首屏件數嘅 row** — focus-driven virtualization)+ 真機 touch ≥48px + claim button dead-gap 誤觸試。Gate: ADVISORY | File: 同上
- **AC-32**:Visual 名單 walkthrough(零 cascade 動畫 / 零 countdown / badge dim-text 文法 / greyscale pass;claim silent 體感順手記錄 — provisional 裁決覆核素材)。Gate: ADVISORY | File: 同上
- **AC-33** *[ADR-0001 RATIFICATION-GATED]*:mobile 真機 120 件 list scroll + bulk rebuild ≤ UI CPU 2ms(注:ADR-0001 2.0ms 原文係 Foundation autoloads 總額 — ratification 時同 #22 AC-49 一齊對返最終 budget 分項)。File: `tests/performance/inventory_ui/`

## Open Questions

| ID | Question | Owner | Target |
|----|----------|-------|--------|
| **Q-IU1** | 入口 affordance + #22↔#23 互斥嘅 shell 接線(= #22 Q-CS1 同一命題;「查看全部 →」link 係 #23 自己嘅,shell 入口係 #24 嘅)| #24 GDD | #24 authoring |
| **Q-IU2** | Mailbox「未開封」ritual recovery(#21 OQ-6)— 需 GSM erratum + content-source 分支;MVP 首次見面永遠喺 #21 | #21/#23 v0.2 | v0.2 |
| **Q-IU3** | User-selectable sort axes + search(MVP 固定 F3;120 件實測唔夠用先加)| #23 v0.2 | v0.2(soak 後)|
| **Q-IU4** | Mailbox hard-cap(180)FIFO evict 預警 UI(#17 機器;quiet ledger 點講「就嚟逼爆」而唔加壓力?)| #23 v0.2 | v0.2 |
| **Q-IU5** | `SfxCatalog` reuse 行 #23 來源 column + 備註 errata(G-IU-3 隨 epic 執行)| epic | epic 期間 |
| **Q-IU6** | **Claim-all / multi-claim**(D7 — MVP 唔做):逐件 claim 喺幾十件 mailbox 係 maintenance fantasy 殺手,但 claim-all 撞 shortfall 要 partial-claim 語意(領到滿為止?揀邊幾件?)— 設計面唔細;D4 inline return affordance 已斬最痛段;v0.2 憑 soak telemetry 裁(180 件係 ~300 週 edge 唔係 MVP 常態)| #23 v0.2 | v0.2(soak 後)|
