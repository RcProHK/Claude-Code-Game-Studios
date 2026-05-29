## MockPersistenceLayer — Test spy for IPersistence consumers (ADR-0006 Contract 14)
##
## Used by Story 014+ consumer system tests (GameStateMachine, GymSys Client,
## etc.) to verify that downstream systems call PersistenceLayer.write() /
## delete() with the expected key/value patterns — WITHOUT touching disk and
## WITHOUT requiring the real autoload to be in the boot order.
##
## Extends RefCounted (NOT Node): MockPersistenceLayer is instantiated per
## test via `MockPersistenceLayer.new()`, never registered as an autoload.
## The duck-typed surface (read / write / delete / migrate / attach_*_spy /
## clear_spies) matches the production PersistenceLayer one-to-one so
## consumer code can swap between them transparently.
##
## ## Behaviour summary
## - `write(key, value, flush=false)` updates the in-memory `_data` Dict
##   and invokes every attached write spy with `{"key": key, "value": value}`.
## - `delete(key)` removes the entry (returns false if missing) and invokes
##   every attached delete spy with the bare `key` String.
## - `attach_write_spy(cb)` / `attach_delete_spy(cb)` append the Callable to
##   the spy list. Multiple spies allowed.
## - `clear_spies()` clears BOTH spy lists; future writes/deletes invoke
##   nothing until new spies are attached.
## - `reset()` clears `_data` AND spies — call in before_each() if the same
##   instance is reused across tests (otherwise prefer fresh `.new()`).
##
## ## Usage (Story 014+)
## ```gdscript
## var mock := MockPersistenceLayer.new()
## var log: Array = []
## mock.attach_write_spy(log.append)
## mock.write("foo", "bar")
## assert_eq(log[0], {"key": "foo", "value": "bar"})
## ```
class_name MockPersistenceLayer extends RefCounted


# ============================================================================
# State
# ============================================================================

## In-memory key→value store. Mirrors production PersistenceLayer._cache shape.
var _data: Dictionary = {}

## Attached write spies. Each Callable receives `{"key": key, "value": value}`.
var _write_spies: Array[Callable] = []

## Attached delete spies. Each Callable receives the bare `key` String.
var _delete_spies: Array[Callable] = []


# ============================================================================
# IPersistence-shape methods (duck-typed against production PersistenceLayer)
# ============================================================================

## Returns the value stored under `key`, or null if missing.
func read(key: String) -> Variant:
	return _data.get(key)


## Stores `value` under `key`, invokes every write spy. Returns true.
## `_flush` flag accepted for API parity with production; mocks never touch disk.
func write(key: String, value: Variant, _flush: bool = false) -> bool:
	_data[key] = value
	for spy in _write_spies:
		spy.call({"key": key, "value": value})
	return true


## Removes `key`, invokes every delete spy. Returns false if `key` did not exist.
func delete(key: String) -> bool:
	if not _data.has(key):
		return false
	_data.erase(key)
	for spy in _delete_spies:
		spy.call(key)
	return true


## Migration stub — always returns true. Mocks do not exercise migration logic.
func migrate(_from_version: int, _to_version: int) -> bool:
	return true


# ============================================================================
# Spy attachment (ADR-0006 Contract 14 interface)
# ============================================================================

## Attach a Callable invoked with `{"key": key, "value": value}` on every write.
func attach_write_spy(spy: Callable) -> void:
	_write_spies.append(spy)


## Attach a Callable invoked with the `key` String on every delete.
func attach_delete_spy(spy: Callable) -> void:
	_delete_spies.append(spy)


## Clear all attached write + delete spies. Subsequent writes/deletes invoke nothing.
func clear_spies() -> void:
	_write_spies.clear()
	_delete_spies.clear()


# ============================================================================
# Test helpers
# ============================================================================

## Full reset: clear in-memory data AND drop all spies. Call in before_each()
## if reusing the same instance across tests (prefer fresh `.new()` otherwise).
func reset() -> void:
	_data.clear()
	clear_spies()
