# Story 001: G-TEL-1 ADR-0008 boot-Last amendment + project.godot register + #14 L593 erratum

> **Epic**: Telemetry / Analytics(#28)
> **Status**: ✅ Complete(2026-06-12 — ADR-0008 amendment + project.godot register Last + stub + #14 erratum + 3 sibling Q-T1 stale-claim fixes; static GUT 4/4 + boot-order/process-mode lint PASS; import boot clean)
> **Layer**: Polish
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD(#28 未有 TR-IDs — /architecture-review Phase 8 未跑;#27 先例)— Rule 13 order-resilient late boot + Dependencies §Cross-system conflict。
**ADR Governing Implementation**: ADR-0008 Autoload Position Map(primary)
**ADR Decision Summary**: project.godot 係 autoload 絕對位置嘅 sole ground-truth;每個新 autoload 跟 reserved insertion rule。#28 Telemetry reserved「**Last** — boots after all producers」,靠 `connect_for_initial_state` order-resilience。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: autoload list 1-indexed;Telemetry 排最尾,boot 喺所有 producer 之後。

**Control Manifest Rules (Polish layer)**:
- Required: 新 autoload 跟 ADR-0008 insertion rule + boot-order CI allowlist sync
- Forbidden: 喺 `_ready()` 內 emit signal(Contract 4)
- Guardrail: boot-order lint 跟 ADR amendment 同步([[feedback_lint_allowlist_adr_sync]])

---

## Acceptance Criteria

*From GDD `design/gdd/telemetry.md`, scoped to this story:*

- [ ] ADR-0008 §insertion 加 `Telemetry` 由「reserved Last」升做 actual entry(位置 = current tail 之後,terminal)
- [ ] `project.godot` 登記 `Telemetry` autoload @ `res://src/autoload/telemetry.gd`,位置 = 全 autoload list 最尾
- [ ] boot-order CI allowlist(若有)sync 新 entry —— 唔引入 stale-enumeration phantom
- [ ] **#14 erratum 回填**:`design/gdd/enemy-director.md` L593「#28 must boot BEFORE #14」改為「#28 boots Last per ADR-0008;combat signals are runtime so late-boot catches all」(Q-T1)
- [ ] boot 乾淨(headless import + run 零 autoload 錯)

---

## Implementation Notes

*Derived from ADR-0008 + GDD Rule 13 / Dependencies:*

- **Impl-time grep current tail**:跑前 grep `project.godot` 攞現時最尾 autoload(勿硬寫某個 #編號 —— #25/#27 已陸續 tail-append;同 #27 B-2 stale-fix 教訓)。Telemetry append 喺現 tail 之後。
- **#14 erratum** 係跨 file doc edit:只改 enemy-director.md L593 一行措辭 + 註明「per ADR-0008 / telemetry.md Dependencies §Cross-system conflict」。唔改 #14 任何 signal/code 行為(契約不變,locus 移)。
- 同款 doc-only amendment 先例:#27 G-OB-1 / #29 G-MM-1 / #25 G-CV-2。

---

## Out of Scope

- Story 002:autoload scaffold + FSM(本 story 只 register 位置 + ADR/erratum doc）

---

## QA Test Cases

- **AC-1 (autoload Last)**:
  - Given: `project.godot` autoload section
  - When: 列舉 autoload 順序
  - Then: `Telemetry` 係最後一個 entry,path = `res://src/autoload/telemetry.gd`
  - Edge cases: 若將來再 tail-append 新 autoload,Telemetry 應再被推後(terminal observer 永遠最尾)— 文檔註明
- **AC-2 (#14 erratum)**:
  - Given: `design/gdd/enemy-director.md` L593
  - When: grep「boot BEFORE #14」
  - Then: 零命中;改為「boots Last per ADR-0008」措辭
  - Edge cases: 確認無其他 file 仲 cite 舊「BEFORE #14」措辭
- **AC-3 (boot clean)**:
  - Given: headless `--import` then run
  - When: 啟動
  - Then: 零 autoload error;boot-order static test(若有)green

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check pass(`production/qa/smoke-*.md`)+ boot-order static test(`tests/static/`)若存在
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None(scaffold 前提)
- Unlocks: Story 002(autoload scaffold)
