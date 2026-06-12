# Telemetry (#28) — Story 017: TelemetryConfig data-driven knobs + INV-T1..4.
#
# Verifies:
#   AC-1  the shipped .tres loads the 12 GDD-default knobs; a fresh config = code defaults
#         (the "missing field → default fallback" posture); the injectable seam overrides
#         the runtime knobs without touching the real autoload cache.
#   AC-2  each cross-knob invariant (INV-T1..4) rejects a violating config via validate(),
#         including the INV-T1 boundary (reserved == buffer-1 OK; == buffer FAIL).
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")
const CONFIG_PATH: String = "res://assets/data/telemetry_config.tres"


func _fresh() -> TelemetryConfig:
	return TelemetryConfig.new()


# --- AC-1: defaults + load ----------------------------------------------------

func test_shipped_tres_loads_gdd_defaults() -> void:
	assert_true(ResourceLoader.exists(CONFIG_PATH), "shipped TelemetryConfig.tres exists")
	var cfg: TelemetryConfig = load(CONFIG_PATH)
	assert_eq(cfg.buffer_max, 2000, "TELEMETRY_BUFFER_MAX default")
	assert_eq(cfg.critical_reserved, 256, "TELEMETRY_CRITICAL_RESERVED default")
	assert_eq(cfg.flush_batch_size, 100, "flush_batch_size default")
	assert_eq(cfg.flush_interval_seconds, 30.0, "flush_interval_seconds default")
	assert_eq(cfg.hit_sample_stride, 10, "HIT_SAMPLE_STRIDE default")
	assert_eq(cfg.switch_latency_buckets_ms, [5000, 15000, 60000, 180000], "SWITCH_LATENCY_BUCKETS_MS default")
	assert_eq(cfg.session_resume_ttl_seconds, 1800, "session_resume_ttl_seconds default")
	assert_eq(cfg.dup_window_ms, 1000, "dup_window_ms GDD default (Story 017 reconciliation, was 5000 const)")
	assert_eq(cfg.foreground_sample_interval_ms, 1000, "foreground_sample_interval_ms default")
	assert_eq(cfg.flush_base_delay_seconds, 2.0, "TELEMETRY_FLUSH_BASE_DELAY default")
	assert_eq(cfg.flush_retry_cap_seconds, 60.0, "TELEMETRY_FLUSH_RETRY_CAP default")
	assert_true(cfg.telemetry_enabled, "telemetry_enabled default true (opt-out master)")


func test_fresh_config_equals_code_defaults_and_is_valid() -> void:
	var cfg := _fresh()
	assert_eq(cfg.validate(), "", "the code-default config satisfies all INV-T")
	assert_eq(cfg.buffer_max, 2000, "fresh config = code default (missing-field fallback posture)")
	assert_eq(cfg.dup_window_ms, 1000, "fresh config dup_window_ms = GDD default")


# --- AC-1: boot + injectable seam applies to runtime knobs --------------------

func test_boot_applies_shipped_config_to_runtime() -> void:
	var t = TelemetryScript.new()
	add_child_autofree(t)   # _ready loads the shipped .tres
	assert_eq(t._dup_window_ms, 1000, "boot applied shipped dup_window_ms")
	assert_eq(t._hit_sample_stride, 10, "boot applied shipped hit_sample_stride")
	assert_eq(t._session_resume_ttl_ms, 1800 * 1000, "boot applied session ttl (s→ms)")
	assert_eq(t._buffer_max, 2000, "boot applied buffer_max")


func test_injected_config_overrides_runtime() -> void:
	var t = TelemetryScript.new()
	add_child_autofree(t)
	var cfg := _fresh()
	cfg.dup_window_ms = 3000
	cfg.hit_sample_stride = 25
	cfg.session_resume_ttl_seconds = 600
	cfg.telemetry_enabled = false
	t.set_config(cfg)   # re-applies because telemetry is already booted
	assert_eq(t._dup_window_ms, 3000, "injected config overrides dup_window_ms")
	assert_eq(t._hit_sample_stride, 25, "injected config overrides hit_sample_stride")
	assert_eq(t._session_resume_ttl_ms, 600 * 1000, "injected config overrides session ttl")
	assert_false(t.is_telemetry_enabled(), "injected telemetry_enabled=false applied to opt-out switch")


func test_pre_ready_injected_config_wins_over_shipped() -> void:
	var t = TelemetryScript.new()
	var cfg := _fresh()
	cfg.dup_window_ms = 4321
	t.set_config(cfg)        # injected BEFORE add_child → _ready keeps it (DI override)
	add_child_autofree(t)
	assert_eq(t._dup_window_ms, 4321, "pre-_ready injected config is honored over the shipped .tres")


# --- AC-2: cross-knob invariants ----------------------------------------------

func test_inv_t1_reserved_must_be_below_buffer() -> void:
	var cfg := _fresh()
	cfg.buffer_max = 1000
	cfg.critical_reserved = 999   # boundary OK: buffer-1
	assert_eq(cfg.validate(), "", "INV-T1 boundary reserved == buffer-1 is valid")
	cfg.critical_reserved = 1000  # == buffer FAIL
	assert_string_contains(cfg.validate(), "INV-T1", "reserved == buffer must fail INV-T1")
	cfg.critical_reserved = 1500  # > buffer FAIL
	assert_string_contains(cfg.validate(), "INV-T1", "reserved > buffer must fail INV-T1")


func test_inv_t2_batch_must_not_exceed_buffer() -> void:
	var cfg := _fresh()
	cfg.buffer_max = 2000
	cfg.flush_batch_size = 2000   # == buffer OK
	assert_eq(cfg.validate(), "", "INV-T2 boundary batch == buffer is valid")
	cfg.flush_batch_size = 2001   # > buffer FAIL
	assert_string_contains(cfg.validate(), "INV-T2", "batch > buffer must fail INV-T2")


func test_inv_t3_buckets_must_be_strictly_ascending() -> void:
	var cfg := _fresh()
	cfg.switch_latency_buckets_ms = [5000, 5000, 60000]   # not strictly ascending
	assert_string_contains(cfg.validate(), "INV-T3", "equal adjacent boundaries must fail INV-T3")
	cfg.switch_latency_buckets_ms = [60000, 15000, 5000]  # descending
	assert_string_contains(cfg.validate(), "INV-T3", "descending boundaries must fail INV-T3")
	cfg.switch_latency_buckets_ms = []                     # empty
	assert_string_contains(cfg.validate(), "INV-T3", "empty boundary list must fail INV-T3")


func test_inv_t4_base_delay_must_not_exceed_cap() -> void:
	var cfg := _fresh()
	cfg.flush_base_delay_seconds = 60.0
	cfg.flush_retry_cap_seconds = 60.0   # == cap OK
	assert_eq(cfg.validate(), "", "INV-T4 boundary base == cap is valid")
	cfg.flush_base_delay_seconds = 61.0  # > cap FAIL
	assert_string_contains(cfg.validate(), "INV-T4", "base > cap must fail INV-T4")


func test_injected_invalid_config_is_not_applied() -> void:
	# An invalid injected config must NOT corrupt the runtime knobs — set_config() applies
	# only a config that passes validate(), so the runtime keeps its prior safe values
	# (telemetry never crashes gameplay, Rule 1). (No push_error here — that path lives in
	# _resolve_config and is deliberately not exercised so the .gutconfig engine-error gate
	# is not tripped; the pure validate() invariant tests above already prove detection.)
	var t = TelemetryScript.new()
	add_child_autofree(t)   # booted with the shipped config → dup_window 1000
	var bad := _fresh()
	bad.dup_window_ms = 9999
	bad.critical_reserved = bad.buffer_max   # INV-T1 violation → whole config invalid
	t.set_config(bad)
	assert_eq(t._dup_window_ms, 1000, "an invalid injected config is rejected — runtime knobs unchanged")
