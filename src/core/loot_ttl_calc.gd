## LootTtlCalc — pure static implementations of Formula 3 + Formula 4 (Story 005)
##
## Driving GDD : design/gdd/loot-drop-system.md §D Formula 3 (Pending TTL Expiry)
##               design/gdd/loot-drop-system.md §D Formula 4 (bfcache Resume Action)
## Driving Story: production/epics/loot-drop-system/story-005-formula-3-4-ttl-bfcache.md
## Governing ADRs:
##   * ADR-0003 (Accepted 2026-05-30) Save State Strategy — lootdrop TTL constants
##     (SOFT_TTL_DAYS=30, HARD_CAP_DAYS=37, DRIFT_TOLERANCE_S=300)
##   * ADR-0006 (Accepted) Contract 15 — pending_since_server (backend timestamp)
##     is authoritative for hard-cap eviction; client timestamp is mirror only.
##
## WHY a dedicated static class (not inlined in loot_drop_system.gd):
## Formula 3 + 4 are O(1) arithmetic on timestamps and states — no autoload,
## no signals, no persistence. Keeping them pure and separately importable lets
## Story 009 (autoload boot TTL check) and Story 012 (persistence lifecycle) each
## import only what they need, and lets unit tests call them without instantiating
## the full autoload.
##
## CF-3 invariant: Formula 3 (process-level TTL, coarse days) and Formula 4
## (session-level bfcache, fine milliseconds) measure different things and MUST
## NOT be conflated.
class_name LootTtlCalc
extends RefCounted


# ── Formula 3 constants (ADR-0003 binding, CI-3 invariant) ────────────────────

## Soft TTL in days. Matching registry `lootdrop_pending_ttl_days` (CI-2).
## Past SOFT_TTL: drop is stale but still recoverable; ceremony degrades to
## a catch-up reveal rather than a fresh modal.
const SOFT_TTL_DAYS: int = 30

## Hard cap in days. Backend retains rows for this long; past hard cap the
## drop is evicted on next boot (ADR-0006 Contract 15 server-authoritative).
const HARD_CAP_DAYS: int = 37

## Clock-drift tolerance in seconds. Applied only at the SOFT boundary to
## protect against a client clock running slightly fast (which would otherwise
## prematurely expire a fresh drop). MUST match ADR-0003 wall-clock drift
## budget (CI-3) — value is 300s (±5 min).
const DRIFT_TOLERANCE_S: int = 300


# ── Formula 4 constants ────────────────────────────────────────────────────────

## Milliseconds — bfcache suspend delta below which a mid-reveal animation may
## continue on resume. Above this threshold the reveal is deferred to next boot
## (stale animation state would confuse the player).
const BFCACHE_CONTINUE_THRESHOLD_MS: int = 30000


# ── Formula 3 — Pending TTL Expiry ────────────────────────────────────────────

## Classify a pending LootDrop's age as FRESH / SOFT_EXPIRED / HARD_EXPIRED.
##
## Drift-tolerance logic (GDD Formula 3):
##   • SOFT boundary: use adjusted_age (age − DRIFT_TOLERANCE_S) so a client
##     clock running ≤5 min fast does not prematurely expire a valid drop.
##   • HARD boundary: use raw age so a client clock running slow cannot delay
##     eviction indefinitely.
##
## Callers should prefer `created_at_unix` sourced from the backend's
## `pending_since_server` field (ADR-0006 Contract 15). Client-only timestamps
## are acceptable for SOFT decisions but MUST NOT be used for HARD-cap eviction
## in production code.
##
## Example:
##   # Drop created 30d 4m ago, client clock runs +5min fast → FRESH
##   var state := LootTtlCalc.pending_ttl_expired(now - 2_592_240, now)
##   assert(state == LootEnums.ExpiryState.FRESH)
##
## @param created_at_unix  Unix timestamp (seconds) when the drop was persisted.
## @param now_unix         Current unix timestamp (seconds), typically from
##                         Time.get_unix_time_from_system() or backend clock.
## @return                 LootEnums.ExpiryState ordinal.
static func pending_ttl_expired(created_at_unix: int, now_unix: int) -> int:
	var age_s: int = now_unix - created_at_unix
	# Drift-adjusted age — only used for the SOFT boundary check.
	var adjusted_age_s: int = age_s - DRIFT_TOLERANCE_S

	if adjusted_age_s < SOFT_TTL_DAYS * 86400:
		return LootEnums.ExpiryState.FRESH
	elif age_s < HARD_CAP_DAYS * 86400:
		return LootEnums.ExpiryState.SOFT_EXPIRED
	else:
		return LootEnums.ExpiryState.HARD_EXPIRED


# ── Formula 4 — bfcache Resume Action ─────────────────────────────────────────

## Determine what to do with a LootDrop's reveal state after a bfcache
## freeze/thaw cycle (app backgrounded and foregrounded).
##
## Rules (GDD Formula 4):
##   PRE_REVEAL          → NO_ACTION    (ceremony plays on next user gesture)
##   POST_REVEAL_PRE_HANDOFF → CONTINUE_ANIMATION (finish the #17 handoff path)
##   MID_REVEAL + delta ≤ 30s → CONTINUE_ANIMATION (resume the paused modal)
##   MID_REVEAL + delta > 30s → DEFER_TO_NEXT_BOOT (stale animation → re-queue)
##
## Example:
##   var action := LootTtlCalc.bfcache_resume_action(
##       LootEnums.DropRevealState.MID_REVEAL, 1000, 13000  # delta = 12s → CONTINUE
##   )
##
## @param drop_state       LootEnums.DropRevealState ordinal when the app froze.
## @param suspended_at_ms  Monotonic ms timestamp when the app backgrounded.
## @param resumed_at_ms    Monotonic ms timestamp when the app foregrounded.
## @return                 LootEnums.ResumeAction ordinal.
static func bfcache_resume_action(
	drop_state: int, suspended_at_ms: int, resumed_at_ms: int
) -> int:
	match drop_state:
		LootEnums.DropRevealState.POST_REVEAL_PRE_HANDOFF:
			# Handoff finalisation is cheap and must always complete.
			return LootEnums.ResumeAction.CONTINUE_ANIMATION
		LootEnums.DropRevealState.PRE_REVEAL:
			# Not yet started — play on the next user gesture, no rush.
			return LootEnums.ResumeAction.NO_ACTION
		LootEnums.DropRevealState.MID_REVEAL:
			var delta_ms: int = resumed_at_ms - suspended_at_ms
			if delta_ms <= BFCACHE_CONTINUE_THRESHOLD_MS:
				return LootEnums.ResumeAction.CONTINUE_ANIMATION
			else:
				# Suspension was long; resuming a stale modal would feel jarring.
				return LootEnums.ResumeAction.DEFER_TO_NEXT_BOOT
	# Defensive fallback for unrecognised drop_state values.
	return LootEnums.ResumeAction.NO_ACTION
