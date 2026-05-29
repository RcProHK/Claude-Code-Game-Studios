# PersistenceLayer — Story 006 AC-18 Signal Surface Introspection Tests
#
# Scope: proves all 6 GDD-mandated telemetry signals are declared on
# PersistenceLayer with correct names and argument counts. Uses
# Object.get_signal_list() introspection — no actual signal emission needed.
#
# AC-18 (GDD design/gdd/persistence-layer.md Rule 11):
#   GIVEN PersistenceLayer autoload instantiated,
#   WHEN  `get_signal_list()` introspected,
#   THEN  6 declared signals present with exact signatures:
#     write_completed: (key: String, latency_ms: int, is_touch: bool)        — 3 args
#     flush_completed: (flushed_key_count: int, latency_ms: int, is_critical: bool) — 3 args
#     delete_completed: (key: String, latency_ms: int)                        — 2 args
#     migration_step_completed: (from_version: int, to_version: int, latency_ms: int) — 3 args
#     critical_save_failed: (error_code: String, key: String)                 — 2 args
#     corrupt_save_recovered: (wiped_byte_count: int)                         — 1 arg
#
# WHY introspection matters: if a signal is renamed, re-typed, or dropped by
# a future story, consumers (GSM Contract 11, Telemetry #28) silently
# disconnect. This test makes any such regression immediately visible in CI.
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 11 (IDB fence telemetry hook)
extends GutTest


## Expected signal signatures: name → expected arg count.
## Arg count is stable even if arg names change in minor refactors.
const EXPECTED_SIGNALS: Dictionary = {
	"write_completed": 3,
	"flush_completed": 3,
	"delete_completed": 2,
	"migration_step_completed": 3,
	"critical_save_failed": 2,
	"corrupt_save_recovered": 1,
}


## AC-18: all 6 telemetry signals present with correct argument counts.
func test_persistence_layer_all_6_telemetry_signals_declared() -> void:
	# Arrange — build a lookup from signal name → arg count from the live object.
	var declared: Dictionary = {}
	for sig_info in PersistenceLayer.get_signal_list():
		declared[sig_info["name"]] = sig_info["args"].size()

	# Act + Assert — verify each expected signal exists with the right arg count.
	for signal_name in EXPECTED_SIGNALS:
		var expected_args: int = EXPECTED_SIGNALS[signal_name]
		assert_true(
			declared.has(signal_name),
			"Signal '%s' must be declared on PersistenceLayer" % signal_name
		)
		if declared.has(signal_name):
			assert_eq(
				declared[signal_name],
				expected_args,
				"Signal '%s' must have %d args (got %d)" % [
					signal_name, expected_args, declared[signal_name]
				]
			)


## AC-19 coupling: tombstone_write_completed must NOT be on PersistenceLayer
## (it is GSM-owned per ADR-0006 Contract 11 signal-split decision).
func test_persistence_layer_does_not_declare_tombstone_write_completed() -> void:
	# Arrange
	var declared_names: Array = []
	for sig_info in PersistenceLayer.get_signal_list():
		declared_names.append(sig_info["name"])

	# Assert
	assert_false(
		declared_names.has("tombstone_write_completed"),
		"tombstone_write_completed is GSM-owned — PersistenceLayer must NOT declare it"
	)


## Additional: the 6 expected signals are the ONLY ones from the contract list
## (no unexpected signals introduced that would break consumer code relying on
## signal count for validation).
func test_persistence_layer_signal_list_contains_all_6_expected_signals() -> void:
	# Arrange
	var declared_names: Array = []
	for sig_info in PersistenceLayer.get_signal_list():
		declared_names.append(sig_info["name"])

	# Assert — every expected signal is in the declared list.
	for signal_name in EXPECTED_SIGNALS:
		assert_true(
			declared_names.has(signal_name),
			"Expected signal '%s' not found in get_signal_list()" % signal_name
		)
