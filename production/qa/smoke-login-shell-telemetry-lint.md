# Smoke — Story 017: G-LS-9 telemetry lint + errata cluster (#24 / AC-25)

> **Story**: `production/epics/login-shell/story-017-telemetry-lint-errata.md`
> **Type**: Config/Data (Static-CI + doc) — evidence = CI lint step + doc-errata confirmation
> **Date**: 2026-06-09
> **Verifier**: local (Godot not required — pure shell lint + Markdown doc edits)

## AC-25 [GATED → now satisfied]

### 1. Lint created + scope extended to UI-class autoload coordinators

- **File**: `tools/ci/check_no_ui_subscribes_telemetry.sh` (created)
- **Scope** (the #2 L120 erratum fix — closes the zero-coverage false green):
  - `src/ui/**/*.gd`
  - `src/autoload/*_coordinator.gd` (#21 loot_reveal, #22 character_screen, #23 inventory_ui, #24 login_shell)
- **Forbidden signals (11)** — ground truth `design/gdd/gymsys-backend-client.md` L120:
  10 telemetry-class (`protocol_error`, `dropped_poll_tick`, `session_evicted_by_browser`,
  `persistence_volatile`, `inflight_cap_breached`, `logout_drain_timeout`, `tombstones_trimmed`,
  `persistence_quota_exhausted`, `drain_in_progress`, `dropped_event`) + 1 test-seam (`substate_changed`).
- **Two checks**:
  - **A — ban-list**: no forbidden signal `.connect(`-ed anywhere in scope (both Godot 4
    `SIGNAL.connect(` form and Godot 3 string `.connect("SIGNAL"` form).
  - **B — #24 default-deny whitelist**: every `.connect(` signal token on
    `login_shell_coordinator.gd` must be a known-legit signal (3 #2 lifecycle +
    4 Rule-5 error-consumer). GSM `state_changed` is bound via
    `connect_for_initial_state` (not `.connect`) → naturally excluded.

### 2. Verification runs (exit-code based — NOT grep FAIL, per lint_allowlist_adr_sync)

| Run | Expected | Actual |
|-----|----------|--------|
| `sh tools/ci/check_no_ui_subscribes_telemetry.sh` (clean tree) | PASS, exit 0 | **PASS, exit 0** ✅ |
| Positive control A — inject `protocol_error.connect(` into a `src/ui/` probe file | exit 1 | **exit 1** ✅ (flagged `protocol_error.connect`) |
| Positive control B — inject non-whitelisted `some_random_signal.connect(` on #24 | exit 1 | **exit 1** ✅ (flagged `some_random_signal`, default-deny) |
| Re-run after revert | PASS, exit 0 | **PASS, exit 0** ✅ |

Probe artifacts cleaned up; no stray files left in `src/`.

### 3. CI integration

- `.github/workflows/tests.yml` auto-discovers `tools/ci/*.sh` (L70 `for lint in tools/ci/*.sh`)
  and checks each script's exit code (L73-77) — no explicit registration needed.
  Exit 1 blocks merge.

## Errata cluster confirmation

### #2 L120 scope erratum (`design/gdd/gymsys-backend-client.md`)
- Added an ERRATUM note: lint scope must include `src/autoload/*_coordinator.gd`, not just
  `src/ui/**` (zero-coverage false green). Documents the shipped two-check design.

### #8 L755 / signature erratum (`design/gdd/streak-system.md`)
- Signal declaration corrected to **two-param** `streak_persistence_failed(error_code: String, key: String)`.
- Ground truth verified: `src/autoload/streak_system.gd` decl L70; emit L193 `.emit("DRIFT_GATE_REJECTED", "")`,
  L403 `.emit(error_code, key)`; #24 consumer handler `login_shell_coordinator.gd:334`
  `_on_streak_error(error_code, key)` — all two-param, consistent.
- Central ERRATUM note added blanket-superseding remaining single-param mentions
  (Failed-state row, Section B narrative, downstream-contract table, AC-10/AC-26 prose)
  without rewriting tested AC semantics.
- #24 downstream-contract table row updated to two-param + status `Implemented`.

## Out of scope (per story)
- Story 016 banner/credential/clock grep — separate lint (`check_login_shell_static_discipline.gd`).

**Result: AC-25 SATISFIED — lint live + scope-correct + both errata recorded against grep-verified ground truth.**
