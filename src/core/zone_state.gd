## ZoneState — #19 `zone.state` single-key persistence envelope (Story 003).
##
## Driving GDD: design/gdd/zone-system.md Rule 5 (single envelope — count and the
## two dedup cursors are an ATOMIC pair; splitting keys risks double-count on a
## crash between writes). ADR-0006 C3 / ADR-0009.
##
## JSON round-trip: unlocked_zone_ids / ceremony_pending land back as generic
## Array[String] — from_dict() REBUILDS the typed Array[StringName] (the first
## typed-array round-trip in the codebase; assigning the generic array directly
## is a runtime error).
class_name ZoneState extends SerializableResource


var workout_count: int = 0
var last_counted_transition_id: String = ""
## ISO "YYYY-MM-DD" UTC date — lexicographic order IS chronological order, so the
## monotone `<=` guard is a plain String compare. Initial "" satisfies the guard
## naturally (any real date > "").
var last_counted_date: String = ""
var unlocked_zone_ids: Array[StringName] = []
var ceremony_pending: Array[StringName] = []


func to_dict() -> Dictionary:
	var unlocked: Array = []
	for id: StringName in unlocked_zone_ids:
		unlocked.append(String(id))
	var pending: Array = []
	for id: StringName in ceremony_pending:
		pending.append(String(id))
	return {
		"schema_version": 1,
		"workout_count": workout_count,
		"last_counted_transition_id": last_counted_transition_id,
		"last_counted_date": last_counted_date,
		"unlocked_zone_ids": unlocked,
		"ceremony_pending": pending,
	}


## Defensive reconstruction; corrupt/partial input degrades to empty fields
## (ALWAYS zones are derived — a wiped manifest never locks the player out, EC-1).
static func from_dict(data: Dictionary) -> ZoneState:
	var s := ZoneState.new()
	s.workout_count = maxi(0, int(data.get("workout_count", 0)))
	s.last_counted_transition_id = str(data.get("last_counted_transition_id", ""))
	s.last_counted_date = str(data.get("last_counted_date", ""))
	var raw_unlocked: Variant = data.get("unlocked_zone_ids", [])
	if raw_unlocked is Array:
		for v: Variant in raw_unlocked:
			if v is String or v is StringName:
				s.unlocked_zone_ids.append(StringName(v))
	var raw_pending: Variant = data.get("ceremony_pending", [])
	if raw_pending is Array:
		for v: Variant in raw_pending:
			if v is String or v is StringName:
				s.ceremony_pending.append(StringName(v))
	return s
