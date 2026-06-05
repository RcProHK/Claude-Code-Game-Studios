# PersistenceLayer — Autoload position 1 (LOCKED per ADR-0006 Contract 4)
#
# Status: Story 003 — atomic flush pattern + critical-flush path implemented.
# Driving GDD: design/gdd/persistence-layer.md (Approved 2026-05-26)
# Governing ADRs: ADR-0003 Save State Strategy, ADR-0006 Contracts 3/4/9/10/11/14
#
# ============================================================================
# CRITICAL DISCIPLINE — NO `await` IN THIS FILE (enforced by CI)
# ============================================================================
# This autoload sits at position 1 in the sequential boot order (ADR-0006
# Contract 4). Every other autoload (pos 2+) calls PersistenceLayer.read()
# synchronously from its own `_ready()`. The Godot engine resolves autoloads
# top-to-bottom and does NOT yield between them — a single `await` here
# suspends `_ready()` and returns control to the engine, which then runs
# GameStateMachine._ready() (pos 2) against a half-initialized
# PersistenceLayer. Result: boot crash, or worse, silent corruption of the
# first save slot read by downstream autoloads.
#
# Forbidden in this file (CI-enforced by tools/ci/check_no_await_in_persistence.sh):
#   * `await <signal_or_callable>` — any await expression
#   * `await get_tree().process_frame` — including the common idle-yield pattern
#   * Coroutine helpers that internally await (do not call them from `_ready()`)
#
# Allowed alternatives for async I/O during boot:
#   * Synchronous FileAccess reads (bounded by the 900ms migration ceiling,
#     ADR-0003) — these block the main thread but stay within frame budget.
#   * Defer truly async work (network fetch, IndexedDB sync) to a *post-boot*
#     phase: emit a signal from `_ready()` and let consumers `await` it from
#     *their* code, not from this file.
#   * Use `call_deferred()` to schedule work AFTER all autoloads have
#     initialized — safe because the deferred call runs after the boot chain.
#
# If you genuinely need async behavior here, escalate first. Do not add
# `await` to silence a warning or "just for one frame" — the CI lint is the
# project's last line of defence against a boot-order regression that is
# extremely hard to reproduce locally.
# ============================================================================
extends Node


# ============================================================================
# Constants
# ============================================================================

## Current schema version. Bumped per ADR-0003 migration policy.
const SCHEMA_VERSION: int = 1

## On-disk state file path. Web Export → IndexedDB-backed `user://`;
## Desktop → OS user data dir.
const STATE_FILE_PATH: String = "user://state.json"

## Debounce window for non-critical writes (Rule 2 / Tuning Knob).
## Writes with `flush=false` reset this timer; on timeout `_flush_dirty()`
## runs once. Tuned per design/gdd/persistence-layer.md Tuning Knobs.
const FLUSH_DEBOUNCE_MS: int = 100

## ADR-006 Contract 9: wall-clock drift tolerance for is_expired() helper.
## If |wall_delta - monotonic_delta| exceeds this, wall-clock is considered
## drifted (NTP correction / DST / manual change) and monotonic is trusted.
## Safe range: 60..3600 (runtime assert in _assert_knob_invariants).
const WALL_CLOCK_DRIFT_TOLERANCE_SECONDS: int = 300

# ADR-006 Contract 10: migration chain bounded
## ADR-0006 Contract 10: maximum number of N→N+1 steps allowed in a single
## migration chain. Reaching this cap is treated as a structural defect
## (someone bumped SCHEMA_VERSION far beyond the on-disk schema with no
## bounded upgrade path), NOT a recoverable runtime condition. Tripping the
## cap fail-fasts BEFORE any step runs (zero `migration_step_completed`
## emits) and routes through `_trigger_corrupt("MIGRATION_CHAIN_TOO_LONG")`.
const MAX_MIGRATION_CHAIN_LENGTH: int = 6

## ADR-0006 Contract 10: per-step wall-clock budget for migration work.
## A single N→N+1 step that exceeds this ceiling is treated as a runaway
## migration (likely O(n) over a pathological cache size) — the cache is
## reverted to its pre-step snapshot and the corrupt path fires with
## `MIGRATION_TIMEOUT`. Tuned to keep the worst-case 6-step chain inside
## the 900ms boot ceiling (6 * 150ms = 900ms — exactly the ADR-0003 cap).
const MIGRATION_BUDGET_MS: int = 150


# ============================================================================
# Signals (Rule 11 — 6 generic telemetry signals, no domain semantics)
# ============================================================================

## Emitted after every cache mutation (write or touch).
## - `key`: the storage key just written
## - `latency_ms`: wall-clock duration of cache mutation only (NOT flush I/O)
## - `is_touch`: true if emitted from `touch()` (Safari ITP refresh path),
##   false for normal `write()` calls
signal write_completed(key: String, latency_ms: int, is_touch: bool)

## Emitted after `_flush_dirty()` successfully writes the cache to disk.
## - `flushed_key_count`: number of keys in the cache snapshot just persisted
## - `latency_ms`: wall-clock duration of full disk I/O (open + store + close)
## - `is_critical`: true for `flush=true` callers (tombstone path), false for
##   debounced flushes
signal flush_completed(flushed_key_count: int, latency_ms: int, is_critical: bool)

## Emitted after a successful `delete()`.
signal delete_completed(key: String, latency_ms: int)

## Emitted per successful migration step (Rule 5).
signal migration_step_completed(from_version: int, to_version: int, latency_ms: int)

## Emitted whenever Rule 9 corrupt path triggers.
## - `error_code`: one of INVALID_JSON / MIGRATION_TIMEOUT / FLUSH_FAILED /
##   UNREGISTERED_PAYLOAD_TYPE / MIGRATION_CHAIN_TOO_LONG / EMPTY_FILE /
##   READ_ONLY_FILESYSTEM / QUOTA_EXHAUSTED / NOT_READY / MIGRATION_IN_PROGRESS
## - `key`: the storage key involved (empty string for boot-time / flush-time
##   corruption with no per-key context)
signal critical_save_failed(error_code: String, key: String)

## Emitted after Rule 9 wipe completes, BEFORE `critical_save_failed`.
## - `wiped_byte_count`: original file size pre-wipe; 0 if file didn't exist
signal corrupt_save_recovered(wiped_byte_count: int)


# ============================================================================
# Internal substates (Story 009 — GDD States and Transitions)
# ============================================================================

## Substate lifecycle: Initialising → Ready (or Corrupt).
## Story 010 adds Migrating + full API-rejection matrix.
## Corrupt is sticky — no auto-recovery without session restart.
enum Substate {
	INITIALISING,  ## During _ready() before disk load completes
	MIGRATING,     ## Migration chain active — API block-rejects read/write/delete
	READY,         ## Normal operation
	CORRUPT,       ## Rule 9 fired — sticky, never auto-recovers
}

## Current operational substate. Read via `_test_get_substate()` debug seam.
var _substate: Substate = Substate.INITIALISING


# ============================================================================
# Private state — in-memory cache + dirty tracking
# ============================================================================

## O(1) key→value cache. Authoritative in-session source of truth.
## Untyped Variant values: stored payloads may be Dictionary, Array, String,
## int, float, bool, or null — JSON round-trip dictates this looseness.
var _cache: Dictionary = {}

## True when `_cache` has unwritten changes pending flush.
## Cleared inside `_flush_dirty()` after a successful disk write.
var _dirty: bool = false

## Byte size of the file loaded in `_load_from_disk()`. Used by
## `_trigger_corrupt()` for `corrupt_save_recovered(wiped_byte_count)` —
## gives accurate pre-wipe byte count for AC-15b.
var _loaded_file_bytes: int = 0

## Injected file factory (production = real FileAccess wrapper;
## tests = MockFileFactory). Set via `attach_file_factory()`; defaults to
## null and is constructed lazily in `_ready()` to avoid CI / headless
## environments that don't have FileAccess available at parse time.
var _file_factory: IFileFactory = null

## Debounce timer for non-critical flushes. Created as a child Node in
## `_ready()` so timeouts deliver synchronously without `await`
## (the Timer's `timeout` signal connects to `_on_flush_timer_timeout`).
##
## ADR-0006 Contract 4 rationale: a Timer node as autoload child fires its
## `timeout` signal on the main thread between frames. The handler runs
## synchronously — no `await` needed, no `await get_tree().create_timer()`
## pattern (which would yield `_ready()` and break Contract 4).
var _flush_timer: Timer = null

## True during an active migration chain — suppresses `write_completed`
## emissions per GDD Rule 5 "Signal suppression (D1)". `write()` still
## mutates the cache (migrations need that), but observers must NOT
## interpret in-flight migration steps as application-level writes.
## Always reset to false before `migrate()` returns (both success and
## failure paths) so subsequent normal writes emit again.
var _suppress_write_completed: bool = false

## Test-only seam: number of milliseconds `_migrate_one_step()` should
## block via `OS.delay_msec()` before returning. Zero in production.
## Tests set this via `PersistenceLayer.set(&"_migration_step_delay_ms", N)`
## to drive timing-boundary cases (AC-07b normal-budget, AC-09 timeout).
## Honored only in debug builds to keep the production migration path
## free of any sleep overhead.
var _migration_step_delay_ms: int = 0

## Test-only seam: when true, `_migrate_one_step()` returns false on the
## next call (after applying any configured delay). Drives AC-10 atomic
## revert: a step that mutates `_cache` then "fails" — `migrate()` must
## restore the pre-step snapshot and route through the corrupt path.
## Cleared automatically after one failure to avoid bleed-over between
## steps within the same chain.
var _migration_step_fail_next: bool = false

## Test-only seam: when set to a non-empty key, `_migrate_one_step()`
## mutates `_cache[_migration_step_mutate_key] = _migration_step_mutate_value`
## BEFORE deciding whether to succeed or fail. Combined with
## `_migration_step_fail_next` this proves the atomic-revert invariant
## (AC-10): a mid-step mutation must be rolled back when the step fails.
var _migration_step_mutate_key: String = ""
var _migration_step_mutate_value: Variant = null


# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	# NOTE: `_ready()` MUST remain synchronous. See file header for rationale.
	# Do NOT add `await` to this function or any function called from it.

	# Create the debounce timer as a child node. one_shot + autostart=false
	# so it only runs when `write()` explicitly resets/starts it.
	_flush_timer = Timer.new()
	_flush_timer.name = "FlushDebounceTimer"
	_flush_timer.one_shot = true
	_flush_timer.autostart = false
	_flush_timer.wait_time = float(FLUSH_DEBOUNCE_MS) / 1000.0
	_flush_timer.timeout.connect(_on_flush_timer_timeout)
	add_child(_flush_timer)

	_load_from_disk()
	if _substate == Substate.INITIALISING:
		_substate = Substate.READY
	print("[PersistenceLayer] initialized — autoload pos 1; substate=%s" % Substate.keys()[_substate])


# ============================================================================
# Dependency injection (ADR-0006 Contract 14)
# ============================================================================

## Inject an IFileFactory implementation. Tests call this with a
## MockFileFactory to assert disk-touch counts without touching `user://`.
## Production code uses the default null factory (lazy real FileAccess wrap).
func attach_file_factory(factory: IFileFactory) -> void:
	_file_factory = factory


# ============================================================================
# IPersistence public API
# ============================================================================
# ADR-006 Contract 4: autoload position 1 + sync _ready
# IPersistence public API — sync returns only, NO await anywhere in this file
# Full bodies: read() → Story 002 ✅, write() flush path → Story 003 ✅,
#              delete() → Story 011, migrate() → Story 008, touch() → Story 011


## Returns the value stored under `key`, or null if the key does not exist.
## O(1) — reads from in-memory cache; zero file I/O per call.
func read(key: String) -> Variant:
	match _substate:
		Substate.INITIALISING:
			assert(false, "PersistenceLayer.read() called before _ready() completed — check autoload position")
			critical_save_failed.emit("NOT_READY", key)
			return null
		Substate.MIGRATING:
			critical_save_failed.emit("MIGRATION_IN_PROGRESS", key)
			return null
		_:  # READY or CORRUPT
			return _cache.get(key, null)


# ADR-006 Contract 11: best-effort IDB fence — sync return, no await IDB ack
## Writes `value` under `key`. If `flush=true`, immediately flushes cache to disk
## (critical path — e.g. GSM tombstone writes). Returns true on cache-accept
## for `flush=false`; returns false for `flush=true` if the disk flush fails.
##
## FileAccess.store_string() bool = WASM-side accept only, not IDB commit ack.
##
## Behaviour by flush mode (Rule 2):
## - `flush=false` (default): mutate `_cache[key]`, mark `_dirty=true`, restart
##   debounce timer (FLUSH_DEBOUNCE_MS = 100ms), emit `write_completed`,
##   return true immediately. Disk flush happens later in `_on_flush_timer_timeout`.
##   If that deferred flush fails, Rule 9 corrupt path triggers then.
## - `flush=true` (critical): mutate `_cache[key]`, mark `_dirty=true`, emit
##   `write_completed`, immediately call `_flush_dirty()`. If the flush fails,
##   `_trigger_corrupt("FLUSH_FAILED", "")` runs (wipes cache + emits signals)
##   and `write()` returns false. AC-03 evidence path.
func write(key: String, value: Variant, flush: bool = false) -> bool:
	match _substate:
		Substate.INITIALISING:
			assert(false, "PersistenceLayer.write() called before _ready() completed")
			critical_save_failed.emit("NOT_READY", key)
			return false
		Substate.MIGRATING:
			critical_save_failed.emit("MIGRATION_IN_PROGRESS", key)
			return false
		_:
			pass  # READY or CORRUPT — proceed
	# GDD Rule 12: namespace convention push_warning (debug only, never blocks write).
	if OS.is_debug_build():
		const VALID_NAMESPACES: Array[String] = [
			"gsm.", "gym.", "_internal.", "streak.", "wst.", "stat.", "ability.unlocked.", "audio.", "boss."
		]
		var has_prefix := VALID_NAMESPACES.any(func(ns: String) -> bool: return key.begins_with(ns))
		if not has_prefix:
			push_warning("[PersistenceLayer] Key '%s' lacks namespace prefix — add one per GDD Rule 12" % key)
	var start_ms: int = Time.get_ticks_msec()
	_cache[key] = value
	_dirty = true
	var latency_ms: int = Time.get_ticks_msec() - start_ms
	# GDD Rule 5 D1: suppress write_completed while a migration chain is
	# running. Migrations may call write() internally (Story 016) and
	# observers must not interpret in-flight schema upgrades as user writes.
	if not _suppress_write_completed:
		write_completed.emit(key, latency_ms, false)

	if flush:
		# Critical path: immediate atomic flush. If it fails, the corrupt
		# path has already wiped `_cache` and emitted the failure signals.
		var flush_ok: bool = _flush_dirty(true)
		return flush_ok

	# Non-critical path: arm/restart the debounce timer. If a previous
	# write already scheduled a flush, restarting collapses both into one
	# disk write (write-amplification mitigation per Rule 2).
	_flush_timer.start()
	return true


## Removes `key` from the cache and flushes to disk. Returns true if key existed.
## Always uses critical flush (flush=true — destructive operation, no debounce).
func delete(key: String) -> bool:
	match _substate:
		Substate.INITIALISING:
			assert(false, "PersistenceLayer.delete() called before _ready() completed")
			critical_save_failed.emit("NOT_READY", key)
			return false
		Substate.MIGRATING:
			critical_save_failed.emit("MIGRATION_IN_PROGRESS", key)
			return false
		Substate.CORRUPT:
			if not _cache.has(key):
				return false
			_cache.erase(key)
			return true  # Corrupt: cache mutation only, no flush attempt
		_:  # READY — full delete path (Story 011)
			if not _cache.has(key):
				return false
			_cache.erase(key)
			_dirty = true
			var start_ms: int = Time.get_ticks_msec()
			var ok: bool = _flush_dirty(true)  # always critical — destructive, no debounce
			if ok:
				delete_completed.emit(key, Time.get_ticks_msec() - start_ms)
			else:
				_trigger_corrupt("FLUSH_FAILED", key)  # don't re-insert key
			return ok


## Runs bounded migration chain from `from_version` to `to_version`.
## Returns true on success, false on failure (corrupt path per Rule 9).
## Bounded: MAX_MIGRATION_CHAIN_LENGTH=6, MIGRATION_BUDGET_MS=150ms (ADR-0006 Contract 10).
##
## Behaviour (Story 008 — ADR-0006 Contract 10):
## 1. Pre-check chain length. `to - from > MAX_MIGRATION_CHAIN_LENGTH` is a
##    structural defect (someone bumped SCHEMA_VERSION without a bounded
##    upgrade path). Fail-fast BEFORE any step runs → zero
##    `migration_step_completed` emits, `critical_save_failed(
##    "MIGRATION_CHAIN_TOO_LONG", "")`, returns false.
## 2. Reject downgrades. `to < from` is treated as corrupt — Story 016 will
##    flesh out downgrade policy; for now route through the corrupt path
##    with `SCHEMA_DOWNGRADE`.
## 3. For each step N→N+1:
##    a. Snapshot `_cache` (deep copy) so a mid-step mutation can be reverted.
##    b. Call `_migrate_one_step(N, N+1)` and measure wall-clock elapsed.
##    c. If the step returns false OR elapsed > MIGRATION_BUDGET_MS,
##       revert `_cache` to the snapshot, route through the corrupt path
##       with `MIGRATION_TIMEOUT` (timeout) or `MIGRATION_FAILED` (return-false),
##       and return false. The `key` field of `critical_save_failed` carries
##       `"step_<from>_to_<to>"` for diagnostics.
##    d. Otherwise emit `migration_step_completed(N, N+1, elapsed_ms)`.
## 4. While the chain is running, `_suppress_write_completed = true` so any
##    cache mutations performed by `_migrate_one_step()` do NOT leak
##    `write_completed` signals to observers (GDD Rule 5 D1). The flag is
##    always cleared before this function returns — including the early
##    fail-fast return at step 1.
func migrate(from_version: int, to_version: int) -> bool:
	# ADR-0006 Contract 10 step 1: fail-fast on structurally invalid chains.
	# Computed as a signed difference so downgrades route to a clearer error
	# than "chain too long".
	var chain_length: int = to_version - from_version
	if chain_length > MAX_MIGRATION_CHAIN_LENGTH:
		# Zero step signals emitted; suppression flag was never raised.
		_trigger_corrupt("MIGRATION_CHAIN_TOO_LONG", "")
		return false

	# Downgrade attempt — Story 016 owns the policy. For Story 008 we treat
	# it as corrupt so callers receive a deterministic failure signal.
	if chain_length < 0:
		_trigger_corrupt("SCHEMA_DOWNGRADE", "")
		return false

	# No-op chain (from == to). Nothing to migrate; succeed silently.
	if chain_length == 0:
		return true

	# Raise the D1 suppression flag + enter Migrating substate for the chain.
	_suppress_write_completed = true
	_substate = Substate.MIGRATING
	var current: int = from_version
	while current < to_version:
		# Deep-copy snapshot so revert restores nested Dictionaries/Arrays.
		var pre_snapshot: Dictionary = _cache.duplicate(true)
		var step_start: int = Time.get_ticks_msec()
		var ok: bool = _migrate_one_step(current, current + 1)
		var elapsed: int = Time.get_ticks_msec() - step_start

		if not ok or elapsed > MIGRATION_BUDGET_MS:
			# AC-10 atomic-or-fail-loud: revert cache to pre-step state.
			_cache = pre_snapshot
			var error_code: String = "MIGRATION_TIMEOUT" if elapsed > MIGRATION_BUDGET_MS else "MIGRATION_FAILED"
			var step_label: String = "step_%d_to_%d" % [current, current + 1]
			# Clear suppression + exit Migrating before the corrupt path.
			_suppress_write_completed = false
			_substate = Substate.INITIALISING  # allow _trigger_corrupt to set CORRUPT
			_trigger_corrupt(error_code, step_label)
			return false

		migration_step_completed.emit(current, current + 1, elapsed)
		current += 1

	_suppress_write_completed = false
	_substate = Substate.READY  # exit Migrating → Ready on success
	return true


## Per-version step hook (Story 008 stub). Story 016 implements the actual
## N→N+1 transformations per ADR-0003. The default implementation honours
## a small set of test-only seams (delay / fail-next / cache mutation) so
## integration tests can exercise the timing-boundary and atomic-revert
## paths without an IClock injection.
##
## Returns true on success, false on failure. Returning false from this
## function causes `migrate()` to revert `_cache` to its pre-step snapshot
## and route through the corrupt path with `MIGRATION_FAILED`.
func _migrate_one_step(_from: int, _to: int) -> bool:
	# Test-only seam: optional mid-step mutation to prove atomic revert.
	if _migration_step_mutate_key != "":
		_cache[_migration_step_mutate_key] = _migration_step_mutate_value

	# Test-only seam: simulate a slow step. Honored only in debug builds
	# so the production migration path carries zero sleep overhead.
	if _migration_step_delay_ms > 0 and OS.is_debug_build():
		OS.delay_msec(_migration_step_delay_ms)

	# Test-only seam: force a single-step failure (auto-clearing).
	if _migration_step_fail_next:
		_migration_step_fail_next = false
		return false

	return true


# ADR-006 Contract 9: clock-drift TTL
## Drift-tolerant TTL expiry check. Pure function — no side effects, no cache mutation.
## Optional anchor_monotonic_ms enables drift detection: if wall-clock vs monotonic differ
## by > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS (300s), trusts monotonic. Session-scoped only:
## never persist anchor_monotonic_ms to disk (resets to 0 on process restart).
func is_expired(anchor_unix: int, ttl_seconds: int, anchor_monotonic_ms: int = 0) -> bool:
	# ADR-006 Contract 9 — Formula 1 implementation.
	# Pure function: no side effects, no cache mutation.
	var now_unix: int = int(Time.get_unix_time_from_system())
	var wall_delta: int = now_unix - anchor_unix

	# Guard: negative wall_delta with no monotonic anchor (clock not initialised
	# or extreme rollback). Treat as not-expired — conservative Pillar 3 choice.
	if wall_delta < 0 and anchor_monotonic_ms == 0:
		push_warning("[PersistenceLayer] is_expired: negative wall_delta (%ds) — clock uninitialised; treating as not-expired" % wall_delta)
		return false

	if anchor_monotonic_ms > 0:
		var now_mono: int = Time.get_ticks_msec()
		# Cross-session guard: monotonic resets to 0 on process restart.
		# If now_mono < anchor, anchor is from a prior session — fall back to wall-clock.
		if now_mono < anchor_monotonic_ms:
			push_error("[PersistenceLayer] is_expired: cross-session anchor_monotonic_ms (%d > now %d) — falling back to wall-clock" % [anchor_monotonic_ms, now_mono])
			return wall_delta > ttl_seconds
		var mono_delta_ms: int = now_mono - anchor_monotonic_ms
		# ms-precision comparison (avoids integer-second truncation)
		if abs(wall_delta * 1000 - mono_delta_ms) > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS * 1000:
			# Wall clock drifted (NTP / DST / manual). Trust monotonic.
			return mono_delta_ms > ttl_seconds * 1000

	# Default: wall-clock comparison
	return wall_delta > ttl_seconds


## Rewrites `key` with its current value to refresh Safari ITP 7-day storage timer.
## Triggers critical flush (flush=true). Emits write_completed with is_touch=true.
## Returns false if key is not in cache (nothing to touch).
func touch(key: String) -> bool:
	if not _cache.has(key):
		return false  # nothing to touch — key absent
	var val: Variant = _cache[key]
	var start_ms: int = Time.get_ticks_msec()
	_cache[key] = val  # no-op value rewrite (touches the slot)
	_dirty = true
	var ok: bool = _flush_dirty(true)  # critical flush — must persist before tab close
	if ok:
		var latency_ms: int = Time.get_ticks_msec() - start_ms
		write_completed.emit(key, latency_ms, true)  # is_touch=true
	return ok


# ADR-006 Contract 14: test spy interface
# Production no-op — MockPersistenceLayer overrides these to record calls.
# Interface shape MUST be identical in production and test builds (no conditional compilation).
## Attach a callable invoked (key, value) on every write. Production no-op.
func attach_write_spy(_spy: Callable) -> void: pass
## Attach a callable invoked (key) on every delete. Production no-op.
func attach_delete_spy(_spy: Callable) -> void: pass
## Clear all attached spies. Call in test tearDown(). Production no-op.
func clear_spies() -> void: pass


# ============================================================================
# Private — atomic flush pattern (Rule 3) + corrupt path (Rule 9)
# ============================================================================

## Atomically writes the full `_cache` to disk as a single JSON blob.
## Returns true on success, false on any I/O failure (triggers corrupt path).
##
## Rule 3 implementation (atomic file write pattern):
##   FileAccess.open(WRITE) → store_string(JSON.stringify(_cache)) → close()
##   → emit flush_completed.
##
## NO incremental / per-key writes — every flush serializes the entire cache.
## NO temp file + rename — Emscripten IDBFS syncfs is whole-filesystem
## snapshot, NOT per-file transactional, so rename atomicity provides no
## additional guarantee on Web Export (GDD Rule 3 rationale).
##
## On failure:
##   - flush_completed is NOT emitted
##   - `_trigger_corrupt("FLUSH_FAILED", "")` runs (wipes cache + emits
##     corrupt_save_recovered then critical_save_failed)
##   - returns false to caller
##
## `is_critical` is forwarded to `flush_completed.is_critical` and used by
## telemetry to distinguish debounced vs immediate flushes.
func _flush_dirty(is_critical: bool = false) -> bool:
	var start_ms: int = Time.get_ticks_msec()

	# Open the state file for writing.
	# Production path (no injected factory): call FileAccess.open() directly.
	# Test path (MockFileFactory injected via attach_file_factory): route through
	# the factory so tests can assert disk-touch counts without real file I/O.
	# ADR-0006 Contract 14: IFileFactory is the test-injection seam — the base
	# class is abstract (push_error stubs) and must never be instantiated here.
	var handle: Object
	if _file_factory != null:
		handle = _file_factory.open(STATE_FILE_PATH, FileAccess.WRITE)
	else:
		handle = FileAccess.open(STATE_FILE_PATH, FileAccess.WRITE)

	if handle == null:
		# open() failed — read-only filesystem or test-injected fail_next_open.
		_trigger_corrupt("FLUSH_FAILED", "")
		return false

	# Serialize the full cache snapshot as a single JSON blob (Rule 3).
	# JSON.stringify is deterministic for primitive Dictionary contents; Node /
	# Callable references are blocked by static-analyzer per Rule 4 / GDD
	# Edge Case Serialization Envelope.
	var payload: String = JSON.stringify(_cache)
	# Duck-typed calls: handle is FileAccess (production) or MockFileAccess (tests).
	# Both expose the same store_string(String)->bool / close()->void surface.
	@warning_ignore("unsafe_method_access")
	var store_ok: bool = handle.store_string(payload)
	@warning_ignore("unsafe_method_access")
	handle.close()

	if not store_ok:
		# WASM MEMFS write failure (quota exhausted / read-only) — corrupt path.
		_trigger_corrupt("FLUSH_FAILED", "")
		return false

	# Successful flush — clear dirty flag and emit telemetry.
	_dirty = false
	var latency_ms: int = Time.get_ticks_msec() - start_ms
	flush_completed.emit(_cache.size(), latency_ms, is_critical)
	return true


## Rule 9 corrupt path: wipe `_cache` to a clean schema-only baseline and
## emit `corrupt_save_recovered` then `critical_save_failed` in order.
##
## Signal ordering is part of the contract (AC-15b): consumers may rely on
## `corrupt_save_recovered` arriving BEFORE `critical_save_failed`.
##
## NOTE: this private helper does NOT re-flush the wiped baseline to disk.
## On the FLUSH_FAILED trigger path the disk is already in an unknown state
## and a re-flush would likely fail for the same reason. ADR-0006 Contract
## 11 VS tier accepts this — consumers receive `critical_save_failed` and
## drive their own clean-slate recovery (e.g. GymSys Client refetches from
## backend on `persistence_volatile()`).
func _trigger_corrupt(error_code: String, key: String) -> void:
	# AC-16 single-emit guard: if already Corrupt, skip re-trigger.
	# Corrupt is sticky — once fired, only a session restart can clear it.
	if _substate == Substate.CORRUPT:
		return

	# Use loaded file size if available; fall back to in-memory JSON size.
	# _loaded_file_bytes is set by _load_from_disk() to the actual disk bytes.
	var wiped_byte_count: int = _loaded_file_bytes if _loaded_file_bytes > 0 \
		else JSON.stringify(_cache).to_utf8_buffer().size()

	# Wipe to schema-only baseline (Rule 9 step 2).
	_cache = { "schema_version": SCHEMA_VERSION }
	_dirty = false
	_substate = Substate.CORRUPT

	# Signal order MUST be: corrupt_save_recovered first, then critical (AC-15b).
	corrupt_save_recovered.emit(wiped_byte_count)
	critical_save_failed.emit(error_code, key)

	# Safety net — log to console even with zero subscribers.
	push_error("[PersistenceLayer] critical_save_failed: %s | key='%s'" % [error_code, key])


## ADR-0006 Contract 14 debug seam: returns current substate name string.
## Guarded by OS.is_debug_build() — production returns empty string.
func _test_get_substate() -> String:
	if not OS.is_debug_build():
		return ""
	return Substate.keys()[_substate]


## ADR-0006 Contract 14 debug seam: force substate to a named value.
## Tests call this via `PersistenceLayer._test_force_substate(&"READY")` to
## set up boundary conditions without going through full boot/migrate cycles.
## Production builds silently no-op.
func _test_force_substate(name: StringName) -> void:
	if not OS.is_debug_build():
		return
	_substate = Substate[name]


# ADR-006 Contract 3: SerializableResource envelope
## Loads `user://state.json` into `_cache`, checking for corrupt conditions.
## Triggers corrupt path on: (1) JSON parse failure, (2) non-Dictionary result,
## (3) missing schema_version key. Calls migrate() if schema mismatch found.
## Called from _ready() — MUST remain synchronous (no await).
func _load_from_disk() -> void:
	# Determine if file exists
	var file_exists: bool = false
	if _file_factory != null:
		file_exists = _file_factory.file_exists(STATE_FILE_PATH)
	else:
		file_exists = FileAccess.file_exists(STATE_FILE_PATH)

	if not file_exists:
		# First boot: init with schema_version baseline (AC-26).
		_cache = { "schema_version": SCHEMA_VERSION }
		return

	# Open + read content
	var content: String = ""
	if _file_factory != null:
		var f: Object = _file_factory.open(STATE_FILE_PATH, FileAccess.READ)
		if not f:
			return  # file vanished between exists() and open() — treat as first boot
		@warning_ignore("unsafe_method_access")
		content = f.get_as_text()
		@warning_ignore("unsafe_method_access")
		_loaded_file_bytes = f.get_length()
		@warning_ignore("unsafe_method_access")
		f.close()
	else:
		var f := FileAccess.open(STATE_FILE_PATH, FileAccess.READ)
		if not f:
			return
		content = f.get_as_text()
		_loaded_file_bytes = f.get_length()
		f.close()

	# Trigger 1+2: parse failure or non-Dictionary.
	# Use JSON.new().parse() (returns an error code) rather than
	# JSON.parse_string(), which ERR_PRINTs on malformed input. Corrupt
	# detection EXPECTS parse failures here, so it must not spam engine
	# errors for a handled condition (core/io/json.cpp parse_string prints).
	var _json := JSON.new()
	var _parse_err: int = _json.parse(content)
	var parsed: Variant = _json.data if _parse_err == OK else null
	if not parsed is Dictionary:
		_trigger_corrupt("INVALID_JSON", "")
		return

	var data: Dictionary = parsed as Dictionary

	# Trigger 3: missing schema_version key
	if not data.has("schema_version"):
		_trigger_corrupt("INVALID_JSON", "")
		return

	# Load cache from disk
	_cache = data
	var file_schema: int = int(data.get("schema_version", 0))

	# Schema mismatch → migrate (Trigger 4 handled inside migrate() itself)
	if file_schema != SCHEMA_VERSION:
		if not migrate(file_schema, SCHEMA_VERSION):
			return  # corrupt already triggered inside migrate()


# ============================================================================
# Signal callbacks
# ============================================================================

## Fires after FLUSH_DEBOUNCE_MS of write-quiet. Runs a non-critical flush.
## Failure path: `_flush_dirty(false)` triggers corrupt internally.
func _on_flush_timer_timeout() -> void:
	if not _dirty:
		return  # nothing to flush (e.g. spurious timer fire)
	_flush_dirty(false)
