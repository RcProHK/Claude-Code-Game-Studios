# Story 003: BossFormulas + Formula 1 boss_max_hp_scaling

> **Epic**: Boss System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-05

**Completion Notes (2026-06-05)**: `src/formulas/boss_formulas.gd` (`class_name BossFormulas extends RefCounted`, pure static) + `tests/unit/boss_system/test_formula1_hp_scaling.gd` (13 tests; combined 260scr/1709/1708pass/0fail/1pending AC-37).
- **Dependency correction**: Story 003 depends on Story 001 ONLY — `compute_max_hp` takes the snapshot value as a param, NOT from BossInstance, so it does NOT depend on Story 002. (003 was wrongly listed as depending on 002.)
- **SIGNATURE DEVIATION (shipped-code-driven)**: GDD's `compute_max_hp(template, snapshot: CombatResolver.StatSnapshot)` is NOT implementable — shipped `CombatResolver.StatSnapshot` (combat_resolver.gd:142) carries ONLY `attack_power` + `crit_chance`, NO `workout_duration_sec` (and NO `max_hp`). Implemented as pure scalars `compute_max_hp(base_hp: int, player_attack_power: float, workout_duration_sec: float) -> int` (matches GP-F9「static func taking explicit inputs」). Caller sources base_hp from template, attack_power from snapshot, workout_duration_sec from #9 WorkoutSummaryRO. GDD signature reconciliation = non-blocking #16 doc-sync followup.
- Split out `compute_effective_atk(...)` as its own static func so AC-41 (a)-(d) can test the ramp intermediate (the first-session cap=180 masks effective_atk in the final HP — the INERT-knob effect).
- **⚠️ CROSS-STORY FLAG for Story 004 / 002 / 007**: Formula 2 needs `player_max_hp`, ALSO absent from `CombatResolver.StatSnapshot`. The boss player snapshot (Story 002 field / Story 007 caller-pass) must carry `max_hp` — either a richer boss-specific snapshot OR pass `player_max_hp` as a scalar to `compute_attack_damage`. Resolve at Story 004/002/007.
- Knobs are `const` in BossFormulas (MVP; data-driven .tres = post-MVP refinement).

## Context

**GDD**: `design/gdd/boss-system.md` — Formula 1 + GP-F9 BossFormulas contract
**Requirement**: `TR-boss-007` (boss_max_hp_scaling clamped [MIN_BOSS_HP, MAX_BOSS_HP])

**ADR Governing Implementation**: ADR-0001 (Web Export Budget — scaling envelope) — primary
**ADR Decision Summary**: budget caps; design-time scaling values; CPU numbers Provisional (VS-tier gated, not a story blocker for pure math).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `class_name BossFormulas extends RefCounted` @ `res://src/formulas/boss_formulas.gd` — stateless, all `static func`, NO autoload access, NO `_emit_telemetry` (AC-41(e) static-grep surrogate via `check_boss_formulas_purity.gd`). Signature: `compute_max_hp(template: BossTemplate, snapshot: CombatResolver.StatSnapshot) -> int`.

**Control Manifest Rules (Feature layer)**: Required — pure static helper, telemetry emitted by the BossSystem CALLER (Story 007), never by the formula.

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-17**: player_attack_power=159, base_hp=200, TARGET_KILL_HITS_FINAL=9, HP_SCALE_FACTOR=1.0 → `boss_max_hp == 1631 ± 1`.
- [ ] **AC-18**: ATTACK_POWER=4500 → ceiling clamp `boss_max_hp == MAX_BOSS_HP=10000`; TEST-ONLY synthetic `base_hp=1` + atk>0 → floor clamp to `MIN_BOSS_HP=50` (defensive future-config guard).
- [ ] **AC-41**: `player_attack_power == 0` bootstrap branch — workout_duration_sec {0,300,600,1200} → effective_atk {10,14,28,28}; F2 first-session cap `max(min(boss_max_hp, FIRST_SESSION_EXPECTED_HIT_DAMAGE × FIRST_SESSION_KILL_HITS_MAX), MIN_BOSS_HP)`. AC-41(e): the `boss.first_session_bootstrap` telemetry is NOT emitted from `compute_max_hp` (static-grep: `boss_formulas.gd` 0× `_emit_telemetry`).
- [ ] Invariants hold: INV-9b (`FIRST_SESSION_KILL_HITS_MAX ≤ TARGET_KILL_HITS_FINAL`, range-enforced [8,9]≤[9,15]); INV-9c (`HIT_DMG.lo 10 × KILL_HITS.lo 8 = 80 ≥ MIN_BOSS_HP.hi 80`); INV-3 (`MIN_BOSS_HP < MAX_BOSS_HP`).

---

## Implementation Notes

*From GDD Formula 1:*

- `boss_max_hp_raw = base_hp + (effective_atk × TARGET_KILL_HITS_FINAL × HP_SCALE_FACTOR)`; `clamp(raw, MIN_BOSS_HP, MAX_BOSS_HP)`. `TARGET_KILL_HITS_FINAL` (the [9,15] knob), NOT the generic mini label.
- Bootstrap branch (`player_attack_power == 0`): `duration_factor = clampf(workout_duration_sec / FIRST_SESSION_DURATION_TARGET_SEC, 0, 1)`; `effective_atk = max(BOOTSTRAP_ATTACK_POWER, duration_factor × FIRST_SESSION_BASELINE_ATK)`; then floor-safe F2 cap. Ramp knobs are ⚠️INERT at default (cap 180 < base_hp 200 always binds) — keep but note Followup #26.
- Reads `snapshot.attack_power` — NEVER live-queries StatSystem (CF-3).

---

## Out of Scope

- **Story 004**: Formula 2 damage. **Story 007**: the `boss.first_session_bootstrap` / `boss.scaling_clamp` telemetry emit (BossSystem scope). **Story 015**: `check_boss_formulas_purity.gd` CI lint.

---

## QA Test Cases

- **AC-17**: Given atk=159/base=200/hits=9/scale=1.0; When compute_max_hp; Then 1631±1.
- **AC-18 ceiling**: atk=4500 → 10000. **floor**: synthetic base_hp=1, atk>0 → 50. Edge: exactly raw==MAX → no clamp side-effect double-count.
- **AC-41 (a)-(d)**: duration {0,300,600,1200} → effective_atk {10,14,28,28}. Edge: duration=1200 ramp saturates at 28 (clampf to 1.0).
- **AC-41(e)**: static assert `boss_formulas.gd` contains 0 occurrences of `_emit_telemetry` and 0 of `BossSystem`.
- Deterministic, no randomness, no time-dependency (pure static).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/feature/boss_system/test_formula1_hp_scaling.gd` + `tests/unit/feature/boss_system/test_formula1_clamps.gd` + `test_ac41_first_session_bootstrap.gd` — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (BossTemplate), Story 002 (snapshot field type)
- Unlocks: Story 004, Story 007
