# Story 006: R-9/R-10 kill branch + critical-kill carve-out + OVERKILL

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(R-9/R-10 + Formula 4 KILLED 分支 + EC-05/06)
**Requirement**: `TR-cvf-006`

**ADR Governing Implementation**: ADR-0009: Signal Payload Schema(primary)
**ADR Decision Summary**: 擊殺 outcome 先 gate(R-3);enemy death VFX 係 #14 own(#25 唔 `play(DEATH)`、唔 direct shake);#25 補 flash/pause climax 層。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: #14 DEATH burst → #6 auto-dispatch shake 0.3(grep screen_effects:205 DEATH pause=0)。exact-HP hit = KILLED 非 OVERKILL(grep combat_resolver:335 overkill_excess=0)。

**Control Manifest Rules (Presentation)**:
- Required: outcome gate FIRST;KILLED 分支 consult `damage_tier` 決定 carve-out
- Forbidden: `play(DEATH)`(= #14 own)/ direct shake(#14 DEATH auto 0.3,重做 = double)
- Guardrail: 招牌「critical 劈死」spectacle 可達

---

## Acceptance Criteria

*From GDD R-9/R-10 + Formula 4:*

- [x] **AC-08**:KILLED 且 tier<CRITICAL → number×1 + play×0 + shake direct×0 + hit_pause×0 + overlay IDLE(test_killed_below_critical_number_only)
- [x] **AC-30(R-9 carve-out — MUST-NOT-REGRESS)**:KILLED 且 tier==CRITICAL → kill number×1 + `hit_pause(0.080)` + overlay FLASHING + play(DEATH)×0 + shake direct×0(test_critical_kill_carveout_flashes_and_pauses);degrade path → 0.100 + 無 flash(test_critical_kill_carveout_degrade)
- [x] **AC-09**:OVERKILL → overlay FLASHING + `hit_pause(0.080)` + number×1 + play×0 + shake direct×0(test_overkill_flashes_and_pauses)
- [x] **AC-10**:KILLED tier=HEAVY → KILLED 分支 only(hit_pause×0,無 HEAVY double;R-3 outcome-first)(test_killed_heavy_takes_kill_branch_no_heavy_double)
- [x] **EC-05/06**:outcome gate 蓋過 tier(EC-05 單 number 單 pause 無 double,test_ec05);`KILLED+NEGLIGIBLE` → kill number 唔 silent(EC-06,test_ec06)

---

## Implementation Notes

*Derived from ADR-0009:*

- `_route_kill(payload)`:always 彈 kill/overkill-confirm number;`if outcome == OVERKILL OR damage_tier == CRITICAL: hit_pause(0.080) + overlay FLASHING`(F4 KILLED 分支:`KILLED & CRITICAL → 0.080; else 0.0`)。
- **絕不** `play(DEATH)`(#14 own)、**絕不** direct shake(#14 DEATH auto 0.3)。flash/pause 屬 #25,additive 無重疊。
- R-3 gate 確保 KILLED+HEAVY 唔行 tier 分支(無 HEAVY 65ms double)。

---

## Out of Scope

- Story 010: overlay FLASHING 真渲染
- Story 008: dedup(KILLED + enemy_killed 同 fire)

---

## QA Test Cases

- **AC-08 / AC-30**: KILLED tier split
  - Given: `outcome=KILLED`, `damage_tier` < CRITICAL(then ==CRITICAL)
  - When: route
  - Then: <CRITICAL → number×1 + hit_pause×0 + overlay 不 FLASHING;==CRITICAL → number×1 + hit_pause(0.080) + overlay FLASHING
  - Edge cases: `play(DEATH)`×0 + `#6.shake` direct×0(兩 case)
- **AC-09**: OVERKILL
  - Given: `outcome=OVERKILL`
  - Then: overlay FLASHING + hit_pause(0.080) + number×1 + play(DEATH)×0 + shake direct×0
- **AC-10**: outcome-first
  - Given: `outcome=KILLED, damage_tier=HEAVY`
  - Then: KILLED 分支 only(hit_pause×0)
  - Edge cases: EC-06 `KILLED+NEGLIGIBLE` → kill number(唔 silent)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat_visual_feedback/test_cvf_kill_branch.gd`(AC-08/09/10/30 + EC-05/06)
**Status**: [x] Created + green 2026-06-11 — `test_cvf_kill_branch.gd` 7/7(AC-08/30/30-degrade/09/10/EC-06/EC-05)。`_route_kill` 接 F4+wants_flash(story 005 已 implement full kill-branch);全 cvf unit 20/20;全 .gd lint exit 0

---

## Dependencies

- Depends on: Story 004(outcome gate)、Story 005(F4 + hit_pause)
- Unlocks: Story 010(overlay enter)
