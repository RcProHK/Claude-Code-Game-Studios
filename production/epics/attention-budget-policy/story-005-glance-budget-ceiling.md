# Story 005: Glance budget ceiling + Formula 3

> **Epic**: Attention Budget & Interaction Policy
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (~2h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/attention-budget-policy.md`
**Requirement**: `TR-ab-???`（glance budget cross-system ceiling）
**ADR Governing Implementation**: N/A — cross-system const + boundary check（GDD Rule 8 / Formula 3）；無 architectural pattern ADR。
**ADR Decision Summary**: N/A。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: debug helper 用 `OS.is_debug_build()` + `push_error`，**唔用 `assert()`**（design-review godot R-5；release build no-op）。

**Control Manifest Rules (Core layer, v2026-05-29)**:
- Required: data-driven tuning const（GDD Tuning Knobs）
- Guardrail: glance helper = design-time / instrumented-playtest only，**非** per-frame runtime gate

---

## Acceptance Criteria

*From GDD `attention-budget-policy.md`, Rule 8 + Formula 3:*

- [ ] **AC-13（Formula 3 boundary）**：`GLANCE_BUDGET_CEILING_MS == 2000`；`glance_within_budget(2001)` → `false`；`glance_within_budget(2000)` → `true`。
- [ ] `GLANCE_BUDGET_CEILING_MS` tuning const（default 2000，safe [800, 3000]）落地 data-driven。
- [ ] `assert_glance_within_budget(element_id, measured_ms)` debug helper：debug build `measured_ms > ceiling` → `push_error`；release build no-op（`OS.is_debug_build()` gate，非 `assert()`）。

---

## Implementation Notes

*Derived from GDD Rule 8 + Formula 3:*

```
glance_within_budget(measured_ms) = measured_ms <= GLANCE_BUDGET_CEILING_MS
```

- `GLANCE_BUDGET_CEILING_MS := 2000`（cross-system 上限；#20 HUD 自己 own 更嚴 0.3s 餘光 — 呢個係 cross-system hard cap，唔取代 #20 嘅）。
- `glance_within_budget(measured_ms: int) -> bool` = pure static / const-folding。
- `assert_glance_within_budget(element_id: StringName, measured_ms: int) -> void`：`if OS.is_debug_build() and measured_ms > GLANCE_BUDGET_CEILING_MS: push_error("glance budget exceeded: %s = %dms" % [element_id, measured_ms])`。release no-op（早 return）。
- Enforcement = design-time AC + instrumented playtest（tachistoscope / observed glance），**非** runtime block（EC-9：量度 >2000ms = AC fail，唔係 runtime block）。

---

## Out of Scope

- 真實 glance 量度 / playtest protocol —— consumer（#20 HUD）playtest 階段做（AC-V-1 等）；本 story 只提供 const + boundary predicate + debug helper。
- #20 自己嘅 0.3s 餘光 budget —— #20 own。

---

## QA Test Cases

*GDD-derived。*

- **AC-13 boundary**: Given GLANCE_BUDGET_CEILING_MS==2000; When glance_within_budget(2000) / (2001) / (300); Then `true` / `false` / `true`. Edge: glance_within_budget(0) → true；負值（理論上唔出現）→ true（≤ ceiling）。
- **const value**: Given GLANCE_BUDGET_CEILING_MS; When 讀; Then == 2000。
- **assert helper (debug)**: Given OS.is_debug_build()==true（test 環境）; When assert_glance_within_budget(&"hud_hp", 2500); Then push_error 被觸發（capture via test）。When measured 1500; Then 無 error。
- **assert helper (release no-op)**: 文件化 — release build 早 return，無 push_error（headless 難測，標 structural / code-inspection）。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/attention-budget/test_glance_budget_ceiling.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（autoload surface 攞 const）DONE
- Unlocks: None
