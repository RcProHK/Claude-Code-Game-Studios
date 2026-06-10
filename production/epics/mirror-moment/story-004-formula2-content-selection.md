# Story 004: Formula 2 — content_tier_selection (EVOLUTION/REFLECTION/NONE honest skip)

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` Formula 2 / CR-M2 / CR-M15 / EC-MM-18/20
**Requirement**: AC-05 / AC-06 / AC-07 / AC-08(GDD 直接 trace)
**ADR Governing Implementation**: N/A — pure formula(content selection);secondary ADR-0010(zero tier-compute)
**ADR Decision Summary**: N/A pure selection;#29 holds zero tier-state(CR-M14)— content 純由 latch boolean 選。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: content 純由 `pending_evolution_ceremony` / `week_had_change` 兩 boolean 選 — **零 tier 計算**(CI-MM-1 守)。

**Control Manifest Rules (Polish layer)**:
- Required: EVOLUTION > REFLECTION 優先序;honest no-change skip(CR-M15)
- Forbidden: tier-derivation(CR-M14);fabricate「變強咗」無真實 backing
- Guardrail: `WEEKLY_REFLECTION_ENABLED` 守 weekly cadence(default true)

---

## Acceptance Criteria

- [ ] **AC-05**: `pending_evolution_ceremony==true` → content==EVOLUTION(before→after + burst + screenshot)
- [ ] **AC-06**: `pending==false` ∧ `week_had_change==true` → content==REFLECTION(單 frame + 回顧 caption + screenshot,**無 burst**)
- [ ] **AC-07**: `pending==false` ∧ `week_had_change==false` → cadence window 開 + IDLE → **無慶典呈現**,emit `mirror.no_change_skip`(CR-M15 honest skip)
- [ ] **AC-08**: 同週既有 tier-up 又有 micro-evolution(pending ∧ week_had_change)→ content==EVOLUTION(tier-up 蓋過 micro,優先序)
- [ ] Formula 2:`content = pending ? EVOLUTION : week_had_change ? REFLECTION : NONE`;output exactly one of {EVOLUTION, REFLECTION, NONE}
- [ ] NONE 喺 ARMED 理論不可達(Formula 1 has_change gate 已擋)但作 defense-in-depth(race 令 flag 被清 → 收 overlay,當 CR-M15 skip)
- [ ] EC-MM-20:同週多次 micro signal → `week_had_change` boolean 重 set true = no-op(idempotent)

---

## Implementation Notes

*Derived from Formula 2 + CR-M15(honest skip):*

- 純 selection,**零 tier 計算**(CI-MM-1 命脈 — tier 數字只經 snapshot 讀入,story 007)。
- `WEEKLY_REFLECTION_ENABLED`(default true)守 Pillar 5 weekly:micro-only 週仍出 REFLECTION 輕慶典。
- CR-M15 honest skip:零訓練週(week_had_change false + 無 pending)→ 唔呈現 + emit `mirror.no_change_skip`;`NO_CHANGE_NUDGE_ENABLED` default false(連 nudge 都唔出)。

---

## Out of Scope

- Story 007:reveal 構圖(Formula 3 — 本 story 只選 content type)
- Story 011:celebration burst(本 story 只標記 EVOLUTION 要 burst)
- Story 013:narrative caption enrich

---

## QA Test Cases

- **AC-05/06/07/08**: content selection
  - Given: golden table(true/true→EVOLUTION;true/false→EVOLUTION;false/true→REFLECTION;false/false→NONE)
  - When: Formula 2
  - Then: content 對表;NONE → emit no_change_skip,唔呈現
  - Edge cases: 優先序 EVOLUTION>REFLECTION;EC-MM-20 idempotent micro
- **CR-M15**: honest skip
  - Given: week_had_change false + 無 pending
  - When: cadence open + IDLE
  - Then: 無慶典 + `mirror.no_change_skip`;無 nudge(default)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/mirror_moment/formula2_content_selection_test.gd` — golden table;deterministic;zero tier-compute assertion
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(FSM + latch booleans)
- Unlocks: Story 007(content → reveal)/ Story 011(EVOLUTION → burst)
