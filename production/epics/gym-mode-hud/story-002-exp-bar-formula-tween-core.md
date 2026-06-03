# Story 002: EXP bar + Formula 1/2 + tween core + reduce_motion

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/gym-mode-hud.md` (Formulas F1/F2, CR-2, CR-3) · **UX**: `design/ux/gym-mode-hud.md` (P-02/P-03/P-10)
**Requirement**: GDD AC-F1 / AC-F2 / AC-CR-2 (no TR-ID — cite GDD AC-ID)

**ADR Governing Implementation**: ADR-0001 Web Export Budget Caps (primary)
**ADR Decision Summary**: 常駐 overlay 須遵 draw-call/frame budget;`max_concurrent_tweens=6` burst cap 防 mobile WASM GC stutter。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: HIGH (web budget)
**Engine Notes**: animation 用 Godot 4 **`SceneTreeTween`**(`create_tween()`,SceneTree 自管,唔經 node `_process`);idle-0-cost 靠 tween 完成即釋放 + `_active_tween_count` 歸 0(**非** toggle `set_process`)。

**Control Manifest Rules (Presentation layer)**:
- Required: 事件驅動 motion only;config-const(唔 hardcode magic number)
- Forbidden: idle 持續 tween;`_process` poll
- Guardrail: `max_concurrent_tweens` cap;reduce_motion master override

---

## Acceptance Criteria

- [ ] **AC-F1**:`340/500` → `exp_fill==0.68`;`500/500` → `1.0`;`exp_to_next=0`(EC-F1)→ `max(0,1)=1`、fill==1.0 無 NaN;`current_exp=-5`(EC-F3)→ sanitize 後 0.0。
- [ ] **AC-F2**:`reduce_motion==false` → `tween_duration==base(0.3)`;`==true` → `==0.0`(瞬間 set)。
- [ ] **AC-CR-2(counter-seam + value-stability + cap)**:tween settle 後 idle 500ms → `node.is_processing()==false` AND `_active_tween_count==0` AND bar `value` delta==0;同幀注入 `max_concurrent_tweens+2` motion → `_active_tween_count ≤ max_concurrent_tweens`(讀 config const)。

---

## Implementation Notes

- F1:`exp_fill = clamp(current_exp / max(exp_to_next, 1), 0.0, 1.0)`,內嵌 `max(.,1)` div-guard 係 load-bearing;EC-F3 sanitize **兩個** input(`current_exp`+`exp_to_next` 各 `max(.,0)`)係 pre-call guard,兩者並存。
- F2:`tween_duration = reduce_motion ? 0.0 : base_tween_duration`(離散)。
- EXP bar = P-02 frameless-hud-bar(≥`min_bar_height_px=4`);step ticker = P-03(33ms/格);popup = P-10 overshoot 1.1×。
- `_active_tween_count` 係 SUT-maintained counter seam(Godot 4 無 public processed-tween count API),test 可讀。
- `max_concurrent_tweens=6` 超 cap → 低優先 motion 降級瞬間 `set`(skip tween)。
- reduce_motion master override:bar step→snap、popup overshoot→定位、應 derive 自 #6 `motion_intensity`(co-design,Story 011 wire)。

---

## Out of Scope

- Story 003:circuit-breaker / handle-map / `_on_tween_finished` seam / zero-floor(本 story 只立 basic tween + counter)。
- Story 004:HP bar(本 story 只 EXP)。
- Story 008:◐ emphasis alpha(本 story tween 唔理 emphasis level)。

---

## QA Test Cases

- **AC-F1**:Given F1 純 static func;When 注入 (340,500)/(500,500)/(c,0)/(-5,500);Then == 0.68/1.0/1.0/0.0;Edge: NaN/INF(EC-F4)→ fallback 上一 confirmed,boot-time first NaN → 0.0。
- **AC-F2**:Given F2 純 func;When reduce_motion T/F;Then 0.0 / 0.3;Edge: base out-of-range → clamp safe range。
- **AC-CR-2**:Given 注入 1 個 stat_changed 起 tween;When settle + idle 500ms;Then `is_processing()==false` AND `_active_tween_count==0` AND value delta==0;Edge: 同幀 `max_concurrent_tweens+2` 事件 → count ≤ 6(讀 const,非字面);超額瞬間 set。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gym_mode_hud/test_exp_bar_formula_tween.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scaffold + dispatch)
- Unlocks: Story 003 (circuit-breaker 疊喺 tween core)
