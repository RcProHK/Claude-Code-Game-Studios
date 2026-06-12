# Story 013: G-TEL-2 CI-1 check_telemetry_no_gameplay_emit.gd (pure observer 命脈)

> **Epic**: Telemetry / Analytics(#28)
> **Status**: Complete
> **Layer**: Polish
> **Type**: Static-CI
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 1(pure observer)+ AC-01 + CI-1。**Pillar 2 / anti-fabrication 命脈,must-not-regress**。
**ADR Governing Implementation**: ADR-N/A — CI tooling(gateway lint),no architectural pattern
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GUT collects `test_*.gd`;CI lint 係 `tools/ci/*.gd` headless script(exit code gate)。

**Control Manifest Rules (Polish layer)**:
- Required: gateway lint grep owner file(防 self-match)
- Forbidden: telemetry emit gameplay signal / call upstream mutator
- Guardrail: lint check exit code 唔係 grep FAIL([[feedback_lint_allowlist_adr_sync]])

---

## Acceptance Criteria

- [x] `tools/ci/check_telemetry_no_gameplay_emit.gd` 建立
- [x] grep `src/autoload/telemetry.gd` + `src/telemetry/*`:零 `emit_signal(<gameplay signal>)`、零 upstream 系統 mutating-method call、零 write 去 `loot.*`/`stat.*`/`ability.*`/`streak.*`
- [x] 違反 → exit code 非 0(CI fail) — probe 驗證 exit 1 + 3 detection (namespace/mutator/emit)
- [x] lint **owner-exempt** 正確:telemetry 自身 diagnostic meta-event(`telemetry_self_error` 等非 gameplay signal)唔誤殺(`OWNED_META` allowlist;fixture 2 owned-meta emit 唔計)
- [x] 加入 `tools/ci/*.gd` lint sweep(workflow glob loop 自動 pick-up,無需 manual sync)

---

## Implementation Notes

*Derived from GDD Rule 1 + AC-01:*

- denylist:`emit_signal\(` 後接非-telemetry-internal signal name + gameplay namespace write pattern。
- **owner-exempt 關鍵**:telemetry **可以** emit 自己嘅 derived meta(`duplicate_transition_observed` / `out_of_order_observed` / `telemetry_self_error` / `dropped_count`)—— 呢啲係 telemetry-internal,**唔係** gameplay signal。lint 要分清(allowlist telemetry-owned meta names)。
- 同款命脈 lint 先例:#27 G-OB-2 `check_onboarding_no_gameplay_mutator.gd` / #29 CI-MM-1 / #25 R-13 no-shake lint。

---

## Out of Scope

- Story 014:no-PII denylist lint
- Story 015:frozen-schema lint

---

## QA Test Cases

- **AC-1 (no gameplay emit)**:
  - Given: telemetry source(乾淨)
  - When: lint run
  - Then: exit 0
  - Edge cases: 注入一行 `emit_signal("loot_dropped", ...)` 或 `Stat.apply_stat_delta(...)` → exit 非 0
- **AC-2 (owner-exempt)**:
  - Given: telemetry emit `telemetry_self_error` / `duplicate_transition_observed`(telemetry-owned meta)
  - When: lint run
  - Then: exit 0(唔誤殺 telemetry-internal meta)
  - Edge cases: gameplay namespace write 仍被 catch

---

## Test Evidence

**Story Type**: Static-CI
**Required evidence**: lint script self-test + `tests/static/` 收口(exit code 0 on clean,非 0 on violation)
**Status**: [x] `tests/static/test_telemetry_ci_lint.gd`(6 tests/106 asserts)+ fixture `tests/fixtures/telemetry_gameplay_emit_violation.gd`;CLI probe exit 1 verified

---

## Dependencies

- Depends on: Story 002(telemetry.gd 存在)
- Unlocks: None(must-not-regress guard,愈早愈好)
