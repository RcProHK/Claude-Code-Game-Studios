# Telemetry / Analytics — Design Review Log

## Review — 2026-06-12 — Verdict: APPROVED (NEEDS REVISION → revise-now → APPROVED, same session)
Scope signal: M (observer-only; 5 formulas; 6-7 deps; needs 1 new ADR-0012)
Specialists: degraded-inline (game-designer / systems-designer / qa-lead / creative-director acted inline; harness no-spawn) + grep-verify against shipped src/registry
Blocking items: 1 | Recommended: 2 | Nice-to-have: 2

### Findings
- **B-1 [BLOCKING — phantom signal]**: Rule 5 listed `out_of_order_signal` as a #28-subscribed
  CRITICAL event. Grep falsified: WST L378 = `log wst.out_of_order_signal(signal, ts, last)` is
  an INTERNAL LOG call, not an emitted signal; WST signal surface (L117-123 + bfcache_resumed L399)
  has no such signal. An implementer would try to `.connect()` a non-existent signal → trap.
  FIX: reclassified as telemetry-DERIVED meta `out_of_order_observed` (parallel to EC-03
  `duplicate_transition_observed`; telemetry self-detects via `client_ts_monotonic_ms` ordering).
- **R-1 [RECOMMENDED — citation]**: Interactions table `state_changed(from, to, transition_id)` →
  actual GSM L578 signature `state_changed(from_state, to_state, payload: StateTransitionPayload)`;
  transition_id is inside payload. FIXED.
- **R-2 [RECOMMENDED — registry]**: registry `state_changed_signal_signature` L1039 explicitly
  reserved telemetry.md (#28) as future referrer → promoted to actual referrer. DONE (Phase 5b).
- **N-1 [NICE — Formula 1 edge]**: switch_latency undefined for first SET_ACTIVE (WARM_UP→SET_ACTIVE,
  no preceding REST_PERIOD). FIXED — added edge (b): only computed when a REST_PERIOD entry recorded
  since last reset.
- **N-2 [NICE — WST-side erratum]**: WST signal declaration block (L117-123) omits `bfcache_resumed`
  although L399 commits to emitting it "for #28 telemetry". WST-side doc inconsistency → Q-T8,
  epic-time WST next-revision. Does NOT block telemetry (contract established by L399 emit commitment).

### Grep-verified EXACT (14/15 upstream signal contracts correct on first authoring)
#9 WST: `workout_started_forwarded` / `workout_completed_forwarded(completed_at,transition_id)` /
`workout_summary_available(WorkoutSummaryRO)` / `set_progress_changed(float)` /
`dominant_class_changed(AbilityClass)` / `phase_changed(from,to)` (L117-123) +
`bfcache_resumed(was_mid_workout,restored_phase)` (L399 emit "for #28"). · #14 ED:
`hit_resolved`/`enemy_killed`/`combat_metric_anomaly` (L144-146) + Rule 17 rate-limit. ·
#15 Loot: `loot_dropped` frozen v1 (FR-LOOT-3) + `loot_ceremony_capped`/`loot_zero_workout_floor_applied`/
`loot_rarity_mismatch`/`loot_drop_unbound`/`loot_pending_recovered`. · #13 EC-49 recursion-guard. ·
GSM `state_changed(from,to,payload)` L578 + `connect_for_initial_state` Contract 6.

### Cross-system conflict resolved
#14 EnemyDirector L593 "#28 must boot BEFORE #14" (stale provisional) vs ADR-0008 L129 "#28 Last".
ADR-0008 prevails (canonical map; combat signals are runtime, late-boot catches all). #14 L593
erratum tracked Q-T1 (epic-time cross-file).

### New ADR flagged
ADR-0012 Telemetry Data Pipeline & Privacy — NOT YET WRITTEN. GDD describes WHAT/WHY; ADR describes
HOW (endpoint/auth/batch/retention/de-id/opt-out). Architecture-phase gate; blocks transport story (Q-T2).

### Senior Verdict (creative-director, degraded-inline)
Pillar-coherent, scope-disciplined, grep-verified upstream contracts highly accurate (14/15 EXACT).
Architecturally clean; only 1 phantom and citation-level. Pillar 1/2 structural defense complete
(de-id + 100% passive). The single BLOCKING was a localized inline fix. APPROVED post-revision.

Prior verdict resolved: First review.
