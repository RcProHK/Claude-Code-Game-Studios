# QA Sign-off — EnemyDirector (#14) Epic

> **Date**: 2026-06-01
> **Scope**: EnemyDirector epic, Stories 001-020 (implementable scope)
> **Verdict**: ✅ **APPROVED** (implementation-complete; 4 stories deferred on external gates)
> **Review mode**: full

> NOTE: `/team-qa` is sprint-scoped and this project uses an epic-based workflow (no
> `production/sprints/`), so this is an epic-level sign-off. The QA content is the batch
> code-review + the automated evidence below — not a separate re-run.

## Evidence Summary

| Gate | Result |
|------|--------|
| Unit + integration GUT (CI gate command `tests/unit,tests/integration`) | **1080 pass / 1 risky / 0 fail** |
| EnemyDirector + combat + static focused suite | 250/250 pass |
| EnemyDirector CI lint suite (12 scripts) | **12/12 PASS** |
| Batch code review (Stories 012-020) | godot-gdscript-specialist **APPROVED WITH SUGGESTIONS** |
| Batch testability review (Stories 012-020) | qa-tester **TESTABLE** — phantom-pass audit **CLEAN** |
| Per-story reviews (Stories 008-011) | APPROVED / TESTABLE (full-mode gates) |

## Story Status (24 total)

- **Complete ✅ (20)**: 001-020 — core class, 12-layer CI lint suite, signals + Contract 6,
  RNGFactory, anomaly rate-limiter, _on_ability_cast pipeline (GSM gate + StatSnapshot +
  catch-up/AOE mutex + full AOE loop), EnemyRegistry.tres, wave scheduler, spawn/despawn
  lifecycle, per-enemy AI FSM, locomotion + dodge + 4Hz perception, particle throttle,
  boss anchor pre-spawn/rollback/commit-cascade, enemy_killed chain + idempotency, test helpers.
- **Blocked (4)** — external gates only, NOT a quality issue:
  - 021 Wave Archetype Readability Playtest — requires real art assets
  - 022 Mobile Particle Floor Benchmark — requires mobile hardware
  - 023 Boss Anchor Latency Gate — requires #9 WST live backend (ADR-0002)
  - 024 CPU Budget Benchmark — requires ADR-0001 CPU ratification + hardware profiling

## Quality Notes

- **Anti-fabrication**: every failure path (UNKNOWN class, registry-null, dup kill, GSM gate,
  RNG-missing, clamps) emits a rate-limited anomaly — never silent. INV-1 / INV-4 use
  fail-loud `assert`, NOT runtime clamp. ADR-0005 transition_id flows verbatim to enemy_killed
  (LootDrop RNG seed). All confirmed in review.
- **Phantom-pass clean**: no test fake overrides a native Object method (the WST-epic lesson held).

## Follow-up (non-blocking)

- Story 025 (Ready, P3): batch-review polish — wave-resolve caching (mobile budget), HP int/float
  domain, + 3 qa coverage gaps (EC-30 release rate-limit, AOE-clamp×pipeline e2e, STAGGERED→DYING).

## Pre-existing debt observed (NOT this epic, fixed where cheap)

- ✅ Fixed: loot `is_private_mode` cross-file test pollution (MockPersistenceLayer gained the
  Private-Mode query — full-suite SCRIPT ERROR eliminated).
- Noted (not fixed): 1 risky test + an `AbilityId.get()` static-call parse-noise in the
  ability_system test suite — pre-existing, 0 failures, out of EnemyDirector scope.

## Sign-off

EnemyDirector epic implementable scope (20/20) is **APPROVED** for the implementation milestone.
Merged + pushed to `origin/main` (RcProHK) @ `1aa8e2a`. The 4 Blocked stories advance only when
their external gates open (art / mobile hardware / WST live backend / ADR-0001 ratification).

| Role | Sign-off |
|------|----------|
| QA (batch review + automated evidence) | [x] Approved |
| Lead (solo dev — frank) | [ ] Approved |
