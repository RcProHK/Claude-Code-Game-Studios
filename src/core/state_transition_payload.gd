## StateTransitionPayload — Canonical payload for GameStateMachine.state_changed
##
## Driving GDD: design/gdd/game-state-machine.md lines 597-602 (Resources block).
## Governing ADRs: ADR-0006 (Accepted 2026-05-28) Contract 3 (envelope) + Contract
## 6 (initial-state sentinel) + Contract 7 (race guard).
##
## Carried by every `state_changed(from, to, payload)` emit — including the
## sentinel-delivery path used by `connect_for_initial_state` (ADR-0006 line 343
## defines `INITIAL_STATE_PAYLOAD_SOURCE_EVENT = "initial_state"`; subscribers
## detect that case via `payload.source_event == "initial_state"`).
##
## WHY extend SerializableResource (not plain Resource):
## Forward-recovery (ADR-0006 Contract 2 line 153) replays the tombstone payload
## stored in `user://state.json`. If the payload field on the tombstone holds a
## raw Resource, `JSON.stringify` silently drops the typed fields (ADR-0006 line
## 266 + the Pass-3 godot-specialist bug citation). Going through `to_dict()` /
## `from_dict()` preserves them.
class_name StateTransitionPayload extends SerializableResource


## Opaque transition identifier per ADR-0006 Contract 2 (line 170 binding rule:
## "transition_id is opaque — no code may parse it to recover from / to / counter").
## Format documented in Contract 2 is for backend UNIQUE constraint lookup +
## debug-log inspection ONLY. Forward-recovery MUST reuse this verbatim (Contract
## 2 line 166) — never call `_generate_transition_id` on the recovery path.
@export var transition_id: String = ""


## Human-readable origin tag. Canonical values include "workout_completed",
## "boss_defeated", "deferred_reveal", "session_invalidated", and the Contract 6
## sentinel "initial_state". Consumer GDDs document additional values per state.
@export var source_event: String = ""


## Per-state schema bag. Documented in consumer GDDs (e.g. BossPayload lives at
## `data["boss"]` per GDD line 603, AC-11a line 687). Resources placed into this
## bag MUST themselves extend SerializableResource so Contract 3 round-trip
## holds — see SerializableResource doc comment.
@export var data: Dictionary = {}


## Convert to plain Dictionary per ADR-0006 Contract 3 (lines 222-247 tombstone
## write path). The `data` field is shallow-copied; any nested SerializableResource
## inside `data` must itself have been pre-converted to Dictionary by the caller
## (Contract 3 currently keeps this responsibility at the call site — see the
## tombstone-write block in GameStateMachine for how BossPayload nesting is
## handled before reaching this method).
func to_dict() -> Dictionary:
	return {
		"transition_id": transition_id,
		"source_event": source_event,
		"data": data,
	}


## Reconstruct from Dictionary per ADR-0006 Contract 3 read path (lines 250-264).
## Defensive `get(key, default)` use guards against older-schema tombstones that
## a migration step (Contract 10, line 502) may not yet have rewritten.
static func from_dict(data_dict: Dictionary) -> SerializableResource:
	var payload: StateTransitionPayload = StateTransitionPayload.new()
	payload.transition_id = data_dict.get("transition_id", "")
	payload.source_event = data_dict.get("source_event", "")
	payload.data = data_dict.get("data", {})
	return payload
