class_name SwitchLatencyTracker extends RefCounted
## Telemetry (#28) — Formula 1 anchor state machine (glance proxy).
##
## Records the last REST_PERIOD entry monotonic ts as the anchor; on the next SET_ACTIVE
## entry it returns the de-identified bucket index and clears the anchor. With NO anchor a
## SET_ACTIVE produces nothing (edge b — first SET_ACTIVE has no preceding REST). A
## WORKOUT_COMPLETE (or any terminal) clears the anchor WITHOUT emitting (edge a, EC-04).
##
## Story 008 wires the real phase_changed subscription into these calls; tests feed phases
## directly. Stateful, so it lives outside the pure TelemetryFormulas library.
##
## Governing: design/gdd/telemetry.md Formula 1, Rule 9, EC-04, AC-05.

const NO_ANCHOR: int = -1
## Sentinel returned by on_set_active when there is no REST anchor (edge b → no event).
const NO_EVENT: int = -1

var _rest_anchor_ms: int = NO_ANCHOR


## phase_changed(_, REST_PERIOD): set the anchor to this entry's monotonic ts.
func on_rest_period(monotonic_ms: int) -> void:
	_rest_anchor_ms = monotonic_ms


## phase_changed(_, SET_ACTIVE): if an anchor exists, return the bucket index [0..N] and
## clear the anchor; otherwise return NO_EVENT (edge b). The anchor is cleared either way
## (a SET_ACTIVE always consumes the pending rest, even the spurious no-anchor case).
func on_set_active(monotonic_ms: int,
		boundaries: Array = TelemetryFormulas.SWITCH_LATENCY_BUCKETS_MS) -> int:
	if _rest_anchor_ms == NO_ANCHOR:
		return NO_EVENT  # edge b — no preceding REST_PERIOD
	var latency: int = TelemetryFormulas.switch_latency_ms(_rest_anchor_ms, monotonic_ms)
	_rest_anchor_ms = NO_ANCHOR
	return TelemetryFormulas.switch_latency_bucket(latency, boundaries)


## phase_changed(_, WORKOUT_COMPLETE) or any non-SET_ACTIVE terminal: clear the anchor
## without emitting (edge a, EC-04 — the final set has no "next exercise" to time).
func clear_anchor() -> void:
	_rest_anchor_ms = NO_ANCHOR


func has_anchor() -> bool:
	return _rest_anchor_ms != NO_ANCHOR
