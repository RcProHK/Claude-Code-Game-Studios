# Architecture Review Report — Ratification Pass

> Date: 2026-05-29
> Mode: `/architecture-review ratify`
> Engine: Godot 4.6
> Scope: ADR-0007, ADR-0008, ADR-0009, ADR-0010 (the four Proposed convention ADRs from commit #3), cross-checked against ADR-0001..0006.

---

## Purpose

Ratification review of the four convention ADRs (ADR-0007..0010), authored 2026-05-29
to close architecture-review GAP-001..004. Goal: confirm each is internally sound,
free of cross-ADR conflict, engine-consistent, and has its `Depends On` chain
satisfied — then promote eligible ADRs `Proposed → Accepted`.

## Inputs Loaded

- ADRs (full read): ADR-0007, ADR-0008, ADR-0009, ADR-0010.
- ADR status scan (all 10): ADR-0006 is the only `Accepted` ADR; ADR-0001..0005 and
  ADR-0007..0010 are `Proposed`.
- GDDs (targeted): loot-drop-system.md, avatar-renderer.md, systems-index.md.
- Engine reference: docs/engine-reference/godot/ (VERSION.md = Godot 4.6).
- Prior review: architecture-review-2026-05-28.md (GAP-001..004 origin).

---

## Cross-ADR Conflict Scan (Phase 4)

No conflicts detected. The four ADRs are mutually reinforcing, not contradictory:

- ADR-0007 (enum convention) → ADR-0009 reuses its string-name enum serialization.
- ADR-0008 (autoload map) → ADR-0009 references its `connect_for_initial_state` resilience.
- ADR-0009 (signal payload) → ADR-0010's `evolution_tier_changed` carries `transition_id` per its rule.
- All four cite, and stay consistent with, ADR-0006 (Contract 2/3/4/6) and ADR-0001/0003/0005.
- No data-ownership, integration-contract, performance-budget, pattern, or state-authority conflict.

## ADR Dependency Ordering (Phase 4)

Actual ADR statuses (ground truth = the ADR files):

| ADR | Status |
|-----|--------|
| ADR-0001 | Proposed (CPU budget values provisional pending VS-tier profiling) |
| ADR-0002 | Proposed |
| ADR-0003 | Proposed |
| ADR-0004 | Proposed |
| ADR-0005 | Proposed |
| ADR-0006 | **Accepted 2026-05-28** |
| ADR-0007 | **Accepted 2026-05-29** (this pass) |
| ADR-0008 | Proposed — BLOCKED on dependency |
| ADR-0009 | **Accepted 2026-05-29** (this pass) |
| ADR-0010 | Proposed — BLOCKED on dependency |

Dependency resolution for the ratify targets:

| Target | Depends On | Resolved? |
|--------|-----------|-----------|
| ADR-0007 | None | ✅ ratifiable standalone |
| ADR-0009 | ADR-0006 (Accepted) + ADR-0007 (ratified same batch) | ✅ ratifiable (0007 ≺ 0009) |
| ADR-0008 | ADR-0006 (Accepted) + **ADR-0001 (Proposed)** | 🔴 BLOCKED — ADR-0001 not Accepted |
| ADR-0010 | ADR-0006 (Accepted) + **ADR-0001 (Proposed)** + **ADR-0003 (Proposed)** | 🔴 BLOCKED — ADR-0001 + ADR-0003 not Accepted |

⚠️ ADR-0008 depends on ADR-0001 — still Proposed. Cannot be ratified until ADR-0001 is Accepted.
⚠️ ADR-0010 depends on ADR-0001 and ADR-0003 — both still Proposed. Cannot be ratified until both are Accepted.

Note: ADR-0001 is *intentionally* held at Proposed (its CPU budget figures are provisional
pending VS-tier profiling on target hardware). Until ADR-0001 graduates, ADR-0008 and
ADR-0010 remain blocked through no fault of their own content.

### Topological ratify order (this pass)

1. ADR-0007 (no deps) → Accepted
2. ADR-0009 (deps satisfied once 0007 accepted) → Accepted

---

## Engine Compatibility Audit (Phase 5)

Engine: Godot 4.6. ADRs with an Engine Compatibility section: 4 / 4.

- **ADR-0007** — Post-cutoff APIs `NamedEnum.find_key(value)` / `NamedEnum.get(key, default)`
  (Godot 4.4+). Already exercised by the 224/224 green suite (`boss_payload.gd:117-148`).
  No deprecated APIs. ✅
- **ADR-0008** — No post-cutoff APIs; relies on documented sequential autoload `_ready()`
  ordering (ADR-0006 Contract 4, verified). ✅
- **ADR-0009** — Post-cutoff `get_script().get_global_name()` for payload type tagging
  (Contract 3 substrate, verified). `Object.get_class()` correctly forbidden. ✅
- **ADR-0010** — No post-cutoff APIs (ownership/coordination decision). Render touches the
  separately-verified ADR-0001 budget. ✅

No version drift (all 4 pinned to 4.6), no deprecated-API references, no contradictory
post-cutoff-API assumptions. Engine specialist consultation skipped for this focused
ratify pass (engine surface already verified green; no novel API decisions among the four).

---

## GDD Revision Flags (Phase 5b) — deferred follow-ups, NOT blocking ratification

The ratified ADRs themselves mark these as deferred migrations ("not auto-applied here").

| GDD / file | Current state | Required by | Action |
|-----------|--------------|-------------|--------|
| loot-drop-system.md | Uses `NEUTRAL` as a `{STRIKE,CONTROL,MOBILITY,NEUTRAL}` ClassTag member (lines 653/664/668/675/679, tuning W_NEUTRAL, AC-16 worked example) + entities.yaml:801 | ADR-0007 | Rename `NEUTRAL` → `UNKNOWN`, OR document `NEUTRAL` as a weight-distribution *outcome* distinct from the `AbilityClass` identity. Follow-up. |
| docs/registry/architecture.yaml | PlatformDetect recorded at "position 0" | ADR-0008 | Correct to position 3. Deferred with ADR-0008 (blocked). |
| avatar-renderer.md | Carries ceremony/reveal language (lines 61/70/95) | ADR-0010 | Pass 3 scope-narrow to visible-state + tier + snapshot/hook API; remove ceremony orchestration. Deferred with ADR-0010 (blocked). |

The loot-drop `NEUTRAL → UNKNOWN` rename is now actionable (ADR-0007 is Accepted) and should
be scheduled as the first follow-up. The registry + avatar-renderer edits stay parked until
their governing ADRs (0008 / 0010) can be ratified.

---

## Verdict: PARTIAL PASS

- ✅ **ADR-0007** — ratified to Accepted 2026-05-29 (closes GAP-001).
- ✅ **ADR-0009** — ratified to Accepted 2026-05-29 (closes GAP-003).
- 🔴 **ADR-0008** — content sound, **deferred**: blocked on ADR-0001 (Proposed). GAP-002 stays open.
- 🔴 **ADR-0010** — content sound, **deferred**: blocked on ADR-0001 + ADR-0003 (Proposed). GAP-004 stays open.

No cross-ADR conflicts. No engine issues. The only blockers are dependency-status, not content.

## Required Next Actions (priority order)

1. **Unblock the foundation chain** — ratify ADR-0001 (gated on VS-tier CPU-budget
   profiling) and ADR-0003. These gate ADR-0008 (needs 0001) and ADR-0010 (needs 0001+0003),
   and also #26 Avatar Renderer's exit from BLOCKED.
2. **Schedule the loot-drop `NEUTRAL → UNKNOWN` migration** (ADR-0007 now Accepted).
3. **Re-run `/architecture-review ratify`** for ADR-0008 + ADR-0010 once ADR-0001/0003 are Accepted.

## Pre-gate Checklist (Phase 9)

- `tests/unit/` + `tests/integration/` — present (Foundation suite 224/224 green).
- GAP-002 (ADR-0008) and GAP-004 (ADR-0010) remain open → **not yet ready for
  `/gate-check pre-production`**. Foundation ADR ratification (0001/0003) is the gating path.
