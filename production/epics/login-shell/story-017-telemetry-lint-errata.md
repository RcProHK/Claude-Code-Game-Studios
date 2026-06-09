# Story 017: G-LS-9 telemetry lint + errata cluster(#2 L120 scope + #8 L755)

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Config/Data(Static-CI + doc)
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-09

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 2 + AC-25 + G-LS-9)
**Requirement**: G-LS-9 — telemetry 訂閱禁令 lint + 上游 errata cluster

**ADR Governing**: N/A — lint tooling + doc errata
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: #2 L120 lint script `check_no_ui_subscribes_telemetry.sh` 原 spec 只掃 `src/ui/**`,唔 cover UI-class autoload coordinators（#20/#22/#23/#24 全喺 `src/autoload/`）→ 直接照 spec implement = zero-coverage 假 green。

**Control Manifest Rules**:
- Required: #24 全域只訂 4 signal whitelist;11 forbidden signal 零 connect
- Required: lint sweep check exit code 唔係 grep FAIL（lint_allowlist_adr_sync lesson）

---

## Acceptance Criteria

*GDD AC-25 [GATED G-LS-9]:*

- [ ] **AC-25 [GATED]**: `tools/ci/check_no_ui_subscribes_telemetry.sh` 已創建 **且 scope 已含 UI-class autoload coordinators**（`src/autoload/` — 唔止 `src/ui/**`)→ 行 lint exit 0;coordinator 只 connect 4-signal whitelist,11 forbidden signal 零 `connect(` 痕跡
- [ ] **#2 L120 scope erratum**：lint scope 擴展涵蓋 `src/autoload/` UI coordinators（zero-coverage 假 green 修正）
- [ ] **#8 L755 erratum**：`streak_persistence_failed` 單參簽名 stale → shipped `streak_system.gd` 係雙參 `(error_code, key)`;#8 GDD doc 改

---

## Implementation Notes

- 創建 `check_no_ui_subscribes_telemetry.sh`：grep `src/autoload/` UI-class coordinators（#20/#22/#23/#24)+ `src/ui/**`,assert 只 connect `auth_required`/`drain_started`/`drain_completed`/`state_changed`,11 forbidden signal（10 TELEMETRY + 1 TEST-SEAM `substate_changed`）零 connect。
- exit-code sweep（唔 grep FAIL — lint_allowlist_adr_sync lesson）。
- 上游 doc errata：#2 L120 scope 註記 + #8 GDD L755 雙參簽名修正（#23 story-018 errata-cluster 先例)。
- **GATED**：script 創建 + scope 擴前 AC-25 GATED;生效後解封。

---

## Out of Scope

- Story 016:banner/credential/clock grep（本 story 係 telemetry-subscription lint）

---

## QA Test Cases

- **AC-25**: telemetry lint
  - Given: `check_no_ui_subscribes_telemetry.sh` 創建 + scope 含 `src/autoload/`;When: 行 lint;Then: exit 0 + coordinator 只 connect 4-signal whitelist
  - Edge cases: 注入一個 forbidden signal connect → lint exit 非 0（positive control）
- **errata**: #2 L120 scope + #8 L755
  - Given: 讀 #2/#8 GDD;Then: lint scope 含 autoload;#8 streak_persistence_failed 雙參簽名

---

## Test Evidence

**Story Type**: Config/Data(Static-CI + doc)
**Required evidence**: CI lint step(`tools/ci/check_no_ui_subscribes_telemetry.sh`)+ smoke doc errata 確認
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(coordinator — connect 對象存在)
- Unlocks: None(AC-25 解封)

---

## Completion Notes
**Completed**: 2026-06-09
**Criteria**: 3/3 passing — AC-25 (lint exit 0 + 2 positive controls), #2 L120 scope erratum, #8 streak_persistence_failed two-param erratum
**Implementation**:
- `tools/ci/check_no_ui_subscribes_telemetry.sh` (NEW) — Check A ban-list (11 forbidden signals,
  ground truth gymsys-backend-client.md L120) across `src/ui/**/*.gd` + `src/autoload/*_coordinator.gd`
  (the L120 scope erratum — coordinators that wire signals live in `src/autoload/`, not `src/ui/`,
  so the original `src/ui/**`-only scope was a zero-coverage false green). Check B = #24 default-deny
  `.connect(` whitelist (3 #2 lifecycle + 4 Rule-5 error-consumer; GSM `state_changed` via cfis excluded).
  Both matched binding forms (Godot 4 `SIGNAL.connect(` + Godot 3 string `.connect("SIGNAL"`).
- Doc errata: `design/gdd/gymsys-backend-client.md` L122 (scope correction note);
  `design/gdd/streak-system.md` L130 signal decl → two-param `(error_code, key)` + central ERRATUM
  note blanket-superseding remaining single-param mentions + L768 #24 contract row.
**Verification**: 全 10 shell CI lint PASS（含新 lint）。Positive control A (forbidden `protocol_error.connect`
in `src/ui/` probe) → exit 1; B (non-whitelisted `some_random_signal.connect` on #24) → exit 1;
revert → exit 0. Zero `src/` `.gd` changes → `.gd` lints + GUT suite unaffected.
**Deviations**: None.
**Test Evidence**: Config/Data — smoke `production/qa/smoke-login-shell-telemetry-lint.md`.
**Code Review**: Degraded-inline (full-mode harness no-spawn) — APPROVED (subshell-pipe bug fixed,
exit-code discipline per lint_allowlist_adr_sync, both positive controls demonstrated).
**Bug found+fixed during dev**: Check B initially used `echo | while … exit 1` — under `set -e` the
subshell exit would abort before the `$?` propagation check. Rewrote as a main-shell `for tok in $tokens`
loop (tokens are `[A-Za-z0-9_]`-only → safe word-split) so `status=1` persists.
