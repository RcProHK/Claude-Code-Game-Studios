# Story 012: G-CS-9 + G-CS-11 — #4 catalog 9-cue co-design + linear volume setter

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation(對象係 Foundation #4 — gate-inside-epic)
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` G-CS-9/G-CS-11 rows + Rule 33 + §Audio direction(9 cue 表 + silent 名單);audio-manager.md L376(catalog freeze process)/ L197-213(Formula 2)/ L43-45(bus API)
**Requirement**: direct GDD trace

**ADR Governing Implementation**: N/A — #4 catalog process + additive setter(G-LM-8 先例)
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: SFX format = WAV mono in-memory(#4 L382 pinned);cue assets 製作隨 /asset-spec(Q-CS7)— 本 story 入表 + placeholder 容器

---

## Acceptance Criteria

- [ ] **G-CS-9**:9 個新 cue(`ui_charscreen_open/close`、`ui_equip_settle`、`ui_lock_on/off`、`ui_salvage_execute`、`ui_sheet_open/close`、`ui_toggle_flip`)event_id / priority(全 low)/ channels(mono / no-duck)入 #4 freeze 表 + `SfxCatalog.tres`;`ui_back`/`ui_error` 來源 column 補 #22
- [ ] Cue naming 慣例裁定記錄(bare `ui_*` 係 canonical;#21 `sfx_loot_*` outlier 注記)
- [ ] Voice pool 重估記錄(8 voices;IDLE 語境 ~2-3 並發 UI cue,零 contention)
- [ ] **G-CS-11**:#4 additive `set_bus_volume_linear(bus: Bus, s: float)`(內部行 Formula 2 linear→dB + clamp)— #22 禁抄 dB 數學嘅兌現面
- [ ] **#4 existing tests 零變紅** + combined CI gate green

## Implementation Notes

- 跟 G-LM-8 story 先例(catalog 表 + .tres + sign-off);audio-director sign-off 記錄喺 story close note
- `set_bus_volume_linear` = thin wrapper:`set_bus_volume_db(bus, linear_to_db_clamped(s))` — Formula 2 locus 不變(#4 own)

## Out of Scope

- Story 018:#22-side volume slider;Story 019:#22-side play_sfx assertions;audio asset 製作(/asset-spec — Q-CS7)

## QA Test Cases

- **catalog**: Given SfxCatalog.tres,When lookup 9 cue ids,Then 全部存在 + priority==LOW + mono
- **linear setter**: Given s=0.5/0/1/NaN,When set_bus_volume_linear,Then dB = Formula 2 結果(clamped;NaN → 入口 clamp/reject 行 #4 現行 EC 慣例)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/audio/`(additive)+ combined CI
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(可並行)
- Unlocks: Story 018(volume slider)/ Story 019(SFX assertions)
