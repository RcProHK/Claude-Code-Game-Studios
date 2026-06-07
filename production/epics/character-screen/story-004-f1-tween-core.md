# Story 004: F1 stat tween core — manual interpolator + injected clock

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)— stat_tween.gd(clamp u / retarget EQUIPMENT-only / settle:=v_target / arrow raw-operand pin / advance settle-tick return)+ char_screen_timing_config.gd(6 knobs);16/16 unit。Lesson:fixture 數 ease bucket 要計準(t=100 已過 0.5)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — F1(含 Pass 1 pins:clamp `u` / retarget 限 EQUIPMENT / settle:=v_target / zero-delta formatter guard / arrow operand = raw interpolated)+ EC-08/09/10/11
**Requirement**: direct GDD trace

**ADR Governing Implementation**: N/A — pure presentation formula(formatter-as-epsilon 原則);ADR-0001 budget 約束性引用
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: **唔用 engine Tween**(injected clock seam — production `_process(delta)` 同 test `advance(delta_ms)` 行同一條 code path);per-row struct `{v_from, v_target, elapsed_ms}`

**Control Manifest Rules**: 零 overshoot 係 pinned design constant(Pillar 1)— 曲線唔係 knob

---

## Acceptance Criteria(GDD AC-01..04)

- [ ] **AC-01**:v_from=84→90, t=150ms → 89.25 →「89」;單步 `advance(500)` overshoot → display「90」恰好(clamp u — 永不超 target)
- [ ] **AC-02**:mid-tween retarget → v_from:=當前 interpolated、clock 歸零、無 queue;連續 N 次後收斂最後 target
- [ ] **AC-03**:`fmt_s(v_target)==fmt_s(display)` → 無 tween 無 arrow;進行中 kill + settle 喺 v_target
- [ ] **AC-04**:A→B→A 反悔 → kill + settle v_target + arrow 清走;arrow operand = raw interpolated pin

## Implementation Notes

- `display_value(t) = fmt_s(lerp(v_from, v_target, ease_out_cubic(clampf(t/STAT_TWEEN_MS, 0, 1))))`;`STAT_TWEEN_MS` knob default 300(hard range 200-400 — #11 L696 band)
- **Retarget 只限 EQUIPMENT source**;非 EQUIPMENT mid-tween → kill + snap v_target + 清 arrow(sd B-4 — wiring 喺 story 009,本 story 提供 API:`retarget(v)` vs `snap(v)`)
- Golden vector 紀律:.5 boundary 只准 binary-exact 值
- 4-row 並行 = 獨立 instances,constant duration ⇒ lockstep settle

## Out of Scope

- Story 009:`stat_changed` signal wiring + source 分流;Story 019:settle SFX coalesce

## QA Test Cases

GDD AC-01..04 GWT 直接 embed(qa-plan-import-equivalent — QL inline ADEQUATE):每條一個 test func + edge cases(t=0 / t=STAT_TWEEN_MS / v_from==v_target / 負 delta / retarget@t=0 / band 兩端 200·400)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/character_screen/test_stat_tween.gd` — 必須 pass(GUT test_ prefix!)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 002
- Unlocks: Story 009(binding wiring)
