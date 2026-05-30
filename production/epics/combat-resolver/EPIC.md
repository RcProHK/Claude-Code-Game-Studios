# Epic: Combat Resolver

> **Layer**: Core
> **GDD**: design/gdd/combat-resolver.md
> **Architecture Module**: CombatResolver (`src/core/combat_resolver.gd` — NOT autoload; stateless pure-function class)
> **Status**: Implemented (8/10 Complete; Story 009 Blocked #14, Story 010 Blocked ADR-0001)
> **Stories**: 10 stories — 8 Complete, 2 Blocked

## Overview

CombatResolver 係 Mirror Hero 嘅 Pillar 3（Drop Euphoria）PRIMARY substrate，實現「DNF 重擊指揮家」fantasy — 每次 hit 都有 crisp damage math 確保打擊感。佢係完全 **stateless pure-function** 架構：`resolve_hit(attacker, ability_id, target) → HitResult`，唔持有任何 mutable member variables。所有 stat reads 係 O(1)（直接讀 StatSystem），冇 side effects。Hit pause coordination 透過 ScreenEffects（唔係 frame skip）確保流暢。CPU budget ≤1.0ms per combat tick（Web Export 硬性約束）。4-layer CI lint defense（purity / autoload / engine-singleton-ref / randf-ban）確保 pure-function 架構唔被污染。係 anti-fabrication quintet 第四件套延伸嘅 combat math 核心。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001 (Proposed ⚠️) | Web Export Budget Caps — CPU ≤1.0ms per combat tick (FR-3) | MEDIUM |
| ADR-0005 (Proposed ⚠️) | Loot Rarity Formula — `enemy_killed.transition_id` → #15 LootDrop chain binding (FR-2) | LOW |
| ADR-0006 Contract 6 (Accepted ✅) | `connect_for_initial_state` for EnemyDirector subscription pattern | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-combat-001 | Stateless pure-function combat math (no stored mutable state) | ADR-0006 ✅ |
| TR-combat-002 | Hit pause coordination via ScreenEffects (not frame skip) | ADR-0001 ⚠️ |
| TR-combat-003 | CPU budget ≤1.0ms per combat tick (Web Export constraint) | ADR-0001 ⚠️ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 20 TR-combat-* entries.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/combat-resolver.md` (37 ACs: 30 BLOCKING + 6 ADVISORY + 1 ADR-RATIFICATION-GATED) verified
- Logic stories: all 5 damage formula unit tests in `tests/unit/combat/` — deterministic, no random seeds
- Pure-function purity test: CI lint scan confirms no member variable mutation in `resolve_hit()`
- CPU budget benchmark: resolve_hit timing test < 1.0ms per call on WASM target
- `randf()` CI ban enforced: no direct RNG calls inside CombatResolver (loot RNG owned by LootDrop)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [ci-lints-purity-defense](story-001-ci-lints-purity-defense.md) | Static | ✅ Complete | ADR-0006 C12 |
| 002 | [data-structures](story-002-data-structures.md) | Logic | ✅ Complete | ADR-0006 C3, ADR-0007 |
| 003 | [formula1-pipeline](story-003-formula1-pipeline.md) | Logic | ✅ Complete | ADR-0006 C12 |
| 004 | [crit-system-formulas](story-004-crit-system-formulas.md) | Logic | ✅ Complete | ADR-0006 C12 |
| 005 | [damage-tier-overkill](story-005-damage-tier-overkill.md) | Logic | ✅ Complete | ADR-0006 C12 |
| 006 | [purity-snapshot-aoe](story-006-purity-snapshot-aoe.md) | Logic | ✅ Complete | ADR-0006 C12 |
| 007 | [rng-safety-aoe-boundary](story-007-rng-safety-aoe-boundary.md) | Logic | ✅ Complete | ADR-0006 C12 |
| 008 | [defensive-guards](story-008-defensive-guards.md) | Logic | ✅ Complete | ADR-0006 C12 |
| 009 | [enemy-director-integration](story-009-enemy-director-integration.md) | Integration | **Blocked** | ADR-0006 C6 (#14 required) |
| 010 | [adr-ratification-gated](story-010-adr-ratification-gated.md) | Logic | **Blocked** | ADR-0001 ⚠️ Proposed |

## Next Step

Run `/story-readiness production/epics/combat-resolver/story-001-ci-lints-purity-defense.md` to begin.

> Work through stories in dependency order: 001 → 002 → 003 → 004 → 005 → 006 → 007 → 008. Stories 009-010 BLOCKED.
> **Key**: CombatResolver is NOT an autoload. `class_name CombatResolver extends RefCounted`, ALL methods `static func`. File: `src/core/combat_resolver.gd`.
