# Epics Index

Last Updated: 2026-06-02
Engine: Godot 4.6 (Web Export, Compatibility Renderer)
Created by: /create-epics Foundation + Core (16 systems); #10 Exercise→Class Mapping promoted Placeholder→Ready 2026-06-02; #4 Audio Manager promoted Placeholder→Ready 2026-06-02 (GDD Approved Pass 6 + ADR-0008 Accepted)

> **Implementation order**: Foundation layer first (pos 1→10 boot order), then Core layer.
> **Critical pre-requisites before any stories start**:
> - ADR-0007 Class Enum Naming Convention (blocks #12 + #14 class-archetype stories)
> - ADR-0008 Autoload Full Position Registry (blocks #4 + #10 + #33 placeholder epics)
> - ADR-0002 + ADR-0004 **full** ratification (data contract + topology Accepted 2026-05-31; **live-transport/CORS empirical validation still gated** — blocks #2 GymSys live-HTTP stories)
> - `/create-control-manifest` (no control-manifest.md exists — required before /create-stories)
> - `/design-review design/gdd/loot-drop-system.md` Pass 3 (before /create-stories loot-drop-system)

---

## Foundation Layer

| Epic | Layer | System # | GDD | Stories | Status |
|------|-------|----------|-----|---------|--------|
| [PersistenceLayer](persistence-layer/EPIC.md) | Foundation | #3 | persistence-layer.md ✅ | **16 stories** (15 Ready, 1 Blocked ADR-0003) | Ready — **START HERE** (pos 1, all others depend on it) |
| [Game State Machine](game-state-machine/EPIC.md) | Foundation | #1 | game-state-machine.md ✅ | **17 stories** (16 Ready, 1 Complete) | Ready — Story 010 already done (Foundation chain) |
| [GymSys Backend Client](gymsys-backend-client/EPIC.md) | Foundation | #2 | gymsys-backend-client.md ✅ | Not yet created | **Blocked** — ADR-0002 + ADR-0004 Proposed |
| [Particle System Wrapper](particle-system-wrapper/EPIC.md) | Foundation | #5 | particle-system-wrapper.md ✅ | **9 stories** (8 Complete CI-green, 1 Blocked: 009 ADR-0001 CPU ratification) | **Implemented 8/9** — CI-green 1220/1221 (2026-06-01); 009 perf-gated (VS hardware) |
| [Screen Effects System](screen-effects-system/EPIC.md) | Foundation | #6 | screen-effects-system.md ✅ | **11 stories** (10 Complete CI-green, 1 Blocked: 011 ADR-0001 hw) | **Implemented 10/11** — CI-green 1266/1267 (2026-06-01); 011 perf-gated (VS hardware) |
| [Camera System](camera-system/EPIC.md) | Foundation | #7 | camera-system.md ✅ | **12 stories** (10 Complete CI-green, 011 Blocked #22, 012 Blocked ADR-001 hw) | **Implemented 10/12** — CI-green 1312/1313 (2026-06-01); 011 (#22 GDD) + 012 (VS hardware) gated |
| [Streak System](streak-system/EPIC.md) | Foundation | #8 | streak-system.md ✅ | **10 stories** (all Complete CI-green) | **Complete 10/10** — CI-green 1321/1322; 009 (AC-39 CI) + 010 (AC-37 retro + Story 002 drift-gate directional fix) closed 2026-06-01; AC-38 deferred (VS-tier) |
| [Audio Manager](audio-manager/EPIC.md) | Foundation | #4 | audio-manager.md ✅ Approved 2026-06-02 (Pass 6) | **9 stories** (1 Complete CI-gated, 002-009 Ready — 6 Logic, 3 Integration) | **In Progress 1/9** — Story 001 (gateway scaffold + CI lint + seams + autoload pos 16) done 2026-06-02 (local-run BLOCKED by Bash EEXIST → CI-gated); NEXT 002; 3 external gates story-level (006 情境A / 007 forwarding) 唔阻 epic |

## Core Layer

| Epic | Layer | System # | GDD | Stories | Status |
|------|-------|----------|-----|---------|--------|
| [Stat System](stat-system/EPIC.md) | Core | #11 | stat-system.md ✅ | **13 stories** (12 Complete, 1 Blocked ADR-003+ADR-005) | **Complete 12/13** — CI green 343/343 (PR #5 merged 2026-05-30) |
| [Ability System](ability-system/EPIC.md) | Core | #12 | ability-system.md ✅ | **10 stories** (9 Complete, 1 Blocked ADR-002+ADR-003+#10) | **Complete 9/10** — CI-green 104/104 (verified 2026-06-01); merged PR #6 2026-05-30 |
| [Combat Resolver](combat-resolver/EPIC.md) | Core | #13 | combat-resolver.md ✅ | **10 stories** (8 Complete, 2 Blocked) | **Complete 8/10** — CI-green 90/90 (verified 2026-06-01); merged PR #7 2026-05-30 |
| [Enemy Director](enemy-director/EPIC.md) | Core | #14 | enemy-director.md ✅ | **24 stories** (20 Ready, 4 Blocked) | Ready — 001 START HERE; 021 Blocked (art); 022 Blocked (hardware); 023 Blocked (#9 WST); 024 Blocked (ADR-0001 CPU) |
| [Workout State Tracker](workout-state-tracker/EPIC.md) | Core | #9 | workout-state-tracker.md ✅ | **12 stories** (11 Complete, 1 Blocked: 011 ADR-0002-transport/#14) | **Complete 11/12** — 012 done mock-scoped (GUT local: Story 012 13/13, WST integ 27/27 + unit 85/86; CI verify on push); 011 needs #14 + live transport |
| [Loot Drop System](loot-drop-system/EPIC.md) | Core | #15 | loot-drop-system.md ✅ Pass 2 | **15 stories** (12 Ready, 3 Blocked #2/#9/#14) | Ready — ADR-0005 Accepted 2026-05-30 |
| [Exercise → Class Mapping](exercise-class-mapping/EPIC.md) | Core | #10 | exercise-class-mapping.md ✅ Approved 2026-06-02 | **5 stories** (001 ✅ Complete CI-green, 002-005 Ready) | **In progress 1/5** — 001 done CI-green 2026-06-02; ADR-0007/0008/0003 Accepted; 2 cross-system close-gates (Q5 #9 patch + entities.yaml 7-member) |
| [Attention Budget & Interaction Policy](attention-budget-policy/EPIC.md) | Core | #33 | NOT STARTED | Not yet created | **Placeholder** — GDD + ADR-0008 required (Pre-MVP) ★ Pillar 2 |

---

## Summary

| Metric | Count |
|--------|-------|
| Total epics | 16 |
| Ready (GDD Approved + ADR-0006 Accepted) | 16 |
| Blocked (ADR Proposed — stories auto-blocked) | 1 (#2 GymSys — ADR-0002/0004 transport VS-gated) |
| Placeholder (no GDD) | 1 (#33 AttentionBudget) |
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
