# Story 018: Settings panel — P-07 / P-08 / MASTER volume + persist 紀律

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — Rules 25-30/33 + EC-24..28 + F2 consumer;UX spec Z4 SETTINGS
**Requirement**: direct GDD trace(CD 裁決 2 volume 落地)

**ADR Governing Implementation**: ADR-0003(primary — persist timing / critical flush / Private Mode)
**ADR Decision Summary**: write on settle(debounce);**任何 close path 先 flush**;EC-27 `write(key, value, true)`;Private Mode session-only + banner。

**Engine**: Godot 4.6 | **Risk**: MEDIUM(web persist + browser throttle)
**Engine Notes**: ScreenEffects BOOTING/SUSPENDED silent reject(L388-389)— fixture 先入 ACTIVE

---

## Acceptance Criteria(GDD AC-35..40 + 52)

- [ ] **AC-35**:drag 期間 `set_motion_intensity` **per-frame ≤1 call**(coalesce locus #22-side);release final call;P-08 flip → setter + persist `settings.reduce_camera_motion`
- [ ] **AC-36**:30 tick drag 零 per-tick write;release 後 debounce window 恰好 1 次 write
- [ ] **AC-37**:pct==0 release preview 照 trigger(uniform path);drag 期間零 preview;**preview 路徑零 play_sfx**
- [ ] **AC-38**:drag 中 force-close → 當 settle,`write(key,value,true)` 先於 close;settle 後 window 內 normal close / suspend snap → 同款 flush;Private Mode → session-applied + banner suppress
- [ ] **AC-39**:persisted 0.999 → 顯示「100%」,唔即時 rewrite;settle 先 normalize
- [ ] **AC-40**:fresh install → defaults(1.0「100%」/ false)
- [ ] **AC-52**:volume slider 經 G-CS-11 linear setter(**#22 源碼零 linear_to_db / 零 dB 數學**);現值 `get_bus_volume_db(MASTER)`;零 `audio.*` write from #22;全程零 play_sfx

## Implementation Notes

- F2 quantize(story 005)做 canonical pct;keyboard ±10 clampi;ARIA announce(EC-28)wire 喺 story 019
- P-08 toggle 一掣兩 consumer:#7 setter(story 013)+ Rule 11 avatar freeze(story 009 已接 key — 本 story 接 flip 即場 path)
- Persist-fail banner 位置跟 UX spec 並發 priority 表

## Out of Scope

- Story 011/012/013:consumer-side APIs(已 unlock);Q-F5(v0.2);Story 019:ARIA

## QA Test Cases

GDD AC-35..40/52 GWT embed;mock #3(write spy + fail mode)+ mock #6(ACTIVE)+ mock #4(linear setter spy);injected clock debounce

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/character_screen/test_charscreen_settings.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 003 + 005 + 011(G-CS-4)+ 012(G-CS-11)+ 013(G-CS-2)
- Unlocks: Story 019(settings ARIA)
