# Story 014: CI lint CI-MM-1..4 + AC-20/AC-25 no-fabrication audit + cadence parity

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Config/Data (Static-CI)
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` CI Lint Suite(CI-MM-1..4)/ CR-M14 / Cross-knob INV / FT-M2
**Requirement**: AC-20 / AC-25(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0010 Mirror Moment Ownership(primary — CI-MM-1 zero-tier-compute 係 ownership 命脈)
**ADR Decision Summary**: #29 holds zero tier-state(CR-M14);CI-grep 守(同 #26 AC-30 對稱守 seam 兩邊)。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: lint `tools/ci/check_mirror_moment_*.gd`;headless `--script`,exit≠0=fail(**check exit code,唔 grep FAIL**)。CI-MM-3 parity assert `MIRROR_CADENCE_SECONDS == #26.MILESTONE_CADENCE_SECONDS`。

**Control Manifest Rules (Polish layer)**:
- Required: 4 CI lint(no-tier-compute / no-particle-instantiate / cadence-data-driven+parity / persistence-namespace)
- Forbidden: lint 漏 owner file;tier-derivation in mirror_moment*.gd
- Guardrail: 每 lint exit-code-checked

---

## Acceptance Criteria

- [ ] **AC-20**(CR-M14 / CI-MM-1): static lint 掃 `src/**/mirror_moment*.gd` → 零 tier-derivation pattern(無 `S_t`/`A_t`/`D_t` threshold、無 `effective_tier=max(...)`、無 `get_stat()` derive tier);tier 只經 snapshot/signal
- [ ] **AC-25**(FT-M2): runtime audit 任何一次慶典 → 100% render field 可 trace 返 `get_evolution_snapshot()`(+ optional #17/#18 payload);無任何 fabricated field
- [ ] **CI-MM-2**:#29 source 零直接 `GPUParticles2D` instantiate;粒子只經 `#5.play()`
- [ ] **CI-MM-3**:`MIRROR_CADENCE_SECONDS` 等 cadence 常數 load from `mirror_moment_config.tres`,零 hardcoded literal in `.gd`;+ **parity assert `== #26.MILESTONE_CADENCE_SECONDS`**(Cross-knob INV)
- [ ] **CI-MM-4**:#29 persistence write 只落 `mirror_moment.*`,零 write `avatar.*`(CR-M13 + ownership)

---

## Implementation Notes

*Derived from CI Lint Suite + AC-25 no-fabrication audit:*

- 4 lint `tools/ci/check_mirror_moment_*.gd`:CI-MM-1 no-tier-compute / CI-MM-2 no-particle-instantiate / CI-MM-3 cadence-data-driven+parity / CI-MM-4 persistence-namespace。
- **CI-MM-1 = ADR-0010 ownership 命脈**(同 #26 AC-30 對稱守 render-vs-ceremony seam 兩邊):grep `src/**/mirror_moment*.gd` 零 tier-derivation literal/pattern。
- **CI-MM-3 parity**:`MIRROR_CADENCE_SECONDS == #26.MILESTONE_CADENCE_SECONDS` hard assert（registry-5b — story 001 registry,本 story code assert）。
- **AC-25 runtime audit**:每 render field 有 trace 返 snapshot(+ #17/#18 payload),無 fabricated(FT-M2 — 同 #26 CR-6 anti-fabrication 對稱)。
- lint exit-code-checked(reference_lint_allowlist);grep owner file 防 main RED。

---

## Out of Scope

- 各 CR 行為實現(本 story 只 lint + audit enforcement)
- #26 CR-17/AC-30(對稱 lint,#26 epic)

---

## QA Test Cases

- **AC-20 (CI-MM-1)**: zero tier-compute
  - Given: 違規 fixture(`effective_tier=max(...)` / `get_stat()` derive in mirror_moment*.gd)
  - When: run lint
  - Then: exit≠0;clean → exit==0
- **CI-MM-2/3/4**: lint enforcement
  - Given: 違規 fixture(direct GPUParticles2D / hardcoded cadence / avatar.* write)
  - When: run lint
  - Then: exit≠0 on violation;CI-MM-3 parity mismatch fires
- **AC-25**: no-fabrication audit
  - Given: runtime ceremony
  - When: audit render fields
  - Then: 100% trace 返 snapshot(+ #17/#18);零 fabricated

---

## Test Evidence

**Story Type**: Config/Data (Static-CI)
**Required evidence**: lint scripts 存在 + green(`tools/ci/check_mirror_moment_*.gd` exit 0 clean);violation-fixture exit≠0;AC-25 audit test `tests/integration/mirror_moment/no_fabrication_audit_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002-013(lint targets 實現後)/ Story 001(cadence registry)
- Unlocks: epic 收線(static gate)
