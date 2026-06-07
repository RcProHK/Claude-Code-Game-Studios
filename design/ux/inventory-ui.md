# UX Spec: Inventory UI(#23)

> **Status**: APPROVED(/ux-review 2026-06-07 — 0 blocking / 3 advisory 已修)
> **Author**: frank + ux-designer(/ux-design,full-autonomous;derived from APPROVED GDD 2026-06-07)
> **Last Updated**: 2026-06-07
> **Journey Phase(s)**: 未知 — 冇 player-journey.md(見 Open Questions)
> **Platform Target**: Web(primary)/ Desktop(secondary);Touch primary(single-tap)+ Keyboard/Mouse;Gamepad none(authoritative: technical-preferences.md)
> **Template**: UX Spec
> **Source of truth**: `design/gdd/inventory-ui.md`(APPROVED 2026-06-07,37 ACs)— 本 spec 引用 GDD Rule/EC/AC 編號;衝突時 GDD 為準

---

## Purpose & Player Need

玩家嚟呢度想做三樣嘢:**巡倉**(瀏覽全部收藏 — 120 件 inventory + 180 件 mailbox,每件嘅日期同來歷喺度先睇得晒 — Pillar 1 收據庫)、**執倉**(per-rarity bulk-salvage / 單件 equip / unequip / lock / salvage — maintenance 型滿足)、**收件**(claim mailbox 件;倉滿時行 MAKE_ROOM 騰位 loop)。

「The player arrives at this screen wanting to ___」:**「執靚個倉」** — 唔係攞 reward(dopamine 喺 #21 burst 完),係 bookkeeping 嘅滿足:分解一批 COMMON、鎖好件有故事嘅 LEGENDARY、領埋 mailbox 嗰幾件,操作完間倉「整齊咗」。冇呢個 screen:mailbox 係黑箱、bulk 冇入口、120 上限係無形牆(GDD Overview)。

#22 答「我而家係邊個」(門框),#23 答「我儲低咗啲乜」(儲物房)— 姊妹 surface,同一 quiet ledger 聲線。

## Player Context on Arrival

- **時機**:workout 以外(GSM `IDLE` / `DISCONNECTED` only — GDD Rule 1)。Anchor scenario:workout 完返到 IDLE,MAILBOX tab 見「(3)」— 「今日掉咗嘢落信箱,執一執」;或 rest day 大執倉。
- **嚟之前做緊乜**:(a)shell home idle;(b)**啱啱喺 #22 LOADOUT 撳咗「查看全部 →」**(sequential 切換 — Rule 1/G-IU-4,帶住「想睇晒我啲後備」嘅意圖);(c)offline 開 app(DISCONNECTED 全功能 — EC-13)。
- **情緒假設**:calm、唔趕時間、主動;比 #22 更操作性 — 預期玩家會連續做幾個 action(claim ×N / bulk / lock),所以 list 操作嘅 scroll 連續性係體驗命脈(EC-14 雙軌)。
- **自願 vs 被send**:永遠自願。Game 永不主動彈;SUSPENDED resume 唔 auto-reopen(Rule 3)。

## Navigation Position

This screen lives at: **[shell home(#24,未 design)] → Inventory UI** — top-level destination,state-gated(GSM ∈ {IDLE, DISCONNECTED};Q-IU1 provisional)。**第二入口**:[shell] → Character Screen(#22)→ LOADOUT tab「查看全部 →」→ **sequential 切換**(#22 close → #23 open;glue = `call_deferred` one-shot — Rule 2/G-IU-4)。Runtime form = autoload coordinator + **CanvasLayer 61**(G-IU-2)— #22(60)之上、#21 modal(110/120)之下;同 #22 永不同時 OPENING/OPEN(crossfade transient 接受 — Rule 2)。

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Shell home nav(#24 provisional)| 入口 affordance tap(GSM permitted 先顯示)| 無 — 每次 open clean-slate(`active_section=INVENTORY` / `filter=ALL` / `modal=NONE` / `make_room_pending=&""` — Rule 3);data 第一 frame sync read 齊(Rule 5)|
| #22 LOADOUT「查看全部 →」(G-IU-4)| link tap → #22 normal close → #23 open(雙 cue 接受 — Rule 1)| 無 state 傳遞(clean-slate 同上);玩家心理 context =「由 4 件現役放大去全部」— INVENTORY default section 啱好接住 |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Shell home | X button(≥48px,persistent)/ ESC(desktop;modal open 時逐層退先 — States return-target 表)| CLOSING 120-150ms;**唔 cancel 任何已發出嘅 #17 write**(Rule 4)|
| (force)workout states | GSM `state_changed` → ∉ {IDLE, DISCONNECTED} | FORCE_CLOSING ≤150ms;modal 一律 cancel(BULK_CONFIRM 永不 confirm — Rule 3/EC-12)+ `make_room_pending` 清空;**零 SFX**(CD C1)|
| (snap)SUSPENDED | tab hidden | instant snap CLOSED;resume 唔 auto-reopen;#23 零 persist ⇒ 冇 flush 需求(對比 #22 EC-27)|
| Character Screen(#22)| **冇直接返回 link**(MVP)— 玩家經 shell 或 close 後再開 | 單向 link(#22→#23);反向 = v0.2 考慮(見 Open Questions)|

One-way notes:唯一不可逆 = salvage / bulk-salvage(兩步 modal friction + D5 三層誠實度保護);claim 可逆(unequip / re-equip 救得返 — 所以 claim 唔 confirm,friction 預算全留 destructive)。

---

## Layout Specification

### Information Hierarchy

(由 GDD Player Fantasy + Pillar 1 推導;ranked)

1. **Item card list(收據庫主體)** — name + rarity + provenance + 狀態標記;screen 存在理由
2. **Section tabs + MAILBOX count「(3)」** — 有嘢未領 = 最高決策資訊(dim text,唔係 urgency)
3. **「[count]/120」readout + filter chips +「批量分解」入口** — 倉房管理員嘅工作檯(Rule 5)
4. **Mailbox retention 行 / receipt glyph / 現役・已鎖標記** — per-row 狀態(F1/F2-M)
5. **Offline banner / toast** — status,出現時即時可見
6. **Shards counter(header)** — 結餘,discoverable

### Layout Zones

**自動裁決(= #22 同款 rationale)**:單欄 portrait-first;desktop content column 置中 max-width ~560px;min viewport **360×560**(GDD UI Requirements)。

| Zone | 內容 | Scroll |
|---|---|---|
| Z1 Header(fixed)| offline banner 位(頂部 strip)+ title + shards counter(**thousands separators — D6**)+ close X(右上 ≥48px)| 固定 |
| Z2 Section tabs(fixed)| INVENTORY(default)/ MAILBOX(dim count「(3)」— 0 件唔 render;Rule 10 文法)| 固定 |
| Z3 Sub-header(INVENTORY only,fixed)| slot filter chips ×5(**2 字 CJK,一行排晒,唔 scroll** — Rule 8)+「[count]/120」readout +「批量分解」button;**MAILBOX section 時 Z3 唔 render**(mailbox 冇 filter 冇 bulk 入口 — list 直接貼 Z2 落)| 固定 |
| Z3b Inline hint strip 位(conditional)| make-room hint「已騰出空位 — [領取『name』]」(P-14;騰夠位先出 — Rule 11)| 固定(list 頂)|
| Z4 Virtualized item list | P-06 card rows(fixed height,provenance 單行 ellipsis — Rule 9)| **scroll**(雙軌 rebuild — EC-14)|
| Z5 Modal layer | ITEM_INSPECT / SALVAGE_CONFIRM / BULK_SELECT / BULK_CONFIRM / MAKE_ROOM + scrim(modal ≠ NONE ⇒ tabs 封鎖 — States)| — |
| Z6 Toast | 底部,同屏最多 1 條 | — |

並發 messaging priority(= #22 pinned):offline banner > error toast > inline notes(hint strip / empty states)。

### Component Inventory

**Z4 — Item card row(P-13 list 變體)**:
| Component | Type | 內容 | Interactive | Pattern |
|---|---|---|---|---|
| Card 主體 zone | card(fixed height)| name + P-06 rarity badge(corner accent + text label)+ provenance 單行 ellipsis + 狀態標記(已鎖 glyph / 現役 chip / receipt glyph[細印章形]) | tap → ITEM_INSPECT | P-06 + **P-13 list 變體**(冇 per-row lock — lock 喺 inspect)|
| 「領取」button(mailbox row only)| button | 右對齊,**寬 ≥64px,同主體 zone ≥8px dead gap**(UI Req hit-zone)| tap → `claim` | — |
| Retention 行(mailbox 普通件)| dim 文字行 | 「保留至 [date]」(F1 −1 day;**過期照 render 原文案** — D2/EC-15;receipt 件唔 render + note;`acquired<=0` 唔 render)| 否 | ledger 文法 |

**Z3 — Sub-header**:
| Component | Type | 內容 | Interactive | Pattern |
|---|---|---|---|---|
| Filter chip ×5 | chip(單選)| 全部 / 武器 / 護甲 / 飾品 / 外觀 | tap → 本地 re-filter(Rule 8)| — |
| 「[count]/120」| 數據 readout | verbatim,禁 progress bar 禁變色(Rule 5)| 否 | columnar ledger |
| 「批量分解」| button ≥48px | — | tap → BULK_SELECT | — |

**Z5 — Modals**:
| Component | Type | 內容 | Pattern |
|---|---|---|---|
| ITEM_INSPECT | panel | provenance 全文 + signature + stat_modifiers 原始數據;affordance 按 lifecycle(Rule 13:IN_INVENTORY「裝備」+ lock nudge inline / EQUIPPED「現役」+「卸下」/ IN_MAILBOX equip・salvage disabled +「先領取」+ **lock enabled + honest copy**[D1])| — |
| SALVAGE_CONFIRM | center modal + scrim | = #22 destructive-confirm-modal 同款;dismiss → 退返 ITEM_INSPECT(return-target 表);成功 → 兩層齊閂 | **P-15** |
| BULK_SELECT | bottom sheet + scrim | 5 rarity rows(preview 真值「COMMON — 12 件 → 1,200 碎片」;0 件 row 灰掉照 tap → re-preview → inline note[EC-02/03])| **P-16** |
| BULK_CONFIRM | center modal,**三段結構**:fixed header(count + yield + 「內含 [R] 件收據件」above-fold)+ scrollable 中段(D5 三層:receipt itemised cap 8 +「+N more」/ conditional「內含信箱 M 件、現役 K 件」/ claim-target warning)+ fixed footer(cancel + confirm 永遠 on-screen;default focus = cancel)| **P-15 加重版**(Rule 16)|
| MAKE_ROOM | bottom sheet | 「倉滿 — 要騰 1 個位」+ 雙入口 row(「批量分解」→ BULK_SELECT /「自行整理」→ 閂 sheet + INVENTORY section)(Rule 11 D4)| **P-16** |

### ASCII Wireframe

**主 view(INVENTORY)+ MAILBOX**:

```
360×560                                      MAILBOX section(切 tab 後)
┌─────────────────────────────────────┐     ┌─────────────────────────────────────┐
│ [⛓ offline banner — 出現時]         │ Z1  │ 收據庫        ◇ 12,400          [X] │
│ 收據庫        ◇ 12,400          [X] │     ├─────────────────────────────────────┤
├─────────────────────────────────────┤     │  INVENTORY   [MAILBOX (3)]          │
│ [INVENTORY]   MAILBOX (3)           │ Z2  ├─────────────────────────────────────┤
├─────────────────────────────────────┤     │ ┌─────────────────────────[領取]──┐ │
│ (全部)(武器)(護甲)(飾品)(外觀)      │ Z3  │ │ 鐵劍        [RARE]              │ │
│ 倉:117/120        [批量分解]        │     │ │ 拾於 6月1日・腿日               │ │
├─────────────────────────────────────┤     │ │ 保留至 6月7日                   │ │
│ ┌─ 已騰出空位 — [領取「鐵劍」] ─ X ┐│ Z3b │ ├─────────────────────────[領取]──┤ │
│ └─────────────────────────────────┘ │     │ │ 龍鱗甲   [LEGENDARY] 🔏▣        │ │
│ ┌─────────────────────────────────┐ │     │ │ 拾於 5月28日・推日              │ │
│ │ 鐵劍      [RARE]  現役          │ │ Z4  │ │ ▣ 收據件唔會自動分解            │ │
│ │ 拾於 6月3日・推日               │ │     │ └─────────────────────────────────┘ │
│ ├─────────────────────────────────┤ │     │ (F2-M:就嚟過期排最頂 — D8)         │
│ │ 木棍      [COMMON] 🔏           │ │     └─────────────────────────────────────┘
│ │ 拾於 5月20日・腿日              │ │      ▣ = receipt 印章 glyph;🔏 = 已鎖
│ │  …(virtualized scroll)         │ │
│ │                                 │ │
│            [toast 位 — Z6]          │
└─────────────────────────────────────┘
```

**BULK 兩層 sheet(wireframe 重點 — UX Flag)**:

```
BULK_SELECT(bottom sheet)                   BULK_CONFIRM(center modal,三段)
┌─────────────────────────────────────┐     ┌─────────────────────────────────────┐
│ ▔▔▔ 批量分解 — 揀 tier ▔▔▔          │     │ 分解 12 件 COMMON → +1,200 碎片     │ ←fixed
│ ┌─────────────────────────────────┐ │     │ 內含 2 件收據件・信箱 3 件          │  header
│ │ COMMON    — 12 件 → 1,200 碎片  │ │     ├─────────────────────────────────────┤
│ ├─────────────────────────────────┤ │     │ ⚠ 包括你想領取嗰件「鐵劍」          │ ←scroll
│ │ UNCOMMON  —  5 件 →   750 碎片  │ │     │ ▣ 木刀(拾於 5月2日・推日)         │  中段
│ ├─────────────────────────────────┤ │     │ ▣ 舊靴(拾於 5月9日・腿日)         │ (cap 8
│ │ RARE      —  0 件(灰)          │ │     │ 呢 2 件帶收據,分解後簽名永久消失   │  +N more)
│ ├─────────────────────────────────┤ │     ├─────────────────────────────────────┤
│ │ EPIC      —  1 件 →   450 碎片  │ │     │ [    取消    ]   [ 確認分解 ]      │ ←fixed
│ │ LEGENDARY —  0 件(灰)          │ │     └─────────────────────────────────────┘  footer
│ └─────────────────────────────────┘ │      ESC/scrim/取消 → 退返 BULK_SELECT
└─────────────────────────────────────┘      確認 → 執行 → modal 全閂 + toast

MAKE_ROOM(bottom sheet)
┌─────────────────────────────────────┐
│ ▔▔▔ 倉滿 — 要騰 1 個位 ▔▔▔          │
│ ┌─────────────────────────────────┐ │
│ │ 批量分解            →           │ │ → BULK_SELECT
│ ├─────────────────────────────────┤ │
│ │ 自行整理            →           │ │ → 閂 sheet + INVENTORY section
│ └─────────────────────────────────┘ │   (騰夠位 → Z3b hint strip 接力)
└─────────────────────────────────────┘
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Default(OPEN)| open() 成功 | INVENTORY / ALL / NONE(clean-slate)|
| OPENING / CLOSING / FORCE_CLOSING / CLOSED | = #22 FSM 五態(spec cite;code fork — States)| 入場 150-200ms content 第一 frame final(**禁 staggered pop-in**)/ 出場 120-150ms / ≤150ms 零 SFX / 零 subscription |
| Offline(DISCONNECTED)| GSM toggle | offline banner only;全功能照行(EC-13)+ **過期 mailbox 件可見**(grace — EC-15:過去日期照 render,「領取」照 enabled = rescue window)|
| First-run empty(ALL + 0 件)| 新玩家 | 「收據庫仲未有收藏 — 完成 workout 之後,loot 會喺度等你」;「批量分解」照 render(EC-09)|
| Filter empty | chips 收窄到 0 件 | 「呢類暫時冇收藏」;唔 auto-reset filter(EC-09)|
| Mailbox empty | 0 件 | dotted outline + dim label(好消息但唔慶祝);tab 唔 render「(0)」|
| Make-room pending | claim shortfall → MAKE_ROOM 之後 | `make_room_pending` transient;騰夠位 → Z3b hint strip 出現;dismiss / close / claim 成功 / not_in_mailbox 清空 |
| Bulk 0 件 / 全 locked row | preview count==0 | 灰掉照 tap → re-preview → 「呢個 tier 冇可分解嘅件」/「0 件可分解([N] 件已鎖)」(EC-02/03)|
| Command error | 任何 #17 command 回 error code(Rule 14)| `ui_error` + toast(同屏最多 1 條;= ARIA live;`not_in_mailbox` 專屬文案)+ re-read;screen 本身唔轉 state |
| Loading | — | **冇 loading state**(全 local sync read — Rule 5)|
| Timer-bearing transients | — | toast 3000ms(reuse #22 `ERROR_TOAST_DURATION_MS`)— injected clock 紀律 |

---

## Interaction Map

Mapping for: **Touch(primary,single-tap)+ Keyboard/Mouse(desktop)**。Gamepad: none。全 tap targets ≥48px;無 hover-only、無 long-press。Audio = GDD event→cue map(binding;AC-29 驗 mapping)。

| Component | Action | Input | Feedback(visual/audio)| Outcome |
|---|---|---|---|---|
| 入口(shell / #22 link)| tap | touch / click | `ui_charscreen_open`(family cue;link path 雙 cue 接受)| open() → OPENING |
| Close X | tap | touch / click / ESC(modal=NONE 時)| `ui_charscreen_close` | CLOSING |
| Section tab | tap | touch / click | snap 80-120ms,**silent**;announce section 名 + list summary | section 切換 + visibility re-read(Rule 6)|
| Filter chip | tap | touch / click | 即時 re-filter,**silent** | 本地 predicate(零 re-read — AC-12)|
| Card 主體 | tap | touch / click | `ui_sheet_open` | ITEM_INSPECT |
| 「領取」button | tap | touch / click | **silent**(claim grammar);toast「已領取(並裝上)」| `claim` → dispatch ①②③(Rule 11)|
| 「批量分解」/ MAKE_ROOM 入口 (a) | tap | touch / click | `ui_sheet_open` | BULK_SELECT |
| BULK_SELECT rarity row | tap | touch / click | re-preview → `ui_sheet_open`(>0)或 inline note(0)| BULK_CONFIRM(tap-time 數)|
| BULK_CONFIRM confirm | tap | touch / click / ENTER(只喺 confirm 獲 focus 時 — default focus 喺 cancel,ENTER 預設 = cancel 退層;= #22 salvage CTA 同款注法)| list rebuild final(**禁逐件 cascade**)+ scroll reset 頂 + `ui_salvage_execute` **一響** + toast(execute 真值,thousands separators)| `bulk_salvage` → modal NONE + re-read |
| BULK_CONFIRM cancel / scrim / ESC | tap / key | — | `ui_sheet_close` | 退返 BULK_SELECT(三者等效)|
| MAKE_ROOM 入口 (b)「自行整理」| tap | touch / click | `ui_sheet_close` | modal NONE + INVENTORY section + re-read |
| Z3b hint「領取『name』」| tap | touch / click | toast | one-tap claim(pending 件)|
| 「裝備」(inspect,IN_INVENTORY)| tap | touch / click | **silent** + toast + 現役 badge + **lock nudge inline 喺 sheet 內**(Rule 13a)| `equip` → re-read |
| 「卸下」(inspect,EQUIPPED)| tap | touch / click | **silent** + toast | `unequip(slot)` → re-read(Rule 13b)|
| Lock toggle(inspect;**含 mailbox 件** — D1)| tap | touch / click | `ui_lock_on/off`;mailbox 件配 honest copy | `set_lock` → re-read |
| Salvage 入口(inspect)| tap | touch / click | `ui_sheet_open`;locked → disabled + hint(Rule 13);**mailbox 件 disabled +「先領取」(零 dispatch invariant — Rule 12)** | SALVAGE_CONFIRM |
| Salvage confirm | tap | touch / click | card collapse + shards snap + `ui_salvage_execute` | `salvage` → 兩層 modal 齊閂 + toast |
| Error(任何 command)| — | — | `ui_error` + toast(= ARIA live;`not_in_mailbox` 有專屬文案)| Rule 14 + re-read |

**Keyboard-only path(desktop)**:TAB 順序 = close X → section tabs → sub-header(chips → count → 批量分解)→ Z3b hint(出現時)→ list rows(focus-driven virtualization — 視窗跟 focus)→ modal 內(default focus = cancel);ESC = States return-target 表逐層退,modal=NONE 先 close screen。

## Events Fired

MVP **零 analytics event**(#28 v0.2)。**#23 零 persist**(冇 owned keys 連 namespace 都唔開 — AC-37 negative)。

| Player Action | Event / Write | Payload |
|---|---|---|
| claim / equip / unequip / set_lock / salvage / bulk_salvage | #17 command(synchronous return;persistence #17 own)| item_id / slot / rarity |
| 開 / 閂 screen、section / filter 切換 | 無 event(pure overlay)| — |
| SFX / ARIA | `play_sfx`(event→cue map);`announce_aria`(AC-28 set)| — |

## Transitions & Animations

| Transition | Spec |
|---|---|
| Screen enter / exit | = #22(slide-up + fade 150-200ms ease-out / 120-150ms ease-in;reuse `char_screen_timing_config`)|
| Force-close / SUSPENDED | ≤150ms fast path / instant snap |
| Section / filter 切換 | snap 80-120ms |
| Sheet / modal | slide-up 150-200ms + scrim;無 elastic |
| Bulk execute | list rebuild **一次過 final**(禁逐件 fade-out cascade — 慶祝化毀滅);shards snap;scroll reset 頂 |
| 單件 mutation(claim / salvage / equip / lock)| rebuild + **scroll offset 保留(clamped)**(EC-14 雙軌 — 連續執倉嘅體驗命脈)|
| Claim 成功 | row 移去 INVENTORY(rebuild,唔做 fly-over)|
| Hint strip(Z3b)| 出現 = static render(L0;唔 slide 唔 pulse)|

**Motion sickness audit**:本 screen 零 shake 零 particle 零 parallax(particle = 0 pinned);唯一 motion = 短 fade/slide + snap 切換。P-07/P-08 settings 唔喺本 screen(#22 SETTINGS own)— reduce-motion 對 #23 嘅 enter/exit 短 fade 唔適用(= #22 同款口徑)。

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| All-inventory(IN_INVENTORY+EQUIPPED)+ mailbox 件 list | #17 **G-IU-1 getters**(gated — epic 第一 story)| Read | copy 語意;F3 / F2-M sort 由 #23 做 |
| count / shards / loadout(badge set)/ per-item detail | #17 `get_inventory_count` / `get_forge_shards` / `get_loadout` / `get_item` | Read | `get_item` 回 live ref — view model snapshot 紀律(Rule 5)|
| Bulk preview + receipt_ids | #17 `bulk_salvage_preview`(receipt_ids = G-IU-1 擴充)| Read | row-tap re-preview(Rule 15)|
| claim / equip / unequip / set_lock / salvage / bulk_salvage | #17 commands | Write | synchronous;dispatch ①②③;同 frame re-read(Rule 6 全套範圍);NO optimistic UI |
| GSM state | #1 cfis + `get_current_state` | Read | force-close driver;唯一 subscription(AC-08)|
| ~~#11 / #26 / #3~~ | — | — | **明文零接觸**(GDD 非依賴;AC-08/AC-37 negative)|

**架構 flag**:#23 唔 own 任何 game data;`make_room_pending` 係 coordinator transient UI state(零 persist)。

## Accessibility

(Tier:accessibility-requirements.md WCAG AA Core + Motion Safety;SR announcements 跟 #21/#22 shipped `announce_aria` 先例 = BLOCKING 級)

- **Keyboard-only**:全 interactive elements TAB-reachable(順序見 Interaction Map);ESC 逐層退(return-target 表);destructive modal default focus = cancel
- **Gamepad**:N/A
- **Contrast / font**:CJK body Zpix 12px floor;數字 m6x11;amber/ink 雙色;dim text(retention 行 / count badge)≥5.2:1(AA)
- **Color-independent**:rarity 永配 text label(P-06);receipt glyph(細印章形)同 lock glyph squint test 分得開;「現役」係 text chip 唔係色;過期日期唔靠色 carry(原文案照印 — D2)
- **Screen reader**(`platform_detect.announce_aria`):AC-28 set — bulk(「已分解 N 件,+M 碎片」)/ claim / equip / unequip / 單件 salvage / error toast / section 切換 + list summary「收藏 N 件」(coalesced);**disabled 入口 focus → announce 原因**(「裝備 — 先領取先用得」);**focus-driven virtualization**(SR/keyboard focus 行到視窗邊 → 視窗跟 focus 推進 — AC-31 walkthrough 包超過首屏件數)
- **Touch**:全部 ≥48px;**「領取」button ≥64px + 主體 zone ≥8px dead gap**(誤觸防線 — claim 唔 confirm 嘅補償設計)
- **Reduced motion**:本 screen 零 motion class(上面 audit);P-07=0% / P-08 對 #23 無作用面

## Localization Considerations

- **最長文字元素**:BULK_CONFIRM 警告行(「呢 [R] 件帶收據,分解後簽名永久消失」~16 字 — scrollable 中段,wrap 安全)/ mailbox lock honest copy(「鎖定 — 批量分解唔會掂佢;保留期照計」~18 字,inspect 內 wrap 安全)/ first-run empty copy(~24 字,empty-state 區 wrap 安全)/ provenance(list row **單行 ellipsis** — Rule 9 fixed height 前提,全文喺 inspect)
- **Layout-critical(HIGH PRIORITY for 40% expansion)**:**filter chips 2 字 CJK labels** — 「5 chips 一行排晒唔 scroll」嘅前提;譯文超 2-3 字就爆 row(en:All/Weapon/Armor/Trinket/Cosmetic 要驗)/「領取」button label(一行,≥64px 內)/「[count]/120」readout(一行)/ MAILBOX tab +「(3)」(一行)
- **Locale formats**:retention / provenance dates = device local(EC-15 / #22 同款);**shards = thousands separators(D6 — 全 game 統一 formatter,G-IU-5)**;⚠ **#22 spec「數字無千分位」行已被 D6 supersede — G-IU-5 erratum 對象**(見 Open Questions)
- **逐 string font 指派表**:CJK(Zpix)vs latin/數字(m6x11)— implementation 前 string table(= #22 UXQ-3 同款 mandate)

## Acceptance Criteria

(Spec-level — GDD 37 ACs 係 implementation 真源;呢度係 QA 可獨立行嘅 screen-level checks)

- [ ] **Performance**:screen open 由 tap 到 content 完整可見 ≤200ms(冇 loading state);120 件 list scroll 60fps(mobile tier:AC-33 RATIFICATION-GATED)
- [ ] **Navigation**:shell 入口 + #22「查看全部 →」兩條路都開到;X / ESC 閂返;workout state 入口唔存在;force-close ≤150ms 兼 modal 全 cancel + pending 清空
- [ ] **Empty/error**:first-run / filter-0 / mailbox-0 三款 empty state 文案正確;command error → toast + ARIA(`not_in_mailbox` 專屬文案);offline 全功能 + 過期件可見可領
- [ ] **Accessibility**:keyboard-only 行到晒(含 list 第 80 件 — focus-driven);全 targets ≥48px +「領取」dead gap;CJK ≥12px;SR 聽齊 AC-28 set + disabled 原因
- [ ] **Core purpose(執倉)**:bulk 由入口到執行必經兩層 sheet;BULK_CONFIRM receipt 總數行喺 above-fold、confirm/cancel 永遠 on-screen;execute 後 toast 報真值;單件 mutation 後 scroll 唔飛頂
- [ ] **Destructive 保護**:salvage / bulk 必經 confirm;scrim / ESC / cancel = 退層永不執行;locked 件全 immune;mailbox 件 salvage 零 dispatch;claim-target warning 喺 make-room context 出現
- [ ] **Claim loop**:倉滿 claim → MAKE_ROOM 雙入口 → 騰位 → hint strip one-tap 領返目標件 — 全程唔使玩家自己記住件嘢
- [ ] **Resolution/viewport**:360×560 下 Z1-Z3 fixed 全可見、Z4 scroll 正常、BULK_CONFIRM 三段結構成立(footer 唔落 fold)、無 horizontal scroll

## Open Questions

| ID | Question | Owner |
|---|---|---|
| UXQ-1 | Player journey map 未建立(= #22 UXQ-1 同款)— arrival context 由 GDD Player Fantasy 推導,journey 建立後 reconcile | producer / ux |
| UXQ-2 | Shell 入口 affordance 形態(= Q-IU1;#24 design 時連 #22 UXQ-2 一齊裁)| #24 |
| UXQ-3 | 逐 string font 指派表(= #22 UXQ-3 同款 mandate)| epic story |
| UXQ-4 | Pattern registry 更新(P-13 list 變體 / P-15 加重版 / P-16 ×2 / P-14 hint strip)— **已框喺 G-IU-3 (d)**,epic 執行 | epic(G-IU-3)|
| UXQ-5 | Accessibility tier 未正式定名(= #22 UXQ-5)| producer |
| UXQ-6 | **#22 ux spec「數字無千分位(shards 禁 K/M)」行同 D6 thousands-separators 衝突** — G-IU-5 執行時連 #22 spec Localization 行一齊 erratum | epic(G-IU-5)|
| UXQ-7 | #23→#22 反向 link(「睇緊件現役 → 想去 loadout 卸佢」)— MVP 經 inspect「卸下」已 cover 主 need;直接反向 link = v0.2 考慮 | #23 v0.2 |

---

## Cross-Reference Check(2026-06-07)

- **GDD requirements**:UI Requirements 全章 cover(layout 結構 / hit-zone / chips pin / modal 三段 / SR 政策);Visual/Audio event→cue map 全反映喺 Interaction Map ✓
- **New patterns to add to library**:4 個變體/新用(UXQ-4)— 已框 G-IU-3 (d),唔 block
- **Navigation mismatches**:#22 spec Entry/Exit 表未列「→ #23」exit row(G-IU-4 落地時 #22 spec 同步加一行 — 隨 gate 執行,非 mismatch);shell #24 provisional 同 #22 一致
- **Accessibility gaps**:tier 未定名(UXQ-5);條款層面全 cover(SR set 比 #22 多 focus-driven virtualization 政策)
- **Missing empty states**:none(first-run / filter / mailbox / bulk-0 / 全 locked 全有)
- **D6 衝突 surfaced**:#22 spec「無千分位」行 → UXQ-6 / G-IU-5(唔 silent drop)✓
