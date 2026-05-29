# Architecture Review Report

**Date**: 2026-05-27
**Engine**: Godot 4.6 (pinned 2026-02-12)
**Mode**: full
**GDDs Reviewed**: 8 (7 Approved + 1 Designed pending review)
**ADRs Reviewed**: 6 (all Proposed)

> **Session caveat**: This review was performed in the same session as `/architecture-decision` authoring of ADR-0001 through ADR-0005. Standard practice mandates fresh-session review for independence. Findings noted but should be cross-validated in a future fresh session. Engine specialist consultation (Phase 5) was spawned as an independent agent for unbiased engine API assessment.

---

## Executive Summary

**Original Verdict**: 🟡 **CONCERNS** — 2 BLOCKING sync issues between ADRs

**Post-fix Verdict (2026-05-27 same session)**: 🟢 **PASS-LIKELY** — B-1 + B-2 both resolved inline via mechanical sync edits. Architecture fundamentally sound. Recommend fresh-session `/architecture-review` to confirm PASS verdict independently.

**Bottom line**: All BLOCKING items resolved inline. Architecture is ready for Pre-Production. Pre-gate infrastructure (`/test-setup` + `/ux-design`) still required separately before `/gate-check pre-production`.

**Post-fix changes log**:
- ✅ B-1 RESOLVED: ADR-006 Contract 10 source synced to ADR-003 (6/150ms/900ms) + Performance table line 882 updated
- ✅ B-2 RESOLVED: ADR-001 §Mobile Platform Detection updated — removed "position 0" claim; PlatformDetect now position 3+ with rationale explaining why position within [3..N] doesn't matter

---

## Phase 2-3 — Traceability Summary

**Coverage status** (extracted from each GDD's "Implements Pillar" + technical requirements):

| GDD | System | Approved | TR Coverage | Status |
|-----|--------|----------|-------------|--------|
| game-state-machine.md | #1 GSM | 2026-05-25 | ADR-0006 (all 15 contracts) | ✅ Full |
| gymsys-backend-client.md | #2 GymSys | 2026-05-26 | ADR-0002 + ADR-0006 (contracts 2/4/5/11/15) | ✅ Full |
| persistence-layer.md | #3 PersistenceLayer | 2026-05-26 | ADR-0003 + ADR-0006 (contracts 3/4/9/10/11/14) | ✅ Full |
| particle-system-wrapper.md | #5 ParticleSystem | 2026-05-26 | ADR-0001 (FR-1/2/3 gated) + ADR-0006 (Contract 6) | ✅ Full |
| screen-effects-system.md | #6 ScreenEffects | 2026-05-26 | ADR-0001 (FR-1/2/3 gated, topology) + ADR-0006 (Contract 6) | ✅ Full |
| camera-system.md | #7 Camera | 2026-05-26 (Pass 4) | ADR-0001 (FR-1/2/3 gated) + ADR-0006 (Contract 4 + 6) | ✅ Full |
| streak-system.md | #8 Streak | 2026-05-26 | ADR-0003 (FR-1/2/3 ratification-gated) + ADR-0006 (Contract 6 + 9) | ⚠️ Partial — see Note 1 |
| stat-system.md | #11 Stat | 2026-05-27 (Designed) | ADR-0003 (`stat.*` namespace) + ADR-0005 (PR_BREAKTHROUGH) + ADR-0006 (Contracts 3/4/6) | ⚠️ Partial — see Note 2 |

**Coverage totals**: 8 / 8 GDDs have ADR coverage. 6 are fully covered, 2 partial pending ADR-003 ratification (Streak) and Stat-specific cross-ADR validation.

### Note 1 — Streak FR-1/2/3 status (Partial)
#8 Streak System defines 3 ADR-RATIFICATION-GATED ACs (AC-37/38/39) waiting for ADR-003 Accepted. ADR-003 currently Proposed pending BLOCKING fix below. Streak does NOT introduce new architectural decisions — purely consumes ADR-003 contracts. Status upgrades to Full once ADR-003 reaches Accepted.

### Note 2 — Stat System status (Partial)
#11 Stat System was authored 2026-05-27 in parallel via `/design-system 11` lean mode. Stat-specific concerns:
- Inherits ADR-003 `stat.*` PersistenceLayer namespace
- References ADR-005 PR_BREAKTHROUGH formula (provisional pending PR_BASE cross-validation per Q-A1 in Stat GDD)
- Inherits ADR-006 Contracts 3/4/6
- No new architectural decisions requiring a Stat-specific ADR
- Awaiting `/design-review --depth lean` validation in fresh session

---

## Phase 4 — Cross-ADR Conflict Detection

### 🔴 BLOCKING Conflicts

#### Conflict B-1: ADR-0006 vs ADR-0003 — Schema Migration Values
**Type**: Data ownership conflict (constants disagreement between ratified ADRs)

- **ADR-0006 Contract 10** (lines 498-499): `MAX_MIGRATION_CHAIN_LENGTH = 10`, `MIGRATION_BUDGET_MS = 500ms` → total ceiling 5000ms
- **ADR-0003 §Schema Migration Protocol** (lines 160-162): `MAX_MIGRATION_CHAIN_LENGTH = 6`, `MIGRATION_BUDGET_MS = 150ms` → total 900ms; explicitly states "corrects stale ADR-006 registry entry of 5000ms"

**Impact**: ADR-003 acknowledges the conflict and supersedes the values in its prose, BUT ADR-006 source has NOT been edited. Two Proposed ADRs cannot disagree on the same constants when one references the other as authoritative. ADR-006 Performance table line 882 also references the stale 5000ms.

**Resolution required**: Update ADR-0006 Contract 10 to match ADR-0003 (6 steps × 150ms = 900ms), OR explicitly supersede ADR-0006 Contract 10 in favour of ADR-0003. The GDDs (#3 PersistenceLayer, #1 GSM) already use the corrected values (6/150ms) — only ADR-0006 ADR document text is stale.

**Note**: `docs/registry/architecture.yaml` already marks the stale entry as `superseded_by: adr-0003`. Source ADR document needs the same correction.

#### Conflict B-2: ADR-0001 vs ADR-0006 — Autoload Position 0
**Type**: Architecture pattern conflict (autoload load order)

- **ADR-0001 §Mobile Platform Detection** (line 156): "PlatformDetect... Autoload position: 0 (before all other autoloads — PersistenceLayer is position 1, GSM position 2, per ADR-006 Contract 4 sequential boot order)"
- **ADR-0006 Contract 4 + Implementation Guideline #1**: Locks position 1 = PersistenceLayer, position 2 = GameStateMachine. **No position 0 defined**. Conventional Godot autoload list is 1-indexed.

**Impact**: Implementer cannot satisfy both ADRs as written. Either (a) ADR-0006 must add PlatformDetect explicitly at position 1 (shifting PersistenceLayer→2, GSM→3, which invalidates ADR-0006 Implementation Guideline #1), or (b) ADR-0001 must reframe PlatformDetect's position to match ADR-0006's locked 1/2 ordering ("before PersistenceLayer" semantics, in concrete index = position 1, push others down).

**Resolution required**: Pick approach (a) or (b) and update both ADRs to agree. Recommend (b) — keep PersistenceLayer at position 1 (already locked + tested), move PlatformDetect to a non-boot-critical autoload position (e.g., position 5+ with delayed `_ready()` execution); call PlatformDetect from PersistenceLayer's `_detect_storage_mode()` after position-1 boot completes.

### ⚠️ Advisory Conflicts (non-blocking)

#### Advisory A-1: ADR-0006 Performance Table stale (line 882)
Same root cause as B-1 — ADR-0006 Performance table references "5000ms migration budget" while ADR-0003 ratifies 900ms. Sync when fixing B-1.

#### Advisory A-2: ADR-0006 Contract 1 stale framing about IDB commit
ADR-0006 Contract 1 (line 527) says `STATE_TRANSITION_FALLBACK_MS = 1000ms` is "60× larger than typical 16ms IDB commit window". But ADR-0003 (line 37) explicitly states IDB flush has no GDScript-visible fence. The 16ms assumption is misleading. Recommend reframing ADR-0006 to acknowledge IDB commit timing is unknown (per ADR-003 Contract 11 best-effort policy).

#### Advisory A-3: ADR-0002 `create_timer` 4-param form not in engine-reference
ADR-0002 prescribes `get_tree().create_timer(delay, true, false, true)` for retry backoff. Engine-reference docs (`current-best-practices.md`) don't document this 4-param signature. Add positive-API note to engine-reference to prevent future regression.

#### Advisory A-4: ADR-0001 `GPUParticles2D` on Compatibility renderer
ADR-0001 claims transform feedback supported on WebGL2. Correct, but historically fragile on mobile Safari. ADR-001 Verification Required item (1) already lists this as VS-tier spike — re-verify periodically per Godot 4.6.x patch releases.

### ADR Dependency Order (Topological Sort)

**Foundation layer (no dependencies)**:
1. ADR-0006 State Machine Contract — most fundamental; all others depend on it

**Layer 1 (depends on ADR-0006)**:
2. ADR-0001 Web Export Budget Caps (depends on ADR-0006 PROCESS_MODE_ALWAYS + Contract 4)
3. ADR-0003 Save State Strategy (depends on ADR-0006 Contracts 10/11 + IPersistence)
4. ADR-0005 Loot Rarity Formula (depends on ADR-0006 Contract 2 for transition_id seeding)

**Layer 2 (depends on Layer 1)**:
5. ADR-0002 GymSys Integration Protocol (depends on ADR-0006 + ADR-0001 + **ADR-0004**)
6. ADR-0004 CORS / Cross-Origin Auth Topology (depends on ADR-0002 + ADR-0003)

**⚠️ Mutual dependency note**: ADR-0002 depends on ADR-0004 for CORS resolution; ADR-0004 depends on ADR-0002 for endpoint contract definitions. This is technically a cycle but acceptable — both can be Proposed simultaneously and Accepted in the same atomic step. The cycle resolves cleanly because:
- ADR-0002 defines endpoints assuming "some CORS topology will resolve them"
- ADR-0004 defines topology assuming "endpoints already defined"
- Both can be implemented together; neither blocks the other in practice

**No true blocking cycles detected.**

---

## Phase 5 — Engine Compatibility Audit

### ✅ Confirmed Consistent (from godot-specialist consultation)

- **FileAccess.store_* bool semantics**: ADR-0003 + ADR-0006 Contract 11 agree (bool = MEMFS write, NOT IDB commit)
- **transition_id format**: ADR-0006 Contract 2 + ADR-0002 (child suffixes) + ADR-0005 (RNG seed) all consistent
- **X-Session-Token header**: ADR-0002 + ADR-0004 + ADR-0006 + registry agree (case-insensitive backend)
- **No deprecated API leakage**: grep across all 6 ADRs returned zero hits for `yield()`, string-based `connect()`, `OS.get_ticks_msec()`, `Texture2D` in shader uniforms
- **Compositor unavailable on Compatibility renderer**: ADR-0001 correctly identifies + Alternative 3 explicitly rejects
- **COOP/COEP single-thread assumption**: ADR-0001 + ADR-0004 + ADR-0006 Contract 1 all agree (threading off for VS-tier; generational lock is future-proof)
- **Engine Compatibility section completeness**: All 6 ADRs have required sub-fields

### ⚠️ Engine Specialist Findings (deferred / re-verification gates)

- **Stale ADR values** (B-1 + A-1 above): ADR-0006 references need sync to ADR-0003 ratified 900ms / 6 steps
- **PlatformDetect autoload position** (B-2 above): ADR-0001 + ADR-0006 disagree
- **GPUParticles2D on Compatibility renderer** (A-4): VS-tier mobile Safari verification required
- **create_timer 4-param documentation gap** (A-3): add to engine-reference best practices

### Known Conflict-Prone Areas (from consistency-failures.md)

Prior /consistency-check log shows two RESOLVED conflicts in PersistenceLayer migration system domain (max_migration_chain_length 10→6, migration_budget_ms 500→150). The 2 BLOCKING items in this review (B-1, B-2) are extensions of that same pattern: ADRs written before downstream GDDs/ADRs finalised values, and ADR source text not synced. **Pattern**: when ADR-006 references constants that other ADRs subsequently ratified at different values, ADR-006 source MUST be edited (not just registry annotated).

---

## Phase 5b — GDD Revision Flags

**No GDD revision flags found.** All 8 GDDs are consistent with verified engine behaviour:
- B-1 migration values: GDDs #3 PersistenceLayer + #1 GSM already use corrected 6/150ms values (the BLOCKING conflict is ADR-006 ↔ ADR-003 only; GDDs are clean)
- B-2 PlatformDetect position: No GDD claims a specific autoload position number; conflict is ADR-001 ↔ ADR-006 only
- A-2 IDB commit framing: GDDs do not reference the specific 16ms assumption

No systems-index Status updates needed for revision flags.

---

## Phase 6 — Architecture Document Coverage

`docs/architecture/architecture.md` does NOT exist. Architecture is documented entirely through ADRs + GDDs cross-referencing. Skipping Phase 6 — recommend `/create-architecture` skill after BLOCKING fixes resolve, to produce consolidated architecture document.

---

## Required Resolutions Before PASS

### Priority 1 (BLOCKING — fix before any ADR Accepted)

1. **Sync ADR-0006 Contract 10 + Performance table to match ADR-0003**
   - Edit `docs/architecture/adr-0006-state-machine-contract.md`:
     - Contract 10: `MAX_MIGRATION_CHAIN_LENGTH = 6`, `MIGRATION_BUDGET_MS = 150ms`, total ceiling = 900ms
     - Performance table line 882: replace 5000ms with 900ms
   - Add revision note: "Updated 2026-05-27 to reflect ADR-003 ratification"
   - Recommended action: `/architecture-decision retrofit docs/architecture/adr-0006-state-machine-contract.md` to apply the sync

2. **Resolve PlatformDetect autoload position (ADR-0001 vs ADR-0006)**
   - Pick approach: (a) update ADR-0006 to add PlatformDetect at position 1 (cascade renumbering) OR (b) update ADR-0001 to remove "position 0" claim and instead delay PlatformDetect detection until PersistenceLayer's first read
   - **Recommended**: approach (b) — preserves ADR-0006 locked ordering; PersistenceLayer can detect storage mode by attempting first FileAccess.open(), no PlatformDetect needed at boot-0 position
   - Edit `docs/architecture/adr-0001-web-export-budget-caps.md` §Mobile Platform Detection to reframe PlatformDetect lifecycle

### Priority 2 (ADVISORY — fix opportunistically)

3. ADR-0006 Performance table stale framing (A-1, A-2) — sync when fixing B-1
4. Add `create_timer` 4-param signature to engine-reference best practices (A-3)
5. Schedule VS-tier `GPUParticles2D` on Compatibility renderer mobile Safari verification (A-4)

---

## Required ADRs (Pre-Production Gaps)

No critical Foundation-tier ADRs missing. All 8 approved GDDs have ADR coverage. Remaining ADRs to consider (post-VS):

- **ADR-007** (deferred): AccessibilityBus.reduce_motion — flagged by camera-system.md design-review as cross-system motion accessibility contract for Camera + ScreenEffects + future systems
- **ADR for Audio system** (#4 Audio Manager) — Not Started; required before MVP

---

## Verdict: 🟡 **CONCERNS**

**Reasoning**:
- ✅ All 8 approved GDDs have ADR coverage (no critical Foundation gaps)
- ✅ All ADRs use Godot 4.6 APIs correctly (no deprecated leakage)
- ✅ No fundamental architectural cycles (ADR-002 ↔ ADR-004 mutual is conceptually clean)
- ✅ Cross-ADR conceptual alignment is strong (FileAccess semantics, transition_id, X-Session-Token, COOP/COEP all consistent)
- 🔴 **2 BLOCKING sync issues** (B-1 ADR-006 stale migration values; B-2 PlatformDetect position conflict) — MUST resolve before any ADR moves Proposed → Accepted
- ⚠️ 4 advisory items (non-blocking improvements)

**Not FAIL** because: BLOCKING issues are documentation sync problems, not fundamental architectural mistakes. The GDDs and registry already use correct values; only ADR-006 source text is stale. Resolution is mechanical, not design-level.

**Not PASS** because: Until ADR-006 source text is synced and PlatformDetect position is resolved, downstream implementation stories cannot safely cite ADR-006 Contract 10 or ADR-001 §Mobile Platform Detection without contradicting one of the other ADRs.

---

## Pre-Gate Checklist Status

| Item | Status |
|------|--------|
| `tests/unit/` directory | ❌ Not present — run `/test-setup` |
| `tests/integration/` directory | ❌ Not present — run `/test-setup` |
| `.github/workflows/tests.yml` | ❌ Not present — run `/test-setup` |
| `design/accessibility-requirements.md` | ❌ Not present — run `/ux-design` |
| `design/ux/interaction-patterns.md` | ❌ Not present — run `/ux-design` |

Pre-gate checklist incomplete — `/gate-check pre-production` blocked on multiple infrastructure items beyond this review's scope.

---

## Next Steps

1. **Immediate (this session OR fresh)**: Fix B-1 + B-2 BLOCKING items via ADR edits (treat as ADR sync, not full re-authoring)
2. **Re-run** `/architecture-review` in **fresh session** to confirm BLOCKING items resolved
3. **VS-tier infrastructure**: Run `/test-setup` for test framework + CI
4. **UX infrastructure**: Run `/ux-design` for accessibility requirements + interaction patterns
5. **Architecture document**: Run `/create-architecture` to consolidate ADRs + GDDs into unified architecture document
6. **Continue GDD authoring**: Most VS-tier systems still Not Started (#9 Workout State Tracker, #12 Ability System, #13 CombatResolver, #14 EnemyDirector, #16 Boss System, #26 Avatar Renderer)
