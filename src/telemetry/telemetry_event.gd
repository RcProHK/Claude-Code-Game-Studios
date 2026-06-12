class_name TelemetryEvent extends RefCounted
## Telemetry (#28) — structured, versioned, de-identified event envelope (Rule 3).
##
## Fixed 8-field schema. `payload` is a per-event-name dict holding ONLY normalized /
## de-identified values (Rule 4 — never raw bodyweight / absolute weight / absolute 1RM;
## body data is normalized at the source before it ever reaches telemetry). `priority`
## is buffer metadata (Rule 5 — Story 004 eviction policy); it is NOT serialized into the
## on-wire envelope (the backend does not need the client's eviction tier).
##
## RefCounted (not Resource) — allocation-light per Rule 2 (one envelope per handled
## signal, no .tres I/O). The on-wire form is produced by to_dict() at flush time.
##
## Governing: design/gdd/telemetry.md Rule 3/4/14; ADR-0009 (typed payload envelope).

enum Priority { CRITICAL, STANDARD, LOW }

# --- The 8 fixed envelope fields (Rule 3) -------------------------------------
var event_name: StringName = &""
var schema_version: int = 1
var client_event_id: int = 0
var session_id: String = ""
var client_ts_unix: int = 0
var client_ts_monotonic_ms: int = 0
var game_state: StringName = &"UNKNOWN"
var payload: Dictionary = {}

# --- Buffer metadata (Rule 5; NOT part of the on-wire envelope) ---------------
var priority: int = Priority.STANDARD


## On-wire envelope (Rule 6 flush serialize). `priority` is intentionally excluded —
## it is a client-side buffer tier, not backend data. StringName fields are emitted as
## plain String for JSON compatibility (Rule 14 frozen field set lives inside `payload`).
func to_dict() -> Dictionary:
	return {
		"event_name": String(event_name),
		"schema_version": schema_version,
		"client_event_id": client_event_id,
		"session_id": session_id,
		"client_ts_unix": client_ts_unix,
		"client_ts_monotonic_ms": client_ts_monotonic_ms,
		"game_state": String(game_state),
		"payload": payload,
	}
