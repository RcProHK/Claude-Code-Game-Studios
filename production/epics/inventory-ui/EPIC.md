# Epic: Inventory UI (#23)

> **Layer**: Presentation(第四個 Presentation epic — 「執倉」收據庫 surface)
> **GDD**: design/gdd/inventory-ui.md(✅ APPROVED 2026-06-07 — 同日全 pipeline:Pass 1 full 7-specialist + CD NEEDS REVISION → consolidated fix pass → 3-verifier re-pass [1 salvage-sibling FAIL → 修] → CD sign-off 0 phantom)
> **UX Spec**: design/ux/inventory-ui.md(✅ APPROVED 2026-06-07 — /ux-review 0 blocking / 3 advisory 已修;stories 引用 UX spec,唔直接 cite GDD UI 細節)
> **Architecture Module**: `InventoryUICoordinator` autoload @ `src/autoload/inventory_ui_coordinator.gd`(thin Node;持有 CanvasLayer **61**(PAUSABLE),pre-warm `visible=false` — G-IU-2;>60 #22 / <100 BackBufferCopy capture[ADR-0001 L112+L127 enumeration 隨 G-IU-2 更新「…/61」] / <110-120 #21)。Autoload 位置:tail append 喺 CharacterScreenCoordinator 後(#28 keep last)— G-IU-2 ADR-0008 amendment;predecessor constraints `{GSM(C6), InventorySystem, AudioManager, PlatformDetect} ≺ #23`;**明文 NO #22 constraint**(tail 係慣例唔係 binding — 防 phantom)。**FSM = fork #22**(~150-200 行 inline;header cross-ref + divergence 同步註記 — CD 裁決;extraction ADR 留 #24)
> **Status**: Ready
> **Stories**: **18**(2 Config/Data + 1 Logic + 15 Integration;baseline 14-18 內)— QL-STORY-READY degraded inline ADEQUATE(spawn blocked 1M-credit,#17/#18/#21/#22 同款;GDD 37 ACs 3-verifier verified GWT = qa-plan-import-equivalent,直接 embed)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | G-IU-2 ADR revisions(layer 61 + enumeration + insertion)| Config/Data | Ready | ADR-0001+0008 |
| 002 | Coordinator scaffold + FSM fork + CanvasLayer 61 + 登記 | Integration | Ready | ADR-0008+0001+0006 |
| 003 | G-IU-1 #17 additive 三件(getters + receipt_ids)| Integration | Ready | N/A(additive)|
| 004 | F1 retention + F2-M comparator + sort identity | Logic | Ready | N/A(pure formula)|
| 005 | Virtualized list component(novel)| Integration | Ready | ADR-0001 |
| 006 | View models + browse binding + count/120 | Integration | Ready | ADR-0006+0007(sec)|
| 007 | Lifecycle suite + subscriptions + zero-persist | Integration | Ready | ADR-0006+0003 |
| 008 | Mailbox section render(F2-M + retention + grace)| Integration | Ready | ADR-0007(sec)|
| 009 | Claim flow + MAKE_ROOM D4 | Integration | Ready | ADR-0006(sec)|
| 010 | Mailbox inspect 限制 + lock D1 + 零-dispatch | Integration | Ready | N/A(UI gating)|
| 011 | Bulk sheets(SELECT + CONFIRM D5 三層)| Integration | Ready | ADR-0007(sec)|
| 012 | Bulk execute + drift + EC-12 | Integration | Ready | ADR-0006(sec)|
| 013 | ITEM_INSPECT 單件 ops | Integration | Ready | ADR-0007(sec)|
| 014 | Error model 6+1 + DISCONNECTED | Integration | Ready | ADR-0006+0003 |
| 015 | ARIA + event→cue map | Integration | Ready | N/A(seams shipped)|
| 016 | G-IU-4 #22 link + glue | Integration | Ready | ADR-0006(sec)|
| 017 | G-IU-5 shards formatter | Integration | Ready | N/A(display)|
| 018 | G-IU-3 errata ×6 + evidence protocol | Config/Data | Ready | N/A(doc)|

## Overview

實作 Mirror Hero 嘅 **Pillar 1 收據庫 surface** — 玩家喺 GSM `IDLE`/`DISCONNECTED` 打開嘅全屏「儲物房」(#22「門框」嘅姊妹篇):full inventory browse(IN_INVENTORY+EQUIPPED 全列 + F3 同一 code sort + slot filter chips +「[count]/120」拆無形牆)、MAILBOX section(F2-M acquired-asc sort + F1 retention date「最後完整保證日」+ receipt glyph + 過期件 grace 誠實 render)、claim flow(dispatch ①②③ + 倉滿 → MAKE_ROOM 雙入口 + `make_room_pending` transient + 騰夠位 inline hint one-tap)、per-rarity bulk-salvage(BULK_SELECT row-tap re-preview → BULK_CONFIRM 三段結構 + D5 三層誠實度[receipt_ids itemised / conditional breakdown / claim-target warning])、單件 ops(equip / EQUIPPED「卸下」/ lock[含 mailbox 件 D1 honest copy] / salvage + **salvage 對 IN_MAILBOX 零-dispatch invariant**)。#23 **唔 own 任何 game data 零 persist**(連 namespace 都唔開 — AC-37 negative);訂閱只 GSM 一條(cfis);**零新 SFX cue**(event→cue map binding)。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0001**: Web Export Budget Caps | CanvasLayer topology;**G-IU-2 revision 對象**(layer 61 PAUSABLE 註冊 + L112/L127 capture enumeration「0/10/50/60」→「0/10/50/60/61」+ mood note + crossfade transient);particle = 0 pinned;virtualized list = draw-call 紀律 | **HIGH**(Compatibility/WebGL2)|
| ADR-0003: Save State Strategy | #23 **零 persist**(clean-slate reset;AC-37 negative assert);#17 persistence 唔受 #23 影響(close 唔 cancel writes — Rule 4)| LOW |
| ADR-0006: State Machine Contract | C6 `connect_for_initial_state`(GSM 一條 — 唯一 subscription);ghost callv guard;handler 內 GSM 行為 `call_deferred`;FSM fork 沿用 #22 全套 semantics | LOW |
| ADR-0007: Class & Domain Enum Convention | RarityTier display(P-06 badge + BULK rarity rows);EquipSlot filter chips mapping | LOW |
| ADR-0008: Autoload Position Map | **G-IU-2 insertion amendment 待做**(本 epic story)— tail append CharacterScreenCoordinator 後 + predecessor set + NO-#22 note | LOW |
| ADR-0009: Signal Payload Schema | GSM payload 處理 minimal+intrinsic;#23 零 persisted payload 零自有 signal | LOW |

## GDD Requirements

> #23 未有 TR-IDs(/architecture-review Phase 8 未跑 — #16/#17/#18/#21/#22 先例一致)。Requirements 由 GDD 直接 trace:**18 Core Rules + FSM(fork #22 五態)+ 2 Formulas(F1 retention −1 day + F2-M mailbox comparator)+ 16 ECs + 37 ACs + CD D1-D8 裁決**,全部有 Accepted ADR cover(上表)。

**Untraced requirements**: None(TR-ID granularity 留 /architecture-review batch)。

**AC 分佈**:**33 BLOCKING**(3 Logic unit:AC-01 F1 / AC-02 filter / AC-03 sort identity+F2-M golden;30 Integration:Group B lifecycle ×7 + C browse ×5 + D mailbox/claim ×6 + E bulk ×7 + F 單件 ops ×3 + G ARIA/audio ×2)+ **3 ADVISORY**(manual:AC-30/31/32)+ **1 RATIFICATION-GATED**(AC-33 ADR-0001 mobile)。**Gated 標記**:G-IU-1 **run-level blocks 全部 integration ACs**(Rule 5 第一 frame call 新 getters — coordinator parse 唔過;G-IU-1 = epic 最早 code story);AC-09 另 gated G-IU-4;AC-20 gated receipt_ids。Test seams(GDD AC header,binding):injected clock / injected tz offset(F1)/ process_frame 禁 wait_frames / cfis 禁 .bind() / 真 #17 誘發禁 stub(`_mutating=true` 注入唔算 stub)/ negative positive-control 紀律(#22 AC-42 qa R4 機制 — 同 file 同 spy)/ golden vector binary-exact。

## Cross-system gates(G-IU-1..5 — 全部係本 epic 內 stories;G-CS 先例)

| Gate | Scope | 對象 | 性質 |
|------|-------|------|------|
| **G-IU-1** | #17 additive 三件:`get_all_inventory_items()`(**IN_INVENTORY+EQUIPPED** — get_inventory_count L1128 口徑)+ `get_mailbox_items()` + `bulk_salvage_preview` return 加 `receipt_ids` key;#17-side unit tests 含 **predicate↔receipt_ids 一致性 assert** | #17 `inventory_system.gd` | code(**run-level 解封者 — epic 最早 code story;#17 suite 零變紅 parity**)|
| **G-IU-2** | ADR-0001 revision(layer 61 PAUSABLE + L112/L127 enumeration「…/61」+ mood note + crossfade transient)+ ADR-0008 insertion(tail + predecessor set + NO-#22 note)+ `project.godot` 登記 | ADR-0001 + ADR-0008 + config | doc + config(**scaffold 前提 — story 001**)|
| **G-IU-3** | doc errata cluster 六件:(a)#4 catalog 來源 column(`ui_back` 唔加 — #23 唔用);(b)備註更新(`ui_salvage_execute` count-invariant / `ui_charscreen_*` family 語意 + chaining constraint);(c)#23 voice pool 包絡行;(d)interaction-patterns P-13/14/15/16 Used-by + 變體註記;(e)#17 L706-707 shortcut 措辭 superseded note;(f)#17 `set_lock` L690-691「immune to every salvage path」over-claim erratum | #4 + design/ux + #17 doc | doc-only(bundle 一個 story)|
| **G-IU-4** | #22 GDD「查看全部 →」link row(LOADOUT panel header 一行)+ #23 接線(glue = #22 link handler `close()` 後 `call_deferred` `InventoryUICoordinator.open()` untyped seam + guard)+ #22 ux spec Entry/Exit 表加 exit row | #22 + glue | code + doc |
| **G-IU-5** | shards thousands-separator shared formatter(locus story 裁)+ **#22-side 一行 churn**(`get_forge_shards_display` → shared formatter + AC literal 同步 + **#22 suite 重跑零變紅**)+ #17 L1138 comment erratum 擴「#22/#23 shared contract」+ #22 GDD/ux spec「verbatim 禁千分位」行 erratum(UXQ-6)| formatter + #22 + #17 doc | code 統一 + doc errata(**單一 story 收口,禁順手 refactor**)|

## Story breakdown directives(PR-EPIC degraded inline — binding;spawn blocked 1M-credit,#22 同款先例)

1. **G-IU-2 = story 001**(ADR revisions = scaffold 前提 — G-CS-7+8 先例);coordinator scaffold = story 002
2. **G-IU-1 = 最早 code story**(run-level blocks 全部 integration ACs — 必須先於任何 browse/mailbox/bulk story)
3. **Virtualized list component 獨立 early story**(novel 零先例 code — `src/ui/inventory_ui/`;fixed row height + pool 公式;Group C/D/E render 全依賴 — F1-tween-early 先例同理)
4. **Per gate story 行 combined CI gate**(`tests/unit` + `tests/integration` 一齊);掂已 merged system(G-IU-1 #17 / G-IU-5 #22)要該 system suite **零變紅 parity**
5. **G-IU-5 churn 管控**:#22-side 限一行 + AC literal 同步;單一 story 收口;禁順手 refactor
6. **G-IU-3 六件 bundle 一個 story**(G-CS-5+6 doc-bundle 先例)
7. **FSM fork story**:header comment cross-ref #22 coordinator + divergence 同步註記(CD binding);Group B ACs 係 mechanism-agnostic 驗收
8. **Story 總數 baseline 14–18**(>18 = scope creep 重審;<14 = AC force-compress 重審)

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, closed via `/story-done`
- **37 ACs verified**:33 BLOCKING 全過(3 Logic + 30 Integration;G-IU-1 落地後解封);3 manual ADVISORY 有 evidence docs @ `production/qa/evidence/inventory-ui/`;AC-33 RATIFICATION-GATED 記錄在案
- Combined GUT gate green(per gate story + epic 收線)
- **G-IU-1 落地時 #17 existing tests 零變紅;G-IU-5 落地時 #22 suite 零變紅**(parity 準則)
- `InventoryUICoordinator` 登記 `project.godot` tail + ADR-0001/0008 revisions merged(G-IU-2)
- G-IU-1..5 全部執行(各自 evidence 喺對應 story 收口)
- **Salvage 零-dispatch invariant**(AC-18)+ **零 persist negative**(AC-37)+ **event→cue mapping**(AC-29)三條紀律 AC 全過
- Test evidence:unit `tests/unit/inventory_ui/` / integration `tests/integration/inventory_ui/`

## Next Step

Run `/create-stories inventory-ui` to break this epic into implementable stories.
