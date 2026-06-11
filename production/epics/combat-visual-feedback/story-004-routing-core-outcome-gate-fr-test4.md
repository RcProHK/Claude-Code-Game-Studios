# Story 004: R-2/R-3 routing core — outcome-first gate + FR Test #4 tier consume

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(R-2/R-3/R-4/R-5/R-6 + EC-18)
**Requirement**: `TR-cvf-004`

**ADR Governing Implementation**: ADR-0007: Class Enum Convention(primary)、ADR-0009(secondary)
**ADR Decision Summary**: `DamageTier`/`HitOutcome` 係 #13-owned Classification enum;#25 read-only 消費。FR Test #4(inherit #13):必用 `damage_tier` 做 routing key,唔可 re-classify by value。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `match` on enum;`damage_tier` enum-typed(`DamageTier {NEGLIGIBLE,LIGHT,MEDIUM,HEAVY,CRITICAL}`);`outcome` `{NORMAL_HIT,CRITICAL_HIT,KILLED,OVERKILL}`。

**Control Manifest Rules (Presentation)**:
- Required: routing key = payload `damage_tier`(FR Test #4)
- Forbidden: 根據 `damage_dealt`/`damage_raw` re-classify tier
- Guardrail: outcome gate FIRST,tier SECOND(R-3)

---

## Acceptance Criteria

*From GDD R-2/R-3/R-4/R-5/R-6:*

- [x] **AC-02(FR Test #4 — MUST-NOT-REGRESS)**:tier=HEAVY damage_dealt=1 → `HIT_HEAVY`(test_fr_test4_heavy_tier_low_value)+ edge tier=LIGHT @999 → `HIT_LIGHT`(信 tier,**唔** re-classify)。⚠️ HEAVY/CRITICAL **preset routing**(共用 HIT_HEAVY,FR-Test-#4 surface)落 `_route_heavy` 本 story;hit_pause/flash/R-13 留 story 005(preset≠effects 拆分)
- [x] **AC-03**:NEGLIGIBLE 非 kill → play==0 AND hit_pause==0 AND number==0(test_negligible_zero_reaction)
- [x] **AC-04**:LIGHT → `play(HIT_LIGHT)` ×1 AND hit_pause ×0 AND number ×1(test_light_plays_hit_light_no_pause)
- [x] **AC-05**:MEDIUM → preset == `HIT_LIGHT`(非 HIT_HEAVY)AND hit_pause ×0(test_medium_shares_hit_light_not_heavy)
- [x] **EC-18**:damage_dealt=0 但 tier=LIGHT → 信 tier,照 play HIT_LIGHT(test_ec18_zero_value_nonzero_tier_trusts_tier)
- [x] R-3:outcome gate FIRST — `_on_hit_resolved` 先 `if outcome in {KILLED,OVERKILL}: _route_kill` 否則 `_route_tier`(kill 分支 stub→story 006)

---

## Implementation Notes

*Derived from ADR-0007/0009:*

- handler:先 `if outcome in [KILLED, OVERKILL]: _route_kill(payload)`(story 006)`else: _route_tier(payload.damage_tier, payload)`。
- `_route_tier`:`match damage_tier`:NEGLIGIBLE→零反應(R-4);LIGHT/MEDIUM→`play(HIT_LIGHT)`+number(R-5/R-6);HEAVY/CRITICAL→story 005。
- routing key **永遠** `payload.damage_tier`,絕不睇 `damage_dealt`/`damage_raw`(FR Test #4 — spy `#5.play` preset arg 驗)。
- number style 由 `is_crit`(story 007)決定;本 story 只驗 number count(唔驗 style)。

---

## Out of Scope

- Story 005: HEAVY/CRITICAL + hit_pause + R-13 guard
- Story 006: kill/overkill 分支 + carve-out
- Story 007: number style(is_crit)

---

## QA Test Cases

- **AC-02**: FR Test #4
  - Given: `hit_resolved{damage_tier=HEAVY, damage_dealt=1}`
  - When: route
  - Then: spy `#5.play` 收 `HIT_HEAVY`（信 tier）
  - Edge cases: `damage_dealt=999, damage_tier=LIGHT` → 仍 `HIT_LIGHT`(value 唔影響)
- **AC-03**: NEGLIGIBLE silent
  - Given: `damage_tier=NEGLIGIBLE`, outcome=NORMAL_HIT
  - When: route
  - Then: `#5.play`==0 AND `#6.hit_pause`==0 AND number==0
- **AC-04 / AC-05**: LIGHT / MEDIUM
  - Given: `damage_tier=LIGHT`(then MEDIUM)
  - When: route
  - Then: `play(HIT_LIGHT)`×1 + number×1 + `hit_pause`×0;MEDIUM preset==`HIT_LIGHT`(非 HIT_HEAVY)
  - Edge cases: EC-18 `damage_dealt≤0` 但 tier≠NEGLIGIBLE → 信 tier

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat_visual_feedback/test_cvf_routing_tier.gd`(AC-02/03/04/05 + EC-18;spy mock #5/#6)
**Status**: [x] Created + green 2026-06-11 — `test_cvf_routing_tier.gd` 6/6 pass(FR Test #4 ×2 + NEGLIGIBLE silent + LIGHT + MEDIUM-shares-HIT_LIGHT + EC-18);combined w/ bootstrap = 11/11

---

## Dependencies

- Depends on: Story 003(scaffold + handler 框架)
- Unlocks: Story 005(HEAVY/CRITICAL)、Story 006(kill 分支)
