## LootDropParser — Backend ACK response parser (Story 010, AC-44)
##
## Driving GDD : design/gdd/loot-drop-system.md EC-22 + Rule 11 (server authority)
## Driving Story: production/epics/loot-drop-system/story-010-idempotency-guards.md
## Governing ADRs:
##   * ADR-0005 (Accepted 2026-05-30) — INV-4: rarity tier enum consistency
##   * ADR-0006 (Accepted) Contract 3 — string-name serialisation
##
## WHY a standalone static class:
## Backend ACK parsing is a pure transformation (response dict → validated dict).
## Isolating it from the autoload allows Story 013 (backend authority, BLOCKED on
## GymSys) to test this parser independently of the live HTTP layer.
##
## EC-22 (CRITICAL): if the backend returns a `rarity_tier` string not in the
## client's RarityTier enum (e.g., "MYTHIC"), the ACK is REJECTED. The client
## treats it as a timeout (EC-18 retry path) and emits a CRITICAL alert. It must
## NOT silently default to COMMON — that would accept a contract-violating backend
## response without surfacing the bug.
class_name LootDropParser
extends RefCounted


## Valid RarityTier string names (must match LootEnums.RarityTier keys exactly).
const VALID_RARITY_TIERS: PackedStringArray = [
	"COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"
]

## Static telemetry log — inspected by tests. Cleared by clear_telemetry().
static var _telemetry_log: Array[Dictionary] = []


## Parse a backend ACK response dictionary.
##
## Rules:
##   * `rarity_tier` field MUST be present and MUST be one of VALID_RARITY_TIERS.
##   * Any other `rarity_tier` value (e.g. "MYTHIC", "ULTRA", "") → reject +
##     CRITICAL telemetry; return {} (caller treats as timeout per EC-18).
##   * A valid response is returned unchanged (server is authoritative).
##
## Example (success):
##   parse_backend_ack({"rarity_tier": "RARE", "canonical_id": "C-007"})
##   → {"rarity_tier": "RARE", "canonical_id": "C-007"}
##
## Example (failure):
##   parse_backend_ack({"rarity_tier": "MYTHIC"})
##   → {} (+ CRITICAL telemetry emitted)
##
## @param response  Raw Dictionary from the backend HTTP response.
## @return          Validated response Dictionary, or {} on parse failure.
static func parse_backend_ack(response: Dictionary) -> Dictionary:
	var tier_str: String = str(response.get("rarity_tier", ""))

	if tier_str not in VALID_RARITY_TIERS:
		# EC-22: unknown tier → CRITICAL alert, treat as timeout, do NOT silent-default.
		_emit_telemetry("loot.backend.unknown_tier", {
			"received": tier_str,
			"severity": "CRITICAL",
			"valid_tiers": VALID_RARITY_TIERS,
		})
		return {}  # empty dict → caller routes to EC-18 retry path

	return response  # Valid — server is authoritative (Rule 11)


# ── Telemetry helpers ────────────────────────────────────────────────────────

## Return all telemetry events with the given name (for test assertions).
static func get_telemetry(event_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _telemetry_log:
		if entry.get("event") == event_name:
			result.append(entry)
	return result


## Clear static telemetry log (call in test after_each()).
static func clear_telemetry() -> void:
	_telemetry_log.clear()


static func _emit_telemetry(event: String, data: Dictionary) -> void:
	_telemetry_log.append({"event": event, "data": data.duplicate()})
	# TODO Story 028: forward to TelemetrySystem
