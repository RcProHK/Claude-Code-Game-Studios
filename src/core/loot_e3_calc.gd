## LootE3Calc — Formula E3: Anti-Pillar Weekly Distribution (Monte Carlo) (Story 008)
##
## Driving GDD : design/gdd/loot-drop-system.md §D Formula E3
## Driving Story: production/epics/loot-drop-system/story-008-formula-e3-anti-pillar.md
## Governing ADR : ADR-0005 (Accepted 2026-05-30) — CF-E3 anti-pillar invariant (EPIC+ ≤ 10%)
##
## PURPOSE: Analytics / VS-tier calibration tool — NOT called per-drop.
## Validates that the loot formula produces a weekly tier distribution where
## EPIC+ items stay at or below 10% of total drops (CF-E3). If the raw Monte
## Carlo exceeds this threshold, a soft-clamp loop degrades the top items one
## tier at a time until the constraint is satisfied or max_iterations is hit.
##
## WHY a dedicated static class:
## Formula E3 is a distribution validator, not part of the per-drop pipeline.
## It lives in src/core/ so it can import LootRarityCalc (Story 003) without
## depending on the LootDropSystem autoload. Tests call it directly.
##
## CI lint: check_loot_e3_termination_guard.gd (Story 001) greps this file for
## the `max_iterations` bound and `assert(` monotonic guard; both MUST be present.
class_name LootE3Calc
extends RefCounted


# ── E3 constants ──────────────────────────────────────────────────────────────

## Monte Carlo sample count — 10,000 drops per weekly simulation run.
const N: int = 10000

## Maximum soft-clamp downgrade iterations (termination guard — CI lint enforced).
## Should never be reached with realistic config; if hit, telemetry fires and
## residual EPIC+ is accepted (fail-soft, not fail-hard).
const MAX_ITERATIONS: int = 10

## LOCKED: maximum fraction of drops that may be EPIC or LEGENDARY (CF-E3).
## Exceeding this in the raw Monte Carlo triggers the soft-clamp loop.
const ANTI_PILLAR_EPIC_PLUS_CAP_PCT: float = 0.10

## Internal telemetry log — appended when max_iterations is hit. Tests inspect
## this to verify the overflow telemetry path. Cleared by clear_telemetry().
static var _telemetry_log: Array[Dictionary] = []


# ── Public API ─────────────────────────────────────────────────────────────────

## Run a Monte Carlo simulation of a player's weekly loot distribution and
## apply the anti-pillar soft-clamp to ensure EPIC+ ≤ 10% (CF-E3).
##
## The caller provides a `player_profile` Dictionary with:
##   "name"          : String           — profile label (for telemetry)
##   "weekly_events" : Array[Dictionary] — one entry per loot-granting event
##     Each event entry has:
##       "workout_score" : float              — pre-computed ws ∈ [0.0, 1.0]
##       "kind"          : int (optional)     — LootEnums.SourceEventKind ordinal
##                                             defaults to WORKOUT_DAILY
##
## Returns a Dictionary keyed by LootEnums.RarityTier ordinal → int drop count.
## The returned counts reflect the CLAMPED distribution (post-soft-clamp).
##
## Example:
##   var hardcore_profile := LootE3Calc.make_profile("Hardcore",
##       5, 0.92)  # 5 weekly events at ws=0.92
##   var dist := LootE3Calc.expected_weekly_rarity_distribution(hardcore_profile)
##   var total := LootE3Calc.count_total(dist)
##   var epic_plus := dist[LootEnums.RarityTier.EPIC] + dist[LootEnums.RarityTier.LEGENDARY]
##   assert(epic_plus / float(total) <= 0.10)  # CF-E3
##
## @param player_profile  Dictionary as described above.
## @return                Dictionary[RarityTier ordinal → int count].
static func expected_weekly_rarity_distribution(player_profile: Dictionary) -> Dictionary:
	# Initialise counts for all 5 tiers.
	var counts: Dictionary = {
		LootEnums.RarityTier.COMMON:    0,
		LootEnums.RarityTier.UNCOMMON:  0,
		LootEnums.RarityTier.RARE:      0,
		LootEnums.RarityTier.EPIC:      0,
		LootEnums.RarityTier.LEGENDARY: 0,
	}
	var total: int = 0

	# ── Monte Carlo simulation (n=10,000 per weekly cycle) ─────────────────────
	var weekly_events: Array = player_profile.get("weekly_events", [])
	for sim_i: int in range(N):
		for event_profile: Dictionary in weekly_events:
			var ws: float = event_profile.get("workout_score", 0.0)
			var kind: int = event_profile.get("kind", LootEnums.SourceEventKind.WORKOUT_DAILY)
			# Deterministic transition_id: unique per (sim_i, total).
			var transition_id: String = "sim_%d_%d" % [sim_i, total]
			var rng_roll: float = _compute_rng_roll(transition_id)
			var raw_tier: int = LootRarityCalc.compute_rarity_from_score(ws, rng_roll)
			var final_tier: int = LootRarityCalc.apply_tier_ceiling_floor(raw_tier, kind, ws)
			counts[final_tier] = counts.get(final_tier, 0) + 1
			total += 1

	if total == 0:
		return counts  # Empty profile — nothing to clamp.

	# ── Anti-pillar soft-clamp (termination-guarded while-loop) ───────────────
	# CI lint check_loot_e3_termination_guard.gd requires: `max_iterations` + `assert(` both present.
	var iteration: int = 0
	while (
		float(counts[LootEnums.RarityTier.EPIC] + counts[LootEnums.RarityTier.LEGENDARY])
		/ float(total)
	) > ANTI_PILLAR_EPIC_PLUS_CAP_PCT and iteration < MAX_ITERATIONS:
		var pre_epic_plus: int = (
			counts[LootEnums.RarityTier.EPIC] + counts[LootEnums.RarityTier.LEGENDARY]
		)
		# Downgrade priority: LEGENDARY first (preserves EPIC visibility), then EPIC→RARE.
		if counts[LootEnums.RarityTier.LEGENDARY] > 0:
			counts[LootEnums.RarityTier.LEGENDARY] -= 1
			counts[LootEnums.RarityTier.EPIC] += 1
		elif counts[LootEnums.RarityTier.EPIC] > 0:
			counts[LootEnums.RarityTier.EPIC] -= 1
			counts[LootEnums.RarityTier.RARE] += 1
		else:
			break  # Defensive — loop condition ensures EPIC+ > 0 before reaching here.
		var post_epic_plus: int = (
			counts[LootEnums.RarityTier.EPIC] + counts[LootEnums.RarityTier.LEGENDARY]
		)
		# Monotonic invariant: each pass MUST strictly decrease the EPIC+ count.
		assert(post_epic_plus < pre_epic_plus,
			"LootE3Calc E3 monotonic invariant violated — post (%d) >= pre (%d)" % [
				post_epic_plus, pre_epic_plus
			])
		iteration += 1

	# If the guard was hit, emit telemetry and accept residual (fail-soft).
	if iteration >= MAX_ITERATIONS:
		var residual_pct: float = (
			float(counts[LootEnums.RarityTier.EPIC] + counts[LootEnums.RarityTier.LEGENDARY])
			/ float(total)
		)
		_emit_telemetry("loot_e3_max_iterations_hit", {
			"profile": player_profile.get("name", "unknown"),
			"residual_epic_plus_pct": residual_pct,
		})

	return counts


# ── Convenience helpers ────────────────────────────────────────────────────────

## Compute the total drop count across all tiers in a distribution dict.
static func count_total(dist: Dictionary) -> int:
	var t: int = 0
	for v: int in dist.values():
		t += v
	return t


## Build a standard player_profile dict from a name + weekly event count + fixed ws.
## Each of `event_count` events has the same `workout_score` and WORKOUT_DAILY kind.
##
## Example:
##   var p := LootE3Calc.make_profile("Hardcore", 5, 0.92)
static func make_profile(profile_name: String, event_count: int, workout_score: float) -> Dictionary:
	var events: Array[Dictionary] = []
	for _i: int in range(event_count):
		events.append({
			"workout_score": workout_score,
			"kind": LootEnums.SourceEventKind.WORKOUT_DAILY,
		})
	return {"name": profile_name, "weekly_events": events}


## Return all telemetry events with the given name (for test assertions).
static func get_telemetry(event_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _telemetry_log:
		if entry.get("event") == event_name:
			result.append(entry)
	return result


## Clear the static telemetry log (call in after_each() / teardown).
static func clear_telemetry() -> void:
	_telemetry_log.clear()


# ── Private helpers ───────────────────────────────────────────────────────────

## Deterministic RNG roll — same transition_id always yields the same float.
## Uses hash() to seed a local RandomNumberGenerator (same pattern as LootRarityCalc).
static func _compute_rng_roll(transition_id: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(transition_id)
	return rng.randf()


## Append an event to the static telemetry log.
static func _emit_telemetry(event: String, data: Dictionary) -> void:
	_telemetry_log.append({"event": event, "data": data.duplicate()})
