# Epic: Ability System

> **Layer**: Core
> **GDD**: design/gdd/ability-system.md
> **Architecture Module**: AbilitySystem (`src/autoload/ability_system.gd`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories ability-system`

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

## Next Step

Run `/create-stories ability-system` to break this epic into implementable stories.

> ⚠️ **Pre-requisite**: ADR-0007 must be Accepted before class-enum stories. Run `/architecture-decision "Class Enum Naming Convention"` first.
