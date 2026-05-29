# ADR-0010: Mirror Moment Ceremony Ownership Split (#26 ↔ #29)

## Status
Proposed

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Presentation (system ownership boundary) |
| **Knowledge Risk** | LOW — this is an ownership/coordination decision, not a novel-API decision; rendering touches the ADR-0001 budget which is separately verified |
| **References Consulted** | `design/gdd/avatar-renderer.md` (#26, Pass 2, BLOCKED on this split — F-13); systems-index (#29 Mirror Moment System, Not Started); ADR-0001 (draw-call + particle budget); ADR-0003 (`avatar.evolution_tier_history.*` namespace); ADR-0006 Contract 6 |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | When #29 is authored, confirm the ceremony reads #26 snapshots only (no duplicate evolution-tier state) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (evolution-tier history persistence namespace); ADR-0001 (render/particle budget the ceremony must respect); ADR-0006 (Contract 6 subscription) |
| **Enables** | #26 Avatar Renderer Pass 3 graduation (unblocks the BLOCKED gate); #29 Mirror Moment System GDD authoring |
| **Blocks** | #26 cannot exit BLOCKED and #29 cannot start until this ownership boundary is ratified |
| **Ordering Note** | HIGH / #26 BLOCKED gate. Closes architecture-review GAP-004 (Producer escalation, F-13). |

## Context

### Problem Statement
Pillar 5 (Mirror Moment) — "every week the avatar shows a visible, screenshottable
evolution reflecting real body change" — is split across two systems, and the boundary
was never ratified. #26 Avatar Renderer is **BLOCKED** (Pass 2, F-13) pending this
decision: does #26 own the weekly *ceremony* (the reveal sequence, screenshot prompt,
before/after composition, celebration VFX), or only the avatar's *visible state*?
#29 Mirror Moment System (Not Started) is the other claimant. Without a ruling, the
two systems risk (a) double-owning evolution-tier state, violating the Pillar 1
anti-fabrication "single source of truth" posture, or (b) #26 absorbing ceremony
orchestration it has no business owning (a Presentation-tier renderer driving
weekly-cadence + non-workout-context gating).

### Constraints
- Pillar 1: visible/evolution state must have ONE canonical owner; no duplicate
  tier state (#26 is the anti-fabrication "第七件套" — visible state derives only
  from #11/#12 canonical data).
- Pillar 2: the ceremony must NOT fire during a workout (mid-set introspection bleed
  risk, avatar-renderer.md Framing-2 / line 70) — it is a **non-workout-context**
  event.
- ADR-0001: the reveal must degrade gracefully on mobile (0.5× particle fallback);
  "silhouette carries identity, particle carries celebration" (avatar-renderer FR-2).
- MVP scope: Mirror Moment v1 is **screenshot-only** (sprite swap on weekly threshold
  + screenshot prompt); full layered ceremony is v0.2.

### Requirements
- A clean, one-directional dependency (#29 → #26), never the reverse.
- Single ownership of evolution-tier state + history.
- A render/snapshot contract #29 can compose against.

## Decision

Split by the **"identity vs celebration"** seam (already named in avatar-renderer FR-2):

### #26 Avatar Renderer OWNS — the avatar's visible identity (stateless render of canonical data)
- Canonical avatar **visible state**: sprite frame, animation state (idle/combat/cast),
  class-tagged posture (STRIKE/CONTROL/MOBILITY).
- **Evolution-tier state + history**: which evolution tier the avatar is at (derived
  from #11 Stat + #12 Ability canonical data), persisted under
  `avatar.evolution_tier_history.*` (ADR-0003).
- A **render/snapshot API** so a consumer can capture "the avatar as it looks now"
  (used by #29 for before/after framing) — and a **tier-changed hook/signal** when a
  weekly threshold is crossed.
- #26 knows **nothing** about ceremonies, weekly cadence, or screenshots.

### #29 Mirror Moment System OWNS — the weekly ceremony (composition + orchestration)
- **When the ceremony fires**: weekly-cadence detection + the Pillar-2 non-workout-context
  gate (never mid-workout).
- **The reveal sequence**: before→after composition using #26 snapshots, timing/beats,
  the screenshot prompt (MVP v1 deliverable).
- **Celebration layer**: particle amplification within the ADR-0001 budget
  (silhouette from #26 carries identity; #29's particles carry celebration only).
- #29 **depends on** #26 (one-directional) and treats #26's tier state as read-only
  truth — it never writes or recomputes evolution tier.

### Architecture Diagram
```
#11 Stat ┐
         ├─(canonical data)→ #26 AvatarRenderer ──(tier_changed signal,
#12 Ability ┘                 (owns visible state +   render/snapshot API)
                               evolution tier+history)        │
                                                              ▼  (read-only)
                                              #29 MirrorMomentSystem
                                              (owns weekly ceremony:
                                               cadence + non-workout gate +
                                               reveal sequence + screenshot
                                               prompt + celebration VFX)
                                  (NO back-edge: #26 never depends on #29)
```

### Key Interfaces
```gdscript
# #26 exposes (consumed by #29, #22, #25):
signal evolution_tier_changed(old_tier: int, new_tier: int, transition_id: String)
func get_current_evolution_tier() -> int
func capture_avatar_snapshot() -> Texture2D    # "as it looks now" for before/after framing

# #29 subscribes via connect_for_initial_state-style; gates on GSM state ∉ workout
# and weekly cadence; composes using #26 snapshots; never writes tier state.
```

## Alternatives Considered

### Alternative 1: #26 owns the whole ceremony
- **Description**: Avatar Renderer also runs the weekly reveal + screenshot prompt.
- **Pros**: One system; no cross-system contract.
- **Cons**: A Presentation-tier renderer would own weekly-cadence + non-workout gating + UX prompt — far outside "render canonical state"; bloats the anti-fabrication boundary; mixes identity with celebration.
- **Rejection Reason**: Violates separation of concerns; #26's BLOCKED status is precisely the symptom.

### Alternative 2: #29 owns evolution-tier state too
- **Description**: Mirror Moment computes/stores its own tier from stats.
- **Pros**: Ceremony fully self-contained.
- **Cons**: Duplicates evolution-tier state outside #26, breaking the Pillar 1 single-source-of-truth posture (avatar could "lie"); two systems deriving tier risk divergence.
- **Rejection Reason**: Directly contradicts the #26 anti-fabrication mandate.

### Alternative 3: Merge #26 + #29 into one system
- **Description**: Collapse both into a single "Avatar & Mirror Moment" system.
- **Pros**: No boundary to maintain.
- **Cons**: Couples a frame-by-frame renderer (runs always) with a weekly ceremony (fires rarely); different cadences, tiers, and test surfaces; loses the clean v0.2 layered-ceremony extension point.
- **Rejection Reason**: Conflates two distinct lifecycles; harms testability and scope control.

## Consequences

### Positive
- #26 exits BLOCKED with a render-only mandate; #29 gets a clear read-only contract.
- Single owner of evolution-tier state preserves Pillar 1 anti-fabrication.
- "Identity vs celebration" seam makes the ADR-0001 mobile degradation rule
  enforceable (degrade #29 particles without touching #26 silhouette).
- v0.2 layered-ceremony expansion lives entirely in #29; #26 unchanged.

### Negative
- A cross-system contract (snapshot API + tier-changed signal) must be defined and
  kept stable — an interface obligation on #26.
- #29 MVP must be authored before the full Mirror Moment loop ships (it is currently
  Not Started); MVP v1 is thin (threshold + sprite swap via #26 + screenshot prompt).

### Risks
- **Risk**: #29 caches tier state and drifts from #26. **Mitigation**: contract rule —
  #29 holds no tier state; always reads #26. CI/grep check for tier computation in #29.
- **Risk**: ceremony fires mid-workout. **Mitigation**: #29 gates on GSM state ∉
  {WORKOUT_ACTIVE, …} per Pillar 2 (avatar-renderer Framing-2).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| avatar-renderer.md (#26) | F-13: ceremony ownership split (BLOCKED); "render canonical state only"; evolution-tier milestone tracking + `avatar.evolution_tier_history.*` | Assigns #26 visible-state + tier ownership + snapshot/hook API; removes ceremony orchestration from its scope |
| avatar-renderer.md FR-2 | "silhouette carries identity, particle carries celebration"; mobile 0.5× degradation | Maps identity→#26, celebration→#29; degradation lands in #29 only |
| #29 Mirror Moment System (future) | Pillar 5 weekly visible evolution; MVP screenshot-only | Defines #29 = ceremony composition consuming #26 snapshots |
| game-state-machine.md | Non-workout-context gating | #29 gates ceremony on GSM state |

## Performance Implications
- **CPU**: Ceremony orchestration runs ~weekly (rare); negligible amortised cost.
- **Memory**: One snapshot Texture2D captured transiently during a ceremony; freed after.
- **Load Time**: None.
- **Network**: None (evolution history persists via existing ADR-0003 path).

## Migration Plan
1. #26 GDD Pass 3: scope narrowed to visible-state + tier ownership + snapshot/hook
   API; ceremony language removed (GDD edit, follow-up — not auto-applied here).
2. #29 GDD authored against this contract (MVP screenshot-only first).
3. No code yet (both Not Started / BLOCKED) — this ADR unblocks authoring.

## Validation Criteria
- #26 GDD Pass 3 contains no ceremony-orchestration ownership; exits BLOCKED.
- #29 GDD holds no evolution-tier computation/state — only reads #26.
- Ceremony never fires during WORKOUT_ACTIVE (test once #29 implemented).
- Mobile reveal degrades particles (#29) without altering silhouette (#26).

## Related Decisions
- ADR-0001 (Web Export Budget Caps) — render/particle budget + mobile degradation.
- ADR-0003 (Save State Strategy) — `avatar.evolution_tier_history.*` namespace.
- ADR-0006 (State Machine Contract) — Contract 6 subscription; non-workout gating via GSM state.
- ADR-0009 (Signal Payload Schema) — `evolution_tier_changed` carries transition_id correlation.
