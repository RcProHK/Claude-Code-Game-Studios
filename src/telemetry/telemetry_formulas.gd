class_name TelemetryFormulas extends RefCounted
## Telemetry (#28) — pure formula library (deterministic, no RNG, no time dependency).
##
## All time quantities are integer milliseconds (GDD 整數紀律). These are stateless pure
## functions — same input → same output — so they unit-test in isolation and never touch
## the autoload's mutable state.
##
## Contents:
##   Formula 3 — hit_sample_keep   (high-frequency sampling decision; Story 005)
##   Formula 1 — switch_latency_*  (glance proxy; Story 006)
##   Formula 2 — foreground_ratio  (glance proxy; Story 007)
##
## Governing: design/gdd/telemetry.md Formulas §.

## Formula 1 default bucket boundaries (ms), strictly ascending (INV-T3). 4 edges → 5
## buckets: <5s / 5–15s / 15–60s / 60–180s / >180s. Only the bucket INDEX is ever emitted
## (de-id — the raw rest duration would leak training detail).
const SWITCH_LATENCY_BUCKETS_MS: Array[int] = [5000, 15000, 60000, 180000]


## Formula 3 — hit_sample_keep. An individual hit event is buffered only when this is
## true; the lossless accumulator (Formula 4 / CombatAggregate) updates REGARDLESS.
##   keep = (hit_index % stride == 0) OR force_keep
## `force_keep` folds in BOTH is_crit AND damage_tier == CRITICAL — the caller computes
## it (AC-06: a crit is never sampled away). stride <= 0 is treated as 1 (full keep).
static func hit_sample_keep(hit_index: int, stride: int, force_keep: bool) -> bool:
	if force_keep:
		return true
	var k: int = stride if stride > 0 else 1
	return hit_index % k == 0


## Formula 1 — raw switch latency (ms) between a REST_PERIOD entry and the next SET_ACTIVE
## entry (both = the phase_changed client_ts_monotonic_ms). Never emitted raw — see bucket.
static func switch_latency_ms(ts_rest_entry: int, ts_set_active_entry: int) -> int:
	return ts_set_active_entry - ts_rest_entry


## Formula 1 — bucket index for a latency, against ascending `boundaries`. Returns
## 0..boundaries.size() (the open-ended top bucket). This index is the de-identified value
## that gets emitted. A negative latency (shouldn't happen on a monotonic clock) → bucket 0.
static func switch_latency_bucket(latency_ms: int,
		boundaries: Array = SWITCH_LATENCY_BUCKETS_MS) -> int:
	for i in range(boundaries.size()):
		if latency_ms < int(boundaries[i]):
			return i
	return boundaries.size()


## INV-T3 predicate — bucket boundaries must be strictly ascending. Pure (no push_error)
## so tests can probe it without tripping the engine-error gate.
static func buckets_strictly_ascending(boundaries: Array) -> bool:
	for i in range(1, boundaries.size()):
		if int(boundaries[i]) <= int(boundaries[i - 1]):
			return false
	return true


## Formula 2 — foreground time ratio (glance proxy: in-session attention). R = t_fg /
## max(t_total, 1), clamped to [0, 1]. EC-06: t_total == 0 → 1.0 (no data → assume full
## foreground, avoids div-by-zero).
static func foreground_ratio(t_foreground_ms: int, t_total_ms: int) -> float:
	if t_total_ms <= 0:
		return 1.0
	return clampf(float(t_foreground_ms) / float(t_total_ms), 0.0, 1.0)


## Formula 5 — flush retry exponential backoff (seconds). delay = min(BASE × 2^(n−1), CAP)
## for the n-th consecutive failure (n >= 1); n <= 0 (no failures) → 0.0 (flush immediately).
## Reuses the registry retry_delay backoff SHAPE with telemetry's own BASE/CAP knobs
## (telemetry.md Formula 5; ADR-0012 §Auth — 5xx / timeout backoff). A 429 Retry-After
## overrides this (handled at the call site). Pure: same (n, base, cap) → same delay.
static func flush_backoff_delay(failure_count: int, base_seconds: float, cap_seconds: float) -> float:
	if failure_count <= 0:
		return 0.0
	var delay: float = base_seconds * pow(2.0, float(failure_count - 1))
	return minf(delay, cap_seconds)
