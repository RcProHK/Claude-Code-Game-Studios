# Inventory UI (#23)

> **Status**: In Design(skeleton — fresh-session `/design-system inventory-ui` 由此 resume)
> **Author**: frank + design-system pipeline
> **Last Updated**: 2026-06-07
> **Implements Pillar**: Pillar 1(provenance 收據庫)· 支援 Pillar 3(loot 整理 — 唔搶 #21 ceremony)

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

[To be designed]

## Player Fantasy

[To be designed]

## Detailed Design

### Core Rules

[To be designed]

### States and Transitions

[To be designed]

### Interactions with Other Systems

[To be designed]

## Formulas

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
