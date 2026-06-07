# Story 019: G-LM-4c — GSM wiring(retry-suppression)+ fast-victory marker ⑧ + GSM errata

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — ⑥⑧ + AC-37b + GSM errata ×2;**loot_confirmed 升級帶 queue_drained intrinsic arg**(defer 場景 GSM 推進但 flag 保留 — ⑥ suppression 防 same-occupancy loop);RestPeriod MIN_REVEAL_WINDOW remaining check 留 #2 transport(VS-gated TODO);GSM existing suite 零變紅;combined 2073/2072/0 fail;commit c566049)
> **Layer**: Presentation(epic)/ 改動喺 Foundation #1 + Core #15
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(G-LM-4 ⑥⑧ + Rule 13b + FSM terminal note)
**ADR**: ADR-0006(GSM Rule 13 reveal gating own)+ ADR-0009(BossPayload.outcome 載體)
**Engine**: Godot 4.6 | **Risk**: MEDIUM(改 shipped GSM — combined CI gate 必行)

**Control Manifest Rules**:
- Required:GSM-side wiring 屬 GSM own(#21 唔自建 wait queue);enum string-name serialize
- Forbidden:#21 direct call GSM

## Acceptance Criteria(G-LM-4 ⑥⑧)

- [ ] **⑥ defer/exit retry-suppression + GSM wiring**:`_check_pending_loot_reveal()`(`game_state_machine.gd:446`,現時零 caller)接線;同一 safe-state occupancy 唔准 banner 無限 re-trigger loop(defer 後唔 re-trigger,下次 safe-state entry 先);**G-flag-3 殘餘收線**:intra-queue 唔 exit 語意確認 + GSM L128「每 RestPeriod 只 drain ONE」erratum(#21 Rule 6/10 supersede)
- [ ] **⑧ fast-victory marker 持久化**:#15 grant 時讀 `BossPayload.outcome`,`INTERRUPTED_WITH_CREDIT` → 寫入 LootDrop record(field 或 pinned `item_metadata` key — shipped record 零 outcome 載體 `loot_drop.gd:39-86`;deferred reveal 下 transition payload 早冇,唯一 durable carrier 係 record)
- [ ] **AC-37b**(fast-victory variant):drop record 帶 marker → attribution slot 用「快勝」variant(fixture string assert);ceremony ladder 照 tier 不變
- [ ] **GSM GDD errata ×2**:L128 drain cadence supersede + L375(b)「未開封 item tap entry」defer v0.2(OQ-6)
- [ ] **Combined CI gate green**(GSM existing tests 唔可變紅)

## Implementation Notes

- Retry-suppression 語意:`rest_ended` force-close 保留 `loot_reveal_pending=true`(GSM L127 — shipped 對齊);suppression 只係防同一 occupancy 內 loop。
- Marker 持久化遵 C3 envelope;migration default = 無 marker(普通 source attribution)。
- 「快勝」copy variant 係 layout variant 唔係 ceremony variant(Rule 13b(c))。

## Out of Scope

- L375(b) 未開封 entry 實作(v0.2,#23);#15 handler 本體(018)。

## QA Test Cases

GDD AC-37b GWT + G-LM-4 ⑥⑧ gate text(qa-plan-import-equivalent);suppression test:defer → 同 occupancy 零 re-trigger → 新 safe-state entry re-trigger。

## Test Evidence

**Required**: `tests/integration/loot_reveal/test_gsm_wiring_fast_victory.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 018
- Unlocks: 026
