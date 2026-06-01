# Retrospective — EnemyDirector (#14) Epic (Autonomous Run)

> **Date**: 2026-06-01
> **Scope**: EnemyDirector epic Stories 001-020 (Stories 008-020 done this session)
> **Mode**: autonomous run — user directive 「不用再問,全部繼續做,做到完為止」
> **Outcome**: 20/20 Ready stories Complete; 24 commits pushed to origin/main @ 1aa8e2a

## What went well 👍

- **Verification-driven gate held.** Every story closed only on GUT-green + CI-lint-green.
  Running tests locally caught real bugs that passed code-review-by-eye (parse errors,
  value-type traps, lint violations) — the load-bearing quality mechanism.
- **DI-seam discipline paid off.** Untyped injection seams (`_combat_resolver`, `_avatar_source`,
  `_spawn_sink`, `_wst_source`, etc.) made otherwise-unmockable things testable — notably the
  STATIC `CombatResolver.resolve_hit` (mocked via `_combat_resolver` seam).
- **Anti-fabrication consistently applied.** UNKNOWN→STRIKE, registry-null, dup-kill, clamps all
  emit anomalies; INV-1/INV-4 fail-loud asserts instead of silent clamps. Both reviewers praised this.
- **Phantom-pass lesson stuck.** Zero test fakes overrode native Object methods (the WST-epic trap).
- **Lint-as-contract worked.** The 12-layer lint suite caught a real boss-transition violation
  (direct `_boss_anchor_state = <non-IDLE>`), forcing the correct `_transition_boss_anchor` helper.

## What didn't 👎

- **Per-story test runs missed whole directories.** I ran `tests/unit/enemy_director` +
  `tests/integration/combat` per story but NOT `tests/integration/enemy_director` or `tests/static`
  — so latent breakage (Story 008 evolving `_on_ability_cast` broke an older Story-005 test's
  FakeGSM; Stories 010/014/015 unblocking stale "const absent" static asserts) sat undetected
  until a late full-suite run. **The CI gate runs `tests/unit,tests/integration` COMBINED** — I
  should have matched it from story 008 onward.
- **Deferred reviews piled up.** Stories 012-020 deferred code-review to a "batch" — fine given
  the directive, but it meant 9 stories' architecture went unreviewed until the end (all passed,
  but the risk window was real).
- **Cross-file test pollution lurked.** The loot `is_private_mode` issue was a shared-mock interface
  gap surfaced only by full-suite ordering — a class of bug per-system runs structurally cannot catch.

## Action items 🎯

1. **Always run the CI gate command (`-gdir=tests/unit,tests/integration -ginclude_subdirs`)
   before declaring a story green** — not just the story's own directory. (Highest value.)
2. **Shared test mocks must implement the FULL consumer interface**, not just the methods one
   epic happens to call (MockPersistenceLayer lesson). Audit shared mocks when a new consumer lands.
3. **When deferring reviews in an autonomous run, batch-review at natural checkpoints** (e.g. every
   3-4 stories) rather than all-at-end, to shrink the risk window.
4. **Story 025** captures the non-blocking polish/coverage follow-ups; pick up before the next
   epic that touches EnemyDirector.

## Velocity note

13 stories (008-020) + 1 epic-doc + 1 follow-up story + 1 cross-epic fix in one session, all
GUT-green and pushed. The fixed loop (readiness → implement → test → GUT → commit) scaled well;
the bottleneck was the late discovery of out-of-scope test directories (action item 1 fixes that).
