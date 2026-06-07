# Story 017: G-LM-4a — #15 revealed/sync state 分離 + ceremony kind 持久化 + #15 errata

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — ①②②b⑦ + errata ×9 appendix;#15 existing suite 217/217 零變紅;combined 2062/2061/0 fail;commit 2646d25)
> **Layer**: Presentation(epic)/ 改動喺 Core #15
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(G-LM-4 ①②⑦ + Rule 2「Grep-verified 警告」)
**ADR**: ADR-0003(`loot.pending`/`loot.committed` namespace 語意)+ ADR-0002(backend ACK 時序)
**Engine**: Godot 4.6 | **Risk**: MEDIUM(改 shipped #15 — combined CI gate 必行)

**Control Manifest Rules**:
- Required:`pending_since_server` authoritative(C15);enum string-name serialization
- Forbidden:backend ACK 將 unrevealed drop 移出 reveal queue;reveal dequeue skip `pending`→`committed` rename

## Acceptance Criteria(G-LM-4 ①②⑦ spec — #15-side unit tests)

- [ ] **① revealed-state / sync-state 分離**:shipped `_pending_drops`(`loot_drop_system.gd:766-779`)雙語意拆解 — `revealed` flag 或雙 namespace;backend ACK(秒級,跑贏 reveal)**永不**令未 reveal drop 由 reveal queue 蒸發;reveal dequeue **永不** skip commit rename(#15 AC-34 保持)— ordering test:ACK 先到、reveal 後到 → 件仍喺 reveal queue、照 reveal、dequeue 唔 skip rename(AC-71 ordering case 嘅 #15-side 基礎)
- [ ] **② ceremony kind 持久化**:`LootDrop` record 加 ceremony field(FULL_CEREMONY / MICRO_ACK,string-name serialize;`LootEnums.CeremonyDecision` 已存在直接用);`get_pending_drops()` 對 reveal flow 只回 FULL_CEREMONY 件(micro_ack 件行 Rule 9 banking 路徑,唔入 reveal queue);migration:既有 record 無 field → default FULL_CEREMONY
- [ ] **②b breakdown 載體持久化(story-008 發現 gap,2026-06-07 fold in — ⑧ 同 class)**:#15 grant 時將 `workout_score` / `rng_roll` / `rarity_score` 寫入 record pinned `item_metadata` keys(shipped grant path 計完即棄 `loot_drop_system.gd:344-353`,record 零載體)— 冇佢 F2 breakdown bar(AC-42 整組)嘅 GIVEN 不可構造;#21-side 已實作讀 keys + missing→EC-M15 hide path(008,commit 75ff5a0)
- [ ] **⑦ #4 catalog source sync**:#4 GDD catalog source 列 `loot_fanfare_*` 觸發 caller #15 → #21 coordinator(EG-1 precedent)— doc
- [ ] **#15 GDD errata batch(×9,Bidirectional sync flags 全列)**:cancel_reveal 方向 / Visual Spec hex → art bible canonical / micro_ack 0.15s = entry beat / L204 sting → toast tick / Audio Duck 列 stale / L1082 FR-2 re-anchor / L1102 K-cap supersede / AC-18+EC-28 contact-sheet model / orbit drift cut(v0.2)
- [ ] **Combined CI gate green**(`tests/unit` + `tests/integration` 一齊跑 — #15 existing tests 唔可變紅,除 errata 對應明文修改)

## Implementation Notes

- 呢個係 G-LM-4 嘅核心 scope(唔係順帶)— story 013 backend wire 後 ACK 必然跑贏 reveal(等 safe state),冇分離 = 未 reveal drop 蒸發。
- micro_ack 件同樣寫入 `_pending_drops`(L646)— kind 持久化先分得開兩條 flow。
- Persisted payload 跟 SerializableResource envelope 慣例(C3)。

## Out of Scope

- `modal_dismissed` handler / `loot_confirmed` / `report_receive_failure`(018);GSM wiring + fast-victory ⑧(019)。

## QA Test Cases

G-LM-4 ①② gate text 係 spec ground truth;ordering test 跟 AC-71 ordering case GWT(#15-side 半)。Kind filter test:mixed queue(2 FULL + 1 MICRO)→ `get_pending_drops()` 回 2。

## Test Evidence

**Required**: `tests/unit/loot_system/test_reveal_sync_state_split.gd`(#15 test dir 慣例跟現有)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(可同 Wave 1 並行;CD 順序:doc gates 後即開 — critical path)
- Unlocks: 018
