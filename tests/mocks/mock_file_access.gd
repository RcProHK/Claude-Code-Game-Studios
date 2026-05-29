## MockFileAccess — In-memory FileAccess stand-in for PersistenceLayer tests
##
## Status: BUILT for Story 002 — EXTENDED for Story 003 (AC-03, AC-04).
## Pairs with: src/core/i_file_factory.gd, tests/mocks/mock_file_factory.gd.
##
## ## Why this is NOT `extends FileAccess`
## `FileAccess` is a built-in engine class with no public constructor that can
## be subclassed in GDScript. We instead `extends RefCounted` and rely on
## duck-typing — the `IFileFactory.open()` signature returns `Object`, and the
## production code calls `store_string()` / `close()` / `get_as_text()` /
## `get_length()` via dynamic dispatch. This is intentional per ADR-0006
## Contract 14: tests trade one layer of static-type safety for full disk
## isolation.
##
## ## Recording surface (read by tests)
## Counters:
## - `open_call_count` — incremented by MockFileFactory.open() when this mock issued
## - `store_string_call_count` — incremented by store_string()
## - `close_call_count` — incremented by close()
## - `get_as_text_call_count` — incremented by get_as_text()
##
## Spies (Callable hooks, AC-04 evidence path):
## - `attach_open_spy(cb)` — called by factory on open() with path (not this mock)
## - `attach_store_spy(cb)` — called inside store_string() with (path, content)
## - `attach_close_spy(cb)` — called inside close() with (path)
##
## Failure injection:
## - `store_string_fail` — when true, store_string() returns false (simulates
##   IDB quota exhaustion / FLUSH_FAILED per AC-03 / AC-15 row 6)
##
## State:
## - `content_buffer` — last string written via store_string() (for AC-04
##   payload assertion: store payload == JSON.stringify(_cache))
## - `seeded_content` — string returned by get_as_text() (test fixture seeds
##   pre-existing file content for migration / corrupt-detect tests)
## - `path` — the path this mock was opened at (set by MockFileFactory)
class_name MockFileAccess extends RefCounted

# ----------------------------------------------------------------------------
# Identity / configuration (set by MockFileFactory at issue time)
# ----------------------------------------------------------------------------

## Path this mock represents. Set by MockFileFactory.open().
var path: String = ""

## Mode flags this mock was opened with. Set by MockFileFactory.open().
var flags: int = -1

## Content seeded into the virtual file (returned by get_as_text()).
var seeded_content: String = ""

## When true, store_string() returns false to simulate a write failure
## (e.g. IndexedDB quota exhaustion, read-only filesystem). Used by AC-03
## to drive the FLUSH_FAILED → critical_save_failed path.
var store_string_fail: bool = false

# ----------------------------------------------------------------------------
# Recording counters
# ----------------------------------------------------------------------------

## Number of times this mock was issued by MockFileFactory.open().
## (Incremented by the factory, NOT by this mock — but kept here for
## test convenience when asserting per-handle behaviour.)
var open_call_count: int = 0

## Number of times store_string() has been called on this mock.
var store_string_call_count: int = 0

## Number of times close() has been called on this mock.
var close_call_count: int = 0

## Number of times get_as_text() has been called on this mock.
var get_as_text_call_count: int = 0

# ----------------------------------------------------------------------------
# State buffers
# ----------------------------------------------------------------------------

## Most recent string passed to store_string(). AC-04 asserts this equals
## `JSON.stringify(_cache)` after a write — proving the full-cache atomic
## flush pattern (Rule 3).
var content_buffer: String = ""

# ----------------------------------------------------------------------------
# Spy hooks (Callable, attached by tests)
# ----------------------------------------------------------------------------

var _store_spy: Callable = Callable()
var _close_spy: Callable = Callable()


# ----------------------------------------------------------------------------
# Spy attachment API
# ----------------------------------------------------------------------------

## Attach a Callable invoked on every store_string() with (path, content).
## Tests use this to record the exact sequence of writes (AC-04).
func attach_store_spy(cb: Callable) -> void:
	_store_spy = cb


## Attach a Callable invoked on every close() with (path).
## Tests use this to confirm the open → store → close sequence (AC-04).
func attach_close_spy(cb: Callable) -> void:
	_close_spy = cb


# ----------------------------------------------------------------------------
# FileAccess-shape duck-typed API
# ----------------------------------------------------------------------------

## Writes `content` to the virtual file buffer. Returns false if
## `store_string_fail` is true (simulated write failure — drives AC-03 path).
## Otherwise returns true and records the content for inspection.
##
## NOTE: real FileAccess.store_string() returns bool reflecting WASM-side
## buffer accept (NOT IDB commit ack) per Contract 11 VS tier.
func store_string(content: String) -> bool:
	store_string_call_count += 1
	if _store_spy.is_valid():
		_store_spy.call(path, content)
	if store_string_fail:
		return false
	content_buffer = content
	return true


## Records the call and invokes the close spy. No buffer flush behaviour —
## the virtual file is already in `content_buffer`.
func close() -> void:
	close_call_count += 1
	if _close_spy.is_valid():
		_close_spy.call(path)


## Returns the seeded content. Used by PersistenceLayer._ready() to read
## `user://state.json` at boot via the injected factory.
func get_as_text() -> String:
	get_as_text_call_count += 1
	return seeded_content


## Returns the byte length of the seeded content. Drives the
## `MAX_STATE_FILE_BYTES` sanity check (Edge Case P0-8) and the
## `corrupt_save_recovered(wiped_byte_count)` signal (AC-15b).
func get_length() -> int:
	return seeded_content.to_utf8_buffer().size()


# ----------------------------------------------------------------------------
# Test helpers
# ----------------------------------------------------------------------------

## Resets all counters and clears buffers. Call in test before_each() or
## after_each() for isolation. Does NOT clear spy callables — tests
## re-attach spies per case.
func reset() -> void:
	open_call_count = 0
	store_string_call_count = 0
	close_call_count = 0
	get_as_text_call_count = 0
	content_buffer = ""
	seeded_content = ""
	store_string_fail = false
	path = ""
	flags = -1
	_store_spy = Callable()
	_close_spy = Callable()
