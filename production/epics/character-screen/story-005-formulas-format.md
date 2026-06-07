# Story 005: F2 quantize + F3 picker sort + F4 badge + Format Table + font floor

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)— char_screen_formulas.gd(F2 ingestion guard + bijectivity round-trip test / F3 strict total order / F4 / Format Table / CJK_FONT_FLOOR_PX guard);14 tests。Lesson:GDScript format string 內「100%」要 %% escape
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — F2(含 NaN ingestion guard — sd B-2)/ F3(strict total order + divergence note)/ F4(formatter-based predicate)/ Per-stat Format Table / EC-12/24/25/28
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0007(RarityTier enum 喺 F3)secondary;主體 N/A — pure formulas
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `clampf(NaN)` IEEE 穿透 → guard 先行;`roundi` half-away-from-zero;F3 `String(a.item_id) < String(b.item_id)` 顯式 cast(StringName `<` 唔保證 lexicographic)

---

## Acceptance Criteria(GDD AC-05..09 + 43a)

- [ ] **AC-05**:0.6789/0.999/−0.5/1.7 → pct 68/100/0/100;**NaN/+inf/−inf/String → default 1.0,零 trap**
- [ ] **AC-06**:clamp no-op 唔 wrap;55+10→65
- [ ] **AC-07**:F3 golden vector `[axe_b, sword_a, bow_c]`;byte-identical determinism
- [ ] **AC-08**:{90.4,90.0}→hidden /{90.6,90.0}→「+90 / +91(受真身上限約束)」/{0,0}→hidden +「+0」render
- [ ] **AC-09**:7 stat Format Table golden vectors(「7%」「210」等)
- [ ] **AC-43a**:theme font sizes introspect — CJK body ≥12px Zpix floor

## Implementation Notes

- F2:guard → clamp → roundi → int pct canonical;1% grid pinned(bijectivity);keyboard ±10 clampi
- F3:rarity desc → acquired desc(**desc 新先 — intentional divergence from #17 `_candidate_beats` asc**,L786-796)→ item_id asc final
- F4:`disp(x)=roundi(x)`;badge_visible = disp(raw) > disp(effective) — 同文案同一 formatter
- 建議檔:`src/ui/character_screen/char_screen_formulas.gd` static funcs(#21 loot_reveal_formulas 先例)

## Out of Scope

- Story 017:picker UI(F3 嘅 consumer);Story 018:slider UI(F2 consumer);Story 014:badge render(F4 consumer)

## QA Test Cases

GDD AC-05..09/43a GWT 直接 embed;edge cases:F2 0.075 binary-inexact 紀律 / F3 同秒 batch tie / F4 .5 雙邊 {90.5,89.5}

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/character_screen/test_char_screen_format.gd` + `test_picker_sort.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 002
- Unlocks: Story 006(fmt_s shared dep)/ 014 / 017 / 018
