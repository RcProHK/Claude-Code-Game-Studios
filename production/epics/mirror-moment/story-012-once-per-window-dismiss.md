# Story 012: CR-M9 once-per-window + dismiss markers

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` CR-M9 / EC-MM-12/13 / States PRESENTING→DORMANT
**Requirement**: AC-16(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0003 Save State Strategy(primary — window marker persist)
**ADR Decision Summary**: IPersistence;window marker 防重呈現。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: dismiss → set `last_ceremony_unix` + 清 latch + persist。

**Control Manifest Rules (Polish layer)**:
- Required: 呈現成功後即 set window marker + 清 latch;dismiss 零摩擦
- Forbidden: 因玩家唔影相而 re-nag(影唔影相一樣標記)
- Guardrail: 同 window 唔重呈現(`CEREMONY_AUTO_DISMISS_SECONDS` default 0 manual)

---

## Acceptance Criteria

- [ ] **AC-16**(CR-M9): 慶典呈現 → 玩家 dismiss(撳✕ / backdrop / 影完相)→ `last_ceremony_unix=now` + 清 `pending` + 清 `week_had_change` + persist;同 window 唔重呈現(**影唔影相都一樣**標記)
- [ ] CR-M9:呈現成功後即 set `last_ceremony_unix=now` + `last_ceremony_tier=snapshot.tier` + 清 `pending_evolution_ceremony` + 清 `week_had_change` + persist;同 cadence window 內唔再呈現(即使再開 game)
- [ ] dismiss 方式:撳✕ / backdrop tap / 影完相 / auto-dismiss(`CEREMONY_AUTO_DISMISS_SECONDS` default 0=manual)— 全部算「呈現過」
- [ ] EC-MM-12:dismiss 唔截圖 → set marker + `mirror.share_skipped`,唔重彈;EC-MM-13:截圖後 dismiss → `mirror.shared` + last_shared_unix,window done → DORMANT

---

## Implementation Notes

*Derived from CR-M9(once-per-window, 唔 nag):*

- PRESENTING → DORMANT(dismiss):set window marker(`last_ceremony_unix`/`last_ceremony_tier`)+ 清 latch(`pending`/`week_had_change`)+ `ceremony_count++` + persist。
- **影唔影相唔影響 window marker**(Pillar 2 唔 nag — 唔可以因玩家唔影相就日日 re-nag)。
- `last_ceremony_unix` 重設 cadence window(Formula 1 `presented_this_window`)。

---

## Out of Scope

- Story 009:suspend 特例 window marker(本 story 正常 dismiss)
- Story 010:dismiss UI affordance(本 story 係 marker 邏輯)

---

## QA Test Cases

- **AC-16**: dismiss markers
  - Given: 慶典呈現
  - When: dismiss(✕/backdrop/影完相)
  - Then: last_ceremony_unix=now + 清 latch + persist;同 window 唔重呈現
  - Edge cases: 影唔影相一樣標記;再開 game window 內唔重彈

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/mirror_moment/dismiss_marker_test.gd` — MockPersistenceLayer;dismiss 各方式 + 重開唔重呈現 case
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 010(dismiss affordance)/ Story 006(latch)/ Story 008(persist)
- Unlocks: None(window done → DORMANT)
