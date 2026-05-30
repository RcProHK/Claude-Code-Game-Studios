# Epic: Ability System

> **Layer**: Core
> **GDD**: design/gdd/ability-system.md
> **Architecture Module**: AbilitySystem (`src/autoload/ability_system.gd`)
> **Status**: Implemented (9/10 Complete; Story 010 Blocked on ADR-0002 + ADR-0003 + #10 GDD)
> **Stories**: 10 stories — 9 Complete, 1 Blocked

## Overview

AbilitySystem 係 Pillar 4（Muscle = Class）PRIMARY substrate，實現 class-tiered ability unlock architecture：Exercise → ExerciseClassMapping (#10) → StatSystem (#11) → AbilitySystem (#12)。管理 ability registry（`AbilityRegistry.tres` data-driven）、unlock state（PR breakthrough signal subscription）、同 cooldown tracking。`cast_ability(ability_id, caster, target)` 有 caller whitelist — **只有 `combat_resolver.gd` 可以呼叫**（CI enforced），防止能力系統被繞過。Ability unlock 透過 `PR_BREAKTHROUGH` signal subscription pattern（唔係 direct call），確保 unlock 係真實 workout 成就嘅 result。`ability.unlocked.*` namespace 係 PersistenceLayer 第二個 Core-tier adopter。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005 (Proposed ⚠️) | Loot Rarity Formula — `PR_BREAKTHROUGH` unlock formula + signal chain | LOW |
| ADR-0006 Contracts 3/4/6 (Accepted ✅) | SerializableResource + boot order pos 6 + connect_for_initial_state | LOW |
| ADR-0007 (Queued ❌) | Class Enum Naming Convention — AbilityClass STRIKE/CONTROL/MOBILITY enum MUST be locked before implementation | LOW |

> ⚠️ **ADR-0007 (Class Enum Naming) 係 HIGH PRIORITY untraced requirement** — AbilityClass enum 嘅 naming convention 未 ADR-locked。呢個 epic 嘅 class-archetype stories blocked 直至 ADR-0007 Accepted。

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ability-001 | Ability unlock via PR breakthrough signal subscription pattern | ADR-0005 ⚠️ |
| TR-ability-002 | `cast_ability()` caller whitelist — only `combat_resolver.gd` (CI enforced) | ADR-0006 Contract 12 ✅ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 20 TR-ability-* entries.
> ⚠️ Untraced: AbilityClass enum naming convention (pending ADR-0007).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/ability-system.md` (33 ACs: 30 BLOCKING + 3 ADR-RATIFICATION-GATED) verified
- ADR-0007 Accepted (class enum naming locked) before any class-archetype implementation stories start
- Logic stories: unlock formula tests + cooldown tracking tests in `tests/unit/ability/`
- caller whitelist CI test: `cast_ability()` called from non-combat_resolver.gd → CI lint violation
- `ability.unlocked.*` namespace round-trip persistence test via MockPersistenceLayer

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [ci-lints-closed-api](story-001-ci-lints-closed-api.md) | Static | ✅ Complete | ADR-0006 C12 |
| 002 | [core-data-structures](story-002-core-data-structures.md) | Logic | ✅ Complete | ADR-0006 C3, ADR-0007 |
| 003 | [source-class-allowlist](story-003-source-class-allowlist.md) | Logic | ✅ Complete | ADR-0006, ADR-0007 |
| 004 | [unlock-path-a-atomic-write](story-004-unlock-path-a-atomic-write.md) | Integration | ✅ Complete | ADR-0006 C3 |
| 005 | [unlock-path-b-formulas](story-005-unlock-path-b-formulas.md) | Logic | ✅ Complete | ADR-0006 C6 |
| 006 | [cast-cooldown-reentrance](story-006-cast-cooldown-reentrance.md) | Logic | ✅ Complete | ADR-0006 C12 |
| 007 | [boot-reconciliation](story-007-boot-reconciliation.md) | Integration | ✅ Complete | ADR-0006 C4 |
| 008 | [gsm-suspended-permanent-unlock](story-008-gsm-suspended-permanent-unlock.md) | Integration | ✅ Complete | ADR-0006 C6/C13 |
| 009 | [cross-knob-invariants](story-009-cross-knob-invariants.md) | Logic | ✅ Complete | ADR-0006 C8 pattern |
| 010 | [adr-ratification-gated](story-010-adr-ratification-gated.md) | Mixed | **Blocked** | ADR-0002 ⚠️, ADR-0003 ⚠️, #10 GDD |

## Next Step

Run `/story-readiness production/epics/ability-system/story-001-ci-lints-closed-api.md` then `/dev-story` to begin.

> Work through stories in dependency order: 001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009. Story 010 BLOCKED until ADR-0002 + ADR-0003 Accepted + #10 GDD authored.
> Story 002: AbilityClass has 4 values {STRIKE, CONTROL, MOBILITY, UNKNOWN} per ADR-0007 (GDD specified 3; ADR-0007 Accepted 2026-05-29 takes precedence).
