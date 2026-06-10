# Story 006: CR-M4 pending-milestone latch + persist (tier-up never lost)

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` CR-M4 / EC-MM-2/3 / N-2 相位差註記
**Requirement**: AC-09(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0003 Save State Strategy(primary — persist latch)· ADR-0009(signal payload)
**ADR Decision Summary**: IPersistence;immediate persist latch 防丟失;payload minimal+intrinsic。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 收 `#26.avatar_evolution_milestone(tier, source_metrics)` → set latch + 即 persist(`mirror_moment.*`)。

**Control Manifest Rules (Polish layer)**:
- Required: milestone → latch + 即時 persist(跨 session/crash 保住)
- Forbidden: latch 喺呈現前清(只呈現成功後清,CR-M9)
- Guardrail: `week_had_change` sticky boolean(吸收 N-2 相位差)

---

## Acceptance Criteria

- [ ] **AC-09**(CR-M4): 收到 `avatar_evolution_milestone(2, m)` → 玩家從未入 non-workout context 兼 app 被 kill 重開 → boot read `mirror_moment.*` 後 `pending_evolution_ceremony==true` ∧ `pending_tier==2`,下次 IDLE flush 呈現(**tier-up 永不失落**)
- [ ] CR-M4 latch:收 milestone → set `pending_evolution_ceremony=true` + `pending_tier=tier` + `pending_source_metrics=source_metrics` + **即時 persist**;latch 喺慶典**成功呈現後**先清(CR-M9)
- [ ] `avatar_micro_evolution` → `week_had_change=true`(sticky boolean,呈現後清)
- [ ] EC-MM-3:玩家每次練完即 quit(從未入 IDLE)→ pending 跨 session 持久 → 下次任何 safe-context open flush(永不失落)
- [ ] N-2 相位差:`week_had_change` sticky — 收 micro/milestone 置 true,只呈現後清 → 吸收 #26 account-anchored vs #29 ceremony-anchored cadence 相位偏移

---

## Implementation Notes

*Derived from CR-M4 + N-2 相位差註記:*

- 收 milestone → latch + immediate `PersistenceLayer.write("mirror_moment", ...)`(防玩家成週唔開 game / crash 丟失 tier-up)。
- `week_had_change` sticky boolean:micro/milestone 置 true,**只呈現後清**(CR-M9,story 012)— stickiness 吸收 #26(account_created_unix 錨)vs #29(last_ceremony_unix 錨)相位差,確保上次慶典後收過任何 micro → window 開時 REFLECTION 必觸發。
- idempotent:重 set true = no-op。

---

## Out of Scope

- Story 008:persistence schema 細節(本 story 用 write API)
- Story 012:CR-M9 latch 清除(呈現後)
- Story 007:collapse(多 milestone 折一次)

---

## QA Test Cases

- **AC-09**: tier-up never lost
  - Given: 收 milestone(2),玩家從未入 IDLE,app kill 重開
  - When: boot read mirror_moment.*
  - Then: pending==true ∧ pending_tier==2;下次 IDLE flush
  - Edge cases: EC-MM-3 練完即 quit 跨 session persist
- **N-2**: sticky week_had_change
  - Given: 收 micro 後 cadence window 開
  - When: arm
  - Then: week_had_change 仍 true(只呈現後清)→ REFLECTION 觸發

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/mirror_moment/pending_latch_test.gd` — MockPersistenceLayer 注入 add_child 前;kill-reopen persist case
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(FSM + subscription)/ Story 008(persistence schema — 可 mock 先行)
- Unlocks: Story 007(latch → collapse)/ Story 012(呈現後清 latch)
