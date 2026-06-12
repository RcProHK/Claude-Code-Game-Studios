class_name TelemetryConfig extends Resource
## Telemetry (#28) — data-driven tuning knobs (Story 017). All telemetry tuning lives
## here, never hardcoded (coding-standards: gameplay/behaviour values are data-driven).
## Telemetry loads the shipped `assets/data/telemetry_config.tres`; tests inject a mock
## via `Telemetry.set_config()` to avoid autoload-cache pollution
## ([[reference_test_persistence_isolation]] posture).
##
## The 12 knobs mirror the design/gdd/telemetry.md §Tuning Knobs table exactly (the story
## header's "13" was an off-by-one — the GDD table and AC list both enumerate 12). Defaults
## below are the GDD canonical defaults; `dup_window_ms` is 1000 per the GDD (the Story 010
## code shipped a 5000 const — Story 017 reconciles the runtime default to the GDD).
##
## Governing: design/gdd/telemetry.md §Tuning Knobs + §Cross-knob invariants (INV-T1..4).

# --- Ring buffer (Rule 5/7) ---------------------------------------------------
@export var buffer_max: int = 2000                  ## TELEMETRY_BUFFER_MAX [500, 10000]
@export var critical_reserved: int = 256            ## TELEMETRY_CRITICAL_RESERVED [64, 1024]

# --- Flush (Rule 6; consumed by Story 011) ------------------------------------
@export var flush_batch_size: int = 100             ## events per batch POST [20, 500]
@export var flush_interval_seconds: float = 30.0    ## periodic flush cadence [10, 120]
@export var flush_base_delay_seconds: float = 2.0   ## TELEMETRY_FLUSH_BASE_DELAY [1, 5]
@export var flush_retry_cap_seconds: float = 60.0   ## TELEMETRY_FLUSH_RETRY_CAP [16, 300]

# --- Sampling / glance proxies (Formula 1/2/3) --------------------------------
@export var hit_sample_stride: int = 10             ## HIT_SAMPLE_STRIDE [1, 100]
@export var switch_latency_buckets_ms: Array[int] = [5000, 15000, 60000, 180000]  ## ascending 4 boundaries
@export var foreground_sample_interval_ms: int = 1000  ## [250, 5000] (latent — tracker is event-driven)

# --- Session / dedup (Rule 11 / EC-03) ----------------------------------------
@export var session_resume_ttl_seconds: int = 1800  ## bfcache session boundary [300, 7200]
@export var dup_window_ms: int = 1000               ## EC-03 duplicate window [100, 5000]

# --- Privacy master switch (EC-17) --------------------------------------------
@export var telemetry_enabled: bool = true          ## opt-out master (Story 016 reads this)


## Cross-knob invariants (INV-T1..4). Pure predicate — returns "" when valid, else the
## first violation reason. No push_error (so tests can probe a bad config without tripping
## the .gutconfig engine-error gate; the same pattern as TelemetryBuffer.validate_config).
func validate() -> String:
	# INV-T1 — the CRITICAL reserve must leave room for STANDARD/LOW in the main ring.
	if critical_reserved >= buffer_max:
		return "INV-T1: critical_reserved (%d) must be < buffer_max (%d)" % [critical_reserved, buffer_max]
	# INV-T2 — a single flush batch cannot exceed what the buffer can hold.
	if flush_batch_size > buffer_max:
		return "INV-T2: flush_batch_size (%d) must be <= buffer_max (%d)" % [flush_batch_size, buffer_max]
	# INV-T3 — the latency bucket boundaries must be strictly ascending.
	if switch_latency_buckets_ms.is_empty():
		return "INV-T3: switch_latency_buckets_ms must not be empty"
	for i in range(1, switch_latency_buckets_ms.size()):
		if switch_latency_buckets_ms[i] <= switch_latency_buckets_ms[i - 1]:
			return "INV-T3: switch_latency_buckets_ms must be strictly ascending (index %d: %d <= %d)" \
				% [i, switch_latency_buckets_ms[i], switch_latency_buckets_ms[i - 1]]
	# INV-T4 — the backoff floor cannot exceed its cap.
	if flush_base_delay_seconds > flush_retry_cap_seconds:
		return "INV-T4: flush_base_delay_seconds (%.1f) must be <= flush_retry_cap_seconds (%.1f)" \
			% [flush_base_delay_seconds, flush_retry_cap_seconds]
	return ""
