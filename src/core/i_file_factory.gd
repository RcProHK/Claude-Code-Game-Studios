## IFileFactory — Dependency injection seam for FileAccess (ADR-0006 Contract 14)
##
## Status: BUILT for Story 002 — NOT YET WIRED into PersistenceLayer (deferred).
## Driving GDD: design/gdd/persistence-layer.md
## Governing ADRs: ADR-0003 Save State Strategy, ADR-0006 Contract 14 (test spy interface)
##
## ## Why this exists
## PersistenceLayer must be testable in pure-memory unit tests (zero file I/O,
## zero IndexedDB round-trips). Direct `FileAccess.open()` calls inside the
## autoload make that impossible — every test would touch the real `user://`
## sandbox, slowing the suite and coupling test state across runs.
##
## This interface lets production code receive a real `FileAccess`-returning
## factory while tests inject `MockFileAccess` via `attach_file_factory()`.
##
## ## Wiring status (CRITICAL — read before editing)
## Story 002 ONLY introduces the interface + `_cache`-state read path. The
## production `PersistenceLayer.read()` body does NOT yet route through this
## factory — it returns directly from `_cache`. Story 003 (write/flush) will
## wire `FileAccess` calls through the factory and tests will then inject
## `MockFileAccess` to assert disk-touch counts.
##
## Until Story 003 wires it: this interface is dormant infrastructure. The
## Story 002 cache-read test (`test_in_memory_cache_read.gd`) does NOT call
## `attach_file_factory()` — it asserts zero I/O purely by reading `_cache`
## state, never invoking any code path that would open a file.
##
## ## Usage (post-Story-003)
## ```gdscript
## # Test setup
## var mock_factory := MockFileFactory.new()  # returns MockFileAccess instances
## PersistenceLayer.attach_file_factory(mock_factory)
##
## # ... exercise PersistenceLayer.write() ...
##
## assert_eq(mock_factory.open_call_count, 0, "cache write must not touch disk")
## ```
class_name IFileFactory extends RefCounted


## Returns a file handle (real FileAccess or mock) opened at `path` with `flags`.
## Returns null if open fails — caller MUST null-check before use.
##
## ## Return type: Object (duck-type), NOT FileAccess
## Decision (Story 003): return type relaxed from `FileAccess` to `Object` to
## allow `MockFileAccess` to stand in without inheriting `FileAccess`
## (which is a final/built-in engine class that cannot be subclassed). The
## production implementation still returns a real `FileAccess`; mocks return
## `MockFileAccess` which exposes the same `store_string()` / `close()` /
## `get_as_text()` / `get_length()` surface via duck-typing.
##
## Caller code must therefore call methods via Object dispatch (no static
## type guarantees) — this is the explicit cost we accept to keep tests
## fully synchronous and disk-free per ADR-0006 Contract 14.
##
## Production: wraps `FileAccess.open(path, flags)` → returns real FileAccess.
## Tests: override to return a `MockFileAccess` instance with virtual storage.
func open(_path: String, _flags: FileAccess.ModeFlags) -> Object:
	push_error("IFileFactory.open() not overridden — subclass must implement")
	return null


## Returns true if a file exists at `path`. Production implementations wrap
## `FileAccess.file_exists(path)`. Test implementations consult their
## in-memory virtual filesystem.
func file_exists(_path: String) -> bool:
	push_error("IFileFactory.file_exists() not overridden — subclass must implement")
	return false
