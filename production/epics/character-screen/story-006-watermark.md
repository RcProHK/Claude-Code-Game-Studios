# Story 006: First-seen stat watermark(Rule 31 — CD 裁決 1)

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)— stat_watermark.gd(write-once ensure / formatter suppress / persist-fail {} / injected date);7/7 unit(AC-55 四翼)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — Rule 31(write-once / formatter suppress / persist-fail 唔 fabricate / 冇 history array / device-local date)
**Requirement**: direct GDD trace(CD 裁決 1 —「可見時間線」嘅 MVP 兌現)

**ADR Governing Implementation**: ADR-0003
**ADR Decision Summary**: `charscreen.*` keys 經 PersistenceLayer;Private Mode detect-and-gate。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: date = device local(同 EC-15 provenance 一致)

---

## Acceptance Criteria(GDD AC-55)

- [ ] 第一次讀 stat → `charscreen.stat_watermark.[stat_id]` = {value, date} 寫一次
- [ ] 已有 watermark → **永不覆寫**(write-once)
- [ ] `fmt_s(current)==fmt_s(watermark.value)` → 行唔 render(suppress);current 變咗 → render「⌜[date]:[fmt_s(value)]⌟」dim 行
- [ ] Persist fail(Private Mode)→ 唔 render、唔 fabricate session-only watermark

## Implementation Notes

- Suppress predicate 用 story 005 嘅 `fmt_s`(formatter-as-epsilon — 新帳號唔出「STR 47 ⌜今日:47⌟」廢話)
- **冇 history array、冇 graph** — v0.2 #28(Q-CS5);老玩家 first-seen = #22 上線日(誠實:幾時量幾時刻)
- Render 部分(dim 行 visual)係 story 009/014 嘅 stat row 組件;本 story 交付 logic + persist + predicate API

## Out of Scope

- Story 009:stat row render 整合;#28 historical comparison(v0.2)

## QA Test Cases

GDD AC-55 GWT 直接 embed:write-once(二次 open assert 原值)/ suppress(equal-formatted)/ render(diverged)/ persist-fail(mock #3 fail → 零 render 零 cache)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/character_screen/test_stat_watermark.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 003(namespace)+ Story 005(fmt_s)
- Unlocks: Story 009(render 整合)
