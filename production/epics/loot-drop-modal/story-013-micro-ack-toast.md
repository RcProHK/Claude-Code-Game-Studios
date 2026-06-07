# Story 013: micro_ack banking + F4 toast aggregation + flush gate + EC-M17

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 9 / F4 / EC-M17)+ UX spec(toast 視覺 §E)
**ADR**: ADR-0009(payload)+ ADR-0003(stateless)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:knob config 讀(`TOAST_*` / `MERGE_MIN_REMAIN` / `FLUSH_DELAY`)
- Forbidden:toast 喺 non-safe state 顯示(#15 L1081「workout 進行中零 toast/overlay」)

## Acceptance Criteria

- [ ] **AC-24**(toast 結構):`loot_micro_ack` 到、modal 唔 active 且 GSM safe state → toast anchor 喺 edge container(parent assert)、icon + tier tint、**零 text node**、entry == `TOAST_ENTRY_SEC`、無 input handler
- [ ] **AC-25**(defer + aggregate):modal active 時 3 個 `loot_micro_ack` → 零 toast 即出;close 後 `FLUSH_DELAY`(且 safe state)出**單一**「×3」toast,tint == 最高 tier
- [ ] **AC-34b(#21-side 半)**(micro_ack banking):`loot_micro_ack(drop_id)` 到 → `receive_loot` exactly-once + `modal_dismissed(drop_id, false)` emit、零 modal/UI 動作、toast 行 F4 deferral;該件唔再出現喺 `get_pending_drops()`;variant:`FAILED_ROLLBACK` → `report_receive_failure` exactly-once(**[dequeue + report 半邊 gated G-LM-4 — fake seam]**)
- [ ] **AC-48**(F4 display):N_agg == 1/2/150 → icon+tint 無字 /「×2」/「×99+」,tint == 最高 tier
- [ ] **AC-49**(F4 merge + 守恆):remaining-to-cap ≥ `MERGE_MIN_REMAIN` 新 ack → remaining := 0.6、N_agg+1;< → 唔 merge 直入 carryover;連續 stream → 壽命 ≤`TOAST_MAX_LIFETIME` 到 cap fade + carryover 開新 toast;守恆:Σ N_agg(displayed)+ pending carryover == total acks
- [ ] **AC-68**(EC-M17 守恆):active toast N=2 時 modal 開 → 0.1s fade、count fold 入 deferred、close 後 flush 包齊 — 總數守恆 assert

## Implementation Notes

- Flush gate(F4):flush 條件 = modal 完全 close 後 `FLUSH_DELAY` **且 GSM ∈ {IDLE, REST_PERIOD, DISCONNECTED}**;唔 safe → hold + 繼續 aggregate。
- micro_ack banking 係 mid-workout data-layer call(零 UI);件唔漏入 catch-up(防 double-acknowledge / 推翻 #15 cap 決策)。
- Toast non-interactive(tappable 要過 #33 exempt,邊際價值近零);永不佔 center stage。
- `FLUSH_DELAY=0.15` 下限避開 #4 set_complete/streak_chime 80-120ms stagger window。
- Instance 時間結構:entry(0.15)→ plateau(1.2)→ fade(0.15);EC-M17 interrupt fade 0.1s 獨立值。

## Out of Scope

- Toast tick audio cue(023 G-LM-8);#15 dequeue handler(018);stash-exit deferred-ack 觸發(011 已斷言)。

## QA Test Cases

GDD AC-24/25/34b/48/49/68 GWT + pinned vectors(qa-plan-import-equivalent;守恆 assert 係 AC-49/68 ground truth)。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_micro_ack_toast.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 009
- Unlocks: 014、026
