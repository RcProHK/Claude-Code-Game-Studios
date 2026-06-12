# Story 014: G-TEL-3 CI-2 check_telemetry_no_pii.gd (de-id denylist 隱私命脈)

> **Epic**: Telemetry / Analytics(#28)
> **Status**: Complete
> **Layer**: Polish
> **Type**: Static-CI
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 4(de-identification)+ AC-02 + CI-2。**隱私命脈,must-not-regress**。
**ADR Governing Implementation**: ADR-N/A — CI tooling,no architectural pattern
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `tools/ci/*.gd` headless lint(exit code gate)。

**Control Manifest Rules (Polish layer)**:
- Required: forbidden-field denylist grep
- Forbidden: payload 載原始 kg / 絕對 1RM / bodyweight
- Guardrail: lint exit code gate

---

## Acceptance Criteria

- [x] `tools/ci/check_telemetry_no_pii.gd` 建立
- [x] denylist 涵蓋原始身體數據 key pattern(`weight_kg`/`bodyweight`/`one_rep_max`/`absolute_1rm`/`set_weight`/`kg_lifted` 等 13 compound key,quoted-key + bare-assign 兩形)
- [x] grep telemetry payload 構造點:任一 denylist 命中 → exit 非 0(CI fail) — probe 驗證 exit 1
- [x] 正規化/分桶值(`pr_magnitude`/`rarity_tier`/`completed_exercises_count`/`damage_dealt` in-game)**唔**誤殺(word-distinct,fixture allowlist 段全 pass)
- [x] 加入 lint sweep(workflow glob 自動)

---

## Implementation Notes

*Derived from GDD Rule 4 + AC-02:*

- denylist = forbidden field-name patterns + 直接寫原始 set weight/1RM 入 payload 嘅 pattern。
- 注意 de-id 係「只送已正規化值」—— lint 守 forbidden raw key 出現喺 payload dict literal / assignment。
- allowlist 正規化值(pr_magnitude / rarity_tier / completed_exercises_count / damage_dealt[in-game 傷害非身體]）。
- 隱私 posture:first-party-only,呢個 lint 係「數據離 device 前」嘅最後守門(EC-17 opt-out 另 Story 016)。

---

## Out of Scope

- Story 013:no-gameplay-emit lint
- Story 016:opt-out(數據離 device 與否)

---

## QA Test Cases

- **AC-1 (no PII)**:
  - Given: telemetry source(乾淨,de-id)
  - When: lint run
  - Then: exit 0
  - Edge cases: 注入 `payload["weight_kg"] = 100` → exit 非 0
- **AC-2 (allowlist 正規化值)**:
  - Given: payload 含 `pr_magnitude` / `rarity_tier` / `completed_exercises_count`
  - When: lint run
  - Then: exit 0(唔誤殺正規化值)
  - Edge cases: `damage_dealt`(in-game 傷害)唔被當身體數據

---

## Test Evidence

**Story Type**: Static-CI
**Required evidence**: lint self-test + `tests/static/` 收口
**Status**: [x] `tests/static/test_telemetry_ci_lint.gd` + fixture `telemetry_pii_violation.gd`(3 raw-body + allowlist 段);CLI probe exit 1 verified

---

## Dependencies

- Depends on: Story 003(envelope/payload 構造存在)
- Unlocks: None(must-not-regress guard)
