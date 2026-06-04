# Story 005: Formula 3 attack-pattern selection (FNV-1a anti-spam)

> **Epic**: Boss System
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/boss-system.md` — Rule 6 + Formula 3
**Requirement**: `TR-boss-005` (deterministic round-robin, posmod-hardened, zero consecutive same-pattern)

**ADR Governing Implementation**: ADR-0006 (transition_id provenance — seed source) — primary
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot `hash()` is build-dependent → use FNV-1a 32-bit `DeterministicHash.deterministic_hash(String)` (BOSS-AC-followup-19 — `res://src/utils/deterministic_hash.gd`). Golden vector `deterministic_hash("abc") == 1454761972`. `posmod()` defense-in-depth.

**Control Manifest Rules (Feature layer)**: never parse transition_id into components — use it opaquely as a seed string.

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-06**: boss with 3 patterns, 100 consecutive selections → zero consecutive same-pattern.
- [ ] **AC-20**: patterns A/B/C, transition_id="seed1", attack_count 0..99 → (a) same seed+count → same pattern (determinism); (b) zero consecutive identical.
- [ ] **AC-34**: identical (transition_id String, attack_count) → identical pattern across Web Export/Desktop/patch versions; golden `deterministic_hash("abc")==1454761972`; `(hash % len) ≥ 0` always.
- [ ] EC-11: `candidates.size()==1` → return it (anti-spam waived); EC-10: empty array → return null + ERROR.

---

## Implementation Notes

*From GDD Formula 3:*

- `seed_str = "%s_pattern_%d" % [transition_id, attack_count]`; `seed = posmod(DeterministicHash.deterministic_hash(seed_str), valid_candidates.size())`.
- `valid_candidates = candidates.filter(p.pattern_id != _last_emitted_pattern_id)`; if empty (all same id, data error) → bypass anti-spam. Update `_last_emitted_pattern_id`.
- NO `randf()`. Reset `attack_count=0` on spawn (Story 002 field).

---

## Out of Scope

- `DeterministicHash` autoload/static helper itself (followup-19 — may pre-exist; if not, a dependency story). BossRegistry empty-pattern CI lint (Story 015).

---

## QA Test Cases

- **AC-20**: Given A/B/C + seed1; When 100 iterations 0..99; Then no two consecutive equal + replay identical. Edge: same (seed,count) twice → same pattern.
- **AC-34**: assert `DeterministicHash.deterministic_hash("abc")==1454761972`; assert `(deterministic_hash(s) % n) ≥ 0`.
- **EC-11**: size==1 → returns the single pattern, no error.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/feature/boss_system/test_formula3_pattern_selection.gd` + `test_formula3_hash_determinism.gd` — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (BossFormulas), Story 001 (AttackPatternResource)
- Unlocks: None (ATTACKING-state runtime uses it)
