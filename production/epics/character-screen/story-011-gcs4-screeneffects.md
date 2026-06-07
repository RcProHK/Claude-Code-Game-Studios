# Story 011: G-CS-4 — #6 boot self-read + preview API(shake-only)

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation(對象係 Foundation #6 — gate-inside-epic)
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` G-CS-4 row + Rules 29/30;screen_effects.gd L95(SettingsManager seam 留位)/ L194(HIT_HEAVY preset internal)/ L388-394(state reject + clamp + non-finite reject)
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0003(boot read settings key)
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: **preview = shake-only,不含 `hit_pause`**(hit_pause `get_tree().paused=true` — #22 layer PAUSABLE 會 freeze 自己 mid-drag;godot verifier 補)

---

## Acceptance Criteria

- [ ] (a)#6 `_ready()` self-read `settings.motion_intensity` 並 apply(documented default 1.0;non-finite reject-and-retain 現行為保留)
- [ ] (b)`preview_hit_heavy()`(或等效)public API — 用 internal HIT_HEAVY preset params,#22 唔 hardcode magic numbers;**shake-only**
- [ ] retrigger 唔疊(cancel-restart — EC-26 consumer 行為前提)
- [ ] **#6 existing tests 零變紅**(parity 準則 — producer directive)+ combined CI gate green

## Implementation Notes

- Boot read 行 consumer-self-read convention(GDD Rule 29 — 無 SettingsManager autoload);#6 BOOTING state 時 PersistenceLayer 已 ready(ADR-0008 位置先後)
- Preview API 內部 = `shake(HIT_HEAVY.intensity, HIT_HEAVY.duration)` 等效 — 唔開新 shake path(single-owner seam)

## Out of Scope

- Story 018:#22-side slider wiring;Q-F5 hud_shake_inclusion(v0.2)

## QA Test Cases

- **boot read**: Given persisted 0.68,When #6 _ready,Then motion_intensity==0.68;Given 冇 key,Then 1.0
- **preview**: Given ACTIVE,When preview_hit_heavy() ×2 快速,Then 唔疊(第二次 restart);When motion_intensity==0,Then 零 visible motion(short-circuit 保留)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/screen_effects/`(additive cases)+ #6 existing suite 零變紅 + combined CI
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 003(namespace)
- Unlocks: Story 018(AC-37 preview)
