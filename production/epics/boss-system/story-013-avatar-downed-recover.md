# Story 013: Avatar-downed auto-recover + grace window

> **Epic**: Boss System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06

**Completion Notes (2026-06-06)**: `src/gameplay/avatar_downed_guard.gd` (`class_name AvatarDownedGuard extends RefCounted`) + `tests/unit/boss_system/test_avatar_downed_recover.gd` (6 tests; combined 273scr/1789/1788pass/0fail/1pending). The #16-owned enforcer of EC-25「invincible avatar during boss fight」(no avatar HP system exists yet, so #16 owns this Pillar-2 rule). AC-45: (a) NO game-over/death/retry signal exists (architectural — the class has no such API), (b) auto-recover to `max(1, round(AVATAR_RECOVER_HP_FRACTION × max_hp))` (25 at 100, 1 at degenerate max_hp=1), (c)/(d) no boss/loot coupling (architectural — `in g` checks), (e) `avatar_downed` signal (consumer forwards `boss.avatar_downed` telemetry), (f) `DOWNED_INVULN_SEC` grace window suppresses the instant re-down flicker (injectable clock test: down at t=0, suppressed at t=0.3, re-down allowed at t=0.7).
- ADR N/A (Pillar-2 frictionless behaviour). Boss-fight wiring (feeding Formula 2 damage → guard) happens at integration time with #13/the avatar.

## Context

**GDD**: `design/gdd/boss-system.md` — EC-25 (avatar-downed) + Rule 16 NEVER #13 (no game-over)
**Requirement**: `TR-boss-008`-adjacent (Formula 2 live-HP consequence); no dedicated TR — covers EC-25/AC-45.

**ADR Governing Implementation**: ADR: N/A — Pillar-2 frictionless behavior spec, no architectural pattern (consumes Formula 2 + #13 HP write). References ADR-0001 (no new budget).
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: avatar is invincible (the「打唔死嘅見證者」). On HP→0: brief `downed` state → auto-recover to `max(1, round(AVATAR_RECOVER_HP_FRACTION × avatar_max_hp))` → `DOWNED_INVULN_SEC` grace window during which boss damage does NOT apply.

**Control Manifest Rules (Feature)**: Rule 16 NEVER #13 — never create/emit a game-over / death / retry screen during a workout (Pillar 2 absolute).

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-45**: avatar HP reaches 0 (e.g. degenerate `player_max_hp=1` one-shot) → (a) NO game-over/death/retry node or signal created (assert absence); (b) `downed` then auto-recover to `max(1, round(AVATAR_RECOVER_HP_FRACTION × avatar_max_hp))` (default 0.25 → 1 at max_hp=1); (c) boss does NOT enter DYING from the avatar-down event (boss death only via Rule 8); (d) loot path unaffected; (e) `boss.avatar_downed(boss_id, transition_id)` telemetry; (f) **post-recover `DOWNED_INVULN_SEC` (default 0.6s) grace window — with `player_max_hp=1` + boss damage 5, avatar does NOT immediately re-down on a within-window hit (no infinite flicker); next damage only after the window elapses.**

---

## Implementation Notes

*From GDD EC-25 + AC-45 + DOWNED_INVULN_SEC knob:*

- This consumes #13's HP-write reaching 0 (Formula 2 supplies the damage number; #13 deducts). On 0: enter downed (≈1s knockdown anim window), recover, start grace timer.
- The grace window is the texture-guard against the degenerate-low-HP flicker the live-HP reading exposed (Story 004 / EC-06). INV-5/MAX_BOSS_DAMAGE clamp (Story 004) complements it.
- Avatar progression power is NEVER lost (game-concept「缺一日 workout = 唔損 avatar 能力」honoured by recovery, not by Formula 2).

---

## Out of Scope

- **Story 004**: the damage number. #13 HP deduction (Approved). The downed ANIMATION visual-design principle (must-not-read-as-fail) = asset/Section-I scope (Pass 11 advisory followup, not this story).

---

## QA Test Cases

- **AC-45 (a)-(e)**: max_hp=1, boss damage 5 → HP 0 → no game-over node/signal (assert); downed→recover to 1; boss not DYING; loot path intact; avatar_downed telemetry.
- **AC-45 (f) grace**: after recover, apply a within-window hit → assert HP NOT 0 again (damage suppressed); advance past DOWNED_INVULN_SEC → next hit applies. Edge: AVATAR_RECOVER_HP_FRACTION=0.25 at max_hp=10 → recover 3, grace prevents the 5-damage re-down.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/feature/boss_system/test_ac45_avatar_downed_autorecover.gd` — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (Formula 2 damage)
- Unlocks: None
