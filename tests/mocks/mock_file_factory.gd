## MockFileFactory — IFileFactory implementation for unit tests (ADR-0006 Contract 14)
##
## Status: EXTENDED for Story 003 (AC-03, AC-04) — issues MockFileAccess
## instances with full duck-typed FileAccess surface (store_string, close,
## get_as_text, get_length).
## Pairs with: tests/mocks/mock_file_access.gd, src/core/i_file_factory.gd.
##
## ## Behaviour summary
## - `open(path, flags)` returns a `MockFileAccess` instance every time —
##   never null. Tests that need open-fail simulation set `fail_next_open`.
## - Each issued mock is recorded in `_issued_mocks` and the most recent
##   one is exposed via `last_issued_mock` so tests can attach spies
##   AFTER the production code has called `open()`.
## - `fail_next_store_string` propagates to the issued mock's
##   `store_string_fail` flag, driving the AC-03 critical-flush failure path.
## - `set_file_content(path, content)` seeds the virtual filesystem so the
##   issued mock's `get_as_text()` returns the seeded string.
##
## ## Usage (Story 003+)
## ```gdscript
## var factory := MockFileFactory.new()
## factory.set_file_content("user://state.json", '{"schema_version": 1}')
## factory.fail_next_store_string = true   # AC-03: simulate FLUSH_FAILED
## PersistenceLayer.attach_file_factory(factory)
## # ... exercise PersistenceLayer.write(key, val, true) ...
## assert_eq(factory.open_write_call_count, 1)
## assert_eq(factory.last_issued_mock.store_string_call_count, 1)
## ```
class_name MockFileFactory extends IFileFactory

# ----------------------------------------------------------------------------
# Counters
# ----------------------------------------------------------------------------

## Number of open() calls with READ flag.
var open_read_call_count: int = 0

## Number of open() calls with WRITE flag (or anything non-READ).
var open_write_call_count: int = 0

## Number of file_exists() calls.
var file_exists_call_count: int = 0

# ----------------------------------------------------------------------------
# Failure injection
# ----------------------------------------------------------------------------

## When true, the NEXT open() call returns null (simulates FileAccess.open
## failure — read-only filesystem / permission denied). Auto-clears after
## one open() call.
var fail_next_open: bool = false

## When true, every MockFileAccess issued from this factory has its
## `store_string_fail` flag set to true at issue time. Drives the
## AC-03 / AC-15 row 6 FLUSH_FAILED path. Persists across opens until
## explicitly cleared.
var fail_next_store_string: bool = false

# ----------------------------------------------------------------------------
# Mock issue tracking
# ----------------------------------------------------------------------------

## Every MockFileAccess this factory has issued, in order. Tests can iterate
## to assert per-handle call counts across multiple opens.
var _issued_mocks: Array[MockFileAccess] = []

## The most recently issued MockFileAccess instance, or null if open()
## has never returned a mock. Convenience accessor for the common case
## where production code opens exactly once per operation.
var last_issued_mock: MockFileAccess = null

# ----------------------------------------------------------------------------
# Virtual filesystem
# ----------------------------------------------------------------------------

## Virtual filesystem: path → file content string.
## Pre-populate via `set_file_content()` to simulate existing saves.
var _virtual_files: Dictionary = {}


# ----------------------------------------------------------------------------
# Fixture setup
# ----------------------------------------------------------------------------

## Seed the virtual filesystem with a file at `path` containing `content`.
## When PersistenceLayer opens this path, the issued MockFileAccess will
## return `content` from get_as_text().
func set_file_content(path: String, content: String) -> void:
	_virtual_files[path] = content


# ----------------------------------------------------------------------------
# IFileFactory overrides
# ----------------------------------------------------------------------------

## Returns a MockFileAccess seeded with virtual file content (if any),
## or null if `fail_next_open` is set (one-shot open-fail simulation).
##
## NOTE: return type widened to `Object` (per IFileFactory contract) to
## allow duck-typed MockFileAccess (which extends RefCounted, NOT
## FileAccess — see mock_file_access.gd header for rationale).
func open(path: String, flags: FileAccess.ModeFlags) -> Object:
	# Track read vs write opens so tests can assert exact call modes.
	if flags == FileAccess.READ:
		open_read_call_count += 1
	else:
		open_write_call_count += 1

	# One-shot open-fail simulation (clears after this call).
	if fail_next_open:
		fail_next_open = false
		return null

	# Issue a fresh MockFileAccess seeded with the virtual content (if any).
	var mock := MockFileAccess.new()
	mock.path = path
	mock.flags = flags
	mock.open_call_count += 1  # record that this handle was issued by 1 open() call
	mock.seeded_content = _virtual_files.get(path, "")
	mock.store_string_fail = fail_next_store_string

	_issued_mocks.append(mock)
	last_issued_mock = mock
	return mock


## Consults the virtual filesystem. Does NOT touch the real filesystem.
func file_exists(path: String) -> bool:
	file_exists_call_count += 1
	return _virtual_files.has(path)


# ----------------------------------------------------------------------------
# Test helpers
# ----------------------------------------------------------------------------

## Reset all counters, clear virtual filesystem, drop issued mocks.
## Call in test before_each() or after_each() for isolation.
func reset() -> void:
	open_read_call_count = 0
	open_write_call_count = 0
	file_exists_call_count = 0
	fail_next_open = false
	fail_next_store_string = false
	_virtual_files.clear()
	_issued_mocks.clear()
	last_issued_mock = null


## Returns the full list of MockFileAccess instances issued in order.
## Used by tests that need to assert behaviour across multiple opens
## (e.g. boot-read followed by flush-write).
func get_issued_mocks() -> Array[MockFileAccess]:
	return _issued_mocks
