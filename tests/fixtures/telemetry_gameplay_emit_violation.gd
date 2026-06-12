extends Node
## FIXTURE (NOT production) — a deliberately-violating telemetry-style file used by
## tests/static/test_telemetry_ci_lint.gd to prove check_telemetry_no_gameplay_emit.gd
## actually catches a gameplay emit / mutator / namespace write. This file must NEVER be
## referenced by real code and lives outside the lint's scan scope (it scans
## src/autoload/telemetry.gd + src/telemetry/* only).

signal telemetry_self_error(context)
signal duplicate_transition_observed(info)

var _persistence = null
var _loot = null


func _bad_observer() -> void:
	# VIOLATION 1 — gameplay persistence namespace write (only telemetry.* would be legal).
	_persistence.write("stat.xp", 5)
	# VIOLATION 2 — a #15 gameplay mutator call.
	_loot.claim_drop("drop_42")
	# VIOLATION 3 — emitting a gameplay signal (telemetry is a pure observer).
	emit_signal("loot_dropped", "drop_42", "EPIC", "sword", "t1")


func _legal_owned_meta() -> void:
	# EXEMPT — telemetry-owned diagnostic meta surfaced as a signal (OWNED_META allowlist).
	telemetry_self_error.emit("self check")
	emit_signal("duplicate_transition_observed", {})
