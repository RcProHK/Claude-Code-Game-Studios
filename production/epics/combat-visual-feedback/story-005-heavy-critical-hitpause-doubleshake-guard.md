# Story 005: R-7/R-8 HEAVY/CRITICAL + F4 hit_pause + R-13 double-shake guard

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(R-7/R-8/R-13 + Formula 4 + EC-12)
**Requirement**: `TR-cvf-005`

**ADR Governing Implementation**: ADR-0009: Signal Payload Schema(primary)、ADR-0001(secondary)
**ADR Decision Summary**: #25 direct call #6 `hit_pause` 填 #6 auto-dispatch 對 HIT_HEAVY/DEATH 嘅 `pause=0` 缺口;shake **靠 #6 auto-dispatch**(#25 絕不 direct shake)。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `#5.play(HIT_HEAVY)` → #5 emit `burst_started` → #6 auto-dispatch `shake(0.4, 0.12)`(grep-verified screen_effects:203 dispatch table HIT_HEAVY pause=0);`#6.hit_pause(d)` clamp ≤ MAX_PAUSE_SEC=0.12 + max-remaining merge。

**Control Manifest Rules (Presentation)**:
- Required: shake 經 #6 auto-dispatch;#25 只 direct `hit_pause`
- Forbidden: `ScreenEffects.shake(` 喺 #25 source(R-13 — AC-11 grep 守)
- Guardrail: hit_pause 值 ≤ 0.12(唔觸發 #6 clamp warning)

---

## Acceptance Criteria

*From GDD R-7/R-8/R-13 + Formula 4:*

- [x] **AC-06**:HEAVY NORMAL_HIT → `play(HIT_HEAVY)`×1 + `hit_pause(0.065)`×1 + FakeScreenFx.shakes==0(test_heavy_plays_pause_and_never_direct_shakes)
- [x] **AC-07a(flash ratified)**:CRITICAL CRITICAL_HIT `_overlay_enabled=true` → `play(HIT_HEAVY)` + `hit_pause(0.080)` + `_overlay_state==FLASHING`(test_critical_ratified_flashes_and_pauses_080)
- [x] **AC-07b(EC-20 degrade)**:同上 `_overlay_enabled=false` → `hit_pause(0.100)` + overlay IDLE + number×1(test_critical_degrade_no_flash_pause_100)
- [x] **AC-11(R-13 MUST-NOT-REGRESS,static/CI)**:`tools/ci/check_cvf_no_direct_shake.gd` PASS(0 `.shake(`)+ `tests/static/test_cvf_ci_lint.gd` 2/2(real source 0 + fixture flagged)。pattern `\.shake\s*\(` single-file scope #25,owner 唔需 exempt
- [x] **AC-22(Formula 4)**:`CombatVisualFeedbackFormulas.hit_pause_sec` pure-static:(NORMAL,HEAVY)→0.065 / (CRITICAL_HIT,CRITICAL)→0.080 / lower→0.0 / degrade CRITICAL→0.100(4 test)

---

## Implementation Notes

*Derived from ADR-0009/0001:*

- HEAVY/CRITICAL → `play(HIT_HEAVY)`(closed library 無 HIT_CRITICAL,共用);#6 因 burst auto-dispatch shake 0.4 —— #25 **唔掂 shake**。
- #25 **direct** `hit_pause(Formula 4 值)` 填缺口:HEAVY 0.065 / CRITICAL 0.080 / degrade-mode CRITICAL 0.100。
- F4 pure static func(`hit_pause_sec(outcome, damage_tier)` — KILLED 分支留 story 006)。
- AC-11 CI lint:grep `src/autoload/combat_visual_feedback.gd` 零 `ScreenEffects.shake(`;owner 唔需 exempt(只掃 #25 single file,非 gateway)。pattern 處理 whitespace。

---

## Out of Scope

- Story 006: KILLED/OVERKILL F4 分支
- Story 010: overlay FLASHING 真渲染(本 story 只驗 overlay 狀態 enter)
- Story 007: number style

---

## QA Test Cases

- **AC-06**: HEAVY
  - Given: `damage_tier=HEAVY, outcome=NORMAL_HIT`
  - When: route
  - Then: `play(HIT_HEAVY)`×1 + `hit_pause(0.065)`×1 + spy `#6.shake` direct==0
- **AC-07a/07b**: CRITICAL ratified vs degrade
  - Given: `damage_tier=CRITICAL`, `overlay_enabled` true / false
  - When: route
  - Then: true→`hit_pause(0.080)`+overlay FLASHING;false→`hit_pause(0.100)`+overlay 不 FLASHING
- **AC-11**: R-13 grep
  - Given: #25 source
  - When: grep `ScreenEffects.shake(`
  - Then: 0 results
- **AC-22**: F4 lookup
  - Given: (outcome,tier) 組合
  - Then: HEAVY→0.065 / CRITICAL→0.080 / lower→0.0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat_visual_feedback/test_cvf_heavy_critical_pause.gd`(AC-06/07a/07b/22)+ static lint `tools/ci/check_cvf_no_direct_shake.gd`(AC-11)+ `tests/static/test_cvf_ci_lint.gd`
**Status**: [x] Created + green 2026-06-11 — `test_cvf_heavy_critical_pause.gd` 7/7（routing AC-06/07a/07b + F4 AC-22 ×4）+ `test_cvf_ci_lint.gd` 2/2(AC-11)+ lint exit 0。新 file:`src/core/combat_visual_feedback_formulas.gd`(F4 + wants_flash)+ `tools/ci/check_cvf_no_direct_shake.gd` + `tests/fixtures/cvf_direct_shake_violation.gd`

---

## Dependencies

- Depends on: Story 004(routing core + handler)
- Unlocks: Story 006(kill 分支共用 F4)、Story 010(overlay enter 對接)
