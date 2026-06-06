# Story 002: Autoload 骨架 + wiring gates(G-PR-3 / G-PR-6 / CI whitelist)

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(Rule 10 / States)
**ADR Governing Implementation**: ADR-0008(G-PR-3 insertion)+ ADR-0011 §D-4(caller path);secondary ADR-0006 C4
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:autoload sequential boot(Contract 4);untyped DI seams(typed Node compile-time member check fail — project memory)
- Forbidden:`src/feature/` path(phantom — ADR-0011 §D-4)

## Acceptance Criteria

- [ ] **AC-27**:load `pr.state` **先於** subscribe #2;`_ready` 完結時 READY(synchronous,INITIALISING 唔跨 frame)
- [ ] `PrDetection` autoload 登記 `project.godot`(append 鏈尾,AttentionBudget 之後;constraint `#2 ≺ #10 ≺ StatSystem ≺ {AbilitySystem, WST} ≺ PrDetection` — **現行相對次序不變**)
- [ ] **G-PR-3**:ADR-0008 focused amendment(insertion rule;**同 #19 G-Z-1 一齊寫** — `Persistence ≺ WST ≺ ZoneSystem` tail append,一次 amendment 兩個 insertion;#28 Telemetry 仍排最尾)
- [ ] **CI whitelist amend**:`tools/ci/check_stat_mutation_callers.gd` L35 `res://src/feature/pr_detection.gd` → `res://src/autoload/pr_detection.gd`
- [ ] **G-PR-6**:`persistence_layer.gd:291-294` VALID_NAMESPACES 加 `"pr."` 一行 + #3 GDD Rule 12 registry 一行 + namespace lint **create-or-amend**(`check_key_namespace_convention` 未 shipped — #3 GDD L128 spec'd;create 或記 follow-up)

## Implementation Notes

- `src/autoload/pr_detection.gd`:skeleton + INITIALISING/READY + 8 個 untyped DI seams stub(#2 / baseline mock / #10 / #11 / telemetry / persistence / handler spies / GSM)。
- Telemetry:`_telemetry_log: Array[Dictionary]` append-log + `_emit_telemetry(event: String, data: Dictionary)` + `get_telemetry()`(#15/#17 **verbatim** — `String` 唔係 StringName)。
- ⚠️ lead-programmer escalation(**唔喺本 story scope**,記 follow-up):lint regex `StatSystem\.` literal 被 DI 慣例繞過 + 2/4 whitelist stale = vacuous — 獨立 CI-tooling story。

## Out of Scope

- 判定邏輯(004/005)/ G-PR-5 #12 改動(012)/ #9 改動(014)。

## QA Test Cases

GDD AC-27(injection order assert + READY synchronous)。Edge:boot 載入 corrupt envelope(交 003 cover)。

## Test Evidence

**Required**:`tests/unit/pr_detection/test_boot_lifecycle.gd`;CI lints pass(whitelist amend 後 `check_stat_mutation_callers` green)。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(可同 001 並行)
- Unlocks: 003-011(全部要 autoload 骨架)
