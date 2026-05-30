## LootReconcileCalc — pure static implementations of Formula 5 + Formula 6 (Story 006)
##
## Driving GDD : design/gdd/loot-drop-system.md §D Formula 5 (Local vs Backend Reconcile)
##               design/gdd/loot-drop-system.md §D Formula 6 (Catch-up Compression)
## Driving Story: production/epics/loot-drop-system/story-006-formula-5-6-reconcile-catchup.md
## Governing ADR : ADR-0003 (Accepted 2026-05-30) Save State Strategy
##
## WHY a dedicated static class:
## Formula 5 + 6 are called at boot-reconciliation time (Story 009) and during
## session resume. Keeping them as pure functions with no autoload dependency lets
## Story 009 import exactly what it needs and lets unit tests call them without
## standing up the full LootDropSystem autoload.
##
## CF-4 invariant (GDD §D Formula 5):
##   The three output sets from reconcile_local_vs_backend() MUST be pairwise
##   disjoint. Any overlap is a logic error — asserted in debug builds.
class_name LootReconcileCalc
extends RefCounted


# ── Formula 5 — Local vs Backend Reconciliation ───────────────────────────────

## Reconcile client-local loot state against the server-authoritative pending list.
##
## Returns a Dictionary with three pairwise-disjoint Arrays (CF-4):
##
##   to_enqueue       — drops the backend knows about but the client does not have
##                      (neither pending nor revealed). Client should add these to
##                      its reveal queue and emit `loot_pending_recovered`.
##
##   to_ack_only      — drops the backend knows about AND the client has already
##                      revealed locally. Client should send ACK to backend only;
##                      do NOT re-reveal (that would be a duplicate ceremony).
##
##   to_discard_local — drops the client has locally-pending but the backend does
##                      NOT list. Backend has already authorised and consumed them
##                      (or they are orphaned). Silently discard from local state.
##
## CF-4 pairwise-disjoint invariant is asserted in debug builds; a violation
## indicates a logic error in the caller's input (e.g. a transition_id in both
## local_pending AND local_revealed simultaneously).
##
## Example (GDD AC-09 worked example):
##   local_pending  = ["T-103"]
##   local_revealed = ["T-101"]
##   backend_pending = ["T-100", "T-101", "T-102"]
##   →  to_enqueue       = ["T-100", "T-102"]
##      to_ack_only      = ["T-101"]
##      to_discard_local = ["T-103"]
##
## @param local_pending   Transition IDs of drops present in client loot.pending.* namespace.
## @param local_revealed  Transition IDs of drops the client has already shown to the player.
## @param backend_pending Transition IDs from GET /api/game/loot/pending (server-authoritative).
## @return Dictionary with keys "to_enqueue", "to_ack_only", "to_discard_local".
static func reconcile_local_vs_backend(
	local_pending: Array,
	local_revealed: Array,
	backend_pending: Array
) -> Dictionary:
	# Build lookup sets for O(1) membership testing.
	var bp_set: Dictionary = {}
	for tid: String in backend_pending:
		bp_set[tid] = true
	var lp_set: Dictionary = {}
	for tid: String in local_pending:
		lp_set[tid] = true
	var lr_set: Dictionary = {}
	for tid: String in local_revealed:
		lr_set[tid] = true

	# backend_pending ∖ (local_pending ∪ local_revealed) → enqueue for reveal.
	var to_enqueue: Array[String] = []
	for tid: String in backend_pending:
		if not lp_set.has(tid) and not lr_set.has(tid):
			to_enqueue.append(tid)

	# backend_pending ∩ local_revealed → ACK only; drop was already shown.
	var to_ack_only: Array[String] = []
	for tid: String in backend_pending:
		if lr_set.has(tid):
			to_ack_only.append(tid)

	# local_pending ∖ backend_pending → discard; backend does not know this drop.
	var to_discard_local: Array[String] = []
	for tid: String in local_pending:
		if not bp_set.has(tid):
			to_discard_local.append(tid)

	# CF-4: assert pairwise disjoint (catches caller logic errors in debug builds).
	var eq_set: Dictionary = {}
	for t: String in to_enqueue:
		eq_set[t] = true
	var ao_set: Dictionary = {}
	for t: String in to_ack_only:
		ao_set[t] = true
	var dl_set: Dictionary = {}
	for t: String in to_discard_local:
		dl_set[t] = true

	for t: String in to_enqueue:
		assert(
			not ao_set.has(t) and not dl_set.has(t),
			"CF-4 violation: transition_id '%s' appears in to_enqueue AND another output set" % t
		)
	for t: String in to_ack_only:
		assert(
			not dl_set.has(t),
			"CF-4 violation: transition_id '%s' appears in to_ack_only AND to_discard_local" % t
		)

	return {
		"to_enqueue": to_enqueue,
		"to_ack_only": to_ack_only,
		"to_discard_local": to_discard_local,
	}


# ── Formula 6 — Catch-up Threshold Compression ────────────────────────────────

## Switch catch-up reveal mode based on pending drop count.
##
## When a player returns after missing several days, accumulated drops are either
## revealed sequentially (few drops — each ceremony maintains full weight) or
## compressed into a summary banner + rapid burst (many drops — avoids ceremony
## fatigue and keeps the session moving).
##
## Threshold = 5 (GDD Rule 15):
##   pending_count < 5  → SEQUENTIAL_REVEAL   (0..4 drops)
##   pending_count ≥ 5  → SUMMARY_BANNER_THEN_BURST
##
## Example:
##   catch_up_threshold_compression(3)  → SEQUENTIAL_REVEAL
##   catch_up_threshold_compression(5)  → SUMMARY_BANNER_THEN_BURST
##   catch_up_threshold_compression(8)  → SUMMARY_BANNER_THEN_BURST
##
## @param pending_count Number of unrevealed drops in the reveal queue.
## @return              LootEnums.CatchUpMode ordinal.
static func catch_up_threshold_compression(pending_count: int) -> int:
	const CATCH_UP_THRESHOLD: int = 5
	if pending_count < CATCH_UP_THRESHOLD:
		return LootEnums.CatchUpMode.SEQUENTIAL_REVEAL
	return LootEnums.CatchUpMode.SUMMARY_BANNER_THEN_BURST
