# Epics Index

Last Updated: 2026-05-29
Engine: Godot 4.6 (Web Export, Compatibility Renderer)
Created by: /create-epics Foundation + Core (16 systems)

> **Implementation order**: Foundation layer first (pos 1→10 boot order), then Core layer.
> **Critical pre-requisites before any stories start**:
> - ADR-0007 Class Enum Naming Convention (blocks #12 + #14 class-archetype stories)
> - ADR-0008 Autoload Full Position Registry (blocks #4 + #10 + #33 placeholder epics)
> - ADR-0002 + ADR-0004 coordinated ratification (blocks all #2 GymSys stories)
> - `/create-control-manifest` (no control-manifest.md exists — required before /create-stories)
> - `/design-review design/gdd/loot-drop-system.md` Pass 3 (before /create-stories loot-drop-system)

---

## Foundation Layer

| Epic | Layer | System # | GDD | Stories | Status |
|------|-------|----------|-----|---------|--------|
| [PersistenceLayer](persistence-layer/EPIC.md) | Foundation | #3 | persistence-layer.md ✅ | **16 stories** (15 Ready, 1 Blocked ADR-0003) | Ready — **START HERE** (pos 1, all others depend on it) |
| [Game State Machine](game-state-machine/EPIC.md) | Foundation | #1 | game-state-machine.md ✅ | **17 stories** (16 Ready, 1 Complete) | Ready — Story 010 already done (Foundation chain) |
| [GymSys Backend Client](gymsys-backend-client/EPIC.md) | Foundation | #2 | gymsys-backend-client.md ✅ | Not yet created | **Blocked** — ADR-0002 + ADR-0004 Proposed |
| [Particle System Wrapper](particle-system-wrapper/EPIC.md) | Foundation | #5 | particle-system-wrapper.md ✅ | Not yet created | Ready (ADR-0001 spike story first) |
| [Screen Effects System](screen-effects-system/EPIC.md) | Foundation | #6 | screen-effects-system.md ✅ | Not yet created | Ready |
| [Camera System](camera-system/EPIC.md) | Foundation | #7 | camera-system.md ✅ | Not yet created | Ready |
| [Streak System](streak-system/EPIC.md) | Foundation | #8 | streak-system.md ✅ | **8 stories** (all Ready) | Ready — Pre-MVP tier |
| [Audio Manager](audio-manager/EPIC.md) | Foundation | #4 | NOT STARTED | Not yet created | **Placeholder** — GDD + ADR-0008 required (MVP tier) |

## Core Layer

| Epic | Layer | System # | GDD | Stories | Status |
|------|-------|----------|-----|---------|--------|
| [Stat System](stat-system/EPIC.md) | Core | #11 | stat-system.md ✅ | **13 stories** (12 Complete, 1 Blocked ADR-003+ADR-005) | **Complete 12/13** — CI green 343/343 (PR #5 merged 2026-05-30) |
| [Ability System](ability-system/EPIC.md) | Core | #12 | ability-system.md ✅ | **10 stories** (9 Complete, 1 Blocked ADR-002+ADR-003+#10) | **Implemented 9/10** — pending CI verify |
| [Combat Resolver](combat-resolver/EPIC.md) | Core | #13 | combat-resolver.md ✅ | **10 stories** (8 Complete, 2 Blocked) | **Implemented 8/10** — pending CI verify |
| [Enemy Director](enemy-director/EPIC.md) | Core | #14 | enemy-director.md ✅ | Not yet created | Ready (ADR-0007 required for wave archetype stories) |
| [Workout State Tracker](workout-state-tracker/EPIC.md) | Core | #9 | workout-state-tracker.md ✅ | Not yet created | Ready |
| [Loot Drop System](loot-drop-system/EPIC.md) | Core | #15 | loot-drop-system.md ✅ Pass 2 | **15 stories** (12 Ready, 3 Blocked #2/#9/#14) | Ready — ADR-0005 Accepted 2026-05-30 |
| [Exercise → Class Mapping](exercise-class-mapping/EPIC.md) | Core | #10 | NOT STARTED | Not yet created | **Placeholder** — ADR-0007 + GDD required (Pre-MVP) |
| [Attention Budget & Interaction Policy](attention-budget-policy/EPIC.md) | Core | #33 | NOT STARTED | Not yet created | **Placeholder** — GDD + ADR-0008 required (Pre-MVP) ★ Pillar 2 |

---

## Summary

| Metric | Count |
|--------|-------|
| Total epics | 16 |
| Ready (GDD Approved + ADR-0006 Accepted) | 11 |
| Blocked (ADR Proposed — stories auto-blocked) | 4 (#2 GymSys, #5 Particle, #6 Screen, #7 Camera) |
| Placeholder (no GDD) | 3 (#4 Audio, #10 ExerciseMapping, #33 AttentionBudget) |
| Pending GDD approval | 1 (#15 LootDrop — Pass 3 required) |

---

## Recommended Implementation Sequence

```
Phase 1 — Foundation ADR-0006 (already Accepted):
  1. /create-stories persistence-layer      → implement PersistenceLayer (pos 1 root)
  2. /create-stories game-state-machine     → Rule 2 full transition + Contracts 1/2/3
  3. /create-stories streak-system          → closed API + milestone thresholds

Phase 2 — After ADR-0007 written + Accepted:
  4. /create-stories stat-system            → closed mutation API + VOLUME_TICK
  5. /create-stories ability-system         → PR breakthrough unlock chain
  6. /create-stories combat-resolver        → stateless pure-function damage math
  7. /create-stories workout-state-tracker  → dominant_class + set_progress

Phase 3 — VS spike (ADR-0001 hardware verification):
  8. /create-stories particle-system-wrapper → pool + 9 presets + mobile tier
  9. /create-stories screen-effects-system  → Trauma² shake + hit pause
 10. /create-stories camera-system          → follow + focal modes

Phase 4 — After ADR-0002 + ADR-0004 ratified:
 11. /create-stories gymsys-backend-client  → HTTP polling + session lock

Phase 5 — After #9 + #13 + #14 + #15 GDD pass:
 12. /create-stories enemy-director         → wave archetype + boss anchor
 13. /create-stories loot-drop-system       → rarity formula + ceremony budget
```

---

## Next Steps

1. Run `/create-control-manifest` — generates `docs/architecture/control-manifest.md` (required before /create-stories)
2. Run `/architecture-decision "Class Enum Naming Convention"` — ADR-0007 (unblocks #12 + #14)
3. Run `/create-stories persistence-layer` — first implementable epic
