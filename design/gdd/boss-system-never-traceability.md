# Boss System (#16) — Rule 16 NEVER → AC Traceability Matrix

> **AC-40 evidence** (Story 015). Every Rule 16 NEVER (13 items) maps to ≥1 covering
> AC — runtime test, CI lint, or architectural assertion. Zero NEVERs are「lint-only」
> without a runtime/arch check. Source: `design/gdd/boss-system.md` Rule 16 + Section H.

| NEVER | Statement (abbrev.) | Covered by AC | Coverage type |
|-------|---------------------|---------------|---------------|
| #1 | spawn without #14 BossAnchor commit transition_id | AC-26 (empty txn reject), AC-37 (chain) | runtime |
| #2 | fabricate a non-STRIKE fallback when class UNKNOWN | AC-13 (UNKNOWN→STRIKE explicit) | runtime |
| #3 | generate own transition_id | AC-08 (verbatim payload.transition_id), AC-37 | runtime |
| #4 | allow boss HP < MIN_BOSS_HP floor | AC-18 (floor clamp), CF-1 | runtime |
| #5 | allow boss damage > MAX_BOSS_DAMAGE ceiling | AC-19 (texture-guard / anti-flicker ceiling), CF-2 | runtime |
| #6 | guarantee a loot drop without enemy_killed emission | AC-09 (floor flag only — #15 emits), AC-11b (enemy_killed→DYING wiring) | runtime |
| #7 | spawn multiple final-bosses concurrently | AC-25 (idempotency — exactly one BossInstance) | runtime |
| #8 | mutate BossTemplate at runtime | AC-01 (immutable @export schema) | runtime + lint (AC-16) |
| #9 | permit player-input mutation of boss state | (no input API on boss; auto-play combat — Pillar 2) | architectural |
| #10 | persist boss instance HP/position — EXCEPT the DD#1 record | AC-12 (persist whitelist grep), AC-42/AC-46 (DD#1 exact-restore) | lint + runtime |
| #11 | spawn boss from a non-workout trigger | AC-26 (empty txn) + EC-23 empty-workout (AC-26 / spawn-selection gate Story 008) | runtime |
| #12 | allow mini-boss visual to exceed final-boss intensity | AC-24 (reveal_ritual_intensity ≤ 1.0 < #5 ceiling 1.5) | runtime |
| #13 | display game-over / death / retry screen during a workout | AC-45 (avatar-downed auto-recover — assert NO such node/signal) | runtime |

**Coverage**: 13/13 NEVERs covered. 12 have a runtime/lint test; NEVER #9 is an
architectural assertion (the boss exposes no player-input mutation API — combat is
auto-play, Pillar 2). AC-16 (CI lint sweep) + AC-12 (persist grep) are ADVISORY
until the followup-08 CI tooling lands, at which point they promote to BLOCKING.

**Status**: Last reconciled 2026-06-06 (Story 015). Re-verify when Rule 16 changes.
