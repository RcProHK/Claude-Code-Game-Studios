# Story 011: Formula 3 — milestone two-gate + epoch-zero guard

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` Formula 3 / CR-5 / EC-MILE-1 / EC-TIER-4
**Requirement**: AC-08(GDD 直接 trace)
**ADR Governing Implementation**: N/A — pure formula(milestone gate logic);secondary ADR-0009(milestone payload)
**ADR Decision Summary**: N/A pure deterministic gate;`avatar_evolution_milestone(tier, source_metrics)` payload schema(ADR-0009)。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: wallclock cadence(`MILESTONE_CADENCE_SECONDS`=604800)是 explicit time-dependence(CI-INV-5 allowed exception);epoch-zero guard 防 backfill false-fire。

**Control Manifest Rules (Presentation layer)**:
- Required: two-gate(promotion + cadence/first-boot + non-workout);epoch-zero guard
- Forbidden: naive cadence test on `last_emit_unix==0`(backfill leak);absorb-on-suppress
- Guardrail: gate_c defer(NOT drop)mid-workout

---

## Acceptance Criteria

- [ ] **AC-08**: fresh account `last_emit_unix=0` + backfill mapping to T1 + 0 observed session → NO milestone(epoch-zero guard:需 ≥1 session AND ≥48h)
- [ ] Formula 3:`should_emit = gate_a ∧ gate_b ∧ gate_c`;`gate_a = current_tier > last_emitted_tier`;`gate_b = (last_emit_unix==0) ? (sessions≥MIN_OBSERVED_SESSIONS ∧ (now−account_created)≥FIRST_BOOT_GRACE_SECONDS) : (now−last_emit)≥MILESTONE_CADENCE_SECONDS`;`gate_c = gsm_state ∉ {WORKOUT_ACTIVE, REST_PERIOD}`
- [ ] CR-5「two-gate」label = 3 sub-gate(promotion + cadence/first-boot + non-workout-defer)— N-1 advisory:label 對齊文字描述
- [ ] EC-MILE-1:tier-up gate pass 但 cadence fail → **suppress-only**(no emit,`last_emitted_tier` 不變,cadence 過後自然 emit);**NO absorb**(寫 last_emitted_tier=current = ceremony 永久蒸發,違 EC-MILE-5)
- [ ] EC-TIER-4:tier jump T1→T3 → emit ONE milestone `{tier:T3, skipped_tiers:[T2]}`(本 story gate 決定 should_emit;emit 喺 story 012)

---

## Implementation Notes

*Derived from Formula 3(epoch-zero guard kept from Pass-2 F-1):*

- **epoch-zero guard 命脈**:fresh account `last_emit_unix==0` 令 naive `now−0≈55yr>cadence` 永過 → GymSys backfill 可喺玩家做一 rep 前 fire tier-up ceremony(Pillar-1 cosplay leak)。gate_b first-boot branch 要 ≥1 observed session AND ≥48h since account creation。AC-08 = regression guard。
- gate_c=false → defer(story 012 `_pending_milestone`),NOT drop。
- **N-1 advisory**:CR-5「two-gate」措辭對齊實際 3 sub-gate(promotion/cadence/non-workout)。
- EC-MILE-1 suppress-only(唔 absorb)= P5 ritual integrity。

---

## Out of Scope

- Story 012:milestone emit / defer / pending buffer(本 story 只算 should_emit gate)
- Story 004:tier 計算(本 story 接受 current_tier)

---

## QA Test Cases

- **AC-08**: epoch-zero guard
  - Given: last_emit_unix=0,backfill→T1,0 sessions
  - When: Formula 3
  - Then: NO emit(gate_b first-boot fail)
  - Edge cases: golden table(T2/T1/800000/IDLE→emit;T1/T1→suppress;T2/T1/300000→suppress cadence;T2/T1/800000/WORKOUT_ACTIVE→defer;epoch-zero→suppress)
- **EC-MILE-1**: suppress-only
  - Given: gate_a true,cadence fail
  - When: gate
  - Then: no emit,last_emitted_tier 不變(下次 cadence 過自然 emit)
  - Edge cases: 確認無 absorb write

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/avatar_renderer/formula3_milestone_gate_test.gd` — injected clock;golden table 含 epoch-zero + suppress-only;deterministic
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004(tier value)/ Story 009(persisted counters)
- Unlocks: Story 012(emit 用 gate result)
