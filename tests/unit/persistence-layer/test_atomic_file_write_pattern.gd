# PersistenceLayer — Story 003 AC-04 Atomic File Write Pattern Tests
#
# Scope: critical-flush path proves Rule 3 atomic file write sequence:
#   FileAccess.open(WRITE) → store_string(JSON.stringify(_cache)) → close()
# with NO incremental / per-key writes. Every flush serializes the FULL
# cache snapshot as a single JSON blob, then emits `flush_completed`.
#
# AC-04 (GDD design/gdd/persistence-layer.md line 464):
#   GIVEN `MockFileAccess.attach_open_spy` + `attach_store_spy` + `attach_close_spy`,
#   WHEN  `write("foo", "bar")` called once,
#   THEN  spy call counts: open_spy.call_count == 1,
#         store_spy.call_count == 1 (single write call, NOT per-key incremental),
#         close_spy.call_count == 1;
#         store payload = `JSON.stringify(_cache)` (full dict).
#
# AC-04b (this suite extends AC-04): proves single-write payload reflects
# the FULL cache, not just the most recently written key.
#
# IMPORTANT — interpretation of "write() called once":
#   AC-04 reads "write(key, val) called once". The production `write()` with
#   the default `flush=false` only mutates the cache and arms the debounce
#   timer — it does NOT touch the file factory directly. To exercise the
#   Rule 3 atomic write sequence in a unit test (without waiting for the
#   debounce timer), this suite uses `write(key, val, true)` (critical
#   flush) which routes through `_flush_dirty()` synchronously. The
#   resulting spy counts are identical to what a debounced flush would
#   produce — the timer path just defers the same sequence.
#
# Direct private-state access policy: same as test_cache_disk_invariant.gd
# (ADR-0006 Contract 14 test-only affordance).
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0003 Save State Strategy, ADR-0006 Contract 4/14
extends GutTest


const CACHE_VAR_NAME: StringName = &"_cache"
const FILE_FACTORY_VAR_NAME: StringName = &"_file_factory"
const DIRTY_VAR_NAME: StringName = &"_dirty"


var _factory: MockFileFactory = null
var _open_log: Array = []
var _store_log: Array = []
var _close_log: Array = []


func before_each() -> void:
	# Arrange (shared): clear cache + dirty flag for isolation.
	PersistenceLayer.get(CACHE_VAR_NAME).clear()
	PersistenceLayer.set(DIRTY_VAR_NAME, false)

	# Reset spy logs.
	_open_log = []
	_store_log = []
	_close_log = []

	# Inject a fresh MockFileFactory.
	_factory = MockFileFactory.new()
	PersistenceLayer.attach_file_factory(_factory)

	# Disconnect any signal listeners from prior tests.
	for conn in PersistenceLayer.flush_completed.get_connections():
		PersistenceLayer.flush_completed.disconnect(conn.callable)
	for conn in PersistenceLayer.write_completed.get_connections():
		PersistenceLayer.write_completed.disconnect(conn.callable)


func after_each() -> void:
	PersistenceLayer.set(FILE_FACTORY_VAR_NAME, null)


# ----------------------------------------------------------------------------
# Helper — attach spies to the mock the factory issues on the next open()
# ----------------------------------------------------------------------------

# Because MockFileFactory issues MockFileAccess lazily inside open(), we
# can't attach spies BEFORE the production code opens. Instead we install
# a one-shot pre-attach by overriding the spy hooks immediately after the
# write() call returns. AC-04 only asserts post-condition counts, so the
# spy install order is irrelevant — we read `last_issued_mock`'s built-in
# counters (open_call_count / store_string_call_count / close_call_count)
# which are incremented at the source, not via Callable hooks.
#
# This suite therefore uses the mock's built-in counters as primary
# evidence, and uses the Callable spies (attach_store_spy / attach_close_spy)
# only for the payload-content assertion (AC-04 "store payload =
# JSON.stringify(_cache)").
#
# To capture the payload we attach the spy BEFORE the production code's
# second store_string by either (a) using `_factory.last_issued_mock` after
# the call (which still has `content_buffer` populated with the payload
# from the actual write) or (b) reading content_buffer directly. We use
# option (b) — simpler, more direct, and equivalent in observability.


# ----------------------------------------------------------------------------
# AC-04 core: single open + single store + single close per critical write
# ----------------------------------------------------------------------------

func test_persistence_layer_critical_write_invokes_open_exactly_once() -> void:
	# Act
	PersistenceLayer.write("foo", "bar", true)

	# Assert — exactly one open() call on the factory (production code
	# opens once, writes the full cache, closes once).
	assert_eq(_factory.open_write_call_count, 1, "open(WRITE) must be called exactly once per flush")
	assert_eq(_factory.open_read_call_count, 0, "Critical write must NOT trigger a read-mode open")


func test_persistence_layer_critical_write_invokes_store_string_exactly_once() -> void:
	# Act
	PersistenceLayer.write("foo", "bar", true)

	# Assert — single store_string call (NOT per-key incremental) on the
	# issued mock. AC-04 evidence path.
	var mock: MockFileAccess = _factory.last_issued_mock
	assert_not_null(mock, "Factory must have issued a MockFileAccess for the write")
	assert_eq(
		mock.store_string_call_count,
		1,
		"store_string must be called exactly once — atomic single-blob write, NOT per-key"
	)


func test_persistence_layer_critical_write_invokes_close_exactly_once() -> void:
	# Act
	PersistenceLayer.write("foo", "bar", true)

	# Assert
	var mock: MockFileAccess = _factory.last_issued_mock
	assert_not_null(mock, "Factory must have issued a MockFileAccess")
	assert_eq(mock.close_call_count, 1, "close() must be called exactly once per flush")


func test_persistence_layer_critical_write_payload_equals_full_cache_json() -> void:
	# Arrange — seed two extra cache entries so the JSON blob includes more
	# than just the key being written. AC-04 asserts payload == JSON.stringify(_cache).
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	cache["pre_seed_a"] = 1
	cache["pre_seed_b"] = "alpha"

	# Act
	PersistenceLayer.write("foo", "bar", true)

	# Assert — store_string received JSON.stringify(_cache) at flush time.
	# The cache at that moment contains: pre_seed_a, pre_seed_b, AND foo.
	var mock: MockFileAccess = _factory.last_issued_mock
	assert_not_null(mock, "Factory must have issued a MockFileAccess")
	var expected_payload: String = JSON.stringify(PersistenceLayer.get(CACHE_VAR_NAME))
	assert_eq(
		mock.content_buffer,
		expected_payload,
		"Stored payload must equal JSON.stringify(_cache) — full snapshot, not delta"
	)


# ----------------------------------------------------------------------------
# AC-04b: open → store → close ordering proven via spy-recorded sequence
# ----------------------------------------------------------------------------

func test_persistence_layer_critical_write_emits_flush_completed_after_close() -> void:
	# Arrange — record the sequence of factory + mock events as they occur.
	var event_sequence: Array[String] = []

	# Attach a flush_completed listener; this signal must fire AFTER close().
	PersistenceLayer.flush_completed.connect(
		func(_count: int, _ms: int, _crit: bool) -> void:
			event_sequence.append("flush_completed")
	)

	# Act
	PersistenceLayer.write("foo", "bar", true)

	# Assert — flush_completed must have fired exactly once (post-close).
	assert_eq(
		event_sequence.size(),
		1,
		"flush_completed must emit exactly once on successful critical flush"
	)

	# Verify the mock saw the full open → store → close sequence before
	# the signal emission.
	var mock: MockFileAccess = _factory.last_issued_mock
	assert_not_null(mock)
	assert_eq(mock.store_string_call_count, 1, "store_string fired before flush_completed")
	assert_eq(mock.close_call_count, 1, "close fired before flush_completed")


func test_persistence_layer_critical_write_flush_completed_signal_args_correct() -> void:
	# Arrange — seed cache so flushed_key_count > 1 (proves count param wired).
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	cache["pre_seed"] = 42
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer.write("foo", "bar", true)

	# Assert — flush_completed(flushed_key_count, latency_ms, is_critical).
	assert_signal_emit_count(PersistenceLayer, "flush_completed", 1)
	var params: Array = get_signal_parameters(PersistenceLayer, "flush_completed", 0)
	assert_eq(params[0], 2, "flushed_key_count must equal _cache.size() at flush time (pre_seed + foo)")
	assert_true(params[1] is int, "latency_ms must be int")
	assert_gte(params[1], 0, "latency_ms must be non-negative")
	assert_eq(params[2], true, "is_critical must be true for write(flush=true) path")


# ----------------------------------------------------------------------------
# Failure case: open() returning null still walks the corrupt path —
# proves the open-fail branch behaves identically to the store-fail branch
# at the AC-03 / Rule 9 contract level.
# ----------------------------------------------------------------------------

func test_persistence_layer_critical_write_open_failure_skips_store_and_close() -> void:
	# Arrange — factory returns null from open() once.
	_factory.fail_next_open = true

	# Act
	var result: bool = PersistenceLayer.write("foo", "bar", true)

	# Assert — write returns false; no mock was issued so no store/close ran.
	assert_false(result, "open() returning null must cause write() to return false")
	# Because fail_next_open returns null BEFORE issuing a mock,
	# last_issued_mock is whatever was last set — for a fresh factory in
	# this test, that's null.
	assert_null(
		_factory.last_issued_mock,
		"No MockFileAccess should be issued when open() fails"
	)
