# Story 001: G-CV-2 ADR-0008 autoload amendment + project.godot 登記

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(§Detailed Design Core Rules + Governing ADRs header)
**Requirement**: `TR-cvf-001`(無 TR-ID registry entry — trace 直接 GDD;#26 G-AR-1 先例)

**ADR Governing Implementation**: ADR-0008: Autoload Position Map(primary)
**ADR Decision Summary**: project.godot 係 autoload 絕對位置嘅 sole ground-truth;新 autoload 用 partial-order 插入,GDD 唔 hardcode 數字。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: autoload 順序由 `project.godot` `[autoload]` section 決定;tail-append 非 disruptive(唔 shift 現有)。

**Control Manifest Rules (Presentation)**:
- Required: autoload 位置經 ADR-0008 amendment 授權先寫 project.godot
- Forbidden: GDD hardcode 絕對 index 數字(v1 ghost 教訓)
- Guardrail: boot 後 GUT harness 重排乾淨(本 project 無 main scene → boot-smoke = 跑 GUT suite)

---

## Acceptance Criteria

*From GDD / EPIC G-CV-2:*

- [x] `CombatVisualFeedback` 加入 `project.godot` `[autoload]`,**tail-append after preds {#14 EnemyDirector, #6 ScreenEffects, #5 ParticleSystemWrapper, #1 GameStateMachine}** — project.godot L150 (after MirrorMomentCoordinator #29)
- [x] ADR-0008 `adr-0008-autoload-position-map.md` 加 traceability row + insertion constraint(`{#14,#6,#5,#1} ≺ CombatVisualFeedback`)— amendment header + reserved-insertion-rule row + GDD-Requirements row, all NO-#29-constraint TERMINAL
- [x] `--import` exit 0(全 script parse);GUT suite boot 乾淨(autoload harness 重排後無 crash)— IMPORT_EXIT=0;GUT 190/190 across static+inventory_ui+mirror_moment
- [x] 非 disruptive:現有 autoload 絕對位置(Camera/ScreenEffects/Avatar/coordinators)`tests/static/*_autoload_position.gd` 斷言**不變**(tail-append 唔 shift;ParticleSystemWrapper pos 13 unchanged)+ boot-order allowlist sync(check_loot_reveal_boot_order ALLOWED_SUCCESSORS + test_invui_lifecycle:131 enumeration 加 CombatVisualFeedback)

---

## Implementation Notes

*Derived from ADR-0008:*

- `CombatVisualFeedback` 係 reactive consumer:`_ready()` subscribe #14 signal + #1 GSM,boot 時需 preds 已 ready。tail-append(類 #29 MirrorMomentCoordinator)滿足 partial-order 而唔 shift 任何現有絕對位置。
- ADR-0008 map 加新 row;若有 `tests/static/test_*_autoload_position.gd` 枚舉全 autoload,加 `CombatVisualFeedback` 喺 tail(grep 全 successor allowlist — [[feedback_lint_allowlist_adr_sync]] 教訓:tail-append 要 grep 晒 boot-order lint allowlist)。
- stub `src/autoload/combat_visual_feedback.gd`(`extends Node` + `_ready()` placeholder)由 story 003 替換。

---

## Out of Scope

- Story 002: ADR-0001 CanvasLayer topology amendment
- Story 003: coordinator scaffold(替換 stub)+ cfis subscription

---

## QA Test Cases

- **AC-1**: tail-append autoload
  - Given: `project.godot` 現有 autoload 列表
  - When: 加 `CombatVisualFeedback` 喺尾
  - Then: `--import` exit 0 + GUT suite boot 無 crash
  - Edge cases: preds 任一缺席 → boot 仍唔 crash(#25 `_ready()` null-safe;story 003 驗)
- **AC-2**: 非 disruptive
  - Given: 現有 `tests/static/*_autoload_position.gd` 斷言
  - When: tail-append 後跑
  - Then: 全部 pass(無絕對位置 shift)
  - Edge cases: 若有 boot-order lint allowlist 枚舉 successor → 加 `CombatVisualFeedback`

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check pass(`--import` exit 0 + GUT combined suite boot green)+ `tests/static` autoload-position 斷言不變
**Status**: [x] Verified 2026-06-11 — smoke check pass (`--import` exit 0 + GUT 190/190 boot green) + `tests/static` position 斷言不變 + 4 autoload lints exit 0 (check_loot_reveal_boot_order / check_autoload_boot_order / check_combat_resolver_autoload [no false-match] / boot-order allowlist synced)

---

## Dependencies

- Depends on: None(scaffold 前提之一)
- Unlocks: Story 003(coordinator scaffold 需 autoload 位置已授權)
